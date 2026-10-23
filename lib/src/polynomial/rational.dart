import '../../type.dart';
import 'polynomial.dart';

/// Rational function $R(x) = \frac{P(x)}{Q(x)}$ representing the ratio of two
/// [Polynomial] instances.
///
/// Conceptually, a rational function is an algebraic fraction where both
/// numerator and denominator are polynomials (such as $\frac{x + 1}{x^2 - 4}$).
/// Formally, this models elements of the field of rational functions
/// `K(x) = Frac(K[x])`, supporting exact formal algebra, differentiation,
/// simplification via GCD reduction, and evaluation.
///
/// ```dart
/// final num = Polynomial.fromCoefficients([1.0, 1.0]); // x + 1
/// final den = Polynomial.fromCoefficients([2.0, 1.0]); // x + 2
/// final r = RationalFunction(num, den);
/// final y = r.evaluateDouble(0.0); // 1.0 / 2.0 = 0.5
/// ```
class RationalFunction<T> {
  /// Constructs a rational function with [numerator] and [denominator].
  new(this.numerator, this.denominator) : type = numerator.type {
    if (denominator.degree < 0) {
      throw UnsupportedError('Denominator cannot be zero polynomial.');
    }
  }

  /// Constructs a rational function from a single [polynomial] with denominator
  /// 1.
  factory fromPolynomial(Polynomial<T> polynomial) {
    final one = Polynomial<T>.fromCoefficients([
      polynomial.type.field.multiplicativeIdentity,
    ], type: polynomial.type);
    return RationalFunction(polynomial, one);
  }

  /// The numerator polynomial $P(x)$.
  final Polynomial<T> numerator;

  /// The denominator polynomial $Q(x)$.
  final Polynomial<T> denominator;

  /// The data type of the polynomial coefficients.
  final DataType<T> type;

  /// Simplifies this rational function by cancelling the greatest common
  /// divisor $\gcd(P, Q)$.
  RationalFunction<T> simplify() {
    final g = numerator.gcd(denominator);
    var num = numerator;
    var den = denominator;
    if (g.degree > 0) {
      num = num / g;
      den = den / g;
    }
    // Make denominator monic if field division is supported
    final lead = den.leadingCoefficient;
    final field = type.field;
    if (lead != field.multiplicativeIdentity &&
        lead != field.additiveIdentity) {
      final inv = field.div(field.multiplicativeIdentity, lead);
      num = num.scale(inv);
      den = den.scale(inv);
    }
    return RationalFunction(num, den);
  }

  /// Evaluates $R(x) = P(x) / Q(x)$ at [x].
  T evaluate(T x) {
    final numVal = numerator.evaluate(x);
    final denVal = denominator.evaluate(x);
    final field = type.field;
    if (denVal == field.additiveIdentity) {
      throw UnsupportedError('Evaluation resulted in division by zero.');
    }
    return field.div(numVal, denVal);
  }

  /// Evaluates $R(x)$ for a numeric value [x] as a double.
  double evaluateDouble(num x) {
    final numVal = numerator.evaluateDouble(x);
    final denVal = denominator.evaluateDouble(x);
    if (denVal == 0.0) {
      throw UnsupportedError('Evaluation resulted in division by zero.');
    }
    return numVal / denVal;
  }

  /// Addition:
  /// $\frac{P_1}{Q_1} + \frac{P_2}{Q_2} = \frac{P_1 Q_2 + P_2 Q_1}{Q_1 Q_2}$.
  RationalFunction<T> operator +(RationalFunction<T> other) {
    final numVal =
        (numerator * other.denominator) + (other.numerator * denominator);
    final denVal = denominator * other.denominator;
    return RationalFunction(numVal, denVal).simplify();
  }

  /// Subtraction:
  /// $\frac{P_1}{Q_1} - \frac{P_2}{Q_2} = \frac{P_1 Q_2 - P_2 Q_1}{Q_1 Q_2}$.
  RationalFunction<T> operator -(RationalFunction<T> other) {
    final numVal =
        (numerator * other.denominator) - (other.numerator * denominator);
    final denVal = denominator * other.denominator;
    return RationalFunction(numVal, denVal).simplify();
  }

  /// Negation: $-\frac{P}{Q} = \frac{-P}{Q}$.
  RationalFunction<T> operator -() => RationalFunction(-numerator, denominator);

  /// Multiplication:
  /// $\frac{P_1}{Q_1} \cdot \frac{P_2}{Q_2} = \frac{P_1 P_2}{Q_1 Q_2}$.
  RationalFunction<T> operator *(RationalFunction<T> other) {
    final numVal = numerator * other.numerator;
    final denVal = denominator * other.denominator;
    return RationalFunction(numVal, denVal).simplify();
  }

  /// Division: $\frac{P_1}{Q_1} / \frac{P_2}{Q_2} = \frac{P_1 Q_2}{Q_1 P_2}$.
  RationalFunction<T> operator /(RationalFunction<T> other) {
    if (other.numerator.degree < 0) {
      throw UnsupportedError('Division by zero rational function.');
    }
    final numVal = numerator * other.denominator;
    final denVal = denominator * other.numerator;
    return RationalFunction(numVal, denVal).simplify();
  }

  /// Computes the formal derivative
  /// $\left(\frac{P}{Q}\right)' = \frac{P' Q - P Q'}{Q^2}$.
  RationalFunction<T> derivative() {
    final pPrime = numerator.derivative();
    final qPrime = denominator.derivative();
    final numVal = (pPrime * denominator) - (numerator * qPrime);
    final denVal = denominator * denominator;
    return RationalFunction(numVal, denVal).simplify();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RationalFunction<T>) return false;
    return (numerator * other.denominator) == (other.numerator * denominator);
  }

  @override
  int get hashCode {
    final s = simplify();
    return Object.hash(RationalFunction, s.numerator, s.denominator);
  }

  @override
  String toString() => '($numerator) / ($denominator)';
}
