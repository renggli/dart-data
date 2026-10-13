import 'dart:math' as math;

import 'package:more/number.dart' show Fraction;

import '../../ast.dart';
import '../simplify.dart';
import '../term_accumulator.dart';
import 'fraction.dart';
import 'multivariate.dart';

/// Polynomial over $\mathbb{Q}\[x\]$ represented as a list of rational coefficients.
class PolyQ {
  /// Creates a polynomial with [coeffs] where `coeffs[k]` is coefficient of $x^k$.
  new(this.coeffs);

  /// List of rational coefficients in ascending order of degree.
  final List<Fraction> coeffs;

  /// Degree of the polynomial ($n = coeffs.length - 1$).
  int get degree => coeffs.length - 1;
}

/// Extracts univariate rational polynomial coefficients for [variable] from [expr].
PolyQ? extractPoly(Expr expr, String variable) {
  final terms = <Expr>[];
  collectAdditiveTerms(expr, 1, terms);

  final coeffMap = <int, Fraction>{};
  for (final term in terms) {
    final (c, base) = decomposeTerm(term);

    if (base is RationalNumber) {
      coeffMap[0] = (coeffMap[0] ?? Fraction.zero) + c * base.toFraction();
    } else if (base is Variable && base.name == variable) {
      coeffMap[1] = (coeffMap[1] ?? Fraction.zero) + c;
    } else if (base is Pow &&
        base.base is Variable &&
        (base.base as Variable).name == variable &&
        base.exponent is RationalNumber) {
      final exp = base.exponent as RationalNumber;
      if (!exp.isInteger || exp.numerator < 0) return null;
      final k = exp.numerator;
      coeffMap[k] = (coeffMap[k] ?? Fraction.zero) + c;
    } else if (!base.dependsOn(variable)) {
      if (base is RationalNumber) {
        coeffMap[0] = (coeffMap[0] ?? Fraction.zero) + c * base.toFraction();
      } else {
        return null;
      }
    } else {
      return null;
    }
  }

  coeffMap.removeWhere((_, v) => v.a == 0);
  if (coeffMap.isEmpty) {
    return PolyQ([Fraction.zero]);
  }
  final maxDeg = coeffMap.keys.reduce(math.max);
  final dense = List<Fraction>.generate(
    maxDeg + 1,
    (i) => coeffMap[i] ?? Fraction.zero,
  );
  return PolyQ(dense);
}

/// Factors univariate rational polynomial [poly] in [variable].
Expr factorUnivariatePoly(PolyQ poly, String variable) {
  if (poly.degree <= 0) {
    return RationalNumber.fraction(poly.coeffs.first);
  }

  // 1. Clear denominators
  var lcmDen = 1;
  for (final c in poly.coeffs) {
    lcmDen = lcm(lcmDen, c.b);
  }

  final intCoeffs = poly.coeffs.map((c) => c.a * (lcmDen ~/ c.b)).toList();

  // 2. Extract content GCD
  var content = 0;
  for (final a in intCoeffs) {
    if (a != 0) content = gcd(content, a);
  }
  if (content == 0) content = 1;

  final lead = intCoeffs[poly.degree];
  final sign = lead < 0 ? -1 : 1;

  var primitiveCoeffs = intCoeffs.map((a) => (a * sign) ~/ content).toList();

  final scalar = Fraction(content * sign, lcmDen);
  final factors = <Expr, int>{};

  // 3. Zero roots: factor out x^m
  var m = 0;
  while (m < primitiveCoeffs.length && primitiveCoeffs[m] == 0) {
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
    final candidates = <(int, int)>[];
    for (final q in qDivs) {
      for (final pAbs in pDivs) {
        for (final p in [pAbs, -pAbs]) {
          if (gcd(p.abs(), q) == 1) {
            candidates.add((p, q));
          }
        }
      }
    }

    candidates.sort((c1, c2) {
      final v1 = (c1.$1 / c1.$2).abs();
      final v2 = (c2.$1 / c2.$2).abs();
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
    final disc = b * b - 4 * a * c;

    if (disc >= 0) {
      final s = integerSqrt(disc);
      if (s != null) {
        final r1 = Fraction(-b + s, 2 * a);
        final r2 = Fraction(-b - s, 2 * a);
        final f1 = buildLinearFactor(r1.b, r1.a, variable);
        final f2 = buildLinearFactor(r2.b, r2.a, variable);
        factors[f1] = (factors[f1] ?? 0) + 1;
        factors[f2] = (factors[f2] ?? 0) + 1;
        return buildFactoredExpr(scalar: scalar, factors: factors);
      }
    }
    // Irreducible quadratic
    final quadExpr = buildPolyExpr(primitiveCoeffs, variable);
    factors[quadExpr] = (factors[quadExpr] ?? 0) + 1;
    return buildFactoredExpr(scalar: scalar, factors: factors);
  }

  if (currentDeg == 1) {
    final linFactor = buildLinearFactor(
      primitiveCoeffs[1],
      -primitiveCoeffs[0],
      variable,
    );
    factors[linFactor] = (factors[linFactor] ?? 0) + 1;
    return buildFactoredExpr(scalar: scalar, factors: factors);
  }

  // 6. Biquadratic check if degree 4
  if (currentDeg == 4 && primitiveCoeffs[3] == 0 && primitiveCoeffs[1] == 0) {
    final a = primitiveCoeffs[4];
    final b = primitiveCoeffs[2];
    final c = primitiveCoeffs[0];
    final disc = b * b - 4 * a * c;
    if (disc >= 0) {
      final s = integerSqrt(disc);
      if (s != null) {
        final u1 = Fraction(-b + s, 2 * a);
        final u2 = Fraction(-b - s, 2 * a);
        final q1 = factorQuadraticInX(u1.b, -u1.a, variable);
        final q2 = factorQuadraticInX(u2.b, -u2.a, variable);
        mergeFactorsInto(factors, q1);
        mergeFactorsInto(factors, q2);
        return buildFactoredExpr(scalar: scalar, factors: factors);
      }
    }
  }

  // Irreducible higher degree
  final polyExpr = buildPolyExpr(primitiveCoeffs, variable);
  factors[polyExpr] = (factors[polyExpr] ?? 0) + 1;
  return buildFactoredExpr(scalar: scalar, factors: factors);
}

/// Factors quadratic $a \cdot x^2 + c$.
Map<Expr, int> factorQuadraticInX(int a, int c, String variable) {
  final res = <Expr, int>{};
  final disc = -4 * a * c;
  if (disc >= 0) {
    final s = integerSqrt(disc);
    if (s != null) {
      final r1 = Fraction(s, 2 * a);
      final r2 = Fraction(-s, 2 * a);
      final f1 = buildLinearFactor(r1.b, r1.a, variable);
      final f2 = buildLinearFactor(r2.b, r2.a, variable);
      res[f1] = (res[f1] ?? 0) + 1;
      res[f2] = (res[f2] ?? 0) + 1;
      return res;
    }
  }
  final quad = buildPolyExpr([c, 0, a], variable);
  res[quad] = 1;
  return res;
}

/// Merges factor multiplicities from [source] into [target].
void mergeFactorsInto(Map<Expr, int> target, Map<Expr, int> source) {
  for (final e in source.entries) {
    target[e.key] = (target[e.key] ?? 0) + e.value;
  }
}

/// Performs synthetic division of [coeffs] by linear factor $q \cdot x - p$.
List<int>? syntheticDivide(List<int> coeffs, int p, int q) {
  final n = coeffs.length - 1;
  if (n <= 0) return null;
  if (coeffs[n] % q != 0) return null;

  final b = List<int>.filled(n, 0);
  b[n - 1] = coeffs[n] ~/ q;

  for (var k = n - 1; k >= 1; k--) {
    final num = coeffs[k] + p * b[k];
    if (num % q != 0) return null;
    b[k - 1] = num ~/ q;
  }

  final rem = coeffs[0] + p * b[0];
  if (rem != 0) return null;
  return b;
}

/// Builds linear factor $q \cdot x - p$.
Expr buildLinearFactor(int q, int p, String variable) {
  final x = Variable(variable);
  if (q == 1) {
    if (p == 0) return x;
    if (p > 0) return Sub(x, RationalNumber(p));
    return Add(x, RationalNumber(-p));
  } else {
    final qx = Mul(RationalNumber(q), x);
    if (p == 0) return qx;
    if (p > 0) return Sub(qx, RationalNumber(p));
    return Add(qx, RationalNumber(-p));
  }
}

/// Builds expression from polynomial integer [coeffs] in descending powers of [variable].
Expr buildPolyExpr(List<int> coeffs, String variable) {
  Expr? result;
  final x = Variable(variable);
  for (var k = coeffs.length - 1; k >= 0; k--) {
    final a = coeffs[k];
    if (a == 0) continue;
    final term = switch (k) {
      0 => RationalNumber(a.abs()),
      1 => a.abs() == 1 ? x : Mul(RationalNumber(a.abs()), x),
      _ =>
        a.abs() == 1
            ? Pow(x, RationalNumber(k))
            : Mul(RationalNumber(a.abs()), Pow(x, RationalNumber(k))),
    };

    if (result == null) {
      result = a < 0 ? Neg(term) : term;
    } else {
      result = a > 0 ? Add(result, term) : Sub(result, term);
    }
  }
  return (result ?? RationalNumber.zero).simplify();
}

/// Computes the magnitude of the root of linear [expr].
Fraction? linearRootMagnitude(Expr expr) {
  if (expr is Variable) return Fraction.zero;
  if (expr is Mul && expr.left is RationalNumber && expr.right is Variable) {
    return Fraction.zero;
  }
  if (expr is Sub) {
    final (c, base) = decomposeTerm(expr.left);
    if (base is Variable && expr.right is RationalNumber) {
      final p = (expr.right as RationalNumber).toFraction().abs();
      return p / c.abs();
    }
  }
  if (expr is Add) {
    final (c, base) = decomposeTerm(expr.left);
    if (base is Variable && expr.right is RationalNumber) {
      final p = (expr.right as RationalNumber).toFraction().abs();
      return p / c.abs();
    }
  }
  return null;
}

/// Computes the greatest common divisor of [a] and [b].
int gcd(int a, int b) {
  var x = a.abs();
  var y = b.abs();
  while (y != 0) {
    final t = y;
    y = x % y;
    x = t;
  }
  return x;
}

/// Computes the least common multiple of [a] and [b].
int lcm(int a, int b) {
  if (a == 0 || b == 0) return 0;
  return (a.abs() ~/ gcd(a, b)) * b.abs();
}

/// Computes exact integer square root of [n] if perfect square, or `null`.
int? integerSqrt(int n) {
  if (n < 0) return null;
  if (n == 0) return 0;
  final r = math.sqrt(n).round();
  if (r * r == n) return r;
  return null;
}

/// Computes all positive integer divisors of [n].
List<int> divisors(int n) {
  final val = n.abs();
  if (val == 0) return const [];
  final small = <int>[];
  final large = <int>[];
  final limit = math.sqrt(val).floor();
  for (var i = 1; i <= limit; i++) {
    if (val % i == 0) {
      small.add(i);
      final other = val ~/ i;
      if (other != i) {
        large.add(other);
      }
    }
  }
  return [...small, ...large.reversed];
}
