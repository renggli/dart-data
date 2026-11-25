import 'package:more/number.dart' show Complex;

import '../type/data_type.dart';
import 'impl/compressed_polynomial.dart';
import 'impl/dense_polynomial.dart';
import 'polynomial.dart';

/// Rational function `R(x) = P(x) / Q(x)` representing the ratio of two
/// [Polynomial] instances.
///
/// Conceptually, a rational function is an algebraic fraction where both
/// numerator and denominator are polynomials (such as `(x + 1) / (x^2 - 4)`).
/// Formally, this models elements of the field of rational functions
/// `K(x) = Frac(K[x])`, supporting formal algebra, differentiation,
/// canonical simplification via GCD reduction, and evaluation.
///
/// ```dart
/// final num = Polynomial.fromCoefficients([1.0, 1.0]); // x + 1
/// final den = Polynomial.fromCoefficients([2.0, 1.0]); // x + 2
/// final r = RationalFunction(num, den);
/// final y = r.evaluateDouble(0.0); // 1.0 / 2.0 = 0.5
/// ```
class RationalFunction<T> {
  /// Constructs a rational function with [numerator] and [denominator].
  ///
  /// Throws an [ArgumentError] if [numerator] and [denominator] have different
  /// [DataType]s, or an [UnsupportedError] if [denominator] is zero.
  new(this.numerator, this.denominator) : type = numerator.type {
    if (numerator.type != denominator.type) {
      throw ArgumentError(
        'Numerator and denominator must have the same DataType: '
        '${numerator.type} != ${denominator.type}.',
      );
    }
    if (denominator.isZero) {
      throw UnsupportedError('Denominator cannot be zero polynomial.');
    }
  }

  /// Constructs a rational function and simplifies it by cancelling `gcd(P, Q)`.
  factory simplified(Polynomial<T> numerator, Polynomial<T> denominator) =>
      RationalFunction(numerator, denominator).simplify();

  /// Constructs a rational function from a single [polynomial] with denominator
  /// `1`, preserving sparse compressed representation when applicable.
  factory fromPolynomial(Polynomial<T> polynomial) =>
      RationalFunction(polynomial, _oneLike(polynomial));

  /// The numerator polynomial `P(x)`.
  final Polynomial<T> numerator;

  /// The denominator polynomial `Q(x)`.
  final Polynomial<T> denominator;

  /// The data type of the polynomial coefficients.
  final DataType<T> type;

  /// Cached canonical simplified rational function.
  late final RationalFunction<T> _canonical = simplify();

  /// Whether this rational function is identically zero (`numerator.isZero`).
  bool get isZero => numerator.isZero;

  /// Whether this rational function reduces to a polynomial
  /// (`denominator.degree == 0`).
  bool get isPolynomial => denominator.degree == 0;

  /// Simplifies this rational function by cancelling `gcd(P, Q)` and
  /// normalizing the denominator to monic form when invertible.
  RationalFunction<T> simplify() {
    final preferCompressed =
        numerator is CompressedPolynomial<T> ||
        denominator is CompressedPolynomial<T>;
    if (numerator.isZero) {
      final onePoly = _oneLikeType(type, compressed: preferCompressed);
      return denominator == onePoly
          ? this
          : RationalFunction(numerator, onePoly);
    }

    final g = numerator.gcd(denominator);
    var num = numerator;
    var den = denominator;
    if (g.degree > 0) {
      num = num / g;
      den = den / g;
    }

    final lead = den.leadingCoefficient;
    final field = type.field;
    final one = field.multiplicativeIdentity;
    if (lead != one && lead != field.additiveIdentity) {
      final inv = field.div(one, lead);
      if (inv != field.additiveIdentity) {
        den = den.monic();
        num = _divideByScalar(num, lead);
      }
    }

    if (num == numerator && den == denominator) {
      return this;
    }
    return RationalFunction(num, den);
  }

  /// Evaluates `R(x) = P(x) / Q(x)` at [x].
  ///
  /// Throws an [UnsupportedError] if `Q(x) == 0`.
  T evaluate(T x) {
    final numVal = numerator.evaluate(x);
    final denVal = denominator.evaluate(x);
    final field = type.field;
    if (denVal == field.additiveIdentity) {
      throw UnsupportedError('Evaluation resulted in division by zero.');
    }
    return field.div(numVal, denVal);
  }

  /// Evaluates `R(x)` for a numeric value [x] as a `double`.
  ///
  /// Throws an [UnsupportedError] if `Q(x) == 0`.
  double evaluateDouble(num x) {
    final numVal = numerator.evaluateDouble(x);
    final denVal = denominator.evaluateDouble(x);
    if (denVal == 0.0) {
      throw UnsupportedError('Evaluation resulted in division by zero.');
    }
    return numVal / denVal;
  }

  /// Evaluates `R(z) = P(z) / Q(z)` for a complex argument [z].
  ///
  /// Throws an [UnsupportedError] if `Q(z) == 0`.
  Complex evaluateComplex(Complex z) {
    final numVal = numerator.evaluateComplex(z);
    final denVal = denominator.evaluateComplex(z);
    if (denVal == Complex.zero) {
      throw UnsupportedError('Evaluation resulted in division by zero.');
    }
    return numVal / denVal;
  }

  /// Scales this rational function by [scalar].
  RationalFunction<T> scale(T scalar) {
    if (scalar == type.field.additiveIdentity) {
      final zeroPoly = numerator is CompressedPolynomial<T>
          ? CompressedPolynomial<T>.zero(type: type)
          : Polynomial<T>.zero(type: type);
      return RationalFunction.fromPolynomial(zeroPoly);
    }
    return RationalFunction(numerator.scale(scalar), denominator).simplify();
  }

  /// Returns the multiplicative inverse `Q(x) / P(x)`.
  ///
  /// Throws an [UnsupportedError] if [isZero] is true.
  RationalFunction<T> reciprocal() {
    if (isZero) {
      throw UnsupportedError('Reciprocal of zero rational function.');
    }
    return RationalFunction(denominator, numerator).simplify();
  }

  /// Raises this rational function to the integer power [exponent].
  ///
  /// Negative exponents compute `(Q / P)^(-exponent)`. Throws an
  /// [UnsupportedError] if [exponent] is negative and [isZero] is true.
  RationalFunction<T> pow(int exponent) {
    if (exponent == 0) {
      final preferCompressed =
          numerator is CompressedPolynomial<T> ||
          denominator is CompressedPolynomial<T>;
      final onePoly = _oneLikeType(type, compressed: preferCompressed);
      return RationalFunction(onePoly, onePoly);
    }
    if (exponent < 0) {
      if (isZero) {
        throw UnsupportedError(
          'Cannot raise zero rational function to negative power ($exponent).',
        );
      }
      final absExp = -exponent;
      return RationalFunction(
        denominator.pow(absExp),
        numerator.pow(absExp),
      ).simplify();
    }
    if (exponent == 1) return simplify();
    if (isZero) {
      final preferCompressed =
          numerator is CompressedPolynomial<T> ||
          denominator is CompressedPolynomial<T>;
      return RationalFunction(
        numerator,
        _oneLikeType(type, compressed: preferCompressed),
      );
    }
    return RationalFunction(
      numerator.pow(exponent),
      denominator.pow(exponent),
    ).simplify();
  }

  /// Addition: `P_1 / Q_1 + P_2 / Q_2 = (P_1 Q_2 + P_2 Q_1) / (Q_1 Q_2)`.
  RationalFunction<T> operator +(RationalFunction<T> other) {
    _checkType(other);
    final numVal =
        (numerator * other.denominator) + (other.numerator * denominator);
    final denVal = denominator * other.denominator;
    return RationalFunction(numVal, denVal).simplify();
  }

  /// Subtraction: `P_1 / Q_1 - P_2 / Q_2 = (P_1 Q_2 - P_2 Q_1) / (Q_1 Q_2)`.
  RationalFunction<T> operator -(RationalFunction<T> other) {
    _checkType(other);
    final numVal =
        (numerator * other.denominator) - (other.numerator * denominator);
    final denVal = denominator * other.denominator;
    return RationalFunction(numVal, denVal).simplify();
  }

  /// Negation: `-(P / Q) = (-P) / Q`.
  RationalFunction<T> operator -() => RationalFunction(-numerator, denominator);

  /// Multiplication: `(P_1 / Q_1) * (P_2 / Q_2) = (P_1 P_2) / (Q_1 Q_2)`.
  RationalFunction<T> operator *(RationalFunction<T> other) {
    _checkType(other);
    final numVal = numerator * other.numerator;
    final denVal = denominator * other.denominator;
    return RationalFunction(numVal, denVal).simplify();
  }

  /// Division: `(P_1 / Q_1) / (P_2 / Q_2) = (P_1 Q_2) / (Q_1 P_2)`.
  RationalFunction<T> operator /(RationalFunction<T> other) {
    _checkType(other);
    if (other.isZero) {
      throw UnsupportedError('Division by zero rational function.');
    }
    final numVal = numerator * other.denominator;
    final denVal = denominator * other.numerator;
    return RationalFunction(numVal, denVal).simplify();
  }

  /// Computes the [order]-th formal derivative using the quotient rule
  /// `(P / Q)' = (P' Q - P Q') / Q^2`.
  ///
  /// Throws a [RangeError] if [order] is negative.
  RationalFunction<T> derivative({int order = 1}) {
    RangeError.checkNotNegative(order, 'order');
    if (order == 0) return this;
    var current = _derivativeOnce();
    for (var k = 1; k < order; k++) {
      if (current.isZero) return current;
      current = current._derivativeOnce();
    }
    return current;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RationalFunction<T> || type != other.type) return false;
    final s1 = _canonical;
    final s2 = other._canonical;
    return s1.numerator == s2.numerator && s1.denominator == s2.denominator;
  }

  @override
  int get hashCode {
    final s = _canonical;
    return Object.hash(RationalFunction, s.numerator, s.denominator);
  }

  @override
  String toString() => '($numerator) / ($denominator)';

  RationalFunction<T> _derivativeOnce() {
    if (numerator.isZero) return simplify();
    final pPrime = numerator.derivative();
    final qPrime = denominator.derivative();
    final numVal = (pPrime * denominator) - (numerator * qPrime);
    final denVal = denominator * denominator;
    return RationalFunction(numVal, denVal).simplify();
  }

  void _checkType(RationalFunction<T> other) {
    if (type != other.type) {
      throw ArgumentError(
        'Rational functions must have the same DataType: '
        '$type != ${other.type}.',
      );
    }
  }

  static Polynomial<T> _oneLike<T>(Polynomial<T> template) => _oneLikeType(
    template.type,
    compressed: template is CompressedPolynomial<T>,
  );

  static Polynomial<T> _oneLikeType<T>(
    DataType<T> type, {
    required bool compressed,
  }) {
    final one = type.field.multiplicativeIdentity;
    return compressed
        ? CompressedPolynomial<T>([0], [one], type: type)
        : DensePolynomial<T>.fromCoefficients([one], type: type);
  }

  static Polynomial<T> _divideByScalar<T>(Polynomial<T> poly, T scalar) {
    final field = poly.type.field;
    if (poly is CompressedPolynomial<T>) {
      final exps = <int>[];
      final coeffs = <T>[];
      for (final term in poly.nonZeroTerms) {
        exps.add(term.exponent);
        coeffs.add(field.div(term.coefficient, scalar));
      }
      return CompressedPolynomial<T>(exps, coeffs, type: poly.type);
    }
    return DensePolynomial<T>.fromCoefficients(
      List<T>.generate(
        poly.degree + 1,
        (i) => field.div(poly[i], scalar),
        growable: false,
      ),
      type: poly.type,
    );
  }
}
