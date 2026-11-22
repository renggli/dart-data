/// SymPy Algebraic Simplification, Expansion, Factorization, Rational, and
/// Trigonometric Benchmark Suite.
///
/// Attribution:
/// - Adapted from SymPy's `sympy/simplify/tests/test_simplify.py`,
///   `sympy/simplify/tests/test_radsimp.py`, `sympy/simplify/tests/test_trigsimp.py`,
///   and `sympy/polys/tests/test_polytools.py`
///   (https://github.com/sympy/sympy), distributed under the 3-Clause BSD
///   License (BSD-3-Clause).
library;

import 'package:data/symbolic.dart';

import 'cas_test_case.dart';

/// Benchmark suite covering canonical simplification, radical extraction,
/// logarithm/exponential combination, univariate & multivariate factoring,
/// rational cancellation, partial fractions, and trigonometric rewriting.
final CasTestSuite algebraSuite = CasTestSuite(
  name: 'algebra',
  description:
      'SymPy Simplify, Radsimp, Trigsimp & Polytools Suite (BSD-3-Clause)',
  buildCases: () => [
    // Canonical Simplification & Radicals
    simplifyCase('alg_simp_like_terms', '3*x + 2*y - x + 5*y', '2*x + 7*y'),
    simplifyCase('alg_simp_exponents', 'x^2 * x^3 / x', 'x^4'),
    simplifyCase('alg_simp_nested_frac', '(1 / (1 + 1/x))', 'x / (x + 1)'),
    simplifyCase('alg_simp_diff_squares_div', '(x^2 - y^2) / (x + y)', 'x - y'),
    simplifyCase(
      'alg_simp_exact_div_multi_add',
      '(x^2 + 2*x) * (y + 3) / x',
      '(x + 2) * (y + 3)',
    ),
    simplifyCase('alg_rad_1', 'sqrt(50) - 5*sqrt(2)', '0'),
    simplifyCase('alg_rad_2', 'sqrt(72) + sqrt(18)', '9*sqrt(2)'),
    simplifyCase('alg_rad_3', '(27)^(2/3)', '9'),
    simplifyCase('alg_rad_4', '(16 / 81)^(3/4)', '8 / 27'),
    simplifyCase(
      'alg_rad_5',
      'sqrt(x) * sqrt(x^3)',
      'x^2',
      assumptions: Assumptions.positive,
    ),
    simplifyCase(
      'alg_log_1',
      'ln(x) + ln(y) - ln(z)',
      'ln(x * y / z)',
      assumptions: Assumptions.positive,
    ),
    simplifyCase(
      'alg_log_2',
      '-ln(x) - ln(y)',
      '-ln(x * y)',
      assumptions: Assumptions.positive,
    ),
    simplifyCase(
      'alg_log_3',
      'exp(ln(x) + ln(y))',
      'x * y',
      assumptions: Assumptions.positive,
    ),

    // Polynomial Expansion
    expandCase('alg_exp_1', '(x + 1)^4', '1 + 4*x + 6*x^2 + 4*x^3 + x^4'),
    expandCase('alg_exp_2', '(x - y) * (x + y) * (x^2 + y^2)', 'x^4 - y^4'),
    expandCase(
      'alg_exp_3',
      '(x + y + z)^2',
      'x^2 + y^2 + z^2 + 2*x*y + 2*x*z + 2*y*z',
    ),
    expandCase('alg_exp_4', '(2*x - 3)^3', '-27 + 54*x - 36*x^2 + 8*x^3'),

    // Univariate & Multivariate Polynomial Factorization
    factorCase('alg_fac_1', 'x^2 - 5*x + 6', '(x - 2) * (x - 3)'),
    factorCase('alg_fac_2', '6*x^2 + 11*x + 3', '(2*x + 3) * (3*x + 1)'),
    factorCase(
      'alg_fac_3',
      'x^3 - 6*x^2 + 11*x - 6',
      '(x - 1) * (x - 2) * (x - 3)',
    ),
    factorCase(
      'alg_fac_4',
      'x^4 - 10*x^2 + 9',
      '(x - 3) * (x - 1) * (x + 1) * (x + 3)',
    ),
    factorCase('alg_fac_5', 'x^4 + 4', '(x^2 - 2*x + 2) * (x^2 + 2*x + 2)'),
    factorCase('alg_fac_6', 'x^4 + x^2 + 1', '(x^2 - x + 1) * (x^2 + x + 1)'),
    factorCase('alg_fac_7', 'a*x + a*y + b*x + b*y', '(a + b) * (x + y)'),
    factorCase('alg_fac_8', 'x^2 + (a + b)*x + a*b', '(x + a) * (x + b)'),
    factorCase('alg_fac_9', 'x^2 - 4*x*y + 4*y^2', '(x - 2*y)^2'),
    factorCase('alg_fac_10', '2*x^2 + 5*x*y + 2*y^2', '(2*x + y) * (x + 2*y)'),
    factorCase('alg_fac_11', 'x^3 - 3*x^2*y + 3*x*y^2 - y^3', '(x - y)^3'),
    factorCase('alg_fac_12', 'x^4 - y^4', '(x - y) * (x + y) * (x^2 + y^2)'),

    // Rational Function Manipulation (cancel, together, apart)
    cancelCase(
      'alg_rat_cancel_1',
      '(x^2 - 4) / (x^2 - 4*x + 4)',
      '(x + 2) / (x - 2)',
    ),
    cancelCase(
      'alg_rat_cancel_2',
      '(x^3 + y^3) / (x^2 - y^2)',
      '(x^2 - x*y + y^2) / (x - y)',
    ),
    togetherCase(
      'alg_rat_together_1',
      '1 / (x - 1) - 1 / (x + 1)',
      '2 / (x^2 - 1)',
    ),
    togetherCase(
      'alg_rat_together_2',
      '1/x + 1/x^2 + 1/x^3',
      '(x^2 + x + 1) / x^3',
    ),
    apartCase('alg_rat_apart_1', '1 / (x * (x + 1))', 'x', '1/x - 1/(x + 1)'),
    apartCase(
      'alg_rat_apart_2',
      '(2*x + 3) / ((x - 1) * (x + 2))',
      'x',
      '5 / (3*(x - 1)) + 1 / (3*(x + 2))',
    ),
    apartCase(
      'alg_rat_apart_3',
      '1 / ((x - 1)^2 * (x + 1))',
      'x',
      '1 / (4*(x + 1)) - 1 / (4*(x - 1)) + 1 / (2*(x - 1)^2)',
    ),

    // Trigonometric & Hyperbolic Simplification
    simplifyCase('alg_trig_1', 'sin(x)^2 + cos(x)^2 - 1', '0'),
    simplifyCase('alg_trig_2', '3*x*sin(y)^2 + 3*x*cos(y)^2', '3*x'),
    simplifyCase('alg_trig_3', 'tan(pi / 4) + cos(pi / 3) - sin(pi / 6)', '1'),
    simplifyCase('alg_trig_4', 'sin(asin(x)) + cos(acos(y))', 'x + y'),
    simplifyCase(
      'alg_trig_5',
      'acosh(cosh(x))',
      'abs(x)',
      assumptions: Assumptions.real,
    ),
    trigSimplifyCase(
      'alg_trig_6',
      'sin(x)^4 - cos(x)^4',
      'sin(x)^2 - cos(x)^2',
    ),
    trigSimplifyCase('alg_trig_7', '1 / cos(x)^2 - tan(x)^2', '1'),
    trigSimplifyCase('alg_trig_8', 'cosh(x)^2 - sinh(x)^2', '1'),
    trigExpandCase('alg_trig_9', 'sin(3*x)', '3*sin(x)*cos(x)^2 - sin(x)^3'),
    trigExpandCase(
      'alg_trig_10',
      'cos(x - y)',
      'cos(x)*cos(y) + sin(x)*sin(y)',
    ),
    simplifyCase('alg_exp_invhyp_1', 'exp(2 * atanh(x))', '(1 + x) / (1 - x)'),
    simplifyCase('alg_exp_invhyp_2', 'exp(asinh(x))', 'sqrt(x^2 + 1) + x'),
    simplifyCase('alg_exp_invhyp_3', 'exp(-asinh(x))', 'sqrt(x^2 + 1) - x'),
    simplifyCase('alg_exp_invhyp_4', 'exp(acosh(x))', 'x + sqrt(x^2 - 1)'),
    simplifyCase('alg_exp_invhyp_5', 'exp(-acosh(x))', 'x - sqrt(x^2 - 1)'),
  ],
);
