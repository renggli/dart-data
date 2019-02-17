library data.type.impl.fraction;

import 'package:data/src/type/models/equality.dart';
import 'package:data/src/type/models/ordering.dart';
import 'package:data/src/type/models/system.dart';
import 'package:data/src/type/type.dart';
import 'package:more/number.dart';

class FractionDataType extends DataType<Fraction> {
  const FractionDataType();

  @override
  String get name => 'fraction';

  @override
  bool get isNullable => true;

  @override
  Fraction get nullValue => null;

  @override
  Fraction convert(Object value) {
    if (value == null || value is Fraction) {
      return value;
    } else if (value is int) {
      return Fraction(value);
    } else if (value is double) {
      return Fraction.fromDouble(value);
    } else if (value is String) {
      return Fraction.tryParse(value) ?? super.convert(value);
    }
    return super.convert(value);
  }

  @override
  Equality<Fraction> get equality => const FractionEquality();

  @override
  Ordering<Fraction> get ordering => const FractionOrdering();

  @override
  System<Fraction> get system => const FractionSystem();
}

class FractionEquality extends Equality<Fraction> {
  const FractionEquality();

  @override
  bool isClose(Fraction a, Fraction b, double epsilon) => a.closeTo(b, epsilon);
}

class FractionOrdering extends Ordering<Fraction> {
  const FractionOrdering();

  @override
  int compare(Fraction a, Fraction b) => a.compareTo(b);
}

class FractionSystem extends System<Fraction> {
  const FractionSystem();

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
  Fraction scale(Fraction a, num f) => a * Fraction(f);

  @override
  Fraction div(Fraction a, Fraction b) => a / b;

  @override
  Fraction mod(Fraction a, Fraction b) => unsupportedOperation('mod');

  @override
  Fraction pow(Fraction a, Fraction b) => unsupportedOperation('pow');
}
