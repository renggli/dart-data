import 'package:more/functional.dart';

import '../../type/type.dart';
import '../tensor.dart';
import '../utils/broadcast.dart';
import '../utils/layout.dart';

extension ElementwiseOperationsOnTensor<T> on Tensor<T> {
  Tensor<T> operator +(Tensor<T> other) =>
      binaryOperation<T, T, T>(this, other, type.field.add);

  Tensor<T> operator -(Tensor<T> other) =>
      binaryOperation<T, T, T>(this, other, type.field.sub);

  Tensor<T> operator *(Tensor<T> other) =>
      binaryOperation<T, T, T>(this, other, type.field.mul);

  Tensor<T> operator /(Tensor<T> other) =>
      binaryOperation<T, T, T>(this, other, type.field.div);

  Tensor<T> operator %(Tensor<T> other) =>
      binaryOperation<T, T, T>(this, other, type.field.mod);

  Tensor<T> operator ~/(Tensor<T> other) =>
      binaryOperation<T, T, T>(this, other, type.field.division);
}

Tensor<R> binaryOperation<T0, T1, R>(
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
