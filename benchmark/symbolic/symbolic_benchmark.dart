/// Baseline benchmarks for the symbolic subsystem.
///
/// Run with `dart run benchmark/symbolic/symbolic_benchmark.dart`, or compile
/// with `dart compile js` and run under `node` to obtain dart2js numbers.
/// Pass benchmark name substrings as arguments to run a subset.
library;

// ignore_for_file: avoid_print

import 'package:data/linear.dart';
import 'package:data/symbolic.dart';

import 'runner.dart';

/// Integrands that the current integrator handles in closed form.
const integrals = [
  '1', 'x', 'x^2', 'x^5 + 3*x^2 - 7', '1/x', 'x^(-2)', 'sqrt(x)', //
  '1/sqrt(x)', 'sin(x)', 'cos(x)', 'tan(x)', 'exp(x)', 'exp(2*x+1)',
  'sin(3*x)', 'cos(2*x - 1)', 'x*exp(x)', 'x*sin(x)', 'x*cos(x)',
  'x^2*exp(x)', 'x^2*sin(x)', 'ln(x)', 'x*ln(x)', 'exp(x)*sin(x)',
  'exp(x)*cos(x)', '1/(1+x^2)', '1/(x+1)', '1/(2*x+3)', 'x/(x^2+1)',
  '1/sqrt(1-x^2)', 'sinh(x)', 'cosh(x)', 'tanh(x)', '2*x*exp(x^2)',
  'cos(x)*exp(sin(x))', '(x+1)^5', '(2*x+1)^3', '1/(x^2+4)', 'atan(x)',
  'asin(x)', 'exp(-x)', 'x*exp(-x)', '3^x', 'x/(x+1)', '(x^2+1)/(x-1)',
  'x*sqrt(x)',
];

/// Valid expressions drawn from the parser and simplifier test suites.
const simplifications = [
  '- -x', '-(x + 1)', '-3^2', '-sin(x)^2 - cos(x)^2', '(-3)^2', '(-x)^2', //
  '((x + 1) * (y - 2)) / (x + y)', '(1 + 2) * 3', '(2 * 3) ^ 2',
  '1 - cos(x)^2', '1 - sin(x)^2', '1 + 2 * 3', '1 + sinh(x)^2', '1/2',
  '10 - 3 - 2', '2 * 3 ^ 2', '2 * pi', '2 ^ (-3)', '2 ^ 3 ^ 2',
  '5 * cos(x)^2 + 5 * sin(x)^2', '5 * sin(x)^2 + 3 * cos(x)^2', '8 / 4 / 2',
  'abs(-5 * x)', 'abs(abs(x))', 'abs(exp(x))', 'acos(cos(x))',
  'asin(-x) + asin(x)', 'asin(sin(x))', 'atan(-x) + atan(x)', 'cos(-5 * x)',
  'cos(-x) - cos(x)', 'cos(acos(x))', 'cos(pi)', 'cos(x)^2 + sin(x)^2',
  'cosh(-x) - cosh(x)', 'cosh(2 * x + y)^2 - sinh(2 * x + y)^2',
  'cosh(x)^2 - 1', 'exp(-ln(x))', 'exp(5 * ln(x))', 'exp(ln(x))',
  'exp(x) * exp(y) / exp(z)', 'ln(a) - ln(b) - ln(c)', 'ln(a) + ln(b) + x',
  'ln(e)', 'ln(exp(x))', 'ln(x) + ln(y) - ln(z)', 'ln(x^3)', 'log(10, 1000)',
  'log(2, 2^x)', 'log(b, b^k)', 'log(x + 1, x^2 + 1)', 'pi / 2', 'pi + e',
  'piecewise(x < -1, -1, x > 1, 1, 0)', 'pow(pow(x, 2), 3)',
  'pow(sqrt(x), 2)', 'pow(x, -1 / 2)', 'root(3, x)', 'sin(-(5 * x))',
  'sin(asin(x))', 'sin(pi * x + 1)', 'sin(pi / 2)',
  'sin(x * y + 3)^2 + cos(x * y + 3)^2', 'sin(x)^2 + cos(x)^2 + abs(-x)',
  'sinh(-x) + sinh(x)', 'sqrt(1 / (1 - x ^ 2))', 'sqrt(sqrt(sqrt(16)))',
  'sqrt(x ^ (-2))', 'sqrt(x) * sqrt(y)', 'sqrt(x^2)', 'tan(-x) + tan(x)',
  'tan(x) + cosh(x) - sinh(x)', 'x * y + z - pi', 'x / y / z',
  'x + ln(a * b)', 'x^2 + 1', '(x + 1)^2 - x^2 - 2*x - 1',
  'x*y + 2*x*y - 3*y*x', '1/3 + 1/6 + 1/2', '0.5 * x + 0.25 * x',
];

void main(List<String> arguments) {
  final benchmarks = <String, BenchmarkResult Function(String name)>{
    'expand((x+y+z+1)^12)': (name) {
      final input = Expr.parse('(x + y + z + 1)^12');
      return measure(name, input.expand, runs: 21);
    },
    'series(exp(sin(x)), x, 0, 20)': (name) {
      final input = Expr.parse('exp(sin(x))');
      return measure(
        name,
        () => input.series('x', order: 20),
        runs: 21,
        inner: 50,
      );
    },
    'det 6x6 symbolic': (name) {
      final matrix = Matrix<Expr>.generate(
        6,
        6,
        (r, c) => Expr.parse('(${r + 1})^$c + x^${(r + c) % 3} * y'),
        type: exprDataType,
      );
      return measure(name, matrix.determinant, runs: 9);
    },
    'integrate corpus (${integrals.length})': (name) {
      final inputs = integrals.map(Expr.parse).toList();
      return measure(
        name,
        () => [for (final input in inputs) input.integrate('x')],
        runs: 21,
        inner: 20,
      );
    },
    'simplify corpus (${simplifications.length})': (name) {
      final inputs = simplifications.map(Expr.parse).toList();
      return measure(
        name,
        () => [for (final input in inputs) input.simplify()],
        runs: 21,
        inner: 50,
      );
    },
    'factor(x^24 - 1)': (name) {
      final input = Expr.parse('x^24 - 1');
      return measure(name, input.factor, runs: 21, inner: 100);
    },
    'solvePolynomialSystem katsura-2': (name) {
      final equations = [
        'a + 2*b + 2*c - 1',
        'a^2 + 2*b^2 + 2*c^2 - a',
        '2*a*b + 2*b*c - b',
      ].map(Expr.parse).toList();
      return measure(
        name,
        () => equations.solve(['a', 'b', 'c']),
        runs: 21,
        inner: 5,
      );
    },
    'solvePolynomialSystem katsura-3': (name) {
      final equations = [
        'a + 2*b + 2*c + 2*d - 1',
        'a^2 + 2*b^2 + 2*c^2 + 2*d^2 - a',
        '2*a*b + 2*b*c + 2*c*d - b',
        'b^2 + 2*a*c + 2*b*d - c',
      ].map(Expr.parse).toList();
      return measure(
        name,
        () => equations.solve(['a', 'b', 'c', 'd']),
        warmup: 1,
        runs: 3,
      );
    },
  };
  for (final MapEntry(key: name, value: benchmark) in benchmarks.entries) {
    if (arguments.isNotEmpty && !arguments.any(name.contains)) continue;
    print(benchmark(name));
  }
}
