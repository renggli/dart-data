import 'package:more/number.dart' show Fraction;

import '../../numeric/integration.dart';
import '../algebra/simplify.dart';
import '../ast.dart';
import '../compiler.dart';
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
  /// substitution), falling back to adaptive Gauss-Kronrod numerical quadrature
  /// when an elementary closed-form anti-derivative cannot be matched over
  /// definite integration limits.
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
    try {
      final antiDeriv = _antiDerivative(function, variable);
      final upper = antiDeriv.substitute(variable, _numToNumber(to));
      final lower = antiDeriv.substitute(variable, _numToNumber(from));
      final diff = Sub(upper, lower).simplify();
      if (diff.freeVariables.isNotEmpty) {
        return diff;
      }
      final val = diff is Number ? diff.value : diff.evaluate(const {});
      if (val.isFinite) {
        return _numToNumber(val);
      }
    } on UnsupportedError {
      // Fall back to numerical integration.
    } catch (_) {
      // Fall back to numerical integration if evaluation is non-finite or
      // fails.
    }
    final numResult = integrate(
      function.toFunction1D(variable),
      from.toDouble(),
      to.toDouble(),
    );
    return _numToNumber(numResult);
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
    Log(:final base, :final expr) =>
      _antiDerivLog(base, expr, variable) ?? _unsupported(expr, variable),
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
  'Cannot compute analytical anti-derivative of "$expr" with respect to "$variable".',
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

Expr? _antiDerivLog(Expr base, Expr inner, String variable) =>
    !base.dependsOn(variable)
    ? switch (inner.matchLinear(variable)) {
        (:final a, b: _) => Div(
          Sub(Mul(inner, Ln(inner)), inner),
          Mul(a, Ln(base)),
        ).simplify(),
        null => null,
      }
    : null;

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
  }

  // int u'(x) / (1 + u(x)^2) dx = arctan(u(x))
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
    } else if (left.dependsOn(variable)) {
      return _antiDerivative(
        Mul(left, Pow(right, RationalNumber.negativeOne)),
        variable,
      );
    }
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
  final linP = pExpr.matchLinear(variable);
  if (linP == null) return null;
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
