# Dart Data

[![Pub Package](https://img.shields.io/pub/v/data.svg)](https://pub.dev/packages/data)
[![Build Status](https://github.com/renggli/dart-data/actions/workflows/dart.yml/badge.svg?branch=main)](https://github.com/renggli/dart-data/actions/workflows/dart.yml)
[![Code Coverage](https://codecov.io/gh/renggli/dart-data/branch/main/graph/badge.svg?token=G8EBSJSR17)](https://codecov.io/gh/renggli/dart-data)
[![GitHub Issues](https://img.shields.io/github/issues/renggli/dart-data.svg)](https://github.com/renggli/dart-data/issues)
[![GitHub Forks](https://img.shields.io/github/forks/renggli/dart-data.svg)](https://github.com/renggli/dart-data/network)
[![GitHub Stars](https://img.shields.io/github/stars/renggli/dart-data.svg)](https://github.com/renggli/dart-data/stargazers)
[![GitHub License](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/renggli/dart-data/main/LICENSE)

**Dart Data** is a modern, high-performance scientific computing, linear algebra, and data science toolkit for Dart and Flutter. Engineered for speed and memory efficiency, it features N-dimensional tensors with NumPy-style striding, dynamic BLAS/LAPACK hardware acceleration, Arrow-aligned columnar DataFrames, exact symbolic calculus, full matrix decompositions, and comprehensive probability distributions.

## Key Features

- **Tensors & Multi-dimensional Arrays**: Zero-copy strided layouts, multidimensional slicing, broadcasting, einsum, contraction, and tensor transformations.
- **Hardware Acceleration**: Dynamic native FFI discovery for BLAS (GEMM, GEMV, SYRK) and LAPACK (GESV, GELSF, POTRF), with transparent Dart SIMD (`Float32x4`) and pure Dart fallbacks.
- **Linear Algebra**: Vectors and Matrices, full matrix decompositions (Cholesky, LU, QR, SVD, Eigenvalue), matrix norms and condition numbers, plus iterative Krylov subspace solvers (GMRES, BiCGSTAB, Conjugate Gradient).
- **Columnar DataFrames**: Arrow-aligned columnar tables with zero-copy chunking, schema inference, streaming CSV parser, relational joins, grouping, aggregations, and expressive filtering.
- **Exact Symbolic Mathematics**: Symbolic expression ASTs, automatic analytical differentiation, algebraic simplification, LaTeX generation, and fast JIT compilation to Dart closures.
- **Probability & Statistics**: 25+ continuous and discrete probability distributions with exact PDF/CDF/quantile calculations, random sampling, descriptive statistics, Pearson/Spearman correlation, and kernel density estimation.
- **Numeric Algorithms & Special Functions**: ODE solvers (Runge-Kutta, Dormand-Prince), optimization (Nelder-Mead, BFGS), numerical integration, 1D/2D interpolation, curve fitting (Levenberg-Marquardt, Polynomial, Multiple Linear Regression), FFT, and special functions ($\Gamma$, $\mathrm{B}$, Bessel $J_\nu / Y_\nu$, complete elliptic integrals $K / E$, and hypergeometric functions $_1F_1, {}_2F_1$).

## Tutorial & Examples

### 1. Multi-Dimensional Tensors

Work with multi-dimensional arrays, zero-copy views, broadcasting, and matrix multiplication:

```dart
// Create a 2x3 tensor from nested collections
final a = Tensor<double>.fromObject([
  [1.0, 2.0, 3.0],
  [4.0, 5.0, 6.0],
]);

// Transpose (swaps strides without copying data)
final aT = a.transpose(); // shape [3, 2]

// Matrix multiplication: [2, 3] x [3, 2] -> [2, 2]
final product = a.matmul(aT);
print(product.toNestedList());
// [[14.0, 32.0], [32.0, 77.0]]

// Slicing and broadcasting
final slice = a.slice([Range.to(1), Range.all()]); // row 0
print(slice.shape); // [1, 3]
```

### 2. Linear Algebra & Decompositions

Solve linear systems and factorize matrices with numerical stability:

```dart
final matrix = Matrix<double>.fromRows([
  [4.0, 2.0],
  [2.0, 5.0],
]);
final b = Vector<double>.fromList([10.0, 11.0]);

// Solve Ax = b
final x = matrix.solve(b);
print(x); // Vector([2.0, 1.0])

// Cholesky decomposition (for symmetric positive-definite matrices)
final cholesky = matrix.cholesky;
print(cholesky.l); // Lower triangular factor L

// LU, QR, and SVD factorizations
final lu = matrix.lu;
final qr = matrix.qr;
final svd = matrix.svd;
print('Determinant: ${matrix.determinant}');
print('Condition number: ${matrix.cond()}');
```

### 3. Columnar DataFrames

Process, transform, and aggregate structured data:

```dart
// Parse CSV into columnar memory
final df = DataFrame.fromCsv('''
name,age,salary,department
Alice,30,75000.0,Engineering
Bob,24,52000.0,Design
Charlie,38,98000.0,Engineering
Diana,29,61000.0,Design
''');

// Filtering and querying
final engineers = df.filterBy((row) => row['department'] == 'Engineering');

// Column operations & aggregations
final salaries = df('salary') as Series<double>;
print('Average salary: ${salaries.mean()}');
print('Max salary: ${salaries.max()}');
```

### 4. Symbolic Calculus & Compilation

Differentiate and simplify mathematical expressions symbolically, or compile them directly into high-speed evaluation functions:

```dart
final x = Variable('x');
// Build f(x) = x^3 + sin(x)
final f = x.pow(3) + Sin(x);

// Analytical derivative: f'(x) = 3 * x^2 + cos(x)
final df = f.diff('x').simplify();
print(df.toLatex()); // 3 * x^{2} + \cos(x)

// JIT-compile into a fast Dart closure
final fastDf = df.compile1D('x');
print(fastDf(0.0)); // 1.0 (since 3*(0)^2 + cos(0) = 1)
```

### 5. Probability Distributions

Over 25 discrete and continuous probability distributions with statistics, probability density, cumulative probability, and quantiles:

```dart
// Standard Normal distribution N(0, 1)
final normal = NormalDistribution(0.0, 1.0);
print('PDF at 0: ${normal.pdf(0.0)}'); // ~0.3989
print('CDF at 1.96: ${normal.cdf(1.96)}'); // ~0.975
print('95% quantile: ${normal.quantile(0.95)}'); // ~1.6448

// Poisson distribution
final poisson = PoissonDistribution(4.0);
print('P(X = 3): ${poisson.pmf(3)}');
print('Samples: ${poisson.samples().take(5).toList()}');
```

### 6. Curve Fitting & Numeric Solvers

Fit non-linear curves using Levenberg-Marquardt or solve ordinary differential equations:

```dart
// Non-linear Levenberg-Marquardt fit: y = a * exp(b * x)
final xs = [0.0, 1.0, 2.0, 3.0];
final ys = [2.5, 4.12, 6.80, 11.20];

final initialGuess = Vector<double>.fromList([1.0, 1.0]);
final fittedParams = levenbergMarquardt(
  residualFunction: (p) => Vector<double>.fromList(
    List.generate(xs.length, (i) => p[0] * exp(p[1] * xs[i]) - ys[i]),
  ),
  initialParams: initialGuess,
);
print('Fitted a: ${fittedParams[0]}, b: ${fittedParams[1]}');

// Numerical ODE integration: dy/dt = -2 * y
final solution = odeRk4(
  f: (t, y) => -2.0 * y,
  t0: 0.0,
  y0: 1.0,
  t1: 2.0,
  steps: 100,
);
print('y(2.0) = ${solution.last}');
```

## Interactive Web Demo

Experience the interactive probability distributions playground directly in your browser:

```bash
dart run build_runner serve web
```

Then navigate to `http://localhost:8080/distributions/` to explore PDF/CDF curves, parameter adjustments, and real-time sampling histograms.

## License

The MIT License, see [LICENSE](https://raw.githubusercontent.com/renggli/dart-data/main/LICENSE).
