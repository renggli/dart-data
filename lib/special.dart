/// High-precision mathematical special functions of mathematical physics and
/// applied analysis.
///
/// Implements transcendental special functions essential in probability theory,
/// quantum mechanics, fluid dynamics, electromagnetism, and engineering across
/// both real and complex domains.
///
/// ## Implemented Function Families
///
/// - **Gamma & Factorial Functions** ([gamma], [gammaComplex], [gammaLn],
///   [gammaLnComplex], [gammaP], [gammaQ], [gammaPInv], [gammaQInv],
///   [lowerGamma], [lowerGammaComplex], [upperGamma], [upperGammaComplex],
///   [factorial], [factorialComplex], [factorialLn], [binomial],
///   [binomialComplex], [binomialLn], [permutation], [permutationComplex],
///   [permutationLn]): The continuous extension of the factorial
///   `Γ(n) = (n - 1)!` and its regularized and unregularized incomplete forms,
///   evaluated via 15-term Lanczos approximation with 15-16 digits of precision.
/// - **Beta Functions** ([beta], [betaComplex], [betaLn], [betaLnComplex],
///   [betaI], [betaIInv]): Euler's integral of the first kind `B(a, b)`, and
///   the regularized incomplete beta function and its inverse.
/// - **Psi, Zeta & Polylogarithm Functions** ([digamma], [digammaComplex],
///   [polygamma], [polygammaComplex], [zeta], [zetaComplex], [hurwitzZeta],
///   [hurwitzZetaComplex], [polylog], [polylogComplex]): Logarithmic
///   derivatives of the gamma function `ψ^(m)(x)`, the Riemann and Hurwitz
///   zeta functions `ζ(s)` and `ζ(s, a)`, and the polylogarithm `Li_s(z)`.
/// - **Error & Fresnel Functions** ([erf], [erfComplex], [erfc],
///   [erfcComplex], [erfi], [erfiComplex], [erfInv], [erfcInv], [fresnelS],
///   [fresnelSComplex], [fresnelC], [fresnelCComplex]): Gaussian error
///   integrals and normalized Fresnel sine and cosine integrals.
/// - **Exponential, Trigonometric & Hyperbolic Integrals** ([expIntegral],
///   [expIntegralComplex], [expIntegralE], [expIntegralEComplex],
///   [logIntegral], [logIntegralComplex], [sinIntegral], [sinIntegralComplex],
///   [cosIntegral], [cosIntegralComplex], [sinhIntegral],
///   [sinhIntegralComplex], [coshIntegral], [coshIntegralComplex]): Classical
///   non-elementary integral functions.
/// - **Bessel Functions** ([besselJ], [besselJComplex], [besselY],
///   [besselYComplex], [besselI], [besselIComplex], [besselK],
///   [besselKComplex]): Solutions to Bessel's differential equation describing
///   radial and wave behavior in cylindrical geometries.
/// - **Elliptic Integrals** ([ellipticK], [ellipticKComplex], [ellipticE],
///   [ellipticEComplex], [ellipticF], [ellipticFComplex], [ellipticPi],
///   [ellipticPiComplex]): Complete and incomplete Legendre elliptic integrals
///   of the 1st, 2nd, and 3rd kinds.
/// - **Hypergeometric & Appell Functions** ([hypergeometric1F1],
///   [hypergeometric1F1Complex], [hypergeometric2F1],
///   [hypergeometric2F1Complex], [hypergeometricPFQ],
///   [hypergeometricPFQComplex], [appellF1], [appellF1Complex]):
///   Kummer's confluent series `1F1(a; b; z)`, Gauss's series `2F1(a, b; c; z)`,
///   the generalized series `pFq(a; b; z)`, and Appell's two-variable series
///   `F_1(a; b_1, b_2; c; x, y)`.
/// - **Lambert W** ([lambertW], [lambertWComplex]): The principal and secondary
///   branches of the product log function solving `W(z) * exp(W(z)) = z`.
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
export 'src/special/exp_integral.dart' hide expIntegralE1Complex;
export 'src/special/factorial.dart';
export 'src/special/fresnel.dart';
export 'src/special/gamma.dart' hide logAbsGammaWithSign;
export 'src/special/hypergeometric.dart';
export 'src/special/lambert_w.dart';
export 'src/special/permutation.dart';
export 'src/special/polylog.dart';
export 'src/special/trig_integral.dart';
export 'src/special/zeta.dart';
