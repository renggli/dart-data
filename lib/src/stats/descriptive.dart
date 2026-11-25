import 'dart:math' as math;
import 'dart:typed_data';

import '../acceleration/vforce/vforce.dart';
import '../linear/matrix.dart';
import '../linear/vector.dart';
import '../tensor/tensor.dart';
import '../type/data_type.dart';

/// Scale factor converting median absolute deviation (MAD) to a consistent
/// estimator of standard deviation for normally distributed data:
/// `1 / inverseNormalCDF(0.75)`.
const double _madNormalScale = 1.482602218505602;

/// Returns the arithmetic mean of [values], or [double.nan] if empty.
///
/// Computes the first sample moment `x_bar = (1 / n) * sum(x_i)`.
///
/// ```dart
/// final avg = mean([1.0, 2.0, 3.0, 4.0, 5.0]); // 3.0
/// ```
double mean(Iterable<num> values) => _mean(values);

/// Returns the geometric mean of non-negative [values].
///
/// Evaluates `exp((1 / n) * sum(ln(x_i)))` in log space to prevent
/// intermediate overflow or underflow. Returns `0.0` if any element is zero
/// (unless `+infinity` is also present, which returns [double.nan]), returns
/// [double.infinity] if any element is positive infinity and all others are
/// strictly positive, and returns [double.nan] if [values] is empty or contains
/// any negative value or `NaN`.
///
/// ```dart
/// final gm = geometricMean([2.0, 8.0]); // 4.0
/// ```
double geometricMean(Iterable<num> values) => _geometricMean(values);

/// Returns the harmonic mean of non-negative [values].
///
/// Evaluates `n / sum(1 / x_i)`. Returns `0.0` if any element is zero and all
/// remaining elements are non-negative, returns [double.infinity] if all
/// elements are positive infinity, and returns [double.nan] if [values] is
/// empty or contains any negative value or `NaN`.
///
/// ```dart
/// final hm = harmonicMean([2.5, 3.0, 10.0]); // 3.6
/// ```
double harmonicMean(Iterable<num> values) => _harmonicMean(values);

/// Returns the sample or population variance of [values].
///
/// Computes `s^2 = sum((x_i - x_bar)^2) / (n - 1)` (or divided by `n` when
/// [population] is true) using Welford's single-pass algorithm. Returns
/// [double.nan] if [values] contains fewer elements than required (`2` for
/// sample variance, `1` for population variance).
///
/// ```dart
/// final v = variance([2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]);
/// ```
double variance(Iterable<num> values, {bool population = false}) =>
    _variance(values, population: population);

/// Returns the sample or population standard deviation of [values].
///
/// Evaluates `sqrt(variance(values, population: population))`.
///
/// ```dart
/// final sd = standardDeviation([2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]);
/// ```
double standardDeviation(Iterable<num> values, {bool population = false}) =>
    _standardDeviation(values, population: population);

/// Returns the empirical quantile of [values] for probability [quantile] in
/// `[0.0, 1.0]` using linear interpolation between order statistics (Type 7).
///
/// Evaluates `Q(p) = x_(k) + (p * (n - 1) - k) * (x_(k+1) - x_(k))` where
/// `k = floor(p * (n - 1))`. Returns [double.nan] if [values] is empty or
/// contains `NaN`, and throws [ArgumentError] if [quantile] is outside
/// `[0.0, 1.0]`.
///
/// ```dart
/// final q = quantile([1.0, 2.0, 3.0, 4.0, 5.0], 0.5); // 3.0
/// ```
double quantile(Iterable<num> values, num quantile) =>
    _quantile(values, quantile);

/// Returns the empirical quantiles of [values] for each probability in
/// [probabilities], sorting [values] once in `O(n log n + k)` time.
///
/// Every probability must lie in `[0.0, 1.0]`; otherwise throws [ArgumentError].
/// Returns [double.nan] entries if [values] is empty or contains `NaN`.
List<double> quantiles(Iterable<num> values, Iterable<num> probabilities) =>
    _quantiles(values, probabilities);

/// Returns the median (0.5 quantile) of [values], or [double.nan] if empty or
/// containing `NaN`.
///
/// ```dart
/// final m = median([1.0, 3.0, 5.0]); // 3.0
/// ```
double median(Iterable<num> values) => _median(values);

/// Returns the interquartile range (`Q(0.75) - Q(0.25)`) of [values].
///
/// ```dart
/// final r = iqr([1.0, 2.0, 5.0, 6.0, 7.0, 9.0]);
/// ```
double iqr(Iterable<num> values) => _iqr(values);

/// Returns the median absolute deviation `median(|x_i - median(x)|)` of
/// [values].
///
/// If [scale] is true, multiplies by `1.482602218505602` (`1 / Phi^-1(0.75)`)
/// so the estimator is consistent for standard deviation under normality.
/// Returns [double.nan] if [values] is empty, contains `NaN`, or has a
/// non-finite median.
///
/// ```dart
/// final m = medianAbsoluteDeviation([1.0, 1.0, 2.0, 2.0, 4.0, 6.0, 9.0]);
/// ```
double medianAbsoluteDeviation(Iterable<num> values, {bool scale = false}) =>
    _medianAbsoluteDeviation(values, scale: scale);

/// Returns the skewness of [values].
///
/// Evaluates the standardized 3rd central moment using scale-normalized central
/// differences to prevent overflow or underflow on extreme magnitudes. Applies
/// the adjusted Fisher-Pearson bias correction `sqrt(n * (n - 1)) / (n - 2)`
/// when [bias] is false (default). Returns [double.nan] when sample size is
/// insufficient (`< 3` unbiased, `< 2` biased), variance is zero, or inputs
/// are non-finite.
///
/// ```dart
/// final s = skewness([1.0, 2.0, 2.0, 3.0]);
/// ```
double skewness(Iterable<num> values, {bool bias = false}) =>
    _skewness(values, bias: bias);

/// Returns the kurtosis of [values]. If [excess] is true (default), returns
/// excess kurtosis (Fisher, 0 for normal distributions).
///
/// Uses scale-normalized 2nd and 4th central moments and applies the sample
/// bias correction when [bias] is false (default). Returns [double.nan] when
/// sample size is insufficient (`< 4` unbiased, `< 2` biased), variance is
/// zero, or inputs are non-finite.
///
/// ```dart
/// final k = kurtosis([1.0, 2.0, 3.0, 4.0, 5.0]);
/// ```
double kurtosis(
  Iterable<num> values, {
  bool excess = true,
  bool bias = false,
}) => _kurtosis(values, excess: excess, bias: bias);

/// Computes the sample or population covariance between [x] and [y] in a
/// single pass using Welford's co-moment recurrence.
///
/// Throws [ArgumentError] if [x] and [y] have different lengths. Returns
/// [double.nan] if sample size is `< 2` (or `< 1` when [population] is true).
///
/// ```dart
/// final cov = covariance([1.0, 2.0, 3.0], [2.0, 4.0, 6.0]);
/// ```
double covariance(
  Iterable<num> x,
  Iterable<num> y, {
  bool population = false,
}) => _covariance(x, y, population: population);

/// Computes the Pearson correlation coefficient `r` in `[-1.0, 1.0]` between
/// [x] and [y] in a single pass.
///
/// Throws [ArgumentError] if [x] and [y] have different lengths. Returns
/// [double.nan] if fewer than 2 elements are provided, either variable has zero
/// variance, or any element is `NaN`.
///
/// ```dart
/// final r = pearsonCorrelation([1.0, 2.0, 3.0], [2.0, 4.0, 6.0]); // 1.0
/// ```
double pearsonCorrelation(Iterable<num> x, Iterable<num> y) =>
    _pearsonCorrelation(x, y);

/// Returns 1-based fractional ranks of [values], averaging ranks for ties.
///
/// If any value in [values] is `NaN`, all ranks are returned as [double.nan].
List<double> rankData(Iterable<num> values) {
  final list = values.map((value) => value.toDouble()).toList();
  final length = list.length;
  for (var i = 0; i < length; i++) {
    if (list[i].isNaN) {
      return List<double>.filled(length, double.nan);
    }
  }
  final indices = List<int>.generate(length, (i) => i)
    ..sort((a, b) => list[a].compareTo(list[b]));
  final ranks = List<double>.filled(length, 0.0);
  var i = 0;
  while (i < length) {
    var j = i;
    while (j + 1 < length && list[indices[j + 1]] == list[indices[i]]) {
      j++;
    }
    final avgRank = 1.0 + 0.5 * (i + j);
    for (var k = i; k <= j; k++) {
      ranks[indices[k]] = avgRank;
    }
    i = j + 1;
  }
  return ranks;
}

/// Computes the Spearman rank correlation coefficient `rho` in `[-1.0, 1.0]`
/// between [x] and [y].
///
/// Throws [ArgumentError] if [x] and [y] have different lengths. Returns
/// [double.nan] when fewer than 2 elements exist, either variable is constant,
/// or either contains `NaN`.
double spearmanCorrelation(Iterable<num> x, Iterable<num> y) =>
    _spearmanCorrelation(x, y);

/// Computes Kendall's rank correlation coefficient `tau-b` in `[-1.0, 1.0]`
/// between [x] and [y] in `O(n log n)` time with exact tie handling.
///
/// Throws [ArgumentError] if [x] and [y] have different lengths. Returns
/// [double.nan] if fewer than 2 pairs exist, either variable is constant, or
/// any value is `NaN`.
///
/// ```dart
/// final tau = kendallCorrelation([1.0, 2.0, 3.0], [2.0, 1.0, 3.0]);
/// ```
double kendallCorrelation(Iterable<num> x, Iterable<num> y) =>
    _kendallCorrelation(x, y);

/// Computes the covariance matrix of [data].
///
/// If [rowVar] is false (default), columns represent variables and rows
/// represent observations. If [rowVar] is true, rows represent variables and
/// columns represent observations. If [population] is true, normalizes by `n`
/// instead of `n - 1`.
///
/// Uses [Matrix.syrk] BLAS acceleration for `Xc^T * Xc`.
Matrix<double> covarianceMatrix(
  Matrix<num> data, {
  bool rowVar = false,
  bool population = false,
}) => _covarianceMatrix(data, rowVar: rowVar, population: population);

/// Computes the Pearson correlation matrix of [data].
///
/// Diagonal entries are `1.0` for variables with positive variance and
/// [double.nan] for constant or non-finite variables.
Matrix<double> pearsonCorrelationMatrix(
  Matrix<num> data, {
  bool rowVar = false,
}) => _pearsonCorrelationMatrix(data, rowVar: rowVar);

/// Computes the Spearman rank correlation matrix of [data].
Matrix<double> spearmanCorrelationMatrix(
  Matrix<num> data, {
  bool rowVar = false,
}) => _spearmanCorrelationMatrix(data, rowVar: rowVar);

/// Computes the Kendall rank correlation matrix (`tau-b`) of [data].
Matrix<double> kendallCorrelationMatrix(
  Matrix<num> data, {
  bool rowVar = false,
}) => _kendallCorrelationMatrix(data, rowVar: rowVar);

/// Returns the weighted mean of [values] weighted by non-negative finite
/// [weights].
///
/// Throws [ArgumentError] if lengths differ or if any weight is negative or
/// non-finite. Returns [double.nan] if weights sum to zero.
double weightedMean(Iterable<num> values, Iterable<num> weights) =>
    _weightedMean(values, weights);

/// Returns the weighted variance of [values] weighted by non-negative finite
/// [weights].
///
/// If [unbiased] is true (default), applies Bessel reliability-weights
/// correction `V1 / (V1^2 - V2) * sum(w_i * (x_i - x_w)^2)` with max-weight
/// normalization to prevent intermediate overflow or underflow.
double weightedVariance(
  Iterable<num> values,
  Iterable<num> weights, {
  bool unbiased = true,
}) => _weightedVariance(values, weights, unbiased: unbiased);

/// Returns the weighted standard deviation of [values] weighted by [weights].
double weightedStandardDeviation(
  Iterable<num> values,
  Iterable<num> weights, {
  bool unbiased = true,
}) => _weightedStandardDeviation(values, weights, unbiased: unbiased);

/// Computes the simple moving average (SMA) of [values] over a rolling window
/// of [windowSize] in amortized `O(N)` time.
///
/// Throws [ArgumentError] if [windowSize] is non-positive or exceeds the number
/// of elements in [values].
List<double> movingAverage(Iterable<num> values, int windowSize) =>
    _movingAverage(values, windowSize);

/// Computes the exponential moving average (EMA) of [values] with smoothing
/// factor [alpha] in `(0, 1]` in `O(N)` time.
///
/// Throws [ArgumentError] if [alpha] is not finite in `(0, 1]`.
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
  double geometricMean() => _geometricMean(this);

  /// Returns the harmonic mean of values.
  double harmonicMean() => _harmonicMean(this);

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

  /// Returns empirical quantiles for [probabilities] in `[0.0, 1.0]`.
  List<double> quantiles(Iterable<num> probabilities) =>
      _quantiles(this, probabilities);

  /// Returns the interquartile range (IQR).
  double iqr() => _iqr(this);

  /// Returns the median absolute deviation (MAD).
  double medianAbsoluteDeviation({bool scale = false}) =>
      _medianAbsoluteDeviation(this, scale: scale);

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

  /// Returns the weighted standard deviation of values using [weights].
  double weightedStandardDeviation(
    Iterable<num> weights, {
    bool unbiased = true,
  }) => _weightedStandardDeviation(this, weights, unbiased: unbiased);

  /// Computes the simple moving average (SMA) over [windowSize].
  List<double> movingAverage(int windowSize) =>
      _movingAverage(this, windowSize);

  /// Computes the exponential moving average (EMA) with factor [alpha].
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
    return _mean(values);
  }

  /// Returns the geometric mean of vector elements.
  double geometricMean() => _geometricMean(values);

  /// Returns the harmonic mean of vector elements.
  double harmonicMean() => _harmonicMean(values);

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
    return _variance(values, population: population);
  }

  /// Returns the standard deviation of vector elements.
  double standardDeviation({bool population = false}) =>
      math.sqrt(variance(population: population));

  /// Returns the median of vector elements.
  double median() => _median(values);

  /// Returns the empirical quantile for [quantile] in `[0.0, 1.0]`.
  double quantile(num quantile) => _quantile(values, quantile);

  /// Returns empirical quantiles for [probabilities] in `[0.0, 1.0]`.
  List<double> quantiles(Iterable<num> probabilities) =>
      _quantiles(values, probabilities);

  /// Returns the interquartile range (IQR).
  double iqr() => _iqr(values);

  /// Returns the median absolute deviation (MAD).
  double medianAbsoluteDeviation({bool scale = false}) =>
      _medianAbsoluteDeviation(values, scale: scale);

  /// Returns the skewness of vector elements.
  double skewness({bool bias = false}) => _skewness(values, bias: bias);

  /// Returns the kurtosis of vector elements.
  double kurtosis({bool excess = true, bool bias = false}) =>
      _kurtosis(values, excess: excess, bias: bias);

  /// Returns the weighted mean of vector elements using [weights].
  double weightedMean(Vector<num> weights) =>
      _weightedMean(values, weights.values);

  /// Returns the weighted variance of vector elements using [weights].
  double weightedVariance(Vector<num> weights, {bool unbiased = true}) =>
      _weightedVariance(values, weights.values, unbiased: unbiased);

  /// Returns the weighted standard deviation of vector elements using [weights].
  double weightedStandardDeviation(
    Vector<num> weights, {
    bool unbiased = true,
  }) => _weightedStandardDeviation(values, weights.values, unbiased: unbiased);

  /// Computes the simple moving average (SMA) over [windowSize].
  Vector<double> movingAverage(int windowSize) => Vector<double>.fromList(
    _movingAverage(values, windowSize),
    type: DataType.float64,
  );

  /// Computes the exponential moving average (EMA) with factor [alpha].
  Vector<double> exponentialMovingAverage(double alpha) =>
      Vector<double>.fromList(
        _exponentialMovingAverage(values, alpha),
        type: DataType.float64,
      );

  /// Computes the sample or population covariance with [other].
  double covariance(Vector<num> other, {bool population = false}) =>
      _covariance(values, other.values, population: population);

  /// Computes the Pearson correlation coefficient with [other].
  double pearsonCorrelation(Vector<num> other) =>
      _pearsonCorrelation(values, other.values);

  /// Computes the Spearman rank correlation coefficient with [other].
  double spearmanCorrelation(Vector<num> other) =>
      _spearmanCorrelation(values, other.values);

  /// Computes Kendall's rank correlation coefficient with [other].
  double kendallCorrelation(Vector<num> other) =>
      _kendallCorrelation(values, other.values);
}

/// Statistics extensions on [Tensor<num>].
extension DescriptiveTensorNumExtension on Tensor<num> {
  /// Returns the arithmetic mean of tensor elements.
  double mean() => _mean(values);

  /// Returns the geometric mean of tensor elements.
  double geometricMean() => _geometricMean(values);

  /// Returns the harmonic mean of tensor elements.
  double harmonicMean() => _harmonicMean(values);

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

  /// Returns empirical quantiles for [probabilities] in `[0.0, 1.0]`.
  List<double> quantiles(Iterable<num> probabilities) =>
      _quantiles(values, probabilities);

  /// Returns the interquartile range (IQR).
  double iqr() => _iqr(values);

  /// Returns the median absolute deviation (MAD).
  double medianAbsoluteDeviation({bool scale = false}) =>
      _medianAbsoluteDeviation(values, scale: scale);

  /// Returns the skewness of tensor elements.
  double skewness({bool bias = false}) => _skewness(values, bias: bias);

  /// Returns the kurtosis of tensor elements.
  double kurtosis({bool excess = true, bool bias = false}) =>
      _kurtosis(values, excess: excess, bias: bias);

  /// Computes the covariance matrix of a rank-2 tensor.
  Matrix<double> covarianceMatrix({
    bool rowVar = false,
    bool population = false,
  }) {
    if (rank != 2) {
      throw ArgumentError.value(rank, 'rank', 'Expected rank-2 tensor');
    }
    return _covarianceMatrix(
      Matrix(this),
      rowVar: rowVar,
      population: population,
    );
  }

  /// Computes the Pearson correlation matrix of a rank-2 tensor.
  Matrix<double> pearsonCorrelationMatrix({bool rowVar = false}) {
    if (rank != 2) {
      throw ArgumentError.value(rank, 'rank', 'Expected rank-2 tensor');
    }
    return _pearsonCorrelationMatrix(Matrix(this), rowVar: rowVar);
  }

  /// Computes the Spearman rank correlation matrix of a rank-2 tensor.
  Matrix<double> spearmanCorrelationMatrix({bool rowVar = false}) {
    if (rank != 2) {
      throw ArgumentError.value(rank, 'rank', 'Expected rank-2 tensor');
    }
    return _spearmanCorrelationMatrix(Matrix(this), rowVar: rowVar);
  }

  /// Computes Kendall's rank correlation matrix of a rank-2 tensor.
  Matrix<double> kendallCorrelationMatrix({bool rowVar = false}) {
    if (rank != 2) {
      throw ArgumentError.value(rank, 'rank', 'Expected rank-2 tensor');
    }
    return _kendallCorrelationMatrix(Matrix(this), rowVar: rowVar);
  }
}

/// Statistics extensions on [Matrix<num>].
extension DescriptiveMatrixNumExtension on Matrix<num> {
  /// Returns the arithmetic mean of matrix elements.
  double mean() => tensor.mean();

  /// Returns the geometric mean of matrix elements.
  double geometricMean() => tensor.geometricMean();

  /// Returns the harmonic mean of matrix elements.
  double harmonicMean() => tensor.harmonicMean();

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

  /// Returns empirical quantiles for [probabilities] in `[0.0, 1.0]`.
  List<double> quantiles(Iterable<num> probabilities) =>
      tensor.quantiles(probabilities);

  /// Returns the interquartile range (IQR).
  double iqr() => tensor.iqr();

  /// Returns the median absolute deviation (MAD).
  double medianAbsoluteDeviation({bool scale = false}) =>
      tensor.medianAbsoluteDeviation(scale: scale);

  /// Returns the skewness of matrix elements.
  double skewness({bool bias = false}) => tensor.skewness(bias: bias);

  /// Returns the kurtosis of matrix elements.
  double kurtosis({bool excess = true, bool bias = false}) =>
      tensor.kurtosis(excess: excess, bias: bias);

  /// Computes the covariance matrix.
  Matrix<double> covarianceMatrix({
    bool rowVar = false,
    bool population = false,
  }) => tensor.covarianceMatrix(rowVar: rowVar, population: population);

  /// Computes the Pearson correlation matrix.
  Matrix<double> pearsonCorrelationMatrix({bool rowVar = false}) =>
      tensor.pearsonCorrelationMatrix(rowVar: rowVar);

  /// Computes the Spearman rank correlation matrix.
  Matrix<double> spearmanCorrelationMatrix({bool rowVar = false}) =>
      tensor.spearmanCorrelationMatrix(rowVar: rowVar);

  /// Computes Kendall's rank correlation matrix.
  Matrix<double> kendallCorrelationMatrix({bool rowVar = false}) =>
      tensor.kendallCorrelationMatrix(rowVar: rowVar);
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

double _geometricMean(Iterable<num> values) {
  var count = 0;
  var logSum = 0.0;
  var hasZero = false;
  var hasInfinity = false;
  for (final val in values) {
    final d = val.toDouble();
    if (d.isNaN || d < 0.0) return double.nan;
    count++;
    if (d == 0.0) {
      hasZero = true;
    } else if (d == double.infinity) {
      hasInfinity = true;
    } else {
      logSum += math.log(d);
    }
  }
  if (count == 0 || (hasZero && hasInfinity)) return double.nan;
  if (hasZero) return 0.0;
  if (hasInfinity) return double.infinity;
  return math.exp(logSum / count);
}

double _harmonicMean(Iterable<num> values) {
  var count = 0;
  var sumRecip = 0.0;
  var hasZero = false;
  for (final val in values) {
    final d = val.toDouble();
    if (d.isNaN || d < 0.0) return double.nan;
    count++;
    if (d == 0.0) {
      hasZero = true;
    } else {
      sumRecip += 1.0 / d;
    }
  }
  if (count == 0) return double.nan;
  if (hasZero) return 0.0;
  return sumRecip == 0.0 ? double.infinity : count / sumRecip;
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

double _quantileFromSorted(List<double> sorted, double q) {
  if (q <= 0.0) return sorted.first;
  if (q >= 1.0) return sorted.last;
  final idx = q * (sorted.length - 1);
  final baseIdx = idx.floor();
  final frac = idx - baseIdx;
  if (baseIdx >= sorted.length - 1) return sorted.last;
  return sorted[baseIdx] + frac * (sorted[baseIdx + 1] - sorted[baseIdx]);
}

List<double>? _sortedDoublesOrNull(Iterable<num> values) {
  final list = <double>[];
  for (final val in values) {
    final d = val.toDouble();
    if (d.isNaN) return null;
    list.add(d);
  }
  if (list.isEmpty) return null;
  list.sort();
  return list;
}

double _quantile(Iterable<num> values, num quantile) {
  final q = quantile.toDouble();
  if (!(q >= 0.0 && q <= 1.0)) {
    throw ArgumentError.value(
      quantile,
      'quantile',
      'Quantile must be between 0.0 and 1.0',
    );
  }
  final sorted = _sortedDoublesOrNull(values);
  return sorted == null ? double.nan : _quantileFromSorted(sorted, q);
}

List<double> _quantiles(Iterable<num> values, Iterable<num> probabilities) {
  final probs = <double>[];
  for (final p in probabilities) {
    final pd = p.toDouble();
    if (!(pd >= 0.0 && pd <= 1.0)) {
      throw ArgumentError.value(
        p,
        'probabilities',
        'Every probability must be between 0.0 and 1.0',
      );
    }
    probs.add(pd);
  }
  if (probs.isEmpty) return <double>[];
  final sorted = _sortedDoublesOrNull(values);
  if (sorted == null) {
    return List<double>.filled(probs.length, double.nan);
  }
  return [for (final p in probs) _quantileFromSorted(sorted, p)];
}

double _median(Iterable<num> values) {
  final sorted = _sortedDoublesOrNull(values);
  return sorted == null ? double.nan : _quantileFromSorted(sorted, 0.5);
}

double _iqr(Iterable<num> values) {
  final sorted = _sortedDoublesOrNull(values);
  if (sorted == null) return double.nan;
  return _quantileFromSorted(sorted, 0.75) - _quantileFromSorted(sorted, 0.25);
}

double _medianAbsoluteDeviation(Iterable<num> values, {bool scale = false}) {
  final sorted = _sortedDoublesOrNull(values);
  if (sorted == null) return double.nan;
  final med = _quantileFromSorted(sorted, 0.5);
  if (!med.isFinite) return double.nan;
  final absDevs = [for (final v in sorted) (v - med).abs()]..sort();
  final mad = _quantileFromSorted(absDevs, 0.5);
  return scale ? mad * _madNormalScale : mad;
}

({int count, double m2, double m3, double m4})? _scaledCentralMoments(
  Iterable<num> values,
) {
  final list = [for (final v in values) v.toDouble()];
  final length = list.length;
  if (length < 2) return null;
  var meanVal = 0.0;
  for (var i = 0; i < length; i++) {
    final v = list[i];
    if (!v.isFinite) return null;
    meanVal += (v - meanVal) / (i + 1);
  }
  var maxAbsDiff = 0.0;
  for (var i = 0; i < length; i++) {
    final ad = (list[i] - meanVal).abs();
    if (ad > maxAbsDiff) maxAbsDiff = ad;
  }
  if (maxAbsDiff == 0.0 || !maxAbsDiff.isFinite) return null;

  final invScale = 1.0 / maxAbsDiff;
  var s2 = 0.0;
  var s3 = 0.0;
  var s4 = 0.0;
  for (var i = 0; i < length; i++) {
    final d = (list[i] - meanVal) * invScale;
    final d2 = d * d;
    s2 += d2;
    s3 += d2 * d;
    s4 += d2 * d2;
  }
  return (count: length, m2: s2 / length, m3: s3 / length, m4: s4 / length);
}

double _skewness(Iterable<num> values, {bool bias = false}) {
  final moments = _scaledCentralMoments(values);
  if (moments == null) return double.nan;
  final n = moments.count;
  if (n < 3 && !bias) return double.nan;
  if (moments.m2 <= 0.0) return double.nan;
  final g1 = moments.m3 / math.pow(moments.m2, 1.5);
  if (bias) return g1;
  return (math.sqrt(n * (n - 1.0)) / (n - 2.0)) * g1;
}

double _kurtosis(
  Iterable<num> values, {
  bool excess = true,
  bool bias = false,
}) {
  final moments = _scaledCentralMoments(values);
  if (moments == null) return double.nan;
  final n = moments.count;
  if (n < 4 && !bias) return double.nan;
  if (moments.m2 <= 0.0) return double.nan;
  final kurtosisVal = moments.m4 / (moments.m2 * moments.m2);
  if (bias) {
    return excess ? kurtosisVal - 3.0 : kurtosisVal;
  }
  final factor1 = (n - 1.0) / ((n - 2.0) * (n - 3.0));
  final factor2 = (n + 1.0) * kurtosisVal - 3.0 * (n - 1.0);
  final excessK = factor1 * factor2;
  return excess ? excessK : excessK + 3.0;
}

double _covariance(
  Iterable<num> x,
  Iterable<num> y, {
  bool population = false,
}) {
  final xIter = x.iterator;
  final yIter = y.iterator;
  var count = 0;
  var mx = 0.0;
  var my = 0.0;
  var cxy = 0.0;
  while (xIter.moveNext()) {
    if (!yIter.moveNext()) {
      throw ArgumentError('x and y must have equal length');
    }
    final xv = xIter.current.toDouble();
    final yv = yIter.current.toDouble();
    count++;
    final dx = xv - mx;
    mx += dx / count;
    my += (yv - my) / count;
    cxy += dx * (yv - my);
  }
  if (yIter.moveNext()) {
    throw ArgumentError('x and y must have equal length');
  }
  final divisor = population ? count : count - 1;
  return divisor < 1 ? double.nan : cxy / divisor;
}

double _pearsonCorrelation(Iterable<num> x, Iterable<num> y) {
  final xIter = x.iterator;
  final yIter = y.iterator;
  var count = 0;
  var scaleX = 0.0;
  var scaleY = 0.0;
  var mx = 0.0;
  var my = 0.0;
  var m2x = 0.0;
  var m2y = 0.0;
  var cxy = 0.0;
  var hasNonFinite = false;
  while (xIter.moveNext()) {
    if (!yIter.moveNext()) {
      throw ArgumentError('x and y must have equal length');
    }
    final xv = xIter.current.toDouble();
    final yv = yIter.current.toDouble();
    count++;
    if (!xv.isFinite || !yv.isFinite) {
      hasNonFinite = true;
      continue;
    }
    final ax = xv.abs();
    if (ax > scaleX) {
      if (scaleX > 0.0) {
        final rx = scaleX / ax;
        mx *= rx;
        m2x *= rx * rx;
        cxy *= rx;
      }
      scaleX = ax;
    }
    final ay = yv.abs();
    if (ay > scaleY) {
      if (scaleY > 0.0) {
        final ry = scaleY / ay;
        my *= ry;
        m2y *= ry * ry;
        cxy *= ry;
      }
      scaleY = ay;
    }
    final sx = scaleX > 0.0 ? xv / scaleX : 0.0;
    final sy = scaleY > 0.0 ? yv / scaleY : 0.0;
    final dx = sx - mx;
    final dy = sy - my;
    mx += dx / count;
    my += dy / count;
    final dx2 = sx - mx;
    final dy2 = sy - my;
    m2x += dx * dx2;
    m2y += dy * dy2;
    cxy += dx * dy2;
  }
  if (yIter.moveNext()) {
    throw ArgumentError('x and y must have equal length');
  }
  if (hasNonFinite || count < 2 || m2x <= 0.0 || m2y <= 0.0) {
    return double.nan;
  }
  final denom = math.sqrt(m2x) * math.sqrt(m2y);
  if (denom <= 0.0 || denom.isNaN) return double.nan;
  return (cxy / denom).clamp(-1.0, 1.0);
}

double _spearmanCorrelation(Iterable<num> x, Iterable<num> y) =>
    _pearsonCorrelation(rankData(x), rankData(y));

double _kendallCorrelation(Iterable<num> x, Iterable<num> y) {
  final xList = [for (final v in x) v.toDouble()];
  final yList = [for (final v in y) v.toDouble()];
  final n = xList.length;
  if (n != yList.length) {
    throw ArgumentError('x and y must have equal length');
  }
  if (n < 2) return double.nan;
  for (var i = 0; i < n; i++) {
    if (xList[i].isNaN || yList[i].isNaN) return double.nan;
  }

  final indices = List<int>.generate(n, (i) => i)
    ..sort((a, b) {
      final cmp = xList[a].compareTo(xList[b]);
      return cmp != 0 ? cmp : yList[a].compareTo(yList[b]);
    });

  // Count ties in x and joint ties in (x, y).
  var xTies = 0.0;
  var xyTies = 0.0;
  var runX = 1;
  var runXY = 1;
  for (var i = 1; i < n; i++) {
    final prev = indices[i - 1];
    final curr = indices[i];
    if (xList[curr] == xList[prev]) {
      runX++;
      if (yList[curr] == yList[prev]) {
        runXY++;
      } else {
        xyTies += 0.5 * runXY * (runXY - 1);
        runXY = 1;
      }
    } else {
      xTies += 0.5 * runX * (runX - 1);
      xyTies += 0.5 * runXY * (runXY - 1);
      runX = 1;
      runXY = 1;
    }
  }
  xTies += 0.5 * runX * (runX - 1);
  xyTies += 0.5 * runXY * (runXY - 1);

  // Extract y values in (x, y)-sorted order and count inversions via merge sort.
  final yOrdered = List<double>.generate(n, (i) => yList[indices[i]]);
  final aux = List<double>.filled(n, 0.0);
  final swaps = _countInversions(yOrdered, aux, 0, n);

  // yOrdered is now sorted ascending; count ties in y in one linear scan.
  var yTies = 0.0;
  var runY = 1;
  for (var i = 1; i < n; i++) {
    if (yOrdered[i] == yOrdered[i - 1]) {
      runY++;
    } else {
      yTies += 0.5 * runY * (runY - 1);
      runY = 1;
    }
  }
  yTies += 0.5 * runY * (runY - 1);

  final totalPairs = 0.5 * n * (n - 1);
  final denom = math.sqrt((totalPairs - xTies) * (totalPairs - yTies));
  if (denom <= 0.0 || denom.isNaN) return double.nan;
  final numerator = totalPairs - xTies - yTies + xyTies - 2.0 * swaps;
  return (numerator / denom).clamp(-1.0, 1.0);
}

double _countInversions(List<double> values, List<double> aux, int lo, int hi) {
  if (hi - lo <= 1) return 0.0;
  final mid = lo + (hi - lo) ~/ 2;
  var inv =
      _countInversions(values, aux, lo, mid) +
      _countInversions(values, aux, mid, hi);
  var i = lo;
  var j = mid;
  var k = lo;
  while (i < mid && j < hi) {
    if (values[i] <= values[j]) {
      aux[k++] = values[i++];
    } else {
      aux[k++] = values[j++];
      inv += (mid - i).toDouble();
    }
  }
  while (i < mid) {
    aux[k++] = values[i++];
  }
  while (j < hi) {
    aux[k++] = values[j++];
  }
  for (var idx = lo; idx < hi; idx++) {
    values[idx] = aux[idx];
  }
  return inv;
}

Matrix<double> _covarianceMatrix(
  Matrix<num> matrix, {
  bool rowVar = false,
  bool population = false,
}) {
  final numRows = matrix.rowCount;
  final numCols = matrix.colCount;
  final nSamples = rowVar ? numCols : numRows;
  final nFeatures = rowVar ? numRows : numCols;

  if (nFeatures < 1) {
    throw ArgumentError('At least 1 variable required for covariance matrix');
  }
  final minSamples = population ? 1 : 2;
  if (nSamples < minSamples) {
    throw ArgumentError(
      'At least $minSamples observation(s) required for covariance matrix',
    );
  }

  final xc = Matrix<double>.filled(
    nSamples,
    nFeatures,
    0.0,
    type: DataType.float64,
  );

  for (var j = 0; j < nFeatures; j++) {
    var sum = 0.0;
    for (var i = 0; i < nSamples; i++) {
      sum += rowVar
          ? matrix.getUnchecked(j, i).toDouble()
          : matrix.getUnchecked(i, j).toDouble();
    }
    final meanVal = sum / nSamples;
    for (var i = 0; i < nSamples; i++) {
      final val = rowVar
          ? matrix.getUnchecked(j, i).toDouble()
          : matrix.getUnchecked(i, j).toDouble();
      xc.setUnchecked(i, j, val - meanVal);
    }
  }

  final scale = 1.0 / (population ? nSamples : nSamples - 1.0);
  return xc.syrk(transpose: true, alpha: scale);
}

Matrix<double> _pearsonCorrelationMatrix(
  Matrix<num> matrix, {
  bool rowVar = false,
}) {
  final cov = _covarianceMatrix(matrix, rowVar: rowVar);
  final dim = cov.rowCount;
  final std = List<double>.generate(dim, (i) {
    final v = cov.getUnchecked(i, i);
    return v > 0.0 ? math.sqrt(v) : (v.isNaN ? double.nan : 0.0);
  });
  final corr = Matrix<double>.filled(dim, dim, 0.0, type: DataType.float64);
  for (var i = 0; i < dim; i++) {
    corr.setUnchecked(i, i, std[i] > 0.0 ? 1.0 : double.nan);
    for (var j = i + 1; j < dim; j++) {
      final denom = std[i] * std[j];
      final correlation = denom > 0.0
          ? (cov.getUnchecked(i, j) / denom).clamp(-1.0, 1.0)
          : double.nan;
      corr.setUnchecked(i, j, correlation);
      corr.setUnchecked(j, i, correlation);
    }
  }
  return corr;
}

Matrix<double> _spearmanCorrelationMatrix(
  Matrix<num> matrix, {
  bool rowVar = false,
}) {
  final numRows = matrix.rowCount;
  final numCols = matrix.colCount;
  final nSamples = rowVar ? numCols : numRows;
  final nFeatures = rowVar ? numRows : numCols;

  if (nFeatures < 1 || nSamples < 2) {
    throw ArgumentError(
      'At least 2 observations and 1 variable required for correlation matrix',
    );
  }

  final ranked = Matrix<double>.filled(
    nSamples,
    nFeatures,
    0.0,
    type: DataType.float64,
  );

  for (var j = 0; j < nFeatures; j++) {
    final colValues = List<double>.generate(
      nSamples,
      (i) => rowVar
          ? matrix.getUnchecked(j, i).toDouble()
          : matrix.getUnchecked(i, j).toDouble(),
    );
    final ranks = rankData(colValues);
    for (var i = 0; i < nSamples; i++) {
      ranked.setUnchecked(i, j, ranks[i]);
    }
  }

  return _pearsonCorrelationMatrix(ranked, rowVar: false);
}

Matrix<double> _kendallCorrelationMatrix(
  Matrix<num> matrix, {
  bool rowVar = false,
}) {
  final numRows = matrix.rowCount;
  final numCols = matrix.colCount;
  final nSamples = rowVar ? numCols : numRows;
  final nFeatures = rowVar ? numRows : numCols;

  if (nFeatures < 1 || nSamples < 2) {
    throw ArgumentError(
      'At least 2 observations and 1 variable required for correlation matrix',
    );
  }

  final columns = List<List<double>>.generate(
    nFeatures,
    (j) => List<double>.generate(
      nSamples,
      (i) => rowVar
          ? matrix.getUnchecked(j, i).toDouble()
          : matrix.getUnchecked(i, j).toDouble(),
    ),
  );

  final corr = Matrix<double>.filled(
    nFeatures,
    nFeatures,
    0.0,
    type: DataType.float64,
  );
  for (var i = 0; i < nFeatures; i++) {
    final colI = columns[i];
    var hasNanOrConst = colI.any((v) => v.isNaN);
    if (!hasNanOrConst) {
      final first = colI[0];
      hasNanOrConst = colI.every((v) => v == first);
    }
    corr.setUnchecked(i, i, hasNanOrConst ? double.nan : 1.0);
    for (var j = i + 1; j < nFeatures; j++) {
      final tau = _kendallCorrelation(colI, columns[j]);
      corr.setUnchecked(i, j, tau);
      corr.setUnchecked(j, i, tau);
    }
  }
  return corr;
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
    if (!w.isFinite || w < 0.0) {
      throw ArgumentError.value(
        w,
        'weights',
        'Weights must be non-negative and finite',
      );
    }
    final x = valIter.current.toDouble();
    if (w > 0.0) {
      sumWeighted += w * x;
      sumWeights += w;
    } else if (x.isNaN) {
      return double.nan;
    }
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
  var maxW = 0.0;
  for (var i = 0; i < n; i++) {
    final w = weightList[i];
    if (!w.isFinite || w < 0.0) {
      throw ArgumentError.value(
        w,
        'weights',
        'Weights must be non-negative and finite',
      );
    }
    if (w > maxW) maxW = w;
  }
  if (n == 0 || maxW <= 0.0) return double.nan;

  var v1 = 0.0;
  var v2 = 0.0;
  var sumWeighted = 0.0;
  for (var i = 0; i < n; i++) {
    final nw = weightList[i] / maxW;
    v1 += nw;
    v2 += nw * nw;
    sumWeighted += nw * valList[i];
  }

  final meanW = sumWeighted / v1;
  var ssW = 0.0;
  for (var i = 0; i < n; i++) {
    final nw = weightList[i] / maxW;
    if (nw > 0.0) {
      final diff = valList[i] - meanW;
      ssW += nw * diff * diff;
    }
  }

  if (!unbiased) {
    return ssW / v1;
  }
  final denom = v1 - (v2 / v1);
  return denom > 0.0 ? ssW / denom : double.nan;
}

double _weightedStandardDeviation(
  Iterable<num> values,
  Iterable<num> weights, {
  bool unbiased = true,
}) => math.sqrt(_weightedVariance(values, weights, unbiased: unbiased));

List<double> _movingAverage(Iterable<num> values, int windowSize) {
  if (windowSize <= 0) {
    throw ArgumentError.value(
      windowSize,
      'windowSize',
      'windowSize must be positive',
    );
  }
  final list = [for (final v in values) v.toDouble()];
  final n = list.length;
  if (windowSize > n) {
    throw ArgumentError.value(
      windowSize,
      'windowSize',
      'windowSize ($windowSize) cannot exceed values length ($n)',
    );
  }
  if (windowSize == 1) return list;

  // Two-stack queue maintains exact sliding window sums in strict O(N) time
  // without subtraction, avoiding spike cancellation, drift, and NaN poisoning.
  final frontSums = Float64List(windowSize);
  final backValues = Float64List(windowSize);
  var frontSize = 0;
  var backSize = 0;
  var backSum = 0.0;

  void transferBackToFront() {
    var acc = 0.0;
    while (backSize > 0) {
      acc += backValues[--backSize];
      frontSums[frontSize++] = acc;
    }
    backSum = 0.0;
  }

  for (var i = 0; i < windowSize; i++) {
    final v = list[i];
    backValues[backSize++] = v;
    backSum += v;
  }
  transferBackToFront();

  final invW = 1.0 / windowSize;
  final result = List<double>.filled(n - windowSize + 1, 0.0);
  result[0] = frontSums[frontSize - 1] * invW;

  for (var i = windowSize; i < n; i++) {
    frontSize--;
    final entering = list[i];
    backValues[backSize++] = entering;
    backSum += entering;
    if (frontSize == 0) {
      transferBackToFront();
      result[i - windowSize + 1] = frontSums[frontSize - 1] * invW;
    } else {
      result[i - windowSize + 1] = (frontSums[frontSize - 1] + backSum) * invW;
    }
  }
  return result;
}

List<double> _exponentialMovingAverage(Iterable<num> values, double alpha) {
  if (!(alpha > 0.0 && alpha <= 1.0)) {
    throw ArgumentError.value(
      alpha,
      'alpha',
      'Smoothing factor alpha must be finite in (0, 1]',
    );
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
