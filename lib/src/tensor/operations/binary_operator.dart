import 'package:more/functional.dart';

import '../../../type.dart';
import '../tensor.dart';
import '../utils/broadcast.dart';
import '../utils/layout.dart';

extension ElementwiseOperationOnTensor<T> on Tensor<T> {
  /// Performs a unary element-wise operation `function` on this tensor and
  /// returns a new tensor with the same shape.
  Tensor<R> unary<R>(Map1<T, R> function, {DataType<R>? type}) =>
      Tensor<R>.fromIterable(values.map(function),
          shape: layout.shape, type: type ?? DataType.fromType<R>());

  /// Performs a binary element-wise operation `function` on this tensor and
  /// `other` and returns a new tensor with the combined broadcast shape.
  Tensor<R> binary<O, R>(Tensor<O> other, Map2<T, O, R> function,
      {DataType<R>? type}) {
    final (layout0, layout1) = broadcast(layout, other.layout);
    final (iterable0, iterable1) = (layout0.indices, layout1.indices);
    final (iterator0, iterator1) = (iterable0.iterator, iterable1.iterator);
    final type_ = type ?? DataType.fromType<R>();
    final data_ = type_.newList(layout0.length);
    for (var i = 0; i < layout0.length; i++) {
      iterator0.moveNext();
      iterator1.moveNext();
      data_[i] =
          function(data[iterator0.current], other.data[iterator1.current]);
    }
    assert(!iterator0.moveNext(), 'Iterator 1 has not completed');
    assert(!iterator1.moveNext(), 'Iterator 2 has not completed');
    return Tensor<R>.internal(
        type: type_, layout: Layout(shape: layout0.shape), data: data_);
  }
}

extension ElementwiseFieldOperationOnTensor<T> on Tensor<T> {
  Tensor<T> operator -() => unary<T>(type.field.neg);

  Tensor<T> operator +(Tensor<T> other) => binary<T, T>(other, type.field.add);

  Tensor<T> operator -(Tensor<T> other) => binary<T, T>(other, type.field.sub);

  Tensor<T> operator *(Tensor<T> other) => binary<T, T>(other, type.field.mul);

  Tensor<T> operator /(Tensor<T> other) => binary<T, T>(other, type.field.div);

  Tensor<T> operator %(Tensor<T> other) => binary<T, T>(other, type.field.mod);

  Tensor<T> operator ~/(Tensor<T> other) =>
      binary<T, T>(other, type.field.division);
}

extension ElementwiseComparatorOperationOnTensor<T> on Tensor<T> {
  Tensor<bool> operator <(Tensor<T> other) =>
      binary<T, bool>(other, type.comparator.lessThan);

  Tensor<bool> operator <=(Tensor<T> other) =>
      binary<T, bool>(other, type.comparator.lessThanOrEqualTo);

  Tensor<bool> operator >(Tensor<T> other) =>
      binary<T, bool>(other, type.comparator.greaterThan);

  Tensor<bool> operator >=(Tensor<T> other) =>
      binary<T, bool>(other, type.comparator.greaterThanOrEqualTo);

  Tensor<bool> equalTo(Tensor<T> other) =>
      binary<T, bool>(other, type.comparator.equalTo);

  Tensor<bool> notEqualTo(Tensor<T> other) =>
      binary<T, bool>(other, type.comparator.notEqualTo);
}

extension ElementwiseBooleanOperationOnTensor on Tensor<bool> {
  Tensor<bool> operator ~() => unary<bool>((a) => !a);

  Tensor<bool> operator &(Tensor<bool> other) =>
      binary<bool, bool>(other, (a, b) => a && b);

  Tensor<bool> operator |(Tensor<bool> other) =>
      binary<bool, bool>(other, (a, b) => a || b);
}
