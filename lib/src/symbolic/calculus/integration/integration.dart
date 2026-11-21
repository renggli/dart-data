import '../../algebra/approximate.dart';
import '../../algebra/expand.dart';
import '../../algebra/rational.dart';
import '../../algebra/simplify.dart';
import '../../algebra/simplify/domain.dart';
import '../../algebra/term_accumulator.dart';
import '../../algebra/trig.dart';
import '../../assumptions.dart';
import '../../ast.dart';
import '../../compiler.dart';
import '../../number/integer.dart';
import '../differentiation.dart';
import '../linear_form.dart';
import 'definite.dart';
import 'parts.dart';
import 'radical.dart';
import 'rational.dart';
import 'substitution.dart';
import 'trigonometric.dart';

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
  /// Computes the symbolic anti-derivative `∫ f(x) dx` with respect to
  /// [variable], or the definite integral `∫_a^b f(x) dx` when [from] and
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
  /// // area: IntegerNumber(9)
  /// ```
  Expr integrate(
    String variable, {
    Object? from,
    Object? to,
    Assumptions assumptions = Assumptions.none,
  }) => symbolicIntegrate(
    this,
    variable,
    from: from,
    to: to,
    assumptions: assumptions,
  );

  /// Computes an iterated (multiple) integral across [bounds] in sequence from
  /// innermost to outermost integration variable.
  ///
  /// For bounds `[(x_1, a_1, b_1), (x_2, a_2, b_2), ..., (x_n, a_n, b_n)]`,
  /// this evaluates the nested integral from `x_1` out to `x_n`.
  ///
  /// Inner bounds may depend symbolically on outer integration variables
  /// (e.g., integrating over a non-rectangular region `0 <= y <= x`,
  /// `0 <= x <= 1`). When any step lacks a closed-form anti-derivative, an
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

/// Evaluates the indefinite or definite symbolic integral of [function] with
/// respect to [variable].
Expr symbolicIntegrate(
  Expr function,
  String variable, {
  Object? from,
  Object? to,
  required Assumptions assumptions,
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
      antiDerivative: antiDerivative,
    );
  }

  try {
    return antiDerivative(
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

/// Computes the symbolic anti-derivative of [expr] with respect to [variable].
Expr antiDerivative(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  final node = expr.simplify(assumptions: assumptions);

  if (!node.dependsOn(variable)) {
    if (node is Number && node.isZero) {
      return IntegerNumber.zero;
    }
    return (node * Variable(variable)).simplify(assumptions: assumptions);
  }

  if (depth < 2 && node.anyNode((n) => n is Binomial)) {
    Expr expandBinomial(Expr e) {
      final mapped = e.mapChildren(expandBinomial);
      if (mapped
          case Binomial(left: final u, right: IntegerNumber(asInt: final k?))
          when u.dependsOn(variable) && k >= 1 && k <= 8) {
        var fact = 1;
        for (var j = 2; j <= k; j++) {
          fact *= j;
        }
        return Mul([for (var j = 0; j < k; j++) u - IntegerNumber.of(j)]) /
            IntegerNumber.of(fact);
      }
      return mapped;
    }

    final expanded = expandBinomial(node).simplify(assumptions: assumptions);
    if (expanded != node) {
      final res = antiDerivative(
        expanded,
        variable,
        assumptions: assumptions,
        depth: depth + 1,
      );
      if (!hasUnevaluatedIntegral(res, variable)) return res;
    }
  }

  final result = switch (node) {
    Derivative(:final expr, variable: final v, :final order)
        when v == variable =>
      order == 1
          ? expr
          : expr.derivative(v, order: order - 1, assumptions: assumptions),
    Variable(:final name) when name == variable =>
      (Pow(node, IntegerNumber.two) / IntegerNumber.two).simplify(
        assumptions: assumptions,
      ),
    Add(:final terms) => () {
      final sumRes = Add([
        for (final term in terms)
          antiDerivative(
            term,
            variable,
            assumptions: assumptions,
            depth: depth,
          ),
      ]).simplify(assumptions: assumptions);
      if (depth == 0 && hasUnevaluatedIntegral(sumRes, variable)) {
        final paired = _tryAdditiveProductRule(
          node,
          variable,
          assumptions: assumptions,
        );
        if (paired != null) return paired;
      }
      return sumRes;
    }(),
    Sin(expr: final inner) =>
      _antiDerivSin(inner, variable) ?? unsupportedIntegral(node, variable),
    Cos(expr: final inner) =>
      _antiDerivCos(inner, variable) ?? unsupportedIntegral(node, variable),
    Tan(expr: final inner) =>
      _antiDerivTan(inner, variable, assumptions: assumptions) ??
          unsupportedIntegral(node, variable),
    Asin(expr: final inner) =>
      _antiDerivAsin(inner, variable) ?? unsupportedIntegral(node, variable),
    Acos(expr: final inner) =>
      _antiDerivAcos(inner, variable) ?? unsupportedIntegral(node, variable),
    Atan(expr: final inner) =>
      _antiDerivAtan(inner, variable) ?? unsupportedIntegral(node, variable),
    Sinh(expr: final inner) =>
      _antiDerivSinh(inner, variable) ?? unsupportedIntegral(node, variable),
    Cosh(expr: final inner) =>
      _antiDerivCosh(inner, variable) ?? unsupportedIntegral(node, variable),
    Tanh(expr: final inner) =>
      _antiDerivTanh(inner, variable) ?? unsupportedIntegral(node, variable),
    Abs(expr: final inner) =>
      _antiDerivAbs(inner, variable) ?? unsupportedIntegral(node, variable),
    Ln(expr: final inner) =>
      _antiDerivLn(inner, variable, assumptions: assumptions, depth: depth) ??
          unsupportedIntegral(node, variable),
    LambertW(expr: final inner, :final branch) =>
      _antiDerivLambertW(inner, branch, variable) ??
          unsupportedIntegral(node, variable),
    Erf(expr: final inner) =>
      _antiDerivErf(inner, variable) ?? unsupportedIntegral(node, variable),
    Erfc(expr: final inner) =>
      _antiDerivErfc(inner, variable) ?? unsupportedIntegral(node, variable),
    Erfi(expr: final inner) =>
      _antiDerivErfi(inner, variable) ?? unsupportedIntegral(node, variable),
    FresnelS(expr: final inner) =>
      _antiDerivFresnelS(inner, variable) ??
          unsupportedIntegral(node, variable),
    FresnelC(expr: final inner) =>
      _antiDerivFresnelC(inner, variable) ??
          unsupportedIntegral(node, variable),
    ExpIntegralEi(expr: final inner) =>
      _antiDerivExpIntegralEi(inner, variable) ??
          unsupportedIntegral(node, variable),
    LogIntegralLi(expr: final inner) =>
      _antiDerivLogIntegralLi(inner, variable) ??
          unsupportedIntegral(node, variable),
    SinIntegralSi(expr: final inner) =>
      _antiDerivSinIntegralSi(inner, variable) ??
          unsupportedIntegral(node, variable),
    CosIntegralCi(expr: final inner) =>
      _antiDerivCosIntegralCi(inner, variable) ??
          unsupportedIntegral(node, variable),
    SinhIntegralShi(expr: final inner) =>
      _antiDerivSinhIntegralShi(inner, variable) ??
          unsupportedIntegral(node, variable),
    CoshIntegralChi(expr: final inner) =>
      _antiDerivCoshIntegralChi(inner, variable) ??
          unsupportedIntegral(node, variable),
    Asinh(expr: final inner) =>
      _antiDerivAsinh(inner, variable) ?? unsupportedIntegral(node, variable),
    Acosh(expr: final inner) =>
      _antiDerivAcosh(inner, variable) ?? unsupportedIntegral(node, variable),
    Atanh(expr: final inner) =>
      _antiDerivAtanh(inner, variable) ?? unsupportedIntegral(node, variable),
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
    Mul() => _antiDerivMul(
      node,
      variable,
      assumptions: assumptions,
      depth: depth,
    ),
    _ => unsupportedIntegral(node, variable),
  };

  if (depth < 2 && node is! Add && hasUnevaluatedIntegral(result, variable)) {
    if (_isRationalIn(node, variable) && _hasNestedRational(node, variable)) {
      final combined = node.together(assumptions: assumptions);
      if (combined != node) {
        final combRes = antiDerivative(
          combined,
          variable,
          assumptions: assumptions,
          depth: depth + 1,
        );
        if (!hasUnevaluatedIntegral(combRes, variable)) return combRes;
      }
    }
    if (trySymbolicBinomialAffine(node, variable, assumptions: assumptions)
        case final symBinomRes?) {
      return symBinomRes;
    }
    if (tryMixedTrigLogExp(node, variable, assumptions: assumptions)
        case final mixedRes?) {
      return mixedRes;
    }
    if (tryAffineRadicalSubstitution(
          node,
          variable,
          assumptions: assumptions,
          depth: depth,
        )
        case final affineRes?) {
      return affineRes;
    }
    if (tryFractionalLinearRadical(
          node,
          variable,
          assumptions: assumptions,
          depth: depth,
        )
        case final fracLinRes?) {
      return fracLinRes;
    }
    if (tryFactorRadicandPower(
          node,
          variable,
          assumptions: assumptions,
          depth: depth,
        )
        case final factorRadRes?) {
      return factorRadRes;
    }
    if (tryVariableRootSubstitution(
          node,
          variable,
          assumptions: assumptions,
          depth: depth,
        )
        case final varRootRes?) {
      return varRootRes;
    }
    if (tryChebyshevBinomial(
          node,
          variable,
          assumptions: assumptions,
          depth: depth,
        )
        case final chebRes?) {
      return chebRes;
    }
    if (tryTrigRadicalSubstitution(
          node,
          variable,
          assumptions: assumptions,
          depth: depth,
        )
        case final trigRadRes?) {
      return trigRadRes;
    }
    if (tryHalfAngleTrigRadical(
          node,
          variable,
          assumptions: assumptions,
          depth: depth,
        )
        case final halfAngleRes?) {
      return halfAngleRes;
    }
    if (tryRealRadicalRewrite(
          node,
          variable,
          assumptions: assumptions,
          depth: depth,
        )
        case final realRadRes?) {
      return realRadRes;
    }
    if (tryUSubstitution(node, variable, assumptions: assumptions, depth: depth)
        case final uSubRes?) {
      return uSubRes;
    }
    if (tryExponentialSubstitution(
          node,
          variable,
          assumptions: assumptions,
          depth: depth,
        )
        case final expSubRes?) {
      return expSubRes;
    }
    if (tryRationalTrigSubstitution(
          node,
          variable,
          assumptions: assumptions,
          depth: depth,
        )
        case final trigSubRes?) {
      return trigSubRes;
    }
    if (tryHyperbolicRationalSubstitution(
          node,
          variable,
          assumptions: assumptions,
          depth: depth,
        )
        case final hypSubRes?) {
      return hypSubRes;
    }
    if (node is! Tan &&
        node.anyNode((n) => n is Tan && n.dependsOn(variable))) {
      final rewritten = _rewriteTanToSinCos(
        node,
        variable,
      ).simplify(assumptions: assumptions);
      if (rewritten != node) {
        final tanRes = antiDerivative(
          rewritten,
          variable,
          assumptions: assumptions,
          depth: depth + 1,
        );
        if (!hasUnevaluatedIntegral(tanRes, variable)) return tanRes;
      }
    }
    if (_tryExpandTrigAtan(node, variable, assumptions: assumptions)
        case final atanTrigRes?) {
      final res = antiDerivative(
        atanTrigRes,
        variable,
        assumptions: assumptions,
        depth: depth + 1,
      );
      if (!hasUnevaluatedIntegral(res, variable)) return res;
    }
    final powLogRewritten = _rewritePowerLogIdentities(
      node,
      variable,
    ).simplify(assumptions: assumptions);
    if (powLogRewritten != node) {
      final res = antiDerivative(
        powLogRewritten,
        variable,
        assumptions: assumptions,
        depth: depth + 1,
      );
      if (!hasUnevaluatedIntegral(res, variable)) return res;
    }
  }
  if (depth == 2 && node is! Add && hasUnevaluatedIntegral(result, variable)) {
    if (tryRealRadicalRewrite(
          node,
          variable,
          assumptions: assumptions,
          depth: depth,
        )
        case final realRadRes?) {
      return realRadRes;
    }
  }
  return result;
}

/// Returns a simplified unevaluated [Integral] node for [expr] in [variable].
Expr unsupportedIntegral(Expr expr, String variable) =>
    Integral(expr, variable, isSimplified: true);

bool _isRationalIn(Expr expr, String variable) {
  if (!expr.dependsOn(variable)) return true;
  return switch (expr) {
    Variable(:final name) => name == variable,
    Add(:final terms) => terms.every((t) => _isRationalIn(t, variable)),
    Mul(:final factors) => factors.every((f) => _isRationalIn(f, variable)),
    Pow(:final base, exponent: IntegerNumber()) => _isRationalIn(
      base,
      variable,
    ),
    _ => false,
  };
}

bool _hasNestedRational(Expr expr, String variable) {
  bool hasNegVarPow(Expr e) {
    if (e case Pow(:final base, exponent: IntegerNumber(isNegative: true))
        when base.dependsOn(variable)) {
      return true;
    }
    var found = false;
    e.mapChildren((c) {
      if (!found && hasNegVarPow(c)) found = true;
      return c;
    });
    return found;
  }

  final (numPart, denPart) = splitNumeratorDenominator(expr);
  return hasNegVarPow(numPart) || hasNegVarPow(denPart);
}

/// Whether [base] is a valid positive non-unit exponential base.
bool isValidExponentialBase(Expr base) => switch (base) {
  RationalNumber(:final isNegative, :final isZero, :final isOne) =>
    !isNegative && !isZero && !isOne,
  RealNumber(:final value) => value > 0 && value != 1.0,
  _ => true,
};

/// Extracts `u` if [expr] has the form `u^(2*k)` for positive integer `k`.
Expr? extractSquareBase(Expr expr) => switch (expr) {
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

/// Extracts `sqrt(c) * u` if [expr] has the form `c * u^(2*k)` in [variable].
Expr? extractScaledSquareBase(Expr expr, String variable) {
  final direct = extractSquareBase(expr);
  if (direct != null) return direct;
  if (expr case Mul(:final factors)) {
    final (:constFactors, :varFactors) = partitionFactors(factors, variable);
    if (varFactors case [final varPart] when constFactors.isNotEmpty) {
      final constPart = switch (constFactors) {
        [final single] => single,
        _ => Mul(constFactors).simplify(),
      };
      if (isSymbolicPositive(constPart)) {
        if (extractSquareBase(varPart) case final sq?) {
          return (Pow(constPart, FractionNumber.half).simplify() * sq)
              .simplify();
        }
      }
    }
  }
  return null;
}

/// Whether [expr] carries a leading syntactic negative sign.
bool isSyntacticallyNegative(Expr expr) => switch (expr) {
  RealNumeric(:final sign) => sign < 0,
  Mul(:final factors) => factors.where(isSyntacticallyNegative).length.isOdd,
  _ => false,
};

/// Whether [expr] is a positive numeric constant or lacks a syntactic negative sign.
bool isSymbolicPositive(Expr expr) {
  if (expr is RealNumeric) return expr.sign > 0;
  if (expr.freeVariables.isEmpty) return isPositiveConstant(expr);
  return !isSyntacticallyNegative(expr);
}

/// Extracts odd integer `k` (`|k| <= 15`) when [exponent] equals `k / 2`.
int? halfIntExponent(Expr exponent) {
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

Expr? _antiDerivSin(Expr inner, String variable) {
  if (inner.matchLinear(variable) case (:final a, b: _)) {
    return (-Cos(inner) / a).simplify();
  }
  if (_matchScaledSquare(inner, variable) case final a?) {
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

Expr? _antiDerivCos(Expr inner, String variable) {
  if (inner.matchLinear(variable) case (:final a, b: _)) {
    return (Sin(inner) / a).simplify();
  }
  if (_matchScaledSquare(inner, variable) case final a?) {
    final absA = isNegativeConstant(a) ? (-a).simplify() : a;
    final twoA = (IntegerNumber.two * absA).simplify();
    final scale = Pow(Constant.pi / twoA, FractionNumber.half);
    final arg =
        Pow(twoA / Constant.pi, FractionNumber.half) * Variable(variable);
    return (scale * FresnelC(arg)).simplify();
  }
  return null;
}

Expr? _matchScaledSquare(Expr expr, String variable) {
  final coeffs = extractPolynomialCoefficients(expr, variable);
  if (coeffs == null || maxPolynomialDegree(coeffs) != 2) return null;
  final c1 = coeffs[1] ?? IntegerNumber.zero;
  final c0 = coeffs[0] ?? IntegerNumber.zero;
  if (c1 != IntegerNumber.zero || c0 != IntegerNumber.zero) return null;
  return coeffs[2];
}

/// Returns `ln(u)` when `u` is proven positive under [assumptions] or may
/// evaluate to a complex value, otherwise `ln(|u|)`.
Expr logAntiderivative(Expr u, Assumptions assumptions) =>
    isPositiveExpr(u, assumptions: assumptions) || _mayBeComplexExpr(u)
    ? Ln(u)
    : Ln(Abs(u));

Expr? _antiDerivTan(
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

Expr? _antiDerivLn(
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
      return ((arg * Ln(inner) - LogIntegralLi(arg)) / a).simplify(
        assumptions: assumptions,
      );
    }
  }
  if (depth < 2) {
    if (inner case Pow(:final base, :final exponent)
        when !base.dependsOn(variable)) {
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

Expr _antiDerivPow(
  Expr base,
  Expr exponent,
  Expr original,
  String variable, {
  required Assumptions assumptions,
}) {
  // Form: (ax + b)^n
  if (!exponent.dependsOn(variable)) {
    if (base.matchLinear(variable) case (:final a, b: _)) {
      if (exponent == IntegerNumber.negativeOne ||
          (exponent is RealNumber && exponent.value == -1.0)) {
        return (logAntiderivative(base, assumptions) / a).simplify(
          assumptions: assumptions,
        );
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
        if (_matchScaledSquare(inner, variable) != null) {
          const half = FractionNumber.half;
          final reduced =
              (half * (IntegerNumber.one - Cos(IntegerNumber.two * inner)))
                  .simplify(assumptions: assumptions);
          return antiDerivative(
            reduced,
            variable,
            assumptions: assumptions,
            depth: 1,
          );
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
        if (_matchScaledSquare(inner, variable) != null) {
          const half = FractionNumber.half;
          final reduced =
              (half * (IntegerNumber.one + Cos(IntegerNumber.two * inner)))
                  .simplify(assumptions: assumptions);
          return antiDerivative(
            reduced,
            variable,
            assumptions: assumptions,
            depth: 1,
          );
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
          final rem = antiDerivative(
            Pow(Sin(inner), nMinus2).simplify(assumptions: assumptions),
            variable,
            assumptions: assumptions,
          );
          if (!hasUnevaluatedIntegral(rem, variable)) {
            return (term1 + (nMinus1 / nExpr) * rem).simplify(
              assumptions: assumptions,
            );
          }
        }
      }
      if (base case Cos(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final nExpr = IntegerNumber.of(n);
          final nMinus1 = IntegerNumber.of(n - 1);
          final nMinus2 = IntegerNumber.of(n - 2);
          final term1 = (Pow(Cos(inner), nMinus1) * Sin(inner) / (nExpr * a))
              .simplify(assumptions: assumptions);
          final rem = antiDerivative(
            Pow(Cos(inner), nMinus2).simplify(assumptions: assumptions),
            variable,
            assumptions: assumptions,
          );
          if (!hasUnevaluatedIntegral(rem, variable)) {
            return (term1 + (nMinus1 / nExpr) * rem).simplify(
              assumptions: assumptions,
            );
          }
        }
      }
      if (base case Sinh(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final nExpr = IntegerNumber.of(n);
          final nMinus1 = IntegerNumber.of(n - 1);
          final nMinus2 = IntegerNumber.of(n - 2);
          final term1 = (Pow(Sinh(inner), nMinus1) * Cosh(inner) / (nExpr * a))
              .simplify(assumptions: assumptions);
          final rem = antiDerivative(
            Pow(Sinh(inner), nMinus2).simplify(assumptions: assumptions),
            variable,
            assumptions: assumptions,
          );
          if (!hasUnevaluatedIntegral(rem, variable)) {
            return (term1 - (nMinus1 / nExpr) * rem).simplify(
              assumptions: assumptions,
            );
          }
        }
      }
      if (base case Cosh(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final nExpr = IntegerNumber.of(n);
          final nMinus1 = IntegerNumber.of(n - 1);
          final nMinus2 = IntegerNumber.of(n - 2);
          final term1 = (Pow(Cosh(inner), nMinus1) * Sinh(inner) / (nExpr * a))
              .simplify(assumptions: assumptions);
          final rem = antiDerivative(
            Pow(Cosh(inner), nMinus2).simplify(assumptions: assumptions),
            variable,
            assumptions: assumptions,
          );
          if (!hasUnevaluatedIntegral(rem, variable)) {
            return (term1 + (nMinus1 / nExpr) * rem).simplify(
              assumptions: assumptions,
            );
          }
        }
      }
      if (base case Tan(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final nMinus1 = IntegerNumber.of(n - 1);
          final nMinus2 = IntegerNumber.of(n - 2);
          final term1 = (Pow(Tan(inner), nMinus1) / (nMinus1 * a)).simplify(
            assumptions: assumptions,
          );
          final rem = antiDerivative(
            Pow(Tan(inner), nMinus2).simplify(assumptions: assumptions),
            variable,
            assumptions: assumptions,
          );
          if (!hasUnevaluatedIntegral(rem, variable)) {
            return (term1 - rem).simplify(assumptions: assumptions);
          }
        }
      }
      if (base case Tanh(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final nMinus1 = IntegerNumber.of(n - 1);
          final nMinus2 = IntegerNumber.of(n - 2);
          final term1 = (-Pow(Tanh(inner), nMinus1) / (nMinus1 * a)).simplify(
            assumptions: assumptions,
          );
          final rem = antiDerivative(
            Pow(Tanh(inner), nMinus2).simplify(assumptions: assumptions),
            variable,
            assumptions: assumptions,
          );
          if (!hasUnevaluatedIntegral(rem, variable)) {
            return (term1 + rem).simplify(assumptions: assumptions);
          }
        }
      }
    }
    // Negative powers of sin and cos: sin(ax+b)^(-k), cos(ax+b)^(-k) for 3 <= k <= 12
    if (exponent case IntegerNumber(asInt: final negK?)
        when negK <= -3 && negK >= -12) {
      final k = -negK;
      final km1 = IntegerNumber.of(k - 1);
      final km2 = IntegerNumber.of(k - 2);
      if (base case Cos(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final term1 = (Sin(inner) / (km1 * a * Pow(Cos(inner), km1)))
              .simplify(assumptions: assumptions);
          final rem = antiDerivative(
            Pow(Cos(inner), -km2).simplify(assumptions: assumptions),
            variable,
            assumptions: assumptions,
          );
          if (!hasUnevaluatedIntegral(rem, variable)) {
            return (term1 + (km2 / km1) * rem).simplify(
              assumptions: assumptions,
            );
          }
        }
      }
      if (base case Sin(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final term1 = (-Cos(inner) / (km1 * a * Pow(Sin(inner), km1)))
              .simplify(assumptions: assumptions);
          final rem = antiDerivative(
            Pow(Sin(inner), -km2).simplify(assumptions: assumptions),
            variable,
            assumptions: assumptions,
          );
          if (!hasUnevaluatedIntegral(rem, variable)) {
            return (term1 + (km2 / km1) * rem).simplify(
              assumptions: assumptions,
            );
          }
        }
      }
    }
    // Powers of logarithms: ln(ax + b)^k for 2 <= k <= 6 and ln(ax + b)^(-k) for 2 <= k <= 6
    if (base case Ln(expr: final inner)) {
      if (exponent case IntegerNumber(asInt: final k?) when k >= 2 && k <= 6) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final kExpr = IntegerNumber.of(k);
          final term1 = ((inner / a) * original).simplify(
            assumptions: assumptions,
          );
          final rem = antiDerivative(
            Pow(
              base,
              IntegerNumber.of(k - 1),
            ).simplify(assumptions: assumptions),
            variable,
            assumptions: assumptions,
          );
          if (!hasUnevaluatedIntegral(rem, variable)) {
            return (term1 - kExpr * rem).simplify(assumptions: assumptions);
          }
        }
      }
      if (exponent case IntegerNumber(asInt: final negK?)
          when negK <= -2 && negK >= -6) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final k = -negK;
          final km1 = IntegerNumber.of(k - 1);
          final term1 = (-inner / (a * km1 * Pow(base, km1))).simplify(
            assumptions: assumptions,
          );
          final rem = antiDerivative(
            Pow(
              base,
              IntegerNumber.of(-(k - 1)),
            ).simplify(assumptions: assumptions),
            variable,
            assumptions: assumptions,
          );
          if (!hasUnevaluatedIntegral(rem, variable)) {
            return (term1 + rem / km1).simplify(assumptions: assumptions);
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
        final ibp = tryIntegrationByParts(
          IntegerNumber.one,
          original,
          variable,
          assumptions: assumptions,
        );
        if (ibp != null) return ibp;
      }
    }
    // Radical quadratic sqrt(a^2 - u^2) or sqrt(u^2 +- a^2) and (Ax^2 + Bx + C)^(n/2)
    if (exponent == FractionNumber.half ||
        (exponent is RealNumber && exponent.value == 0.5)) {
      // Half-angle identities: sqrt(1 +- sin(a*x+b)) and sqrt(1 +- cos(a*x+b))
      if (base case Add(terms: [final t0, final t1])) {
        final (Expr? cTerm, Expr? trigTerm) = !t0.dependsOn(variable)
            ? (t0, t1)
            : (!t1.dependsOn(variable) ? (t1, t0) : (null, null));
        if (cTerm == IntegerNumber.one && trigTerm != null) {
          if (trigTerm case Sin(:final expr)) {
            if (expr.matchLinear(variable) case (:final a, b: _)) {
              final half = (expr / IntegerNumber.two).simplify();
              return (IntegerNumber.two * (Sin(half) - Cos(half)) / a).simplify(
                assumptions: assumptions,
              );
            }
          } else if (trigTerm
              case Mul(factors: [Number(isNegativeOne: true), Sin(:final expr)])
              when expr.matchLinear(variable) != null) {
            final a = expr.matchLinear(variable)!.a;
            final half = (expr / IntegerNumber.two).simplify();
            return (IntegerNumber.two * (Sin(half) + Cos(half)) / a).simplify(
              assumptions: assumptions,
            );
          } else if (trigTerm case Cos(:final expr)) {
            if (expr.matchLinear(variable) case (:final a, b: _)) {
              final half = (expr / IntegerNumber.two).simplify();
              return (IntegerNumber.two *
                      Pow(IntegerNumber.two, FractionNumber.half) *
                      Sin(half) /
                      a)
                  .simplify(assumptions: assumptions);
            }
          } else if (trigTerm
              case Mul(factors: [Number(isNegativeOne: true), Cos(:final expr)])
              when expr.matchLinear(variable) != null) {
            final a = expr.matchLinear(variable)!.a;
            final half = (expr / IntegerNumber.two).simplify();
            return (-IntegerNumber.two *
                    Pow(IntegerNumber.two, FractionNumber.half) *
                    Cos(half) /
                    a)
                .simplify(assumptions: assumptions);
          }
        }
      }
      final radQuad = tryRadicalQuadratic(base, variable);
      if (radQuad != null) return radQuad;
    }
    if (exponent is FractionNumber) {
      final combinedBase = base.together(assumptions: assumptions);
      if (combinedBase != base) {
        final combPow = Pow(
          combinedBase,
          exponent,
        ).simplify(assumptions: assumptions);
        if (combPow != original) {
          return antiDerivative(combPow, variable, assumptions: assumptions);
        }
      }
    }
    if (halfIntExponent(exponent) case final halfExp?) {
      final quadRad = tryQuadraticRadical(
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
        return antiDerivative(expanded, variable, assumptions: assumptions);
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
      final divRes = tryAntiDerivDiv(
        IntegerNumber.one,
        den,
        variable,
        assumptions: assumptions,
      );
      if (divRes != null) return divRes;
    }
  }

  // Form: c^(ax + b) or e^(ax + b) or Gaussian e^(-a*x^2 + b*x + c)
  if (!base.dependsOn(variable)) {
    if (exponent.matchLinear(variable) case (:final a, b: _)) {
      if (base == Constant.e) {
        return (original / a).simplify();
      }
      if (isValidExponentialBase(base)) {
        final denom = (a * Ln(base)).simplify();
        return (original / denom).simplify();
      }
    }
    if (base == Constant.e) {
      final gaussRes = tryGaussianAntiderivative(exponent, variable);
      if (gaussRes != null) return gaussRes;

      // e^(e^(a*x + b)) -> Ei(e^(a*x + b)) / a
      if (exponent case Pow(base: Constant.e, exponent: final innerExp)) {
        if (innerExp.matchLinear(variable) case (:final a, b: _)) {
          return (ExpIntegralEi(exponent) / a).simplify(
            assumptions: assumptions,
          );
        }
      }

      // e^(a/x) -> x * e^(a/x) - a * Ei(a/x)
      final prod = (exponent * Variable(variable)).simplify();
      if (!prod.dependsOn(variable)) {
        return (Variable(variable) * original - prod * ExpIntegralEi(exponent))
            .simplify();
      }
    }
    // b^ln(x) -> x^ln(b)
    if (isValidExponentialBase(base)) {
      if (exponent case Ln(expr: Variable(:final name)) when name == variable) {
        final lnB = Ln(base).simplify(assumptions: assumptions);
        return antiDerivative(
          Pow(Variable(variable), lnB),
          variable,
          assumptions: assumptions,
        );
      }
    }
  }

  return unsupportedIntegral(original, variable);
}

Expr _antiDerivMul(
  Mul original,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  // 1. Check if this product represents a quotient f(x) / g(x) where g depends on variable
  final (numExpr, denExpr) = splitNumeratorDenominator(original);
  if (denExpr != IntegerNumber.one && denExpr.dependsOn(variable)) {
    final divRes = tryAntiDerivDiv(
      numExpr,
      denExpr,
      variable,
      depth: depth,
      assumptions: assumptions,
    );
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
    return antiDerivative(
      varPart,
      variable,
      assumptions: assumptions,
      depth: depth,
    ).scale(constPart);
  }

  // Fast-path for x^m * (a*x + b)^n with large integer n > 8 to avoid expansion.
  if (polynomialDegree(original, variable) != null &&
      varFactors.any(
        (f) =>
            f is Pow &&
            f.exponent is IntegerNumber &&
            (f.exponent as IntegerNumber).value > const Integer(8) &&
            f.base.matchLinear(variable) != null,
      )) {
    final binomRes = trySymbolicBinomialAffine(
      original,
      variable,
      assumptions: assumptions,
    );
    if (binomRes != null) return binomRes;
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
    if (tryChainRule(candidate, otherExpr, variable, assumptions: assumptions)
        case final subRes?) {
      return subRes;
    }
    if (candidate case Pow(
      base: Constant.e,
      exponent: Pow(base: Constant.e, exponent: final innerU),
    )) {
      final uPrime = innerU.derivative(variable).simplify();
      if (otherExpr.matchScalarMultiple(uPrime, variable) case final k?) {
        return (k * ExpIntegralEi(Pow(Constant.e, innerU))).simplify(
          assumptions: assumptions,
        );
      }
    }
  }

  // 3b. Product of sines and cosines:
  if (varFactors case [final f1, final f2]) {
    if (tryTrigProduct(f1, f2, variable) case final trigRes?) {
      return trigRes;
    }
  }
  // Mixed hyperbolic-trigonometric products: rewrite sinh/cosh as exponentials
  final hasTrig = varFactors.any(
    (f) =>
        f is Sin || f is Cos || (f is Pow && (f.base is Sin || f.base is Cos)),
  );
  final hasHyp = varFactors.any(
    (f) =>
        f is Sinh ||
        f is Cosh ||
        (f is Pow && (f.base is Sinh || f.base is Cosh)),
  );
  if (depth < 2 && hasTrig && hasHyp) {
    Expr hypToExp(Expr e) {
      if (e case Sinh(:final expr)) {
        return (Pow(Constant.e, expr) - Pow(Constant.e, -expr)) /
            IntegerNumber.two;
      }
      if (e case Cosh(:final expr)) {
        return (Pow(Constant.e, expr) + Pow(Constant.e, -expr)) /
            IntegerNumber.two;
      }
      return e.mapChildren(hypToExp);
    }

    final rewritten = hypToExp(original)
        .expand()
        .simplify(assumptions: assumptions);
    if (rewritten != original) {
      final res = antiDerivative(
        rewritten,
        variable,
        assumptions: assumptions,
        depth: depth + 1,
      );
      if (!hasUnevaluatedIntegral(res, variable)) return res;
    }
  }
  if (tryTrigPowerProduct(original, IntegerNumber.one, variable)
      case final trigPowRes?) {
    return trigPowRes;
  }
  if (tryExpandTrigBinomialProduct(
        varFactors,
        variable,
        assumptions: assumptions,
        depth: depth,
      )
      case final trigBinomRes?) {
    return trigBinomRes;
  }

  // 3c. Linear polynomial times quadratic radical: (px + q) * (Ax^2 + Bx + C)^(k/2)
  for (var i = 0; i < varFactors.length; i++) {
    if (varFactors[i] case Pow(:final base, :final exponent)) {
      if (halfIntExponent(exponent) case final halfExp?) {
        final others = <Expr>[
          for (var j = 0; j < varFactors.length; j++)
            if (i != j) varFactors[j],
        ];
        final otherExpr = others.length == 1
            ? others.first
            : Mul(others).simplify();
        if (tryQuadraticRadical(otherExpr, base, halfExp, variable)
            case final quadRes?) {
          return quadRes;
        }
      }
    }
  }

  // 3d. Polynomial times trig power or trig product: P(x) * sin^n(u), P(x) * sin(ax)*cos(bx)
  if (tryPolyTrigPowerReduction(varFactors, variable) case final trigPolyRes?) {
    return trigPolyRes;
  }

  // 4. Integration by parts (try pairing one factor with the rest):
  if (varFactors case [final left, final right]) {
    if (tryIntegrationByParts(
          left,
          right,
          variable,
          assumptions: assumptions,
          depth: depth,
        )
        case final ibpLR?) {
      return ibpLR;
    }
    if (tryIntegrationByParts(
          right,
          left,
          variable,
          assumptions: assumptions,
          depth: depth,
        )
        case final ibpRL?) {
      return ibpRL;
    }
  } else {
    for (var i = 0; i < varFactors.length; i++) {
      final candidate = varFactors[i];
      final others = <Expr>[
        for (var j = 0; j < varFactors.length; j++)
          if (i != j) varFactors[j],
      ];
      final otherExpr = Mul(others).simplify(assumptions: assumptions);
      if (tryIntegrationByParts(
            candidate,
            otherExpr,
            variable,
            assumptions: assumptions,
            depth: depth,
          )
          case final ibp1?) {
        return ibp1;
      }
      if (tryIntegrationByParts(
            otherExpr,
            candidate,
            variable,
            assumptions: assumptions,
            depth: depth,
          )
          case final ibp2?) {
        return ibp2;
      }
    }
  }

  // 4b. Expand powered Add factors (2 <= m <= 4) when combined with inverse trig/hyperbolic functions:
  if (depth < 2) {
    bool isInvTrigOrHyp(Expr n) =>
        n is Asin ||
        n is Acos ||
        n is Atan ||
        n is Asinh ||
        n is Acosh ||
        n is Atanh;
    final hasPoweredAdd = varFactors.any(
      (f) =>
          f is Pow &&
          f.base is Add &&
          f.exponent is IntegerNumber &&
          ((f.exponent as IntegerNumber).asInt ?? 0) >= 2 &&
          ((f.exponent as IntegerNumber).asInt ?? 0) <= 4,
    );
    if (hasPoweredAdd && varFactors.any((f) => f.anyNode(isInvTrigOrHyp))) {
      final expandedFactors = <Expr>[
        for (final f in varFactors)
          if (f case Pow(base: Add(), exponent: IntegerNumber(asInt: final m?))
              when m >= 2 && m <= 4)
            f.expand(assumptions: assumptions)
          else
            f,
      ];
      final rewritten = Mul(expandedFactors).simplify(assumptions: assumptions);
      final res = antiDerivative(
        rewritten,
        variable,
        assumptions: assumptions,
        depth: depth + 1,
      );
      if (!hasUnevaluatedIntegral(res, variable)) return res;
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
      final (_, otherDen) = splitNumeratorDenominator(otherExpr);
      final hasVarDen = otherDen.dependsOn(variable);
      final distDepth = hasVarDen ? (depth >= 1 ? depth : 1) : depth;
      final distSum = Add([
        for (final t in terms)
          antiDerivative(
            (t * otherExpr).simplify(assumptions: assumptions),
            variable,
            assumptions: assumptions,
            depth: distDepth,
          ),
      ]).simplify(assumptions: assumptions);
      if (!hasVarDen || !hasUnevaluatedIntegral(distSum, variable)) {
        return distSum;
      }
      if (depth == 0) {
        final distAdd = Add([
          for (final t in terms)
            (t * otherExpr).simplify(assumptions: assumptions),
        ]);
        final paired = _tryAdditiveProductRule(
          distAdd,
          variable,
          assumptions: assumptions,
        );
        if (paired != null) return paired;
      }
      break;
    }
  }

  // 6. Full polynomial expansion fallback (e.g. factored polynomials like (x-1)*(x-2)*(x+2)):
  if (polynomialDegree(original, variable) != null) {
    final expanded = original.expand().simplify(assumptions: assumptions);
    if (expanded != original) {
      return antiDerivative(
        expanded,
        variable,
        assumptions: assumptions,
        depth: depth,
      );
    }
  }

  return unsupportedIntegral(original, variable);
}

Expr? _tryAdditiveProductRule(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
}) {
  final terms = expr is Add ? expr.terms : [expr];
  final candidates = <Expr>{};
  void addCandidate(Expr e) {
    if (e.dependsOn(variable)) candidates.add(e);
  }

  for (final term in terms) {
    final factors = term is Mul ? term.factors : [term];
    for (final f in factors) {
      addCandidate(f);
      if (f case Sin(:final expr)) {
        addCandidate(Cos(expr));
      } else if (f case Cos(:final expr)) {
        addCandidate(Sin(expr));
      } else if (f case Pow(:final base, exponent: IntegerNumber(:final asInt?))
          when asInt < 0) {
        addCandidate(Pow(base, IntegerNumber.negativeOne));
        if (asInt < -1) {
          addCandidate(Pow(base, IntegerNumber.of(asInt + 1)));
        }
      }
    }
  }

  final candList = candidates.toList();
  for (final c in candList) {
    final diff = (c.derivative(variable, assumptions: assumptions) - expr)
        .expand(assumptions: assumptions)
        .simplify(assumptions: assumptions);
    if (diff is Number && diff.isZero) {
      return c.simplify(assumptions: assumptions);
    }
  }
  for (var i = 0; i < candList.length; i++) {
    for (var j = i; j < candList.length; j++) {
      final prod = (candList[i] * candList[j]).simplify(
        assumptions: assumptions,
      );
      if (!prod.dependsOn(variable)) continue;
      final diff = (prod.derivative(variable, assumptions: assumptions) - expr)
          .expand(assumptions: assumptions)
          .simplify(assumptions: assumptions);
      if (diff is Number && diff.isZero) {
        return prod;
      }
    }
  }
  return null;
}

bool _mayBeComplexExpr(Expr expr) => expr.anyNode(
  (node) =>
      node is ComplexNumber ||
      (node is Pow &&
          node.exponent is FractionNumber &&
          (node.exponent as FractionNumber).denominator.isEven &&
          (isSyntacticallyNegative(node.base) ||
              isNegativeConstant(node.base))),
);

Expr _rewriteTanToSinCos(Expr node, String variable) {
  if (!node.dependsOn(variable)) return node;
  if (node case Tan(:final expr)) {
    return Sin(expr) * Pow(Cos(expr), IntegerNumber.negativeOne);
  }
  return node.mapChildren((c) => _rewriteTanToSinCos(c, variable));
}

Expr? _tryExpandTrigAtan(
  Expr node,
  String variable, {
  required Assumptions assumptions,
}) {
  final Expr inner;
  if (node case Sin(:final expr)) {
    inner = expr;
  } else if (node case Cos(:final expr)) {
    inner = expr;
  } else {
    return null;
  }
  if (inner
      case Mul(factors: [IntegerNumber(asInt: final k?), Atan(expr: final u)])
      when k >= 2 && k <= 6 && u.matchLinear(variable) != null) {
    return node
        .expandTrig(assumptions: assumptions)
        .simplify(assumptions: assumptions);
  }
  return null;
}

Expr _rewritePowerLogIdentities(Expr node, String variable) {
  if (!node.dependsOn(variable)) return node;
  final mapped = node.mapChildren(
    (c) => _rewritePowerLogIdentities(c, variable),
  );
  if (mapped case Pow(:final base, :final exponent)) {
    // 1. u^(c / ln(u)) -> e^c
    final (expNum, expDen) = splitNumeratorDenominator(exponent);
    if (expDen case Ln(expr: final lnBase) when lnBase == base) {
      return Pow(Constant.e, expNum);
    }
    // 2. Nested variable power: (c * x^a)^b -> c^b * x^(a*b)
    if (!exponent.dependsOn(variable)) {
      if (base is Variable && base.name == variable) return mapped;
      if (_extractMonomialVarPower(base, variable) case (
        :final scale,
        :final power,
      )) {
        return (Pow(scale, exponent) *
                Pow(Variable(variable), (power * exponent).simplify()))
            .simplify();
      }
    }
  }
  return mapped;
}

({Expr scale, Expr power})? _extractMonomialVarPower(
  Expr expr,
  String variable,
) {
  if (!expr.dependsOn(variable)) {
    return (scale: expr, power: IntegerNumber.zero);
  }
  if (expr is Variable && expr.name == variable) {
    return (scale: IntegerNumber.one, power: IntegerNumber.one);
  }
  if (expr case Pow(base: Variable(:final name), :final exponent)
      when name == variable && !exponent.dependsOn(variable)) {
    return (scale: IntegerNumber.one, power: exponent);
  }
  if (expr is Mul) {
    var scale = IntegerNumber.one as Expr;
    var power = IntegerNumber.zero as Expr;
    for (final f in expr.factors) {
      final sub = _extractMonomialVarPower(f, variable);
      if (sub == null) return null;
      scale = (scale * sub.scale).simplify();
      power = (power + sub.power).simplify();
    }
    return (scale: scale, power: power);
  }
  return null;
}
