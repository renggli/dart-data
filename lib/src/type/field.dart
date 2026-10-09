import 'dart:math' as math;

import 'package:more/number.dart' show Complex, Fraction;

/// Encapsulates a mathematical field with algebraic operations.
abstract class Field<T> {
  const new();

  /// The additive neutral element: `0`.
  T get additiveIdentity;

  /// Computes the additive inverse: `-a`.
  T neg(T a) => sub(additiveIdentity, a);

  /// Computes addition: `a + b`.
  T add(T a, T b);

  /// Computes subtraction: `a - b`.
  T sub(T a, T b);

  /// The multiplicative neutral element: `1`.
  T get multiplicativeIdentity;

  /// Computes multiplicative inverse: `1 / a`.
  T inv(T a) => div(multiplicativeIdentity, a);

  /// Computes multiplication: `a * b`.
  T mul(T a, T b);

  /// Computes scalar scaling: `a * factor`.
  T scale(T a, num factor);

  /// Computes division: `a / b`.
  T div(T a, T b);

  /// Computes power: `base ^ exponent`.
  T pow(T base, T exponent);

  /// Computes absolute value: `|a|`.
  T abs(T a) => unsupportedOperation('abs');

  /// Computes Euclidean norm: `||a||`.
  double norm(T a) => throw UnsupportedError('norm is not supported for $T');

  /// Computes square root: `sqrt(a)`.
  T sqrt(T a) => unsupportedOperation('sqrt');

  /// Computes exponential: `exp(a)`.
  T exp(T a) => unsupportedOperation('exp');

  /// Computes natural logarithm: `ln(a)`.
  T log(T a) => unsupportedOperation('log');

  /// Computes complex conjugate: `a*` (identity for real types).
  T conjugate(T a) => a;

  /// Throws when an operation is unsupported.
  T unsupportedOperation(String operation) =>
      throw UnsupportedError('$operation is not supported for $T.');
}

/// Float field for double precision operations.
class FloatField extends Field<double> {
  const new();

  @override
  double get additiveIdentity => 0.0;

  @override
  double neg(double a) => -a;

  @override
  double add(double a, double b) => a + b;

  @override
  double sub(double a, double b) => a - b;

  @override
  double get multiplicativeIdentity => 1.0;

  @override
  double inv(double a) => 1.0 / a;

  @override
  double mul(double a, double b) => a * b;

  @override
  double scale(double a, num factor) => a * factor;

  @override
  double div(double a, double b) => a / b;

  @override
  double pow(double base, double exponent) =>
      math.pow(base, exponent).toDouble();

  @override
  double abs(double a) => a.abs();

  @override
  double norm(double a) => a.abs();

  @override
  double sqrt(double a) => math.sqrt(a);

  @override
  double exp(double a) => math.exp(a);

  @override
  double log(double a) => math.log(a);

  @override
  double conjugate(double a) => a;
}

/// Integer field.
class IntegerField extends Field<int> {
  const new();

  @override
  int get additiveIdentity => 0;

  @override
  int neg(int a) => -a;

  @override
  int add(int a, int b) => a + b;

  @override
  int sub(int a, int b) => a - b;

  @override
  int get multiplicativeIdentity => 1;

  @override
  int inv(int a) => 1 ~/ a;

  @override
  int mul(int a, int b) => a * b;

  @override
  int scale(int a, num factor) => (a * factor).round();

  @override
  int div(int a, int b) => a ~/ b;

  @override
  int pow(int base, int exponent) => math.pow(base, exponent).truncate();

  @override
  int abs(int a) => a.abs();

  @override
  double norm(int a) => a.abs().toDouble();

  @override
  int sqrt(int a) => math.sqrt(a).truncate();

  @override
  int exp(int a) => math.exp(a).truncate();

  @override
  int log(int a) => math.log(a).truncate();

  @override
  int conjugate(int a) => a;
}

/// Complex field.
class ComplexField extends Field<Complex> {
  const new();

  @override
  Complex get additiveIdentity => Complex.zero;

  @override
  Complex neg(Complex a) => -a;

  @override
  Complex add(Complex a, Complex b) => a + b;

  @override
  Complex sub(Complex a, Complex b) => a - b;

  @override
  Complex get multiplicativeIdentity => Complex.one;

  @override
  Complex inv(Complex a) => a.reciprocal();

  @override
  Complex mul(Complex a, Complex b) => a * b;

  @override
  Complex scale(Complex a, num factor) => a * factor;

  @override
  Complex div(Complex a, Complex b) => a / b;

  @override
  Complex pow(Complex base, Complex exponent) => base.pow(exponent);

  @override
  Complex abs(Complex a) => Complex(a.abs());

  @override
  double norm(Complex a) => a.abs();

  @override
  Complex sqrt(Complex a) => a.sqrt();

  @override
  Complex exp(Complex a) => a.exp();

  @override
  Complex log(Complex a) => a.log();

  @override
  Complex conjugate(Complex a) => a.conjugate();
}

/// Fraction field.
class FractionField extends Field<Fraction> {
  const new();

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
  Fraction scale(Fraction a, num factor) => a * factor;

  @override
  Fraction div(Fraction a, Fraction b) => a / b;

  @override
  Fraction pow(Fraction base, Fraction exponent) => base.pow(exponent.toInt());

  @override
  Fraction abs(Fraction a) => a.abs();

  @override
  double norm(Fraction a) => a.abs().toDouble();

  @override
  Fraction sqrt(Fraction a) => Fraction.fromDouble(math.sqrt(a.toDouble()));

  @override
  Fraction exp(Fraction a) => Fraction.fromDouble(math.exp(a.toDouble()));

  @override
  Fraction log(Fraction a) => Fraction.fromDouble(math.log(a.toDouble()));

  @override
  Fraction conjugate(Fraction a) => a;
}

/// BigInt field with correct rounding order on scale.
class BigIntField extends Field<BigInt> {
  const new();

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
  BigInt scale(BigInt a, num factor) {
    if (factor is int) return a * BigInt.from(factor);
    final frac = Fraction.fromDouble(factor.toDouble());
    return (a * BigInt.from(frac.numerator)) ~/ BigInt.from(frac.denominator);
  }

  @override
  BigInt div(BigInt a, BigInt b) => a ~/ b;

  @override
  BigInt pow(BigInt base, BigInt exponent) => base.pow(exponent.toInt());

  @override
  BigInt abs(BigInt a) => a.abs();

  @override
  double norm(BigInt a) => a.abs().toDouble();

  @override
  BigInt sqrt(BigInt a) {
    if (a < BigInt.zero) throw ArgumentError.value(a, 'a', 'Negative value');
    if (a == BigInt.zero) return BigInt.zero;
    var x0 = a >> 1;
    if (x0 > BigInt.zero) {
      var x1 = (x0 + a ~/ x0) >> 1;
      while (x1 < x0) {
        x0 = x1;
        x1 = (x0 + a ~/ x0) >> 1;
      }
      return x0;
    }
    return BigInt.one;
  }

  @override
  BigInt exp(BigInt a) => BigInt.from(math.exp(a.toDouble()).round());

  @override
  BigInt log(BigInt a) => BigInt.from(math.log(a.toDouble()).round());

  @override
  BigInt conjugate(BigInt a) => a;
}
