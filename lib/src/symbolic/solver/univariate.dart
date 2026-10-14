import '../algebra/factor.dart';
import '../algebra/simplify.dart';
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
  /// // roots: [RationalNumber(-2), RationalNumber(2)]
  /// ```
  List<Expr> solve(String variable) => solveEquation(this, variable);
}

/// Recursively solves univariate equation [expr] = 0 for [variable].
List<Expr> solveEquation(Expr expr, String variable) {
  if (expr is Equal) {
    expr = Sub(expr.left, expr.right);
  }
  expr = expr.simplify();

  if (!expr.dependsOn(variable)) {
    return const [];
  }

  // Rational equation: N(x) / D(x) = 0 -> N(x) = 0 with D(x) != 0
  if (expr is Div) {
    final num = expr.left;
    final den = expr.right;
    if (!num.dependsOn(variable)) {
      return const [];
    }
    final candidates = solveEquation(num, variable);
    if (!den.dependsOn(variable)) {
      return candidates;
    }
    return candidates.where((r) => !_isZeroAt(den, variable, r)).toList();
  }

  // Linear form: a * x + b = 0
  final lin = expr.matchLinear(variable);
  if (lin != null) {
    final sol = ((-lin.b) / lin.a).simplify();
    return [sol];
  }

  // Quadratic form: a * x^2 + b * x + c = 0
  final quad = matchQuadratic(expr, variable);
  if (quad != null) {
    return solveQuadratic(quad.a, quad.b, quad.c);
  }

  // Biquadratic form: a * x^4 + b * x^2 + c = 0
  final biquad = matchBiquadratic(expr, variable);
  if (biquad != null) {
    return solveBiquadratic(biquad.a, biquad.b, biquad.c, variable);
  }

  // Factored products or unrolled factor decomposition:
  final factors = <Expr>[];
  collectFactors(expr, factors);
  final varFactors = factors.where((f) => f.dependsOn(variable)).toList();
  if (varFactors.length > 1) {
    final allRoots = <Expr>[];
    for (final factor in varFactors) {
      allRoots.addAll(solveEquation(factor, variable));
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
    if (varFactored.length > 1 ||
        (varFactored.length == 1 && varFactored.first.simplify() != expr)) {
      final allRoots = <Expr>[];
      for (final factor in varFactored) {
        allRoots.addAll(solveEquation(factor, variable));
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

/// Checks whether a constant symbolic expression [expr] evaluates to zero.
bool isZeroExpr(Expr expr) {
  if (expr is RationalNumber && expr.isZero) return true;
  if (expr is RealNumber && expr.value.abs() < 1e-10) return true;
  if (expr.freeVariables.isEmpty) {
    try {
      final c = expr.evaluateComplex();
      if (c.a.abs() < 1e-10 && c.b.abs() < 1e-10) return true;
    } catch (_) {}
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
      if (existing is Number && simplified is Number) {
        if (existing.isReal && simplified.isReal) {
          return (existing.toDouble() - simplified.toDouble()).abs() < 1e-12;
        } else if (!existing.isReal && !simplified.isReal) {
          final c1 = existing.complexValue;
          final c2 = simplified.complexValue;
          return (c1.a - c2.a).abs() < 1e-12 && (c1.b - c2.b).abs() < 1e-12;
        }
        return false;
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

/// Collects factors of [expr] unrolling multiplication, positive power, and negation.
void collectFactors(Expr expr, List<Expr> target) {
  switch (expr) {
    case Mul(:final left, :final right):
      collectFactors(left, target);
      collectFactors(right, target);
    case Pow(:final base, exponent: RationalNumber(:final numerator))
        when numerator > 0:
      collectFactors(base, target);
    case Neg(:final expr):
      collectFactors(expr, target);
    default:
      if (expr is! Number) {
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
