import 'dart:math' as math;

import 'package:data/linear.dart';
import 'package:data/src/numeric/curve_fit.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('Curve Fitting & Regression', () {
    test('linear regression y = 2x + 1', () {
      final xs = Vector<double>.fromList([0.0, 1.0, 2.0, 3.0, 4.0],
          type: DataType.float64);
      final ys = Vector<double>.fromList([1.0, 3.0, 5.0, 7.0, 9.0],
          type: DataType.float64);

      final result = linearRegression(xs, ys);
      expect(result.slope, closeTo(2.0, 1e-6));
      expect(result.intercept, closeTo(1.0, 1e-6));
      expect(result.rSquared, closeTo(1.0, 1e-6));
      expect(result.predict(5.0), closeTo(11.0, 1e-6));
    });

    test('polynomial regression y = 3 - 2x + x^2', () {
      final xs = Vector<double>.fromList([-2.0, -1.0, 0.0, 1.0, 2.0, 3.0],
          type: DataType.float64);
      // y = 3 - 2x + x^2
      final ys = Vector<double>.fromList([11.0, 6.0, 3.0, 2.0, 3.0, 6.0],
          type: DataType.float64);

      final poly = polynomialRegression(xs, ys, degree: 2);
      expect(poly.degree, 2);
      expect(poly[0], closeTo(3.0, 1e-6));
      expect(poly[1], closeTo(-2.0, 1e-6));
      expect(poly[2], closeTo(1.0, 1e-6));
      expect(poly.evaluateDouble(4.0), closeTo(11.0, 1e-6));
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
      final y = Vector<double>.fromList([-3.0, 2.0, -5.0, 5.0],
          type: DataType.float64);

      final model = multipleLinearRegression(x, y, fitIntercept: true);
      expect(model.intercept, closeTo(1.0, 1e-6));
      expect(model.coefficients[0], closeTo(2.0, 1e-6));
      expect(model.coefficients[1], closeTo(-3.0, 1e-6));
      expect(model.rSquared, closeTo(1.0, 1e-6));

      final testPoint = Vector<double>.fromList([4.0, 1.0], type: DataType.float64);
      // 1 + 2*4 - 3*1 = 6
      expect(model.predict(testPoint), closeTo(6.0, 1e-6));
    });

    test('Levenberg-Marquardt non-linear exponential fit y = a * exp(b * x)', () {
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

      final initialGuess = Vector<double>.fromList([1.0, 1.0], type: DataType.float64);
      final fitted = levenbergMarquardt(
        residualFunction: residuals,
        initialParams: initialGuess,
      );

      expect(fitted[0], closeTo(2.5, 1e-3));
      expect(fitted[1], closeTo(0.5, 1e-3));
    });
  });
}
