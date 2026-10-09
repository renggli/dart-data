# Subsystem Architecture: Statistics & Probability Distributions

## 1. Overview & Current Deficiencies

The `stats` subsystem ([lib/src/stats/](../lib/src/stats/)) provides a collection of probability distributions, univariate sample aggregations on iterables, and jackknife resampling.

However, modern statistical analysis requires empirical descriptive metrics, inferential hypothesis testing, distribution fitting, and multivariate modeling—all of which are currently either missing or incomplete.

### 1.1 Identified Gaps & Deficiencies

1. **Missing Descriptive Statistics & Quantiles**:
   - [`lib/src/stats/iterable.dart`](../lib/src/stats/iterable.dart) provides basic aggregations: `sum`, `product`, `mean`, `variance`, and `standardDeviation`.
   - Missing:
     - Quantiles and percentiles (`quantile(q)`, `percentile(p)`, `median`, `iqr`).
     - Sample skewness and kurtosis (evaluating distribution asymmetry and tail weight).
     - Covariance matrix $\Sigma = \text{cov}(X)$ and correlation matrices (Pearson $r$, Spearman rank $\rho$).
     - Weighted statistics (`weightedMean`, `weightedVariance`).
     - Moving / rolling window aggregations (simple moving average SMA, exponential moving average EMA).

2. **Complete Absence of Hypothesis Testing**:
   - The package contains zero statistical hypothesis tests, preventing rigorous statistical inference:
     - **Student's t-test**: One-sample, two-sample independent (Student and Welch's t-test), paired t-test.
     - **ANOVA**: One-way analysis of variance ($F$-test).
     - **Chi-Squared ($\chi^2$) Tests**: Goodness-of-fit and contingency table test of independence.
     - **Non-Parametric Tests**: Mann-Whitney $U$ test, Wilcoxon signed-rank test.
     - **Goodness-of-Fit / Normality Tests**: Kolmogorov-Smirnov (KS) test, Shapiro-Wilk, Jarque-Bera.

3. **Missing Distribution Parameter Fitting (`fit`)**:
   - Theoretical distributions in `lib/src/stats/distributions/` (e.g. `NormalDistribution`, `ExponentialDistribution`, `GammaDistribution`, `BetaDistribution`) cannot be fitted to empirical data.
   - Users must manually derive and code estimators rather than calling `NormalDistribution.fit(data)`.

4. **Missing Bootstrap Resampling**:
   - [`Jackknife`](../lib/src/stats/jackknife.dart) is provided, but modern computational statistics relies primarily on **Bootstrap Resampling** (both non-parametric and parametric bootstrap) with percentile and bias-corrected/accelerated (BCa) confidence intervals.

5. **Exclusively Univariate Distributions**:
   - All distributions model a single random scalar variable.
   - Missing multivariate distributions:
     - **Multivariate Normal Distribution** $\mathcal{N}(\mu, \Sigma)$.
     - **Dirichlet Distribution**.
     - **Multinomial Distribution**.

---

## 2. Target Design & Architecture

```
+-------------------------------------------------------------------------+
|                            Stats Subsystem                              |
+-------------------------------------------------------------------------+
       |                     |                      |               |
+---------------+     +---------------+     +---------------+ +---------------+
| Descriptive   |     | Hypothesis    |     | Parameter     | | Resampling    |
| - Quantiles   |     | Testing       |     | Fitting (MLE) | | - Bootstrap   |
| - Cov / Corr  |     | - t-test      |     | - Normal.fit  | |   (Percentile,|
| - Skew / Kurt |     | - Chi-Squared |     | - Gamma.fit   | |    BCa CIs)   |
| - Rolling Stat|     | - ANOVA / KS  |     | - Poisson.fit | | - Jackknife   |
+---------------+     +---------------+     +---------------+ +---------------+
```

### 2.1 Empirical & Descriptive Statistics

Add comprehensive statistical extensions to `Iterable<num>`, `Vector<num>`, and `Series<num>`:

```dart
extension DescriptiveStatsExtension on Iterable<num> {
  double quantile(double q, {QuantileMethod method = QuantileMethod.linear});
  double get median => quantile(0.5);
  double get iqr => quantile(0.75) - quantile(0.25);
  
  double get skewness;
  double get kurtosis;
  
  List<double> movingAverage(int windowSize);
  List<double> exponentialMovingAverage(double alpha);
}

Matrix<double> covarianceMatrix(Matrix<num> data);
Matrix<double> correlationMatrix(Matrix<num> data, {CorrelationType type = CorrelationType.pearson});
```

### 2.2 Statistical Hypothesis Testing

A unified `HypothesisTestResult` model returning test statistics, degrees of freedom, $p$-values, and confidence intervals:

```dart
class HypothesisTestResult {
  final String testName;
  final double statistic;
  final double pValue;
  final double? degreesOfFreedom;
  final (double, double)? confidenceInterval;
  final double significanceLevel;
  
  bool get isSignificant => pValue < significanceLevel;
}

// Student's t-test
HypothesisTestResult tTestOneSample(Iterable<num> sample, double populationMean);
HypothesisTestResult tTestTwoSample(
  Iterable<num> sampleA,
  Iterable<num> sampleB, {
  bool equalVariances = false, // Welch's t-test by default
});

// Goodness of Fit & Independence
HypothesisTestResult chiSquaredTest(List<num> observed, [List<num>? expected]);
HypothesisTestResult kolmogorovSmirnovTest(Iterable<num> sample, ContinuousDistribution distribution);

// Analysis of Variance
HypothesisTestResult anovaOneWay(List<Iterable<num>> groups);
```

### 2.3 Parameter Estimation (`Distribution.fit`)

Equip distributions with Maximum Likelihood Estimation (MLE) or closed-form method-of-moments estimators:

```dart
abstract class ContinuousDistribution {
  ...
  static NormalDistribution fit(Iterable<num> data) {
    final mean = data.mean;
    final std = data.standardDeviation;
    return NormalDistribution(mean, std);
  }
}
```

### 2.4 Bootstrap Resampling

Implement non-parametric and parametric bootstrap confidence intervals:

```dart
class BootstrapResult {
  final double estimate;
  final double standardError;
  final (double, double) confidenceInterval;
}

BootstrapResult bootstrap(
  List<double> data,
  double Function(List<double> resample) statistic, {
  int resamples = 2000,
  double confidenceLevel = 0.95,
  BootstrapMethod method = BootstrapMethod.bca, // percentile or bca
  Random? random,
});
```

### 2.5 Multivariate Distributions

Implement the `MultivariateNormalDistribution`:

```dart
class MultivariateNormalDistribution {
  final Vector<double> mean;
  final Matrix<double> covariance;
  
  MultivariateNormalDistribution(this.mean, this.covariance);
  
  double probabilityDensity(Vector<double> x);
  Vector<double> sample({Random? random});
}
```

---

## 3. Prioritized Implementation Task List

| Task ID | Phase | Priority | Description | Verification / Success Criteria |
| :--- | :--- | :--- | :--- | :--- |
| **STA-01** | Descriptive | **P0** | Implement quantiles, percentiles, median, and IQR with standard linear interpolation methods. | Match R/NumPy `quantile(type=7)` across test vectors with odd/even lengths. |
| **STA-02** | Correlation | **P1** | Implement covariance and correlation matrix functions (Pearson and Spearman rank). | Test known correlation matrices; ensure diagonal is exactly 1.0 and bounds are $[-1, 1]$. |
| **STA-03** | Moments | **P1** | Implement sample skewness and excess kurtosis (Fisher-Pearson standard). | Normal distribution samples produce skewness $\approx 0$ and kurtosis $\approx 0$. |
| **STA-04** | t-Test | **P1** | Implement one-sample, two-sample independent (Student and Welch), and paired t-tests. | Compare calculated $t$-statistic and $p$-value against SciPy `scipy.stats.ttest_ind`. |
| **STA-05** | Chi-Squared | **P1** | Implement Chi-Squared goodness-of-fit and contingency table test of independence. | Validate contingency table test on classic medical trial dataset. |
| **STA-06** | ANOVA & KS | **P2** | Implement One-way ANOVA ($F$-test) and two-sample Kolmogorov-Smirnov test. | Validate $F$-statistic and KS distances against standard benchmarks. |
| **STA-07** | MLE Fitting | **P2** | Implement `.fit()` estimators on common distributions (`Normal`, `Exponential`, `Poisson`, `Uniform`). | Fitting $10,000$ synthetic samples recovers true generating parameters within $1\%$. |
| **STA-08** | Bootstrap | **P2** | Implement non-parametric bootstrap resampling with percentile and BCa confidence intervals. | Coverage probability test on mean estimator achieves nominal $95\%$ rate. |
| **STA-09** | Multivar Dist | **P3** | Implement `MultivariateNormalDistribution` using Cholesky decomposition of covariance matrix. | Verify sample covariance matrix converges to true covariance matrix. |
