import '../ast.dart';
import '../simplifier.dart';
import 'differentiation.dart';

/// Multivariable calculus extensions on [Expr].
extension MultivariableExtension on Expr {
  /// Computes the analytical gradient vector $\nabla f = [\frac{\partial f}{\partial x_1}, \frac{\partial f}{\partial x_2}, \dots]$.
  List<Expr> gradient(List<String> variables) =>
      _multivariableGradient(this, variables);

  /// Computes the analytical Hessian matrix $H_{ij} = \frac{\partial^2 f}{\partial x_i \partial x_j}$.
  List<List<Expr>> hessian(List<String> variables) =>
      _multivariableHessian(this, variables);
}

/// Multivariable calculus extensions on collections of [Expr].
extension MultivariableIterableExtension on Iterable<Expr> {
  /// Computes the analytical Jacobian matrix $J_{ij} = \frac{\partial f_i}{\partial x_j}$.
  List<List<Expr>> jacobian(List<String> variables) =>
      _multivariableJacobian(toList(), variables);
}

List<Expr> _multivariableGradient(Expr function, List<String> variables) => [
  for (final variable in variables) function.diff(variable).simplify(),
];

List<List<Expr>> _multivariableJacobian(
  List<Expr> functions,
  List<String> variables,
) => [
  for (final fn in functions)
    [for (final variable in variables) fn.diff(variable).simplify()],
];

List<List<Expr>> _multivariableHessian(Expr function, List<String> variables) {
  final grad = _multivariableGradient(function, variables);
  return [
    for (final df in grad)
      [for (final variable in variables) df.diff(variable).simplify()],
  ];
}
