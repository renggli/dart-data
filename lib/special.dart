/// High-precision mathematical special functions of mathematical physics and
/// applied analysis.
///
/// Implements transcendent special functions essential in probability theory,
/// quantum mechanics, fluid dynamics, electromagnetism, and engineering.
///
/// ## Implemented Function Families
///
/// - **Gamma & Factorial Functions** ([gamma], [gammaLn], [gammap],
///   [gammaq], [gammapInv], [lowRegGamma]): The continuous extension of the factorial
///   $\Gamma(n) = (n - 1)!$, implemented via Lanczos approximation with 15
///   digits of numerical precision.
/// - **Beta Functions** ([beta], [betaLn], [ibeta], [ibetaInv]): Euler's
///   integral of the first kind $B(a, b)$, and the regularized incomplete beta
///   function.
/// - **Psi / Digamma** ([digamma], [trigamma]): Logarithmic derivatives of the
///   gamma function $\psi(x) = \frac{d}{dx} \ln \Gamma(x)$.
/// - **Error Functions** ([erf], [erfc], [erfInv], [erfcInv]): Gaussian error
///   integrals fundamental to normal distributions and diffusion processes.
/// - **Bessel Functions** ([besselJ0], [besselJ1], [besselY0], [besselY1],
///   [besselI0], [besselI1], [besselK0], [besselK1]): Solutions to Bessel's
///   differential equation describing radial and wave behavior in cylindrical
///   geometries.
/// - **Elliptic Integrals** ([ellipticK], [ellipticE]): Complete Legendre
///   elliptic integrals of the 1st and 2nd kinds computed via
///   arithmetic-geometric mean.
/// - **Hypergeometric Functions** ([hypergeometric2F1]): Gauss's generalized
///   series $_2F_1(a, b; c; z)$.
/// - **Lambert W** ([lambertW0], [lambertW1]): The principal and secondary real
///   branches of the product log function solving $W(x) e^{W(x)} = x$.
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
import 'src/special/gamma.dart';
import 'src/special/hypergeometric.dart';
import 'src/special/lambert_w.dart';

export 'src/special/bessel.dart';
export 'src/special/beta.dart';
export 'src/special/digamma.dart';
export 'src/special/elliptic.dart';
export 'src/special/erf.dart';
export 'src/special/gamma.dart';
export 'src/special/hypergeometric.dart';
export 'src/special/lambert_w.dart';
