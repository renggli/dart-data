import '../assumptions.dart';
import '../ast.dart';
import 'expand.dart';
import 'helpers.dart';
import 'rational.dart';
import 'simplify.dart';
import 'trig.dart';

/// Computes a weighted structural cost for [expr] used to select compact
/// canonical forms during multi-strategy normalization.
int expressionCost(Expr expr) {
  switch (expr) {
    case IntegerNumber(:final value):
      return value.abs() > _maxSimpleBigInt ? 2 : 1;
    case FractionNumber():
    case ComplexNumber():
      return 2;
    case RealNumber() || Constant() || Variable():
      return 1;
    case OrderTerm(:final point):
      return 2 + expressionCost(point);
    case Add(:final terms):
      var cost = 1;
      for (final t in terms) {
        cost += expressionCost(t);
      }
      return cost;
    case Mul(:final factors):
      var cost = 1;
      for (final f in factors) {
        cost += expressionCost(f);
      }
      return cost;
    case Pow(:final base, :final exponent):
      final penalty = switch (exponent) {
        RealNumeric(:final isNegative) when isNegative => 2,
        FractionNumber() => 2,
        _ => 0,
      };
      return 2 + penalty + expressionCost(base) + expressionCost(exponent);
    case Call(:final spec, :final args):
      final extra = _isCommonCall(spec.id)
          ? 0
          : (spec.category == FunctionCategory.special ? 4 : 3);
      var cost = 3 + extra;
      for (final a in args) {
        cost += expressionCost(a);
      }
      return cost;
    case Relational(:final left, :final right):
      return 4 + expressionCost(left) + expressionCost(right);
    case Piecewise(:final branches, :final otherwise):
      var cost = 4 + (otherwise != null ? expressionCost(otherwise) : 0);
      for (final (:relation, :expr) in branches) {
        cost += expressionCost(relation) + expressionCost(expr);
      }
      return cost;
    case Integral(:final integrand, :final lower, :final upper):
      return 4 +
          expressionCost(integrand) +
          (lower != null ? expressionCost(lower) : 0) +
          (upper != null ? expressionCost(upper) : 0);
    case Derivative(expr: final body, :final point):
      return 4 +
          expressionCost(body) +
          (point != null ? expressionCost(point) : 0);
    case Limit(expr: final body, :final point):
      return 4 + expressionCost(body) + expressionCost(point);
    case Sum(expr: final body, :final lower, :final upper) ||
        Product(expr: final body, :final lower, :final upper):
      return 4 +
          expressionCost(body) +
          expressionCost(lower) +
          expressionCost(upper);
    case RootSum(:final polynomial, :final body):
      return 5 + expressionCost(polynomial) + expressionCost(body);
  }
}

/// Selects the expression with lowest [expressionCost] (breaking ties by
/// [Expr.nodeCount] while keeping [current] on exact ties).
Expr pickCheapestExpr(Expr current, Iterable<Expr> candidates) {
  var best = current;
  var bestCost = expressionCost(current);
  var bestNodes = current.nodeCount;
  for (final candidate in candidates) {
    final cCost = expressionCost(candidate);
    final cNodes = candidate.nodeCount;
    if (cCost < bestCost || (cCost == bestCost && cNodes < bestNodes)) {
      best = candidate;
      bestCost = cCost;
      bestNodes = cNodes;
    }
  }
  return best;
}

/// Applies bounded polynomial and rational normalizations (`simplify`,
/// `cancel`, and `expand`) and returns the form with lowest [expressionCost].
Expr normalizeAlgebraic(
  Expr expr, {
  Assumptions assumptions = Assumptions.none,
}) {
  final simplified = expr.simplify(assumptions: assumptions);
  if (simplified is Number ||
      simplified is Constant ||
      simplified is Variable ||
      exceedsNodeBudget(simplified, 250)) {
    return simplified;
  }

  final candidates = <Expr>[];
  if (_hasDenominator(simplified)) {
    candidates.add(simplified.cancel(assumptions: assumptions));
  }
  if (_hasExpandableProductOrPower(simplified)) {
    final expanded = simplified
        .expand(assumptions: assumptions)
        .simplify(assumptions: assumptions);
    candidates.add(expanded);
    if (_hasDenominator(expanded)) {
      candidates.add(expanded.cancel(assumptions: assumptions));
    }
  }
  return pickCheapestExpr(simplified, candidates);
}

/// Applies bounded cost-driven normalization across algebraic (`simplify`,
/// `cancel`, `expand`) and trigonometric/hyperbolic (`simplifyTrig`) forms,
/// never returning a higher-cost expression than `expr.simplify()`.
Expr normalizeExpression(
  Expr expr, {
  Assumptions assumptions = Assumptions.none,
}) {
  final alg = normalizeAlgebraic(expr, assumptions: assumptions);
  if (alg is Number ||
      alg is Constant ||
      alg is Variable ||
      exceedsNodeBudget(alg, 250)) {
    return alg;
  }
  final hasTrigOrHyp = alg.anyNode(
    (n) =>
        n is Call &&
        (n.id == FunctionId.sin ||
            n.id == FunctionId.cos ||
            n.id == FunctionId.tan ||
            n.id == FunctionId.sinh ||
            n.id == FunctionId.cosh ||
            n.id == FunctionId.tanh),
  );
  if (!hasTrigOrHyp) return alg;

  final trigNorm = alg.simplifyTrig(assumptions: assumptions);
  final postAlg = exceedsNodeBudget(trigNorm, 250)
      ? trigNorm
      : normalizeAlgebraic(trigNorm, assumptions: assumptions);
  return pickCheapestExpr(alg, [trigNorm, postAlg]);
}

final BigInt _maxSimpleBigInt = BigInt.from(1000000);

bool _isCommonCall(FunctionId id) => switch (id) {
  FunctionId.sin ||
  FunctionId.cos ||
  FunctionId.tan ||
  FunctionId.sinh ||
  FunctionId.cosh ||
  FunctionId.tanh ||
  FunctionId.ln ||
  FunctionId.abs => true,
  _ => false,
};

bool _hasDenominator(Expr expr) => expr.anyNode(
  (n) => switch (n) {
    FractionNumber() => true,
    Pow(exponent: RealNumeric(:final isNegative)) when isNegative => true,
    _ => false,
  },
);

bool _hasExpandableProductOrPower(Expr expr) => expr.anyNode(
  (n) => switch (n) {
    Mul(:final factors) => factors.any((f) => f is Add),
    Pow(:final base, exponent: IntegerNumber(asInt: final e?))
        when e >= 2 && e <= 16 =>
      base is Add,
    _ => false,
  },
);
