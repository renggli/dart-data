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
      evaluateLambertWReal(expr.evaluate(context), branch: branch);

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

/// Evaluates the real Lambert $W_k(x)$ function for $k \in \{0, -1\}$ using
/// Halley's third-order cubic iteration.
double evaluateLambertWReal(double x, {int branch = 0}) {
  if (x.isNaN) return double.nan;
  const negInvE = -1.0 / math.e;

  if (branch == 0) {
    if (x < negInvE - 1e-15) return double.nan;
    if ((x - negInvE).abs() <= 1e-15) return -1.0;
    if (x == 0.0) return 0.0;
    if (x == double.infinity) return double.infinity;

    // Initial guess for principal branch W_0(x)
    double w;
    if (x < -0.3) {
      final p = math.sqrt(2.0 * (math.e * x + 1.0));
      w = -1.0 + p - (p * p) / 3.0;
    } else if (x < 3.0) {
      w = x < 0 ? x : math.log(1.0 + x);
    } else {
      final lx = math.log(x);
      final llx = math.log(lx);
      w = lx - llx + llx / lx;
    }
    return _halleyIterate(x, w);
  } else if (branch == -1) {
    if (x < negInvE - 1e-15 || x >= 0.0) return double.nan;
    if ((x - negInvE).abs() <= 1e-15) return -1.0;

    // Initial guess for lower branch W_{-1}(x)
    double w;
    if (x > -0.25) {
      final l1 = math.log(-x);
      final l2 = math.log(-l1);
      w = l1 - l2 + l2 / l1;
    } else {
      final p = -math.sqrt(2.0 * (math.e * x + 1.0));
      w = -1.0 + p - (p * p) / 3.0;
    }
    return _halleyIterate(x, w);
  } else {
    throw ArgumentError.value(
      branch,
      'branch',
      'Only branches 0 and -1 are supported in real evaluation',
    );
  }
}

double _halleyIterate(double x, double w0) {
  var w = w0;
  for (var i = 0; i < 50; i++) {
    final ew = math.exp(w);
    final wew = w * ew;
    final f = wew - x;
    if (f.abs() <= 1e-15 * x.abs().clamp(1.0, double.infinity)) {
      break;
    }
    final wp1 = w + 1.0;
    final denom = ew * wp1 - (w + 2.0) * f / (2.0 * wp1);
    if (denom == 0.0) break;
    final dw = f / denom;
    w -= dw;
    if (dw.abs() <= 1e-15 * w.abs().clamp(1.0, double.infinity)) {
      break;
    }
  }
  return w;
}
