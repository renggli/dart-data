/// Comprehensive statistical analysis, probability distributions, hypothesis testing, and resampling algorithms.
///
/// Designed to model uncertainty, calculate descriptive summaries, perform statistical
/// inference, and evaluate experimental hypotheses.
///
/// ## Core Modules
///
/// - **Descriptive Statistics**:
///   [mean], [median], [variance], [standardDeviation], [quantile], [iqr], [skewness], [kurtosis],
///   [covariance], [pearsonCorrelation], [spearmanCorrelation], [pca], and [movingAverage].
/// - **Univariate Continuous Distributions**:
///   [ContinuousDistribution] base class, [NormalDistribution], [StudentDistribution], [FDistribution],
///   [ChiSquaredDistribution], [ExponentialDistribution], [GammaDistribution], [InverseGammaDistribution],
///   [BetaDistribution], [LogNormalDistribution], [WeibullDistribution], [CauchyDistribution],
///   [LaplaceDistribution], [LogisticDistribution], [ParetoDistribution], [DegenerateDistribution],
///   and [UniformDistribution].
/// - **Univariate Discrete Distributions**:
///   [DiscreteDistribution] base class, [BinomialDistribution], [PoissonDistribution],
///   [BernoulliDistribution], [GeometricDistribution], [HypergeometricDistribution],
///   [NegativeBinomialDistribution], [RademacherDistribution], and [UniformDiscreteDistribution].
/// - **Multivariate Distributions**:
///   [MultivariateDistribution] base class, [MultivariateNormalDistribution],
///   [DirichletDistribution], and [MultinomialDistribution].
/// - **Hypothesis Testing**:
///   [tTestOneSample], [tTestTwoSample] (Student's and Welch's $t$-tests), [tTestPaired],
///   [oneWayAnova] ($F$-test), [chiSquaredTest], [chiSquaredContingency],
///   [mannWhitneyUTest], [wilcoxonSignedRankTest], [kolmogorovSmirnovTest],
///   [kolmogorovSmirnov2Sample], and [jarqueBeraTest].
/// - **Resampling & Inference**:
///   [bootstrap] (non-parametric confidence intervals and distributions) and [Jackknife].
/// - **Distribution Infrastructure**:
///   [Distribution] abstract contract and [InvalidProbability] validation error.
///
/// ## Example
///
/// ```dart
/// import 'package:data/stats.dart';
///
/// void main() {
///   // 1. Calculate descriptive statistics
///   final scores = [88.0, 92.5, 79.0, 95.0, 85.5, 91.0];
///   print('Mean: ${scores.mean()}');
///   print('Std Dev: ${scores.standardDeviation()}');
///
///   // 2. Standard normal distribution probabilities
///   const normal = NormalDistribution.standard();
///   print('P(Z <= 1.96) ~= ${normal.cumulativeProbability(1.96)}');
///
///   // 3. Two-sample t-test comparing treatment vs control
///   final treatment = [12.1, 14.3, 13.8, 15.2, 14.9];
///   final control = [10.2, 11.5, 10.8, 12.0, 11.1];
///   final test = tTestTwoSample(treatment, control);
///   print('p-value: ${test.pValue}, significant: ${test.isSignificant}');
/// }
/// ```
library;

import 'src/stats/descriptive.dart';
import 'src/stats/distribution.dart';
import 'src/stats/distributions/continuous.dart';
import 'src/stats/distributions/continuous/beta.dart';
import 'src/stats/distributions/continuous/cauchy.dart';
import 'src/stats/distributions/continuous/chi_squared.dart';
import 'src/stats/distributions/continuous/degenerate.dart';
import 'src/stats/distributions/continuous/exponential.dart';
import 'src/stats/distributions/continuous/f.dart';
import 'src/stats/distributions/continuous/gamma.dart';
import 'src/stats/distributions/continuous/inverse_gamma.dart';
import 'src/stats/distributions/continuous/laplace.dart';
import 'src/stats/distributions/continuous/log_normal.dart';
import 'src/stats/distributions/continuous/logistic.dart';
import 'src/stats/distributions/continuous/normal.dart';
import 'src/stats/distributions/continuous/pareto.dart';
import 'src/stats/distributions/continuous/student_t.dart';
import 'src/stats/distributions/continuous/uniform.dart';
import 'src/stats/distributions/continuous/weibull.dart';
import 'src/stats/distributions/discrete.dart';
import 'src/stats/distributions/discrete/bernoulli.dart';
import 'src/stats/distributions/discrete/binomial.dart';
import 'src/stats/distributions/discrete/geometric.dart';
import 'src/stats/distributions/discrete/hypergeometric.dart';
import 'src/stats/distributions/discrete/negative_binomial.dart';
import 'src/stats/distributions/discrete/poisson.dart';
import 'src/stats/distributions/discrete/rademacher.dart';
import 'src/stats/distributions/discrete/uniform.dart';
import 'src/stats/distributions/errors.dart';
import 'src/stats/distributions/multivariate/dirichlet.dart';
import 'src/stats/distributions/multivariate/multinomial.dart';
import 'src/stats/distributions/multivariate/multivariate_distribution.dart';
import 'src/stats/distributions/multivariate/multivariate_normal.dart';
import 'src/stats/hypothesis.dart';
import 'src/stats/resampling.dart';

export 'src/stats/descriptive.dart';
export 'src/stats/distribution.dart';
export 'src/stats/distributions/continuous.dart';
export 'src/stats/distributions/continuous/beta.dart';
export 'src/stats/distributions/continuous/cauchy.dart';
export 'src/stats/distributions/continuous/chi_squared.dart';
export 'src/stats/distributions/continuous/degenerate.dart';
export 'src/stats/distributions/continuous/exponential.dart';
export 'src/stats/distributions/continuous/f.dart';
export 'src/stats/distributions/continuous/gamma.dart';
export 'src/stats/distributions/continuous/inverse_gamma.dart';
export 'src/stats/distributions/continuous/laplace.dart';
export 'src/stats/distributions/continuous/log_normal.dart';
export 'src/stats/distributions/continuous/logistic.dart';
export 'src/stats/distributions/continuous/normal.dart';
export 'src/stats/distributions/continuous/pareto.dart';
export 'src/stats/distributions/continuous/student_t.dart';
export 'src/stats/distributions/continuous/uniform.dart';
export 'src/stats/distributions/continuous/weibull.dart';
export 'src/stats/distributions/discrete.dart';
export 'src/stats/distributions/discrete/bernoulli.dart';
export 'src/stats/distributions/discrete/binomial.dart';
export 'src/stats/distributions/discrete/geometric.dart';
export 'src/stats/distributions/discrete/hypergeometric.dart';
export 'src/stats/distributions/discrete/negative_binomial.dart';
export 'src/stats/distributions/discrete/poisson.dart';
export 'src/stats/distributions/discrete/rademacher.dart';
export 'src/stats/distributions/discrete/uniform.dart';
export 'src/stats/distributions/errors.dart';
export 'src/stats/distributions/multivariate/dirichlet.dart';
export 'src/stats/distributions/multivariate/multinomial.dart';
export 'src/stats/distributions/multivariate/multivariate_distribution.dart';
export 'src/stats/distributions/multivariate/multivariate_normal.dart';
export 'src/stats/hypothesis.dart';
export 'src/stats/resampling.dart';
