/// Numerical analysis library for integration, differentiation, root-finding, optimization, ODEs, and signal processing.
///
/// Provides robust, efficient algorithms for problems in calculus, engineering,
/// and scientific computation where closed-form analytical solutions are unavailable.
///
/// ## Key Capabilities
///
/// - **Numerical Calculus**: [numericalDerivative] for univariate differentiation,
///   and [numericalGradient], [numericalHessian], and [numericalJacobian] for multivariate calculus.
/// - **Root Finding**: [brentRoot] (Brent-Dekker method with guaranteed convergence),
///   [newtonRaphson] (Newton-Raphson method), and [bisection] for solving $f(x) = 0$.
/// - **Numerical Integration**: [gaussKronrod] (15-point Gauss-Kronrod quadrature)
///   and [adaptiveSimpson] (adaptive Simpson's quadrature) for computing $\int_a^b f(x) dx$.
/// - **Numerical Optimization**: [brentMinimize] for 1D scalar minimization, [nelderMead] simplex,
///   and [bfgs] quasi-Newton method for unconstrained multivariate optimization.
/// - **Curve Fitting & Regression**: [leastSquares], [linearRegression], and [polynomialRegression]
///   using numerically stable QR and SVD factorizations.
/// - **Differential Equations**: [rk4] (classical 4th-order Runge-Kutta) and [rk45] (adaptive step-size) for solving $y' = f(t, y)$.
/// - **Interpolation**: 1D linear ([LinearInterpolation]), cubic spline ([CubicSpline]),
///   monotonic cubic ([PchipInterpolation]), and 2D bilinear ([BilinearInterpolation]) / bicubic ([BicubicInterpolation]).
/// - **Fast Fourier Transform**: [fft] and [ifft] for 1D complex frequency-domain signal processing.
///
/// ## Example
///
/// ```dart
/// import 'dart:math';
/// import 'package:data/numeric.dart';
///
/// void main() {
///   // Approximate the integral of sin(x) from 0 to pi (exact value: 2.0)
///   final result = gaussKronrod((double x) => sin(x), 0.0, pi);
///   print('Integral of sin(x) on [0, pi]: $result');
///
///   // Find the root of cos(x) - x = 0 near x = 0.5
///   final root = brentRoot((double x) => cos(x) - x, 0.0, 1.0);
///   print('Root: $root');
/// }
/// ```
library;

import 'src/numeric/calculus.dart';
import 'src/numeric/curve_fit.dart';
import 'src/numeric/fft.dart';
import 'src/numeric/integration.dart';
import 'src/numeric/interpolation.dart';
import 'src/numeric/interpolation_2d.dart';
import 'src/numeric/ode.dart';
import 'src/numeric/optimization.dart';
import 'src/numeric/root_finding.dart';

export 'src/numeric/calculus.dart';
export 'src/numeric/curve_fit.dart';
export 'src/numeric/fft.dart';
export 'src/numeric/integration.dart';
export 'src/numeric/interpolation.dart';
export 'src/numeric/interpolation_2d.dart';
export 'src/numeric/ode.dart';
export 'src/numeric/optimization.dart';
export 'src/numeric/root_finding.dart';
