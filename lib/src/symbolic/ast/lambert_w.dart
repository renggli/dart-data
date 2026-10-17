part of '../ast.dart';

/// Lambert $W$ function (product logarithm) node: $W_k(x)$, satisfying
/// $W_k(x) e^{W_k(x)} = x$.
///
/// The principal branch is $k = 0$ ($W_0(x)$ for $x \ge -1/e$), and the lower
/// real branch is $k = -1$ ($W_{-1}(x)$ for $-1/e \le x < 0$).
final class LambertW extends UnaryExpr {
  /// Creates a Lambert $W$ node $W_{\text{branch}}(\text{expr})$.
  new(super.expr, {this.branch = 0, super.isSimplified = false})
    : assert(
        branch == 0 || branch == -1,
        'Real LambertW only supports branches 0 and -1',
      );

  /// The branch index ($0$ for principal branch, $-1$ for lower real branch).
  final int branch;

  @override
  double evaluate([Map<String, double> context = const {}]) =>
      _evaluateLambertWReal(expr.evaluate(context), branch: branch);

  @override
  Expr substitute(String variable, Expr replacement) =>
      LambertW(expr.substitute(variable, replacement), branch: branch);

  @override
  Expr mapChildren(Expr Function(Expr) transform) =>
      LambertW(transform(expr), branch: branch);

  @override
  bool _extraEquals(UnaryExpr other) =>
      other is LambertW && branch == other.branch;

  @override
  int _computeHash() => Object.hash(LambertW, branch, expr);
}

double _evaluateLambertWReal(double x, {int branch = 0}) =>
    branch == 0 ? special.lambertW0(x) : special.lambertW1(x);
