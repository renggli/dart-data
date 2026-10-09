# Subsystem Architecture: Numeric Analysis & Scientific Computing

## 1. Overview & Current Deficiencies

The `numeric` subsystem ([lib/src/numeric/](../lib/src/numeric/)) provides fundamental numerical routines including univariate root-finding, numerical integration, univariate derivatives, curve fitting, and fast Fourier transforms (FFT).

However, an audit of the current implementation reveals critical gaps, numerical instability bugs, and missing scientific capabilities that limit its utility for engineering, simulation, and machine learning.

### 1.1 Identified Bugs & Critical Limitations

1. **In-Place Mutation and Fixed-Length Failure in `fft.dart`**:
   - In [`lib/src/numeric/fft.dart:28-48`](../lib/src/numeric/fft.dart#L28-L48):

     ```dart
     var result = values;
     final n = values.length.bitCeil;
     ...
     if (i < j) {
       result.swap(i, j); // Mutates caller's input list in place!
     }
     ```

     When `values.length` is already a power of two, `result` directly aliases `values`. The bit-reversal permutation mutates the caller's input list in place without warning. If the caller passes an unmodifiable list (e.g. `UnmodifiableListView` or const list), it throws an `UnsupportedError`. Furthermore, the library lacks Real-to-Complex FFT (RFFT) and 2D FFT (`fft2`).

2. **Ill-Conditioned Polynomial Fitting & Lack of Regularization**:
   - While [`PolynomialRegression.fit`](../lib/src/numeric/curve_fit/polynomial_regression.dart#L43) uses QR factorization (`vandermonde.qr.solve(yMatrix)`), Vandermonde matrices have notoriously large condition numbers growing exponentially with degree ($\kappa(V) \sim \mathcal{O}(e^{c \cdot n})$).
   - The current implementation lacks Tikhonov (L2/Ridge) regularization and truncated SVD solving, causing extreme numerical oscillations (Runge's phenomenon) for degrees $\ge 6$ with noisy data.
   - **Remedy**: Add regularized least-squares and orthogonal basis fitting (Chebyshev/Legendre regression).

3. **Absence of Numerical Optimization**:
   - The package contains univariate root-finding (Brent's method in `solve.dart`), but **zero function minimization / optimization algorithms**:
     - No 1D scalar minimization (Golden-section search, Brent's minimization).
     - No multi-dimensional unconstrained optimization (Nelder-Mead Simplex, BFGS, L-BFGS, Conjugate Gradient).
     - No constrained optimization (box bounds, penalties).

4. **Absence of Ordinary Differential Equation (ODE) Solvers**:
   - Simulating dynamical systems, physics, and kinetics requires solving initial value problems:
     $$\frac{dy}{dt} = f(t, y), \quad y(t_0) = y_0$$
   - The package lacks standard Runge-Kutta solvers (RK4, adaptive Dormand-Prince RK45).

5. **Univariate-Only Numerical Calculus**:
   - [`derivative.dart`](../lib/src/numeric/derivative.dart) only supports univariate functions $f: \mathbb{R} \to \mathbb{R}$.
   - Missing multivariate calculus:
     - Gradient vector $\nabla f(x)$ for scalar fields $f: \mathbb{R}^n \to \mathbb{R}$.
     - Jacobian matrix $J_f(x)$ for vector-valued functions $f: \mathbb{R}^n \to \mathbb{R}^m$.
     - Hessian matrix $H_f(x)$ for second-order curvature and optimization.

6. **Interpolation Limitations**:
   - Existing interpolation ([lib/src/numeric/interpolate/](../lib/src/numeric/interpolate/)) includes only `linear`, `lagrange`, `nearest`, `next`, and `previous`.
   - Lagrange interpolation exhibits Runge's phenomenon (massive oscillations at interval edges).
   - Missing: Natural and Clamped **Cubic Splines** and **PCHIP** (Piecewise Cubic Hermite Interpolating Polynomial) for monotonicity-preserving interpolation.

---

## 2. Target Design & Architecture

```
+-------------------------------------------------------------------------+
|                           Numeric Subsystem                             |
+-------------------------------------------------------------------------+
    |                 |                 |                  |
+-------------+ +-------------+ +---------------+ +------------------+
| Optimization| | ODE Solvers | | Multivar Calc | | Advanced Interp  |
| - Brent 1D  | | - RK4       | | - Gradient    | | - Cubic Spline   |
| - NelderMead| | - RK45 DP   | | - Jacobian    | | - PCHIP          |
| - BFGS / L  | | (Adaptive)  | | - Hessian     | | - 2D Bilinear    |
+-------------+ +-------------+ +---------------+ +------------------+
```

### 2.1 Optimization Engine

Provide both 1D and multi-dimensional optimization solvers:

```dart
abstract class Optimizer {
  OptimizationResult minimize(
    double Function(Vector<double>) objective,
    Vector<double> initialGuess, {
    Vector<double>? lowerBounds,
    Vector<double>? upperBounds,
    double tolerance = 1e-6,
    int maxIterations = 1000,
  });
}

class NelderMeadOptimizer implements Optimizer { ... }
class BfgsOptimizer implements Optimizer { ... }
```

### 2.2 Adaptive ODE Integration

Implement Dormand-Prince (RK45) with automatic step size control based on local truncation error estimates:

```dart
class OdeSolution {
  final List<double> t;
  final List<Vector<double>> y;
  Vector<double> interpolate(double time);
}

OdeSolution solveOde(
  Vector<double> Function(double t, Vector<double> y) derivative,
  (double, double) tSpan,
  Vector<double> y0, {
  double rtol = 1e-5,
  double atol = 1e-8,
  OdeMethod method = OdeMethod.rk45,
});
```

### 2.3 Multivariate Calculus

Implement finite-difference and complex-step differentiation:

```dart
Vector<double> gradient(
  double Function(Vector<double>) f,
  Vector<double> x, {
  double stepSize = 1e-7,
});

Matrix<double> jacobian(
  Vector<double> Function(Vector<double>) f,
  Vector<double> x, {
  double stepSize = 1e-7,
});

Matrix<double> hessian(
  double Function(Vector<double>) f,
  Vector<double> x, {
  double stepSize = 1e-5,
});
```

### 2.4 Numerically Stable Polynomial Regression

Refactor `PolynomialRegression.fit` using QR decomposition:

```dart
// Vandermonde matrix V of shape (N, degree + 1)
final qr = vandermonde.qr;
final coefficients = qr.solve(ys); // Numerically stable, no condition squaring
```

### 2.5 Cubic Spline & PCHIP Interpolation

Provide continuous second-derivative natural/clamped splines and shape-preserving PCHIP:

```dart
abstract class Spline {
  double evaluate(double x);
  double derivative(double x);
  double integrate(double a, double b);
}

Spline cubicSpline(List<double> xs, List<double> ys, {SplineBoundary boundary = SplineBoundary.natural});
Spline pchip(List<double> xs, List<double> ys);
```

---

## 3. Prioritized Implementation Task List

| Task ID | Phase | Priority | Description | Verification / Success Criteria |
| :--- | :--- | :--- | :--- | :--- |
| **NUM-01** | Correctness | **P0** | Ensure `fft.dart` always operates on a copy (`List.of(values)`) to avoid mutating input lists and to support unmodifiable lists. | Unit test verifying passing `UnmodifiableListView` or const list does not throw or mutate. |
| **NUM-02** | Stability | **P1** | Add Tikhonov (Ridge) regularization and SVD least-squares option to `PolynomialRegression.fit`. | High-degree ($n=8$) polynomial fit on noisy data remains numerically stable. |
| **NUM-03** | Splines | **P1** | Implement Natural and Clamped Cubic Spline interpolation with $C^2$ continuity. | Test interpolation on Runge function; error matches cubic spline bounds. |
| **NUM-04** | Interpolation | **P1** | Implement PCHIP (Piecewise Cubic Hermite) monotonic interpolation. | Monotonic input points produce strictly monotonic interpolated curves. |
| **NUM-05** | Calculus | **P1** | Implement multivariate numerical calculus: `gradient`, `jacobian`, and `hessian`. | Verify against known analytical derivatives of Rosenbrock function within $10^{-6}$. |
| **NUM-06** | 1D Minimize | **P1** | Implement 1D scalar minimization (Golden-Section Search and Brent's method). | Find minimum of multimodal functions within $10^{-8}$ tolerance. |
| **NUM-07** | Multivar Opt | **P2** | Implement Nelder-Mead Simplex and BFGS / L-BFGS multi-dimensional optimizers. | Successfully minimize 2D and 10D Rosenbrock function from non-trivial initial points. |
| **NUM-08** | ODE Solvers | **P2** | Implement classical RK4 and adaptive Dormand-Prince (RK45) ODE solvers with interpolation. | Simulate harmonic oscillator and Lorenz attractor with bounded energy drift. |
| **NUM-09** | 2D FFT | **P3** | Implement 2D Fast Fourier Transform (`fft2` and `ifft2`) for image processing and spatial data. | Round-trip identity $\|x - \text{ifft2}(\text{fft2}(x))\| < 10^{-12}$. |
