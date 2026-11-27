import 'dart:math' as math;

import 'package:data/linear.dart';
import 'package:data/stats.dart';
import 'package:data/type.dart';

/// Configuration of a single parameter.
class ParameterConfig {
  final String name;
  final String label;
  final double min;
  final double max;
  final double defaultValue;
  final double step;
  final bool isInt;

  const new({
    required this.name,
    required this.label,
    required this.min,
    required this.max,
    required this.defaultValue,
    required this.step,
    this.isInt = false,
  });
}

/// Configuration of a single distribution.
class DistributionConfig {
  final String id;
  final String name;
  final String description;
  final bool isContinuous;
  final List<ParameterConfig> parameters;
  final Distribution<num> Function(List<double> params) creator;

  const new({
    required this.id,
    required this.name,
    required this.description,
    required this.isContinuous,
    required this.parameters,
    required this.creator,
  });
}

/// Registry containing all 24 supported distributions sorted alphabetically
final List<DistributionConfig> distributions = [
  DistributionConfig(
    id: 'bernoulli',
    name: 'Bernoulli',
    description:
        'A discrete distribution representing a single coin toss, taking value '
        '1 with probability p, and value 0 with probability 1-p. The '
        'foundation of binomial models.',
    isContinuous: false,
    parameters: [
      const ParameterConfig(
        name: 'p',
        label: 'Success Prob. (p)',
        min: 0.0,
        max: 1.0,
        defaultValue: 0.5,
        step: 0.05,
      ),
    ],
    creator: (p) => BernoulliDistribution(p[0]),
  ),
  DistributionConfig(
    id: 'beta',
    name: 'Beta',
    description:
        'Defined on the interval [0, 1], characterized by two shape parameters '
        'α and β. Extremely useful in Bayesian inference as a conjugate prior '
        'for binomial trials.',
    isContinuous: true,
    parameters: [
      const ParameterConfig(
        name: 'alpha',
        label: 'Shape (α)',
        min: 0.1,
        max: 10.0,
        defaultValue: 2.0,
        step: 0.1,
      ),
      const ParameterConfig(
        name: 'beta',
        label: 'Shape (β)',
        min: 0.1,
        max: 10.0,
        defaultValue: 2.0,
        step: 0.1,
      ),
    ],
    creator: (p) => BetaDistribution(p[0], p[1]),
  ),
  DistributionConfig(
    id: 'binomial',
    name: 'Binomial',
    description:
        'Models the number of successes in n independent Bernoulli trials, '
        'each with success probability p. Widely used in quality control and '
        'statistics.',
    isContinuous: false,
    parameters: [
      const ParameterConfig(
        name: 'n',
        label: 'Trials (n)',
        min: 1,
        max: 100,
        defaultValue: 10,
        step: 1,
        isInt: true,
      ),
      const ParameterConfig(
        name: 'p',
        label: 'Success Prob. (p)',
        min: 0.0,
        max: 1.0,
        defaultValue: 0.5,
        step: 0.05,
      ),
    ],
    creator: (p) => BinomialDistribution(p[0].toInt(), p[1]),
  ),
  DistributionConfig(
    id: 'cauchy',
    name: 'Cauchy (Lorentz)',
    description:
        'An infinite-support distribution without defined mean or variance. '
        'Characterized by location (x₀) and scale (γ). Known for its heavy '
        'tails and high outlier frequency.',
    isContinuous: true,
    parameters: [
      const ParameterConfig(
        name: 'location',
        label: 'Location (x₀)',
        min: -10.0,
        max: 10.0,
        defaultValue: 0.0,
        step: 0.1,
      ),
      const ParameterConfig(
        name: 'scale',
        label: 'Scale (γ)',
        min: 0.1,
        max: 10.0,
        defaultValue: 1.0,
        step: 0.1,
      ),
    ],
    creator: (p) => CauchyDistribution(p[0], p[1]),
  ),
  DistributionConfig(
    id: 'chi_squared',
    name: 'Chi-Squared (χ²)',
    description:
        'The distribution of a sum of squares of k independent standard normal '
        'variables. Widely used in statistical hypothesis testing (e.g. chi-'
        'squared goodness of fit).',
    isContinuous: true,
    parameters: [
      const ParameterConfig(
        name: 'dof',
        label: 'Deg. of Freedom (k)',
        min: 0.5,
        max: 30.0,
        defaultValue: 3.0,
        step: 0.5,
      ),
    ],
    creator: (p) => ChiSquaredDistribution(p[0]),
  ),
  DistributionConfig(
    id: 'degenerate_continuous',
    name: 'Degenerate (Continuous)',
    description:
        'A localized distribution where all probability density is '
        'concentrated at a single point k. Models deterministic values within '
        'a probabilistic context.',
    isContinuous: true,
    parameters: [
      const ParameterConfig(
        name: 'k',
        label: 'Location (k)',
        min: -10.0,
        max: 10.0,
        defaultValue: 0.0,
        step: 0.1,
      ),
    ],
    creator: (p) => DegenerateDistribution(p[0]),
  ),
  DistributionConfig(
    id: 'exponential',
    name: 'Exponential',
    description:
        'Models the time or distance between occurrences of Poisson events. '
        'Governed by a rate parameter (λ). Frequently used in reliability and '
        'queuing theory.',
    isContinuous: true,
    parameters: [
      const ParameterConfig(
        name: 'lambda',
        label: 'Rate (λ)',
        min: 0.1,
        max: 10.0,
        defaultValue: 1.0,
        step: 0.1,
      ),
    ],
    creator: (p) => ExponentialDistribution(p[0]),
  ),
  DistributionConfig(
    id: 'f',
    name: 'F (Fisher-Snedecor)',
    description:
        'The ratio of two scaled chi-squared variables. Frequently appears in '
        'analysis of variance (ANOVA) and standard regression coefficient '
        'testing.',
    isContinuous: true,
    parameters: [
      const ParameterConfig(
        name: 'dof1',
        label: 'Numerator DOF (d₁)',
        min: 1.0,
        max: 30.0,
        defaultValue: 5.0,
        step: 1.0,
      ),
      const ParameterConfig(
        name: 'dof2',
        label: 'Denominator DOF (d₂)',
        min: 1.0,
        max: 30.0,
        defaultValue: 5.0,
        step: 1.0,
      ),
    ],
    creator: (p) => FDistribution(p[0], p[1]),
  ),
  DistributionConfig(
    id: 'gamma',
    name: 'Gamma',
    description:
        'A flexible two-parameter distribution (shape and scale) which '
        'generalizes the exponential distribution. Useful for modeling queue '
        'times and rainfall levels.',
    isContinuous: true,
    parameters: [
      const ParameterConfig(
        name: 'shape',
        label: 'Shape (k)',
        min: 0.1,
        max: 10.0,
        defaultValue: 2.0,
        step: 0.1,
      ),
      const ParameterConfig(
        name: 'scale',
        label: 'Scale (θ)',
        min: 0.1,
        max: 10.0,
        defaultValue: 2.0,
        step: 0.1,
      ),
    ],
    creator: (p) => GammaDistribution(p[0], p[1]),
  ),
  DistributionConfig(
    id: 'geometric',
    name: 'Geometric',
    description:
        'The number of Bernoulli failure trials needed before encountering the '
        'first success. Models duration until event triggers, e.g. marketing '
        'conversions.',
    isContinuous: false,
    parameters: [
      const ParameterConfig(
        name: 'p',
        label: 'Success Prob. (p)',
        min: 0.05,
        max: 1.0,
        defaultValue: 0.5,
        step: 0.05,
      ),
    ],
    creator: (p) => GeometricDistribution(p[0]),
  ),
  DistributionConfig(
    id: 'hypergeometric',
    name: 'Hypergeometric',
    description:
        'Models the probability of k successes in n draws without replacement '
        'from a population N containing K success states. Common in lottery '
        'and card games.',
    isContinuous: false,
    parameters: [
      const ParameterConfig(
        name: 'populationSize',
        label: 'Population Size (N)',
        min: 10,
        max: 150,
        defaultValue: 50,
        step: 1,
        isInt: true,
      ),
      const ParameterConfig(
        name: 'successStates',
        label: 'Success States (K)',
        min: 1,
        max: 150,
        defaultValue: 20,
        step: 1,
        isInt: true,
      ),
      const ParameterConfig(
        name: 'draws',
        label: 'Draws (n)',
        min: 1,
        max: 150,
        defaultValue: 10,
        step: 1,
        isInt: true,
      ),
    ],
    creator: (p) {
      final populationSize = p[0].toInt();
      final successStates = math.min(p[1].toInt(), populationSize);
      final draws = math.min(p[2].toInt(), populationSize);
      return HypergeometricDistribution(populationSize, successStates, draws);
    },
  ),
  DistributionConfig(
    id: 'inverse_gamma',
    name: 'Inverse Gamma',
    description:
        'The distribution of the reciprocal of a gamma-distributed variable. '
        'Acts as a conjugate prior for the variance parameter of a normal '
        'distribution in Bayesian statistics.',
    isContinuous: true,
    parameters: [
      const ParameterConfig(
        name: 'shape',
        label: 'Shape (α)',
        min: 0.1,
        max: 10.0,
        defaultValue: 3.0,
        step: 0.1,
      ),
      const ParameterConfig(
        name: 'scale',
        label: 'Scale (β)',
        min: 0.1,
        max: 10.0,
        defaultValue: 2.0,
        step: 0.1,
      ),
    ],
    creator: (p) => InverseGammaDistribution(p[0], p[1]),
  ),
  DistributionConfig(
    id: 'laplace',
    name: 'Laplace (Double Exponential)',
    description:
        'Represents the difference between two independent exponential '
        'variables. Governed by location (μ) and scale (b). Commonly displays '
        'distinct, sharp peaks.',
    isContinuous: true,
    parameters: [
      const ParameterConfig(
        name: 'location',
        label: 'Location (μ)',
        min: -10.0,
        max: 10.0,
        defaultValue: 0.0,
        step: 0.1,
      ),
      const ParameterConfig(
        name: 'scale',
        label: 'Scale (b)',
        min: 0.1,
        max: 10.0,
        defaultValue: 1.0,
        step: 0.1,
      ),
    ],
    creator: (p) => LaplaceDistribution(p[0], p[1]),
  ),
  DistributionConfig(
    id: 'log_normal',
    name: 'Log-Normal',
    description:
        'A distribution whose logarithm is normally distributed. Used to model '
        'values that are strictly positive and highly skewed, such as income '
        'distribution or file sizes.',
    isContinuous: true,
    parameters: [
      const ParameterConfig(
        name: 'mu',
        label: 'Log Mean (μ)',
        min: -3.0,
        max: 3.0,
        defaultValue: 0.0,
        step: 0.1,
      ),
      const ParameterConfig(
        name: 'sigma',
        label: 'Log Std Dev (σ)',
        min: 0.1,
        max: 2.5,
        defaultValue: 0.5,
        step: 0.1,
      ),
    ],
    creator: (p) => LogNormalDistribution(p[0], p[1]),
  ),
  DistributionConfig(
    id: 'logistic',
    name: 'Logistic',
    description:
        'Symmetric S-shaped cumulative distribution resembling a normal '
        'distribution but with heavier tails. Governed by location (μ) and '
        'scale (s). Common in logistic regression models.',
    isContinuous: true,
    parameters: [
      const ParameterConfig(
        name: 'location',
        label: 'Location (μ)',
        min: -10.0,
        max: 10.0,
        defaultValue: 0.0,
        step: 0.1,
      ),
      const ParameterConfig(
        name: 'scale',
        label: 'Scale (s)',
        min: 0.1,
        max: 10.0,
        defaultValue: 1.0,
        step: 0.1,
      ),
    ],
    creator: (p) => LogisticDistribution(p[0], p[1]),
  ),
  DistributionConfig(
    id: 'negative_binomial',
    name: 'Negative Binomial',
    description:
        'Models the number of successes in independent trials before a '
        'specified number of failures (r) occurs. Useful for modeling '
        'overdispersed count data.',
    isContinuous: false,
    parameters: [
      const ParameterConfig(
        name: 'r',
        label: 'Failures Limit (r)',
        min: 0.1,
        max: 20.0,
        defaultValue: 5.0,
        step: 0.5,
      ),
      const ParameterConfig(
        name: 'p',
        label: 'Success Prob. (p)',
        min: 0.01,
        max: 0.95,
        defaultValue: 0.5,
        step: 0.05,
      ),
    ],
    creator: (p) => NegativeBinomialDistribution(p[0], p[1]),
  ),
  DistributionConfig(
    id: 'normal',
    name: 'Normal (Gaussian)',
    description:
        'Models a symmetric bell curve where values cluster around the mean. '
        'Described by mean (μ) and standard deviation (σ). Highly applicable '
        'across physical and social sciences.',
    isContinuous: true,
    parameters: [
      const ParameterConfig(
        name: 'mu',
        label: 'Mean (μ)',
        min: -10.0,
        max: 10.0,
        defaultValue: 0.0,
        step: 0.1,
      ),
      const ParameterConfig(
        name: 'sigma',
        label: 'Std Dev (σ)',
        min: 0.1,
        max: 10.0,
        defaultValue: 1.0,
        step: 0.1,
      ),
    ],
    creator: (p) => NormalDistribution(p[0], p[1]),
  ),
  DistributionConfig(
    id: 'pareto',
    name: 'Pareto (80/20 Rule)',
    description:
        'A power-law probability distribution used to describe social, '
        'scientific, and geophysical phenomena where a large fraction of '
        'resources is held by a tiny percentage.',
    isContinuous: true,
    parameters: [
      const ParameterConfig(
        name: 'shape',
        label: 'Shape (α)',
        min: 0.5,
        max: 10.0,
        defaultValue: 3.0,
        step: 0.1,
      ),
      const ParameterConfig(
        name: 'scale',
        label: 'Scale (x₀)',
        min: 0.5,
        max: 5.0,
        defaultValue: 1.0,
        step: 0.1,
      ),
    ],
    creator: (p) => ParetoDistribution(p[0], p[1]),
  ),
  DistributionConfig(
    id: 'poisson',
    name: 'Poisson',
    description:
        'Expresses the probability of a given number of independent events '
        'occurring in a fixed interval of time/space with a known constant '
        'rate (λ).',
    isContinuous: false,
    parameters: [
      const ParameterConfig(
        name: 'lambda',
        label: 'Event Rate (λ)',
        min: 0.1,
        max: 30.0,
        defaultValue: 4.0,
        step: 0.2,
      ),
    ],
    creator: (p) => PoissonDistribution(p[0]),
  ),
  DistributionConfig(
    id: 'rademacher',
    name: 'Rademacher',
    description:
        'A symmetric discrete distribution that returns -1 with probability '
        '0.5, and 1 with probability 0.5. Useful in bootstrapping and '
        'randomized algorithms.',
    isContinuous: false,
    parameters: [],
    creator: (p) => const RademacherDistribution(),
  ),
  DistributionConfig(
    id: 'student_t',
    name: 'Student-T',
    description:
        'Symmetric bell curve representing the estimated mean of a small '
        'normally distributed population with unknown standard deviation. '
        'Heavy tails scale with degree of freedom.',
    isContinuous: true,
    parameters: [
      const ParameterConfig(
        name: 'dof',
        label: 'Deg. of Freedom (ν)',
        min: 0.5,
        max: 30.0,
        defaultValue: 3.0,
        step: 0.5,
      ),
    ],
    creator: (p) => StudentDistribution(p[0]),
  ),
  DistributionConfig(
    id: 'uniform_continuous',
    name: 'Uniform (Continuous)',
    description:
        'A constant probability distribution where every point in [a, b] is '
        'equally likely. Ideal for modeling uniform selection or noise '
        'baseline simulations.',
    isContinuous: true,
    parameters: [
      const ParameterConfig(
        name: 'a',
        label: 'Min (a)',
        min: -10.0,
        max: 10.0,
        defaultValue: -2.0,
        step: 0.1,
      ),
      const ParameterConfig(
        name: 'b',
        label: 'Max (b)',
        min: -9.0,
        max: 15.0,
        defaultValue: 2.0,
        step: 0.1,
      ),
    ],
    creator: (p) {
      final a = p[0];
      final b = math.max(a + 0.1, p[1]);
      return UniformDistribution(a, b);
    },
  ),
  DistributionConfig(
    id: 'uniform_discrete',
    name: 'Uniform (Discrete)',
    description:
        'A discrete distribution where a finite set of integers in [a, b] is '
        'equally probable. For example, rolling a standard six-sided die.',
    isContinuous: false,
    parameters: [
      const ParameterConfig(
        name: 'a',
        label: 'Min (a)',
        min: -20,
        max: 20,
        defaultValue: 1,
        step: 1,
        isInt: true,
      ),
      const ParameterConfig(
        name: 'b',
        label: 'Max (b)',
        min: -19,
        max: 40,
        defaultValue: 6,
        step: 1,
        isInt: true,
      ),
    ],
    creator: (p) {
      final a = p[0].toInt();
      final b = math.max(a, p[1].toInt());
      return UniformDiscreteDistribution(a, b);
    },
  ),
  DistributionConfig(
    id: 'weibull',
    name: 'Weibull',
    description:
        'Extremely versatile distribution modeling material breaking points '
        'and machinery time-to-failure. Described by scale (λ) and shape (k) '
        'parameters.',
    isContinuous: true,
    parameters: [
      const ParameterConfig(
        name: 'shape',
        label: 'Shape (k)',
        min: 0.1,
        max: 10.0,
        defaultValue: 2.0,
        step: 0.1,
      ),
      const ParameterConfig(
        name: 'scale',
        label: 'Scale (λ)',
        min: 0.1,
        max: 10.0,
        defaultValue: 1.5,
        step: 0.1,
      ),
    ],
    creator: (p) => WeibullDistribution(p[0], p[1]),
  ),
];

/// Configuration of a single multivariate probability distribution.
class MultivariateDistributionConfig {
  final String id;
  final String name;
  final String description;
  final bool isContinuous;
  final int dimensions;
  final bool isSimplex;
  final List<ParameterConfig> parameters;
  final MultivariateDistribution<num> Function(List<double> params) creator;
  final String Function(List<double> params) supportLabel;

  const new({
    required this.id,
    required this.name,
    required this.description,
    required this.isContinuous,
    required this.dimensions,
    required this.isSimplex,
    required this.parameters,
    required this.creator,
    required this.supportLabel,
  });
}

/// Enforces cross-parameter constraints on multivariate distribution sliders.
void syncMultivariateParameters(
  MultivariateDistributionConfig def,
  List<double> values, {
  int? changedIndex,
}) {
  if (def.id == 'multinomial' && values.length >= 3) {
    const maxPairSum = 0.95;
    const minP = 0.05;
    const maxP = 0.90;
    var p1 = values[1].clamp(minP, maxP);
    var p2 = values[2].clamp(minP, maxP);
    if (p1 + p2 > maxPairSum) {
      if (changedIndex == 1) {
        p2 = (maxPairSum - p1).clamp(minP, maxP);
        p1 = math.min(p1, maxPairSum - p2);
      } else if (changedIndex == 2) {
        p1 = (maxPairSum - p2).clamp(minP, maxP);
        p2 = math.min(p2, maxPairSum - p1);
      } else {
        final scale = maxPairSum / (p1 + p2);
        p1 = (p1 * scale).clamp(minP, maxP);
        p2 = (maxPairSum - p1).clamp(minP, maxP);
      }
    }
    values[1] = (p1 * 100).roundToDouble() / 100;
    values[2] = (p2 * 100).roundToDouble() / 100;
  }
}

/// Registry containing all supported multivariate distributions sorted
/// alphabetically.
final List<MultivariateDistributionConfig> multivariateDistributions = [
  MultivariateDistributionConfig(
    id: 'dirichlet',
    name: 'Dirichlet (3D Simplex)',
    description:
        'A continuous family over probability vectors on the 2-simplex '
        'x₁ + x₂ + x₃ = 1, parameterized by positive concentrations α₁, α₂, α₃. '
        'Serves as the conjugate prior for categorical and multinomial models.',
    isContinuous: true,
    dimensions: 3,
    isSimplex: true,
    parameters: [
      const ParameterConfig(
        name: 'alpha1',
        label: 'Concentration (α₁)',
        min: 0.2,
        max: 10.0,
        defaultValue: 2.0,
        step: 0.1,
      ),
      const ParameterConfig(
        name: 'alpha2',
        label: 'Concentration (α₂)',
        min: 0.2,
        max: 10.0,
        defaultValue: 2.0,
        step: 0.1,
      ),
      const ParameterConfig(
        name: 'alpha3',
        label: 'Concentration (α₃)',
        min: 0.2,
        max: 10.0,
        defaultValue: 2.0,
        step: 0.1,
      ),
    ],
    creator: (p) => DirichletDistribution(
      Vector<double>.fromList([
        math.max(0.2, p[0]),
        math.max(0.2, p[1]),
        math.max(0.2, p[2]),
      ], type: DataType.float64),
    ),
    supportLabel: (_) => 'Δ² = {x ∈ [0, 1]³ : x₁ + x₂ + x₃ = 1}',
  ),
  MultivariateDistributionConfig(
    id: 'multinomial',
    name: 'Multinomial (3-Category)',
    description:
        'Generalizes the binomial distribution to k = 3 mutually exclusive '
        'categories across n independent trials with probabilities p₁, p₂, and '
        'p₃ = 1 − p₁ − p₂.',
    isContinuous: false,
    dimensions: 3,
    isSimplex: true,
    parameters: [
      const ParameterConfig(
        name: 'trials',
        label: 'Trials (n)',
        min: 1,
        max: 40,
        defaultValue: 10,
        step: 1,
        isInt: true,
      ),
      const ParameterConfig(
        name: 'p1',
        label: 'Category 1 Prob. (p₁)',
        min: 0.05,
        max: 0.90,
        defaultValue: 0.35,
        step: 0.05,
      ),
      const ParameterConfig(
        name: 'p2',
        label: 'Category 2 Prob. (p₂)',
        min: 0.05,
        max: 0.90,
        defaultValue: 0.35,
        step: 0.05,
      ),
    ],
    creator: (p) {
      final n = math.max(1, p[0].round());
      var p1 = p[1].clamp(0.01, 0.94);
      var p2 = p[2].clamp(0.01, 0.94);
      if (p1 + p2 > 0.95) {
        final scale = 0.95 / (p1 + p2);
        p1 *= scale;
        p2 *= scale;
      }
      final p3 = 1.0 - p1 - p2;
      return MultinomialDistribution(
        n,
        Vector<double>.fromList([p1, p2, p3], type: DataType.float64),
      );
    },
    supportLabel: (p) =>
        '{k ∈ ℕ³ : k₁ + k₂ + k₃ = ${math.max(1, p[0].round())}}',
  ),
  MultivariateDistributionConfig(
    id: 'multivariate_normal',
    name: 'Multivariate Normal (2D)',
    description:
        'A bivariate Gaussian distribution over ℝ² characterized by mean '
        'vector μ = [μ₁, μ₂], marginal standard deviations σ₁, σ₂, and linear '
        'correlation ρ ∈ (−1, 1).',
    isContinuous: true,
    dimensions: 2,
    isSimplex: false,
    parameters: [
      const ParameterConfig(
        name: 'mu1',
        label: 'Mean (μ₁)',
        min: -5.0,
        max: 5.0,
        defaultValue: 0.0,
        step: 0.1,
      ),
      const ParameterConfig(
        name: 'mu2',
        label: 'Mean (μ₂)',
        min: -5.0,
        max: 5.0,
        defaultValue: 0.0,
        step: 0.1,
      ),
      const ParameterConfig(
        name: 'sigma1',
        label: 'Std Dev (σ₁)',
        min: 0.2,
        max: 4.0,
        defaultValue: 1.0,
        step: 0.1,
      ),
      const ParameterConfig(
        name: 'sigma2',
        label: 'Std Dev (σ₂)',
        min: 0.2,
        max: 4.0,
        defaultValue: 1.0,
        step: 0.1,
      ),
      const ParameterConfig(
        name: 'rho',
        label: 'Correlation (ρ)',
        min: -0.95,
        max: 0.95,
        defaultValue: 0.5,
        step: 0.05,
      ),
    ],
    creator: (p) {
      final s1 = math.max(0.2, p[2]);
      final s2 = math.max(0.2, p[3]);
      final rho = p[4].clamp(-0.95, 0.95);
      final cov12 = rho * s1 * s2;
      final mean = Vector<double>.fromList([
        p[0],
        p[1],
      ], type: DataType.float64);
      final cov = Matrix<double>.fromRows([
        [s1 * s1, cov12],
        [cov12, s2 * s2],
      ], type: DataType.float64);
      return MultivariateNormalDistribution(mean, cov);
    },
    supportLabel: (_) => 'ℝ²',
  ),
];
