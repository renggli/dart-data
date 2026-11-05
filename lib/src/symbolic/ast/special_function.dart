part of '../ast.dart';

/// Error function node: $\operatorname{erf}(x) = \frac{2}{\sqrt{\pi}} \int_0^x e^{-t^2}\,dt$.
final class Erf extends UnaryExpr {
  /// Creates an error function node $\operatorname{erf}(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

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
  Expr substitute(String variable, Expr replacement) => Mod(
    left.substitute(variable, replacement),
    right.substitute(variable, replacement),
  );

  @override
  Expr mapChildren(Expr Function(Expr) transform) =>
      Mod(transform(left), transform(right));
}

/// Riemann zeta function node: $\zeta(s) = \sum_{n=1}^\infty \frac{1}{n^s}$.
final class Zeta extends UnaryExpr {
  /// Creates a Riemann zeta function node $\zeta(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr substitute(String variable, Expr replacement) =>
      Zeta(expr.substitute(variable, replacement));

  @override
  Expr mapChildren(Expr Function(Expr) transform) => Zeta(transform(expr));
}

/// Digamma function node (psi function): $\psi(x) = \frac{d}{dx} \ln \Gamma(x) = \frac{\Gamma'(x)}{\Gamma(x)}$.
final class Digamma extends UnaryExpr {
  /// Creates a digamma function node $\psi(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr substitute(String variable, Expr replacement) =>
      Digamma(expr.substitute(variable, replacement));

  @override
  Expr mapChildren(Expr Function(Expr) transform) => Digamma(transform(expr));
}

/// Polygamma function node: $\psi^{(m)}(x) = \frac{d^{m+1}}{dx^{m+1}} \ln \Gamma(x) = \frac{d^m}{dx^m} \psi(x)$.
final class Polygamma extends BinaryExpr {
  /// Creates a polygamma function node $\psi^{(m)}(x) = \text{Polygamma}(m, x)$.
  new(super.left, super.right, {super.isSimplified = false});

  /// The derivative order $m$.
  Expr get order => left;

  /// The function argument $x$.
  Expr get argument => right;

  @override
  Expr substitute(String variable, Expr replacement) => Polygamma(
    left.substitute(variable, replacement),
    right.substitute(variable, replacement),
  );

  @override
  Expr mapChildren(Expr Function(Expr) transform) =>
      Polygamma(transform(left), transform(right));
}

/// Bessel function of the first kind: $J_\nu(x)$.
final class BesselJ extends BinaryExpr {
  /// Creates a Bessel function node $J_\nu(x)$ of order [order] at [argument].
  new(super.left, super.right, {super.isSimplified = false});

  /// The order parameter $\nu$.
  Expr get order => left;

  /// The function argument $x$.
  Expr get argument => right;

  @override
  Expr substitute(String variable, Expr replacement) => BesselJ(
    left.substitute(variable, replacement),
    right.substitute(variable, replacement),
  );

  @override
  Expr mapChildren(Expr Function(Expr) transform) =>
      BesselJ(transform(left), transform(right));
}

/// Bessel function of the second kind (Weber function): $Y_\nu(x)$.
final class BesselY extends BinaryExpr {
  /// Creates a Bessel function node $Y_\nu(x)$ of order [order] at [argument].
  new(super.left, super.right, {super.isSimplified = false});

  /// The order parameter $\nu$.
  Expr get order => left;

  /// The function argument $x$.
  Expr get argument => right;

  @override
  Expr substitute(String variable, Expr replacement) => BesselY(
    left.substitute(variable, replacement),
    right.substitute(variable, replacement),
  );

  @override
  Expr mapChildren(Expr Function(Expr) transform) =>
      BesselY(transform(left), transform(right));
}

/// Modified Bessel function of the first kind: $I_\nu(x)$.
final class BesselI extends BinaryExpr {
  /// Creates a modified Bessel function node $I_\nu(x)$ of order [order] at [argument].
  new(super.left, super.right, {super.isSimplified = false});

  /// The order parameter $\nu$.
  Expr get order => left;

  /// The function argument $x$.
  Expr get argument => right;

  @override
  Expr substitute(String variable, Expr replacement) => BesselI(
    left.substitute(variable, replacement),
    right.substitute(variable, replacement),
  );

  @override
  Expr mapChildren(Expr Function(Expr) transform) =>
      BesselI(transform(left), transform(right));
}

/// Modified Bessel function of the second kind: $K_\nu(x)$.
final class BesselK extends BinaryExpr {
  /// Creates a modified Bessel function node $K_\nu(x)$ of order [order] at [argument].
  new(super.left, super.right, {super.isSimplified = false});

  /// The order parameter $\nu$.
  Expr get order => left;

  /// The function argument $x$.
  Expr get argument => right;

  @override
  Expr substitute(String variable, Expr replacement) => BesselK(
    left.substitute(variable, replacement),
    right.substitute(variable, replacement),
  );

  @override
  Expr mapChildren(Expr Function(Expr) transform) =>
      BesselK(transform(left), transform(right));
}

/// Complete elliptic integral of the first kind: $K(k) = \int_0^{\pi/2} \frac{d\theta}{\sqrt{1 - k^2 \sin^2\theta}}$.
final class EllipticK extends UnaryExpr {
  /// Creates a complete elliptic integral of the first kind $K(k)$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr substitute(String variable, Expr replacement) =>
      EllipticK(expr.substitute(variable, replacement));

  @override
  Expr mapChildren(Expr Function(Expr) transform) => EllipticK(transform(expr));
}

/// Complete elliptic integral of the second kind: $E(k) = \int_0^{\pi/2} \sqrt{1 - k^2 \sin^2\theta}\,d\theta$.
final class EllipticE extends UnaryExpr {
  /// Creates a complete elliptic integral of the second kind $E(k)$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr substitute(String variable, Expr replacement) =>
      EllipticE(expr.substitute(variable, replacement));

  @override
  Expr mapChildren(Expr Function(Expr) transform) => EllipticE(transform(expr));
}
