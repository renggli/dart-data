import 'package:more/functional.dart';

import '../../../type.dart';
import '../tensor.dart';
import '../utils/broadcast.dart';
import '../utils/errors.dart';
import '../utils/layout.dart';

extension OperationTensorExtension<T> on Tensor<T> {
  /// Performs an unary element-wise operation `function` on this tensor and
  /// stores the result into `target` or (if missing) into a newly created one.
  Tensor<R> unaryOperation<R>(Map1<T, R> function,
      {DataType<R>? type, Tensor<R>? target}) {
    if (target == null) {
      // Create a new tensor.
      return Tensor<R>.fromIterable(values.map(function),
          shape: layout.shape, type: type ?? DataType.fromType<R>());
    } else if (target == this) {
      // Perform the operation in-place.
      final targetData = target.data;
      for (final i in layout.indices) {
        targetData[i] = function(data[i]);
      }
      return target;
    } else {
      // Perform the operation into another one.
      final targetLayout = target.layout;
      LayoutError.checkEqualShape(layout, targetLayout, 'target');
      final sourceData = data, sourceIterator = layout.indices.iterator;
      final targetData = target.data,
          targetIterator = targetLayout.indices.iterator;
      while (targetIterator.moveNext() && sourceIterator.moveNext()) {
        targetData[targetIterator.current] =
            function(sourceData[sourceIterator.current]);
      }
      return target;
    }
  }

  /// Performs a binary element-wise operation `function` on this tensor and
  /// `other` and stores the result into `target` or (if missing) into a newly
  /// created one.
  Tensor<R> binaryOperation<O, R>(Tensor<O> other, Map2<T, O, R> function,
      {DataType<R>? type, Tensor<R>? target}) {
    final (thisLayout, otherLayout) = broadcast(layout, other.layout);
    final thisIterator = thisLayout.indices.iterator;
    final otherIterator = otherLayout.indices.iterator;
    final thisData = data, otherData = other.data;
    if (target == null) {
      // Create a new tensor.
      final resultType = type ?? DataType.fromType<R>();
      final resultData = resultType.newList(thisLayout.length);
      for (var i = 0;
          i < thisLayout.length &&
              thisIterator.moveNext() &&
              otherIterator.moveNext();
          i++) {
        resultData[i] = function(
          thisData[thisIterator.current],
          otherData[otherIterator.current],
        );
      }
      return Tensor<R>.internal(
        type: resultType,
        layout: Layout(shape: thisLayout.shape),
        data: resultData,
      );
    } else {
      // Perform the operation into another one (possibly in-place).
      LayoutError.checkEqualShape(layout, target.layout, 'target');
      final targetData = target.data;
      final targetIterator = target.layout.indices.iterator;
      while (targetIterator.moveNext() &&
          thisIterator.moveNext() &&
          otherIterator.moveNext()) {
        targetData[targetIterator.current] = function(
          thisData[thisIterator.current],
          otherData[otherIterator.current],
        );
      }
      return target;
    }
  }
}

extension MathTensorExtension<T> on Tensor<T> {
  Tensor<T> operator -() => unaryOperation<T>(type.field.neg);

  Tensor<T> operator +(Tensor<T> other) =>
      binaryOperation<T, T>(other, type.field.add);

  Tensor<T> operator -(Tensor<T> other) =>
      binaryOperation<T, T>(other, type.field.sub);

  Tensor<T> operator *(Tensor<T> other) =>
      binaryOperation<T, T>(other, type.field.mul);

  Tensor<T> operator /(Tensor<T> other) =>
      binaryOperation<T, T>(other, type.field.div);

  Tensor<T> operator %(Tensor<T> other) =>
      binaryOperation<T, T>(other, type.field.mod);

  Tensor<T> operator ~/(Tensor<T> other) =>
      binaryOperation<T, T>(other, type.field.division);
}

extension ComparisonTensorExtension<T> on Tensor<T> {
  Tensor<bool> operator <(Tensor<T> other) =>
      binaryOperation<T, bool>(other, type.comparator.lessThan);

  Tensor<bool> operator <=(Tensor<T> other) =>
      binaryOperation<T, bool>(other, type.comparator.lessThanOrEqualTo);

  Tensor<bool> operator >(Tensor<T> other) =>
      binaryOperation<T, bool>(other, type.comparator.greaterThan);

  Tensor<bool> operator >=(Tensor<T> other) =>
      binaryOperation<T, bool>(other, type.comparator.greaterThanOrEqualTo);

  Tensor<bool> equalTo(Tensor<T> other) =>
      binaryOperation<T, bool>(other, type.comparator.equalTo);

  Tensor<bool> notEqualTo(Tensor<T> other) =>
      binaryOperation<T, bool>(other, type.comparator.notEqualTo);
}

extension LogicalTensorExtension on Tensor<bool> {
  Tensor<bool> operator ~() => unaryOperation<bool>((a) => !a);

  Tensor<bool> operator &(Tensor<bool> other) =>
      binaryOperation<bool, bool>(other, (a, b) => a && b);

  Tensor<bool> operator |(Tensor<bool> other) =>
      binaryOperation<bool, bool>(other, (a, b) => a || b);
}
