import 'package:more/number.dart' show Fraction;

import '../algebra/expand.dart';
import '../algebra/factor.dart';
import '../algebra/simplify.dart';
import '../algebra/term_accumulator.dart';
import '../ast.dart';
import 'differentiation.dart';
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
  /// substitution). Throws an [UnsupportedError] when no elementary
  /// closed-form anti-derivative exists.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final area = (x * x).integrate('x', from: 0, to: 3);
  /// // area: RationalNumber(9) because \int_0^3 x^2 dx = [x^3 / 3]_0^3 = 9.0
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
      return RationalNumber.zero;
    }
    final antiDeriv = _antiDerivative(function, variable);
    final upper = antiDeriv.substitute(variable, _numToNumber(to));
    final lower = antiDeriv.substitute(variable, _numToNumber(from));
    final diff = Sub(upper, lower).simplify();
    if (diff.freeVariables.isNotEmpty) {
      return diff;
    }
    try {
      final val = diff is Number ? diff.toDouble() : diff.evaluate(const {});
      if (val.isFinite) {
        return _numToNumber(val);
      }
    } catch (_) {
      // Return symbolic difference if numerical evaluation fails.
    }
    return diff;
  }

  return _antiDerivative(function, variable).simplify();
}

Number _numToNumber(num n) {
  if (n is int) return RationalNumber(n);
  final frac = Fraction.fromDouble(n, maxDenominator: 64);
  if ((n.toDouble() - frac.toDouble()).abs() < 1e-12) {
    return RationalNumber(frac.numerator, frac.denominator);
  }
  return RealNumber(n.toDouble());
}

Expr _antiDerivative(Expr expr, String variable) {
  expr = expr.simplify();

  if (!expr.dependsOn(variable)) {
    if (expr case RationalNumber(isZero: true)) {
      return RationalNumber.zero;
    }
    return Mul(expr, Variable(variable)).simplify();
  }

  return switch (expr) {
    Variable(:final name) when name == variable => Div(
      Pow(expr, const RationalNumber(2)),
      const RationalNumber(2),
    ),
    Neg(:final expr) => Neg(_antiDerivative(expr, variable)).simplify(),
    Add(:final left, :final right) => Add(
      _antiDerivative(left, variable),
      _antiDerivative(right, variable),
    ).simplify(),
    Sub(:final left, :final right) => Sub(
      _antiDerivative(left, variable),
      _antiDerivative(right, variable),
    ).simplify(),
    Sin(:final expr) =>
      _antiDerivSin(expr, variable) ?? _unsupported(expr, variable),
    Cos(:final expr) =>
      _antiDerivCos(expr, variable) ?? _unsupported(expr, variable),
    Tan(:final expr) =>
      _antiDerivTan(expr, variable) ?? _unsupported(expr, variable),
    Asin(:final expr) =>
      _antiDerivAsin(expr, variable) ?? _unsupported(expr, variable),
    Acos(:final expr) =>
      _antiDerivAcos(expr, variable) ?? _unsupported(expr, variable),
    Atan(:final expr) =>
      _antiDerivAtan(expr, variable) ?? _unsupported(expr, variable),
    Sinh(:final expr) =>
      _antiDerivSinh(expr, variable) ?? _unsupported(expr, variable),
    Cosh(:final expr) =>
      _antiDerivCosh(expr, variable) ?? _unsupported(expr, variable),
    Tanh(:final expr) =>
      _antiDerivTanh(expr, variable) ?? _unsupported(expr, variable),
    Abs(:final expr) =>
      _antiDerivAbs(expr, variable) ?? _unsupported(expr, variable),
    Exp(:final expr) =>
      _antiDerivExp(expr, variable) ?? _unsupported(expr, variable),
    Ln(:final expr) =>
      _antiDerivLn(expr, variable) ?? _unsupported(expr, variable),
    LambertW(:final expr, :final branch) =>
      _antiDerivLambertW(expr, branch, variable) ??
          _unsupported(expr, variable),
    Erf(:final expr) =>
      _antiDerivErf(expr, variable) ?? _unsupported(expr, variable),
    Erfc(:final expr) =>
      _antiDerivErfc(expr, variable) ?? _unsupported(expr, variable),
    Asinh(:final expr) =>
      _antiDerivAsinh(expr, variable) ?? _unsupported(expr, variable),
    Acosh(:final expr) =>
      _antiDerivAcosh(expr, variable) ?? _unsupported(expr, variable),
    Atanh(:final expr) =>
      _antiDerivAtanh(expr, variable) ?? _unsupported(expr, variable),
    Piecewise() => _antiDerivPiecewise(expr, variable),
    Pow(:final base, :final exponent) => _antiDerivPow(
      base,
      exponent,
      expr,
      variable,
    ),
    Div(:final left, :final right) => _antiDerivDiv(
      left,
      right,
      expr,
      variable,
    ),
    Mul(:final left, :final right) => _antiDerivMul(
      left,
      right,
      expr,
      variable,
    ),
    _ => _unsupported(expr, variable),
  };
}

Never _unsupported(Expr expr, String variable) => throw UnsupportedError(
  'No closed-form anti-derivative found for $expr with respect to $variable',
);

Expr? _antiDerivSin(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) => Div(Neg(Cos(inner)), a).simplify(),
      null => null,
    };

Expr? _antiDerivCos(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) => Div(Sin(inner), a).simplify(),
      null => null,
    };

Expr? _antiDerivTan(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) => Div(Neg(Ln(Cos(inner))), a).simplify(),
      null => null,
    };

Expr? _antiDerivAsin(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) => Div(
        Add(
          Mul(inner, Asin(inner)),
          Pow(
            Sub(RationalNumber.one, Pow(inner, const RationalNumber(2))),
            const RationalNumber(1, 2),
          ),
        ),
        a,
      ).simplify(),
      null => null,
    };

Expr? _antiDerivAcos(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) => Div(
        Sub(
          Mul(inner, Acos(inner)),
          Pow(
            Sub(RationalNumber.one, Pow(inner, const RationalNumber(2))),
            const RationalNumber(1, 2),
          ),
        ),
        a,
      ).simplify(),
      null => null,
    };

Expr? _antiDerivAtan(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) => Div(
        Sub(
          Mul(inner, Atan(inner)),
          Mul(
            const RationalNumber(1, 2),
            Ln(Add(RationalNumber.one, Pow(inner, const RationalNumber(2)))),
          ),
        ),
        a,
      ).simplify(),
      null => null,
    };

Expr? _antiDerivSinh(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) => Div(Cosh(inner), a).simplify(),
      null => null,
    };

Expr? _antiDerivCosh(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) => Div(Sinh(inner), a).simplify(),
      null => null,
    };

Expr? _antiDerivTanh(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) => Div(Ln(Cosh(inner)), a).simplify(),
      null => null,
    };

Expr? _antiDerivAbs(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) => Div(
        Mul(inner, Abs(inner)),
        Mul(const RationalNumber(2), a),
      ).simplify(),
      null => null,
    };

Expr? _antiDerivExp(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) => Div(Exp(inner), a).simplify(),
      null => null,
    };

Expr? _antiDerivLn(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) => Div(Sub(Mul(inner, Ln(inner)), inner), a).simplify(),
      null => null,
    };

Expr? _antiDerivLambertW(Expr inner, int branch, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) => Div(
        Add(
          Mul(inner, Sub(LambertW(inner, branch: branch), RationalNumber.one)),
          Exp(LambertW(inner, branch: branch)),
        ),
        a,
      ).simplify(),
      null => null,
    };

Expr? _antiDerivErf(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) => Div(
        Add(
          Mul(inner, Erf(inner)),
          Div(
            Exp(Neg(Pow(inner, const RationalNumber(2)))),
            const Pow(ConstantNumber.pi, RationalNumber(1, 2)),
          ),
        ),
        a,
      ).simplify(),
      null => null,
    };

Expr? _antiDerivErfc(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) => Div(
        Sub(
          Mul(inner, Erfc(inner)),
          Div(
            Exp(Neg(Pow(inner, const RationalNumber(2)))),
            const Pow(ConstantNumber.pi, RationalNumber(1, 2)),
          ),
        ),
        a,
      ).simplify(),
      null => null,
    };

Expr? _antiDerivAsinh(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) => Div(
        Sub(
          Mul(inner, Asinh(inner)),
          Pow(
            Add(Pow(inner, const RationalNumber(2)), RationalNumber.one),
            const RationalNumber(1, 2),
          ),
        ),
        a,
      ).simplify(),
      null => null,
    };

Expr? _antiDerivAcosh(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) => Div(
        Sub(
          Mul(inner, Acosh(inner)),
          Pow(
            Sub(Pow(inner, const RationalNumber(2)), RationalNumber.one),
            const RationalNumber(1, 2),
          ),
        ),
        a,
      ).simplify(),
      null => null,
    };

Expr? _antiDerivAtanh(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) => Div(
        Add(
          Mul(inner, Atanh(inner)),
          Mul(
            const RationalNumber(1, 2),
            Ln(Sub(RationalNumber.one, Pow(inner, const RationalNumber(2)))),
          ),
        ),
        a,
      ).simplify(),
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

  final constants = <Expr>[RationalNumber.zero];
  for (var k = 0; k < m - 1; k++) {
    final pt = _extractBoundaryPoint(expr.branches[k].$1, variable);
    if (pt != null) {
      final vLeft = Add(
        rawG[k].substitute(variable, pt),
        constants[k],
      ).simplify();
      final vRight = rawG[k + 1].substitute(variable, pt).simplify();
      constants.add(Sub(vLeft, vRight).simplify());
    } else {
      constants.add(RationalNumber.zero);
    }
  }

  Expr? constOth;
  if (rawOth != null && m > 0) {
    final pt = _extractBoundaryPoint(expr.branches[m - 1].$1, variable);
    if (pt != null) {
      final vLeft = Add(
        rawG[m - 1].substitute(variable, pt),
        constants[m - 1],
      ).simplify();
      final vRight = rawOth.substitute(variable, pt).simplify();
      constOth = Sub(vLeft, vRight).simplify();
    } else {
      constOth = RationalNumber.zero;
    }
  }

  final newBranches = <(Expr, Expr)>[
    for (var i = 0; i < m; i++)
      (expr.branches[i].$1, Add(rawG[i], constants[i]).simplify()),
  ];
  final newOtherwise = rawOth != null
      ? Add(rawOth, constOth ?? RationalNumber.zero).simplify()
      : null;
  return Piecewise(newBranches, otherwise: newOtherwise);
}

Expr? _extractBoundaryPoint(Expr cond, String variable) => switch (cond) {
  LessThan(left: Variable(:final name), :final right)
      when name == variable && !right.dependsOn(variable) =>
    right,
  LessEqual(left: Variable(:final name), :final right)
      when name == variable && !right.dependsOn(variable) =>
    right,
  GreaterThan(left: final bound, right: Variable(:final name))
      when name == variable && !bound.dependsOn(variable) =>
    bound,
  GreaterEqual(left: final bound, right: Variable(:final name))
      when name == variable && !bound.dependsOn(variable) =>
    bound,
  _ => null,
};

Expr _antiDerivPow(Expr base, Expr exponent, Expr original, String variable) {
  // Form: (ax + b)^n
  if (!exponent.dependsOn(variable)) {
    if (base.matchLinear(variable) case (:final a, b: _)) {
      if (exponent case RationalNumber(isNegativeOne: true)) {
        return Div(Ln(base), a).simplify();
      }
      final nPlus1 = Add(exponent, RationalNumber.one).simplify();
      final denom = Mul(a, nPlus1).simplify();
      final numer = Pow(base, nPlus1).simplify();
      return Div(numer, denom).simplify();
    }
    if (exponent is RationalNumber &&
        exponent.isInteger &&
        exponent.numerator > 1) {
      final expanded = original.expand().simplify();
      if (expanded != original) {
        return _antiDerivative(expanded, variable);
      }
    }
  }

  // Form: c^(ax + b)
  if (!base.dependsOn(variable)) {
    if (exponent.matchLinear(variable) case (:final a, b: _)) {
      var validBase = true;
      if (base case RationalNumber(
        :final isNegative,
        :final isZero,
        :final isOne,
      )) {
        validBase = !isNegative && !isZero && !isOne;
      } else if (base case RealNumber(:final value)) {
        validBase = value > 0 && value != 1.0;
      }
      if (validBase) {
        final denom = Mul(a, Ln(base)).simplify();
        return Div(original, denom).simplify();
      }
    }
  }

  return _unsupported(original, variable);
}

Expr _antiDerivDiv(Expr left, Expr right, Expr original, String variable) {
  // int (f / c) dx = (1/c) int f dx
  if (!right.dependsOn(variable)) {
    final anti = _antiDerivative(left, variable);
    return anti.scale(Div(RationalNumber.one, right));
  }

  // int (c / g(x)) dx
  if (!left.dependsOn(variable)) {
    // int c / (ax + b) dx = (c ln(ax + b)) / a
    if (right.matchLinear(variable) case (:final a, b: _)) {
      final num = Mul(left, Ln(right)).simplify();
      return Div(num, a).simplify();
    }

    // int c / (ax + b)^n dx = int c * (ax + b)^(-n) dx
    if (right case Pow(:final base, :final exponent)
        when !exponent.dependsOn(variable) &&
            base.matchLinear(variable) != null) {
      final negExp = Neg(exponent).simplify();
      return _antiDerivative(Mul(left, Pow(base, negExp)), variable);
    }

    // int c / cosh(ax + b) dx = (c / a) * atan(sinh(ax + b))
    if (right case Cosh(expr: final inner)) {
      if (inner.matchLinear(variable) case (:final a, b: _)) {
        return Div(Mul(left, Atan(Sinh(inner))), a).simplify();
      }
    }

    // int c / (d + exp(ax + b)) dx = (c / d) * (x - (1 / a) * ln(d + exp(ax + b)))
    if (right case Add(left: final rL, right: final rR)) {
      Expr? constTerm;
      Expr? expArg;
      if (!rL.dependsOn(variable) && rR is Exp) {
        constTerm = rL;
        expArg = rR.expr;
      } else if (!rR.dependsOn(variable) && rL is Exp) {
        constTerm = rR;
        expArg = rL.expr;
      }
      if (constTerm != null && expArg != null) {
        if (expArg.matchLinear(variable) case (:final a, b: _)) {
          final term = Sub(Variable(variable), Div(Ln(right), a)).simplify();
          return Mul(Div(left, constTerm), term).simplify();
        }
      }
    }
  }

  // int u'(x) / (a + b * u(x)^2) dx = (1 / sqrt(a * b)) * arctan(sqrt(b / a) * u(x))
  if (right case Add(left: final rL, right: final rR)) {
    Expr? u;
    if (rL case RationalNumber(isOne: true) || RealNumber(value: 1.0)) {
      u = _extractSquareBase(rR);
    } else if (rR case RationalNumber(isOne: true) || RealNumber(value: 1.0)) {
      u = _extractSquareBase(rL);
    }
    if (u != null && u.dependsOn(variable)) {
      final uPrime = u.derivative(variable).simplify();
      final k = left.matchScalarMultiple(uPrime, variable);
      if (k != null) {
        return Atan(u).scale(k);
      }
    }
    // General positive constant a + sqTerm
    Expr? aConst;
    Expr? sqTerm;
    if (!rL.dependsOn(variable) && rR.dependsOn(variable)) {
      aConst = rL;
      sqTerm = rR;
    } else if (!rR.dependsOn(variable) && rL.dependsOn(variable)) {
      aConst = rR;
      sqTerm = rL;
    }
    if (aConst != null && sqTerm != null && _isPositiveConstant(aConst)) {
      final w = _extractScaledSquareBase(
        Div(sqTerm, aConst).simplify(),
        variable,
      );
      if (w != null && w.dependsOn(variable)) {
        final wPrime = w.derivative(variable).simplify();
        final k = left.matchScalarMultiple(wPrime, variable);
        if (k != null) {
          return Atan(w).scale(Div(k, aConst).simplify());
        }
      }
    }
  }

  // int u'(x) / sqrt(1 - u(x)^2) dx = asin(u(x))
  {
    Expr? inner;
    if (right case Pow(
      base: final b,
      exponent: RationalNumber(numerator: 1, denominator: 2) ||
          RealNumber(value: 0.5),
    )) {
      inner = b;
    }
    Expr? u;
    if (inner case Sub(
      left: RationalNumber(isOne: true) || RealNumber(value: 1.0),
      right: final term,
    )) {
      u = _extractSquareBase(term);
    } else if (inner case Add(
      left: Neg(expr: final term) ||
          Mul(
            left: RationalNumber(isNegativeOne: true) ||
                RealNumber(value: -1.0),
            right: final term,
          ),
      right: RationalNumber(isOne: true) || RealNumber(value: 1.0),
    )) {
      u = _extractSquareBase(term);
    } else if (inner case Add(
      left: RationalNumber(isOne: true) || RealNumber(value: 1.0),
      right: Neg(expr: final term) ||
          Mul(
            left: RationalNumber(isNegativeOne: true) ||
                RealNumber(value: -1.0),
            right: final term,
          ),
    )) {
      u = _extractSquareBase(term);
    }
    if (u != null && u.dependsOn(variable)) {
      final uPrime = u.derivative(variable).simplify();
      final k = left.matchScalarMultiple(uPrime, variable);
      if (k != null) {
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
    if (right case Pow(:final base, :final exponent)
        when !exponent.dependsOn(variable)) {
      final negExp = Neg(exponent).simplify();
      return _antiDerivative(Mul(left, Pow(base, negExp)), variable);
    }
  }

  // Univariate polynomial long division when deg(left) >= deg(right) >= 1
  if (left.dependsOn(variable) && right.dependsOn(variable)) {
    final divResult = _tryPolynomialLongDivision(left, right, variable);
    if (divResult != null) {
      final (quotient, remainder) = divResult;
      final qInt = _antiDerivative(quotient, variable);
      if (remainder is RationalNumber && remainder.isZero) {
        return qInt;
      }
      final rInt = _antiDerivative(Div(remainder, right).simplify(), variable);
      return Add(qInt, rInt).simplify();
    }

    final factored = original.factor().simplify();
    if (factored != original && factored is! Div) {
      return _antiDerivative(factored, variable);
    }

    return _antiDerivative(
      Mul(left, Pow(right, RationalNumber.negativeOne)),
      variable,
    );
  }

  return _unsupported(original, variable);
}

Expr _antiDerivMul(Expr left, Expr right, Expr original, String variable) {
  // Linear combinations: c * f(x)
  if (!left.dependsOn(variable)) {
    return _antiDerivative(right, variable).scale(left);
  }
  if (!right.dependsOn(variable)) {
    return _antiDerivative(left, variable).scale(right);
  }

  // Identity multiplication: u * u = u^2
  if (left == right) {
    return _antiDerivative(Pow(left, const RationalNumber(2)), variable);
  }

  // Chain-rule substitution: int u'(x) f(u(x)) dx = F(u(x))
  if (_tryChainRule(right, left, variable) case final subRight?) {
    return subRight;
  }
  if (_tryChainRule(left, right, variable) case final subLeft?) {
    return subLeft;
  }

  // Integration by parts:
  if (_tryIntegrationByParts(left, right, variable) case final ibpLR?) {
    return ibpLR;
  }
  if (_tryIntegrationByParts(right, left, variable) case final ibpRL?) {
    return ibpRL;
  }

  // Distributive expansion across additions/subtractions:
  if (left case Add(:final left, right: final lRight)) {
    return Add(
      _antiDerivative(Mul(left, right), variable),
      _antiDerivative(Mul(lRight, right), variable),
    ).simplify();
  }
  if (left case Sub(:final left, right: final lRight)) {
    return Sub(
      _antiDerivative(Mul(left, right), variable),
      _antiDerivative(Mul(lRight, right), variable),
    ).simplify();
  }
  if (right case Add(left: final rLeft, :final right)) {
    return Add(
      _antiDerivative(Mul(left, rLeft), variable),
      _antiDerivative(Mul(left, right), variable),
    ).simplify();
  }
  if (right case Sub(left: final rLeft, :final right)) {
    return Sub(
      _antiDerivative(Mul(left, rLeft), variable),
      _antiDerivative(Mul(left, right), variable),
    ).simplify();
  }

  // Full polynomial expansion fallback (e.g. factored polynomials like (x-1)*(x-2)*(x+2)):
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
        Neg(Cos(expr)).simplify(),
        variable,
      ),
      Exp(:final expr) when expr.dependsOn(variable) => _scaleMatch(
        factor,
        expr.derivative(variable).simplify(),
        Exp(expr),
        variable,
      ),
      Ln(:final expr) when expr.dependsOn(variable) => _scaleMatch(
        factor,
        expr.derivative(variable).simplify(),
        Sub(Mul(expr, Ln(expr)), expr),
        variable,
      ),
      Tan(:final expr) when expr.dependsOn(variable) => _scaleMatch(
        factor,
        expr.derivative(variable).simplify(),
        Neg(Ln(Cos(expr))),
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
        Div(Mul(expr, Abs(expr)), const RationalNumber(2)),
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
    if (exponent case RationalNumber(isNegativeOne: true)) {
      return Ln(base).scale(k);
    }
    final nPlus1 = Add(exponent, RationalNumber.one).simplify();
    final fU = Div(Pow(base, nPlus1), nPlus1).simplify();
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
  var validBase = true;
  if (base case RationalNumber(
    :final isNegative,
    :final isZero,
    :final isOne,
  )) {
    validBase = !isNegative && !isZero && !isOne;
  } else if (base case RealNumber(:final value)) {
    validBase = value > 0 && value != 1.0;
  }
  if (validBase) {
    final uPrime = exponent.derivative(variable).simplify();
    final k = factor.matchScalarMultiple(uPrime, variable);
    if (k != null) {
      final denom = Ln(base);
      final fU = Div(candidate, denom).simplify();
      return fU.scale(k);
    }
  }
  return null;
}

Expr? _tryIntegrationByParts(Expr pExpr, Expr vExpr, String variable) {
  // Cyclic IBP: exp(ax + b) * sin(cx + d) or exp(ax + b) * cos(cx + d)
  if (pExpr case Exp(expr: final expInner)) {
    if (expInner.matchLinear(variable) case (a: final a, b: _)) {
      if (vExpr case Sin(expr: final trigInner)) {
        if (trigInner.matchLinear(variable) case (a: final c, b: _)) {
          final denom = Add(Mul(a, a), Mul(c, c)).simplify();
          final numer = Mul(
            pExpr,
            Sub(Mul(a, Sin(trigInner)), Mul(c, Cos(trigInner))),
          ).simplify();
          return Div(numer, denom).simplify();
        }
      }
      if (vExpr case Cos(expr: final trigInner)) {
        if (trigInner.matchLinear(variable) case (a: final c, b: _)) {
          final denom = Add(Mul(a, a), Mul(c, c)).simplify();
          final numer = Mul(
            pExpr,
            Add(Mul(a, Cos(trigInner)), Mul(c, Sin(trigInner))),
          ).simplify();
          return Div(numer, denom).simplify();
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
      Exp(:final expr) => switch (expr.matchLinear(variable)) {
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
      Exp(:final expr) ||
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
        Mul(pPrime, v).expand().simplify(),
        variable,
      );
      return Sub(Mul(pExpr, v), remIntegral).simplify();
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
  final cSquared = Mul(c, c).simplify();
  final aCap = Div(p, cSquared).simplify();
  final numB = Sub(Mul(q, c), Mul(p, d)).simplify();
  final bCap = Div(numB, cSquared).simplify();
  final w = expr;
  final wSquared = Pow(w, const RationalNumber(2)).simplify();
  final termA1 = Div(Mul(aCap, wSquared), const RationalNumber(2)).simplify();
  final termB1 = Mul(bCap, w).simplify();
  final coeff1 = Add(termA1, termB1).simplify();

  final termA2 = Div(Mul(aCap, wSquared), const RationalNumber(4)).simplify();
  final coeff2 = Add(termA2, termB1).simplify();

  return Sub(Mul(coeff1, vExpr), coeff2).simplify();
}

Expr _ibpExponential(Expr pExpr, Expr vExpr, Expr p, Expr c) {
  final term1 = Div(pExpr, c).simplify();
  final cSquared = Mul(c, c).simplify();
  final term2 = Div(p, cSquared).simplify();
  final coeff = Sub(term1, term2).simplify();
  return Mul(coeff, vExpr).simplify();
}

Expr? _ibpGeneralExponential(
  Expr pExpr,
  Expr vExpr,
  Expr base,
  Expr p,
  Expr a,
) {
  var validBase = true;
  if (base case RationalNumber(
    :final isNegative,
    :final isZero,
    :final isOne,
  )) {
    validBase = !isNegative && !isZero && !isOne;
  } else if (base case RealNumber(:final value)) {
    validBase = value > 0 && value != 1.0;
  }
  if (validBase) {
    final cEff = Mul(a, Ln(base)).simplify();
    final term1 = Div(pExpr, cEff).simplify();
    final cEffSquared = Mul(cEff, cEff).simplify();
    final term2 = Div(p, cEffSquared).simplify();
    final coeff = Sub(term1, term2).simplify();
    return Mul(coeff, vExpr).simplify();
  }
  return null;
}

Expr _ibpCosine(Expr pExpr, Expr vExpr, Expr expr, Expr p, Expr c) {
  final term1 = Mul(Div(pExpr, c).simplify(), Sin(expr)).simplify();
  final cSquared = Mul(c, c).simplify();
  final term2 = Mul(Div(p, cSquared).simplify(), Cos(expr)).simplify();
  return Add(term1, term2).simplify();
}

Expr _ibpSine(Expr pExpr, Expr vExpr, Expr expr, Expr p, Expr c) {
  final term1 = Neg(Mul(Div(pExpr, c).simplify(), Cos(expr))).simplify();
  final cSquared = Mul(c, c).simplify();
  final term2 = Mul(Div(p, cSquared).simplify(), Sin(expr)).simplify();
  return Add(term1, term2).simplify();
}

Expr _ibpSinh(Expr pExpr, Expr vExpr, Expr expr, Expr p, Expr c) {
  final term1 = Mul(Div(pExpr, c).simplify(), Cosh(expr)).simplify();
  final cSquared = Mul(c, c).simplify();
  final term2 = Mul(Div(p, cSquared).simplify(), Sinh(expr)).simplify();
  return Sub(term1, term2).simplify();
}

Expr _ibpCosh(Expr pExpr, Expr vExpr, Expr expr, Expr p, Expr c) {
  final term1 = Mul(Div(pExpr, c).simplify(), Sinh(expr)).simplify();
  final cSquared = Mul(c, c).simplify();
  final term2 = Mul(Div(p, cSquared).simplify(), Cosh(expr)).simplify();
  return Sub(term1, term2).simplify();
}

Expr? _extractSquareBase(Expr expr) {
  if (expr is Pow) {
    final exp = expr.exponent;
    if (exp is RationalNumber &&
        exp.denominator == 1 &&
        exp.numerator % 2 == 0) {
      final half = exp.numerator ~/ 2;
      return half == 1 ? expr.base : Pow(expr.base, RationalNumber(half));
    } else if (exp is RealNumber && exp.value % 2.0 == 0.0) {
      final half = (exp.value / 2.0).round();
      return half == 1 ? expr.base : Pow(expr.base, RationalNumber(half));
    }
  }
  return null;
}

bool _isPositiveConstant(Expr expr) {
  if (expr is RationalNumber) return expr.numerator > 0;
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
  if (expr case Mul(:final left, :final right)) {
    if (!left.dependsOn(variable) && _isPositiveConstant(left)) {
      final sq = _extractSquareBase(right);
      if (sq != null) {
        return Mul(
          Pow(left, const RationalNumber(1, 2)).simplify(),
          sq,
        ).simplify();
      }
    }
    if (!right.dependsOn(variable) && _isPositiveConstant(right)) {
      final sq = _extractSquareBase(left);
      if (sq != null) {
        return Mul(
          Pow(right, const RationalNumber(1, 2)).simplify(),
          sq,
        ).simplify();
      }
    }
  }
  if (expr case Div(:final left, :final right)) {
    if (!right.dependsOn(variable) && _isPositiveConstant(right)) {
      final sq = _extractScaledSquareBase(left, variable);
      if (sq != null) {
        return Div(
          sq,
          Pow(right, const RationalNumber(1, 2)).simplify(),
        ).simplify();
      }
    }
  }
  return null;
}

int? _univariatePolyDegree(Expr expr, String variable) {
  if (!expr.dependsOn(variable)) return 0;
  return switch (expr) {
    Variable(:final name) when name == variable => 1,
    Neg(:final expr) => _univariatePolyDegree(expr, variable),
    Add(:final left, :final right) || Sub(:final left, :final right) => () {
      final dl = _univariatePolyDegree(left, variable);
      final dr = _univariatePolyDegree(right, variable);
      if (dl == null || dr == null) return null;
      return dl > dr ? dl : dr;
    }(),
    Mul(:final left, :final right) => () {
      final dl = _univariatePolyDegree(left, variable);
      final dr = _univariatePolyDegree(right, variable);
      if (dl == null || dr == null) return null;
      return dl + dr;
    }(),
    Pow(
      :final base,
      exponent: RationalNumber(:final isInteger, :final numerator),
    )
        when isInteger && numerator >= 0 =>
      () {
        final db = _univariatePolyDegree(base, variable);
        return db != null ? db * numerator : null;
      }(),
    _ => null,
  };
}

Map<int, Expr>? _extractUnivariatePolynomialCoeffs(Expr expr, String variable) {
  final expanded = expr.expand().simplify();
  final deg = _univariatePolyDegree(expanded, variable);
  if (deg == null) return null;

  final acc = MonomialAccumulator();
  acc.add(expanded);
  final coeffs = <int, Expr>{};

  void addTerm(int d, Expr c) {
    final existing = coeffs[d];
    coeffs[d] = existing == null ? c : Add(existing, c).simplify();
  }

  if (acc.constantRational != Fraction.zero) {
    addTerm(0, RationalNumber.fraction(acc.constantRational));
  }
  if (acc.constantReal != 0.0) {
    addTerm(0, RealNumber(acc.constantReal));
  }

  for (final entry in acc.rationalTerms.entries) {
    final parsed = _parseUnivariateTerm(
      entry.key,
      RationalNumber.fraction(entry.value),
      variable,
    );
    if (parsed == null) return null;
    addTerm(parsed.$1, parsed.$2);
  }
  for (final entry in acc.realTerms.entries) {
    final parsed = _parseUnivariateTerm(
      entry.key,
      RealNumber(entry.value),
      variable,
    );
    if (parsed == null) return null;
    addTerm(parsed.$1, parsed.$2);
  }
  return coeffs;
}

(int, Expr)? _parseUnivariateTerm(Expr base, Expr scalar, String variable) {
  if (!base.dependsOn(variable)) {
    return (0, Mul(scalar, base).simplify());
  }
  if (base is Variable && base.name == variable) {
    return (1, scalar);
  }
  if (base is Pow &&
      base.base is Variable &&
      (base.base as Variable).name == variable &&
      base.exponent is RationalNumber &&
      (base.exponent as RationalNumber).isInteger &&
      (base.exponent as RationalNumber).numerator >= 0) {
    return ((base.exponent as RationalNumber).numerator, scalar);
  }
  if (base is Mul) {
    if (!base.left.dependsOn(variable)) {
      return _parseUnivariateTerm(
        base.right,
        Mul(scalar, base.left).simplify(),
        variable,
      );
    }
    if (!base.right.dependsOn(variable)) {
      return _parseUnivariateTerm(
        base.left,
        Mul(scalar, base.right).simplify(),
        variable,
      );
    }
  }
  return null;
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
    final factor = Div(rem[dRem]!, leadDen).simplify();
    final existingQ = quot[shift];
    quot[shift] = existingQ == null
        ? factor
        : Add(existingQ, factor).simplify();

    for (final entry in denCoeffs.entries) {
      final targetDeg = entry.key + shift;
      final subTerm = Mul(factor, entry.value).simplify();
      final cur = rem[targetDeg] ?? RationalNumber.zero;
      rem[targetDeg] = Sub(cur, subTerm).simplify();
    }
    rem.remove(dRem);
    dRem = maxDeg(rem);
  }

  Expr buildPoly(Map<int, Expr> coeffs) {
    final x = Variable(variable);
    Expr? res;
    final keys = coeffs.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final k in keys) {
      final c = coeffs[k]!.simplify();
      if (c is Number && c.isZero) continue;
      final xPow = k == 0
          ? RationalNumber.one
          : k == 1
          ? x
          : Pow(x, RationalNumber(k));
      final term = k == 0 ? c : Mul(c, xPow).simplify();
      res = res == null ? term : Add(res, term);
    }
    return (res ?? RationalNumber.zero).simplify();
  }

  return (buildPoly(quot), buildPoly(rem));
}
