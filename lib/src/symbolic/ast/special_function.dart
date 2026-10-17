part of '../ast.dart';

/// Error function node: $\operatorname{erf}(x) = \frac{2}{\sqrt{\pi}} \int_0^x e^{-t^2}\,dt$.
final class Erf extends UnaryExpr {
  /// Creates an error function node $\operatorname{erf}(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  double evaluate([Map<String, double> context = const {}]) =>
      special.erf(expr.evaluate(context));

  @override
  Expr substitute(String variable, Expr replacement) =>
      Erf(expr.substitute(variable, replacement));

  @override
  Expr mapChildren(Expr Function(Expr) transform) => Erf(transform(expr));
}

/// Complementary error function node: $\operatorname{erfc}(x) = 1 - \operatorname{erf}(x)$.
final class Erfc extends UnaryExpr {
  /// Creates a complementary error function node $\operatorname{erfc}(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  double evaluate([Map<String, double> context = const {}]) =>
      special.erfc(expr.evaluate(context));

  @override
  Expr substitute(String variable, Expr replacement) =>
      Erfc(expr.substitute(variable, replacement));

  @override
  Expr mapChildren(Expr Function(Expr) transform) => Erfc(transform(expr));
}

/// Euler Gamma function node: $\Gamma(x) = \int_0^\infty t^{x-1} e^{-t}\,dt$.
final class Gamma extends UnaryExpr {
  /// Creates a Gamma function node $\Gamma(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  double evaluate([Map<String, double> context = const {}]) =>
      special.gamma(expr.evaluate(context));

  @override
  Expr substitute(String variable, Expr replacement) =>
      Gamma(expr.substitute(variable, replacement));

  @override
  Expr mapChildren(Expr Function(Expr) transform) => Gamma(transform(expr));
}

/// Euler Beta function node: $\operatorname{B}(a, b) = \frac{\Gamma(a)\Gamma(b)}{\Gamma(a+b)}$.
final class Beta extends BinaryExpr {
  /// Creates a Beta function node $\operatorname{B}(\text{left}, \text{right})$.
  new(super.left, super.right, {super.isSimplified = false});

  @override
  double evaluate([Map<String, double> context = const {}]) =>
      special.beta(left.evaluate(context), right.evaluate(context));

  @override
  Expr substitute(String variable, Expr replacement) => Beta(
    left.substitute(variable, replacement),
    right.substitute(variable, replacement),
  );

  @override
  Expr mapChildren(Expr Function(Expr) transform) =>
      Beta(transform(left), transform(right));
}

/// Factorial node: $n! = \Gamma(n + 1)$.
final class Factorial extends UnaryExpr {
  /// Creates a factorial node $(\text{expr})!$.
  new(super.expr, {super.isSimplified = false});

  @override
  double evaluate([Map<String, double> context = const {}]) =>
      special.gamma(expr.evaluate(context) + 1.0);

  @override
  Expr substitute(String variable, Expr replacement) =>
      Factorial(expr.substitute(variable, replacement));

  @override
  Expr mapChildren(Expr Function(Expr) transform) => Factorial(transform(expr));
}

/// Binomial coefficient node: $\binom{n}{k} = \frac{\Gamma(n + 1)}{\Gamma(k + 1)\Gamma(n - k + 1)}$.
final class Binomial extends BinaryExpr {
  /// Creates a binomial coefficient node $\binom{\text{left}}{\text{right}}$.
  new(super.left, super.right, {super.isSimplified = false});

  @override
  double evaluate([Map<String, double> context = const {}]) {
    final n = left.evaluate(context);
    final k = right.evaluate(context);
    if (n.isNaN || k.isNaN) return double.nan;
    if (k == k.roundToDouble() && k < 0.0) return 0.0;
    if (n == n.roundToDouble() && k == k.roundToDouble() && n >= 0.0 && k > n) {
      return 0.0;
    }
    return special.gamma(n + 1.0) /
        (special.gamma(k + 1.0) * special.gamma(n - k + 1.0));
  }

  @override
  Expr substitute(String variable, Expr replacement) => Binomial(
    left.substitute(variable, replacement),
    right.substitute(variable, replacement),
  );

  @override
  Expr mapChildren(Expr Function(Expr) transform) =>
      Binomial(transform(left), transform(right));
}

/// Floor function node: $\lfloor x \rfloor$.
final class Floor extends UnaryExpr {
  /// Creates a floor function node $\lfloor \text{expr} \rfloor$.
  new(super.expr, {super.isSimplified = false});

  @override
  double evaluate([Map<String, double> context = const {}]) {
    final v = expr.evaluate(context);
    return v.isFinite ? v.floorToDouble() : v;
  }

  @override
  Expr substitute(String variable, Expr replacement) =>
      Floor(expr.substitute(variable, replacement));

  @override
  Expr mapChildren(Expr Function(Expr) transform) => Floor(transform(expr));
}

/// Ceiling function node: $\lceil x \rceil$.
final class Ceil extends UnaryExpr {
  /// Creates a ceiling function node $\lceil \text{expr} \rceil$.
  new(super.expr, {super.isSimplified = false});

  @override
  double evaluate([Map<String, double> context = const {}]) {
    final v = expr.evaluate(context);
    return v.isFinite ? v.ceilToDouble() : v;
  }

  @override
  Expr substitute(String variable, Expr replacement) =>
      Ceil(expr.substitute(variable, replacement));

  @override
  Expr mapChildren(Expr Function(Expr) transform) => Ceil(transform(expr));
}

/// Round-to-nearest-integer function node: $\operatorname{round}(x)$.
final class Round extends UnaryExpr {
  /// Creates a rounding function node $\operatorname{round}(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  double evaluate([Map<String, double> context = const {}]) {
    final v = expr.evaluate(context);
    return v.isFinite ? v.roundToDouble() : v;
  }

  @override
  Expr substitute(String variable, Expr replacement) =>
      Round(expr.substitute(variable, replacement));

  @override
  Expr mapChildren(Expr Function(Expr) transform) => Round(transform(expr));
}

/// Signum function node: $\operatorname{sgn}(x)$.
final class Sign extends UnaryExpr {
  /// Creates a signum function node $\operatorname{sgn}(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  double evaluate([Map<String, double> context = const {}]) {
    final v = expr.evaluate(context);
    if (v.isNaN) return double.nan;
    if (v == 0.0) return 0.0;
    return v > 0.0 ? 1.0 : -1.0;
  }

  @override
  Expr substitute(String variable, Expr replacement) =>
      Sign(expr.substitute(variable, replacement));

  @override
  Expr mapChildren(Expr Function(Expr) transform) => Sign(transform(expr));
}

/// Modulo function node: $a \bmod b = a - b \lfloor a / b \rfloor$.
final class Mod extends BinaryExpr {
  /// Creates a modulo node $\text{left} \bmod \text{right}$.
  new(super.left, super.right, {super.isSimplified = false});

  @override
  double evaluate([Map<String, double> context = const {}]) {
    final a = left.evaluate(context);
    final b = right.evaluate(context);
    if (a.isNaN || b.isNaN || b == 0.0) return double.nan;
    return a - b * (a / b).floorToDouble();
  }

  @override
  Expr substitute(String variable, Expr replacement) => Mod(
    left.substitute(variable, replacement),
    right.substitute(variable, replacement),
  );

  @override
  Expr mapChildren(Expr Function(Expr) transform) =>
      Mod(transform(left), transform(right));
}
