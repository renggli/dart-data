import '../algebra/approximate.dart';
import '../algebra/expand.dart';
import '../algebra/rational.dart';
import '../algebra/simplify.dart';
import '../algebra/term_accumulator.dart';
import '../assumptions.dart';
import '../ast.dart';
import '../compiler.dart';
import '../number/integer.dart';
import 'definite_integration.dart';
import 'differentiation.dart';
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
    return evaluateDefiniteIntegral(
      function,
      variable,
      from,
      to,
      assumptions: assumptions,
      antiDerivative: _antiDerivative,
    );
  }

  try {
    return _antiDerivative(
      function,
      variable,
      assumptions: assumptions,
    ).simplify(assumptions: assumptions);
  } on Object {
    return Integral(
      function.simplify(assumptions: assumptions),
      variable,
      isSimplified: true,
    );
  }
}

Expr _antiDerivative(
  Expr expr,
  String variable, {
  Assumptions assumptions = Assumptions.none,
  int depth = 0,
}) {
  final node = expr.simplify(assumptions: assumptions);

  if (!node.dependsOn(variable)) {
    if (node is Number && node.isZero) {
      return IntegerNumber.zero;
    }
    return (node * Variable(variable)).simplify(assumptions: assumptions);
  }

  final result = switch (node) {
    Variable(:final name) when name == variable =>
      (Pow(node, IntegerNumber.two) / IntegerNumber.two).simplify(
        assumptions: assumptions,
      ),
    Add(:final terms) => Add([
      for (final term in terms)
        _antiDerivative(term, variable, assumptions: assumptions),
    ]).simplify(assumptions: assumptions),
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
    Erfi(expr: final inner) =>
      _antiDerivErfi(inner, variable) ?? _unsupported(node, variable),
    FresnelS(expr: final inner) =>
      _antiDerivFresnelS(inner, variable) ?? _unsupported(node, variable),
    FresnelC(expr: final inner) =>
      _antiDerivFresnelC(inner, variable) ?? _unsupported(node, variable),
    ExpIntegralEi(expr: final inner) =>
      _antiDerivExpIntegralEi(inner, variable) ?? _unsupported(node, variable),
    LogIntegralLi(expr: final inner) =>
      _antiDerivLogIntegralLi(inner, variable) ?? _unsupported(node, variable),
    SinIntegralSi(expr: final inner) =>
      _antiDerivSinIntegralSi(inner, variable) ?? _unsupported(node, variable),
    CosIntegralCi(expr: final inner) =>
      _antiDerivCosIntegralCi(inner, variable) ?? _unsupported(node, variable),
    SinhIntegralShi(expr: final inner) =>
      _antiDerivSinhIntegralShi(inner, variable) ??
          _unsupported(node, variable),
    CoshIntegralChi(expr: final inner) =>
      _antiDerivCoshIntegralChi(inner, variable) ??
          _unsupported(node, variable),
    Asinh(expr: final inner) =>
      _antiDerivAsinh(inner, variable) ?? _unsupported(node, variable),
    Acosh(expr: final inner) =>
      _antiDerivAcosh(inner, variable) ?? _unsupported(node, variable),
    Atanh(expr: final inner) =>
      _antiDerivAtanh(inner, variable) ?? _unsupported(node, variable),
    Piecewise() => _antiDerivPiecewise(
      node,
      variable,
      assumptions: assumptions,
    ),
    Pow(:final base, :final exponent) => _antiDerivPow(
      base,
      exponent,
      node,
      variable,
      assumptions: assumptions,
    ),
    Mul() => _antiDerivMul(node, variable, assumptions: assumptions),
    _ => _unsupported(node, variable),
  };

  if (depth < 2 && node is! Add && _hasUnevaluatedIntegral(result, variable)) {
    if (_trySymbolicBinomialAffine(node, variable, assumptions: assumptions)
        case final symBinomRes?) {
      return symBinomRes;
    }
    if (_tryMixedTrigLogExp(node, variable, assumptions: assumptions)
        case final mixedRes?) {
      return mixedRes;
    }
    if (_tryAffineRadicalSubstitution(
          node,
          variable,
          assumptions: assumptions,
          depth: depth,
        )
        case final affineRes?) {
      return affineRes;
    }
    if (_tryFractionalLinearRadical(
          node,
          variable,
          assumptions: assumptions,
          depth: depth,
        )
        case final fracLinRes?) {
      return fracLinRes;
    }
    if (_tryChebyshevBinomial(
          node,
          variable,
          assumptions: assumptions,
          depth: depth,
        )
        case final chebRes?) {
      return chebRes;
    }
    if (_tryUSubstitution(
          node,
          variable,
          assumptions: assumptions,
          depth: depth,
        )
        case final uSubRes?) {
      return uSubRes;
    }
    if (_tryRationalTrigSubstitution(
          node,
          variable,
          assumptions: assumptions,
          depth: depth,
        )
        case final trigSubRes?) {
      return trigSubRes;
    }
    if (_tryHyperbolicRationalSubstitution(
          node,
          variable,
          assumptions: assumptions,
          depth: depth,
        )
        case final hypSubRes?) {
      return hypSubRes;
    }
  }
  return result;
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

Expr? _matchReciprocalLinear(Expr inner, String variable) {
  final prod = (inner * Variable(variable)).simplify();
  return prod.dependsOn(variable) ? null : prod;
}

Expr? _antiDerivAsin(Expr inner, String variable) {
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
    return (xVar * Asin(inner) + c * Ln((xVar * (IntegerNumber.one + s)) / c))
        .simplify();
  }
  return null;
}

Expr? _antiDerivAcos(Expr inner, String variable) {
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
    return (xVar * Acos(inner) - c * Ln((xVar * (IntegerNumber.one + s)) / c))
        .simplify();
  }
  return null;
}

Expr? _antiDerivAtan(Expr inner, String variable) {
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

Expr? _antiDerivErfi(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) =>
        ((inner * Erfi(inner) -
                    Pow(Constant.e, Pow(inner, IntegerNumber.two)) /
                        Pow(Constant.pi, FractionNumber.half)) /
                a)
            .simplify(),
      null => null,
    };

Expr? _antiDerivFresnelS(Expr inner, String variable) =>
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

Expr? _antiDerivFresnelC(Expr inner, String variable) =>
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

Expr? _antiDerivExpIntegralEi(Expr inner, String variable) => switch (inner
    .matchLinear(variable)) {
  (:final a, b: _) =>
    ((inner * ExpIntegralEi(inner) - Pow(Constant.e, inner)) / a).simplify(),
  null => null,
};

Expr? _antiDerivLogIntegralLi(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) =>
        ((inner * LogIntegralLi(inner) -
                    ExpIntegralEi(IntegerNumber.two * Ln(inner))) /
                a)
            .simplify(),
      null => null,
    };

Expr? _antiDerivSinIntegralSi(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) =>
        ((inner * SinIntegralSi(inner) + Cos(inner)) / a).simplify(),
      null => null,
    };

Expr? _antiDerivCosIntegralCi(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) =>
        ((inner * CosIntegralCi(inner) - Sin(inner)) / a).simplify(),
      null => null,
    };

Expr? _antiDerivSinhIntegralShi(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) =>
        ((inner * SinhIntegralShi(inner) - Cosh(inner)) / a).simplify(),
      null => null,
    };

Expr? _antiDerivCoshIntegralChi(Expr inner, String variable) =>
    switch (inner.matchLinear(variable)) {
      (:final a, b: _) =>
        ((inner * CoshIntegralChi(inner) - Sinh(inner)) / a).simplify(),
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

Expr _antiDerivPiecewise(
  Piecewise expr,
  String variable, {
  Assumptions assumptions = Assumptions.none,
}) {
  final m = expr.branches.length;
  final rawG = <Expr>[
    for (var i = 0; i < m; i++)
      _antiDerivative(
        expr.branches[i].expr,
        variable,
        assumptions: assumptions,
      ),
  ];
  final rawOth = expr.otherwise != null
      ? _antiDerivative(expr.otherwise!, variable, assumptions: assumptions)
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

Expr _antiDerivPow(
  Expr base,
  Expr exponent,
  Expr original,
  String variable, {
  Assumptions assumptions = Assumptions.none,
}) {
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
      if (base case Tan(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final nMinus1 = IntegerNumber.of(n - 1);
          final nMinus2 = IntegerNumber.of(n - 2);
          final term1 = (Pow(Tan(inner), nMinus1) / (nMinus1 * a)).simplify();
          final rem = _antiDerivative(
            Pow(Tan(inner), nMinus2).simplify(),
            variable,
          );
          if (!_hasUnevaluatedIntegral(rem, variable)) {
            return (term1 - rem).simplify();
          }
        }
      }
      if (base case Tanh(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final nMinus1 = IntegerNumber.of(n - 1);
          final nMinus2 = IntegerNumber.of(n - 2);
          final term1 = (-Pow(Tanh(inner), nMinus1) / (nMinus1 * a)).simplify();
          final rem = _antiDerivative(
            Pow(Tanh(inner), nMinus2).simplify(),
            variable,
          );
          if (!_hasUnevaluatedIntegral(rem, variable)) {
            return (term1 + rem).simplify();
          }
        }
      }
    }
    // Powers of logarithms: ln(ax + b)^k for 2 <= k <= 6
    if (base case Ln(expr: final inner)) {
      if (exponent case IntegerNumber(asInt: final k?) when k >= 2 && k <= 6) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final kExpr = IntegerNumber.of(k);
          final term1 = ((inner / a) * original).simplify();
          final rem = _antiDerivative(
            Pow(base, IntegerNumber.of(k - 1)).simplify(),
            variable,
          );
          if (!_hasUnevaluatedIntegral(rem, variable)) {
            return (term1 - kExpr * rem).simplify();
          }
        }
      }
    }
    // Squares of inverse trig/hyperbolic functions: asin(ax+b)^2, acos(ax+b)^2, atan(ax+b)^2, ...
    if (exponent == IntegerNumber.two ||
        (exponent is RealNumber && exponent.value == 2.0)) {
      if (base is Asin ||
          base is Acos ||
          base is Atan ||
          base is Asinh ||
          base is Acosh ||
          base is Atanh) {
        final ibp = _tryIntegrationByParts(
          IntegerNumber.one,
          original,
          variable,
        );
        if (ibp != null) return ibp;
      }
    }
    // Radical quadratic sqrt(a^2 - u^2) or sqrt(u^2 +- a^2) and (Ax^2 + Bx + C)^(n/2)
    if (exponent == FractionNumber.half ||
        (exponent is RealNumber && exponent.value == 0.5)) {
      final radQuad = _tryRadicalQuadratic(base, variable);
      if (radQuad != null) return radQuad;
    }
    if (_halfIntExponent(exponent) case final halfExp?) {
      final quadRad = _tryQuadraticRadical(
        IntegerNumber.one,
        base,
        halfExp,
        variable,
      );
      if (quadRad != null) return quadRad;
    }
    if (exponent is IntegerNumber && exponent.value > Integer.one) {
      final expanded = original.expand().simplify(assumptions: assumptions);
      if (expanded != original) {
        return _antiDerivative(expanded, variable, assumptions: assumptions);
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

      // e^(a/x) -> x * e^(a/x) - a * Ei(a/x)
      final prod = (exponent * Variable(variable)).simplify();
      if (!prod.dependsOn(variable)) {
        return (Variable(variable) * original - prod * ExpIntegralEi(exponent))
            .simplify();
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

    // int c / sinh(ax + b) dx = (c / a) * ln|tanh((ax + b) / 2)|
    if (right case Sinh(expr: final inner)) {
      if (inner.matchLinear(variable) case (:final a, b: _)) {
        return ((left * Ln(Abs(Tanh(inner / IntegerNumber.two)))) / a)
            .simplify();
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

    // Higher negative trig/hyperbolic powers: sec^n, csc^n, sech^n, csch^n (3 <= n <= 10)
    if (right case Pow(:final base, exponent: IntegerNumber(asInt: final n?))
        when n >= 3 && n <= 10) {
      final nMinus1 = IntegerNumber.of(n - 1);
      final nMinus2 = IntegerNumber.of(n - 2);
      if (base case Cos(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final term1 = (Sin(inner) / (a * nMinus1 * Pow(Cos(inner), nMinus1)))
              .simplify();
          final rem = _tryAntiDerivDiv(
            IntegerNumber.one,
            Pow(Cos(inner), nMinus2).simplify(),
            variable,
          );
          if (rem != null) {
            return (left * (term1 + (nMinus2 / nMinus1) * rem)).simplify();
          }
        }
      }
      if (base case Sin(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final term1 = (-Cos(inner) / (a * nMinus1 * Pow(Sin(inner), nMinus1)))
              .simplify();
          final rem = _tryAntiDerivDiv(
            IntegerNumber.one,
            Pow(Sin(inner), nMinus2).simplify(),
            variable,
          );
          if (rem != null) {
            return (left * (term1 + (nMinus2 / nMinus1) * rem)).simplify();
          }
        }
      }
      if (base case Cosh(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final term1 =
              (Sinh(inner) / (a * nMinus1 * Pow(Cosh(inner), nMinus1)))
                  .simplify();
          final rem = _tryAntiDerivDiv(
            IntegerNumber.one,
            Pow(Cosh(inner), nMinus2).simplify(),
            variable,
          );
          if (rem != null) {
            return (left * (term1 + (nMinus2 / nMinus1) * rem)).simplify();
          }
        }
      }
      if (base case Sinh(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final term1 =
              (-Cosh(inner) / (a * nMinus1 * Pow(Sinh(inner), nMinus1)))
                  .simplify();
          final rem = _tryAntiDerivDiv(
            IntegerNumber.one,
            Pow(Sinh(inner), nMinus2).simplify(),
            variable,
          );
          if (rem != null) {
            return (left * (term1 - (nMinus2 / nMinus1) * rem)).simplify();
          }
        }
      }
    }

    // Weierstrass substitution for c / (A + B*sin(u) + C*cos(u))
    if (_tryWeierstrassSubstitution(left, right, variable)
        case final weierRes?) {
      return weierRes;
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
      } else if (!_isSyntacticallyNegative(delta)) {
        final sqrtDelta = Pow(delta, FractionNumber.half).simplify();
        return ((IntegerNumber.two * left / sqrtDelta) *
                Atan(twoAxPlusB / sqrtDelta))
            .simplify();
      } else {
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
        _isSymbolicPositive(rL)) {
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
      if (_isSymbolicPositive(aConst)) {
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
      } else if (_isSymbolicPositive((-aConst).simplify())) {
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

  // c / ln(ax + b) -> (c / a) * li(ax + b)
  if (!left.dependsOn(variable)) {
    if (right case Ln(expr: final inner)) {
      if (inner.matchLinear(variable) case (:final a, b: _)) {
        return ((left / a) * LogIntegralLi(inner)).simplify();
      }
    }
  }

  // c * ln(x) / (a*x + b) -> (c / a) * (ln(x) * ln(1 + a*x/b) + polylog(2, -a*x/b))
  if (left case Ln(expr: Variable(:final name)) when name == variable) {
    if (right.matchLinear(variable) case (:final a, :final b)
        when b != IntegerNumber.zero) {
      final ratio = (a * Variable(variable) / b).simplify();
      return ((Ln(Variable(variable)) * Ln(IntegerNumber.one + ratio) +
                  Polylog(IntegerNumber.two, -ratio)) /
              a)
          .simplify();
    }
  }

  // c * exp(a*x + b) / (c1*x + d)^k -> Ei reduction
  if (left case Pow(base: Constant.e, exponent: final expInner)) {
    if (expInner.matchLinear(variable) case (:final a, :final b)) {
      if (right.matchLinear(variable) case (a: final c1, b: final d1)) {
        final shift = (b - (a * d1) / c1).simplify();
        final eiArg = (a * right / c1).simplify();
        return (Pow(Constant.e, shift) * ExpIntegralEi(eiArg) / c1).simplify();
      }
      if (right
          case Pow(base: final rBase, exponent: IntegerNumber(asInt: final k?))
          when k >= 2 && k <= 8) {
        if (rBase.matchLinear(variable) case (a: final c1, b: _)) {
          final kMinus1 = IntegerNumber.of(k - 1);
          final term1 = (-left / (c1 * kMinus1 * Pow(rBase, kMinus1)))
              .simplify();
          final rem = _antiDerivative(
            (a * left / (c1 * kMinus1 * (k == 2 ? rBase : Pow(rBase, kMinus1))))
                .simplify(),
            variable,
            depth: 1,
          );
          if (!_hasUnevaluatedIntegral(rem, variable)) {
            return (term1 + rem).simplify();
          }
        }
      }
    }
  }

  // c * sin(ax)/x, cos(ax)/x, sinh(ax)/x, cosh(ax)/x, exp(ax+b)/x
  if (right is Variable && right.name == variable) {
    final (:constFactors, :varFactors) = partitionFactors(
      left is Mul ? left.factors : [left],
      variable,
    );
    if (varFactors case [final vf]) {
      final scale = switch (constFactors) {
        [] => IntegerNumber.one,
        [final single] => single,
        _ => Mul(constFactors).simplify(),
      };
      switch (vf) {
        case Sin(expr: final inner):
          if (inner.matchLinear(variable) case (a: _, b: final b)
              when b == IntegerNumber.zero) {
            return (scale * SinIntegralSi(inner)).simplify();
          }
        case Cos(expr: final inner):
          if (inner.matchLinear(variable) case (a: _, b: final b)
              when b == IntegerNumber.zero) {
            return (scale * CosIntegralCi(inner)).simplify();
          }
        case Sinh(expr: final inner):
          if (inner.matchLinear(variable) case (a: _, b: final b)
              when b == IntegerNumber.zero) {
            return (scale * SinhIntegralShi(inner)).simplify();
          }
        case Cosh(expr: final inner):
          if (inner.matchLinear(variable) case (a: _, b: final b)
              when b == IntegerNumber.zero) {
            return (scale * CoshIntegralChi(inner)).simplify();
          }
        case Pow(base: Constant.e, exponent: final expInner):
          if (expInner.matchLinear(variable) case (:final a, :final b)) {
            return (scale *
                    Pow(Constant.e, b) *
                    ExpIntegralEi(a * Variable(variable)))
                .simplify();
          }
        default:
          break;
      }
    }
  }

  // Quadratic radical denominator: (p*x + q) / (Ax^2 + Bx + C)^(k/2)
  if (right case Pow(:final base, :final exponent)) {
    if (_halfIntExponent(exponent) case final halfExp?) {
      final quadRad = _tryQuadraticRadical(left, base, -halfExp, variable);
      if (quadRad != null) return quadRad;
    }
  }

  // c / (x * sqrt(A*x^2 + C))
  if (!left.dependsOn(variable)) {
    if (right case Mul(factors: [final f0, final f1])) {
      final Variable? xFactor;
      final Pow? radFactor;
      if (f0 is Variable && f0.name == variable && f1 is Pow) {
        xFactor = f0;
        radFactor = f1;
      } else if (f1 is Variable && f1.name == variable && f0 is Pow) {
        xFactor = f1;
        radFactor = f0;
      } else {
        xFactor = null;
        radFactor = null;
      }
      if (xFactor != null &&
          radFactor != null &&
          _halfIntExponent(radFactor.exponent) == 1) {
        final coeffs = extractPolynomialCoefficients(radFactor.base, variable);
        if (coeffs != null &&
            maxPolynomialDegree(coeffs) == 2 &&
            (coeffs[1] == null || coeffs[1] == IntegerNumber.zero)) {
          final cConst = coeffs[0] ?? IntegerNumber.zero;
          if (_isSymbolicPositive(cConst)) {
            final sqrtC = Pow(cConst, FractionNumber.half).simplify();
            return ((-left / sqrtC) * Ln(Abs((sqrtC + radFactor) / xFactor)))
                .simplify();
          }
          final negC = (-cConst).simplify();
          if (_isSymbolicPositive(negC)) {
            final sqrtNegC = Pow(negC, FractionNumber.half).simplify();
            return ((left / sqrtNegC) * Atan(radFactor / sqrtNegC)).simplify();
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

  // Trigonometric quotients/powers: sin^p(u) / cos^q(u), cot^n(u), etc.
  if (_tryTrigPowerProduct(left, right, variable) case final trigQuot?) {
    return trigQuot;
  }

  // Linear trig quotient: (a1*sin(u) + b1*cos(u) + c1) / (a*sin(u) + b*cos(u) + c)
  if (_tryLinearTrigQuotient(left, right, variable) case final linTrigRes?) {
    return linTrigRes;
  }

  // Polynomial / (x^k * sqrt(Q)) or sqrt(Q) / x^k or x^m / sqrt(Q)
  if (_tryPolynomialOverSqrtQuadratic(left, right, variable)
      case final polySqrtRes?) {
    return polySqrtRes;
  }

  // Repeated quadratic denominator: P(x) / (Ax^2 + Bx + C)^m (m >= 2)
  if (right case Pow(base: final quad, exponent: IntegerNumber(asInt: final m?))
      when m >= 2 && m <= 10) {
    if (_tryRepeatedQuadratic(left, quad, m, variable) case final repRes?) {
      return repRes;
    }
  }

  // Rational functions P(x) / Q(x): polynomial division and partial fractions
  if (right.dependsOn(variable)) {
    final leftExp = left.expand().simplify();
    final rightExp = right.expand().simplify();
    final degLeft = polynomialDegree(leftExp, variable);
    final degRight = polynomialDegree(rightExp, variable);
    if (degLeft != null && degRight != null && degRight >= 1) {
      if (degLeft >= degRight && degRight <= 24) {
        final (:quotient, :remainder) = leftExp.polynomialDivide(
          rightExp,
          variable,
        );
        final qInt = _antiDerivative(quotient, variable);
        if (remainder is Number && remainder.isZero) {
          return qInt;
        }
        final rInt = _antiDerivative(
          (remainder / rightExp).simplify(),
          variable,
        );
        return (qInt + rInt).simplify();
      }
      if (degRight == 3) {
        if (_tryCubicBinomialDenominator(leftExp, rightExp, variable)
            case final cubRes?) {
          return cubRes;
        }
      }
      if (degRight == 4) {
        if (_trySophieGermainQuartic(leftExp, rightExp, variable)
            case final quartRes?) {
          return quartRes;
        }
        if (_tryBiquadraticDenominator(leftExp, rightExp, variable)
            case final biqRes?) {
          return biqRes;
        }
      }
      if (degRight >= 2) {
        if (_tryDistinctLinearPartialFractions(left, right, variable)
            case final pfRes?) {
          return pfRes;
        }
      }
      if (degRight >= 2 && degRight <= 12) {
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

Expr _antiDerivMul(
  Mul original,
  String variable, {
  Assumptions assumptions = Assumptions.none,
}) {
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
        : Mul(constFactors).simplify(assumptions: assumptions);
    final varPart = varFactors.length == 1
        ? varFactors.first
        : Mul(varFactors).simplify(assumptions: assumptions);
    return _antiDerivative(
      varPart,
      variable,
      assumptions: assumptions,
    ).scale(constPart);
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
  if (_tryTrigPowerProduct(original, IntegerNumber.one, variable)
      case final trigPowRes?) {
    return trigPowRes;
  }

  // 3c. Linear polynomial times quadratic radical: (px + q) * (Ax^2 + Bx + C)^(k/2)
  for (var i = 0; i < varFactors.length; i++) {
    if (varFactors[i] case Pow(:final base, :final exponent)) {
      if (_halfIntExponent(exponent) case final halfExp?) {
        final others = <Expr>[
          for (var j = 0; j < varFactors.length; j++)
            if (i != j) varFactors[j],
        ];
        final otherExpr = others.length == 1
            ? others.first
            : Mul(others).simplify();
        if (_tryQuadraticRadical(otherExpr, base, halfExp, variable)
            case final quadRes?) {
          return quadRes;
        }
      }
    }
  }

  // 3d. Polynomial times trig power or trig product: P(x) * sin^n(u), P(x) * sin(ax)*cos(bx)
  if (_tryPolyTrigPowerReduction(varFactors, variable)
      case final trigPolyRes?) {
    return trigPolyRes;
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
          : Mul(others).simplify(assumptions: assumptions);
      return Add([
        for (final t in terms)
          _antiDerivative(
            (t * otherExpr).simplify(assumptions: assumptions),
            variable,
            assumptions: assumptions,
          ),
      ]).simplify(assumptions: assumptions);
    }
  }

  // 6. Full polynomial expansion fallback (e.g. factored polynomials like (x-1)*(x-2)*(x+2)):
  if (polynomialDegree(original, variable) != null) {
    final expanded = original.expand().simplify(assumptions: assumptions);
    if (expanded != original) {
      return _antiDerivative(expanded, variable, assumptions: assumptions);
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

Expr? _tryIntegrationByParts(
  Expr pExpr,
  Expr vExpr,
  String variable, {
  int depth = 0,
}) {
  if (depth >= 4) return null;

  // Symbolic power times logarithm: x^n * ln(a*x)
  if (vExpr case Ln(expr: final inner)) {
    if (inner.matchLinear(variable) case (a: _, b: final b)
        when b == IntegerNumber.zero) {
      if (pExpr case Pow(base: Variable(:final name), exponent: final n)
          when name == variable && !n.dependsOn(variable)) {
        final nPlus1 = (n + IntegerNumber.one).simplify();
        if (nPlus1 is! Number || !nPlus1.isZero) {
          final xNP1 = Pow(pExpr.base, nPlus1);
          return (xNP1 * Ln(inner) / nPlus1 - xNP1 / (nPlus1 * nPlus1))
              .simplify();
        }
      }
    }
  }

  // Inverse trig / inverse hyperbolic IBP: u = f(g(x)) or f(g(x))^2, dv = pExpr dx
  final isInverseTrigOrHyp = switch (vExpr) {
    Asin() || Acos() || Atan() || Asinh() || Acosh() || Atanh() => true,
    Pow(
      base: Asin() || Acos() || Atan() || Asinh() || Acosh() || Atanh(),
      exponent: IntegerNumber(asInt: 2) || RealNumber(value: 2.0),
    ) =>
      true,
    _ => false,
  };
  if (isInverseTrigOrHyp) {
    final v = _antiDerivative(pExpr, variable, depth: 2);
    if (!_hasUnevaluatedIntegral(v, variable)) {
      final uPrime = vExpr.derivative(variable).simplify();
      final remIntegrand = (v * uPrime).simplify();
      final remIntegral = _antiDerivative(remIntegrand, variable, depth: 1);
      if (!_hasUnevaluatedIntegral(remIntegral, variable)) {
        return (v * vExpr - remIntegral).simplify();
      }
    }
  }
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

  // exp(a*x + b) * ln(c*x + d)
  if (pExpr case Pow(base: Constant.e, exponent: final expInner)) {
    if (expInner.matchLinear(variable) case (a: final a, b: _)) {
      if (vExpr case Ln(expr: final lnInner)
          when lnInner.matchLinear(variable) != null) {
        final v = (pExpr / a).simplify();
        final rem = _antiDerivative(
          (v * vExpr.derivative(variable)).simplify(),
          variable,
          depth: 1,
        );
        if (!_hasUnevaluatedIntegral(rem, variable)) {
          return (v * vExpr - rem).simplify();
        }
      }
    }
  }

  final linP = pExpr.matchLinear(variable);
  if (linP != null) {
    final p = linP.a;
    final linRes = switch (vExpr) {
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
    if (linRes != null) return linRes;
  }

  // Higher-degree polynomial P(x) * vExpr (e.g. x^n * exp(ax+b), x^n * sin(ax+b), x^n * ln(x), x^n * exp(-a*x^2)):
  final degP = polynomialDegree(pExpr, variable);
  if (degP != null && degP >= 1 && degP <= 10) {
    // 1. P(x) * ln(a*x + b)^k where u = ln(a*x + b)^k, dv = P(x) dx
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
    if (vExpr
        case Pow(
          base: Ln(expr: final inner),
          exponent: IntegerNumber(asInt: final k?),
        )
        when k >= 1 && k <= 5 && inner.matchLinear(variable) != null) {
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
    value == 2.0 ? base : Pow(base, RealNumber(value / 2.0)),
  _ => null,
};

bool _isPositiveConstant(Expr expr) => isPositiveConstant(expr);

bool _isNegativeConstant(Expr expr) => isNegativeConstant(expr);

bool _hasUnevaluatedIntegral(Expr expr, String variable) =>
    hasUnevaluatedIntegral(expr, variable);

Expr? _tryGaussianAntiderivative(Expr exponent, String variable) {
  final coeffs = extractPolynomialCoefficients(exponent, variable);
  if (coeffs == null || maxPolynomialDegree(coeffs) != 2) return null;
  final a2 = coeffs[2] ?? IntegerNumber.zero;
  final a1 = coeffs[1] ?? IntegerNumber.zero;
  final a0 = coeffs[0] ?? IntegerNumber.zero;

  // Positive leading coefficient a2 > 0 -> erfi
  if (_isPositiveConstant(a2)) {
    final sqrtA2 = Pow(a2, FractionNumber.half).simplify();
    final sqrtPi = Pow(Constant.pi, FractionNumber.half).simplify();
    final xVar = Variable(variable);
    if (a1 == IntegerNumber.zero && a0 == IntegerNumber.zero) {
      return ((sqrtPi / (IntegerNumber.two * sqrtA2)) * Erfi(sqrtA2 * xVar))
          .simplify();
    }
    final shift = (a1 / (IntegerNumber.two * sqrtA2)).simplify();
    final u = (sqrtA2 * xVar + shift).simplify();
    final constExp =
        (a0 - Pow(a1, IntegerNumber.two) / (IntegerNumber.of(4) * a2))
            .simplify();
    final expScale = Pow(Constant.e, constExp).simplify();
    return ((expScale * sqrtPi / (IntegerNumber.two * sqrtA2)) * Erfi(u))
        .simplify();
  }

  // Require negative leading coefficient a2 = -k where k > 0 -> erf
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
    if (_isSymbolicPositive(aConst)) {
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
    } else if (_isSymbolicPositive((-aConst).simplify())) {
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
      if (_isSymbolicPositive(constPart)) {
        if (_extractSquareBase(varPart) case final sq?) {
          return (Pow(constPart, FractionNumber.half).simplify() * sq)
              .simplify();
        }
      }
    }
  }
  return null;
}

bool _isSyntacticallyNegative(Expr expr) => switch (expr) {
  RealNumeric(:final sign) => sign < 0,
  Mul(:final factors) => factors.where(_isSyntacticallyNegative).length.isOdd,
  _ => false,
};

bool _isSymbolicPositive(Expr expr) {
  if (expr is RealNumeric) return expr.sign > 0;
  if (expr.freeVariables.isEmpty) return isPositiveConstant(expr);
  return !_isSyntacticallyNegative(expr);
}

int? _halfIntExponent(Expr exponent) {
  if (exponent case FractionNumber(:final numerator, denominator: final den)
      when den == Integer.two && numerator.isOdd) {
    final value = numerator.asInt;
    if (value != null && value.abs() <= 15) return value;
  }
  if (exponent is RealNumber) {
    final doubled = exponent.value * 2;
    if (doubled == doubled.roundToDouble() &&
        doubled.toInt().isOdd &&
        doubled.abs() <= 15) {
      return doubled.toInt();
    }
  }
  return null;
}

Expr? _tryQuadraticRadical(
  Expr numerator,
  Expr quad,
  int halfExp,
  String variable,
) {
  final numCoeffs = extractPolynomialCoefficients(numerator, variable);
  if (numCoeffs == null || maxPolynomialDegree(numCoeffs) > 1) return null;
  final p = numCoeffs[1] ?? IntegerNumber.zero;
  final q = numCoeffs[0] ?? IntegerNumber.zero;

  final quadCoeffs = extractPolynomialCoefficients(quad, variable);
  if (quadCoeffs == null || maxPolynomialDegree(quadCoeffs) != 2) return null;
  final a = quadCoeffs[2] ?? IntegerNumber.zero;
  final b = quadCoeffs[1] ?? IntegerNumber.zero;
  final c = quadCoeffs[0] ?? IntegerNumber.zero;

  if (p == IntegerNumber.zero) {
    final rem = _tryQuadraticRadicalConst(quad, a, b, c, halfExp, variable);
    return rem == null ? null : (q * rem).simplify();
  }

  final twoA = (IntegerNumber.two * a).simplify();
  final leadTerm =
      (p / (a * IntegerNumber.of(halfExp + 2))) *
      Pow(quad, FractionNumber(Integer(halfExp + 2), Integer.two));
  final qRem = (q - (p * b) / twoA).simplify();
  if (qRem == IntegerNumber.zero) return leadTerm.simplify();

  final rem = _tryQuadraticRadicalConst(quad, a, b, c, halfExp, variable);
  if (rem == null) return null;
  return (leadTerm + qRem * rem).simplify();
}

Expr? _tryQuadraticRadicalConst(
  Expr quad,
  Expr a,
  Expr b,
  Expr c,
  int halfExp,
  String variable,
) {
  final twoA = (IntegerNumber.two * a).simplify();
  final twoAxPlusB = (twoA * Variable(variable) + b).simplify();
  final disc = (const IntegerNumber(Integer(4)) * a * c - b * b).simplify();

  if (halfExp == -1) {
    if (disc == IntegerNumber.zero) return null;
    if (_isSyntacticallyNegative(a) || isNegativeConstant(a)) {
      final negA = (-a).simplify();
      final sqrtNegA = Pow(negA, FractionNumber.half).simplify();
      final b2Minus4ac = (-disc).simplify();
      final sqrtDisc = Pow(b2Minus4ac, FractionNumber.half).simplify();
      final arg = ((-twoAxPlusB) / sqrtDisc).simplify();
      return (Asin(arg) / sqrtNegA).simplify();
    }
    final sqrtA = Pow(a, FractionNumber.half).simplify();
    if (_isSyntacticallyNegative(disc) || isNegativeConstant(disc)) {
      final rad = Pow(quad, FractionNumber.half).simplify();
      final logArg = (twoAxPlusB + IntegerNumber.two * sqrtA * rad).simplify();
      return (Ln(Abs(logArg)) / sqrtA).simplify();
    }
    final sqrtDisc = Pow(disc, FractionNumber.half).simplify();
    final arg = (twoAxPlusB / sqrtDisc).simplify();
    return (Asinh(arg) / sqrtA).simplify();
  }

  if (halfExp == -3) {
    if (disc == IntegerNumber.zero) return null;
    final rad = Pow(quad, FractionNumber.half).simplify();
    return ((IntegerNumber.two * twoAxPlusB) / (disc * rad)).simplify();
  }

  if (halfExp <= -5) {
    if (disc == IntegerNumber.zero) return null;
    final m = -halfExp;
    final prev = _tryQuadraticRadicalConst(
      quad,
      a,
      b,
      c,
      halfExp + 2,
      variable,
    );
    if (prev == null) return null;
    final mMinus2 = IntegerNumber.of(m - 2);
    final mMinus3 = IntegerNumber.of(m - 3);
    final denom = (mMinus2 * disc).simplify();
    final term1 =
        (IntegerNumber.two * twoAxPlusB) /
        (denom * Pow(quad, FractionNumber(Integer(m - 2), Integer.two)));
    final term2 =
        (const IntegerNumber(Integer(4)) * a * mMinus3 / denom) * prev;
    return (term1 + term2).simplify();
  }

  if (halfExp >= 1) {
    final prev = _tryQuadraticRadicalConst(
      quad,
      a,
      b,
      c,
      halfExp - 2,
      variable,
    );
    if (prev == null) return null;
    final nPlus1 = IntegerNumber.of(halfExp + 1);
    final term1 =
        (twoAxPlusB *
            Pow(quad, FractionNumber(Integer(halfExp), Integer.two))) /
        (twoA * nPlus1);
    final term2 =
        (IntegerNumber.of(halfExp) *
            disc /
            (const IntegerNumber(Integer(4)) * a * nPlus1)) *
        prev;
    return (term1 + term2).simplify();
  }

  return null;
}

int _gcdInt(int a, int b) {
  var x = a.abs();
  var y = b.abs();
  while (y != 0) {
    final t = x % y;
    x = y;
    y = t;
  }
  return x;
}

int _lcmInt(int a, int b) => (a * b) ~/ _gcdInt(a, b);

({int p, int q})? _fractionalExponent(Expr exponent) {
  if (exponent case FractionNumber(:final numerator, :final denominator)) {
    final p = numerator.asInt;
    final q = denominator.asInt;
    if (p != null && q != null && q >= 2 && q <= 6) return (p: p, q: q);
  }
  if (exponent is RealNumber && exponent.value.abs() == 0.5) {
    return (p: exponent.value > 0 ? 1 : -1, q: 2);
  }
  return null;
}

void _collectAffineRadicals(
  Expr node,
  String variable,
  List<({Expr base, int p, int q})> out,
) {
  if (node case Pow(:final base, :final exponent)) {
    if (base.dependsOn(variable) && base.matchLinear(variable) != null) {
      if (_fractionalExponent(exponent) case (:final p, :final q)) {
        out.add((base: base, p: p, q: q));
        return;
      }
    }
  }
  node.mapChildren((child) {
    _collectAffineRadicals(child, variable, out);
    return child;
  });
}

Expr _replaceAffineRadical(
  Expr node,
  Expr targetBase,
  String variable,
  Variable uVar,
  int n,
  Expr a,
  Expr b,
) {
  if (node case Pow(:final base, :final exponent) when base == targetBase) {
    if (_fractionalExponent(exponent) case (:final p, :final q)) {
      return Pow(uVar, IntegerNumber.of((p * n) ~/ q));
    }
  }
  if (node is Variable && node.name == variable) {
    return ((Pow(uVar, IntegerNumber.of(n)) - b) / a).simplify();
  }
  return node.mapChildren(
    (child) =>
        _replaceAffineRadical(child, targetBase, variable, uVar, n, a, b),
  );
}

Expr? _tryAffineRadicalSubstitution(
  Expr expr,
  String variable, {
  Assumptions assumptions = Assumptions.none,
  int depth = 0,
}) {
  final radicals = <({Expr base, int p, int q})>[];
  _collectAffineRadicals(expr, variable, radicals);
  if (radicals.isEmpty) return null;

  final firstBase = radicals.first.base;
  if (!radicals.every((r) => r.base == firstBase)) return null;
  final linear = firstBase.matchLinear(variable);
  if (linear == null) return null;
  final (:a, :b) = linear;

  var n = 1;
  for (final r in radicals) {
    n = _lcmInt(n, r.q);
    if (n > 6) return null;
  }
  if (n < 2) return null;

  final uName = '_u$depth';
  final uVar = Variable(uName);
  final replaced = _replaceAffineRadical(
    expr,
    firstBase,
    variable,
    uVar,
    n,
    a,
    b,
  );
  final dx = (IntegerNumber.of(n) * Pow(uVar, IntegerNumber.of(n - 1))) / a;
  final transformed = (replaced * dx).expand().simplify(
    assumptions: assumptions,
  );
  if (transformed.dependsOn(variable)) return null;

  final uAntideriv = _antiDerivative(
    transformed,
    uName,
    assumptions: assumptions,
    depth: depth + 1,
  );
  if (_hasUnevaluatedIntegral(uAntideriv, uName)) return null;

  final backSub = Pow(firstBase, FractionNumber(Integer.one, Integer(n)));
  return uAntideriv
      .substitute(uName, backSub)
      .simplify(assumptions: assumptions);
}

Expr? _tryChebyshevBinomial(
  Expr expr,
  String variable, {
  Assumptions assumptions = Assumptions.none,
  int depth = 0,
}) {
  final factors = expr is Mul ? expr.factors : [expr];
  var constScale = IntegerNumber.one as Expr;
  var m = 0;
  Pow? binomPow;

  for (final f in factors) {
    if (!f.dependsOn(variable)) {
      constScale = (constScale * f).simplify();
      continue;
    }
    if (f is Variable && f.name == variable) {
      m += 1;
      continue;
    }
    if (f case Pow(base: Variable(:final name), :final exponent)
        when name == variable) {
      if (exponent case IntegerNumber(:final asInt) when asInt != null) {
        m += asInt;
        continue;
      }
      return null;
    }
    if (f is Pow && binomPow == null) {
      binomPow = f;
      continue;
    }
    return null;
  }

  if (binomPow == null) return null;
  final fracExp = _fractionalExponent(binomPow.exponent);
  if (fracExp == null) return null;
  final (:p, :q) = fracExp;

  final baseCoeffs = extractPolynomialCoefficients(binomPow.base, variable);
  if (baseCoeffs == null) return null;
  final n = maxPolynomialDegree(baseCoeffs);
  if (n < 2) return null;
  for (var deg = 1; deg < n; deg++) {
    if (baseCoeffs[deg] != null && baseCoeffs[deg] != IntegerNumber.zero) {
      return null;
    }
  }
  final a = baseCoeffs[0] ?? IntegerNumber.zero;
  final b = baseCoeffs[n] ?? IntegerNumber.zero;
  if (a == IntegerNumber.zero || b == IntegerNumber.zero) return null;

  final uName = '_u$depth';
  final uVar = Variable(uName);

  // Case 1: (m + 1) / n is a positive integer k
  if ((m + 1) > 0 && (m + 1) % n == 0) {
    final k = (m + 1) ~/ n;
    if (k <= 8) {
      final transformed =
          (constScale *
                  (IntegerNumber.one / (IntegerNumber.of(n) * b)) *
                  Pow((uVar - a) / b, IntegerNumber.of(k - 1)) *
                  Pow(uVar, FractionNumber(Integer(p), Integer(q))))
              .expand()
              .simplify(assumptions: assumptions);
      final uAntideriv = _antiDerivative(
        transformed,
        uName,
        assumptions: assumptions,
        depth: depth + 1,
      );
      if (!_hasUnevaluatedIntegral(uAntideriv, uName)) {
        return uAntideriv
            .substitute(uName, binomPow.base)
            .simplify(assumptions: assumptions);
      }
    }
  }

  // Case 2: (m + 1) / n + p / q is an integer r
  final numSum = (m + 1) * q + p * n;
  final denProd = n * q;
  if (numSum % denProd == 0) {
    final r = numSum ~/ denProd;
    if (r.abs() <= 6) {
      final transformed =
          (constScale *
                  (-IntegerNumber.of(q) / (IntegerNumber.of(n) * a)) *
                  Pow(uVar, IntegerNumber.of(q - 1 + p)) *
                  Pow(
                    (Pow(uVar, IntegerNumber.of(q)) - b) / a,
                    IntegerNumber.of(-(r + 1)),
                  ))
              .expand()
              .simplify(assumptions: assumptions);
      final uAntideriv = _antiDerivative(
        transformed,
        uName,
        assumptions: assumptions,
        depth: depth + 1,
      );
      if (!_hasUnevaluatedIntegral(uAntideriv, uName)) {
        final backSub = Pow(
          (a * Pow(Variable(variable), IntegerNumber.of(-n)) + b).simplify(),
          FractionNumber(Integer.one, Integer(q)),
        );
        return uAntideriv
            .substitute(uName, backSub)
            .simplify(assumptions: assumptions);
      }
    }
  }

  return null;
}

void _collectUCandidates(Expr node, String variable, Set<Expr> out) {
  if (!node.dependsOn(variable)) return;
  switch (node) {
    case Sin(:final expr) ||
        Cos(:final expr) ||
        Tan(:final expr) ||
        Asin(:final expr) ||
        Acos(:final expr) ||
        Atan(:final expr) ||
        Sinh(:final expr) ||
        Cosh(:final expr) ||
        Tanh(:final expr) ||
        Asinh(:final expr) ||
        Acosh(:final expr) ||
        Atanh(:final expr) ||
        Ln(:final expr) ||
        Erf(:final expr) ||
        Erfc(:final expr):
      if (node is Sin ||
          node is Cos ||
          node is Tan ||
          node is Ln ||
          node is Atan ||
          node is Asin ||
          node is Acos) {
        out.add(node);
      }
      if (expr is! Variable || expr.name != variable) {
        out.add(expr);
      }
      _collectUCandidates(expr, variable, out);
    case Pow(:final base, :final exponent):
      if (base == Constant.e && exponent.dependsOn(variable)) {
        out.add(node);
        if (exponent is! Variable || exponent.name != variable) {
          out.add(exponent);
        }
      } else {
        if (base.dependsOn(variable) &&
            (base is! Variable || base.name != variable)) {
          out.add(base);
        }
        if (exponent.dependsOn(variable) &&
            (base.dependsOn(variable) || _isValidExponentialBase(base))) {
          out.add(node);
        }
      }
      _collectUCandidates(base, variable, out);
      _collectUCandidates(exponent, variable, out);
    default:
      node.mapChildren((child) {
        _collectUCandidates(child, variable, out);
        return child;
      });
  }
}

Expr _expandDoubleAngleTrig(Expr node) {
  if (node case Sin(:final expr)) {
    if (expr case Mul(factors: [IntegerNumber(asInt: 2), final inner])) {
      return IntegerNumber.two * Sin(inner) * Cos(inner);
    }
  }
  return node.mapChildren(_expandDoubleAngleTrig);
}

Expr _replaceUCandidate(
  Expr node,
  Expr candidate,
  Variable uVar,
  String variable,
) {
  if (node == candidate) return uVar;
  if (candidate case Pow(base: final cBase, exponent: final cExp)) {
    if (node case Pow(base: final nBase, exponent: final nExp)
        when nBase == cBase) {
      final ratio = (nExp / cExp).simplify();
      if (!ratio.dependsOn(variable)) {
        return Pow(uVar, ratio);
      }
    }
  }
  if (candidate is Sin && node is Pow) {
    if (node.base == Cos(candidate.expr) &&
        node.exponent == IntegerNumber.two) {
      return IntegerNumber.one - Pow(uVar, IntegerNumber.two);
    }
  }
  if (candidate is Cos && node is Pow) {
    if (node.base == Sin(candidate.expr) &&
        node.exponent == IntegerNumber.two) {
      return IntegerNumber.one - Pow(uVar, IntegerNumber.two);
    }
  }
  return node.mapChildren(
    (child) => _replaceUCandidate(child, candidate, uVar, variable),
  );
}

Expr? _tryUSubstitution(
  Expr expr,
  String variable, {
  Assumptions assumptions = Assumptions.none,
  int depth = 0,
}) {
  final candidates = <Expr>{};
  _collectUCandidates(expr, variable, candidates);
  if (candidates.isEmpty) return null;

  final expandedTrig = _expandDoubleAngleTrig(expr);
  final exprVariants = expandedTrig != expr ? [expr, expandedTrig] : [expr];

  final uName = '_u$depth';
  final uVar = Variable(uName);

  for (final candidate in candidates) {
    if (!candidate.dependsOn(variable)) continue;
    if (candidate is Variable && candidate.name == variable) continue;
    final gPrime = candidate
        .derivative(variable)
        .simplify(assumptions: assumptions);
    if (gPrime is Number && gPrime.isZero) continue;

    for (final variant in exprVariants) {
      final quot = (variant / gPrime).simplify(assumptions: assumptions);
      final replaced = _replaceUCandidate(quot, candidate, uVar, variable);
      var fU = replaced.simplify(assumptions: assumptions);
      if (fU.dependsOn(variable)) {
        fU = replaced.expand().simplify(assumptions: assumptions);
      }
      if (fU.dependsOn(variable)) continue;

      final uAntideriv = _antiDerivative(
        fU,
        uName,
        assumptions: assumptions,
        depth: depth + 1,
      );
      if (!_hasUnevaluatedIntegral(uAntideriv, uName)) {
        return uAntideriv
            .substitute(uName, candidate)
            .simplify(assumptions: assumptions);
      }
    }
  }

  return null;
}

Expr? _tryWeierstrassSubstitution(Expr left, Expr right, String variable) {
  final terms = right is Add ? right.terms : [right];
  var aConst = IntegerNumber.zero as Expr;
  var bSin = IntegerNumber.zero as Expr;
  var cCos = IntegerNumber.zero as Expr;
  Expr? inner;

  for (final term in terms) {
    if (!term.dependsOn(variable)) {
      aConst = (aConst + term).simplify();
      continue;
    }
    var coeff = IntegerNumber.one as Expr;
    var varPart = term;
    if (term case Mul(:final factors)) {
      final (:constFactors, :varFactors) = partitionFactors(factors, variable);
      if (varFactors.length != 1) return null;
      varPart = varFactors.first;
      coeff = switch (constFactors) {
        [] => IntegerNumber.one,
        [final single] => single,
        _ => Mul(constFactors).simplify(),
      };
    }
    switch (varPart) {
      case Sin(expr: final arg):
        if (inner == null) {
          inner = arg;
        } else if (inner != arg) {
          return null;
        }
        bSin = (bSin + coeff).simplify();
      case Cos(expr: final arg):
        if (inner == null) {
          inner = arg;
        } else if (inner != arg) {
          return null;
        }
        cCos = (cCos + coeff).simplify();
      default:
        return null;
    }
  }

  if (inner == null) return null;
  final linear = inner.matchLinear(variable);
  if (linear == null) return null;
  final k = linear.a;

  const tName = '_wt';
  const tVar = Variable(tName);
  final denom =
      ((aConst - cCos) * tVar * tVar +
              IntegerNumber.two * bSin * tVar +
              (aConst + cCos))
          .simplify();
  if (denom is Number && denom.isZero) return null;

  final integrandT = ((IntegerNumber.two * left) / (k * denom)).simplify();
  final tAntideriv = _antiDerivative(integrandT, tName, depth: 2);
  if (_hasUnevaluatedIntegral(tAntideriv, tName)) return null;

  return tAntideriv
      .substitute(tName, Tan((inner / IntegerNumber.two).simplify()))
      .simplify();
}

({Expr scale, int sinExp, int cosExp, Expr? inner})? _extractTrigPowers(
  Expr expr,
  String variable,
) {
  final factors = expr is Mul ? expr.factors : [expr];
  var scale = IntegerNumber.one as Expr;
  var sinExp = 0;
  var cosExp = 0;
  Expr? inner;

  for (final f in factors) {
    if (!f.dependsOn(variable)) {
      scale = (scale * f).simplify();
      continue;
    }
    var base = f;
    var exp = 1;
    if (f case Pow(base: final pBase, exponent: IntegerNumber(:final asInt))
        when asInt != null && asInt.abs() <= 10) {
      base = pBase;
      exp = asInt;
    }
    switch (base) {
      case Sin(expr: final arg):
        if (inner == null) {
          inner = arg;
        } else if (inner != arg) {
          return null;
        }
        sinExp += exp;
      case Cos(expr: final arg):
        if (inner == null) {
          inner = arg;
        } else if (inner != arg) {
          return null;
        }
        cosExp += exp;
      default:
        return null;
    }
  }
  return (scale: scale, sinExp: sinExp, cosExp: cosExp, inner: inner);
}

Expr _integrateCotPower(int n, Expr inner, Expr a, String variable) {
  if (n == 0) return Variable(variable);
  if (n == 1) return (Ln(Abs(Sin(inner))) / a).simplify();
  final nMinus1 = IntegerNumber.of(n - 1);
  final cotTerm = Pow(Cos(inner) / Sin(inner), nMinus1);
  final term1 = (-cotTerm / (nMinus1 * a)).simplify();
  final rem = _integrateCotPower(n - 2, inner, a, variable);
  return (term1 - rem).simplify();
}

Expr? _tryTrigPowerProduct(Expr num, Expr den, String variable) {
  final numInfo = _extractTrigPowers(num, variable);
  final denInfo = _extractTrigPowers(den, variable);
  if (numInfo == null || denInfo == null) return null;

  final inner = numInfo.inner ?? denInfo.inner;
  if (inner == null) return null;
  if (numInfo.inner != null &&
      denInfo.inner != null &&
      numInfo.inner != denInfo.inner) {
    return null;
  }
  final linear = inner.matchLinear(variable);
  if (linear == null) return null;
  final a = linear.a;

  final p = numInfo.sinExp - denInfo.sinExp;
  final q = numInfo.cosExp - denInfo.cosExp;
  if (p == 0 && q == 0) return null;
  if (p.abs() > 10 || q.abs() > 10) return null;
  final scale = (numInfo.scale / denInfo.scale).simplify();

  if (q < 0 && p == -q && p >= 2) {
    final res = _antiDerivative(Pow(Tan(inner), IntegerNumber.of(p)), variable);
    return _hasUnevaluatedIntegral(res, variable) ? null : res.scale(scale);
  }
  if (p < 0 && q == -p && q >= 2) {
    return _integrateCotPower(q, inner, a, variable).scale(scale);
  }

  const tName = '_wt';
  const tVar = Variable(tName);

  if (p >= 1 && p.isOdd) {
    final k = (p - 1) ~/ 2;
    final integrand =
        ((-scale / a) *
                Pow(IntegerNumber.one - tVar * tVar, IntegerNumber.of(k)) *
                Pow(tVar, IntegerNumber.of(q)))
            .expand()
            .simplify();
    final tInt = _antiDerivative(integrand, tName, depth: 2);
    if (!_hasUnevaluatedIntegral(tInt, tName)) {
      return tInt.substitute(tName, Cos(inner)).simplify();
    }
  }

  if (q >= 1 && q.isOdd) {
    final k = (q - 1) ~/ 2;
    final integrand =
        ((scale / a) *
                Pow(tVar, IntegerNumber.of(p)) *
                Pow(IntegerNumber.one - tVar * tVar, IntegerNumber.of(k)))
            .expand()
            .simplify();
    final tInt = _antiDerivative(integrand, tName, depth: 2);
    if (!_hasUnevaluatedIntegral(tInt, tName)) {
      return tInt.substitute(tName, Sin(inner)).simplify();
    }
  }

  if ((p + q).isEven && p + q <= -2) {
    final m = -(p + q) ~/ 2 - 1;
    final integrand =
        ((scale / a) *
                Pow(tVar, IntegerNumber.of(p)) *
                Pow(IntegerNumber.one + tVar * tVar, IntegerNumber.of(m)))
            .expand()
            .simplify();
    final tInt = _antiDerivative(integrand, tName, depth: 2);
    if (!_hasUnevaluatedIntegral(tInt, tName)) {
      return tInt.substitute(tName, Tan(inner)).simplify();
    }
  }

  if (p >= 0 && q >= 0 && p.isEven && q.isEven) {
    final twoInner = (IntegerNumber.two * inner).simplify();
    final sin2 = (IntegerNumber.one - Cos(twoInner)) / IntegerNumber.two;
    final cos2 = (IntegerNumber.one + Cos(twoInner)) / IntegerNumber.two;
    final expanded =
        (scale *
                Pow(sin2, IntegerNumber.of(p ~/ 2)) *
                Pow(cos2, IntegerNumber.of(q ~/ 2)))
            .expand()
            .simplify();
    if (expanded is Add || expanded != (num / den).simplify()) {
      final res = _antiDerivative(expanded, variable, depth: 2);
      if (!_hasUnevaluatedIntegral(res, variable)) return res;
    }
  }

  return null;
}

Expr? _reduceTrigPower(Expr factor, String variable) {
  if (factor case Pow(:final base, exponent: IntegerNumber(asInt: final n?))
      when n >= 2 && n <= 6) {
    final Expr inner;
    final bool isSin;
    if (base case Sin(:final expr) when expr.matchLinear(variable) != null) {
      inner = expr;
      isSin = true;
    } else if (base case Cos(:final expr)
        when expr.matchLinear(variable) != null) {
      inner = expr;
      isSin = false;
    } else {
      return null;
    }
    final u2 = (IntegerNumber.two * inner).simplify();
    final u3 = (IntegerNumber.of(3) * inner).simplify();
    final u4 = (IntegerNumber.of(4) * inner).simplify();
    final u5 = (IntegerNumber.of(5) * inner).simplify();
    final u6 = (IntegerNumber.of(6) * inner).simplify();
    return switch ((isSin, n)) {
      (true, 2) => (IntegerNumber.one - Cos(u2)) / IntegerNumber.two,
      (false, 2) => (IntegerNumber.one + Cos(u2)) / IntegerNumber.two,
      (true, 3) =>
        (IntegerNumber.of(3) * Sin(inner) - Sin(u3)) / IntegerNumber.of(4),
      (false, 3) =>
        (IntegerNumber.of(3) * Cos(inner) + Cos(u3)) / IntegerNumber.of(4),
      (true, 4) =>
        (IntegerNumber.of(3) - IntegerNumber.of(4) * Cos(u2) + Cos(u4)) /
            IntegerNumber.of(8),
      (false, 4) =>
        (IntegerNumber.of(3) + IntegerNumber.of(4) * Cos(u2) + Cos(u4)) /
            IntegerNumber.of(8),
      (true, 5) =>
        (IntegerNumber.of(10) * Sin(inner) -
                IntegerNumber.of(5) * Sin(u3) +
                Sin(u5)) /
            IntegerNumber.of(16),
      (false, 5) =>
        (IntegerNumber.of(10) * Cos(inner) +
                IntegerNumber.of(5) * Cos(u3) +
                Cos(u5)) /
            IntegerNumber.of(16),
      (true, 6) =>
        (IntegerNumber.of(10) -
                IntegerNumber.of(15) * Cos(u2) +
                IntegerNumber.of(6) * Cos(u4) -
                Cos(u6)) /
            IntegerNumber.of(32),
      (false, 6) =>
        (IntegerNumber.of(10) +
                IntegerNumber.of(15) * Cos(u2) +
                IntegerNumber.of(6) * Cos(u4) +
                Cos(u6)) /
            IntegerNumber.of(32),
      _ => null,
    };
  }
  return null;
}

Expr? _tryPolyTrigPowerReduction(List<Expr> varFactors, String variable) {
  for (var i = 0; i < varFactors.length; i++) {
    if (_reduceTrigPower(varFactors[i], variable) case final reduced?) {
      final others = <Expr>[
        for (var j = 0; j < varFactors.length; j++)
          if (i != j) varFactors[j],
      ];
      final otherExpr = others.length == 1
          ? others.first
          : Mul(others).simplify();
      if (polynomialDegree(otherExpr, variable) != null) {
        final expanded = (otherExpr * reduced).expand().simplify();
        final res = _antiDerivative(expanded, variable);
        if (!_hasUnevaluatedIntegral(res, variable)) return res;
      }
    }
  }

  for (var i = 0; i < varFactors.length; i++) {
    for (var j = i + 1; j < varFactors.length; j++) {
      final f1 = varFactors[i];
      final f2 = varFactors[j];
      Expr? pairReduced;
      if (f1 case Sin(expr: final a) when a.matchLinear(variable) != null) {
        if (f2 case Cos(expr: final b) when b.matchLinear(variable) != null) {
          pairReduced =
              (Sin((a + b).simplify()) + Sin((a - b).simplify())) /
              IntegerNumber.two;
        } else if (f2 case Sin(expr: final b)
            when b.matchLinear(variable) != null) {
          pairReduced =
              (Cos((a - b).simplify()) - Cos((a + b).simplify())) /
              IntegerNumber.two;
        }
      } else if (f1 case Cos(expr: final a)
          when a.matchLinear(variable) != null) {
        if (f2 case Sin(expr: final b) when b.matchLinear(variable) != null) {
          pairReduced =
              (Sin((a + b).simplify()) - Sin((a - b).simplify())) /
              IntegerNumber.two;
        } else if (f2 case Cos(expr: final b)
            when b.matchLinear(variable) != null) {
          pairReduced =
              (Cos((a + b).simplify()) + Cos((a - b).simplify())) /
              IntegerNumber.two;
        }
      }
      if (pairReduced != null) {
        final others = <Expr>[
          for (var k = 0; k < varFactors.length; k++)
            if (k != i && k != j) varFactors[k],
        ];
        final otherExpr = others.length == 1
            ? others.first
            : Mul(others).simplify();
        if (polynomialDegree(otherExpr, variable) != null) {
          final expanded = (otherExpr * pairReduced).expand().simplify();
          final res = _antiDerivative(expanded, variable);
          if (!_hasUnevaluatedIntegral(res, variable)) return res;
        }
      }
    }
  }

  return null;
}

Expr? _tryRepeatedQuadratic(Expr left, Expr quad, int m, String variable) {
  final quadCoeffs = extractPolynomialCoefficients(quad, variable);
  if (quadCoeffs == null || maxPolynomialDegree(quadCoeffs) != 2) return null;
  final a = quadCoeffs[2] ?? IntegerNumber.zero;
  final b = quadCoeffs[1] ?? IntegerNumber.zero;
  final c = quadCoeffs[0] ?? IntegerNumber.zero;

  final degLeft = polynomialDegree(left.expand().simplify(), variable);
  if (degLeft == null) return null;
  if (degLeft >= 2) {
    final (:quotient, :remainder) = left.polynomialDivide(quad, variable);
    final qTerm = _antiDerivative(
      (quotient / Pow(quad, IntegerNumber.of(m - 1))).simplify(),
      variable,
    );
    if (_hasUnevaluatedIntegral(qTerm, variable)) return null;
    if (remainder is Number && remainder.isZero) return qTerm;
    final rTerm = _tryRepeatedQuadratic(remainder, quad, m, variable);
    if (rTerm == null) return null;
    return (qTerm + rTerm).simplify();
  }

  final numCoeffs = extractPolynomialCoefficients(left, variable);
  if (numCoeffs == null || maxPolynomialDegree(numCoeffs) > 1) return null;
  final d = numCoeffs[1] ?? IntegerNumber.zero;
  final e = numCoeffs[0] ?? IntegerNumber.zero;

  final twoA = (IntegerNumber.two * a).simplify();
  final mMinus1 = IntegerNumber.of(m - 1);
  var result = IntegerNumber.zero as Expr;

  if (d != IntegerNumber.zero) {
    result = (-d / (twoA * mMinus1 * Pow(quad, mMinus1))).simplify();
  }

  final eRem = (e - (d * b) / twoA).simplify();
  if (eRem != IntegerNumber.zero) {
    final constPart = _integrateRepeatedQuadConst(quad, a, b, c, m, variable);
    if (constPart == null) return null;
    result = (result + eRem * constPart).simplify();
  }
  return result;
}

Expr? _integrateRepeatedQuadConst(
  Expr quad,
  Expr a,
  Expr b,
  Expr c,
  int m,
  String variable,
) {
  if (m == 1) {
    final res = _antiDerivative(IntegerNumber.one / quad, variable);
    return _hasUnevaluatedIntegral(res, variable) ? null : res;
  }
  final disc = (const IntegerNumber(Integer(4)) * a * c - b * b).simplify();
  if (disc is Number && disc.isZero) return null;

  final prev = _integrateRepeatedQuadConst(quad, a, b, c, m - 1, variable);
  if (prev == null) return null;

  final mMinus1 = IntegerNumber.of(m - 1);
  final twoAxPlusB = (IntegerNumber.two * a * Variable(variable) + b)
      .simplify();
  final denom = (mMinus1 * disc).simplify();
  final term1 = (twoAxPlusB / (denom * Pow(quad, mMinus1))).simplify();
  final coeff2 = ((IntegerNumber.two * IntegerNumber.of(2 * m - 3) * a) / denom)
      .simplify();
  return (term1 + coeff2 * prev).simplify();
}

Expr _integrateLinearOverQuad(
  Expr d,
  Expr e,
  Expr quad,
  Expr a,
  Expr b,
  String variable,
) {
  final twoA = (IntegerNumber.two * a).simplify();
  var result = IntegerNumber.zero as Expr;
  if (d != IntegerNumber.zero) {
    result = ((d / twoA) * Ln(quad)).simplify();
  }
  final eRem = (e - (d * b) / twoA).simplify();
  if (eRem != IntegerNumber.zero) {
    final constInt = _antiDerivative((eRem / quad).simplify(), variable);
    result = (result + constInt).simplify();
  }
  return result;
}

Expr? _tryCubicBinomialDenominator(Expr left, Expr right, String variable) {
  final denCoeffs = extractPolynomialCoefficients(right, variable);
  if (denCoeffs == null || maxPolynomialDegree(denCoeffs) != 3) return null;
  if ((denCoeffs[2] != null && denCoeffs[2] != IntegerNumber.zero) ||
      (denCoeffs[1] != null && denCoeffs[1] != IntegerNumber.zero)) {
    return null;
  }
  final a3 = denCoeffs[3] ?? IntegerNumber.zero;
  final c0 = denCoeffs[0] ?? IntegerNumber.zero;
  if (a3 == IntegerNumber.zero || c0 == IntegerNumber.zero) return null;

  final numCoeffs = extractPolynomialCoefficients(left, variable);
  if (numCoeffs == null || maxPolynomialDegree(numCoeffs) > 2) return null;
  final p2 = ((numCoeffs[2] ?? IntegerNumber.zero) / a3).simplify();
  final p1 = ((numCoeffs[1] ?? IntegerNumber.zero) / a3).simplify();
  final p0 = ((numCoeffs[0] ?? IntegerNumber.zero) / a3).simplify();
  final c = (c0 / a3).simplify();

  final r = Pow(c, const FractionNumber(Integer.one, Integer(3))).simplify();
  final xVar = Variable(variable);
  final linFactor = (xVar + r).simplify();
  final quadFactor = (xVar * xVar - r * xVar + r * r).simplify();

  final aCoeff = ((p2 * r * r - p1 * r + p0) / (IntegerNumber.of(3) * r * r))
      .simplify();
  final bCoeff = (p2 - aCoeff).simplify();
  final cCoeff = (p0 / r - aCoeff * r).simplify();

  final linInt = _antiDerivative((aCoeff / linFactor).simplify(), variable);
  final quadInt = _integrateLinearOverQuad(
    bCoeff,
    cCoeff,
    quadFactor,
    IntegerNumber.one,
    (-r).simplify(),
    variable,
  );
  if (_hasUnevaluatedIntegral(linInt, variable) ||
      _hasUnevaluatedIntegral(quadInt, variable)) {
    return null;
  }
  return (linInt + quadInt).simplify();
}

Expr? _trySophieGermainQuartic(Expr left, Expr right, String variable) {
  final denCoeffs = extractPolynomialCoefficients(right, variable);
  if (denCoeffs == null || maxPolynomialDegree(denCoeffs) != 4) return null;
  for (var deg = 1; deg <= 3; deg++) {
    if (denCoeffs[deg] != null && denCoeffs[deg] != IntegerNumber.zero) {
      return null;
    }
  }
  final a4 = denCoeffs[4] ?? IntegerNumber.zero;
  final c0 = denCoeffs[0] ?? IntegerNumber.zero;
  if (a4 == IntegerNumber.zero || c0 == IntegerNumber.zero) return null;

  final c = (c0 / a4).simplify();
  if (!_isSymbolicPositive(c)) return null;

  final numCoeffs = extractPolynomialCoefficients(left, variable);
  if (numCoeffs == null || maxPolynomialDegree(numCoeffs) > 3) return null;
  final p3 = ((numCoeffs[3] ?? IntegerNumber.zero) / a4).simplify();
  final p2 = ((numCoeffs[2] ?? IntegerNumber.zero) / a4).simplify();
  final p1 = ((numCoeffs[1] ?? IntegerNumber.zero) / a4).simplify();
  final p0 = ((numCoeffs[0] ?? IntegerNumber.zero) / a4).simplify();

  final r = Pow(c, FractionNumber.half).simplify();
  final s =
      (Pow(IntegerNumber.two, FractionNumber.half) *
              Pow(c, const FractionNumber(Integer.one, Integer(4))))
          .simplify();
  final xVar = Variable(variable);
  final q1 = (xVar * xVar - s * xVar + r).simplify();
  final q2 = (xVar * xVar + s * xVar + r).simplify();

  final diffAlpha = ((p2 - p0 / r) / s).simplify();
  final sumBeta = (p0 / r).simplify();
  final diffBeta = ((p1 - r * p3) / s).simplify();

  final alpha1 = ((p3 + diffAlpha) / IntegerNumber.two).simplify();
  final alpha2 = ((p3 - diffAlpha) / IntegerNumber.two).simplify();
  final beta1 = ((sumBeta + diffBeta) / IntegerNumber.two).simplify();
  final beta2 = ((sumBeta - diffBeta) / IntegerNumber.two).simplify();

  final int1 = _integrateLinearOverQuad(
    alpha1,
    beta1,
    q1,
    IntegerNumber.one,
    (-s).simplify(),
    variable,
  );
  final int2 = _integrateLinearOverQuad(
    alpha2,
    beta2,
    q2,
    IntegerNumber.one,
    s,
    variable,
  );
  if (_hasUnevaluatedIntegral(int1, variable) ||
      _hasUnevaluatedIntegral(int2, variable)) {
    return null;
  }
  return (int1 + int2).simplify();
}

Expr? _trySymbolicBinomialAffine(
  Expr expr,
  String variable, {
  Assumptions assumptions = Assumptions.none,
}) {
  final factors = expr is Mul ? expr.factors : [expr];
  var scale = IntegerNumber.one as Expr;
  var m = 0;
  Pow? binomPow;

  for (final f in factors) {
    if (!f.dependsOn(variable)) {
      scale = (scale * f).simplify();
      continue;
    }
    if (f is Variable && f.name == variable) {
      m += 1;
      continue;
    }
    if (f
        case Pow(
          base: Variable(:final name),
          exponent: IntegerNumber(asInt: final k?),
        )
        when name == variable && k >= 1 && k <= 8) {
      m += k;
      continue;
    }
    if (f is Pow && binomPow == null && !f.exponent.dependsOn(variable)) {
      if (f.base.matchLinear(variable) != null) {
        binomPow = f;
        continue;
      }
    }
    return null;
  }

  if (binomPow == null || m == 0 || m > 8) return null;
  final linear = binomPow.base.matchLinear(variable)!;
  final (:a, :b) = linear;
  final p = binomPow.exponent;

  // u = a*x + b => x = (u - b) / a, dx = du / a
  const uName = '_sb';
  const uVar = Variable(uName);
  final expanded = (Pow((uVar - b) / a, IntegerNumber.of(m)) / a)
      .expand()
      .simplify(assumptions: assumptions);
  final terms = expanded is Add ? expanded.terms : [expanded];
  final integrated = <Expr>[];
  for (final t in terms) {
    final deg = polynomialDegree(t, uName);
    if (deg == null) return null;
    final coeff =
        (t / (deg == 0 ? IntegerNumber.one : Pow(uVar, IntegerNumber.of(deg))))
            .simplify();
    final newExp = (p + IntegerNumber.of(deg + 1)).simplify();
    if (newExp is Number && newExp.isZero) {
      integrated.add((coeff * Ln(uVar)).simplify());
    } else {
      integrated.add((coeff * Pow(uVar, newExp) / newExp).simplify());
    }
  }
  return (scale * Add(integrated))
      .substitute(uName, binomPow.base)
      .simplify(assumptions: assumptions);
}

Expr? _tryMixedTrigLogExp(
  Expr expr,
  String variable, {
  Assumptions assumptions = Assumptions.none,
}) {
  // 1. x^n * sin(ln(a*x)) or x^n * cos(ln(a*x))
  final factors = expr is Mul ? expr.factors : [expr];
  var scale = IntegerNumber.one as Expr;
  Expr? xPower = IntegerNumber.zero;
  Expr? trigFactor;

  for (final f in factors) {
    if (!f.dependsOn(variable)) {
      scale = (scale * f).simplify();
      continue;
    }
    if (f is Variable && f.name == variable && xPower != null) {
      xPower = (xPower + IntegerNumber.one).simplify();
      continue;
    }
    if (f case Pow(base: Variable(:final name), :final exponent)
        when name == variable &&
            !exponent.dependsOn(variable) &&
            xPower != null) {
      xPower = (xPower + exponent).simplify();
      continue;
    }
    if ((f is Sin || f is Cos) && trigFactor == null) {
      trigFactor = f;
      continue;
    }
    xPower = null;
  }

  if (xPower != null && trigFactor != null) {
    final inner = trigFactor is Sin
        ? trigFactor.expr
        : (trigFactor as Cos).expr;
    if (inner case Ln(expr: final lnInner)) {
      if (lnInner.matchLinear(variable) case (:final a, b: final b)
          when b == IntegerNumber.zero) {
        const uName = '_ml';
        const uVar = Variable(uName);
        final expFactor = Pow(Constant.e, (xPower + IntegerNumber.one) * uVar);
        final trigU = trigFactor is Sin ? Sin(uVar) : Cos(uVar);
        final uInt = _antiDerivative(
          (expFactor * trigU).simplify(),
          uName,
          depth: 2,
        );
        if (!_hasUnevaluatedIntegral(uInt, uName)) {
          final preFactor = (scale / Pow(a, xPower + IntegerNumber.one))
              .simplify();
          return (preFactor * uInt)
              .substitute(uName, inner)
              .simplify(assumptions: assumptions);
        }
      }
    }
  }

  // 2. exp(c * atan(x)) / (x^2 + 1)^(k/2) * x^m
  final (numExpr, denExpr) = splitNumeratorDenominator(expr);
  if (denExpr case Pow(base: final qBase, :final exponent)) {
    final halfExp = _halfIntExponent(exponent);
    if (halfExp != null && halfExp >= 2) {
      final coeffs = extractPolynomialCoefficients(qBase, variable);
      if (coeffs != null &&
          maxPolynomialDegree(coeffs) == 2 &&
          coeffs[2] == IntegerNumber.one &&
          (coeffs[1] == null || coeffs[1] == IntegerNumber.zero) &&
          coeffs[0] == IntegerNumber.one) {
        final numFactors = numExpr is Mul ? numExpr.factors : [numExpr];
        var numScale = IntegerNumber.one as Expr;
        var xDeg = 0;
        Expr? atanCoeff;
        var ok = true;
        for (final nf in numFactors) {
          if (!nf.dependsOn(variable)) {
            numScale = (numScale * nf).simplify();
          } else if (nf is Variable && nf.name == variable) {
            xDeg += 1;
          } else if (nf
              case Pow(
                base: Variable(:final name),
                exponent: IntegerNumber(asInt: final k?),
              )
              when name == variable && k >= 1) {
            xDeg += k;
          } else if (nf case Pow(base: Constant.e, exponent: final eExp)) {
            if (eExp case Atan(expr: Variable(:final name))
                when name == variable) {
              atanCoeff = IntegerNumber.one;
            } else if (eExp case Mul(factors: final ef)) {
              final (:constFactors, :varFactors) = partitionFactors(
                ef,
                variable,
              );
              if (varFactors case [Atan(expr: Variable(:final name))]
                  when name == variable) {
                atanCoeff = constFactors.length == 1
                    ? constFactors.first
                    : Mul(constFactors).simplify();
              } else {
                ok = false;
              }
            } else {
              ok = false;
            }
          } else {
            ok = false;
          }
        }
        if (ok && atanCoeff != null && xDeg <= 2 && halfExp >= xDeg + 2) {
          const uName = '_at';
          const uVar = Variable(uName);
          final cosPow = halfExp - 2 - xDeg;
          final integrand =
              (numScale *
                      Pow(Constant.e, atanCoeff * uVar) *
                      Pow(Sin(uVar), IntegerNumber.of(xDeg)) *
                      Pow(Cos(uVar), IntegerNumber.of(cosPow)))
                  .simplify();
          final uInt = _antiDerivative(integrand, uName, depth: 2);
          if (!_hasUnevaluatedIntegral(uInt, uName)) {
            return uInt
                .substitute(uName, Atan(Variable(variable)))
                .simplify(assumptions: assumptions);
          }
        }
      }
    }
  }

  return null;
}

({Expr aSin, Expr bCos, Expr cConst, Expr? inner})? _extractLinearTrigCombo(
  Expr expr,
  String variable,
) {
  final terms = expr is Add ? expr.terms : [expr];
  var aSin = IntegerNumber.zero as Expr;
  var bCos = IntegerNumber.zero as Expr;
  var cConst = IntegerNumber.zero as Expr;
  Expr? inner;

  for (final term in terms) {
    if (!term.dependsOn(variable)) {
      cConst = (cConst + term).simplify();
      continue;
    }
    var coeff = IntegerNumber.one as Expr;
    var varPart = term;
    if (term case Mul(:final factors)) {
      final (:constFactors, :varFactors) = partitionFactors(factors, variable);
      if (varFactors.length != 1) return null;
      varPart = varFactors.first;
      coeff = switch (constFactors) {
        [] => IntegerNumber.one,
        [final single] => single,
        _ => Mul(constFactors).simplify(),
      };
    }
    switch (varPart) {
      case Sin(expr: final arg):
        if (inner == null) {
          inner = arg;
        } else if (inner != arg) {
          return null;
        }
        aSin = (aSin + coeff).simplify();
      case Cos(expr: final arg):
        if (inner == null) {
          inner = arg;
        } else if (inner != arg) {
          return null;
        }
        bCos = (bCos + coeff).simplify();
      default:
        return null;
    }
  }
  if (inner == null || inner.matchLinear(variable) == null) return null;
  return (aSin: aSin, bCos: bCos, cConst: cConst, inner: inner);
}

Expr? _tryLinearTrigQuotient(Expr left, Expr right, String variable) {
  if (!left.dependsOn(variable)) return null;
  final numCombo = _extractLinearTrigCombo(left, variable);
  final denCombo = _extractLinearTrigCombo(right, variable);
  if (numCombo == null || denCombo == null) return null;
  if (numCombo.inner != denCombo.inner) return null;
  final inner = denCombo.inner!;
  final k = inner.matchLinear(variable)!.a;

  final a = denCombo.aSin;
  final b = denCombo.bCos;
  final c = denCombo.cConst;
  final a1 = numCombo.aSin;
  final b1 = numCombo.bCos;
  final c1 = numCombo.cConst;

  final denom = (a * a + b * b).simplify();
  if (denom is Number && denom.isZero) return null;

  final alpha = ((a1 * a + b1 * b) / denom).simplify();
  final beta = ((b1 * a - a1 * b) / denom).simplify();
  final gamma = (c1 - alpha * c).simplify();

  var res = (alpha * Variable(variable)).simplify();
  if (beta != IntegerNumber.zero) {
    res = (res + (beta / k) * Ln(Abs(right))).simplify();
  }
  if (gamma != IntegerNumber.zero) {
    final remInt = _tryWeierstrassSubstitution(gamma, right, variable);
    if (remInt == null) return null;
    res = (res + remInt).simplify();
  }
  return res;
}

Expr? _collectAffineTrigInner(Expr node, String variable) {
  Expr? found;
  var valid = true;
  void scan(Expr n) {
    if (!valid || !n.dependsOn(variable)) return;
    switch (n) {
      case Sin(:final expr) || Cos(:final expr) || Tan(:final expr):
        if (expr.matchLinear(variable) == null) {
          valid = false;
          return;
        }
        if (found == null) {
          found = expr;
        } else if (found != expr) {
          valid = false;
        }
      case Add(:final terms):
        for (final t in terms) {
          scan(t);
        }
      case Mul(:final factors):
        for (final f in factors) {
          scan(f);
        }
      case Pow(:final base, :final exponent)
          when exponent is IntegerNumber && !exponent.dependsOn(variable):
        scan(base);
      default:
        valid = false;
    }
  }

  scan(node);
  return valid ? found : null;
}

Expr _replaceTrigWithWeierstrass(Expr node, Expr inner, Variable tVar) {
  if (node is Sin && node.expr == inner) {
    return (IntegerNumber.two * tVar) / (IntegerNumber.one + tVar * tVar);
  }
  if (node is Cos && node.expr == inner) {
    return (IntegerNumber.one - tVar * tVar) /
        (IntegerNumber.one + tVar * tVar);
  }
  if (node is Tan && node.expr == inner) {
    return (IntegerNumber.two * tVar) / (IntegerNumber.one - tVar * tVar);
  }
  return node.mapChildren((c) => _replaceTrigWithWeierstrass(c, inner, tVar));
}

Expr _replaceTrigWithTan(Expr node, Expr inner, Variable tVar) {
  if (node is Tan && node.expr == inner) return tVar;
  if (node
      case Pow(
        base: Sin(expr: final arg),
        exponent: IntegerNumber(asInt: final n?),
      )
      when arg == inner && n.isEven) {
    return Pow(
      (tVar * tVar) / (IntegerNumber.one + tVar * tVar),
      IntegerNumber.of(n ~/ 2),
    );
  }
  if (node
      case Pow(
        base: Cos(expr: final arg),
        exponent: IntegerNumber(asInt: final n?),
      )
      when arg == inner && n.isEven) {
    return Pow(
      IntegerNumber.one / (IntegerNumber.one + tVar * tVar),
      IntegerNumber.of(n ~/ 2),
    );
  }
  return node.mapChildren((c) => _replaceTrigWithTan(c, inner, tVar));
}

Expr? _tryRationalTrigSubstitution(
  Expr expr,
  String variable, {
  Assumptions assumptions = Assumptions.none,
  int depth = 0,
}) {
  final inner = _collectAffineTrigInner(expr, variable);
  if (inner == null) return null;
  final k = inner.matchLinear(variable)!.a;

  // 1. Try t = tan(u) if expression is even in (sin, cos)
  const tName = '_rt';
  const tVar = Variable(tName);
  final tanReplaced = _replaceTrigWithTan(expr, inner, tVar);
  if (!tanReplaced.dependsOn(variable)) {
    final rawIntegrand = (tanReplaced / (k * (IntegerNumber.one + tVar * tVar)))
        .simplify();
    final integrand = rawIntegrand.together();
    final tInt = _antiDerivative(
      integrand,
      tName,
      assumptions: assumptions,
      depth: 2,
    );
    if (!_hasUnevaluatedIntegral(tInt, tName)) {
      return tInt
          .substitute(tName, Tan(inner))
          .simplify(assumptions: assumptions);
    }
  }

  // 2. General Weierstrass substitution t = tan(u / 2)
  final wReplaced = _replaceTrigWithWeierstrass(expr, inner, tVar);
  if (!wReplaced.dependsOn(variable)) {
    final rawIntegrand =
        ((wReplaced * IntegerNumber.two) /
                (k * (IntegerNumber.one + tVar * tVar)))
            .simplify();
    final integrand = rawIntegrand.together();
    final deg = polynomialDegree(
      splitNumeratorDenominator(integrand).$2.expand().simplify(),
      tName,
    );
    if (deg != null && deg <= 8) {
      final tInt = _antiDerivative(
        integrand,
        tName,
        assumptions: assumptions,
        depth: 2,
      );
      if (!_hasUnevaluatedIntegral(tInt, tName)) {
        return tInt
            .substitute(tName, Tan((inner / IntegerNumber.two).simplify()))
            .simplify(assumptions: assumptions);
      }
    }
  }

  return null;
}

Expr? _collectAffineHypInner(Expr node, String variable) {
  Expr? found;
  var valid = true;
  void scan(Expr n) {
    if (!valid || !n.dependsOn(variable)) return;
    switch (n) {
      case Sinh(:final expr) || Cosh(:final expr) || Tanh(:final expr):
        if (expr.matchLinear(variable) == null) {
          valid = false;
          return;
        }
        if (found == null) {
          found = expr;
        } else if (found != expr) {
          valid = false;
        }
      case Add(:final terms):
        for (final t in terms) {
          scan(t);
        }
      case Mul(:final factors):
        for (final f in factors) {
          scan(f);
        }
      case Pow(:final base, :final exponent)
          when exponent is IntegerNumber && !exponent.dependsOn(variable):
        scan(base);
      default:
        valid = false;
    }
  }

  scan(node);
  return valid ? found : null;
}

Expr _replaceHypWithExp(Expr node, Expr inner, Variable wVar) {
  if (node is Sinh && node.expr == inner) {
    return (wVar - IntegerNumber.one / wVar) / IntegerNumber.two;
  }
  if (node is Cosh && node.expr == inner) {
    return (wVar + IntegerNumber.one / wVar) / IntegerNumber.two;
  }
  if (node is Tanh && node.expr == inner) {
    return (wVar * wVar - IntegerNumber.one) /
        (wVar * wVar + IntegerNumber.one);
  }
  return node.mapChildren((c) => _replaceHypWithExp(c, inner, wVar));
}

Expr? _tryHyperbolicRationalSubstitution(
  Expr expr,
  String variable, {
  Assumptions assumptions = Assumptions.none,
  int depth = 0,
}) {
  final inner = _collectAffineHypInner(expr, variable);
  if (inner == null) return null;
  final k = inner.matchLinear(variable)!.a;

  const wName = '_hw';
  const wVar = Variable(wName);
  final replaced = _replaceHypWithExp(expr, inner, wVar);
  if (replaced.dependsOn(variable)) return null;

  final integrand = (replaced / (k * wVar)).simplify().together();
  final wInt = _antiDerivative(
    integrand,
    wName,
    assumptions: assumptions,
    depth: 2,
  );
  if (_hasUnevaluatedIntegral(wInt, wName)) return null;

  return wInt
      .substitute(wName, Pow(Constant.e, inner))
      .simplify(assumptions: assumptions);
}

Expr? _tryPolynomialOverSqrtQuadratic(Expr left, Expr right, String variable) {
  // Case 1: P(x) / sqrt(Ax^2 + Bx + C) with deg(P) >= 2
  if (right case Pow(base: final quad, exponent: final exp)
      when _halfIntExponent(exp) == 1) {
    final coeffs = extractPolynomialCoefficients(quad, variable);
    if (coeffs != null && maxPolynomialDegree(coeffs) == 2) {
      final degLeft = polynomialDegree(left.expand().simplify(), variable);
      if (degLeft != null && degLeft >= 2 && degLeft <= 6) {
        return _integratePolyOverSqrtQ(
          left.expand().simplify(),
          quad,
          coeffs[2] ?? IntegerNumber.zero,
          coeffs[1] ?? IntegerNumber.zero,
          coeffs[0] ?? IntegerNumber.zero,
          variable,
        );
      }
    }
  }

  // Case 2: sqrt(Ax^2 + Bx + C) / x^k (k >= 1)
  if (left case Pow(base: final quad, exponent: final exp)
      when _halfIntExponent(exp) == 1) {
    final coeffs = extractPolynomialCoefficients(quad, variable);
    if (coeffs != null && maxPolynomialDegree(coeffs) == 2) {
      int? k;
      if (right is Variable && right.name == variable) {
        k = 1;
      } else if (right
          case Pow(
            base: Variable(:final name),
            exponent: IntegerNumber(asInt: final p?),
          )
          when name == variable && p >= 1 && p <= 4) {
        k = p;
      }
      if (k != null) {
        final a = coeffs[2] ?? IntegerNumber.zero;
        final b = coeffs[1] ?? IntegerNumber.zero;
        final c = coeffs[0] ?? IntegerNumber.zero;
        final xVar = Variable(variable);
        // sqrt(Q)/x^k = A*x^(2-k)/sqrt(Q) + B*x^(1-k)/sqrt(Q) + C/(x^k * sqrt(Q))
        final term1 = k == 1
            ? _antiDerivative((a * xVar / left).simplify(), variable)
            : (k == 2
                  ? _antiDerivative((a / left).simplify(), variable)
                  : _tryPolynomialOverSqrtQuadratic(
                      a,
                      Pow(xVar, IntegerNumber.of(k - 2)) * left,
                      variable,
                    ));
        final term2 = k == 1
            ? _antiDerivative((b / left).simplify(), variable)
            : _tryPolynomialOverSqrtQuadratic(
                b,
                Pow(xVar, IntegerNumber.of(k - 1)) * left,
                variable,
              );
        final term3 = _tryPolynomialOverSqrtQuadratic(
          c,
          (right * left).simplify(),
          variable,
        );
        if (term1 != null &&
            term2 != null &&
            term3 != null &&
            !_hasUnevaluatedIntegral(term1, variable) &&
            !_hasUnevaluatedIntegral(term2, variable)) {
          return (term1 + term2 + term3).simplify();
        }
      }
    }
  }

  // Case 3: c / (x^k * sqrt(Ax^2 + Bx + C)) (k >= 1) via t = 1/x
  if (!left.dependsOn(variable) && right is Mul) {
    final factors = right.factors;
    var k = 0;
    Pow? rad;
    var valid = true;
    for (final f in factors) {
      if (f is Variable && f.name == variable) {
        k += 1;
      } else if (f
          case Pow(
            base: Variable(:final name),
            exponent: IntegerNumber(asInt: final p?),
          )
          when name == variable && p >= 1) {
        k += p;
      } else if (f is Pow && _halfIntExponent(f.exponent) == 1 && rad == null) {
        rad = f;
      } else {
        valid = false;
      }
    }
    if (valid && k >= 1 && k <= 4 && rad != null) {
      final coeffs = extractPolynomialCoefficients(rad.base, variable);
      if (coeffs != null && maxPolynomialDegree(coeffs) == 2) {
        final a = coeffs[2] ?? IntegerNumber.zero;
        final b = coeffs[1] ?? IntegerNumber.zero;
        final c = coeffs[0] ?? IntegerNumber.zero;
        if (c != IntegerNumber.zero) {
          const tName = '_inv';
          const tVar = Variable(tName);
          final qT = (c * tVar * tVar + b * tVar + a).simplify();
          final numT =
              (-left *
                      (k == 1
                          ? IntegerNumber.one
                          : Pow(tVar, IntegerNumber.of(k - 1))))
                  .simplify();
          final tInt = _antiDerivative(
            (numT / Pow(qT, FractionNumber.half)).simplify(),
            tName,
            depth: 2,
          );
          if (!_hasUnevaluatedIntegral(tInt, tName)) {
            return tInt
                .substitute(tName, IntegerNumber.one / Variable(variable))
                .simplify();
          }
        }
      }
    }
  }

  return null;
}

Expr? _integratePolyOverSqrtQ(
  Expr poly,
  Expr quad,
  Expr a,
  Expr b,
  Expr c,
  String variable,
) {
  final coeffs = extractPolynomialCoefficients(poly, variable);
  if (coeffs == null) return null;
  final deg = maxPolynomialDegree(coeffs);
  if (deg <= 1) {
    return _tryQuadraticRadical(poly, quad, -1, variable);
  }
  final leadCoeff = coeffs[deg]!;
  final m = deg;
  final xVar = Variable(variable);
  final rad = Pow(quad, FractionNumber.half);
  final term1 =
      (leadCoeff *
              Pow(xVar, IntegerNumber.of(m - 1)) *
              rad /
              (IntegerNumber.of(m) * a))
          .simplify();

  final rem1 =
      (-leadCoeff *
              IntegerNumber.of(2 * m - 1) *
              b /
              (IntegerNumber.two * IntegerNumber.of(m) * a) *
              Pow(xVar, IntegerNumber.of(m - 1)))
          .simplify();
  final rem2 =
      (-leadCoeff *
              IntegerNumber.of(m - 1) *
              c /
              (IntegerNumber.of(m) * a) *
              (m - 2 == 0
                  ? IntegerNumber.one
                  : Pow(xVar, IntegerNumber.of(m - 2))))
          .simplify();
  final lowerPoly =
      (poly - leadCoeff * Pow(xVar, IntegerNumber.of(m)) + rem1 + rem2)
          .expand()
          .simplify();
  final remInt = _integratePolyOverSqrtQ(lowerPoly, quad, a, b, c, variable);
  if (remInt == null) return null;
  return (term1 + remInt).simplify();
}

Expr? _tryFractionalLinearRadical(
  Expr expr,
  String variable, {
  Assumptions assumptions = Assumptions.none,
  int depth = 0,
}) {
  Pow? targetPow;
  ({int p, int q})? frac;
  void scan(Expr n) {
    if (targetPow != null || !n.dependsOn(variable)) return;
    if (n case Pow(:final base, :final exponent)) {
      if (_fractionalExponent(exponent) case final fq? when fq.q <= 4) {
        final (numB, denB) = splitNumeratorDenominator(base);
        if (numB.matchLinear(variable) != null &&
            denB.dependsOn(variable) &&
            denB.matchLinear(variable) != null) {
          targetPow = n;
          frac = fq;
          return;
        }
      }
    }
    n.mapChildren((c) {
      scan(c);
      return c;
    });
  }

  scan(expr);
  if (targetPow == null || frac == null) return null;

  final (numB, denB) = splitNumeratorDenominator(targetPow!.base);
  final (:a, :b) = numB.matchLinear(variable)!;
  final (a: c, b: d) = denB.matchLinear(variable)!;
  final n = frac!.q;

  const uName = '_fl';
  const uVar = Variable(uName);
  final uPowN = Pow(uVar, IntegerNumber.of(n));
  final xOfU = ((d * uPowN - b) / (a - c * uPowN)).simplify();
  final dx =
      (IntegerNumber.of(n) *
              (a * d - b * c) *
              Pow(uVar, IntegerNumber.of(n - 1)) /
              Pow(a - c * uPowN, IntegerNumber.two))
          .simplify();

  Expr replaceNode(Expr node) {
    if (node == targetPow) return Pow(uVar, IntegerNumber.of(frac!.p));
    if (node is Variable && node.name == variable) return xOfU;
    return node.mapChildren(replaceNode);
  }

  final transformed = (replaceNode(expr) * dx).simplify(
    assumptions: assumptions,
  );
  if (transformed.dependsOn(variable)) return null;
  final uInt = _antiDerivative(
    transformed,
    uName,
    assumptions: assumptions,
    depth: 2,
  );
  if (_hasUnevaluatedIntegral(uInt, uName)) return null;

  final backSub = Pow(targetPow!.base, FractionNumber(Integer.one, Integer(n)));
  return uInt.substitute(uName, backSub).simplify(assumptions: assumptions);
}

Expr? _tryBiquadraticDenominator(Expr left, Expr right, String variable) {
  final denCoeffs = extractPolynomialCoefficients(right, variable);
  if (denCoeffs == null || maxPolynomialDegree(denCoeffs) != 4) return null;
  if ((denCoeffs[3] != null && denCoeffs[3] != IntegerNumber.zero) ||
      (denCoeffs[1] != null && denCoeffs[1] != IntegerNumber.zero)) {
    return null;
  }
  final a = denCoeffs[4] ?? IntegerNumber.zero;
  final b = denCoeffs[2] ?? IntegerNumber.zero;
  final c = denCoeffs[0] ?? IntegerNumber.zero;
  if (a == IntegerNumber.zero ||
      b == IntegerNumber.zero ||
      c == IntegerNumber.zero) {
    return null;
  }

  final numCoeffs = extractPolynomialCoefficients(left, variable);
  if (numCoeffs == null || maxPolynomialDegree(numCoeffs) > 3) return null;
  final p3 = ((numCoeffs[3] ?? IntegerNumber.zero) / a).simplify();
  final p2 = ((numCoeffs[2] ?? IntegerNumber.zero) / a).simplify();
  final p1 = ((numCoeffs[1] ?? IntegerNumber.zero) / a).simplify();
  final p0 = ((numCoeffs[0] ?? IntegerNumber.zero) / a).simplify();
  final xVar = Variable(variable);

  // Case 1: b^2 - 4ac > 0 -> a*(x^2 + r1)*(x^2 + r2)
  final disc = (b * b - const IntegerNumber(Integer(4)) * a * c).simplify();
  if (_isSymbolicPositive(disc)) {
    final sqrtDisc = Pow(disc, FractionNumber.half).simplify();
    final r1 = ((b + sqrtDisc) / (IntegerNumber.two * a)).simplify();
    final r2 = ((b - sqrtDisc) / (IntegerNumber.two * a)).simplify();
    final diffR = (r2 - r1).simplify();
    final q1 = (xVar * xVar + r1).simplify();
    final q2 = (xVar * xVar + r2).simplify();
    final c1Lin = ((p1 - p3 * r1) / diffR).simplify();
    final c1Const = ((p0 - p2 * r1) / diffR).simplify();
    final c2Lin = (-(p1 - p3 * r2) / diffR).simplify();
    final c2Const = (-(p0 - p2 * r2) / diffR).simplify();
    final int1 = _integrateLinearOverQuad(
      c1Lin,
      c1Const,
      q1,
      IntegerNumber.one,
      IntegerNumber.zero,
      variable,
    );
    final int2 = _integrateLinearOverQuad(
      c2Lin,
      c2Const,
      q2,
      IntegerNumber.one,
      IntegerNumber.zero,
      variable,
    );
    if (!_hasUnevaluatedIntegral(int1, variable) &&
        !_hasUnevaluatedIntegral(int2, variable)) {
      return (int1 + int2).simplify();
    }
  }

  final cNorm = (c / a).simplify();
  final bNorm = (b / a).simplify();
  if (!_isSymbolicPositive(cNorm)) return null;

  final r = Pow(cNorm, FractionNumber.half).simplify();
  final sSq = (IntegerNumber.two * r - bNorm).simplify();
  if (!_isSymbolicPositive(sSq)) return null;
  final s = Pow(sSq, FractionNumber.half).simplify();

  final q1 = (xVar * xVar - s * xVar + r).simplify();
  final q2 = (xVar * xVar + s * xVar + r).simplify();

  final diffAlpha = ((p2 - p0 / r) / s).simplify();
  final sumBeta = (p0 / r).simplify();
  final diffBeta = ((p1 - r * p3) / s).simplify();

  final alpha1 = ((p3 + diffAlpha) / IntegerNumber.two).simplify();
  final alpha2 = ((p3 - diffAlpha) / IntegerNumber.two).simplify();
  final beta1 = ((sumBeta + diffBeta) / IntegerNumber.two).simplify();
  final beta2 = ((sumBeta - diffBeta) / IntegerNumber.two).simplify();

  final int1 = _integrateLinearOverQuad(
    alpha1,
    beta1,
    q1,
    IntegerNumber.one,
    (-s).simplify(),
    variable,
  );
  final int2 = _integrateLinearOverQuad(
    alpha2,
    beta2,
    q2,
    IntegerNumber.one,
    s,
    variable,
  );
  if (_hasUnevaluatedIntegral(int1, variable) ||
      _hasUnevaluatedIntegral(int2, variable)) {
    return null;
  }
  return (int1 + int2).simplify();
}

Expr? _tryDistinctLinearPartialFractions(
  Expr left,
  Expr right,
  String variable,
) {
  if (right is! Mul) return null;
  final linFactors = <({Expr factor, Expr a, Expr b})>[];
  var constScale = IntegerNumber.one as Expr;
  for (final f in right.factors) {
    if (!f.dependsOn(variable)) {
      constScale = (constScale * f).simplify();
      continue;
    }
    if (f.matchLinear(variable) case (:final a, :final b)) {
      linFactors.add((factor: f, a: a, b: b));
    } else {
      return null;
    }
  }
  if (linFactors.length < 2 || linFactors.length > 5) return null;
  final degLeft = polynomialDegree(left.expand().simplify(), variable);
  if (degLeft == null || degLeft >= linFactors.length) return null;

  final terms = <Expr>[];
  for (var i = 0; i < linFactors.length; i++) {
    final fi = linFactors[i];
    final root = (-fi.b / fi.a).simplify();
    final numAtRoot = left.substitute(variable, root).simplify();
    var denAtRoot = constScale * fi.a;
    for (var j = 0; j < linFactors.length; j++) {
      if (i != j) {
        denAtRoot =
            (denAtRoot * linFactors[j].factor.substitute(variable, root))
                .simplify();
      }
    }
    if (denAtRoot is Number && denAtRoot.isZero) return null;
    final coeff = (numAtRoot / denAtRoot).simplify();
    terms.add((coeff * Ln(Abs(fi.factor))).simplify());
  }
  return Add(terms).simplify();
}
