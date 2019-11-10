library data.type.impl.modulo;

import 'package:data/src/type/models/equality.dart';
import 'package:data/src/type/models/field.dart';
import 'package:data/src/type/models/order.dart';
import 'package:data/src/type/type.dart';
import 'package:more/printer.dart' show Printer;

class ModuloDataType<T> extends DataType<T> {
  final DataType<T> type;
  final T modulus;

  ModuloDataType(this.type, this.modulus) : field = ModuloField(type, modulus);

  @override
  String get name => '${type.name}/$modulus';

  @override
  bool get isNullable => type.isNullable;

  @override
  T get nullValue => type.nullValue;

  @override
  final Field<T> field;

  @override
  Order<T> get order => type.order;

  @override
  Equality<T> get equality => type.equality;

  @override
  T cast(Object value) => type.field.mod(type.cast(value), modulus);

  @override
  Printer get printer => type.printer;
}

class ModuloField<T> extends Field<T> {
  final DataType<T> type;
  final T modulus;

  ModuloField(this.type, this.modulus);

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
