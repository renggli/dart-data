/// High-precision mathematical special functions of mathematical physics and
/// applied analysis.
///
/// Implements transcendent special functions essential in probability theory,
/// quantum mechanics, fluid dynamics, electromagnetism, and engineering.
///
/// ## Implemented Function Families
///
/// - **Gamma & Factorial Functions** ([gamma], [gammaLn], [gammap],
///   [gammaq], [gammapInv], [gammaqInv], [upperGamma], [lowerGamma]): The
///   continuous extension of the factorial `Γ(n) = (n - 1)!` and its
///   regularized and unregularized incomplete forms, implemented via Lanczos
///   approximation with 15 digits of numerical precision.
/// - **Beta Functions** ([beta], [betaLn], [ibeta], [ibetaInv]): Euler's
///   integral of the first kind `B(a, b)`, and the regularized incomplete beta
///   function.
/// - **Psi, Zeta & Polylogarithm Functions** ([digamma], [trigamma],
///   [polygamma], [zeta], [polylog]): Logarithmic derivatives of the gamma
///   function `ψ^(m)(x)`, the Riemann zeta function `ζ(s)`, and the
///   polylogarithm `Li_s(z)`.
/// - **Error & Fresnel Functions** ([erf], [erfc], [erfi], [erfInv],
///   [erfcInv], [fresnelS], [fresnelC]): Gaussian error integrals and
///   normalized Fresnel sine and cosine integrals.
/// - **Exponential, Trigonometric & Hyperbolic Integrals** ([expIntegralEi],
///   [logIntegralLi], [sinIntegralSi], [cosIntegralCi], [sinhIntegralShi],
///   [coshIntegralChi]): Classical non-elementary integral functions.
/// - **Bessel Functions** ([besselJ], [besselY], [besselI], [besselK],
///   [besselJ0], [besselJ1], [besselY0], [besselY1],
///   [besselI0], [besselI1], [besselK0], [besselK1]): Solutions to Bessel's
///   differential equation describing radial and wave behavior in cylindrical
///   geometries.
/// - **Elliptic Integrals** ([ellipticK], [ellipticE], [ellipticF],
///   [ellipticEIncomplete]): Complete and incomplete Legendre elliptic integrals
///   of the 1st and 2nd kinds.
/// - **Hypergeometric Functions** ([hypergeometric1F1], [hypergeometric2F1]):
///   Kummer's confluent series `1F1(a; b; z)` and Gauss's generalized series
///   `2F1(a, b; c; z)`.
/// - **Lambert W** ([lambertW0], [lambertW1]): The principal and secondary real
///   branches of the product log function solving `W(x) * exp(W(x)) = x`.
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
///   print('J_0(0.0) = ${besselJ0(0.0)}');
/// }
/// ```
library;

import 'src/special/bessel.dart';
import 'src/special/beta.dart';
import 'src/special/digamma.dart';
import 'src/special/elliptic.dart';
import 'src/special/erf.dart';
import 'src/special/exp_integral.dart';
import 'src/special/fresnel.dart';
import 'src/special/gamma.dart';
import 'src/special/hypergeometric.dart';
import 'src/special/lambert_w.dart';
import 'src/special/polylog.dart' show polylog;
import 'src/special/zeta.dart';

export 'src/special/bessel.dart';
export 'src/special/beta.dart';
export 'src/special/digamma.dart';
export 'src/special/elliptic.dart';
export 'src/special/erf.dart';
export 'src/special/exp_integral.dart';
export 'src/special/fresnel.dart';
export 'src/special/gamma.dart';
export 'src/special/hypergeometric.dart';
export 'src/special/lambert_w.dart';
export 'src/special/polylog.dart' show polylog;
export 'src/special/zeta.dart';
