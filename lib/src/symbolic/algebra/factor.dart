import 'dart:math' as math;

import 'package:more/number.dart' show Fraction;

import '../ast.dart';
import 'expand.dart';
import 'simplify.dart';
import 'structural_order.dart';
import 'term_accumulator.dart';

/// Extension providing polynomial factorization and factor grouping on [Expr].
extension FactorExtension on Expr {
  /// Factors this algebraic expression into irreducible products and groups
  /// like powers.
  ///
  /// Conceptually, this reverses polynomial expansion, decomposing polynomial
  /// expressions into products of irreducible factors over $\mathbb{Q}\[x\]$ (such as
  /// factoring $x^2 - 5x + 6$ into $(x - 2)(x - 3)$, or $2x^3 - 8x$ into
  /// $2x(x - 2)(x + 2)$). Formally, this implements univariate polynomial
  /// content extraction, Rational Root Theorem root search with synthetic
  /// division, quadratic discriminant factorization, common monomial grouping,
  /// and multivariate factoring by grouping.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final expr = x * x - const RationalNumber(5) * x + const RationalNumber(6);
  /// print(expr.factor()); // (x - 2) * (x - 3)
  /// ```
  Expr factor() => _factor(this);
}

Expr _factor(Expr expr) {
  // 1. Structural base cases
  if (expr is Number || expr is Variable) return expr;

  // 2. Pure division: factor numerator and denominator recursively and cancel common factors
  if (expr is Div) {
    final num = _factor(expr.left);
    final den = _factor(expr.right);
    return _cancelFactoredFraction(num, den);
  }

  // 3. Pure power: factor base
  if (expr is Pow && expr.exponent is RationalNumber) {
    final exp = expr.exponent as RationalNumber;
    if (exp.isInteger && exp.numerator > 0) {
      final base = _factor(expr.base);
      return _distributePower(base, exp.numerator);
    }
  }

  // 4. Pure multiplication: factor components and combine
  if (expr is Mul) {
    final leftFactored = _factor(expr.left);
    final rightFactored = _factor(expr.right);
    return _combineFactoredProducts([leftFactored, rightFactored]);
  }

  // 5. Expand additive sums into canonical polynomial form
  final expanded = expr.expand();
  final vars = expanded.freeVariables;

  // 6. Univariate polynomial factorization over Q[x]
  if (vars.length == 1) {
    final v = vars.first;
    final poly = _extractPoly(expanded, v);
    if (poly != null) {
      return _factorUnivariatePoly(poly, v);
    }
  }

  // 7. Multivariate / multi-term grouping
  final additiveTerms = <Expr>[];
  _collectAdditiveTerms(expanded, 1, additiveTerms);
  if (additiveTerms.length > 1) {
    // 7a. Common monomial GCD extraction
    final commonGcd = _extractMonomialGcd(additiveTerms);
    if (commonGcd != null && !_isOne(commonGcd)) {
      final cofactorTerms = additiveTerms
          .map((t) => _divideMonomial(t, commonGcd))
          .toList();
      var cofactor = cofactorTerms.first;
      for (var i = 1; i < cofactorTerms.length; i++) {
        cofactor = Add(cofactor, cofactorTerms[i]);
      }
      cofactor = cofactor.simplify();
      if (cofactor != expanded) {
        final factoredCofactor = _factor(cofactor);
        return _combineFactoredProducts([commonGcd, factoredCofactor]);
      }
    }

    // 7b. 4-Term grouping
    if (additiveTerms.length == 4) {
      final grouped = _factorByGrouping4(additiveTerms);
      if (grouped != null) return grouped;
    }

    // 7c. Difference of squares: A^2 - B^2
    final diffSq = _matchDifferenceOfSquares(additiveTerms);
    if (diffSq != null) {
      final (a, b) = diffSq;
      return _combineFactoredProducts([_factor(a - b), _factor(a + b)]);
    }
  }

  return expanded;
}

class _PolyQ {
  new(this.coeffs);
  final List<Fraction> coeffs; // coeffs[k] is coefficient of x^k
  int get degree => coeffs.length - 1;
}

_PolyQ? _extractPoly(Expr expr, String variable) {
  final terms = <Expr>[];
  _collectAdditiveTerms(expr, 1, terms);

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
    return _PolyQ([Fraction.zero]);
  }
  final maxDeg = coeffMap.keys.reduce(math.max);
  final dense = List<Fraction>.generate(
    maxDeg + 1,
    (i) => coeffMap[i] ?? Fraction.zero,
  );
  return _PolyQ(dense);
}

Expr _factorUnivariatePoly(_PolyQ poly, String variable) {
  if (poly.degree <= 0) {
    return RationalNumber.fraction(poly.coeffs.first);
  }

  // 1. Clear denominators
  var lcmDen = 1;
  for (final c in poly.coeffs) {
    lcmDen = _lcm(lcmDen, c.b);
  }

  final intCoeffs = poly.coeffs.map((c) => c.a * (lcmDen ~/ c.b)).toList();

  // 2. Extract content GCD
  var content = 0;
  for (final a in intCoeffs) {
    if (a != 0) content = _gcd(content, a);
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
    return _buildFactoredExpr(scalar: scalar, factors: factors);
  }

  if (currentDeg == 1) {
    final linFactor = _buildLinearFactor(
      primitiveCoeffs[1],
      -primitiveCoeffs[0],
      variable,
    );
    factors[linFactor] = (factors[linFactor] ?? 0) + 1;
    return _buildFactoredExpr(scalar: scalar, factors: factors);
  }

  // 4. Degree >= 2: Rational Root Theorem search
  if (currentDeg >= 3) {
    final a0 = primitiveCoeffs[0];
    final ad = primitiveCoeffs.last;
    final pDivs = _divisors(a0);
    final qDivs = _divisors(ad);

    // Candidates (p, q) where root is p / q
    final candidates = <(int, int)>[];
    for (final q in qDivs) {
      for (final pAbs in pDivs) {
        for (final p in [pAbs, -pAbs]) {
          if (_gcd(p.abs(), q) == 1) {
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
        final quotient = _syntheticDivide(primitiveCoeffs, p, q);
        if (quotient != null) {
          final lin = _buildLinearFactor(q, p, variable);
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
      final s = _integerSqrt(disc);
      if (s != null) {
        final r1 = Fraction(-b + s, 2 * a);
        final r2 = Fraction(-b - s, 2 * a);
        final f1 = _buildLinearFactor(r1.b, r1.a, variable);
        final f2 = _buildLinearFactor(r2.b, r2.a, variable);
        factors[f1] = (factors[f1] ?? 0) + 1;
        factors[f2] = (factors[f2] ?? 0) + 1;
        return _buildFactoredExpr(scalar: scalar, factors: factors);
      }
    }
    // Irreducible quadratic
    final quadExpr = _buildPolyExpr(primitiveCoeffs, variable);
    factors[quadExpr] = (factors[quadExpr] ?? 0) + 1;
    return _buildFactoredExpr(scalar: scalar, factors: factors);
  }

  if (currentDeg == 1) {
    final linFactor = _buildLinearFactor(
      primitiveCoeffs[1],
      -primitiveCoeffs[0],
      variable,
    );
    factors[linFactor] = (factors[linFactor] ?? 0) + 1;
    return _buildFactoredExpr(scalar: scalar, factors: factors);
  }

  // 6. Biquadratic check if degree 4
  if (currentDeg == 4 && primitiveCoeffs[3] == 0 && primitiveCoeffs[1] == 0) {
    final a = primitiveCoeffs[4];
    final b = primitiveCoeffs[2];
    final c = primitiveCoeffs[0];
    final disc = b * b - 4 * a * c;
    if (disc >= 0) {
      final s = _integerSqrt(disc);
      if (s != null) {
        final u1 = Fraction(-b + s, 2 * a);
        final u2 = Fraction(-b - s, 2 * a);
        final q1 = _factorQuadraticInX(u1.b, -u1.a, variable);
        final q2 = _factorQuadraticInX(u2.b, -u2.a, variable);
        _mergeFactorsInto(factors, q1);
        _mergeFactorsInto(factors, q2);
        return _buildFactoredExpr(scalar: scalar, factors: factors);
      }
    }
  }

  // Irreducible higher degree
  final polyExpr = _buildPolyExpr(primitiveCoeffs, variable);
  factors[polyExpr] = (factors[polyExpr] ?? 0) + 1;
  return _buildFactoredExpr(scalar: scalar, factors: factors);
}

Map<Expr, int> _factorQuadraticInX(int a, int c, String variable) {
  // Factors a * x^2 + c
  final res = <Expr, int>{};
  final disc = -4 * a * c;
  if (disc >= 0) {
    final s = _integerSqrt(disc);
    if (s != null) {
      final r1 = Fraction(s, 2 * a);
      final r2 = Fraction(-s, 2 * a);
      final f1 = _buildLinearFactor(r1.b, r1.a, variable);
      final f2 = _buildLinearFactor(r2.b, r2.a, variable);
      res[f1] = (res[f1] ?? 0) + 1;
      res[f2] = (res[f2] ?? 0) + 1;
      return res;
    }
  }
  final quad = _buildPolyExpr([c, 0, a], variable);
  res[quad] = 1;
  return res;
}

void _mergeFactorsInto(Map<Expr, int> target, Map<Expr, int> source) {
  for (final e in source.entries) {
    target[e.key] = (target[e.key] ?? 0) + e.value;
  }
}

List<int>? _syntheticDivide(List<int> coeffs, int p, int q) {
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

Expr _buildLinearFactor(int q, int p, String variable) {
  // Returns (q * x - p)
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

Expr _buildPolyExpr(List<int> coeffs, String variable) {
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

Fraction? _linearRootMagnitude(Expr expr) {
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

bool _isMonomial(Expr expr) => switch (expr) {
  Variable() => true,
  Pow(base: Variable()) => true,
  Mul(left: final l, right: final r) => _isMonomial(l) && _isMonomial(r),
  _ => false,
};

double _factorDegree(Expr expr) => switch (expr) {
  Variable() => 1.0,
  Pow(base: Variable(), exponent: Number(:final value)) => value,
  Pow(base: Variable(), exponent: Neg(expr: Number(:final value))) => -value,
  Mul(left: final l, right: final r) => _factorDegree(l) + _factorDegree(r),
  Add(left: final l, right: final r) => math.max(
    _factorDegree(l),
    _factorDegree(r),
  ),
  Sub(left: final l, right: final r) => math.max(
    _factorDegree(l),
    _factorDegree(r),
  ),
  Neg(:final expr) => _factorDegree(expr),
  Number() => 0.0,
  _ => 0.0,
};

int _compareFactor(Expr a, Expr b) {
  if (identical(a, b)) return 0;
  // 1. Monomials (x, y, x^2) come before compound polynomial factors ((x-2), (x+y))
  final isMonoA = _isMonomial(a);
  final isMonoB = _isMonomial(b);
  if (isMonoA != isMonoB) {
    return isMonoA ? -1 : 1;
  }

  // 2. Ascending polynomial degree (linear before quadratic, etc.)
  final degA = _factorDegree(a);
  final degB = _factorDegree(b);
  if (degA != degB) {
    return degA.compareTo(degB);
  }

  // 3. Primary variable symbol name alphabetically
  final symA = primarySymbol(a);
  final symB = primarySymbol(b);
  final cmpSym = symA.compareTo(symB);
  if (cmpSym != 0) return cmpSym;

  // 4. For linear factors, sort by ascending root magnitude
  if (degA == 1.0) {
    final rA = _linearRootMagnitude(a);
    final rB = _linearRootMagnitude(b);
    if (rA != null && rB != null && rA != rB) {
      return rA.compareTo(rB);
    }
  }

  // 5. Sub (difference) before Add (sum) for identical degree & root magnitude
  final isSubA = a is Sub;
  final isSubB = b is Sub;
  if (isSubA != isSubB) {
    return isSubA ? -1 : 1;
  }

  // 6. Fallback to compareStructural
  return compareStructural(a, b);
}

Expr _buildFactoredExpr({
  required Fraction scalar,
  required Map<Expr, int> factors,
}) {
  if (factors.isEmpty) {
    return RationalNumber.fraction(scalar);
  }

  final sortedFactors = factors.entries.toList()
    ..sort((a, b) => _compareFactor(a.key, b.key));

  Expr? product;
  if (scalar != Fraction.one && scalar != -Fraction.one) {
    product = RationalNumber.fraction(scalar);
  }

  for (final entry in sortedFactors) {
    final factorExpr = entry.value == 1
        ? entry.key
        : Pow(entry.key, RationalNumber(entry.value));
    product = product == null ? factorExpr : Mul(product, factorExpr);
  }

  if (scalar == -Fraction.one) {
    return Neg(product!).simplify();
  }
  return product ?? RationalNumber.fraction(scalar);
}

Expr _cancelFactoredFraction(Expr num, Expr den) {
  final numFactors = <Expr, int>{};
  var numScalar = Fraction.one;
  _flattenFactored(num, numFactors, (s) => numScalar *= s);

  final denFactors = <Expr, int>{};
  var denScalar = Fraction.one;
  _flattenFactored(den, denFactors, (s) => denScalar *= s);

  if (denScalar.a == 0) {
    throw UnsupportedError('Division by zero in factorization');
  }

  // Cancel common symbolic factors
  for (final key in numFactors.keys.toList()) {
    if (denFactors.containsKey(key)) {
      final nExp = numFactors[key]!;
      final dExp = denFactors[key]!;
      final common = math.min(nExp, dExp);
      final newN = nExp - common;
      final newD = dExp - common;
      if (newN == 0) {
        numFactors.remove(key);
      } else {
        numFactors[key] = newN;
      }
      if (newD == 0) {
        denFactors.remove(key);
      } else {
        denFactors[key] = newD;
      }
    }
  }

  final totalScalar = numScalar / denScalar;
  final numExpr = _buildFactoredExpr(scalar: totalScalar, factors: numFactors);
  if (denFactors.isEmpty) {
    return numExpr;
  }
  final denExpr = _buildFactoredExpr(scalar: Fraction.one, factors: denFactors);
  return Div(numExpr, denExpr);
}

Expr _distributePower(Expr base, int exponent) {
  if (exponent == 1) return base;
  if (base is Mul) {
    return Mul(
      _distributePower(base.left, exponent),
      _distributePower(base.right, exponent),
    );
  }
  if (base is Pow && base.exponent is RationalNumber) {
    final existingExp = (base.exponent as RationalNumber).toInt();
    return Pow(base.base, RationalNumber(existingExp * exponent)).simplify();
  }
  return Pow(base, RationalNumber(exponent));
}

Expr _combineFactoredProducts(List<Expr> factoredExprs) {
  final factors = <Expr, int>{};
  var scalar = Fraction.one;

  for (final e in factoredExprs) {
    _flattenFactored(e, factors, (s) => scalar *= s);
  }

  return _buildFactoredExpr(scalar: scalar, factors: factors);
}

void _flattenFactored(
  Expr expr,
  Map<Expr, int> factors,
  void Function(Fraction) onScalar,
) {
  if (expr is RationalNumber) {
    onScalar(expr.toFraction());
  } else if (expr is Neg) {
    onScalar(-Fraction.one);
    _flattenFactored(expr.expr, factors, onScalar);
  } else if (expr is Mul) {
    _flattenFactored(expr.left, factors, onScalar);
    _flattenFactored(expr.right, factors, onScalar);
  } else if (expr is Pow && expr.exponent is RationalNumber) {
    final exp = expr.exponent as RationalNumber;
    if (exp.isInteger && exp.numerator > 0) {
      factors[expr.base] = (factors[expr.base] ?? 0) + exp.numerator;
    } else {
      factors[expr] = (factors[expr] ?? 0) + 1;
    }
  } else {
    factors[expr] = (factors[expr] ?? 0) + 1;
  }
}

void _collectAdditiveTerms(Expr expr, int sign, List<Expr> result) {
  switch (expr) {
    case Add(:final left, :final right):
      _collectAdditiveTerms(left, sign, result);
      _collectAdditiveTerms(right, sign, result);
    case Sub(:final left, :final right):
      _collectAdditiveTerms(left, sign, result);
      _collectAdditiveTerms(right, -sign, result);
    case Neg(:final expr):
      _collectAdditiveTerms(expr, -sign, result);
    default:
      if (expr is! RationalNumber || !expr.isZero) {
        result.add(sign == 1 ? expr : (-expr).simplify());
      }
  }
}

Expr? _extractMonomialGcd(List<Expr> terms) {
  if (terms.isEmpty) return null;
  var lcmDen = 1;
  final termCoeffs = <Fraction>[];
  final varPowers = <Map<String, int>>[];

  for (final t in terms) {
    final (c, base) = decomposeTerm(t);
    lcmDen = _lcm(lcmDen, c.b);
    termCoeffs.add(c);
    final powers = <String, int>{};
    _collectVariablePowers(base, powers);
    varPowers.add(powers);
  }

  var content = 0;
  for (final c in termCoeffs) {
    final intVal = (c.a * (lcmDen ~/ c.b)).abs();
    if (intVal != 0) content = _gcd(content, intVal);
  }
  if (content == 0) content = 1;

  final commonVars = <String, int>{};
  for (final v in varPowers.first.keys) {
    var minP = varPowers.first[v]!;
    var presentInAll = true;
    for (var i = 1; i < varPowers.length; i++) {
      final p = varPowers[i][v] ?? 0;
      if (p == 0) {
        presentInAll = false;
        break;
      }
      minP = math.min(minP, p);
    }
    if (presentInAll && minP > 0) {
      commonVars[v] = minP;
    }
  }

  final scalarGcd = Fraction(content, lcmDen);
  if (scalarGcd == Fraction.one && commonVars.isEmpty) return null;

  Expr result = RationalNumber.fraction(scalarGcd);
  for (final e in commonVars.entries) {
    final vExpr = e.value == 1
        ? Variable(e.key)
        : Pow(Variable(e.key), RationalNumber(e.value));
    result = result is RationalNumber && result.isOne
        ? vExpr
        : Mul(result, vExpr);
  }
  return result.simplify();
}

void _collectVariablePowers(Expr expr, Map<String, int> target) {
  if (expr is Variable) {
    target[expr.name] = (target[expr.name] ?? 0) + 1;
  } else if (expr is Pow &&
      expr.base is Variable &&
      expr.exponent is RationalNumber) {
    final exp = expr.exponent as RationalNumber;
    if (exp.isInteger && exp.numerator > 0) {
      final v = expr.base as Variable;
      target[v.name] = (target[v.name] ?? 0) + exp.numerator;
    }
  } else if (expr is Mul) {
    _collectVariablePowers(expr.left, target);
    _collectVariablePowers(expr.right, target);
  }
}

Expr _divideMonomial(Expr term, Expr gcd) {
  final (cTerm, bTerm) = decomposeTerm(term);
  final (cGcd, bGcd) = decomposeTerm(gcd);
  final coeff = cTerm / cGcd;
  final powersTerm = <String, int>{};
  _collectVariablePowers(bTerm, powersTerm);
  final powersGcd = <String, int>{};
  _collectVariablePowers(bGcd, powersGcd);
  final remainingPowers = <String, int>{};
  for (final entry in powersTerm.entries) {
    final rem = entry.value - (powersGcd[entry.key] ?? 0);
    if (rem > 0) remainingPowers[entry.key] = rem;
  }
  Expr result = RationalNumber.fraction(coeff);
  for (final entry in remainingPowers.entries) {
    final factor = entry.value == 1
        ? Variable(entry.key)
        : Pow(Variable(entry.key), RationalNumber(entry.value));
    if (result is RationalNumber && result.isOne) {
      result = factor;
    } else if (result is RationalNumber && result.isNegativeOne) {
      result = Neg(factor);
    } else {
      result = Mul(result, factor);
    }
  }
  return result.simplify();
}

Expr? _factorByGrouping4(List<Expr> terms) {
  if (terms.length != 4) return null;

  final partitions = [
    ((terms[0], terms[1]), (terms[2], terms[3])),
    ((terms[0], terms[2]), (terms[1], terms[3])),
    ((terms[0], terms[3]), (terms[1], terms[2])),
  ];

  for (final ((t1, t2), (t3, t4)) in partitions) {
    final g1 = _extractMonomialGcd([t1, t2]) ?? RationalNumber.one;
    final g2 = _extractMonomialGcd([t3, t4]) ?? RationalNumber.one;

    final r1 = Add(_divideMonomial(t1, g1), _divideMonomial(t2, g1)).simplify();
    final r2 = Add(_divideMonomial(t3, g2), _divideMonomial(t4, g2)).simplify();

    if (r1 == r2) {
      final factorA = (g1 + g2).simplify().factor();
      final factorB = r1.factor();
      return _combineFactoredProducts([factorA, factorB]);
    }
    if (r1 == (-r2).simplify()) {
      final factorA = (g1 - g2).simplify().factor();
      final factorB = r1.factor();
      return _combineFactoredProducts([factorA, factorB]);
    }
  }
  return null;
}

(Expr, Expr)? _matchDifferenceOfSquares(List<Expr> terms) {
  if (terms.length != 2) return null;
  final t1 = terms[0];
  final t2 = terms[1];

  final (c1, base1) = decomposeTerm(t1);
  final (c2, base2) = decomposeTerm(t2);

  if (c1.a > 0 && c2.a < 0) {
    final sq1 = _monomialSquareRoot(c1, base1);
    final sq2 = _monomialSquareRoot(-c2, base2);
    if (sq1 != null && sq2 != null) return (sq1, sq2);
  } else if (c2.a > 0 && c1.a < 0) {
    final sq1 = _monomialSquareRoot(c2, base2);
    final sq2 = _monomialSquareRoot(-c1, base1);
    if (sq1 != null && sq2 != null) return (sq1, sq2);
  }
  return null;
}

Expr? _monomialSquareRoot(Fraction coeff, Expr base) {
  final numSqrt = _integerSqrt(coeff.a);
  final denSqrt = _integerSqrt(coeff.b);
  if (numSqrt == null || denSqrt == null) return null;
  final scalar = RationalNumber(numSqrt, denSqrt);

  final baseSqrt = _extractBaseSquareRoot(base);
  if (baseSqrt == null) return null;

  return scalar.isOne ? baseSqrt : Mul(scalar, baseSqrt).simplify();
}

Expr? _extractBaseSquareRoot(Expr expr) {
  if (expr is RationalNumber && expr.isOne) return RationalNumber.one;
  if (expr is Pow && expr.exponent is RationalNumber) {
    final exp = expr.exponent as RationalNumber;
    if (exp.isInteger && exp.numerator % 2 == 0) {
      final half = exp.numerator ~/ 2;
      return half == 1 ? expr.base : Pow(expr.base, RationalNumber(half));
    }
  }
  if (expr is Mul) {
    final l = _extractBaseSquareRoot(expr.left);
    final r = _extractBaseSquareRoot(expr.right);
    if (l != null && r != null) return Mul(l, r).simplify();
  }
  if (expr is Variable) {
    return null;
  }
  return null;
}

bool _isOne(Expr expr) =>
    (expr is RationalNumber && expr.isOne) ||
    (expr is RealNumber && expr.value == 1.0);

int _gcd(int a, int b) {
  var x = a.abs();
  var y = b.abs();
  while (y != 0) {
    final t = y;
    y = x % y;
    x = t;
  }
  return x;
}

int _lcm(int a, int b) {
  if (a == 0 || b == 0) return 0;
  return (a.abs() ~/ _gcd(a, b)) * b.abs();
}

int? _integerSqrt(int n) {
  if (n < 0) return null;
  if (n == 0) return 0;
  final r = math.sqrt(n).round();
  if (r * r == n) return r;
  return null;
}

List<int> _divisors(int n) {
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
