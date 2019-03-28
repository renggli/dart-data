library data.type.impl.bigint;

import 'package:data/src/type/models/equality.dart';
import 'package:data/src/type/models/field.dart';
import 'package:data/src/type/models/order.dart';
import 'package:data/src/type/type.dart';

class BigIntDataType extends DataType<BigInt> {
  const BigIntDataType();

  @override
  String get name => 'bigInt';

  @override
  bool get isNullable => true;

  @override
  BigInt get nullValue => null;

  @override
  BigInt cast(Object value) {
    if (value == null || value is BigInt) {
      return value;
    } else if (value is num) {
      return BigInt.from(value);
    } else if (value is String) {
      return BigInt.tryParse(value) ?? super.cast(value);
    }
    return super.cast(value);
  }

  @override
  Equality<BigInt> get equality => const BigIntEquality();

  @override
  Order<BigInt> get order => const BigIntOrder();

  @override
  Field<BigInt> get field => const BigIntField();
}

class BigIntEquality extends Equality<BigInt> {
  const BigIntEquality();

  @override
  bool isClose(BigInt a, BigInt b, double epsilon) =>
      (a - b).abs() < BigInt.from(epsilon.ceil());
}

class BigIntOrder extends Order<BigInt> {
  const BigIntOrder();

  @override
  int compare(BigInt a, BigInt b) => a.compareTo(b);
}

class BigIntField extends Field<BigInt> {
  const BigIntField();

  @override
  BigInt get additiveIdentity => BigInt.zero;

  @override
  BigInt neg(BigInt a) => -a;

  @override
  BigInt add(BigInt a, BigInt b) => a + b;

  @override
  BigInt sub(BigInt a, BigInt b) => a - b;

  @override
  BigInt get multiplicativeIdentity => BigInt.one;

  @override
  BigInt inv(BigInt a) => BigInt.one ~/ a;

  @override
  BigInt mul(BigInt a, BigInt b) => a * b;

  @override
  BigInt scale(BigInt a, num f) => a * BigInt.from(f.round());

  @override
  BigInt div(BigInt a, BigInt b) => a ~/ b;

  @override
  BigInt mod(BigInt a, BigInt b) => a % b;

  @override
  BigInt pow(BigInt a, BigInt b) => a.pow(b.toInt());
}
