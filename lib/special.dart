/// High-precision mathematical special functions of mathematical physics and
/// applied analysis.
///
/// Implements transcendent special functions essential in probability theory,
/// quantum mechanics, fluid dynamics, electromagnetism, and engineering.
///
/// ## Implemented Function Families
///
/// - **Gamma & Factorial Functions** ([gamma], [gammaLn], [gammaP],
///   [gammaQ], [gammaPInv], [gammaQInv], [upperGamma], [lowerGamma],
///   [factorial], [factorialLn], [binomial], [binomialLn], [permutation],
///   [permutationLn]): The continuous extension of the factorial
///   `Γ(n) = (n - 1)!` and its regularized and unregularized incomplete forms,
///   implemented via Lanczos approximation with 15 digits of numerical precision.
/// - **Beta Functions** ([beta], [betaLn], [betaI], [betaIInv]): Euler's
///   integral of the first kind `B(a, b)`, and the regularized incomplete beta
///   function.
/// - **Psi, Zeta & Polylogarithm Functions** ([digamma], [polygamma], [zeta],
///   [hurwitzZeta], [polylog], [polylogComplex]): Logarithmic derivatives of
///   the gamma function `ψ^(m)(x)`, the Riemann and Hurwitz zeta functions
///   `ζ(s)` and `ζ(s, a)`, and the polylogarithm `Li_s(z)`.
/// - **Error & Fresnel Functions** ([erf], [erfc], [erfi], [erfInv],
///   [erfcInv], [fresnelS], [fresnelC]): Gaussian error integrals and
///   normalized Fresnel sine and cosine integrals.
/// - **Exponential, Trigonometric & Hyperbolic Integrals** ([expIntegral],
///   [expIntegralE], [logIntegral], [sinIntegral], [cosIntegral],
///   [sinhIntegral], [coshIntegral]): Classical non-elementary integral
///   functions.
/// - **Bessel Functions** ([besselJ], [besselY], [besselI], [besselK]):
///   Solutions to Bessel's differential equation describing radial and wave
///   behavior in cylindrical geometries.
/// - **Elliptic Integrals** ([ellipticK], [ellipticE], [ellipticF],
///   [ellipticPi]): Complete and incomplete Legendre elliptic integrals of the
///   1st, 2nd, and 3rd kinds.
/// - **Hypergeometric Functions** ([hypergeometric1F1], [hypergeometric2F1],
///   [hypergeometricPFQ]): Kummer's confluent series `1F1(a; b; z)`, Gauss's
///   series `2F1(a, b; c; z)`, and the generalized series `pFq(a; b; z)`.
/// - **Lambert W** ([lambertW]): The principal and secondary real branches of
///   the product log function solving `W(x) * exp(W(x)) = x`.
///
/// ## Example
///
/// ```dart
/// import 'package:data/special.dart';
///
/// void main() {
///   // Gamma of half-integers: Gamma(0.5) = sqrt(pi) ~= 1.77245
///   print('Gamma(0.5) = ${gamma(0.5)}');
///
///   // Error function erf(1.0) ~= 0.84270
///   print('erf(1.0) = ${erf(1.0)}');
///
///   // Bessel J0(0.0) = 1.0
///   print('J_0(0.0) = ${besselJ(0, 0.0)}');
/// }
/// ```
library;

import 'src/special/bessel.dart';
import 'src/special/beta.dart';
import 'src/special/binomial.dart';
import 'src/special/digamma.dart';
import 'src/special/elliptic.dart';
import 'src/special/erf.dart';
import 'src/special/exp_integral.dart';
import 'src/special/factorial.dart';
import 'src/special/fresnel.dart';
import 'src/special/gamma.dart';
import 'src/special/hypergeometric.dart';
import 'src/special/lambert_w.dart';
import 'src/special/permutation.dart';
import 'src/special/polylog.dart';
import 'src/special/trig_integral.dart';
import 'src/special/zeta.dart';

export 'src/special/bessel.dart';
export 'src/special/beta.dart';
export 'src/special/binomial.dart';
export 'src/special/digamma.dart';
export 'src/special/elliptic.dart';
export 'src/special/erf.dart';
export 'src/special/exp_integral.dart';
export 'src/special/factorial.dart';
export 'src/special/fresnel.dart';
export 'src/special/gamma.dart';
export 'src/special/hypergeometric.dart';
export 'src/special/lambert_w.dart';
export 'src/special/permutation.dart';
export 'src/special/polylog.dart';
export 'src/special/trig_integral.dart';
export 'src/special/zeta.dart';
