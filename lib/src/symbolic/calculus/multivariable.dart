import '../algebra/simplify.dart';
import '../ast.dart';
import 'differentiation.dart';

/// Multivariable calculus extensions on [Expr].
extension MultivariableExtension on Expr {
  /// Computes the analytical gradient vector:
  /// $\nabla f =$
  /// $\left(\frac{\partial f}{\partial x_1}, \dots,\right.$
  /// $\left.\frac{\partial f}{\partial x_n}\right)$.
  ///
  /// Conceptually, the gradient points in the direction of steepest ascent on a
  /// multivariate surface. Formally, this yields the covector of first-order
  /// partial derivatives.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final y = Variable('y');
  /// final grad = (x * x + y * y).gradient(['x', 'y']);
  /// // grad: [2 * x, 2 * y]
  /// ```
  List<Expr> gradient(List<String> variables) =>
      _multivariableGradient(this, variables);

  /// Computes the analytical Hessian matrix
  /// $H_{ij} = \frac{\partial^2 f}{\partial x_i \partial x_j}$.
  ///
  /// Conceptually, the Hessian describes the local curvature or concavity of a
  /// multivariate surface. Formally, this is the symmetric matrix of second
  /// partial derivatives used in multivariate optimization and critical point
  /// classification.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final y = Variable('y');
  /// final h = (x * x + 3 * x * y).hessian(['x', 'y']);
  /// // h[0]: [2, 3], h[1]: [3, 0]
  /// ```
  List<List<Expr>> hessian(List<String> variables) =>
      _multivariableHessian(this, variables);
}

/// Multivariable calculus extensions on collections of [Expr].
extension MultivariableIterableExtension on Iterable<Expr> {
  /// Computes the analytical Jacobian matrix
  /// $J_{ij} = \frac{\partial f_i}{\partial x_j}$.
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
  /// // jac[0]: [y, x]
  /// // jac[1]: [1, 1]
  /// ```
  List<List<Expr>> jacobian(List<String> variables) =>
      _multivariableJacobian(toList(), variables);
}

List<Expr> _multivariableGradient(Expr function, List<String> variables) => [
  for (final variable in variables) function.derivative(variable).simplify(),
];

List<List<Expr>> _multivariableJacobian(
  List<Expr> functions,
  List<String> variables,
) => [
  for (final fn in functions)
    [for (final variable in variables) fn.derivative(variable).simplify()],
];

List<List<Expr>> _multivariableHessian(Expr function, List<String> variables) {
  final grad = _multivariableGradient(function, variables);
  return [
    for (final df in grad)
      [for (final variable in variables) df.derivative(variable).simplify()],
  ];
}
