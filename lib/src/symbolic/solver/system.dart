import '../algebra/expand.dart';
import '../algebra/factor.dart';
import '../algebra/rational.dart';
import '../algebra/simplify.dart';
import '../algebra/term_accumulator.dart';
import '../ast.dart';
import '../calculus/differentiation.dart';
import 'polynomial_system.dart';
import 'univariate.dart';

/// Extension providing unified equation system solving on [Iterable] of [Expr].
extension SystemSolverExtension on Iterable<Expr> {
  /// Solves this system of equations $f_i(x_1, \dots, x_n) = 0$ for
  /// [variables].
  ///
  /// Equations may be [Equal] nodes (`lhs == rhs`) or algebraic expressions
  /// implicitly equated to $0$, including rational equations whose denominator
  /// poles are automatically excluded from the solution set.
  ///
  /// When [method] is [PolynomialSystemMethod.auto] (the default), dispatches
  /// automatically by algebraic structure:
  /// - Single-equation univariate systems use [SolverExtension.solve].
  /// - Determined linear systems use exact symbolic Gaussian elimination.
  /// - Bivariate nonlinear polynomial systems use Sylvester resultant
  ///   elimination, falling back to Buchberger Gröbner basis + FGLM conversion.
  /// - General multivariate polynomial systems use Buchberger Gröbner basis
  ///   with Sugar selection followed by FGLM lexicographic conversion.
  ///
  /// Returns a list of solution maps assigning each variable in [variables] to
  /// its exact symbolic value, or an empty list if the system is inconsistent
  /// or singular.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final y = Variable('y');
  /// final solutions = [x + y - 10, x - y - 2].solve(['x', 'y']);
  /// // solutions == [{'x': IntegerNumber(6), 'y': IntegerNumber(4)}]
  /// ```
  List<Map<String, Expr>> solve(
    List<String> variables, {
    PolynomialSystemMethod method = PolynomialSystemMethod.auto,
  }) => solveEquations(toList(), variables, method: method);
}

/// Unified solver for a system of [equations] in [variables].
List<Map<String, Expr>> solveEquations(
  List<Expr> equations,
  List<String> variables, {
  PolynomialSystemMethod method = PolynomialSystemMethod.auto,
}) {
  if (equations.isEmpty || variables.isEmpty) {
    if (method == PolynomialSystemMethod.resultant) {
      throw ArgumentError(
        'Resultant method requires exactly 2 equations and 2 variables',
      );
    }
    return const [];
  }

  final varSet = variables.toSet();
  final denominators = <Expr>[];
  final numEquations = <Expr>[];

  for (final rawEq in equations) {
    final diff = switch (rawEq) {
      Equal(:final left, :final right) => left - right,
      _ => rawEq,
    };
    _collectDenominatorBases(diff, varSet, denominators);
    final combined = diff.together();
    final (numPart, denPart) = splitNumeratorDenominator(combined);
    if (denPart != IntegerNumber.one &&
        denPart.freeVariables.any(varSet.contains)) {
      denominators.add(denPart);
    }
    numEquations.add(numPart.expand().simplify());
  }

  List<Map<String, Expr>> rawSolutions;
  if (method != PolynomialSystemMethod.auto) {
    rawSolutions = solvePolynomialSystemEquations(
      numEquations,
      variables,
      method: method,
    );
  } else if (numEquations.length == 1 && variables.length == 1) {
    final v = variables.first;
    final roots = solveEquation(numEquations.first, v);
    rawSolutions = [
      for (final r in roots) {v: r.simplify()},
    ];
  } else if (_isLinearSystem(numEquations, variables)) {
    if (numEquations.length != variables.length) {
      rawSolutions = const [];
    } else {
      final linearSol = solveSystemEquations(numEquations, variables);
      rawSolutions = linearSol != null ? [linearSol] : const [];
    }
  } else {
    rawSolutions = solvePolynomialSystemEquations(
      numEquations,
      variables,
      method: PolynomialSystemMethod.auto,
    );
  }

  if (denominators.isEmpty || rawSolutions.isEmpty) {
    return rawSolutions;
  }

  return [
    for (final sol in rawSolutions)
      if (!_vanishesAnyDenominator(denominators, sol)) sol,
  ];
}

void _collectDenominatorBases(
  Expr expr,
  Set<String> variables,
  List<Expr> target,
) {
  expr.anyNode((node) {
    if (node case Pow(:final base, exponent: RealNumeric(isNegative: true))) {
      if (base.freeVariables.any(variables.contains)) {
        target.add(base);
      }
    }
    return false;
  });
}

bool _vanishesAnyDenominator(
  List<Expr> denominators,
  Map<String, Expr> solution,
) {
  for (final den in denominators) {
    var sub = den;
    for (final MapEntry(:key, :value) in solution.entries) {
      sub = sub.substitute(key, value);
    }
    if (isZeroExpr(sub.expand().simplify())) {
      return true;
    }
  }
  return false;
}

bool _isLinearSystem(List<Expr> equations, List<String> variables) {
  for (final eq in equations) {
    var reconstructed = IntegerNumber.zero as Expr;
    for (final v in variables) {
      final deriv = eq.derivative(v).simplify();
      for (final otherV in variables) {
        if (deriv.dependsOn(otherV)) return false;
      }
      reconstructed = reconstructed + deriv * Variable(v);
    }
    var cTerm = eq;
    for (final v in variables) {
      cTerm = cTerm.substitute(v, IntegerNumber.zero);
    }
    reconstructed = (reconstructed + cTerm).expand().simplify();
    final residual = (eq - reconstructed).expand().simplify();
    if (!isZeroExpr(residual)) return false;
  }
  return true;
}

/// Solves a linear system of [equations] in [variables] via exact Gaussian
/// elimination.
Map<String, Expr>? solveSystemEquations(
  List<Expr> equations,
  List<String> variables,
) {
  final n = variables.length;
  if (equations.length != n || n == 0) {
    return null;
  }

  // Extract coefficient matrix A and right-hand side b
  final a = List<List<Expr>>.generate(
    n,
    (_) => List<Expr>.filled(n, IntegerNumber.zero),
  );
  final b = List<Expr>.filled(n, IntegerNumber.zero);

  for (var i = 0; i < n; i++) {
    final rawEq = equations[i];
    final eq = (switch (rawEq) {
      Equal(:final left, :final right) => left - right,
      _ => rawEq,
    }).expand().simplify();
    for (var j = 0; j < n; j++) {
      final aij = eq.derivative(variables[j]).simplify();
      // Ensure linearity: derivative must not depend on any variable
      for (final v in variables) {
        if (aij.dependsOn(v)) return null;
      }
      a[i][j] = aij;
    }

    // Constant term: evaluate with all variables set to 0
    var cTerm = eq;
    for (final v in variables) {
      cTerm = cTerm.substitute(v, IntegerNumber.zero);
    }
    b[i] = (-cTerm).simplify();
  }

  // Fraction-free Gaussian elimination with non-zero pivot selection
  for (var k = 0; k < n; k++) {
    var pivotRow = -1;
    for (var i = k; i < n; i++) {
      if (!isZeroExpr(a[i][k])) {
        pivotRow = i;
        break;
      }
    }
    if (pivotRow == -1) {
      return null; // Singular matrix
    }

    if (pivotRow != k) {
      final tempRow = a[k];
      a[k] = a[pivotRow];
      a[pivotRow] = tempRow;
      final tempB = b[k];
      b[k] = b[pivotRow];
      b[pivotRow] = tempB;
    }

    final pivot = a[k][k];
    for (var i = k + 1; i < n; i++) {
      final aik = a[i][k];
      if (!isZeroExpr(aik)) {
        a[i][k] = IntegerNumber.zero;
        for (var j = k + 1; j < n; j++) {
          a[i][j] = (pivot * a[i][j] - aik * a[k][j]).expand().simplify();
        }
        b[i] = (pivot * b[i] - aik * b[k]).expand().simplify();
      }
    }
  }

  // Back-substitution keeping numerator/denominator rational form
  final xNum = List<Expr>.filled(n, IntegerNumber.zero);
  final xDen = List<Expr>.filled(n, IntegerNumber.one);
  final x = List<Expr>.filled(n, IntegerNumber.zero);
  for (var i = n - 1; i >= 0; i--) {
    var numSum = b[i];
    Expr denSum = IntegerNumber.one;
    for (var j = i + 1; j < n; j++) {
      final aij = a[i][j];
      if (!isZeroExpr(aij) && !isZeroExpr(xNum[j])) {
        numSum = (numSum * xDen[j] - aij * xNum[j]).expand().simplify();
        denSum = (denSum * xDen[j]).expand().simplify();
      }
    }
    final rawDen = (denSum * a[i][i]).expand().simplify();
    final sol = (numSum / rawDen).factor().simplify();
    x[i] = sol;
    final (numPart, denPart) = splitNumeratorDenominator(sol);
    xNum[i] = numPart;
    xDen[i] = denPart;
  }

  final result = <String, Expr>{};
  for (var i = 0; i < n; i++) {
    result[variables[i]] = x[i];
  }
  return result;
}
