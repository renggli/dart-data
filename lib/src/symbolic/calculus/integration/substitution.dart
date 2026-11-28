import 'package:more/math.dart' show LcmIntegerExtension;

import '../../algebra/expand.dart';
import '../../algebra/helpers.dart';
import '../../algebra/rational.dart';
import '../../algebra/simplify.dart';
import '../../assumptions.dart';
import '../../ast.dart';
import '../../functions/fn.dart';
import '../differentiation.dart';
import '../linear_form.dart';
import 'definite.dart';
import 'integration.dart';
import 'integration_elementary.dart';

/// Attempts exponential substitution `u = e^(effSlope * x)` or `u = B^(alpha * x)`
/// for rational or algebraic integrands whose variable dependence is confined
/// to exponential atoms with commensurate linear exponents.
Expr? tryExponentialSubstitution(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  if (depth >= 2) return null;

  final expNodes = <({Pow node, Expr base, Expr outerExp, Expr a, Expr b})>[];
  var valid = true;

  void collect(Expr node) {
    if (!valid) return;
    if (node case Pow(:final base, :final exponent)
        when exponent.dependsOn(variable)) {
      if (!base.dependsOn(variable)) {
        final lin = exponent.matchLinear(variable);
        if (lin == null || !isValidExponentialBase(base)) {
          valid = false;
          return;
        }
        expNodes.add((
          node: node,
          base: base,
          outerExp: IntegerNumber.one,
          a: lin.a,
          b: lin.b,
        ));
        return;
      }
    }
    if (node
        case Pow(
          base: Pow(base: final innerBase, exponent: final innerExp),
          exponent: final outerExp,
        )
        when !innerBase.dependsOn(variable) &&
            innerExp.dependsOn(variable) &&
            !outerExp.dependsOn(variable)) {
      if (!isValidExponentialBase(innerBase)) {
        valid = false;
        return;
      }
      final combinedExp = (innerExp * outerExp).expand().simplify(
        assumptions: assumptions,
      );
      final lin = combinedExp.matchLinear(variable);
      if (lin == null) {
        valid = false;
        return;
      }
      expNodes.add((
        node: node,
        base: innerBase,
        outerExp: outerExp,
        a: lin.a,
        b: lin.b,
      ));
      return;
    }
    node.mapChildren((c) {
      collect(c);
      return c;
    });
  }

  collect(expr);
  if (!valid || expNodes.isEmpty) return null;

  Expr logBaseOf(Expr b) => b == Constant.e
      ? IntegerNumber.one
      : Fn.ln(b).simplify(assumptions: assumptions);

  final logSlopes = <Expr>[
    for (final item in expNodes)
      (item.a * logBaseOf(item.base)).simplify(assumptions: assumptions),
  ];

  var bestIdx = 0;
  var bestLen = logSlopes[0].toString().length;
  for (var i = 1; i < logSlopes.length; i++) {
    final len = logSlopes[i].toString().length;
    if (len < bestLen) {
      bestIdx = i;
      bestLen = len;
    }
  }
  final logSlope0 = logSlopes[bestIdx];

  final fracRatios = <({int p, int q})>[];
  var lcmQ = 1;
  for (final slope in logSlopes) {
    var ratio = (slope / logSlope0).simplify(assumptions: assumptions);
    if (ratio is! RationalNumber) {
      ratio = ratio.cancel(assumptions: assumptions);
    }
    if (ratio is! RationalNumber) return null;
    if (!ratio.numerator.isValidInt ||
        !ratio.denominator.isValidInt ||
        ratio.numerator == BigInt.zero) {
      return null;
    }
    final p = ratio.numerator.toInt();
    final q = ratio.denominator.toInt();
    lcmQ = lcmQ.lcm(q);
    if (lcmQ > 6) return null;
    fracRatios.add((p: p, q: q));
  }

  final intRatios = <int>[];
  for (final r in fracRatios) {
    final m = (r.p * lcmQ) ~/ r.q;
    if (m.abs() > 8) return null;
    intRatios.add(m);
  }

  final uName = freshIntegrationVar('_exp_u', expr, variable, depth);
  final uVar = Variable(uName);
  final mapByNode = <Pow, ({Expr base, Expr beta, int m})>{
    for (var i = 0; i < expNodes.length; i++)
      expNodes[i].node: (
        base: expNodes[i].base,
        beta: expNodes[i].b,
        m: intRatios[i],
      ),
  };

  Expr rewrite(Expr node) {
    if (node is Pow) {
      if (mapByNode[node] case final info?) {
        return (Pow.of(info.base, info.beta) *
                Pow.of(uVar, IntegerNumber.of(info.m)))
            .simplify(assumptions: assumptions);
      }
    }
    return node.mapChildren(rewrite);
  }

  final rewritten = rewrite(expr).simplify(assumptions: assumptions);
  if (rewritten.dependsOn(variable)) return null;

  final effSlope = (logSlope0 / IntegerNumber.of(lcmQ)).simplify(
    assumptions: assumptions,
  );
  final integrandU = (rewritten / (effSlope * uVar)).simplify(
    assumptions: assumptions,
  );
  final resU = antiDerivative(
    integrandU,
    uName,
    depth: depth + 1,
    assumptions: assumptions,
  );
  if (hasUnevaluatedIntegral(resU, uName)) return null;

  final commonBase = expNodes.first.base;
  final allSameBase = expNodes.every((e) => e.base == commonBase);
  final Expr uExpr;
  if (allSameBase) {
    final alphaEff = (expNodes[bestIdx].a / IntegerNumber.of(lcmQ)).simplify(
      assumptions: assumptions,
    );
    uExpr = Pow.of(
      commonBase,
      (alphaEff * Variable(variable)).simplify(assumptions: assumptions),
    );
  } else {
    uExpr = Pow.of(
      Constant.e,
      (effSlope * Variable(variable)).simplify(assumptions: assumptions),
    );
  }
  return resU.substitute(uName, uExpr).simplify(assumptions: assumptions);
}

/// Attempts direct chain-rule matching on `candidate * factor` with respect to [variable].
Expr? tryChainRule(
  Expr candidate,
  Expr factor,
  String variable, {
  required Assumptions assumptions,
}) {
  if (_hasDiscontinuousOperator(candidate, variable)) return null;
  // General u(x) * u'(x) chain rule: int u * u' dx = 1/2 * u^2
  if (candidate.dependsOn(variable)) {
    final uPrime = candidate.derivative(variable).simplify();
    if (factor.matchScalarMultiple(uPrime, variable) case final k?) {
      return (Pow.of(candidate, IntegerNumber.two) / IntegerNumber.two).scale(
        k,
      );
    }
  }

  return switch (candidate) {
    Call(:final id, args: [final expr]) when expr.dependsOn(variable) =>
      switch (id) {
        FunctionId.cos => _scaleMatch(
          factor,
          expr.derivative(variable).simplify(),
          Fn.sin(expr),
          variable,
        ),
        FunctionId.sin => _scaleMatch(
          factor,
          expr.derivative(variable).simplify(),
          (-Fn.cos(expr)).simplify(),
          variable,
        ),
        FunctionId.ln => _scaleMatch(
          factor,
          expr.derivative(variable).simplify(),
          expr * Fn.ln(expr) - expr,
          variable,
        ),
        FunctionId.tan => _scaleMatch(
          factor,
          expr.derivative(variable).simplify(),
          -logAntiderivative(Fn.cos(expr), Assumptions.none),
          variable,
        ),
        FunctionId.sinh => _scaleMatch(
          factor,
          expr.derivative(variable).simplify(),
          Fn.cosh(expr),
          variable,
        ),
        FunctionId.cosh => _scaleMatch(
          factor,
          expr.derivative(variable).simplify(),
          Fn.sinh(expr),
          variable,
        ),
        FunctionId.tanh => _scaleMatch(
          factor,
          expr.derivative(variable).simplify(),
          Fn.ln(Fn.cosh(expr)),
          variable,
        ),
        FunctionId.abs => _scaleMatch(
          factor,
          expr.derivative(variable).simplify(),
          (expr * Fn.abs(expr)) / IntegerNumber.two,
          variable,
        ),
        _ => null,
      },
    Pow(:final base, :final exponent)
        when !exponent.dependsOn(variable) && base.dependsOn(variable) =>
      _tryChainRulePower(
        base,
        exponent,
        factor,
        variable,
        assumptions: assumptions,
      ),
    Pow(:final base, :final exponent)
        when !base.dependsOn(variable) && exponent.dependsOn(variable) =>
      _tryChainRuleExponential(candidate, base, exponent, factor, variable),
    _ => null,
  };
}

/// Integrates Gaussian exponentials `exp(a2*x^2 + a1*x + a0)` via `erf` or `erfi`.
Expr? tryGaussianAntiderivative(Expr exponent, String variable) {
  final coeffs = extractPolynomialCoefficients(exponent, variable);
  if (coeffs == null || maxPolynomialDegree(coeffs) != 2) return null;
  final a2 = coeffs[2] ?? IntegerNumber.zero;
  final a1 = coeffs[1] ?? IntegerNumber.zero;
  final a0 = coeffs[0] ?? IntegerNumber.zero;

  // Positive leading coefficient a2 > 0 -> erfi
  if (isPositiveConstant(a2)) {
    final sqrtA2 = Pow.of(a2, FractionNumber.half).simplify();
    final sqrtPi = Pow.of(Constant.pi, FractionNumber.half).simplify();
    final xVar = Variable(variable);
    if (a1 == IntegerNumber.zero && a0 == IntegerNumber.zero) {
      return ((sqrtPi / (IntegerNumber.two * sqrtA2)) * Fn.erfi(sqrtA2 * xVar))
          .simplify();
    }
    final shift = (a1 / (IntegerNumber.two * sqrtA2)).simplify();
    final u = (sqrtA2 * xVar + shift).simplify();
    final constExp =
        (a0 - Pow.of(a1, IntegerNumber.two) / (IntegerNumber.of(4) * a2))
            .simplify();
    final expScale = Pow.of(Constant.e, constExp).simplify();
    return ((expScale * sqrtPi / (IntegerNumber.two * sqrtA2)) * Fn.erfi(u))
        .simplify();
  }

  // Require negative leading coefficient a2 = -k where k > 0 -> erf
  final k = (-a2).simplify();
  if (!isPositiveConstant(k)) return null;

  final sqrtK = Pow.of(k, FractionNumber.half).simplify();
  final sqrtPi = Pow.of(Constant.pi, FractionNumber.half).simplify();
  final xVar = Variable(variable);

  if (a1 == IntegerNumber.zero && a0 == IntegerNumber.zero) {
    // int e^(-k*x^2) dx = (sqrt(pi) / (2 * sqrt(k))) * erf(sqrt(k) * x)
    return ((sqrtPi / (IntegerNumber.two * sqrtK)) * Fn.erf(sqrtK * xVar))
        .simplify();
  }

  // Complete the square: -k * x^2 + a1 * x + a0 = -(sqrt(k)*x - a1/(2*sqrt(k)))^2 + (a0 + a1^2/(4*k))
  final shift = (a1 / (IntegerNumber.two * sqrtK)).simplify();
  final u = (sqrtK * xVar - shift).simplify();
  final constExp =
      (a0 + Pow.of(a1, IntegerNumber.two) / (IntegerNumber.of(4) * k))
          .simplify();
  final expScale = Pow.of(Constant.e, constExp).simplify();
  return ((expScale * sqrtPi / (IntegerNumber.two * sqrtK)) * Fn.erf(u))
      .simplify();
}

/// Attempts general `u`-substitution across composite subexpressions of [expr].
Expr? tryUSubstitution(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  if (isIntegrationBudgetExhausted()) return null;
  if (_hasDiscontinuousOperator(expr, variable)) return null;
  final candidates = <Expr>{};
  _collectUCandidates(expr, variable, candidates);
  if (candidates.isEmpty) return null;

  final isLargeExpr = exceedsNodeBudget(expr, 400);
  final splitExp = isLargeExpr ? expr : splitExpSumProduct(expr, variable);
  final expandedTrig = isLargeExpr ? expr : _expandDoubleAngleTrig(expr);
  final exprVariants = <Expr>[
    expr,
    if (expandedTrig != expr) expandedTrig,
    if (splitExp != expr && splitExp != expandedTrig) splitExp,
  ];

  final uName = freshIntegrationVar('_u', expr, variable, depth);
  final uVar = Variable(uName);
  final sizeWeight = expr.nodeCount > 80 ? 4 : (expr.nodeCount > 40 ? 2 : 1);

  var triedCandidates = 0;
  for (final candidate in candidates) {
    if (isIntegrationBudgetExhausted()) return null;
    if (triedCandidates >= 64) break;
    if (!candidate.dependsOn(variable)) continue;
    if (candidate is Variable && candidate.name == variable) continue;
    if (isLargeExpr && exceedsNodeBudget(candidate, 300)) continue;
    triedCandidates++;
    final gPrime = candidate
        .derivative(variable)
        .simplify(assumptions: assumptions);
    if (gPrime is Number && gPrime.isZero) continue;

    for (final variant in exprVariants) {
      if (consumeIntegrationWork(sizeWeight)) return null;
      final quot = (variant / gPrime).simplify(assumptions: assumptions);
      var replaced = _replaceUCandidate(quot, candidate, uVar, variable);
      var fU = replaced.simplify(assumptions: assumptions);
      if (fU.dependsOn(variable) && variant == splitExp) {
        final vSub = _replaceUCandidate(variant, candidate, uVar, variable);
        final gSub = _replaceUCandidate(gPrime, candidate, uVar, variable);
        if (!vSub.dependsOn(variable) && !gSub.dependsOn(variable)) {
          replaced = vSub / gSub;
          fU = replaced.simplify(assumptions: assumptions);
        }
      }
      if (fU.dependsOn(variable) &&
          !exceedsNodeBudget(replaced, 350) &&
          !consumeIntegrationWork(sizeWeight * 2)) {
        fU = replaced.expand().simplify(assumptions: assumptions);
      }
      if (fU.dependsOn(variable) &&
          !isIntegrationBudgetExhausted() &&
          !_hasLargeIntegerExponent(quot) &&
          !exceedsNodeBudget(quot, 350)) {
        final hasNestedFrac = quot.anyNode(
          (node) =>
              node is Add &&
              node.terms.any(
                (t) => t.anyNode(
                  (n) =>
                      n is FractionNumber ||
                      (n is Pow &&
                          n.exponent is RealNumeric &&
                          (n.exponent as RealNumeric).isNegative),
                ),
              ),
        );
        final (_, qDen) = splitNumeratorDenominator(quot);
        var normQuot = quot;
        if (hasNestedFrac && !consumeIntegrationWork(sizeWeight * 2)) {
          normQuot = quot
              .together(assumptions: assumptions)
              .cancel(assumptions: assumptions);
        } else if (!hasNestedFrac &&
            qDen.dependsOn(variable) &&
            !consumeIntegrationWork(sizeWeight * 2)) {
          normQuot = quot.cancel(assumptions: assumptions);
        }
        if (normQuot != quot) {
          final normReplaced = _replaceUCandidate(
            normQuot,
            candidate,
            uVar,
            variable,
          );
          fU = normReplaced.simplify(assumptions: assumptions);
          if (fU.dependsOn(variable) &&
              !exceedsNodeBudget(normReplaced, 350) &&
              !consumeIntegrationWork(sizeWeight * 2)) {
            fU = normReplaced.expand().simplify(assumptions: assumptions);
          }
        }
        if (fU.dependsOn(variable) &&
            !exceedsNodeBudget(normQuot, 350) &&
            !consumeIntegrationWork(sizeWeight * 2)) {
          fU =
              _tryLinearTranscendentalReplace(
                normQuot: normQuot,
                candidate: candidate,
                uVar: uVar,
                variable: variable,
                assumptions: assumptions,
              ) ??
              fU;
        }
      }
      if (fU.dependsOn(variable)) continue;

      final uAntideriv = antiDerivative(
        fU,
        uName,
        assumptions: assumptions,
        depth: depth + 1,
      );
      if (!hasUnevaluatedIntegral(uAntideriv, uName)) {
        return uAntideriv
            .substitute(uName, candidate)
            .simplify(assumptions: assumptions);
      }
    }
  }

  return null;
}

/// Integrates products `x^m * (a*x + b)^p` with symbolic exponent `p`.
Expr? trySymbolicBinomialAffine(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
}) {
  final factors = expr is Mul ? expr.factors : [expr];
  var scale = IntegerNumber.one as Expr;
  var m = 0;
  Pow? binomPow;

  for (final f in factors) {
    if (!f.dependsOn(variable)) {
      scale = (scale * f).simplify();
      continue;
    }
    if (f is Variable && f.name == variable) {
      m += 1;
      continue;
    }
    if (f
        case Pow(
          base: Variable(:final name),
          exponent: IntegerNumber(asInt: final k?),
        )
        when name == variable && k >= 1 && k <= 8) {
      m += k;
      continue;
    }
    if (f is Pow && binomPow == null && !f.exponent.dependsOn(variable)) {
      if (f.base.matchLinear(variable) != null) {
        binomPow = f;
        continue;
      }
    }
    return null;
  }

  if (binomPow == null || m == 0 || m > 8) return null;
  final linear = binomPow.base.matchLinear(variable)!;
  final (:a, :b) = linear;
  final p = binomPow.exponent;

  // u = a*x + b => x = (u - b) / a, dx = du / a
  final uName = freshVariable('_sb', {variable, ...expr.freeVariables});
  final uVar = Variable(uName);
  final expanded = (Pow.of((uVar - b) / a, IntegerNumber.of(m)) / a)
      .expand()
      .simplify(assumptions: assumptions);
  final terms = expanded is Add ? expanded.terms : [expanded];
  final integrated = <Expr>[];
  for (final t in terms) {
    final deg = polynomialDegree(t, uName);
    if (deg == null) return null;
    final coeff =
        (t /
                (deg == 0
                    ? IntegerNumber.one
                    : Pow.of(uVar, IntegerNumber.of(deg))))
            .simplify();
    final newExp = (p + IntegerNumber.of(deg + 1)).simplify();
    if (newExp is Number && newExp.isZero) {
      integrated.add((coeff * logAntiderivative(uVar, assumptions)).simplify());
    } else {
      integrated.add((coeff * Pow.of(uVar, newExp) / newExp).simplify());
    }
  }
  return (scale * Add.of(integrated))
      .substitute(uName, binomPow.base)
      .simplify(assumptions: assumptions);
}

/// Integrates mixed exponential-trigonometric-logarithmic forms such as
/// `x^n * sin(ln(a*x))` and `exp(c * atan(x)) / (x^2 + 1)^(k/2)`.
Expr? tryMixedTrigLogExp(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
}) {
  // 0. x^(a*ln(x) + b) -> u = ln(x), dx = e^u du -> exp(a*u^2 + (b + 1)*u)
  if (expr case Pow(base: Variable(:final name), :final exponent)
      when name == variable) {
    final uName = freshVariable('_ml', {variable, ...expr.freeVariables});
    final uVar = Variable(uName);
    final xVar = Variable(variable);
    final expSub = _substituteExpr(exponent, Fn.ln(xVar), uVar);
    if (!expSub.dependsOn(variable)) {
      if (expSub.matchLinear(uName) case (a: final a, b: final b)) {
        final quadExp = (a * uVar * uVar + (b + IntegerNumber.one) * uVar)
            .simplify(assumptions: assumptions);
        final res = tryGaussianAntiderivative(quadExp, uName);
        if (res != null) {
          return res
              .substitute(uName, Fn.ln(xVar))
              .simplify(assumptions: assumptions);
        }
      }
    }
  }

  // 1. x^n * sin(ln(a*x)) or x^n * cos(ln(a*x))
  final factors = expr is Mul ? expr.factors : [expr];
  var scale = IntegerNumber.one as Expr;
  Expr? xPower = IntegerNumber.zero;
  Expr? trigBase;
  var trigPower = 1;

  for (final f in factors) {
    if (!f.dependsOn(variable)) {
      scale = (scale * f).simplify();
      continue;
    }
    if (f is Variable && f.name == variable && xPower != null) {
      xPower = (xPower + IntegerNumber.one).simplify();
      continue;
    }
    if (f case Pow(base: Variable(:final name), :final exponent)
        when name == variable &&
            !exponent.dependsOn(variable) &&
            xPower != null) {
      xPower = (xPower + exponent).simplify();
      continue;
    }
    if (f is Call &&
        (f.id == FunctionId.sin || f.id == FunctionId.cos) &&
        trigBase == null) {
      trigBase = f;
      trigPower = 1;
      continue;
    }
    if (f case Pow(base: final b, exponent: IntegerNumber(asInt: final k?))
        when b is Call &&
            (b.id == FunctionId.sin || b.id == FunctionId.cos) &&
            k >= 1 &&
            k <= 6 &&
            trigBase == null) {
      trigBase = b;
      trigPower = k;
      continue;
    }
    xPower = null;
  }

  if (xPower != null && trigBase is Call) {
    final inner = trigBase.args[0];
    if (inner case Call(id: FunctionId.ln, args: [final lnInner])) {
      if (lnInner.matchLinear(variable) case (:final a, b: final b)
          when b == IntegerNumber.zero) {
        final uName = freshVariable('_ml', {variable, ...expr.freeVariables});
        final uVar = Variable(uName);
        final expFactor = Pow.of(
          Constant.e,
          (xPower + IntegerNumber.one) * uVar,
        );
        final baseTrigU = trigBase.id == FunctionId.sin
            ? Fn.sin(uVar)
            : Fn.cos(uVar);
        final trigU = trigPower == 1
            ? baseTrigU
            : Pow.of(baseTrigU, IntegerNumber.of(trigPower));
        final uInt = antiDerivative(
          (expFactor * trigU).simplify(assumptions: assumptions),
          uName,
          assumptions: assumptions,
          depth: 2,
        );
        if (!hasUnevaluatedIntegral(uInt, uName)) {
          final preFactor = (scale / Pow.of(a, xPower + IntegerNumber.one))
              .simplify();
          return (preFactor * uInt)
              .substitute(uName, inner)
              .simplify(assumptions: assumptions);
        }
      }
    }
  }

  // 2. exp(c * atan(x)) / (x^2 + 1)^(k/2) * x^m
  final (numExpr, denExpr) = splitNumeratorDenominator(expr);
  if (denExpr case Pow(base: final qBase, :final exponent)) {
    final halfExp = halfIntExponent(exponent);
    if (halfExp != null && halfExp >= 2) {
      final coeffs = extractPolynomialCoefficients(qBase, variable);
      if (coeffs != null &&
          maxPolynomialDegree(coeffs) == 2 &&
          coeffs[2] == IntegerNumber.one &&
          (coeffs[1] == null || coeffs[1] == IntegerNumber.zero) &&
          coeffs[0] == IntegerNumber.one) {
        final numFactors = numExpr is Mul ? numExpr.factors : [numExpr];
        var numScale = IntegerNumber.one as Expr;
        var xDeg = 0;
        Expr? atanCoeff;
        var ok = true;
        for (final nf in numFactors) {
          if (!nf.dependsOn(variable)) {
            numScale = (numScale * nf).simplify();
          } else if (nf is Variable && nf.name == variable) {
            xDeg += 1;
          } else if (nf
              case Pow(
                base: Variable(:final name),
                exponent: IntegerNumber(asInt: final k?),
              )
              when name == variable && k >= 1) {
            xDeg += k;
          } else if (nf case Pow(base: Constant.e, exponent: final eExp)) {
            if (eExp
                case Call(id: FunctionId.atan, args: [Variable(:final name)])
                when name == variable) {
              atanCoeff = IntegerNumber.one;
            } else if (eExp case Mul(factors: final ef)) {
              final (:constFactors, :varFactors) = partitionFactors(
                ef,
                variable,
              );
              if (varFactors
                  case [
                    Call(id: FunctionId.atan, args: [Variable(:final name)]),
                  ]
                  when name == variable) {
                atanCoeff = constFactors.length == 1
                    ? constFactors.first
                    : Mul.of(constFactors).simplify();
              } else {
                ok = false;
              }
            } else {
              ok = false;
            }
          } else {
            ok = false;
          }
        }
        if (ok && atanCoeff != null && xDeg <= 2 && halfExp >= xDeg + 2) {
          final uName = freshVariable('_at', {variable, ...expr.freeVariables});
          final uVar = Variable(uName);
          final cosPow = halfExp - 2 - xDeg;
          final integrand =
              (numScale *
                      Pow.of(Constant.e, atanCoeff * uVar) *
                      Pow.of(Fn.sin(uVar), IntegerNumber.of(xDeg)) *
                      Pow.of(Fn.cos(uVar), IntegerNumber.of(cosPow)))
                  .simplify();
          final uInt = antiDerivative(
            integrand,
            uName,
            assumptions: assumptions,
            depth: 2,
          );
          if (!hasUnevaluatedIntegral(uInt, uName)) {
            return uInt
                .substitute(uName, Fn.atan(Variable(variable)))
                .simplify(assumptions: assumptions);
          }
        }
      }
    }
  }

  return null;
}

Expr? _scaleMatch(Expr factor, Expr deriv, Expr target, String variable) {
  final k = factor.matchScalarMultiple(deriv, variable);
  return k != null ? target.scale(k) : null;
}

Expr? _tryChainRulePower(
  Expr base,
  Expr exponent,
  Expr factor,
  String variable, {
  required Assumptions assumptions,
}) {
  final uPrime = base.derivative(variable).simplify();
  final k = factor.matchScalarMultiple(uPrime, variable);
  if (k != null) {
    if (exponent == IntegerNumber.negativeOne ||
        (exponent is RealNumber && exponent.value == -1.0)) {
      return logAntiderivative(
        base,
        assumptions,
      ).simplify(assumptions: assumptions).scale(k);
    }
    final nPlus1 = (exponent + IntegerNumber.one).simplify();
    final fU = (Pow.of(base, nPlus1) / nPlus1).simplify();
    return fU.scale(k);
  }
  return null;
}

Expr? _tryChainRuleExponential(
  Expr candidate,
  Expr base,
  Expr exponent,
  Expr factor,
  String variable,
) {
  if (base == Constant.e) {
    final uPrime = exponent.derivative(variable).simplify();
    final k = factor.matchScalarMultiple(uPrime, variable);
    if (k != null) {
      return candidate.scale(k);
    }
    return null;
  }
  if (isValidExponentialBase(base)) {
    final uPrime = exponent.derivative(variable).simplify();
    final k = factor.matchScalarMultiple(uPrime, variable);
    if (k != null) {
      final denom = Fn.ln(base);
      final fU = (candidate / denom).simplify();
      return fU.scale(k);
    }
  }
  return null;
}

void _collectUCandidates(Expr node, String variable, Set<Expr> out) {
  if (out.length >= 64 || !node.dependsOn(variable)) return;
  switch (node) {
    case Call(:final id, args: [final expr])
        when _uCandidateFunctions.contains(id):
      if (_directUFunctions.contains(id)) {
        out.add(node);
      }
      if (expr is! Variable || expr.name != variable) {
        out.add(expr);
      }
      _collectUCandidates(expr, variable, out);
    case Pow(:final base, :final exponent):
      if (base == Constant.e && exponent.dependsOn(variable)) {
        out.add(node);
        if (exponent is! Variable || exponent.name != variable) {
          out.add(exponent);
        }
        if (exponent.anyNode(
          (n) =>
              n is Pow &&
              n.base is Variable &&
              (n.base as Variable).name == variable &&
              n.exponent is IntegerNumber &&
              (n.exponent as IntegerNumber).isNegative,
        )) {
          out.add(Pow.of(Variable(variable), IntegerNumber.negativeOne));
        }
      } else {
        if (base.dependsOn(variable) &&
            (base is! Variable || base.name != variable)) {
          out.add(base);
          if (base is Add &&
              exponent is IntegerNumber &&
              exponent.isNegative &&
              !exceedsNodeBudget(base, 160) &&
              _findTranscendental(base, variable) != null) {
            final xVar = Variable(variable);
            out.add((base / xVar).simplify());
            out.add((base / (xVar * xVar)).simplify());
          }
        }
        if (base case Variable(:final name) when name == variable) {
          if (exponent case IntegerNumber(asInt: final m?)
              when m >= 4 && m.isEven) {
            out.add(Pow.of(base, IntegerNumber.of(m ~/ 2)));
          } else if (exponent is FractionNumber) {
            out.add(node);
          }
        }
        if (exponent.dependsOn(variable) &&
            (base.dependsOn(variable) || isValidExponentialBase(base))) {
          out.add(node);
        }
      }
      _collectUCandidates(base, variable, out);
      _collectUCandidates(exponent, variable, out);
    case Sum() || Product() || RootSum() || Limit() || Integral():
      return;
    default:
      node.mapChildren((child) {
        _collectUCandidates(child, variable, out);
        return child;
      });
  }
}

const _uCandidateFunctions = {
  FunctionId.sin,
  FunctionId.cos,
  FunctionId.tan,
  FunctionId.asin,
  FunctionId.acos,
  FunctionId.atan,
  FunctionId.sinh,
  FunctionId.cosh,
  FunctionId.tanh,
  FunctionId.asinh,
  FunctionId.acosh,
  FunctionId.atanh,
  FunctionId.ln,
  FunctionId.erf,
  FunctionId.erfc,
  FunctionId.erfi,
  FunctionId.fresnelS,
  FunctionId.fresnelC,
};

const _directUFunctions = {
  FunctionId.sin,
  FunctionId.cos,
  FunctionId.tan,
  FunctionId.ln,
  FunctionId.atan,
  FunctionId.asin,
  FunctionId.acos,
};

bool _hasDiscontinuousOperator(Expr expr, String variable) => expr.anyNode(
  (node) =>
      (node is Piecewise ||
          (node is Call &&
              const {
                FunctionId.floor,
                FunctionId.ceil,
                FunctionId.round,
                FunctionId.sign,
                FunctionId.mod,
              }.contains(node.id))) &&
      node.dependsOn(variable),
);

Expr _expandDoubleAngleTrig(Expr node) {
  if (node case Call(
    id: FunctionId.sin,
    args: [Mul(factors: [IntegerNumber(asInt: 2), final inner])],
  )) {
    return IntegerNumber.two * Fn.sin(inner) * Fn.cos(inner);
  }
  return node.mapChildren(_expandDoubleAngleTrig);
}

Expr _replaceUCandidate(
  Expr node,
  Expr candidate,
  Variable uVar,
  String variable,
) {
  if (node == candidate) return uVar;
  if (candidate case Pow(base: final cBase, exponent: final cExp)) {
    if (node case Pow(base: final nBase, exponent: final nExp)) {
      if (nBase == cBase) {
        final ratio = (nExp / cExp).simplify();
        if (!ratio.dependsOn(variable) &&
            (ratio is IntegerNumber ||
                !(cExp is IntegerNumber && cExp.value.isEven))) {
          return Pow.of(uVar, ratio);
        }
      } else if (cBase is IntegerNumber &&
          nBase is IntegerNumber &&
          cBase.asInt != null &&
          nBase.asInt != null &&
          cBase.asInt! > 1 &&
          nBase.asInt! > cBase.asInt!) {
        final k = _integerLogBase(nBase.asInt!, cBase.asInt!);
        if (k != null) {
          final ratio = (IntegerNumber.of(k) * nExp / cExp).simplify();
          if (!ratio.dependsOn(variable)) {
            return Pow.of(uVar, ratio);
          }
        }
      } else if (nExp case Add(:final terms)) {
        final mappedFactors = <Expr>[];
        var changed = false;
        for (final t in terms) {
          final part = Pow.of(nBase, t);
          final replaced = _replaceUCandidate(part, candidate, uVar, variable);
          if (!identical(replaced, part)) changed = true;
          mappedFactors.add(replaced);
        }
        if (changed) {
          final product = Mul.of(mappedFactors);
          if (!product.dependsOn(variable)) {
            return product;
          }
        }
      }
    }
  }
  if (candidate case Call(id: FunctionId.sin, args: [final cArg])
      when node is Pow) {
    if (node.base == Fn.cos(cArg) && node.exponent == IntegerNumber.two) {
      return IntegerNumber.one - Pow.of(uVar, IntegerNumber.two);
    }
  }
  if (candidate case Call(id: FunctionId.cos, args: [final cArg])
      when node is Pow) {
    if (node.base == Fn.sin(cArg) && node.exponent == IntegerNumber.two) {
      return IntegerNumber.one - Pow.of(uVar, IntegerNumber.two);
    }
  }
  return node.mapChildren(
    (child) => _replaceUCandidate(child, candidate, uVar, variable),
  );
}

Expr? _tryLinearTranscendentalReplace({
  required Expr normQuot,
  required Expr candidate,
  required Variable uVar,
  required String variable,
  required Assumptions assumptions,
}) {
  final tNode = _findTranscendental(candidate, variable);
  if (tNode == null) return null;
  final tName = freshVariable('_lt', {
    variable,
    uVar.name,
    ...normQuot.freeVariables,
    ...candidate.freeVariables,
  });
  final tVar = Variable(tName);
  final linear = _substituteExpr(candidate, tNode, tVar).matchLinear(tName);
  if (linear == null) return null;
  final (:a, :b) = linear;
  if (a is Number && a.isZero) return null;
  final tReplacement = ((uVar - b) / a).simplify(assumptions: assumptions);
  final subbed = _substituteExpr(normQuot, tNode, tReplacement);
  if (_hasLargeIntegerExponent(subbed)) return null;
  final reduced = subbed
      .together(assumptions: assumptions)
      .cancel(assumptions: assumptions)
      .simplify(assumptions: assumptions);
  return reduced.dependsOn(variable) ? null : reduced;
}

bool _hasLargeIntegerExponent(Expr expr, {int limit = 16}) => expr.anyNode(
  (n) =>
      n is Pow &&
      n.exponent is IntegerNumber &&
      ((n.exponent as IntegerNumber).asInt == null ||
          (n.exponent as IntegerNumber).asInt!.abs() > limit),
);

Expr? _findTranscendental(Expr node, String variable) {
  if (!node.dependsOn(variable)) return null;
  if ((node is Call && _transcendentalUFunctions.contains(node.id)) ||
      (node is Pow && node.base == Constant.e)) {
    return node;
  }
  Expr? found;
  node.mapChildren((child) {
    found ??= _findTranscendental(child, variable);
    return child;
  });
  return found;
}

const _transcendentalUFunctions = {
  FunctionId.sin,
  FunctionId.cos,
  FunctionId.tan,
  FunctionId.asin,
  FunctionId.acos,
  FunctionId.atan,
  FunctionId.sinh,
  FunctionId.cosh,
  FunctionId.tanh,
  FunctionId.ln,
};

Expr _substituteExpr(Expr root, Expr target, Expr replacement) {
  if (root == target) return replacement;
  return root.mapChildren((c) => _substituteExpr(c, target, replacement));
}

/// Splits `exp(nonLinear + linear)` into `exp(nonLinear) * exp(linear)` and
/// factors common exponential factors out of additive sums.
Expr splitExpSumProduct(Expr node, String variable) {
  Expr splitNode(Expr n) {
    if (!n.dependsOn(variable)) return n;
    final mapped = n.mapChildren(splitNode);
    if (mapped case Pow(base: Constant.e, exponent: Add(:final terms))) {
      final linearTerms = <Expr>[];
      final otherTerms = <Expr>[];
      var hasExpTerm = false;
      for (final t in terms) {
        if (t.anyNode((c) => c is Pow && c.base == Constant.e)) {
          hasExpTerm = true;
          otherTerms.add(t);
        } else if (t.matchLinear(variable) != null) {
          linearTerms.add(t);
        } else {
          otherTerms.add(t);
        }
      }
      if (hasExpTerm && linearTerms.isNotEmpty && otherTerms.isNotEmpty) {
        final otherSum = otherTerms.length == 1
            ? otherTerms.first
            : Add.of(otherTerms);
        final linSum = linearTerms.length == 1
            ? linearTerms.first
            : Add.of(linearTerms);
        return Mul.raw([
          Pow.of(Constant.e, otherSum),
          Pow.of(Constant.e, linSum),
        ]);
      }
    }
    return mapped;
  }

  final split = splitNode(node);
  if (split case Add(:final terms) when terms.length >= 2) {
    Set<Expr>? commonExpFactors;
    for (final t in terms) {
      final factors = t is Mul ? t.factors : [t];
      final expSet = <Expr>{
        for (final f in factors)
          if (f is Pow && f.base == Constant.e && f.dependsOn(variable)) f,
      };
      commonExpFactors = commonExpFactors == null
          ? expSet
          : commonExpFactors.intersection(expSet);
      if (commonExpFactors.isEmpty) break;
    }
    if (commonExpFactors != null && commonExpFactors.isNotEmpty) {
      final common = commonExpFactors.length == 1
          ? commonExpFactors.first
          : Mul.of(commonExpFactors.toList()).simplify();
      final remTerms = [for (final t in terms) (t / common).simplify()];
      return common * Add.of(remTerms).simplify();
    }
  }
  return split;
}

int? _integerLogBase(int value, int base) {
  var current = base;
  var exp = 1;
  while (current < value && exp < 12) {
    current *= base;
    exp += 1;
  }
  return current == value ? exp : null;
}
