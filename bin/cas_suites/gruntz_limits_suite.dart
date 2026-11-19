/// Dominik Gruntz's Limit & Asymptotic Benchmark Suite.
///
/// Attribution:
/// - Dominik Gruntz, "On Computing Limits in a Symbolic Manipulation System",
///   PhD Thesis, ETH Zürich (1996), Chapter 8.
/// - Adapted from SymPy's `sympy/series/tests/test_gruntz.py` and
///   `sympy/series/tests/test_limits.py`
///   (https://github.com/sympy/sympy/blob/master/sympy/series/tests/test_gruntz.py),
///   distributed under the 3-Clause BSD License (BSD-3-Clause).
library;

import 'package:data/symbolic.dart';

import 'cas_test_case.dart';

/// Gruntz (1996) thesis problems and SymPy limit regression cases covering
/// exponential-logarithmic towers, cancelling poles, directional singularities,
/// parameter-dependent limits, and oscillating divergences.
final CasTestSuite gruntzLimitsSuite = CasTestSuite(
  name: 'gruntz_limits',
  description:
      'Dominik Gruntz (1996) ETH Thesis & SymPy Limit Suite (BSD-3-Clause)',
  buildCases: () => [
    // Gruntz Thesis Section 8.1 – 8.20 & exp-log towers
    limitCase(
      'gruntz_basic_exp_decay',
      'exp(x) * (exp(1/x - exp(-x)) - exp(1/x))',
      'x',
      'oo',
      '-1',
    ),
    limitCase(
      'gruntz_exp_tower_1',
      'exp(x) * (exp(1/x + exp(-x) + exp(-x^2)) - exp(1/x - exp(-exp(x))))',
      'x',
      'oo',
      '1',
    ),
    limitCase(
      'gruntz_8_1',
      'exp(x) * (exp(1/x - exp(-x)) - exp(1/x))',
      'x',
      'oo',
      '-1',
    ),
    limitCase(
      'gruntz_8_2',
      'exp(x) * (exp(1/x + exp(-x) + exp(-x^2)) - exp(1/x - exp(-exp(x))))',
      'x',
      'oo',
      '1',
    ),
    limitCase(
      'gruntz_8_3',
      'exp(exp(x - exp(-x)) / (1 - 1/x)) - exp(exp(x))',
      'x',
      'oo',
      'oo',
    ),
    limitCase('gruntz_8_11', '(exp(x) + x) / exp(x)', 'x', 'oo', '1'),
    limitCase('gruntz_8_12', 'x^3 / exp(x)', 'x', 'oo', '0'),
    limitCase('gruntz_8_13', 'ln(x)^2 / x', 'x', 'oo', '0'),
    limitCase(
      'gruntz_8_14',
      'x^x',
      'x',
      '0',
      '1',
      direction: LimitDirection.fromAbove,
    ),
    limitCase(
      'gruntz_8_15',
      '1 / (x * ln(x)^2) - 1 / (x * (ln(x) + 1)^2)',
      'x',
      'oo',
      '0',
    ),
    limitCase(
      'gruntz_8_16',
      '(x^x - 1) / (x * ln(x))',
      'x',
      '0',
      '1',
      direction: LimitDirection.fromAbove,
    ),
    limitCase('gruntz_8_17', '(exp(x) - 1) / x', 'x', '0', '1'),
    limitCase('gruntz_8_18', 'ln(1 + x) / x', 'x', '0', '1'),
    limitCase('gruntz_8_19', '(1 + 1/x)^x', 'x', 'oo', 'E'),
    limitCase('gruntz_8_20', '(1 + 2/x)^(3*x)', 'x', 'oo', 'exp(6)'),

    // Algebraic & Radical Indeterminate Forms at Infinity
    limitCase('limit_radical_diff_1', 'sqrt(x^2 + x) - x', 'x', 'oo', '1/2'),
    limitCase(
      'limit_radical_diff_2',
      'sqrt(x^2 + a*x + b) - x',
      'x',
      'oo',
      'a / 2',
    ),
    limitCase(
      'limit_radical_diff_3',
      'x * (sqrt(x^2 + 1) - x)',
      'x',
      'oo',
      '1/2',
    ),
    limitCase(
      'limit_cube_root_diff',
      '(x^3 + x^2)^(1/3) - x',
      'x',
      'oo',
      '1/3',
    ),
    limitCase(
      'limit_rat_same_deg',
      '(3*x^3 - 2*x + 1) / (5*x^3 + x^2 - 4)',
      'x',
      'oo',
      '3/5',
    ),
    limitCase(
      'limit_rat_lower_deg',
      '(10*x^2 + 5) / (x^3 + 1)',
      'x',
      'oo',
      '0',
    ),
    limitCase(
      'limit_rat_higher_deg',
      '(2*x^4 + 1) / (x^2 + 1)',
      'x',
      'oo',
      'oo',
    ),
    limitCase(
      'limit_rat_neg_inf',
      '(2*x^3 + 1) / (x^2 + 1)',
      'x',
      '-oo',
      '-oo',
    ),

    // Cancelling Poles & L'Hôpital / Laurent Forms
    limitCase('limit_cancel_pole_1', '1/x - 1/sin(x)', 'x', '0', '0'),
    limitCase('limit_cancel_pole_2', '1/x^2 - 1/sin(x)^2', 'x', '0', '-1/3'),
    limitCase('limit_cancel_pole_3', '1/sin(x)^2 - 1/tan(x)^2', 'x', '0', '1'),
    limitCase(
      'limit_cancel_pole_4',
      '(1 / (x - 1)) - (2 / (x^2 - 1))',
      'x',
      '1',
      '1/2',
    ),
    limitCase('limit_trig_1', '(sin(x) - x) / x^3', 'x', '0', '-1/6'),
    limitCase('limit_trig_2', '(tan(x) - sin(x)) / x^3', 'x', '0', '1/2'),
    limitCase('limit_trig_3', '(1 - cos(x)) / (x * sin(x))', 'x', '0', '1/2'),
    limitCase('limit_trig_4', 'sin(a * x) / sin(b * x)', 'x', '0', 'a / b'),
    limitCase('limit_hyp_1', '(cosh(x) - 1) / x^2', 'x', '0', '1/2'),
    limitCase('limit_hyp_2', '(sinh(x) - x) / x^3', 'x', '0', '1/6'),
    limitCase('limit_inv_trig_1', 'asin(x) / x', 'x', '0', '1'),
    limitCase('limit_inv_trig_2', 'atan(x) / x', 'x', '0', '1'),
    limitCase('limit_inv_trig_inf', 'atan(x)', 'x', 'oo', 'pi / 2'),
    limitCase('limit_inv_trig_neg_inf', 'atan(x)', 'x', '-oo', '-pi / 2'),

    // Directional & Branch-Jump Limits
    limitCase(
      'limit_dir_inv_pos',
      '1 / x',
      'x',
      '0',
      'oo',
      direction: LimitDirection.fromAbove,
    ),
    limitCase(
      'limit_dir_inv_neg',
      '1 / x',
      'x',
      '0',
      '-oo',
      direction: LimitDirection.fromBelow,
    ),
    limitDoesNotExistCase('limit_dir_inv_both', '1 / x', 'x', '0'),
    limitCase(
      'limit_dir_abs_pos',
      'abs(x) / x',
      'x',
      '0',
      '1',
      direction: LimitDirection.fromAbove,
    ),
    limitCase(
      'limit_dir_abs_neg',
      'abs(x) / x',
      'x',
      '0',
      '-1',
      direction: LimitDirection.fromBelow,
    ),
    limitDoesNotExistCase('limit_dir_abs_both', 'abs(x) / x', 'x', '0'),
    limitCase('limit_even_pole', '1 / x^2', 'x', '0', 'oo'),
    limitCase(
      'limit_param_pole_pos',
      'a / x^2',
      'x',
      '0',
      'oo',
      assumptions: const Assumptions(domains: {'a': VariableDomain.positive}),
    ),
    limitDoesNotExistCase(
      'limit_param_pole_unknown',
      'a / x^2',
      'x',
      '0',
      assumptions: Assumptions.none,
    ),

    // Special Function & Squeeze / Oscillation Limits
    limitCase('limit_erf_inf', 'erf(x)', 'x', 'oo', '1'),
    limitCase('limit_erf_neg_inf', 'erf(x)', 'x', '-oo', '-1'),
    limitCase('limit_erfc_inf', 'erfc(x)', 'x', 'oo', '0'),
    limitCase('limit_erf_ratio', 'erf(x) / x', 'x', '0', '2 / sqrt(pi)'),
    limitCase('limit_lambertW', 'LambertW(x) / x', 'x', '0', '1'),
    limitCase('limit_squeeze_sin', 'sin(x) / x', 'x', 'oo', '0'),
    limitCase('limit_squeeze_cos', 'exp(-x) * cos(x)', 'x', 'oo', '0'),
    limitDoesNotExistCase('limit_osc_sin_inf', 'sin(x)', 'x', 'oo'),
    limitDoesNotExistCase('limit_osc_neg_exp', '(-2)^x * x', 'x', 'oo'),
  ],
);
