import '../../../linear.dart';

/// Solves a system of equations $F(\mathbf{x}) = \mathbf{0}$ using multivariate
/// Newton-Raphson iteration.
///
/// Conceptually, this finds coordinates where multiple equations simultaneously
/// equal zero. Formally, starting from [initialGuess] $\mathbf{x}_0$, it
/// iteratively updates:
/// $$\mathbf{x}_{k+1} = \mathbf{x}_k - J_F(\mathbf{x}_k)^{-1} F(\mathbf{x}_k)$$
/// where $J_F(\mathbf{x}_k)$ is the Jacobian matrix computed either via
/// [jacobian] or central finite differences.
///
/// ```dart
/// final sol = solveSystem([
///   (v) => v[0] + v[1] - 10,
///   (v) => v[0] - v[1] - 2,
/// ], Vector.fromList([0.0, 0.0]));
/// // sol: [6.0, 4.0]
/// ```
Vector<double> solveSystem(
  List<double Function(Vector<double>)> equations,
  Vector<double> initialGuess, {
  Matrix<double> Function(Vector<double>)? jacobian,
  double tolerance = 1e-10,
  int maxIterations = 100,
  double step = 1e-5,
}) {
  final n = initialGuess.length;
  if (equations.length != n) {
    throw ArgumentError(
      'Number of equations (${equations.length}) must match dimension of initialGuess ($n).',
    );
  }
  if (tolerance <= 0) {
    throw ArgumentError.value(
      tolerance,
      'tolerance',
      'Tolerance must be positive.',
    );
  }
  if (maxIterations <= 0) {
    throw ArgumentError.value(
      maxIterations,
      'maxIterations',
      'Max iterations must be positive.',
    );
  }
  final x = initialGuess.copy();
  for (var iter = 0; iter < maxIterations; iter++) {
    final residual = Vector<double>.generate(n, (i) => equations[i](x));
    var maxRes = 0.0;
    for (var i = 0; i < n; i++) {
      final val = residual[i];
      if (val.isNaN) throw StateError('Function evaluation returned NaN');
      final r = val.abs();
      if (r > maxRes) maxRes = r;
    }
    if (maxRes <= tolerance) {
      return x;
    }

    final jac = jacobian != null
        ? jacobian(x)
        : Matrix<double>.generate(n, n, (row, col) {
            final xPlus = x.copy();
            final xMinus = x.copy();
            xPlus[col] += step;
            xMinus[col] -= step;
            return (equations[row](xPlus) - equations[row](xMinus)) /
                (2.0 * step);
          });

    Vector<double> delta;
    try {
      delta = jac.solve(residual);
    } on Object catch (e) {
      throw StateError(
        'Failed to converge: Jacobian is singular or step failed ($e).',
      );
    }
    for (var i = 0; i < n; i++) {
      x[i] -= delta[i];
    }
  }
  final finalResidual = Vector<double>.generate(n, (i) => equations[i](x));
  var maxRes = 0.0;
  for (var i = 0; i < n; i++) {
    final val = finalResidual[i];
    if (val.isNaN) throw StateError('Function evaluation returned NaN');
    final r = val.abs();
    if (r > maxRes) maxRes = r;
  }
  if (maxRes <= tolerance) {
    return x;
  }
  throw StateError(
    'solveSystem failed to converge within $maxIterations iterations.',
  );
}
