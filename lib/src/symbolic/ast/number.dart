part of '../ast.dart';

/// Base class for all atomic numeric literals in the symbolic AST.
///
/// The numeric tower consists of [RealNumeric] ([RationalNumber] — subdivided
/// into [IntegerNumber] and [FractionNumber] — and [RealNumber]) together with
/// [ComplexNumber] over [RealNumeric] components.
sealed class Number extends Expr {
  /// Creates an atomic numeric expression.
  const new();

  @override
  bool get isSimplified => true;

  /// Whether this number is identically zero ($0$).
  bool get isZero;

  /// Whether this number is identically one ($1$).
  bool get isOne;

  /// Whether this number is identically negative one ($-1$).
  bool get isNegativeOne;

  /// Converts this number to a real IEEE-754 floating-point value.
  ///
  /// Throws an [UnsupportedError] if this is a [ComplexNumber] with a non-zero
  /// imaginary component.
  double toDouble();

  /// Converts this number to a floating-point [Complex] value.
  Complex toComplex();

  /// Returns the complex conjugate $\bar{z}$ of this number.
  Number get conjugate;

  /// Returns the additive inverse $-z$ of this number.
  Number neg();

  /// Returns the exact or contagion-promoted sum `this + other`.
  Number add(Number other) {
    if ((this, other) case (final RealNumeric a, final RealNumeric b)) {
      return _addReal(a, b);
    }
    final (ar, ai) = _components(this);
    final (br, bi) = _components(other);
    return ComplexNumber.of(_addReal(ar, br), _addReal(ai, bi));
  }

  /// Returns the exact or contagion-promoted difference `this - other`.
  Number sub(Number other) => add(other.neg());

  /// Returns the exact or contagion-promoted product `this * other`.
  Number mul(Number other) {
    if ((this, other) case (final RealNumeric a, final RealNumeric b)) {
      return _mulReal(a, b);
    }
    final (ar, ai) = _components(this);
    final (br, bi) = _components(other);
    // (ar + ai*i) * (br + bi*i) = (ar*br - ai*bi) + (ar*bi + ai*br)*i
    final realPart = _subReal(_mulReal(ar, br), _mulReal(ai, bi));
    final imagPart = _addReal(_mulReal(ar, bi), _mulReal(ai, br));
    return ComplexNumber.of(realPart, imagPart);
  }

  /// Returns the exact or contagion-promoted quotient `this / other`.
  ///
  /// Throws an [UnsupportedError] if [other] is zero.
  Number div(Number other) {
    if (other.isZero) {
      throw UnsupportedError('Division by zero: $this / $other');
    }
    if ((this, other) case (final RealNumeric a, final RealNumeric b)) {
      return _divReal(a, b);
    }
    final (ar, ai) = _components(this);
    final (br, bi) = _components(other);
    // (ar + ai*i) / (br + bi*i) = ((ar*br + ai*bi) + (ai*br - ar*bi)*i) / (br^2 + bi^2)
    final denom = _addReal(_mulReal(br, br), _mulReal(bi, bi));
    if (denom.isZero) {
      throw UnsupportedError('Division by zero: $this / $other');
    }
    final realNum = _addReal(_mulReal(ar, br), _mulReal(ai, bi));
    final imagNum = _subReal(_mulReal(ai, br), _mulReal(ar, bi));
    return ComplexNumber.of(_divReal(realNum, denom), _divReal(imagNum, denom));
  }

  /// Evaluates `this ^ exponent` as a single [Number] if it reduces to an
  /// atomic numeric value, or returns `null` if it must remain a symbolic [Pow].
  Number? powNumber(Number exponent) => switch ((this, exponent)) {
    (final RationalNumber baseRat, final IntegerNumber exp) => _powRationalInt(
      baseRat,
      exp,
    ),
    (final RationalNumber baseRat, final FractionNumber exp) =>
      _powRationalFrac(baseRat, exp),
    (final ComplexNumber c, final exp) => _powComplex(c, exp),
    (final RealNumeric baseReal, final RealNumeric exp) => _powReal(
      baseReal,
      exp,
    ),
    _ => null,
  };

  static Number? _powRationalInt(
    RationalNumber baseRat,
    IntegerNumber exponent,
  ) {
    if (baseRat.isZero) {
      if (exponent.isZero) return IntegerNumber.one;
      if (exponent.isNegative) {
        throw UnsupportedError('Division by zero in power: 0 ^ $exponent');
      }
      return IntegerNumber.zero;
    }
    if (baseRat.isOne) return IntegerNumber.one;
    if (baseRat.isNegativeOne) {
      return exponent.value.isEven
          ? IntegerNumber.one
          : IntegerNumber.negativeOne;
    }
    if (exponent.asInt case final expInt? when expInt.abs() <= 1000) {
      return baseRat.powInteger(expInt);
    }
    return null;
  }

  static Number? _powRationalFrac(
    RationalNumber baseRat,
    FractionNumber exponent,
  ) {
    if (baseRat.isZero) {
      if (exponent.isNegative) {
        throw UnsupportedError('Division by zero in power: 0 ^ $exponent');
      }
      return IntegerNumber.zero;
    }
    if (baseRat.isOne) return IntegerNumber.one;
    if (baseRat.isNegative) return null;
    if ((exponent.denominator.asInt, exponent.numerator.asInt)
        case (final q?, final p?) when q <= 64 && p.abs() <= 64) {
      if (_exactIntegerRoot(baseRat.numerator, q) case final rootNum?) {
        if (_exactIntegerRoot(baseRat.denominator, q) case final rootDen?) {
          return RationalNumber.of(rootNum, rootDen).powInteger(p);
        }
      }
    }
    return null;
  }

  static Number? _powComplex(ComplexNumber c, Number exponent) {
    final intExp = switch (exponent) {
      IntegerNumber(:final value) => value,
      RealNumber(:final value)
          when value == value.roundToDouble() &&
              value.abs() < 9007199254740992.0 =>
        Integer.from(value.round()),
      _ => null,
    };
    if (intExp == null) return null;
    final isFloat =
        exponent is RealNumber ||
        c.real is RealNumber ||
        c.imaginary is RealNumber;
    if (intExp.isZero) {
      return isFloat ? const RealNumber(1.0) : IntegerNumber.one;
    }
    Number? result;
    if (c.isPureImaginary) {
      // (b * i)^n = b^n * i^n
      final mod = (intExp % const Integer(4)).toInt();
      final iPow = switch (mod) {
        0 => IntegerNumber.one,
        1 => ComplexNumber.i,
        2 => IntegerNumber.negativeOne,
        _ => ComplexNumber.negativeI,
      };
      if (c.imaginary.isOne) {
        result = iPow;
      } else if (c.imaginary.isNegativeOne) {
        final sign = intExp.isEven
            ? IntegerNumber.one
            : IntegerNumber.negativeOne;
        result = sign.mul(iPow);
      } else {
        result = c.imaginary.powNumber(IntegerNumber(intExp))?.mul(iPow);
      }
    } else if (intExp.asInt case final expAsInt? when expAsInt.abs() <= 64) {
      result = _complexIntPow(c, expAsInt);
    }
    if (result == null) return null;
    if (isFloat) {
      return switch (result) {
        final RealNumeric r => RealNumber(r.toDouble()),
        ComplexNumber(:final real, :final imaginary) => ComplexNumber.of(
          RealNumber(real.toDouble()),
          RealNumber(imaginary.toDouble()),
        ),
      };
    }
    return result;
  }

  static Number? _powReal(RealNumeric baseReal, RealNumeric exponent) {
    if (baseReal.isZero) {
      if (exponent.isZero) {
        return (baseReal is RealNumber || exponent is RealNumber)
            ? const RealNumber(1.0)
            : IntegerNumber.one;
      }
      if (exponent.isNegative) {
        throw UnsupportedError('Division by zero in power: 0 ^ $exponent');
      }
      return const RealNumber(0.0);
    }
    if (baseReal.isOne) {
      return (baseReal is RealNumber || exponent is RealNumber)
          ? const RealNumber(1.0)
          : IntegerNumber.one;
    }
    final bVal = baseReal.toDouble();
    final eVal = exponent.toDouble();
    if (bVal < 0 && eVal != eVal.roundToDouble()) {
      return null;
    }
    final res = math.pow(bVal, eVal).toDouble();
    return res.isFinite ? RealNumber(res) : null;
  }

  static (RealNumeric, RealNumeric) _components(Number n) => switch (n) {
    RealNumeric() => (n, IntegerNumber.zero),
    ComplexNumber(:final real, :final imaginary) => (real, imaginary),
  };

  static RealNumeric _addReal(RealNumeric a, RealNumeric b) {
    if (a is RationalNumber && b is RationalNumber) {
      return a.addRational(b);
    }
    return RealNumber(a.toDouble() + b.toDouble());
  }

  static RealNumeric _subReal(RealNumeric a, RealNumeric b) =>
      _addReal(a, b.neg());

  static RealNumeric _mulReal(RealNumeric a, RealNumeric b) {
    if (a is RationalNumber && b is RationalNumber) {
      if (a.isZero || b.isZero) {
        return IntegerNumber.zero;
      }
      return a.mulRational(b);
    }
    return RealNumber(a.toDouble() * b.toDouble());
  }

  static RealNumeric _divReal(RealNumeric a, RealNumeric b) {
    if (a is RationalNumber && b is RationalNumber) {
      if (a.isZero) return IntegerNumber.zero;
      return a.divRational(b);
    }
    return RealNumber(a.toDouble() / b.toDouble());
  }

  static Number _complexIntPow(ComplexNumber base, int exponent) {
    var exp = exponent.abs();
    Number result = IntegerNumber.one;
    Number current = base;
    while (exp > 0) {
      if (exp.isOdd) {
        result = result.mul(current);
      }
      exp >>= 1;
      if (exp > 0) {
        current = current.mul(current);
      }
    }
    return exponent < 0 ? IntegerNumber.one.div(result) : result;
  }

  /// If [n] can be written as $b^k$ for integer $b \ge 2$ and maximal integer $k \ge 2$,
  /// returns `(b, k)`; otherwise returns `null`.
  static (Integer, int)? integerPower(Integer n) {
    if (n.isNegative || n.isZero || n.isOne) return null;
    final maxK = switch (n.asInt) {
      final int nInt when nInt <= 3 => 1,
      final int nInt => (math.log(nInt) / math.ln2 + 1e-12).floor(),
      _ => n.toBigInt().bitLength - 1,
    };
    for (var k = maxK; k >= 2; k--) {
      final root = _exactIntegerRoot(n, k);
      if (root != null && root > Integer.one) {
        return (root, k);
      }
    }
    return null;
  }

  static Integer? _exactIntegerRoot(Integer n, int q) {
    if (n.isNegative || q <= 0) return null;
    if (n.isZero) return Integer.zero;
    if (n.isOne || q == 1) return n;
    if (!n.isBig) {
      final nInt = n.asInt;
      if (nInt != null) {
        final approx = math.pow(nInt, 1.0 / q);
        if (approx.isFinite) {
          final rInt = approx.round();
          final candidate = Integer.from(rInt);
          if (candidate.pow(q) == n) return candidate;
          if (rInt > 0) {
            final lower = Integer.from(rInt - 1);
            if (lower.pow(q) == n) return lower;
          }
          final upper = Integer.from(rInt + 1);
          if (upper.pow(q) == n) return upper;
          return null;
        }
      }
    }
    final bigN = n.toBigInt();
    final r = _bigIntNthRoot(bigN, q);
    if (r != null && r.pow(q) == bigN) {
      return Integer.big(r);
    }
    return null;
  }

  static BigInt? _bigIntNthRoot(BigInt n, int q) {
    if (q <= 0) return null;
    if (q == 1) return n;
    if (q >= n.bitLength) return null;
    var x = BigInt.one << ((n.bitLength + q - 1) ~/ q + 1);
    final bigQ = BigInt.from(q);
    final bigQMinus1 = BigInt.from(q - 1);
    while (true) {
      final xPowQMinus1 = x.pow(q - 1);
      if (xPowQMinus1 == BigInt.zero) return null;
      final next = (bigQMinus1 * x + n ~/ xPowQMinus1) ~/ bigQ;
      if (next >= x) break;
      x = next;
    }
    return x;
  }
}

/// Base class for real-valued numeric literals ([RationalNumber] and [RealNumber]).
sealed class RealNumeric extends Number implements Comparable<RealNumeric> {
  /// Creates a real-valued numeric literal.
  const new();

  /// Whether this number is strictly less than zero ($< 0$).
  bool get isNegative;

  /// Returns the sign of this number: `-1` if negative, `0` if zero, `1` if positive.
  int get sign;

  @override
  RealNumeric get conjugate => this;

  @override
  RealNumeric neg();

  /// Returns the absolute value $|x|$ of this real number.
  RealNumeric abs() => isNegative ? neg() : this;

  @override
  Complex toComplex() => Complex(toDouble());

  @override
  int compareTo(RealNumeric other) => switch ((this, other)) {
    (final RationalNumber a, final RationalNumber b) => rationalCompare(
      a._parts,
      b._parts,
    ),
    (final RealNumber a, final RealNumber b) => a.value.compareTo(b.value),
    _ => switch (toDouble().compareTo(other.toDouble())) {
      0 => this is RationalNumber ? -1 : 1,
      final cmp => cmp,
    },
  };
}

/// Exact rational number $p / q \in \mathbb{Q}$, represented canonically as
/// either an [IntegerNumber] (when $q = 1$) or a reduced [FractionNumber]
/// (when $q > 1$ and $\gcd(|p|, q) = 1$).
sealed class RationalNumber extends RealNumeric {
  /// Creates a canonical rational number subclass.
  const new _();

  /// Creates an exact rational number from machine `int` [numerator] and
  /// [denominator], reducing by their greatest common divisor and returning
  /// an [IntegerNumber] when the reduced denominator is $1$.
  factory(int numerator, [int denominator = 1]) =>
      RationalNumber.of(Integer.from(numerator), Integer.from(denominator));

  /// Creates an exact rational number from a [Fraction].
  factory fromFraction(Fraction fraction) => RationalNumber.of(
    Integer.from(fraction.numerator),
    Integer.from(fraction.denominator),
  );

  /// Creates an exact rational number from arbitrary-precision [Integer]
  /// [numerator] and [denominator], reducing by their greatest common divisor
  /// and returning an [IntegerNumber] when the reduced denominator is $1$.
  factory of(Integer numerator, [Integer denominator = Integer.one]) {
    final norm = rationalNormalize(numerator, denominator);
    return norm.denominator.isOne
        ? IntegerNumber(norm.numerator)
        : FractionNumber(norm.numerator, norm.denominator);
  }

  factory _fromParts(RationalParts parts) => parts.denominator.isOne
      ? IntegerNumber(parts.numerator)
      : FractionNumber(parts.numerator, parts.denominator);

  /// The signed numerator $p$.
  Integer get numerator;

  /// The positive coprime denominator $q \ge 1$.
  Integer get denominator;

  RationalParts get _parts => (numerator: numerator, denominator: denominator);

  /// Whether this rational number is an integer ($q = 1$).
  bool get isInteger => this is IntegerNumber;

  @override
  bool get isZero => switch (this) {
    IntegerNumber(:final value) => value.isZero,
    FractionNumber() => false,
  };

  @override
  bool get isOne => switch (this) {
    IntegerNumber(:final value) => value.isOne,
    FractionNumber() => false,
  };

  @override
  bool get isNegativeOne => switch (this) {
    IntegerNumber(:final value) => value == Integer.negativeOne,
    FractionNumber() => false,
  };

  @override
  bool get isNegative => numerator.isNegative;

  @override
  int get sign => numerator.sign;

  /// Returns this rational as a machine `int` if it is an [IntegerNumber] that
  /// fits in a signed 64-bit integer, or `null` otherwise.
  int? get asInt => switch (this) {
    IntegerNumber(:final value) => value.asInt,
    FractionNumber() => null,
  };

  /// Truncates this rational number toward zero as a machine `int`.
  int toInt() => (numerator ~/ denominator).toInt();

  @override
  RationalNumber neg();

  @override
  RationalNumber abs() => isNegative ? neg() : this;

  /// Returns the multiplicative inverse $q / p$ of this rational number.
  RationalNumber reciprocal() =>
      RationalNumber._fromParts(rationalInvert(_parts));

  /// Exact rational sum `this + other`.
  RationalNumber addRational(RationalNumber other) =>
      RationalNumber._fromParts(rationalAdd(_parts, other._parts));

  /// Exact rational difference `this - other`.
  RationalNumber subRational(RationalNumber other) =>
      RationalNumber._fromParts(rationalSubtract(_parts, other._parts));

  /// Exact rational product `this * other`.
  RationalNumber mulRational(RationalNumber other) =>
      RationalNumber._fromParts(rationalMultiply(_parts, other._parts));

  /// Exact rational quotient `this / other`.
  RationalNumber divRational(RationalNumber other) =>
      RationalNumber._fromParts(rationalDivide(_parts, other._parts));

  /// Exact rational integer power `this ^ exponent`, or `null` if the result
  /// exceeds the maximum bit-length limit.
  RationalNumber? powInteger(int exponent) {
    final res = rationalPow(_parts, exponent);
    return res != null ? RationalNumber._fromParts(res) : null;
  }

  /// Returns the non-negative greatest common divisor of this rational number
  /// and [other]: $\gcd(p_1/q_1, p_2/q_2) = \frac{\gcd(p_1, p_2)}{\operatorname{lcm}(q_1, q_2)}$.
  RationalNumber gcd(RationalNumber other) {
    if (isZero && other.isZero) return IntegerNumber.zero;
    if (isZero) return other.abs();
    if (other.isZero) return abs();
    return RationalNumber.of(
      numerator.gcd(other.numerator),
      denominator.lcm(other.denominator),
    );
  }

  /// Returns the non-negative least common multiple of this rational number
  /// and [other]: $\operatorname{lcm}(p_1/q_1, p_2/q_2) = \frac{\operatorname{lcm}(p_1, p_2)}{\gcd(q_1, q_2)}$.
  RationalNumber lcm(RationalNumber other) {
    if (isZero || other.isZero) return IntegerNumber.zero;
    return RationalNumber.of(
      numerator.lcm(other.numerator),
      denominator.gcd(other.denominator),
    );
  }

  /// Whether this rational number is a prime integer ($q = 1$ and $p \ge 2$ is prime).
  bool get isPrime => switch (this) {
    IntegerNumber(:final value) => value.isPrime,
    FractionNumber() => false,
  };
}

/// Exact arbitrary-precision integer literal $n \in \mathbb{Z}$.
final class IntegerNumber extends RationalNumber {
  /// Creates an exact integer literal wrapping [value].
  const new(this.value) : super._();

  /// Creates an exact integer literal from a machine `int`.
  factory of(int value) => IntegerNumber(Integer.from(value));

  /// The additive identity $0$.
  static const zero = IntegerNumber(Integer.zero);

  /// The multiplicative identity $1$.
  static const one = IntegerNumber(Integer.one);

  /// The integer $2$.
  static const two = IntegerNumber(Integer.two);

  /// The integer $-1$.
  static const negativeOne = IntegerNumber(Integer.negativeOne);

  /// The underlying arbitrary-precision integer value.
  final Integer value;

  @override
  Integer get numerator => value;

  @override
  Integer get denominator => Integer.one;

  @override
  double toDouble() => value.toDouble();

  @override
  IntegerNumber neg() => IntegerNumber(-value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IntegerNumber && value == other.value);

  @override
  int get hashCode => Object.hash(IntegerNumber, value);
}

/// Exact reduced non-integer rational fraction $p / q$ with $q > 1$ and $\gcd(|p|, q) = 1$.
final class FractionNumber extends RationalNumber {
  /// Creates a reduced fraction with coprime [numerator] and [denominator] $> 1$.
  const new(this.numerator, this.denominator)
    : assert(
        denominator != Integer.zero && denominator != Integer.one,
        'FractionNumber denominator must be strictly greater than 1',
      ),
      super._();

  /// The fraction $1/2$.
  static const half = FractionNumber(Integer.one, Integer.two);

  /// The fraction $-1/2$.
  static const negativeHalf = FractionNumber(Integer.negativeOne, Integer.two);

  /// The fraction $1/3$.
  static const third = FractionNumber(Integer.one, Integer(3));

  /// The fraction $1/4$.
  static const quarter = FractionNumber(Integer.one, Integer(4));

  @override
  final Integer numerator;

  @override
  final Integer denominator;

  @override
  double toDouble() => numerator.toDouble() / denominator.toDouble();

  @override
  FractionNumber neg() => FractionNumber(-numerator, denominator);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FractionNumber &&
          numerator == other.numerator &&
          denominator == other.denominator);

  @override
  int get hashCode => Object.hash(FractionNumber, numerator, denominator);
}

/// Finite IEEE-754 floating-point real number literal.
///
/// Non-finite IEEE-754 values (`NaN`, `Infinity`, `-Infinity`) are prohibited
/// in [RealNumber] and are mapped via [RealNumber.fromDouble] to
/// [Constant.undefined] and $\pm$[Constant.infinity]. Negative zero (`-0.0`)
/// is canonicalized to `+0.0`.
final class RealNumber extends RealNumeric {
  /// Creates a finite real number literal.
  const new(double value)
    : assert(
        value == value &&
            value != double.infinity &&
            value != double.negativeInfinity,
        'RealNumber requires a finite value; use RealNumber.fromDouble for non-finite values',
      ),
      value = value == 0.0 ? 0.0 : value;

  /// Converts any IEEE-754 [double] into its canonical symbolic [Expr]:
  /// - `NaN` $\to$ [Constant.undefined]
  /// - `+Infinity` $\to$ [Constant.infinity]
  /// - `-Infinity` $\to$ `-Constant.infinity`
  /// - finite value $\to$ [RealNumber]
  static Expr fromDouble(double value) {
    if (value.isNaN) return Constant.undefined;
    if (value == double.infinity) return Constant.infinity;
    if (value == double.negativeInfinity) {
      return Mul(const [
        IntegerNumber.negativeOne,
        Constant.infinity,
      ], isSimplified: true);
    }
    return RealNumber(value);
  }

  /// The floating-point zero `0.0`.
  static const zero = RealNumber(0.0);

  /// The floating-point one `1.0`.
  static const one = RealNumber(1.0);

  /// The floating-point negative one `-1.0`.
  static const negativeOne = RealNumber(-1.0);

  /// The finite IEEE-754 floating-point value.
  final double value;

  @override
  bool get isZero => value == 0.0;

  @override
  bool get isOne => value == 1.0;

  @override
  bool get isNegativeOne => value == -1.0;

  @override
  bool get isNegative => value < 0.0;

  @override
  int get sign => value == 0.0 ? 0 : (value < 0.0 ? -1 : 1);

  @override
  double toDouble() => value;

  @override
  RealNumber neg() => RealNumber(-value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is RealNumber && value == other.value);

  @override
  int get hashCode => Object.hash(RealNumber, value);
}

/// Atomic complex number $a + b i$ with [RealNumeric] real and non-zero
/// imaginary parts.
final class ComplexNumber extends Number {
  /// Creates an atomic complex number with [real] part $a$ and non-zero
  /// [imaginary] part $b$.
  const new(this.real, this.imaginary);

  /// Constructs a canonical [Number] from [real] and [imaginary] components,
  /// automatically demoting to [real] when `imaginary.isZero`.
  static Number of(RealNumeric real, RealNumeric imaginary) =>
      imaginary.isZero ? real : ComplexNumber(real, imaginary);

  /// The imaginary unit $i = 0 + 1i$.
  static const i = ComplexNumber(IntegerNumber.zero, IntegerNumber.one);

  /// The negated imaginary unit $-i = 0 - 1i$.
  static const negativeI = ComplexNumber(
    IntegerNumber.zero,
    IntegerNumber.negativeOne,
  );

  /// The real component $\Re(z)$.
  final RealNumeric real;

  /// The non-zero imaginary component $\Im(z)$.
  final RealNumeric imaginary;

  /// Whether the real component is zero ($\Re(z) = 0$).
  bool get isPureImaginary => real.isZero;

  /// Floating-point [Complex] evaluation of this number.
  Complex get value => toComplex();

  @override
  bool get isZero => real.isZero && imaginary.isZero;

  @override
  bool get isOne => false;

  @override
  bool get isNegativeOne => false;

  @override
  bool get isReal => imaginary.isZero;

  @override
  Complex toComplex() => Complex(real.toDouble(), imaginary.toDouble());

  @override
  double toDouble() => throw UnsupportedError(
    'Complex number $this cannot be converted to a real double.',
  );

  @override
  ComplexNumber get conjugate => ComplexNumber(real, imaginary.neg());

  @override
  ComplexNumber neg() => ComplexNumber(real.neg(), imaginary.neg());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ComplexNumber &&
          real == other.real &&
          imaginary == other.imaginary);

  @override
  int get hashCode => Object.hash(ComplexNumber, real, imaginary);
}
