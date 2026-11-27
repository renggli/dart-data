import '../../algebra/expand.dart';
import '../../algebra/helpers.dart';
import '../../algebra/rational.dart';
import '../../algebra/simplify.dart';
import '../../algebra/trig.dart';
import '../../assumptions.dart';
import '../../ast.dart';
import '../../functions/fn.dart';
import '../linear_form.dart';
import 'definite.dart';
import 'integration.dart';
import 'trigonometric_helpers.dart';

/// Expands powered trigonometric or hyperbolic binomials `(a + b*sin(u))^m`
/// multiplied by other trig/hyperbolic powers and integrates term-by-term.
Expr? tryExpandTrigBinomialProduct(
  List<Expr> varFactors,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  if (depth >= 2 || varFactors.length < 2) return null;

  bool isLinearTrigOrHyp(Expr node) => switch (node) {
    Call(
      id: FunctionId.sin ||
          FunctionId.cos ||
          FunctionId.tan ||
          FunctionId.sinh ||
          FunctionId.cosh ||
          FunctionId.tanh,
      args: [final expr],
    ) =>
      expr.matchLinear(variable) != null,
    _ => false,
  };

  bool isTrigOrHypPower(Expr node) => switch (node) {
    Pow(:final base, exponent: IntegerNumber()) => isLinearTrigOrHyp(base),
    _ => isLinearTrigOrHyp(node),
  };

  var binomIdx = -1;
  for (var i = 0; i < varFactors.length; i++) {
    if (varFactors[i]
        case Pow(
          base: final Add addBase,
          exponent: IntegerNumber(asInt: final m?),
        )
        when m >= 2 && m <= 8 && addBase.terms.length <= 3) {
      if (addBase.anyNode(isLinearTrigOrHyp)) {
        binomIdx = i;
        break;
      }
    }
  }
  if (binomIdx < 0) return null;

  for (var i = 0; i < varFactors.length; i++) {
    if (i != binomIdx && !isTrigOrHypPower(varFactors[i])) return null;
  }

  final expandedBinom = varFactors[binomIdx]
      .expand(assumptions: assumptions)
      .simplify(assumptions: assumptions);
  var scaleFactor = IntegerNumber.one as Expr;
  Add? expandedAdd;
  if (expandedBinom is Add) {
    expandedAdd = expandedBinom;
  } else if (expandedBinom is Mul) {
    final rest = <Expr>[];
    for (final f in expandedBinom.factors) {
      if (f is Add && expandedAdd == null) {
        expandedAdd = f;
      } else {
        rest.add(f);
      }
    }
    if (rest.isNotEmpty) {
      scaleFactor = Mul.of(rest).simplify(assumptions: assumptions);
    }
  }
  if (expandedAdd == null) return null;

  final otherFactors = <Expr>[
    for (var i = 0; i < varFactors.length; i++)
      if (i != binomIdx) varFactors[i],
  ];
  final otherExpr = otherFactors.length == 1
      ? otherFactors.first
      : Mul.of(otherFactors).simplify(assumptions: assumptions);

  final results = <Expr>[];
  for (final term in expandedAdd.terms) {
    final prod = (scaleFactor * term * otherExpr).simplify(
      assumptions: assumptions,
    );
    final res = antiDerivative(
      prod,
      variable,
      depth: depth + 1,
      assumptions: assumptions,
    );
    if (hasUnevaluatedIntegral(res, variable)) return null;
    results.add(res);
  }
  return Add.of(results).simplify(assumptions: assumptions);
}

/// Integrates products of two sines or cosines via product-to-sum identities.
Expr? tryTrigProduct(Expr left, Expr right, String variable) {
  if (left case Call(id: FunctionId.sin, args: [final a])
      when a.matchLinear(variable) != null) {
    if (right case Call(id: FunctionId.cos, args: [final b])
        when b.matchLinear(variable) != null) {
      final sum = (a + b).simplify();
      final diff = (a - b).simplify();
      final expanded = ((Fn.sin(sum) + Fn.sin(diff)) / IntegerNumber.two)
          .simplify();
      return antiDerivative(expanded, variable, assumptions: Assumptions.none);
    }
    if (right case Call(id: FunctionId.sin, args: [final b])
        when b.matchLinear(variable) != null) {
      final diff = (a - b).simplify();
      final sum = (a + b).simplify();
      final expanded = ((Fn.cos(diff) - Fn.cos(sum)) / IntegerNumber.two)
          .simplify();
      return antiDerivative(expanded, variable, assumptions: Assumptions.none);
    }
  }
  if (left case Call(id: FunctionId.cos, args: [final a])
      when a.matchLinear(variable) != null) {
    if (right case Call(id: FunctionId.sin)) {
      return tryTrigProduct(right, left, variable);
    }
    if (right case Call(id: FunctionId.cos, args: [final b])
        when b.matchLinear(variable) != null) {
      final diff = (a - b).simplify();
      final sum = (a + b).simplify();
      final expanded = ((Fn.cos(diff) + Fn.cos(sum)) / IntegerNumber.two)
          .simplify();
      return antiDerivative(expanded, variable, assumptions: Assumptions.none);
    }
  }
  return null;
}

/// Integrates `c / (a + b*sin(u) + c*cos(u))` via Weierstrass half-angle substitution.
Expr? tryWeierstrassSubstitution(Expr left, Expr right, String variable) {
  final terms = right is Add ? right.terms : [right];
  var aConst = IntegerNumber.zero as Expr;
  var bSin = IntegerNumber.zero as Expr;
  var cCos = IntegerNumber.zero as Expr;
  Expr? inner;

  for (final term in terms) {
    if (!term.dependsOn(variable)) {
      aConst = (aConst + term).simplify();
      continue;
    }
    var coeff = IntegerNumber.one as Expr;
    var varPart = term;
    if (term case Mul(:final factors)) {
      final (:constFactors, :varFactors) = partitionFactors(factors, variable);
      if (varFactors.length != 1) return null;
      varPart = varFactors.first;
      coeff = switch (constFactors) {
        [] => IntegerNumber.one,
        [final single] => single,
        _ => Mul.of(constFactors).simplify(),
      };
    }
    switch (varPart) {
      case Call(id: FunctionId.sin, args: [final arg]):
        if (inner == null) {
          inner = arg;
        } else if (inner != arg) {
          return null;
        }
        bSin = (bSin + coeff).simplify();
      case Call(id: FunctionId.cos, args: [final arg]):
        if (inner == null) {
          inner = arg;
        } else if (inner != arg) {
          return null;
        }
        cCos = (cCos + coeff).simplify();
      default:
        return null;
    }
  }

  if (inner == null) return null;
  final linear = inner.matchLinear(variable);
  if (linear == null) return null;
  final k = linear.a;

  const tName = '_wt';
  const tVar = Variable(tName);
  final denom =
      ((aConst - cCos) * tVar * tVar +
              IntegerNumber.two * bSin * tVar +
              (aConst + cCos))
          .simplify();
  if (denom is Number && denom.isZero) return null;

  final integrandT = ((IntegerNumber.two * left) / (k * denom)).simplify();
  final tAntideriv = antiDerivative(
    integrandT,
    tName,
    depth: 2,
    assumptions: Assumptions.none,
  );
  if (hasUnevaluatedIntegral(tAntideriv, tName)) return null;

  return tAntideriv
      .substitute(tName, Fn.tan((inner / IntegerNumber.two).simplify()))
      .simplify();
}

/// Integrates products and quotients of integer powers `sin(u)^p * cos(u)^q`.
Expr? tryTrigPowerProduct(Expr num, Expr den, String variable) {
  final numInfo = _extractTrigPowers(num, variable);
  final denInfo = _extractTrigPowers(den, variable);
  if (numInfo == null || denInfo == null) return null;

  final inner = numInfo.inner ?? denInfo.inner;
  if (inner == null) return null;
  if (numInfo.inner != null &&
      denInfo.inner != null &&
      numInfo.inner != denInfo.inner) {
    return null;
  }
  final linear = inner.matchLinear(variable);
  if (linear == null) return null;
  final a = linear.a;

  final p = numInfo.sinExp - denInfo.sinExp;
  final q = numInfo.cosExp - denInfo.cosExp;
  if (p == 0 && q == 0) return null;
  if (p.abs() > 10 || q.abs() > 10) return null;
  final scale = (numInfo.scale / denInfo.scale).simplify();

  if (q < 0 && p == -q && p >= 2) {
    final res = antiDerivative(
      Pow.of(Fn.tan(inner), IntegerNumber.of(p)),
      variable,
      assumptions: Assumptions.none,
    );
    return hasUnevaluatedIntegral(res, variable) ? null : res.scale(scale);
  }
  if (p < 0 && q == -p && q >= 2) {
    return integrateCotPower(q, inner, a, variable).scale(scale);
  }

  final tName = freshIntegrationVar('_wt', num / den, variable, 0);
  final tVar = Variable(tName);

  if (p.isOdd && p >= -9 && p <= 9) {
    final k = (p - 1) ~/ 2;
    final cosPow = k == 0
        ? IntegerNumber.one
        : Pow.of(IntegerNumber.one - tVar * tVar, IntegerNumber.of(k));
    final rawIntegrand =
        (-scale / a) * cosPow * Pow.of(tVar, IntegerNumber.of(q));
    final integrand = k >= 0
        ? rawIntegrand.expand().simplify()
        : rawIntegrand.simplify();
    final tInt = antiDerivative(
      integrand,
      tName,
      depth: 1,
      assumptions: Assumptions.none,
    );
    if (!hasUnevaluatedIntegral(tInt, tName)) {
      return tInt.substitute(tName, Fn.cos(inner)).simplify();
    }
  }

  if (q.isOdd && q >= -9 && q <= 9) {
    final k = (q - 1) ~/ 2;
    final sinPow = k == 0
        ? IntegerNumber.one
        : Pow.of(IntegerNumber.one - tVar * tVar, IntegerNumber.of(k));
    final rawIntegrand =
        (scale / a) * Pow.of(tVar, IntegerNumber.of(p)) * sinPow;
    final integrand = k >= 0
        ? rawIntegrand.expand().simplify()
        : rawIntegrand.simplify();
    final tInt = antiDerivative(
      integrand,
      tName,
      depth: 1,
      assumptions: Assumptions.none,
    );
    if (!hasUnevaluatedIntegral(tInt, tName)) {
      return tInt.substitute(tName, Fn.sin(inner)).simplify();
    }
  }

  if ((p + q).isEven && p + q <= -2) {
    final m = -(p + q) ~/ 2 - 1;
    final integrand =
        ((scale / a) *
                Pow.of(tVar, IntegerNumber.of(p)) *
                Pow.of(IntegerNumber.one + tVar * tVar, IntegerNumber.of(m)))
            .expand()
            .simplify();
    final tInt = antiDerivative(
      integrand,
      tName,
      depth: 1,
      assumptions: Assumptions.none,
    );
    if (!hasUnevaluatedIntegral(tInt, tName)) {
      return tInt.substitute(tName, Fn.tan(inner)).simplify();
    }
  }

  if (p >= 0 && q >= 0 && p.isEven && q.isEven) {
    final twoInner = (IntegerNumber.two * inner).simplify();
    final sin2 = (IntegerNumber.one - Fn.cos(twoInner)) / IntegerNumber.two;
    final cos2 = (IntegerNumber.one + Fn.cos(twoInner)) / IntegerNumber.two;
    final expanded =
        (scale *
                Pow.of(sin2, IntegerNumber.of(p ~/ 2)) *
                Pow.of(cos2, IntegerNumber.of(q ~/ 2)))
            .expand()
            .simplify();
    if (expanded is Add || expanded != (num / den).simplify()) {
      final res = antiDerivative(
        expanded,
        variable,
        depth: 2,
        assumptions: Assumptions.none,
      );
      if (!hasUnevaluatedIntegral(res, variable)) return res;
    }
  }

  // Even positive numerator power times odd negative denominator power:
  // sin(u)^(2k) / cos(u)^m = sum_{j=0}^k C(k,j) * (-1)^j * cos(u)^(2j - m)
  if (p >= 2 && p.isEven && q < 0 && q.isOdd) {
    final k = p ~/ 2;
    final terms = <Expr>[];
    var binom = 1;
    for (var j = 0; j <= k; j++) {
      if (j > 0) binom = (binom * (k - j + 1)) ~/ j;
      final coeff = j.isOdd ? -binom : binom;
      final termInt = antiDerivative(
        (scale *
                IntegerNumber.of(coeff) *
                Pow.of(Fn.cos(inner), IntegerNumber.of(q + 2 * j)))
            .simplify(),
        variable,
        depth: 2,
        assumptions: Assumptions.none,
      );
      if (hasUnevaluatedIntegral(termInt, variable)) {
        terms.clear();
        break;
      }
      terms.add(termInt);
    }
    if (terms.isNotEmpty) return Add.of(terms).simplify();
  }
  if (q >= 2 && q.isEven && p < 0 && p.isOdd) {
    final k = q ~/ 2;
    final terms = <Expr>[];
    var binom = 1;
    for (var j = 0; j <= k; j++) {
      if (j > 0) binom = (binom * (k - j + 1)) ~/ j;
      final coeff = j.isOdd ? -binom : binom;
      final termInt = antiDerivative(
        (scale *
                IntegerNumber.of(coeff) *
                Pow.of(Fn.sin(inner), IntegerNumber.of(p + 2 * j)))
            .simplify(),
        variable,
        depth: 2,
        assumptions: Assumptions.none,
      );
      if (hasUnevaluatedIntegral(termInt, variable)) {
        terms.clear();
        break;
      }
      terms.add(termInt);
    }
    if (terms.isNotEmpty) return Add.of(terms).simplify();
  }

  return null;
}

/// Integrates products of a polynomial with trigonometric powers or products
/// via multiple-angle power reduction.
Expr? tryPolyTrigPowerReduction(List<Expr> varFactors, String variable) {
  for (var i = 0; i < varFactors.length; i++) {
    if (reduceTrigPower(varFactors[i], variable) case final reduced?) {
      final others = <Expr>[
        for (var j = 0; j < varFactors.length; j++)
          if (i != j) varFactors[j],
      ];
      final isReducible = others.every(
        (o) =>
            polynomialDegree(o, variable) != null ||
            (o is Pow &&
                !o.base.dependsOn(variable) &&
                o.exponent.matchLinear(variable) != null),
      );
      if (isReducible) {
        final otherExpr = others.length == 1
            ? others.first
            : Mul.of(others).simplify();
        final expanded = (otherExpr * reduced).expand().simplify();
        final res = antiDerivative(
          expanded,
          variable,
          assumptions: Assumptions.none,
        );
        if (!hasUnevaluatedIntegral(res, variable)) return res;
      }
    }
  }

  for (var i = 0; i < varFactors.length; i++) {
    for (var j = i + 1; j < varFactors.length; j++) {
      final f1 = varFactors[i];
      final f2 = varFactors[j];
      Expr? pairReduced;
      if (f1 case Call(id: FunctionId.sin, args: [final a])
          when a.matchLinear(variable) != null) {
        if (f2 case Call(id: FunctionId.cos, args: [final b])
            when b.matchLinear(variable) != null) {
          pairReduced =
              (Fn.sin((a + b).simplify()) + Fn.sin((a - b).simplify())) /
              IntegerNumber.two;
        } else if (f2 case Call(id: FunctionId.sin, args: [final b])
            when b.matchLinear(variable) != null) {
          pairReduced =
              (Fn.cos((a - b).simplify()) - Fn.cos((a + b).simplify())) /
              IntegerNumber.two;
        }
      } else if (f1 case Call(id: FunctionId.cos, args: [final a])
          when a.matchLinear(variable) != null) {
        if (f2 case Call(id: FunctionId.sin, args: [final b])
            when b.matchLinear(variable) != null) {
          pairReduced =
              (Fn.sin((a + b).simplify()) - Fn.sin((a - b).simplify())) /
              IntegerNumber.two;
        } else if (f2 case Call(id: FunctionId.cos, args: [final b])
            when b.matchLinear(variable) != null) {
          pairReduced =
              (Fn.cos((a + b).simplify()) + Fn.cos((a - b).simplify())) /
              IntegerNumber.two;
        }
      }
      if (pairReduced != null) {
        final others = <Expr>[
          for (var k = 0; k < varFactors.length; k++)
            if (k != i && k != j) varFactors[k],
        ];
        final isReducibleProduct = others.every(
          (o) =>
              polynomialDegree(o, variable) != null ||
              (o is Call &&
                  (o.id == FunctionId.sin || o.id == FunctionId.cos) &&
                  o.args[0].matchLinear(variable) != null) ||
              (o is Pow &&
                  !o.base.dependsOn(variable) &&
                  o.exponent.matchLinear(variable) != null),
        );
        if (isReducibleProduct) {
          final otherExpr = others.length == 1
              ? others.first
              : Mul.of(others).simplify();
          final expanded = (otherExpr * pairReduced).expand().simplify();
          final res = antiDerivative(
            expanded,
            variable,
            assumptions: Assumptions.none,
          );
          if (!hasUnevaluatedIntegral(res, variable)) return res;
        }
      }
    }
  }

  return null;
}

/// Integrates `(a1*sin(u) + b1*cos(u) + c1) / (a*sin(u) + b*cos(u) + c)`.
Expr? tryLinearTrigQuotient(Expr left, Expr right, String variable) {
  if (!left.dependsOn(variable)) return null;
  final numCombo = extractLinearTrigCombo(left, variable);
  final denCombo = extractLinearTrigCombo(right, variable);
  if (numCombo == null || denCombo == null) return null;
  final inner = denCombo.inner;
  if (inner == null || numCombo.inner != inner) return null;
  final k = inner.matchLinear(variable)!.a;

  final a = denCombo.aSin;
  final b = denCombo.bCos;
  final c = denCombo.cConst;
  final a1 = numCombo.aSin;
  final b1 = numCombo.bCos;
  final c1 = numCombo.cConst;

  final denom = (a * a + b * b).simplify();
  if (denom is Number && denom.isZero) return null;

  final alpha = ((a1 * a + b1 * b) / denom).simplify();
  final beta = ((b1 * a - a1 * b) / denom).simplify();
  final gamma = (c1 - alpha * c).simplify();

  var res = (alpha * Variable(variable)).simplify();
  if (beta != IntegerNumber.zero) {
    res = (res + (beta / k) * Fn.ln(Fn.abs(right))).simplify();
  }
  if (gamma != IntegerNumber.zero) {
    final remInt = tryWeierstrassSubstitution(gamma, right, variable);
    if (remInt == null) return null;
    res = (res + remInt).simplify();
  }
  return res;
}

/// Integrates rational trigonometric functions `R(sin(u), cos(u), tan(u))` via
/// tangent or Weierstrass substitution.
Expr? tryRationalTrigSubstitution(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  if (tryDirichletKernel(expr, variable, assumptions: assumptions)
      case final dirRes?) {
    return dirRes;
  }

  final inner = collectAffineTrigInner(expr, variable);
  if (inner == null) {
    if (depth == 0 && hasMultipleAngleTrig(expr, variable)) {
      final expanded = expr.expandTrig(assumptions: assumptions);
      if (expanded != expr) {
        return tryRationalTrigSubstitution(
          expanded,
          variable,
          assumptions: assumptions,
          depth: depth + 1,
        );
      }
    }
    if (!isIntegrationBudgetExhausted()) {
      final tanInner = _findSingleLinearTanInner(expr, variable);
      if (tanInner != null) {
        final kTan = tanInner.matchLinear(variable)!.a;
        final tName = freshIntegrationVar('_rt', expr, variable, depth);
        final tVar = Variable(tName);
        final tanReplaced = replaceTrigWithTan(expr, tanInner, tVar);
        if (!tanReplaced.dependsOn(variable)) {
          final rawIntegrand =
              (tanReplaced / (kTan * (IntegerNumber.one + tVar * tVar)))
                  .simplify(assumptions: assumptions);
          if (!exceedsNodeBudget(rawIntegrand, 250)) {
            final integrand = rawIntegrand.together(assumptions: assumptions);
            final tInt = antiDerivative(
              integrand,
              tName,
              assumptions: assumptions,
              depth: depth + 1,
            );
            if (!hasUnevaluatedIntegral(tInt, tName)) {
              return tInt
                  .substitute(tName, Fn.tan(tanInner))
                  .simplify(assumptions: assumptions);
            }
          }
        }
      }
    }
    return null;
  }
  final k = inner.matchLinear(variable)!.a;

  if (tryTrigPolyDivision(
        expr,
        inner,
        variable,
        assumptions: assumptions,
        depth: depth,
      )
      case final polyDivRes?) {
    return polyDivRes;
  }

  // 1. Try t = tan(u) if expression is even in (sin, cos)
  final tName = freshIntegrationVar('_rt', expr, variable, depth);
  final tVar = Variable(tName);
  if (!isIntegrationBudgetExhausted()) {
    final tanReplaced = replaceTrigWithTan(expr, inner, tVar);
    if (!tanReplaced.dependsOn(variable)) {
      final rawIntegrand =
          (tanReplaced / (k * (IntegerNumber.one + tVar * tVar))).simplify();
      if (!exceedsNodeBudget(rawIntegrand, 300)) {
        final integrand = rawIntegrand.together();
        final tInt = antiDerivative(
          integrand,
          tName,
          assumptions: assumptions,
          depth: depth + 1,
        );
        if (!hasUnevaluatedIntegral(tInt, tName)) {
          return tInt
              .substitute(tName, Fn.tan(inner))
              .simplify(assumptions: assumptions);
        }
      }
    }
  }

  // 2. General Weierstrass substitution t = tan(u / 2)
  if (!isIntegrationBudgetExhausted()) {
    final wReplaced = replaceTrigWithWeierstrass(expr, inner, tVar);
    if (!wReplaced.dependsOn(variable)) {
      final rawIntegrand =
          ((wReplaced * IntegerNumber.two) /
                  (k * (IntegerNumber.one + tVar * tVar)))
              .simplify();
      if (!exceedsNodeBudget(rawIntegrand, 300)) {
        final integrand = rawIntegrand.together();
        final (_, intDen) = splitNumeratorDenominator(integrand);
        final rawDeg = polynomialDegree(intDen, tName);
        if (rawDeg != null && rawDeg <= 8) {
          final deg = polynomialDegree(intDen.expand().simplify(), tName);
          if (deg != null && deg <= 8) {
            final tInt = antiDerivative(
              integrand,
              tName,
              assumptions: assumptions,
              depth: depth + 1,
            );
            if (!hasUnevaluatedIntegral(tInt, tName)) {
              return tInt
                  .substitute(
                    tName,
                    Fn.tan((inner / IntegerNumber.two).simplify()),
                  )
                  .simplify(assumptions: assumptions);
            }
          }
        }
      }
    }
  }

  return null;
}

/// Integrates products containing an odd positive power of `cos`, `sin`, `cosh`,
/// or `sinh` paired with functions of the dual trig/hyperbolic function.
Expr? tryOddTrigHypSubstitution(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  if (depth >= 2 || expr is! Mul) return null;
  final factors = expr.factors;
  for (var i = 0; i < factors.length; i++) {
    final f = factors[i];
    final Expr fnBase;
    final int exp;
    if (f case Pow(:final base, exponent: IntegerNumber(asInt: final k?))
        when k.abs() <= 11 && k.isOdd) {
      fnBase = base;
      exp = k;
    } else if (f is Call &&
        const {
          FunctionId.cos,
          FunctionId.sin,
          FunctionId.cosh,
          FunctionId.sinh,
        }.contains(f.id)) {
      fnBase = f;
      exp = 1;
    } else {
      continue;
    }

    final Expr inner;
    final int kind; // 0: cos, 1: sin, 2: cosh, 3: sinh
    if (fnBase case Call(:final id, args: [final u])) {
      inner = u;
      switch (id) {
        case FunctionId.cos:
          kind = 0;
        case FunctionId.sin:
          kind = 1;
        case FunctionId.cosh:
          kind = 2;
        case FunctionId.sinh:
          kind = 3;
        default:
          continue;
      }
    } else {
      continue;
    }

    final lin = inner.matchLinear(variable);
    if (lin == null) continue;
    final kSlope = lin.a;

    final otherFactors = <Expr>[
      for (var j = 0; j < factors.length; j++)
        if (j != i) factors[j],
    ];
    final otherExpr = otherFactors.length == 1
        ? otherFactors.first
        : Mul.of(otherFactors).simplify(assumptions: assumptions);

    final sName = freshIntegrationVar('_ts', expr, variable, depth);
    final sVar = Variable(sName);
    final sqExpr = switch (kind) {
      0 || 1 => (IntegerNumber.one - sVar * sVar).simplify(),
      2 => (IntegerNumber.one + sVar * sVar).simplify(),
      _ => (sVar * sVar - IntegerNumber.one).simplify(),
    };
    final subTarget = switch (kind) {
      0 => Fn.sin(inner),
      1 => Fn.cos(inner),
      2 => Fn.sinh(inner),
      _ => Fn.cosh(inner),
    };
    final derivSign = kind == 1 ? IntegerNumber.negativeOne : IntegerNumber.one;

    Expr? replaceOther(Expr node) {
      if (!node.dependsOn(variable)) return node;
      if (node == subTarget) return sVar;
      if (node
          case Pow(base: final pBase, exponent: IntegerNumber(asInt: final m?))
          when pBase == fnBase && m.isEven && m.abs() <= 12) {
        return Pow.of(sqExpr, IntegerNumber.of(m ~/ 2));
      }
      if (node is Add) {
        final mapped = <Expr>[];
        for (final t in node.terms) {
          final rt = replaceOther(t);
          if (rt == null) return null;
          mapped.add(rt);
        }
        return Add.of(mapped);
      }
      if (node is Mul) {
        final mapped = <Expr>[];
        for (final mf in node.factors) {
          final rm = replaceOther(mf);
          if (rm == null) return null;
          mapped.add(rm);
        }
        return Mul.of(mapped);
      }
      if (node is Pow && !node.exponent.dependsOn(variable)) {
        final rb = replaceOther(node.base);
        if (rb == null) return null;
        return Pow.of(rb, node.exponent);
      }
      return null;
    }

    final replacedOther = replaceOther(otherExpr);
    if (replacedOther == null || replacedOther.dependsOn(variable)) continue;

    final r = (exp - 1) ~/ 2;
    final remCos = r == 0
        ? IntegerNumber.one
        : Pow.of(sqExpr, IntegerNumber.of(r));
    final transformed = (derivSign * replacedOther * remCos / kSlope).simplify(
      assumptions: assumptions,
    );
    if (exceedsNodeBudget(transformed, 250)) continue;

    final sRes = antiDerivative(
      transformed,
      sName,
      assumptions: assumptions,
      depth: depth + 1,
    );
    if (!hasUnevaluatedIntegral(sRes, sName)) {
      return sRes
          .substitute(sName, subTarget)
          .simplify(assumptions: assumptions);
    }
  }
  return null;
}

/// Integrates products and quotients of integer powers `sinh(u)^p * cosh(u)^q`.
Expr? tryHypPowerProduct(
  Expr num,
  Expr den,
  String variable, {
  Assumptions assumptions = Assumptions.none,
}) {
  final numInfo = _extractHypPowers(num, variable);
  final denInfo = _extractHypPowers(den, variable);
  if (numInfo == null || denInfo == null) return null;

  final inner = numInfo.inner ?? denInfo.inner;
  if (inner == null) return null;
  if (numInfo.inner != null &&
      denInfo.inner != null &&
      numInfo.inner != denInfo.inner) {
    return null;
  }
  final linear = inner.matchLinear(variable);
  if (linear == null) return null;
  final a = linear.a;

  final p = numInfo.sinhExp - denInfo.sinhExp;
  final q = numInfo.coshExp - denInfo.coshExp;
  if (p == 0 && q == 0) return null;
  if (p.abs() > 10 || q.abs() > 10) return null;
  final scale = (numInfo.scale / denInfo.scale).simplify(
    assumptions: assumptions,
  );

  final tName = freshIntegrationVar('_ht', num / den, variable, 0);
  final tVar = Variable(tName);

  if ((p + q).isEven && p + q <= -2) {
    final m = -(p + q) ~/ 2 - 1;
    final oneMT2 = (IntegerNumber.one - tVar * tVar).simplify();
    final integrand =
        ((scale / a) *
                Pow.of(tVar, IntegerNumber.of(p)) *
                Pow.of(oneMT2, IntegerNumber.of(m)))
            .expand()
            .simplify(assumptions: assumptions);
    final tInt = antiDerivative(
      integrand,
      tName,
      depth: 1,
      assumptions: assumptions,
    );
    if (!hasUnevaluatedIntegral(tInt, tName)) {
      return tInt
          .substitute(tName, Fn.tanh(inner))
          .simplify(assumptions: assumptions);
    }
  }

  if (p.isOdd && p >= -9 && p <= 9) {
    final k = (p - 1) ~/ 2;
    final coshPow = k == 0
        ? IntegerNumber.one
        : Pow.of(
            (tVar * tVar - IntegerNumber.one).simplify(),
            IntegerNumber.of(k),
          );
    final rawIntegrand =
        (scale / a) * coshPow * Pow.of(tVar, IntegerNumber.of(q));
    final integrand = k >= 0
        ? rawIntegrand.expand().simplify(assumptions: assumptions)
        : rawIntegrand.simplify(assumptions: assumptions);
    final tInt = antiDerivative(
      integrand,
      tName,
      depth: 1,
      assumptions: assumptions,
    );
    if (!hasUnevaluatedIntegral(tInt, tName)) {
      return tInt
          .substitute(tName, Fn.cosh(inner))
          .simplify(assumptions: assumptions);
    }
  }

  if (q.isOdd && q >= -9 && q <= 9) {
    final k = (q - 1) ~/ 2;
    final sinhPow = k == 0
        ? IntegerNumber.one
        : Pow.of(
            (IntegerNumber.one + tVar * tVar).simplify(),
            IntegerNumber.of(k),
          );
    final rawIntegrand =
        (scale / a) * Pow.of(tVar, IntegerNumber.of(p)) * sinhPow;
    final integrand = k >= 0
        ? rawIntegrand.expand().simplify(assumptions: assumptions)
        : rawIntegrand.simplify(assumptions: assumptions);
    final tInt = antiDerivative(
      integrand,
      tName,
      depth: 1,
      assumptions: assumptions,
    );
    if (!hasUnevaluatedIntegral(tInt, tName)) {
      return tInt
          .substitute(tName, Fn.sinh(inner))
          .simplify(assumptions: assumptions);
    }
  }

  if (p >= 0 && q >= 0 && p.isEven && q.isEven) {
    final twoInner = (IntegerNumber.two * inner).simplify();
    final sinh2 = (Fn.cosh(twoInner) - IntegerNumber.one) / IntegerNumber.two;
    final cosh2 = (Fn.cosh(twoInner) + IntegerNumber.one) / IntegerNumber.two;
    final expanded =
        (scale *
                Pow.of(sinh2, IntegerNumber.of(p ~/ 2)) *
                Pow.of(cosh2, IntegerNumber.of(q ~/ 2)))
            .expand()
            .simplify(assumptions: assumptions);
    if (expanded is Add || expanded != (num / den).simplify()) {
      final res = antiDerivative(
        expanded,
        variable,
        depth: 2,
        assumptions: assumptions,
      );
      if (!hasUnevaluatedIntegral(res, variable)) return res;
    }
  }

  return null;
}

/// Integrates rational hyperbolic functions `R(sinh(u), cosh(u), tanh(u))` via
/// `t = tanh(u)` or exponential substitution `w = exp(u)`.
Expr? tryHyperbolicRationalSubstitution(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  if (isIntegrationBudgetExhausted()) return null;
  final inner = collectAffineHypInner(expr, variable);
  if (inner == null) return null;
  final k = inner.matchLinear(variable)!.a;

  // 1. Try t = tanh(u) for even hyperbolic functions
  final tName = freshIntegrationVar('_ht', expr, variable, depth);
  final tVar = Variable(tName);
  final tanhReplaced = replaceHypWithTanh(expr, inner, tVar);
  if (!tanhReplaced.dependsOn(variable)) {
    final rawIntegrand =
        (tanhReplaced / (k * (IntegerNumber.one - tVar * tVar))).simplify(
          assumptions: assumptions,
        );
    if (!exceedsNodeBudget(rawIntegrand, 300)) {
      final integrand = rawIntegrand.together(assumptions: assumptions);
      final tInt = antiDerivative(
        integrand,
        tName,
        assumptions: assumptions,
        depth: depth + 1,
      );
      if (!hasUnevaluatedIntegral(tInt, tName)) {
        return tInt
            .substitute(tName, Fn.tanh(inner))
            .simplify(assumptions: assumptions);
      }
    }
  }

  // 2. General exponential substitution w = exp(u)
  final wName = freshIntegrationVar('_hw', expr, variable, depth);
  final wVar = Variable(wName);
  final replaced = replaceHypWithExp(expr, inner, wVar);
  if (replaced.dependsOn(variable) || exceedsNodeBudget(replaced, 300)) {
    return null;
  }

  final integrand = (replaced / (k * wVar)).simplify().together();
  final (_, intDen) = splitNumeratorDenominator(integrand);
  if (intDen.anyNode((n) => n is Add)) {
    final rawDeg = polynomialDegree(intDen, wName);
    final paramCount = ({...expr.freeVariables}..remove(variable)).length;
    if (rawDeg != null && (rawDeg > 16 || (paramCount >= 5 && rawDeg > 8))) {
      return null;
    }
  }
  final wInt = antiDerivative(
    integrand,
    wName,
    assumptions: assumptions,
    depth: depth + 1,
  );
  if (hasUnevaluatedIntegral(wInt, wName)) return null;

  return wInt
      .substitute(wName, Pow.of(Constant.e, inner))
      .simplify(assumptions: assumptions);
}

Expr? _findSingleLinearTanInner(Expr expr, String variable) {
  Expr? found;
  var hasTan = false;
  var valid = true;
  void scan(Expr n) {
    if (!valid || !n.dependsOn(variable)) return;
    switch (n) {
      case Call(id: FunctionId.tan, args: [final expr]):
        if (expr.matchLinear(variable) == null) {
          valid = false;
          return;
        }
        hasTan = true;
        if (found == null) {
          found = expr;
        } else if (found != expr) {
          valid = false;
        }
      case Call(id: FunctionId.sin || FunctionId.cos, args: [final expr]):
        if (expr.matchLinear(variable) == null) {
          valid = false;
          return;
        }
        if (found == null) {
          found = expr;
        } else if (found != expr) {
          valid = false;
        }
      case Add(:final terms):
        for (final t in terms) {
          scan(t);
        }
      case Mul(:final factors):
        for (final f in factors) {
          scan(f);
        }
      case Pow(:final base, :final exponent) when !exponent.dependsOn(variable):
        scan(base);
      default:
        valid = false;
    }
  }

  scan(expr);
  return (valid && hasTan) ? found : null;
}

({Expr scale, int sinhExp, int coshExp, Expr? inner})? _extractHypPowers(
  Expr expr,
  String variable,
) {
  final factors = expr is Mul ? expr.factors : [expr];
  var scale = IntegerNumber.one as Expr;
  var sinhExp = 0;
  var coshExp = 0;
  Expr? inner;

  for (final f in factors) {
    if (!f.dependsOn(variable)) {
      scale = (scale * f).simplify();
      continue;
    }
    var base = f;
    var exp = 1;
    if (f case Pow(base: final pBase, exponent: IntegerNumber(:final asInt))
        when asInt != null && asInt.abs() <= 10) {
      base = pBase;
      exp = asInt;
    }
    switch (base) {
      case Call(id: FunctionId.sinh, args: [final arg]):
        if (inner == null) {
          inner = arg;
        } else if (inner != arg) {
          return null;
        }
        sinhExp += exp;
      case Call(id: FunctionId.cosh, args: [final arg]):
        if (inner == null) {
          inner = arg;
        } else if (inner != arg) {
          return null;
        }
        coshExp += exp;
      case Call(id: FunctionId.tanh, args: [final arg]):
        if (inner == null) {
          inner = arg;
        } else if (inner != arg) {
          return null;
        }
        sinhExp += exp;
        coshExp -= exp;
      default:
        return null;
    }
  }
  return (scale: scale, sinhExp: sinhExp, coshExp: coshExp, inner: inner);
}

({Expr scale, int sinExp, int cosExp, Expr? inner})? _extractTrigPowers(
  Expr expr,
  String variable,
) {
  final factors = expr is Mul ? expr.factors : [expr];
  var scale = IntegerNumber.one as Expr;
  var sinExp = 0;
  var cosExp = 0;
  Expr? inner;

  for (final f in factors) {
    if (!f.dependsOn(variable)) {
      scale = (scale * f).simplify();
      continue;
    }
    var base = f;
    var exp = 1;
    if (f case Pow(base: final pBase, exponent: IntegerNumber(:final asInt))
        when asInt != null && asInt.abs() <= 10) {
      base = pBase;
      exp = asInt;
    }
    switch (base) {
      case Call(id: FunctionId.sin, args: [final arg]):
        if (inner == null) {
          inner = arg;
        } else if (inner != arg) {
          return null;
        }
        sinExp += exp;
      case Call(id: FunctionId.cos, args: [final arg]):
        if (inner == null) {
          inner = arg;
        } else if (inner != arg) {
          return null;
        }
        cosExp += exp;
      case Call(id: FunctionId.tan, args: [final arg]):
        if (inner == null) {
          inner = arg;
        } else if (inner != arg) {
          return null;
        }
        sinExp += exp;
        cosExp -= exp;
      default:
        return null;
    }
  }
  return (scale: scale, sinExp: sinExp, cosExp: cosExp, inner: inner);
}
