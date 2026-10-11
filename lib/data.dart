/// Comprehensive scientific computing, data analysis, and mathematical modeling library for Dart.
///
/// Designed to provide both an intuitive, accessible interface
/// and mathematically rigorous, high-performance algorithms for scientific computing.
///
/// ## Subsystems
///
/// - **Tensors** (`tensor.dart`): Multi-dimensional arrays with
///   generalized stride layouts ([Layout]), broadcasting, contraction, and Einstein summation ([einsum]).
/// - **Linear Algebra** (`linear.dart`): Vectors ([Vector]), matrices ([Matrix]), iterative
///   solvers ([gmres], [conjugateGradient]), and matrix factorizations ([LUDecomposition], [QRDecomposition], [CholeskyDecomposition], [SingularValueDecomposition], [EigenvalueDecomposition]).
/// - **DataFrames** (`dataframe.dart`): Apache Arrow-aligned columnar
///   tabular data engine with zero-allocation slicing, relational hash joins, and grouping ([DataFrame], [Series], [GroupBy]).
/// - **Hardware Acceleration** (`hardware.dart`): Transparent routing to
///   native BLAS/LAPACK via FFI ([HardwareManager]) and 128-bit SIMD vector instructions ([SimdEngine]).
/// - **Symbolic Computation** (`symbolic.dart`): Exact algebraic expressions ([Expr]),
///   analytical differentiation, Taylor expansions, LaTeX formatting, and JIT compilation.
/// - **Numerical Analysis** (`numeric.dart`): Numerical root-finding
///   ([brentRoot], [newtonRaphson]), numerical integration ([adaptiveSimpson], [gaussKronrod]), ODE solvers ([rk4]),
///   and linear/polynomial regression ([leastSquares], [linearRegression]).
/// - **Polynomials** (`polynomial.dart`): Polynomial algebra ([Polynomial]), root isolation,
///   rational functions ([RationalFunction]), and orthogonal polynomials ([Polynomial.chebyshevT], [Polynomial.legendreP], [Polynomial.hermiteH], [Polynomial.laguerreL]).
/// - **Special Functions** (`special.dart`): Accurate implementations of $\Gamma(z)$ ([gamma]),
///   $\beta(a, b)$ ([beta]), Bessel $J_\nu, Y_\nu, I_\nu, K_\nu$ ([besselJ0], [besselY0]), error function $\operatorname{erf}(z)$ ([erf]),
///   and Lambert $W$ ([lambertW0]).
/// - **Statistics** (`stats.dart`): Parametric probability distributions ([NormalDistribution], [StudentDistribution]),
///   hypothesis testing ([tTestOneSample], [tTestTwoSample], [oneWayAnova], [chiSquaredTest]), and bootstrap resampling ([bootstrap]).
/// - **Type System** (`type.dart`): Algebraic fields ([Field]), data type descriptors ([DataType]),
///   equality models ([Equality]), and native memory buffers ([NativeBuffer]).
///
/// ## Quick Start
///
/// ```dart
/// import 'package:data/data.dart';
///
/// void main() {
///   // Solve linear system A x = b
///   final a = Matrix<double>.fromRows([
///     [2.0, 1.0],
///     [1.0, 3.0],
///   ]);
///   final b = Vector<double>.fromList([4.0, 7.0]);
///   final x = a.solve(b);
///   print(x);
///
///   // Columnar DataFrames
///   final df = DataFrame.fromColumns({
///     'name': ['Alice', 'Bob', 'Charlie'],
///     'score': [95.0, 82.5, 91.0],
///   });
///   print(df['score'].mean);
/// }
/// ```
library;

import 'dataframe.dart';
import 'hardware.dart';
import 'linear.dart';
import 'numeric.dart';
import 'polynomial.dart';
import 'special.dart';
import 'stats.dart';
import 'symbolic.dart';
import 'tensor.dart';
import 'type.dart';

export 'dataframe.dart';
export 'hardware.dart';
export 'linear.dart';
export 'numeric.dart';
export 'polynomial.dart';
export 'special.dart';
export 'stats.dart';
export 'symbolic.dart';
export 'tensor.dart';
export 'type.dart';
