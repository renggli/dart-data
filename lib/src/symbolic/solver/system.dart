import '../algebra/simplify.dart';
import '../ast.dart';
import '../calculus/differentiation.dart';

/// Extension providing linear equation system solving on [Iterable] of [Expr].
extension SystemSolverExtension on Iterable<Expr> {
  /// Solves the linear system $f_i(x_1, \dots, x_n) = 0$ for [variables].
  ///
  /// Conceptually, this finds the common solution satisfying multiple
  /// simultaneous linear equations (such as $x + y - 10 = 0$ and
  /// $x - y - 2 = 0$).
  ///
  /// Formally, this performs exact symbolic Gaussian elimination with partial
  /// pivoting over the affine coefficient matrix. Returns a mapping from each
  /// variable name to its solution expression, or `null` if the system is
  /// singular, underdetermined, or contradictory.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final y = Variable('y');
  /// final solution = [x + y - 10, x - y - 2].solveSystem(['x', 'y']);
  /// // solution?['x'] == RationalNumber(6), solution?['y'] == RationalNumber(4)
  /// ```
  Map<String, Expr>? solveSystem(List<String> variables) =>
      solveSystemEquations(toList(), variables);
}

/// Solves a system of [equations] in [variables] via exact Gaussian elimination.
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
    (_) => List<Expr>.filled(n, RationalNumber.zero),
  );
  final b = List<Expr>.filled(n, RationalNumber.zero);

  for (var i = 0; i < n; i++) {
    final eq = equations[i].simplify();
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
      cTerm = cTerm.substitute(v, RationalNumber.zero);
    }
    b[i] = (-cTerm).simplify();
  }

  // Gaussian elimination with partial pivoting
  for (var k = 0; k < n; k++) {
    // Find pivot
    var pivotRow = -1;
    for (var i = k; i < n; i++) {
      final aik = a[i][k];
      if (aik != RationalNumber.zero &&
          !(aik is RationalNumber && aik.isZero)) {
        pivotRow = i;
        break;
      }
    }
    if (pivotRow == -1) {
      return null; // Singular matrix
    }

    // Swap rows
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
      final factor = (a[i][k] / pivot).simplify();
      if (factor != RationalNumber.zero &&
          !(factor is RationalNumber && factor.isZero)) {
        for (var j = k; j < n; j++) {
          a[i][j] = (a[i][j] - factor * a[k][j]).simplify();
        }
        b[i] = (b[i] - factor * b[k]).simplify();
      }
    }
  }

  // Back-substitution
  final x = List<Expr>.filled(n, RationalNumber.zero);
  for (var i = n - 1; i >= 0; i--) {
    var sum = b[i];
    for (var j = i + 1; j < n; j++) {
      sum = (sum - a[i][j] * x[j]).simplify();
    }
    x[i] = (sum / a[i][i]).simplify();
  }

  final result = <String, Expr>{};
  for (var i = 0; i < n; i++) {
    result[variables[i]] = x[i];
  }
  return result;
}
