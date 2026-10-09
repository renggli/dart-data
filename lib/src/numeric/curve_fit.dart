import 'dart:math' as math;

import '../../linear.dart';
import '../../polynomial.dart';
import '../../type.dart';

/// Curve fitting and regression algorithms using numerically stable QR and SVD
/// matrix decompositions.

/// Solves the general linear least squares problem $\min \|A x - b\|_2$.
///
/// Uses Householder QR decomposition for full-rank systems and Golub-Reinsch
/// SVD decomposition for rank-deficient or singular systems.
Vector<double> leastSquares(Matrix<num> a, Vector<num> b) {
  if (a.rowCount != b.length) {
    throw ArgumentError(
      'Matrix row count (${a.rowCount}) must match vector length (${b.length}).',
    );
  }
  if (a.rowCount >= a.colCount) {
    final qr = a.qr;
    if (qr.isFullRank) {
      return qr.solveVector(b);
    }
  }
  return a.svd.solveVector(b);
}

/// Simple univariate linear regression fitting $y = \text{slope} \cdot x + \text{intercept}$.
({
  double slope,
  double intercept,
  double rSquared,
  double Function(num x) predict,
})
linearRegression(Vector<num> xs, Vector<num> ys) {
  if (xs.length != ys.length) {
    throw ArgumentError('xs and ys must have the same length.');
  }
  final n = xs.length;
  if (n < 2) {
    throw ArgumentError(
      'At least 2 points are required for linear regression.',
    );
  }

  // Construct Vandermonde design matrix A of size [N x 2]: [1, x_i]
  final a = Matrix<double>.generate(
    n,
    2,
    (r, c) => c == 0 ? 1.0 : xs[r].toDouble(),
    type: DataType.float64,
  );
  final beta = leastSquares(a, ys);
  final intercept = beta[0];
  final slope = beta[1];

  // Calculate R^2 coefficient of determination
  var meanY = 0.0;
  for (var i = 0; i < n; i++) {
    meanY += ys[i].toDouble();
  }
  meanY /= n;

  var ssTot = 0.0;
  var ssRes = 0.0;
  for (var i = 0; i < n; i++) {
    final yi = ys[i].toDouble();
    final yPred = intercept + slope * xs[i].toDouble();
    final totDiff = yi - meanY;
    final resDiff = yi - yPred;
    ssTot += totDiff * totDiff;
    ssRes += resDiff * resDiff;
  }
  final rSquared = ssTot > 0.0 ? 1.0 - (ssRes / ssTot) : 1.0;

  return (
    slope: slope,
    intercept: intercept,
    rSquared: rSquared,
    predict: (num x) => intercept + slope * x.toDouble(),
  );
}

/// Fits a polynomial of given [degree] to data points [xs] and [ys] using
/// QR least squares on the Vandermonde matrix.
Polynomial<double> polynomialRegression(
  Vector<num> xs,
  Vector<num> ys, {
  required int degree,
}) {
  if (xs.length != ys.length) {
    throw ArgumentError('xs and ys must have the same length.');
  }
  final n = xs.length;
  if (n < degree + 1) {
    throw ArgumentError(
      'At least ${degree + 1} points are required to fit degree $degree polynomial, got $n.',
    );
  }

  // Construct Vandermonde matrix V of size [n x (degree + 1)] where V[i, j] = xs[i]^j
  final v = Matrix<double>.generate(
    n,
    degree + 1,
    (r, c) => math.pow(xs[r].toDouble(), c).toDouble(),
    type: DataType.float64,
  );

  final coeffs = leastSquares(v, ys);
  return Polynomial<double>.fromCoefficients(
    coeffs.toList(),
    type: DataType.float64,
  );
}

/// Multiple linear regression fitting $y = X \beta + \epsilon$.
({
  Vector<double> coefficients,
  double intercept,
  double rSquared,
  double Function(Vector<num> x) predict,
})
multipleLinearRegression(
  Matrix<num> x,
  Vector<num> y, {
  bool fitIntercept = true,
}) {
  if (x.rowCount != y.length) {
    throw ArgumentError('x rowCount must match y length.');
  }
  final n = x.rowCount;
  final p = x.colCount;

  final designMatrix = fitIntercept
      ? Matrix<double>.generate(
          n,
          p + 1,
          (r, c) => c == 0 ? 1.0 : x.get(r, c - 1).toDouble(),
          type: DataType.float64,
        )
      : Matrix<double>.generate(
          n,
          p,
          (r, c) => x.get(r, c).toDouble(),
          type: DataType.float64,
        );

  final beta = leastSquares(designMatrix, y);
  final intercept = fitIntercept ? beta[0] : 0.0;
  final coefs = fitIntercept ? beta.subVector(1, p + 1) : beta;

  var meanY = 0.0;
  for (var i = 0; i < n; i++) {
    meanY += y[i].toDouble();
  }
  meanY /= n;

  var ssTot = 0.0;
  var ssRes = 0.0;
  for (var i = 0; i < n; i++) {
    final yi = y[i].toDouble();
    var yPred = intercept;
    for (var j = 0; j < p; j++) {
      yPred += coefs[j] * x.get(i, j).toDouble();
    }
    final totDiff = yi - meanY;
    final resDiff = yi - yPred;
    ssTot += totDiff * totDiff;
    ssRes += resDiff * resDiff;
  }
  final rSquared = ssTot > 0.0 ? 1.0 - (ssRes / ssTot) : 1.0;

  return (
    coefficients: coefs,
    intercept: intercept,
    rSquared: rSquared,
    predict: (Vector<num> xVec) {
      if (xVec.length != p) {
        throw ArgumentError(
          'Input vector length must match number of features ($p).',
        );
      }
      var out = intercept;
      for (var j = 0; j < p; j++) {
        out += coefs[j] * xVec[j].toDouble();
      }
      return out;
    },
  );
}

/// Fits non-linear parameters using the Levenberg-Marquardt damped least-squares algorithm.
Vector<double> levenbergMarquardt({
  required Vector<double> Function(Vector<double> params) residualFunction,
  required Vector<double> initialParams,
  double damping = 1e-2,
  double dampingStepUp = 10.0,
  double dampingStepDown = 0.1,
  double tolerance = 1e-7,
  int maxIterations = 100,
}) {
  var p = initialParams.copy();
  var r = residualFunction(p);
  var currentCost = r.dot(r);
  var lambda = damping;

  for (var iter = 0; iter < maxIterations; iter++) {
    if (math.sqrt(currentCost) < tolerance) break;

    // Approximate Jacobian J_ij = dr_i / dp_j via finite differences
    final m = r.length;
    final n = p.length;
    const h = 1e-7;

    final j = Matrix<double>.generate(m, n, (row, col) {
      final pForward = p.copy();
      pForward[col] += h;
      final rForward = residualFunction(pForward);
      return (rForward[row] - r[row]) / h;
    }, type: DataType.float64);

    // Augmented normal equations: (J^T J + lambda * diag(J^T J)) delta = -J^T r
    final jT = j.transposed;
    final jTj = jT * j;
    final jTr = jT.apply(r);

    final a = Matrix<double>.generate(n, n, (row, col) {
      var val = jTj.get(row, col);
      if (row == col) {
        val += lambda * (val.abs() > 1e-6 ? val.abs() : 1.0);
      }
      return val;
    }, type: DataType.float64);

    final rhs = -jTr;
    final delta = leastSquares(a, rhs);

    if (delta.norm() < tolerance) break;

    final pCandidate = p + delta;
    final rCandidate = residualFunction(pCandidate);
    final candidateCost = rCandidate.dot(rCandidate);

    if (candidateCost < currentCost) {
      p = pCandidate;
      r = rCandidate;
      currentCost = candidateCost;
      lambda *= dampingStepDown;
    } else {
      lambda *= dampingStepUp;
    }
  }

  return p;
}
