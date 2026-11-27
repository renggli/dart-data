import '../algebra/approximate.dart';
import '../algebra/expand.dart';
import '../algebra/factor.dart';
import '../algebra/helpers.dart';
import '../algebra/rational.dart';
import '../algebra/simplify.dart';
import '../assumptions.dart';
import '../ast.dart';
import '../calculus/linear_form.dart';
import '../compiler.dart';
import '../oracle/domain_oracle.dart';
import '../oracle/sign.dart';
import '../type/expr_data_type.dart';
import 'polynomial.dart';
import 'transcendental.dart';

/// Extension providing analytical equation solving on [Expr].
extension SolverExtension on Expr {
  /// Solves the algebraic equation `this = 0` for [variable].
  ///
  /// Conceptually, this isolates the values of [variable] that satisfy the
  /// equation `this = 0` (such as finding roots where `2*x - 6 = 0` or
  /// `x^2 - 5*x + 6 = 0`). Formally, this isolates analytical roots of
  /// univariate equations:
  /// - Linear equations: `a * x + b = 0 -> x = -b / a`
  /// - Quadratic polynomials:
  ///   `a * x^2 + b * x + c = 0 -> x = (-b +/- sqrt(b^2 - 4*a*c)) / (2*a)`
  /// - Factored products:
  ///   `f(x) * g(x) = 0 -> solve(f) union solve(g)` via
  ///   the zero-product property
  /// - Invertible transcendental compositions: `exp(f(x)) = c`,
  ///   `ln(f(x)) = c`, `sin(f(x)) = c`, `cos(f(x)) = c`, and isolated powers
  ///
  /// Returns a list of unique exact solution expressions.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final roots = (x * x - 4).solve('x');
  /// // roots: [IntegerNumber(-2), IntegerNumber(2)]
  /// ```
  List<Expr> solve(
    String variable, {
    Assumptions assumptions = Assumptions.none,
  }) => solveEquation(this, variable, assumptions: assumptions);
}

/// Recursively solves univariate equation [expr] = 0 for [variable], optionally
/// filtering roots by [assumptions] for [variable].
List<Expr> solveEquation(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
}) {
  final effectiveDomain = assumptions.domainOf(variable);
  final normalized = expr is Relational && expr.op == RelOp.equal
      ? expr.left - expr.right
      : expr;
  final rawRoots = _solveUnfiltered(expr, variable, assumptions);
  final validRoots = rawRoots
      .where((root) => _isValidRoot(normalized, variable, root, assumptions))
      .toList();
  final filtered = _filterByDomain(validRoots, effectiveDomain, assumptions);
  final bound = assumptions.boundsOf(variable);
  if (bound.isUnbounded) return filtered;
  return filtered
      .where((root) => satisfiesVariableBounds(root, bound, assumptions))
      .toList();
}

/// Checks whether [root] satisfies interval [bound] under [assumptions].
bool satisfiesVariableBounds(
  Expr root,
  VariableBounds bound,
  Assumptions assumptions,
) {
  if (bound.isUnbounded) return true;
  final oracle = DomainOracle(assumptions);
  final s = root.simplify(assumptions: assumptions);
  if (bound.lower case final lo?) {
    final diff = (s - lo).simplify(assumptions: assumptions);
    final sign = oracle.signOf(diff);
    if (sign == Sign.negative) return false;
    if (sign == Sign.zero && !bound.lowerInclusive) return false;
    if (sign == Sign.unknown) {
      final v = oracle.tryStaticRealValue(diff);
      if (v != null) {
        if (v < -1e-12) return false;
        if (!bound.lowerInclusive && v <= 1e-12) return false;
      }
    }
  }
  if (bound.upper case final hi?) {
    final diff = (hi - s).simplify(assumptions: assumptions);
    final sign = oracle.signOf(diff);
    if (sign == Sign.negative) return false;
    if (sign == Sign.zero && !bound.upperInclusive) return false;
    if (sign == Sign.unknown) {
      final v = oracle.tryStaticRealValue(diff);
      if (v != null) {
        if (v < -1e-12) return false;
        if (!bound.upperInclusive && v <= 1e-12) return false;
      }
    }
  }
  return true;
}

/// Checks whether [root] satisfies [domain] under [assumptions].
bool satisfiesVariableDomain(
  Expr root,
  VariableDomain domain,
  Assumptions assumptions,
) {
  if (domain == VariableDomain.unknown || domain == VariableDomain.complex) {
    return true;
  }
  final s = root.simplify(assumptions: assumptions);
  return switch (domain) {
    VariableDomain.unknown || VariableDomain.complex => true,
    VariableDomain.integer =>
      isIntegerExpr(s, assumptions: assumptions) ||
          (s is RealNumber &&
              s.value.isFinite &&
              s.value == s.value.roundToDouble()),
    VariableDomain.real => _isRealRoot(s, assumptions),
    VariableDomain.positive => _isPositiveRealRoot(s, assumptions),
  };
}

/// Deduplicates roots analytically and numerically (for floating-point roots).
List<Expr> deduplicateRoots(
  List<Expr> list, {
  Assumptions assumptions = Assumptions.none,
}) {
  final result = <Expr>[];
  for (final item in list) {
    final simplified = item.simplify(assumptions: assumptions);
    final isDup = result.any((existing) {
      if (existing == simplified) return true;
      if (existing is RationalNumber && simplified is RationalNumber) {
        return false;
      }
      final hasFloat =
          existing.anyNode((n) => n is RealNumber) ||
          simplified.anyNode((n) => n is RealNumber);
      if (existing case final RealNumeric a) {
        if (simplified case final RealNumeric b) {
          if (!hasFloat) return false;
          final scale = a.toDouble().abs() > b.toDouble().abs()
              ? a.toDouble().abs()
              : b.toDouble().abs();
          return (a.toDouble() - b.toDouble()).abs() <=
              1e-12 * (scale > 1.0 ? scale : 1.0);
        }
      }
      if (!hasFloat) {
        final diff = (existing - simplified).simplify(assumptions: assumptions);
        if (isZeroExpr(diff)) return true;
        if (existing.freeVariables.isEmpty &&
            simplified.freeVariables.isEmpty &&
            !exceedsNodeBudget(diff, 200)) {
          final expDiff = diff
              .expand(assumptions: assumptions)
              .simplify(assumptions: assumptions);
          if (isZeroExpr(expDiff)) return true;
        }
        return false;
      }
      if (existing.freeVariables.isEmpty && simplified.freeVariables.isEmpty) {
        final c1 = tryEvaluateComplex(existing);
        final c2 = tryEvaluateComplex(simplified);
        if (c1 != null && c2 != null) {
          final mag1 = c1.abs();
          final mag2 = c2.abs();
          final mag = mag1 > mag2 ? mag1 : mag2;
          final tol = 1e-12 * (mag > 1.0 ? mag : 1.0);
          return (c1.a - c2.a).abs() <= tol && (c1.b - c2.b).abs() <= tol;
        }
      }
      return false;
    });
    if (!isDup) {
      result.add(simplified);
    }
  }
  return result;
}

List<Expr> _solveUnfiltered(
  Expr expr,
  String variable,
  Assumptions assumptions,
) {
  if (expr case Relational(op: RelOp.equal, :final left, :final right)) {
    expr = left - right;
  }
  expr = expr.simplify(assumptions: assumptions);

  if (!expr.dependsOn(variable)) {
    return const [];
  }

  // Rational equation: N(x) / D(x) = 0 -> N(x) = 0 with D(x) != 0
  final (num, den) = splitNumeratorDenominator(expr);
  if (den != IntegerNumber.one && den.dependsOn(variable)) {
    if (!num.dependsOn(variable)) {
      return const [];
    }
    final candidates = _solveUnfiltered(num, variable, assumptions);
    return candidates
        .where((r) => !_isZeroAt(den, variable, r, assumptions))
        .toList();
  }

  if (expr.anyNode((n) => n is Call && n.id == FunctionId.binomial)) {
    Expr expandBinomial(Expr e) {
      final mapped = e.mapChildren(expandBinomial);
      if (mapped
          case Call(
            id: FunctionId.binomial,
            args: [final u, IntegerNumber(asInt: final k?)],
          )
          when k >= 0 && k <= 20) {
        if (k == 0) return IntegerNumber.one;
        final factors = <Expr>[
          for (var j = 0; j < k; j++)
            (j == 0 ? u : u - IntegerNumber.of(j)) / IntegerNumber.of(j + 1),
        ];
        return factors.length == 1 ? factors.first : Mul.of(factors);
      }
      return mapped;
    }

    final expanded = expandBinomial(expr).simplify(assumptions: assumptions);
    if (expanded != expr) {
      return _solveUnfiltered(expanded, variable, assumptions);
    }
  }

  if (expr is Add &&
      expr.anyNode(
        (n) =>
            n is Pow &&
            n.exponent is RealNumeric &&
            (n.exponent as RealNumeric).isNegative &&
            n.base.dependsOn(variable),
      )) {
    final combined = expr
        .together(assumptions: assumptions)
        .cancel(assumptions: assumptions);
    if (combined != expr && combined is! Add) {
      return _solveUnfiltered(combined, variable, assumptions);
    }
  }

  // Linear form: a * x + b = 0
  if (expr.matchLinear(variable) case (:final a, :final b)) {
    return [((-b) / a).simplify(assumptions: assumptions)];
  }

  // Quadratic form: a * x^2 + b * x + c = 0
  if (matchQuadratic(expr, variable) case (:final a, :final b, :final c)) {
    return solveQuadratic(a, b, c, assumptions: assumptions);
  }

  // Biquadratic form: a * x^4 + b * x^2 + c = 0
  if (matchBiquadratic(expr, variable) case (:final a, :final b, :final c)) {
    return solveBiquadratic(a, b, c, variable, assumptions: assumptions);
  }

  // Factored products or unrolled factor decomposition:
  final factors = <Expr>[];
  collectFactors(expr, factors);
  final varFactors = factors.where((f) => f.dependsOn(variable)).toList();
  if (varFactors.length > 1) {
    return _solveProductFactors(varFactors, factors, variable, assumptions);
  }

  // Polynomial factoring step (degree > 2 or multi-term polynomials):
  final factored = expr.factor(assumptions: assumptions);
  if (factored != expr) {
    final factoredList = <Expr>[];
    collectFactors(factored, factoredList);
    final varFactored = factoredList
        .where((f) => f.dependsOn(variable))
        .toList();
    final shouldSolveFactors = switch (varFactored) {
      [final single] => single.simplify(assumptions: assumptions) != expr,
      [_, _, ...] => true,
      _ => false,
    };
    if (shouldSolveFactors) {
      return _solveProductFactors(
        varFactored,
        factoredList,
        variable,
        assumptions,
      );
    }
  }

  // Transcendental isolation: f(u(x)) = C
  final trans = isolateAndInvert(expr, variable, assumptions: assumptions);
  if (trans != null) {
    return deduplicateRoots(trans, assumptions: assumptions);
  }

  return const [];
}

List<Expr> _filterByDomain(
  List<Expr> roots,
  VariableDomain domain,
  Assumptions assumptions,
) {
  if (domain == VariableDomain.unknown || domain == VariableDomain.complex) {
    return roots;
  }
  return roots
      .where((root) => satisfiesVariableDomain(root, domain, assumptions))
      .toList();
}

bool _isRealRoot(Expr expr, Assumptions assumptions) {
  if (isProvenReal(expr, assumptions)) return true;
  if (!expr.isReal) return false;
  if (_containsNonRealBranch(expr, assumptions)) return false;
  if (expr.freeVariables.isEmpty) {
    final c = tryEvaluateComplex(expr);
    return c != null && !c.isNaN && c.b.abs() < 1e-12;
  }
  return true;
}

bool _containsNonRealBranch(Expr expr, Assumptions assumptions) =>
    expr.anyNode((node) {
      if (node is ComplexNumber && !node.imaginary.isZero) return true;
      if (node
          case Pow(:final base, exponent: FractionNumber(:final denominator))
          when denominator.isEven &&
              isNegativeExpr(base, assumptions: assumptions)) {
        return true;
      }
      if (node case Call(id: FunctionId.ln, args: [final inner])
          when isNegativeExpr(inner, assumptions: assumptions)) {
        return true;
      }
      return false;
    });

bool _isPositiveRealRoot(Expr expr, Assumptions assumptions) {
  if (isPositiveExpr(expr, assumptions: assumptions)) {
    return true;
  }
  switch (expr) {
    case RationalNumber(:final sign):
      return sign > 0;
    case RealNumber(:final value):
      return value > 0.0;
    case _ when expr.isReal && expr.freeVariables.isEmpty:
      final v = tryEvaluateReal(expr);
      return v != null && !v.isNaN && v > 0.0;
    case _:
      return false;
  }
}

bool _isZeroAt(
  Expr expr,
  String variable,
  Expr value,
  Assumptions assumptions,
) {
  final sub = trySymbolicOp(
    () => expr.substitute(variable, value).simplify(assumptions: assumptions),
  );
  // If evaluating the denominator at value throws (e.g. pole), exclude value.
  return sub == null || isZeroExpr(sub);
}

bool _isValidRoot(
  Expr original,
  String variable,
  Expr root,
  Assumptions assumptions,
) {
  final Expr sub;
  try {
    sub = original.substitute(variable, root);
  } on ArgumentError {
    return false;
  } on UnsupportedError {
    return false;
  } on StateError {
    return false;
  } on FormatException {
    return false;
  }
  final v = (exceedsNodeBudget(sub, 500)
      ? sub.simplify(assumptions: assumptions)
      : sub
            .expand(assumptions: assumptions)
            .simplify(assumptions: assumptions));
  if (v.anyNode(
    (n) =>
        n == Constant.undefined ||
        n == Constant.infinity ||
        (n is RealNumber && !n.value.isFinite),
  )) {
    return false;
  }
  if (v is Number) {
    if (v.isZero) return true;
    if (v is RationalNumber) return false;
    if (v is RealNumber) {
      final scale = original is Add && original.terms.length >= 2
          ? original.terms.fold<double>(1.0, (acc, t) {
              final c = trySymbolicOp(
                () => t.substitute(variable, root).evaluateComplex(),
              );
              if (c == null) return acc;
              final mag = c.abs();
              return c.isNaN || mag < acc ? acc : mag;
            })
          : 1.0;
      return v.value.abs() <= 1e-9 * scale;
    }
    if (v is ComplexNumber) {
      if (v.real is RationalNumber && v.imaginary is RationalNumber) {
        return false;
      }
      return v.real.toDouble().abs() <= 1e-9 &&
          v.imaginary.toDouble().abs() <= 1e-9;
    }
  }
  if (isPositiveExpr(v, assumptions: assumptions) ||
      isNegativeExpr(v, assumptions: assumptions)) {
    return false;
  }
  if (v.freeVariables.isEmpty &&
      (root.anyNode((n) => n is RealNumber) ||
          original.anyNode((n) => n is RealNumber))) {
    final approx = trySymbolicOp(v.approximate);
    if (approx is RealNumeric) {
      return approx.toDouble().abs() <= 1e-9;
    }
    if (approx is ComplexNumber) {
      return approx.real.toDouble().abs() <= 1e-9 &&
          approx.imaginary.toDouble().abs() <= 1e-9;
    }
  }
  return true;
}

List<Expr> _solveProductFactors(
  List<Expr> varFactors,
  List<Expr> allFactors,
  String variable,
  Assumptions assumptions,
) {
  if (varFactors.isEmpty) return const [];
  final allRoots = <Expr>[];
  for (final factor in varFactors) {
    if (!factor.dependsOn(variable)) continue;
    allRoots.addAll(_solveUnfiltered(factor, variable, assumptions));
  }
  if (allRoots.isEmpty) return const [];
  final validRoots = allRoots.where((root) {
    for (final other in allFactors) {
      final sub = trySymbolicOp(
        () =>
            other.substitute(variable, root).simplify(assumptions: assumptions),
      );
      if (sub == null) return false;
      if (sub == Constant.undefined ||
          sub == Constant.infinity ||
          sub == -Constant.infinity ||
          sub.anyNode(
            (n) =>
                n == Constant.undefined ||
                n == Constant.infinity ||
                (n is RealNumber && !n.value.isFinite),
          )) {
        return false;
      }
    }
    return true;
  }).toList();
  return deduplicateRoots(validRoots, assumptions: assumptions);
}
