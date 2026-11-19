/// Michael J. Wester's Computer Algebra System Benchmark Suite.
///
/// Attribution:
/// - Michael J. Wester, "A Critique of the Mathematical Abilities of CA Systems",
///   in *Computer Algebra Systems: A Practical Guide*, John Wiley & Sons (1999).
/// - Adapted from SymPy's `sympy/utilities/tests/test_wester.py`
///   (https://github.com/sympy/sympy/blob/master/sympy/utilities/tests/test_wester.py),
///   distributed under the 3-Clause BSD License (BSD-3-Clause).
library;

import 'package:data/linear.dart';
import 'package:data/symbolic.dart';

import 'cas_test_case.dart';

/// Wester (1999) benchmark problems across exact arithmetic, domain assumptions,
/// algebra, trigonometry, complex analysis, matrices, sums, products, limits,
/// series, solvers, and differential equations.
final CasTestSuite westerSuite = CasTestSuite(
  name: 'wester',
  description: 'Michael Wester (1999) CAS Benchmark Suite (adapted from SymPy test_wester.py, BSD-3-Clause)',
  buildCases: () => [
    // Section A–C: Exact Numbers, Factorials, Binomials, Gamma, Radicals
    simplifyCase('wester_A1', '50! / 49!', '50'),
    simplifyCase('wester_A2', '10000! / 9999!', '10000'),
    simplifyCase('wester_A3', 'gamma(10000) / gamma(9999)', '9999'),
    simplifyCase('wester_A4', 'binomial(100, 50) / binomial(100, 49)', '51/50'),
    simplifyCase(
      'wester_A5',
      'binomial(10000, 2000) / binomial(10000, 1999)',
      '8001/2000',
    ),
    simplifyCase(
      'wester_C1',
      '1/2 + 1/3 + 1/4 + 1/5 + 1/6 + 1/7 + 1/8 + 1/9 + 1/10',
      '4861/2520',
    ),
    simplifyCase('wester_C8', '(-27)^(1/3) + (-1)^(1/2)', 'i - 3'),
    simplifyCase('wester_C10', 'sqrt(8) - 2*sqrt(2)', '0'),
    simplifyCase('wester_C11', 'sqrt(12) + 3*sqrt(3)', '5*sqrt(3)'),
    simplifyCase('wester_C12', 'sqrt(2 * 1009^2)', '1009 * sqrt(2)'),
    simplifyCase('wester_C14', 'gamma(1/2)', 'sqrt(pi)'),
    simplifyCase('wester_C15', 'gamma(7/2)', '15/8 * sqrt(pi)'),
    simplifyCase('wester_C16', 'gamma(-1/2)', '-2 * sqrt(pi)'),
    simplifyCase('wester_C17', 'zeta(0)', '-1/2'),
    simplifyCase('wester_C18', 'zeta(2)', 'pi^2 / 6'),
    simplifyCase('wester_C19', 'zeta(4)', 'pi^4 / 90'),
    simplifyCase('wester_C20', 'zeta(-1)', '-1/12'),
    simplifyCase('wester_C21', 'zeta(-2)', '0'),
    simplifyCase('wester_C22', 'beta(2, 3)', '1/12'),
    simplifyCase('wester_C23', 'beta(1/2, 1/2)', 'pi'),

    // Section D–F: Domain Assumptions, Branch Cuts, Inequalities
    simplifyCase(
      'wester_D1_unknown',
      'sqrt(x^2)',
      'sqrt(x^2)',
      assumptions: Assumptions.none,
    ),
    simplifyCase(
      'wester_D1_real',
      'sqrt(x^2)',
      'abs(x)',
      assumptions: Assumptions.real,
    ),
    simplifyCase(
      'wester_D1_positive',
      'sqrt(x^2)',
      'x',
      assumptions: Assumptions.positive,
    ),
    simplifyCase(
      'wester_D2_real',
      '((x^(2/3))^(3/2))',
      'abs(x)',
      assumptions: Assumptions.real,
    ),
    simplifyCase(
      'wester_D3_positive',
      'sqrt(x) * sqrt(y)',
      'sqrt(x * y)',
      assumptions: Assumptions.positive,
    ),
    simplifyCase(
      'wester_D4_real',
      'ln(exp(x))',
      'x',
      assumptions: Assumptions.real,
    ),
    simplifyCase(
      'wester_D5_positive',
      'ln(x * y) - (ln(x) + ln(y))',
      '0',
      assumptions: Assumptions.positive,
    ),
    simplifyCase(
      'wester_D6_real',
      'ln(x^2)',
      '2 * ln(abs(x))',
      assumptions: Assumptions.real,
    ),
    simplifyCase(
      'wester_D7_real',
      'ln(x^(2/3))',
      '2/3 * ln(abs(x))',
      assumptions: Assumptions.real,
    ),
    simplifyCase(
      'wester_D8_positive',
      'abs(x) + sign(x)',
      'x + 1',
      assumptions: Assumptions.positive,
    ),
    simplifyCase(
      'wester_D9_integer',
      'sin(n * pi)',
      '0',
      assumptions: const Assumptions(domains: {'n': VariableDomain.integer}),
    ),
    simplifyCase(
      'wester_D10_integer',
      'cos(2 * n * pi)',
      '1',
      assumptions: const Assumptions(domains: {'n': VariableDomain.integer}),
    ),
    simplifyCase(
      'wester_D11_integer',
      'floor(n) + ceil(n) + round(n)',
      '3 * n',
      assumptions: const Assumptions(domains: {'n': VariableDomain.integer}),
    ),

    // Section G–K: Polynomial & Rational Algebra (simplify, expand, factor, cancel, apart)
    simplifyCase('wester_G1', '(x^2 - 1) / (x - 1)', 'x + 1'),
    simplifyCase('wester_G2', '(x^3 - y^3) / (x - y)', 'x^2 + x*y + y^2'),
    simplifyCase('wester_G3', '(x^2 + x) * (y + 1) / x', '(1 + x) * (1 + y)'),
    expandCase('wester_G4', '(x + y)^3', 'x^3 + 3*x^2*y + 3*x*y^2 + y^3'),
    factorCase('wester_H1', 'x^2 - y^2', '(x - y) * (x + y)'),
    factorCase('wester_H2', 'x^3 - y^3', '(x - y) * (x^2 + x*y + y^2)'),
    factorCase('wester_H3', 'x^3 + y^3', '(x + y) * (x^2 - x*y + y^2)'),
    factorCase('wester_H4', 'x^2 + 2*x*y + y^2', '(x + y)^2'),
    factorCase('wester_H5', 'x^3 + 3*x^2*y + 3*x*y^2 + y^3', '(x + y)^3'),
    factorCase('wester_H6', 'x^2 - x*y - 6*y^2', '(x - 3*y) * (x + 2*y)'),
    factorCase('wester_H7', 'x^4 - 1', '(x - 1) * (x + 1) * (x^2 + 1)'),
    factorCase(
      'wester_H8',
      'x^6 - 1',
      '(x - 1) * (x + 1) * (x^2 - x + 1) * (x^2 + x + 1)',
    ),
    cancelCase('wester_I1', '(x^2 - y^2) / (x - y)', 'x + y'),
    cancelCase('wester_I2', '(x^3 - 1) / (x^2 - 1)', '(x^2 + x + 1) / (x + 1)'),
    apartCase(
      'wester_J1',
      '1 / (x^2 - 1)',
      'x',
      '1 / (2*(x - 1)) - 1 / (2*(x + 1))',
    ),
    apartCase(
      'wester_J2',
      '(3*x + 5) / (x^2 + 3*x + 2)',
      'x',
      '2 / (x + 1) + 1 / (x + 2)',
    ),
    togetherCase('wester_J3', '1/x + 1/y', '(x + y) / (x * y)'),

    // Section L–N: Trigonometry, Hyperbolics, and Complex Analysis
    simplifyCase('wester_L1', 'sin(x)^2 + cos(x)^2', '1'),
    simplifyCase('wester_L2', 'a * sin(x)^2 + a * cos(x)^2', 'a'),
    simplifyCase('wester_L3', 'cosh(x)^2 - sinh(x)^2', '1'),
    simplifyCase('wester_L4', '2 * y * cosh(x)^2 - 2 * y * sinh(x)^2', '2 * y'),
    trigSimplifyCase('wester_L5', 'sin(2*x) / (2 * sin(x))', 'cos(x)'),
    trigSimplifyCase('wester_L6', 'cos(2*x) + 2 * sin(x)^2', '1'),
    trigExpandCase('wester_L7', 'sin(x + y)', 'sin(x)*cos(y) + cos(x)*sin(y)'),
    trigExpandCase('wester_L8', 'cos(2*x)', 'cos(x)^2 - sin(x)^2'),
    simplifyCase('wester_M1', 're(3 + 4*i) + im(3 + 4*i)', '7'),
    simplifyCase('wester_M2', 'abs(3 + 4*i)', '5'),
    simplifyCase('wester_M3', 'conj(3 + 4*i)', '3 - 4*i'),
    simplifyCase(
      'wester_M4',
      're(x + i*y) + im(x + i*y)',
      'x + y',
      assumptions: Assumptions.real,
    ),
    simplifyCase(
      'wester_M5',
      'conj(x + i*y)',
      'x - i*y',
      assumptions: Assumptions.real,
    ),
    rectangularCase(
      'wester_M6',
      'exp(i * x)',
      'cos(x) + i * sin(x)',
      assumptions: Assumptions.real,
    ),

    // Section O–Q: Equation & System Solving
    solveCase('wester_O1', 'x^2 - 5*x + 6', 'x', ['2', '3']),
    solveCase('wester_O2', 'x^3 - 6*x^2 + 11*x - 6', 'x', ['1', '2', '3']),
    solveCase('wester_O3', 'x^4 - 5*x^2 + 4', 'x', ['-2', '-1', '1', '2']),
    solveCase('wester_O4', 'exp(x) - 5', 'x', ['ln(5)']),
    solveCase('wester_O5', 'x * exp(x) - 1', 'x', ['LambertW(1)']),
    solveCase(
      'wester_O6',
      'sqrt(x) + a',
      'x',
      [],
      assumptions: Assumptions.positive,
    ),

    // Section R–S: Symbolic Matrix Algebra
    customCase(
      'wester_R1_matrix_det',
      'det([[a, b], [c, d]]) == a*d - b*c',
      () {
        final m = Matrix<Expr>.fromRows([
          [parseCas('a'), parseCas('b')],
          [parseCas('c'), parseCas('d')],
        ], type: exprDataType);
        final det = m.determinant();
        final exp = parseCas('a*d - b*c').simplify();
        final ok = verifyExprEquivalent(det, exp);
        return (ok: ok, detail: ok ? null : 'got $det');
      },
    ),
    customCase(
      'wester_R2_matrix_inv',
      'inv([[1, x], [0, 1]]) == [[1, -x], [0, 1]]',
      () {
        final m = Matrix<Expr>.fromRows([
          [IntegerNumber.one, const Variable('x')],
          [IntegerNumber.zero, IntegerNumber.one],
        ], type: exprDataType);
        final inv = m.inverse();
        if (inv == null) return (ok: false, detail: 'inverse returned null');
        final ok =
            inv.get(0, 0) == IntegerNumber.one &&
            inv.get(0, 1) == (-const Variable('x')).simplify() &&
            inv.get(1, 0) == IntegerNumber.zero &&
            inv.get(1, 1) == IntegerNumber.one;
        return (ok: ok, detail: ok ? null : 'got $inv');
      },
    ),
    customCase(
      'wester_R3_eigenvalues',
      'eigenvalues([[2, 1], [1, 2]]) == [1, 3]',
      () {
        final m = Matrix<Expr>.fromRows([
          [IntegerNumber.two, IntegerNumber.one],
          [IntegerNumber.one, IntegerNumber.two],
        ], type: exprDataType);
        final eigs = m.eigenvalues();
        final ok =
            eigs.length == 2 &&
            eigs.contains(IntegerNumber.one) &&
            eigs.contains(IntegerNumber.of(3));
        return (ok: ok, detail: ok ? null : 'got $eigs');
      },
    ),

    // Section T–U: Symbolic Sums & Products
    sumCase('wester_T1', 'k', 'k', '1', 'n', 'n * (n + 1) / 2'),
    sumCase('wester_T2', 'k^2', 'k', '1', 'n', 'n * (n + 1) * (2*n + 1) / 6'),
    sumCase('wester_T3', 'k^3', 'k', '1', 'n', 'n^2 * (n + 1)^2 / 4'),
    sumCase('wester_T4', '1 / (k * (k + 1))', 'k', '1', 'n', 'n / (n + 1)'),
    sumCase('wester_T5', '1 / k^2', 'k', '1', 'oo', 'pi^2 / 6'),
    sumCase('wester_T6', '1 / k^4', 'k', '1', 'oo', 'pi^4 / 90'),
    sumCase('wester_T7', 'x^k / k!', 'k', '0', 'oo', 'exp(x)'),
    sumCase('wester_T8', 'binomial(n, k)', 'k', '0', 'n', '2^n'),
    productCase('wester_U1', 'k', 'k', '1', '5', '120'),
    productCase('wester_U2', '(k + 1) / k', 'k', '1', 'n', 'n + 1'),
    productCase('wester_U3', '1 - 1 / k^2', 'k', '2', 'n', '(n + 1) / (2 * n)'),
    productCase(
      'wester_U4',
      '1 - x^2 / k^2',
      'k',
      '1',
      'oo',
      'sin(pi * x) / (pi * x)',
    ),
    productCase('wester_U5', 'cos(x / 2^k)', 'k', '1', 'oo', 'sin(x) / x'),

    // Section V–W: Limits & Series
    limitCase('wester_V1', 'sin(x) / x', 'x', '0', '1'),
    limitCase('wester_V2', '(1 - cos(x)) / x^2', 'x', '0', '1/2'),
    limitCase('wester_V3', '(1 + 1/x)^x', 'x', 'oo', 'E'),
    limitCase('wester_V4', '(1 + a/x)^x', 'x', 'oo', 'exp(a)'),
    limitCase(
      'wester_V5',
      'x * ln(x)',
      'x',
      '0',
      '0',
      direction: LimitDirection.fromAbove,
    ),
    limitCase('wester_V6', '1/x - 1/sin(x)', 'x', '0', '0'),
    seriesCase(
      'wester_W1',
      'sin(x)',
      'x',
      order: 6,
      expected: 'x - x^3/6 + x^5/120 + O(x^6)',
    ),
    seriesCase(
      'wester_W2',
      'cos(x)',
      'x',
      order: 5,
      expected: '1 - x^2/2 + x^4/24 + O(x^5)',
    ),
    seriesCase(
      'wester_W3',
      'tan(x)',
      'x',
      order: 6,
      expected: 'x + x^3/3 + 2*x^5/15 + O(x^6)',
    ),
    seriesCase(
      'wester_W4',
      'exp(x)',
      'x',
      order: 4,
      expected: '1 + x + x^2/2 + x^3/6 + O(x^4)',
    ),
    seriesCase(
      'wester_W5',
      'ln(1 + x)',
      'x',
      order: 4,
      expected: 'x - x^2/2 + x^3/3 + O(x^4)',
    ),

    // Section Y: Differentiation & Indefinite/Definite Integration
    differentiateCase(
      'wester_Y1_diff',
      'x^3 * sin(x)',
      'x',
      '3*x^2*sin(x) + x^3*cos(x)',
    ),
    differentiateCase('wester_Y2_diff', 'ln(sin(x))', 'x', 'cos(x) / sin(x)'),
    integrateCase(
      'wester_Y3_int_indef',
      'x * exp(x)',
      'x',
      expected: '(x - 1) * exp(x)',
    ),
    integrateCase(
      'wester_Y4_int_indef',
      '1 / (x^2 + 1)',
      'x',
      expected: 'atan(x)',
    ),
    integrateCase(
      'wester_Y5_int_def_gaussian',
      'exp(-x^2)',
      'x',
      lower: '-oo',
      upper: 'oo',
      expected: 'sqrt(pi)',
    ),
    integrateCase(
      'wester_Y6_int_def_dirichlet',
      'sin(x) / x',
      'x',
      lower: '0',
      upper: 'oo',
      expected: 'pi / 2',
    ),
    integrateCase(
      'wester_Y7_int_def_pole_split',
      '((x - 1)^2)^(-1/3)',
      'x',
      lower: '0',
      upper: '2',
      expected: '6',
    ),
    integrateCase(
      'wester_Y8_int_def_divergent_pole',
      '1 / (x - 1)^2',
      'x',
      lower: '0',
      upper: '2',
      expected: 'oo',
    ),

    // Section Z: Ordinary Differential Equations
    odeCase(
      'wester_Z1',
      'diff(y, x) - y',
      'y',
      'x',
      'exp(x)',
      at: '0',
      initialValue: '1',
    ),
    odeCase(
      'wester_Z2',
      'diff(y, x) + 2*x*y',
      'y',
      'x',
      'exp(-x^2)',
      at: '0',
      initialValue: '1',
    ),
  ],
);
