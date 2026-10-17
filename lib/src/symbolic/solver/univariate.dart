import '../algebra/factor.dart';
import '../algebra/simplify.dart';
import '../algebra/term_accumulator.dart';
import '../assumptions.dart';
import '../ast.dart';
import '../calculus/linear_form.dart';
import 'polynomial.dart';
import 'transcendental.dart';

/// Extension providing analytical equation solving on [Expr].
extension SolverExtension on Expr {
  /// Solves the algebraic equation $\text{this} = 0$ for [variable].
  ///
  /// Conceptually, this isolates the values of [variable] that satisfy the
  /// equation $\text{this} = 0$ (such as finding roots where $2x - 6 = 0$ or
  /// $x^2 - 5x + 6 = 0$). Formally, this isolates analytical roots of
  /// univariate equations:
  /// - Linear equations: $a x + b = 0 \implies x = -b / a$
  /// - Quadratic polynomials:
  ///   $a x^2 + b x + c = 0 \implies x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}$
  /// - Factored products:
  ///   $f(x) \cdot g(x) = 0 \implies \text{solve}(f) \cup \text{solve}(g)$ via
  ///   the zero-product property
  /// - Invertible transcendental compositions: $\exp(f(x)) = c$,
  ///   $\ln(f(x)) = c$, $\sin(f(x)) = c$, $\cos(f(x)) = c$, and isolated powers
  ///
  /// Returns a list of unique exact solution expressions.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final roots = (x * x - 4).solve('x');
  /// // roots: [IntegerNumber(-2), IntegerNumber(2)]
  /// ```
  List<Expr> solve(String variable, {VariableDomain? domain}) =>
      solveEquation(this, variable, domain: domain);
}

/// Recursively solves univariate equation [expr] = 0 for [variable], optionally
/// filtering roots by [domain] (or the [Variable.effectiveDomain] present in [expr]).
List<Expr> solveEquation(Expr expr, String variable, {VariableDomain? domain}) {
  final effectiveDomain = domain ?? _inferVariableDomain(expr, variable);
  final rawRoots = _solveUnfiltered(expr, variable);
  return _filterByDomain(rawRoots, effectiveDomain);
}

List<Expr> _solveUnfiltered(Expr expr, String variable) {
  if (expr case Equal(:final left, :final right)) {
    expr = left - right;
  }
  expr = expr.simplify();

  if (!expr.dependsOn(variable)) {
    return const [];
  }

  // Rational equation: N(x) / D(x) = 0 -> N(x) = 0 with D(x) != 0
  final (num, den) = splitNumeratorDenominator(expr);
  if (den != IntegerNumber.one && den.dependsOn(variable)) {
    if (!num.dependsOn(variable)) {
      return const [];
    }
    final candidates = _solveUnfiltered(num, variable);
    return candidates.where((r) => !_isZeroAt(den, variable, r)).toList();
  }

  // Linear form: a * x + b = 0
  if (expr.matchLinear(variable) case (:final a, :final b)) {
    return [((-b) / a).simplify()];
  }

  // Quadratic form: a * x^2 + b * x + c = 0
  if (matchQuadratic(expr, variable) case (:final a, :final b, :final c)) {
    return solveQuadratic(a, b, c);
  }

  // Biquadratic form: a * x^4 + b * x^2 + c = 0
  if (matchBiquadratic(expr, variable) case (:final a, :final b, :final c)) {
    return solveBiquadratic(a, b, c, variable);
  }

  // Factored products or unrolled factor decomposition:
  final factors = <Expr>[];
  collectFactors(expr, factors);
  final varFactors = factors.where((f) => f.dependsOn(variable)).toList();
  if (varFactors.length > 1) {
    final allRoots = <Expr>[];
    for (final factor in varFactors) {
      allRoots.addAll(_solveUnfiltered(factor, variable));
    }
    return deduplicateRoots(allRoots);
  }

  // Polynomial factoring step (degree > 2 or multi-term polynomials):
  final factored = expr.factor();
  if (factored != expr) {
    final factoredList = <Expr>[];
    collectFactors(factored, factoredList);
    final varFactored = factoredList
        .where((f) => f.dependsOn(variable))
        .toList();
    final shouldSolveFactors = switch (varFactored) {
      [final single] => single.simplify() != expr,
      [_, _, ...] => true,
      _ => false,
    };
    if (shouldSolveFactors) {
      final allRoots = <Expr>[];
      for (final factor in varFactored) {
        allRoots.addAll(_solveUnfiltered(factor, variable));
      }
      return deduplicateRoots(allRoots);
    }
  }

  // Transcendental isolation: f(u(x)) = C
  final trans = isolateAndInvert(expr, variable);
  if (trans != null) {
    return deduplicateRoots(trans);
  }

  return const [];
}

VariableDomain _inferVariableDomain(Expr expr, String variable) {
  var inferred = Assumptions.domainOf(variable);
  expr.anyNode((node) {
    if (node case Variable(:final name, :final effectiveDomain)
        when name == variable && effectiveDomain != VariableDomain.unknown) {
      inferred = effectiveDomain;
      return true;
    }
    return false;
  });
  return inferred;
}

List<Expr> _filterByDomain(List<Expr> roots, VariableDomain domain) {
  if (domain == VariableDomain.unknown || domain == VariableDomain.complex) {
    return roots;
  }
  return roots.where((root) {
    final s = root.simplify();
    return switch (domain) {
      VariableDomain.unknown || VariableDomain.complex => true,
      VariableDomain.integer => s is IntegerNumber,
      VariableDomain.real => _isRealRoot(s),
      VariableDomain.positive => _isPositiveRealRoot(s),
    };
  }).toList();
}

bool _isRealRoot(Expr expr) {
  if (!expr.isReal) return false;
  if (expr.freeVariables.isEmpty) {
    try {
      final c = expr.evaluateComplex();
      return !c.isNaN && c.b.abs() < 1e-12;
    } on Object {
      return false;
    }
  }
  return true;
}

bool _isPositiveRealRoot(Expr expr) {
  switch (expr) {
    case RationalNumber(:final sign):
      return sign > 0;
    case RealNumber(:final value):
      return value > 0.0;
    case _ when expr.isReal && expr.freeVariables.isEmpty:
      try {
        final v = expr.evaluate();
        return !v.isNaN && v > 0.0;
      } on Object {
        return false;
      }
    case _:
      return false;
  }
}

/// Checks whether a constant symbolic expression [expr] evaluates to zero.
bool isZeroExpr(Expr expr) {
  switch (expr) {
    case Number(isZero: true):
    case RealNumber(:final value) when value.abs() < 1e-10:
      return true;
    case _ when expr.freeVariables.isEmpty:
      try {
        final c = expr.evaluateComplex();
        if (c.a.abs() < 1e-10 && c.b.abs() < 1e-10) return true;
      } catch (_) {}
    case _:
      break;
  }
  return false;
}

/// Deduplicates roots analytically and numerically.
List<Expr> deduplicateRoots(List<Expr> list) {
  final result = <Expr>[];
  for (final item in list) {
    final simplified = item.simplify();
    final isDup = result.any((existing) {
      if (existing == simplified) return true;
      if ((existing, simplified) case (
        final RealNumeric a,
        final RealNumeric b,
      )) {
        return (a.toDouble() - b.toDouble()).abs() < 1e-12;
      }
      if (existing.freeVariables.isEmpty && simplified.freeVariables.isEmpty) {
        try {
          final c1 = existing.evaluateComplex();
          final c2 = simplified.evaluateComplex();
          return (c1.a - c2.a).abs() < 1e-12 && (c1.b - c2.b).abs() < 1e-12;
        } catch (_) {}
      }
      return false;
    });
    if (!isDup) {
      result.add(simplified);
    }
  }
  return result;
}

/// Collects factors of [expr] unrolling multiplication and positive power.
void collectFactors(Expr expr, List<Expr> target) {
  switch (expr) {
    case Mul(:final factors):
      for (final f in factors) {
        collectFactors(f, target);
      }
    case Pow(
          :final base,
          exponent: RationalNumber(:final isNegative, :final isZero),
        )
        when !isNegative && !isZero:
      collectFactors(base, target);
    default:
      if (expr is! Number && expr is! Constant) {
        target.add(expr);
      }
  }
}

bool _isZeroAt(Expr expr, String variable, Expr value) {
  try {
    final sub = expr.substitute(variable, value).simplify();
    return isZeroExpr(sub);
  } catch (_) {
    // If evaluating the denominator at value throws (e.g. pole), exclude value.
    return true;
  }
}
