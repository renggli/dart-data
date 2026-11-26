import '../../algebra/approximate.dart';
import '../../algebra/helpers.dart';
import '../../algebra/rational.dart';
import '../../algebra/simplify.dart';
import '../../assumptions.dart';
import '../../ast.dart';
import '../../compiler.dart';
import '../../number/integer.dart';
import '../differentiation.dart';
import '../linear_form.dart';
import 'definite.dart';
import 'integration_elementary.dart';
import 'integration_power_mul.dart';
import 'radical.dart';
import 'radical_binomial.dart';
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

final class _IntegrationBudget {
  static const int maxSteps = 250;
  static const int maxDepth = 8;
  static const int maxElapsedMs = 250;

  final Stopwatch _stopwatch = Stopwatch()..start();
  final Map<(Expr, String, Assumptions), Expr> memo =
      <(Expr, String, Assumptions), Expr>{};
  int steps = 0;

  bool get isExhausted =>
      steps >= maxSteps || _stopwatch.elapsedMilliseconds >= maxElapsedMs;
}

_IntegrationBudget? _activeBudget;

/// Whether the current [symbolicIntegrate] budget has been exhausted.
bool isIntegrationBudgetExhausted() => _activeBudget?.isExhausted ?? false;

/// Generates a fresh substitution variable name that neither equals
/// [variable] nor collides with any free variable in [expr].
String freshIntegrationVar(
  String prefix,
  Expr expr,
  String variable,
  int depth,
) {
  final used = expr.freeVariables;
  var idx = depth;
  while (true) {
    final candidate = '$prefix$idx';
    if (candidate != variable && !used.contains(candidate)) return candidate;
    idx++;
  }
}

/// Computes the symbolic indefinite or definite integral of [function] with
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
  final prevBudget = _activeBudget;
  final ownBudget = prevBudget == null ? _IntegrationBudget() : null;
  if (ownBudget != null) {
    _activeBudget = ownBudget;
  }
  try {
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
      var res = antiDerivative(function, variable, assumptions: assumptions);
      if (mayBeComplexExpr(function)) {
        res = stripAbsInLn(res);
      }
      return res.simplify(assumptions: assumptions);
    } on UnsupportedError {
      return Integral(
        function.simplify(assumptions: assumptions),
        variable,
        isSimplified: true,
      );
    } on ArgumentError {
      return Integral(
        function.simplify(assumptions: assumptions),
        variable,
        isSimplified: true,
      );
    } on StateError {
      return Integral(
        function.simplify(assumptions: assumptions),
        variable,
        isSimplified: true,
      );
    }
  } finally {
    _activeBudget = prevBudget;
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

  if (depth > _IntegrationBudget.maxDepth) {
    return unsupportedIntegral(node, variable);
  }

  final budget = _activeBudget;
  if (budget != null) {
    if (budget.isExhausted) {
      return unsupportedIntegral(node, variable);
    }
    final key = (node, variable, assumptions);
    if (budget.memo[key] case final cached?) {
      return cached;
    }
    budget.steps++;
    final res = _antiDerivativeCore(
      node,
      variable,
      assumptions: assumptions,
      depth: depth,
    );
    if (!budget.isExhausted &&
        !(depth >= 2 && hasUnevaluatedIntegral(res, variable))) {
      budget.memo[key] = res;
    }
    return res;
  }

  return _antiDerivativeCore(
    node,
    variable,
    assumptions: assumptions,
    depth: depth,
  );
}

Expr _antiDerivativeCore(
  Expr node,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
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

  if (depth == 0 &&
      node.anyNode(
        (n) =>
            n is Pow &&
            n.exponent is FractionNumber &&
            n.base.dependsOn(variable),
      ) &&
      node.anyNode(
        (n) =>
            n is Pow &&
            n.exponent is RealNumeric &&
            (n.exponent as RealNumeric).isNegative &&
            n.base.dependsOn(variable),
      )) {
    if (tryRealRadicalRewrite(
          node,
          variable,
          assumptions: assumptions,
          depth: depth,
        )
        case final realRadRes?) {
      return realRadRes;
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
        final paired = tryAdditiveProductRule(
          node,
          variable,
          assumptions: assumptions,
        );
        if (paired != null) return paired;
        final factoredExp = splitExpSumProduct(node, variable);
        if (factoredExp != node) {
          final expRes = tryUSubstitution(
            factoredExp,
            variable,
            assumptions: assumptions,
            depth: depth,
          );
          if (expRes != null) return expRes;
        }
      }
      return sumRes;
    }(),
    Sin(expr: final inner) =>
      antiDerivSin(inner, variable) ?? unsupportedIntegral(node, variable),
    Cos(expr: final inner) =>
      antiDerivCos(inner, variable) ?? unsupportedIntegral(node, variable),
    Tan(expr: final inner) =>
      antiDerivTan(inner, variable, assumptions: assumptions) ??
          unsupportedIntegral(node, variable),
    Asin(expr: final inner) =>
      antiDerivAsin(inner, variable) ?? unsupportedIntegral(node, variable),
    Acos(expr: final inner) =>
      antiDerivAcos(inner, variable) ?? unsupportedIntegral(node, variable),
    Atan(expr: final inner) =>
      antiDerivAtan(inner, variable) ?? unsupportedIntegral(node, variable),
    Sinh(expr: final inner) =>
      antiDerivSinh(inner, variable) ?? unsupportedIntegral(node, variable),
    Cosh(expr: final inner) =>
      antiDerivCosh(inner, variable) ?? unsupportedIntegral(node, variable),
    Tanh(expr: final inner) =>
      antiDerivTanh(inner, variable) ?? unsupportedIntegral(node, variable),
    Abs(expr: final inner) =>
      antiDerivAbs(inner, variable) ?? unsupportedIntegral(node, variable),
    Ln(expr: final inner) =>
      antiDerivLn(inner, variable, assumptions: assumptions, depth: depth) ??
          unsupportedIntegral(node, variable),
    LambertW(expr: final inner, :final branch) =>
      antiDerivLambertW(inner, branch, variable) ??
          unsupportedIntegral(node, variable),
    Erf(expr: final inner) =>
      antiDerivErf(inner, variable) ?? unsupportedIntegral(node, variable),
    Erfc(expr: final inner) =>
      antiDerivErfc(inner, variable) ?? unsupportedIntegral(node, variable),
    Erfi(expr: final inner) =>
      antiDerivErfi(inner, variable) ?? unsupportedIntegral(node, variable),
    FresnelS(expr: final inner) =>
      antiDerivFresnelS(inner, variable) ?? unsupportedIntegral(node, variable),
    FresnelC(expr: final inner) =>
      antiDerivFresnelC(inner, variable) ?? unsupportedIntegral(node, variable),
    ExpIntegral(expr: final inner) =>
      antiDerivExpIntegralEi(inner, variable) ??
          unsupportedIntegral(node, variable),
    LogIntegral(expr: final inner) =>
      antiDerivLogIntegralLi(inner, variable) ??
          unsupportedIntegral(node, variable),
    SinIntegral(expr: final inner) =>
      antiDerivSinIntegralSi(inner, variable) ??
          unsupportedIntegral(node, variable),
    CosIntegral(expr: final inner) =>
      antiDerivCosIntegralCi(inner, variable) ??
          unsupportedIntegral(node, variable),
    SinhIntegral(expr: final inner) =>
      antiDerivSinhIntegralShi(inner, variable) ??
          unsupportedIntegral(node, variable),
    CoshIntegral(expr: final inner) =>
      antiDerivCoshIntegralChi(inner, variable) ??
          unsupportedIntegral(node, variable),
    Asinh(expr: final inner) =>
      antiDerivAsinh(inner, variable) ?? unsupportedIntegral(node, variable),
    Acosh(expr: final inner) =>
      antiDerivAcosh(inner, variable) ?? unsupportedIntegral(node, variable),
    Atanh(expr: final inner) =>
      antiDerivAtanh(inner, variable) ?? unsupportedIntegral(node, variable),
    Piecewise() => antiDerivPiecewise(node, variable, assumptions: assumptions),
    Pow(:final base, :final exponent) => antiDerivPow(
      base,
      exponent,
      node,
      variable,
      assumptions: assumptions,
      depth: depth,
    ),
    Mul() => antiDerivMul(
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
    if (tryRealRadicalRewrite(
          node,
          variable,
          assumptions: assumptions,
          depth: depth,
        )
        case final realRadRes?) {
      return realRadRes;
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
    if (tryLinearBinomialProductSpecial(
          node,
          variable,
          assumptions: assumptions,
        )
        case final binomSpecRes?) {
      return binomSpecRes;
    }
    if (node is! Tan &&
        node.anyNode((n) => n is Tan && n.dependsOn(variable))) {
      final rewritten = rewriteTanToSinCos(
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
    if (tryExpandTrigAtan(node, variable, assumptions: assumptions)
        case final atanTrigRes?) {
      final res = antiDerivative(
        atanTrigRes,
        variable,
        assumptions: assumptions,
        depth: depth + 1,
      );
      if (!hasUnevaluatedIntegral(res, variable)) return res;
    }
    final powLogRewritten = rewritePowerLogIdentities(
      node,
      variable,
      assumptions: assumptions,
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

/// Extracts odd integer `k` (`k <= 15`) when [exponent] equals `k / 2`.
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
