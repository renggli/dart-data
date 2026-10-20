/// Method used for numerical root-finding.
enum RootMethod {
  /// Brent-Dekker hybrid method combining inverse quadratic interpolation,
  /// secant steps, and bisection safeguards. Requires bracketed interval
  /// `[a, b]`.
  brent,

  /// Newton-Raphson method with quadratic convergence using analytical or
  /// finite-difference derivative. Starts from initial point `a`.
  newtonRaphson,

  /// Bisection method guaranteeing linear convergence. Requires bracketed
  /// interval `[a, b]`.
  bisection,
}
