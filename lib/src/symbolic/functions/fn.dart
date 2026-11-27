import '../ast.dart';
import 'discrete_specs.dart';
import 'elementary_specs.dart';
import 'special_specs.dart';

/// Canonical namespace of all built-in mathematical function descriptors and
/// constructors.
///
/// Each field is a compile-time `const` [FunctionSpec] whose `call(...)` method
/// builds a [Call] node directly (for example `Fn.sin(x)`, `Fn.besselJ(n, x)`).
abstract final class Fn {
  /// Sine function `sin(x)`.
  static const sin = sinSpec;

  /// Cosine function `cos(x)`.
  static const cos = cosSpec;

  /// Tangent function `tan(x)`.
  static const tan = tanSpec;

  /// Inverse sine `asin(x)`.
  static const asin = asinSpec;

  /// Inverse cosine `acos(x)`.
  static const acos = acosSpec;

  /// Inverse tangent `atan(x)`.
  static const atan = atanSpec;

  /// Two-argument arctangent `atan2(y, x)`.
  static const atan2 = atan2Spec;

  /// Hyperbolic sine `sinh(x)`.
  static const sinh = sinhSpec;

  /// Hyperbolic cosine `cosh(x)`.
  static const cosh = coshSpec;

  /// Hyperbolic tangent `tanh(x)`.
  static const tanh = tanhSpec;

  /// Inverse hyperbolic sine `asinh(x)`.
  static const asinh = asinhSpec;

  /// Inverse hyperbolic cosine `acosh(x)`.
  static const acosh = acoshSpec;

  /// Inverse hyperbolic tangent `atanh(x)`.
  static const atanh = atanhSpec;

  /// Absolute value or modulus `abs(x)`.
  static const abs = absSpec;

  /// Natural logarithm `ln(x)`.
  static const ln = lnSpec;

  /// Real part `re(z)`.
  static const re = reSpec;

  /// Imaginary part `im(z)`.
  static const im = imSpec;

  /// Principal argument `arg(z)`.
  static const arg = argSpec;

  /// Complex conjugate `conj(z)`.
  static const conj = conjSpec;

  /// Factorial `factorial(n)` / `n!`.
  static const factorial = factorialSpec;

  /// Binomial coefficient `binomial(n, k)`.
  static const binomial = binomialSpec;

  /// Floor function `floor(x)`.
  static const floor = floorSpec;

  /// Ceiling function `ceil(x)`.
  static const ceil = ceilSpec;

  /// Rounding function `round(x)`.
  static const round = roundSpec;

  /// Signum function `sign(x)`.
  static const sign = signSpec;

  /// Modulo remainder `mod(a, b)`.
  static const mod = modSpec;

  /// Minimum `min([a_1, ..., a_n])`.
  static const min = minSpec;

  /// Maximum `max([a_1, ..., a_n])`.
  static const max = maxSpec;

  /// Greatest common divisor `gcd([a_1, ..., a_n])`.
  static const gcd = gcdSpec;

  /// Least common multiple `lcm([a_1, ..., a_n])`.
  static const lcm = lcmSpec;

  /// Ordered tuple `tuple([a_1, ..., a_n])`.
  static const tuple = tupleSpec;

  /// Error function `erf(z)`.
  static const erf = erfSpec;

  /// Complementary error function `erfc(z)`.
  static const erfc = erfcSpec;

  /// Imaginary error function `erfi(z)`.
  static const erfi = erfiSpec;

  /// Fresnel sine integral `fresnelS(z)`.
  static const fresnelS = fresnelSSpec;

  /// Fresnel cosine integral `fresnelC(z)`.
  static const fresnelC = fresnelCSpec;

  /// Exponential integral `Ei(x)`.
  static const ei = eiSpec;

  /// Generalized exponential integral `expIntegralE(n, x)`.
  static const expIntegralE = expIntegralESpec;

  /// Logarithmic integral `li(x)`.
  static const li = liSpec;

  /// Sine integral `Si(x)`.
  static const si = siSpec;

  /// Cosine integral `Ci(x)`.
  static const ci = ciSpec;

  /// Hyperbolic sine integral `Shi(x)`.
  static const shi = shiSpec;

  /// Hyperbolic cosine integral `Chi(x)`.
  static const chi = chiSpec;

  /// Euler gamma function `gamma(z)`.
  static const gamma = gammaSpec;

  /// Upper incomplete gamma `upperGamma(s, x)`.
  static const upperGamma = upperGammaSpec;

  /// Lower incomplete gamma `lowerGamma(s, x)`.
  static const lowerGamma = lowerGammaSpec;

  /// Log-gamma function `logGamma(z)`.
  static const logGamma = logGammaSpec;

  /// Digamma function `digamma(z)`.
  static const digamma = digammaSpec;

  /// Polygamma function `polygamma(n, z)`.
  static const polygamma = polygammaSpec;

  /// Riemann or Hurwitz zeta function `zeta(s, [a])`.
  static const zeta = zetaSpec;

  /// Euler beta function `beta(a, b)`.
  static const beta = betaSpec;

  /// Polylogarithm `polylog(s, z)`.
  static const polylog = polylogSpec;

  /// Bessel function of the first kind `besselJ(n, z)`.
  static const besselJ = besselJSpec;

  /// Bessel function of the second kind `besselY(n, z)`.
  static const besselY = besselYSpec;

  /// Modified Bessel function of the first kind `besselI(n, z)`.
  static const besselI = besselISpec;

  /// Modified Bessel function of the second kind `besselK(n, z)`.
  static const besselK = besselKSpec;

  /// Complete elliptic integral of the first kind `ellipticK(k)`.
  static const ellipticK = ellipticKSpec;

  /// Complete/incomplete elliptic integral of the second kind `ellipticE`.
  static const ellipticE = ellipticESpec;

  /// Incomplete elliptic integral of the first kind `ellipticF(phi, k)`.
  static const ellipticF = ellipticFSpec;

  /// Incomplete elliptic integral of the third kind `ellipticPi(n, phi, k)`.
  static const ellipticPi = ellipticPiSpec;

  /// Generalized hypergeometric function `hypergeometric(upper, lower, z)`.
  static const hypergeometric = hypergeometricSpec;

  /// Appell hypergeometric function `appellF1(a, b1, b2, c, x, y)`.
  static const appellF1 = appellF1Spec;

  /// Lambert W function `lambertW(z, [k])`.
  static const lambertW = lambertWSpec;

  /// Constructs an uninterpreted symbolic function call `name(args...)`.
  static Call symbolic(String name, Iterable<Expr> args) =>
      Call.symbolic(name, args);

  /// Dense registry of all built-in [FunctionSpec] descriptors, ordered by
  /// [FunctionId.index] (excluding [FunctionId.symbolic]).
  static const List<FunctionSpec> registry = [
    sin,
    cos,
    tan,
    asin,
    acos,
    atan,
    atan2,
    sinh,
    cosh,
    tanh,
    asinh,
    acosh,
    atanh,
    abs,
    ln,
    re,
    im,
    arg,
    conj,
    factorial,
    binomial,
    floor,
    ceil,
    round,
    sign,
    mod,
    min,
    max,
    gcd,
    lcm,
    tuple,
    erf,
    erfc,
    erfi,
    fresnelS,
    fresnelC,
    ei,
    expIntegralE,
    li,
    si,
    ci,
    shi,
    chi,
    gamma,
    upperGamma,
    lowerGamma,
    logGamma,
    digamma,
    polygamma,
    zeta,
    beta,
    polylog,
    besselJ,
    besselY,
    besselI,
    besselK,
    ellipticK,
    ellipticE,
    ellipticF,
    ellipticPi,
    hypergeometric,
    appellF1,
    lambertW,
  ];

  /// Map from canonical function name to its [FunctionSpec] descriptor.
  static final Map<String, FunctionSpec> byName = Map.unmodifiable({
    for (final spec in registry) spec.name: spec,
  });
}
