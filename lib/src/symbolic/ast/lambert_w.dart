part of '../ast.dart';

/// Principal or secondary branch of the Lambert W function $W(expr)$.
///
/// Conceptually, the Lambert W function solves equations where the unknown
/// variable appears both linearly and exponentiated, such as $w e^w = z$.
/// Formally, it computes the inverse function of $f(w) = w e^w$.
///
/// Supports principal branch [branch] = 0 (defined for $x \ge -1/e$) and
/// secondary real branch [branch] = -1 (defined for $-1/e \le x < 0$).
final class LambertW extends UnaryExpr {
  /// Creates a Lambert W function node.
  ///
  /// [branch] must be 0 or -1.
  const new(super.expr, {this.branch = 0})
    : assert(branch == 0 || branch == -1, 'Lambert W branch must be 0 or -1');

  /// The real branch index (0 for principal branch $W_0$, -1 for secondary $W_{-1}$).
  final int branch;

  @override
  LambertW copyWith(Expr newExpr) => LambertW(newExpr, branch: branch);

  @override
  double evaluate(Map<String, double> context) =>
      evaluateLambertW(expr.evaluate(context), branch);

  /// Computes the Puiseux series expansion around the branch point $-1/e$.
  ///
  /// Local parameter $p = \sqrt{2(e x + 1)}$.
  Expr puiseuxSeries(String variable, {int order = 5}) =>
      lambertWPuiseuxSeries(variable, branch: branch, order: order);

  /// Computes the large-$x$ De Bruijn asymptotic expansion for $x \to \infty$.
  Expr asymptoticExpansion(String variable, {int order = 4}) =>
      lambertWAsymptoticExpansion(variable, order: order);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LambertW && other.branch == branch && other.expr == expr);

  @override
  int get hashCode => Object.hash(LambertW, expr, branch);
}

/// Evaluates the real Lambert W function at [x] for real [branch] (0 or -1).
double evaluateLambertW(double x, int branch) {
  if (x.isNaN) return double.nan;
  const invE = 0.36787944117144232159587; // 1/e
  const negInvE = -invE;
  const tol = 1e-15;
  if (branch == 0) {
    if (x < negInvE - tol) {
      throw RangeError.value(
        x,
        'x',
        'Lambert W (branch 0) is undefined for x < -1/e',
      );
    }
    if (x <= negInvE + tol) return -1.0;
    if (x == 0.0) return 0.0;
    if (x.isInfinite) return double.infinity;
    return special_lambert_w.lambertW0(x);
  } else if (branch == -1) {
    if (x < negInvE - tol || x >= 0.0) {
      throw RangeError.value(
        x,
        'x',
        'Lambert W (branch -1) is undefined for x outside [-1/e, 0)',
      );
    }
    if (x <= negInvE + tol) return -1.0;
    return special_lambert_w.lambertW1(x);
  } else {
    throw ArgumentError.value(
      branch,
      'branch',
      'Lambert W branch must be 0 or -1',
    );
  }
}

/// Computes the Puiseux series expansion of $W(x)$ around $-1/e$.
Expr lambertWPuiseuxSeries(String variable, {int branch = 0, int order = 5}) {
  final v = Variable(variable);
  final p = Pow(
    Mul(
      const RationalNumber(2),
      Add(Mul(ConstantNumber.e, v), RationalNumber.one),
    ),
    const RationalNumber(1, 2),
  );
  Expr res = RationalNumber.negativeOne;
  final sign = branch == 0 ? 1 : -1;

  if (order >= 1) {
    res = Add(res, Mul(RationalNumber(sign), p));
  }
  if (order >= 2) {
    res = Sub(
      res,
      Mul(const RationalNumber(1, 3), Pow(p, const RationalNumber(2))),
    );
  }
  if (order >= 3) {
    res = Add(
      res,
      Mul(RationalNumber(sign * 11, 72), Pow(p, const RationalNumber(3))),
    );
  }
  if (order >= 4) {
    res = Sub(
      res,
      Mul(const RationalNumber(43, 540), Pow(p, const RationalNumber(4))),
    );
  }
  if (order >= 5) {
    res = Add(
      res,
      OrderTerm(
        variable,
        order,
        point: const Div(RationalNumber.negativeOne, ConstantNumber.e),
      ),
    );
  }
  return res;
}

/// Computes the De Bruijn asymptotic expansion for $W_0(x)$ as $x \to \infty$.
Expr lambertWAsymptoticExpansion(String variable, {int order = 4}) {
  final v = Variable(variable);
  final l1 = Ln(v);
  final l2 = Ln(l1);
  Expr res = Sub(l1, l2);
  if (order >= 2) {
    res = Add(res, Div(l2, l1));
  }
  if (order >= 3) {
    final num = Mul(l2, Sub(l2, const RationalNumber(2)));
    final den = Mul(const RationalNumber(2), Pow(l1, const RationalNumber(2)));
    res = Add(res, Div(num, den));
  }
  if (order >= 4) {
    final inner = Add(
      Sub(
        Mul(const RationalNumber(2), Pow(l2, const RationalNumber(2))),
        Mul(const RationalNumber(9), l2),
      ),
      const RationalNumber(6),
    );
    final num = Mul(l2, inner);
    final den = Mul(const RationalNumber(6), Pow(l1, const RationalNumber(3)));
    res = Add(res, Div(num, den));
  }
  return res;
}
