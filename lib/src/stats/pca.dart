import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:more/printer.dart' show ObjectPrinter, ToStringPrinter;

import '../linear/decomposition/eigenvalue.dart';
import '../linear/decomposition/svd.dart';
import '../linear/matrix.dart';
import '../linear/vector.dart';
import '../type/data_type.dart';

/// Result of Principal Component Analysis (PCA).
@immutable
class PcaResult with ToStringPrinter {
  /// Creates a [PcaResult] with the fitted principal axes and variance metrics.
  const new({
    required this.components,
    required this.explainedVariance,
    required this.explainedVarianceRatio,
    required this.singularValues,
    required this.mean,
    required this.standardize,
    this.std,
  });

  /// Principal axes in feature space with shape `(nComponents, nFeatures)`.
  final Matrix<double> components;

  /// Amount of variance explained by each principal component.
  final Vector<double> explainedVariance;

  /// Proportion of total variance explained by each principal component.
  final Vector<double> explainedVarianceRatio;

  /// Singular values corresponding to each principal component.
  final Vector<double> singularValues;

  /// Per-feature empirical mean.
  final Vector<double> mean;

  /// Whether input features were standardized to unit variance.
  final bool standardize;

  /// Per-feature empirical standard deviation when [standardize] is true.
  final Vector<double>? std;

  /// Cumulative proportion of variance explained across components.
  Vector<double> get cumulativeExplainedVarianceRatio {
    final len = explainedVarianceRatio.length;
    final cumsum = Vector<double>.filled(len, 0.0, type: DataType.float64);
    var total = 0.0;
    for (var i = 0; i < len; i++) {
      total += explainedVarianceRatio[i];
      cumsum[i] = total;
    }
    return cumsum;
  }

  /// Projects [x] onto the principal component space.
  ///
  /// Throws [ArgumentError] if the feature count of [x] does not match [mean].
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
    final stdVec = std;
    for (var i = 0; i < rowCount; i++) {
      for (var j = 0; j < colCount; j++) {
        var val = x.getUnchecked(i, j).toDouble() - mean[j];
        if (standardize && stdVec != null && stdVec[j] > 0.0) {
          val /= stdVec[j];
        }
        centered.setUnchecked(i, j, val);
      }
    }
    return centered * components.transposed;
  }

  /// Transforms [x] from principal component space back to the original
  /// feature space.
  ///
  /// Throws [ArgumentError] if the component count of [x] does not match
  /// `components.rowCount`.
  Matrix<double> inverseTransform(Matrix<num> x) {
    final rowCount = x.rowCount;
    final compCount = x.colCount;
    if (compCount != components.rowCount) {
      throw ArgumentError(
        'Component dimension $compCount does not match ${components.rowCount}',
      );
    }
    final featureCount = components.colCount;
    final xDouble = x is Matrix<double> ? x : x.toDoubleMatrix();
    final recon = xDouble * components;
    final stdVec = std;
    for (var i = 0; i < rowCount; i++) {
      for (var j = 0; j < featureCount; j++) {
        var val = recon.getUnchecked(i, j);
        if (standardize && stdVec != null) {
          val *= stdVec[j];
        }
        val += mean[j];
        recon.setUnchecked(i, j, val);
      }
    }
    return recon;
  }

  @override
  bool operator ==(Object other) =>
      other is PcaResult &&
      standardize == other.standardize &&
      components == other.components &&
      explainedVariance == other.explainedVariance &&
      explainedVarianceRatio == other.explainedVarianceRatio &&
      singularValues == other.singularValues &&
      mean == other.mean &&
      std == other.std;

  @override
  int get hashCode => Object.hash(
    PcaResult,
    components,
    explainedVariance,
    explainedVarianceRatio,
    singularValues,
    mean,
    standardize,
    std,
  );

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(components.rowCount, name: 'components')
    ..addValue(mean.length, name: 'features')
    ..addValue(standardize, name: 'standardize')
    ..addValue(explainedVarianceRatio, name: 'explainedVarianceRatio');
}

/// Fits Principal Component Analysis (PCA) on [data].
///
/// Rows of [data] represent observations and columns represent features.
/// When [nComponents] is omitted, retains `min(nSamples, nFeatures)`
/// components; otherwise validates `1 <= nComponents <= nFeatures`. When
/// [standardize] is true, scales each feature by its sample standard
/// deviation before decomposition.
///
/// Uses [SingularValueDecomposition] for direct numerical stability on small
/// and medium datasets and symmetric covariance eigendecomposition for tall
/// matrices (`nSamples > 512`), enforcing deterministic eigenvector sign
/// orientation. Throws [ArgumentError] or [RangeError] on invalid dimensions,
/// component counts, or non-finite entries.
PcaResult pca(Matrix<num> data, {int? nComponents, bool standardize = false}) {
  final nSamples = data.rowCount;
  final nFeatures = data.colCount;
  if (nSamples < 2) {
    throw ArgumentError('At least 2 samples required for PCA');
  }
  if (nFeatures < 1) {
    throw ArgumentError('At least 1 feature required for PCA');
  }
  final numComponents = nComponents ?? math.min(nSamples, nFeatures);
  RangeError.checkValueInInterval(numComponents, 1, nFeatures, 'nComponents');

  final meanVec = Vector<double>.filled(nFeatures, 0.0, type: DataType.float64);
  final stdVec = Vector<double>.filled(nFeatures, 1.0, type: DataType.float64);

  // Single pass per feature with Welford mean and M2 to avoid overflow/cancellation.
  for (var j = 0; j < nFeatures; j++) {
    var m = 0.0;
    var m2 = 0.0;
    for (var i = 0; i < nSamples; i++) {
      final val = data.getUnchecked(i, j).toDouble();
      if (!val.isFinite) {
        throw ArgumentError.value(
          val,
          'data[$i][$j]',
          'PCA input entries must be finite',
        );
      }
      final delta = val - m;
      m += delta / (i + 1);
      m2 += delta * (val - m);
    }
    meanVec[j] = m;
    if (standardize) {
      final stdVal = math.sqrt(m2 / (nSamples - 1.0));
      stdVec[j] = stdVal > 0.0 ? stdVal : 1.0;
    }
  }

  final xCentered = Matrix<double>.filled(
    nSamples,
    nFeatures,
    0.0,
    type: DataType.float64,
  );
  for (var j = 0; j < nFeatures; j++) {
    final m = meanVec[j];
    final invStd = standardize ? 1.0 / stdVec[j] : 1.0;
    for (var i = 0; i < nSamples; i++) {
      xCentered.setUnchecked(
        i,
        j,
        (data.getUnchecked(i, j).toDouble() - m) * invStd,
      );
    }
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
  final singValues = Vector<double>.filled(
    numComponents,
    0.0,
    type: DataType.float64,
  );

  final dof = nSamples - 1.0;
  if (nSamples <= 512) {
    final svd = SingularValueDecomposition(xCentered);
    final sAll = svd.s;
    final vt = svd.vt;
    final nSing = sAll.length;
    var totalVar = 0.0;
    for (var i = 0; i < nSing; i++) {
      final sv = sAll[i];
      totalVar += (sv * sv) / dof;
    }
    for (var compIdx = 0; compIdx < numComponents; compIdx++) {
      final sv = compIdx < nSing ? sAll[compIdx].abs() : 0.0;
      final ev = (sv * sv) / dof;
      singValues[compIdx] = sv;
      expVar[compIdx] = ev;
      expVarRatio[compIdx] = totalVar > 0.0 ? ev / totalVar : 0.0;
      for (var j = 0; j < nFeatures; j++) {
        compMatrix.setUnchecked(compIdx, j, vt.getUnchecked(compIdx, j));
      }
    }
  } else {
    final cov = xCentered.syrk(transpose: true, alpha: 1.0 / dof);
    final eig = EigenvalueDecomposition(cov);
    final rawEigenvalues = eig.realEigenvalues;
    final eigVectors = eig.v;
    final order = List<int>.generate(nFeatures, (i) => i)
      ..sort((a, b) => rawEigenvalues[b].compareTo(rawEigenvalues[a]));

    var totalVar = 0.0;
    for (final val in rawEigenvalues) {
      if (val > 0.0) totalVar += val;
    }

    for (var compIdx = 0; compIdx < numComponents; compIdx++) {
      final featureIdx = order[compIdx];
      final ev = math.max(0.0, rawEigenvalues[featureIdx]);
      expVar[compIdx] = ev;
      expVarRatio[compIdx] = totalVar > 0.0 ? ev / totalVar : 0.0;
      singValues[compIdx] = math.sqrt(ev * dof);
      for (var j = 0; j < nFeatures; j++) {
        compMatrix.setUnchecked(
          compIdx,
          j,
          eigVectors.getUnchecked(j, featureIdx),
        );
      }
    }
  }

  // Enforce deterministic sign convention: largest-magnitude entry per axis is non-negative.
  for (var compIdx = 0; compIdx < numComponents; compIdx++) {
    var maxIdx = 0;
    var maxAbs = compMatrix.getUnchecked(compIdx, 0).abs();
    for (var j = 1; j < nFeatures; j++) {
      final a = compMatrix.getUnchecked(compIdx, j).abs();
      if (a > maxAbs) {
        maxAbs = a;
        maxIdx = j;
      }
    }
    if (compMatrix.getUnchecked(compIdx, maxIdx) < 0.0) {
      for (var j = 0; j < nFeatures; j++) {
        compMatrix.setUnchecked(
          compIdx,
          j,
          -compMatrix.getUnchecked(compIdx, j),
        );
      }
    }
  }

  return PcaResult(
    components: compMatrix,
    explainedVariance: expVar,
    explainedVarianceRatio: expVarRatio,
    singularValues: singValues,
    mean: meanVec,
    standardize: standardize,
    std: standardize ? stdVec : null,
  );
}
