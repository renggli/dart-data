import 'dart:math' as math;
import 'dart:typed_data';

import '../acceleration/vforce/vforce.dart';
import '../linear/matrix.dart';
import '../linear/vector.dart';
import '../tensor/tensor.dart';
import '../type/data_type.dart';

/// Returns the arithmetic mean of [values], or [double.nan] if empty.
///
/// Conceptually, the mean is the standard average: the sum of all elements
/// divided by the count of observations. Formally, it computes the first sample
/// central moment $\bar{x} = \frac{1}{n} \sum_{i=1}^n x_i$.
///
/// ```dart
/// final avg = mean([1.0, 2.0, 3.0, 4.0, 5.0]); // 3.0
/// ```
double mean(Iterable<num> values) => _mean(values);

/// Returns the sample or population variance of [values].
///
/// Conceptually, variance measures how widely spread the values are around
/// their arithmetic mean. If all observations are identical, variance is 0.
/// Formally, it computes $s^2 = \frac{1}{n - 1} \sum_{i=1}^n (x_i - \bar{x})^2$
/// (or $\sigma^2 = \frac{1}{n} \sum (x_i - \bar{x})^2$ when [population] is
/// true) using Welford's numerically stable one-pass algorithm.
///
/// ```dart
/// final v = variance([2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]); // 4.5714...
/// ```
double variance(Iterable<num> values, {bool population = false}) =>
    _variance(values, population: population);

/// Returns the standard deviation of [values].
///
/// Conceptually, standard deviation is the square root of the variance,
/// expressing dispersion in the same units of measurement as the original data.
/// Formally, it computes $s = \sqrt{\operatorname{Var}(X)}$.
///
/// ```dart
/// final sd = standardDeviation([2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]);
/// ```
double standardDeviation(Iterable<num> values, {bool population = false}) =>
    _standardDeviation(values, population: population);

/// Returns the empirical quantile of [values] for fraction [quantile] in the
/// range `[0.0, 1.0]` using standard linear interpolation between adjacent
/// ranks (Type 7).
///
/// Conceptually, a quantile is a dividing threshold: for example, the 0.5
/// quantile is the median, and the 0.25 quantile is the lower quartile cutoff.
/// Formally, it computes $Q(p) = x_{(k)} + (p(n - 1) - k)(x_{(k+1)} - x_{(k)})$
/// where $k = \lfloor p(n - 1) \rfloor$ (Hyndman and Fan Type 7).
///
/// ```dart
/// final q = quantile([1.0, 2.0, 3.0, 4.0, 5.0], 0.5); // 3.0
/// ```
double quantile(Iterable<num> values, num quantile) =>
    _quantile(values, quantile);

/// Returns the median of [values].
///
/// Conceptually, the median is the middle value when data is sorted in
/// ascending order. Formally, it computes the 50th percentile / 0.5 quantile.
///
/// ```dart
/// final m = median([1.0, 3.0, 5.0]); // 3.0
/// ```
double median(Iterable<num> values) => _median(values);

/// Returns the interquartile range (IQR = Q3 - Q1) of [values].
///
/// Conceptually, the IQR is the distance between the 25th percentile and 75th
/// percentile, spanning the central 50% of the sample. Formally, it computes
/// $Q(0.75) - Q(0.25)$, providing a robust measure of statistical dispersion
/// unaffected by extreme outliers.
///
/// ```dart
/// final r = iqr([1.0, 2.0, 5.0, 6.0, 7.0, 9.0]);
/// ```
double iqr(Iterable<num> values) => _iqr(values);

/// Returns the sample skewness of [values].
///
/// Conceptually, skewness indicates distribution asymmetry: whether
/// observations lean to the left (negative skew, longer left tail) or to the
/// right (positive skew, longer right tail). Formally, it computes the
/// standardized 3rd central moment $g_1 = \frac{m_3}{m_2^{3/2}}$, with optional
/// sample bias correction $\frac{\sqrt{n(n-1)}}{n-2}$.
///
/// ```dart
/// final s = skewness([1.0, 2.0, 2.0, 3.0]);
/// ```
double skewness(Iterable<num> values, {bool bias = false}) =>
    _skewness(values, bias: bias);

/// Returns the kurtosis of [values]. If [excess] is true (default), returns
/// excess kurtosis (Fisher).
///
/// Conceptually, kurtosis measures tail heaviness and propensity toward
/// outliers relative to a normal distribution. Formally, it computes the
/// standardized 4th central moment $g_2 = \frac{m_4}{m_2^2} - 3$ (Fisher's
/// excess kurtosis, 0 for normal distribution).
///
/// ```dart
/// final k = kurtosis([1.0, 2.0, 3.0, 4.0, 5.0]);
/// ```
double kurtosis(
  Iterable<num> values, {
  bool excess = true,
  bool bias = false,
}) => _kurtosis(values, excess: excess, bias: bias);

/// Computes the sample or population covariance between [x] and [y].
///
/// Conceptually, covariance indicates whether two variables tend to increase
/// together (positive covariance) or vary inversely (negative covariance).
/// Formally, it computes
/// $\operatorname{Cov}(X, Y) =$
/// $\frac{1}{n - 1} \sum_{i=1}^n (x_i - \bar{x})(y_i - \bar{y})$
/// using a numerically stable two-variable Welford-style algorithm.
///
/// ```dart
/// final cov = covariance([1.0, 2.0, 3.0], [2.0, 4.0, 6.0]);
/// ```
double covariance(
  Iterable<num> x,
  Iterable<num> y, {
  bool population = false,
}) => _covariance(x, y, population: population);

/// Computes the Pearson correlation coefficient $r$ (in `[-1.0, 1.0]`) between
/// [x] and [y].
///
/// Conceptually, Pearson's $r$ measures the strength and direction of linear
/// association between two variables, where $+1$ represents a perfect positive
/// linear relationship, $-1$ represents a perfect negative linear relationship,
/// and $0$ indicates absence of linear correlation. Formally, it computes
/// $r = \frac{\operatorname{Cov}(X, Y)}{\sigma_X \sigma_Y}$
/// $\in \lbrack -1, 1 \rbrack$.
///
/// ```dart
/// final r = pearsonCorrelation([1.0, 2.0, 3.0], [2.0, 4.0, 6.0]); // 1.0
/// ```
double pearsonCorrelation(Iterable<num> x, Iterable<num> y) =>
    _pearsonCorrelation(x, y);

/// Returns fractional ranks of [values], handling ties by averaging ranks.
///
/// If any value in [values] is `NaN`, all ranks are returned as `double.nan`.
List<double> rankData(Iterable<num> values) {
  final list = values.map((value) => value.toDouble()).toList();
  final length = list.length;
  for (var i = 0; i < length; i++) {
    if (list[i].isNaN) {
      return List<double>.filled(length, double.nan);
    }
  }
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

/// Computes the Spearman rank correlation coefficient $\rho$ (in `[-1.0, 1.0]`)
/// between [x] and [y].
double spearmanCorrelation(Iterable<num> x, Iterable<num> y) =>
    _spearmanCorrelation(x, y);

/// Computes the sample covariance matrix of [data].
///
/// If [rowVar] is false (default), columns represent variables and rows
/// represent observations. If [rowVar] is true, rows represent variables and
/// columns represent observations.
///
/// Transparently uses [Matrix.syrk] BLAS acceleration for large matrix
/// multiplications.
Matrix<double> covarianceMatrix(Object data, {bool rowVar = false}) =>
    _covarianceMatrix(data, rowVar: rowVar);

/// Computes the Pearson correlation matrix of [data].
Matrix<double> pearsonCorrelationMatrix(Object data, {bool rowVar = false}) =>
    _pearsonCorrelationMatrix(data, rowVar: rowVar);

/// Computes the Spearman rank correlation matrix of [data].
Matrix<double> spearmanCorrelationMatrix(Object data, {bool rowVar = false}) =>
    _spearmanCorrelationMatrix(data, rowVar: rowVar);

/// Returns the weighted mean of [values] weighted by [weights].
double weightedMean(Iterable<num> values, Iterable<num> weights) =>
    _weightedMean(values, weights);

/// Returns the weighted variance of [values] weighted by [weights].
///
/// If [unbiased] is true (default), applies the Bessel reliability weights
/// correction:
/// $s_w^2 = \frac{\sum w_i}{\left(\sum w_i\right)^2 - \sum w_i^2}$
/// $\sum w_i (x_i - \bar{x}_w)^2$.
double weightedVariance(
  Iterable<num> values,
  Iterable<num> weights, {
  bool unbiased = true,
}) => _weightedVariance(values, weights, unbiased: unbiased);

/// Computes the simple moving average (SMA) of [values] over a rolling window
/// of [windowSize].
///
/// Returns a list of length `values.length - windowSize + 1` computed in
/// $\mathcal{O}(N)$ time using $\mathcal{O}(1)$ updates per step.
List<double> movingAverage(Iterable<num> values, int windowSize) =>
    _movingAverage(values, windowSize);

/// Computes the exponential moving average (EMA) of [values] with smoothing
/// factor [alpha] $\in (0, 1]$.
///
/// Returns a list of length `values.length` computed in $\mathcal{O}(N)$ time
/// with $\mathcal{O}(1)$ updates per step.
List<double> exponentialMovingAverage(Iterable<num> values, double alpha) =>
    _exponentialMovingAverage(values, alpha);

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

  /// Returns the empirical quantile for [quantile] in `[0.0, 1.0]`.
  double quantile(num quantile) => _quantile(this, quantile);

  /// Returns the interquartile range (IQR).
  double iqr() => _iqr(this);

  /// Returns the skewness of values.
  double skewness({bool bias = false}) => _skewness(this, bias: bias);

  /// Returns the kurtosis of values.
  double kurtosis({bool excess = true, bool bias = false}) =>
      _kurtosis(this, excess: excess, bias: bias);

  /// Returns the weighted mean of values using [weights].
  double weightedMean(Iterable<num> weights) => _weightedMean(this, weights);

  /// Returns the weighted variance of values using [weights].
  double weightedVariance(Iterable<num> weights, {bool unbiased = true}) =>
      _weightedVariance(this, weights, unbiased: unbiased);

  /// Computes the simple moving average (SMA) over a rolling window of
  /// [windowSize].
  List<double> movingAverage(int windowSize) =>
      _movingAverage(this, windowSize);

  /// Computes the exponential moving average (EMA) with smoothing factor
  /// [alpha].
  List<double> exponentialMovingAverage(double alpha) =>
      _exponentialMovingAverage(this, alpha);
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
  /// Returns the sum of vector elements.
  double sum() {
    final tData = tensor.data;
    if (tData is Float64List && tensor.layout.isContiguous && length >= 64) {
      final offset = tensor.layout.offset;
      final view = offset == 0 && tData.length == length
          ? tData
          : Float64List.sublistView(tData, offset, offset + length);
      return Vforce.sum(x: view);
    }
    var total = 0.0;
    for (var i = 0; i < length; i++) {
      total += this[i];
    }
    return total;
  }

  /// Returns the arithmetic mean of vector elements.
  double mean() {
    final tData = tensor.data;
    if (tData is Float64List && tensor.layout.isContiguous && length >= 64) {
      final offset = tensor.layout.offset;
      final view = offset == 0 && tData.length == length
          ? tData
          : Float64List.sublistView(tData, offset, offset + length);
      return Vforce.mean(x: view);
    }
    return _mean(toList());
  }

  /// Returns the variance of vector elements.
  double variance({bool population = false}) {
    final tData = tensor.data;
    if (tData is Float64List && tensor.layout.isContiguous && length >= 64) {
      final offset = tensor.layout.offset;
      final view = offset == 0 && tData.length == length
          ? tData
          : Float64List.sublistView(tData, offset, offset + length);
      return Vforce.variance(x: view, sample: !population);
    }
    return _variance(toList(), population: population);
  }

  /// Returns the standard deviation of vector elements.
  double standardDeviation({bool population = false}) =>
      math.sqrt(variance(population: population));

  /// Returns the median of vector elements.
  double median() => _median(toList());

  /// Returns the empirical quantile for [quantile] in `[0.0, 1.0]`.
  double quantile(num quantile) => _quantile(toList(), quantile);

  /// Returns the interquartile range (IQR).
  double iqr() => _iqr(toList());

  /// Returns the skewness of vector elements.
  double skewness({bool bias = false}) => _skewness(toList(), bias: bias);

  /// Returns the kurtosis of vector elements.
  double kurtosis({bool excess = true, bool bias = false}) =>
      _kurtosis(toList(), excess: excess, bias: bias);

  /// Returns the weighted mean of vector elements using [weights].
  double weightedMean(Vector<num> weights) =>
      _weightedMean(toList(), weights.toList());

  /// Returns the weighted variance of vector elements using [weights].
  double weightedVariance(Vector<num> weights, {bool unbiased = true}) =>
      _weightedVariance(toList(), weights.toList(), unbiased: unbiased);

  /// Computes the simple moving average (SMA) over a rolling window of
  /// [windowSize].
  Vector<double> movingAverage(int windowSize) => Vector<double>.fromList(
    _movingAverage(toList(), windowSize),
    type: DataType.float64,
  );

  /// Computes the exponential moving average (EMA) with smoothing factor
  /// [alpha].
  Vector<double> exponentialMovingAverage(double alpha) =>
      Vector<double>.fromList(
        _exponentialMovingAverage(toList(), alpha),
        type: DataType.float64,
      );

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

  /// Returns the empirical quantile for [quantile] in `[0.0, 1.0]`.
  double quantile(num quantile) => _quantile(values, quantile);

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
  double mean() => tensor.mean();

  /// Returns the variance of matrix elements.
  double variance({bool population = false}) =>
      tensor.variance(population: population);

  /// Returns the standard deviation of matrix elements.
  double standardDeviation({bool population = false}) =>
      tensor.standardDeviation(population: population);

  /// Returns the median of matrix elements.
  double median() => tensor.median();

  /// Returns the empirical quantile for [quantile] in `[0.0, 1.0]`.
  double quantile(num quantile) => tensor.quantile(quantile);

  /// Returns the interquartile range (IQR).
  double iqr() => tensor.iqr();

  /// Returns the skewness of matrix elements.
  double skewness({bool bias = false}) => tensor.skewness(bias: bias);

  /// Returns the kurtosis of matrix elements.
  double kurtosis({bool excess = true, bool bias = false}) =>
      tensor.kurtosis(excess: excess, bias: bias);

  /// Computes the covariance matrix.
  Matrix<double> covarianceMatrix({bool rowVar = false}) =>
      tensor.covarianceMatrix(rowVar: rowVar);

  /// Computes the Pearson correlation matrix.
  Matrix<double> pearsonCorrelationMatrix({bool rowVar = false}) =>
      tensor.pearsonCorrelationMatrix(rowVar: rowVar);

  /// Computes the Spearman rank correlation matrix.
  Matrix<double> spearmanCorrelationMatrix({bool rowVar = false}) =>
      tensor.spearmanCorrelationMatrix(rowVar: rowVar);
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
  final q = quantile.toDouble();
  if (q.isNaN || q < 0.0 || q > 1.0) {
    throw ArgumentError.value(
      quantile,
      'quantile',
      'Quantile must be between 0.0 and 1.0',
    );
  }
  final list = <double>[];
  for (final val in values) {
    final d = val.toDouble();
    if (d.isNaN) return double.nan;
    list.add(d);
  }
  if (list.isEmpty) return double.nan;
  list.sort();
  if (q <= 0.0) return list.first;
  if (q >= 1.0) return list.last;
  final idx = q * (list.length - 1);
  final baseIdx = idx.floor();
  final frac = idx - baseIdx;
  if (baseIdx >= list.length - 1) return list.last;
  return list[baseIdx] + frac * (list[baseIdx + 1] - list[baseIdx]);
}

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
  if (m2 == 0.0) return double.nan;
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
  if (m2 == 0.0) return double.nan;
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

Matrix<double> _covarianceMatrix(Object data, {bool rowVar = false}) {
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

Matrix<double> _pearsonCorrelationMatrix(Object data, {bool rowVar = false}) {
  final cov = _covarianceMatrix(data, rowVar: rowVar);
  final dim = cov.rowCount;
  final std = List<double>.generate(dim, (i) => math.sqrt(cov.get(i, i)));
  final corr = Matrix<double>.filled(dim, dim, 0.0, type: DataType.float64);
  for (var i = 0; i < dim; i++) {
    corr.set(i, i, std[i] > 0.0 ? 1.0 : double.nan);
    for (var j = i + 1; j < dim; j++) {
      final denom = std[i] * std[j];
      final correlation = denom > 0.0
          ? (cov.get(i, j) / denom).clamp(-1.0, 1.0)
          : double.nan;
      corr.set(i, j, correlation);
      corr.set(j, i, correlation);
    }
  }
  return corr;
}

Matrix<double> _spearmanCorrelationMatrix(Object data, {bool rowVar = false}) {
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

double _weightedMean(Iterable<num> values, Iterable<num> weights) {
  final valIter = values.iterator;
  final weightIter = weights.iterator;
  var sumWeighted = 0.0;
  var sumWeights = 0.0;

  while (valIter.moveNext()) {
    if (!weightIter.moveNext()) {
      throw ArgumentError('values and weights must have identical length.');
    }
    final w = weightIter.current.toDouble();
    if (w < 0.0) {
      throw ArgumentError('Weights must be non-negative: $w');
    }
    final x = valIter.current.toDouble();
    sumWeighted += w * x;
    sumWeights += w;
  }
  if (weightIter.moveNext()) {
    throw ArgumentError('values and weights must have identical length.');
  }
  return sumWeights > 0.0 ? sumWeighted / sumWeights : double.nan;
}

double _weightedVariance(
  Iterable<num> values,
  Iterable<num> weights, {
  bool unbiased = true,
}) {
  final valList = [for (final v in values) v.toDouble()];
  final weightList = [for (final w in weights) w.toDouble()];
  if (valList.length != weightList.length) {
    throw ArgumentError('values and weights must have identical length.');
  }
  final n = valList.length;
  if (n == 0) return double.nan;

  var v1 = 0.0;
  var v2 = 0.0;
  var sumWeighted = 0.0;
  for (var i = 0; i < n; i++) {
    final w = weightList[i];
    if (w < 0.0) {
      throw ArgumentError('Weights must be non-negative: $w');
    }
    v1 += w;
    v2 += w * w;
    sumWeighted += w * valList[i];
  }

  if (v1 <= 0.0) return double.nan;
  final meanW = sumWeighted / v1;

  var ssW = 0.0;
  for (var i = 0; i < n; i++) {
    final diff = valList[i] - meanW;
    ssW += weightList[i] * diff * diff;
  }

  if (!unbiased) {
    return ssW / v1;
  }
  final denom = v1 - (v2 / v1);
  return denom > 0.0 ? ssW / denom : double.nan;
}

List<double> _movingAverage(Iterable<num> values, int windowSize) {
  if (windowSize <= 0) {
    throw ArgumentError('windowSize must be positive: $windowSize');
  }
  final list = [for (final v in values) v.toDouble()];
  final n = list.length;
  if (windowSize > n) {
    throw ArgumentError(
      'windowSize ($windowSize) cannot exceed values length ($n)',
    );
  }

  final result = List<double>.filled(n - windowSize + 1, 0.0);
  var sum = 0.0;
  for (var i = 0; i < windowSize; i++) {
    sum += list[i];
  }
  result[0] = sum / windowSize;

  for (var i = windowSize; i < n; i++) {
    sum += list[i] - list[i - windowSize];
    result[i - windowSize + 1] = sum / windowSize;
  }
  return result;
}

List<double> _exponentialMovingAverage(Iterable<num> values, double alpha) {
  if (alpha <= 0.0 || alpha > 1.0) {
    throw ArgumentError('Smoothing factor alpha must be in (0, 1]: $alpha');
  }
  final list = [for (final v in values) v.toDouble()];
  final n = list.length;
  if (n == 0) return <double>[];

  final result = List<double>.filled(n, 0.0);
  var s = list[0];
  result[0] = s;

  final oneMinusAlpha = 1.0 - alpha;
  for (var i = 1; i < n; i++) {
    s = alpha * list[i] + oneMinusAlpha * s;
    result[i] = s;
  }
  return result;
}
