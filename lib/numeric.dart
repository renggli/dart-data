/// Numerical analysis library for integration, differentiation, root-finding,
/// optimization, ODEs, and signal processing.
///
/// Provides robust, efficient algorithms for problems in calculus, engineering,
/// and scientific computation where closed-form analytical solutions are
/// unavailable.
///
/// ## Key Capabilities
///
/// - **Numerical Calculus**: [derivative] for univariate differentiation, and
///   [gradient], [hessian], and [jacobian] for multivariate calculus.
/// - **Root Finding**: [solve] with [RootMethod] ([RootMethod.brent],
///   [RootMethod.newtonRaphson], [RootMethod.bisection]), and [solveSystem] for
///   multivariable systems.
/// - **Numerical Integration**: [integrate] with [IntegrationMethod]
///   ([IntegrationMethod.gaussKronrod], [IntegrationMethod.simpson]).
/// - **Numerical Optimization**: [minimize] with [OptimizationMethod]
///   ([OptimizationMethod.nelderMead], [OptimizationMethod.bfgs],
///   [OptimizationMethod.lbfgs], [OptimizationMethod.brent]) and [BoxBound]
///   constraints.
/// - **Curve Fitting & Regression**: [curveFit] and [CurveModels] for
///   non-linear models, [leastSquares], [linearRegression],
///   [polynomialRegression], and [fitNonlinear].
/// - **Sampling Grids & Adaptive Curve Sampling**: [linearSpaced],
///   [logarithmicSpaced], [geometricSpaced], and [sampleCurve] for generating
///   coordinate grids and discontinuity-aware adaptive curve samples.
/// - **Differential Equations**: [solveOde] with [OdeMethod]
///   ([OdeMethod.dormandPrince45], [OdeMethod.rk4]).
/// - **Interpolation**: 1D linear ([LinearInterpolation]), cubic spline
///   ([CubicSpline]), monotonic cubic ([PchipInterpolation]), and 2D bilinear
///   ([BilinearInterpolation]) / bicubic ([BicubicInterpolation]).
/// - **Fast Fourier Transform**: [fft] and [ifft] for 1D complex
///   frequency-domain signal processing.
///
/// ## Example
///
/// ```dart
/// import 'dart:math';
/// import 'package:data/numeric.dart';
///
/// void main() {
///   // Approximate the integral of sin(x) from 0 to pi (exact value: 2.0)
///   final result = integrate((double x) => sin(x), 0.0, pi);
///   print('Integral of sin(x) on [0, pi]: $result');
///
///   // Find the root of cos(x) - x = 0 near x = 0.5
///   final root = solve((double x) => cos(x) - x, 0.0, b: 1.0);
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
import 'src/numeric/sampling.dart';

export 'src/numeric/calculus.dart';
export 'src/numeric/curve_fit.dart';
export 'src/numeric/fft.dart';
export 'src/numeric/integration.dart';
export 'src/numeric/interpolation.dart';
export 'src/numeric/interpolation_2d.dart';
export 'src/numeric/ode.dart';
export 'src/numeric/optimization.dart';
export 'src/numeric/root_finding.dart';
export 'src/numeric/sampling.dart';
