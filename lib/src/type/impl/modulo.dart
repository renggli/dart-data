import 'package:more/printer.dart' show Printer;

import '../models/equality.dart';
import '../models/field.dart';
import '../type.dart';

class ModuloDataType<T> extends DataType<T> {
  ModuloDataType(this.delegate, this.modulus)
      : field = ModuloField<T>(delegate, modulus),
        equality = ModuloEquality<T>(delegate, modulus);

  final DataType<T> delegate;
  final T modulus;

  @override
  String get name => '${delegate.name}/$modulus';

  @override
  T get defaultValue => delegate.defaultValue;

  @override
  final Field<T> field;

  @override
  final Equality<T> equality;

  @override
  int comparator(T a, T b) => delegate.comparator(
        delegate.field.mod(a, modulus),
        delegate.field.mod(b, modulus),
      );

  @override
  T cast(dynamic value) => delegate.field.mod(delegate.cast(value), modulus);

  @override
  Printer<T> get printer => delegate.printer;
}

class ModuloField<T> extends Field<T> {
  const ModuloField(this.type, this.modulus);

  final DataType<T> type;
  final T modulus;

  @override
  T get additiveIdentity => type.field.additiveIdentity;

  @override
  T neg(T a) => type.field.add(type.field.neg(a), modulus);

  @override
  T add(T a, T b) => type.field.mod(type.field.add(a, b), modulus);

  @override
  T sub(T a, T b) => type.field.mod(type.field.sub(a, b), modulus);

  @override
  T get multiplicativeIdentity => type.field.multiplicativeIdentity;

  @override
  T inv(T a) => type.field.modInverse(a, modulus);

  @override
  T mul(T a, T b) => type.field.mod(type.field.mul(a, b), modulus);

  @override
  T scale(T a, num f) => type.field.mod(type.field.scale(a, f), modulus);

  @override
  T div(T a, T b) => type.field.mod(type.field.mul(a, inv(b)), modulus);

  @override
  T mod(T a, T b) => type.field.mod(type.field.mod(a, b), modulus);

  @override
  T division(T a, T b) => unsupportedOperation('division');

  @override
  T remainder(T a, T b) => unsupportedOperation('remainder');

  @override
  T pow(T base, T exponent) => type.field.modPow(base, exponent, modulus);

  @override
  T modPow(T base, T exponent, T modulus) => unsupportedOperation('modPow');

  @override
  T modInverse(T base, T modulus) => unsupportedOperation('modInverse');

  @override
  T gcd(T a, T b) => unsupportedOperation('gcd');
}

class ModuloEquality<T> extends Equality<T> {
  const ModuloEquality(this.type, this.modulus);

  final DataType<T> type;
  final T modulus;

  @override
  bool isEqual(T a, T b) => type.equality.isEqual(
        type.field.mod(a, modulus),
        type.field.mod(b, modulus),
      );

  @override
  bool isClose(T a, T b, double epsilon) => type.equality.isClose(
        type.field.mod(a, modulus),
        type.field.mod(b, modulus),
        epsilon,
      );

  @override
  int hash(T a) => type.equality.hash(type.field.mod(a, modulus));
}
