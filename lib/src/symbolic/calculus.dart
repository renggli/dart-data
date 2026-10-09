import 'ast.dart';

/// Multivariable analytical calculus utilities: gradients, Jacobians, Hessians, and Taylor series.
class Calculus {
  const new _();

  /// Computes the analytical gradient vector grad(f) = [df/dx1, df/dx2, ...].
  static List<Expr> gradient(Expr f, List<String> variables) => [
    for (final v in variables) f.diff(v).simplify(),
  ];

  /// Computes the analytical Jacobian matrix J_ij = df_i / dx_j.
  static List<List<Expr>> jacobian(
    List<Expr> functions,
    List<String> variables,
  ) => [
    for (final f in functions)
      [for (final v in variables) f.diff(v).simplify()],
  ];

  /// Computes the analytical Hessian matrix H_ij = d^2 f / (dx_i dx_j).
  static List<List<Expr>> hessian(Expr f, List<String> variables) {
    final grad = gradient(f, variables);
    return [
      for (final df in grad) [for (final v in variables) df.diff(v).simplify()],
    ];
  }

  /// Computes the Taylor series expansion of [f] around [point] up to [order].
  static Expr taylorSeries(
    Expr f,
    String variable, {
    double point = 0.0,
    int order = 4,
  }) {
    final x = Variable(variable);
    final a = Constant(point);
    final delta = Sub(x, a);

    var currentDeriv = f;
    var result = currentDeriv.substitute(variable, a).simplify();
    var factorial = 1.0;

    for (var n = 1; n <= order; n++) {
      currentDeriv = currentDeriv.diff(variable);
      factorial *= n;
      final termVal = currentDeriv.substitute(variable, a).simplify();
      final polyTerm = Mul(
        Div(termVal, Constant(factorial)),
        Pow(delta, Constant(n.toDouble())),
      );
      result = Add(result, polyTerm).simplify();
    }

    return result;
  }
}
