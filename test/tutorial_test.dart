import 'dart:math';

import 'package:data/data.dart';
import 'package:more/printer.dart';
import 'package:test/test.dart';

void main() {
  test('linear equation', () {
    final a = Matrix<double>.fromRows(DataType.float64, [
      [2, 1, 1],
      [1, 3, 2],
      [1, 0, 0],
    ]);
    final b = Vector<double>.fromList(DataType.float64, [4, 5, 6]);
    final x = a.solve(b.columnMatrix).column(0);
    expect(x.format(valuePrinter: FixedNumberPrinter()), '6 15 -23');
  });
  test('find eigenvalues', () {
    final a = Matrix<double>.fromRows(DataType.float64, [
      [1, 0, 0, -1],
      [0, -1, 0, 0],
      [0, 0, 1, -1],
      [-1, 0, -1, 0],
    ]);
    final decomposition = a.eigenvalue;
    final eigenvalues = Vector<double>.fromList(
      DataType.float64,
      decomposition.realEigenvalues,
    );
    expect(
      eigenvalues.format(valuePrinter: FixedNumberPrinter(precision: 1)),
      '-1.0 -1.0 1.0 2.0',
    );
  });
  test('polynomial roots', () {
    final roots = [-5, -3, -2, 7, 11];
    final polynomial = Polynomial.fromRoots(DataType.int32, roots);
    expect(
      polynomial.roots.map((each) => each.real),
      containsAll(roots.map((root) => closeTo(root, 1e-10))),
    );
    expect(
      polynomial.roots.map((each) => each.imaginary),
      everyElement(closeTo(0.0, 1e-10)),
    );
  });
  test('polynomial regression', () {
    final height = [
      1.47,
      1.50,
      1.52,
      1.55,
      1.57,
      1.60,
      1.63,
      1.65,
      1.68,
      1.70,
      1.73,
      1.75,
      1.78,
      1.80,
      1.83,
    ].toVector();
    final mass = [
      52.21,
      53.12,
      54.48,
      55.84,
      57.20,
      58.57,
      59.93,
      61.29,
      63.11,
      64.47,
      66.28,
      68.10,
      69.92,
      72.19,
      74.46,
    ].toVector();
    final fitter = PolynomialRegression(degree: 2);
    final result = fitter.fit(xs: height, ys: mass);
    expect(
      result.polynomial.format(valuePrinter: FixedNumberPrinter(precision: 3)),
      '61.960x^2 + -143.162x + 128.813',
    );
  });
  test('integrate', () {
    final pi = 4 * integrate((x) => sqrt(1 - x * x), 0, 1, depth: 30);
    expect(pi, closeTo(pi, 1e-6));
    final one = integrate((x) => exp(-x), 0, double.infinity, depth: 30);
    expect(one, closeTo(one, 1e-6));
  });
}
