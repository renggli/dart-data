import '../algebra/approximate.dart';
import '../algebra/expand.dart';
import '../algebra/simplify.dart';
import '../algebra/term_accumulator.dart';
import '../ast.dart';
import 'differentiation.dart';
import 'limit.dart';
import 'linear_form.dart';

/// Symbolic analytical integration extension on [Expr].
extension IntegrationExtension on Expr {
  /// Computes the symbolic anti-derivative $\int f(x) dx$ with respect to
  /// [variable], or the definite integral $\int_a^b f(x) dx$ when [from] and
  /// [to] are specified.
  ///
  /// Conceptually, an integral calculates the total accumulated area under the
  /// curve between two coordinates (or recovers the primitive function from its
  /// derivative). Formally, this implements symbolic integration rules (power
  /// rule, logarithmic, trigonometric, exponential, integration by parts, and
  /// substitution). Returns an unevaluated [Integral] node when no elementary
  /// closed-form anti-derivative exists.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final area = (x * x).integrate('x', from: 0, to: 3);
  /// // area: IntegerNumber(9) because \int_0^3 x^2 dx = [x^3 / 3]_0^3 = 9
  /// ```
  Expr integrate(String variable, {num? from, num? to}) =>
      _symbolicIntegrate(this, variable, from: from, to: to);
}

Expr _symbolicIntegrate(Expr function, String variable, {num? from, num? to}) {
  if ((from == null) != (to == null)) {
    throw ArgumentError(
      'Both "from" and "to" must be provided for definite integration.',
    );
  }
  if (from != null && to != null) {
    if (from == to) {
      return IntegerNumber.zero;
    }
    final antiDeriv = _antiDerivative(function, variable).simplify();
    if (_hasUnevaluatedIntegral(antiDeriv)) {
      return Integral(
        function.simplify(),
        variable,
        lower: _numToExpr(from),
        upper: _numToExpr(to),
        isSimplified: true,
      );
    }
    try {
      final upper = to.isInfinite
          ? antiDeriv.limit(
              variable,
              to > 0 ? Constant.infinity : -Constant.infinity,
            )
          : antiDeriv.substitute(variable, _numToExpr(to));
      final lower = from.isInfinite
          ? antiDeriv.limit(
              variable,
              from > 0 ? Constant.infinity : -Constant.infinity,
            )
          : antiDeriv.substitute(variable, _numToExpr(from));
      return (upper - lower).simplify();
    } on Object {
      return Integral(
        function.simplify(),
        variable,
        lower: _numToExpr(from),
        upper: _numToExpr(to),
        isSimplified: true,
      );
    }
  }

  return _antiDerivative(function, variable).simplify();
}

bool _hasUnevaluatedIntegral(Expr expr) => expr.anyNode((e) => e is Integral);

Expr _numToExpr(num n) {
  if (n is int) return IntegerNumber.of(n);
  final d = n.toDouble();
  if (d.isNaN) return Constant.undefined;
  if (d == double.infinity) return Constant.infinity;
  if (d == double.negativeInfinity) return -Constant.infinity;
  if (d == d.truncateToDouble() && d.abs() <= Integer.maxSafe.toDouble()) {
    return IntegerNumber.of(d.toInt());
  }
  final real = RealNumber(d);
  final rat = real.rationalize(maxDenominator: 64);
  if (rat is RationalNumber && (d - rat.toDouble()).abs() < 1e-12) {
    return rat;
  }
  return real;
}

Expr _antiDerivative(Expr expr, String variable) {
  final node = expr.simplify();

  if (!node.dependsOn(variable)) {
    if (node is Number && node.isZero) {
      return IntegerNumber.zero;
    }
    return (node * Variable(variable)).simplify();
  }

  return switch (node) {
    Variable(:final name) when name == variable =>
      (Pow(node, IntegerNumber.two) / IntegerNumber.two).simplify(),
    Add(:final terms) => Add([
      for (final term in terms) _antiDerivative(term, variable),
    ]).simplify(),
    Sin(expr: final inner) =>
      _antiDerivSin(inner, variable) ?? _unsupported(node, variable),
    Cos(expr: final inner) =>
      _antiDerivCos(inner, variable) ?? _unsupported(node, variable),
    Tan(expr: final inner) =>
      _antiDerivTan(inner, variable) ?? _unsupported(node, variable),
    Asin(expr: final inner) =>
      _antiDerivAsin(inner, variable) ?? _unsupported(node, variable),
    Acos(expr: final inner) =>
      _antiDerivAcos(inner, variable) ?? _unsupported(node, variable),
    Atan(expr: final inner) =>
      _antiDerivAtan(inner, variable) ?? _unsupported(node, variable),
    Sinh(expr: final inner) =>
      _antiDerivSinh(inner, variable) ?? _unsupported(node, variable),
    Cosh(expr: final inner) =>
      _antiDerivCosh(inner, variable) ?? _unsupported(node, variable),
    Tanh(expr: final inner) =>
      _antiDerivTanh(inner, variable) ?? _unsupported(node, variable),
    Abs(expr: final inner) =>
      _antiDerivAbs(inner, variable) ?? _unsupported(node, variable),
    Ln(expr: final inner) =>
      _antiDerivLn(inner, variable) ?? _unsupported(node, variable),
    LambertW(expr: final inner, :final branch) =>
      _antiDerivLambertW(inner, branch, variable) ??
          _unsupported(node, variable),
    Erf(expr: final inner) =>
      _antiDerivErf(inner, variable) ?? _unsupported(node, variable),
    Erfc(expr: final inner) =>
      _antiDerivErfc(inner, variable) ?? _unsupported(node, variable),
    Asinh(expr: final inner) =>
      _antiDerivAsinh(inner, variable) ?? _unsupported(node, variable),
    Acosh(expr: final inner) =>
      _antiDerivAcosh(inner, variable) ?? _unsupported(node, variable),
    Atanh(expr: final inner) =>
      _antiDerivAtanh(inner, variable) ?? _unsupported(node, variable),
    Piecewise() => _antiDerivPiecewise(node, variable),
    Pow(:final base, :final exponent) => _antiDerivPow(
      base,
      exponent,
      node,
      variable,
    ),
    Mul() => _antiDerivMul(node, variable),
    _ => _unsupported(node, variable),
  };
}

Expr _unsupported(Expr expr, String variable) =>
    Integral(expr, variable, isSimplified: true);

Expr? _antiDerivSin(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) => (-Cos(inner) / a).simplify(),
      null => null,
    };

Expr? _antiDerivCos(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) => (Sin(inner) / a).simplify(),
      null => null,
    };

Expr? _antiDerivTan(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) => (-Ln(Cos(inner)) / a).simplify(),
      null => null,
    };

Expr? _antiDerivAsin(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) =>
        ((inner * Asin(inner) +
                    Pow(
                      IntegerNumber.one - Pow(inner, IntegerNumber.two),
                      FractionNumber.half,
                    )) /
                a)
            .simplify(),
      null => null,
    };

Expr? _antiDerivAcos(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) =>
        ((inner * Acos(inner) -
                    Pow(
                      IntegerNumber.one - Pow(inner, IntegerNumber.two),
                      FractionNumber.half,
                    )) /
                a)
            .simplify(),
      null => null,
    };

Expr? _antiDerivAtan(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) =>
        ((inner * Atan(inner) -
                    FractionNumber.half *
                        Ln(IntegerNumber.one + Pow(inner, IntegerNumber.two))) /
                a)
            .simplify(),
      null => null,
    };

Expr? _antiDerivSinh(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) => (Cosh(inner) / a).simplify(),
      null => null,
    };

Expr? _antiDerivCosh(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) => (Sinh(inner) / a).simplify(),
      null => null,
    };

Expr? _antiDerivTanh(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) => (Ln(Cosh(inner)) / a).simplify(),
      null => null,
    };

Expr? _antiDerivAbs(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) =>
        ((inner * Abs(inner)) / (IntegerNumber.two * a)).simplify(),
      null => null,
    };

Expr? _antiDerivLn(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) => ((inner * Ln(inner) - inner) / a).simplify(),
      null => null,
    };

Expr? _antiDerivLambertW(Expr inner, int branch, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) =>
        ((inner * (LambertW(inner, branch: branch) - IntegerNumber.one) +
                    Pow(Constant.e, LambertW(inner, branch: branch))) /
                a)
            .simplify(),
      null => null,
    };

Expr? _antiDerivErf(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) =>
        ((inner * Erf(inner) +
                    Pow(Constant.e, -Pow(inner, IntegerNumber.two)) /
                        Pow(Constant.pi, FractionNumber.half)) /
                a)
            .simplify(),
      null => null,
    };

Expr? _antiDerivErfc(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) =>
        ((inner * Erfc(inner) -
                    Pow(Constant.e, -Pow(inner, IntegerNumber.two)) /
                        Pow(Constant.pi, FractionNumber.half)) /
                a)
            .simplify(),
      null => null,
    };

Expr? _antiDerivAsinh(Expr inner, String variable) =>
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

Expr? _antiDerivAcosh(Expr inner, String variable) =>
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

Expr? _antiDerivAtanh(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) =>
        ((inner * Atanh(inner) +
                    FractionNumber.half *
                        Ln(IntegerNumber.one - Pow(inner, IntegerNumber.two))) /
                a)
            .simplify(),
      null => null,
    };

Expr _antiDerivPiecewise(Piecewise expr, String variable) {
  final m = expr.branches.length;
  final rawG = <Expr>[
    for (var i = 0; i < m; i++) _antiDerivative(expr.branches[i].$2, variable),
  ];
  final rawOth = expr.otherwise != null
      ? _antiDerivative(expr.otherwise!, variable)
      : null;

  final constants = <Expr>[IntegerNumber.zero];
  for (var k = 0; k < m - 1; k++) {
    final pt = _extractBoundaryPoint(expr.branches[k].$1, variable);
    if (pt != null) {
      final vLeft = (rawG[k].substitute(variable, pt) + constants[k])
          .simplify();
      final vRight = rawG[k + 1].substitute(variable, pt).simplify();
      constants.add((vLeft - vRight).simplify());
    } else {
      constants.add(IntegerNumber.zero);
    }
  }

  Expr? constOth;
  if (rawOth != null && m > 0) {
    final pt = _extractBoundaryPoint(expr.branches[m - 1].$1, variable);
    if (pt != null) {
      final vLeft = (rawG[m - 1].substitute(variable, pt) + constants[m - 1])
          .simplify();
      final vRight = rawOth.substitute(variable, pt).simplify();
      constOth = (vLeft - vRight).simplify();
    } else {
      constOth = IntegerNumber.zero;
    }
  }

  final newBranches = <(RelationalExpr, Expr)>[
    for (var i = 0; i < m; i++)
      (expr.branches[i].$1, (rawG[i] + constants[i]).simplify()),
  ];
  final newOtherwise = rawOth != null
      ? (rawOth + (constOth ?? IntegerNumber.zero)).simplify()
      : null;
  return Piecewise(newBranches, otherwise: newOtherwise);
}

Expr? _extractBoundaryPoint(Expr cond, String variable) => switch (cond) {
  LessThan(left: Variable(:final name), right: final bound) ||
  LessEqual(left: Variable(:final name), right: final bound) ||
  GreaterThan(left: final bound, right: Variable(:final name)) ||
  GreaterEqual(
    left: final bound,
    right: Variable(:final name),
  ) when name == variable && !bound.dependsOn(variable) => bound,
  _ => null,
};

bool _isValidExponentialBase(Expr base) => switch (base) {
  RationalNumber(:final isNegative, :final isZero, :final isOne) =>
    !isNegative && !isZero && !isOne,
  RealNumber(:final value) => value > 0 && value != 1.0,
  _ => true,
};

Expr _antiDerivPow(Expr base, Expr exponent, Expr original, String variable) {
  // Form: (ax + b)^n
  if (!exponent.dependsOn(variable)) {
    if (base.matchLinear(variable) case (:final a, b: _)) {
      if (exponent is IntegerNumber && exponent.isNegativeOne) {
        return (Ln(base) / a).simplify();
      }
      final nPlus1 = (exponent + IntegerNumber.one).simplify();
      final denom = (a * nPlus1).simplify();
      final numer = Pow(base, nPlus1).simplify();
      return (numer / denom).simplify();
    }
    if (exponent is IntegerNumber && exponent.value > Integer.one) {
      final expanded = original.expand().simplify();
      if (expanded != original) {
        return _antiDerivative(expanded, variable);
      }
    }
    // Check if this is 1 / g(x) represented as g(x)^(-n)
    final isNegExp = switch (exponent) {
      RationalNumber(:final isNegative) => isNegative,
      RealNumber(:final value) => value < 0,
      _ => false,
    };
    if (isNegExp) {
      final posExp = (-exponent).simplify();
      final den = posExp == IntegerNumber.one ? base : Pow(base, posExp);
      final divRes = _tryAntiDerivDiv(IntegerNumber.one, den, variable);
      if (divRes != null) return divRes;
    }
  }

  // Form: c^(ax + b) or e^(ax + b)
  if (!base.dependsOn(variable)) {
    if (exponent.matchLinear(variable) case (:final a, b: _)) {
      if (base == Constant.e) {
        return (original / a).simplify();
      }
      if (_isValidExponentialBase(base)) {
        final denom = (a * Ln(base)).simplify();
        return (original / denom).simplify();
      }
    }
  }

  return _unsupported(original, variable);
}

Expr? _tryAntiDerivDiv(Expr left, Expr right, String variable) {
  // int (c / g(x)) dx
  if (!left.dependsOn(variable)) {
    // int c / (ax + b) dx = (c ln(ax + b)) / a
    if (right.matchLinear(variable) case (:final a, b: _)) {
      final num = (left * Ln(right)).simplify();
      return (num / a).simplify();
    }

    // int c / (ax + b)^n dx = int c * (ax + b)^(-n) dx
    if (right case Pow(:final base, :final exponent)
        when !exponent.dependsOn(variable) &&
            base.matchLinear(variable) != null) {
      final negExp = (-exponent).simplify();
      final powExpr = Pow(base, negExp);
      return _antiDerivPow(base, negExp, powExpr, variable).scale(left);
    }

    // int c / cosh(ax + b) dx = (c / a) * atan(sinh(ax + b))
    if (right case Cosh(expr: final inner)) {
      if (inner.matchLinear(variable) case (:final a, b: _)) {
        return ((left * Atan(Sinh(inner))) / a).simplify();
      }
    }

    // int c / (d + exp(ax + b)) dx = (c / d) * (x - (1 / a) * ln(d + exp(ax + b)))
    if (right
        case Add(terms: [final rL, Pow(base: Constant.e, :final exponent)])
        when !rL.dependsOn(variable)) {
      if (exponent.matchLinear(variable) case (:final a, b: _)) {
        final term = (Variable(variable) - (Ln(right) / a)).simplify();
        return ((left / rL) * term).simplify();
      }
    }
  }

  // int u'(x) / (a + b * u(x)^2) dx = (1 / sqrt(a * b)) * arctan(sqrt(b / a) * u(x))
  if (right case Add(terms: [final rL, final rR])) {
    if (rL case RationalNumber(isOne: true) || RealNumber(value: 1.0)) {
      if (_extractSquareBase(rR) case final u? when u.dependsOn(variable)) {
        final uPrime = u.derivative(variable).simplify();
        if (left.matchScalarMultiple(uPrime, variable) case final k?) {
          return Atan(u).scale(k);
        }
      }
    }
    // General positive constant a + sqTerm
    if (!rL.dependsOn(variable) &&
        rR.dependsOn(variable) &&
        _isPositiveConstant(rL)) {
      if (_extractScaledSquareBase((rR / rL).simplify(), variable) case final w?
          when w.dependsOn(variable)) {
        final wPrime = w.derivative(variable).simplify();
        if (left.matchScalarMultiple(wPrime, variable) case final k?) {
          return Atan(w).scale((k / rL).simplify());
        }
      }
    }
  }

  // int u'(x) / sqrt(1 - u(x)^2) dx = asin(u(x))
  if (right
      case Pow(
        base: Add(
          terms: [
            RationalNumber(isOne: true) || RealNumber(value: 1.0),
            final t1,
          ],
        ),
        :final exponent,
      )
      when exponent == FractionNumber.half ||
          (exponent is RealNumber && exponent.value == 0.5)) {
    final negTerm = (-t1).simplify();
    if (_extractSquareBase(negTerm) case final u? when u.dependsOn(variable)) {
      final uPrime = u.derivative(variable).simplify();
      if (left.matchScalarMultiple(uPrime, variable) case final k?) {
        return Asin(u).scale(k);
      }
    }
  }

  // Chain rule quotient: int u'(x) / u(x) dx = ln(u(x))
  if (right.dependsOn(variable)) {
    final uPrime = right.derivative(variable).simplify();
    final k = left.matchScalarMultiple(uPrime, variable);
    if (k != null) {
      return Ln(right).scale(k);
    }
  }

  // Univariate polynomial long division when deg(left) >= deg(right) >= 1
  if (left.dependsOn(variable) && right.dependsOn(variable)) {
    if (_tryPolynomialLongDivision(left, right, variable) case (
      final quotient,
      final remainder,
    )) {
      final qInt = _antiDerivative(quotient, variable);
      if (remainder is Number && remainder.isZero) {
        return qInt;
      }
      final rInt = _antiDerivative((remainder / right).simplify(), variable);
      return (qInt + rInt).simplify();
    }
  }

  return null;
}

Expr _antiDerivMul(Mul original, String variable) {
  // 1. Check if this product represents a quotient f(x) / g(x) where g depends on variable
  final (numExpr, denExpr) = splitNumeratorDenominator(original);
  if (denExpr != IntegerNumber.one && denExpr.dependsOn(variable)) {
    final divRes = _tryAntiDerivDiv(numExpr, denExpr, variable);
    if (divRes != null) return divRes;
  }

  // 2. Separate constant factors from variable-dependent factors
  final constFactors = <Expr>[];
  final varFactors = <Expr>[];
  for (final f in original.factors) {
    if (f.dependsOn(variable)) {
      varFactors.add(f);
    } else {
      constFactors.add(f);
    }
  }

  if (constFactors.isNotEmpty) {
    final constPart = constFactors.length == 1
        ? constFactors.first
        : Mul(constFactors).simplify();
    final varPart = varFactors.length == 1
        ? varFactors.first
        : Mul(varFactors).simplify();
    return _antiDerivative(varPart, variable).scale(constPart);
  }

  // 3. Chain-rule substitution across any factor as candidate and remaining product as factor:
  for (var i = 0; i < varFactors.length; i++) {
    final candidate = varFactors[i];
    final others = <Expr>[
      for (var j = 0; j < varFactors.length; j++)
        if (i != j) varFactors[j],
    ];
    final otherExpr = others.length == 1
        ? others.first
        : Mul(others).simplify();
    if (_tryChainRule(candidate, otherExpr, variable) case final subRes?) {
      return subRes;
    }
  }

  // 4. Integration by parts (try pairing one factor with the rest):
  if (varFactors case [final left, final right]) {
    if (_tryIntegrationByParts(left, right, variable) case final ibpLR?) {
      return ibpLR;
    }
    if (_tryIntegrationByParts(right, left, variable) case final ibpRL?) {
      return ibpRL;
    }
  } else {
    for (var i = 0; i < varFactors.length; i++) {
      final candidate = varFactors[i];
      final others = <Expr>[
        for (var j = 0; j < varFactors.length; j++)
          if (i != j) varFactors[j],
      ];
      final otherExpr = Mul(others).simplify();
      if (_tryIntegrationByParts(candidate, otherExpr, variable)
          case final ibp1?) {
        return ibp1;
      }
      if (_tryIntegrationByParts(otherExpr, candidate, variable)
          case final ibp2?) {
        return ibp2;
      }
    }
  }

  // 5. Distributive expansion across additions:
  for (var i = 0; i < varFactors.length; i++) {
    if (varFactors[i] case Add(:final terms)) {
      final others = <Expr>[
        for (var j = 0; j < varFactors.length; j++)
          if (i != j) varFactors[j],
      ];
      final otherExpr = others.length == 1
          ? others.first
          : Mul(others).simplify();
      return Add([
        for (final t in terms)
          _antiDerivative((t * otherExpr).simplify(), variable),
      ]).simplify();
    }
  }

  // 6. Full polynomial expansion fallback (e.g. factored polynomials like (x-1)*(x-2)*(x+2)):
  if (_univariatePolyDegree(original, variable) != null) {
    final expanded = original.expand().simplify();
    if (expanded != original) {
      return _antiDerivative(expanded, variable);
    }
  }

  return _unsupported(original, variable);
}

Expr? _tryChainRule(Expr candidate, Expr factor, String variable) =>
    switch (candidate) {
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
        _tryChainRulePower(base, exponent, factor, variable),
      Pow(:final base, :final exponent)
          when !base.dependsOn(variable) && exponent.dependsOn(variable) =>
        _tryChainRuleExponential(candidate, base, exponent, factor, variable),
      _ => null,
    };

Expr? _scaleMatch(Expr factor, Expr deriv, Expr target, String variable) {
  final k = factor.matchScalarMultiple(deriv, variable);
  return k != null ? target.scale(k) : null;
}

Expr? _tryChainRulePower(
  Expr base,
  Expr exponent,
  Expr factor,
  String variable,
) {
  final uPrime = base.derivative(variable).simplify();
  final k = factor.matchScalarMultiple(uPrime, variable);
  if (k != null) {
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
  if (_isValidExponentialBase(base)) {
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

Expr? _tryIntegrationByParts(Expr pExpr, Expr vExpr, String variable) {
  // Cyclic IBP: exp(ax + b) * sin(cx + d) or exp(ax + b) * cos(cx + d)
  if (pExpr case Pow(base: Constant.e, exponent: final expInner)) {
    if (expInner.matchLinear(variable) case (a: final a, b: _)) {
      if (vExpr case Sin(expr: final trigInner)) {
        if (trigInner.matchLinear(variable) case (a: final c, b: _)) {
          final denom = (a * a + c * c).simplify();
          final numer = (pExpr * (a * Sin(trigInner) - c * Cos(trigInner)))
              .simplify();
          return (numer / denom).simplify();
        }
      }
      if (vExpr case Cos(expr: final trigInner)) {
        if (trigInner.matchLinear(variable) case (a: final c, b: _)) {
          final denom = (a * a + c * c).simplify();
          final numer = (pExpr * (a * Cos(trigInner) + c * Sin(trigInner)))
              .simplify();
          return (numer / denom).simplify();
        }
      }
    }
  }

  final linP = pExpr.matchLinear(variable);
  if (linP != null) {
    final p = linP.a;
    return switch (vExpr) {
      Ln(:final expr) => switch (expr.matchLinear(variable)) {
        (:final a, :final b) => _ibpLogarithm(pExpr, vExpr, expr, linP, a, b),
        null => null,
      },
      Pow(:final base, :final exponent) when base == Constant.e =>
        switch (exponent.matchLinear(variable)) {
          (:final a, b: _) => _ibpExponential(pExpr, vExpr, p, a),
          null => null,
        },
      Cos(:final expr) => switch (expr.matchLinear(variable)) {
        (:final a, b: _) => _ibpCosine(pExpr, vExpr, expr, p, a),
        null => null,
      },
      Sin(:final expr) => switch (expr.matchLinear(variable)) {
        (:final a, b: _) => _ibpSine(pExpr, vExpr, expr, p, a),
        null => null,
      },
      Sinh(:final expr) => switch (expr.matchLinear(variable)) {
        (:final a, b: _) => _ibpSinh(pExpr, vExpr, expr, p, a),
        null => null,
      },
      Cosh(:final expr) => switch (expr.matchLinear(variable)) {
        (:final a, b: _) => _ibpCosh(pExpr, vExpr, expr, p, a),
        null => null,
      },
      Pow(:final base, :final exponent) when !base.dependsOn(variable) =>
        switch (exponent.matchLinear(variable)) {
          (:final a, b: _) => _ibpGeneralExponential(pExpr, vExpr, base, p, a),
          null => null,
        },
      _ => null,
    };
  }

  // Higher-degree polynomial P(x) * vExpr (e.g. x^n * exp(ax+b), x^n * sin(ax+b)):
  final degP = _univariatePolyDegree(pExpr, variable);
  if (degP != null && degP >= 2 && degP <= 10) {
    final isIntegrableV = switch (vExpr) {
      Pow(:final base, :final exponent) when base == Constant.e =>
        exponent.matchLinear(variable) != null,
      Sin(:final expr) ||
      Cos(:final expr) ||
      Sinh(:final expr) ||
      Cosh(:final expr) => expr.matchLinear(variable) != null,
      _ => false,
    };
    if (isIntegrableV) {
      final v = _antiDerivative(vExpr, variable);
      final pPrime = pExpr.derivative(variable);
      final remIntegral = _antiDerivative(
        (pPrime * v).expand().simplify(),
        variable,
      );
      if (!_hasUnevaluatedIntegral(v) &&
          !_hasUnevaluatedIntegral(remIntegral)) {
        return (pExpr * v - remIntegral).simplify();
      }
    }
  }

  return null;
}

Expr _ibpLogarithm(
  Expr pExpr,
  Expr vExpr,
  Expr expr,
  ({Expr a, Expr b}) linP,
  Expr c,
  Expr d,
) {
  final p = linP.a;
  final q = linP.b;
  final cSquared = (c * c).simplify();
  final aCap = (p / cSquared).simplify();
  final numB = (q * c - p * d).simplify();
  final bCap = (numB / cSquared).simplify();
  final w = expr;
  final wSquared = Pow(w, IntegerNumber.two).simplify();
  final termA1 = ((aCap * wSquared) / IntegerNumber.two).simplify();
  final termB1 = (bCap * w).simplify();
  final coeff1 = (termA1 + termB1).simplify();

  final termA2 = ((aCap * wSquared) / IntegerNumber.of(4)).simplify();
  final coeff2 = (termA2 + termB1).simplify();

  return (coeff1 * vExpr - coeff2).simplify();
}

Expr _ibpExponential(Expr pExpr, Expr vExpr, Expr p, Expr c) {
  final term1 = (pExpr / c).simplify();
  final cSquared = (c * c).simplify();
  final term2 = (p / cSquared).simplify();
  final coeff = (term1 - term2).simplify();
  return (coeff * vExpr).simplify();
}

Expr? _ibpGeneralExponential(
  Expr pExpr,
  Expr vExpr,
  Expr base,
  Expr p,
  Expr a,
) {
  if (_isValidExponentialBase(base)) {
    final cEff = (a * Ln(base)).simplify();
    final term1 = (pExpr / cEff).simplify();
    final cEffSquared = (cEff * cEff).simplify();
    final term2 = (p / cEffSquared).simplify();
    final coeff = (term1 - term2).simplify();
    return (coeff * vExpr).simplify();
  }
  return null;
}

Expr _ibpCosine(Expr pExpr, Expr vExpr, Expr expr, Expr p, Expr c) {
  final term1 = ((pExpr / c).simplify() * Sin(expr)).simplify();
  final cSquared = (c * c).simplify();
  final term2 = ((p / cSquared).simplify() * Cos(expr)).simplify();
  return (term1 + term2).simplify();
}

Expr _ibpSine(Expr pExpr, Expr vExpr, Expr expr, Expr p, Expr c) {
  final term1 = (-((pExpr / c).simplify() * Cos(expr))).simplify();
  final cSquared = (c * c).simplify();
  final term2 = ((p / cSquared).simplify() * Sin(expr)).simplify();
  return (term1 + term2).simplify();
}

Expr _ibpSinh(Expr pExpr, Expr vExpr, Expr expr, Expr p, Expr c) {
  final term1 = ((pExpr / c).simplify() * Cosh(expr)).simplify();
  final cSquared = (c * c).simplify();
  final term2 = ((p / cSquared).simplify() * Sinh(expr)).simplify();
  return (term1 - term2).simplify();
}

Expr _ibpCosh(Expr pExpr, Expr vExpr, Expr expr, Expr p, Expr c) {
  final term1 = ((pExpr / c).simplify() * Sinh(expr)).simplify();
  final cSquared = (c * c).simplify();
  final term2 = ((p / cSquared).simplify() * Cosh(expr)).simplify();
  return (term1 - term2).simplify();
}

Expr? _extractSquareBase(Expr expr) => switch (expr) {
  Pow(:final base, exponent: IntegerNumber(:final value))
      when value.isEven && value > Integer.zero =>
    value == Integer.two
        ? base
        : Pow(base, IntegerNumber(value ~/ Integer.two)),
  Pow(:final base, exponent: RealNumber(:final value))
      when value % 2.0 == 0.0 && value > 0 =>
    value == 2.0 ? base : Pow(base, IntegerNumber.of((value / 2.0).round())),
  _ => null,
};

bool _isPositiveConstant(Expr expr) {
  if (expr is RationalNumber) return !expr.isNegative && !expr.isZero;
  if (expr is RealNumber) return expr.value > 0.0;
  if (expr.freeVariables.isEmpty) {
    try {
      return expr.evaluate(const {}) > 0.0;
    } catch (_) {}
  }
  return false;
}

Expr? _extractScaledSquareBase(Expr expr, String variable) {
  final direct = _extractSquareBase(expr);
  if (direct != null) return direct;
  if (expr case Mul(:final factors)) {
    final constFactors = <Expr>[];
    final varFactors = <Expr>[];
    for (final f in factors) {
      if (f.dependsOn(variable)) {
        varFactors.add(f);
      } else {
        constFactors.add(f);
      }
    }
    if (varFactors case [final varPart] when constFactors.isNotEmpty) {
      final constPart = switch (constFactors) {
        [final single] => single,
        _ => Mul(constFactors).simplify(),
      };
      if (_isPositiveConstant(constPart)) {
        if (_extractSquareBase(varPart) case final sq?) {
          return (Pow(constPart, FractionNumber.half).simplify() * sq)
              .simplify();
        }
      }
    }
  }
  return null;
}

int? _univariatePolyDegree(Expr expr, String variable) {
  if (!expr.dependsOn(variable)) return 0;
  return switch (expr) {
    Variable(:final name) when name == variable => 1,
    Add(:final terms) => () {
      var maxD = 0;
      for (final t in terms) {
        final d = _univariatePolyDegree(t, variable);
        if (d == null) return null;
        if (d > maxD) maxD = d;
      }
      return maxD;
    }(),
    Mul(:final factors) => () {
      var sumD = 0;
      for (final f in factors) {
        final d = _univariatePolyDegree(f, variable);
        if (d == null) return null;
        sumD += d;
      }
      return sumD;
    }(),
    Pow(:final base, exponent: IntegerNumber(:final value))
        when value >= Integer.zero && !value.isBig =>
      () {
        final db = _univariatePolyDegree(base, variable);
        return db != null ? db * value.toInt() : null;
      }(),
    _ => null,
  };
}

Map<int, Expr>? _extractUnivariatePolynomialCoeffs(Expr expr, String variable) {
  final expanded = expr.expand().simplify();
  final deg = _univariatePolyDegree(expanded, variable);
  if (deg == null) return null;

  final acc = MonomialAccumulator()..add(expanded);
  return acc.extractPolynomialCoefficients(variable);
}

(Expr, Expr)? _tryPolynomialLongDivision(
  Expr numExpr,
  Expr denExpr,
  String variable,
) {
  final numCoeffs = _extractUnivariatePolynomialCoeffs(numExpr, variable);
  final denCoeffs = _extractUnivariatePolynomialCoeffs(denExpr, variable);
  if (numCoeffs == null || denCoeffs == null) return null;

  int maxDeg(Map<int, Expr> c) {
    var m = -1;
    for (final e in c.entries) {
      final s = e.value.simplify();
      if (!(s is Number && s.isZero) && e.key > m) {
        m = e.key;
      }
    }
    return m;
  }

  final dDen = maxDeg(denCoeffs);
  var dRem = maxDeg(numCoeffs);
  if (dDen < 1 || dRem < dDen) return null;

  final rem = Map<int, Expr>.from(numCoeffs);
  final quot = <int, Expr>{};
  final leadDen = denCoeffs[dDen]!;

  var steps = 0;
  while (dRem >= dDen && steps <= 20) {
    steps++;
    final shift = dRem - dDen;
    final factor = (rem[dRem]! / leadDen).simplify();
    final existingQ = quot[shift];
    quot[shift] = existingQ == null ? factor : (existingQ + factor).simplify();

    for (final entry in denCoeffs.entries) {
      final targetDeg = entry.key + shift;
      final subTerm = (factor * entry.value).simplify();
      final cur = rem[targetDeg] ?? IntegerNumber.zero;
      rem[targetDeg] = (cur - subTerm).simplify();
    }
    rem.remove(dRem);
    dRem = maxDeg(rem);
  }

  Expr buildPoly(Map<int, Expr> coeffs) {
    final x = Variable(variable);
    final terms = <Expr>[];
    final keys = coeffs.keys.toList()..sort();
    for (final k in keys) {
      final c = coeffs[k]!.simplify();
      if (c is Number && c.isZero) continue;
      final xPow = k == 0
          ? IntegerNumber.one
          : k == 1
          ? x
          : Pow(x, IntegerNumber.of(k));
      final term = k == 0 ? c : (c * xPow).simplify();
      terms.add(term);
    }
    if (terms.isEmpty) return IntegerNumber.zero;
    if (terms.length == 1) return terms.first;
    return Add(terms).simplify();
  }

  return (buildPoly(quot), buildPoly(rem));
}
