import 'dart:math' as math;

import '../../type.dart';
import '../linear/decomposition/eigenvalue.dart';
import '../linear/matrix.dart';
import '../linear/vector.dart';
import '../tensor/tensor.dart';

/// Returns the arithmetic mean of [values], or [double.nan] if empty.
double mean(Iterable<num> values) => _mean(values);

/// Returns the sample or population variance of [values].
double variance(Iterable<num> values, {bool population = false}) =>
    _variance(values, population: population);

/// Returns the standard deviation of [values].
double standardDeviation(Iterable<num> values, {bool population = false}) =>
    _standardDeviation(values, population: population);

/// Returns the empirical quantile of [values] for fraction [quantile] $\in [0, 1]$
/// using standard linear interpolation between adjacent ranks (Type 7).
double quantile(Iterable<num> values, num quantile) =>
    _quantile(values, quantile);

/// Returns the [percentile]-th percentile of [values] where [percentile] $\in [0, 100]$.
double percentile(Iterable<num> values, num percentile) =>
    _percentile(values, percentile);

/// Returns the median of [values].
double median(Iterable<num> values) => _median(values);

/// Returns the interquartile range (IQR = Q3 - Q1) of [values].
double iqr(Iterable<num> values) => _iqr(values);

/// Returns the sample skewness of [values].
double skewness(Iterable<num> values, {bool bias = false}) =>
    _skewness(values, bias: bias);

/// Returns the kurtosis of [values]. If [excess] is true (default), returns excess kurtosis (Fisher).
double kurtosis(
  Iterable<num> values, {
  bool excess = true,
  bool bias = false,
}) => _kurtosis(values, excess: excess, bias: bias);

/// Computes the sample or population covariance between [x] and [y].
double covariance(
  Iterable<num> x,
  Iterable<num> y, {
  bool population = false,
}) => _covariance(x, y, population: population);

/// Computes Pearson correlation coefficient $r \in [-1, 1]$ between [x] and [y].
double pearsonCorrelation(Iterable<num> x, Iterable<num> y) =>
    _pearsonCorrelation(x, y);

/// Returns fractional ranks of [values], handling ties by averaging ranks.
List<double> rankData(Iterable<num> values) {
  final list = values.map((value) => value.toDouble()).toList();
  final length = list.length;
  final indices = List.generate(length, (i) => i)
    ..sort((a, b) => list[a].compareTo(list[b]));
  final ranks = List<double>.filled(length, 0.0);
  var i = 0;
  while (i < length) {
    var j = i;
    while (j + 1 < length && list[indices[j + 1]] == list[indices[i]]) {
      j++;
    }
    final avgRank = 1.0 + (i + j) / 2.0;
    for (var k = i; k <= j; k++) {
      ranks[indices[k]] = avgRank;
    }
    i = j + 1;
  }
  return ranks;
}

/// Computes Spearman rank correlation coefficient $\rho \in [-1, 1]$ between [x] and [y].
double spearmanCorrelation(Iterable<num> x, Iterable<num> y) =>
    _spearmanCorrelation(x, y);

/// Computes the sample covariance matrix of [data].
///
/// If [rowVar] is false (default), columns represent variables and rows represent observations.
/// If [rowVar] is true, rows represent variables and columns represent observations.
///
/// Transparently uses [Matrix.syrk] BLAS acceleration for large matrix multiplications.
Matrix<double> covarianceMatrix(dynamic data, {bool rowVar = false}) =>
    _covarianceMatrix(data, rowVar: rowVar);

/// Computes the Pearson correlation matrix of [data].
Matrix<double> pearsonCorrelationMatrix(dynamic data, {bool rowVar = false}) =>
    _pearsonCorrelationMatrix(data, rowVar: rowVar);

/// Computes the Spearman rank correlation matrix of [data].
Matrix<double> spearmanCorrelationMatrix(dynamic data, {bool rowVar = false}) =>
    _spearmanCorrelationMatrix(data, rowVar: rowVar);

/// Result of Principal Component Analysis (PCA).
class PcaResult {
  const new({
    required this.components,
    required this.explainedVariance,
    required this.explainedVarianceRatio,
    required this.mean,
    required this.standardize,
    this.std,
  });

  /// Principal axes in feature space: shape is (nComponents, nFeatures).
  final Matrix<double> components;

  /// Amount of variance explained by each principal component.
  final Vector<double> explainedVariance;

  /// Proportion of total variance explained by each principal component.
  final Vector<double> explainedVarianceRatio;

  /// Per-feature empirical mean.
  final Vector<double> mean;

  /// Whether data was standardized to unit variance.
  final bool standardize;

  /// Per-feature empirical standard deviation (if standardized).
  final Vector<double>? std;

  /// Projects [x] onto the principal component space.
  Matrix<double> transform(Matrix<num> x) {
    final rowCount = x.rowCount;
    final colCount = x.colCount;
    if (colCount != mean.length) {
      throw ArgumentError(
        'Feature dimension $colCount does not match fitted features ${mean.length}',
      );
    }
    final centered = Matrix<double>.filled(
      rowCount,
      colCount,
      0.0,
      type: DataType.float64,
    );
    for (var i = 0; i < rowCount; i++) {
      for (var j = 0; j < colCount; j++) {
        var val = x.get(i, j).toDouble() - mean[j];
        if (standardize && std != null && std![j] > 0.0) {
          val /= std![j];
        }
        centered.set(i, j, val);
      }
    }
    return centered * components.transpose();
  }

  /// Transforms [x] from principal component space back to original feature space.
  Matrix<double> inverseTransform(Matrix<num> x) {
    final rowCount = x.rowCount;
    final compCount = x.colCount;
    if (compCount != components.rowCount) {
      throw ArgumentError(
        'Component dimension $compCount does not match ${components.rowCount}',
      );
    }
    final featureCount = components.colCount;
    final xDouble = Matrix<double>.filled(
      rowCount,
      compCount,
      0.0,
      type: DataType.float64,
    );
    for (var i = 0; i < rowCount; i++) {
      for (var j = 0; j < compCount; j++) {
        xDouble.set(i, j, x.get(i, j).toDouble());
      }
    }
    final recon = xDouble * components;
    final result = Matrix<double>.filled(
      rowCount,
      featureCount,
      0.0,
      type: DataType.float64,
    );
    for (var i = 0; i < rowCount; i++) {
      for (var j = 0; j < featureCount; j++) {
        var val = recon.get(i, j);
        if (standardize && std != null) {
          val *= std![j];
        }
        val += mean[j];
        result.set(i, j, val);
      }
    }
    return result;
  }
}

/// Fits Principal Component Analysis (PCA) on [data].
///
/// Rows of [data] represent observations, and columns represent features.
/// If [standardize] is true, features are scaled to unit variance.
PcaResult pca(Matrix<num> data, {int? nComponents, bool standardize = false}) {
  final nSamples = data.rowCount;
  final nFeatures = data.colCount;
  if (nSamples < 2) {
    throw ArgumentError('At least 2 samples required for PCA');
  }
  final numComponents = (nComponents ?? math.min(nSamples, nFeatures)).clamp(
    1,
    nFeatures,
  );

  final meanVec = Vector<double>.filled(nFeatures, 0.0, type: DataType.float64);
  final stdVec = Vector<double>.filled(nFeatures, 1.0, type: DataType.float64);

  for (var j = 0; j < nFeatures; j++) {
    var sum = 0.0;
    for (var i = 0; i < nSamples; i++) {
      sum += data.get(i, j).toDouble();
    }
    final meanVal = sum / nSamples;
    meanVec[j] = meanVal;

    if (standardize) {
      var ss = 0.0;
      for (var i = 0; i < nSamples; i++) {
        final diff = data.get(i, j).toDouble() - meanVal;
        ss += diff * diff;
      }
      final stdVal = math.sqrt(ss / (nSamples - 1.0));
      stdVec[j] = stdVal > 0.0 ? stdVal : 1.0;
    }
  }

  final cov = standardize
      ? pearsonCorrelationMatrix(data, rowVar: false)
      : covarianceMatrix(data, rowVar: false);

  final eig = EigenvalueDecomposition(cov);
  final rawEigenvalues = eig.realEigenvalues;
  final eigVectors = eig.v;

  final order = List.generate(nFeatures, (i) => i)
    ..sort((a, b) => rawEigenvalues[b].compareTo(rawEigenvalues[a]));

  var totalVar = 0.0;
  for (final val in rawEigenvalues) {
    if (val > 0.0) totalVar += val;
  }

  final compMatrix = Matrix<double>.filled(
    numComponents,
    nFeatures,
    0.0,
    type: DataType.float64,
  );
  final expVar = Vector<double>.filled(
    numComponents,
    0.0,
    type: DataType.float64,
  );
  final expVarRatio = Vector<double>.filled(
    numComponents,
    0.0,
    type: DataType.float64,
  );

  for (var compIdx = 0; compIdx < numComponents; compIdx++) {
    final featureIdx = order[compIdx];
    final ev = math.max(0.0, rawEigenvalues[featureIdx]);
    expVar[compIdx] = ev;
    expVarRatio[compIdx] = totalVar > 0.0 ? ev / totalVar : 0.0;

    for (var j = 0; j < nFeatures; j++) {
      compMatrix.set(compIdx, j, eigVectors.get(j, featureIdx));
    }
  }

  return PcaResult(
    components: compMatrix,
    explainedVariance: expVar,
    explainedVarianceRatio: expVarRatio,
    mean: meanVec,
    standardize: standardize,
    std: standardize ? stdVec : null,
  );
}

/// Statistics extensions on [Iterable<num>].
extension DescriptiveIterableNumExtension on Iterable<num> {
  /// Returns the sum of values.
  double sum() {
    var total = 0.0;
    for (final value in this) {
      total += value;
    }
    return total;
  }

  /// Returns the product of values.
  double product() {
    var result = 1.0;
    for (final value in this) {
      result *= value;
    }
    return result;
  }

  /// Returns the arithmetic mean of values.
  double average() => arithmeticMean();

  /// Returns the arithmetic mean of values.
  double arithmeticMean() => _mean(this);

  /// Returns the arithmetic mean of values.
  double mean() => _mean(this);

  /// Returns the geometric mean of values.
  double geometricMean() {
    var count = 0;
    var sum = 0.0;
    for (final value in this) {
      if (value <= 0) return double.nan;
      count++;
      sum += math.log(value);
    }
    return count == 0 ? double.nan : math.exp(sum / count);
  }

  /// Returns the harmonic mean of values.
  double harmonicMean() {
    var count = 0;
    var sum = 0.0;
    for (final value in this) {
      if (value == 0) return double.nan;
      count++;
      sum += 1.0 / value;
    }
    return sum == 0.0 || count == 0 ? double.nan : count / sum;
  }

  /// Returns the variance of values.
  double variance({bool population = false}) =>
      _variance(this, population: population);

  /// Returns the standard deviation of values.
  double standardDeviation({bool population = false}) =>
      _standardDeviation(this, population: population);

  /// Returns the median of values.
  double median() => _median(this);

  /// Returns the empirical quantile for [quantile] $\in [0, 1]$.
  double quantile(num quantile) => _quantile(this, quantile);

  /// Returns the percentile for [percentile] $\in [0, 100]$.
  double percentile(num percentile) => _percentile(this, percentile);

  /// Returns the interquartile range (IQR).
  double iqr() => _iqr(this);

  /// Returns the skewness of values.
  double skewness({bool bias = false}) => _skewness(this, bias: bias);

  /// Returns the kurtosis of values.
  double kurtosis({bool excess = true, bool bias = false}) =>
      _kurtosis(this, excess: excess, bias: bias);
}

/// Statistics extensions on [Iterable<int>].
extension DescriptiveIterableIntExtension on Iterable<int> {
  /// Returns the integer sum.
  int sum() {
    var total = 0;
    for (final value in this) {
      total += value;
    }
    return total;
  }

  /// Returns the integer product.
  int product() {
    var result = 1;
    for (final value in this) {
      result *= value;
    }
    return result;
  }
}

/// Statistics extensions on [Vector<num>].
extension DescriptiveVectorNumExtension on Vector<num> {
  /// Returns the arithmetic mean of vector elements.
  double mean() => _mean(toList());

  /// Returns the variance of vector elements.
  double variance({bool population = false}) =>
      _variance(toList(), population: population);

  /// Returns the standard deviation of vector elements.
  double standardDeviation({bool population = false}) =>
      _standardDeviation(toList(), population: population);

  /// Returns the median of vector elements.
  double median() => _median(toList());

  /// Returns the empirical quantile for [quantile] $\in [0, 1]$.
  double quantile(num quantile) => _quantile(toList(), quantile);

  /// Returns the percentile for [percentile] $\in [0, 100]$.
  double percentile(num percentile) => _percentile(toList(), percentile);

  /// Returns the interquartile range (IQR).
  double iqr() => _iqr(toList());

  /// Returns the skewness of vector elements.
  double skewness({bool bias = false}) => _skewness(toList(), bias: bias);

  /// Returns the kurtosis of vector elements.
  double kurtosis({bool excess = true, bool bias = false}) =>
      _kurtosis(toList(), excess: excess, bias: bias);

  /// Computes the sample or population covariance with [other].
  double covariance(Vector<num> other, {bool population = false}) =>
      _covariance(toList(), other.toList(), population: population);

  /// Computes the Pearson correlation coefficient with [other].
  double pearsonCorrelation(Vector<num> other) =>
      _pearsonCorrelation(toList(), other.toList());

  /// Computes the Spearman rank correlation coefficient with [other].
  double spearmanCorrelation(Vector<num> other) =>
      _spearmanCorrelation(toList(), other.toList());
}

/// Statistics extensions on [Tensor<num>].
extension DescriptiveTensorNumExtension on Tensor<num> {
  /// Returns the arithmetic mean of tensor elements.
  double mean() => _mean(values);

  /// Returns the variance of tensor elements.
  double variance({bool population = false}) =>
      _variance(values, population: population);

  /// Returns the standard deviation of tensor elements.
  double standardDeviation({bool population = false}) =>
      _standardDeviation(values, population: population);

  /// Returns the median of tensor elements.
  double median() => _median(values);

  /// Returns the empirical quantile for [quantile] $\in [0, 1]$.
  double quantile(num quantile) => _quantile(values, quantile);

  /// Returns the percentile for [percentile] $\in [0, 100]$.
  double percentile(num percentile) => _percentile(values, percentile);

  /// Returns the interquartile range (IQR).
  double iqr() => _iqr(values);

  /// Returns the skewness of tensor elements.
  double skewness({bool bias = false}) => _skewness(values, bias: bias);

  /// Returns the kurtosis of tensor elements.
  double kurtosis({bool excess = true, bool bias = false}) =>
      _kurtosis(values, excess: excess, bias: bias);

  /// Computes the covariance matrix of a rank-2 tensor.
  Matrix<double> covarianceMatrix({bool rowVar = false}) =>
      _covarianceMatrix(this, rowVar: rowVar);

  /// Computes the Pearson correlation matrix of a rank-2 tensor.
  Matrix<double> pearsonCorrelationMatrix({bool rowVar = false}) =>
      _pearsonCorrelationMatrix(this, rowVar: rowVar);

  /// Computes the Spearman rank correlation matrix of a rank-2 tensor.
  Matrix<double> spearmanCorrelationMatrix({bool rowVar = false}) =>
      _spearmanCorrelationMatrix(this, rowVar: rowVar);
}

/// Statistics extensions on [Matrix<num>].
extension DescriptiveMatrixNumExtension on Matrix<num> {
  /// Returns the arithmetic mean of matrix elements.
  double mean() => _mean(values);

  /// Returns the variance of matrix elements.
  double variance({bool population = false}) =>
      _variance(values, population: population);

  /// Returns the standard deviation of matrix elements.
  double standardDeviation({bool population = false}) =>
      _standardDeviation(values, population: population);

  /// Returns the median of matrix elements.
  double median() => _median(values);

  /// Returns the empirical quantile for [quantile] $\in [0, 1]$.
  double quantile(num quantile) => _quantile(values, quantile);

  /// Returns the percentile for [percentile] $\in [0, 100]$.
  double percentile(num percentile) => _percentile(values, percentile);

  /// Returns the interquartile range (IQR).
  double iqr() => _iqr(values);

  /// Returns the skewness of matrix elements.
  double skewness({bool bias = false}) => _skewness(values, bias: bias);

  /// Returns the kurtosis of matrix elements.
  double kurtosis({bool excess = true, bool bias = false}) =>
      _kurtosis(values, excess: excess, bias: bias);

  /// Computes the covariance matrix.
  Matrix<double> covarianceMatrix({bool rowVar = false}) =>
      _covarianceMatrix(this, rowVar: rowVar);

  /// Computes the Pearson correlation matrix.
  Matrix<double> pearsonCorrelationMatrix({bool rowVar = false}) =>
      _pearsonCorrelationMatrix(this, rowVar: rowVar);

  /// Computes the Spearman rank correlation matrix.
  Matrix<double> spearmanCorrelationMatrix({bool rowVar = false}) =>
      _spearmanCorrelationMatrix(this, rowVar: rowVar);
}

double _mean(Iterable<num> values) {
  var count = 0;
  var sum = 0.0;
  for (final val in values) {
    count++;
    sum += val;
  }
  return count == 0 ? double.nan : sum / count;
}

double _variance(Iterable<num> values, {bool population = false}) {
  var count = 0;
  var mean = 0.0;
  var m2 = 0.0;
  for (final val in values) {
    count++;
    final delta = val - mean;
    mean += delta / count;
    final delta2 = val - mean;
    m2 += delta * delta2;
  }
  final divisor = population ? count : count - 1;
  return divisor < 1 ? double.nan : m2 / divisor;
}

double _standardDeviation(Iterable<num> values, {bool population = false}) =>
    math.sqrt(_variance(values, population: population));

double _quantile(Iterable<num> values, num quantile) {
  final list = values.map((val) => val.toDouble()).toList()..sort();
  if (list.isEmpty) return double.nan;
  if (quantile <= 0.0) return list.first;
  if (quantile >= 1.0) return list.last;
  final idx = quantile * (list.length - 1);
  final baseIdx = idx.floor();
  final frac = idx - baseIdx;
  if (baseIdx >= list.length - 1) return list.last;
  return list[baseIdx] + frac * (list[baseIdx + 1] - list[baseIdx]);
}

double _percentile(Iterable<num> values, num percentile) =>
    _quantile(values, percentile / 100.0);

double _median(Iterable<num> values) => _quantile(values, 0.5);

double _iqr(Iterable<num> values) =>
    _quantile(values, 0.75) - _quantile(values, 0.25);

double _skewness(Iterable<num> values, {bool bias = false}) {
  final list = values.map((val) => val.toDouble()).toList();
  final length = list.length;
  if (length < 3 && !bias) return double.nan;
  if (length < 2) return double.nan;
  final meanVal = _mean(list);
  var m2 = 0.0;
  var m3 = 0.0;
  for (final x in list) {
    final diff = x - meanVal;
    m2 += diff * diff;
    m3 += diff * diff * diff;
  }
  m2 /= length;
  m3 /= length;
  if (m2 == 0.0) return 0.0;
  final g1 = m3 / math.pow(m2, 1.5);
  if (bias) return g1;
  return (math.sqrt(length * (length - 1.0)) / (length - 2.0)) * g1;
}

double _kurtosis(
  Iterable<num> values, {
  bool excess = true,
  bool bias = false,
}) {
  final list = values.map((val) => val.toDouble()).toList();
  final length = list.length;
  if (length < 4 && !bias) return double.nan;
  if (length < 2) return double.nan;
  final meanVal = _mean(list);
  var m2 = 0.0;
  var m4 = 0.0;
  for (final x in list) {
    final diff = x - meanVal;
    final diff2 = diff * diff;
    m2 += diff2;
    m4 += diff2 * diff2;
  }
  m2 /= length;
  m4 /= length;
  if (m2 == 0.0) return 0.0;
  final kurtosisVal = m4 / (m2 * m2);
  if (bias) {
    return excess ? kurtosisVal - 3.0 : kurtosisVal;
  }
  final factor1 = (length - 1.0) / ((length - 2.0) * (length - 3.0));
  final factor2 = (length + 1.0) * kurtosisVal - 3.0 * (length - 1.0);
  final excessK = factor1 * factor2;
  return excess ? excessK : excessK + 3.0;
}

double _covariance(
  Iterable<num> x,
  Iterable<num> y, {
  bool population = false,
}) {
  final xList = x.map((val) => val.toDouble()).toList();
  final yList = y.map((val) => val.toDouble()).toList();
  if (xList.length != yList.length) {
    throw ArgumentError('x and y must have equal length');
  }
  final length = xList.length;
  final divisor = population ? length : length - 1;
  if (divisor < 1) return double.nan;
  final mx = _mean(xList);
  final my = _mean(yList);
  var sum = 0.0;
  for (var i = 0; i < length; i++) {
    sum += (xList[i] - mx) * (yList[i] - my);
  }
  return sum / divisor;
}

double _pearsonCorrelation(Iterable<num> x, Iterable<num> y) {
  final xList = x.map((val) => val.toDouble()).toList();
  final yList = y.map((val) => val.toDouble()).toList();
  if (xList.length != yList.length) {
    throw ArgumentError('x and y must have equal length');
  }
  final length = xList.length;
  if (length < 2) return double.nan;
  final mx = _mean(xList);
  final my = _mean(yList);
  var ssX = 0.0;
  var ssY = 0.0;
  var ssXY = 0.0;
  for (var i = 0; i < length; i++) {
    final dx = xList[i] - mx;
    final dy = yList[i] - my;
    ssX += dx * dx;
    ssY += dy * dy;
    ssXY += dx * dy;
  }
  if (ssX == 0.0 || ssY == 0.0) return double.nan;
  return ssXY / math.sqrt(ssX * ssY);
}

double _spearmanCorrelation(Iterable<num> x, Iterable<num> y) =>
    _pearsonCorrelation(rankData(x), rankData(y));

Matrix<double> _covarianceMatrix(dynamic data, {bool rowVar = false}) {
  final matrix = switch (data) {
    Matrix<num>() => data,
    Tensor<num>() => Matrix(data),
    _ => throw ArgumentError.value(
      data,
      'data',
      'Expected Matrix<num> or Tensor<num>',
    ),
  };

  final numRows = matrix.rowCount;
  final numCols = matrix.colCount;
  final nSamples = rowVar ? numCols : numRows;
  final nFeatures = rowVar ? numRows : numCols;

  if (nSamples < 2) {
    throw ArgumentError(
      'At least 2 observations required for covariance matrix',
    );
  }

  // Build centered data matrix Xc of size (nSamples x nFeatures)
  final xc = Matrix<double>.filled(
    nSamples,
    nFeatures,
    0.0,
    type: DataType.float64,
  );

  for (var j = 0; j < nFeatures; j++) {
    var sum = 0.0;
    for (var i = 0; i < nSamples; i++) {
      sum += rowVar ? matrix.get(j, i).toDouble() : matrix.get(i, j).toDouble();
    }
    final meanVal = sum / nSamples;
    for (var i = 0; i < nSamples; i++) {
      final val = rowVar
          ? matrix.get(j, i).toDouble()
          : matrix.get(i, j).toDouble();
      xc.set(i, j, val - meanVal);
    }
  }

  final scale = 1.0 / (nSamples - 1.0);
  return xc.syrk(transpose: true, alpha: scale);
}

Matrix<double> _pearsonCorrelationMatrix(dynamic data, {bool rowVar = false}) {
  final cov = _covarianceMatrix(data, rowVar: rowVar);
  final dim = cov.rowCount;
  final std = List<double>.generate(dim, (i) => math.sqrt(cov.get(i, i)));
  final corr = Matrix<double>.filled(dim, dim, 0.0, type: DataType.float64);
  for (var i = 0; i < dim; i++) {
    corr.set(i, i, 1.0);
    for (var j = i + 1; j < dim; j++) {
      final denom = std[i] * std[j];
      final correlation = denom > 0.0
          ? (cov.get(i, j) / denom).clamp(-1.0, 1.0)
          : 0.0;
      corr.set(i, j, correlation);
      corr.set(j, i, correlation);
    }
  }
  return corr;
}

Matrix<double> _spearmanCorrelationMatrix(dynamic data, {bool rowVar = false}) {
  final matrix = switch (data) {
    Matrix<num>() => data,
    Tensor<num>() => Matrix(data),
    _ => throw ArgumentError.value(
      data,
      'data',
      'Expected Matrix<num> or Tensor<num>',
    ),
  };

  final numRows = matrix.rowCount;
  final numCols = matrix.colCount;
  final nSamples = rowVar ? numCols : numRows;
  final nFeatures = rowVar ? numRows : numCols;

  final ranked = Matrix<double>.filled(
    nSamples,
    nFeatures,
    0.0,
    type: DataType.float64,
  );

  for (var j = 0; j < nFeatures; j++) {
    final colValues = List<double>.generate(
      nSamples,
      (i) => rowVar ? matrix.get(j, i).toDouble() : matrix.get(i, j).toDouble(),
    );
    final ranks = rankData(colValues);
    for (var i = 0; i < nSamples; i++) {
      ranked.set(i, j, ranks[i]);
    }
  }

  return _pearsonCorrelationMatrix(ranked, rowVar: false);
}
