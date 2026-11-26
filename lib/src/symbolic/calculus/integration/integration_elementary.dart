import '../../algebra/expand.dart';
import '../../algebra/helpers.dart';
import '../../algebra/simplify.dart';
import '../../algebra/simplify/domain.dart';
import '../../assumptions.dart';
import '../../ast.dart';
import '../differentiation.dart';
import '../limit.dart';
import '../linear_form.dart';
import 'definite.dart';
import 'integration.dart';
import 'integration_power_mul.dart';

Expr? antiDerivSin(Expr inner, String variable) {
  if (inner.matchLinear(variable) case (:final a, b: _)) {
    return (-Cos(inner) / a).simplify();
  }
  if (matchScaledSquare(inner, variable) case final a?) {
    final absA = isNegativeConstant(a) ? (-a).simplify() : a;
    final sign = isNegativeConstant(a)
        ? IntegerNumber.negativeOne
        : IntegerNumber.one;
    final twoA = (IntegerNumber.two * absA).simplify();
    final scale = Pow(Constant.pi / twoA, FractionNumber.half);
    final arg =
        Pow(twoA / Constant.pi, FractionNumber.half) * Variable(variable);
    return (sign * scale * FresnelS(arg)).simplify();
  }
  return null;
}

Expr? antiDerivCos(Expr inner, String variable) {
  if (inner.matchLinear(variable) case (:final a, b: _)) {
    return (Sin(inner) / a).simplify();
  }
  if (matchScaledSquare(inner, variable) case final a?) {
    final absA = isNegativeConstant(a) ? (-a).simplify() : a;
    final twoA = (IntegerNumber.two * absA).simplify();
    final scale = Pow(Constant.pi / twoA, FractionNumber.half);
    final arg =
        Pow(twoA / Constant.pi, FractionNumber.half) * Variable(variable);
    return (scale * FresnelC(arg)).simplify();
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
/// evaluate to a complex value, otherwise `ln(u)`.
Expr logAntiderivative(Expr u, Assumptions assumptions) =>
    isPositiveExpr(u, assumptions: assumptions) || mayBeComplexExpr(u)
    ? Ln(u)
    : Ln(Abs(u));

Expr? antiDerivTan(
  Expr inner,
  String variable, {
  required Assumptions assumptions,
}) => switch (inner.matchLinear(variable)) {
  (:final a, b: _) =>
    (-logAntiderivative(Cos(inner), assumptions) / a).simplify(
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
    return ((inner * Asin(inner) +
                Pow(
                  IntegerNumber.one - Pow(inner, IntegerNumber.two),
                  FractionNumber.half,
                )) /
            a)
        .simplify();
  }
  if (_matchReciprocalLinear(inner, variable) case final c?) {
    final xVar = Variable(variable);
    final s = Pow(
      IntegerNumber.one - Pow(inner, IntegerNumber.two),
      FractionNumber.half,
    );
    return (xVar * Asin(inner) +
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
    return ((inner * Acos(inner) -
                Pow(
                  IntegerNumber.one - Pow(inner, IntegerNumber.two),
                  FractionNumber.half,
                )) /
            a)
        .simplify();
  }
  if (_matchReciprocalLinear(inner, variable) case final c?) {
    final xVar = Variable(variable);
    final s = Pow(
      IntegerNumber.one - Pow(inner, IntegerNumber.two),
      FractionNumber.half,
    );
    return (xVar * Acos(inner) -
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
    return ((inner * Atan(inner) -
                FractionNumber.half *
                    Ln(IntegerNumber.one + Pow(inner, IntegerNumber.two))) /
            a)
        .simplify();
  }
  if (_matchReciprocalLinear(inner, variable) case final c?) {
    final xVar = Variable(variable);
    return (xVar * Atan(inner) +
            (c / IntegerNumber.two) *
                Ln(Pow(xVar, IntegerNumber.two) + Pow(c, IntegerNumber.two)))
        .simplify();
  }
  return null;
}

Expr? antiDerivSinh(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) => (Cosh(inner) / a).simplify(),
      null => null,
    };

Expr? antiDerivCosh(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) => (Sinh(inner) / a).simplify(),
      null => null,
    };

Expr? antiDerivTanh(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) => (Ln(Cosh(inner)) / a).simplify(),
      null => null,
    };

Expr? antiDerivAbs(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) =>
        ((inner * Abs(inner)) / (IntegerNumber.two * a)).simplify(),
      null => null,
    };

Expr? antiDerivLn(
  Expr inner,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  if (inner.matchLinear(variable) case (:final a, b: _)) {
    return ((inner * Ln(inner) - inner) / a).simplify(assumptions: assumptions);
  }
  if (inner case Ln(expr: final arg)) {
    if (arg.matchLinear(variable) case (:final a, b: _)) {
      return ((arg * Ln(inner) - LogIntegral(arg)) / a).simplify(
        assumptions: assumptions,
      );
    }
  }
  if (depth < 2) {
    if (inner case Pow(:final base, :final exponent)
        when !base.dependsOn(variable) &&
            (base == Constant.e ||
                isPositiveExpr(base, assumptions: assumptions))) {
      final lnBase = base == Constant.e ? IntegerNumber.one : Ln(base);
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
      return (Variable(variable) * Ln(inner) - remInt).simplify(
        assumptions: assumptions,
      );
    }
  }
  return null;
}

Expr? antiDerivLambertW(Expr inner, int branch, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) =>
        ((inner * (LambertW(inner, branch: branch) - IntegerNumber.one) +
                    Pow(Constant.e, LambertW(inner, branch: branch))) /
                a)
            .simplify(),
      null => null,
    };

Expr? antiDerivErf(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) =>
        ((inner * Erf(inner) +
                    Pow(Constant.e, -Pow(inner, IntegerNumber.two)) /
                        Pow(Constant.pi, FractionNumber.half)) /
                a)
            .simplify(),
      null => null,
    };

Expr? antiDerivErfc(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) =>
        ((inner * Erfc(inner) -
                    Pow(Constant.e, -Pow(inner, IntegerNumber.two)) /
                        Pow(Constant.pi, FractionNumber.half)) /
                a)
            .simplify(),
      null => null,
    };

Expr? antiDerivErfi(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) =>
        ((inner * Erfi(inner) -
                    Pow(Constant.e, Pow(inner, IntegerNumber.two)) /
                        Pow(Constant.pi, FractionNumber.half)) /
                a)
            .simplify(),
      null => null,
    };

Expr? antiDerivFresnelS(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) =>
        ((inner * FresnelS(inner) +
                    Cos(
                          Constant.pi *
                              Pow(inner, IntegerNumber.two) /
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
        ((inner * FresnelC(inner) -
                    Sin(
                          Constant.pi *
                              Pow(inner, IntegerNumber.two) /
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
        ((inner * ExpIntegral(inner) - Pow(Constant.e, inner)) / a).simplify(),
      null => null,
    };

Expr? antiDerivLogIntegralLi(Expr inner, String variable) => switch (inner
    .matchLinear(variable)) {
  (:final a, b: _) =>
    ((inner * LogIntegral(inner) - ExpIntegral(IntegerNumber.two * Ln(inner))) /
            a)
        .simplify(),
  null => null,
};

Expr? antiDerivSinIntegralSi(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) =>
        ((inner * SinIntegral(inner) + Cos(inner)) / a).simplify(),
      null => null,
    };

Expr? antiDerivCosIntegralCi(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) =>
        ((inner * CosIntegral(inner) - Sin(inner)) / a).simplify(),
      null => null,
    };

Expr? antiDerivSinhIntegralShi(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) =>
        ((inner * SinhIntegral(inner) - Cosh(inner)) / a).simplify(),
      null => null,
    };

Expr? antiDerivCoshIntegralChi(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) =>
        ((inner * CoshIntegral(inner) - Sinh(inner)) / a).simplify(),
      null => null,
    };

Expr? antiDerivAsinh(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) =>
        ((inner * Asinh(inner) -
                    Pow(
                      Pow(inner, IntegerNumber.two) + IntegerNumber.one,
                      FractionNumber.half,
                    )) /
                a)
            .simplify(),
      null => null,
    };

Expr? antiDerivAcosh(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) =>
        ((inner * Acosh(inner) -
                    Pow(
                      Pow(inner, IntegerNumber.two) - IntegerNumber.one,
                      FractionNumber.half,
                    )) /
                a)
            .simplify(),
      null => null,
    };

Expr? antiDerivAtanh(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) =>
        ((inner * Atanh(inner) +
                    FractionNumber.half *
                        Ln(IntegerNumber.one - Pow(inner, IntegerNumber.two))) /
                a)
            .simplify(),
      null => null,
    };

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
  LessThan(left: Variable(:final name), right: final bound) ||
  LessEqual(left: Variable(:final name), right: final bound) ||
  GreaterThan(left: Variable(:final name), right: final bound) ||
  GreaterEqual(left: Variable(:final name), right: final bound) ||
  GreaterThan(left: final bound, right: Variable(:final name)) ||
  GreaterEqual(left: final bound, right: Variable(:final name)) ||
  LessThan(left: final bound, right: Variable(:final name)) ||
  LessEqual(
    left: final bound,
    right: Variable(:final name),
  ) when name == variable && !bound.dependsOn(variable) => bound,
  _ => null,
};
