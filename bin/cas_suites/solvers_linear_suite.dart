/// SymPy Equation Solvers, Ordinary Differential Equations, and Symbolic
/// Linear Algebra Benchmark Suite.
///
/// Attribution:
/// - Adapted from SymPy's `sympy/solvers/tests/test_solvers.py`,
///   `sympy/solvers/ode/tests/test_ode.py`, and
///   `sympy/matrices/tests/test_matrices.py`
///   (https://github.com/sympy/sympy), distributed under the 3-Clause BSD
///   License (BSD-3-Clause).
library;

import 'package:data/linear.dart';
import 'package:data/symbolic.dart';

import 'cas_test_case.dart';

/// Benchmark suite covering univariate polynomial, radical, exponential,
/// logarithmic, and trigonometric equation solving, linear and nonlinear
/// polynomial system solving, 1st/2nd-order ODEs, multivariable calculus,
/// and symbolic matrix operations.
final CasTestSuite solversLinearSuite = CasTestSuite(
  name: 'solvers_linear',
  description: 'SymPy Solvers, ODEs, Multivariable Calculus & Symbolic Matrices Suite (BSD-3-Clause)',
  buildCases: () => [
    // Univariate Polynomial, Radical, Transcendental & Trigonometric Equations
    solveCase('sol_linear_param', 'a*x + b', 'x', ['-b / a']),
    solveCase('sol_quad_symbolic', 'x^2 - (a + b)*x + a*b', 'x', ['a', 'b']),
    solveCase('sol_cubic_roots', 'x^3 - 7*x + 6', 'x', ['-3', '1', '2']),
    solveCase('sol_biquadratic', 'x^4 - 13*x^2 + 36', 'x', [
      '-3',
      '-2',
      '2',
      '3',
    ]),
    solveCase('sol_radical_valid', 'sqrt(x + 3) - x + 3', 'x', ['6']),
    solveCase('sol_radical_extraneous', 'sqrt(x) + 2', 'x', []),
    solveCase('sol_domain_positive', 'x^2 - 4', 'x', [
      '2',
    ], assumptions: Assumptions.positive),
    solveCase('sol_domain_integer', '2*x^2 - 5*x + 2', 'x', [
      '2',
    ], assumptions: const Assumptions(domains: {'x': VariableDomain.integer})),
    solveCase(
      'sol_domain_symbolic_integer',
      'x - (n + 1)',
      'x',
      ['n + 1'],
      assumptions: const Assumptions(
        domains: {'x': VariableDomain.integer, 'n': VariableDomain.integer},
      ),
    ),
    solveCase('sol_log_combine', 'ln(x) + ln(x - 1) - ln(2)', 'x', ['2']),
    solveCase('sol_exp_quadratic', 'exp(2*x) - 3*exp(x) + 2', 'x', [
      '0',
      'ln(2)',
    ]),
    solveCase('sol_lambertW', 'x * exp(x) - 2', 'x', ['LambertW(2)']),
    solveCase('sol_trig_sin', 'sin(x) - 1/2', 'x', ['pi / 6', '5 * pi / 6']),
    solveCase('sol_trig_cos', 'cos(x) - 1/2', 'x', ['pi / 3', '5 * pi / 3']),

    // Linear & Nonlinear Polynomial Systems
    customCase(
      'sys_linear_2x2',
      'solve([x + y - 5, x - y - 1], [x, y]) == [{x: 3, y: 2}]',
      () {
        final sols = [
          parseCas('x + y - 5'),
          parseCas('x - y - 1'),
        ].solve(['x', 'y']);
        final ok =
            sols.length == 1 &&
            sols.first['x'] == IntegerNumber.of(3) &&
            sols.first['y'] == IntegerNumber.two;
        return (ok: ok, detail: ok ? null : 'got $sols');
      },
    ),
    customCase(
      'sys_linear_symbolic',
      'solve([a*x + y - 1, x + y - 2], [x, y])',
      () {
        final sols = [
          parseCas('a*x + y - 1'),
          parseCas('x + y - 2'),
        ].solve(['x', 'y']);
        final ok =
            sols.length == 1 &&
            verifyExprEquivalent(sols.first['x']!, parseCas('-1 / (a - 1)')) &&
            verifyExprEquivalent(
              sols.first['y']!,
              parseCas('(2*a - 1) / (a - 1)'),
            );
        return (ok: ok, detail: ok ? null : 'got $sols');
      },
    ),
    customCase(
      'sys_poly_circle_line',
      'solve([x^2 + y^2 - 5, x - y - 1], [x, y])',
      () {
        final sols = [
          parseCas('x^2 + y^2 - 5'),
          parseCas('x - y - 1'),
        ].solve(['x', 'y']);
        final ok =
            sols.length == 2 &&
            sols.any(
              (m) => m['x'] == IntegerNumber.two && m['y'] == IntegerNumber.one,
            ) &&
            sols.any(
              (m) =>
                  m['x'] == IntegerNumber.negativeOne &&
                  m['y'] == IntegerNumber.of(-2),
            );
        return (ok: ok, detail: ok ? null : 'got $sols');
      },
    ),

    // Ordinary Differential Equations (1st & 2nd Order)
    odeCase(
      'ode_separable',
      'diff(y, x) - x * y',
      'y',
      'x',
      '2 * exp(x^2 / 2)',
      at: '0',
      initialValue: '2',
    ),
    odeCase(
      'ode_linear_first_order',
      'diff(y, x) + y - exp(x)',
      'y',
      'x',
      '1/2 * exp(x) + 1/2 * exp(-x)',
      at: '0',
      initialValue: '1',
    ),
    odeCase(
      'ode_harmonic_2nd_order',
      'diff(y, x, 2) + y',
      'y',
      'x',
      'C1 * cos(x) + C2 * sin(x)',
    ),
    odeCase(
      'ode_damped_roots_2nd_order',
      'diff(y, x, 2) - 3 * diff(y, x) + 2 * y',
      'y',
      'x',
      'C1 * exp(x) + C2 * exp(2 * x)',
    ),

    // Multivariable Calculus & Symbolic Matrix Algebra
    customCase('calc_grad_hessian', 'gradient and hessian of x^2*y + y^3', () {
      final f = parseCas('x^2 * y + y^3');
      final grad = f.gradient(['x', 'y']);
      final hess = f.hessian(['x', 'y']);
      final ok =
          verifyExprEquivalent(grad[0], parseCas('2*x*y')) &&
          verifyExprEquivalent(grad[1], parseCas('x^2 + 3*y^2')) &&
          verifyExprEquivalent(hess.get(0, 0), parseCas('2*y')) &&
          verifyExprEquivalent(hess.get(0, 1), parseCas('2*x')) &&
          verifyExprEquivalent(hess.get(1, 1), parseCas('6*y'));
      return (ok: ok, detail: ok ? null : 'grad=$grad, hess=$hess');
    }),
    customCase(
      'mat_3x3_bareiss_det',
      'det of 3x3 Vandermonde matrix == (b - a)*(c - a)*(c - b)',
      () {
        final v = Matrix<Expr>.fromRows([
          [IntegerNumber.one, parseCas('a'), parseCas('a^2')],
          [IntegerNumber.one, parseCas('b'), parseCas('b^2')],
          [IntegerNumber.one, parseCas('c'), parseCas('c^2')],
        ], type: exprDataType);
        final det = v.determinant();
        final exp = parseCas('(b - a) * (c - a) * (c - b)');
        final ok = verifyExprEquivalent(det, exp);
        return (ok: ok, detail: ok ? null : 'got $det');
      },
    ),
    customCase(
      'mat_charpoly',
      'characteristicPolynomial of [[a, 1], [0, b]]',
      () {
        final m = Matrix<Expr>.fromRows([
          [parseCas('a'), IntegerNumber.one],
          [IntegerNumber.zero, parseCas('b')],
        ], type: exprDataType);
        final cp = m.characteristicPolynomial('lambda');
        final exp = parseCas('(lambda - a) * (lambda - b)');
        final ok = verifyExprEquivalent(cp, exp);
        return (ok: ok, detail: ok ? null : 'got $cp');
      },
    ),
  ],
);
