import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/src/numeric/curve_fit.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

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
        final fitted = fitNonlinear(
          residualFunction: residuals,
          initialParams: initialGuess,
        );

        check(fitted[0]).isCloseTo(2.5, 1e-3);
        check(fitted[1]).isCloseTo(0.5, 1e-3);
      },
    );

    test('multiple linear regression without intercept and predict errors', () {
      final x = Matrix<double>.fromRows([
        [1.0, 2.0],
        [2.0, 1.0],
      ], type: DataType.float64);
      // y = 2*x1 + 3*x2
      final y = Vector<double>.fromList([8.0, 7.0], type: DataType.float64);
      final model = multipleLinearRegression(x, y, fitIntercept: false);
      check(model.intercept).equals(0.0);
      check(model.coefficients[0]).isCloseTo(2.0, 1e-6);
      check(model.coefficients[1]).isCloseTo(3.0, 1e-6);

      // Predict length mismatch
      check(() => model.predict(Vector<double>.fromList([1.0])))
          .throws<ArgumentError>();
      // Data rowCount mismatch
      check(() => multipleLinearRegression(x, Vector<double>.fromList([1.0])))
          .throws<ArgumentError>();
    });

    test('leastSquares and regression error validations', () {
      final a = Matrix<double>.fromRows([
        [1.0, 2.0],
        [3.0, 4.0],
      ]);
      final bBad = Vector<double>.fromList([1.0]);
      check(() => leastSquares(a, bBad)).throws<ArgumentError>();

      // Non-float64 leastSquares
      final aInt = Matrix<int>.fromRows([
        [1, 0],
        [0, 1],
      ]);
      final bInt = Vector<int>.fromList([3, 4]);
      final sol = leastSquares(aInt, bInt);
      check(sol[0]).isCloseTo(3.0, 1e-6);
      check(sol[1]).isCloseTo(4.0, 1e-6);

      // linearRegression errors
      final v1 = Vector<double>.fromList([1.0, 2.0]);
      final v2 = Vector<double>.fromList([1.0]);
      check(() => linearRegression(v1, v2)).throws<ArgumentError>();
      check(() => linearRegression(v2, v2)).throws<ArgumentError>();

      // polynomialRegression errors
      check(() => polynomialRegression(v1, v2, degree: 1))
          .throws<ArgumentError>();
      check(() => polynomialRegression(v1, v1, degree: 3))
          .throws<ArgumentError>();
      check(() => polynomialRegression(v1, v1, degree: 1, lambda: -0.1))
          .throws<ArgumentError>();
    });

    test('regularized polynomial regression coefficient shrinkage', () {
      final xs = Vector<double>.fromList([
        -2.0,
        -1.0,
        0.0,
        1.0,
        2.0,
      ], type: DataType.float64);
      // Clean quadratic: y = 2 + 3x^2
      final ys = Vector<double>.fromList([
        14.0,
        5.0,
        2.0,
        5.0,
        14.0,
      ], type: DataType.float64);

      final unreg = polynomialRegression(xs, ys, degree: 2, lambda: 0.0);
      final regSmall = polynomialRegression(xs, ys, degree: 2, lambda: 1.0);
      final regLarge = polynomialRegression(xs, ys, degree: 2, lambda: 100.0);

      // Unpenalized x^2 coefficient is 3.0
      check(unreg[2]).isCloseTo(3.0, 1e-4);

      // Regularization shrinks the non-intercept coefficients
      check(regSmall[2].abs()).isLessThan(unreg[2].abs());
      check(regLarge[2].abs()).isLessThan(regSmall[2].abs());

      // Intercept remains unpenalized (adapts to match mean of ys)
      check(regLarge[0]).isGreaterThan(0.0);
    });

    test('regularized polynomial regression underdetermined system (N < degree + 1)', () {
      // 3 points, degree 4 polynomial
      final xs = Vector<double>.fromList([
        0.0,
        1.0,
        2.0,
      ], type: DataType.float64);
      final ys = Vector<double>.fromList([
        1.0,
        3.0,
        2.0,
      ], type: DataType.float64);

      // Without regularization, fails due to insufficient points
      check(() => polynomialRegression(xs, ys, degree: 4, lambda: 0.0))
          .throws<ArgumentError>();

      // With regularization, solves uniquely via full-rank augmented system
      final poly = polynomialRegression(xs, ys, degree: 4, lambda: 1e-4);
      check(poly.degree).equals(4);
      check(poly.evaluateDouble(0.0)).isCloseTo(1.0, 0.05);
    });
  });

  group('High-Level Parametric Curve Fitting (curveFit)', () {
    test('CurveModels.exponential fitting with clean metrics', () {
      final xs = Vector<double>.fromList([0.0, 1.0, 2.0, 3.0]);
      // True model: y = 3.0 * exp(0.5 * x)
      final ys = Vector<double>.generate(
        xs.length,
        (i) => 3.0 * math.exp(0.5 * xs[i]),
      );

      final result = curveFit(
        xs: xs,
        ys: ys,
        model: CurveModels.exponential,
        initialParams: Vector<double>.fromList([1.0, 0.1]),
      );

      check(result.parameters[0]).isCloseTo(3.0, 1e-5);
      check(result.parameters[1]).isCloseTo(0.5, 1e-5);
      check(result.rSquared).isCloseTo(1.0, 1e-5);
      check(result.residualStandardError).isLessThan(1e-5);
      check(result.predict(4.0)).isCloseTo(3.0 * math.exp(0.5 * 4.0), 1e-4);
      check(result.iterations).isGreaterThan(0);
      check(result.covariance.rowCount).equals(2);
      check(result.covariance.colCount).equals(2);
      check(result.standardErrors.length).equals(2);
      check(result.standardErrors[0])
          .isCloseTo(math.sqrt(result.covariance.get(0, 0)), 1e-12);
      check(result.standardErrors[1])
          .isCloseTo(math.sqrt(result.covariance.get(1, 1)), 1e-12);
    });

    test('CurveModels.power law fitting', () {
      final xs = Vector<double>.fromList([1.0, 2.0, 3.0, 4.0, 5.0]);
      // True model: y = 2.0 * x^1.5
      final ys = Vector<double>.generate(
        xs.length,
        (i) => 2.0 * math.pow(xs[i], 1.5).toDouble(),
      );

      final result = curveFit(
        xs: xs,
        ys: ys,
        model: CurveModels.power,
        initialParams: Vector<double>.fromList([1.0, 1.0]),
      );

      check(result.parameters[0]).isCloseTo(2.0, 1e-5);
      check(result.parameters[1]).isCloseTo(1.5, 1e-5);
      check(result.rSquared).isCloseTo(1.0, 1e-5);
    });

    test('CurveModels.logarithmic model fitting', () {
      final xs = Vector<double>.fromList([1.0, 2.0, 3.0, 4.0, 5.0]);
      // True model: y = 1.5 + 2.0 * ln(x)
      final ys = Vector<double>.generate(
        xs.length,
        (i) => 1.5 + 2.0 * math.log(xs[i]),
      );

      final result = curveFit(
        xs: xs,
        ys: ys,
        model: CurveModels.logarithmic,
        initialParams: Vector<double>.fromList([0.5, 1.0]),
      );

      check(result.parameters[0]).isCloseTo(1.5, 1e-5);
      check(result.parameters[1]).isCloseTo(2.0, 1e-5);
      check(result.rSquared).isCloseTo(1.0, 1e-5);
    });

    test('CurveModels.gaussian peak fitting with noisy data', () {
      final xs = Vector<double>.fromList([-1.0, 0.0, 1.0, 2.0, 3.0]);
      // True model: 4.0 * exp(-(x - 1.0)^2 / (2 * 0.8^2))
      final ys = Vector<double>.generate(
        xs.length,
        (i) =>
            4.0 *
            math.exp(-((xs[i] - 1.0) * (xs[i] - 1.0)) / (2.0 * 0.8 * 0.8)),
      );

      final result = curveFit(
        xs: xs,
        ys: ys,
        model: CurveModels.gaussian,
        initialParams: Vector<double>.fromList([3.0, 0.8, 1.0]),
      );

      check(result.parameters[0]).isCloseTo(4.0, 1e-4);
      check(result.parameters[1]).isCloseTo(1.0, 1e-4);
      check(result.parameters[2]).isCloseTo(0.8, 1e-4);
      check(result.rSquared).isGreaterThan(0.999);
    });

    test('parameter bounds constraints', () {
      final xs = Vector<double>.fromList([0.0, 1.0, 2.0]);
      final ys = Vector<double>.fromList([1.0, 2.0, 4.0]);

      // Enforce lower bound on parameter 0 of at least 2.0
      final result = curveFit(
        xs: xs,
        ys: ys,
        model: (x, p) => p[0] + p[1] * x,
        initialParams: Vector<double>.fromList([2.5, 1.0]),
        lowerBounds: Vector<double>.fromList([2.0, 0.0]),
        upperBounds: Vector<double>.fromList([5.0, 5.0]),
      );

      check(result.parameters[0]).isGreaterOrEqual(2.0);
    });

    test('curveFit validation errors', () {
      final xs = Vector<double>.fromList([1.0, 2.0]);
      final ys = Vector<double>.fromList([1.0]);

      // Length mismatch
      check(
        () => curveFit(
          xs: xs,
          ys: ys,
          model: CurveModels.exponential,
          initialParams: Vector<double>.fromList([1.0, 1.0]),
        ),
      ).throws<ArgumentError>();

      // Insufficient points
      check(
        () => curveFit(
          xs: Vector<double>.fromList([1.0]),
          ys: Vector<double>.fromList([1.0]),
          model: CurveModels.gaussian,
          initialParams: Vector<double>.fromList([1.0, 1.0, 1.0]),
        ),
      ).throws<ArgumentError>();

      // Bounds length mismatch
      check(
        () => curveFit(
          xs: Vector<double>.fromList([1.0, 2.0, 3.0]),
          ys: Vector<double>.fromList([1.0, 2.0, 3.0]),
          model: CurveModels.exponential,
          initialParams: Vector<double>.fromList([1.0, 1.0]),
          lowerBounds: Vector<double>.fromList([0.0]),
        ),
      ).throws<ArgumentError>();

      // Upper bounds length mismatch
      check(
        () => curveFit(
          xs: Vector<double>.fromList([1.0, 2.0, 3.0]),
          ys: Vector<double>.fromList([1.0, 2.0, 3.0]),
          model: CurveModels.exponential,
          initialParams: Vector<double>.fromList([1.0, 1.0]),
          upperBounds: Vector<double>.fromList([5.0]),
        ),
      ).throws<ArgumentError>();
    });

    test('leastSquares rank-deficient and integer RHS', () {
      final a = Matrix<double>.fromRows([
        [1.0, 2.0],
        [2.0, 4.0],
      ]);
      final b = Vector<int>.fromList([3, 6]);
      final x = leastSquares(a, b);
      check(x.length).equals(2);
      final ax = a.apply(x);
      check(ax[0]).isCloseTo(3.0, 1e-8);
      check(ax[1]).isCloseTo(6.0, 1e-8);
    });

    test('polynomialRegression edge cases', () {
      check(
        () => polynomialRegression(
          Vector<double>.fromList([]),
          Vector<double>.fromList([]),
          degree: 1,
          lambda: 1.0,
        ),
      ).throws<ArgumentError>();

      final xs = Vector<double>.fromList([1.0, 2.0, 3.0]);
      final ys = Vector<int>.fromList([2, 4, 6]);
      final res = polynomialRegression(xs, ys, degree: 1);
      check(res[1]).isCloseTo(2.0, 1e-6);
    });

    test(
      'curveFit with constant values yields rSquared 0.0 (ssTot == 0.0)',
      () {
        final xs = Vector<double>.fromList([1.0, 2.0, 3.0]);
        final ys = Vector<double>.fromList([5.0, 5.0, 5.0]);
        final res = curveFit(
          xs: xs,
          ys: ys,
          model: (x, p) => p[0],
          initialParams: Vector<double>.fromList([1.0]),
        );
        check(res.rSquared).equals(0.0);
      },
    );

    test('fitNonlinear step rejection', () {
      final p = fitNonlinear(
        residualFunction: (v) =>
            Vector<double>.fromList([10.0 * (v[1] - v[0] * v[0]), 1.0 - v[0]]),
        initialParams: Vector<double>.fromList([-1.2, 1.0]),
        damping: 1e-4,
        maxIterations: 10,
      );
      check(p.length).equals(2);
    });

    test('fitNonlinear evaluates residual function O(p) times per iteration', () {
      var callCount = 0;
      // N = 50 residuals, P = 2 params
      final p = fitNonlinear(
        residualFunction: (v) {
          callCount++;
          return Vector<double>.generate(50, (i) => (i + 1) * v[0] - v[1]);
        },
        initialParams: Vector<double>.fromList([1.0, 2.0]),
        maxIterations: 1,
      );
      check(p.length).equals(2);
      // With N = 50, previously this would have been > 100 calls per iteration.
      // Now it's initial (1) + numParams (2) + candidate (1) = 4 calls.
      check(callCount).isLessThan(10);
    });

    test('curveFit handles degenerate rank-deficient model with singular covariance', () {
      final xs = Vector<double>.fromList([1.0, 2.0, 3.0, 4.0, 5.0]);
      final ys = Vector<double>.fromList([2.0, 4.0, 6.0, 8.0, 10.0]);

      // Degenerate model a * x + b * x with collinear parameters
      final res = curveFit(
        xs: xs,
        ys: ys,
        model: (x, p) => p[0] * x + p[1] * x,
        initialParams: Vector<double>.fromList([1.0, 1.0]),
      );

      // Non-identifiable parameters should have infinite variance / standard error
      check(res.covariance.get(0, 0)).equals(double.infinity);
      check(res.covariance.get(1, 1)).equals(double.infinity);
      check(res.standardErrors[0]).equals(double.infinity);
      check(res.standardErrors[1]).equals(double.infinity);
    });
  });
}
