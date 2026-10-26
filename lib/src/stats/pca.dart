import 'dart:math' as math;

import '../linear/decomposition/eigenvalue.dart';
import '../linear/matrix.dart';
import '../linear/vector.dart';
import '../type/data_type.dart';
import 'descriptive.dart';

/// Result of Principal Component Analysis (PCA).
class PcaResult {
  /// Creates a [PcaResult] with the fitted principal axes and variance metrics.
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
    final stdVec = std;
    for (var i = 0; i < rowCount; i++) {
      for (var j = 0; j < colCount; j++) {
        var val = x.get(i, j).toDouble() - mean[j];
        if (standardize && stdVec != null && stdVec[j] > 0.0) {
          val /= stdVec[j];
        }
        centered.set(i, j, val);
      }
    }
    return centered * components.transposed;
  }

  /// Transforms [x] from principal component space back to original feature
  /// space.
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
    final stdVec = std;
    for (var i = 0; i < rowCount; i++) {
      for (var j = 0; j < featureCount; j++) {
        var val = recon.get(i, j);
        if (standardize && stdVec != null) {
          val *= stdVec[j];
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
/// Rows of [data] represent observations, and columns represent features. If
/// [standardize] is true, features are scaled to unit variance.
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
