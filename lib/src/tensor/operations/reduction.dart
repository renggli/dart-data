import 'dart:math' as math;

import '../../../type.dart';
import '../layout.dart';
import '../tensor.dart';
import 'operation.dart';

extension ReductionTensorExtension<T> on Tensor<T> {
  /// Computes the sum of elements over the given [axis], or all elements if [axis] is null.
  Tensor<T> sum({int? axis, bool keepDims = false, Tensor<T>? target}) {
    final field = type.field;
    return _reduceAxis(
      axis: axis,
      keepDims: keepDims,
      target: target,
      initialValue: field.additiveIdentity,
      combine: field.add,
    );
  }

  /// Computes the arithmetic mean over the given [axis], or all elements if [axis] is null.
  Tensor<double> mean({
    int? axis,
    bool keepDims = false,
    Tensor<double>? target,
  }) {
    final count = axis == null
        ? length
        : layout.shape[axis < 0 ? axis + rank : axis];
    if (count == 0) throw StateError('Cannot compute mean of empty tensor');
    final sumTensor = sum(axis: axis, keepDims: keepDims);
    const resultType = DataType.float64;
    return sumTensor.unaryOperation<double>(
      (T value) => (value as num).toDouble() / count,
      type: resultType,
      target: target,
    );
  }

  /// Computes the minimum value over the given [axis], or all elements if [axis] is null.
  Tensor<T> min({int? axis, bool keepDims = false, Tensor<T>? target}) {
    if (length == 0) throw StateError('Cannot compute min of empty tensor');
    final cmp = type.comparator;
    return _reduceAxis(
      axis: axis,
      keepDims: keepDims,
      target: target,
      combine: (a, b) => cmp(a, b) <= 0 ? a : b,
    );
  }

  /// Computes the maximum value over the given [axis], or all elements if [axis] is null.
  Tensor<T> max({int? axis, bool keepDims = false, Tensor<T>? target}) {
    if (length == 0) throw StateError('Cannot compute max of empty tensor');
    final cmp = type.comparator;
    return _reduceAxis(
      axis: axis,
      keepDims: keepDims,
      target: target,
      combine: (a, b) => cmp(a, b) >= 0 ? a : b,
    );
  }

  /// Computes the variance over the given [axis].
  Tensor<double> var_({
    int? axis,
    bool keepDims = false,
    int ddof = 0,
    Tensor<double>? target,
  }) {
    final count = axis == null
        ? length
        : layout.shape[axis < 0 ? axis + rank : axis];
    final denom = count - ddof;
    if (denom <= 0) throw StateError('Degrees of freedom <= 0');
    final meanTensor = mean(axis: axis, keepDims: true);
    final thisDouble = unaryOperation<double>(
      (T value) => (value as num).toDouble(),
      type: DataType.float64,
    );
    final diff = thisDouble - meanTensor;
    final sq = diff * diff;
    final sumSq = sq.sum(axis: axis, keepDims: keepDims);
    return sumSq.unaryOperation<double>(
      (double value) => value / denom,
      type: DataType.float64,
      target: target,
    );
  }

  /// Computes the standard deviation over the given [axis].
  Tensor<double> std({
    int? axis,
    bool keepDims = false,
    int ddof = 0,
    Tensor<double>? target,
  }) {
    final varTensor = var_(axis: axis, keepDims: keepDims, ddof: ddof);
    return varTensor.unaryOperation<double>(
      math.sqrt,
      type: DataType.float64,
      target: target,
    );
  }

  /// Computes the $L_p$ norm of this tensor.
  double norm([num pNorm = 2]) {
    if (length == 0) return 0.0;
    if (pNorm == double.infinity) {
      var maxVal = 0.0;
      for (final val in values) {
        final absVal = type.field.norm(val);
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
      var sumSq = 0.0;
      for (final val in values) {
        final normVal = type.field.norm(val);
        sumSq += normVal * normVal;
      }
      return math.sqrt(sumSq);
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
      final outShape = keepDims ? List<int>.filled(rank, 1) : <int>[];
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
    final outShape = <int>[];
    for (var i = 0; i < rank; i++) {
      if (i == normalizedAxis) {
        if (keepDims) outShape.add(1);
      } else {
        outShape.add(layout.shape[i]);
      }
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
      for (var k = 1; k < axisLen; k++) {
        inKey[normalizedAxis] = k;
        final currentVal = getValue(inKey);
        final isBetter = findMin
            ? cmp(currentVal, bestVal) < 0
            : cmp(currentVal, bestVal) > 0;
        if (isBetter) {
          bestVal = currentVal;
          bestIdx = k;
        }
      }
      outTensor.setValue(key, bestIdx);
    }
    return outTensor;
  }
}
