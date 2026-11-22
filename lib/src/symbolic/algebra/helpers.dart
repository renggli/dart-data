import '../assumptions.dart';
import '../ast.dart';
import '../number/integer.dart';
import 'expand.dart';
import 'simplify.dart';
import 'term_accumulator.dart';

/// Returns whether [expr] has at least [limit] AST nodes.
bool exceedsNodeBudget(Expr expr, [int limit = 500]) {
  var count = 0;
  var exceeded = false;
  expr.anyNode((_) {
    count++;
    if (count >= limit) {
      exceeded = true;
      return true;
    }
    return false;
  });
  return exceeded;
}

/// Splits an expression into `(numerator, denominator)` by extracting
/// [FractionNumber] denominators and negative-exponent [Pow] factors.
///
/// When [expr] has no denominator factors, returns `(expr, IntegerNumber.one)`.
(Expr, Expr) splitNumeratorDenominator(Expr expr) => switch (expr) {
  FractionNumber(:final numerator, :final denominator) => (
    IntegerNumber(numerator),
    IntegerNumber(denominator),
  ),
  Pow(:final base, exponent: final RealNumeric exp, :final isSimplified)
      when exp.isNegative =>
    () {
      final posExp = exp.neg();
      final den = posExp.isOne
          ? base
          : Pow(base, posExp, isSimplified: isSimplified);
      return (IntegerNumber.one, den);
    }(),
  Mul(:final factors, :final isSimplified) => () {
    final numFactors = <Expr>[];
    final denFactors = <Expr>[];
    for (final f in factors) {
      switch (f) {
        case FractionNumber(:final numerator, :final denominator):
          if (!numerator.isOne) {
            numFactors.add(IntegerNumber(numerator));
          }
          denFactors.add(IntegerNumber(denominator));
        case Pow(
              :final base,
              exponent: final RealNumeric exp,
              isSimplified: final fSimplified,
            )
            when exp.isNegative:
          final posExp = exp.neg();
          denFactors.add(
            posExp.isOne ? base : Pow(base, posExp, isSimplified: fSimplified),
          );
        default:
          numFactors.add(f);
      }
    }
    if (denFactors.isEmpty) return (expr, IntegerNumber.one);
    final numPart = switch (numFactors) {
      [] => IntegerNumber.one,
      [final single] => single,
      _ => Mul(numFactors, isSimplified: isSimplified),
    };
    final denPart = switch (denFactors) {
      [final single] => single,
      _ => Mul(denFactors, isSimplified: isSimplified),
    };
    return (numPart, denPart);
  }(),
  _ => (expr, IntegerNumber.one),
};

/// Computes the degree of [expr] as a univariate polynomial in [variable],
/// or returns `null` if [expr] is not a polynomial in [variable].
int? polynomialDegree(Expr expr, String variable) {
  if (!expr.dependsOn(variable)) return 0;
  return switch (expr) {
    Variable(:final name) when name == variable => 1,
    Add(:final terms) => () {
      var maxD = 0;
      for (final t in terms) {
        final d = polynomialDegree(t, variable);
        if (d == null) return null;
        if (d > maxD) maxD = d;
      }
      return maxD;
    }(),
    Mul(:final factors) => () {
      var sumD = 0;
      for (final f in factors) {
        final d = polynomialDegree(f, variable);
        if (d == null) return null;
        sumD += d;
      }
      return sumD;
    }(),
    Pow(:final base, exponent: IntegerNumber(:final value))
        when value >= Integer.zero && !value.isBig =>
      () {
        final db = polynomialDegree(base, variable);
        return db != null ? db * value.toInt() : null;
      }(),
    Pow(:final base, exponent: RealNumber(:final value))
        when value >= 0 && value == value.roundToDouble() =>
      () {
        final db = polynomialDegree(base, variable);
        return db != null ? db * value.round() : null;
      }(),
    _ => null,
  };
}

/// Extracts univariate polynomial coefficients for [expr] in [variable].
///
/// Returns a map where each key `k >= 0` is the power of [variable] and the
/// value is the coefficient expression independent of [variable], or `null` if
/// [expr] is not a polynomial in [variable].
Map<int, Expr>? extractPolynomialCoefficients(Expr expr, String variable) {
  if (!expr.dependsOn(variable)) {
    final simplified = expr.simplify();
    return simplified is RationalNumber && simplified.isZero
        ? {0: IntegerNumber.zero}
        : {0: simplified};
  }
  if (!_canBePolynomialAfterExpand(expr, variable)) return null;
  final expanded = (expr.isSimplified && !_needsExpansion(expr))
      ? expr
      : expr.expand().simplify();
  if (!expanded.dependsOn(variable)) {
    return expanded is RationalNumber && expanded.isZero
        ? {0: IntegerNumber.zero}
        : {0: expanded};
  }
  if (polynomialDegree(expanded, variable) == null) return null;
  final acc = MonomialAccumulator(assumptions: Assumptions.none)..add(expanded);
  return acc.extractPolynomialCoefficients(variable);
}

/// Returns the maximum degree `k >= 0` with a non-zero coefficient in [coeffs],
/// or `-1` if [coeffs] has no non-zero terms.
int maxPolynomialDegree(Map<int, Expr> coeffs) {
  var maxD = -1;
  for (final MapEntry(key: deg, value: coeff) in coeffs.entries) {
    if (!MonomialAccumulator.isAlgebraicallyZero(coeff) && deg > maxD) {
      maxD = deg;
    }
  }
  return maxD;
}

/// Reconstructs a simplified polynomial [Expr] in [variable] from a
/// degree-to-coefficient map [coeffs].
Expr buildPolynomialFromCoefficients(Map<int, Expr> coeffs, String variable) {
  final x = Variable(variable);
  final terms = <Expr>[];
  final sortedDegrees = coeffs.keys.toList()..sort();
  for (final deg in sortedDegrees) {
    final c = coeffs[deg]!.simplify();
    if (MonomialAccumulator.isAlgebraicallyZero(c)) continue;
    final xPow = deg == 0
        ? IntegerNumber.one
        : deg == 1
        ? x
        : Pow(x, IntegerNumber.of(deg));
    terms.add(deg == 0 ? c : (c * xPow).simplify());
  }
  return switch (terms) {
    [] => IntegerNumber.zero,
    [final single] => single,
    _ => Add(terms).simplify(),
  };
}

bool _canBePolynomialAfterExpand(Expr expr, String variable) {
  if (!expr.dependsOn(variable)) return true;
  return switch (expr) {
    Variable(:final name) when name == variable => true,
    Add(:final terms) => terms.every(
      (t) => _canBePolynomialAfterExpand(t, variable),
    ),
    Mul(:final factors) => factors.every(
      (f) => _canBePolynomialAfterExpand(f, variable),
    ),
    Pow(:final base, exponent: IntegerNumber(:final value)) when !value.isBig =>
      _canBePolynomialAfterExpand(base, variable),
    Pow(:final base, exponent: RealNumber(:final value))
        when value == value.roundToDouble() =>
      _canBePolynomialAfterExpand(base, variable),
    _ => false,
  };
}

bool _needsExpansion(Expr expr) => expr.anyNode(
  (n) => switch (n) {
    Mul(:final factors) => factors.any((f) => f is Add),
    Pow(:final base, exponent: IntegerNumber(asInt: final e?)) when e > 0 =>
      base is Add,
    _ => false,
  },
);
