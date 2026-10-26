import '../algebra/expand.dart';
import '../algebra/simplify.dart';
import '../assumptions.dart';
import '../ast.dart';
import 'linear_form.dart';

/// Analytical symbolic differentiation extension on [Expr].
extension DifferentiationExtension on Expr {
  /// Computes the exact analytical symbolic derivative of order [order] with
  /// respect to [variable].
  ///
  /// Conceptually, the derivative describes the instantaneous rate of change or
  /// the slope of the tangent line to the graph at any point (such as how the
  /// derivative of $x^3$ is $3x^2$). Formally, this executes recursive formal
  /// differentiation $\frac{\partial^n}{\partial x^n}$ applying the product
  /// rule, quotient rule, chain rule, and generalized power rule across the
  /// abstract syntax tree for [order] times.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final d1 = (x * x * x).derivative('x').simplify(); // 3 * (x ^ 2)
  /// final d2 = (x * x * x).derivative('x', order: 2).simplify(); // 6 * x
  /// ```
  Expr derivative(
    String variable, {
    int order = 1,
    Assumptions assumptions = Assumptions.none,
  }) {
    RangeError.checkValueInInterval(order, 0, 1000, 'order');
    if (order == 0) return simplify(assumptions: assumptions);
    var current = this;
    for (var i = 0; i < order; i++) {
      if (!current.dependsOn(variable)) return IntegerNumber.zero;
      current = _differentiate(
        current,
        variable,
      ).simplify(assumptions: assumptions);
    }
    return current;
  }
}

Expr _differentiate(Expr expr, String variable) => switch (expr) {
  Number() || Constant() || RelationalExpr() => IntegerNumber.zero,
  Variable(:final name) =>
    name == variable ? IntegerNumber.one : IntegerNumber.zero,
  _ when !expr.dependsOn(variable) => IntegerNumber.zero,
  Add(:final terms) => Add(
    terms.map((t) => _differentiate(t, variable)).toList(),
  ),
  Mul(:final factors) => _differentiateMul(factors, variable),
  Pow(:final base, :final exponent) => _differentiatePow(
    expr,
    base,
    exponent,
    variable,
  ),
  Sin(expr: final inner) => Mul([Cos(inner), _differentiate(inner, variable)]),
  Cos(expr: final inner) => Mul([
    IntegerNumber.negativeOne,
    Sin(inner),
    _differentiate(inner, variable),
  ]),
  Tan(expr: final inner) =>
    _differentiate(inner, variable) / Pow(Cos(inner), IntegerNumber.two),
  Asin(expr: final inner) =>
    _differentiate(inner, variable) /
        Pow(
          IntegerNumber.one - Pow(inner, IntegerNumber.two),
          FractionNumber.half,
        ),
  Acos(expr: final inner) =>
    (-_differentiate(inner, variable)) /
        Pow(
          IntegerNumber.one - Pow(inner, IntegerNumber.two),
          FractionNumber.half,
        ),
  Atan(expr: final inner) =>
    _differentiate(inner, variable) /
        (IntegerNumber.one + Pow(inner, IntegerNumber.two)),
  Sinh(expr: final inner) => Mul([
    Cosh(inner),
    _differentiate(inner, variable),
  ]),
  Cosh(expr: final inner) => Mul([
    Sinh(inner),
    _differentiate(inner, variable),
  ]),
  Tanh(expr: final inner) =>
    _differentiate(inner, variable) / Pow(Cosh(inner), IntegerNumber.two),
  Abs(expr: final inner) => Mul([
    inner / Abs(inner),
    _differentiate(inner, variable),
  ]),
  Ln(expr: final inner) => _differentiate(inner, variable) / inner,
  OrderTerm(variable: final v, :final order, :final point) =>
    v == variable
        ? OrderTerm(v, order - 1, point: point)
        : OrderTerm(v, order, point: point),
  LambertW(expr: final inner, :final branch) =>
    _differentiate(inner, variable) /
        Mul([
          Pow(Constant.e, LambertW(inner, branch: branch)),
          IntegerNumber.one + LambertW(inner, branch: branch),
        ]),
  Erf(expr: final inner) => Mul([
    (IntegerNumber.two / Pow(Constant.pi, FractionNumber.half)),
    Pow(Constant.e, -Pow(inner, IntegerNumber.two)),
    _differentiate(inner, variable),
  ]),
  Erfc(expr: final inner) => Mul([
    (IntegerNumber.of(-2) / Pow(Constant.pi, FractionNumber.half)),
    Pow(Constant.e, -Pow(inner, IntegerNumber.two)),
    _differentiate(inner, variable),
  ]),
  Gamma() ||
  Beta() ||
  Factorial() ||
  Binomial() ||
  Arg() => Derivative(expr, variable),
  Re(expr: final inner) => Re(_differentiate(inner, variable)),
  Im(expr: final inner) => Im(_differentiate(inner, variable)),
  Conjugate(expr: final inner) => Conjugate(_differentiate(inner, variable)),
  Floor() || Ceil() || Round() || Sign() => IntegerNumber.zero,
  Mod(:final left, :final right) =>
    right.dependsOn(variable)
        ? Derivative(expr, variable)
        : _differentiate(left, variable),
  Asinh(expr: final inner) =>
    _differentiate(inner, variable) /
        Pow(
          Pow(inner, IntegerNumber.two) + IntegerNumber.one,
          FractionNumber.half,
        ),
  Acosh(expr: final inner) =>
    _differentiate(inner, variable) /
        Pow(
          Pow(inner, IntegerNumber.two) - IntegerNumber.one,
          FractionNumber.half,
        ),
  Atanh(expr: final inner) =>
    _differentiate(inner, variable) /
        (IntegerNumber.one - Pow(inner, IntegerNumber.two)),
  Piecewise(:final branches, :final otherwise) => Piecewise([
    for (final (:relation, :expr) in branches)
      (relation: relation, expr: _differentiate(expr, variable)),
  ], otherwise: otherwise != null ? _differentiate(otherwise, variable) : null),
  Integral(
    :final integrand,
    variable: final intVar,
    :final lower,
    :final upper,
  ) =>
    _differentiateIntegral(integrand, intVar, lower, upper, variable),
  Derivative(
    expr: final inner,
    variable: final dVar,
    :final order,
    :final point,
  ) =>
    _differentiateDerivative(expr, inner, dVar, order, point, variable),
  Sum(expr: final inner, variable: final sVar, :final lower, :final upper) =>
    sVar != variable && !lower.dependsOn(variable) && !upper.dependsOn(variable)
        ? Sum(_differentiate(inner, variable), sVar, lower, upper)
        : Derivative(expr, variable),
  Limit() || Product() || VariableFunction() => Derivative(expr, variable),
};

Expr _differentiateDerivative(
  Expr expr,
  Expr inner,
  String dVar,
  int order,
  Expr? point,
  String variable,
) {
  if (point == null) {
    return dVar == variable
        ? Derivative(inner, variable, order: order + 1)
        : Derivative(expr, variable);
  }
  final terms = <Expr>[];
  if (point.dependsOn(variable)) {
    terms.add(
      Mul([
        Derivative(inner, dVar, order: order + 1, point: point),
        _differentiate(point, variable),
      ]),
    );
  }
  if (dVar != variable && inner.dependsOn(variable)) {
    terms.add(
      Derivative(
        _differentiate(inner, variable),
        dVar,
        order: order,
        point: point,
      ),
    );
  }
  return switch (terms) {
    [] => IntegerNumber.zero,
    [final single] => single,
    _ => Add(terms),
  };
}

Expr _differentiateIntegral(
  Expr integrand,
  String intVar,
  Expr? lower,
  Expr? upper,
  String variable,
) {
  if (lower == null || upper == null) {
    if (intVar == variable) {
      return integrand;
    }
    return Integral(_differentiate(integrand, variable), intVar);
  }
  final terms = <Expr>[];
  if (upper.dependsOn(variable)) {
    terms.add(
      Mul([
        integrand.substitute(intVar, upper),
        _differentiate(upper, variable),
      ]),
    );
  }
  if (lower.dependsOn(variable)) {
    terms.add(
      Mul([
        IntegerNumber.negativeOne,
        integrand.substitute(intVar, lower),
        _differentiate(lower, variable),
      ]),
    );
  }
  if (intVar != variable && integrand.dependsOn(variable)) {
    terms.add(
      Integral(
        _differentiate(integrand, variable),
        intVar,
        lower: lower,
        upper: upper,
      ),
    );
  }
  return switch (terms) {
    [final single] => single,
    _ => Add(terms),
  };
}

Expr _differentiateMul(List<Expr> factors, String variable) {
  final numFactors = <Expr>[];
  final denFactors = <Expr>[];

  for (final f in factors) {
    if (f case Pow(:final base, exponent: final IntegerNumber exp)
        when exp.isNegative && base.dependsOn(variable)) {
      denFactors.add(exp.isNegativeOne ? base : Pow(base, exp.neg()));
    } else {
      numFactors.add(f);
    }
  }

  if (denFactors.isNotEmpty && numFactors.isNotEmpty) {
    final left = switch (numFactors) {
      [final single] => single,
      _ => Mul(numFactors),
    };
    final right = switch (denFactors) {
      [final single] => single,
      _ => Mul(denFactors),
    };
    return switch (right) {
      Pow(:final base, :final exponent) when !exponent.dependsOn(variable) =>
        ((_differentiate(left, variable) * base -
                    exponent * left * _differentiate(base, variable))
                .expand()) /
            Pow(base, exponent + IntegerNumber.one),
      _ =>
        ((_differentiate(left, variable) * right -
                    left * _differentiate(right, variable))
                .expand()) /
            Pow(right, IntegerNumber.two),
    };
  }

  final (:constFactors, :varFactors) = partitionFactors(factors, variable);

  if (varFactors case [final singleVar]) {
    final d = _differentiate(singleVar, variable);
    return constFactors.isEmpty ? d : Mul([...constFactors, d]);
  }

  final sumTerms = <Expr>[];
  for (var i = 0; i < varFactors.length; i++) {
    final prodFactors = <Expr>[
      ...constFactors,
      for (var j = 0; j < varFactors.length; j++)
        if (j == i) _differentiate(varFactors[j], variable) else varFactors[j],
    ];
    sumTerms.add(Mul(prodFactors));
  }
  return Add(sumTerms);
}

Expr _differentiatePow(Expr expr, Expr base, Expr exponent, String variable) {
  if (base == Constant.e) {
    return Mul([expr, _differentiate(exponent, variable)]);
  }
  if (!exponent.dependsOn(variable)) {
    return Mul([
      exponent,
      Pow(base, exponent - IntegerNumber.one),
      _differentiate(base, variable),
    ]);
  }
  if (!base.dependsOn(variable)) {
    return Mul([expr, Ln(base), _differentiate(exponent, variable)]);
  }
  return Mul([
    expr,
    Add([
      Mul([_differentiate(exponent, variable), Ln(base)]),
      (exponent * _differentiate(base, variable)) / base,
    ]),
  ]);
}
