import '../algebra/expand.dart';
import '../algebra/simplify.dart';
import '../algebra/term_accumulator.dart';
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
    var current = simplify(assumptions: assumptions);
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
  Atan2(left: final y, right: final x) =>
    (x * _differentiate(y, variable) - y * _differentiate(x, variable)) /
        (Pow(x, IntegerNumber.two) + Pow(y, IntegerNumber.two)),
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
  Gamma(expr: final inner) => Mul([
    Gamma(inner),
    Digamma(inner),
    _differentiate(inner, variable),
  ]),
  Digamma(expr: final inner) => Mul([
    Polygamma(IntegerNumber.one, inner),
    _differentiate(inner, variable),
  ]),
  Polygamma(:final left, :final right) when !left.dependsOn(variable) => Mul([
    Polygamma(left + IntegerNumber.one, right),
    _differentiate(right, variable),
  ]),
  Beta(:final left, :final right) => Mul([
    Beta(left, right),
    Add([
      Mul([
        _differentiate(left, variable),
        Add([Digamma(left), -Digamma(left + right)]),
      ]),
      Mul([
        _differentiate(right, variable),
        Add([Digamma(right), -Digamma(left + right)]),
      ]),
    ]),
  ]),
  Factorial(expr: final inner) => Mul([
    Factorial(inner),
    Digamma(inner + IntegerNumber.one),
    _differentiate(inner, variable),
  ]),
  BesselJ(:final left, :final right) when !left.dependsOn(variable) =>
    left == IntegerNumber.zero
        ? Mul([
            IntegerNumber.negativeOne,
            BesselJ(IntegerNumber.one, right),
            _differentiate(right, variable),
          ])
        : Mul([
            FractionNumber.half,
            Add([
              BesselJ(left - IntegerNumber.one, right),
              -BesselJ(left + IntegerNumber.one, right),
            ]),
            _differentiate(right, variable),
          ]),
  BesselY(:final left, :final right) when !left.dependsOn(variable) =>
    left == IntegerNumber.zero
        ? Mul([
            IntegerNumber.negativeOne,
            BesselY(IntegerNumber.one, right),
            _differentiate(right, variable),
          ])
        : Mul([
            FractionNumber.half,
            Add([
              BesselY(left - IntegerNumber.one, right),
              -BesselY(left + IntegerNumber.one, right),
            ]),
            _differentiate(right, variable),
          ]),
  BesselI(:final left, :final right) when !left.dependsOn(variable) =>
    left == IntegerNumber.zero
        ? Mul([
            BesselI(IntegerNumber.one, right),
            _differentiate(right, variable),
          ])
        : Mul([
            FractionNumber.half,
            Add([
              BesselI(left - IntegerNumber.one, right),
              BesselI(left + IntegerNumber.one, right),
            ]),
            _differentiate(right, variable),
          ]),
  BesselK(:final left, :final right) when !left.dependsOn(variable) =>
    left == IntegerNumber.zero
        ? Mul([
            IntegerNumber.negativeOne,
            BesselK(IntegerNumber.one, right),
            _differentiate(right, variable),
          ])
        : Mul([
            FractionNumber.negativeHalf,
            Add([
              BesselK(left - IntegerNumber.one, right),
              BesselK(left + IntegerNumber.one, right),
            ]),
            _differentiate(right, variable),
          ]),
  EllipticK(expr: final inner) => Mul([
    (EllipticE(inner) -
            (IntegerNumber.one - Pow(inner, IntegerNumber.two)) *
                EllipticK(inner)) /
        (inner * (IntegerNumber.one - Pow(inner, IntegerNumber.two))),
    _differentiate(inner, variable),
  ]),
  EllipticE(expr: final inner) => Mul([
    (EllipticE(inner) - EllipticK(inner)) / inner,
    _differentiate(inner, variable),
  ]),
  Erfi(expr: final inner) => Mul([
    IntegerNumber.two / Pow(Constant.pi, FractionNumber.half),
    Pow(Constant.e, Pow(inner, IntegerNumber.two)),
    _differentiate(inner, variable),
  ]),
  FresnelS(expr: final inner) => Mul([
    Sin(Constant.pi * Pow(inner, IntegerNumber.two) / IntegerNumber.two),
    _differentiate(inner, variable),
  ]),
  FresnelC(expr: final inner) => Mul([
    Cos(Constant.pi * Pow(inner, IntegerNumber.two) / IntegerNumber.two),
    _differentiate(inner, variable),
  ]),
  ExpIntegralEi(expr: final inner) => Mul([
    Pow(Constant.e, inner) / inner,
    _differentiate(inner, variable),
  ]),
  LogIntegralLi(expr: final inner) =>
    _differentiate(inner, variable) / Ln(inner),
  SinIntegralSi(expr: final inner) => Mul([
    Sin(inner) / inner,
    _differentiate(inner, variable),
  ]),
  CosIntegralCi(expr: final inner) => Mul([
    Cos(inner) / inner,
    _differentiate(inner, variable),
  ]),
  SinhIntegralShi(expr: final inner) => Mul([
    Sinh(inner) / inner,
    _differentiate(inner, variable),
  ]),
  CoshIntegralChi(expr: final inner) => Mul([
    Cosh(inner) / inner,
    _differentiate(inner, variable),
  ]),
  UpperGamma(:final left, :final right) when !left.dependsOn(variable) => Mul([
    IntegerNumber.negativeOne,
    Pow(right, left - IntegerNumber.one),
    Pow(Constant.e, -right),
    _differentiate(right, variable),
  ]),
  LowerGamma(:final left, :final right) when !left.dependsOn(variable) => Mul([
    Pow(right, left - IntegerNumber.one),
    Pow(Constant.e, -right),
    _differentiate(right, variable),
  ]),
  Polylog(:final left, :final right) when !left.dependsOn(variable) =>
    left == IntegerNumber.one
        ? _differentiate(right, variable) / (IntegerNumber.one - right)
        : Mul([
                Polylog(left - IntegerNumber.one, right),
                _differentiate(right, variable),
              ]) /
              right,
  EllipticF(:final left, :final right) => () {
    final delta =
        IntegerNumber.one -
        Pow(right, IntegerNumber.two) * Pow(Sin(left), IntegerNumber.two);
    final terms = <Expr>[];
    if (left.dependsOn(variable)) {
      terms.add(
        _differentiate(left, variable) *
            Pow(delta, FractionNumber.negativeHalf),
      );
    }
    if (right.dependsOn(variable)) {
      final oneMinusK2 = IntegerNumber.one - Pow(right, IntegerNumber.two);
      final dFdk =
          (EllipticEIncomplete(left, right) -
              oneMinusK2 * EllipticF(left, right) -
              Pow(right, IntegerNumber.two) *
                  Sin(left) *
                  Cos(left) *
                  Pow(delta, FractionNumber.negativeHalf)) /
          (right * oneMinusK2);
      terms.add(dFdk * _differentiate(right, variable));
    }
    return switch (terms) {
      [] => IntegerNumber.zero,
      [final single] => single,
      _ => Add(terms),
    };
  }(),
  EllipticEIncomplete(:final left, :final right) => () {
    final terms = <Expr>[];
    if (left.dependsOn(variable)) {
      final delta =
          IntegerNumber.one -
          Pow(right, IntegerNumber.two) * Pow(Sin(left), IntegerNumber.two);
      terms.add(
        Pow(delta, FractionNumber.half) * _differentiate(left, variable),
      );
    }
    if (right.dependsOn(variable)) {
      final dEdk =
          (EllipticEIncomplete(left, right) - EllipticF(left, right)) / right;
      terms.add(dEdk * _differentiate(right, variable));
    }
    return switch (terms) {
      [] => IntegerNumber.zero,
      [final single] => single,
      _ => Add(terms),
    };
  }(),
  EllipticPi(:final characteristic, :final amplitude, :final modulus) => () {
    final n = characteristic;
    final phi = amplitude;
    final k = modulus;
    final terms = <Expr>[];
    final sinPhi = Sin(phi);
    final sin2Phi = Pow(sinPhi, IntegerNumber.two);
    final k2 = Pow(k, IntegerNumber.two);
    final delta = IntegerNumber.one - k2 * sin2Phi;
    final oneMinusNSin2 = IntegerNumber.one - n * sin2Phi;
    if (phi.dependsOn(variable)) {
      final dPidPhi =
          Pow(oneMinusNSin2, IntegerNumber.negativeOne) *
          Pow(delta, FractionNumber.negativeHalf);
      terms.add(dPidPhi * _differentiate(phi, variable));
    }
    if (k.dependsOn(variable)) {
      final k2Minus1 = k2 - IntegerNumber.one;
      final dPidK =
          (k / (n - k2)) *
          (EllipticEIncomplete(phi, k) / k2Minus1 +
              EllipticPi(n, phi, k) -
              (k2 * sinPhi * Cos(phi)) /
                  (k2Minus1 * Pow(delta, FractionNumber.half)));
      terms.add(dPidK * _differentiate(k, variable));
    }
    if (n.dependsOn(variable)) {
      final dPidN =
          (EllipticEIncomplete(phi, k) +
              ((k2 - n) / n) * EllipticF(phi, k) +
              ((Pow(n, IntegerNumber.two) - k2) / n) * EllipticPi(n, phi, k) -
              (n * sinPhi * Cos(phi) * Pow(delta, FractionNumber.half)) /
                  oneMinusNSin2) /
          (IntegerNumber.two * (k2 - n) * (n - IntegerNumber.one));
      terms.add(dPidN * _differentiate(n, variable));
    }
    return switch (terms) {
      [] => IntegerNumber.zero,
      [final single] => single,
      _ => Add(terms),
    };
  }(),
  Binomial(:final left, :final right) => () {
    if (right case IntegerNumber(asInt: final k?) when k >= 0 && k <= 20) {
      if (k == 0) return IntegerNumber.zero;
      final factors = <Expr>[
        for (var j = 0; j < k; j++)
          (j == 0 ? left : left - IntegerNumber.of(j)) /
              IntegerNumber.of(j + 1),
      ];
      final expanded = factors.length == 1 ? factors.first : Mul(factors);
      return _differentiate(expanded, variable);
    }
    final dn = _differentiate(left, variable);
    final dk = _differentiate(right, variable);
    final psiNK1 = Polygamma(
      IntegerNumber.zero,
      left - right + IntegerNumber.one,
    );
    final terms = <Expr>[];
    if (dn != IntegerNumber.zero) {
      final psiN1 = Polygamma(IntegerNumber.zero, left + IntegerNumber.one);
      terms.add((psiN1 - psiNK1) * dn);
    }
    if (dk != IntegerNumber.zero) {
      final psiK1 = Polygamma(IntegerNumber.zero, right + IntegerNumber.one);
      terms.add(-(psiK1 - psiNK1) * dk);
    }
    if (terms.isEmpty) return IntegerNumber.zero;
    final sum = terms.length == 1 ? terms.first : Add(terms);
    return expr * sum;
  }(),
  Zeta(:final expr, :final shift)
      when shift != null && !expr.dependsOn(variable) =>
    Mul([
      IntegerNumber.negativeOne,
      expr,
      Zeta(expr + IntegerNumber.one, shift: shift),
      _differentiate(shift, variable),
    ]),
  ExpIntegralE(:final left, :final right) when !left.dependsOn(variable) => Mul(
    [
      IntegerNumber.negativeOne,
      ExpIntegralE(left - IntegerNumber.one, right),
      _differentiate(right, variable),
    ],
  ),
  Hypergeometric(:final upper, :final lower, :final argument)
      when upper.every((e) => !e.dependsOn(variable)) &&
          lower.every((e) => !e.dependsOn(variable)) =>
    () {
      final numProd = upper.isEmpty
          ? IntegerNumber.one
          : (upper.length == 1 ? upper.first : Mul(upper));
      final denProd = lower.isEmpty
          ? IntegerNumber.one
          : (lower.length == 1 ? lower.first : Mul(lower));
      return Mul([
        numProd / denProd,
        Hypergeometric(
          [for (final u in upper) u + IntegerNumber.one],
          [for (final l in lower) l + IntegerNumber.one],
          argument,
        ),
        _differentiate(argument, variable),
      ]);
    }(),
  Min(args: [final a, final b]) => () {
    final da = _differentiate(a, variable);
    final db = _differentiate(b, variable);
    return FractionNumber.half * ((da + db) - Sign(a - b) * (da - db));
  }(),
  Max(args: [final a, final b]) => () {
    final da = _differentiate(a, variable);
    final db = _differentiate(b, variable);
    return FractionNumber.half * ((da + db) + Sign(a - b) * (da - db));
  }(),
  UpperGamma() ||
  LowerGamma() ||
  Polylog() ||
  Polygamma() ||
  BesselJ() ||
  BesselY() ||
  BesselI() ||
  BesselK() ||
  Zeta() ||
  ExpIntegralE() ||
  Hypergeometric() ||
  Min() ||
  Max() ||
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
        Mul([
          Pow(inner - IntegerNumber.one, FractionNumber.half),
          Pow(inner + IntegerNumber.one, FractionNumber.half),
        ]),
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
  Product(
    expr: final inner,
    variable: final pVar,
    :final lower,
    :final upper,
  ) =>
    pVar != variable && !lower.dependsOn(variable) && !upper.dependsOn(variable)
        ? Mul([
            expr,
            Sum(_differentiate(inner, variable) / inner, pVar, lower, upper),
          ])
        : Derivative(expr, variable),
  Limit() || VariableFunction() => Derivative(expr, variable),
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
    [] => IntegerNumber.zero,
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

  if (denFactors.length == 1 && numFactors.isNotEmpty) {
    final left = switch (numFactors) {
      [final single] => single,
      _ => Mul(numFactors),
    };
    final right = denFactors.first;
    final degLeft = polynomialDegree(left, variable);
    return switch (right) {
      Pow(:final base, :final exponent) when !exponent.dependsOn(variable) =>
        () {
          final degBase = polynomialDegree(base, variable);
          final num =
              _differentiate(left, variable) * base -
              exponent * left * _differentiate(base, variable);
          final shouldExpand =
              (degLeft != null &&
                  degLeft <= 4 &&
                  degBase != null &&
                  degBase <= 4) ||
              (exponent is IntegerNumber &&
                  (exponent.asInt == null || exponent.asInt!.abs() > 16));
          return (shouldExpand ? num.expand() : num) /
              Pow(base, exponent + IntegerNumber.one);
        }(),
      _ => () {
        final degRight = polynomialDegree(right, variable);
        final num =
            _differentiate(left, variable) * right -
            left * _differentiate(right, variable);
        final shouldExpand =
            degLeft != null &&
            degLeft <= 4 &&
            degRight != null &&
            degRight <= 4;
        return (shouldExpand ? num.expand() : num) /
            Pow(right, IntegerNumber.two);
      }(),
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
