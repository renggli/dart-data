import '../algebra/expand.dart';
import '../algebra/factor.dart';
import '../algebra/simplify.dart';
import '../ast.dart';
import '../calculus/differentiation.dart';
import 'univariate.dart';

/// Extension providing linear equation system solving on [Iterable] of [Expr].
extension SystemSolverExtension on Iterable<Expr> {
  /// Solves the linear system $f_i(x_1, \dots, x_n) = 0$ for [variables].
  ///
  /// Conceptually, this finds the common solution satisfying multiple
  /// simultaneous linear equations (such as $x + y - 10 = 0$ and
  /// $x - y - 2 = 0$).
  ///
  /// Formally, this performs exact symbolic Gaussian elimination over the
  /// affine coefficient matrix. Returns a mapping from each variable name to
  /// its solution expression, or `null` if the system is singular,
  /// underdetermined, or contradictory.
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
    final rawEq = equations[i];
    final eq = (rawEq is Equal ? Sub(rawEq.left, rawEq.right) : rawEq)
        .expand()
        .simplify();
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
        a[i][k] = RationalNumber.zero;
        for (var j = k + 1; j < n; j++) {
          a[i][j] = (pivot * a[i][j] - aik * a[k][j]).expand().simplify();
        }
        b[i] = (pivot * b[i] - aik * b[k]).expand().simplify();
      }
    }
  }

  // Back-substitution keeping numerator/denominator rational form
  final xNum = List<Expr>.filled(n, RationalNumber.zero);
  final xDen = List<Expr>.filled(n, RationalNumber.one);
  final x = List<Expr>.filled(n, RationalNumber.zero);
  for (var i = n - 1; i >= 0; i--) {
    var numSum = b[i];
    var denSum = RationalNumber.one as Expr;
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
    if (sol is Div) {
      xNum[i] = sol.left;
      xDen[i] = sol.right;
    } else {
      xNum[i] = sol;
      xDen[i] = RationalNumber.one;
    }
  }

  final result = <String, Expr>{};
  for (var i = 0; i < n; i++) {
    result[variables[i]] = x[i];
  }
  return result;
}
