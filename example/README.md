# Data Examples

This directory contains executable command-line examples and sample datasets illustrating the capabilities of [Data](https://github.com/renggli/dart-data). A complete tutorial and documentation are available in the [package description](https://pub.dev/packages/data) and [API documentation](https://pub.dev/documentation/data/latest/).

## Command-Line Examples

Run any example directly from the project root using `dart run`:

### Magic Square (`example/magic_square.dart`)

Generates magic squares of various sizes (odd, doubly-even, and singly-even) and computes their structural properties, condition numbers, matrix norms, eigenvalue spectra, and matrix decompositions (LU, QR, SVD).

```bash
dart run example/magic_square.dart
```

### Numerical Algorithms Demo (`example/numeric_demo.dart`)

Demonstrates modern numerical computing algorithms:

- **Fast Fourier Transform (FFT)**: 1D complex forward and inverse FFT on time-domain signals.
- **Numerical Integration**: Adaptive Simpson and Gauss-Kronrod quadrature on $[0, \pi]$.
- **Root Finding**: Brent-Dekker root finding for non-linear equations ($\cos(x) - x = 0$).
- **Non-Linear Optimization**: Quasi-Newton BFGS minimization on the 2D Rosenbrock banana function.
- **Adaptive ODE Integration**: Runge-Kutta Dormand-Prince 45 adaptive step-size integration of an undamped harmonic oscillator.
- **Non-Linear Curve Fitting**: Damped Gauss-Newton Levenberg-Marquardt parameter estimation (`fitNonlinear`).

```bash
dart run example/numeric_demo.dart
```

### Statistics & Analysis Demo (`example/stats_demo.dart`)

Demonstrates statistical analysis and probability workflows:

- **Descriptive Statistics & Covariance**: Sample mean, standard deviation, median, interquartile range (IQR), and Pearson/Spearman correlation coefficients.
- **Principal Component Analysis (PCA)**: Covariance-based dimensionality reduction, explained variance ratios, and 2D coordinate projections.
- **Hypothesis Testing**: Two-sample Welch t-test for unequal variances.
- **Parametric Distributions**: Normal, Student-t, and Fisher-Snedecor $F$ distributions with PDF, CDF, survival, and quantile evaluation.
- **Non-Parametric Resampling**: Bootstrap resampling with standard error estimation, percentile intervals, and bias-corrected accelerated (BCa) confidence intervals.

```bash
dart run example/stats_demo.dart
```

### Polynomial Algebra Demo (`example/polynomial_demo.dart`)

Demonstrates polynomial manipulation and approximation theory:

- **Polynomial Algebra**: Arithmetic operations, Horner polynomial evaluation, and degree analysis.
- **Polynomial Calculus**: Analytical differentiation and formal indefinite integration.
- **Root Finding**: Polynomial root isolation via companion matrix eigenvalues.
- **Orthogonal Polynomial Families**: Chebyshev $T_n(x)$, Legendre $P_n(x)$, and Hermite $H_n(x)$ polynomials.
- **Clenshaw Algorithm**: Fast Clenshaw summation for evaluating orthogonal series expansions.

```bash
dart run example/polynomial_demo.dart
```

## Sample Datasets (`example/data/`)

Standard datasets formatted as CSV files for exploring columnar DataFrames, relational operations, and statistical pipelines:

- `cars.csv`: Multi-attribute vehicle specifications, horsepower, weight, acceleration, and fuel economy.
- `cereal.csv`: Nutritional contents, calories, vitamins, sugars, and consumer ratings for breakfast cereals.
- `countries.csv`: Global demographic, economic, and geographic indicators across countries.
- `iris.csv`: Morphological measurements (sepal and petal length/width) across Iris flower species.
- `tips.csv`: Food server tips, total bills, party sizes, and dining metadata.

## Interactive Web Applications

Interactive web applications located in `web/` can be launched with `build_runner`:

```bash
dart run build_runner serve web
```

- **[Catalog & Showcase](web/index.html)**: Interactive documentation portal, feature overview, and package highlights.
- **[Symbolic Calculator](web/calculator/)**: Progressive Web App (PWA) supporting Notebook and RPN calculation modes, live MathML rendering, 2D function plotting, and multivariate system solving.
- **[Symbolic Expressions Explorer](web/expressions/)**: Interactive algebra, calculus, Taylor series, limits, and equation solving playground.
- **[Distributions Dashboard](web/distributions/)**: Probability density, cumulative distribution, quantile visualizations, and real-time sampling histograms for 25+ distributions.
