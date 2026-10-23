import '../algebra/approximate.dart';
import '../algebra/expand.dart';
import '../algebra/rational.dart';
import '../algebra/simplify.dart';
import '../algebra/term_accumulator.dart';
import '../assumptions.dart';
import '../ast.dart';
import '../compiler.dart';
import '../number/integer.dart';
import '../solver/univariate.dart';
import 'differentiation.dart';
import 'limit.dart';
import 'linear_form.dart';

/// Specification of a single integration variable and optional definite bounds
/// for iterated integration via [IntegrationExtension.integrateMultiple].
///
/// When both `from` and `to` are omitted (`null`), an indefinite
/// anti-derivative is computed with respect to `variable`. When `from` and
/// `to` are provided (as [Expr], [int], [BigInt], or [double]), a definite
/// integral is evaluated.
typedef IntegrationBound = ({String variable, Object? from, Object? to});

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
  Expr integrate(
    String variable, {
    Object? from,
    Object? to,
    Assumptions assumptions = Assumptions.none,
  }) => _symbolicIntegrate(
    this,
    variable,
    from: from,
    to: to,
    assumptions: assumptions,
  );

  /// Computes an iterated (multiple) integral across [bounds] in sequence from
  /// innermost to outermost integration variable.
  ///
  /// For bounds $\[(x_1, a_1, b_1), (x_2, a_2, b_2), \dots, (x_n, a_n, b_n)\]$,
  /// this evaluates:
  /// $$\int_{a_n}^{b_n} \cdots \left(\int_{a_2}^{b_2} \left(\int_{a_1}^{b_1} f \, dx_1\right) dx_2\right) \cdots dx_n$$
  ///
  /// Inner bounds may depend symbolically on outer integration variables
  /// (e.g., integrating over a non-rectangular region $0 \le y \le x$,
  /// $0 \le x \le 1$). When any step lacks a closed-form anti-derivative, an
  /// unevaluated [Integral] node is retained, and nested definite [Integral]
  /// nodes can still be evaluated numerically via [CompilerExtension.evaluate]
  /// or [ApproximationExtension.approximate].
  ///
  /// ```dart
  /// final f = Expr.parse('x * y');
  /// final triangle = f.integrateMultiple([
  ///   (variable: 'y', from: 0, to: Variable('x')),
  ///   (variable: 'x', from: 0, to: 1),
  /// ]);
  /// // triangle: 1/8
  /// ```
  Expr integrateMultiple(
    Iterable<IntegrationBound> bounds, {
    Assumptions assumptions = Assumptions.none,
  }) {
    var current = this;
    for (final bound in bounds) {
      current = current.integrate(
        bound.variable,
        from: bound.from,
        to: bound.to,
        assumptions: assumptions,
      );
    }
    return current;
  }
}

final Expr _negInfinity = Mul(const [
  IntegerNumber.negativeOne,
  Constant.infinity,
], isSimplified: true);

bool _isInfiniteBound(Expr bound) =>
    bound == Constant.infinity ||
    bound == _negInfinity ||
    bound == -Constant.infinity;

Expr _symbolicIntegrate(
  Expr function,
  String variable, {
  Object? from,
  Object? to,
  Assumptions assumptions = Assumptions.none,
}) {
  if ((from == null) != (to == null)) {
    throw ArgumentError(
      'Both "from" and "to" must be provided for definite integration.',
    );
  }
  if (from != null && to != null) {
    final fromExpr = _boundToExpr(from).simplify(assumptions: assumptions);
    final toExpr = _boundToExpr(to).simplify(assumptions: assumptions);
    if (fromExpr == toExpr) {
      return IntegerNumber.zero;
    }
    final antiDeriv = _antiDerivative(
      function,
      variable,
    ).simplify(assumptions: assumptions);
    if (_hasUnevaluatedIntegral(antiDeriv, variable)) {
      return Integral(
        function.simplify(assumptions: assumptions),
        variable,
        lower: fromExpr,
        upper: toExpr,
        isSimplified: true,
      );
    }
    // Check for interior singularities/poles in finite intervals [a, b]
    if (!_isInfiniteBound(fromExpr) && !_isInfiniteBound(toExpr)) {
      final numFrom = _evaluateBoundNumeric(fromExpr);
      final numTo = _evaluateBoundNumeric(toExpr);
      if (numFrom != null && numTo != null) {
        final low = numFrom < numTo ? numFrom : numTo;
        final high = numFrom < numTo ? numTo : numFrom;
        final poles = _findDenominatorRoots(function, variable);
        for (final pole in poles) {
          if (pole > low && pole < high) {
            return Integral(
              function.simplify(assumptions: assumptions),
              variable,
              lower: fromExpr,
              upper: toExpr,
              isSimplified: true,
            );
          }
        }
      }
    }
    final effectiveAntiDeriv = _wrapLnWithAbs(antiDeriv);
    try {
      final upper = _isInfiniteBound(toExpr)
          ? effectiveAntiDeriv.limit(variable, toExpr, assumptions: assumptions)
          : effectiveAntiDeriv.substitute(variable, toExpr);
      final lower = _isInfiniteBound(fromExpr)
          ? effectiveAntiDeriv.limit(
              variable,
              fromExpr,
              assumptions: assumptions,
            )
          : effectiveAntiDeriv.substitute(variable, fromExpr);
      return (upper - lower).simplify(assumptions: assumptions);
    } on Object {
      return Integral(
        function.simplify(assumptions: assumptions),
        variable,
        lower: fromExpr,
        upper: toExpr,
        isSimplified: true,
      );
    }
  }

  try {
    return _antiDerivative(
      function,
      variable,
    ).simplify(assumptions: assumptions);
  } on Object {
    return Integral(
      function.simplify(assumptions: assumptions),
      variable,
      isSimplified: true,
    );
  }
}

double? _evaluateBoundNumeric(Expr bound) {
  if (bound is Number) return bound.toDouble();
  if (bound.freeVariables.isEmpty) {
    try {
      final v = bound.evaluate(const {});
      if (v.isFinite) return v;
    } on ArgumentError {
    } on UnsupportedError {}
  }
  return null;
}

List<Expr> _extractDenominatorFactors(Expr expr) {
  final factors = <Expr>[];
  void visit(Expr e) {
    if (e is Pow) {
      final exp = e.exponent;
      if (exp is Number && exp.toDouble() < 0) {
        factors.add(e.base);
      }
    } else if (e is Mul) {
      for (final f in e.factors) {
        visit(f);
      }
    } else if (e is Add) {
      for (final t in e.terms) {
        visit(t);
      }
    }
  }

  visit(expr);
  return factors;
}

List<double> _findDenominatorRoots(Expr expr, String variable) {
  final roots = <double>{};
  final factors = _extractDenominatorFactors(expr);
  for (final factor in factors) {
    if (factor.dependsOn(variable)) {
      try {
        final solutions = factor.solve(variable);
        for (final sol in solutions) {
          if (sol is Number) {
            final val = sol.toDouble();
            if (val.isFinite) roots.add(val);
          } else {
            try {
              final val = sol.evaluate(const {});
              if (val.isFinite) roots.add(val);
            } on ArgumentError {
            } on UnsupportedError {}
          }
        }
      } on ArgumentError {
      } on UnsupportedError {
      } on StateError {}
    }
  }
  return roots.toList();
}

Expr _wrapLnWithAbs(Expr expr) {
  if (expr is Ln) {
    if (expr.expr is Abs) return expr;
    return Ln(Abs(_wrapLnWithAbs(expr.expr)));
  }
  return expr.mapChildren(_wrapLnWithAbs);
}

bool _hasUnevaluatedIntegral(Expr expr, String variable) => expr.anyNode(
  (e) => e is Integral && !e.isDefinite && e.variable == variable,
);

Expr _boundToExpr(Object bound) => switch (bound) {
  double() => _doubleToBoundExpr(bound),
  _ => Expr.wrap(bound),
};

Expr _doubleToBoundExpr(double d) {
  final real = RealNumber.fromDouble(d);
  if (!d.isFinite) return real;
  if (d == d.truncateToDouble() && d.abs() <= Integer.maxSafe.toDouble()) {
    return IntegerNumber.of(d.toInt());
  }
  if (real is RealNumber) {
    final rat = real.rationalize(maxDenominator: 64);
    if (rat is RationalNumber && (d - rat.toDouble()).abs() < 1e-12) {
      return rat;
    }
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
    for (var i = 0; i < m; i++)
      _antiDerivative(expr.branches[i].expr, variable),
  ];
  final rawOth = expr.otherwise != null
      ? _antiDerivative(expr.otherwise!, variable)
      : null;

  final constants = <Expr>[IntegerNumber.zero];
  for (var k = 0; k < m - 1; k++) {
    final pt = _extractBoundaryPoint(expr.branches[k].relation, variable);
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
    final pt = _extractBoundaryPoint(expr.branches[m - 1].relation, variable);
    if (pt != null) {
      final vLeft = (rawG[m - 1].substitute(variable, pt) + constants[m - 1])
          .simplify();
      final vRight = rawOth.substitute(variable, pt).simplify();
      constOth = (vLeft - vRight).simplify();
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
      if (exponent == IntegerNumber.negativeOne ||
          (exponent is RealNumber && exponent.value == -1.0)) {
        return (Ln(base) / a).simplify();
      }
      final nPlus1 = (exponent + IntegerNumber.one).simplify();
      final denom = (a * nPlus1).simplify();
      final numer = Pow(base, nPlus1).simplify();
      return (numer / denom).simplify();
    }
    // Standard trig powers: sin^2, cos^2, tan^2, sinh^2, cosh^2, tanh^2
    if (exponent == IntegerNumber.two ||
        (exponent is RealNumber && exponent.value == 2.0)) {
      if (base case Sin(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final xVar = Variable(variable);
          final twoInner = (IntegerNumber.two * inner).simplify();
          return (xVar / IntegerNumber.two -
                  Sin(twoInner) / (const IntegerNumber(Integer(4)) * a))
              .simplify();
        }
      }
      if (base case Cos(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final xVar = Variable(variable);
          final twoInner = (IntegerNumber.two * inner).simplify();
          return (xVar / IntegerNumber.two +
                  Sin(twoInner) / (const IntegerNumber(Integer(4)) * a))
              .simplify();
        }
      }
      if (base case Tan(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final xVar = Variable(variable);
          return (Tan(inner) / a - xVar).simplify();
        }
      }
      if (base case Sinh(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final xVar = Variable(variable);
          final twoInner = (IntegerNumber.two * inner).simplify();
          return (Sinh(twoInner) / (const IntegerNumber(Integer(4)) * a) -
                  xVar / IntegerNumber.two)
              .simplify();
        }
      }
      if (base case Cosh(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final xVar = Variable(variable);
          final twoInner = (IntegerNumber.two * inner).simplify();
          return (Sinh(twoInner) / (const IntegerNumber(Integer(4)) * a) +
                  xVar / IntegerNumber.two)
              .simplify();
        }
      }
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

    // int c / cos(ax + b) dx = (c / a) * ln| (1 + sin(ax + b)) / cos(ax + b) |
    if (right case Cos(expr: final inner)) {
      if (inner.matchLinear(variable) case (:final a, b: _)) {
        final secTan = ((IntegerNumber.one + Sin(inner)) / Cos(inner))
            .simplify();
        return ((left * Ln(Abs(secTan))) / a).simplify();
      }
    }

    // int c / sin(ax + b) dx = -(c / a) * ln| (1 + cos(ax + b)) / sin(ax + b) |
    if (right case Sin(expr: final inner)) {
      if (inner.matchLinear(variable) case (:final a, b: _)) {
        final cscCot = ((IntegerNumber.one + Cos(inner)) / Sin(inner))
            .simplify();
        return ((-left * Ln(Abs(cscCot))) / a).simplify();
      }
    }

    // Completing the square for quadratic denominator: c / (Ax^2 + Bx + C)
    final coeffs = extractPolynomialCoefficients(right, variable);
    if (coeffs != null && maxPolynomialDegree(coeffs) == 2) {
      final a = coeffs[2] ?? IntegerNumber.zero;
      final b = coeffs[1] ?? IntegerNumber.zero;
      final c = coeffs[0] ?? IntegerNumber.zero;
      final delta = (const IntegerNumber(Integer(4)) * a * c - b * b)
          .simplify();
      final twoA = (IntegerNumber.two * a).simplify();
      final twoAxPlusB = (twoA * Variable(variable) + b).simplify();

      if (delta case RealNumeric(:final sign) when sign > 0) {
        final sqrtDelta = Pow(delta, FractionNumber.half).simplify();
        return ((IntegerNumber.two * left / sqrtDelta) *
                Atan(twoAxPlusB / sqrtDelta))
            .simplify();
      } else if (delta case RealNumeric(:final sign) when sign == 0) {
        final xPlus = (twoAxPlusB / twoA).simplify();
        return (-left / (a * xPlus)).simplify();
      } else if (delta case RealNumeric(:final sign) when sign < 0) {
        final dPos = (-delta).simplify();
        final sqrtD = Pow(dPos, FractionNumber.half).simplify();
        final arg = ((twoAxPlusB - sqrtD) / (twoAxPlusB + sqrtD)).simplify();
        return ((left / sqrtD) * Ln(Abs(arg))).simplify();
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

  // int u'(x) / sqrt(a - u(x)^2) dx = asin(u(x) / sqrt(a))
  if (right
      case Pow(base: Add(terms: [final aConst, final t1]), :final exponent)
      when (exponent == FractionNumber.half ||
              (exponent is RealNumber && exponent.value == 0.5)) &&
          !aConst.dependsOn(variable) &&
          _isPositiveConstant(aConst)) {
    final negTerm = (-t1).simplify();
    if (_extractSquareBase(negTerm) case final u? when u.dependsOn(variable)) {
      final uPrime = u.derivative(variable).simplify();
      if (left.matchScalarMultiple(uPrime, variable) case final k?) {
        final sqrtA = aConst == IntegerNumber.one
            ? IntegerNumber.one
            : Pow(aConst, FractionNumber.half).simplify();
        return Asin(u / sqrtA).scale(k);
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

  // Rational functions P(x) / Q(x): polynomial division and partial fractions
  if (right.dependsOn(variable)) {
    final degLeft = polynomialDegree(left.expand().simplify(), variable);
    final degRight = polynomialDegree(right.expand().simplify(), variable);
    if (degLeft != null && degRight != null && degRight >= 1) {
      if (degLeft >= degRight) {
        final (:quotient, :remainder) = left.polynomialDivide(right, variable);
        final qInt = _antiDerivative(quotient, variable);
        if (remainder is Number && remainder.isZero) {
          return qInt;
        }
        final rInt = _antiDerivative((remainder / right).simplify(), variable);
        return (qInt + rInt).simplify();
      }
      if (degRight >= 2) {
        final originalRatio = (left / right).simplify();
        final decomposed = originalRatio.apart(variable);
        if (decomposed case Add(:final terms)) {
          return Add([
            for (final term in terms) _antiDerivative(term, variable),
          ]).simplify();
        }
        if (decomposed != originalRatio) {
          final (_, newDen) = splitNumeratorDenominator(decomposed);
          final newDeg = polynomialDegree(newDen.expand().simplify(), variable);
          if ((newDeg != null && newDeg < degRight) ||
              (newDen is Pow && newDen.base.matchLinear(variable) != null) ||
              newDen.matchLinear(variable) != null) {
            return _antiDerivative(decomposed, variable);
          }
        }
      }
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
  final (:constFactors, :varFactors) = partitionFactors(
    original.factors,
    variable,
  );

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

  // 3b. Product of sines and cosines:
  if (varFactors case [final f1, final f2]) {
    if (_tryTrigProduct(f1, f2, variable) case final trigRes?) {
      return trigRes;
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
  if (polynomialDegree(original, variable) != null) {
    final expanded = original.expand().simplify();
    if (expanded != original) {
      return _antiDerivative(expanded, variable);
    }
  }

  return _unsupported(original, variable);
}

Expr? _tryTrigProduct(Expr left, Expr right, String variable) {
  if (left case Sin(expr: final a) when a.matchLinear(variable) != null) {
    if (right case Cos(expr: final b) when b.matchLinear(variable) != null) {
      final sum = (a + b).simplify();
      final diff = (a - b).simplify();
      final expanded = ((Sin(sum) + Sin(diff)) / IntegerNumber.two).simplify();
      return _antiDerivative(expanded, variable);
    }
    if (right case Sin(expr: final b) when b.matchLinear(variable) != null) {
      final diff = (a - b).simplify();
      final sum = (a + b).simplify();
      final expanded = ((Cos(diff) - Cos(sum)) / IntegerNumber.two).simplify();
      return _antiDerivative(expanded, variable);
    }
  }
  if (left case Cos(expr: final a) when a.matchLinear(variable) != null) {
    if (right case Sin()) {
      return _tryTrigProduct(right, left, variable);
    }
    if (right case Cos(expr: final b) when b.matchLinear(variable) != null) {
      final diff = (a - b).simplify();
      final sum = (a + b).simplify();
      final expanded = ((Cos(diff) + Cos(sum)) / IntegerNumber.two).simplify();
      return _antiDerivative(expanded, variable);
    }
  }
  return null;
}

Expr? _tryChainRule(Expr candidate, Expr factor, String variable) {
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
      _tryChainRulePower(base, exponent, factor, variable),
    Pow(:final base, :final exponent)
        when !base.dependsOn(variable) && exponent.dependsOn(variable) =>
      _tryChainRuleExponential(candidate, base, exponent, factor, variable),
    _ => null,
  };
}

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
    if (exponent == IntegerNumber.negativeOne ||
        (exponent is RealNumber && exponent.value == -1.0)) {
      return Ln(base).scale(k);
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
  final degP = polynomialDegree(pExpr, variable);
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
      if (!_hasUnevaluatedIntegral(v, variable) &&
          !_hasUnevaluatedIntegral(remIntegral, variable)) {
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
    } on ArgumentError {
    } on UnsupportedError {}
  }
  return false;
}

Expr? _extractScaledSquareBase(Expr expr, String variable) {
  final direct = _extractSquareBase(expr);
  if (direct != null) return direct;
  if (expr case Mul(:final factors)) {
    final (:constFactors, :varFactors) = partitionFactors(factors, variable);
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
