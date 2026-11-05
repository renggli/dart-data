import 'dart:math' as math;

import '../../ast.dart';
import '../../number/integer.dart';
import '../simplify/additive.dart';
import '../simplify/multiplicative.dart';
import '../term_accumulator.dart';
import 'fraction.dart';
import 'multivariate.dart';

/// Polynomial over $\mathbb{Q}\[x\]$ represented as a list of rational coefficients.
class PolyQ {
  /// Creates a polynomial with [coeffs] where `coeffs[k]` is coefficient of $x^k$.
  new(this.coeffs);

  /// List of rational coefficients in ascending order of degree.
  final List<RationalNumber> coeffs;

  /// Degree of the polynomial ($n = coeffs.length - 1$).
  int get degree => coeffs.length - 1;
}

/// Extracts univariate rational polynomial coefficients for [variable] from [expr].
PolyQ? extractPoly(Expr expr, String variable) {
  final terms = <Expr>[];
  collectAdditiveTerms(expr, 1, terms);

  final coeffMap = <int, RationalNumber>{};
  for (final term in terms) {
    final (c, base) = decomposeTerm(term);
    if (c is! RationalNumber) return null;

    switch (base) {
      case final RationalNumber r:
        final prod = c.mulRational(r);
        coeffMap[0] = (coeffMap[0] ?? IntegerNumber.zero).addRational(prod);
      case Variable(:final name) when name == variable:
        coeffMap[1] = (coeffMap[1] ?? IntegerNumber.zero).addRational(c);
      case Pow(
            base: Variable(:final name),
            exponent: RationalNumber(asInt: final k?),
          )
          when name == variable && k >= 0:
        coeffMap[k] = (coeffMap[k] ?? IntegerNumber.zero).addRational(c);
      default:
        return null;
    }
  }

  coeffMap.removeWhere((_, v) => v.isZero);
  if (coeffMap.isEmpty) {
    return PolyQ([IntegerNumber.zero]);
  }
  final maxDeg = coeffMap.keys.reduce(math.max);
  final dense = List<RationalNumber>.generate(
    maxDeg + 1,
    (i) => coeffMap[i] ?? IntegerNumber.zero,
  );
  return PolyQ(dense);
}

/// Factors univariate rational polynomial [poly] in [variable].
Expr factorUnivariatePoly(PolyQ poly, String variable) {
  if (poly.degree <= 0) {
    return poly.coeffs.first;
  }

  // 1. Clear denominators
  var lcmDen = Integer.one;
  for (final c in poly.coeffs) {
    lcmDen = lcmDen.lcm(c.denominator);
  }

  final intCoeffs = <Integer>[];
  for (final c in poly.coeffs) {
    intCoeffs.add(c.numerator * (lcmDen ~/ c.denominator));
  }

  // 2. Extract content GCD
  var content = Integer.zero;
  for (final a in intCoeffs) {
    if (!a.isZero) content = content.gcd(a);
  }
  if (content.isZero) content = Integer.one;

  final lead = intCoeffs[poly.degree];
  final sign = lead.isNegative ? Integer.negativeOne : Integer.one;

  var primitiveCoeffs = intCoeffs.map((a) => (a * sign) ~/ content).toList();

  var scalar = RationalNumber.of(content * sign, lcmDen);
  final factors = <Expr, int>{};

  // 3. Zero roots: factor out x^m
  var m = 0;
  while (m < primitiveCoeffs.length && primitiveCoeffs[m].isZero) {
    m++;
  }
  if (m > 0) {
    factors[Variable(variable)] = m;
    primitiveCoeffs = primitiveCoeffs.sublist(m);
  }

  var currentDeg = primitiveCoeffs.length - 1;
  if (currentDeg == 0) {
    return buildFactoredExpr(scalar: scalar, factors: factors);
  }

  if (currentDeg == 1) {
    if (factors.isEmpty && content.isOne && lcmDen.isOne) {
      return buildPolyExpr(intCoeffs, variable);
    }
    final linFactor = buildLinearFactor(
      primitiveCoeffs[1],
      -primitiveCoeffs[0],
      variable,
    );
    factors[linFactor] = (factors[linFactor] ?? 0) + 1;
    return buildFactoredExpr(scalar: scalar, factors: factors);
  }

  // 4. Degree >= 2: Rational Root Theorem search
  if (currentDeg >= 3) {
    final a0 = primitiveCoeffs[0];
    final ad = primitiveCoeffs.last;
    final pDivs = divisors(a0);
    final qDivs = divisors(ad);

    // Candidates (p, q) where root is p / q
    final candidates = <(Integer, Integer)>[];
    for (final q in qDivs) {
      for (final pAbs in pDivs) {
        for (final p in [pAbs, -pAbs]) {
          if (p.abs().gcd(q).isOne) {
            candidates.add((p, q));
          }
        }
      }
    }

    candidates.sort((c1, c2) {
      final (p1, q1) = c1;
      final (p2, q2) = c2;
      final v1 = (p1.toDouble() / q1.toDouble()).abs();
      final v2 = (p2.toDouble() / q2.toDouble()).abs();
      return v1.compareTo(v2);
    });

    for (final (p, q) in candidates) {
      while (currentDeg >= 3) {
        final quotient = syntheticDivide(primitiveCoeffs, p, q);
        if (quotient != null) {
          final lin = buildLinearFactor(q, p, variable);
          factors[lin] = (factors[lin] ?? 0) + 1;
          primitiveCoeffs = quotient;
          currentDeg = primitiveCoeffs.length - 1;
        } else {
          break;
        }
      }
      if (currentDeg < 3) break;
    }
  }

  // 5. Quadratic resolution
  if (currentDeg == 2) {
    final a = primitiveCoeffs[2];
    final b = primitiveCoeffs[1];
    final c = primitiveCoeffs[0];
    final disc = b * b - const Integer(4) * a * c;

    if (!disc.isNegative) {
      final s = disc.isqrt();
      if (s != null) {
        final twoA = a * Integer.two;
        final r1 = RationalNumber.of(-b + s, twoA);
        final r2 = RationalNumber.of(-b - s, twoA);
        final f1 = buildLinearFactor(r1.denominator, r1.numerator, variable);
        final f2 = buildLinearFactor(r2.denominator, r2.numerator, variable);
        factors[f1] = (factors[f1] ?? 0) + 1;
        factors[f2] = (factors[f2] ?? 0) + 1;
        return buildFactoredExpr(scalar: scalar, factors: factors);
      }
    }
    // Irreducible quadratic
    if (factors.isEmpty && content.isOne && lcmDen.isOne) {
      return buildPolyExpr(intCoeffs, variable);
    }
    final quadExpr = buildPolyExpr(primitiveCoeffs, variable);
    factors[quadExpr] = (factors[quadExpr] ?? 0) + 1;
    return buildFactoredExpr(scalar: scalar, factors: factors);
  }

  // 6. Biquadratic check if degree 4
  if (currentDeg == 4 &&
      primitiveCoeffs[3].isZero &&
      primitiveCoeffs[1].isZero) {
    final a = primitiveCoeffs[4];
    final b = primitiveCoeffs[2];
    final c = primitiveCoeffs[0];
    final disc = b * b - const Integer(4) * a * c;
    if (!disc.isNegative) {
      final s = disc.isqrt();
      if (s != null) {
        final twoA = a * Integer.two;
        final u1 = RationalNumber.of(-b + s, twoA);
        final u2 = RationalNumber.of(-b - s, twoA);
        final q1 = factorQuadraticInX(u1.denominator, -u1.numerator, variable);
        final q2 = factorQuadraticInX(u2.denominator, -u2.numerator, variable);
        mergeFactorsInto(factors, q1);
        mergeFactorsInto(factors, q2);
        return buildFactoredExpr(scalar: scalar, factors: factors);
      }
    }

    // Sophie Germain / cyclotomic difference of squares:
    // a x^4 + b x^2 + c = (sA x^2 + sC)^2 - (k x)^2 = (sA x^2 - k x + sC)(sA x^2 + k x + sC)
    if (!a.isNegative && !a.isZero && !c.isNegative && !c.isZero) {
      final sA = a.isqrt();
      final sC = c.isqrt();
      if (sA != null && sC != null) {
        final mid = Integer.two * sA * sC - b;
        if (!mid.isNegative && !mid.isZero) {
          final k = mid.isqrt();
          if (k != null) {
            final q1 = buildPolyExpr([sC, -k, sA], variable);
            final q2 = buildPolyExpr([sC, k, sA], variable);
            factors[q1] = (factors[q1] ?? 0) + 1;
            factors[q2] = (factors[q2] ?? 0) + 1;
            return buildFactoredExpr(scalar: scalar, factors: factors);
          }
        }
      }
    }
  }

  // 7. Square-free decomposition for repeated nonlinear factors (e.g. (x^2 + x + 1)^2)
  if (currentDeg >= 4) {
    final sqFree = _decomposeSquareFree(primitiveCoeffs);
    if (sqFree != null) {
      for (final (partCoeffs, mult) in sqFree) {
        final partPoly = PolyQ(
          partCoeffs.map<RationalNumber>(IntegerNumber.new).toList(),
        );
        final subExpr = factorUnivariatePoly(partPoly, variable);
        final subFactors = <Expr, int>{};
        var subScalar = IntegerNumber.one as RationalNumber;
        flattenFactored(subExpr, subFactors, (s) {
          subScalar = subScalar.mulRational(s);
        });
        if (!subScalar.isOne) {
          final powScalar = subScalar.powInteger(mult)!;
          scalar = scalar.mulRational(powScalar);
        }
        for (final MapEntry(:key, :value) in subFactors.entries) {
          factors[key] = (factors[key] ?? 0) + value * mult;
        }
      }
      return buildFactoredExpr(scalar: scalar, factors: factors);
    }
  }

  // Irreducible higher degree
  if (factors.isEmpty && content.isOne && lcmDen.isOne) {
    return buildPolyExpr(intCoeffs, variable);
  }
  final polyExpr = buildPolyExpr(primitiveCoeffs, variable);
  factors[polyExpr] = (factors[polyExpr] ?? 0) + 1;
  return buildFactoredExpr(scalar: scalar, factors: factors);
}

/// Factors quadratic $a \cdot x^2 + c$.
Map<Expr, int> factorQuadraticInX(Integer a, Integer c, String variable) {
  final res = <Expr, int>{};
  final disc = -const Integer(4) * a * c;
  if (!disc.isNegative) {
    final s = disc.isqrt();
    if (s != null) {
      final twoA = a * Integer.two;
      final r1 = RationalNumber.of(s, twoA);
      final r2 = RationalNumber.of(-s, twoA);
      final f1 = buildLinearFactor(r1.denominator, r1.numerator, variable);
      final f2 = buildLinearFactor(r2.denominator, r2.numerator, variable);
      res[f1] = (res[f1] ?? 0) + 1;
      res[f2] = (res[f2] ?? 0) + 1;
      return res;
    }
  }
  final quad = buildPolyExpr([c, Integer.zero, a], variable);
  res[quad] = 1;
  return res;
}

/// Merges factor multiplicities from [source] into [target].
void mergeFactorsInto(Map<Expr, int> target, Map<Expr, int> source) {
  for (final MapEntry(:key, :value) in source.entries) {
    target[key] = (target[key] ?? 0) + value;
  }
}

/// Performs synthetic division of [coeffs] by linear factor $q \cdot x - p$.
List<Integer>? syntheticDivide(List<Integer> coeffs, Integer p, Integer q) {
  final n = coeffs.length - 1;
  if (n <= 0) return null;
  if (!(coeffs[n] % q).isZero) return null;

  final b = List<Integer>.filled(n, Integer.zero);
  b[n - 1] = coeffs[n] ~/ q;

  for (var k = n - 1; k >= 1; k--) {
    final num = coeffs[k] + p * b[k];
    if (!(num % q).isZero) return null;
    b[k - 1] = num ~/ q;
  }

  final rem = coeffs[0] + p * b[0];
  if (!rem.isZero) return null;
  return b;
}

/// Builds linear factor $q \cdot x - p$ in canonical simplified order.
Expr buildLinearFactor(Integer q, Integer p, String variable) =>
    buildPolyExpr([-p, q], variable);

/// Builds expression from polynomial integer [coeffs] in canonical simplified order.
Expr buildPolyExpr(List<Integer> coeffs, String variable) =>
    buildPolyExprFromRational([
      for (final a in coeffs) IntegerNumber(a),
    ], variable);

/// Builds expression from rational polynomial [coeffs] in canonical simplified order.
Expr buildPolyExprFromRational(List<RationalNumber> coeffs, String variable) {
  final x = Variable(variable);
  return simplifyAdd([
    for (var k = 0; k < coeffs.length; k++)
      if (!coeffs[k].isZero)
        switch (k) {
          0 => coeffs[k],
          1 => simplifyMul([coeffs[k], x]),
          _ => simplifyMul([
            coeffs[k],
            Pow(x, IntegerNumber.of(k), isSimplified: true),
          ]),
        },
  ]);
}

/// Computes exact integer cube root of [n] if perfect cube, or `null`.
Integer? integerCbrt(Integer n) {
  if (n.isZero) return Integer.zero;
  if (n.isNegative) {
    final r = integerCbrt(-n);
    return r == null ? null : -r;
  }
  if (n.isOne) return Integer.one;
  if (n.bitLength <= 52) {
    final v = n.asInt;
    if (v != null) {
      final r = math.pow(v.toDouble(), 1.0 / 3.0).round();
      if (r * r * r == v) return Integer.from(r);
      return null;
    }
  }
  final b = n.toBigInt();
  var x0 = BigInt.one << ((b.bitLength + 2) ~/ 3);
  final two = BigInt.two;
  final three = BigInt.from(3);
  while (true) {
    final x1 = (two * x0 + b ~/ (x0 * x0)) ~/ three;
    if (x1 >= x0) break;
    x0 = x1;
  }
  if (x0 * x0 * x0 == b) return Integer.big(x0);
  return null;
}

/// Computes positive integer divisors of [n].
List<Integer> divisors(Integer n) {
  final val = n.abs();
  if (val.isZero) return const [];
  final valInt = val.asInt;
  if (valInt != null && val.bitLength <= 30) {
    final small = <Integer>[];
    final large = <Integer>[];
    final limit = math.sqrt(valInt.toDouble()).floor();
    for (var i = 1; i <= limit; i++) {
      if (valInt % i == 0) {
        small.add(Integer.from(i));
        final other = valInt ~/ i;
        if (other != i) {
          large.add(Integer.from(other));
        }
      }
    }
    return [...small, ...large.reversed];
  }
  return [Integer.one, val];
}

List<(List<Integer>, int)>? _decomposeSquareFree(
  List<Integer> primitiveCoeffs,
) {
  final pRat = [for (final c in primitiveCoeffs) IntegerNumber(c)];
  final dRat = _polyDerivative(pRat);
  final g = _polyGcd(pRat, dRat);
  if (g.length <= 1 || g.length >= pRat.length) {
    return null;
  }

  var c = g;
  var d = _polyExactDiv(pRat, g);
  if (d == null) return null;

  final components = <(List<Integer>, int)>[];
  var mult = 1;
  while (d != null && d.length > 1) {
    final y = _polyGcd(c, d);
    final z = _polyExactDiv(d, y);
    if (z == null) return null;
    if (z.length > 1) {
      final primZ = _toPrimitiveIntCoeffs(z);
      if (primZ == null) return null;
      components.add((primZ, mult));
    }
    final nextC = _polyExactDiv(c, y);
    if (nextC == null) return null;
    c = nextC;
    d = y;
    mult++;
  }
  return components.isEmpty ? null : components;
}

List<RationalNumber> _makeMonic(List<RationalNumber> coeffs) {
  final lead = coeffs.last;
  if (lead.isZero || lead.isOne) return coeffs;
  return [for (final c in coeffs) c.divRational(lead)];
}

List<RationalNumber> _polyDerivative(List<RationalNumber> coeffs) {
  if (coeffs.length <= 1) return [IntegerNumber.zero];
  return [
    for (var i = 1; i < coeffs.length; i++)
      coeffs[i].mulRational(IntegerNumber.of(i)),
  ];
}

(List<RationalNumber>, List<RationalNumber>)? _polyDivMod(
  List<RationalNumber> num,
  List<RationalNumber> den,
) {
  final a = List<RationalNumber>.of(num);
  final b = den;
  final degB = b.length - 1;
  if (b.last.isZero) return null;
  var degA = a.length - 1;
  if (degA < degB) {
    return ([IntegerNumber.zero], a);
  }
  final quot = List<RationalNumber>.filled(degA - degB + 1, IntegerNumber.zero);
  final leadB = b.last;
  while (degA >= degB && !(degA == 0 && a[0].isZero)) {
    final shift = degA - degB;
    final factor = a[degA].divRational(leadB);
    quot[shift] = factor;
    for (var i = 0; i <= degB; i++) {
      a[shift + i] = a[shift + i].subRational(factor.mulRational(b[i]));
    }
    while (degA > 0 && a[degA].isZero) {
      degA--;
    }
  }
  return (quot, a.sublist(0, degA + 1));
}

List<RationalNumber>? _polyExactDiv(
  List<RationalNumber> a,
  List<RationalNumber> b,
) => switch (_polyDivMod(a, b)) {
  (final q, [RationalNumber(isZero: true)]) => q,
  _ => null,
};

List<RationalNumber> _polyGcd(List<RationalNumber> a, List<RationalNumber> b) {
  var x = a;
  var y = b;
  while (!(y.length == 1 && y[0].isZero)) {
    final dm = _polyDivMod(x, y);
    if (dm == null) break;
    final (_, rem) = dm;
    x = y;
    y = rem;
  }
  return _makeMonic(x);
}

List<Integer>? _toPrimitiveIntCoeffs(List<RationalNumber> coeffs) {
  var lcmDen = Integer.one;
  for (final c in coeffs) {
    lcmDen = lcmDen.lcm(c.denominator);
  }
  final intCoeffs = <Integer>[];
  var content = Integer.zero;
  for (final c in coeffs) {
    final scaled = c.numerator * (lcmDen ~/ c.denominator);
    intCoeffs.add(scaled);
    if (!scaled.isZero) content = content.gcd(scaled.abs());
  }
  if (content.isZero) content = Integer.one;
  final sign = intCoeffs.last.isNegative ? Integer.negativeOne : Integer.one;
  return [for (final a in intCoeffs) (a * sign) ~/ content];
}
