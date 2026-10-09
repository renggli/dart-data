import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/src/numeric/curve_fit.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Curve Fitting & Regression', () {
    test('linear regression y = 2x + 1', () {
      final xs = Vector<double>.fromList([
        0.0,
        1.0,
        2.0,
        3.0,
        4.0,
      ], type: DataType.float64);
      final ys = Vector<double>.fromList([
        1.0,
        3.0,
        5.0,
        7.0,
        9.0,
      ], type: DataType.float64);

      final result = linearRegression(xs, ys);
      check(result.slope).isCloseTo(2.0, 1e-6);
      check(result.intercept).isCloseTo(1.0, 1e-6);
      check(result.rSquared).isCloseTo(1.0, 1e-6);
      check(result.predict(5.0)).isCloseTo(11.0, 1e-6);
    });

    test('polynomial regression y = 3 - 2x + x^2', () {
      final xs = Vector<double>.fromList([
        -2.0,
        -1.0,
        0.0,
        1.0,
        2.0,
        3.0,
      ], type: DataType.float64);
      // y = 3 - 2x + x^2
      final ys = Vector<double>.fromList([
        11.0,
        6.0,
        3.0,
        2.0,
        3.0,
        6.0,
      ], type: DataType.float64);

      final poly = polynomialRegression(xs, ys, degree: 2);
      check(poly.degree).equals(2);
      check(poly[0]).isCloseTo(3.0, 1e-6);
      check(poly[1]).isCloseTo(-2.0, 1e-6);
      check(poly[2]).isCloseTo(1.0, 1e-6);
      check(poly.evaluateDouble(4.0)).isCloseTo(11.0, 1e-6);
    });

    test('multiple linear regression y = 1 + 2*x1 - 3*x2', () {
      // 4 points, 2 features
      final x = Matrix<double>.fromRows([
        [1.0, 2.0],
        [2.0, 1.0],
        [3.0, 4.0],
        [5.0, 2.0],
      ], type: DataType.float64);
      // y = 1 + 2*x1 - 3*x2
      final y = Vector<double>.fromList([
        -3.0,
        2.0,
        -5.0,
        5.0,
      ], type: DataType.float64);

      final model = multipleLinearRegression(x, y, fitIntercept: true);
      check(model.intercept).isCloseTo(1.0, 1e-6);
      check(model.coefficients[0]).isCloseTo(2.0, 1e-6);
      check(model.coefficients[1]).isCloseTo(-3.0, 1e-6);
      check(model.rSquared).isCloseTo(1.0, 1e-6);

      final testPoint = Vector<double>.fromList([
        4.0,
        1.0,
      ], type: DataType.float64);
      // 1 + 2*4 - 3*1 = 6
      check(model.predict(testPoint)).isCloseTo(6.0, 1e-6);
    });

    test(
      'Levenberg-Marquardt non-linear exponential fit y = a * exp(b * x)',
      () {
        final xData = [0.0, 1.0, 2.0, 3.0];
        // Target: a = 2.5, b = 0.5
        // y = 2.5 * exp(0.5 * x)
        final yData = [2.5, 4.1218, 6.7957, 11.2042];

        Vector<double> residuals(Vector<double> p) {
          final a = p[0];
          final b = p[1];
          final res = List<double>.generate(
            xData.length,
            (i) => (a * math.exp(b * xData[i])) - yData[i],
          );
          return Vector<double>.fromList(res, type: DataType.float64);
        }

        final initialGuess = Vector<double>.fromList([
          1.0,
          1.0,
        ], type: DataType.float64);
        final fitted = levenbergMarquardt(
          residualFunction: residuals,
          initialParams: initialGuess,
        );

        check(fitted[0]).isCloseTo(2.5, 1e-3);
        check(fitted[1]).isCloseTo(0.5, 1e-3);
      },
    );
  });
}
