import 'dart:math' as math;

import 'package:data/stats.dart';

/// Configuration of a single parameter.
class ParameterConfig {
  final String name;
  final String label;
  final double min;
  final double max;
  final double defaultValue;
  final double step;
  final bool isInt;

  new({
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

  new({
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
      ParameterConfig(
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
      ParameterConfig(
        name: 'alpha',
        label: 'Shape (α)',
        min: 0.1,
        max: 10.0,
        defaultValue: 2.0,
        step: 0.1,
      ),
      ParameterConfig(
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
      ParameterConfig(
        name: 'n',
        label: 'Trials (n)',
        min: 1,
        max: 100,
        defaultValue: 10,
        step: 1,
        isInt: true,
      ),
      ParameterConfig(
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
      ParameterConfig(
        name: 'xo',
        label: 'Location (x₀)',
        min: -10.0,
        max: 10.0,
        defaultValue: 0.0,
        step: 0.1,
      ),
      ParameterConfig(
        name: 'gamma',
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
      ParameterConfig(
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
      ParameterConfig(
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
      ParameterConfig(
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
      ParameterConfig(
        name: 'dof1',
        label: 'Numerator DOF (d₁)',
        min: 1.0,
        max: 30.0,
        defaultValue: 5.0,
        step: 1.0,
      ),
      ParameterConfig(
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
      ParameterConfig(
        name: 'shape',
        label: 'Shape (k)',
        min: 0.1,
        max: 10.0,
        defaultValue: 2.0,
        step: 0.1,
      ),
      ParameterConfig(
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
      ParameterConfig(
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
      ParameterConfig(
        name: 'N',
        label: 'Population Size (N)',
        min: 10,
        max: 150,
        defaultValue: 50,
        step: 1,
        isInt: true,
      ),
      ParameterConfig(
        name: 'K',
        label: 'Success States (K)',
        min: 1,
        max: 150,
        defaultValue: 20,
        step: 1,
        isInt: true,
      ),
      ParameterConfig(
        name: 'n',
        label: 'Draws (n)',
        min: 1,
        max: 150,
        defaultValue: 10,
        step: 1,
        isInt: true,
      ),
    ],
    creator: (p) {
      final N = p[0].toInt();
      final K = math.min(p[1].toInt(), N);
      final n = math.min(p[2].toInt(), N);
      return HypergeometricDistribution(N, K, n);
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
      ParameterConfig(
        name: 'shape',
        label: 'Shape (α)',
        min: 0.1,
        max: 10.0,
        defaultValue: 3.0,
        step: 0.1,
      ),
      ParameterConfig(
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
      ParameterConfig(
        name: 'mu',
        label: 'Location (μ)',
        min: -10.0,
        max: 10.0,
        defaultValue: 0.0,
        step: 0.1,
      ),
      ParameterConfig(
        name: 'b',
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
      ParameterConfig(
        name: 'mu',
        label: 'Log Mean (μ)',
        min: -3.0,
        max: 3.0,
        defaultValue: 0.0,
        step: 0.1,
      ),
      ParameterConfig(
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
      ParameterConfig(
        name: 'mu',
        label: 'Location (μ)',
        min: -10.0,
        max: 10.0,
        defaultValue: 0.0,
        step: 0.1,
      ),
      ParameterConfig(
        name: 's',
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
      ParameterConfig(
        name: 'r',
        label: 'Failures Limit (r)',
        min: 0.1,
        max: 20.0,
        defaultValue: 5.0,
        step: 0.5,
      ),
      ParameterConfig(
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
      ParameterConfig(
        name: 'mu',
        label: 'Mean (μ)',
        min: -10.0,
        max: 10.0,
        defaultValue: 0.0,
        step: 0.1,
      ),
      ParameterConfig(
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
      ParameterConfig(
        name: 'xo',
        label: 'Scale (x₀)',
        min: 0.5,
        max: 5.0,
        defaultValue: 1.0,
        step: 0.1,
      ),
      ParameterConfig(
        name: 'alpha',
        label: 'Shape (α)',
        min: 0.5,
        max: 10.0,
        defaultValue: 3.0,
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
      ParameterConfig(
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
      ParameterConfig(
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
      ParameterConfig(
        name: 'a',
        label: 'Min (a)',
        min: -10.0,
        max: 10.0,
        defaultValue: -2.0,
        step: 0.1,
      ),
      ParameterConfig(
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
      ParameterConfig(
        name: 'a',
        label: 'Min (a)',
        min: -20,
        max: 20,
        defaultValue: 1,
        step: 1,
        isInt: true,
      ),
      ParameterConfig(
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
      ParameterConfig(
        name: 'scale',
        label: 'Scale (λ)',
        min: 0.1,
        max: 10.0,
        defaultValue: 1.5,
        step: 0.1,
      ),
      ParameterConfig(
        name: 'shape',
        label: 'Shape (k)',
        min: 0.1,
        max: 10.0,
        defaultValue: 2.0,
        step: 0.1,
      ),
    ],
    creator: (p) => WeibullDistribution(p[0], p[1]),
  ),
];
