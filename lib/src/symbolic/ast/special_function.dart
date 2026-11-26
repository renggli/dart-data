part of '../ast.dart';

/// Error function node: `erf(x) = (2)/(sqrt(pi)) integrate _0^x e^{-t^2} dt`.
final class Erf extends UnaryExpr {
  /// Creates an error function node `erf(expr)`.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => Erf(expr);
}

/// Complementary error function node: `erfc(x) = 1 - erf(x)`.
final class Erfc extends UnaryExpr {
  /// Creates a complementary error function node `erfc(expr)`.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => Erfc(expr);
}

/// Euler Gamma function node: `Gamma(x) = integrate _0^oot^x-1 e^-t dt`.
final class Gamma extends UnaryExpr {
  /// Creates a Gamma function node `Gamma(expr)`.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => Gamma(expr);
}

/// Euler Beta function node: `B(a, b) = (Gamma(a)Gamma(b))/(Gamma(a+b))`.
final class Beta extends BinaryExpr {
  /// Creates a Beta function node `B(left, right)`.
  new(super.left, super.right, {super.isSimplified = false});

  @override
  Expr _withOperands(Expr left, Expr right) => Beta(left, right);
}

/// Factorial node: `n! = Gamma(n + 1)`.
final class Factorial extends UnaryExpr {
  /// Creates a factorial node `(expr)!`.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => Factorial(expr);
}

/// Binomial coefficient node: `binomial(n, k) = (Gamma(n + 1))/(Gamma(k + 1)Gamma(n - k + 1))`.
final class Binomial extends BinaryExpr {
  /// Creates a binomial coefficient node `binomial(left, right)`.
  new(super.left, super.right, {super.isSimplified = false});

  @override
  Expr _withOperands(Expr left, Expr right) => Binomial(left, right);
}

/// Floor function node: `floor(x )`.
final class Floor extends UnaryExpr {
  /// Creates a floor function node `floor(expr )`.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => Floor(expr);
}

/// Ceiling function node: `ceil(x )`.
final class Ceil extends UnaryExpr {
  /// Creates a ceiling function node `ceil(expr )`.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => Ceil(expr);
}

/// Round-to-nearest-integer function node: `round(x)`.
final class Round extends UnaryExpr {
  /// Creates a rounding function node `round(expr)`.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => Round(expr);
}

/// Signum function node: `sgn(x)`.
final class Sign extends UnaryExpr {
  /// Creates a signum function node `sgn(expr)`.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => Sign(expr);
}

/// Modulo function node: `a mod b = a - b floor(a / b )`.
final class Mod extends BinaryExpr {
  /// Creates a modulo node `left mod right`.
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

/// Digamma function node (psi function): `psi(x) = (d)/(dx) ln Gamma(x) = (Gamma'(x))/(Gamma(x))`.
final class Digamma extends UnaryExpr {
  /// Creates a digamma function node `psi(expr)`.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => Digamma(expr);
}

/// Polygamma function node: `psi^{(m)}(x) = (d^m+1)/(dx^m+1) ln Gamma(x) = (d^m)/(dx^m) psi(x)`.
final class Polygamma extends BinaryExpr {
  /// Creates a polygamma function node `psi^{(m)}(x) = Polygamma(m, x)`.
  new(super.left, super.right, {super.isSimplified = false});

  /// The derivative order `m`.
  Expr get order => left;

  /// The function argument `x`.
  Expr get argument => right;

  @override
  Expr _withOperands(Expr left, Expr right) => Polygamma(left, right);
}

/// Bessel function of the first kind: `J_nu(x)`.
final class BesselJ extends BinaryExpr {
  /// Creates a Bessel function node `J_nu(x)` of order [order] at [argument].
  new(super.left, super.right, {super.isSimplified = false});

  /// The order parameter `nu`.
  Expr get order => left;

  /// The function argument `x`.
  Expr get argument => right;

  @override
  Expr _withOperands(Expr left, Expr right) => BesselJ(left, right);
}

/// Bessel function of the second kind (Weber function): `Y_nu(x)`.
final class BesselY extends BinaryExpr {
  /// Creates a Bessel function node `Y_nu(x)` of order [order] at [argument].
  new(super.left, super.right, {super.isSimplified = false});

  /// The order parameter `nu`.
  Expr get order => left;

  /// The function argument `x`.
  Expr get argument => right;

  @override
  Expr _withOperands(Expr left, Expr right) => BesselY(left, right);
}

/// Modified Bessel function of the first kind: `I_nu(x)`.
final class BesselI extends BinaryExpr {
  /// Creates a modified Bessel function node `I_nu(x)` of order [order] at [argument].
  new(super.left, super.right, {super.isSimplified = false});

  /// The order parameter `nu`.
  Expr get order => left;

  /// The function argument `x`.
  Expr get argument => right;

  @override
  Expr _withOperands(Expr left, Expr right) => BesselI(left, right);
}

/// Modified Bessel function of the second kind: `K_nu(x)`.
final class BesselK extends BinaryExpr {
  /// Creates a modified Bessel function node `K_nu(x)` of order [order] at [argument].
  new(super.left, super.right, {super.isSimplified = false});

  /// The order parameter `nu`.
  Expr get order => left;

  /// The function argument `x`.
  Expr get argument => right;

  @override
  Expr _withOperands(Expr left, Expr right) => BesselK(left, right);
}

/// Complete elliptic integral of the first kind: `K(k) = integrate _0^{pi/2} (dtheta)/(sqrt(1 - k^2 sin^2theta))`.
final class EllipticK extends UnaryExpr {
  /// Creates a complete elliptic integral of the first kind `K(k)`.
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

/// Imaginary error function node: `erfi(x) = -ierf(ix)`.
final class Erfi extends UnaryExpr {
  /// Creates an imaginary error function node `erfi(expr)`.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => Erfi(expr);
}

/// Fresnel sine integral node: `S(x) = integrate _0^x sin ((pi)/(2)t^2)dt`.
final class FresnelS extends UnaryExpr {
  /// Creates a Fresnel sine integral node `S(expr)`.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => FresnelS(expr);
}

/// Fresnel cosine integral node: `C(x) = integrate _0^x cos ((pi)/(2)t^2)dt`.
final class FresnelC extends UnaryExpr {
  /// Creates a Fresnel cosine integral node `C(expr)`.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => FresnelC(expr);
}

/// Exponential integral node: `Ei(x) = -PVintegrate _-x^oo(e^-t)/(t) dt`.
final class ExpIntegral extends UnaryExpr {
  /// Creates an exponential integral node `Ei(expr)`.
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

/// Logarithmic integral node: `li(x) = integrate _0^x (dt)/(ln t)`.
final class LogIntegral extends UnaryExpr {
  /// Creates a logarithmic integral node `li(expr)`.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => LogIntegral(expr);
}

/// Sine integral node: `Si(x) = integrate _0^x (sin t)/(t) dt`.
final class SinIntegral extends UnaryExpr {
  /// Creates a sine integral node `Si(expr)`.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => SinIntegral(expr);
}

/// Cosine integral node: `Ci(x) = gamma + ln x + integrate _0^x (cos t - 1)/(t) dt`.
final class CosIntegral extends UnaryExpr {
  /// Creates a cosine integral node `Ci(expr)`.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => CosIntegral(expr);
}

/// Hyperbolic sine integral node: `Shi(x) = integrate _0^x (sinh t)/(t) dt`.
final class SinhIntegral extends UnaryExpr {
  /// Creates a hyperbolic sine integral node `Shi(expr)`.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => SinhIntegral(expr);
}

/// Hyperbolic cosine integral node: `Chi(x) = gamma + ln x + integrate _0^x (cosh t - 1)/(t) dt`.
final class CoshIntegral extends UnaryExpr {
  /// Creates a hyperbolic cosine integral node `Chi(expr)`.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => CoshIntegral(expr);
}

/// Upper incomplete gamma function node: `Gamma(s, x) = integrate _x^oot^s-1 e^-t dt`.
final class UpperGamma extends BinaryExpr {
  /// Creates an upper incomplete gamma node `Gamma(left, right)`.
  new(super.left, super.right, {super.isSimplified = false});

  /// The shape parameter `s`.
  Expr get order => left;

  /// The lower integration bound `x`.
  Expr get argument => right;

  @override
  Expr _withOperands(Expr left, Expr right) => UpperGamma(left, right);
}

/// Lower incomplete gamma function node: `gamma(s, x) = integrate _0^x t^s-1 e^-t dt`.
final class LowerGamma extends BinaryExpr {
  /// Creates a lower incomplete gamma node `gamma(left, right)`.
  new(super.left, super.right, {super.isSimplified = false});

  /// The shape parameter `s`.
  Expr get order => left;

  /// The upper integration bound `x`.
  Expr get argument => right;

  @override
  Expr _withOperands(Expr left, Expr right) => LowerGamma(left, right);
}

/// Polylogarithm node: `Li_s(z) = sum_{k=1}^oo(z^k)/(k^s)`.
final class Polylog extends BinaryExpr {
  /// Creates a polylogarithm node `Li_left(right)`.
  new(super.left, super.right, {super.isSimplified = false});

  /// The order `s`.
  Expr get order => left;

  /// The argument `z`.
  Expr get argument => right;

  @override
  Expr _withOperands(Expr left, Expr right) => Polylog(left, right);
}

/// Incomplete elliptic integral of the first kind: `F(phi, k) = integrate _0^phi (dtheta)/(sqrt(1 - k^2 sin^2theta))`.
final class EllipticF extends BinaryExpr {
  /// Creates an incomplete elliptic integral of the first kind `F(left, right)`.
  new(super.left, super.right, {super.isSimplified = false});

  /// The amplitude `phi`.
  Expr get amplitude => left;

  /// The modulus `k`.
  Expr get modulus => right;

  @override
  Expr _withOperands(Expr left, Expr right) => EllipticF(left, right);
}

/// Incomplete elliptic integral of the third kind: `Pi(n; phi | k) = integrate _0^phi (dtheta)/((1 - nsin^2theta)sqrt(1 - k^2sin^2theta))`.
final class EllipticPi extends Expr {
  /// Creates an incomplete elliptic integral of the third kind `Pi(n; phi | k)`.
  new(
    this.characteristic,
    this.amplitude,
    this.modulus, {
    this.isSimplified = false,
  });

  /// The characteristic `n`.
  final Expr characteristic;

  /// The amplitude `phi`.
  final Expr amplitude;

  /// The modulus `k`.
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
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Hypergeometric &&
          hashCode == other.hashCode &&
          upper.length == other.upper.length &&
          lower.length == other.lower.length &&
          argument == other.argument &&
          const ListEquality<Expr>().equals(upper, other.upper) &&
          const ListEquality<Expr>().equals(lower, other.lower));
}

/// Base class for variadic expression nodes (`min`, `max`, `gcd`, `lcm`, `tuple`).
sealed class _VariadicExpr extends Expr {
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
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _VariadicExpr &&
          runtimeType == other.runtimeType &&
          hashCode == other.hashCode &&
          args.length == other.args.length &&
          const ListEquality<Expr>().equals(args, other.args));
}

/// Minimum function node `min(a_1, ..., a_n)`.
final class Min extends _VariadicExpr {
  /// Creates a minimum expression node.
  new(super.args, {super.isSimplified = false});

  @override
  Expr _withArgs(List<Expr> args) => Min(args);
}

/// Maximum function node `max(a_1, ..., a_n)`.
final class Max extends _VariadicExpr {
  /// Creates a maximum expression node.
  new(super.args, {super.isSimplified = false});

  @override
  Expr _withArgs(List<Expr> args) => Max(args);
}

/// Greatest common divisor node `gcd(a_1, ..., a_n)`.
final class Gcd extends _VariadicExpr {
  /// Creates a greatest common divisor expression node.
  new(super.args, {super.isSimplified = false});

  @override
  Expr _withArgs(List<Expr> args) => Gcd(args);
}

/// Least common multiple node `lcm(a_1, ..., a_n)`.
final class Lcm extends _VariadicExpr {
  /// Creates a least common multiple expression node.
  new(super.args, {super.isSimplified = false});

  @override
  Expr _withArgs(List<Expr> args) => Lcm(args);
}

/// Ordered symbolic tuple node `[a_1, ..., a_n]`.
final class Tuple extends _VariadicExpr {
  /// Creates an ordered tuple expression node.
  new(super.args, {super.isSimplified = false});

  @override
  Expr _withArgs(List<Expr> args) => Tuple(args);
}
