import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

final maxSafe = BigInt.from(Integer.maxSafe);

/// Boundary values around the platform-relevant powers of two, given as
/// [BigInt] so that the test compiles on the web.
final boundaries = () {
  final result = <BigInt>{};
  for (final power in const [0, 1, 26, 31, 32, 52, 53, 62, 63, 64, 100]) {
    final value = BigInt.two.pow(power);
    for (final offset in const [-1, 0, 1]) {
      result.add(value + BigInt.from(offset));
      result.add(-value - BigInt.from(offset));
    }
  }
  result
    ..add(BigInt.zero)
    ..add(BigInt.from(3))
    ..add(BigInt.from(-7))
    ..add(BigInt.from(10).pow(30))
    ..add(-BigInt.from(10).pow(30) + BigInt.one);
  return result.toList()..sort();
}();

void checkInvariant(Integer value, BigInt expected) {
  check(value.toBigInt()).equals(expected);
  check(value.isBig).equals(expected.abs() > maxSafe);
  check(value).equals(Integer.big(expected));
  check(value.hashCode).equals(Integer.big(expected).hashCode);
  check(value.toString()).equals(expected.toString());
}

void main() {
  group('construction', () {
    test('constant constructor', () {
      check(const Integer(42).asInt).equals(42);
      check(const Integer(-Integer.maxSafe).asInt).equals(-Integer.maxSafe);
      check(Integer.zero.asInt).equals(0);
      check(Integer.one.asInt).equals(1);
      check(Integer.two.asInt).equals(2);
      check(Integer.negativeOne.asInt).equals(-1);
    });
    test('from int', () {
      check(Integer.from(Integer.maxSafe).isBig).isFalse();
      check(Integer.from(-Integer.maxSafe).isBig).isFalse();
      final unsafe = int.parse('9007199254740992');
      check(Integer.from(unsafe).isBig).isTrue();
      check(Integer.from(-unsafe).isBig).isTrue();
      checkInvariant(Integer.from(unsafe), maxSafe + BigInt.one);
    });
    test('from BigInt demotes safe values', () {
      for (final value in boundaries) {
        final integer = Integer.big(value);
        check(integer.isBig).equals(value.abs() > maxSafe);
        check(integer.toBigInt()).equals(value);
      }
      check(Integer.big(maxSafe).asInt).equals(Integer.maxSafe);
      check(Integer.big(-maxSafe).asInt).equals(-Integer.maxSafe);
      check(Integer.big(maxSafe + BigInt.one).asInt).isNull();
      check(Integer.big(-maxSafe - BigInt.one).asInt).isNull();
    });
    test('conversions', () {
      check(const Integer(-5).toInt()).equals(-5);
      check(const Integer(-5).toBigInt()).equals(BigInt.from(-5));
      check(const Integer(-5).toDouble()).equals(-5.0);
      final big = Integer.big(BigInt.two.pow(100));
      check(big.toInt).throws<StateError>();
      check(big.toDouble()).equals(1.2676506002282294e30);
      check(Integer.big(BigInt.two.pow(1100)).toDouble())
          .equals(double.infinity);
    });
  });
  group('parse', () {
    test('short values', () {
      check(Integer.parse('0')).equals(Integer.zero);
      check(Integer.parse('-0')).equals(Integer.zero);
      check(Integer.parse('+17')).equals(const Integer(17));
      check(Integer.parse('-123456789012345'))
          .equals(const Integer(-123456789012345));
    });
    test('safe range boundaries', () {
      check(Integer.parse('9007199254740991').isBig).isFalse();
      check(Integer.parse('-9007199254740991').isBig).isFalse();
      check(Integer.parse('9007199254740992').isBig).isTrue();
      check(Integer.parse('-9007199254740992').isBig).isTrue();
    });
    test('leading zeros demote', () {
      final value = Integer.parse('00000000000000000000000012');
      check(value).equals(const Integer(12));
      check(value.isBig).isFalse();
    });
    test('long digit strings', () {
      for (final length in const [16, 19, 20, 50, 100, 1000]) {
        final digits = List.generate(length, (i) => '${(i * 7 + 1) % 10}');
        final source = digits.join();
        check(Integer.parse(source).toString()).equals(source);
        check(Integer.parse('-$source').toString()).equals('-$source');
        checkInvariant(Integer.parse(source), BigInt.parse(source));
      }
    });
    test('invalid input', () {
      for (final source in const [
        '',
        '-',
        '+',
        '1.0',
        '1e3',
        '0x10',
        ' 1',
        '1 ',
        '--1',
        '1_000',
        '١٢',
      ]) {
        check(
          because: source,
          () => Integer.parse(source),
        ).throws<FormatException>();
      }
    });
  });
  group('normalization', () {
    test('equality across representations', () {
      final big = Integer.big(maxSafe + BigInt.one);
      check(big - Integer.one).equals(const Integer(Integer.maxSafe));
      check((big - Integer.one).isBig).isFalse();
      check((big - Integer.one).hashCode)
          .equals(const Integer(Integer.maxSafe).hashCode);
      check(Integer.big(BigInt.from(5))).equals(const Integer(5));
      check(Integer.from(5).hashCode).equals(const Integer(5).hashCode);
    });
    test('set deduplication', () {
      final values = {
        const Integer(7),
        Integer.big(BigInt.from(7)),
        Integer.parse('0000000000000000000007'),
        Integer.big(BigInt.two.pow(64)) -
            Integer.big(BigInt.two.pow(64) - BigInt.from(7)),
      };
      check(values).length.equals(1);
    });
    test('negative zero', () {
      for (final zero in [
        Integer.zero * const Integer(-5),
        const Integer(-5) * Integer.zero,
        -Integer.zero,
        Integer.zero ~/ const Integer(-3),
        const Integer(-3) % const Integer(3),
        const Integer(-3) + const Integer(3),
        Integer.zero.abs(),
      ]) {
        check(zero).equals(Integer.zero);
        check(zero.toString()).equals('0');
        check(zero.isNegative).isFalse();
        check(zero.sign).equals(0);
      }
    });
  });
  group('arithmetic', () {
    test('addition', () {
      for (final a in boundaries) {
        for (final b in boundaries) {
          checkInvariant(Integer.big(a) + Integer.big(b), a + b);
        }
      }
    });
    test('subtraction', () {
      for (final a in boundaries) {
        for (final b in boundaries) {
          checkInvariant(Integer.big(a) - Integer.big(b), a - b);
        }
      }
    });
    test('multiplication', () {
      for (final a in boundaries) {
        for (final b in boundaries) {
          checkInvariant(Integer.big(a) * Integer.big(b), a * b);
        }
      }
    });
    test('truncating division', () {
      for (final a in boundaries) {
        for (final b in boundaries.where((each) => each != BigInt.zero)) {
          checkInvariant(Integer.big(a) ~/ Integer.big(b), a ~/ b);
        }
      }
      check(const Integer(-7) ~/ Integer.two).equals(const Integer(-3));
      check(const Integer(7) ~/ const Integer(-2)).equals(const Integer(-3));
    });
    test('modulo', () {
      for (final a in boundaries) {
        for (final b in boundaries.where((each) => each != BigInt.zero)) {
          checkInvariant(Integer.big(a) % Integer.big(b), a % b);
        }
      }
      check(const Integer(-7) % Integer.two).equals(Integer.one);
      check(const Integer(-7) % const Integer(-2)).equals(Integer.one);
    });
    test('division by zero', () {
      final big = Integer.big(BigInt.two.pow(100));
      check(() => Integer.one ~/ Integer.zero).throws<UnsupportedError>();
      check(() => big ~/ Integer.zero).throws<UnsupportedError>();
      check(() => Integer.one % Integer.zero).throws<UnsupportedError>();
      check(() => big % Integer.zero).throws<UnsupportedError>();
    });
    test('negation and absolute value', () {
      for (final a in boundaries) {
        checkInvariant(-Integer.big(a), -a);
        checkInvariant(Integer.big(a).abs(), a.abs());
      }
    });
    test('predicates', () {
      for (final a in boundaries) {
        final value = Integer.big(a);
        check(value.isZero).equals(a == BigInt.zero);
        check(value.isOne).equals(a == BigInt.one);
        check(value.isNegative).equals(a.isNegative);
        check(value.isEven).equals(a.isEven);
        check(value.isOdd).equals(a.isOdd);
        check(value.sign).equals(a.sign);
        check(value.bitLength).equals(a.bitLength);
      }
    });
    test('accumulated sum crosses the safe range', () {
      var sum = Integer.zero;
      const step = Integer(Integer.maxSafe);
      for (var i = 0; i < 4; i++) {
        sum += step;
      }
      checkInvariant(sum, maxSafe * BigInt.from(4));
      for (var i = 0; i < 4; i++) {
        sum -= step;
      }
      check(sum).equals(Integer.zero);
      check(sum.isBig).isFalse();
    });
  });
  group('gcd', () {
    test('boundary pairs', () {
      for (final a in boundaries) {
        for (final b in boundaries) {
          checkInvariant(Integer.big(a).gcd(Integer.big(b)), a.gcd(b));
        }
      }
    });
    test('special values', () {
      check(Integer.zero.gcd(Integer.zero)).equals(Integer.zero);
      check(Integer.zero.gcd(const Integer(-6))).equals(const Integer(6));
      check(const Integer(-12).gcd(const Integer(18))).equals(const Integer(6));
      final a = Integer.big(BigInt.two.pow(100) * BigInt.from(3));
      final b = Integer.big(BigInt.two.pow(90) * BigInt.from(9));
      checkInvariant(a.gcd(b), BigInt.two.pow(90) * BigInt.from(3));
    });
  });
  group('pow', () {
    test('small results', () {
      check(const Integer(3).pow(4)).equals(const Integer(81));
      check(const Integer(-3).pow(5)).equals(const Integer(-243));
      check(Integer.zero.pow(0)).equals(Integer.one);
      check(Integer.zero.pow(5)).equals(Integer.zero);
      check(Integer.one.pow(1000000)).equals(Integer.one);
      check(Integer.negativeOne.pow(1000001)).equals(Integer.negativeOne);
      check(Integer.negativeOne.pow(1000000)).equals(Integer.one);
    });
    test('powers of two', () {
      for (var exponent = 0; exponent <= 130; exponent++) {
        final result = Integer.two.pow(exponent);
        check(result).isNotNull();
        checkInvariant(result!, BigInt.two.pow(exponent));
        checkInvariant(-Integer.two.pow(exponent)!, -BigInt.two.pow(exponent));
      }
    });
    test('boundary bases', () {
      for (final a in boundaries) {
        for (final exponent in const [0, 1, 2, 3, 7]) {
          checkInvariant(Integer.big(a).pow(exponent)!, a.pow(exponent));
        }
      }
    });
    test('size limit', () {
      check(Integer.two.pow(65535))
          .isNotNull()
          .has((value) => value.bitLength, 'bitLength')
          .equals(65536);
      check(Integer.two.pow(65536)).isNull();
      check(const Integer(3).pow(100, maxBitLength: 100)).isNull();
      check(const Integer(3).pow(100, maxBitLength: 159))
          .isNotNull()
          .equals(Integer.big(BigInt.from(3).pow(100)));
      check(Integer.two.pow(1000000)).isNull();
      check(Integer.two.pow(100000, maxBitLength: 100001)).isNotNull();
    });
    test('negative exponent', () {
      check(() => Integer.two.pow(-1)).throws<ArgumentError>();
    });
  });
  group('comparison', () {
    test('boundary pairs', () {
      for (final a in boundaries) {
        for (final b in boundaries) {
          final x = Integer.big(a), y = Integer.big(b);
          check(x.compareTo(y).sign).equals(a.compareTo(b).sign);
          check(x < y).equals(a < b);
          check(x <= y).equals(a <= b);
          check(x > y).equals(a > b);
          check(x >= y).equals(a >= b);
          check(x == y).equals(a == b);
        }
      }
    });
  });
}
