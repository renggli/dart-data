import 'dart:io';
import 'dart:math' as math;

import 'package:data/data.dart';

void main() {
  stdout.writeln('=== Package:Data Statistics & Analysis Demo ===\n');

  // 1. Descriptive Statistics & Covariance
  stdout.writeln('1. Descriptive Statistics & Correlation Matrix');
  final sampleA = [12.0, 14.5, 11.0, 16.2, 14.8, 15.1, 13.9, 17.5];
  final sampleB = [24.1, 28.9, 22.5, 32.0, 29.2, 30.1, 27.8, 35.2];
  stdout.writeln(
    '   Sample A mean: ${sampleA.mean()}, std: ${sampleA.standardDeviation()}',
  );
  stdout.writeln(
    '   Sample A median: ${sampleA.median()}, IQR: ${sampleA.iqr()}',
  );
  stdout.writeln(
    '   Pearson correlation: ${pearsonCorrelation(sampleA, sampleB)}',
  );
  stdout.writeln(
    '   Spearman correlation: ${spearmanCorrelation(sampleA, sampleB)}\n',
  );

  // 2. Principal Component Analysis (PCA)
  stdout.writeln('2. Principal Component Analysis (PCA)');
  final featureMatrix = Matrix<double>.fromRows([
    [2.5, 2.4, 0.5],
    [0.5, 0.7, 0.1],
    [2.2, 2.9, 0.6],
    [1.9, 2.2, 0.4],
    [3.1, 3.0, 0.7],
    [2.3, 2.7, 0.5],
    [2.0, 1.6, 0.3],
    [1.0, 1.1, 0.2],
    [1.5, 1.6, 0.3],
    [1.1, 0.9, 0.2],
  ], type: DataType.float64);

  final pcaModel = pca(featureMatrix, nComponents: 2);
  stdout.writeln(
    '   Components shape: ${pcaModel.components.rowCount} x ${pcaModel.components.colCount}',
  );
  stdout.writeln(
    '   Explained variance ratio: ${pcaModel.explainedVarianceRatio.toList()}',
  );
  final projected = pcaModel.transform(featureMatrix);
  stdout.writeln('   Projected 2D coordinates (first 3 rows):');
  for (var i = 0; i < 3; i++) {
    stdout.writeln(
      '     Row $i: [${projected.get(i, 0)}, ${projected.get(i, 1)}]',
    );
  }
  stdout.writeln();

  // 3. Hypothesis Testing
  stdout.writeln('3. Hypothesis Testing');
  final groupControl = [5.2, 5.5, 4.9, 5.1, 5.3, 5.0, 5.4, 4.8];
  final groupTreatment = [6.1, 6.4, 5.9, 6.3, 6.2, 5.8, 6.5, 6.0];

  final tTest = tTestTwoSample(groupControl, groupTreatment);
  stdout.writeln(
    '   Two-Sample Welch t-test: t = ${tTest.statistic}, p-value = ${tTest.pValue}',
  );
  stdout.writeln('   Significant difference? ${tTest.isSignificant}\n');

  // 4. Probability Distributions
  stdout.writeln('4. Probability Distributions');
  const normal = NormalDistribution.standard();
  stdout.writeln(
    '   Standard Normal P(-1.96 <= Z <= 1.96): ${normal.cdf(1.96) - normal.cdf(-1.96)}',
  );
  const student = StudentDistribution(5.0);
  stdout.writeln(
    '   Student-t (df=5) 97.5% quantile: ${student.quantile(0.975)}',
  );
  const fDist = FDistribution(3.0, 20.0);
  stdout.writeln('   F(3, 20) p-value for F = 3.5: ${fDist.survival(3.5)}\n');

  // 5. Bootstrap Resampling
  stdout.writeln('5. Non-Parametric Bootstrap Resampling');
  final boot = bootstrap<double>(
    groupControl,
    (list) => list.mean(),
    resamples: 1000,
    confidenceLevel: 0.95,
    random: math.Random(42),
  );
  stdout.writeln('   Sample mean estimate: ${boot.estimate}');
  stdout.writeln('   Bootstrap standard error: ${boot.standardError}');
  stdout.writeln('   95% Percentile CI: ${boot.percentileInterval}');
  stdout.writeln('   95% BCa CI: ${boot.bcaInterval}');
}
