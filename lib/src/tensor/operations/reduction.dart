import 'dart:math' as math;
import 'dart:typed_data';

import '../../acceleration/blas/blas.dart';
import '../../acceleration/utils/norm_accumulator.dart';
import '../../acceleration/vforce/vforce.dart';
import '../../type/data_type.dart';
import '../../type/utils/memory.dart';
import '../layout.dart';
import '../tensor.dart';

/// Multi-axis reduction and aggregation operations on tensors.
extension ReductionTensorExtension<T> on Tensor<T> {
  /// Computes the sum of elements over the given [axis], or all elements if
  /// [axis] is `null`.
  Tensor<T> sum({int? axis, bool keepDims = false, Tensor<T>? target}) {
    if (axis == null && layout.isContiguous && data is Float64List) {
      final outShape = keepDims ? List<int>.filled(rank, 1) : <int>[];
      _validateTargetShape(target, outShape);
      final double result;
      if (length == 0) {
        result = 0.0;
      } else {
        final f64Data = data as Float64List;
        final view = (layout.offset == 0 && length == f64Data.length)
            ? f64Data
            : Float64List.sublistView(
                f64Data,
                layout.offset,
                layout.offset + length,
              );
        result = Vforce.sum(x: view);
      }
      if (target != null) {
        target.setValue(List<int>.filled(outShape.length, 0), result as T);
        return target;
      }
      return Tensor<T>.filled(result as T, shape: outShape, type: type);
    }
    final field = type.field;
    return _reduceAxis(
      axis: axis,
      keepDims: keepDims,
      target: target,
      initialValue: field.additiveIdentity,
      combine: field.add,
    );
  }

  /// Computes the product of elements over the given [axis], or all elements
  /// if [axis] is `null`.
  Tensor<T> prod({int? axis, bool keepDims = false, Tensor<T>? target}) {
    final field = type.field;
    return _reduceAxis(
      axis: axis,
      keepDims: keepDims,
      target: target,
      initialValue: field.multiplicativeIdentity,
      combine: field.mul,
    );
  }

  /// Computes the arithmetic mean over the given [axis], or all elements if
  /// [axis] is `null`.
  ///
  /// Uses overflow-safe summation fallback when direct summation overflows on
  /// large finite inputs.
  Tensor<double> mean({
    int? axis,
    bool keepDims = false,
    Tensor<double>? target,
  }) {
    if (axis == null) {
      final count = length;
      if (count == 0) throw StateError('Cannot compute mean of empty tensor');
      final outShape = keepDims ? List<int>.filled(rank, 1) : <int>[];
      _validateTargetShape(target, outShape);
      final double result;
      if (data is Float64List && layout.isContiguous) {
        final f64Data = data as Float64List;
        final view = (layout.offset == 0 && count == f64Data.length)
            ? f64Data
            : Float64List.sublistView(
                f64Data,
                layout.offset,
                layout.offset + count,
              );
        result = Vforce.mean(x: view);
      } else {
        result = _safeMeanIterable(values, count);
      }
      if (target != null) {
        target.setValue(List<int>.filled(outShape.length, 0), result);
        return target;
      }
      return Tensor<double>.filled(
        result,
        shape: outShape,
        type: DataType.float64,
      );
    }

    final normalizedAxis = _normalizeReductionAxis(axis, rank);
    final count = layout.shape[normalizedAxis];
    if (count == 0) throw StateError('Cannot compute mean of empty tensor');

    final outShape = _reducedShape(layout.shape, normalizedAxis, keepDims);
    _validateTargetShape(target, outShape);

    final hasHazard = target != null && sharesMemory(target.data, data);
    final outTensor = (target != null && !hasHazard)
        ? target
        : Tensor<double>.filled(0.0, shape: outShape, type: DataType.float64);

    final outLayout = Layout(shape: outShape);
    final axisStride = layout.strides[normalizedAxis];

    for (final key in outLayout.keys) {
      final baseOffset = _fiberBaseOffset(key, normalizedAxis, keepDims);
      outTensor.setValue(
        key,
        _safeMeanFiber(data, baseOffset, count, axisStride),
      );
    }

    if (hasHazard) {
      outTensor.copy(target: target);
      return target;
    }
    return outTensor;
  }

  /// Computes the minimum value over the given [axis], or all elements if
  /// [axis] is `null`.
  Tensor<T> min({int? axis, bool keepDims = false, Tensor<T>? target}) {
    if (axis == null && length == 0) {
      throw StateError('Cannot compute min of empty tensor');
    }
    final cmp = type.comparator;
    return _reduceAxis(
      axis: axis,
      keepDims: keepDims,
      target: target,
      combine: (a, b) {
        if (a is double && a.isNaN) return a;
        if (b is double && b.isNaN) return b;
        return cmp(a, b) <= 0 ? a : b;
      },
    );
  }

  /// Computes the maximum value over the given [axis], or all elements if
  /// [axis] is `null`.
  Tensor<T> max({int? axis, bool keepDims = false, Tensor<T>? target}) {
    if (axis == null && length == 0) {
      throw StateError('Cannot compute max of empty tensor');
    }
    final cmp = type.comparator;
    return _reduceAxis(
      axis: axis,
      keepDims: keepDims,
      target: target,
      combine: (a, b) {
        if (a is double && a.isNaN) return a;
        if (b is double && b.isNaN) return b;
        return cmp(a, b) >= 0 ? a : b;
      },
    );
  }

  /// Computes the variance over the given [axis], or all elements if [axis] is
  /// `null`.
  ///
  /// Conceptually, variance measures how spread out the values are from their
  /// arithmetic mean. A variance of zero indicates all values are identical.
  ///
  /// Formally, this calculates the sample or population variance
  /// `σ^2 = (1 / (N - ddof)) * ∑_{i=1}^N (x_i - mean)^2`.
  ///
  /// Throws a [RangeError] if [ddof] is negative, or a [StateError] if
  /// `N - ddof <= 0`.
  ///
  /// ```dart
  /// final t = Tensor<double>.fromIterable(
  ///   [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0],
  /// );
  /// final v = t.variance().toFlatList().first; // 4.0
  /// ```
  Tensor<double> variance({
    int? axis,
    bool keepDims = false,
    int ddof = 0,
    Tensor<double>? target,
  }) {
    RangeError.checkNotNegative(ddof, 'ddof');
    if (axis == null) {
      final count = length;
      final denom = count - ddof;
      if (denom <= 0) throw StateError('Degrees of freedom <= 0');

      final outShape = keepDims ? List<int>.filled(rank, 1) : <int>[];
      _validateTargetShape(target, outShape);

      final double v;
      if (data is Float64List && layout.isContiguous) {
        final f64Data = data as Float64List;
        final view = (layout.offset == 0 && count == f64Data.length)
            ? f64Data
            : Float64List.sublistView(
                f64Data,
                layout.offset,
                layout.offset + count,
              );
        if (ddof == 0) {
          v = Vforce.variance(x: view, sample: false);
        } else if (ddof == 1) {
          v = Vforce.variance(x: view, sample: true);
        } else {
          final popVar = Vforce.variance(x: view, sample: false);
          v = popVar * (count / denom);
        }
      } else {
        final meanVal = _safeMeanIterable(values, count);
        var sumSq = 0.0;
        for (final val in values) {
          final diff = _toDouble(val) - meanVal;
          sumSq += diff * diff;
        }
        v = sumSq / denom;
      }

      if (target != null) {
        target.setValue(List<int>.filled(outShape.length, 0), v);
        return target;
      }
      return Tensor<double>.filled(v, shape: outShape, type: DataType.float64);
    }

    final normalizedAxis = _normalizeReductionAxis(axis, rank);
    final count = layout.shape[normalizedAxis];
    final denom = count - ddof;
    if (denom <= 0) throw StateError('Degrees of freedom <= 0');

    final outShape = _reducedShape(layout.shape, normalizedAxis, keepDims);
    _validateTargetShape(target, outShape);

    final hasHazard = target != null && sharesMemory(target.data, data);
    final outTensor = (target != null && !hasHazard)
        ? target
        : Tensor<double>.filled(0.0, shape: outShape, type: DataType.float64);

    final outLayout = Layout(shape: outShape);
    final axisStride = layout.strides[normalizedAxis];

    for (final key in outLayout.keys) {
      final baseOffset = _fiberBaseOffset(key, normalizedAxis, keepDims);
      final meanVal = _safeMeanFiber(data, baseOffset, count, axisStride);

      var sumSq = 0.0;
      var offset = baseOffset;
      for (var k = 0; k < count; k++) {
        final diff = _toDouble(data[offset]) - meanVal;
        sumSq += diff * diff;
        offset += axisStride;
      }
      outTensor.setValue(key, sumSq / denom);
    }

    if (hasHazard) {
      outTensor.copy(target: target);
      return target;
    }
    return outTensor;
  }

  /// Computes the standard deviation over the given [axis].
  ///
  /// Uses [ScaledNormAccumulator] fallback when squaring deviations overflows
  /// or underflows for finite inputs.
  Tensor<double> std({
    int? axis,
    bool keepDims = false,
    int ddof = 0,
    Tensor<double>? target,
  }) {
    RangeError.checkNotNegative(ddof, 'ddof');
    final hasHazard = target != null && sharesMemory(target.data, data);
    final safeTarget = hasHazard ? null : target;
    final outTensor = variance(
      axis: axis,
      keepDims: keepDims,
      ddof: ddof,
      target: safeTarget,
    );

    if (axis == null) {
      final v = outTensor.data[outTensor.layout.offset];
      final double s;
      if (v.isFinite && v > 0.0) {
        s = math.sqrt(v);
      } else {
        s = _safeStdIterable(values, length, length - ddof);
      }
      outTensor.data[outTensor.layout.offset] = s;
    } else {
      final normalizedAxis = _normalizeReductionAxis(axis, rank);
      final count = layout.shape[normalizedAxis];
      final denom = count - ddof;
      final axisStride = layout.strides[normalizedAxis];
      for (final key in outTensor.layout.keys) {
        final v = outTensor.getValue(key);
        if (v.isFinite && v > 0.0) {
          outTensor.setValue(key, math.sqrt(v));
        } else {
          final baseOffset = _fiberBaseOffset(key, normalizedAxis, keepDims);
          outTensor.setValue(
            key,
            _safeStdFiber(data, baseOffset, count, axisStride, denom),
          );
        }
      }
    }

    if (hasHazard) {
      outTensor.copy(target: target);
      return target;
    }
    return outTensor;
  }

  /// Computes the `L_p` norm of this tensor.
  double norm([num pNorm = 2]) {
    if (pNorm.isNaN || pNorm < 1) {
      throw ArgumentError.value(pNorm, 'pNorm', 'pNorm must be >= 1');
    }
    if (length == 0) return 0.0;
    if (pNorm == double.infinity) {
      var maxVal = 0.0;
      for (final val in values) {
        final absVal = type.field.norm(val);
        if (absVal.isNaN) return double.nan;
        if (absVal > maxVal) maxVal = absVal;
      }
      return maxVal;
    } else if (pNorm == 1) {
      var sum = 0.0;
      for (final val in values) {
        sum += type.field.norm(val);
      }
      return sum;
    } else if (pNorm == 2) {
      if (layout.isContiguous && data is Float64List) {
        return Blas.dnrm2(
          n: length,
          x: data as Float64List,
          xOffset: offset,
          incX: 1,
        );
      } else if (layout.isContiguous && data is Float32List) {
        return Blas.snrm2(
          n: length,
          x: data as Float32List,
          xOffset: offset,
          incX: 1,
        );
      }
      final acc = ScaledNormAccumulator();
      for (final val in values) {
        acc.addAbs(type.field.norm(val));
      }
      return acc.norm;
    } else {
      var maxVal = 0.0;
      for (final val in values) {
        final absVal = type.field.norm(val);
        if (absVal.isNaN) return double.nan;
        if (absVal > maxVal) maxVal = absVal;
      }
      if (maxVal == 0.0 || maxVal.isInfinite) return maxVal;
      var sum = 0.0;
      for (final val in values) {
        final scaled = type.field.norm(val) / maxVal;
        sum += math.pow(scaled, pNorm);
      }
      return maxVal * math.pow(sum, 1.0 / pNorm).toDouble();
    }
  }

  /// Finds the index of the minimum value along [axis], or globally when
  /// [axis] is `null`.
  Tensor<int> argmin({int? axis, bool keepDims = false, Tensor<int>? target}) =>
      _argReduceAxis(
        axis: axis,
        keepDims: keepDims,
        findMin: true,
        target: target,
      );

  /// Finds the index of the maximum value along [axis], or globally when
  /// [axis] is `null`.
  Tensor<int> argmax({int? axis, bool keepDims = false, Tensor<int>? target}) =>
      _argReduceAxis(
        axis: axis,
        keepDims: keepDims,
        findMin: false,
        target: target,
      );

  Tensor<T> _reduceAxis({
    int? axis,
    required bool keepDims,
    Tensor<T>? target,
    T? initialValue,
    required T Function(T a, T b) combine,
  }) {
    if (axis == null) {
      final outShape = keepDims ? List<int>.filled(rank, 1) : <int>[];
      _validateTargetShape(target, outShape);
      T result;
      if (layout.isContiguous && length > 0) {
        final start = layout.offset;
        final srcData = data;
        result = initialValue ?? srcData[start];
        final i0 = initialValue == null ? start + 1 : start;
        for (var i = i0; i < start + length; i++) {
          result = combine(result, srcData[i]);
        }
      } else {
        final it = values.iterator;
        if (!it.moveNext()) {
          result =
              initialValue ??
              (throw StateError(
                'Cannot reduce empty tensor without initialValue',
              ));
        } else {
          result = initialValue == null
              ? it.current
              : combine(initialValue, it.current);
          while (it.moveNext()) {
            result = combine(result, it.current);
          }
        }
      }
      if (target != null) {
        target.setValue(List<int>.filled(outShape.length, 0), result);
        return target;
      }
      return Tensor<T>.filled(result, shape: outShape, type: type);
    }

    final normalizedAxis = _normalizeReductionAxis(axis, rank);
    final axisLen = layout.shape[normalizedAxis];
    if (axisLen == 0 && initialValue == null) {
      throw StateError('Cannot reduce empty axis without initialValue');
    }
    final outShape = _reducedShape(layout.shape, normalizedAxis, keepDims);
    _validateTargetShape(target, outShape);

    final outLayout = Layout(shape: outShape);
    final hasHazard = target != null && sharesMemory(target.data, data);
    final outTensor = (target != null && !hasHazard)
        ? target
        : Tensor<T>.filled(type.defaultValue, shape: outShape, type: type);

    final axisStride = layout.strides[normalizedAxis];
    for (final key in outLayout.keys) {
      var offset = _fiberBaseOffset(key, normalizedAxis, keepDims);
      T acc;
      if (initialValue != null) {
        acc = initialValue;
        for (var k = 0; k < axisLen; k++) {
          acc = combine(acc, data[offset]);
          offset += axisStride;
        }
      } else {
        acc = data[offset];
        offset += axisStride;
        for (var k = 1; k < axisLen; k++) {
          acc = combine(acc, data[offset]);
          offset += axisStride;
        }
      }
      outTensor.setValue(key, acc);
    }
    if (hasHazard) {
      outTensor.copy(target: target);
      return target;
    }
    return outTensor;
  }

  Tensor<int> _argReduceAxis({
    int? axis,
    required bool keepDims,
    required bool findMin,
    Tensor<int>? target,
  }) {
    final cmp = type.comparator;
    if (axis == null) {
      if (length == 0) throw StateError('Cannot arg-reduce empty tensor');
      final outShape = keepDims ? List<int>.filled(rank, 1) : <int>[];
      _validateTargetShape(target, outShape);

      final it = values.iterator..moveNext();
      var bestIdx = 0;
      var bestVal = it.current;
      if (bestVal is! double || !bestVal.isNaN) {
        var idx = 1;
        while (it.moveNext()) {
          final val = it.current;
          if (val is double && val.isNaN) {
            bestIdx = idx;
            break;
          }
          final isBetter = findMin
              ? cmp(val, bestVal) < 0
              : cmp(val, bestVal) > 0;
          if (isBetter) {
            bestVal = val;
            bestIdx = idx;
          }
          idx++;
        }
      }
      if (target != null) {
        target.setValue(List<int>.filled(outShape.length, 0), bestIdx);
        return target;
      }
      return Tensor<int>.filled(bestIdx, shape: outShape, type: DataType.int32);
    }

    final normalizedAxis = _normalizeReductionAxis(axis, rank);
    final axisLen = layout.shape[normalizedAxis];
    if (axisLen == 0) {
      throw StateError('Cannot arg-reduce empty axis');
    }
    final outShape = _reducedShape(layout.shape, normalizedAxis, keepDims);
    _validateTargetShape(target, outShape);

    final outLayout = Layout(shape: outShape);
    final hasHazard = target != null && sharesMemory(target.data, data);
    final outTensor = (target != null && !hasHazard)
        ? target
        : Tensor<int>.filled(0, shape: outShape, type: DataType.int32);

    final axisStride = layout.strides[normalizedAxis];
    for (final key in outLayout.keys) {
      var offset = _fiberBaseOffset(key, normalizedAxis, keepDims);
      var bestIdx = 0;
      var bestVal = data[offset];
      if (bestVal is! double || !bestVal.isNaN) {
        offset += axisStride;
        for (var k = 1; k < axisLen; k++) {
          final currentVal = data[offset];
          if (currentVal is double && currentVal.isNaN) {
            bestIdx = k;
            break;
          }
          final isBetter = findMin
              ? cmp(currentVal, bestVal) < 0
              : cmp(currentVal, bestVal) > 0;
          if (isBetter) {
            bestVal = currentVal;
            bestIdx = k;
          }
          offset += axisStride;
        }
      }
      outTensor.setValue(key, bestIdx);
    }
    if (hasHazard) {
      outTensor.copy(target: target);
      return target;
    }
    return outTensor;
  }

  int _fiberBaseOffset(List<int> outKey, int normalizedAxis, bool keepDims) {
    final inKey = List<int>.from(outKey);
    if (!keepDims) {
      inKey.insert(normalizedAxis, 0);
    } else {
      inKey[normalizedAxis] = 0;
    }
    return layout.toIndex(inKey);
  }
}

/// Boolean quantifier reductions on [Tensor<bool>].
extension LogicalReductionTensorExtension on Tensor<bool> {
  /// Returns whether all elements along [axis] (or the whole tensor) are
  /// `true`.
  Tensor<bool> all({int? axis, bool keepDims = false, Tensor<bool>? target}) =>
      _reduceAxis(
        axis: axis,
        keepDims: keepDims,
        target: target,
        initialValue: true,
        combine: (a, b) => a && b,
      );

  /// Returns whether any element along [axis] (or the whole tensor) is `true`.
  Tensor<bool> any({int? axis, bool keepDims = false, Tensor<bool>? target}) =>
      _reduceAxis(
        axis: axis,
        keepDims: keepDims,
        target: target,
        initialValue: false,
        combine: (a, b) => a || b,
      );
}

int _normalizeReductionAxis(int axis, int rank) {
  final normalized = axis < 0 ? axis + rank : axis;
  if (normalized < 0 || normalized >= rank) {
    throw RangeError.range(axis, -rank, rank - 1, 'axis');
  }
  return normalized;
}

List<int> _reducedShape(List<int> shape, int normalizedAxis, bool keepDims) {
  final outShape = <int>[];
  for (var i = 0; i < shape.length; i++) {
    if (i == normalizedAxis) {
      if (keepDims) outShape.add(1);
    } else {
      outShape.add(shape[i]);
    }
  }
  return outShape;
}

void _validateTargetShape<R>(Tensor<R>? target, List<int> expectedShape) {
  if (target != null && !areShapesEqual(target.layout.shape, expectedShape)) {
    throw ArgumentError(
      'Target shape ${target.layout.shape} does not match reduced shape $expectedShape',
    );
  }
}

double _safeMeanIterable(Iterable<Object?> items, int count) {
  var sum = 0.0;
  for (final val in items) {
    sum += _toDouble(val);
  }
  final avg = sum / count;
  if (avg.isFinite) return avg;
  for (final val in items) {
    if (!_toDouble(val).isFinite) return avg;
  }
  var welford = 0.0;
  var i = 0;
  for (final val in items) {
    welford += (_toDouble(val) - welford) / (++i);
  }
  return welford;
}

double _safeMeanFiber(
  List<Object?> data,
  int baseOffset,
  int count,
  int stride,
) {
  var sum = 0.0;
  var offset = baseOffset;
  for (var k = 0; k < count; k++) {
    sum += _toDouble(data[offset]);
    offset += stride;
  }
  final avg = sum / count;
  if (avg.isFinite) return avg;
  offset = baseOffset;
  for (var k = 0; k < count; k++) {
    if (!_toDouble(data[offset]).isFinite) return avg;
    offset += stride;
  }
  var welford = 0.0;
  offset = baseOffset;
  for (var k = 0; k < count; k++) {
    welford += (_toDouble(data[offset]) - welford) / (k + 1);
    offset += stride;
  }
  return welford;
}

double _safeStdIterable(Iterable<Object?> items, int count, int denom) {
  final meanVal = _safeMeanIterable(items, count);
  if (!meanVal.isFinite) return double.nan;
  final acc = ScaledNormAccumulator();
  for (final val in items) {
    acc.addAbs((_toDouble(val) - meanVal).abs());
  }
  return acc.norm / math.sqrt(denom);
}

double _safeStdFiber(
  List<Object?> data,
  int baseOffset,
  int count,
  int stride,
  int denom,
) {
  final meanVal = _safeMeanFiber(data, baseOffset, count, stride);
  if (!meanVal.isFinite) return double.nan;
  final acc = ScaledNormAccumulator();
  var offset = baseOffset;
  for (var k = 0; k < count; k++) {
    acc.addAbs((_toDouble(data[offset]) - meanVal).abs());
    offset += stride;
  }
  return acc.norm / math.sqrt(denom);
}

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  return DataType.float64.cast(value);
}
