/// Numerical integration method for ordinary differential equations.
enum OdeMethod {
  /// Classical 4th-order Runge-Kutta with fixed step size.
  rk4,

  /// Adaptive 5(4) Dormand-Prince Runge-Kutta with dynamic step-size control.
  dormandPrince45,
}
