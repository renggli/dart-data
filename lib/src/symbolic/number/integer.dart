/// Exact arbitrary-precision integers with a small-value fast path.
library;

/// An exact integer of arbitrary size that is stored as an [int] whenever its
/// magnitude is platform-independently safe, and as a [BigInt] otherwise.
///
/// Values with $|v| \le 2^{53} - 1$ ([maxSafe]) are represented by an [int],
/// all others by a [BigInt]. Because each value has exactly one
/// representation, the underlying `==` and `hashCode` are exact on the VM and
/// on the web. Arithmetic uses overflow-checked [int] fast paths and promotes
/// to [BigInt] only when a result leaves the safe range, so results never
/// silently wrap (VM) or lose precision (web).
///
/// ```dart
/// final big = Integer.two.pow(100)!;
/// print(big); // 1267650600228229401496703205376
/// print(big ~/ Integer.two.pow(98)!); // 4
/// print(Integer.parse('-12') * const Integer(3)); // -36
/// ```
extension type const Integer._(Object _value) {
  /// Creates an integer from a [value] within the safe range
  /// $[-(2^{53} - 1), 2^{53} - 1]$.
  ///
  /// Use [Integer.from] for values that might exceed the safe range.
  const new(int value)
    : assert(
        -maxSafe <= value && value <= maxSafe,
        'Value $value is outside the safe range, use Integer.from',
      ),
      _value = value;

  /// Creates an integer from an arbitrary [int] [value], promoting it to a
  /// [BigInt] representation when it exceeds the safe range.
  factory from(int value) => -maxSafe <= value && value <= maxSafe
      ? Integer._(value)
      : Integer._(BigInt.from(value));

  /// Creates an integer from a [BigInt] [value], demoting it to an [int]
  /// representation when it lies within the safe range.
  factory big(BigInt value) {
    final bitLength = value.bitLength;
    if (bitLength < 53 || (bitLength == 53 && value != _negativeTwoPow53)) {
      return Integer._small(value.toInt());
    }
    return Integer._(value);
  }

  /// Parses a decimal integer [source] of arbitrary length with an optional
  /// leading sign.
  ///
  /// Throws a [FormatException] if [source] is not a valid decimal integer.
  factory parse(String source) {
    if (!_decimal.hasMatch(source)) {
      throw FormatException('Invalid decimal integer', source);
    }
    // At most 15 decimal digits always fit into the safe range.
    final first = source.codeUnitAt(0);
    final digits = source.length - (first == 43 || first == 45 ? 1 : 0);
    if (digits <= 15) return Integer._small(int.parse(source));
    return Integer.big(BigInt.parse(source));
  }

  /// The largest magnitude $2^{53} - 1$ stored as an [int] on all platforms.
  static const maxSafe = 9007199254740991;

  /// The integer `0`.
  static const zero = Integer(0);

  /// The integer `1`.
  static const one = Integer(1);

  /// The integer `2`.
  static const two = Integer(2);

  /// The integer `-1`.
  static const negativeOne = Integer(-1);

  /// The default upper bound on the bit length of [pow] results ($2^{16}$).
  static const defaultMaxBitLength = 65536;

  /// Returns this value as an [int], or `null` if it exceeds the safe range.
  int? get asInt => switch (_value) {
    final int value => value,
    _ => null,
  };

  /// Whether this value is stored as a [BigInt] because it exceeds the safe
  /// range.
  bool get isBig => _value is BigInt;

  /// Returns this value as an [int].
  ///
  /// Throws a [StateError] if the value exceeds the safe range.
  int toInt() => switch (_value) {
    final int value => value,
    _ => throw StateError('$_value exceeds the safe integer range'),
  };

  /// Returns this value as a [BigInt].
  BigInt toBigInt() => _value is int ? BigInt.from(_value) : (_value as BigInt);

  /// Returns the nearest [double] to this value (possibly infinite).
  double toDouble() =>
      _value is int ? _value.toDouble() : (_value as BigInt).toDouble();

  /// Whether this value is `0`.
  bool get isZero => _value == 0;

  /// Whether this value is `1`.
  bool get isOne => _value == 1;

  /// Whether this value is strictly negative.
  bool get isNegative =>
      _value is int ? _value < 0 : (_value as BigInt).isNegative;

  /// Whether this value is even.
  bool get isEven => _value is int ? _value.isEven : (_value as BigInt).isEven;

  /// Whether this value is odd.
  bool get isOdd => !isEven;

  /// The sign of this value: `-1`, `0`, or `1`.
  int get sign => _value is int ? _value.sign : (_value as BigInt).sign;

  /// The minimum number of bits required to store this value, excluding the
  /// sign bit, with the semantics of [int.bitLength].
  int get bitLength =>
      _value is int ? _value.bitLength : (_value as BigInt).bitLength;

  /// Returns the absolute value.
  Integer abs() => switch (_value) {
    final int value => value < 0 ? Integer._(-value) : this,
    final BigInt value when value.isNegative => Integer._(-value),
    _ => this,
  };

  /// Returns the sum of this value and [other].
  Integer operator +(Integer other) {
    final a = _value, b = other._value;
    if (a is int && b is int) {
      if (-_addLimit < a && a < _addLimit && -_addLimit < b && b < _addLimit) {
        return Integer._small(a + b);
      }
      // Safe operands sum to less than 2^54 in magnitude, exact on the VM.
      if (!_isWeb) return Integer.from(a + b);
    }
    return Integer.big(toBigInt() + other.toBigInt());
  }

  /// Returns the difference of this value and [other].
  Integer operator -(Integer other) {
    final a = _value, b = other._value;
    if (a is int && b is int) {
      if (-_addLimit < a && a < _addLimit && -_addLimit < b && b < _addLimit) {
        return Integer._small(a - b);
      }
      if (!_isWeb) return Integer.from(a - b);
    }
    return Integer.big(toBigInt() - other.toBigInt());
  }

  /// Returns the product of this value and [other].
  Integer operator *(Integer other) {
    final a = _value, b = other._value;
    if (a is int && b is int) {
      if (-_mulLimit < a && a < _mulLimit && -_mulLimit < b && b < _mulLimit) {
        return _isWeb ? Integer._small(a * b) : Integer.from(a * b);
      }
      // |a| < 2^m and |b| < 2^n imply |a * b| < 2^(m + n).
      final bits = a.abs().bitLength + b.abs().bitLength;
      if (bits <= 53) return Integer._small(a * b);
      if (!_isWeb && bits <= 63) return Integer.from(a * b);
    }
    return Integer.big(toBigInt() * other.toBigInt());
  }

  /// Returns the quotient of this value and [other], truncated towards zero.
  ///
  /// Throws an [UnsupportedError] if [other] is zero.
  Integer operator ~/(Integer other) {
    if (other.isZero) throw UnsupportedError('Integer division by zero');
    final a = _value, b = other._value;
    if (a is int && b is int) return Integer._small(a ~/ b);
    return Integer.big(toBigInt() ~/ other.toBigInt());
  }

  /// Returns the Euclidean modulo of this value and [other], which is always
  /// non-negative.
  ///
  /// Throws an [UnsupportedError] if [other] is zero.
  Integer operator %(Integer other) {
    if (other.isZero) throw UnsupportedError('Integer division by zero');
    final a = _value, b = other._value;
    if (a is int && b is int) return Integer._small(a % b);
    return Integer.big(toBigInt() % other.toBigInt());
  }

  /// Returns the negation of this value.
  Integer operator -() =>
      _value is int ? Integer._small(-_value) : Integer._(-(_value as BigInt));

  /// Returns the non-negative greatest common divisor of this value and
  /// [other].
  ///
  /// The result is `0` only if both values are zero.
  Integer gcd(Integer other) {
    final a = _value, b = other._value;
    if (a is int && b is int) return Integer._small(a.gcd(b));
    return Integer.big(toBigInt().gcd(other.toBigInt()));
  }

  /// Returns the non-negative least common multiple of this value and [other].
  ///
  /// Returns `0` if either value is zero.
  Integer lcm(Integer other) {
    if (isZero || other.isZero) return zero;
    final g = gcd(other);
    return (abs() ~/ g) * other.abs();
  }

  /// Whether this integer is a prime number ($p \ge 2$).
  ///
  /// Uses deterministic Miller-Rabin witnesses for 64-bit integers and
  /// trial division + strong probable prime testing for larger [BigInt] values.
  bool get isPrime {
    if (isNegative || isZero || isOne) return false;
    final n = _value;
    if (n is int) {
      return _isSmallPrime(n);
    }
    return _isBigPrime(n as BigInt);
  }

  /// Returns this value raised to the non-negative [exponent], or `null` if
  /// the result would need more than [maxBitLength] bits.
  ///
  /// Throws an [ArgumentError] if [exponent] is negative.
  Integer? pow(int exponent, {int maxBitLength = defaultMaxBitLength}) {
    if (exponent < 0) {
      throw ArgumentError.value(exponent, 'exponent', 'Must be non-negative');
    }
    if (exponent == 0) return one;
    if (isZero || isOne || exponent == 1) return this;
    if (_value == -1) return exponent.isEven ? one : this;
    // A base with b bits yields a power with between e * (b - 1) + 1 and
    // e * b bits.
    final bits = abs().bitLength;
    if (exponent * (bits - 1) + 1 > maxBitLength) return null;
    final Integer result;
    if (_value case final int base when exponent * bits <= 53) {
      var value = 1;
      for (var i = 0; i < exponent; i++) {
        value *= base;
      }
      result = Integer._small(value);
    } else {
      result = Integer.big(toBigInt().pow(exponent));
    }
    return result.abs().bitLength > maxBitLength ? null : result;
  }

  /// Compares this value to [other], returning a negative number, zero, or a
  /// positive number.
  int compareTo(Integer other) => switch ((_value, other._value)) {
    (final int a, final int b) => a.compareTo(b),
    (int(), final BigInt b) => b.isNegative ? 1 : -1,
    (final BigInt a, int()) => a.isNegative ? -1 : 1,
    (final BigInt a, final BigInt b) => a.compareTo(b),
    _ => 0,
  };

  /// Whether this value is less than [other].
  bool operator <(Integer other) => compareTo(other) < 0;

  /// Whether this value is less than or equal to [other].
  bool operator <=(Integer other) => compareTo(other) <= 0;

  /// Whether this value is greater than [other].
  bool operator >(Integer other) => compareTo(other) > 0;

  /// Whether this value is greater than or equal to [other].
  bool operator >=(Integer other) => compareTo(other) >= 0;

  /// Wraps an [int] [value] known to be in the safe range, normalizing the
  /// negative zero produced by some operations on the web.
  static Integer _small(int value) => Integer._(value == 0 ? 0 : value);
}

/// Whether the code runs on the web, where integers are IEEE doubles.
const _isWeb = identical(1, 1.0);

/// Operands below this magnitude always add to a safe result.
const _addLimit = 4503599627370496; // 2^52

/// Operands below this magnitude multiply without wrapping (VM) or precision
/// loss (web).
const _mulLimit = _isWeb ? 67108864 : 2147483648; // 2^26 : 2^31

/// The value $-2^{53}$, the only 53-bit value outside the safe range.
final _negativeTwoPow53 = -BigInt.two.pow(53);

/// Pattern of a decimal integer with an optional sign.
final _decimal = RegExp(r'^[+-]?[0-9]+$');

const _smallPrimes = <int>[2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37];

bool _isSmallPrime(int n) {
  if (n < 2) return false;
  for (final p in _smallPrimes) {
    if (n == p) return true;
    if (n % p == 0) return false;
  }
  if (n < 1369) return true; // 37^2 = 1369
  if (n < 1000000) {
    for (var d = 41; d * d <= n; d += 6) {
      if (n % d == 0 || n % (d + 2) == 0) return false;
    }
    return true;
  }
  return _isBigPrime(BigInt.from(n));
}

bool _isBigPrime(BigInt n) {
  if (n < BigInt.two) return false;
  for (final p in _smallPrimes) {
    final bp = BigInt.from(p);
    if (n == bp) return true;
    if (n % bp == BigInt.zero) return false;
  }
  var d = n - BigInt.one;
  var r = 0;
  while (d.isEven) {
    d >>= 1;
    r++;
  }
  for (final aInt in _smallPrimes) {
    final a = BigInt.from(aInt);
    if (a >= n) break;
    var x = a.modPow(d, n);
    if (x == BigInt.one || x == n - BigInt.one) continue;
    var composite = true;
    for (var i = 1; i < r; i++) {
      x = (x * x) % n;
      if (x == n - BigInt.one) {
        composite = false;
        break;
      }
    }
    if (composite) return false;
  }
  return true;
}
