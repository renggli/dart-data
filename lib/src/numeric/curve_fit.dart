import 'dart:math' as math;
import 'dart:typed_data';

import '../../hardware.dart';
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
  final rows = a.rowCount;
  final cols = a.colCount;
  if (rows >= cols && HardwareManager.isAccelerated) {
    final Float64List aData;
    if (a.type == DataType.float64 &&
        a.tensor.isContiguous &&
        a.tensor.data is Float64List) {
      aData = DataType.float64.newList(rows * cols);
      aData.setRange(
        0,
        rows * cols,
        a.tensor.data as Float64List,
        a.tensor.offset,
      );
    } else {
      aData = DataType.float64.newList(rows * cols);
      final aFlat = a.values.toList(growable: false);
      for (var i = 0; i < aFlat.length; i++) {
        aData[i] = aFlat[i].toDouble();
      }
    }
    final Float64List bData;
    if (b.type == DataType.float64 &&
        b.tensor.isContiguous &&
        b.tensor.data is Float64List) {
      bData = DataType.float64.newList(rows);
      bData.setRange(0, rows, b.tensor.data as Float64List, b.tensor.offset);
    } else {
      bData = DataType.float64.newList(rows);
      for (var i = 0; i < rows; i++) {
        bData[i] = b[i].toDouble();
      }
    }
    final success = HardwareManager.dgels(
      m: rows,
      n: cols,
      nrhs: 1,
      a: aData,
      lda: cols,
      b: bData,
      ldb: rows,
    );
    if (success) {
      return Vector<double>.fromList(
        bData.sublist(0, cols),
        type: DataType.float64,
      );
    }
  }
  if (rows >= cols) {
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
  final numPoints = xs.length;
  if (numPoints < 2) {
    throw ArgumentError(
      'At least 2 points are required for linear regression.',
    );
  }

  // Construct Vandermonde design matrix A of size [N x 2]: [1, x_i]
  final a = Matrix<double>.generate(
    numPoints,
    2,
    (row, col) => col == 0 ? 1.0 : xs[row].toDouble(),
    type: DataType.float64,
  );
  final beta = leastSquares(a, ys);
  final intercept = beta[0];
  final slope = beta[1];

  // Calculate R^2 coefficient of determination
  var meanY = 0.0;
  for (var i = 0; i < numPoints; i++) {
    meanY += ys[i].toDouble();
  }
  meanY /= numPoints;

  var ssTot = 0.0;
  var ssRes = 0.0;
  for (var i = 0; i < numPoints; i++) {
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
  final numPoints = xs.length;
  if (numPoints < degree + 1) {
    throw ArgumentError(
      'At least ${degree + 1} points are required to fit degree $degree polynomial, got $numPoints.',
    );
  }

  // Construct Vandermonde matrix V of size [n x (degree + 1)] where V[i, j] = xs[i]^j
  final vandermonde = Matrix<double>.generate(
    numPoints,
    degree + 1,
    (row, col) => math.pow(xs[row].toDouble(), col).toDouble(),
    type: DataType.float64,
  );

  final coeffs = leastSquares(vandermonde, ys);
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
  final numSamples = x.rowCount;
  final numFeatures = x.colCount;

  final designMatrix = fitIntercept
      ? Matrix<double>.generate(
          numSamples,
          numFeatures + 1,
          (row, col) => col == 0 ? 1.0 : x.get(row, col - 1).toDouble(),
          type: DataType.float64,
        )
      : Matrix<double>.generate(
          numSamples,
          numFeatures,
          (row, col) => x.get(row, col).toDouble(),
          type: DataType.float64,
        );

  final beta = leastSquares(designMatrix, y);
  final intercept = fitIntercept ? beta[0] : 0.0;
  final coefs = fitIntercept ? beta.subVector(1, numFeatures + 1) : beta;

  var meanY = 0.0;
  for (var i = 0; i < numSamples; i++) {
    meanY += y[i].toDouble();
  }
  meanY /= numSamples;

  var ssTot = 0.0;
  var ssRes = 0.0;
  for (var i = 0; i < numSamples; i++) {
    final yi = y[i].toDouble();
    var yPred = intercept;
    for (var j = 0; j < numFeatures; j++) {
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
      if (xVec.length != numFeatures) {
        throw ArgumentError(
          'Input vector length must match number of features ($numFeatures).',
        );
      }
      var out = intercept;
      for (var j = 0; j < numFeatures; j++) {
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
  var params = initialParams.copy();
  var residuals = residualFunction(params);
  var currentCost = residuals.dot(residuals);
  var lambda = damping;

  for (var iter = 0; iter < maxIterations; iter++) {
    if (math.sqrt(currentCost) < tolerance) break;

    // Approximate Jacobian J_ij = dr_i / dp_j via finite differences
    final numResiduals = residuals.length;
    final numParams = params.length;
    const step = 1e-7;

    final j = Matrix<double>.generate(numResiduals, numParams, (row, col) {
      final pForward = params.copy();
      pForward[col] += step;
      final rForward = residualFunction(pForward);
      return (rForward[row] - residuals[row]) / step;
    }, type: DataType.float64);

    // Augmented normal equations: (J^T J + lambda * diag(J^T J)) delta = -J^T r
    final jTj = j.syrk(transpose: true);
    final jTr = j.applyTranspose(residuals);

    final a = Matrix<double>.generate(numParams, numParams, (row, col) {
      var val = jTj.get(row, col);
      if (row == col) {
        val += lambda * (val.abs() > 1e-6 ? val.abs() : 1.0);
      }
      return val;
    }, type: DataType.float64);

    final rhs = -jTr;
    final delta = leastSquares(a, rhs);

    if (delta.norm() < tolerance) break;

    final pCandidate = params + delta;
    final rCandidate = residualFunction(pCandidate);
    final candidateCost = rCandidate.dot(rCandidate);

    if (candidateCost < currentCost) {
      params = pCandidate;
      residuals = rCandidate;
      currentCost = candidateCost;
      lambda *= dampingStepDown;
    } else {
      lambda *= dampingStepUp;
    }
  }

  return params;
}
