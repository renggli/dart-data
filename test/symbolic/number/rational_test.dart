import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

/// Builds a normalized rational from [BigInt] components via the oracle.
RationalParts oracle(BigInt numerator, BigInt denominator) {
  if (denominator.isNegative) {
    numerator = -numerator;
    denominator = -denominator;
  }
  final divisor = numerator.gcd(denominator);
  return (
    numerator: Integer.big(numerator ~/ divisor),
    denominator: Integer.big(denominator ~/ divisor),
  );
}

RationalParts parts(int numerator, [int denominator = 1]) => (
  numerator: Integer.from(numerator),
  denominator: Integer.from(denominator),
);

BigInt numeratorOf(RationalParts value) => value.numerator.toBigInt();
BigInt denominatorOf(RationalParts value) => value.denominator.toBigInt();

void checkNormalized(RationalParts value) {
  check(value.denominator.isNegative).isFalse();
  check(value.denominator.isZero).isFalse();
  check(value.numerator.gcd(value.denominator))
      .equals(value.numerator.isZero ? value.denominator : Integer.one);
  if (value.numerator.isZero) check(value.denominator).equals(Integer.one);
}

final values = () {
  final big = BigInt.two.pow(70);
  final safe = BigInt.from(Integer.maxSafe);
  final components = [
    (BigInt.zero, BigInt.one),
    (BigInt.one, BigInt.one),
    (BigInt.from(-1), BigInt.one),
    (BigInt.one, BigInt.two),
    (BigInt.from(-7), BigInt.from(3)),
    (BigInt.from(6), BigInt.from(4)),
    (safe, BigInt.from(3)),
    (safe, safe - BigInt.one),
    (big, BigInt.from(3)),
    (BigInt.one, big),
    (-big - BigInt.one, big + BigInt.one + BigInt.one),
    (BigInt.from(2147483647), BigInt.from(67108864)),
  ];
  return [
    for (final (numerator, denominator) in components)
      (
        value: rationalNormalize(
          Integer.big(numerator),
          Integer.big(denominator),
        ),
        numerator: numerator,
        denominator: denominator,
      ),
  ];
}();

void main() {
  group('rationalNormalize', () {
    test('lowest terms', () {
      check(rationalNormalize(Integer.two, const Integer(4)))
          .equals(parts(1, 2));
      check(rationalNormalize(Integer.two, const Integer(-4)))
          .equals(parts(-1, 2));
      check(rationalNormalize(const Integer(-6), const Integer(-9)))
          .equals(parts(2, 3));
      check(rationalNormalize(Integer.zero, const Integer(-5)))
          .equals(parts(0));
      check(rationalNormalize(const Integer(5), Integer.negativeOne))
          .equals(parts(-5));
      check(rationalNormalize(const Integer(5), Integer.one)).equals(parts(5));
    });
    test('big components demote', () {
      final big = Integer.big(BigInt.two.pow(100));
      check(rationalNormalize(big, big * Integer.two)).equals(parts(1, 2));
      check(rationalNormalize(big * const Integer(3), -big)).equals(parts(-3));
    });
    test('division by zero', () {
      check(() => rationalNormalize(Integer.one, Integer.zero))
          .throws<UnsupportedError>();
    });
    test('oracle', () {
      for (final (:value, :numerator, :denominator) in values) {
        checkNormalized(value);
        check(value).equals(oracle(numerator, denominator));
      }
    });
  });
  group('arithmetic', () {
    test('addition and subtraction', () {
      for (final a in values) {
        for (final b in values) {
          final sum = rationalAdd(a.value, b.value);
          final difference = rationalSubtract(a.value, b.value);
          checkNormalized(sum);
          checkNormalized(difference);
          final (n1, d1) = (numeratorOf(a.value), denominatorOf(a.value));
          final (n2, d2) = (numeratorOf(b.value), denominatorOf(b.value));
          check(sum).equals(oracle(n1 * d2 + n2 * d1, d1 * d2));
          check(difference).equals(oracle(n1 * d2 - n2 * d1, d1 * d2));
        }
      }
    });
    test('multiplication and division', () {
      for (final a in values) {
        for (final b in values) {
          final (n1, d1) = (numeratorOf(a.value), denominatorOf(a.value));
          final (n2, d2) = (numeratorOf(b.value), denominatorOf(b.value));
          final product = rationalMultiply(a.value, b.value);
          checkNormalized(product);
          check(product).equals(oracle(n1 * n2, d1 * d2));
          if (n2 == BigInt.zero) {
            check(() => rationalDivide(a.value, b.value))
                .throws<UnsupportedError>();
          } else {
            final quotient = rationalDivide(a.value, b.value);
            checkNormalized(quotient);
            check(quotient).equals(oracle(n1 * d2, d1 * n2));
          }
        }
      }
    });
    test('negation and inversion', () {
      check(rationalNegate(parts(-7, 3))).equals(parts(7, 3));
      check(rationalNegate(parts(0))).equals(parts(0));
      check(rationalInvert(parts(-7, 3))).equals(parts(-3, 7));
      check(rationalInvert(parts(5))).equals(parts(1, 5));
      check(() => rationalInvert(parts(0))).throws<UnsupportedError>();
    });
    test('integer fast path', () {
      final big = Integer.big(BigInt.two.pow(60));
      check(rationalAdd((numerator: big, denominator: Integer.one), parts(1)))
          .equals((numerator: big + Integer.one, denominator: Integer.one));
      check(rationalMultiply(parts(3), parts(-4))).equals(parts(-12));
    });
  });
  group('rationalPow', () {
    test('integer exponents', () {
      check(rationalPow(parts(2, 3), 3)).equals(parts(8, 27));
      check(rationalPow(parts(-2, 3), 3)).equals(parts(-8, 27));
      check(rationalPow(parts(2, 3), -3)).equals(parts(27, 8));
      check(rationalPow(parts(-2, 3), -3)).equals(parts(-27, 8));
      check(rationalPow(parts(-2, 3), 0)).equals(parts(1));
      check(rationalPow(parts(0), 5)).equals(parts(0));
    });
    test('big results', () {
      check(rationalPow(parts(1, 2), 100)).equals((
        numerator: Integer.one,
        denominator: Integer.big(BigInt.two.pow(100)),
      ));
    });
    test('size limit', () {
      check(rationalPow(parts(1, 2), 65536)).isNull();
      check(rationalPow(parts(3, 2), 100, maxBitLength: 100)).isNull();
      check(rationalPow(parts(3, 2), 100, maxBitLength: 159)).isNotNull();
    });
    test('zero to a negative power', () {
      check(() => rationalPow(parts(0), -1)).throws<UnsupportedError>();
    });
  });
  group('rationalCompare', () {
    test('oracle', () {
      for (final a in values) {
        for (final b in values) {
          final (n1, d1) = (numeratorOf(a.value), denominatorOf(a.value));
          final (n2, d2) = (numeratorOf(b.value), denominatorOf(b.value));
          check(rationalCompare(a.value, b.value).sign)
              .equals((n1 * d2).compareTo(n2 * d1).sign);
        }
      }
    });
  });
}
