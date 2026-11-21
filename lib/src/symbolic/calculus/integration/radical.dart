import '../../algebra/expand.dart';
import '../../algebra/rational.dart';
import '../../algebra/simplify.dart';
import '../../algebra/simplify/domain.dart';
import '../../algebra/term_accumulator.dart';
import '../../assumptions.dart';
import '../../ast.dart';
import '../../number/integer.dart';
import '../linear_form.dart';
import 'definite.dart';
import 'integration.dart';

/// Factors common monomials `x^m` or perfect-square trinomials out of
/// fractional-power radicands and delegates to [antiDerivative].
Expr? tryFactorRadicandPower(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  if (depth >= 2) return null;
  final factors = expr is Mul ? expr.factors : [expr];
  final xVar = Variable(variable);

  Expr rebuild(int idx, Expr replacement) => Mul([
    for (var j = 0; j < factors.length; j++)
      if (j == idx) replacement else factors[j],
  ]).simplify(assumptions: assumptions);

  for (var i = 0; i < factors.length; i++) {
    final factor = factors[i];
    if (factor case Pow(:final base, exponent: final FractionNumber exp)
        when base.dependsOn(variable)) {
      final k = halfIntExponent(exp);
      if (k != null && k.isOdd && k.abs() <= 9 && base is Mul) {
        final varPart = [
          for (final f in base.factors)
            if (f.dependsOn(variable)) f,
        ];
        if (varPart.length == 1) {
          if (varPart.first case Pow(
            base: final f,
            exponent: IntegerNumber(asInt: 2),
          )) {
            final isLinearTrigOrHyp = switch (f) {
              Sin(:final expr) ||
              Cos(:final expr) ||
              Tan(:final expr) ||
              Sinh(:final expr) ||
              Cosh(:final expr) ||
              Tanh(:final expr) => expr.matchLinear(variable) != null,
              _ => false,
            };
            if (isLinearTrigOrHyp) {
              final fPowK = Pow(
                f,
                IntegerNumber.of(k),
              ).simplify(assumptions: assumptions);
              final scaleFactor = (factor / fPowK).simplify(
                assumptions: assumptions,
              );
              final rewritten = rebuild(i, fPowK);
              final res = antiDerivative(
                rewritten,
                variable,
                depth: depth + 1,
                assumptions: assumptions,
              );
              if (!hasUnevaluatedIntegral(res, variable)) {
                return (scaleFactor * res).simplify(assumptions: assumptions);
              }
            }
          }
        }
      }

      final coeffs = extractPolynomialCoefficients(base, variable);
      if (coeffs == null) continue;
      final nonZero = [
        for (final entry in coeffs.entries)
          if (entry.value is! Number || !(entry.value as Number).isZero) entry,
      ];
      if (nonZero.length < 2) continue;

      final minDeg = nonZero.map((e) => e.key).reduce((a, b) => a < b ? a : b);
      if (minDeg >= 1) {
        final quotientPoly = Add([
          for (final entry in nonZero)
            entry.value * Pow(xVar, IntegerNumber.of(entry.key - minDeg)),
        ]).simplify(assumptions: assumptions);
        final replacement =
            (Pow(xVar, (IntegerNumber.of(minDeg) * exp).simplify()) *
                    Pow(quotientPoly, exp))
                .simplify(assumptions: assumptions);
        final rewritten = rebuild(i, replacement);
        final res = antiDerivative(
          rewritten,
          variable,
          depth: depth + 1,
          assumptions: assumptions,
        );
        if (!hasUnevaluatedIntegral(res, variable)) return res;
      }

      for (final k in const [1, 2, 3]) {
        if (nonZero.length == 3 &&
            nonZero.every((e) => e.key == 0 || e.key == k || e.key == 2 * k)) {
          final a = coeffs[2 * k]!;
          final b = coeffs[k]!;
          final c = coeffs[0]!;
          final disc = (b * b - IntegerNumber.of(4) * a * c).expand().simplify(
            assumptions: assumptions,
          );
          if (disc is Number && disc.isZero) {
            final sqrtA = _factorEvenPowerSqrt(a, assumptions);
            final sqrtC = _factorEvenPowerSqrt(c, assumptions);
            final signRatio = (b / (IntegerNumber.two * sqrtA * sqrtC))
                .expand()
                .simplify(assumptions: assumptions);
            final s = signRatio == IntegerNumber.negativeOne
                ? IntegerNumber.negativeOne
                : IntegerNumber.one;
            final inner = (sqrtA * Pow(xVar, IntegerNumber.of(k)) + s * sqrtC)
                .simplify(assumptions: assumptions);
            final newExp = (IntegerNumber.two * exp).simplify(
              assumptions: assumptions,
            );
            final rewritten = rebuild(i, Pow(inner, newExp));
            final res = antiDerivative(
              rewritten,
              variable,
              depth: depth + 1,
              assumptions: assumptions,
            );
            if (!hasUnevaluatedIntegral(res, variable)) return res;
          }
        }
      }
    }
  }
  return null;
}

/// Integrates half-integer powers `(a +/- a*sin(u))^(k/2)` and
/// `(a +/- a*cos(u))^(k/2)` via half-angle identities.
Expr? tryHalfAngleTrigRadical(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  if (depth >= 2) return null;

  var constScale = IntegerNumber.one as Expr;
  Pow? targetPow;
  if (expr is Pow) {
    targetPow = expr;
  } else if (expr is Mul) {
    final consts = <Expr>[];
    final vars = <Expr>[];
    for (final f in expr.factors) {
      if (f.dependsOn(variable)) {
        vars.add(f);
      } else {
        consts.add(f);
      }
    }
    if (vars.length == 1 && vars.first is Pow) {
      targetPow = vars.first as Pow;
      if (consts.isNotEmpty) {
        constScale = Mul(consts).simplify(assumptions: assumptions);
      }
    }
  }
  if (targetPow == null) return null;

  final k = halfIntExponent(targetPow.exponent);
  if (k == null || k.isEven || k.abs() > 9) return null;

  if (targetPow.base case Add(terms: [final t0, final t1])) {
    final Expr? a;
    final Expr trigTerm;
    if (!t0.dependsOn(variable) && t1.dependsOn(variable)) {
      a = t0;
      trigTerm = t1;
    } else if (!t1.dependsOn(variable) && t0.dependsOn(variable)) {
      a = t1;
      trigTerm = t0;
    } else {
      return null;
    }

    final trigFactors = trigTerm is Mul ? trigTerm.factors : [trigTerm];
    final trigConst = <Expr>[];
    final trigVar = <Expr>[];
    for (final f in trigFactors) {
      if (f.dependsOn(variable)) {
        trigVar.add(f);
      } else {
        trigConst.add(f);
      }
    }
    if (trigVar.length != 1) return null;
    final trigNode = trigVar.first;
    final bool isSin;
    final Expr u;
    if (trigNode case Sin(:final expr)) {
      isSin = true;
      u = expr;
    } else if (trigNode case Cos(:final expr)) {
      isSin = false;
      u = expr;
    } else {
      return null;
    }
    if (u.matchLinear(variable) == null) return null;

    final coeff = trigConst.isEmpty
        ? IntegerNumber.one
        : Mul(trigConst).simplify(assumptions: assumptions);
    final ratio = (coeff / a).simplify(assumptions: assumptions);
    final int sign;
    if (ratio == IntegerNumber.one) {
      sign = 1;
    } else if (ratio == IntegerNumber.negativeOne) {
      sign = -1;
    } else {
      return null;
    }

    final aExpr = a;
    final duFactor = u
        .matchLinear(variable)!
        .a
        .simplify(assumptions: assumptions);
    final trigDeriv = isSin ? Cos(u) : (-Sin(u)).simplify();
    final sqrt2 = Pow(IntegerNumber.two, FractionNumber.half);
    final sqrtA = Pow(aExpr, FractionNumber.half);

    Expr integrateHalfInt(int m) {
      final sExpr = targetPow!.base;
      if (m == 1) {
        return (-IntegerNumber.of(2 * sign) *
                aExpr *
                trigDeriv *
                Pow(sExpr, const FractionNumber(Integer(-1), Integer(2))))
            .simplify(assumptions: assumptions);
      }
      if (m == -1) {
        final arg =
            (sqrt2 *
                    sqrtA *
                    trigDeriv /
                    (IntegerNumber.two * Pow(sExpr, FractionNumber.half)))
                .simplify(assumptions: assumptions);
        return (-IntegerNumber.of(sign) * sqrt2 * Atanh(arg) / sqrtA).simplify(
          assumptions: assumptions,
        );
      }
      if (m > 1) {
        final q = FractionNumber(Integer(m), const Integer(2));
        final prev = integrateHalfInt(m - 2);
        final term1 =
            (-IntegerNumber.of(2 * sign) *
                aExpr *
                trigDeriv *
                Pow(sExpr, (q - IntegerNumber.one).simplify())) /
            IntegerNumber.of(m);
        final term2 =
            (IntegerNumber.of(2 * (m - 1)) * aExpr / IntegerNumber.of(m)) *
            prev;
        return (term1 + term2).simplify(assumptions: assumptions);
      }
      // m <= -3
      final q = FractionNumber(Integer(m), const Integer(2));
      final next = integrateHalfInt(m + 2);
      final term1 =
          (IntegerNumber.of(sign) * trigDeriv * Pow(sExpr, q)) /
          IntegerNumber.of(m + 1);
      final term2 =
          (IntegerNumber.of(m + 2) / (IntegerNumber.of(2 * (m + 1)) * aExpr)) *
          next;
      return (term1 + term2).simplify(assumptions: assumptions);
    }

    return (constScale * integrateHalfInt(k) / duFactor).simplify(
      assumptions: assumptions,
    );
  }
  return null;
}

/// Rewrites products of linear square roots and perfect-square trig factors
/// inside `sqrt(...)` for real antiderivative computation.
Expr? tryRealRadicalRewrite(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  if (depth >= 2) return null;

  // 1. Product of two linear square roots: sqrt(a1*x + b1) * sqrt(a2*x + b2)
  if (expr case Mul(:final factors)) {
    final sqrtLinIndices = <int>[];
    for (var i = 0; i < factors.length; i++) {
      if (factors[i]
          case Pow(
            :final base,
            exponent: FractionNumber(
              numerator: Integer(asInt: 1),
              denominator: Integer(asInt: 2),
            ),
          )
          when base.matchLinear(variable) != null) {
        sqrtLinIndices.add(i);
      }
    }
    if (sqrtLinIndices.length >= 2) {
      final i0 = sqrtLinIndices[0];
      final i1 = sqrtLinIndices[1];
      final b0 = (factors[i0] as Pow).base;
      final b1 = (factors[i1] as Pow).base;
      final merged = Pow(
        (b0 * b1).expand().simplify(assumptions: assumptions),
        FractionNumber.half,
      );
      final rebuilt = Mul([
        merged,
        for (var j = 0; j < factors.length; j++)
          if (j != i0 && j != i1) factors[j],
      ]).simplify(assumptions: assumptions);
      final res = antiDerivative(
        rebuilt,
        variable,
        depth: depth + 1,
        assumptions: assumptions,
      );
      if (!hasUnevaluatedIntegral(res, variable)) return res;
    }
  }

  // 2. Trig Pythagorean identity & even-power extraction inside sqrt(...)
  final signFactors = <Expr>[];
  Expr rewriteSqrt(Expr node) {
    final mapped = node.mapChildren(rewriteSqrt);
    if (mapped case Pow(
      :final base,
      exponent: FractionNumber(
        numerator: Integer(asInt: 1),
        denominator: Integer(asInt: 2),
      ),
    )) {
      if (base case Add(terms: [final t0, final t1])) {
        Expr? tanSq;
        if (t0 == IntegerNumber.one) {
          tanSq = t1;
        } else if (t1 == IntegerNumber.one) {
          tanSq = t0;
        }
        if (tanSq case Pow(
          base: Tan(expr: final u),
          exponent: IntegerNumber(asInt: 2),
        )) {
          final cosU = Cos(u);
          if (!isPositiveExpr(cosU, assumptions: assumptions)) {
            signFactors.add(Sign(cosU));
          }
          return Pow(cosU, IntegerNumber.negativeOne);
        }
      }
      if (base case Mul(:final factors)) {
        final pulled = <Expr>[];
        final remaining = <Expr>[];
        for (final f in factors) {
          if (f
              case Pow(
                base: final inner,
                exponent: IntegerNumber(asInt: final p?),
              )
              when p.isEven && (inner is Sin || inner is Cos)) {
            final k = p ~/ 2;
            if (k.isOdd && !isPositiveExpr(inner, assumptions: assumptions)) {
              signFactors.add(Sign(inner));
            }
            pulled.add(Pow(inner, IntegerNumber.of(k)));
          } else {
            remaining.add(f);
          }
        }
        if (pulled.isNotEmpty) {
          final remSqrt = switch (remaining) {
            [] => IntegerNumber.one,
            [Pow(:final base, exponent: Number(isNegativeOne: true))] => Pow(
              base,
              const FractionNumber(Integer(-1), Integer(2)),
            ),
            _ => Pow(
              Mul(remaining).simplify(assumptions: assumptions),
              FractionNumber.half,
            ),
          };
          return (Mul(pulled) * remSqrt).simplify(assumptions: assumptions);
        }
      }
    }
    return mapped;
  }

  final rewritten = rewriteSqrt(expr).simplify(assumptions: assumptions);
  if (rewritten != expr) {
    final res = antiDerivative(
      rewritten,
      variable,
      depth: depth + 1,
      assumptions: assumptions,
    );
    if (!hasUnevaluatedIntegral(res, variable)) {
      return signFactors.isEmpty
          ? res
          : (Mul(signFactors) * res).simplify(assumptions: assumptions);
    }
  }
  return null;
}

/// Integrates square-root binomial quadratics `sqrt(a +/- u^2)` or `sqrt(u^2 - a)`.
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

/// Integrates `P(x) * (A*x^2 + B*x + C)^(k/2)` with respect to [variable].
Expr? tryQuadraticRadical(
  Expr numerator,
  Expr quad,
  int halfExp,
  String variable,
) {
  final numExpanded = numerator.expand().simplify();
  if (numExpanded is Number && numExpanded.isZero) return IntegerNumber.zero;

  final numCoeffs = extractPolynomialCoefficients(numExpanded, variable);
  if (numCoeffs == null) return null;
  final degP = maxPolynomialDegree(numCoeffs);
  if (degP > 8) return null;

  final quadCoeffs = extractPolynomialCoefficients(quad, variable);
  if (quadCoeffs == null || maxPolynomialDegree(quadCoeffs) != 2) return null;
  final a = quadCoeffs[2] ?? IntegerNumber.zero;
  final b = quadCoeffs[1] ?? IntegerNumber.zero;
  final c = quadCoeffs[0] ?? IntegerNumber.zero;

  if (degP >= 2) {
    if (halfExp <= -3) {
      final (:quotient, :remainder) = numExpanded.polynomialDivide(
        quad,
        variable,
      );
      final qInt = tryQuadraticRadical(quotient, quad, halfExp + 2, variable);
      if (qInt == null) return null;
      final rInt = tryQuadraticRadical(remainder, quad, halfExp, variable);
      if (rInt == null) return null;
      return (qInt + rInt).simplify();
    }
    if (halfExp == -1) {
      return _integratePolyOverSqrtQ(numExpanded, quad, a, b, c, variable);
    }
    if (halfExp >= 1 && halfExp.isOdd) {
      final m = degP;
      final lead = numCoeffs[m]!;
      final xVar = Variable(variable);
      final denom = (IntegerNumber.of(m + halfExp + 1) * a).simplify();
      final term1 =
          (lead *
              Pow(xVar, IntegerNumber.of(m - 1)) *
              Pow(
                quad,
                FractionNumber(Integer(halfExp + 2), const Integer(2)),
              )) /
          denom;
      final bTerm =
          (lead *
              IntegerNumber.of(2 * m + halfExp) *
              b /
              (IntegerNumber.two * denom)) *
          Pow(xVar, IntegerNumber.of(m - 1));
      final cTerm =
          (lead * IntegerNumber.of(m - 1) * c / denom) *
          (m == 2 ? IntegerNumber.one : Pow(xVar, IntegerNumber.of(m - 2)));
      final lowerPoly =
          (numExpanded - lead * Pow(xVar, IntegerNumber.of(m)) - bTerm - cTerm)
              .expand()
              .simplify();
      final rem = tryQuadraticRadical(lowerPoly, quad, halfExp, variable);
      if (rem == null) return null;
      return (term1 + rem).simplify();
    }
    return null;
  }

  final p = numCoeffs[1] ?? IntegerNumber.zero;
  final q = numCoeffs[0] ?? IntegerNumber.zero;

  if (p == IntegerNumber.zero) {
    final rem = _tryQuadraticRadicalConst(quad, a, b, c, halfExp, variable);
    return rem == null ? null : (q * rem).simplify();
  }

  final twoA = (IntegerNumber.two * a).simplify();
  final leadTerm =
      (p / (a * IntegerNumber.of(halfExp + 2))) *
      Pow(quad, FractionNumber(Integer(halfExp + 2), const Integer(2)));
  final qRem = (q - (p * b) / twoA).simplify();
  if (qRem == IntegerNumber.zero) return leadTerm.simplify();

  final rem = _tryQuadraticRadicalConst(quad, a, b, c, halfExp, variable);
  if (rem == null) return null;
  return (leadTerm + qRem * rem).simplify();
}

/// Attempts affine radical substitution `u = (a*x + b)^(1/n)` on [expr].
Expr? tryAffineRadicalSubstitution(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
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

/// Attempts Chebyshev differential binomial substitution on `x^m * (a + b*x^n)^(p/q)`.
Expr? tryChebyshevBinomial(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
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

  // Case 1: (m + 1) / n is an integer k
  if ((m + 1) % n == 0) {
    final k = (m + 1) ~/ n;
    if (k > 0 && k <= 8) {
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
    } else if (k <= 0 && k >= -6 && q >= 2) {
      final bPow = k == 0 ? IntegerNumber.one : Pow(b, IntegerNumber.of(k));
      final transformed =
          (constScale *
                  (IntegerNumber.of(q) / (IntegerNumber.of(n) * bPow)) *
                  Pow(uVar, IntegerNumber.of(p + q - 1)) *
                  Pow(
                    Pow(uVar, IntegerNumber.of(q)) - a,
                    IntegerNumber.of(k - 1),
                  ))
              .simplify(assumptions: assumptions);
      final uAntideriv = antiDerivative(
        transformed,
        uName,
        assumptions: assumptions,
        depth: depth + 1,
      );
      if (!hasUnevaluatedIntegral(uAntideriv, uName)) {
        return uAntideriv
            .substitute(
              uName,
              Pow(binomPow.base, FractionNumber(Integer.one, Integer(q))),
            )
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

/// Integrates `P(x) / sqrt(Q(x))`, `sqrt(Q(x)) / x^k`, or `c / (x^k * sqrt(Q(x)))`.
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
            ? antiDerivative(
                (a * xVar / left).simplify(),
                variable,
                assumptions: Assumptions.none,
              )
            : (k == 2
                  ? antiDerivative(
                      (a / left).simplify(),
                      variable,
                      assumptions: Assumptions.none,
                    )
                  : tryPolynomialOverSqrtQuadratic(
                      a,
                      Pow(xVar, IntegerNumber.of(k - 2)) * left,
                      variable,
                    ));
        final term2 = (b is Number && b.isZero)
            ? IntegerNumber.zero
            : (k == 1
                  ? antiDerivative(
                      (b / left).simplify(),
                      variable,
                      assumptions: Assumptions.none,
                    )
                  : tryPolynomialOverSqrtQuadratic(
                      b,
                      Pow(xVar, IntegerNumber.of(k - 1)) * left,
                      variable,
                    ));
        final term3 = (c is Number && c.isZero)
            ? IntegerNumber.zero
            : tryPolynomialOverSqrtQuadratic(
                c,
                (right * left).simplify(),
                variable,
              );
        if (term1 != null &&
            term2 != null &&
            term3 != null &&
            !hasUnevaluatedIntegral(term1, variable) &&
            !hasUnevaluatedIntegral(term2, variable) &&
            !hasUnevaluatedIntegral(term3, variable)) {
          return (term1 + term2 + term3).simplify();
        }
      }
    }
  }

  // Case 3: P(x) / (x^k * sqrt(Ax^2 + Bx + C)) (k >= 1) via t = 1/x
  if (right is Mul) {
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
    if (valid && k >= 1 && k <= 8 && rad != null) {
      if (left.dependsOn(variable)) {
        final degLeft = polynomialDegree(left, variable);
        if (degLeft != null && degLeft <= 8) {
          final pCoeffs = extractPolynomialCoefficients(left, variable);
          if (pCoeffs != null) {
            final xVar = Variable(variable);
            final results = <Expr>[];
            var ok = true;
            for (final MapEntry(key: j, value: coeff) in pCoeffs.entries) {
              if (coeff is Number && coeff.isZero) continue;
              final Expr? termRes;
              if (j >= k) {
                final numTerm = j == k
                    ? coeff
                    : (coeff * Pow(xVar, IntegerNumber.of(j - k))).simplify();
                termRes = antiDerivative(
                  (numTerm / rad).simplify(),
                  variable,
                  assumptions: Assumptions.none,
                  depth: 2,
                );
              } else {
                final denomTerm = (Pow(xVar, IntegerNumber.of(k - j)) * rad)
                    .simplify();
                termRes = tryPolynomialOverSqrtQuadratic(
                  coeff,
                  denomTerm,
                  variable,
                );
              }
              if (termRes == null ||
                  hasUnevaluatedIntegral(termRes, variable)) {
                ok = false;
                break;
              }
              results.add(termRes);
            }
            if (ok) {
              return results.isEmpty
                  ? IntegerNumber.zero
                  : Add(results).simplify();
            }
          }
        }
        return null;
      }
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
            assumptions: Assumptions.none,
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

/// Attempts fractional-linear radical substitution `u = ((a*x + b) / (c*x + d))^(1/n)`.
Expr? tryFractionalLinearRadical(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
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

/// Integrates fractional powers `(b * tan(a*x + c))^(k/2)` via
/// `u = (b * tan(a*x + c))^(1/2)`.
Expr? tryTrigRadicalSubstitution(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  if (depth >= 2) return null;
  final factors = expr is Mul ? expr.factors : [expr];
  var constScale = IntegerNumber.one as Expr;
  Pow? tanPow;

  for (final f in factors) {
    if (!f.dependsOn(variable)) {
      constScale = (constScale * f).simplify();
      continue;
    }
    if (f is Pow && tanPow == null) {
      tanPow = f;
      continue;
    }
    return null;
  }

  if (tanPow == null) return null;
  final k = halfIntExponent(tanPow.exponent);
  if (k == null || k.isEven || k.abs() > 7) return null;

  Expr bScale = IntegerNumber.one;
  Tan? tanNode;
  if (tanPow.base case final Tan t) {
    tanNode = t;
  } else if (tanPow.base case Mul(:final factors)) {
    final consts = <Expr>[];
    final vars = <Expr>[];
    for (final f in factors) {
      if (f.dependsOn(variable)) {
        vars.add(f);
      } else {
        consts.add(f);
      }
    }
    if (vars.length == 1 && vars.first is Tan) {
      tanNode = vars.first as Tan;
      if (consts.isNotEmpty) {
        bScale = Mul(consts).simplify(assumptions: assumptions);
      }
    }
  }
  if (tanNode == null) return null;

  final inner = tanNode.expr;
  final lin = inner.matchLinear(variable);
  if (lin == null) return null;
  final d = lin.a;

  final uName = '_u$depth';
  final uVar = Variable(uName);
  final bSq = (bScale * bScale).simplify(assumptions: assumptions);
  final quarticDen = (Pow(uVar, const IntegerNumber(Integer(4))) + bSq)
      .simplify(assumptions: assumptions);
  final preFactor = (constScale * (IntegerNumber.two * bScale / d)).simplify(
    assumptions: assumptions,
  );

  Expr? uAntideriv;
  if (k >= -1) {
    final numU = k + 1 == 0
        ? IntegerNumber.one
        : Pow(uVar, IntegerNumber.of(k + 1));
    final transformed = (preFactor * numU / quarticDen).simplify(
      assumptions: assumptions,
    );
    uAntideriv = antiDerivative(
      transformed,
      uName,
      assumptions: assumptions,
      depth: depth + 1,
    );
  } else {
    // k <= -3: m = -(k + 1) in {2, 4, 6}
    var m = -(k + 1);
    var remScale = IntegerNumber.one as Expr;
    final terms = <Expr>[];
    while (m > 0) {
      final coeff = (remScale / bSq).simplify(assumptions: assumptions);
      final laurentInt =
          (-coeff /
                  (IntegerNumber.of(m - 1) *
                      Pow(uVar, IntegerNumber.of(m - 1))))
              .simplify(assumptions: assumptions);
      terms.add(laurentInt);
      remScale = (-coeff).simplify(assumptions: assumptions);
      m -= 4;
    }
    final remPow = -m; // 0 or 2
    final remNum = remPow == 0
        ? remScale
        : (remScale * Pow(uVar, IntegerNumber.of(remPow))).simplify(
            assumptions: assumptions,
          );
    final remInt = antiDerivative(
      (remNum / quarticDen).simplify(assumptions: assumptions),
      uName,
      assumptions: assumptions,
      depth: depth + 1,
    );
    if (!hasUnevaluatedIntegral(remInt, uName)) {
      terms.add(remInt);
      uAntideriv = (preFactor * Add(terms)).simplify(assumptions: assumptions);
    }
  }

  if (uAntideriv == null || hasUnevaluatedIntegral(uAntideriv, uName)) {
    return null;
  }
  return uAntideriv
      .substitute(uName, Pow(tanPow.base, FractionNumber.half))
      .simplify(assumptions: assumptions);
}

Expr _factorEvenPowerSqrt(Expr expr, Assumptions assumptions) => switch (expr) {
  Pow(:final base, exponent: IntegerNumber(asInt: final p?)) when p.isEven =>
    Pow(base, IntegerNumber.of(p ~/ 2)).simplify(assumptions: assumptions),
  Mul(:final factors) => Mul([
    for (final f in factors) _factorEvenPowerSqrt(f, assumptions),
  ]).simplify(assumptions: assumptions),
  _ => Pow(expr, FractionNumber.half).simplify(assumptions: assumptions),
};
