import 'package:more/functional.dart';

import '../../../type.dart';
import '../tensor.dart';
import '../utils/broadcast.dart';
import '../utils/layout.dart';

extension ElementwiseFieldOperationOnTensor<T> on Tensor<T> {
  Tensor<T> operator -() => _unaryOperation<T, T>(this, type.field.neg);

  Tensor<T> operator +(Tensor<T> other) =>
      _binaryOperation<T, T, T>(this, other, type.field.add);

  Tensor<T> operator -(Tensor<T> other) =>
      _binaryOperation<T, T, T>(this, other, type.field.sub);

  Tensor<T> operator *(Tensor<T> other) =>
      _binaryOperation<T, T, T>(this, other, type.field.mul);

  Tensor<T> operator /(Tensor<T> other) =>
      _binaryOperation<T, T, T>(this, other, type.field.div);

  Tensor<T> operator %(Tensor<T> other) =>
      _binaryOperation<T, T, T>(this, other, type.field.mod);

  Tensor<T> operator ~/(Tensor<T> other) =>
      _binaryOperation<T, T, T>(this, other, type.field.division);
}

extension ElementwiseComparatorOperationOnTensor<T> on Tensor<T> {
  Tensor<bool> operator <(Tensor<T> other) =>
      _binaryOperation<T, T, bool>(this, other, type.comparator.lessThan);

  Tensor<bool> operator <=(Tensor<T> other) => _binaryOperation<T, T, bool>(
      this, other, type.comparator.lessThanOrEqualTo);

  Tensor<bool> operator >(Tensor<T> other) =>
      _binaryOperation<T, T, bool>(this, other, type.comparator.greaterThan);

  Tensor<bool> operator >=(Tensor<T> other) => _binaryOperation<T, T, bool>(
      this, other, type.comparator.greaterThanOrEqualTo);

  Tensor<bool> equalTo(Tensor<T> other) =>
      _binaryOperation<T, T, bool>(this, other, type.comparator.equalTo);

  Tensor<bool> notEqualTo(Tensor<T> other) =>
      _binaryOperation<T, T, bool>(this, other, type.comparator.notEqualTo);
}

extension ElementwiseBooleanOperationOnTensor on Tensor<bool> {
  Tensor<bool> operator ~() => _unaryOperation<bool, bool>(this, (a) => !a);

  Tensor<bool> operator &(Tensor<bool> other) =>
      _binaryOperation<bool, bool, bool>(this, other, (a, b) => a && b);

  Tensor<bool> operator |(Tensor<bool> other) =>
      _binaryOperation<bool, bool, bool>(this, other, (a, b) => a || b);
}

Tensor<R> _unaryOperation<T0, R>(Tensor<T0> t0, Map1<T0, R> function,
        {DataType<R>? type}) =>
    Tensor<R>.fromIterable(t0.values.map(function),
        shape: t0.layout.shape, type: type ?? DataType.fromType<R>());

Tensor<R> _binaryOperation<T0, T1, R>(
    Tensor<T0> t0, Tensor<T1> t1, Map2<T0, T1, R> function,
    {DataType<R>? type}) {
  final (layout0, layout1) = broadcast(t0.layout, t1.layout);
  final (iterable0, iterable1) = (layout0.indices, layout1.indices);
  final (iterator0, iterator1) = (iterable0.iterator, iterable1.iterator);
  final type_ = type ?? DataType.fromType<R>();
  final data_ = type_.newList(layout0.length);
  for (var i = 0; i < layout0.length; i++) {
    iterator0.moveNext();
    iterator1.moveNext();
    data_[i] = function(t0.data[iterator0.current], t1.data[iterator1.current]);
  }
  assert(!iterator0.moveNext(), 'Iterator 1 has not completed');
  assert(!iterator1.moveNext(), 'Iterator 2 has not completed');
  return Tensor<R>.internal(
      type: type_, layout: Layout(shape: layout0.shape), data: data_);
}
