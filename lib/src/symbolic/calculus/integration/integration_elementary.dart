import '../../algebra/expand.dart';
import '../../algebra/helpers.dart';
import '../../algebra/simplify.dart';
import '../../algebra/simplify/domain.dart';
import '../../assumptions.dart';
import '../../ast.dart';
import '../../functions/fn.dart';
import '../differentiation.dart';
import '../limit.dart';
import '../linear_form.dart';
import 'definite.dart';
import 'integration.dart';
import 'integration_power_mul.dart';

Expr? antiDerivSin(Expr inner, String variable) {
  if (inner.matchLinear(variable) case (:final a, b: _)) {
    return (-Fn.cos(inner) / a).simplify();
  }
  if (matchScaledSquare(inner, variable) case final a?) {
    final absA = isNegativeConstant(a) ? (-a).simplify() : a;
    final sign = isNegativeConstant(a)
        ? IntegerNumber.negativeOne
        : IntegerNumber.one;
    final twoA = (IntegerNumber.two * absA).simplify();
    final scale = Pow.of(Constant.pi / twoA, FractionNumber.half);
    final arg =
        Pow.of(twoA / Constant.pi, FractionNumber.half) * Variable(variable);
    return (sign * scale * Fn.fresnelS(arg)).simplify();
  }
  return null;
}

Expr? antiDerivCos(Expr inner, String variable) {
  if (inner.matchLinear(variable) case (:final a, b: _)) {
    return (Fn.sin(inner) / a).simplify();
  }
  if (matchScaledSquare(inner, variable) case final a?) {
    final absA = isNegativeConstant(a) ? (-a).simplify() : a;
    final twoA = (IntegerNumber.two * absA).simplify();
    final scale = Pow.of(Constant.pi / twoA, FractionNumber.half);
    final arg =
        Pow.of(twoA / Constant.pi, FractionNumber.half) * Variable(variable);
    return (scale * Fn.fresnelC(arg)).simplify();
  }
  return null;
}

Expr? matchScaledSquare(Expr expr, String variable) {
  final coeffs = extractPolynomialCoefficients(expr, variable);
  if (coeffs == null || maxPolynomialDegree(coeffs) != 2) return null;
  final c1 = coeffs[1] ?? IntegerNumber.zero;
  final c0 = coeffs[0] ?? IntegerNumber.zero;
  if (c1 != IntegerNumber.zero || c0 != IntegerNumber.zero) return null;
  return coeffs[2];
}

/// Returns `ln(u)` when `u` is proven positive under [assumptions] or may
/// evaluate to a complex value, otherwise `ln(abs(u))`, factoring out always-
/// holomorphic exponential factors `e^g` cleanly without introducing non-
/// holomorphic `exp(re(g))` terms.
Expr logAntiderivative(Expr u, Assumptions assumptions) {
  if (u case Pow(base: Constant.e, :final exponent)) {
    return exponent;
  }
  if (u case Mul(:final factors)) {
    final expTerms = <Expr>[];
    final rest = <Expr>[];
    for (final f in factors) {
      if (f case Pow(base: Constant.e, :final exponent)) {
        expTerms.add(exponent);
      } else {
        rest.add(f);
      }
    }
    if (expTerms.isNotEmpty) {
      final linSum = expTerms.length == 1
          ? expTerms.first
          : Add.of(expTerms).simplify(assumptions: assumptions);
      if (rest.isEmpty) return linSum;
      final restProd = rest.length == 1
          ? rest.first
          : Mul.of(rest).simplify(assumptions: assumptions);
      return (linSum + logAntiderivative(restProd, assumptions)).simplify(
        assumptions: assumptions,
      );
    }
  }
  return isPositiveExpr(u, assumptions: assumptions) || mayBeComplexExpr(u)
      ? Fn.ln(u)
      : Fn.ln(Fn.abs(u));
}

Expr? antiDerivTan(
  Expr inner,
  String variable, {
  required Assumptions assumptions,
}) => switch (inner.matchLinear(variable)) {
  (:final a, b: _) =>
    (-logAntiderivative(Fn.cos(inner), assumptions) / a).simplify(
      assumptions: assumptions,
    ),
  null => null,
};

Expr? _matchReciprocalLinear(Expr inner, String variable) {
  final prod = (inner * Variable(variable)).simplify();
  return prod.dependsOn(variable) ? null : prod;
}

Expr? antiDerivAsin(Expr inner, String variable) {
  if (inner.matchLinear(variable) case (:final a, b: _)) {
    return ((inner * Fn.asin(inner) +
                Pow.of(
                  IntegerNumber.one - Pow.of(inner, IntegerNumber.two),
                  FractionNumber.half,
                )) /
            a)
        .simplify();
  }
  if (_matchReciprocalLinear(inner, variable) case final c?) {
    final xVar = Variable(variable);
    final s = Pow.of(
      IntegerNumber.one - Pow.of(inner, IntegerNumber.two),
      FractionNumber.half,
    );
    return (xVar * Fn.asin(inner) +
            c *
                logAntiderivative(
                  (xVar * (IntegerNumber.one + s)) / c,
                  Assumptions.none,
                ))
        .simplify();
  }
  return null;
}

Expr? antiDerivAcos(Expr inner, String variable) {
  if (inner.matchLinear(variable) case (:final a, b: _)) {
    return ((inner * Fn.acos(inner) -
                Pow.of(
                  IntegerNumber.one - Pow.of(inner, IntegerNumber.two),
                  FractionNumber.half,
                )) /
            a)
        .simplify();
  }
  if (_matchReciprocalLinear(inner, variable) case final c?) {
    final xVar = Variable(variable);
    final s = Pow.of(
      IntegerNumber.one - Pow.of(inner, IntegerNumber.two),
      FractionNumber.half,
    );
    return (xVar * Fn.acos(inner) -
            c *
                logAntiderivative(
                  (xVar * (IntegerNumber.one + s)) / c,
                  Assumptions.none,
                ))
        .simplify();
  }
  return null;
}

Expr? antiDerivAtan(Expr inner, String variable) {
  if (inner.matchLinear(variable) case (:final a, b: _)) {
    return ((inner * Fn.atan(inner) -
                FractionNumber.half *
                    Fn.ln(
                      IntegerNumber.one + Pow.of(inner, IntegerNumber.two),
                    )) /
            a)
        .simplify();
  }
  if (_matchReciprocalLinear(inner, variable) case final c?) {
    final xVar = Variable(variable);
    return (xVar * Fn.atan(inner) +
            (c / IntegerNumber.two) *
                Fn.ln(
                  Pow.of(xVar, IntegerNumber.two) +
                      Pow.of(c, IntegerNumber.two),
                ))
        .simplify();
  }
  if (_matchExpScaledLinear(inner, variable) case (
    scale: _,
    :final base,
    :final a,
    b: _,
  )) {
    final lnBase = base == Constant.e ? IntegerNumber.one : Fn.ln(base);
    final cEff = (a * lnBase).simplify();
    return ((ComplexNumber.i / (IntegerNumber.two * cEff)) *
            (Fn.polylog(IntegerNumber.two, -ComplexNumber.i * inner) -
                Fn.polylog(IntegerNumber.two, ComplexNumber.i * inner)))
        .simplify();
  }
  return null;
}

Expr? antiDerivSinh(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) => (Fn.cosh(inner) / a).simplify(),
      null => null,
    };

Expr? antiDerivCosh(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) => (Fn.sinh(inner) / a).simplify(),
      null => null,
    };

Expr? antiDerivTanh(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) => (Fn.ln(Fn.cosh(inner)) / a).simplify(),
      null => null,
    };

Expr? antiDerivAbs(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) =>
        ((inner * Fn.abs(inner)) / (IntegerNumber.two * a)).simplify(),
      null => null,
    };

Expr? antiDerivLn(
  Expr inner,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  if (inner.matchLinear(variable) case (:final a, b: _)) {
    return ((inner * Fn.ln(inner) - inner) / a).simplify(
      assumptions: assumptions,
    );
  }
  if (_matchLinPlusExp(inner, variable) case (
    :final constTerm,
    :final expTerm,
    :final base,
    :final slope,
  )) {
    final r = (expTerm / constTerm).simplify(assumptions: assumptions);
    final lnBase = base == Constant.e
        ? IntegerNumber.one
        : Fn.ln(base).simplify(assumptions: assumptions);
    final cEff = (slope * lnBase).simplify(assumptions: assumptions);
    return (Fn.ln(constTerm) * Variable(variable) -
            Fn.polylog(IntegerNumber.two, -r) / cEff)
        .simplify(assumptions: assumptions);
  }
  if (inner case Call(id: FunctionId.abs, args: [final sub])) {
    if (_matchLinPlusExp(sub, variable) case (
      :final constTerm,
      :final expTerm,
      :final base,
      :final slope,
    )) {
      final r = (expTerm / constTerm).simplify(assumptions: assumptions);
      final lnBase = base == Constant.e
          ? IntegerNumber.one
          : Fn.ln(base).simplify(assumptions: assumptions);
      final cEff = (slope * lnBase).simplify(assumptions: assumptions);
      return (Fn.ln(Fn.abs(constTerm)) * Variable(variable) -
              Fn.polylog(IntegerNumber.two, -r) / cEff)
          .simplify(assumptions: assumptions);
    }
  }
  if (depth < 3 && (inner is Mul || inner is Pow)) {
    final rawFactors = inner is Mul ? inner.factors : [inner];
    final items = <({Expr base, int exp})>[];
    var allPositiveOrAbs = true;
    for (final f in rawFactors) {
      if (f case Pow(:final base, exponent: IntegerNumber(asInt: final k?))) {
        if ((base is Call && base.id == FunctionId.abs) ||
            isPositiveExpr(base, assumptions: assumptions)) {
          items.add((base: base, exp: k));
        } else {
          allPositiveOrAbs = false;
          break;
        }
      } else if ((f is Call && f.id == FunctionId.abs) ||
          isPositiveExpr(f, assumptions: assumptions)) {
        items.add((base: f, exp: 1));
      } else {
        allPositiveOrAbs = false;
        break;
      }
    }
    if (allPositiveOrAbs &&
        items.any((it) => it.base.dependsOn(variable)) &&
        (items.length >= 2 || (items.length == 1 && items.first.exp != 1))) {
      final sumTerms = <Expr>[];
      var allOk = true;
      for (final (:base, :exp) in items) {
        if (!base.dependsOn(variable)) {
          sumTerms.add(
            (IntegerNumber.of(exp) * Fn.ln(base) * Variable(variable)).simplify(
              assumptions: assumptions,
            ),
          );
          continue;
        }
        final subInt = antiDerivative(
          Fn.ln(base),
          variable,
          assumptions: assumptions,
          depth: depth + 1,
        );
        if (hasUnevaluatedIntegral(subInt, variable)) {
          allOk = false;
          break;
        }
        sumTerms.add(
          (IntegerNumber.of(exp) * subInt).simplify(assumptions: assumptions),
        );
      }
      if (allOk) {
        return Add.of(sumTerms).simplify(assumptions: assumptions);
      }
    }
  }
  if (inner case Call(id: FunctionId.ln, args: [final arg])) {
    if (arg.matchLinear(variable) case (:final a, b: _)) {
      return ((arg * Fn.ln(inner) - Fn.li(arg)) / a).simplify(
        assumptions: assumptions,
      );
    }
  }
  if (depth < 2) {
    if (inner case Pow(:final base, :final exponent)
        when !base.dependsOn(variable) &&
            (base == Constant.e ||
                isPositiveExpr(base, assumptions: assumptions))) {
      final lnBase = base == Constant.e ? IntegerNumber.one : Fn.ln(base);
      final gInt = antiDerivative(
        exponent,
        variable,
        assumptions: assumptions,
        depth: depth + 1,
      );
      if (!hasUnevaluatedIntegral(gInt, variable)) {
        return (lnBase * gInt).simplify(assumptions: assumptions);
      }
    }
  }
  if (depth >= 2) return null;
  final uPrime = (inner.derivative(variable, assumptions: assumptions) / inner)
      .simplify(assumptions: assumptions);
  final (uNum, uDen) = splitNumeratorDenominator(uPrime);
  final uNumExp = uNum
      .expand(assumptions: assumptions)
      .simplify(assumptions: assumptions);
  final uDenExp = uDen
      .expand(assumptions: assumptions)
      .simplify(assumptions: assumptions);
  if (polynomialDegree(uNumExp, variable) != null &&
      polynomialDegree(uDenExp, variable) != null) {
    final rem = (Variable(variable) * uNumExp / uDenExp).simplify(
      assumptions: assumptions,
    );
    final remInt = antiDerivative(
      rem,
      variable,
      assumptions: assumptions,
      depth: depth + 1,
    );
    if (!hasUnevaluatedIntegral(remInt, variable)) {
      return (Variable(variable) * Fn.ln(inner) - remInt).simplify(
        assumptions: assumptions,
      );
    }
  }
  return null;
}

Expr? antiDerivLambertW(Expr inner, int branch, String variable) {
  final wExpr = branch == 0
      ? Fn.lambertW(inner)
      : Fn.lambertW(inner, IntegerNumber.of(branch));
  return switch (inner.matchLinear(variable)) {
    (:final a, b: _) =>
      ((inner * (wExpr - IntegerNumber.one) + Pow.of(Constant.e, wExpr)) / a)
          .simplify(),
    null => null,
  };
}

Expr? antiDerivErf(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) =>
        ((inner * Fn.erf(inner) +
                    Pow.of(Constant.e, -Pow.of(inner, IntegerNumber.two)) /
                        Pow.of(Constant.pi, FractionNumber.half)) /
                a)
            .simplify(),
      null => null,
    };

Expr? antiDerivErfc(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) =>
        ((inner * Fn.erfc(inner) -
                    Pow.of(Constant.e, -Pow.of(inner, IntegerNumber.two)) /
                        Pow.of(Constant.pi, FractionNumber.half)) /
                a)
            .simplify(),
      null => null,
    };

Expr? antiDerivErfi(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) =>
        ((inner * Fn.erfi(inner) -
                    Pow.of(Constant.e, Pow.of(inner, IntegerNumber.two)) /
                        Pow.of(Constant.pi, FractionNumber.half)) /
                a)
            .simplify(),
      null => null,
    };

Expr? antiDerivFresnelS(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) =>
        ((inner * Fn.fresnelS(inner) +
                    Fn.cos(
                          Constant.pi *
                              Pow.of(inner, IntegerNumber.two) /
                              IntegerNumber.two,
                        ) /
                        Constant.pi) /
                a)
            .simplify(),
      null => null,
    };

Expr? antiDerivFresnelC(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) =>
        ((inner * Fn.fresnelC(inner) -
                    Fn.sin(
                          Constant.pi *
                              Pow.of(inner, IntegerNumber.two) /
                              IntegerNumber.two,
                        ) /
                        Constant.pi) /
                a)
            .simplify(),
      null => null,
    };

Expr? antiDerivExpIntegralEi(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) =>
        ((inner * Fn.ei(inner) - Pow.of(Constant.e, inner)) / a).simplify(),
      null => null,
    };

Expr? antiDerivLogIntegralLi(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) =>
        ((inner * Fn.li(inner) - Fn.ei(IntegerNumber.two * Fn.ln(inner))) / a)
            .simplify(),
      null => null,
    };

Expr? antiDerivSinIntegralSi(Expr inner, String variable) => switch (inner
    .matchLinear(variable)) {
  (:final a, b: _) => ((inner * Fn.si(inner) + Fn.cos(inner)) / a).simplify(),
  null => null,
};

Expr? antiDerivCosIntegralCi(Expr inner, String variable) => switch (inner
    .matchLinear(variable)) {
  (:final a, b: _) => ((inner * Fn.ci(inner) - Fn.sin(inner)) / a).simplify(),
  null => null,
};

Expr? antiDerivSinhIntegralShi(Expr inner, String variable) => switch (inner
    .matchLinear(variable)) {
  (:final a, b: _) => ((inner * Fn.shi(inner) - Fn.cosh(inner)) / a).simplify(),
  null => null,
};

Expr? antiDerivCoshIntegralChi(Expr inner, String variable) => switch (inner
    .matchLinear(variable)) {
  (:final a, b: _) => ((inner * Fn.chi(inner) - Fn.sinh(inner)) / a).simplify(),
  null => null,
};

Expr? antiDerivAsinh(Expr inner, String variable) {
  if (inner.matchLinear(variable) case (:final a, b: _)) {
    return ((inner * Fn.asinh(inner) -
                Pow.of(
                  Pow.of(inner, IntegerNumber.two) + IntegerNumber.one,
                  FractionNumber.half,
                )) /
            a)
        .simplify();
  }
  if (_matchReciprocalLinear(inner, variable) case final c?) {
    final xVar = Variable(variable);
    final s = Pow.of(
      IntegerNumber.one + Pow.of(inner, IntegerNumber.two),
      FractionNumber.half,
    );
    return (xVar * Fn.asinh(inner) +
            c *
                logAntiderivative(
                  (xVar * (IntegerNumber.one + s)) / c,
                  Assumptions.none,
                ))
        .simplify();
  }
  return null;
}

Expr? antiDerivAcosh(Expr inner, String variable) {
  if (inner.matchLinear(variable) case (:final a, b: _)) {
    return ((inner * Fn.acosh(inner) -
                Pow.of(
                  Pow.of(inner, IntegerNumber.two) - IntegerNumber.one,
                  FractionNumber.half,
                )) /
            a)
        .simplify();
  }
  if (_matchReciprocalLinear(inner, variable) case final c?) {
    final xVar = Variable(variable);
    final s =
        Pow.of(inner - IntegerNumber.one, FractionNumber.half) *
        Pow.of(inner + IntegerNumber.one, FractionNumber.half);
    return (xVar * Fn.acosh(inner) - c * Fn.atan(s)).simplify();
  }
  return null;
}

Expr? antiDerivAtanh(Expr inner, String variable) {
  if (inner.matchLinear(variable) case (:final a, b: _)) {
    return ((inner * Fn.atanh(inner) +
                FractionNumber.half *
                    Fn.ln(
                      IntegerNumber.one - Pow.of(inner, IntegerNumber.two),
                    )) /
            a)
        .simplify();
  }
  if (_matchReciprocalLinear(inner, variable) case final c?) {
    final xVar = Variable(variable);
    return (xVar * Fn.atanh(inner) +
            (c / IntegerNumber.two) *
                logAntiderivative(
                  Pow.of(xVar, IntegerNumber.two) -
                      Pow.of(c, IntegerNumber.two),
                  Assumptions.none,
                ))
        .simplify();
  }
  if (_matchExpScaledLinear(inner, variable) case (
    scale: _,
    :final base,
    :final a,
    b: _,
  )) {
    final lnBase = base == Constant.e ? IntegerNumber.one : Fn.ln(base);
    final cEff = (a * lnBase).simplify();
    return ((IntegerNumber.one / (IntegerNumber.two * cEff)) *
            (Fn.polylog(IntegerNumber.two, inner) -
                Fn.polylog(IntegerNumber.two, -inner)))
        .simplify();
  }
  return null;
}

/// Integrates `polylog(order, c * B^(a*x + b))` with respect to [variable].
Expr? antiDerivPolylog(
  Expr order,
  Expr arg,
  String variable, {
  required Assumptions assumptions,
}) {
  if (order.dependsOn(variable)) return null;
  if (_matchExpScaledLinear(arg, variable) case (
    scale: _,
    :final base,
    :final a,
    b: _,
  )) {
    final lnBase = base == Constant.e
        ? IntegerNumber.one
        : Fn.ln(base).simplify(assumptions: assumptions);
    return (Fn.polylog(
              (order + IntegerNumber.one).simplify(assumptions: assumptions),
              arg,
            ) /
            (a * lnBase))
        .simplify(assumptions: assumptions);
  }
  return null;
}

Expr antiDerivPiecewise(
  Piecewise expr,
  String variable, {
  required Assumptions assumptions,
}) {
  final m = expr.branches.length;
  final rawG = <Expr>[
    for (var i = 0; i < m; i++)
      antiDerivative(expr.branches[i].expr, variable, assumptions: assumptions),
  ];
  final rawOth = expr.otherwise != null
      ? antiDerivative(expr.otherwise!, variable, assumptions: assumptions)
      : null;

  Expr evalBoundary(Expr f, Expr pt, LimitDirection dir) {
    final sub = f.substitute(variable, pt).simplify(assumptions: assumptions);
    if (sub != Constant.undefined &&
        !sub.anyNode(
          (n) => n == Constant.undefined || n == Constant.infinity,
        )) {
      return sub;
    }
    return f.limit(variable, pt, direction: dir, assumptions: assumptions);
  }

  final constants = <Expr>[IntegerNumber.zero];
  for (var k = 0; k < m - 1; k++) {
    final pt = _extractBoundaryPoint(expr.branches[k].relation, variable);
    if (pt != null) {
      final vLeft =
          (evalBoundary(rawG[k], pt, LimitDirection.fromBelow) + constants[k])
              .simplify(assumptions: assumptions);
      final vRight = evalBoundary(rawG[k + 1], pt, LimitDirection.fromAbove);
      constants.add((vLeft - vRight).simplify(assumptions: assumptions));
    } else {
      constants.add(IntegerNumber.zero);
    }
  }

  Expr? constOth;
  if (rawOth != null && m > 0) {
    final pt = _extractBoundaryPoint(expr.branches[m - 1].relation, variable);
    if (pt != null) {
      final vLeft =
          (evalBoundary(rawG[m - 1], pt, LimitDirection.fromBelow) +
                  constants[m - 1])
              .simplify(assumptions: assumptions);
      final vRight = evalBoundary(rawOth, pt, LimitDirection.fromAbove);
      constOth = (vLeft - vRight).simplify(assumptions: assumptions);
    } else {
      constOth = IntegerNumber.zero;
    }
  }

  final newBranches = <PiecewiseBranch>[
    for (var i = 0; i < m; i++)
      (
        relation: expr.branches[i].relation,
        expr: (rawG[i] + constants[i]).simplify(),
      ),
  ];
  final newOtherwise = rawOth != null
      ? (rawOth + (constOth ?? IntegerNumber.zero)).simplify()
      : null;
  return Piecewise(newBranches, otherwise: newOtherwise);
}

Expr? _extractBoundaryPoint(Expr cond, String variable) => switch (cond) {
  Relational(
    op: RelOp.lessThan ||
        RelOp.lessEqual ||
        RelOp.greaterThan ||
        RelOp.greaterEqual,
    left: Variable(:final name),
    right: final bound,
  ) ||
  Relational(
    op: RelOp.lessThan ||
        RelOp.lessEqual ||
        RelOp.greaterThan ||
        RelOp.greaterEqual,
    left: final bound,
    right: Variable(:final name),
  ) when name == variable && !bound.dependsOn(variable) => bound,
  _ => null,
};

({Expr scale, Expr base, Expr a, Expr b})? _matchExpScaledLinear(
  Expr expr,
  String variable,
) {
  final factors = expr is Mul ? expr.factors : [expr];
  final consts = <Expr>[];
  Pow? expPow;
  for (final f in factors) {
    if (!f.dependsOn(variable)) {
      consts.add(f);
    } else if (f is Pow && expPow == null && !f.base.dependsOn(variable)) {
      expPow = f;
    } else {
      return null;
    }
  }
  if (expPow == null || !isValidExponentialBase(expPow.base)) return null;
  final lin = expPow.exponent.matchLinear(variable);
  if (lin == null) return null;
  final scale = consts.isEmpty ? IntegerNumber.one : Mul.of(consts).simplify();
  return (scale: scale, base: expPow.base, a: lin.a, b: lin.b);
}

({Expr constTerm, Expr expTerm, Expr base, Expr slope})? _matchLinPlusExp(
  Expr expr,
  String variable,
) {
  if (expr is! Add) return null;
  final constTerms = <Expr>[];
  final varTerms = <Expr>[];
  for (final t in expr.terms) {
    if (!t.dependsOn(variable)) {
      constTerms.add(t);
    } else {
      varTerms.add(t);
    }
  }
  if (constTerms.isEmpty || varTerms.length != 1) return null;
  final constTerm = constTerms.length == 1
      ? constTerms.first
      : Add.of(constTerms).simplify();
  if (constTerm is Number && constTerm.isZero) return null;
  final expMatch = _matchExpScaledLinear(varTerms.first, variable);
  if (expMatch == null) return null;
  return (
    constTerm: constTerm,
    expTerm: varTerms.first,
    base: expMatch.base,
    slope: expMatch.a,
  );
}
