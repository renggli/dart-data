import 'dart:math';

import 'package:data/data.dart';
import 'package:data/src/numeric/types.dart';
import 'package:data/src/shared/config.dart';
import 'package:meta/meta.dart';
import 'package:more/math.dart';
import 'package:more/tuple.dart';
import 'package:test/test.dart';

import 'utils/matchers.dart';

@isTest
void verifyLevenbergMarquardt(
  String name,
  LevenbergMarquardt fitter, {
  int? n,
  double? xStart,
  double? xEnd,
  List<double>? xs,
  List<double>? ys,
  List<double>? expectedParameterValues,
  double parameterValuesEpsilon = 1e-3,
  double? expectedParameterError = 0.0,
  double parameterErrorEpsilon = 1e-2,
  int? expectedIterations,
}) {
  test(name, () {
    final x = xs?.toVector() ??
        Vector.generate(floatDataType, n!,
            (i) => xStart! + (i * (xEnd! - xStart)) / (n - 1));
    final y = xs?.toVector() ??
        Vector.generate(floatDataType, n!,
            (i) => fitter.function(expectedParameterValues!, x[i]));
    final actual = fitter.fit(x: x, y: y);

    if (expectedParameterValues != null) {
      for (var i = 0; i < expectedParameterValues.length; i++) {
        expect(
            actual.parameterValues[i],
            isCloseTo(expectedParameterValues[i],
                epsilon: parameterValuesEpsilon),
            reason: 'expectedParameterValues[$i]');
      }
    }
    if (expectedParameterError != null) {
      expect(actual.parameterError,
          isCloseTo(expectedParameterError, epsilon: parameterErrorEpsilon));
    }
    if (expectedIterations != null) {
      expect(actual.iterationCount, expectedIterations);
    }
  });
}

Tuple2<Vector<double>, Vector<double>> generateSamples(
  NumericFunction function, {
  double min = -1.0,
  double max = 1.0,
  int count = 10,
}) {
  final xs = Vector.generate(
      floatDataType, count, (i) => min + (i * (max - min)) / (count - 1),
      format: VectorFormat.standard);
  final ys = Vector.generate(floatDataType, count, (i) => function(xs[i]),
      format: VectorFormat.standard);
  return Tuple2(xs, ys);
}

void main() {
  group('derivative', () {
    test('first derivative at different accuracies', () {
      for (var a = 2; a <= 8; a += 2) {
        // sin-function
        expect(derivative(sin, 0.0 * pi, accuracy: a), isCloseTo(1.0));
        expect(derivative(sin, 0.5 * pi, accuracy: a), isCloseTo(0.0));
        expect(derivative(sin, 1.0 * pi, accuracy: a), isCloseTo(-1.0));
        expect(derivative(sin, 1.5 * pi, accuracy: a), isCloseTo(0.0));
        // cos-function
        expect(derivative(cos, 0.0 * pi, accuracy: a), isCloseTo(0.0));
        expect(derivative(cos, 0.5 * pi, accuracy: a), isCloseTo(-1.0));
        expect(derivative(cos, 1.0 * pi, accuracy: a), isCloseTo(0.0));
        expect(derivative(cos, 1.5 * pi, accuracy: a), isCloseTo(1.0));
        // exp-function
        expect(derivative(exp, -1.0, accuracy: a), isCloseTo(1 / e));
        expect(derivative(exp, 0.0, accuracy: a), isCloseTo(1.0));
        expect(derivative(exp, 1.0, accuracy: a), isCloseTo(e));
      }
    });
    test('second derivative at different accuracies', () {
      for (var a = 2; a <= 8; a += 2) {
        // sin-function
        expect(derivative(sin, 0.0 * pi, derivative: 2, accuracy: a),
            isCloseTo(0.0));
        expect(derivative(sin, 0.5 * pi, derivative: 2, accuracy: a),
            isCloseTo(-1.0));
        expect(derivative(sin, 1.0 * pi, derivative: 2, accuracy: a),
            isCloseTo(0.0));
        expect(derivative(sin, 1.5 * pi, derivative: 2, accuracy: a),
            isCloseTo(1.0));
        // cos-function
        expect(derivative(cos, 0.0 * pi, derivative: 2, accuracy: a),
            isCloseTo(-1.0));
        expect(derivative(cos, 0.5 * pi, derivative: 2, accuracy: a),
            isCloseTo(0.0));
        expect(derivative(cos, 1.0 * pi, derivative: 2, accuracy: a),
            isCloseTo(1.0));
        expect(derivative(cos, 1.5 * pi, derivative: 2, accuracy: a),
            isCloseTo(0.0));
        // exp-function
        expect(derivative(exp, -1.0, derivative: 2, accuracy: a),
            isCloseTo(1 / e));
        expect(
            derivative(exp, 0.0, derivative: 2, accuracy: a), isCloseTo(1.0));
        expect(derivative(exp, 1.0, derivative: 2, accuracy: a), isCloseTo(e));
      }
    });
    group('error', () {
      test('derivative', () {
        expect(
            () => derivative(sin, 0, derivative: 0),
            throwsA(isA<ArgumentError>()
                .having((error) => error.name, 'name', 'derivative')
                .having((error) => error.message, 'message',
                    'Must be one of 1, 2, 3, 4, 5, 6')));
      });
      test('accuracy', () {
        expect(
            () => derivative(sin, 0, accuracy: 0),
            throwsA(isA<ArgumentError>()
                .having((error) => error.name, 'name', 'accuracy')
                .having((error) => error.message, 'message',
                    'Must be one of 2, 4, 6, 8')));
      });
    });
  });
  group('fit', () {
    group('levenberg marquardt', () {
      double lorentzians(List<double> params, double x) {
        var result = 0.0;
        for (var i = 0; i < params.length; i += 3) {
          final p2 = pow(params[i + 2] / 2, 2);
          final factor = params[i + 1] * p2;
          result += factor / (pow(x - params[i], 2) + p2);
        }
        return result;
      }

      double sinFunction(List<double> params, double x) =>
          params[0] * sin(params[1] * x);

      verifyLevenbergMarquardt(
        'bennet5(2, 3, 5)',
        LevenbergMarquardt(
          (params, x) => params[0] * pow(x + params[1], -1 / params[2]),
          initialDamping: 0.00001,
          maxIterations: 1000,
          errorTolerance: 1e-7,
          maxValues: <double>[11, 11, 11].toVector(),
          minValues: <double>[1, 2.7, 1].toVector(),
          initialValues: <double>[3.5, 3.8, 4].toVector(),
        ),
        n: 154,
        xStart: -2.6581,
        xEnd: 49.6526,
        expectedParameterValues: [2, 3, 5],
      );
      verifyLevenbergMarquardt(
        '2*sin(2*x)',
        LevenbergMarquardt(
          sinFunction,
          maxIterations: 100,
          gradientDifference: 0.1,
          initialDamping: 0.1,
          dampingStepDown: 1,
          dampingStepUp: 1,
          initialValues: <double>[3, 3].toVector(),
        ),
        n: 20,
        xStart: 0,
        xEnd: 19,
        expectedParameterValues: [2, 2],
      );
      verifyLevenbergMarquardt(
        'Sigmoid',
        LevenbergMarquardt(
          (params, x) => params[0] / (params[1] + exp(-x * params[2])),
          initialDamping: 0.1,
          initialValues: <double>[3, 3, 3].toVector(),
          maxIterations: 200,
        ),
        n: 20,
        xStart: 0,
        xEnd: 19,
        expectedParameterValues: [2, 2, 2],
        parameterValuesEpsilon: 0.1,
      );
      verifyLevenbergMarquardt(
        'Sum of lorentzians',
        LevenbergMarquardt(
          lorentzians,
          initialDamping: 0.01,
          gradientDifferences:
              <double>[0.01, 0.0001, 0.0001, 0.01, 0.0001, 0.0].toVector(),
          initialValues: <double>[1.1, 0.15, 0.29, 4.05, 0.17, 0.3].toVector(),
          maxIterations: 500,
        ),
        n: 100,
        xStart: 0,
        xEnd: 99,
        expectedParameterValues: [1.05, 0.1, 0.3, 4, 0.15, 0.3],
        parameterValuesEpsilon: 0.1,
      );
      verifyLevenbergMarquardt(
        'Sum of lorentzians, central differences',
        LevenbergMarquardt(
          lorentzians,
          initialDamping: 0.01,
          gradientDifferences:
              <double>[0.01, 0.0001, 0.0001, 0.01, 0.0001, 0.01].toVector(),
          centralDifference: true,
          initialValues: <double>[1.1, 0.15, 0.29, 4.05, 0.17, 0.28].toVector(),
          maxIterations: 500,
          errorTolerance: 10e-8,
        ),
        n: 100,
        xStart: 0,
        xEnd: 99,
        expectedParameterValues: [1.0, 0.1, 0.3, 4, 0.15, 0.3],
        parameterValuesEpsilon: 0.1,
      );
      verifyLevenbergMarquardt(
        'should return solution with lowest error',
        LevenbergMarquardt(
          sinFunction,
          initialDamping: 1.5,
          initialValues: <double>[
            0.594398586701882,
            0.3506424963635226,
          ].toVector(),
          gradientDifference: 1e-2,
          maxIterations: 100,
          errorTolerance: 1e-2,
        ),
        xs: [
          0,
          0.6283185307179586,
          1.2566370614359172,
          1.8849555921538759,
          2.5132741228718345,
          3.141592653589793,
          3.7699111843077517,
          4.39822971502571,
          5.026548245743669,
          5.654866776461628,
        ],
        ys: [
          0,
          1.902113032590307,
          1.1755705045849465,
          -1.175570504584946,
          -1.9021130325903073,
          -4.898587196589413e-16,
          1.902113032590307,
          1.1755705045849467,
          -1.1755705045849456,
          -1.9021130325903075,
        ],
        expectedParameterValues: [-14.846618431652454, -0.06846434130254946],
      );
    });
    group('polynomial regression', () {
      group('american women', () {
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
        test('constant', () {
          final fitter = PolynomialRegression(degree: 0);
          final result = fitter.fit(x: height, y: mass);
          expect(result.polynomial.degree, 0);
          expect(result.polynomial[0], isCloseTo(62.078000));
        });
        test('linear', () {
          final fitter = PolynomialRegression(degree: 1);
          final result = fitter.fit(x: height, y: mass);
          expect(result.polynomial.degree, 1);
          expect(result.polynomial[0], isCloseTo(-39.061956));
          expect(result.polynomial[1], isCloseTo(61.272187));
        });
        test('quadratic', () {
          final fitter = PolynomialRegression(degree: 2);
          final result = fitter.fit(x: height, y: mass);
          expect(result.polynomial.degree, 2);
          expect(result.polynomial[0], isCloseTo(128.812804));
          expect(result.polynomial[1], isCloseTo(-143.162023));
          expect(result.polynomial[2], isCloseTo(61.960325));
        });
      });
      group('taylor', () {
        test('exp', () {
          final fitter = PolynomialRegression(degree: 10);
          final data = generateSamples(exp, count: 25);
          final result = fitter.fit(x: data.first, y: data.second);
          expect(result.polynomial.degree, fitter.degree);
          for (var i = 0; i <= fitter.degree; i++) {
            expect(result.polynomial[i], isCloseTo(1.0 / i.factorial()),
                reason: '$i-th coefficient');
          }
        });
        test('sin', () {
          final fitter = PolynomialRegression(degree: 10);
          final data = generateSamples(sin, count: 50);
          final result = fitter.fit(x: data.first, y: data.second);
          expect(result.polynomial.degree, fitter.degree);
          for (var i = 0; i <= fitter.degree; i++) {
            expect(
                result.polynomial[i],
                isCloseTo(
                    i.isOdd ? pow(-1, (i - 1) ~/ 2) / i.factorial() : 0.0),
                reason: '$i-th coefficient');
          }
        });
        test('cos', () {
          final fitter = PolynomialRegression(degree: 10);
          final data = generateSamples(cos, count: 50);
          final result = fitter.fit(x: data.first, y: data.second);
          expect(result.polynomial.degree, fitter.degree);
          for (var i = 0; i <= fitter.degree; i++) {
            expect(result.polynomial[i],
                isCloseTo(i.isEven ? pow(-1, i ~/ 2) / i.factorial() : 0.0),
                reason: '$i-th coefficient');
          }
        });
      });
    });
  });
  group('derivative', () {
    test('first derivative at different accuracies', () {
      for (var a = 2; a <= 8; a += 2) {
        // sin-function
        expect(derivative(sin, 0.0 * pi, accuracy: a), isCloseTo(1.0));
        expect(derivative(sin, 0.5 * pi, accuracy: a), isCloseTo(0.0));
        expect(derivative(sin, 1.0 * pi, accuracy: a), isCloseTo(-1.0));
        expect(derivative(sin, 1.5 * pi, accuracy: a), isCloseTo(0.0));
        // cos-function
        expect(derivative(cos, 0.0 * pi, accuracy: a), isCloseTo(0.0));
        expect(derivative(cos, 0.5 * pi, accuracy: a), isCloseTo(-1.0));
        expect(derivative(cos, 1.0 * pi, accuracy: a), isCloseTo(0.0));
        expect(derivative(cos, 1.5 * pi, accuracy: a), isCloseTo(1.0));
        // exp-function
        expect(derivative(exp, -1.0, accuracy: a), isCloseTo(1 / e));
        expect(derivative(exp, 0.0, accuracy: a), isCloseTo(1.0));
        expect(derivative(exp, 1.0, accuracy: a), isCloseTo(e));
      }
    });
    test('second derivative at different accuracies', () {
      for (var a = 2; a <= 8; a += 2) {
        // sin-function
        expect(derivative(sin, 0.0 * pi, derivative: 2, accuracy: a),
            isCloseTo(0.0));
        expect(derivative(sin, 0.5 * pi, derivative: 2, accuracy: a),
            isCloseTo(-1.0));
        expect(derivative(sin, 1.0 * pi, derivative: 2, accuracy: a),
            isCloseTo(0.0));
        expect(derivative(sin, 1.5 * pi, derivative: 2, accuracy: a),
            isCloseTo(1.0));
        // cos-function
        expect(derivative(cos, 0.0 * pi, derivative: 2, accuracy: a),
            isCloseTo(-1.0));
        expect(derivative(cos, 0.5 * pi, derivative: 2, accuracy: a),
            isCloseTo(0.0));
        expect(derivative(cos, 1.0 * pi, derivative: 2, accuracy: a),
            isCloseTo(1.0));
        expect(derivative(cos, 1.5 * pi, derivative: 2, accuracy: a),
            isCloseTo(0.0));
        // exp-function
        expect(derivative(exp, -1.0, derivative: 2, accuracy: a),
            isCloseTo(1 / e));
        expect(
            derivative(exp, 0.0, derivative: 2, accuracy: a), isCloseTo(1.0));
        expect(derivative(exp, 1.0, derivative: 2, accuracy: a), isCloseTo(e));
      }
    });
    group('error', () {
      test('derivative', () {
        expect(
            () => derivative(sin, 0, derivative: 0),
            throwsA(isA<ArgumentError>()
                .having((error) => error.name, 'name', 'derivative')
                .having((error) => error.message, 'message',
                    'Must be one of 1, 2, 3, 4, 5, 6')));
      });
      test('accuracy', () {
        expect(
            () => derivative(sin, 0, accuracy: 0),
            throwsA(isA<ArgumentError>()
                .having((error) => error.name, 'name', 'accuracy')
                .having((error) => error.message, 'message',
                    'Must be one of 2, 4, 6, 8')));
      });
    });
  });
  group('functions', () {
    test('list', () {
      final function = ParametrizedUnaryFunction<String>.list(
        DataType.string,
        3,
        (params) => (x) => 'f_${params[0]},${params[1]},${params[2]}($x)',
      );
      expect(function.dataType, DataType.string);
      expect(function.count, 3);
      expect(function.toVector(['a', 'b'], 'c').iterable, ['a', 'b', 'c']);
      final arguments = ['a', 'b', 'c'].toVector();
      final bindings = function.toBindings(arguments);
      final bound = function.bind(arguments);
      arguments[0] = 'x';
      expect(bindings, ['a', 'b', 'c']);
      expect(bound('1'), 'f_a,b,c(1)');
    });
    test('map', () {
      final function = ParametrizedUnaryFunction<String>.map(
        DataType.string,
        [#a, #b, #c],
        (params) => (x) => 'f_${params[#a]},${params[#b]},${params[#c]}($x)',
      );
      expect(function.dataType, DataType.string);
      expect(function.count, 3);
      expect(
          function.toVector({#b: 'b', #a: 'a'}, 'c').iterable, ['a', 'b', 'c']);
      final arguments = ['a', 'b', 'c'].toVector();
      final bindings = function.toBindings(arguments);
      final bound = function.bind(arguments);
      arguments[0] = 'x';
      expect(bindings, {#a: 'a', #b: 'b', #c: 'c'});
      expect(bound('1'), 'f_a,b,c(1)');
    });
    test('named', () {
      final function = ParametrizedUnaryFunction<String>.named(
        DataType.string,
        [#a, #b, #c],
        ({required String a, required String b, required String c}) =>
            (x) => 'f_$a,$b,$c($x)',
      );
      expect(function.dataType, DataType.string);
      expect(function.count, 3);
      expect(
          function.toVector({#b: 'b', #a: 'a'}, 'c').iterable, ['a', 'b', 'c']);
      final arguments = ['a', 'b', 'c'].toVector();
      final bindings = function.toBindings(arguments);
      final bound = function.bind(arguments);
      arguments[0] = 'x';
      expect(bindings, {#a: 'a', #b: 'b', #c: 'c'});
      expect(bound('1'), 'f_a,b,c(1)');
    });
    test('positional', () {
      final function = ParametrizedUnaryFunction<String>.positional(
        DataType.string,
        3,
        (String a, String b, String c) => (x) => 'f_$a,$b,$c($x)',
      );
      expect(function.dataType, DataType.string);
      expect(function.count, 3);
      expect(function.toVector(['a', 'b'], 'c').iterable, ['a', 'b', 'c']);
      final arguments = ['a', 'b', 'c'].toVector();
      final bindings = function.toBindings(arguments);
      final bound = function.bind(arguments);
      arguments[0] = 'x';
      expect(bindings, ['a', 'b', 'c']);
      expect(bound('1'), 'f_a,b,c(1)');
    });
    test('vector', () {
      final function = ParametrizedUnaryFunction<String>.vector(
        DataType.string,
        3,
        (params) => (x) => 'f_${params[0]},${params[1]},${params[2]}($x)',
      );
      expect(function.dataType, DataType.string);
      expect(function.count, 3);
      expect(function.toVector(['a', 'b'].toVector(), 'c').iterable,
          ['a', 'b', 'c']);
      final arguments = ['a', 'b', 'c'].toVector();
      final bindings = function.toBindings(arguments);
      final bound = function.bind(arguments);
      arguments[0] = 'x';
      expect((bindings as Vector<String>).toList(), ['a', 'b', 'c']);
      expect(bound('1'), 'f_a,b,c(1)');
    });
  });
  group('interpolate', () {
    group('sequences', () {
      group('linear', () {
        test('default', () {
          final vector = linearSpaced(2, 3, count: 5);
          expect(vector.iterable, isCloseTo([2, 2.25, 2.5, 2.75, 3]));
        });
        test('without endpoint', () {
          final vector = linearSpaced(2, 3, count: 5, includeEndpoint: false);
          expect(vector.iterable, isCloseTo([2, 2.2, 2.4, 2.6, 2.8]));
        });
      });
      group('logarithmic', () {
        test('default', () {
          final vector = logarithmicSpaced(2, 3, count: 4);
          expect(vector.iterable,
              isCloseTo([100, 215.443469, 464.15888336, 1000]));
        });
        test('without endpoint', () {
          final vector =
              logarithmicSpaced(2, 3, count: 4, includeEndpoint: false);
          expect(vector.iterable,
              isCloseTo([100, 177.827941, 316.22776602, 562.34132519]));
        });
        test('with base', () {
          final vector = logarithmicSpaced(2.0, 3.0, count: 4, base: 2.0);
          expect(vector.iterable, isCloseTo([4.0, 5.0396842, 6.34960421, 8.0]));
        });
      });
      group('geometric', () {
        test('increasing', () {
          final vector = geometricSpaced(1, 1000, count: 4);
          expect(vector.iterable, isCloseTo([1, 10, 100, 1000]));
        });
        test('decreasing', () {
          final vector = geometricSpaced(1000.0, 1.0, count: 4);
          expect(vector.iterable, isCloseTo([1000, 100, 10, 1]));
        });
        test('without endpoint', () {
          final vector =
              geometricSpaced(1, 1000, count: 4, includeEndpoint: false);
          expect(vector.iterable,
              isCloseTo([1, 5.62341325, 31.6227766, 177.827941]));
        });
      });
    });
    group('linear', () {
      test('increasing', () {
        final f = LinearInterpolation(
          x: [1.0, 2.0].toVector(),
          y: [3.0, 4.0].toVector(),
        );
        expect(f(0.5), isCloseTo(3.0));
        expect(f(1.0), isCloseTo(3.0));
        expect(f(1.5), isCloseTo(3.5));
        expect(f(2.0), isCloseTo(4.0));
        expect(f(2.5), isCloseTo(4.0));
      });
      test('decreasing', () {
        final f = LinearInterpolation(
          x: [1.0, 2.0].toVector(),
          y: [4.0, 3.0].toVector(),
        );
        expect(f(0.5), isCloseTo(4.0));
        expect(f(1.0), isCloseTo(4.0));
        expect(f(1.5), isCloseTo(3.5));
        expect(f(2.0), isCloseTo(3.0));
        expect(f(2.5), isCloseTo(3.0));
      });
      test('custom bounds', () {
        final f = LinearInterpolation(
          x: [1.0, 2.0].toVector(),
          y: [3.0, 4.0].toVector(),
          left: double.negativeInfinity,
          right: double.infinity,
        );
        expect(f(0.5), isCloseTo(double.negativeInfinity));
        expect(f(1.0), isCloseTo(3.0));
        expect(f(1.5), isCloseTo(3.5));
        expect(f(2.0), isCloseTo(4.0));
        expect(f(2.5), isCloseTo(double.infinity));
      });
      test('exponential function', () {
        final x = linearSpaced(-1, 1);
        final y = x.map((i, x) => exp(x));
        final f = LinearInterpolation(x: x, y: y);
        for (var i = -1.0; i <= 1.0; i += 0.25) {
          expect(f(i), isCloseTo(exp(i), epsilon: 0.1));
        }
      });
    });
  });
  group('integrate', () {
    group('common', () {
      test('exp', () {
        expect(integrate(exp, 0, 1), isCloseTo(e - 1));
        expect(integrate(exp, -1, 0), isCloseTo(1 - 1 / e));
        expect(integrate(exp, -1, 1), isCloseTo(e - 1 / e));
      });
      test('sin', () {
        expect(integrate(sin, 0, 2 * pi), isCloseTo(0));
        expect(integrate(sin, -2 * pi, 0), isCloseTo(0));
        expect(integrate(sin, -2 * pi, 2 * pi), isCloseTo(0));
      });
      test('cos', () {
        expect(integrate(cos, 0, 2 * pi), isCloseTo(0));
        expect(integrate(cos, -2 * pi, 0), isCloseTo(0));
        expect(integrate(cos, -2 * pi, 2 * pi), isCloseTo(0));
      });
      test('sqr', () {
        double sqr(double x) => x * x;
        expect(integrate(sqr, -1, 1), isCloseTo(2 / 3));
        expect(integrate(sqr, 0, 2), isCloseTo(8 / 3));
        expect(integrate(sqr, -1, 2), isCloseTo(3));
      });
      test('sqrt', () {
        expect(
            integrate(sqrt, 0, 1, depth: 25), isCloseTo(2 / 3 * pow(1, 3 / 2)));
        expect(
            integrate(sqrt, 0, 2, depth: 25), isCloseTo(2 / 3 * pow(2, 3 / 2)));
        expect(
            integrate(sqrt, 0, 3, depth: 30), isCloseTo(2 / 3 * pow(3, 3 / 2)));
        expect(
            integrate(sqrt, 0, 4, depth: 30), isCloseTo(2 / 3 * pow(4, 3 / 2)));
        expect(
            integrate(sqrt, 0, 5, depth: 40), isCloseTo(2 / 3 * pow(5, 3 / 2)));
      });
      test('other', () {
        expect(integrate((x) => sqrt(1 - x * x), 0, 1, depth: 30),
            isCloseTo(pi / 4));
        expect(integrate((x) => exp(-x), 0, double.infinity, depth: 30),
            isCloseTo(1));
      });
    });
    group('bounds', () {
      double f(double x) => exp(-x * x);
      double g(double x) => 1.0 / (x * x);
      test('empty', () {
        expect(integrate((x) => fail('No evaluation'), pi, pi), isCloseTo(0));
      });
      test('inverted', () {
        expect(integrate(exp, 1, 0), isCloseTo(1 - e));
      });
      test('unbounded', () {
        expect(integrate(f, double.negativeInfinity, double.infinity),
            isCloseTo(sqrt(pi)));
      });
      test('lower unbounded', () {
        expect(integrate(f, double.negativeInfinity, 0),
            isCloseTo(sqrt(pi) / 2.0));
        expect(integrate(g, double.negativeInfinity, -1), isCloseTo(1.0));
      });
      test('upper unbounded', () {
        expect(integrate(f, 0, double.infinity), isCloseTo(sqrt(pi) / 2.0));
        expect(integrate(g, 1, double.infinity), isCloseTo(1.0));
      });
      test('inverted unbounded', () {
        expect(integrate(f, double.infinity, double.negativeInfinity),
            isCloseTo(-sqrt(pi)));
      });
      test('inverted lower unbounded', () {
        expect(integrate(f, 0, double.negativeInfinity),
            isCloseTo(-sqrt(pi) / 2.0));
        expect(integrate(g, -1, double.negativeInfinity), isCloseTo(-1.0));
      });
      test('inverted upper unbounded', () {
        expect(integrate(f, double.infinity, 0), isCloseTo(-sqrt(pi) / 2.0));
        expect(integrate(g, double.infinity, 1), isCloseTo(-1.0));
      });
    });
    group('poles', () {
      double f(double x) => x.roundToDouble() == x && x.round().isEven
          ? throw ArgumentError('Pole was evaluated at $x.')
          : 1.0;
      test('at lower bound', () {
        expect(integrate(f, -1, 0, poles: [0]), isCloseTo(1));
      });
      test('at upper bound', () {
        expect(integrate(f, 0, 1.5, poles: [0]), isCloseTo(1.5));
      });
      test('at both bounds', () {
        expect(integrate(f, 0, 2, poles: [0, 2]), isCloseTo(2));
      });
      test('at the center', () {
        expect(integrate(f, -1.5, 1.5, poles: [0]), isCloseTo(3));
      });
      test('multiple poles', () {
        expect(integrate(f, -3, 3, poles: [0, 2, -2]), isCloseTo(6));
      });
      test('irrelevant poles', () {
        expect(integrate(f, 0.5, 1.5, poles: [0, 2, -2]), isCloseTo(1));
      });
    });
    test('evaluation points', () {
      final evaluationPoints = <double>{};
      integrate((x) {
        expect(evaluationPoints.add(x), isTrue,
            reason: 'No repeated evaluations.');
        return exp(x);
      }, 0, 1);
      expect(evaluationPoints, hasLength(lessThan(20)),
          reason: 'No more than 20 evaluation necessary.');
    });
    group('warnings', () {
      test('does not converge', () {
        expect(
            () => integrate(exp, 0, 1, epsilon: 0),
            throwsA(isA<IntegrateError>()
                .having(
                    (err) => err.type, 'type', IntegrateWarning.doesNotConverge)
                .having((err) => err.x, 'x', isCloseTo(0.5))
                .having((err) => err.toString(), 'toString',
                    startsWith('IntegrateError'))));
      });
      test('does not converge (custom)', () {
        final warnings = <Tuple2<IntegrateWarning, double>>[];
        integrate(exp, 0, 1,
            epsilon: 0, onWarning: (type, x) => warnings.add(Tuple2(type, x)));
        expect(warnings, const [Tuple2(IntegrateWarning.doesNotConverge, 0.5)]);
      });
      test('depth too shallow', () {
        expect(
            () => integrate(exp, 0, 1, depth: 1),
            throwsA(isA<IntegrateError>()
                .having(
                    (err) => err.type, 'type', IntegrateWarning.depthTooShallow)
                .having((err) => err.x, 'x', isCloseTo(0.25))
                .having((err) => err.toString(), 'toString',
                    startsWith('IntegrateError'))));
      });
      test('depth too shallow (custom)', () {
        final warnings = <Tuple2<IntegrateWarning, double>>[];
        integrate(exp, 0, 1,
            depth: 1, onWarning: (type, x) => warnings.add(Tuple2(type, x)));
        expect(warnings, const [
          Tuple2(IntegrateWarning.depthTooShallow, 0.25),
          Tuple2(IntegrateWarning.depthTooShallow, 0.75),
        ]);
      });
    });
    group('errors', () {
      test('invalid lower bound', () {
        expect(
            () => integrate(exp, double.nan, 0),
            throwsA(isA<ArgumentError>()
                .having((error) => error.name, 'name', 'a')
                .having((error) => error.message, 'message',
                    'Invalid lower bound')));
      });
      test('invalid upper bound', () {
        expect(
            () => integrate(exp, 0, double.nan),
            throwsA(isA<ArgumentError>()
                .having((error) => error.name, 'name', 'b')
                .having((error) => error.message, 'message',
                    'Invalid upper bound')));
      });
    });
    group('beauties', () {
      test('sophomore\'s dream', () {
        expect(integrate((x) => pow(x, -x).toDouble(), 0, 1, depth: 15),
            isCloseTo(1.2912859970));
        expect(integrate((x) => pow(x, x).toDouble(), 0, 1, depth: 15),
            isCloseTo(0.7834305107));
      });
      test('pi', () {
        expect(
            integrate((x) => 1 / (1 + x * x), double.negativeInfinity,
                double.infinity),
            isCloseTo(pi));
        expect(22 / 7 - integrate((x) => pow(x - x * x, 4) / (1 + x * x), 0, 1),
            isCloseTo(pi));
      });
    });
  });
  group('solve', () {
    test('raising bracket', () {
      expect(solve(cos, 4, 6), isCloseTo(3 * pi / 2));
    });
    test('descending bracket', () {
      expect(solve(sin, 2, 4), isCloseTo(pi));
    });
    test('polynomial', () {
      double f(double x) => (x + 3) * (x - 1) * (x - 1);
      expect(solve(f, -4, 0), isCloseTo(-3));
    });
  });
}
