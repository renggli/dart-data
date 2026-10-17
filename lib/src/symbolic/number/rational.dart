/// Exact rational arithmetic on normalized [Integer] numerator/denominator
/// pairs, used by the symbolic number tower.
library;

import 'integer.dart';

/// A rational number $p/q$ as a pair of [Integer] components.
///
/// A pair is _normalized_ if $q > 0$ and $\gcd(|p|, q) = 1$; zero is
/// normalized as $0/1$. All functions in this library expect normalized
/// operands and return normalized results.
typedef RationalParts = ({Integer numerator, Integer denominator});

/// Returns the normalized form of [numerator] / [denominator].
///
/// Throws an [UnsupportedError] if [denominator] is zero.
RationalParts rationalNormalize(Integer numerator, Integer denominator) {
  if (denominator.isZero) throw UnsupportedError('Division by zero');
  if (numerator.isZero) return _zero;
  if (denominator.isOne) {
    return (numerator: numerator, denominator: denominator);
  }
  final divisor = denominator.isNegative
      ? -numerator.gcd(denominator)
      : numerator.gcd(denominator);
  if (divisor.isOne) return (numerator: numerator, denominator: denominator);
  return (numerator: numerator ~/ divisor, denominator: denominator ~/ divisor);
}

/// Returns the normalized sum of [a] and [b].
RationalParts rationalAdd(RationalParts a, RationalParts b) {
  if (a.denominator.isOne && b.denominator.isOne) {
    return (numerator: a.numerator + b.numerator, denominator: Integer.one);
  }
  // Henrici: reduce by the denominators' gcd before multiplying.
  final divisor = a.denominator.gcd(b.denominator);
  if (divisor.isOne) {
    return (
      numerator: a.numerator * b.denominator + b.numerator * a.denominator,
      denominator: a.denominator * b.denominator,
    );
  }
  final numerator =
      a.numerator * (b.denominator ~/ divisor) +
      b.numerator * (a.denominator ~/ divisor);
  if (numerator.isZero) return _zero;
  final reduction = numerator.gcd(divisor);
  return (
    numerator: numerator ~/ reduction,
    denominator: (a.denominator ~/ divisor) * (b.denominator ~/ reduction),
  );
}

/// Returns the normalized difference of [a] and [b].
RationalParts rationalSubtract(RationalParts a, RationalParts b) =>
    rationalAdd(a, rationalNegate(b));

/// Returns the normalized negation of [a].
RationalParts rationalNegate(RationalParts a) =>
    (numerator: -a.numerator, denominator: a.denominator);

/// Returns the normalized product of [a] and [b].
RationalParts rationalMultiply(RationalParts a, RationalParts b) {
  if (a.numerator.isZero || b.numerator.isZero) return _zero;
  if (a.denominator.isOne && b.denominator.isOne) {
    return (numerator: a.numerator * b.numerator, denominator: Integer.one);
  }
  // Cross-cancel before multiplying to keep the intermediates small.
  final first = a.numerator.gcd(b.denominator);
  final second = b.numerator.gcd(a.denominator);
  return (
    numerator: (a.numerator ~/ first) * (b.numerator ~/ second),
    denominator: (a.denominator ~/ second) * (b.denominator ~/ first),
  );
}

/// Returns the normalized multiplicative inverse of [a].
///
/// Throws an [UnsupportedError] if [a] is zero.
RationalParts rationalInvert(RationalParts a) {
  if (a.numerator.isZero) throw UnsupportedError('Division by zero');
  return a.numerator.isNegative
      ? (numerator: -a.denominator, denominator: -a.numerator)
      : (numerator: a.denominator, denominator: a.numerator);
}

/// Returns the normalized quotient of [a] and [b].
///
/// Throws an [UnsupportedError] if [b] is zero.
RationalParts rationalDivide(RationalParts a, RationalParts b) =>
    rationalMultiply(a, rationalInvert(b));

/// Returns [a] raised to the integer [exponent], or `null` if the numerator
/// or denominator of the result would need more than [maxBitLength] bits.
///
/// Throws an [UnsupportedError] if [a] is zero and [exponent] is negative.
RationalParts? rationalPow(
  RationalParts a,
  int exponent, {
  int maxBitLength = Integer.defaultMaxBitLength,
}) {
  final base = exponent < 0 ? rationalInvert(a) : a;
  final magnitude = exponent.abs();
  final numerator = base.numerator.pow(magnitude, maxBitLength: maxBitLength);
  if (numerator == null) return null;
  final denominator = base.denominator.pow(
    magnitude,
    maxBitLength: maxBitLength,
  );
  if (denominator == null) return null;
  // Powers of coprime integers stay coprime.
  return (numerator: numerator, denominator: denominator);
}

/// Compares [a] and [b], returning a negative number, zero, or a positive
/// number.
int rationalCompare(RationalParts a, RationalParts b) {
  if (a.denominator == b.denominator) return a.numerator.compareTo(b.numerator);
  return (a.numerator * b.denominator).compareTo(b.numerator * a.denominator);
}

const RationalParts _zero = (numerator: Integer.zero, denominator: Integer.one);
