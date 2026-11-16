import '../../algebra/expand.dart';
import '../../algebra/simplify.dart';
import '../../algebra/term_accumulator.dart';
import '../../assumptions.dart';
import '../../ast.dart';
import '../../number/integer.dart';
import '../linear_form.dart';
import 'definite.dart';
import 'integration.dart';

Expr? tryRadicalQuadratic(Expr base, String variable) {
  if (base case Add(terms: [final t0, final t1])) {
    final aConst = !t0.dependsOn(variable)
        ? t0
        : (!t1.dependsOn(variable) ? t1 : null);
    final varTerm = !t0.dependsOn(variable) ? t1 : t0;
    if (aConst == null) return null;

    final rad = Pow(base, FractionNumber.half).simplify();
    if (isSymbolicPositive(aConst)) {
      final sqrtA = Pow(aConst, FractionNumber.half).simplify();
      // 1. sqrt(a - u^2) where u = m*x + b
      final negVar = (-varTerm).simplify();
      if (extractScaledSquareBase(negVar, variable) case final u?) {
        if (u.matchLinear(variable) case (a: final slope, b: _)) {
          return ((u * rad / IntegerNumber.two +
                      (aConst / IntegerNumber.two) * Asin(u / sqrtA)) /
                  slope)
              .simplify();
        }
      }
      // 2. sqrt(a + u^2) where u = m*x + b
      if (extractScaledSquareBase(varTerm, variable) case final u?) {
        if (u.matchLinear(variable) case (a: final slope, b: _)) {
          return ((u * rad / IntegerNumber.two +
                      (aConst / IntegerNumber.two) * Asinh(u / sqrtA)) /
                  slope)
              .simplify();
        }
      }
    } else if (isSymbolicPositive((-aConst).simplify())) {
      // 3. sqrt(u^2 - a) where a = -aConst > 0 and u = m*x + b
      final posA = (-aConst).simplify();
      if (extractScaledSquareBase(varTerm, variable) case final u?) {
        if (u.matchLinear(variable) case (a: final slope, b: _)) {
          return ((u * rad / IntegerNumber.two -
                      (posA / IntegerNumber.two) *
                          Ln(Abs((u + rad).simplify()))) /
                  slope)
              .simplify();
        }
      }
    }
  }
  return null;
}

Expr? tryQuadraticRadical(
  Expr numerator,
  Expr quad,
  int halfExp,
  String variable,
) {
  final numCoeffs = extractPolynomialCoefficients(numerator, variable);
  if (numCoeffs == null || maxPolynomialDegree(numCoeffs) > 1) return null;
  final p = numCoeffs[1] ?? IntegerNumber.zero;
  final q = numCoeffs[0] ?? IntegerNumber.zero;

  final quadCoeffs = extractPolynomialCoefficients(quad, variable);
  if (quadCoeffs == null || maxPolynomialDegree(quadCoeffs) != 2) return null;
  final a = quadCoeffs[2] ?? IntegerNumber.zero;
  final b = quadCoeffs[1] ?? IntegerNumber.zero;
  final c = quadCoeffs[0] ?? IntegerNumber.zero;

  if (p == IntegerNumber.zero) {
    final rem = _tryQuadraticRadicalConst(quad, a, b, c, halfExp, variable);
    return rem == null ? null : (q * rem).simplify();
  }

  final twoA = (IntegerNumber.two * a).simplify();
  final leadTerm =
      (p / (a * IntegerNumber.of(halfExp + 2))) *
      Pow(quad, FractionNumber(Integer(halfExp + 2), Integer.two));
  final qRem = (q - (p * b) / twoA).simplify();
  if (qRem == IntegerNumber.zero) return leadTerm.simplify();

  final rem = _tryQuadraticRadicalConst(quad, a, b, c, halfExp, variable);
  if (rem == null) return null;
  return (leadTerm + qRem * rem).simplify();
}

Expr? _tryQuadraticRadicalConst(
  Expr quad,
  Expr a,
  Expr b,
  Expr c,
  int halfExp,
  String variable,
) {
  final twoA = (IntegerNumber.two * a).simplify();
  final twoAxPlusB = (twoA * Variable(variable) + b).simplify();
  final disc = (const IntegerNumber(Integer(4)) * a * c - b * b).simplify();

  if (halfExp == -1) {
    if (disc == IntegerNumber.zero) return null;
    if (isSyntacticallyNegative(a) || isNegativeConstant(a)) {
      final negA = (-a).simplify();
      final sqrtNegA = Pow(negA, FractionNumber.half).simplify();
      final b2Minus4ac = (-disc).simplify();
      final sqrtDisc = Pow(b2Minus4ac, FractionNumber.half).simplify();
      final arg = ((-twoAxPlusB) / sqrtDisc).simplify();
      return (Asin(arg) / sqrtNegA).simplify();
    }
    final sqrtA = Pow(a, FractionNumber.half).simplify();
    if (isSyntacticallyNegative(disc) || isNegativeConstant(disc)) {
      final rad = Pow(quad, FractionNumber.half).simplify();
      final logArg = (twoAxPlusB + IntegerNumber.two * sqrtA * rad).simplify();
      return (Ln(Abs(logArg)) / sqrtA).simplify();
    }
    final sqrtDisc = Pow(disc, FractionNumber.half).simplify();
    final arg = (twoAxPlusB / sqrtDisc).simplify();
    return (Asinh(arg) / sqrtA).simplify();
  }

  if (halfExp == -3) {
    if (disc == IntegerNumber.zero) return null;
    final rad = Pow(quad, FractionNumber.half).simplify();
    return ((IntegerNumber.two * twoAxPlusB) / (disc * rad)).simplify();
  }

  if (halfExp <= -5) {
    if (disc == IntegerNumber.zero) return null;
    final m = -halfExp;
    final prev = _tryQuadraticRadicalConst(
      quad,
      a,
      b,
      c,
      halfExp + 2,
      variable,
    );
    if (prev == null) return null;
    final mMinus2 = IntegerNumber.of(m - 2);
    final mMinus3 = IntegerNumber.of(m - 3);
    final denom = (mMinus2 * disc).simplify();
    final term1 =
        (IntegerNumber.two * twoAxPlusB) /
        (denom * Pow(quad, FractionNumber(Integer(m - 2), Integer.two)));
    final term2 =
        (const IntegerNumber(Integer(4)) * a * mMinus3 / denom) * prev;
    return (term1 + term2).simplify();
  }

  if (halfExp >= 1) {
    final prev = _tryQuadraticRadicalConst(
      quad,
      a,
      b,
      c,
      halfExp - 2,
      variable,
    );
    if (prev == null) return null;
    final nPlus1 = IntegerNumber.of(halfExp + 1);
    final term1 =
        (twoAxPlusB *
            Pow(quad, FractionNumber(Integer(halfExp), Integer.two))) /
        (twoA * nPlus1);
    final term2 =
        (IntegerNumber.of(halfExp) *
            disc /
            (const IntegerNumber(Integer(4)) * a * nPlus1)) *
        prev;
    return (term1 + term2).simplify();
  }

  return null;
}

int _gcdInt(int a, int b) {
  var x = a.abs();
  var y = b.abs();
  while (y != 0) {
    final t = x % y;
    x = y;
    y = t;
  }
  return x;
}

int _lcmInt(int a, int b) => (a * b) ~/ _gcdInt(a, b);

({int p, int q})? _fractionalExponent(Expr exponent) {
  if (exponent case FractionNumber(:final numerator, :final denominator)) {
    final p = numerator.asInt;
    final q = denominator.asInt;
    if (p != null && q != null && p.abs() <= 12 && q >= 2 && q <= 6) {
      return (p: p, q: q);
    }
  }
  if (exponent is RealNumber && exponent.value.abs() == 0.5) {
    return (p: exponent.value > 0 ? 1 : -1, q: 2);
  }
  return null;
}

void _collectAffineRadicals(
  Expr node,
  String variable,
  List<({Expr base, int p, int q})> out,
) {
  if (node case Pow(:final base, :final exponent)) {
    if (base.dependsOn(variable) && base.matchLinear(variable) != null) {
      if (_fractionalExponent(exponent) case (:final p, :final q)) {
        out.add((base: base, p: p, q: q));
        return;
      }
    }
  }
  node.mapChildren((child) {
    _collectAffineRadicals(child, variable, out);
    return child;
  });
}

Expr _replaceAffineRadical(
  Expr node,
  Expr targetBase,
  String variable,
  Variable uVar,
  int n,
  Expr a,
  Expr b,
) {
  if (node case Pow(:final base, :final exponent) when base == targetBase) {
    if (_fractionalExponent(exponent) case (:final p, :final q)) {
      return Pow(uVar, IntegerNumber.of((p * n) ~/ q));
    }
  }
  if (node is Variable && node.name == variable) {
    return ((Pow(uVar, IntegerNumber.of(n)) - b) / a).simplify();
  }
  return node.mapChildren(
    (child) =>
        _replaceAffineRadical(child, targetBase, variable, uVar, n, a, b),
  );
}

Expr? tryAffineRadicalSubstitution(
  Expr expr,
  String variable, {
  Assumptions assumptions = Assumptions.none,
  int depth = 0,
}) {
  final radicals = <({Expr base, int p, int q})>[];
  _collectAffineRadicals(expr, variable, radicals);
  if (radicals.isEmpty) return null;

  final firstBase = radicals.first.base;
  if (!radicals.every((r) => r.base == firstBase)) return null;
  final linear = firstBase.matchLinear(variable);
  if (linear == null) return null;
  final (:a, :b) = linear;

  var n = 1;
  for (final r in radicals) {
    n = _lcmInt(n, r.q);
    if (n > 6) return null;
  }
  if (n < 2) return null;

  final uName = '_u$depth';
  final uVar = Variable(uName);
  final replaced = _replaceAffineRadical(
    expr,
    firstBase,
    variable,
    uVar,
    n,
    a,
    b,
  );
  final dx = (IntegerNumber.of(n) * Pow(uVar, IntegerNumber.of(n - 1))) / a;
  final transformed = (replaced * dx).expand().simplify(
    assumptions: assumptions,
  );
  if (transformed.dependsOn(variable)) return null;

  final uAntideriv = antiDerivative(
    transformed,
    uName,
    assumptions: assumptions,
    depth: depth + 1,
  );
  if (hasUnevaluatedIntegral(uAntideriv, uName)) return null;

  final backSub = Pow(firstBase, FractionNumber(Integer.one, Integer(n)));
  return uAntideriv
      .substitute(uName, backSub)
      .simplify(assumptions: assumptions);
}

Expr? tryChebyshevBinomial(
  Expr expr,
  String variable, {
  Assumptions assumptions = Assumptions.none,
  int depth = 0,
}) {
  final factors = expr is Mul ? expr.factors : [expr];
  var constScale = IntegerNumber.one as Expr;
  var m = 0;
  Pow? binomPow;

  for (final f in factors) {
    if (!f.dependsOn(variable)) {
      constScale = (constScale * f).simplify();
      continue;
    }
    if (f is Variable && f.name == variable) {
      m += 1;
      continue;
    }
    if (f case Pow(base: Variable(:final name), :final exponent)
        when name == variable) {
      if (exponent case IntegerNumber(:final asInt) when asInt != null) {
        m += asInt;
        continue;
      }
      return null;
    }
    if (f is Pow && binomPow == null) {
      binomPow = f;
      continue;
    }
    return null;
  }

  if (binomPow == null) return null;
  final fracExp = _fractionalExponent(binomPow.exponent);
  if (fracExp == null) return null;
  final (:p, :q) = fracExp;

  final baseCoeffs = extractPolynomialCoefficients(binomPow.base, variable);
  if (baseCoeffs == null) return null;
  final n = maxPolynomialDegree(baseCoeffs);
  if (n < 2) return null;
  for (var deg = 1; deg < n; deg++) {
    if (baseCoeffs[deg] != null && baseCoeffs[deg] != IntegerNumber.zero) {
      return null;
    }
  }
  final a = baseCoeffs[0] ?? IntegerNumber.zero;
  final b = baseCoeffs[n] ?? IntegerNumber.zero;
  if (a == IntegerNumber.zero || b == IntegerNumber.zero) return null;

  final uName = '_u$depth';
  final uVar = Variable(uName);

  // Case 1: (m + 1) / n is a positive integer k
  if ((m + 1) > 0 && (m + 1) % n == 0) {
    final k = (m + 1) ~/ n;
    if (k <= 8) {
      final transformed =
          (constScale *
                  (IntegerNumber.one / (IntegerNumber.of(n) * b)) *
                  Pow((uVar - a) / b, IntegerNumber.of(k - 1)) *
                  Pow(uVar, FractionNumber(Integer(p), Integer(q))))
              .expand()
              .simplify(assumptions: assumptions);
      final uAntideriv = antiDerivative(
        transformed,
        uName,
        assumptions: assumptions,
        depth: depth + 1,
      );
      if (!hasUnevaluatedIntegral(uAntideriv, uName)) {
        return uAntideriv
            .substitute(uName, binomPow.base)
            .simplify(assumptions: assumptions);
      }
    }
  }

  // Case 2: (m + 1) / n + p / q is an integer r
  final numSum = (m + 1) * q + p * n;
  final denProd = n * q;
  if (numSum % denProd == 0) {
    final r = numSum ~/ denProd;
    if (r.abs() <= 6) {
      final transformed =
          (constScale *
                  (-IntegerNumber.of(q) / (IntegerNumber.of(n) * a)) *
                  Pow(uVar, IntegerNumber.of(q - 1 + p)) *
                  Pow(
                    (Pow(uVar, IntegerNumber.of(q)) - b) / a,
                    IntegerNumber.of(-(r + 1)),
                  ))
              .expand()
              .simplify(assumptions: assumptions);
      final uAntideriv = antiDerivative(
        transformed,
        uName,
        assumptions: assumptions,
        depth: depth + 1,
      );
      if (!hasUnevaluatedIntegral(uAntideriv, uName)) {
        final backSub = Pow(
          (a * Pow(Variable(variable), IntegerNumber.of(-n)) + b).simplify(),
          FractionNumber(Integer.one, Integer(q)),
        );
        return uAntideriv
            .substitute(uName, backSub)
            .simplify(assumptions: assumptions);
      }
    }
  }

  return null;
}

Expr? tryPolynomialOverSqrtQuadratic(Expr left, Expr right, String variable) {
  // Case 1: P(x) / sqrt(Ax^2 + Bx + C) with deg(P) >= 2
  if (right case Pow(base: final quad, exponent: final exp)
      when halfIntExponent(exp) == 1) {
    final coeffs = extractPolynomialCoefficients(quad, variable);
    if (coeffs != null && maxPolynomialDegree(coeffs) == 2) {
      final rawDegLeft = polynomialDegree(left, variable);
      if (rawDegLeft != null && rawDegLeft >= 2 && rawDegLeft <= 6) {
        final leftExp = left.expand().simplify();
        final degLeft = polynomialDegree(leftExp, variable);
        if (degLeft != null && degLeft >= 2 && degLeft <= 6) {
          return _integratePolyOverSqrtQ(
            leftExp,
            quad,
            coeffs[2] ?? IntegerNumber.zero,
            coeffs[1] ?? IntegerNumber.zero,
            coeffs[0] ?? IntegerNumber.zero,
            variable,
          );
        }
      }
    }
  }

  // Case 2: sqrt(Ax^2 + Bx + C) / x^k (k >= 1)
  if (left case Pow(base: final quad, exponent: final exp)
      when halfIntExponent(exp) == 1) {
    final coeffs = extractPolynomialCoefficients(quad, variable);
    if (coeffs != null && maxPolynomialDegree(coeffs) == 2) {
      int? k;
      if (right is Variable && right.name == variable) {
        k = 1;
      } else if (right
          case Pow(
            base: Variable(:final name),
            exponent: IntegerNumber(asInt: final p?),
          )
          when name == variable && p >= 1 && p <= 4) {
        k = p;
      }
      if (k != null) {
        final a = coeffs[2] ?? IntegerNumber.zero;
        final b = coeffs[1] ?? IntegerNumber.zero;
        final c = coeffs[0] ?? IntegerNumber.zero;
        final xVar = Variable(variable);
        // sqrt(Q)/x^k = A*x^(2-k)/sqrt(Q) + B*x^(1-k)/sqrt(Q) + C/(x^k * sqrt(Q))
        final term1 = k == 1
            ? antiDerivative((a * xVar / left).simplify(), variable)
            : (k == 2
                  ? antiDerivative((a / left).simplify(), variable)
                  : tryPolynomialOverSqrtQuadratic(
                      a,
                      Pow(xVar, IntegerNumber.of(k - 2)) * left,
                      variable,
                    ));
        final term2 = k == 1
            ? antiDerivative((b / left).simplify(), variable)
            : tryPolynomialOverSqrtQuadratic(
                b,
                Pow(xVar, IntegerNumber.of(k - 1)) * left,
                variable,
              );
        final term3 = tryPolynomialOverSqrtQuadratic(
          c,
          (right * left).simplify(),
          variable,
        );
        if (term1 != null &&
            term2 != null &&
            term3 != null &&
            !hasUnevaluatedIntegral(term1, variable) &&
            !hasUnevaluatedIntegral(term2, variable)) {
          return (term1 + term2 + term3).simplify();
        }
      }
    }
  }

  // Case 3: c / (x^k * sqrt(Ax^2 + Bx + C)) (k >= 1) via t = 1/x
  if (!left.dependsOn(variable) && right is Mul) {
    final factors = right.factors;
    var k = 0;
    Pow? rad;
    var valid = true;
    for (final f in factors) {
      if (f is Variable && f.name == variable) {
        k += 1;
      } else if (f
          case Pow(
            base: Variable(:final name),
            exponent: IntegerNumber(asInt: final p?),
          )
          when name == variable && p >= 1) {
        k += p;
      } else if (f is Pow && halfIntExponent(f.exponent) == 1 && rad == null) {
        rad = f;
      } else {
        valid = false;
      }
    }
    if (valid && k >= 1 && k <= 4 && rad != null) {
      final coeffs = extractPolynomialCoefficients(rad.base, variable);
      if (coeffs != null && maxPolynomialDegree(coeffs) == 2) {
        final a = coeffs[2] ?? IntegerNumber.zero;
        final b = coeffs[1] ?? IntegerNumber.zero;
        final c = coeffs[0] ?? IntegerNumber.zero;
        if (c != IntegerNumber.zero) {
          const tName = '_inv';
          const tVar = Variable(tName);
          final qT = (c * tVar * tVar + b * tVar + a).simplify();
          final numT =
              (-left *
                      (k == 1
                          ? IntegerNumber.one
                          : Pow(tVar, IntegerNumber.of(k - 1))))
                  .simplify();
          final tInt = antiDerivative(
            (numT / Pow(qT, FractionNumber.half)).simplify(),
            tName,
            depth: 2,
          );
          if (!hasUnevaluatedIntegral(tInt, tName)) {
            return tInt
                .substitute(tName, IntegerNumber.one / Variable(variable))
                .simplify();
          }
        }
      }
    }
  }

  return null;
}

Expr? _integratePolyOverSqrtQ(
  Expr poly,
  Expr quad,
  Expr a,
  Expr b,
  Expr c,
  String variable,
) {
  final coeffs = extractPolynomialCoefficients(poly, variable);
  if (coeffs == null) return null;
  final deg = maxPolynomialDegree(coeffs);
  if (deg <= 1) {
    return tryQuadraticRadical(poly, quad, -1, variable);
  }
  final leadCoeff = coeffs[deg]!;
  final m = deg;
  final xVar = Variable(variable);
  final rad = Pow(quad, FractionNumber.half);
  final term1 =
      (leadCoeff *
              Pow(xVar, IntegerNumber.of(m - 1)) *
              rad /
              (IntegerNumber.of(m) * a))
          .simplify();

  final rem1 =
      (-leadCoeff *
              IntegerNumber.of(2 * m - 1) *
              b /
              (IntegerNumber.two * IntegerNumber.of(m) * a) *
              Pow(xVar, IntegerNumber.of(m - 1)))
          .simplify();
  final rem2 =
      (-leadCoeff *
              IntegerNumber.of(m - 1) *
              c /
              (IntegerNumber.of(m) * a) *
              (m - 2 == 0
                  ? IntegerNumber.one
                  : Pow(xVar, IntegerNumber.of(m - 2))))
          .simplify();
  final lowerPoly =
      (poly - leadCoeff * Pow(xVar, IntegerNumber.of(m)) + rem1 + rem2)
          .expand()
          .simplify();
  final remInt = _integratePolyOverSqrtQ(lowerPoly, quad, a, b, c, variable);
  if (remInt == null) return null;
  return (term1 + remInt).simplify();
}

Expr? tryFractionalLinearRadical(
  Expr expr,
  String variable, {
  Assumptions assumptions = Assumptions.none,
  int depth = 0,
}) {
  Pow? targetPow;
  ({int p, int q})? frac;
  void scan(Expr n) {
    if (targetPow != null || !n.dependsOn(variable)) return;
    if (n case Pow(:final base, :final exponent)) {
      if (_fractionalExponent(exponent) case final fq? when fq.q <= 4) {
        final (numB, denB) = splitNumeratorDenominator(base);
        if (numB.matchLinear(variable) != null &&
            denB.dependsOn(variable) &&
            denB.matchLinear(variable) != null) {
          targetPow = n;
          frac = fq;
          return;
        }
      }
    }
    n.mapChildren((c) {
      scan(c);
      return c;
    });
  }

  scan(expr);
  if (targetPow == null || frac == null) return null;

  final (numB, denB) = splitNumeratorDenominator(targetPow!.base);
  final (:a, :b) = numB.matchLinear(variable)!;
  final (a: c, b: d) = denB.matchLinear(variable)!;
  final n = frac!.q;

  const uName = '_fl';
  const uVar = Variable(uName);
  final uPowN = Pow(uVar, IntegerNumber.of(n));
  final xOfU = ((d * uPowN - b) / (a - c * uPowN)).simplify();
  final dx =
      (IntegerNumber.of(n) *
              (a * d - b * c) *
              Pow(uVar, IntegerNumber.of(n - 1)) /
              Pow(a - c * uPowN, IntegerNumber.two))
          .simplify();

  Expr replaceNode(Expr node) {
    if (node == targetPow) return Pow(uVar, IntegerNumber.of(frac!.p));
    if (node is Variable && node.name == variable) return xOfU;
    return node.mapChildren(replaceNode);
  }

  final transformed = (replaceNode(expr) * dx).simplify(
    assumptions: assumptions,
  );
  if (transformed.dependsOn(variable)) return null;
  final uInt = antiDerivative(
    transformed,
    uName,
    assumptions: assumptions,
    depth: 2,
  );
  if (hasUnevaluatedIntegral(uInt, uName)) return null;

  final backSub = Pow(targetPow!.base, FractionNumber(Integer.one, Integer(n)));
  return uInt.substitute(uName, backSub).simplify(assumptions: assumptions);
}
