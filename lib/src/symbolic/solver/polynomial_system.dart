import '../algebra/simplify.dart';
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

/// Extension on [Iterable] of [Expr] for solving multivariate polynomial systems.
extension PolynomialSystemSolverExtension on Iterable<Expr> {
  /// Solves this system of multivariate polynomial equations for [variables].
  ///
  /// Equations may be [Equal] nodes (`lhs = rhs`) or algebraic expressions
  /// implicitly equated to $0$.
  List<Map<String, Expr>> solvePolynomialSystem(
    List<String> variables, {
    PolynomialSystemMethod method = PolynomialSystemMethod.auto,
  }) => solvePolynomialSystemEquations(toList(), variables, method: method);
}

/// Solves a polynomial system of [equations] in [variables].
List<Map<String, Expr>> solvePolynomialSystemEquations(
  List<Expr> equations,
  List<String> variables, {
  PolynomialSystemMethod method = PolynomialSystemMethod.auto,
}) {
  if (equations.isEmpty || variables.isEmpty) return const [];

  final normalizedEqs = [
    for (final e in equations)
      (switch (e) {
        Equal(:final left, :final right) => left - right,
        _ => e,
      }).simplify(),
  ];

  switch (method) {
    case PolynomialSystemMethod.resultant:
      if (normalizedEqs case [final f, final g] when variables.length == 2) {
        return SylvesterResultantSolver.solve(f, g, variables);
      }
      throw ArgumentError(
        'Resultant method requires exactly 2 equations and 2 variables',
      );
    case PolynomialSystemMethod.auto:
      if (normalizedEqs case [final f, final g] when variables.length == 2) {
        try {
          final res = SylvesterResultantSolver.solve(f, g, variables);
          if (res.isNotEmpty) return res;
        } catch (_) {
          // Fall back to Gröbner basis
        }
      }
      return _solveViaGroebner(normalizedEqs, variables);
    case PolynomialSystemMethod.groebner:
      return _solveViaGroebner(normalizedEqs, variables);
  }
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

  final lexBasis = FglmEngine.convert(
    grevlexBasis,
    targetOrder: MonomialOrder.lex,
  );

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

  // Find a polynomial in lexExprs that depends on currentVar and only already-solved variables
  Expr? candidateEq;
  for (final expr in lexExprs) {
    if (expr.dependsOn(currentVar)) {
      var onlyAllowedVars = true;
      for (var i = 0; i < varIndex; i++) {
        if (expr.dependsOn(variables[i])) {
          onlyAllowedVars = false;
          break;
        }
      }
      if (onlyAllowedVars) {
        candidateEq = expr;
        break;
      }
    }
  }

  if (candidateEq == null) {
    return;
  }

  // Substitute already-solved variables
  var instantiated = candidateEq;
  for (final MapEntry(:key, :value) in currentSolution.entries) {
    instantiated = instantiated.substitute(key, value);
  }
  instantiated = instantiated.simplify();

  final roots = solveEquation(instantiated, currentVar);
  for (final r in roots) {
    currentSolution[currentVar] = r.simplify();
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
