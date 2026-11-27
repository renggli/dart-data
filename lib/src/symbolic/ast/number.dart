part of '../ast.dart';

/// Base class for all atomic numeric literals in the symbolic AST.
///
/// The numeric tower consists of [RealNumeric] ([RationalNumber] — subdivided
/// into [IntegerNumber] and [FractionNumber] — and [RealNumber]) together with
/// [ComplexNumber] over [RealNumeric] components.
sealed class Number extends Expr {
  /// Creates an atomic numeric expression.
  const new();

  /// Default maximum bit length allowed for exact integer powers.
  static const int defaultMaxBitLength = 65536;

  @override
  int get nodeCount => 1;

  @override
  int get structuralTag => 0;

  /// Whether this number is identically zero (`0`).
  bool get isZero;

  /// Whether this number is identically one (`1`).
  bool get isOne;

  /// Whether this number is identically negative one (`-1`).
  bool get isNegativeOne;

  /// Converts this number to a real IEEE-754 floating-point value.
  ///
  /// Throws an [UnsupportedError] if this is a [ComplexNumber] with a non-zero
  /// imaginary component.
  double toDouble();

  /// Converts this number to a floating-point [Complex] value.
  Complex toComplex();

  /// Returns the complex conjugate `conj(z)` of this number.
  Number get conjugate;

  /// Returns the additive inverse `-z` of this number.
  Number neg();

  /// Returns the exact or contagion-promoted sum `this + other`.
  Number add(Number other) {
    if (this case final RationalNumber a when other is RationalNumber) {
      return a.addRational(other);
    }
    if ((this, other) case (final RealNumeric a, final RealNumeric b)) {
      return _addReal(a, b);
    }
    final (ar, ai) = _components(this);
    final (br, bi) = _components(other);
    return ComplexNumber.of(_addReal(ar, br), _addReal(ai, bi));
  }

  /// Returns the exact or contagion-promoted difference `this - other`.
  Number sub(Number other) {
    if (this case final RationalNumber a when other is RationalNumber) {
      return a.subRational(other);
    }
    return add(other.neg());
  }

  /// Returns the exact or contagion-promoted product `this * other`.
  Number mul(Number other) {
    if (this case final RationalNumber a when other is RationalNumber) {
      return a.mulRational(other);
    }
    if ((this, other) case (final RealNumeric a, final RealNumeric b)) {
      return _mulReal(a, b);
    }
    final (ar, ai) = _components(this);
    final (br, bi) = _components(other);
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
    if (ar is RationalNumber &&
        ai is RationalNumber &&
        br is RationalNumber &&
        bi is RationalNumber) {
      final denom = br.mulRational(br).addRational(bi.mulRational(bi));
      if (denom.isZero) {
        throw UnsupportedError('Division by zero: $this / $other');
      }
      final realNum = ar.mulRational(br).addRational(ai.mulRational(bi));
      final imagNum = ai.mulRational(br).subRational(ar.mulRational(bi));
      return ComplexNumber.of(
        realNum.divRational(denom),
        imagNum.divRational(denom),
      );
    }
    final arD = ar.toDouble();
    final aiD = ai.toDouble();
    final brD = br.toDouble();
    final biD = bi.toDouble();
    if (brD == 0.0 && biD == 0.0) {
      throw UnsupportedError('Division by zero: $this / $other');
    }
    final double realOut;
    final double imagOut;
    if (brD.abs() >= biD.abs()) {
      final ratio = biD / brD;
      final denom = brD + biD * ratio;
      realOut = (arD + aiD * ratio) / denom;
      imagOut = (aiD - arD * ratio) / denom;
    } else {
      final ratio = brD / biD;
      final denom = brD * ratio + biD;
      realOut = (arD * ratio + aiD) / denom;
      imagOut = (aiD * ratio - arD) / denom;
    }
    if (!realOut.isFinite || !imagOut.isFinite) {
      throw UnsupportedError(
        'Floating-point overflow in division: $this / $other',
      );
    }
    return ComplexNumber.of(RealNumber(realOut), RealNumber(imagOut));
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
    if (exponent.asInt case final expInt?) {
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
    if (baseRat.isNegative && exponent.denominator.isEven) return null;
    if (exponent.denominator <= _maxRootOrder &&
        exponent.numerator.abs() <= _maxRootOrder) {
      final q = exponent.denominator.toInt();
      final p = exponent.numerator.toInt();
      if (exactIntegerRoot(baseRat.numerator.abs(), q) case final rootNum?) {
        if (exactIntegerRoot(baseRat.denominator, q) case final rootDen?) {
          final signedNum = baseRat.isNegative ? -rootNum : rootNum;
          return RationalNumber.of(signedNum, rootDen).powInteger(p);
        }
      }
    }
    return null;
  }

  static final _maxRootOrder = BigInt.from(1024);

  static Number? _powComplex(ComplexNumber c, Number exponent) {
    final intExp = switch (exponent) {
      IntegerNumber(:final value) => value,
      RealNumber(:final value)
          when value == value.roundToDouble() &&
              value.abs() < 9007199254740992.0 =>
        BigInt.from(value.round()),
      _ => null,
    };
    if (intExp == null) return null;
    final isFloat =
        exponent is RealNumber ||
        c.real is RealNumber ||
        c.imaginary is RealNumber;
    if (intExp == BigInt.zero) {
      return isFloat ? RealNumber.one : IntegerNumber.one;
    }
    Number? result;
    if (c.isPureImaginary) {
      final mod = (intExp % _four).toInt();
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
    } else if (intExp.abs() <= _maxRootOrder) {
      result = _complexIntPow(c, intExp.toInt());
    }
    if (result == null) return null;
    if (isFloat) {
      switch (result) {
        case final RealNumeric r:
          final v = r.toDouble();
          return v.isFinite ? RealNumber(v) : null;
        case ComplexNumber(:final real, :final imaginary):
          final vr = real.toDouble();
          final vi = imaginary.toDouble();
          return (vr.isFinite && vi.isFinite)
              ? ComplexNumber.of(RealNumber(vr), RealNumber(vi))
              : null;
      }
    }
    return result;
  }

  static final _four = BigInt.from(4);

  static Number? _powReal(RealNumeric baseReal, RealNumeric exponent) {
    if (baseReal.isZero) {
      if (exponent.isZero) return RealNumber.one;
      if (exponent.isNegative) {
        throw UnsupportedError('Division by zero in power: 0 ^ $exponent');
      }
      return RealNumber.zero;
    }
    if (baseReal.isOne) return RealNumber.one;
    final bVal = baseReal.toDouble();
    if (bVal == -1.0 && exponent is IntegerNumber) {
      return exponent.value.isEven ? RealNumber.one : RealNumber.negativeOne;
    }
    final eVal = exponent.toDouble();
    if (bVal < 0 && eVal != eVal.roundToDouble()) return null;
    final res = math.pow(bVal, eVal).toDouble();
    return res.isFinite ? RealNumber(res) : null;
  }

  static (RealNumeric, RealNumeric) _components(Number n) => switch (n) {
    RealNumeric() => (
      n,
      n is RealNumber ? RealNumber.zero : IntegerNumber.zero,
    ),
    ComplexNumber(:final real, :final imaginary) => (real, imaginary),
  };

  static RealNumeric _addReal(RealNumeric a, RealNumeric b) {
    if (a is RationalNumber && b is RationalNumber) {
      return a.addRational(b);
    }
    final sum = a.toDouble() + b.toDouble();
    if (!sum.isFinite) {
      throw UnsupportedError('Floating-point overflow in addition: $a + $b');
    }
    return RealNumber(sum);
  }

  static RealNumeric _subReal(RealNumeric a, RealNumeric b) =>
      _addReal(a, b.neg());

  static RealNumeric _mulReal(RealNumeric a, RealNumeric b) {
    if (a is RationalNumber && b is RationalNumber) {
      if (a.isZero || b.isZero) return IntegerNumber.zero;
      return a.mulRational(b);
    }
    if (a.isZero || b.isZero) return RealNumber.zero;
    final prod = a.toDouble() * b.toDouble();
    if (!prod.isFinite) {
      throw UnsupportedError(
        'Floating-point overflow in multiplication: $a * $b',
      );
    }
    return RealNumber(prod);
  }

  static RealNumeric _divReal(RealNumeric a, RealNumeric b) {
    if (a is RationalNumber && b is RationalNumber) {
      if (a.isZero) return IntegerNumber.zero;
      return a.divRational(b);
    }
    if (b.isZero) throw UnsupportedError('Division by zero: $a / $b');
    if (a.isZero) return RealNumber.zero;
    final quot = a.toDouble() / b.toDouble();
    if (!quot.isFinite) {
      throw UnsupportedError('Floating-point overflow in division: $a / $b');
    }
    return RealNumber(quot);
  }

  static Number _complexIntPow(ComplexNumber base, int exponent) {
    var exp = exponent.abs();
    Number result = IntegerNumber.one;
    Number current = base;
    while (exp > 0) {
      if (exp.isOdd) result = result.mul(current);
      exp >>= 1;
      if (exp > 0) current = current.mul(current);
    }
    return exponent < 0 ? IntegerNumber.one.div(result) : result;
  }

  /// Computes `base^exponent`, returning `null` if the result exceeds
  /// [maxBitLength] bits.
  static BigInt? bigIntPow(
    BigInt base,
    int exponent, {
    int maxBitLength = defaultMaxBitLength,
  }) {
    if (exponent < 0) {
      throw ArgumentError.value(exponent, 'exponent', 'Must be non-negative');
    }
    if (exponent == 0) return BigInt.one;
    if (base == BigInt.zero || base == BigInt.one || exponent == 1) return base;
    if (base == -BigInt.one) return exponent.isEven ? BigInt.one : base;
    final bits = base.abs().bitLength;
    if (exponent > maxBitLength ||
        (bits > 1 && exponent > (maxBitLength - 1) ~/ (bits - 1))) {
      return null;
    }
    final result = base.pow(exponent);
    return result.abs().bitLength > maxBitLength ? null : result;
  }

  /// If [n] can be written as `b^k` for integer `b >= 2` and maximal `k >= 2`,
  /// returns `(b, k)`; otherwise returns `null`.
  static (BigInt, int)? integerPower(BigInt n) {
    if (n <= BigInt.one) return null;
    final maxK = n.bitLength - 1;
    for (var k = maxK; k >= 2; k--) {
      final root = exactIntegerRoot(n, k);
      if (root != null && root > BigInt.one) return (root, k);
    }
    return null;
  }

  /// Returns the exact non-negative [q]-th integer root of [n], or `null` if
  /// [n] is not a perfect [q]-th power.
  static BigInt? exactIntegerRoot(BigInt n, int q) {
    if (n.isNegative || q <= 0) return null;
    if (n == BigInt.zero) return BigInt.zero;
    if (n == BigInt.one || q == 1) return n;
    if (q >= n.bitLength) return null;
    if (n.bitLength <= 52) {
      final nInt = n.toInt();
      final approx = math.pow(nInt, 1.0 / q);
      if (approx.isFinite) {
        final rInt = approx.round();
        for (final cand in [rInt, if (rInt > 0) rInt - 1, rInt + 1]) {
          final bigCand = BigInt.from(cand);
          if (bigCand.pow(q) == n) return bigCand;
        }
        return null;
      }
    }
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
    return x.pow(q) == n ? x : null;
  }
}

/// Base class for real-valued numeric literals ([RationalNumber] and [RealNumber]).
sealed class RealNumeric extends Number implements Comparable<RealNumeric> {
  /// Creates a real-valued numeric literal.
  const new();

  /// Whether this number is strictly less than zero (`< 0`).
  bool get isNegative;

  /// Returns `-1` if negative, `0` if zero, or `1` if positive.
  int get sign;

  @override
  RealNumeric get conjugate => this;

  @override
  RealNumeric neg();

  /// Returns the absolute value `|x|` of this real number.
  RealNumeric abs() => isNegative ? neg() : this;

  @override
  Complex toComplex() => Complex(toDouble());

  @override
  int compareTo(RealNumeric other) => switch ((this, other)) {
    (final IntegerNumber a, final IntegerNumber b)
        when a._big == null && b._big == null =>
      a._small.compareTo(b._small),
    (final RationalNumber a, final RationalNumber b) => _compareRationals(a, b),
    (final RealNumber a, final RealNumber b) => a.value.compareTo(b.value),
    (final RationalNumber r, final RealNumber f) => _compareRationalReal(r, f),
    (final RealNumber f, final RationalNumber r) => -_compareRationalReal(r, f),
  };
}

/// Exact rational number `p / q in Q`, represented canonically as
/// [IntegerNumber] when `q = 1` or [FractionNumber] when `q > 1`.
sealed class RationalNumber extends RealNumeric {
  /// Creates a canonical rational number subclass.
  const new _();

  /// Creates an exact rational number from machine `int` [numerator] and
  /// [denominator], reducing by their greatest common divisor.
  factory(int numerator, [int denominator = 1]) {
    if (numerator >= -_maxSafeInt &&
        numerator <= _maxSafeInt &&
        denominator >= -_maxSafeInt &&
        denominator <= _maxSafeInt) {
      if (denominator == 0) {
        throw UnsupportedError('Division by zero');
      }
      if (numerator == 0) return IntegerNumber.zero;
      if (denominator == 1) return IntegerNumber.of(numerator);
      var num = numerator;
      var den = denominator;
      if (den < 0) {
        num = -num;
        den = -den;
      }
      if (den == 1) return IntegerNumber.of(num);
      final g = _intGcd(num, den);
      if (g != 1) {
        num ~/= g;
        den ~/= g;
      }
      return den == 1 ? IntegerNumber.of(num) : FractionNumber._small(num, den);
    }
    return RationalNumber.of(
      BigInt.from(numerator),
      denominator == 1 ? null : BigInt.from(denominator),
    );
  }

  /// Creates an exact rational number from a [Fraction].
  factory fromFraction(Fraction fraction) => RationalNumber.of(
    BigInt.from(fraction.numerator),
    BigInt.from(fraction.denominator),
  );

  /// Creates an exact rational number from [BigInt] [numerator] and optional
  /// [denominator], reducing by their greatest common divisor.
  factory of(BigInt numerator, [BigInt? denominator]) {
    final den = denominator ?? BigInt.one;
    if (den == BigInt.zero) {
      throw UnsupportedError('Division by zero');
    }
    if (numerator == BigInt.zero) return IntegerNumber.zero;
    if (den == BigInt.one) return IntegerNumber(numerator);
    final rawDiv = _bigIntGcd(numerator, den);
    final divisor = den.isNegative ? -rawDiv : rawDiv;
    final normNum = divisor == BigInt.one ? numerator : numerator ~/ divisor;
    final normDen = divisor == BigInt.one ? den : den ~/ divisor;
    return normDen == BigInt.one
        ? IntegerNumber(normNum)
        : FractionNumber._normalized(normNum, normDen);
  }

  /// The signed numerator `p`.
  BigInt get numerator;

  /// The positive coprime denominator `q >= 1`.
  BigInt get denominator;

  @override
  int get flags => kFlagSimplified;

  /// Whether this rational number is an integer (`q = 1`).
  bool get isInteger => this is IntegerNumber;

  @override
  bool get isZero => switch (this) {
    IntegerNumber(:final _small, :final _big) => _big == null && _small == 0,
    FractionNumber() => false,
  };

  @override
  bool get isOne => switch (this) {
    IntegerNumber(:final _small, :final _big) => _big == null && _small == 1,
    FractionNumber() => false,
  };

  @override
  bool get isNegativeOne => switch (this) {
    IntegerNumber(:final _small, :final _big) => _big == null && _small == -1,
    FractionNumber() => false,
  };

  @override
  bool get isNegative => switch (this) {
    IntegerNumber(:final _small, :final _big) =>
      _big == null ? _small < 0 : _big.isNegative,
    FractionNumber(:final _smallNum, :final _bigNum) =>
      _bigNum == null ? _smallNum < 0 : _bigNum.isNegative,
  };

  @override
  int get sign => switch (this) {
    IntegerNumber(:final _small, :final _big) =>
      _big == null ? _small.sign : _big.sign,
    FractionNumber(:final _smallNum, :final _bigNum) =>
      _bigNum == null ? _smallNum.sign : _bigNum.sign,
  };

  /// Returns this rational as a platform-safe machine `int` if it is an
  /// [IntegerNumber] within `[-(2^53 - 1), 2^53 - 1]`, or `null` otherwise.
  int? get asInt;

  /// Truncates this rational number toward zero as a platform-safe `int`.
  int toInt() {
    if (this case IntegerNumber(:final _small, :final _big)) {
      if (_big == null) return _small;
      throw StateError('$_big exceeds the safe integer range');
    }
    final q = numerator ~/ denominator;
    if (q < _negMaxSafeBig || q > _posMaxSafeBig) {
      throw StateError('$q exceeds the safe integer range');
    }
    return q.toInt();
  }

  @override
  RationalNumber neg();

  @override
  RationalNumber abs() => isNegative ? neg() : this;

  /// Returns the multiplicative inverse `q / p`.
  RationalNumber reciprocal() {
    if (this case IntegerNumber(:final _small, :final _big)) {
      if (_big == null) {
        if (_small == 0) throw UnsupportedError('Division by zero');
        if (_small == 1 || _small == -1) return this;
        return _small < 0
            ? FractionNumber._small(-1, -_small)
            : FractionNumber._small(1, _small);
      }
      return _big.isNegative
          ? FractionNumber._big(-BigInt.one, -_big)
          : FractionNumber._big(BigInt.one, _big);
    }
    final frac = this as FractionNumber;
    if (frac._bigDen == null) {
      final n = frac._smallNum;
      final d = frac._smallDen;
      return n < 0 ? _fromSafeInts(-d, -n) : _fromSafeInts(d, n);
    }
    final n = frac.numerator;
    final d = frac.denominator;
    return n.isNegative
        ? RationalNumber._fromNormalized(-d, -n)
        : RationalNumber._fromNormalized(d, n);
  }

  static RationalNumber _fromSafeInts(int num, int den) =>
      den == 1 ? IntegerNumber.of(num) : FractionNumber._small(num, den);

  static RationalNumber _fromNormalized(BigInt num, BigInt den) =>
      den == BigInt.one
      ? IntegerNumber(num)
      : FractionNumber._normalized(num, den);

  /// Exact rational sum `this + other`.
  RationalNumber addRational(RationalNumber other) {
    if (this is IntegerNumber && other is IntegerNumber) {
      final a = this as IntegerNumber;
      final b = other;
      if (a._big == null && b._big == null) {
        if (a._small == 0) return b;
        if (b._small == 0) return a;
        if (a._small >= -_addSafeBound &&
            a._small <= _addSafeBound &&
            b._small >= -_addSafeBound &&
            b._small <= _addSafeBound) {
          return IntegerNumber.of(a._small + b._small);
        }
        return IntegerNumber(BigInt.from(a._small) + BigInt.from(b._small));
      }
      return IntegerNumber(a.value + b.value);
    }
    if (isZero) return other;
    if (other.isZero) return this;
    final aSmall = _asSafePair(this);
    final bSmall = _asSafePair(other);
    if (aSmall != null && bSmall != null) {
      final (an, ad) = aSmall;
      final (bn, bd) = bSmall;
      if (an >= -_mulSafeBound &&
          an <= _mulSafeBound &&
          ad <= _mulSafeBound &&
          bn >= -_mulSafeBound &&
          bn <= _mulSafeBound &&
          bd <= _mulSafeBound) {
        final div = _intGcd(ad, bd);
        if (div == 1) {
          final num = an * bd + bn * ad;
          return num == 0
              ? IntegerNumber.zero
              : FractionNumber._small(num, ad * bd);
        }
        final bdDiv = bd ~/ div;
        final adDiv = ad ~/ div;
        final num = an * bdDiv + bn * adDiv;
        if (num == 0) return IntegerNumber.zero;
        final red = _intGcd(num, div);
        return _fromSafeInts(num ~/ red, adDiv * (bd ~/ red));
      }
    }
    final divisor = _bigIntGcd(denominator, other.denominator);
    if (divisor == BigInt.one) {
      return RationalNumber._fromNormalized(
        numerator * other.denominator + other.numerator * denominator,
        denominator * other.denominator,
      );
    }
    final num =
        numerator * (other.denominator ~/ divisor) +
        other.numerator * (denominator ~/ divisor);
    if (num == BigInt.zero) return IntegerNumber.zero;
    final reduction = _bigIntGcd(num, divisor);
    return RationalNumber._fromNormalized(
      num ~/ reduction,
      (denominator ~/ divisor) * (other.denominator ~/ reduction),
    );
  }

  /// Exact rational difference `this - other`.
  RationalNumber subRational(RationalNumber other) {
    if (this is IntegerNumber && other is IntegerNumber) {
      final a = this as IntegerNumber;
      final b = other;
      if (a._big == null &&
          b._big == null &&
          a._small >= -_addSafeBound &&
          a._small <= _addSafeBound &&
          b._small >= -_addSafeBound &&
          b._small <= _addSafeBound) {
        return IntegerNumber.of(a._small - b._small);
      }
    }
    return addRational(other.neg());
  }

  /// Exact rational product `this * other`.
  RationalNumber mulRational(RationalNumber other) {
    if (isZero || other.isZero) return IntegerNumber.zero;
    if (this is IntegerNumber && other is IntegerNumber) {
      final a = this as IntegerNumber;
      final b = other;
      if (a._big == null && b._big == null) {
        if (a._small == 1) return b;
        if (b._small == 1) return a;
        if (a._small >= -_mulSafeBound &&
            a._small <= _mulSafeBound &&
            b._small >= -_mulSafeBound &&
            b._small <= _mulSafeBound) {
          return IntegerNumber.of(a._small * b._small);
        }
      }
      return IntegerNumber(a.value * b.value);
    }
    final aSmall = _asSafePair(this);
    final bSmall = _asSafePair(other);
    if (aSmall != null && bSmall != null) {
      final (an, ad) = aSmall;
      final (bn, bd) = bSmall;
      if (an >= -_mulSafeBound &&
          an <= _mulSafeBound &&
          ad <= _mulSafeBound &&
          bn >= -_mulSafeBound &&
          bn <= _mulSafeBound &&
          bd <= _mulSafeBound) {
        final first = _intGcd(an, bd);
        final second = _intGcd(bn, ad);
        return _fromSafeInts(
          (an ~/ first) * (bn ~/ second),
          (ad ~/ second) * (bd ~/ first),
        );
      }
    }
    final first = _bigIntGcd(numerator, other.denominator);
    final second = _bigIntGcd(other.numerator, denominator);
    final n1 = first == BigInt.one ? numerator : numerator ~/ first;
    final d2 = first == BigInt.one
        ? other.denominator
        : other.denominator ~/ first;
    final n2 = second == BigInt.one
        ? other.numerator
        : other.numerator ~/ second;
    final d1 = second == BigInt.one ? denominator : denominator ~/ second;
    return RationalNumber._fromNormalized(n1 * n2, d1 * d2);
  }

  /// Exact rational quotient `this / other`.
  RationalNumber divRational(RationalNumber other) =>
      mulRational(other.reciprocal());

  /// Exact rational integer power `this ^ exponent`, or `null` if the result
  /// exceeds [maxBitLength].
  RationalNumber? powInteger(
    int exponent, {
    int maxBitLength = Number.defaultMaxBitLength,
  }) {
    if (exponent == 0) return IntegerNumber.one;
    if (isZero) {
      if (exponent < 0) throw UnsupportedError('Division by zero');
      return IntegerNumber.zero;
    }
    if (isOne) return IntegerNumber.one;
    if (isNegativeOne) {
      return exponent.isEven ? IntegerNumber.one : IntegerNumber.negativeOne;
    }
    final base = exponent < 0 ? reciprocal() : this;
    if (exponent < 0 && -exponent < 0) return null;
    final mag = exponent.abs();
    if (mag == 1) return base;
    if (mag == 2) {
      if (_asSafePair(base) case (final n, final d)
          when n >= -_mulSafeBound &&
              n <= _mulSafeBound &&
              d <= _mulSafeBound) {
        return _fromSafeInts(n * n, d * d);
      }
    }
    final num = Number.bigIntPow(
      base.numerator,
      mag,
      maxBitLength: maxBitLength,
    );
    if (num == null) return null;
    final den = Number.bigIntPow(
      base.denominator,
      mag,
      maxBitLength: maxBitLength,
    );
    if (den == null) return null;
    return RationalNumber._fromNormalized(num, den);
  }

  /// Non-negative GCD: `gcd(p_1/q_1, p_2/q_2) = gcd(p_1, p_2) / lcm(q_1, q_2)`.
  RationalNumber gcd(RationalNumber other) {
    if (isZero && other.isZero) return IntegerNumber.zero;
    if (isZero) return other.abs();
    if (other.isZero) return abs();
    return RationalNumber.of(
      _bigIntGcd(numerator, other.numerator),
      denominator.lcm(other.denominator),
    );
  }

  /// Non-negative LCM: `lcm(p_1/q_1, p_2/q_2) = lcm(p_1, p_2) / gcd(q_1, q_2)`.
  RationalNumber lcm(RationalNumber other) {
    if (isZero || other.isZero) return IntegerNumber.zero;
    return RationalNumber.of(
      numerator.lcm(other.numerator),
      _bigIntGcd(denominator, other.denominator),
    );
  }

  /// Whether this rational number is a prime integer (`q = 1` and `p >= 2` prime).
  bool get isPrime => switch (this) {
    IntegerNumber(:final value) => value.isProbablyPrime,
    FractionNumber() => false,
  };
}

/// Exact arbitrary-precision integer literal `n in Z` with unboxed fast path
/// for safe integers and [BigInt] overflow fallback.
final class IntegerNumber extends RationalNumber {
  /// Returns an [IntegerNumber] for [value], reusing cached singletons for
  /// small integers in `-16..256` and unboxed storage within `+/-(2^53 - 1)`.
  factory(BigInt value) {
    if (value >= _negMaxSafeBig && value <= _posMaxSafeBig) {
      return IntegerNumber.of(value.toInt());
    }
    return IntegerNumber._bigAlloc(value);
  }

  const new _smallConst(this._small) : _big = null, super._();

  new _bigAlloc(BigInt value) : _small = 0, _big = value, super._();

  /// Creates an exact integer literal from a machine `int`.
  factory of(int value) {
    if (value >= _cacheMin && value <= _cacheMax) {
      return _smallCache[value - _cacheMin];
    }
    if (value >= -_maxSafeInt && value <= _maxSafeInt) {
      return IntegerNumber._smallConst(value);
    }
    return IntegerNumber._bigAlloc(BigInt.from(value));
  }

  /// Parses an integer literal from [source].
  factory parse(String source) {
    if (source.length <= 15) {
      final parsed = int.tryParse(source);
      if (parsed != null && parsed >= -_maxSafeInt && parsed <= _maxSafeInt) {
        return IntegerNumber.of(parsed);
      }
    }
    return IntegerNumber(BigInt.parse(source));
  }

  static const int _cacheMin = -16;
  static const int _cacheMax = 256;
  static final List<IntegerNumber> _smallCache = List<IntegerNumber>.generate(
    _cacheMax - _cacheMin + 1,
    (i) => IntegerNumber._smallConst(i + _cacheMin),
    growable: false,
  );

  /// The additive identity `0`.
  static final zero = IntegerNumber.of(0);

  /// The multiplicative identity `1`.
  static final one = IntegerNumber.of(1);

  /// The integer `2`.
  static final two = IntegerNumber.of(2);

  /// The integer `-1`.
  static final negativeOne = IntegerNumber.of(-1);

  final int _small;
  final BigInt? _big;

  /// The underlying arbitrary-precision [BigInt] value.
  BigInt get value => _big ?? BigInt.from(_small);

  @override
  BigInt get numerator => _big ?? BigInt.from(_small);

  @override
  BigInt get denominator => BigInt.one;

  @override
  int? get asInt => _big == null ? _small : null;

  /// Formats this integer without allocating a [BigInt] when in safe range.
  String formatText() => _big == null ? '$_small' : '$_big';

  @override
  double toDouble() => _big == null ? _small.toDouble() : _big.toDouble();

  @override
  IntegerNumber neg() =>
      _big == null ? IntegerNumber.of(-_small) : IntegerNumber._bigAlloc(-_big);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IntegerNumber &&
          (_big == null
              ? (other._big == null && _small == other._small)
              : _big == other._big));

  @override
  int get hashCode => _big == null
      ? Object.hash(IntegerNumber, _small)
      : Object.hash(IntegerNumber, _big);
}

/// Exact reduced non-integer rational fraction `p / q` with `q > 1` and
/// `gcd(|p|, q) = 1`.
final class FractionNumber extends RationalNumber {
  /// Creates a reduced fraction with coprime [numerator] and [denominator] `> 1`.
  factory(BigInt numerator, BigInt denominator) {
    assert(
      denominator > BigInt.one &&
          _bigIntGcd(numerator, denominator) == BigInt.one,
      'FractionNumber must be reduced with denominator > 1',
    );
    return FractionNumber._normalized(numerator, denominator);
  }

  factory _normalized(BigInt numerator, BigInt denominator) {
    if (denominator <= _posMaxSafeBig &&
        numerator >= _negMaxSafeBig &&
        numerator <= _posMaxSafeBig) {
      return FractionNumber._small(numerator.toInt(), denominator.toInt());
    }
    return FractionNumber._big(numerator, denominator);
  }

  const new _small(this._smallNum, this._smallDen)
    : _bigNum = null,
      _bigDen = null,
      super._();

  new _big(BigInt numerator, BigInt denominator)
    : _smallNum = 0,
      _smallDen = 0,
      _bigNum = numerator,
      _bigDen = denominator,
      super._();

  /// The fraction `1/2`.
  static const half = FractionNumber._small(1, 2);

  /// The fraction `-1/2`.
  static const negativeHalf = FractionNumber._small(-1, 2);

  /// The fraction `1/3`.
  static const third = FractionNumber._small(1, 3);

  /// The fraction `1/4`.
  static const quarter = FractionNumber._small(1, 4);

  final int _smallNum;
  final int _smallDen;
  final BigInt? _bigNum;
  final BigInt? _bigDen;

  @override
  BigInt get numerator => _bigNum ?? BigInt.from(_smallNum);

  @override
  BigInt get denominator => _bigDen ?? BigInt.from(_smallDen);

  @override
  int? get asInt => null;

  /// Whether this fraction equals `1/2`.
  bool get isHalf => _bigDen == null && _smallNum == 1 && _smallDen == 2;

  /// Formats this fraction as `p/q` without allocating [BigInt]s when safe.
  String formatText() =>
      _bigDen == null ? '$_smallNum/$_smallDen' : '$_bigNum/$_bigDen';

  @override
  double toDouble() {
    if (_bigDen == null) {
      return _smallNum / _smallDen;
    }
    final num = _bigNum!;
    final den = _bigDen;
    if (num.bitLength < 1024 && den.bitLength < 1024) {
      return num.toDouble() / den.toDouble();
    }
    final shift = math.max(num.bitLength, den.bitLength) - 53;
    final scaledNum = (num >> shift).toDouble();
    final scaledDen = (den >> shift).toDouble();
    return scaledNum / scaledDen;
  }

  @override
  FractionNumber neg() => _bigDen == null
      ? FractionNumber._small(-_smallNum, _smallDen)
      : FractionNumber._big(-_bigNum!, _bigDen);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FractionNumber &&
          (_bigDen == null
              ? (other._bigDen == null &&
                    _smallNum == other._smallNum &&
                    _smallDen == other._smallDen)
              : (_bigDen == other._bigDen && _bigNum == other._bigNum)));

  @override
  int get hashCode => _bigDen == null
      ? Object.hash(FractionNumber, _smallNum, _smallDen)
      : Object.hash(FractionNumber, _bigNum, _bigDen);
}

/// Finite IEEE-754 floating-point real number literal.
///
/// Non-finite IEEE-754 values (`NaN`, `Infinity`, `-Infinity`) are mapped via
/// [RealNumber.fromDouble] to [Constant.undefined] and `+/-`[Constant.infinity].
/// Negative zero (`-0.0`) is canonicalized to `+0.0`.
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

  /// Converts any IEEE-754 [double] into its canonical symbolic [Expr].
  static Expr fromDouble(double value) {
    if (value.isNaN) return Constant.undefined;
    if (value == double.infinity) return Constant.infinity;
    if (value == double.negativeInfinity) return _negativeInfinity;
    return RealNumber(value);
  }

  static final Expr _negativeInfinity = Mul._([
    IntegerNumber.negativeOne,
    Constant.infinity,
  ]);

  /// The floating-point zero `0.0`.
  static const zero = RealNumber(0.0);

  /// The floating-point one `1.0`.
  static const one = RealNumber(1.0);

  /// The floating-point negative one `-1.0`.
  static const negativeOne = RealNumber(-1.0);

  /// The finite IEEE-754 floating-point value.
  final double value;

  @override
  int get flags => kFlagHasReal | kFlagSimplified;

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

/// Atomic complex number `a + b i` with [RealNumeric] real and non-zero
/// imaginary parts.
final class ComplexNumber extends Number {
  new _(this.real, this.imaginary);

  /// Creates an atomic complex number with [real] part `a` and non-zero
  /// [imaginary] part `b`.
  new(this.real, this.imaginary)
    : assert(
        !imaginary.isZero,
        'ComplexNumber imaginary component must be non-zero; use ComplexNumber.of instead',
      );

  /// Constructs a canonical [Number] from [real] and [imaginary] components,
  /// demoting to [real] when `imaginary.isZero` and matching [RealNumber]
  /// precision across both components.
  static Number of(RealNumeric real, RealNumeric imaginary) {
    if (imaginary.isZero) {
      return (imaginary is RealNumber && real is! RealNumber)
          ? RealNumber(real.toDouble())
          : real;
    }
    if (real is RealNumber && imaginary is! RealNumber) {
      return ComplexNumber(real, RealNumber(imaginary.toDouble()));
    } else if (imaginary is RealNumber && real is! RealNumber) {
      return ComplexNumber(RealNumber(real.toDouble()), imaginary);
    }
    return ComplexNumber(real, imaginary);
  }

  /// The imaginary unit `i = 0 + 1i`.
  static final i = ComplexNumber._(IntegerNumber.zero, IntegerNumber.one);

  /// The negated imaginary unit `-i = 0 - 1i`.
  static final negativeI = ComplexNumber._(
    IntegerNumber.zero,
    IntegerNumber.negativeOne,
  );

  /// The real component `Re(z)`.
  final RealNumeric real;

  /// The non-zero imaginary component `Im(z)`.
  final RealNumeric imaginary;

  /// Whether the real component is zero (`Re(z) = 0`).
  bool get isPureImaginary => real.isZero;

  /// Floating-point [Complex] evaluation of this number.
  Complex get value => toComplex();

  @override
  int get flags =>
      ((real.flags | imaginary.flags) & kStructuralFlagsMask) |
      (imaginary.isZero ? 0 : kFlagHasComplex) |
      kFlagSimplified;

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

const int _maxSafeInt = 9007199254740991;
const int _addSafeBound = 4503599627370495;
const int _mulSafeBound = 67108863;

final BigInt _posMaxSafeBig = BigInt.parse('9007199254740991');
final BigInt _negMaxSafeBig = -_posMaxSafeBig;

int _intGcd(int a, int b) {
  var x = a < 0 ? -a : a;
  var y = b < 0 ? -b : b;
  while (y != 0) {
    final t = x % y;
    x = y;
    y = t;
  }
  return x;
}

BigInt _bigIntGcd(BigInt a, BigInt b) {
  var x = a.isNegative ? -a : a;
  var y = b.isNegative ? -b : b;
  if (x == BigInt.zero) return y;
  if (y == BigInt.zero) return x;
  if (x == BigInt.one || y == BigInt.one) return BigInt.one;
  if (x.bitLength < y.bitLength) {
    final tmp = x;
    x = y;
    y = tmp;
  }
  if (x.bitLength > y.bitLength + 32 ||
      (y.bitLength <= 53 && x.bitLength > 53)) {
    x = x % y;
    if (x == BigInt.zero) return y;
  }
  if (y.bitLength <= 53) {
    return BigInt.from(_intGcd(y.toInt(), x.toInt()));
  }
  return y.gcd(x);
}

(int, int)? _asSafePair(RationalNumber r) => switch (r) {
  IntegerNumber(:final _small, :final _big) =>
    _big == null ? (_small, 1) : null,
  FractionNumber(:final _smallNum, :final _smallDen, :final _bigDen) =>
    _bigDen == null ? (_smallNum, _smallDen) : null,
};

int _compareRationals(RationalNumber a, RationalNumber b) {
  final aSafe = _asSafePair(a);
  final bSafe = _asSafePair(b);
  if (aSafe != null && bSafe != null) {
    final (an, ad) = aSafe;
    final (bn, bd) = bSafe;
    if (ad == bd) return an.compareTo(bn);
    if (an >= -_mulSafeBound &&
        an <= _mulSafeBound &&
        ad <= _mulSafeBound &&
        bn >= -_mulSafeBound &&
        bn <= _mulSafeBound &&
        bd <= _mulSafeBound) {
      return (an * bd).compareTo(bn * ad);
    }
  }
  return a.denominator == b.denominator
      ? a.numerator.compareTo(b.numerator)
      : (a.numerator * b.denominator).compareTo(b.numerator * a.denominator);
}

int _compareRationalReal(RationalNumber r, RealNumber f) =>
    _compareRationalToDoubleValue(r, f.value);

final _compareByteData = ByteData(8);

int _compareRationalToDoubleValue(RationalNumber r, double d) {
  if (d.isNaN) return -1;
  if (d.isInfinite) return d.isNegative ? 1 : -1;
  if (d == 0.0) return r.sign;
  final dSign = d < 0 ? -1 : 1;
  if (r.sign != dSign) return r.sign.compareTo(dSign);
  _compareByteData.setFloat64(0, d.abs());
  final hi = _compareByteData.getUint32(0);
  final lo = _compareByteData.getUint32(4);
  final biasedExp = (hi >> 20) & 0x7ff;
  final fracHi = hi & 0xfffff;
  final mantissa =
      (BigInt.from(biasedExp == 0 ? fracHi : (fracHi | 0x100000)) << 32) |
      BigInt.from(lo);
  final exp = (biasedExp == 0 ? 1 : biasedExp) - 1023 - 52;
  final rNum = r.numerator.abs();
  final rDen = r.denominator;
  final cmp = exp >= 0
      ? rNum.compareTo((mantissa << exp) * rDen)
      : (rNum << (-exp)).compareTo(mantissa * rDen);
  return dSign < 0 ? -cmp : cmp;
}
