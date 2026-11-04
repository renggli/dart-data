import 'dart:math' as math;
import 'dart:typed_data';

import '../../acceleration/blas/blas.dart';
import '../../acceleration/vforce/vforce.dart';
import '../../type/data_type.dart';
import '../../type/utils/memory.dart';
import '../layout.dart';
import '../tensor.dart';
import 'operation.dart';

/// Multi-axis reduction and aggregation operations on tensors.
extension ReductionTensorExtension<T> on Tensor<T> {
  /// Computes the sum of elements over the given [axis], or all elements if
  /// [axis] is null.
  Tensor<T> sum({int? axis, bool keepDims = false, Tensor<T>? target}) {
    if (axis == null && layout.isContiguous && data is Float64List) {
      final outShape = keepDims ? List<int>.filled(rank, 1) : <int>[];
      if (target != null && !areShapesEqual(target.layout.shape, outShape)) {
        throw ArgumentError(
          'Target shape ${target.layout.shape} does not match reduced shape $outShape',
        );
      }
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

  /// Computes the arithmetic mean over the given [axis], or all elements if
  /// [axis] is null.
  Tensor<double> mean({
    int? axis,
    bool keepDims = false,
    Tensor<double>? target,
  }) {
    if (axis == null) {
      final count = length;
      if (count == 0) throw StateError('Cannot compute mean of empty tensor');
      final outShape = keepDims ? List<int>.filled(rank, 1) : <int>[];
      if (target != null && !areShapesEqual(target.layout.shape, outShape)) {
        throw ArgumentError(
          'Target shape ${target.layout.shape} does not match reduced shape $outShape',
        );
      }
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
        var sum = 0.0;
        for (final val in values) {
          sum += _toDouble(val);
        }
        result = sum / count;
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

    final normalizedAxis = axis < 0 ? axis + rank : axis;
    if (normalizedAxis < 0 || normalizedAxis >= rank) {
      throw RangeError.range(axis, -rank, rank - 1, 'axis');
    }
    final count = layout.shape[normalizedAxis];
    if (count == 0) throw StateError('Cannot compute mean of empty tensor');

    final outShape = <int>[];
    for (var i = 0; i < rank; i++) {
      if (i == normalizedAxis) {
        if (keepDims) outShape.add(1);
      } else {
        outShape.add(layout.shape[i]);
      }
    }

    if (target != null && !areShapesEqual(target.layout.shape, outShape)) {
      throw ArgumentError(
        'Target shape ${target.layout.shape} does not match reduced shape $outShape',
      );
    }

    final hasHazard = target != null && sharesMemory(target.data, data);
    final outTensor = (target != null && !hasHazard)
        ? target
        : Tensor<double>.filled(0.0, shape: outShape, type: DataType.float64);

    final outLayout = Layout(shape: outShape);
    final axisStride = layout.strides[normalizedAxis];

    for (final key in outLayout.keys) {
      final inKey = List<int>.from(key);
      if (!keepDims) {
        inKey.insert(normalizedAxis, 0);
      }
      inKey[normalizedAxis] = 0;
      final baseOffset = layout.toIndex(inKey);

      var sum = 0.0;
      var offset = baseOffset;
      for (var k = 0; k < count; k++) {
        sum += _toDouble(data[offset]);
        offset += axisStride;
      }
      outTensor.setValue(key, sum / count);
    }

    if (hasHazard) {
      outTensor.copy(target: target);
      return target;
    }
    return outTensor;
  }

  /// Computes the minimum value over the given [axis], or all elements if
  /// [axis] is null.
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
  /// [axis] is null.
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
  /// null.
  ///
  /// Conceptually, variance measures how spread out the values are from their
  /// arithmetic mean. A variance of zero indicates all values are identical.
  ///
  /// Formally, this calculates the sample or population variance
  /// $\sigma^2 = \frac{1}{N - \text{ddof}} \sum_{i=1}^N (x_i - \bar{x})^2$.
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
    if (axis == null) {
      final count = length;
      final denom = count - ddof;
      if (denom <= 0) throw StateError('Degrees of freedom <= 0');

      final outShape = keepDims ? List<int>.filled(rank, 1) : <int>[];
      if (target != null && !areShapesEqual(target.layout.shape, outShape)) {
        throw ArgumentError(
          'Target shape ${target.layout.shape} does not match reduced shape $outShape',
        );
      }

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
          v = (popVar * count) / denom;
        }
      } else {
        var sum = 0.0;
        for (final val in values) {
          sum += _toDouble(val);
        }
        final meanVal = sum / count;

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

    final normalizedAxis = axis < 0 ? axis + rank : axis;
    if (normalizedAxis < 0 || normalizedAxis >= rank) {
      throw RangeError.range(axis, -rank, rank - 1, 'axis');
    }
    final count = layout.shape[normalizedAxis];
    final denom = count - ddof;
    if (denom <= 0) throw StateError('Degrees of freedom <= 0');

    final outShape = <int>[];
    for (var i = 0; i < rank; i++) {
      if (i == normalizedAxis) {
        if (keepDims) outShape.add(1);
      } else {
        outShape.add(layout.shape[i]);
      }
    }

    if (target != null && !areShapesEqual(target.layout.shape, outShape)) {
      throw ArgumentError(
        'Target shape ${target.layout.shape} does not match reduced shape $outShape',
      );
    }

    final hasHazard = target != null && sharesMemory(target.data, data);
    final outTensor = (target != null && !hasHazard)
        ? target
        : Tensor<double>.filled(0.0, shape: outShape, type: DataType.float64);

    final outLayout = Layout(shape: outShape);
    final axisStride = layout.strides[normalizedAxis];

    for (final key in outLayout.keys) {
      final inKey = List<int>.from(key);
      if (!keepDims) {
        inKey.insert(normalizedAxis, 0);
      }
      inKey[normalizedAxis] = 0;
      final baseOffset = layout.toIndex(inKey);

      var sum = 0.0;
      var offset = baseOffset;
      for (var k = 0; k < count; k++) {
        sum += _toDouble(data[offset]);
        offset += axisStride;
      }
      final meanVal = sum / count;

      var sumSq = 0.0;
      offset = baseOffset;
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
  Tensor<double> std({
    int? axis,
    bool keepDims = false,
    int ddof = 0,
    Tensor<double>? target,
  }) {
    final varTensor = variance(
      axis: axis,
      keepDims: keepDims,
      ddof: ddof,
      target: target,
    );
    return varTensor.unaryOperation<double>(
      math.sqrt,
      type: DataType.float64,
      target: varTensor,
    );
  }

  /// Computes the $L_p$ norm of this tensor.
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
      var scale = 0.0;
      var sumsq = 1.0;
      for (final val in values) {
        final absVal = type.field.norm(val);
        if (absVal != 0.0) {
          if (absVal.isNaN) return double.nan;
          if (absVal.isInfinite) {
            scale = double.infinity;
          } else if (scale < absVal) {
            sumsq = 1.0 + sumsq * (scale / absVal) * (scale / absVal);
            scale = absVal;
          } else if (scale.isFinite) {
            sumsq += (absVal / scale) * (absVal / scale);
          }
        }
      }
      return scale * math.sqrt(sumsq);
    } else {
      var sum = 0.0;
      for (final val in values) {
        sum += math.pow(type.field.norm(val), pNorm);
      }
      return math.pow(sum, 1.0 / pNorm).toDouble();
    }
  }

  /// Finds the index of the minimum value.
  Tensor<int> argmin({int? axis, bool keepDims = false}) =>
      _argReduceAxis(axis: axis, keepDims: keepDims, findMin: true);

  /// Finds the index of the maximum value.
  Tensor<int> argmax({int? axis, bool keepDims = false}) =>
      _argReduceAxis(axis: axis, keepDims: keepDims, findMin: false);

  Tensor<T> _reduceAxis({
    int? axis,
    required bool keepDims,
    Tensor<T>? target,
    T? initialValue,
    required T Function(T a, T b) combine,
  }) {
    if (axis == null) {
      final outShape = keepDims ? List<int>.filled(rank, 1) : <int>[];
      if (target != null && !areShapesEqual(target.layout.shape, outShape)) {
        throw ArgumentError(
          'Target shape ${target.layout.shape} does not match reduced shape $outShape',
        );
      }
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

    final normalizedAxis = axis < 0 ? axis + rank : axis;
    if (normalizedAxis < 0 || normalizedAxis >= rank) {
      throw RangeError.value(axis, 'axis', 'Axis out of range [0, $rank)');
    }

    final axisLen = layout.shape[normalizedAxis];
    if (axisLen == 0 && initialValue == null) {
      throw StateError('Cannot reduce empty axis without initialValue');
    }
    final outShape = <int>[];
    for (var i = 0; i < rank; i++) {
      if (i == normalizedAxis) {
        if (keepDims) outShape.add(1);
      } else {
        outShape.add(layout.shape[i]);
      }
    }

    if (target != null && !areShapesEqual(target.layout.shape, outShape)) {
      throw ArgumentError(
        'Target shape ${target.layout.shape} does not match reduced shape $outShape',
      );
    }

    final outLayout = Layout(shape: outShape);
    final hasHazard = target != null && sharesMemory(target.data, data);
    final outTensor = (target != null && !hasHazard)
        ? target
        : Tensor<T>.filled(type.defaultValue, shape: outShape, type: type);

    for (final key in outLayout.keys) {
      final inKey = List<int>.from(key);
      if (!keepDims) {
        inKey.insert(normalizedAxis, 0);
      }
      inKey[normalizedAxis] = 0;
      var acc = initialValue ?? getValue(inKey);
      final startK = initialValue == null ? 1 : 0;
      for (var k = startK; k < axisLen; k++) {
        inKey[normalizedAxis] = k;
        acc = combine(acc, getValue(inKey));
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
  }) {
    final cmp = type.comparator;
    if (axis == null) {
      if (length == 0) throw StateError('Cannot arg-reduce empty tensor');
      var bestIdx = 0;
      var bestVal = values.first;
      var idx = 0;
      for (final val in values) {
        if (val is double && val.isNaN) {
          bestVal = val;
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
      final outShape = keepDims ? List<int>.filled(rank, 1) : <int>[];
      return Tensor<int>.filled(bestIdx, shape: outShape, type: DataType.int32);
    }

    final normalizedAxis = axis < 0 ? axis + rank : axis;
    if (normalizedAxis < 0 || normalizedAxis >= rank) {
      throw RangeError.value(axis, 'axis', 'Axis out of range [0, $rank)');
    }

    final axisLen = layout.shape[normalizedAxis];
    if (axisLen == 0) {
      throw StateError('Cannot arg-reduce empty axis');
    }
    final outShape = <int>[];
    for (var i = 0; i < rank; i++) {
      if (i == normalizedAxis) {
        if (keepDims) outShape.add(1);
      } else {
        outShape.add(layout.shape[i]);
      }
    }

    final outLayout = Layout(shape: outShape);
    final outTensor = Tensor<int>.filled(
      0,
      shape: outShape,
      type: DataType.int32,
    );

    for (final key in outLayout.keys) {
      final inKey = List<int>.from(key);
      if (!keepDims) {
        inKey.insert(normalizedAxis, 0);
      }
      inKey[normalizedAxis] = 0;
      var bestIdx = 0;
      var bestVal = getValue(inKey);
      if (bestVal is! double || !bestVal.isNaN) {
        for (var k = 1; k < axisLen; k++) {
          inKey[normalizedAxis] = k;
          final currentVal = getValue(inKey);
          if (currentVal is double && currentVal.isNaN) {
            bestVal = currentVal;
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
        }
      }
      outTensor.setValue(key, bestIdx);
    }
    return outTensor;
  }
}

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  return DataType.float64.cast(value);
}
