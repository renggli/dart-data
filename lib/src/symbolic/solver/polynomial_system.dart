import 'dart:math' as math;

import '../algebra/expand.dart';
import '../algebra/simplify.dart';
import '../assumptions.dart';
import '../ast.dart';
import 'buchberger.dart';
import 'fglm.dart';
import 'multivariate_polynomial.dart';
import 'resultant.dart';
import 'univariate.dart';

/// Method selection for solving multivariate polynomial systems.
enum PolynomialSystemMethod {
  /// Selects resultant elimination for bivariate systems, Gröbner basis otherwise.
  auto,

  /// Uses Sylvester resultant elimination (requires 2 equations and 2 variables).
  resultant,

  /// Uses Buchberger algorithm with Sugar strategy followed by FGLM order conversion.
  groebner,
}

/// Solves a polynomial system of [equations] in [variables].
List<Map<String, Expr>> solvePolynomialSystemEquations(
  List<Expr> equations,
  List<String> variables, {
  PolynomialSystemMethod method = PolynomialSystemMethod.auto,
  Assumptions assumptions = Assumptions.none,
}) {
  if (equations.isEmpty || variables.isEmpty) return const [];

  final normalizedEqs = [
    for (final e in equations)
      (switch (e) {
        Equal(:final left, :final right) => left - right,
        _ => e,
      }).simplify(assumptions: assumptions),
  ];

  final List<Map<String, Expr>> rawSolutions;
  switch (method) {
    case PolynomialSystemMethod.resultant:
      if (normalizedEqs case [final f, final g] when variables.length == 2) {
        rawSolutions = SylvesterResultantSolver.solve(f, g, variables);
      } else {
        throw ArgumentError(
          'Resultant method requires exactly 2 equations and 2 variables',
        );
      }
    case PolynomialSystemMethod.auto:
      List<Map<String, Expr>>? resSolutions;
      if (normalizedEqs case [final f, final g] when variables.length == 2) {
        try {
          final res = SylvesterResultantSolver.solve(f, g, variables);
          if (res.isNotEmpty) resSolutions = res;
        } on ArgumentError {
          // Fall back to Gröbner basis
        } on UnsupportedError {
          // Fall back to Gröbner basis
        } on StateError {
          // Fall back to Gröbner basis
        }
      }
      rawSolutions =
          resSolutions ?? _solveViaGroebner(normalizedEqs, variables);
    case PolynomialSystemMethod.groebner:
      rawSolutions = _solveViaGroebner(normalizedEqs, variables);
  }

  return filterSolutionsByAssumptions(rawSolutions, assumptions);
}

/// Filters multivariate [solutions] by checking each variable assignment
/// against its domain in [assumptions].
List<Map<String, Expr>> filterSolutionsByAssumptions(
  List<Map<String, Expr>> solutions,
  Assumptions assumptions,
) {
  if (assumptions.isEmpty || solutions.isEmpty) return solutions;
  final filtered = <Map<String, Expr>>[];
  for (final sol in solutions) {
    var matches = true;
    final simplifiedSol = <String, Expr>{};
    for (final MapEntry(:key, :value) in sol.entries) {
      final s = value.simplify(assumptions: assumptions);
      if (!satisfiesVariableDomain(s, assumptions.domainOf(key), assumptions)) {
        matches = false;
        break;
      }
      simplifiedSol[key] = s;
    }
    if (matches) {
      filtered.add(simplifiedSol);
    }
  }
  return filtered;
}

List<Map<String, Expr>> _solveViaGroebner(
  List<Expr> equations,
  List<String> variables,
) {
  final polys = equations
      .map((e) => MultivariatePolynomial.fromExpr(e, variables))
      .toList();

  final grevlexBasis = BuchbergerEngine.compute(
    polys,
    order: MonomialOrder.grevlex,
  );

  // If ideal contains constant 1, there are no solutions
  if (grevlexBasis.any(
    (g) => g.leadingMonomial(MonomialOrder.grevlex).isZero,
  )) {
    return const [];
  }

  final List<MultivariatePolynomial> lexBasis;
  try {
    lexBasis = FglmEngine.convert(grevlexBasis, targetOrder: MonomialOrder.lex);
  } on UnsupportedError {
    return const [];
  }

  if (lexBasis.any((g) => g.leadingMonomial(MonomialOrder.lex).isZero)) {
    return const [];
  }

  final lexExprs = lexBasis.map((p) => p.toExpr()).toList();

  // Triangular back-substitution
  final solutions = <Map<String, Expr>>[];
  _backSubstitute(
    lexExprs,
    variables,
    variables.length - 1,
    {},
    equations,
    solutions,
  );

  return solutions;
}

void _backSubstitute(
  List<Expr> lexExprs,
  List<String> variables,
  int varIndex,
  Map<String, Expr> currentSolution,
  List<Expr> originalEquations,
  List<Map<String, Expr>> results,
) {
  if (varIndex < 0) {
    // Validate complete candidate solution against original equations
    for (final eq in originalEquations) {
      var val = eq;
      for (final MapEntry(:key, :value) in currentSolution.entries) {
        val = val.substitute(key, value);
      }
      val = val.simplify();
      if (!isZeroExpr(val)) return;
    }
    results.add(Map<String, Expr>.of(currentSolution));
    return;
  }

  final currentVar = variables[varIndex];

  // Collect all polynomials in lexExprs that depend only on variables[varIndex..end]
  // and substitute already-solved variables.
  final univariateEqs = <Expr>[];
  for (final expr in lexExprs) {
    var onlyAllowedVars = true;
    for (var i = 0; i < varIndex; i++) {
      if (expr.dependsOn(variables[i])) {
        onlyAllowedVars = false;
        break;
      }
    }
    if (!onlyAllowedVars) continue;

    var instantiated = expr;
    for (final MapEntry(:key, :value) in currentSolution.entries) {
      instantiated = instantiated.substitute(key, value);
    }
    instantiated = instantiated.expand().simplify();

    if (!instantiated.dependsOn(currentVar)) {
      if (!isZeroExpr(instantiated)) {
        return;
      }
      continue;
    }
    univariateEqs.add(instantiated);
  }

  if (univariateEqs.isEmpty) {
    return;
  }

  // Pick the univariate equation of lowest degree in currentVar
  var primaryIdx = 0;
  var minDeg = _degreeIn(univariateEqs.first, currentVar);
  for (var i = 1; i < univariateEqs.length; i++) {
    final deg = _degreeIn(univariateEqs[i], currentVar);
    if (deg > 0 && (minDeg <= 0 || deg < minDeg)) {
      minDeg = deg;
      primaryIdx = i;
    }
  }

  final roots = solveEquation(univariateEqs[primaryIdx], currentVar);
  for (final r in roots) {
    final rSimp = r.simplify();
    var satisfiesAll = true;
    for (var i = 0; i < univariateEqs.length; i++) {
      if (i == primaryIdx) continue;
      final val = univariateEqs[i].substitute(currentVar, rSimp).simplify();
      if (!isZeroExpr(val)) {
        satisfiesAll = false;
        break;
      }
    }
    if (!satisfiesAll) continue;
    currentSolution[currentVar] = rSimp;
    _backSubstitute(
      lexExprs,
      variables,
      varIndex - 1,
      currentSolution,
      originalEquations,
      results,
    );
    currentSolution.remove(currentVar);
  }
}

int _degreeIn(Expr expr, String variable) {
  if (!expr.dependsOn(variable)) return 0;
  return switch (expr) {
    Variable(:final name) => name == variable ? 1 : 0,
    Add(:final terms) => terms.fold(
      0,
      (maxDeg, t) => math.max(maxDeg, _degreeIn(t, variable)),
    ),
    Mul(:final factors) => factors.fold(
      0,
      (sumDeg, f) => sumDeg + _degreeIn(f, variable),
    ),
    Pow(:final base, exponent: IntegerNumber(:final asInt?)) when asInt >= 0 =>
      _degreeIn(base, variable) * asInt,
    _ => 1000,
  };
}
