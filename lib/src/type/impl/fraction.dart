import 'package:more/number.dart';

import '../models/equality.dart';
import '../models/field.dart';
import '../type.dart';

class FractionDataType extends DataType<Fraction> {
  const FractionDataType();

  @override
  String get name => 'fraction';

  @override
  Fraction get defaultValue => Fraction.zero;

  @override
  int comparator(Fraction a, Fraction b) => a.compareTo(b);

  @override
  Fraction cast(dynamic value) {
    if (value is Fraction) {
      return value;
    } else if (value is int) {
      return Fraction(value);
    } else if (value is double) {
      return Fraction.fromDouble(value);
    } else if (value is BigInt) {
      return Fraction(value.toInt());
    } else if (value is String) {
      return Fraction.tryParse(value) ?? super.cast(value);
    }
    return super.cast(value);
  }

  @override
  Equality<Fraction> get equality => const FractionEquality();

  @override
  Field<Fraction> get field => const FractionField();
}

class FractionEquality extends NaturalEquality<Fraction> {
  const FractionEquality();

  @override
  bool isGreaterThan(Fraction a, Fraction b) => a > b;

  @override
  bool isGreaterThanOrEqual(Fraction a, Fraction b) => a >= b;

  @override
  bool isLessThan(Fraction a, Fraction b) => a < b;

  @override
  bool isLessThanOrEqual(Fraction a, Fraction b) => a <= b;

  @override
  bool isClose(Fraction a, Fraction b, double epsilon) => a.closeTo(b, epsilon);
}

class FractionField extends Field<Fraction> {
  const FractionField();

  @override
  Fraction get additiveIdentity => Fraction.zero;

  @override
  Fraction neg(Fraction a) => -a;

  @override
  Fraction add(Fraction a, Fraction b) => a + b;

  @override
  Fraction sub(Fraction a, Fraction b) => a - b;

  @override
  Fraction get multiplicativeIdentity => Fraction.one;

  @override
  Fraction inv(Fraction a) => a.reciprocal();

  @override
  Fraction mul(Fraction a, Fraction b) => a * b;

  @override
  Fraction scale(Fraction a, num f) => a * f;

  @override
  Fraction div(Fraction a, Fraction b) => a / b;

  @override
  Fraction mod(Fraction a, Fraction b) => unsupportedOperation('mod');

  @override
  Fraction division(Fraction a, Fraction b) => unsupportedOperation('division');

  @override
  Fraction remainder(Fraction a, Fraction b) =>
      unsupportedOperation('remainder');

  @override
  Fraction pow(Fraction base, Fraction exponent) => base.pow(exponent.toInt());

  @override
  Fraction modPow(Fraction base, Fraction exponent, Fraction modulus) =>
      unsupportedOperation('modPow');

  @override
  Fraction modInverse(Fraction base, Fraction modulus) =>
      unsupportedOperation('modInverse');

  @override
  Fraction gcd(Fraction a, Fraction b) => unsupportedOperation('gcd');
}
