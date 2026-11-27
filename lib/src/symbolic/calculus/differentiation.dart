import '../algebra/expand.dart';
import '../algebra/helpers.dart';
import '../algebra/simplify.dart';
import '../algebra/simplify/domain.dart';
import '../assumptions.dart';
import '../ast.dart';
import '../functions/fn.dart';
import 'linear_form.dart';

/// Analytical symbolic differentiation extension on [Expr].
extension DifferentiationExtension on Expr {
  /// Computes the exact analytical symbolic derivative of order [order] with
  /// respect to [variable].
  Expr derivative(
    String variable, {
    int order = 1,
    Assumptions assumptions = Assumptions.none,
  }) {
    RangeError.checkValueInInterval(order, 0, 1000, 'order');
    if (order == 0) return simplify(assumptions: assumptions);
    var current = simplify(assumptions: assumptions);
    for (var i = 0; i < order; i++) {
      if (!current.dependsOn(variable)) return IntegerNumber.zero;
      current = _differentiate(
        current,
        variable,
        assumptions,
      ).simplify(assumptions: assumptions);
    }
    return current;
  }
}

Expr _differentiate(
  Expr expr,
  String variable, [
  Assumptions assumptions = Assumptions.none,
]) => switch (expr) {
  Number() || Constant() || Relational() => IntegerNumber.zero,
  Variable(:final name) =>
    name == variable ? IntegerNumber.one : IntegerNumber.zero,
  _ when !expr.dependsOn(variable) => IntegerNumber.zero,
  Add(:final terms) => Add.of([
    for (final t in terms) _differentiate(t, variable, assumptions),
  ]),
  Mul(:final factors) => _differentiateMul(factors, variable, assumptions),
  Pow(:final base, :final exponent) => _differentiatePow(
    expr,
    base,
    exponent,
    variable,
    assumptions,
  ),
  Call(:final spec, :final args) => () {
    final rule = spec.derivativeRule;
    if (rule != null) {
      final res = rule(
        args,
        variable,
        (inner) => _differentiate(inner, variable, assumptions),
        isComplexVar: assumptions.domainOf(variable) == VariableDomain.complex,
      );
      if (res != null) return res;
    }
    return Derivative(expr, variable);
  }(),
  OrderTerm(variable: final v, :final order, :final point) =>
    v == variable
        ? OrderTerm(v, order == 0 ? 0 : order - 1, point: point)
        : OrderTerm(v, order, point: point),
  Piecewise(:final branches, :final otherwise) => Piecewise(
    [
      for (final (:relation, :expr) in branches)
        (relation: relation, expr: _differentiate(expr, variable, assumptions)),
    ],
    otherwise: otherwise != null
        ? _differentiate(otherwise, variable, assumptions)
        : null,
  ),
  Integral(
    :final integrand,
    variable: final intVar,
    :final lower,
    :final upper,
  ) =>
    _differentiateIntegral(
      integrand,
      intVar,
      lower,
      upper,
      variable,
      assumptions,
    ),
  Derivative(
    expr: final inner,
    variable: final dVar,
    :final order,
    :final point,
  ) =>
    _differentiateDerivative(
      expr,
      inner,
      dVar,
      order,
      point,
      variable,
      assumptions,
    ),
  Sum(expr: final inner, variable: final sVar, :final lower, :final upper) =>
    sVar != variable && !lower.dependsOn(variable) && !upper.dependsOn(variable)
        ? Sum(_differentiate(inner, variable, assumptions), sVar, lower, upper)
        : Derivative(expr, variable),
  Product(
    expr: final inner,
    variable: final pVar,
    :final lower,
    :final upper,
  ) =>
    pVar != variable && !lower.dependsOn(variable) && !upper.dependsOn(variable)
        ? expr *
              Sum(
                _differentiate(inner, variable, assumptions) / inner,
                pVar,
                lower,
                upper,
              )
        : Derivative(expr, variable),
  RootSum(:final polynomial, variable: final rVar, :final body) => () {
    if (rVar == variable) return IntegerNumber.zero;
    if (!polynomial.dependsOn(variable)) {
      return RootSum(
        polynomial,
        rVar,
        _differentiate(body, variable, assumptions),
      );
    }
    final total =
        _differentiate(body, variable, assumptions) -
        _differentiate(body, rVar, assumptions) *
            _differentiate(polynomial, variable, assumptions) /
            _differentiate(polynomial, rVar, assumptions);
    return RootSum(polynomial, rVar, total);
  }(),
  Limit() => Derivative(expr, variable),
};

Expr _differentiateDerivative(
  Expr expr,
  Expr inner,
  String dVar,
  int order,
  Expr? point,
  String variable,
  Assumptions assumptions,
) {
  if (point == null) {
    return dVar == variable
        ? Derivative(inner, variable, order: order + 1)
        : Derivative(expr, variable);
  }
  final terms = <Expr>[];
  if (point.dependsOn(variable)) {
    terms.add(
      Derivative(inner, dVar, order: order + 1, point: point) *
          _differentiate(point, variable, assumptions),
    );
  }
  if (dVar != variable && inner.dependsOn(variable)) {
    terms.add(
      Derivative(
        _differentiate(inner, variable, assumptions),
        dVar,
        order: order,
        point: point,
      ),
    );
  }
  return Add.of(terms);
}

Expr _differentiateIntegral(
  Expr integrand,
  String intVar,
  Expr? lower,
  Expr? upper,
  String variable,
  Assumptions assumptions,
) {
  if (lower == null || upper == null) {
    if (intVar == variable) return integrand;
    return Integral(_differentiate(integrand, variable, assumptions), intVar);
  }
  final terms = <Expr>[];
  if (upper.dependsOn(variable)) {
    terms.add(
      integrand.substitute(intVar, upper) *
          _differentiate(upper, variable, assumptions),
    );
  }
  if (lower.dependsOn(variable)) {
    terms.add(
      -integrand.substitute(intVar, lower) *
          _differentiate(lower, variable, assumptions),
    );
  }
  if (intVar != variable && integrand.dependsOn(variable)) {
    terms.add(
      Integral(
        _differentiate(integrand, variable, assumptions),
        intVar,
        lower: lower,
        upper: upper,
      ),
    );
  }
  return Add.of(terms);
}

Expr _differentiateMul(
  List<Expr> factors,
  String variable,
  Assumptions assumptions,
) {
  final numFactors = <Expr>[];
  final denFactors = <Expr>[];

  for (final f in factors) {
    if (f case Pow(:final base, exponent: final IntegerNumber exp)
        when exp.isNegative && base.dependsOn(variable)) {
      denFactors.add(exp.isNegativeOne ? base : Pow.of(base, exp.neg()));
    } else {
      numFactors.add(f);
    }
  }

  if (denFactors.length == 1 && numFactors.isNotEmpty) {
    final left = Mul.of(numFactors);
    final right = denFactors.first;
    final degLeft = polynomialDegree(left, variable);
    return switch (right) {
      Pow(:final base, :final exponent) when !exponent.dependsOn(variable) =>
        () {
          final degBase = polynomialDegree(base, variable);
          final num =
              _differentiate(left, variable, assumptions) * base -
              exponent * left * _differentiate(base, variable, assumptions);
          final shouldExpand =
              (degLeft != null &&
                  degLeft <= 4 &&
                  degBase != null &&
                  degBase <= 4) ||
              (exponent is IntegerNumber &&
                  (exponent.asInt == null || exponent.asInt!.abs() > 16));
          return (shouldExpand ? num.expand() : num) /
              Pow.of(base, exponent + IntegerNumber.one);
        }(),
      _ => () {
        final degRight = polynomialDegree(right, variable);
        final num =
            _differentiate(left, variable, assumptions) * right -
            left * _differentiate(right, variable, assumptions);
        final shouldExpand =
            degLeft != null &&
            degLeft <= 4 &&
            degRight != null &&
            degRight <= 4;
        return (shouldExpand ? num.expand() : num) /
            Pow.of(right, IntegerNumber.two);
      }(),
    };
  }

  final (:constFactors, :varFactors) = partitionFactors(factors, variable);

  if (varFactors case [final singleVar]) {
    final d = _differentiate(singleVar, variable, assumptions);
    return constFactors.isEmpty ? d : Mul.of([...constFactors, d]);
  }

  final sumTerms = <Expr>[];
  for (var i = 0; i < varFactors.length; i++) {
    final prodFactors = <Expr>[
      ...constFactors,
      for (var j = 0; j < varFactors.length; j++)
        if (j == i)
          _differentiate(varFactors[j], variable, assumptions)
        else
          varFactors[j],
    ];
    sumTerms.add(Mul.of(prodFactors));
  }
  return Add.of(sumTerms);
}

Expr _differentiatePow(
  Expr expr,
  Expr base,
  Expr exponent,
  String variable, [
  Assumptions assumptions = Assumptions.none,
]) {
  if (base == Constant.e) {
    return expr * _differentiate(exponent, variable, assumptions);
  }
  if (!exponent.dependsOn(variable)) {
    return exponent *
        Pow.of(base, exponent - IntegerNumber.one) *
        _differentiate(base, variable, assumptions);
  }
  if (!base.dependsOn(variable)) {
    if (base is Number && base.isZero) {
      return isPositiveExpr(exponent, assumptions: assumptions)
          ? IntegerNumber.zero
          : Derivative(expr, variable);
    }
    return expr * Fn.ln(base) * _differentiate(exponent, variable, assumptions);
  }
  return expr *
      (_differentiate(exponent, variable, assumptions) * Fn.ln(base) +
          (exponent * _differentiate(base, variable, assumptions)) / base);
}
