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

/// Returns the empirical quantile of [values] for fraction [q] $\in [0, 1]$
/// using standard linear interpolation between adjacent ranks (Type 7).
double quantile(Iterable<num> values, num q) => _quantile(values, q);

/// Returns the [p]-th percentile of [values] where $p \in [0, 100]$.
double percentile(Iterable<num> values, num p) => _percentile(values, p);

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
  final list = values.map((e) => e.toDouble()).toList();
  final n = list.length;
  final indices = List.generate(n, (i) => i)
    ..sort((a, b) => list[a].compareTo(list[b]));
  final ranks = List<double>.filled(n, 0.0);
  var i = 0;
  while (i < n) {
    var j = i;
    while (j + 1 < n && list[indices[j + 1]] == list[indices[i]]) {
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
    final n = x.rowCount;
    final p = x.colCount;
    if (p != mean.length) {
      throw ArgumentError(
        'Feature dimension $p does not match fitted features ${mean.length}',
      );
    }
    final centered = Matrix<double>.filled(n, p, 0.0, type: DataType.float64);
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < p; j++) {
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
    final n = x.rowCount;
    final k = x.colCount;
    if (k != components.rowCount) {
      throw ArgumentError(
        'Component dimension $k does not match ${components.rowCount}',
      );
    }
    final p = components.colCount;
    final xDouble = Matrix<double>.filled(n, k, 0.0, type: DataType.float64);
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < k; j++) {
        xDouble.set(i, j, x.get(i, j).toDouble());
      }
    }
    final recon = xDouble * components;
    final result = Matrix<double>.filled(n, p, 0.0, type: DataType.float64);
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < p; j++) {
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
  final k = (nComponents ?? math.min(nSamples, nFeatures)).clamp(1, nFeatures);

  final meanVec = Vector<double>.filled(nFeatures, 0.0, type: DataType.float64);
  final stdVec = Vector<double>.filled(nFeatures, 1.0, type: DataType.float64);

  for (var j = 0; j < nFeatures; j++) {
    var sum = 0.0;
    for (var i = 0; i < nSamples; i++) {
      sum += data.get(i, j).toDouble();
    }
    final m = sum / nSamples;
    meanVec[j] = m;

    if (standardize) {
      var ss = 0.0;
      for (var i = 0; i < nSamples; i++) {
        final d = data.get(i, j).toDouble() - m;
        ss += d * d;
      }
      final s = math.sqrt(ss / (nSamples - 1.0));
      stdVec[j] = s > 0.0 ? s : 1.0;
    }
  }

  final cov = standardize
      ? pearsonCorrelationMatrix(data, rowVar: false)
      : covarianceMatrix(data, rowVar: false);

  final eig = EigenvalueDecomposition(cov);
  final rawEigenvalues = eig.realEigenvalues;
  final v = eig.v;

  final order = List.generate(nFeatures, (i) => i)
    ..sort((a, b) => rawEigenvalues[b].compareTo(rawEigenvalues[a]));

  var totalVar = 0.0;
  for (final val in rawEigenvalues) {
    if (val > 0.0) totalVar += val;
  }

  final compMatrix = Matrix<double>.filled(
    k,
    nFeatures,
    0.0,
    type: DataType.float64,
  );
  final expVar = Vector<double>.filled(k, 0.0, type: DataType.float64);
  final expVarRatio = Vector<double>.filled(k, 0.0, type: DataType.float64);

  for (var compIdx = 0; compIdx < k; compIdx++) {
    final featureIdx = order[compIdx];
    final ev = math.max(0.0, rawEigenvalues[featureIdx]);
    expVar[compIdx] = ev;
    expVarRatio[compIdx] = totalVar > 0.0 ? ev / totalVar : 0.0;

    for (var j = 0; j < nFeatures; j++) {
      compMatrix.set(compIdx, j, v.get(j, featureIdx));
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
    var s = 0.0;
    for (final v in this) {
      s += v;
    }
    return s;
  }

  /// Returns the product of values.
  double product() {
    var p = 1.0;
    for (final v in this) {
      p *= v;
    }
    return p;
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
    for (final v in this) {
      if (v <= 0) return double.nan;
      count++;
      sum += math.log(v);
    }
    return count == 0 ? double.nan : math.exp(sum / count);
  }

  /// Returns the harmonic mean of values.
  double harmonicMean() {
    var count = 0;
    var sum = 0.0;
    for (final v in this) {
      if (v == 0) return double.nan;
      count++;
      sum += 1.0 / v;
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

  /// Returns the empirical quantile for [q] $\in [0, 1]$.
  double quantile(num q) => _quantile(this, q);

  /// Returns the percentile for [p] $\in [0, 100]$.
  double percentile(num p) => _percentile(this, p);

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
    var s = 0;
    for (final v in this) {
      s += v;
    }
    return s;
  }

  /// Returns the integer product.
  int product() {
    var p = 1;
    for (final v in this) {
      p *= v;
    }
    return p;
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

  /// Returns the empirical quantile for [q] $\in [0, 1]$.
  double quantile(num q) => _quantile(toList(), q);

  /// Returns the percentile for [p] $\in [0, 100]$.
  double percentile(num p) => _percentile(toList(), p);

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

  /// Returns the empirical quantile for [q] $\in [0, 1]$.
  double quantile(num q) => _quantile(values, q);

  /// Returns the percentile for [p] $\in [0, 100]$.
  double percentile(num p) => _percentile(values, p);

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

  /// Returns the empirical quantile for [q] $\in [0, 1]$.
  double quantile(num q) => _quantile(values, q);

  /// Returns the percentile for [p] $\in [0, 100]$.
  double percentile(num p) => _percentile(values, p);

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
  for (final v in values) {
    count++;
    sum += v;
  }
  return count == 0 ? double.nan : sum / count;
}

double _variance(Iterable<num> values, {bool population = false}) {
  var count = 0;
  var m = 0.0;
  var m2 = 0.0;
  for (final v in values) {
    count++;
    final delta = v - m;
    m += delta / count;
    final delta2 = v - m;
    m2 += delta * delta2;
  }
  final divisor = population ? count : count - 1;
  return divisor < 1 ? double.nan : m2 / divisor;
}

double _standardDeviation(Iterable<num> values, {bool population = false}) =>
    math.sqrt(_variance(values, population: population));

double _quantile(Iterable<num> values, num q) {
  final list = values.map((e) => e.toDouble()).toList()..sort();
  if (list.isEmpty) return double.nan;
  if (q <= 0.0) return list.first;
  if (q >= 1.0) return list.last;
  final idx = q * (list.length - 1);
  final i = idx.floor();
  final frac = idx - i;
  if (i >= list.length - 1) return list.last;
  return list[i] + frac * (list[i + 1] - list[i]);
}

double _percentile(Iterable<num> values, num p) => _quantile(values, p / 100.0);

double _median(Iterable<num> values) => _quantile(values, 0.5);

double _iqr(Iterable<num> values) =>
    _quantile(values, 0.75) - _quantile(values, 0.25);

double _skewness(Iterable<num> values, {bool bias = false}) {
  final list = values.map((e) => e.toDouble()).toList();
  final n = list.length;
  if (n < 3 && !bias) return double.nan;
  if (n < 2) return double.nan;
  final m = _mean(list);
  var m2 = 0.0;
  var m3 = 0.0;
  for (final x in list) {
    final diff = x - m;
    m2 += diff * diff;
    m3 += diff * diff * diff;
  }
  m2 /= n;
  m3 /= n;
  if (m2 == 0.0) return 0.0;
  final g1 = m3 / math.pow(m2, 1.5);
  if (bias) return g1;
  return (math.sqrt(n * (n - 1.0)) / (n - 2.0)) * g1;
}

double _kurtosis(
  Iterable<num> values, {
  bool excess = true,
  bool bias = false,
}) {
  final list = values.map((e) => e.toDouble()).toList();
  final n = list.length;
  if (n < 4 && !bias) return double.nan;
  if (n < 2) return double.nan;
  final m = _mean(list);
  var m2 = 0.0;
  var m4 = 0.0;
  for (final x in list) {
    final diff = x - m;
    final diff2 = diff * diff;
    m2 += diff2;
    m4 += diff2 * diff2;
  }
  m2 /= n;
  m4 /= n;
  if (m2 == 0.0) return 0.0;
  final k = m4 / (m2 * m2);
  if (bias) {
    return excess ? k - 3.0 : k;
  }
  final factor1 = (n - 1.0) / ((n - 2.0) * (n - 3.0));
  final factor2 = (n + 1.0) * k - 3.0 * (n - 1.0);
  final excessK = factor1 * factor2;
  return excess ? excessK : excessK + 3.0;
}

double _covariance(
  Iterable<num> x,
  Iterable<num> y, {
  bool population = false,
}) {
  final xList = x.map((e) => e.toDouble()).toList();
  final yList = y.map((e) => e.toDouble()).toList();
  if (xList.length != yList.length) {
    throw ArgumentError('x and y must have equal length');
  }
  final n = xList.length;
  final divisor = population ? n : n - 1;
  if (divisor < 1) return double.nan;
  final mx = _mean(xList);
  final my = _mean(yList);
  var sum = 0.0;
  for (var i = 0; i < n; i++) {
    sum += (xList[i] - mx) * (yList[i] - my);
  }
  return sum / divisor;
}

double _pearsonCorrelation(Iterable<num> x, Iterable<num> y) {
  final xList = x.map((e) => e.toDouble()).toList();
  final yList = y.map((e) => e.toDouble()).toList();
  if (xList.length != yList.length) {
    throw ArgumentError('x and y must have equal length');
  }
  final n = xList.length;
  if (n < 2) return double.nan;
  final mx = _mean(xList);
  final my = _mean(yList);
  var ssX = 0.0;
  var ssY = 0.0;
  var ssXY = 0.0;
  for (var i = 0; i < n; i++) {
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
  final m = switch (data) {
    Matrix<num>() => data,
    Tensor<num>() => Matrix(data),
    _ => throw ArgumentError.value(
      data,
      'data',
      'Expected Matrix<num> or Tensor<num>',
    ),
  };

  final numRows = m.rowCount;
  final numCols = m.colCount;
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
      sum += rowVar ? m.get(j, i).toDouble() : m.get(i, j).toDouble();
    }
    final meanVal = sum / nSamples;
    for (var i = 0; i < nSamples; i++) {
      final val = rowVar ? m.get(j, i).toDouble() : m.get(i, j).toDouble();
      xc.set(i, j, val - meanVal);
    }
  }

  final scale = 1.0 / (nSamples - 1.0);
  return xc.syrk(transpose: true, alpha: scale);
}

Matrix<double> _pearsonCorrelationMatrix(dynamic data, {bool rowVar = false}) {
  final cov = _covarianceMatrix(data, rowVar: rowVar);
  final p = cov.rowCount;
  final std = List<double>.generate(p, (i) => math.sqrt(cov.get(i, i)));
  final corr = Matrix<double>.filled(p, p, 0.0, type: DataType.float64);
  for (var i = 0; i < p; i++) {
    corr.set(i, i, 1.0);
    for (var j = i + 1; j < p; j++) {
      final denom = std[i] * std[j];
      final r = denom > 0.0 ? (cov.get(i, j) / denom).clamp(-1.0, 1.0) : 0.0;
      corr.set(i, j, r);
      corr.set(j, i, r);
    }
  }
  return corr;
}

Matrix<double> _spearmanCorrelationMatrix(dynamic data, {bool rowVar = false}) {
  final m = switch (data) {
    Matrix<num>() => data,
    Tensor<num>() => Matrix(data),
    _ => throw ArgumentError.value(
      data,
      'data',
      'Expected Matrix<num> or Tensor<num>',
    ),
  };

  final numRows = m.rowCount;
  final numCols = m.colCount;
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
      (i) => rowVar ? m.get(j, i).toDouble() : m.get(i, j).toDouble(),
    );
    final ranks = rankData(colValues);
    for (var i = 0; i < nSamples; i++) {
      ranked.set(i, j, ranks[i]);
    }
  }

  return _pearsonCorrelationMatrix(ranked, rowVar: false);
}
