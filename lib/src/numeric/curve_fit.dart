import 'dart:math' as math;
import 'dart:typed_data';

import '../acceleration/lapack/lapack.dart';
import '../linear/decomposition/qr.dart';
import '../linear/decomposition/svd.dart';
import '../linear/matrix.dart';
import '../linear/vector.dart';
import '../polynomial/polynomial.dart';
import '../type/data_type.dart';
import 'calculus/jacobian.dart' as calculus;

/// Curve fitting and regression algorithms using numerically stable QR and SVD
/// matrix decompositions.

/// Solves the general linear least squares problem $\min \|A x - b\|_2$.
///
/// Conceptually, when an overdetermined system has more observations than
/// parameters, an exact solution may not exist. Least squares finds the
/// parameters that best fit the data by minimizing the sum of squared
/// residuals. Formally, it computes $\hat{\mathbf{x}} = A^+ \mathbf{b}$ using
/// Householder QR factorization for full-rank systems, and Golub-Reinsch SVD
/// for rank-deficient systems.
///
/// ```dart
/// final a = Matrix<double>.fromRows([
///   [1.0, 1.0],
///   [1.0, 2.0],
///   [1.0, 3.0],
/// ]);
/// final b = Vector<double>.fromList([2.0, 2.8, 4.1]);
/// final x = leastSquares(a, b);
/// ```
Vector<double> leastSquares(Matrix<num> a, Vector<num> b) {
  if (a.rowCount != b.length) {
    throw ArgumentError(
      'Matrix row count (${a.rowCount}) must match vector length (${b.length}).',
    );
  }
  final rows = a.rowCount;
  final cols = a.colCount;
  if (cols == 0 || rows == 0) {
    return Vector<double>.filled(cols, 0.0, type: DataType.float64);
  }
  if (rows >= cols) {
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
    final success = Lapack.dgels(
      m: rows,
      n: cols,
      nrhs: 1,
      a: aData,
      lda: cols,
      b: bData,
      ldb: 1,
    );
    if (success) {
      return Vector<double>.fromList(
        bData.sublist(0, cols),
        type: DataType.float64,
      );
    }
  }
  final bDouble = b is Vector<double>
      ? b
      : Vector<double>.generate(
          b.length,
          (i) => b.getUnchecked(i).toDouble(),
          type: DataType.float64,
        );
  if (rows >= cols) {
    final qr = a.qr;
    if (qr.isFullRank) {
      return qr.solveVector(bDouble);
    }
  }
  return a.svd.solveVector(bDouble);
}

/// Simple univariate linear regression fitting
/// $y = \text{slope} \cdot x + \text{intercept}$.
///
/// Conceptually, this fits an optimal straight trendline through scattered data
/// points, determining the slope and vertical intercept. Formally, it fits an
/// ordinary least squares affine model minimizing
/// $\sum (y_i - (\beta_0 + \beta_1 x_i))^2$ and computes the coefficient of
/// determination $R^2$.
///
/// ```dart
/// final xs = Vector<double>.fromList([1.0, 2.0, 3.0, 4.0]);
/// final ys = Vector<double>.fromList([2.0, 4.0, 6.0, 8.0]);
/// final model = linearRegression(xs, ys);
/// print(model.slope); // ~2.0
/// ```
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

/// Fits a polynomial of given [degree] to data points [xs] and [ys] using QR
/// least squares on the Vandermonde matrix, with optional L2 [lambda]
/// regularization (Ridge / Tikhonov) suppressing high-frequency oscillations.
Polynomial<double> polynomialRegression(
  Vector<num> xs,
  Vector<num> ys, {
  required int degree,
  double lambda = 0.0,
}) {
  if (xs.length != ys.length) {
    throw ArgumentError('xs and ys must have the same length.');
  }
  if (degree < 0) {
    throw ArgumentError.value(degree, 'degree', 'Degree must be non-negative.');
  }
  if (lambda < 0.0) {
    throw ArgumentError(
      'Regularization parameter lambda must be non-negative: $lambda',
    );
  }
  final numPoints = xs.length;
  final numCoeffs = degree + 1;
  if (lambda == 0.0 && numPoints < numCoeffs) {
    throw ArgumentError(
      'At least $numCoeffs points are required to fit unregularized degree $degree polynomial, got $numPoints.',
    );
  }
  if (numPoints < 1) {
    throw ArgumentError('At least 1 point is required for regression.');
  }

  final Matrix<double> designMatrix;
  final Vector<double> targetVector;

  if (lambda == 0.0) {
    designMatrix = Matrix<double>.generate(
      numPoints,
      numCoeffs,
      (row, col) => math.pow(xs[row].toDouble(), col).toDouble(),
      type: DataType.float64,
    );
    targetVector = ys is Vector<double>
        ? ys
        : Vector<double>.generate(
            numPoints,
            (i) => ys[i].toDouble(),
            type: DataType.float64,
          );
  } else {
    // Augment Vandermonde matrix with sqrt(lambda) * I (leaving intercept
    // column 0 unpenalized)
    final sqrtLambda = math.sqrt(lambda);
    final totalRows = numPoints + numCoeffs;
    designMatrix = Matrix<double>.generate(totalRows, numCoeffs, (row, col) {
      if (row < numPoints) {
        return math.pow(xs[row].toDouble(), col).toDouble();
      }
      final penaltyIdx = row - numPoints;
      // Do not penalize intercept (col == 0)
      return (penaltyIdx > 0 && penaltyIdx == col) ? sqrtLambda : 0.0;
    }, type: DataType.float64);
    targetVector = Vector<double>.generate(
      totalRows,
      (i) => i < numPoints ? ys[i].toDouble() : 0.0,
      type: DataType.float64,
    );
  }

  final coeffs = leastSquares(designMatrix, targetVector);
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
  final numParams = fitIntercept ? numFeatures + 1 : numFeatures;
  if (numSamples < 1 || numSamples < numParams) {
    throw ArgumentError(
      'At least ${math.max(1, numParams)} samples are required, got $numSamples.',
    );
  }

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

/// Result of non-linear parametric curve fitting.
class CurveFitResult {
  /// Creates a [CurveFitResult].
  const new({
    required this.parameters,
    required this.predict,
    required this.rSquared,
    required this.residualStandardError,
    required this.residuals,
    required this.iterations,
    required this.covariance,
    required this.standardErrors,
  });

  /// The optimal parameter vector $\hat{\boldsymbol{\theta}}$.
  final Vector<double> parameters;

  /// Predictor function evaluating the fitted model
  /// $\hat{y} = f(x; \hat{\boldsymbol{\theta}})$.
  final double Function(double x) predict;

  /// Coefficient of determination $R^2 \in (-\infty, 1]$, measuring
  /// goodness-of-fit.
  final double rSquared;

  /// Residual standard error $\sqrt{\frac{\sum r_i^2}{N - P}}$.
  final double residualStandardError;

  /// The residual vector $\mathbf{r}$ where $r_i = \hat{y}_i - y_i$.
  final Vector<double> residuals;

  /// The number of optimization iterations performed.
  final int iterations;

  /// The estimated parameter covariance matrix $(J^T J)^{-1} \cdot \text{RSE}^2$.
  final Matrix<double> covariance;

  /// The standard errors for each fitted parameter.
  final Vector<double> standardErrors;
}

/// Predefined parametric models for non-linear curve fitting with [curveFit].
abstract final class CurveModels {
  /// Exponential model: $f(x; a, b) = a e^{b x}$. Parameters: `[a, b]`.
  static double exponential(double x, Vector<double> params) =>
      params[0] * math.exp(params[1] * x);

  /// Power-law model: $f(x; a, b) = a x^b$. Parameters: `[a, b]`.
  static double power(double x, Vector<double> params) =>
      params[0] * math.pow(x, params[1]).toDouble();

  /// Logarithmic model: $f(x; a, b) = a + b \ln x$. Parameters: `[a, b]`.
  static double logarithmic(double x, Vector<double> params) =>
      params[0] + params[1] * math.log(x);

  /// Gaussian peak model:
  /// $f(x; a, \mu, \sigma) = a e^{-\frac{(x - \mu)^2}{2\sigma^2}}$. Parameters:
  /// `[a, mu, sigma]`.
  static double gaussian(double x, Vector<double> params) {
    final diff = x - params[1];
    final s = params[2];
    return params[0] * math.exp(-(diff * diff) / (2.0 * s * s));
  }
}

/// Fits non-linear parameters $\hat{\boldsymbol{\theta}}$ to data points ([xs],
/// [ys]) using [model].
///
/// Conceptually, curve fitting determines the optimal parameters of a
/// mathematical function that best trace the trend of experimental or observed
/// data points. Formally, it minimizes the sum of squared residuals
/// $\sum_{i=1}^N (f(x_i; \boldsymbol{\theta}) - y_i)^2$ using
/// Levenberg-Marquardt damped least-squares with optional box constraints
/// ([lowerBounds] and [upperBounds]).
///
/// Returns a [CurveFitResult] containing the optimal parameters, predictor
/// function, $R^2$ goodness-of-fit, and residual metrics.
///
/// ```dart
/// final xs = Vector<double>.fromList([0.0, 1.0, 2.0, 3.0]);
/// final ys = Vector<double>.fromList(
///   [2.0, 5.4, 14.8, 40.2],
/// ); // approx 2 * exp(x)
/// final result = curveFit(
///   xs: xs,
///   ys: ys,
///   model: CurveModels.exponential,
///   initialParams: Vector<double>.fromList([1.0, 0.5]),
/// );
/// print(result.parameters); // [~2.0, ~1.0]
/// print(result.predict(4.0)); // ~109.2
/// ```
CurveFitResult curveFit({
  required Vector<num> xs,
  required Vector<num> ys,
  required double Function(double x, Vector<double> params) model,
  required Vector<double> initialParams,
  Vector<double>? lowerBounds,
  Vector<double>? upperBounds,
  double tolerance = 1e-7,
  int maxIterations = 100,
  double damping = 1e-2,
  double dampingStepUp = 10.0,
  double dampingStepDown = 0.1,
}) {
  final n = xs.length;
  if (n != ys.length) {
    throw ArgumentError('xs length ($n) must match ys length (${ys.length}).');
  }
  final numParams = initialParams.length;
  if (n < numParams) {
    throw ArgumentError(
      'Number of data points ($n) must be at least number of parameters ($numParams).',
    );
  }
  if (lowerBounds != null && lowerBounds.length != numParams) {
    throw ArgumentError(
      'lowerBounds length (${lowerBounds.length}) must match initialParams length ($numParams).',
    );
  }
  if (upperBounds != null && upperBounds.length != numParams) {
    throw ArgumentError(
      'upperBounds length (${upperBounds.length}) must match initialParams length ($numParams).',
    );
  }

  final params = initialParams.copy();
  for (var k = 0; k < numParams; k++) {
    final lo = lowerBounds?[k] ?? double.negativeInfinity;
    final hi = upperBounds?[k] ?? double.infinity;
    params[k] = params[k].clamp(lo, hi);
  }

  Vector<double> computeResiduals(Vector<double> p) => Vector<double>.generate(
    n,
    (i) => model(xs[i].toDouble(), p) - ys[i].toDouble(),
    type: DataType.float64,
  );

  var residuals = computeResiduals(params);
  var currentCost = residuals.dot(residuals);
  var lambda = damping;
  var iter = 0;

  for (; iter < maxIterations; iter++) {
    if (math.sqrt(currentCost) < tolerance) break;

    final j = calculus.jacobian(computeResiduals, params, step: 1e-7);

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
    for (var k = 0; k < numParams; k++) {
      final lo = lowerBounds?[k] ?? double.negativeInfinity;
      final hi = upperBounds?[k] ?? double.infinity;
      pCandidate[k] = pCandidate[k].clamp(lo, hi);
    }

    final rCandidate = computeResiduals(pCandidate);
    final candidateCost = rCandidate.dot(rCandidate);

    if (candidateCost < currentCost) {
      for (var k = 0; k < numParams; k++) {
        params[k] = pCandidate[k];
      }
      residuals = rCandidate;
      currentCost = candidateCost;
      lambda *= dampingStepDown;
    } else {
      lambda *= dampingStepUp;
    }
  }

  var ySum = 0.0;
  for (var i = 0; i < n; i++) {
    ySum += ys[i].toDouble();
  }
  final yMean = ySum / n;

  var ssTot = 0.0;
  var ssRes = 0.0;
  for (var i = 0; i < n; i++) {
    final yVal = ys[i].toDouble();
    final dTot = yVal - yMean;
    ssTot += dTot * dTot;
    final r = residuals[i];
    ssRes += r * r;
  }

  final rSquared = ssTot > 0.0
      ? 1.0 - (ssRes / ssTot)
      : (ssRes == 0.0 ? 1.0 : 0.0);
  final df = n - numParams;
  final rse = math.sqrt(ssRes / math.max(df, 1));

  final optimalParams = params.copy();
  final j = calculus.jacobian(computeResiduals, optimalParams, step: 1e-7);
  final jTj = j.syrk(transpose: true);
  final eye = Matrix<double>.identity(numParams, type: DataType.float64);
  final Matrix<double> inv;
  Matrix<double>? solvedInv;
  try {
    solvedInv = jTj.solve(eye);
  } on ArgumentError {
    solvedInv = null;
  } on StateError {
    solvedInv = null;
  }
  if (solvedInv != null) {
    inv = solvedInv;
  } else {
    final svd = SingularValueDecomposition(jTj);
    final s = svd.s;
    final maxS = s.length > 0 ? s[0] : 0.0;
    final tol = numParams * maxS * 2.220446049250313e-16;
    final vt = svd.vt;
    final sInv = List<double>.filled(numParams, 0.0);
    final hasZeroSingular = List<bool>.filled(numParams, false);
    for (var i = 0; i < numParams; i++) {
      if (s[i] > tol) {
        sInv[i] = 1.0 / s[i];
      } else {
        hasZeroSingular[i] = true;
      }
    }
    final nonIdentifiable = List<bool>.filled(numParams, false);
    for (var p = 0; p < numParams; p++) {
      for (var k = 0; k < numParams; k++) {
        if (hasZeroSingular[k] && vt.getUnchecked(k, p).abs() > 1e-6) {
          nonIdentifiable[p] = true;
          break;
        }
      }
    }
    inv = Matrix<double>.generate(numParams, numParams, (r, c) {
      if (nonIdentifiable[r] || nonIdentifiable[c]) {
        return r == c ? double.infinity : double.nan;
      }
      var sum = 0.0;
      for (var k = 0; k < numParams; k++) {
        if (sInv[k] > 0.0) {
          sum += vt.getUnchecked(k, r) * sInv[k] * vt.getUnchecked(k, c);
        }
      }
      return sum;
    }, type: DataType.float64);
  }
  final rseSq = rse * rse;
  final covariance = Matrix<double>.generate(numParams, numParams, (r, c) {
    final v = inv.get(r, c);
    if (v.isInfinite) return double.infinity;
    if (v.isNaN) return double.nan;
    return v * rseSq;
  }, type: DataType.float64);
  final standardErrors = Vector<double>.generate(numParams, (i) {
    final v = covariance.get(i, i);
    if (v.isNaN) return double.nan;
    if (v.isInfinite) return double.infinity;
    return v > 0.0 ? math.sqrt(v) : 0.0;
  }, type: DataType.float64);

  return CurveFitResult(
    parameters: optimalParams,
    predict: (double x) => model(x, optimalParams),
    rSquared: rSquared,
    residualStandardError: rse,
    residuals: residuals,
    iterations: iter,
    covariance: covariance,
    standardErrors: standardErrors,
  );
}

/// Fits non-linear parameters using the Levenberg-Marquardt damped
/// least-squares algorithm.
Vector<double> fitNonlinear({
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

    final numParams = params.length;
    final j = calculus.jacobian(residualFunction, params, step: 1e-7);

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
