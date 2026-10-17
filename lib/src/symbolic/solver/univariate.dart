import '../algebra/factor.dart';
import '../algebra/simplify.dart';
import '../algebra/term_accumulator.dart';
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
/// filtering roots by [domain] (or the [Variable.domain] present in [expr]).
List<Expr> solveEquation(Expr expr, String variable, {VariableDomain? domain}) {
  final effectiveDomain = domain ?? _inferVariableDomain(expr, variable);
  final rawRoots = _solveUnfiltered(expr, variable);
  return _filterByDomain(rawRoots, effectiveDomain);
}

List<Expr> _solveUnfiltered(Expr expr, String variable) {
  if (expr is Equal) {
    expr = expr.left - expr.right;
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
    if (varFactored.length > 1 ||
        (varFactored.length == 1 && varFactored.first.simplify() != expr)) {
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
  var inferred = VariableDomain.unknown;
  expr.anyNode((node) {
    if (node is Variable &&
        node.name == variable &&
        node.domain != VariableDomain.unknown) {
      inferred = node.domain;
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
  if (expr is RationalNumber) return expr.sign > 0;
  if (expr is RealNumber) return expr.value > 0.0;
  if (!expr.isReal) return false;
  if (expr.freeVariables.isEmpty) {
    try {
      final v = expr.evaluate();
      return !v.isNaN && v > 0.0;
    } on Object {
      return false;
    }
  }
  return false;
}

/// Checks whether a constant symbolic expression [expr] evaluates to zero.
bool isZeroExpr(Expr expr) {
  if (expr is Number && expr.isZero) return true;
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
      if (existing is RealNumeric && simplified is RealNumeric) {
        return (existing.toDouble() - simplified.toDouble()).abs() < 1e-12;
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
