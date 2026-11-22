import '../../algebra/expand.dart';
import '../../algebra/helpers.dart';
import '../../algebra/rational.dart';
import '../../algebra/simplify.dart';
import '../../algebra/simplify/domain.dart';
import '../../assumptions.dart';
import '../../ast.dart';
import '../../number/integer.dart';
import '../linear_form.dart';
import 'definite.dart';
import 'integration.dart';
import 'radical_binomial.dart';

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
            if (!hasUnevaluatedIntegral(res, variable)) {
              final halfExp = halfIntExponent(exp);
              if (halfExp != null &&
                  !isPositiveExpr(inner, assumptions: assumptions) &&
                  !inner.anyNode((n) => n is ComplexNumber) &&
                  !isSyntacticallyNegative(a) &&
                  !isSyntacticallyNegative(c)) {
                return (Sign(inner) * res).simplify(assumptions: assumptions);
              }
              return res;
            }
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
  if (depth >= 3) return null;

  // 1. Product of two linear square roots: sqrt(a1*x + b1) * sqrt(a2*x + b2)
  //    or 1 / (sqrt(a1*x + b1) * sqrt(a2*x + b2))
  if (expr case Mul(:final factors)) {
    final posIndices = <int>[];
    final negIndices = <int>[];
    for (var i = 0; i < factors.length; i++) {
      if (factors[i] case Pow(:final base, :final exponent)
          when base.matchLinear(variable) != null) {
        final h = halfIntExponent(exponent);
        if (h == 1) {
          posIndices.add(i);
        } else if (h == -1) {
          negIndices.add(i);
        }
      }
    }
    final pair = posIndices.length >= 2
        ? (i0: posIndices[0], i1: posIndices[1], exp: FractionNumber.half)
        : (negIndices.length >= 2
              ? (
                  i0: negIndices[0],
                  i1: negIndices[1],
                  exp: const FractionNumber(Integer(-1), Integer(2)),
                )
              : null);
    if (pair != null) {
      final b0 = (factors[pair.i0] as Pow).base;
      final b1 = (factors[pair.i1] as Pow).base;
      final isOpposite =
          (b0 + b1).simplify(assumptions: assumptions) == IntegerNumber.zero;
      final ratio = isOpposite
          ? IntegerNumber.negativeOne
          : (b0 / b1)
                .cancel(assumptions: assumptions)
                .simplify(assumptions: assumptions);
      if (ratio is RealNumeric && ratio.sign < 0) {
        if (factors.length == 2 &&
            pair.exp == const FractionNumber(Integer(-1), Integer(2))) {
          final posBase = isSyntacticallyNegative(b0) ? b1 : b0;
          final negBase = isSyntacticallyNegative(b0) ? b0 : b1;
          if (posBase.matchLinear(variable) case (:final a, b: _)) {
            return (Pow(posBase, FractionNumber.half) *
                    Ln(posBase) /
                    (a * Pow(negBase, FractionNumber.half)))
                .simplify(assumptions: assumptions);
          }
        }
      } else {
        final merged = Pow(
          (b0 * b1).expand().simplify(assumptions: assumptions),
          pair.exp,
        );
        final rebuilt = Mul([
          merged,
          for (var j = 0; j < factors.length; j++)
            if (j != pair.i0 && j != pair.i1) factors[j],
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

/// Integrates expressions containing fractional powers `x^(p/q)` via `x = t^d`.
Expr? tryVariableRootSubstitution(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  if (depth >= 2) return null;

  final denoms = <int>{};
  var hasNonVarFracPow = false;
  var hasTranscendental = false;

  void collect(Expr node) {
    if (node
        case Pow(
          base: Variable(:final name),
          exponent: FractionNumber(:final denominator),
        )
        when name == variable && denominator.toInt() >= 2) {
      denoms.add(denominator.toInt());
      return;
    }
    if (node is Pow &&
        node.exponent is FractionNumber &&
        node.dependsOn(variable)) {
      hasNonVarFracPow = true;
    } else if (node is UnaryExpr && node.dependsOn(variable)) {
      hasTranscendental = true;
    }
    node.mapChildren((c) {
      collect(c);
      return c;
    });
  }

  collect(expr);
  if (denoms.isEmpty) return null;

  int gcd(int a, int b) {
    var x = a.abs();
    var y = b.abs();
    while (y != 0) {
      final t = x % y;
      x = y;
      y = t;
    }
    return x;
  }

  var d = 1;
  for (final q in denoms) {
    d = (d ~/ gcd(d, q)) * q;
    if (d > 25) return null;
  }
  if (d < 2) return null;
  if (d > 6 && (hasNonVarFracPow || hasTranscendental)) return null;

  final tName = '_rt$depth';
  final tVar = Variable(tName);

  Expr replaceX(Expr node) {
    if (node
        case Pow(
          base: Variable(:final name),
          exponent: FractionNumber(:final numerator, :final denominator),
        )
        when name == variable) {
      final exp = numerator.toInt() * (d ~/ denominator.toInt());
      return Pow(tVar, IntegerNumber.of(exp));
    }
    if (node is Variable && node.name == variable) {
      return Pow(tVar, IntegerNumber.of(d));
    }
    return node.mapChildren(replaceX);
  }

  final substituted = replaceX(expr).simplify(assumptions: assumptions);
  if (substituted.dependsOn(variable)) return null;

  final dxFactor = (IntegerNumber.of(d) * Pow(tVar, IntegerNumber.of(d - 1)))
      .simplify(assumptions: assumptions);
  final transformed = (substituted * dxFactor).simplify(
    assumptions: assumptions,
  );
  final res = antiDerivative(
    transformed,
    tName,
    depth: depth + 1,
    assumptions: assumptions,
  );
  if (hasUnevaluatedIntegral(res, tName)) return null;

  final xRoot = Pow(
    Variable(variable),
    FractionNumber(Integer.one, Integer(d)),
  );
  return res.substitute(tName, xRoot).simplify(assumptions: assumptions);
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
  if (degP > 12) return null;

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
      return integratePolyOverSqrtQ(numExpanded, quad, a, b, c, variable);
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
  final transformed = (replaced * dx)
      .together(assumptions: assumptions)
      .cancel(assumptions: assumptions);
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
  final disc = (const IntegerNumber(Integer(4)) * a * c - b * b)
      .expand()
      .simplify();

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
    if (!isPositiveExpr(disc, assumptions: Assumptions.none)) {
      final rad = Pow(quad, FractionNumber.half).simplify();
      final logArg = (twoAxPlusB + IntegerNumber.two * sqrtA * rad).simplify();
      return (Ln(logArg) / sqrtA).simplify();
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

({int p, int q})? fractionalExponent(Expr exponent) {
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
      if (fractionalExponent(exponent) case (:final p, :final q)) {
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
    if (fractionalExponent(exponent) case (:final p, :final q)) {
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

Expr _factorEvenPowerSqrt(Expr expr, Assumptions assumptions) => switch (expr) {
  Pow(:final base, exponent: IntegerNumber(asInt: final p?)) when p.isEven =>
    Pow(base, IntegerNumber.of(p ~/ 2)).simplify(assumptions: assumptions),
  Mul(:final factors) => Mul([
    for (final f in factors) _factorEvenPowerSqrt(f, assumptions),
  ]).simplify(assumptions: assumptions),
  _ => Pow(expr, FractionNumber.half).simplify(assumptions: assumptions),
};
