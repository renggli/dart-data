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

    // Odd integrand over symmetric interval [-a, a]
    if ((fromExpr + toExpr).simplify(assumptions: assumptions) ==
        IntegerNumber.zero) {
      if (_isOddIntegrandWithoutInteriorPoles(
        function,
        variable,
        fromExpr,
        toExpr,
        assumptions: assumptions,
      )) {
        return IntegerNumber.zero;
      }
    }

    final antiDeriv = _antiDerivative(
      function,
      variable,
    ).simplify(assumptions: assumptions);
    if (!_hasUnevaluatedIntegral(antiDeriv, variable)) {
      var hasInteriorPole = false;
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
              hasInteriorPole = true;
              break;
            }
          }
        }
      }
      if (!hasInteriorPole) {
        final effectiveAntiDeriv = _wrapLnWithAbs(antiDeriv);
        try {
          final upper = _isInfiniteBound(toExpr)
              ? effectiveAntiDeriv.limit(
                  variable,
                  toExpr,
                  assumptions: assumptions,
                )
              : effectiveAntiDeriv.substitute(variable, toExpr);
          final lower = _isInfiniteBound(fromExpr)
              ? effectiveAntiDeriv.limit(
                  variable,
                  fromExpr,
                  assumptions: assumptions,
                )
              : effectiveAntiDeriv.substitute(variable, fromExpr);
          final diff = (upper - lower).simplify(assumptions: assumptions);
          if (!diff.anyNode((n) => n is Limit || n == Constant.undefined)) {
            return diff;
          }
        } on Object {
          // Fall through to definite integral special cases or endpoint limit.
        }
        // Try one-sided limits at finite endpoints (e.g. int_0^1 ln(x) dx)
        try {
          final isAscending =
              (_evaluateBoundNumeric(fromExpr) ?? 0.0) <=
              (_evaluateBoundNumeric(toExpr) ?? 1.0);
          final upper = _isInfiniteBound(toExpr)
              ? effectiveAntiDeriv.limit(
                  variable,
                  toExpr,
                  assumptions: assumptions,
                )
              : effectiveAntiDeriv.limit(
                  variable,
                  toExpr,
                  direction: isAscending
                      ? LimitDirection.fromBelow
                      : LimitDirection.fromAbove,
                  assumptions: assumptions,
                );
          final lower = _isInfiniteBound(fromExpr)
              ? effectiveAntiDeriv.limit(
                  variable,
                  fromExpr,
                  assumptions: assumptions,
                )
              : effectiveAntiDeriv.limit(
                  variable,
                  fromExpr,
                  direction: isAscending
                      ? LimitDirection.fromAbove
                      : LimitDirection.fromBelow,
                  assumptions: assumptions,
                );
          final diff = (upper - lower).simplify(assumptions: assumptions);
          if (!diff.anyNode((n) => n is Limit || n == Constant.undefined)) {
            return diff;
          }
        } on Object {
          // Fall through to definite integral special cases.
        }
      }
    }

    final specialDef = _definiteIntegralSpecialCases(
      function.simplify(assumptions: assumptions),
      variable,
      fromExpr,
      toExpr,
      assumptions: assumptions,
    );
    if (specialDef != null) {
      return specialDef.simplify(assumptions: assumptions);
    }

    return Integral(
      function.simplify(assumptions: assumptions),
      variable,
      lower: fromExpr,
      upper: toExpr,
      isSimplified: true,
    );
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
      // Ignored.
    } on UnsupportedError {
      // Ignored.
    }
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
              // Ignored.
            } on UnsupportedError {
              // Ignored.
            }
          }
        }
      } on ArgumentError {
        // Ignored.
      } on UnsupportedError {
        // Ignored.
      } on StateError {
        // Ignored.
      }
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

Expr _boundToExpr(Object bound) => Expr.wrap(bound);

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
      if (base case Tanh(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final xVar = Variable(variable);
          return (xVar - Tanh(inner) / a).simplify();
        }
      }
    }
    // Higher trig/hyperbolic integer powers: sin^n, cos^n, sinh^n, cosh^n (3 <= n <= 10)
    if (exponent case IntegerNumber(asInt: final n?) when n >= 3 && n <= 10) {
      if (base case Sin(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final nExpr = IntegerNumber.of(n);
          final nMinus1 = IntegerNumber.of(n - 1);
          final nMinus2 = IntegerNumber.of(n - 2);
          final term1 = (-Pow(Sin(inner), nMinus1) * Cos(inner) / (nExpr * a))
              .simplify();
          final rem = _antiDerivative(
            Pow(Sin(inner), nMinus2).simplify(),
            variable,
          );
          if (!_hasUnevaluatedIntegral(rem, variable)) {
            return (term1 + (nMinus1 / nExpr) * rem).simplify();
          }
        }
      }
      if (base case Cos(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final nExpr = IntegerNumber.of(n);
          final nMinus1 = IntegerNumber.of(n - 1);
          final nMinus2 = IntegerNumber.of(n - 2);
          final term1 = (Pow(Cos(inner), nMinus1) * Sin(inner) / (nExpr * a))
              .simplify();
          final rem = _antiDerivative(
            Pow(Cos(inner), nMinus2).simplify(),
            variable,
          );
          if (!_hasUnevaluatedIntegral(rem, variable)) {
            return (term1 + (nMinus1 / nExpr) * rem).simplify();
          }
        }
      }
      if (base case Sinh(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final nExpr = IntegerNumber.of(n);
          final nMinus1 = IntegerNumber.of(n - 1);
          final nMinus2 = IntegerNumber.of(n - 2);
          final term1 = (Pow(Sinh(inner), nMinus1) * Cosh(inner) / (nExpr * a))
              .simplify();
          final rem = _antiDerivative(
            Pow(Sinh(inner), nMinus2).simplify(),
            variable,
          );
          if (!_hasUnevaluatedIntegral(rem, variable)) {
            return (term1 - (nMinus1 / nExpr) * rem).simplify();
          }
        }
      }
      if (base case Cosh(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final nExpr = IntegerNumber.of(n);
          final nMinus1 = IntegerNumber.of(n - 1);
          final nMinus2 = IntegerNumber.of(n - 2);
          final term1 = (Pow(Cosh(inner), nMinus1) * Sinh(inner) / (nExpr * a))
              .simplify();
          final rem = _antiDerivative(
            Pow(Cosh(inner), nMinus2).simplify(),
            variable,
          );
          if (!_hasUnevaluatedIntegral(rem, variable)) {
            return (term1 + (nMinus1 / nExpr) * rem).simplify();
          }
        }
      }
    }
    // Radical quadratic sqrt(a^2 - u^2) or sqrt(u^2 +- a^2)
    if (exponent == FractionNumber.half ||
        (exponent is RealNumber && exponent.value == 0.5)) {
      final radQuad = _tryRadicalQuadratic(base, variable);
      if (radQuad != null) return radQuad;
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

  // Form: c^(ax + b) or e^(ax + b) or Gaussian e^(-a*x^2 + b*x + c)
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
    if (base == Constant.e) {
      final gaussRes = _tryGaussianAntiderivative(exponent, variable);
      if (gaussRes != null) return gaussRes;
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

    // int c / cos(ax + b)^2 dx = (c / a) * tan(ax + b)
    if (right case Pow(base: Cos(expr: final inner), :final exponent)
        when exponent == IntegerNumber.two ||
            (exponent is RealNumber && exponent.value == 2.0)) {
      if (inner.matchLinear(variable) case (:final a, b: _)) {
        return ((left * Tan(inner)) / a).simplify();
      }
    }

    // int c / sin(ax + b)^2 dx = -(c / a) * (cos(ax + b) / sin(ax + b))
    if (right case Pow(base: Sin(expr: final inner), :final exponent)
        when exponent == IntegerNumber.two ||
            (exponent is RealNumber && exponent.value == 2.0)) {
      if (inner.matchLinear(variable) case (:final a, b: _)) {
        return ((-left * Cos(inner)) / (a * Sin(inner))).simplify();
      }
    }

    // int c / cosh(ax + b)^2 dx = (c / a) * tanh(ax + b)
    if (right case Pow(base: Cosh(expr: final inner), :final exponent)
        when exponent == IntegerNumber.two ||
            (exponent is RealNumber && exponent.value == 2.0)) {
      if (inner.matchLinear(variable) case (:final a, b: _)) {
        return ((left * Tanh(inner)) / a).simplify();
      }
    }

    // int c / sinh(ax + b)^2 dx = -(c / a) * (cosh(ax + b) / sinh(ax + b))
    if (right case Pow(base: Sinh(expr: final inner), :final exponent)
        when exponent == IntegerNumber.two ||
            (exponent is RealNumber && exponent.value == 2.0)) {
      if (inner.matchLinear(variable) case (:final a, b: _)) {
        return ((-left * Cosh(inner)) / (a * Sinh(inner))).simplify();
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
  // int u'(x) / sqrt(a + u(x)^2) dx = asinh(u(x) / sqrt(a))
  // int u'(x) / sqrt(u(x)^2 - a) dx = ln|u(x) + sqrt(u(x)^2 - a)|
  if (right case Pow(base: Add(terms: [final t0, final t1]), :final exponent)
      when exponent == FractionNumber.half ||
          (exponent is RealNumber && exponent.value == 0.5)) {
    final aConst = !t0.dependsOn(variable)
        ? t0
        : (!t1.dependsOn(variable) ? t1 : null);
    final varTerm = !t0.dependsOn(variable) ? t1 : t0;
    if (aConst != null) {
      if (_isPositiveConstant(aConst)) {
        final sqrtA = aConst == IntegerNumber.one
            ? IntegerNumber.one
            : Pow(aConst, FractionNumber.half).simplify();
        final negTerm = (-varTerm).simplify();
        if (_extractScaledSquareBase(negTerm, variable) case final u?
            when u.dependsOn(variable)) {
          final uPrime = u.derivative(variable).simplify();
          if (left.matchScalarMultiple(uPrime, variable) case final k?) {
            return Asin(u / sqrtA).scale(k);
          }
        }
        if (_extractScaledSquareBase(varTerm, variable) case final u?
            when u.dependsOn(variable)) {
          final uPrime = u.derivative(variable).simplify();
          if (left.matchScalarMultiple(uPrime, variable) case final k?) {
            return Asinh(u / sqrtA).scale(k);
          }
        }
      } else if (_isPositiveConstant((-aConst).simplify())) {
        if (_extractScaledSquareBase(varTerm, variable) case final u?
            when u.dependsOn(variable)) {
          final uPrime = u.derivative(variable).simplify();
          if (left.matchScalarMultiple(uPrime, variable) case final k?) {
            return Ln(Abs((u + right).simplify())).scale(k);
          }
        }
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

  // Higher-degree polynomial P(x) * vExpr (e.g. x^n * exp(ax+b), x^n * sin(ax+b), x^n * ln(x), x^n * exp(-a*x^2)):
  final degP = polynomialDegree(pExpr, variable);
  if (degP != null && degP >= 1 && degP <= 10) {
    // 1. P(x) * ln(a*x + b) where u = ln(a*x + b), dv = P(x) dx
    if (vExpr case Ln(:final expr)
        when degP >= 2 && expr.matchLinear(variable) != null) {
      final v = _antiDerivative(pExpr, variable);
      final uPrime = vExpr.derivative(variable).simplify();
      final remIntegrand = (v * uPrime).simplify();
      final remIntegral = _antiDerivative(remIntegrand, variable);
      if (!_hasUnevaluatedIntegral(v, variable) &&
          !_hasUnevaluatedIntegral(remIntegral, variable)) {
        return (v * vExpr - remIntegral).simplify();
      }
    }

    // 2. P(x) * exp(-a*x^2 + b*x + c) (Gaussian moments)
    if (vExpr case Pow(:final base, :final exponent) when base == Constant.e) {
      final expCoeffs = extractPolynomialCoefficients(exponent, variable);
      if (expCoeffs != null && maxPolynomialDegree(expCoeffs) == 2) {
        final a2 = expCoeffs[2] ?? IntegerNumber.zero;
        final a1 = expCoeffs[1] ?? IntegerNumber.zero;
        if (degP >= 2 && a1 == IntegerNumber.zero && _isNegativeConstant(a2)) {
          // Write P(x) = x * Q(x) + p0, and integrate x * Q(x) * exp(a2*x^2) via u = Q(x), dv = x*exp(a2*x^2) dx
          final xVar = Variable(variable);
          final (:quotient, :remainder) = pExpr.polynomialDivide(
            xVar,
            variable,
          );
          final dvAnti = (vExpr / (IntegerNumber.two * a2)).simplify();
          final qPrime = quotient.derivative(variable).simplify();
          final ibpRem = _antiDerivative(
            (qPrime * dvAnti).expand().simplify(),
            variable,
          );
          final rem0 = (remainder is Number && remainder.isZero)
              ? IntegerNumber.zero
              : _antiDerivative((remainder * vExpr).simplify(), variable);
          if (!_hasUnevaluatedIntegral(ibpRem, variable) &&
              !_hasUnevaluatedIntegral(rem0, variable)) {
            return (quotient * dvAnti - ibpRem + rem0).simplify();
          }
        }
      }
    }

    if (degP >= 2) {
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
      // Ignored.
    } on UnsupportedError {
      // Ignored.
    }
  }
  return false;
}

bool _isNegativeConstant(Expr expr) => _isPositiveConstant((-expr).simplify());

Expr? _tryGaussianAntiderivative(Expr exponent, String variable) {
  final coeffs = extractPolynomialCoefficients(exponent, variable);
  if (coeffs == null || maxPolynomialDegree(coeffs) != 2) return null;
  final a2 = coeffs[2] ?? IntegerNumber.zero;
  final a1 = coeffs[1] ?? IntegerNumber.zero;
  final a0 = coeffs[0] ?? IntegerNumber.zero;

  // Require negative leading coefficient a2 = -k where k > 0
  final k = (-a2).simplify();
  if (!_isPositiveConstant(k)) return null;

  final sqrtK = Pow(k, FractionNumber.half).simplify();
  final sqrtPi = Pow(Constant.pi, FractionNumber.half).simplify();
  final xVar = Variable(variable);

  if (a1 == IntegerNumber.zero && a0 == IntegerNumber.zero) {
    // int e^(-k*x^2) dx = (sqrt(pi) / (2 * sqrt(k))) * erf(sqrt(k) * x)
    return ((sqrtPi / (IntegerNumber.two * sqrtK)) * Erf(sqrtK * xVar))
        .simplify();
  }

  // Complete the square: -k * x^2 + a1 * x + a0 = -(sqrt(k)*x - a1/(2*sqrt(k)))^2 + (a0 + a1^2/(4*k))
  final shift = (a1 / (IntegerNumber.two * sqrtK)).simplify();
  final u = (sqrtK * xVar - shift).simplify();
  final constExp = (a0 + Pow(a1, IntegerNumber.two) / (IntegerNumber.of(4) * k))
      .simplify();
  final expScale = Pow(Constant.e, constExp).simplify();
  return ((expScale * sqrtPi / (IntegerNumber.two * sqrtK)) * Erf(u))
      .simplify();
}

Expr? _tryRadicalQuadratic(Expr base, String variable) {
  if (base case Add(terms: [final t0, final t1])) {
    final aConst = !t0.dependsOn(variable)
        ? t0
        : (!t1.dependsOn(variable) ? t1 : null);
    final varTerm = !t0.dependsOn(variable) ? t1 : t0;
    if (aConst == null) return null;

    final rad = Pow(base, FractionNumber.half).simplify();
    if (_isPositiveConstant(aConst)) {
      final sqrtA = Pow(aConst, FractionNumber.half).simplify();
      // 1. sqrt(a - u^2) where u = m*x + b
      final negVar = (-varTerm).simplify();
      if (_extractScaledSquareBase(negVar, variable) case final u?) {
        if (u.matchLinear(variable) case (a: final slope, b: _)) {
          return ((u * rad / IntegerNumber.two +
                      (aConst / IntegerNumber.two) * Asin(u / sqrtA)) /
                  slope)
              .simplify();
        }
      }
      // 2. sqrt(a + u^2) where u = m*x + b
      if (_extractScaledSquareBase(varTerm, variable) case final u?) {
        if (u.matchLinear(variable) case (a: final slope, b: _)) {
          return ((u * rad / IntegerNumber.two +
                      (aConst / IntegerNumber.two) * Asinh(u / sqrtA)) /
                  slope)
              .simplify();
        }
      }
    } else if (_isPositiveConstant((-aConst).simplify())) {
      // 3. sqrt(u^2 - a) where a = -aConst > 0 and u = m*x + b
      final posA = (-aConst).simplify();
      if (_extractScaledSquareBase(varTerm, variable) case final u?) {
        if (u.matchLinear(variable) case (a: final slope, b: _)) {
          return ((u * rad / IntegerNumber.two -
                      (posA / IntegerNumber.two) *
                          Ln(Abs((u + rad).simplify()))) /
                  slope)
              .simplify();
        }
      }
    }
  }
  return null;
}

bool _isOddIntegrandWithoutInteriorPoles(
  Expr function,
  String variable,
  Expr fromExpr,
  Expr toExpr, {
  Assumptions assumptions = Assumptions.none,
}) {
  final sFunc = function.simplify(assumptions: assumptions);
  final reflected = sFunc
      .substitute(variable, -Variable(variable))
      .simplify(assumptions: assumptions);
  if ((sFunc + reflected).expand().simplify(assumptions: assumptions) !=
      IntegerNumber.zero) {
    return false;
  }

  // Ensure no denominator vanishes on the interval
  final poles = _findDenominatorRoots(sFunc, variable);
  if (poles.isNotEmpty) {
    if (_isInfiniteBound(fromExpr) || _isInfiniteBound(toExpr)) {
      return false;
    }
    final numFrom = _evaluateBoundNumeric(fromExpr);
    final numTo = _evaluateBoundNumeric(toExpr);
    if (numFrom == null || numTo == null) return false;
    final low = numFrom < numTo ? numFrom : numTo;
    final high = numFrom < numTo ? numTo : numFrom;
    for (final pole in poles) {
      if (pole >= low - 1e-12 && pole <= high + 1e-12) {
        return false;
      }
    }
  }
  return true;
}

Expr? _definiteIntegralSpecialCases(
  Expr function,
  String variable,
  Expr fromExpr,
  Expr toExpr, {
  Assumptions assumptions = Assumptions.none,
}) {
  // Flip reversed bounds: int_a^b f(x) dx = -int_b^a f(x) dx when a > b
  if ((fromExpr == Constant.infinity) ||
      (toExpr == _negInfinity || toExpr == -Constant.infinity) ||
      (toExpr == IntegerNumber.zero && _isPositiveConstant(fromExpr))) {
    final flipped = _definiteIntegralSpecialCases(
      function,
      variable,
      toExpr,
      fromExpr,
      assumptions: assumptions,
    );
    return flipped != null
        ? (-flipped).simplify(assumptions: assumptions)
        : null;
  }

  // Extract constant factors independent of variable
  final rawFactors = function is Mul ? function.factors : [function];
  final (:constFactors, :varFactors) = partitionFactors(rawFactors, variable);
  if (constFactors.isNotEmpty && varFactors.isNotEmpty) {
    final constPart = constFactors.length == 1
        ? constFactors.first
        : Mul(constFactors).simplify(assumptions: assumptions);
    final varPart = varFactors.length == 1
        ? varFactors.first
        : Mul(varFactors).simplify(assumptions: assumptions);
    final inner = _definiteIntegralSpecialCases(
      varPart,
      variable,
      fromExpr,
      toExpr,
      assumptions: assumptions,
    );
    if (inner != null) {
      return (constPart * inner).simplify(assumptions: assumptions);
    }
  }

  // Even integrand over [-infty, infty] -> 2 * int_0^infty f(x) dx
  if ((fromExpr == _negInfinity || fromExpr == -Constant.infinity) &&
      toExpr == Constant.infinity) {
    final reflected = function
        .substitute(variable, -Variable(variable))
        .simplify(assumptions: assumptions);
    if ((function - reflected).expand().simplify(assumptions: assumptions) ==
        IntegerNumber.zero) {
      final halfInt = _definiteIntegralZeroToInfinity(
        function,
        variable,
        assumptions: assumptions,
      );
      if (halfInt != null) {
        return (IntegerNumber.two * halfInt).simplify(assumptions: assumptions);
      }
    }
  }

  // Domain [0, infty)
  if (fromExpr == IntegerNumber.zero && toExpr == Constant.infinity) {
    final res = _definiteIntegralZeroToInfinity(
      function,
      variable,
      assumptions: assumptions,
    );
    if (res != null) return res;
  }

  // Domain [0, pi/2] or [0, pi]
  final halfPi = (Constant.pi / IntegerNumber.two).simplify();
  if (fromExpr == IntegerNumber.zero &&
      (toExpr == halfPi || toExpr == Constant.pi)) {
    final trigRes = _definiteIntegralTrigDomain(
      function,
      variable,
      toExpr,
      assumptions: assumptions,
    );
    if (trigRes != null) return trigRes;
  }

  // Domain [0, 1]
  if (fromExpr == IntegerNumber.zero && toExpr == IntegerNumber.one) {
    final unitRes = _definiteIntegralUnitInterval(
      function,
      variable,
      assumptions: assumptions,
    );
    if (unitRes != null) return unitRes;
  }

  return null;
}

Expr? _definiteIntegralZeroToInfinity(
  Expr function,
  String variable, {
  Assumptions assumptions = Assumptions.none,
}) {
  final xVar = Variable(variable);
  final (num, den) = splitNumeratorDenominator(function);

  // 1. Dirichlet integral: sin(a*x) / x -> pi/2 * sign(a)
  //    and sin(a*x)^2 / x^2 -> pi/2 * |a|
  if (den == xVar && num is Sin) {
    if (num.expr.matchLinear(variable) case (a: final slope, :final b)
        when b == IntegerNumber.zero) {
      return (Constant.pi / IntegerNumber.two * Sign(slope)).simplify(
        assumptions: assumptions,
      );
    }
  }
  if (den case Pow(base: final b, exponent: IntegerNumber(asInt: 2))
      when b == xVar) {
    if (num case Pow(
      base: Sin(expr: final inner),
      exponent: IntegerNumber(asInt: 2),
    )) {
      if (inner.matchLinear(variable) case (a: final slope, b: final shift)
          when shift == IntegerNumber.zero) {
        return (Constant.pi / IntegerNumber.two * Abs(slope)).simplify(
          assumptions: assumptions,
        );
      }
    }
  }

  // 2. Fresnel integrals: sin(a*x^2) or cos(a*x^2) -> 1/4 * sqrt(2*pi / |a|)
  if (function case Sin(expr: final inner) || Cos(expr: final inner)) {
    final coeffs = extractPolynomialCoefficients(inner, variable);
    if (coeffs != null &&
        maxPolynomialDegree(coeffs) == 2 &&
        (coeffs[1] ?? IntegerNumber.zero) == IntegerNumber.zero &&
        (coeffs[0] ?? IntegerNumber.zero) == IntegerNumber.zero) {
      final a2 = coeffs[2] ?? IntegerNumber.zero;
      final absA = Abs(a2).simplify(assumptions: assumptions);
      if (_isPositiveConstant(absA)) {
        final fresnelVal =
            (FractionNumber.quarter *
                    Pow(
                      (IntegerNumber.two * Constant.pi) / absA,
                      FractionNumber.half,
                    ))
                .simplify(assumptions: assumptions);
        return function is Sin
            ? (Sign(a2) * fresnelVal).simplify(assumptions: assumptions)
            : fresnelVal;
      }
    }
  }

  // 3. Euler Gamma integral: x^s * e^(-a*x) -> Gamma(s + 1) / a^(s + 1) for a > 0, s > -1
  final factors = function is Mul ? function.factors : [function];
  Expr? expSlope;
  Expr? xExponent;
  var validGamma = true;
  for (final f in factors) {
    if (expSlope == null && f is Pow && f.base == Constant.e) {
      if (f.exponent.matchLinear(variable) case (a: final slope, :final b)
          when b == IntegerNumber.zero) {
        final posA = (-slope).simplify(assumptions: assumptions);
        if (_isPositiveConstant(posA) ||
            (posA is Variable &&
                assumptions.domainOf(posA.name) == VariableDomain.positive)) {
          expSlope = posA;
          continue;
        }
      }
    }
    if (xExponent == null && f == xVar) {
      xExponent = IntegerNumber.one;
      continue;
    }
    if (xExponent == null &&
        f is Pow &&
        f.base == xVar &&
        !f.exponent.dependsOn(variable)) {
      xExponent = f.exponent;
      continue;
    }
    validGamma = false;
    break;
  }
  if (validGamma && expSlope != null) {
    final s = xExponent ?? IntegerNumber.zero;
    final sPlus1 = (s + IntegerNumber.one).simplify(assumptions: assumptions);
    if (_isPositiveConstant(sPlus1) ||
        (s is Variable &&
            assumptions.domainOf(s.name) == VariableDomain.positive)) {
      return (Gamma(sPlus1) / Pow(expSlope, sPlus1)).simplify(
        assumptions: assumptions,
      );
    }
  }

  // 4. Generalized Gaussian / Gamma integral: x^s * e^(-a*x^2) -> 1/2 * Gamma((s+1)/2) / a^((s+1)/2)
  Expr? gaussCoeff;
  Expr? gaussXExp;
  var validGaussGamma = true;
  for (final f in factors) {
    if (gaussCoeff == null && f is Pow && f.base == Constant.e) {
      final coeffs = extractPolynomialCoefficients(f.exponent, variable);
      if (coeffs != null &&
          maxPolynomialDegree(coeffs) == 2 &&
          (coeffs[1] ?? IntegerNumber.zero) == IntegerNumber.zero &&
          (coeffs[0] ?? IntegerNumber.zero) == IntegerNumber.zero) {
        final posA = (-(coeffs[2] ?? IntegerNumber.zero)).simplify(
          assumptions: assumptions,
        );
        if (_isPositiveConstant(posA)) {
          gaussCoeff = posA;
          continue;
        }
      }
    }
    if (gaussXExp == null && f == xVar) {
      gaussXExp = IntegerNumber.one;
      continue;
    }
    if (gaussXExp == null &&
        f is Pow &&
        f.base == xVar &&
        !f.exponent.dependsOn(variable)) {
      gaussXExp = f.exponent;
      continue;
    }
    validGaussGamma = false;
    break;
  }
  if (validGaussGamma && gaussCoeff != null) {
    final s = gaussXExp ?? IntegerNumber.zero;
    final alpha = ((s + IntegerNumber.one) / IntegerNumber.two).simplify(
      assumptions: assumptions,
    );
    if (_isPositiveConstant(alpha)) {
      return (FractionNumber.half * Gamma(alpha) / Pow(gaussCoeff, alpha))
          .simplify(assumptions: assumptions);
    }
  }

  // 5. Bose-Einstein & Fermi-Dirac integrals:
  //    int_0^infty x^(s-1) / (e^x - 1) dx = Gamma(s) * zeta(s)
  //    int_0^infty x^(s-1) / (e^x + 1) dx = Gamma(s) * eta(s)
  if (den case Add(terms: [final d0, final d1])) {
    final expTerm = d0 is Pow && d0.base == Constant.e && d0.exponent == xVar
        ? d0
        : (d1 is Pow && d1.base == Constant.e && d1.exponent == xVar
              ? d1
              : null);
    final constTerm = expTerm == d0 ? d1 : d0;
    if (expTerm != null &&
        (constTerm == IntegerNumber.negativeOne ||
            constTerm == IntegerNumber.one)) {
      int? s;
      if (num == xVar) {
        s = 2;
      } else if (num
          case Pow(base: final b, exponent: IntegerNumber(asInt: final m?))
          when b == xVar && m >= 1 && m.isOdd && m <= 15) {
        s = m + 1;
      }
      if (s != null && s.isEven) {
        final factSMinus1 = IntegerNumber(Integer.from(s - 1).factorial());
        final zetaS = _evenZetaIntegralValue(s);
        if (constTerm == IntegerNumber.negativeOne) {
          return (factSMinus1 * zetaS).simplify(assumptions: assumptions);
        } else {
          final etaFactor =
              (IntegerNumber.one -
                      Pow(IntegerNumber.two, IntegerNumber.of(1 - s)))
                  .simplify();
          return (factSMinus1 * etaFactor * zetaS).simplify(
            assumptions: assumptions,
          );
        }
      }
    }
  }

  return null;
}

Expr? _definiteIntegralTrigDomain(
  Expr function,
  String variable,
  Expr toExpr, {
  Assumptions assumptions = Assumptions.none,
}) {
  final xVar = Variable(variable);
  final halfPi = (Constant.pi / IntegerNumber.two).simplify();

  // 1. Euler's log-sine / log-cosine integrals:
  //    int_0^(pi/2) ln(sin(x)) dx = int_0^(pi/2) ln(cos(x)) dx = -pi/2 * ln(2)
  //    int_0^pi ln(sin(x)) dx = -pi * ln(2)
  if (function case Ln(expr: Sin(expr: final inner)) when inner == xVar) {
    if (toExpr == halfPi) {
      return (-halfPi * Ln(IntegerNumber.two)).simplify(
        assumptions: assumptions,
      );
    }
    if (toExpr == Constant.pi) {
      return (-Constant.pi * Ln(IntegerNumber.two)).simplify(
        assumptions: assumptions,
      );
    }
  }
  if (function case Ln(expr: Cos(expr: final inner))
      when inner == xVar && toExpr == halfPi) {
    return (-halfPi * Ln(IntegerNumber.two)).simplify(assumptions: assumptions);
  }

  // 2. Wallis / Beta trigonometric integrals on [0, pi/2]:
  //    int_0^(pi/2) sin(x)^m * cos(x)^n dx = 1/2 * Beta((m+1)/2, (n+1)/2)
  if (toExpr == halfPi) {
    final factors = function is Mul ? function.factors : [function];
    Expr mExp = IntegerNumber.zero;
    Expr nExp = IntegerNumber.zero;
    var validWallis = true;
    for (final f in factors) {
      if (f case Sin(expr: final inner) when inner == xVar) {
        mExp = (mExp + IntegerNumber.one).simplify();
        continue;
      }
      if (f case Cos(expr: final inner) when inner == xVar) {
        nExp = (nExp + IntegerNumber.one).simplify();
        continue;
      }
      if (f case Pow(base: Sin(expr: final inner), :final exponent)
          when inner == xVar && !exponent.dependsOn(variable)) {
        mExp = (mExp + exponent).simplify();
        continue;
      }
      if (f case Pow(base: Cos(expr: final inner), :final exponent)
          when inner == xVar && !exponent.dependsOn(variable)) {
        nExp = (nExp + exponent).simplify();
        continue;
      }
      validWallis = false;
      break;
    }
    if (validWallis &&
        (mExp != IntegerNumber.zero || nExp != IntegerNumber.zero)) {
      final aArg = ((mExp + IntegerNumber.one) / IntegerNumber.two).simplify();
      final bArg = ((nExp + IntegerNumber.one) / IntegerNumber.two).simplify();
      if (_isPositiveConstant(aArg) && _isPositiveConstant(bArg)) {
        return (FractionNumber.half * Beta(aArg, bArg)).simplify(
          assumptions: assumptions,
        );
      }
    }
  }

  return null;
}

Expr? _definiteIntegralUnitInterval(
  Expr function,
  String variable, {
  Assumptions assumptions = Assumptions.none,
}) {
  final xVar = Variable(variable);
  final (num, den) = splitNumeratorDenominator(function);

  // 1. Logarithmic zeta/eta integrals on [0, 1]:
  //    int_0^1 ln(x) / (1 - x) dx = -pi^2 / 6
  //    int_0^1 ln(x) / (1 + x) dx = -pi^2 / 12
  //    int_0^1 ln(1 + x) / x dx = pi^2 / 12
  //    int_0^1 ln(1 - x) / x dx = -pi^2 / 6
  if (num case Ln(expr: final lnArg) when lnArg == xVar) {
    if ((den - (IntegerNumber.one - xVar)).expand().simplify() ==
        IntegerNumber.zero) {
      return (-Pow(Constant.pi, IntegerNumber.two) / IntegerNumber.of(6))
          .simplify(assumptions: assumptions);
    }
    if ((den - (IntegerNumber.one + xVar)).expand().simplify() ==
        IntegerNumber.zero) {
      return (-Pow(Constant.pi, IntegerNumber.two) / IntegerNumber.of(12))
          .simplify(assumptions: assumptions);
    }
  }
  if (den == xVar && num is Ln) {
    if ((num.expr - (IntegerNumber.one + xVar)).expand().simplify() ==
        IntegerNumber.zero) {
      return (Pow(Constant.pi, IntegerNumber.two) / IntegerNumber.of(12))
          .simplify(assumptions: assumptions);
    }
    if ((num.expr - (IntegerNumber.one - xVar)).expand().simplify() ==
        IntegerNumber.zero) {
      return (-Pow(Constant.pi, IntegerNumber.two) / IntegerNumber.of(6))
          .simplify(assumptions: assumptions);
    }
  }

  // 2. Euler Beta integral on [0, 1]:
  //    int_0^1 x^(a - 1) * (1 - x)^(b - 1) dx = Beta(a, b)
  final factors = function is Mul ? function.factors : [function];
  Expr aMinus1 = IntegerNumber.zero;
  Expr bMinus1 = IntegerNumber.zero;
  var hasOneMinusX = false;
  var validBeta = true;
  for (final f in factors) {
    if (f == xVar) {
      aMinus1 = (aMinus1 + IntegerNumber.one).simplify();
      continue;
    }
    if (f case Pow(base: final b, :final exponent)
        when b == xVar && !exponent.dependsOn(variable)) {
      aMinus1 = (aMinus1 + exponent).simplify();
      continue;
    }
    if ((f - (IntegerNumber.one - xVar)).expand().simplify() ==
        IntegerNumber.zero) {
      bMinus1 = (bMinus1 + IntegerNumber.one).simplify();
      hasOneMinusX = true;
      continue;
    }
    if (f case Pow(:final base, :final exponent)
        when !exponent.dependsOn(variable) &&
            (base - (IntegerNumber.one - xVar)).expand().simplify() ==
                IntegerNumber.zero) {
      bMinus1 = (bMinus1 + exponent).simplify();
      hasOneMinusX = true;
      continue;
    }
    validBeta = false;
    break;
  }
  if (validBeta && hasOneMinusX) {
    final aArg = (aMinus1 + IntegerNumber.one).simplify();
    final bArg = (bMinus1 + IntegerNumber.one).simplify();
    if (_isPositiveConstant(aArg) && _isPositiveConstant(bArg)) {
      return Beta(aArg, bArg).simplify(assumptions: assumptions);
    }
  }

  return null;
}

Expr _evenZetaIntegralValue(int s) {
  // Returns zeta(s) for even s in {2, 4, 6, ...}
  final b = <RationalNumber>[IntegerNumber.one];
  for (var m = 1; m <= s; m++) {
    if (m == 1) {
      b.add(FractionNumber.negativeHalf);
      continue;
    }
    if (m.isOdd) {
      b.add(IntegerNumber.zero);
      continue;
    }
    var sum = IntegerNumber.zero as RationalNumber;
    for (var j = 0; j < m; j++) {
      if (b[j].isZero) continue;
      final binom = IntegerNumber(
        Integer.from(m + 1).binomial(Integer.from(j)),
      );
      sum = sum.addRational(binom.mulRational(b[j]));
    }
    b.add(sum.neg().divRational(IntegerNumber.of(m + 1)));
  }
  final bsAbs = b[s].abs();
  final twoPowS = Integer.big(BigInt.two.pow(s));
  final factS = Integer.from(s).factorial();
  final coeff = bsAbs.mulRational(
    RationalNumber.of(twoPowS, Integer.two * factS),
  );
  return (coeff * Pow(Constant.pi, IntegerNumber.of(s))).simplify();
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
