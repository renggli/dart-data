import '../../../type.dart';
import '../layout.dart';
import '../tensor.dart';

extension OperationTensorExtension<T> on Tensor<T> {
  /// Element-wise unary operation evaluated into [target] or a new tensor.
  ///
  /// If [target] is provided, its layout shape must match [shape],
  /// otherwise an [ArgumentError] is thrown.
  Tensor<R> unaryOperation<R>(
    R Function(T value) function, {
    DataType<R>? type,
    Tensor<R>? target,
  }) {
    final resultType = type ?? DataType.fromType<R>();
    if (target == null) {
      final len = layout.length;
      final resultData = resultType.newList(len);
      if (layout.isContiguous) {
        final offset = layout.offset;
        final srcData = data;
        for (var i = 0; i < len; i++) {
          resultData[i] = function(srcData[offset + i]);
        }
      } else {
        var i = 0;
        for (final idx in layout.indices) {
          resultData[i++] = function(data[idx]);
        }
      }
      return Tensor<R>.internal(
        type: resultType,
        layout: Layout(shape: layout.shape),
        data: resultData,
      );
    } else {
      if (!_areShapesEqual(target.layout.shape, layout.shape)) {
        throw ArgumentError(
          'Target shape ${target.layout.shape} does not match shape ${layout.shape}',
        );
      }
      final len = layout.length;
      final targetData = target.data;
      final sharesMem = sharesMemory(targetData, data);
      final hasHazard =
          sharesMem &&
          (!layout.isContiguous ||
              !target.layout.isContiguous ||
              target.layout.offset != layout.offset ||
              hasOverlap(
                target.data,
                target.layout.offset,
                data,
                layout.offset,
                len,
              ));

      if (hasHazard) {
        final temp = unaryOperation<R>(function, type: type);
        final targetIter = target.layout.indices.iterator;
        final tempIter = temp.layout.indices.iterator;
        while (targetIter.moveNext() && tempIter.moveNext()) {
          targetData[targetIter.current] = temp.data[tempIter.current];
        }
        return target;
      }

      if (layout.isContiguous && target.layout.isContiguous) {
        final sOffset = layout.offset;
        final tOffset = target.layout.offset;
        final srcData = data;
        for (var i = 0; i < len; i++) {
          targetData[tOffset + i] = function(srcData[sOffset + i]);
        }
      } else {
        final sIter = layout.indices.iterator;
        final tIter = target.layout.indices.iterator;
        while (sIter.moveNext() && tIter.moveNext()) {
          targetData[tIter.current] = function(data[sIter.current]);
        }
      }
      return target;
    }
  }

  /// Element-wise binary operation evaluated into [target] or a new tensor.
  ///
  /// If [target] is provided, its layout shape must match the broadcasted
  /// output shape, otherwise an [ArgumentError] is thrown.
  Tensor<R> binaryOperation<O, R>(
    Tensor<O> other,
    R Function(T a, O b) function, {
    DataType<R>? type,
    Tensor<R>? target,
  }) {
    final thisData = data;
    final otherData = other.data;

    final isTargetMatching =
        target == null ||
        (target.layout.isContiguous &&
            _areShapesEqual(target.layout.shape, layout.shape));

    // Fast contiguous path without broadcasting
    if (layout.isContiguous &&
        other.layout.isContiguous &&
        _areShapesEqual(layout.shape, other.layout.shape) &&
        isTargetMatching) {
      final len = layout.length;
      if (target == null) {
        final resultType = type ?? DataType.fromType<R>();
        final resultData = resultType.newList(len);
        final s1 = layout.offset, s2 = other.layout.offset;
        for (var i = 0; i < len; i++) {
          resultData[i] = function(thisData[s1 + i], otherData[s2 + i]);
        }
        return Tensor<R>.internal(
          type: resultType,
          layout: Layout(shape: layout.shape),
          data: resultData,
        );
      } else if (target.layout.isContiguous &&
          (!sharesMemory(target.data, thisData) ||
              target.layout.offset == layout.offset) &&
          (!sharesMemory(target.data, otherData) ||
              target.layout.offset == other.layout.offset)) {
        final targetData = target.data;
        final s1 = layout.offset,
            s2 = other.layout.offset,
            t = target.layout.offset;
        for (var i = 0; i < len; i++) {
          targetData[t + i] = function(thisData[s1 + i], otherData[s2 + i]);
        }
        return target;
      }
    }

    final (thisLayout, otherLayout) = layout.broadcast(other.layout);

    if (target == null) {
      final resultType = type ?? DataType.fromType<R>();
      final resultData = resultType.newList(thisLayout.length);
      final thisIter = thisLayout.indices.iterator;
      final otherIter = otherLayout.indices.iterator;
      for (
        var i = 0;
        i < thisLayout.length && thisIter.moveNext() && otherIter.moveNext();
        i++
      ) {
        resultData[i] = function(
          thisData[thisIter.current],
          otherData[otherIter.current],
        );
      }
      return Tensor<R>.internal(
        type: resultType,
        layout: Layout(shape: thisLayout.shape),
        data: resultData,
      );
    } else {
      final expectedShape = thisLayout.shape;
      if (!_areShapesEqual(target.layout.shape, expectedShape)) {
        throw ArgumentError(
          'Target shape ${target.layout.shape} does not match broadcasted shape $expectedShape',
        );
      }

      bool hasHazardFor(Tensor<dynamic> op, Layout opLayout) {
        if (!sharesMemory(target.data, op.data)) return false;
        if (target.layout.isContiguous &&
            opLayout.isContiguous &&
            target.layout.offset == opLayout.offset &&
            _areShapesEqual(target.layout.strides, opLayout.strides)) {
          return false;
        }
        return true;
      }

      final hasHazard =
          hasHazardFor(this, thisLayout) || hasHazardFor(other, otherLayout);

      if (hasHazard) {
        final temp = binaryOperation<O, R>(other, function, type: type);
        final targetData = target.data;
        final targetIter = target.layout.indices.iterator;
        final tempIter = temp.layout.indices.iterator;
        while (targetIter.moveNext() && tempIter.moveNext()) {
          targetData[targetIter.current] = temp.data[tempIter.current];
        }
        return target;
      }

      final thisIter = thisLayout.indices.iterator;
      final otherIter = otherLayout.indices.iterator;
      final targetData = target.data;
      final targetIter = target.layout.indices.iterator;
      while (targetIter.moveNext() &&
          thisIter.moveNext() &&
          otherIter.moveNext()) {
        targetData[targetIter.current] = function(
          thisData[thisIter.current],
          otherData[otherIter.current],
        );
      }
      return target;
    }
  }

  // Eager arithmetic operators
  Tensor<T> operator -() => unaryOperation<T>(type.field.neg);
  Tensor<T> operator +(Tensor<T> other) =>
      binaryOperation<T, T>(other, type.field.add);
  Tensor<T> operator -(Tensor<T> other) =>
      binaryOperation<T, T>(other, type.field.sub);
  Tensor<T> operator *(Tensor<T> other) =>
      binaryOperation<T, T>(other, type.field.mul);
  Tensor<T> operator /(Tensor<T> other) =>
      binaryOperation<T, T>(other, type.field.div);

  /// Computes the element-wise absolute value.
  Tensor<T> abs() => unaryOperation<T>(type.field.abs);

  /// Computes the element-wise square root.
  Tensor<T> sqrt() => unaryOperation<T>(type.field.sqrt);

  /// Computes the element-wise exponential.
  Tensor<T> exp() => unaryOperation<T>(type.field.exp);

  /// Computes the element-wise natural logarithm.
  Tensor<T> log() => unaryOperation<T>(type.field.log);

  // Comparisons
  Tensor<bool> operator <(Tensor<T> other) =>
      binaryOperation<T, bool>(other, (a, b) => type.comparator(a, b) < 0);
  Tensor<bool> operator <=(Tensor<T> other) =>
      binaryOperation<T, bool>(other, (a, b) => type.comparator(a, b) <= 0);
  Tensor<bool> operator >(Tensor<T> other) =>
      binaryOperation<T, bool>(other, (a, b) => type.comparator(a, b) > 0);
  Tensor<bool> operator >=(Tensor<T> other) =>
      binaryOperation<T, bool>(other, (a, b) => type.comparator(a, b) >= 0);
  Tensor<bool> equalTo(Tensor<T> other) =>
      binaryOperation<T, bool>(other, (a, b) => type.equality.isEqual(a, b));
}

extension LogicalTensorExtension on Tensor<bool> {
  Tensor<bool> operator ~() => unaryOperation<bool>((a) => !a);
  Tensor<bool> operator &(Tensor<bool> other) =>
      binaryOperation<bool, bool>(other, (a, b) => a && b);
  Tensor<bool> operator |(Tensor<bool> other) =>
      binaryOperation<bool, bool>(other, (a, b) => a || b);
}

bool _areShapesEqual(List<int> a, List<int> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
