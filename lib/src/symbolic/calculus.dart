import 'ast.dart';

/// Multivariable analytical calculus utilities: gradients, Jacobians, Hessians, and Taylor series.
class Calculus {
  const new _();

  /// Computes the analytical gradient vector grad(f) = [df/dx1, df/dx2, ...].
  static List<Expr> gradient(Expr function, List<String> variables) => [
    for (final variable in variables) function.diff(variable).simplify(),
  ];

  /// Computes the analytical Jacobian matrix J_ij = df_i / dx_j.
  static List<List<Expr>> jacobian(
    List<Expr> functions,
    List<String> variables,
  ) => [
    for (final fn in functions)
      [for (final variable in variables) fn.diff(variable).simplify()],
  ];

  /// Computes the analytical Hessian matrix H_ij = d^2 f / (dx_i dx_j).
  static List<List<Expr>> hessian(Expr function, List<String> variables) {
    final grad = gradient(function, variables);
    return [
      for (final df in grad)
        [for (final variable in variables) df.diff(variable).simplify()],
    ];
  }

  /// Computes the Taylor series expansion of [function] around [point] up to [order].
  static Expr taylorSeries(
    Expr function,
    String variable, {
    double point = 0.0,
    int order = 4,
  }) {
    final x = Variable(variable);
    final a = Constant(point);
    final delta = Sub(x, a);

    var currentDeriv = function;
    var result = currentDeriv.substitute(variable, a).simplify();
    var factorial = 1.0;

    for (var step = 1; step <= order; step++) {
      currentDeriv = currentDeriv.diff(variable);
      factorial *= step;
      final termVal = currentDeriv.substitute(variable, a).simplify();
      final polyTerm = Mul(
        Div(termVal, Constant(factorial)),
        Pow(delta, Constant(step.toDouble())),
      );
      result = Add(result, polyTerm).simplify();
    }

    return result;
  }
}
