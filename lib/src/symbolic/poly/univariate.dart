import 'package:more/math.dart';

import '../ast.dart';

/// Exact univariate polynomial in `Z[x]` stored in ascending power order
/// `c_0 + c_1 * x + ... + c_d * x^d` with no trailing zero coefficients.
///
/// The zero polynomial has empty [coeffs] and [degree] `-1`.
final class PolyZ {
  /// Creates a normalized polynomial over `Z[x]` from ascending [coeffs].
  factory(List<BigInt> coeffs) {
    var end = coeffs.length;
    while (end > 0 && coeffs[end - 1] == BigInt.zero) {
      end--;
    }
    if (end == 0) return zero;
    return PolyZ._(List<BigInt>.unmodifiable(coeffs.sublist(0, end)));
  }

  const new _(this.coeffs);

  /// Zero polynomial `0` (`degree == -1`).
  static const PolyZ zero = PolyZ._([]);

  /// Multiplicative identity polynomial `1`.
  static final PolyZ one = PolyZ._([BigInt.one]);

  /// Constant polynomial `c`.
  factory constant(BigInt c) => c == BigInt.zero ? zero : PolyZ._([c]);

  /// Monomial `coeff * x^degree` (with `coeff` defaulting to `1`).
  factory monomial(int degree, [BigInt? coeff]) {
    if (degree < 0) {
      throw ArgumentError.value(degree, 'degree', 'Must be non-negative.');
    }
    final c = coeff ?? BigInt.one;
    if (c == BigInt.zero) return zero;
    final list = List<BigInt>.filled(degree + 1, BigInt.zero);
    list[degree] = c;
    return PolyZ._(List<BigInt>.unmodifiable(list));
  }

  /// Normalized ascending integer coefficients (no trailing zeros).
  final List<BigInt> coeffs;

  /// Algebraic degree (`-1` for the zero polynomial).
  int get degree => coeffs.length - 1;

  /// Whether this is the zero polynomial.
  bool get isZero => coeffs.isEmpty;

  /// Whether `degree <= 0`.
  bool get isConstant => coeffs.length <= 1;

  /// Leading coefficient (`0` for the zero polynomial).
  BigInt get leadingCoeff => isZero ? BigInt.zero : coeffs.last;

  /// Non-negative content `gcd(|c_0|, ..., |c_d|)`.
  BigInt content() {
    var g = BigInt.zero;
    for (final c in coeffs) {
      if (c != BigInt.zero) {
        g = g == BigInt.zero ? c.abs() : g.gcd(c.abs());
        if (g == BigInt.one) return BigInt.one;
      }
    }
    return g;
  }

  /// Returns the primitive part with non-negative leading coefficient.
  PolyZ primitivePart() {
    if (isZero) return zero;
    final c = content();
    final sign = leadingCoeff.isNegative ? -BigInt.one : BigInt.one;
    if (c == BigInt.one && sign == BigInt.one) return this;
    return PolyZ._([for (final a in coeffs) (a * sign) ~/ c]);
  }

  /// Unary negation `-this`.
  PolyZ operator -() => isZero ? zero : PolyZ._([for (final a in coeffs) -a]);

  /// Polynomial addition `this + other`.
  PolyZ operator +(PolyZ other) {
    if (isZero) return other;
    if (other.isZero) return this;
    final len = coeffs.length > other.coeffs.length
        ? coeffs.length
        : other.coeffs.length;
    final out = List<BigInt>.generate(
      len,
      (i) =>
          (i < coeffs.length ? coeffs[i] : BigInt.zero) +
          (i < other.coeffs.length ? other.coeffs[i] : BigInt.zero),
    );
    return PolyZ(out);
  }

  /// Polynomial subtraction `this - other`.
  PolyZ operator -(PolyZ other) {
    if (other.isZero) return this;
    if (isZero) return -other;
    final len = coeffs.length > other.coeffs.length
        ? coeffs.length
        : other.coeffs.length;
    final out = List<BigInt>.generate(
      len,
      (i) =>
          (i < coeffs.length ? coeffs[i] : BigInt.zero) -
          (i < other.coeffs.length ? other.coeffs[i] : BigInt.zero),
    );
    return PolyZ(out);
  }

  /// Scalar integer multiplication `scalar * this`.
  PolyZ scale(BigInt scalar) {
    if (scalar == BigInt.zero || isZero) return zero;
    if (scalar == BigInt.one) return this;
    return PolyZ._([for (final a in coeffs) a * scalar]);
  }

  /// Polynomial multiplication `this * other`.
  PolyZ operator *(PolyZ other) {
    if (isZero || other.isZero) return zero;
    final out = List<BigInt>.filled(
      coeffs.length + other.coeffs.length - 1,
      BigInt.zero,
    );
    for (var i = 0; i < coeffs.length; i++) {
      final a = coeffs[i];
      if (a == BigInt.zero) continue;
      for (var j = 0; j < other.coeffs.length; j++) {
        out[i + j] += a * other.coeffs[j];
      }
    }
    return PolyZ(out);
  }

  /// Formal derivative `d/dx(this)`.
  PolyZ derivative() {
    if (coeffs.length <= 1) return zero;
    return PolyZ([
      for (var i = 1; i < coeffs.length; i++) coeffs[i] * BigInt.from(i),
    ]);
  }

  /// Evaluates `this(x)` at exact integer [x] using Horner's scheme.
  BigInt evaluate(BigInt x) {
    var acc = BigInt.zero;
    for (var i = coeffs.length - 1; i >= 0; i--) {
      acc = acc * x + coeffs[i];
    }
    return acc;
  }

  /// Exact integer pseudo-division of `this` by [divisor].
  ///
  /// Returns `(quotient: Q, remainder: R)` satisfying
  /// `lc(divisor)^(deg(this) - deg(divisor) + 1) * this = Q * divisor + R`
  /// when `deg(this) >= deg(divisor)`.
  ({PolyZ quotient, PolyZ remainder}) pseudoDivide(PolyZ divisor) {
    if (divisor.isZero) {
      throw ArgumentError.value(divisor, 'divisor', 'Division by zero.');
    }
    final degB = divisor.degree;
    var degA = degree;
    if (degA < degB) {
      return (quotient: zero, remainder: this);
    }
    final rem = List<BigInt>.of(coeffs);
    final quot = List<BigInt>.filled(degA - degB + 1, BigInt.zero);
    final leadB = divisor.leadingCoeff;

    while (degA >= degB) {
      final shift = degA - degB;
      final leadA = rem[degA];
      for (var i = 0; i < quot.length; i++) {
        quot[i] *= leadB;
      }
      quot[shift] += leadA;
      for (var i = 0; i < rem.length; i++) {
        rem[i] *= leadB;
      }
      for (var i = 0; i <= degB; i++) {
        rem[shift + i] -= leadA * divisor.coeffs[i];
      }
      while (degA >= 0 && rem[degA] == BigInt.zero) {
        degA--;
      }
    }
    return (
      quotient: PolyZ(quot),
      remainder: degA < 0 ? zero : PolyZ(rem.sublist(0, degA + 1)),
    );
  }

  /// Returns exact polynomial quotient `this / divisor` over `Z[x]`, or
  /// `null` if [divisor] does not divide `this` evenly in `Z[x]`.
  PolyZ? exactDivide(PolyZ divisor) {
    if (divisor.isZero) {
      throw ArgumentError.value(divisor, 'divisor', 'Division by zero.');
    }
    if (isZero) return zero;
    if (degree < divisor.degree) return null;
    if (divisor.isConstant) {
      final d = divisor.coeffs.first;
      final out = <BigInt>[];
      for (final c in coeffs) {
        if (c % d != BigInt.zero) return null;
        out.add(c ~/ d);
      }
      return PolyZ(out);
    }
    final rem = List<BigInt>.of(coeffs);
    final degB = divisor.degree;
    final leadB = divisor.leadingCoeff;
    final quot = List<BigInt>.filled(degree - degB + 1, BigInt.zero);
    for (var shift = degree - degB; shift >= 0; shift--) {
      final idx = shift + degB;
      final c = rem[idx];
      if (c % leadB != BigInt.zero) return null;
      final q = c ~/ leadB;
      quot[shift] = q;
      if (q != BigInt.zero) {
        for (var i = 0; i <= degB; i++) {
          rem[shift + i] -= q * divisor.coeffs[i];
        }
      }
    }
    for (var i = 0; i < rem.length; i++) {
      if (rem[i] != BigInt.zero) return null;
    }
    return PolyZ(quot);
  }

  /// Primitive GCD in `Z[x]` with non-negative leading coefficient.
  PolyZ gcd(PolyZ other) {
    if (isZero) return other.primitivePart();
    if (other.isZero) return primitivePart();
    final contentGcd = content().gcd(other.content());
    var a = primitivePart();
    var b = other.primitivePart();
    while (!b.isZero) {
      if (b.isConstant) {
        return PolyZ.constant(contentGcd);
      }
      final (:quotient, :remainder) = a.pseudoDivide(b);
      a = b;
      b = remainder.primitivePart();
    }
    return a.primitivePart().scale(contentGcd);
  }

  /// Yun's square-free decomposition of `primitivePart()`.
  ///
  /// Returns primitive irreducible-multiplicity components `(f_i, i)` with
  /// `i >= 1` and `primitivePart() = prod f_i^i`.
  List<({PolyZ factor, int multiplicity})> squareFreeDecomposition() {
    final prim = primitivePart();
    if (prim.isZero) return const [];
    if (prim.isConstant) {
      return const [];
    }
    final deriv = prim.derivative();
    final g = prim.gcd(deriv);
    if (g.degree <= 0) {
      return [(factor: prim, multiplicity: 1)];
    }

    var c = g.primitivePart();
    var w = prim.exactDivide(c)!;
    final result = <({PolyZ factor, int multiplicity})>[];
    var mult = 1;
    while (w.degree > 0) {
      final y = w.gcd(c);
      final z = w.exactDivide(y)!;
      if (z.degree > 0) {
        result.add((factor: z.primitivePart(), multiplicity: mult));
      }
      w = y;
      c = c.exactDivide(y)!;
      mult++;
    }
    return result;
  }

  /// Exact integer Sylvester resultant `Res(this, other)`.
  BigInt resultant(PolyZ other) {
    if (isZero || other.isZero) return BigInt.zero;
    if (isConstant) {
      return coeffs.first.pow(other.degree);
    }
    if (other.isConstant) {
      return other.coeffs.first.pow(degree);
    }
    final qResultant = toPolyQ().resultant(other.toPolyQ());
    return qResultant.numerator ~/ qResultant.denominator;
  }

  /// Promotes this integer polynomial to `Q[x]`.
  PolyQ toPolyQ() =>
      isZero ? PolyQ.zero : PolyQ([for (final c in coeffs) IntegerNumber(c)]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PolyZ || coeffs.length != other.coeffs.length) return false;
    for (var i = 0; i < coeffs.length; i++) {
      if (coeffs[i] != other.coeffs[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(coeffs);

  @override
  String toString() => 'PolyZ($coeffs)';
}

/// Exact univariate polynomial in `Q[x]` stored in ascending power order
/// `c_0 + c_1 * x + ... + c_d * x^d` with no trailing zero coefficients.
///
/// The zero polynomial has empty [coeffs] and [degree] `-1`.
final class PolyQ {
  /// Creates a normalized polynomial over `Q[x]` from ascending [coeffs].
  factory(List<RationalNumber> coeffs) {
    var end = coeffs.length;
    while (end > 0 && coeffs[end - 1].isZero) {
      end--;
    }
    if (end == 0) return zero;
    return PolyQ._(List<RationalNumber>.unmodifiable(coeffs.sublist(0, end)));
  }

  const new _(this.coeffs);

  /// Zero polynomial `0` (`degree == -1`).
  static const PolyQ zero = PolyQ._([]);

  /// Multiplicative identity polynomial `1`.
  static final PolyQ one = PolyQ._([IntegerNumber.one]);

  /// Constant polynomial `c`.
  factory constant(RationalNumber c) => c.isZero ? zero : PolyQ._([c]);

  /// Monomial `coeff * x^degree` (with `coeff` defaulting to `1`).
  factory monomial(int degree, [RationalNumber? coeff]) {
    if (degree < 0) {
      throw ArgumentError.value(degree, 'degree', 'Must be non-negative.');
    }
    final c = coeff ?? IntegerNumber.one;
    if (c.isZero) return zero;
    final list = List<RationalNumber>.filled(degree + 1, IntegerNumber.zero);
    list[degree] = c;
    return PolyQ._(List<RationalNumber>.unmodifiable(list));
  }

  /// Normalized ascending rational coefficients (no trailing zeros).
  final List<RationalNumber> coeffs;

  /// Algebraic degree (`-1` for the zero polynomial).
  int get degree => coeffs.length - 1;

  /// Whether this is the zero polynomial.
  bool get isZero => coeffs.isEmpty;

  /// Whether `degree <= 0`.
  bool get isConstant => coeffs.length <= 1;

  /// Leading coefficient (`0` for the zero polynomial).
  RationalNumber get leadingCoeff => isZero ? IntegerNumber.zero : coeffs.last;

  /// Returns the monic scalar multiple of this polynomial (`zero` stays `zero`).
  PolyQ monic() {
    if (isZero || leadingCoeff.isOne) return this;
    final inv = leadingCoeff.reciprocal();
    return scale(inv);
  }

  /// Extracts rational scale and primitive [PolyZ] such that
  /// `this == primitive.toPolyQ().scale(scale)` with `primitive.leadingCoeff >= 0`.
  ({RationalNumber scale, PolyZ primitive}) clearDenominators() {
    if (isZero) {
      return (scale: IntegerNumber.zero, primitive: PolyZ.zero);
    }
    var lcmDen = BigInt.one;
    for (final c in coeffs) {
      lcmDen = lcmDen.lcm(c.denominator);
    }
    final scaled = <BigInt>[
      for (final c in coeffs) c.numerator * (lcmDen ~/ c.denominator),
    ];
    final raw = PolyZ(scaled);
    final content = raw.content();
    final sign = raw.leadingCoeff.isNegative ? -BigInt.one : BigInt.one;
    return (
      scale: RationalNumber.of(content * sign, lcmDen),
      primitive: raw.primitivePart(),
    );
  }

  /// Unary negation `-this`.
  PolyQ operator -() =>
      isZero ? zero : PolyQ._([for (final a in coeffs) a.neg()]);

  /// Polynomial addition `this + other`.
  PolyQ operator +(PolyQ other) {
    if (isZero) return other;
    if (other.isZero) return this;
    final len = coeffs.length > other.coeffs.length
        ? coeffs.length
        : other.coeffs.length;
    final out = <RationalNumber>[
      for (var i = 0; i < len; i++)
        (i < coeffs.length ? coeffs[i] : IntegerNumber.zero).addRational(
          i < other.coeffs.length ? other.coeffs[i] : IntegerNumber.zero,
        ),
    ];
    return PolyQ(out);
  }

  /// Polynomial subtraction `this - other`.
  PolyQ operator -(PolyQ other) {
    if (other.isZero) return this;
    if (isZero) return -other;
    final len = coeffs.length > other.coeffs.length
        ? coeffs.length
        : other.coeffs.length;
    final out = <RationalNumber>[
      for (var i = 0; i < len; i++)
        (i < coeffs.length ? coeffs[i] : IntegerNumber.zero).subRational(
          i < other.coeffs.length ? other.coeffs[i] : IntegerNumber.zero,
        ),
    ];
    return PolyQ(out);
  }

  /// Scalar rational multiplication `scalar * this`.
  PolyQ scale(RationalNumber scalar) {
    if (scalar.isZero || isZero) return zero;
    if (scalar.isOne) return this;
    return PolyQ._([for (final a in coeffs) a.mulRational(scalar)]);
  }

  /// Polynomial multiplication `this * other`.
  PolyQ operator *(PolyQ other) {
    if (isZero || other.isZero) return zero;
    final out = List<RationalNumber>.filled(
      coeffs.length + other.coeffs.length - 1,
      IntegerNumber.zero,
    );
    for (var i = 0; i < coeffs.length; i++) {
      final a = coeffs[i];
      if (a.isZero) continue;
      for (var j = 0; j < other.coeffs.length; j++) {
        out[i + j] = out[i + j].addRational(a.mulRational(other.coeffs[j]));
      }
    }
    return PolyQ(out);
  }

  /// Exact Euclidean polynomial division over `Q[x]`:
  /// `this = quotient * divisor + remainder` with `deg(remainder) < deg(divisor)`.
  ({PolyQ quotient, PolyQ remainder}) divRem(PolyQ divisor) {
    if (divisor.isZero) {
      throw ArgumentError.value(divisor, 'divisor', 'Division by zero.');
    }
    final degB = divisor.degree;
    var degA = degree;
    if (degA < degB) {
      return (quotient: zero, remainder: this);
    }
    final rem = List<RationalNumber>.of(coeffs);
    final quot = List<RationalNumber>.filled(
      degA - degB + 1,
      IntegerNumber.zero,
    );
    final leadB = divisor.leadingCoeff;
    while (degA >= degB) {
      final shift = degA - degB;
      final factor = rem[degA].divRational(leadB);
      quot[shift] = factor;
      for (var i = 0; i <= degB; i++) {
        rem[shift + i] = rem[shift + i].subRational(
          factor.mulRational(divisor.coeffs[i]),
        );
      }
      while (degA >= 0 && rem[degA].isZero) {
        degA--;
      }
    }
    return (
      quotient: PolyQ(quot),
      remainder: degA < 0 ? zero : PolyQ(rem.sublist(0, degA + 1)),
    );
  }

  /// Exact monic greatest common divisor in `Q[x]` using primitive [PolyZ] PRS.
  PolyQ gcd(PolyQ other) {
    if (isZero && other.isZero) return zero;
    if (isZero) return other.monic();
    if (other.isZero) return monic();
    final (scale: _, primitive: pA) = clearDenominators();
    final (scale: _, primitive: pB) = other.clearDenominators();
    return pA.gcd(pB).toPolyQ().monic();
  }

  /// Extended Euclidean algorithm over `Q[x]`.
  ///
  /// Returns `(gcd, s, t)` where `gcd` is monic (or [zero] if both are zero)
  /// and `s * this + t * other == gcd`.
  ({PolyQ gcd, PolyQ s, PolyQ t}) extendedGcd(PolyQ other) {
    if (isZero && other.isZero) {
      return (gcd: zero, s: zero, t: zero);
    }
    var r0 = this;
    var r1 = other;
    var s0 = one;
    var s1 = zero;
    var t0 = zero;
    var t1 = one;
    while (!r1.isZero) {
      final (:quotient, :remainder) = r0.divRem(r1);
      r0 = r1;
      r1 = remainder;
      final nextS = s0 - quotient * s1;
      s0 = s1;
      s1 = nextS;
      final nextT = t0 - quotient * t1;
      t0 = t1;
      t1 = nextT;
    }
    if (r0.isZero) return (gcd: zero, s: zero, t: zero);
    final invLead = r0.leadingCoeff.reciprocal();
    return (gcd: r0.scale(invLead), s: s0.scale(invLead), t: t0.scale(invLead));
  }

  /// Monic least common multiple in `Q[x]`.
  PolyQ lcm(PolyQ other) {
    if (isZero || other.isZero) return zero;
    final g = gcd(other);
    final q = divRem(g).quotient;
    return (q * other).monic();
  }

  /// Formal derivative `d/dx(this)`.
  PolyQ derivative() {
    if (coeffs.length <= 1) return zero;
    return PolyQ([
      for (var i = 1; i < coeffs.length; i++)
        coeffs[i].mulRational(IntegerNumber.of(i)),
    ]);
  }

  /// Evaluates `this(x)` at rational [x] using Horner's scheme.
  RationalNumber evaluate(RationalNumber x) {
    RationalNumber acc = IntegerNumber.zero;
    for (var i = coeffs.length - 1; i >= 0; i--) {
      acc = acc.mulRational(x).addRational(coeffs[i]);
    }
    return acc;
  }

  /// Yun's square-free decomposition over `Q[x]` returning monic factors.
  List<({PolyQ factor, int multiplicity})> squareFreeDecomposition() {
    if (isZero || isConstant) return const [];
    final (scale: _, :primitive) = clearDenominators();
    return [
      for (final (:factor, :multiplicity)
          in primitive.squareFreeDecomposition())
        (factor: factor.toPolyQ().monic(), multiplicity: multiplicity),
    ];
  }

  /// Exact rational Sylvester resultant `Res(this, other)`.
  RationalNumber resultant(PolyQ other) {
    if (isZero || other.isZero) return IntegerNumber.zero;
    if (isConstant) {
      return coeffs.first.powInteger(other.degree) ?? IntegerNumber.zero;
    }
    if (other.isConstant) {
      return other.coeffs.first.powInteger(degree) ?? IntegerNumber.zero;
    }
    var a = this;
    var b = other;
    RationalNumber signFactor = IntegerNumber.one;
    RationalNumber multiplier = IntegerNumber.one;
    while (!b.isConstant) {
      final degA = a.degree;
      final degB = b.degree;
      final rem = a.divRem(b).remainder;
      if (rem.isZero) return IntegerNumber.zero;
      if ((degA.isOdd) && (degB.isOdd)) {
        signFactor = signFactor.neg();
      }
      final degR = rem.degree;
      final factor = b.leadingCoeff.powInteger(degA - degR);
      if (factor == null) return IntegerNumber.zero;
      multiplier = multiplier.mulRational(factor);
      a = b;
      b = rem;
    }
    final last = b.coeffs.first.powInteger(a.degree);
    if (last == null) return IntegerNumber.zero;
    return signFactor.mulRational(multiplier).mulRational(last);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PolyQ || coeffs.length != other.coeffs.length) return false;
    for (var i = 0; i < coeffs.length; i++) {
      if (coeffs[i] != other.coeffs[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(coeffs);

  @override
  String toString() => 'PolyQ($coeffs)';
}
