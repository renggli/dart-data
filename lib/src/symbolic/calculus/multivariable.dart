import '../../linear/matrix.dart';
import '../../linear/vector.dart';
import '../ast.dart';
import '../type/expr_data_type.dart';
import 'differentiation.dart';

/// Multivariable calculus extensions on [Expr].
extension MultivariableExtension on Expr {
  /// Computes the analytical gradient vector:
  /// $\nabla f =$
  /// $\left(\frac{\partial f}{\partial x_1}, \dots,\right.$
  /// $\left.\frac{\partial f}{\partial x_n}\right)$
  /// as a [Vector] of symbolic expressions.
  ///
  /// Conceptually, the gradient points in the direction of steepest ascent on a
  /// multivariate surface. Formally, this yields the covector of first-order
  /// partial derivatives.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final y = Variable('y');
  /// final grad = (x * x + y * y).gradient(['x', 'y']);
  /// // grad[0]: 2 * x, grad[1]: 2 * y
  /// ```
  Vector<Expr> gradient(List<String> variables) =>
      _multivariableGradient(this, variables);

  /// Computes the analytical Hessian matrix
  /// $H_{ij} = \frac{\partial^2 f}{\partial x_i \partial x_j}$
  /// as a symmetric [Matrix] of symbolic expressions.
  ///
  /// Conceptually, the Hessian describes the local curvature or concavity of a
  /// multivariate surface. Formally, this is the symmetric matrix of second
  /// partial derivatives used in multivariate optimization and critical point
  /// classification.
  ///
  /// Exploits Clairaut's symmetry theorem to compute only the upper triangle
  /// ($j \ge i$) and mirror identical expressions to the lower triangle
  /// ($H_{ji} = H_{ij}$), halving the number of second derivative and
  /// simplification passes from $n^2$ to $\frac{n(n+1)}{2}$.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final y = Variable('y');
  /// final h = (x * x + x * y * 3).hessian(['x', 'y']);
  /// // h[0][0]: 2, h[0][1]: 3, h[1][0]: 3, h[1][1]: 0
  /// ```
  Matrix<Expr> hessian(List<String> variables) =>
      _multivariableHessian(this, variables);
}

/// Multivariable calculus extensions on collections of [Expr].
extension MultivariableIterableExtension on Iterable<Expr> {
  /// Computes the analytical Jacobian matrix
  /// $J_{ij} = \frac{\partial f_i}{\partial x_j}$
  /// as a [Matrix] of symbolic expressions.
  ///
  /// Conceptually, the Jacobian shows how each component of a multivariable
  /// vector system changes with respect to each input variable. Formally, this
  /// represents the linear approximation / pushforward map of a vector-valued
  /// function $F: \mathbb{R}^n \to \mathbb{R}^m$.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final y = Variable('y');
  /// final jac = [x * y, x + y].jacobian(['x', 'y']);
  /// // jac[0][0]: y, jac[0][1]: x
  /// // jac[1][0]: 1, jac[1][1]: 1
  /// ```
  Matrix<Expr> jacobian(List<String> variables) =>
      _multivariableJacobian(toList(), variables);
}

Vector<Expr> _multivariableGradient(Expr function, List<String> variables) =>
    Vector<Expr>.generate(
      variables.length,
      (i) => function.derivative(variables[i]),
      type: exprDataType,
    );

Matrix<Expr> _multivariableJacobian(
  List<Expr> functions,
  List<String> variables,
) {
  final m = functions.length;
  final n = variables.length;
  return Matrix<Expr>.generate(
    m,
    n,
    (r, c) => functions[r].derivative(variables[c]),
    type: exprDataType,
  );
}

Matrix<Expr> _multivariableHessian(Expr function, List<String> variables) {
  final n = variables.length;
  final grad = _multivariableGradient(function, variables);
  final entries = List<Expr?>.filled(n * n, null);
  for (var i = 0; i < n; i++) {
    final df = grad[i];
    for (var j = i; j < n; j++) {
      final d2f = df.derivative(variables[j]);
      entries[i * n + j] = d2f;
      entries[j * n + i] = d2f;
    }
  }
  return Matrix<Expr>.generate(
    n,
    n,
    (r, c) => entries[r * n + c]!,
    type: exprDataType,
  );
}
