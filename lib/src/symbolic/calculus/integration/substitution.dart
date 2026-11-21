import '../../algebra/expand.dart';
import '../../algebra/rational.dart';
import '../../algebra/simplify.dart';
import '../../algebra/term_accumulator.dart';
import '../../assumptions.dart';
import '../../ast.dart';
import '../differentiation.dart';
import '../linear_form.dart';
import 'definite.dart';
import 'integration.dart';

/// Attempts exponential substitution `u = B^(alpha_0 * x)` for rational or
/// algebraic integrands whose variable dependence is confined to `B^(a_i*x + b_i)`.
Expr? tryExponentialSubstitution(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  if (depth >= 2) return null;

  Expr? commonBase;
  final expNodes = <Pow>[];
  var valid = true;

  void collect(Expr node) {
    if (!valid) return;
    if (node is Pow &&
        !node.base.dependsOn(variable) &&
        node.exponent.dependsOn(variable)) {
      if (commonBase == null) {
        commonBase = node.base;
      } else if (commonBase != node.base) {
        valid = false;
        return;
      }
      expNodes.add(node);
      return;
    }
    node.mapChildren((c) {
      collect(c);
      return c;
    });
  }

  collect(expr);
  if (!valid || expNodes.isEmpty || commonBase == null) return null;
  final base = commonBase!;
  if (!isValidExponentialBase(base)) return null;

  final linearInfos = <Pow, ({Expr a, Expr b})>{};
  for (final node in expNodes) {
    final lin = node.exponent.matchLinear(variable);
    if (lin == null) return null;
    linearInfos[node] = lin;
  }

  // Choose alpha_0 with smallest string length so integer multiples are positive/clean.
  var alpha0 = linearInfos.values.first.a;
  var bestLen = alpha0.toString().length;
  for (final info in linearInfos.values) {
    final len = info.a.toString().length;
    if (len < bestLen) {
      alpha0 = info.a;
      bestLen = len;
    }
  }

  final ratios = <Pow, int>{};
  for (final MapEntry(:key, :value) in linearInfos.entries) {
    final ratio = (value.a / alpha0).simplify(assumptions: assumptions);
    if (ratio case IntegerNumber(asInt: final m?)
        when m.abs() >= 1 && m.abs() <= 6) {
      ratios[key] = m;
    } else {
      return null;
    }
  }

  const uName = '_exp_u';
  const uVar = Variable(uName);

  Expr rewrite(Expr node) {
    if (node is Pow && linearInfos.containsKey(node)) {
      final beta = linearInfos[node]!.b;
      final m = ratios[node]!;
      return (Pow(base, beta) * Pow(uVar, IntegerNumber.of(m))).simplify(
        assumptions: assumptions,
      );
    }
    return node.mapChildren(rewrite);
  }

  final rewritten = rewrite(expr).simplify(assumptions: assumptions);
  if (rewritten.dependsOn(variable)) return null;

  final lnBase = base == Constant.e
      ? IntegerNumber.one
      : Ln(base).simplify(assumptions: assumptions);
  final integrandU = (rewritten / (alpha0 * lnBase * uVar)).simplify(
    assumptions: assumptions,
  );
  final resU = antiDerivative(
    integrandU,
    uName,
    depth: depth + 1,
    assumptions: assumptions,
  );
  if (hasUnevaluatedIntegral(resU, uName)) return null;

  final uExpr = Pow(
    base,
    (alpha0 * Variable(variable)).simplify(assumptions: assumptions),
  );
  return resU.substitute(uName, uExpr).simplify(assumptions: assumptions);
}

/// Attempts direct chain-rule matching on `candidate * factor` with respect to [variable].
Expr? tryChainRule(
  Expr candidate,
  Expr factor,
  String variable, {
  required Assumptions assumptions,
}) {
  // General u(x) * u'(x) chain rule: int u * u' dx = 1/2 * u^2
  if (candidate.dependsOn(variable)) {
    final uPrime = candidate.derivative(variable).simplify();
    if (factor.matchScalarMultiple(uPrime, variable) case final k?) {
      return (Pow(candidate, IntegerNumber.two) / IntegerNumber.two).scale(k);
    }
  }

  return switch (candidate) {
    Cos(:final expr) when expr.dependsOn(variable) => _scaleMatch(
      factor,
      expr.derivative(variable).simplify(),
      Sin(expr),
      variable,
    ),
    Sin(:final expr) when expr.dependsOn(variable) => _scaleMatch(
      factor,
      expr.derivative(variable).simplify(),
      (-Cos(expr)).simplify(),
      variable,
    ),
    Ln(:final expr) when expr.dependsOn(variable) => _scaleMatch(
      factor,
      expr.derivative(variable).simplify(),
      expr * Ln(expr) - expr,
      variable,
    ),
    Tan(:final expr) when expr.dependsOn(variable) => _scaleMatch(
      factor,
      expr.derivative(variable).simplify(),
      -Ln(Cos(expr)),
      variable,
    ),
    Sinh(:final expr) when expr.dependsOn(variable) => _scaleMatch(
      factor,
      expr.derivative(variable).simplify(),
      Cosh(expr),
      variable,
    ),
    Cosh(:final expr) when expr.dependsOn(variable) => _scaleMatch(
      factor,
      expr.derivative(variable).simplify(),
      Sinh(expr),
      variable,
    ),
    Tanh(:final expr) when expr.dependsOn(variable) => _scaleMatch(
      factor,
      expr.derivative(variable).simplify(),
      Ln(Cosh(expr)),
      variable,
    ),
    Abs(:final expr) when expr.dependsOn(variable) => _scaleMatch(
      factor,
      expr.derivative(variable).simplify(),
      (expr * Abs(expr)) / IntegerNumber.two,
      variable,
    ),
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
    final sqrtA2 = Pow(a2, FractionNumber.half).simplify();
    final sqrtPi = Pow(Constant.pi, FractionNumber.half).simplify();
    final xVar = Variable(variable);
    if (a1 == IntegerNumber.zero && a0 == IntegerNumber.zero) {
      return ((sqrtPi / (IntegerNumber.two * sqrtA2)) * Erfi(sqrtA2 * xVar))
          .simplify();
    }
    final shift = (a1 / (IntegerNumber.two * sqrtA2)).simplify();
    final u = (sqrtA2 * xVar + shift).simplify();
    final constExp =
        (a0 - Pow(a1, IntegerNumber.two) / (IntegerNumber.of(4) * a2))
            .simplify();
    final expScale = Pow(Constant.e, constExp).simplify();
    return ((expScale * sqrtPi / (IntegerNumber.two * sqrtA2)) * Erfi(u))
        .simplify();
  }

  // Require negative leading coefficient a2 = -k where k > 0 -> erf
  final k = (-a2).simplify();
  if (!isPositiveConstant(k)) return null;

  final sqrtK = Pow(k, FractionNumber.half).simplify();
  final sqrtPi = Pow(Constant.pi, FractionNumber.half).simplify();
  final xVar = Variable(variable);

  if (a1 == IntegerNumber.zero && a0 == IntegerNumber.zero) {
    // int e^(-k*x^2) dx = (sqrt(pi) / (2 * sqrt(k))) * erf(sqrt(k) * x)
    return ((sqrtPi / (IntegerNumber.two * sqrtK)) * Erf(sqrtK * xVar))
        .simplify();
  }

  // Complete the square: -k * x^2 + a1 * x + a0 = -(sqrt(k)*x - a1/(2*sqrt(k)))^2 + (a0 + a1^2/(4*k))
  final shift = (a1 / (IntegerNumber.two * sqrtK)).simplify();
  final u = (sqrtK * xVar - shift).simplify();
  final constExp = (a0 + Pow(a1, IntegerNumber.two) / (IntegerNumber.of(4) * k))
      .simplify();
  final expScale = Pow(Constant.e, constExp).simplify();
  return ((expScale * sqrtPi / (IntegerNumber.two * sqrtK)) * Erf(u))
      .simplify();
}

/// Attempts general `u`-substitution across composite subexpressions of [expr].
Expr? tryUSubstitution(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  final candidates = <Expr>{};
  _collectUCandidates(expr, variable, candidates);
  if (candidates.isEmpty) return null;

  final expandedTrig = _expandDoubleAngleTrig(expr);
  final exprVariants = expandedTrig != expr ? [expr, expandedTrig] : [expr];

  final uName = '_u$depth';
  final uVar = Variable(uName);

  for (final candidate in candidates) {
    if (!candidate.dependsOn(variable)) continue;
    if (candidate is Variable && candidate.name == variable) continue;
    final gPrime = candidate
        .derivative(variable)
        .simplify(assumptions: assumptions);
    if (gPrime is Number && gPrime.isZero) continue;

    for (final variant in exprVariants) {
      final quot = (variant / gPrime).simplify(assumptions: assumptions);
      final replaced = _replaceUCandidate(quot, candidate, uVar, variable);
      var fU = replaced.simplify(assumptions: assumptions);
      if (fU.dependsOn(variable)) {
        fU = replaced.expand().simplify(assumptions: assumptions);
      }
      if (fU.dependsOn(variable)) {
        final normQuot = quot
            .together(assumptions: assumptions)
            .cancel(assumptions: assumptions);
        if (normQuot != quot) {
          final normReplaced = _replaceUCandidate(
            normQuot,
            candidate,
            uVar,
            variable,
          );
          fU = normReplaced.simplify(assumptions: assumptions);
          if (fU.dependsOn(variable)) {
            fU = normReplaced.expand().simplify(assumptions: assumptions);
          }
        }
        if (fU.dependsOn(variable)) {
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
  const uName = '_sb';
  const uVar = Variable(uName);
  final expanded = (Pow((uVar - b) / a, IntegerNumber.of(m)) / a)
      .expand()
      .simplify(assumptions: assumptions);
  final terms = expanded is Add ? expanded.terms : [expanded];
  final integrated = <Expr>[];
  for (final t in terms) {
    final deg = polynomialDegree(t, uName);
    if (deg == null) return null;
    final coeff =
        (t / (deg == 0 ? IntegerNumber.one : Pow(uVar, IntegerNumber.of(deg))))
            .simplify();
    final newExp = (p + IntegerNumber.of(deg + 1)).simplify();
    if (newExp is Number && newExp.isZero) {
      integrated.add((coeff * Ln(uVar)).simplify());
    } else {
      integrated.add((coeff * Pow(uVar, newExp) / newExp).simplify());
    }
  }
  return (scale * Add(integrated))
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
    if ((f is Sin || f is Cos) && trigBase == null) {
      trigBase = f;
      trigPower = 1;
      continue;
    }
    if (f case Pow(base: final b, exponent: IntegerNumber(asInt: final k?))
        when (b is Sin || b is Cos) && k >= 1 && k <= 6 && trigBase == null) {
      trigBase = b;
      trigPower = k;
      continue;
    }
    xPower = null;
  }

  if (xPower != null && trigBase != null) {
    final inner = trigBase is Sin ? trigBase.expr : (trigBase as Cos).expr;
    if (inner case Ln(expr: final lnInner)) {
      if (lnInner.matchLinear(variable) case (:final a, b: final b)
          when b == IntegerNumber.zero) {
        const uName = '_ml';
        const uVar = Variable(uName);
        final expFactor = Pow(Constant.e, (xPower + IntegerNumber.one) * uVar);
        final baseTrigU = trigBase is Sin ? Sin(uVar) : Cos(uVar);
        final trigU = trigPower == 1
            ? baseTrigU
            : Pow(baseTrigU, IntegerNumber.of(trigPower));
        final uInt = antiDerivative(
          (expFactor * trigU).simplify(assumptions: assumptions),
          uName,
          assumptions: assumptions,
          depth: 2,
        );
        if (!hasUnevaluatedIntegral(uInt, uName)) {
          final preFactor = (scale / Pow(a, xPower + IntegerNumber.one))
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
            if (eExp case Atan(expr: Variable(:final name))
                when name == variable) {
              atanCoeff = IntegerNumber.one;
            } else if (eExp case Mul(factors: final ef)) {
              final (:constFactors, :varFactors) = partitionFactors(
                ef,
                variable,
              );
              if (varFactors case [Atan(expr: Variable(:final name))]
                  when name == variable) {
                atanCoeff = constFactors.length == 1
                    ? constFactors.first
                    : Mul(constFactors).simplify();
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
          const uName = '_at';
          const uVar = Variable(uName);
          final cosPow = halfExp - 2 - xDeg;
          final integrand =
              (numScale *
                      Pow(Constant.e, atanCoeff * uVar) *
                      Pow(Sin(uVar), IntegerNumber.of(xDeg)) *
                      Pow(Cos(uVar), IntegerNumber.of(cosPow)))
                  .simplify();
          final uInt = antiDerivative(
            integrand,
            uName,
            assumptions: assumptions,
            depth: 2,
          );
          if (!hasUnevaluatedIntegral(uInt, uName)) {
            return uInt
                .substitute(uName, Atan(Variable(variable)))
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
    final fU = (Pow(base, nPlus1) / nPlus1).simplify();
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
      final denom = Ln(base);
      final fU = (candidate / denom).simplify();
      return fU.scale(k);
    }
  }
  return null;
}

void _collectUCandidates(Expr node, String variable, Set<Expr> out) {
  if (!node.dependsOn(variable)) return;
  switch (node) {
    case Sin(:final expr) ||
        Cos(:final expr) ||
        Tan(:final expr) ||
        Asin(:final expr) ||
        Acos(:final expr) ||
        Atan(:final expr) ||
        Sinh(:final expr) ||
        Cosh(:final expr) ||
        Tanh(:final expr) ||
        Asinh(:final expr) ||
        Acosh(:final expr) ||
        Atanh(:final expr) ||
        Ln(:final expr) ||
        Erf(:final expr) ||
        Erfc(:final expr):
      if (node is Sin ||
          node is Cos ||
          node is Tan ||
          node is Ln ||
          node is Atan ||
          node is Asin ||
          node is Acos) {
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
      } else {
        if (base.dependsOn(variable) &&
            (base is! Variable || base.name != variable)) {
          out.add(base);
          if (base is Add &&
              exponent is IntegerNumber &&
              exponent.isNegative &&
              _findTranscendental(base, variable) != null) {
            final xVar = Variable(variable);
            out.add((base / xVar).simplify());
            out.add((base / (xVar * xVar)).simplify());
          }
        }
        if (base case Variable(:final name) when name == variable) {
          if (exponent case IntegerNumber(asInt: final m?)
              when m >= 4 && m.isEven) {
            out.add(Pow(base, IntegerNumber.of(m ~/ 2)));
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
    default:
      node.mapChildren((child) {
        _collectUCandidates(child, variable, out);
        return child;
      });
  }
}

Expr _expandDoubleAngleTrig(Expr node) {
  if (node case Sin(:final expr)) {
    if (expr case Mul(factors: [IntegerNumber(asInt: 2), final inner])) {
      return IntegerNumber.two * Sin(inner) * Cos(inner);
    }
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
    if (node case Pow(base: final nBase, exponent: final nExp)
        when nBase == cBase) {
      final ratio = (nExp / cExp).simplify();
      if (!ratio.dependsOn(variable)) {
        return Pow(uVar, ratio);
      }
    }
  }
  if (candidate is Sin && node is Pow) {
    if (node.base == Cos(candidate.expr) &&
        node.exponent == IntegerNumber.two) {
      return IntegerNumber.one - Pow(uVar, IntegerNumber.two);
    }
  }
  if (candidate is Cos && node is Pow) {
    if (node.base == Sin(candidate.expr) &&
        node.exponent == IntegerNumber.two) {
      return IntegerNumber.one - Pow(uVar, IntegerNumber.two);
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
  const tName = '_lt';
  const tVar = Variable(tName);
  final linear = _substituteExpr(candidate, tNode, tVar).matchLinear(tName);
  if (linear == null) return null;
  final (:a, :b) = linear;
  if (a is Number && a.isZero) return null;
  final tReplacement = ((uVar - b) / a).simplify(assumptions: assumptions);
  final subbed = _substituteExpr(normQuot, tNode, tReplacement);
  final reduced = subbed
      .together(assumptions: assumptions)
      .cancel(assumptions: assumptions)
      .simplify(assumptions: assumptions);
  return reduced.dependsOn(variable) ? null : reduced;
}

Expr? _findTranscendental(Expr node, String variable) {
  if (!node.dependsOn(variable)) return null;
  if (node is Sin ||
      node is Cos ||
      node is Tan ||
      node is Asin ||
      node is Acos ||
      node is Atan ||
      node is Sinh ||
      node is Cosh ||
      node is Tanh ||
      node is Ln ||
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

Expr _substituteExpr(Expr root, Expr target, Expr replacement) {
  if (root == target) return replacement;
  return root.mapChildren((c) => _substituteExpr(c, target, replacement));
}
