part of '../ast.dart';

/// Error function node: $\operatorname{erf}(x) = \frac{2}{\sqrt{\pi}} \int_0^x e^{-t^2}\,dt$.
final class Erf extends UnaryExpr {
  /// Creates an error function node $\operatorname{erf}(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => Erf(expr);
}

/// Complementary error function node: $\operatorname{erfc}(x) = 1 - \operatorname{erf}(x)$.
final class Erfc extends UnaryExpr {
  /// Creates a complementary error function node $\operatorname{erfc}(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => Erfc(expr);
}

/// Euler Gamma function node: $\Gamma(x) = \int_0^\infty t^{x-1} e^{-t}\,dt$.
final class Gamma extends UnaryExpr {
  /// Creates a Gamma function node $\Gamma(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => Gamma(expr);
}

/// Euler Beta function node: $\operatorname{B}(a, b) = \frac{\Gamma(a)\Gamma(b)}{\Gamma(a+b)}$.
final class Beta extends BinaryExpr {
  /// Creates a Beta function node $\operatorname{B}(\text{left}, \text{right})$.
  new(super.left, super.right, {super.isSimplified = false});

  @override
  Expr _withOperands(Expr left, Expr right) => Beta(left, right);
}

/// Factorial node: $n! = \Gamma(n + 1)$.
final class Factorial extends UnaryExpr {
  /// Creates a factorial node $(\text{expr})!$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => Factorial(expr);
}

/// Binomial coefficient node: $\binom{n}{k} = \frac{\Gamma(n + 1)}{\Gamma(k + 1)\Gamma(n - k + 1)}$.
final class Binomial extends BinaryExpr {
  /// Creates a binomial coefficient node $\binom{\text{left}}{\text{right}}$.
  new(super.left, super.right, {super.isSimplified = false});

  @override
  Expr _withOperands(Expr left, Expr right) => Binomial(left, right);
}

/// Floor function node: $\lfloor x \rfloor$.
final class Floor extends UnaryExpr {
  /// Creates a floor function node $\lfloor \text{expr} \rfloor$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => Floor(expr);
}

/// Ceiling function node: $\lceil x \rceil$.
final class Ceil extends UnaryExpr {
  /// Creates a ceiling function node $\lceil \text{expr} \rceil$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => Ceil(expr);
}

/// Round-to-nearest-integer function node: $\operatorname{round}(x)$.
final class Round extends UnaryExpr {
  /// Creates a rounding function node $\operatorname{round}(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => Round(expr);
}

/// Signum function node: $\operatorname{sgn}(x)$.
final class Sign extends UnaryExpr {
  /// Creates a signum function node $\operatorname{sgn}(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => Sign(expr);
}

/// Modulo function node: $a \bmod b = a - b \lfloor a / b \rfloor$.
final class Mod extends BinaryExpr {
  /// Creates a modulo node $\text{left} \bmod \text{right}$.
  new(super.left, super.right, {super.isSimplified = false});

  @override
  Expr _withOperands(Expr left, Expr right) => Mod(left, right);
}

/// Riemann or Hurwitz zeta function node: `zeta(s)` or `zeta(s, a)`.
final class Zeta extends Expr {
  /// Creates a Riemann (`shift == null`) or Hurwitz zeta function node.
  new(this.expr, {this.shift, this.isSimplified = false});

  /// The exponent argument `s`.
  final Expr expr;

  /// Optional Hurwitz shift parameter `a`.
  final Expr? shift;

  @override
  final bool isSimplified;

  @override
  late final int hashCode = Object.hash(runtimeType, expr, shift);

  @override
  late final Set<String> freeVariables = shift == null
      ? expr.freeVariables
      : Set.unmodifiable({...expr.freeVariables, ...shift!.freeVariables});

  @override
  Expr mapChildren(Expr Function(Expr) transform) {
    final nextExpr = transform(expr);
    final nextShift = shift == null ? null : transform(shift!);
    return identical(nextExpr, expr) && identical(nextShift, shift)
        ? this
        : Zeta(nextExpr, shift: nextShift);
  }

  @override
  bool anyNode(bool Function(Expr) predicate) =>
      predicate(this) ||
      expr.anyNode(predicate) ||
      (shift != null && shift!.anyNode(predicate));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Zeta &&
          hashCode == other.hashCode &&
          expr == other.expr &&
          shift == other.shift);
}

/// Digamma function node (psi function): $\psi(x) = \frac{d}{dx} \ln \Gamma(x) = \frac{\Gamma'(x)}{\Gamma(x)}$.
final class Digamma extends UnaryExpr {
  /// Creates a digamma function node $\psi(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => Digamma(expr);
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
  Expr _withOperands(Expr left, Expr right) => Polygamma(left, right);
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
  Expr _withOperands(Expr left, Expr right) => BesselJ(left, right);
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
  Expr _withOperands(Expr left, Expr right) => BesselY(left, right);
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
  Expr _withOperands(Expr left, Expr right) => BesselI(left, right);
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
  Expr _withOperands(Expr left, Expr right) => BesselK(left, right);
}

/// Complete elliptic integral of the first kind: $K(k) = \int_0^{\pi/2} \frac{d\theta}{\sqrt{1 - k^2 \sin^2\theta}}$.
final class EllipticK extends UnaryExpr {
  /// Creates a complete elliptic integral of the first kind $K(k)$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => EllipticK(expr);
}

/// Complete (`amplitude == null`) or incomplete elliptic integral of the
/// second kind: `E(k)` or `E(phi, k)`.
final class EllipticE extends Expr {
  /// Creates a complete or incomplete elliptic integral of the second kind.
  new(this.expr, {this.amplitude, this.isSimplified = false});

  /// The modulus `k`.
  final Expr expr;

  /// Optional amplitude `phi` for the incomplete integral `E(phi, k)`.
  final Expr? amplitude;

  @override
  final bool isSimplified;

  @override
  late final int hashCode = Object.hash(runtimeType, expr, amplitude);

  @override
  late final Set<String> freeVariables = amplitude == null
      ? expr.freeVariables
      : Set.unmodifiable({...expr.freeVariables, ...amplitude!.freeVariables});

  @override
  Expr mapChildren(Expr Function(Expr) transform) {
    final nextExpr = transform(expr);
    final nextAmp = amplitude == null ? null : transform(amplitude!);
    return identical(nextExpr, expr) && identical(nextAmp, amplitude)
        ? this
        : EllipticE(nextExpr, amplitude: nextAmp);
  }

  @override
  bool anyNode(bool Function(Expr) predicate) =>
      predicate(this) ||
      expr.anyNode(predicate) ||
      (amplitude != null && amplitude!.anyNode(predicate));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EllipticE &&
          hashCode == other.hashCode &&
          expr == other.expr &&
          amplitude == other.amplitude);
}

/// Imaginary error function node: $\operatorname{erfi}(x) = -i\operatorname{erf}(ix)$.
final class Erfi extends UnaryExpr {
  /// Creates an imaginary error function node $\operatorname{erfi}(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => Erfi(expr);
}

/// Fresnel sine integral node: $S(x) = \int_0^x \sin\!\left(\frac{\pi}{2}t^2\right)dt$.
final class FresnelS extends UnaryExpr {
  /// Creates a Fresnel sine integral node $S(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => FresnelS(expr);
}

/// Fresnel cosine integral node: $C(x) = \int_0^x \cos\!\left(\frac{\pi}{2}t^2\right)dt$.
final class FresnelC extends UnaryExpr {
  /// Creates a Fresnel cosine integral node $C(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => FresnelC(expr);
}

/// Exponential integral node: $\operatorname{Ei}(x) = -\operatorname{PV}\int_{-x}^\infty \frac{e^{-t}}{t}\,dt$.
final class ExpIntegral extends UnaryExpr {
  /// Creates an exponential integral node $\operatorname{Ei}(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => ExpIntegral(expr);
}

/// Generalized exponential integral node `E_n(z)`.
final class ExpIntegralE extends BinaryExpr {
  /// Creates a generalized exponential integral node `E_order(argument)`.
  new(super.left, super.right, {super.isSimplified = false});

  /// The order `n`.
  Expr get order => left;

  /// The argument `z`.
  Expr get argument => right;

  @override
  Expr _withOperands(Expr left, Expr right) => ExpIntegralE(left, right);
}

/// Logarithmic integral node: $\operatorname{li}(x) = \int_0^x \frac{dt}{\ln t}$.
final class LogIntegral extends UnaryExpr {
  /// Creates a logarithmic integral node $\operatorname{li}(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => LogIntegral(expr);
}

/// Sine integral node: $\operatorname{Si}(x) = \int_0^x \frac{\sin t}{t}\,dt$.
final class SinIntegral extends UnaryExpr {
  /// Creates a sine integral node $\operatorname{Si}(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => SinIntegral(expr);
}

/// Cosine integral node: $\operatorname{Ci}(x) = \gamma + \ln x + \int_0^x \frac{\cos t - 1}{t}\,dt$.
final class CosIntegral extends UnaryExpr {
  /// Creates a cosine integral node $\operatorname{Ci}(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => CosIntegral(expr);
}

/// Hyperbolic sine integral node: $\operatorname{Shi}(x) = \int_0^x \frac{\sinh t}{t}\,dt$.
final class SinhIntegral extends UnaryExpr {
  /// Creates a hyperbolic sine integral node $\operatorname{Shi}(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => SinhIntegral(expr);
}

/// Hyperbolic cosine integral node: $\operatorname{Chi}(x) = \gamma + \ln x + \int_0^x \frac{\cosh t - 1}{t}\,dt$.
final class CoshIntegral extends UnaryExpr {
  /// Creates a hyperbolic cosine integral node $\operatorname{Chi}(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => CoshIntegral(expr);
}

/// Upper incomplete gamma function node: $\Gamma(s, x) = \int_x^\infty t^{s-1} e^{-t}\,dt$.
final class UpperGamma extends BinaryExpr {
  /// Creates an upper incomplete gamma node $\Gamma(\text{left}, \text{right})$.
  new(super.left, super.right, {super.isSimplified = false});

  /// The shape parameter $s$.
  Expr get order => left;

  /// The lower integration bound $x$.
  Expr get argument => right;

  @override
  Expr _withOperands(Expr left, Expr right) => UpperGamma(left, right);
}

/// Lower incomplete gamma function node: $\gamma(s, x) = \int_0^x t^{s-1} e^{-t}\,dt$.
final class LowerGamma extends BinaryExpr {
  /// Creates a lower incomplete gamma node $\gamma(\text{left}, \text{right})$.
  new(super.left, super.right, {super.isSimplified = false});

  /// The shape parameter $s$.
  Expr get order => left;

  /// The upper integration bound $x$.
  Expr get argument => right;

  @override
  Expr _withOperands(Expr left, Expr right) => LowerGamma(left, right);
}

/// Polylogarithm node: $\operatorname{Li}_s(z) = \sum_{k=1}^\infty \frac{z^k}{k^s}$.
final class Polylog extends BinaryExpr {
  /// Creates a polylogarithm node $\operatorname{Li}_{\text{left}}(\text{right})$.
  new(super.left, super.right, {super.isSimplified = false});

  /// The order $s$.
  Expr get order => left;

  /// The argument $z$.
  Expr get argument => right;

  @override
  Expr _withOperands(Expr left, Expr right) => Polylog(left, right);
}

/// Incomplete elliptic integral of the first kind: $F(\phi, k) = \int_0^\phi \frac{d\theta}{\sqrt{1 - k^2 \sin^2\theta}}$.
final class EllipticF extends BinaryExpr {
  /// Creates an incomplete elliptic integral of the first kind $F(\text{left}, \text{right})$.
  new(super.left, super.right, {super.isSimplified = false});

  /// The amplitude $\phi$.
  Expr get amplitude => left;

  /// The modulus $k$.
  Expr get modulus => right;

  @override
  Expr _withOperands(Expr left, Expr right) => EllipticF(left, right);
}

/// Incomplete elliptic integral of the third kind: $\Pi(n; \phi \mid k) = \int_0^\phi \frac{d\theta}{(1 - n\sin^2\theta)\sqrt{1 - k^2\sin^2\theta}}$.
final class EllipticPi extends Expr {
  /// Creates an incomplete elliptic integral of the third kind $\Pi(n; \phi \mid k)$.
  new(
    this.characteristic,
    this.amplitude,
    this.modulus, {
    this.isSimplified = false,
  });

  /// The characteristic $n$.
  final Expr characteristic;

  /// The amplitude $\phi$.
  final Expr amplitude;

  /// The modulus $k$.
  final Expr modulus;

  @override
  final bool isSimplified;

  @override
  late final int hashCode = Object.hash(
    runtimeType,
    characteristic,
    amplitude,
    modulus,
  );

  @override
  late final Set<String> freeVariables = Set.unmodifiable({
    ...characteristic.freeVariables,
    ...amplitude.freeVariables,
    ...modulus.freeVariables,
  });

  @override
  Expr mapChildren(Expr Function(Expr) transform) {
    final nextN = transform(characteristic);
    final nextPhi = transform(amplitude);
    final nextK = transform(modulus);
    return identical(nextN, characteristic) &&
            identical(nextPhi, amplitude) &&
            identical(nextK, modulus)
        ? this
        : EllipticPi(nextN, nextPhi, nextK);
  }

  @override
  bool anyNode(bool Function(Expr) predicate) =>
      predicate(this) ||
      characteristic.anyNode(predicate) ||
      amplitude.anyNode(predicate) ||
      modulus.anyNode(predicate);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EllipticPi &&
          hashCode == other.hashCode &&
          characteristic == other.characteristic &&
          amplitude == other.amplitude &&
          modulus == other.modulus);
}

/// Generalized hypergeometric function node `pFq(upper; lower; argument)`.
final class Hypergeometric extends Expr {
  /// Creates a generalized hypergeometric function node.
  new(
    List<Expr> upper,
    List<Expr> lower,
    this.argument, {
    this.isSimplified = false,
  }) : upper = List<Expr>.unmodifiable(upper),
       lower = List<Expr>.unmodifiable(lower);

  /// Upper parameter list `[a_1, ..., a_p]`.
  final List<Expr> upper;

  /// Lower parameter list `[b_1, ..., b_q]`.
  final List<Expr> lower;

  /// Argument expression `z`.
  final Expr argument;

  @override
  final bool isSimplified;

  @override
  late final int hashCode = Object.hash(
    runtimeType,
    Object.hashAll(upper),
    Object.hashAll(lower),
    argument,
  );

  @override
  late final Set<String> freeVariables = Set.unmodifiable({
    for (final u in upper) ...u.freeVariables,
    for (final l in lower) ...l.freeVariables,
    ...argument.freeVariables,
  });

  @override
  Expr mapChildren(Expr Function(Expr) transform) {
    var changed = false;
    final nextUpper = <Expr>[];
    for (final u in upper) {
      final nu = transform(u);
      if (!identical(nu, u)) changed = true;
      nextUpper.add(nu);
    }
    final nextLower = <Expr>[];
    for (final l in lower) {
      final nl = transform(l);
      if (!identical(nl, l)) changed = true;
      nextLower.add(nl);
    }
    final nextArg = transform(argument);
    if (!identical(nextArg, argument)) changed = true;
    return changed ? Hypergeometric(nextUpper, nextLower, nextArg) : this;
  }

  @override
  bool anyNode(bool Function(Expr) predicate) =>
      predicate(this) ||
      upper.any((u) => u.anyNode(predicate)) ||
      lower.any((l) => l.anyNode(predicate)) ||
      argument.anyNode(predicate);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Hypergeometric ||
        hashCode != other.hashCode ||
        upper.length != other.upper.length ||
        lower.length != other.lower.length ||
        argument != other.argument) {
      return false;
    }
    for (var i = 0; i < upper.length; i++) {
      if (upper[i] != other.upper[i]) return false;
    }
    for (var i = 0; i < lower.length; i++) {
      if (lower[i] != other.lower[i]) return false;
    }
    return true;
  }
}

/// Base class for variadic order-statistics functions (`min`, `max`).
sealed class _OrderExpr extends Expr {
  new(List<Expr> args, {this.isSimplified = false})
    : args = List<Expr>.unmodifiable(args);

  /// Operand expressions.
  final List<Expr> args;

  @override
  final bool isSimplified;

  @override
  late final int hashCode = Object.hash(runtimeType, Object.hashAll(args));

  @override
  late final Set<String> freeVariables = Set.unmodifiable({
    for (final a in args) ...a.freeVariables,
  });

  Expr _withArgs(List<Expr> args);

  @override
  Expr mapChildren(Expr Function(Expr) transform) {
    var changed = false;
    final next = <Expr>[];
    for (final a in args) {
      final na = transform(a);
      if (!identical(na, a)) changed = true;
      next.add(na);
    }
    return changed ? _withArgs(next) : this;
  }

  @override
  bool anyNode(bool Function(Expr) predicate) =>
      predicate(this) || args.any((a) => a.anyNode(predicate));

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _OrderExpr ||
        runtimeType != other.runtimeType ||
        hashCode != other.hashCode ||
        args.length != other.args.length) {
      return false;
    }
    for (var i = 0; i < args.length; i++) {
      if (args[i] != other.args[i]) return false;
    }
    return true;
  }
}

/// Minimum function node `min(a_1, ..., a_n)`.
final class Min extends _OrderExpr {
  /// Creates a minimum expression node.
  new(super.args, {super.isSimplified = false});

  @override
  Expr _withArgs(List<Expr> args) => Min(args);
}

/// Maximum function node `max(a_1, ..., a_n)`.
final class Max extends _OrderExpr {
  /// Creates a maximum expression node.
  new(super.args, {super.isSimplified = false});

  @override
  Expr _withArgs(List<Expr> args) => Max(args);
}
