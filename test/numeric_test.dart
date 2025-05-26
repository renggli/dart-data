import 'dart:math';

import 'package:data/data.dart';
import 'package:meta/meta.dart';
import 'package:more/collection.dart';
import 'package:more/math.dart';
import 'package:more/tuple.dart';
import 'package:test/test.dart';

import 'utils/assertions.dart';
import 'utils/matchers.dart';

(Vector<double>, Vector<double>) generateSamples(
  UnaryFunction<double> function, {
  double min = -1.0,
  double max = 1.0,
  int count = 10,
}) {
  final xs = Vector<double>.generate(
    DataType.float,
    count,
    (i) => min + i * (max - min) / (count - 1),
    format: VectorFormat.list,
  );
  final ys = Vector<double>.generate(
    DataType.float,
    count,
    (i) => function(xs[i]),
    format: VectorFormat.list,
  );
  return (xs, ys);
}

void main() {
  group('curve fit', () {
    group('levenberg marquardt', () {
      @isTest
      void verifyLevenbergMarquardt(
        String name,
        LevenbergMarquardt fitter, {
        // Parameters for sampled test data.
        Object? parameters,
        double? start,
        double? stop,
        int? count,
        // Parameters for provided test data.
        Vector<double>? xs,
        Vector<double>? ys,
        // Assertion parameters.
        Object? expectedParameters,
        double expectedParametersEpsilon = 1e-3,
        double? expectedError = 0.0,
        double expectedErrorEpsilon = 1e-2,
        int? expectedIterations,
      }) {
        test(name, () {
          final result = () {
            if (parameters != null &&
                start != null &&
                stop != null &&
                count != null) {
              final function = fitter.parametrizedFunction.bind(
                fitter.parametrizedFunction.toVector(expectedParameters),
              );
              final x = linearSpaced(start, stop, count: count).toVector();
              final y = x.map((i, xi) => function(xi)).toVector();
              return fitter.fit(xs: x, ys: y);
            } else if (xs != null && ys != null) {
              return fitter.fit(xs: xs, ys: ys);
            } else {
              throw ArgumentError('Invalid test configuration');
            }
          }();
          if (expectedParameters != null) {
            expect(
              result.parameters,
              isCloseTo(expectedParameters, epsilon: expectedParametersEpsilon),
            );
          }
          if (expectedError != null) {
            expect(
              result.error,
              isCloseTo(expectedError, epsilon: expectedErrorEpsilon),
            );
          }
          if (expectedIterations != null) {
            expect(result.iterations, expectedIterations);
          }
        });
      }

      final bennet5 = ParametrizedUnaryFunction<double>.positional(
        DataType.float,
        3,
        (double a, double b, double c) =>
            (double x) => a * pow(x + b, -1 / c),
      );

      final sinFunction = ParametrizedUnaryFunction<double>.named(
        DataType.float,
        [#a, #b],
        ({required double a, required double b}) =>
            (double x) => a * sin(b * x),
      );

      final sigmodid = ParametrizedUnaryFunction<double>.positional(
        DataType.float,
        3,
        (double a, double b, double c) =>
            (double x) => a / (b + exp(-x * c)),
      );

      final lorentzians = ParametrizedUnaryFunction<double>.vector(
        DataType.float,
        6,
        (params) => (double x) {
          var result = 0.0;
          for (var i = 0; i < params.count; i += 3) {
            final p2 = pow(params[i + 2] / 2, 2);
            final factor = params[i + 1] * p2;
            result += factor / (pow(x - params[i], 2) + p2);
          }
          return result;
        },
      );

      verifyLevenbergMarquardt(
        'bennet5(2, 3, 5)',
        LevenbergMarquardt(
          bennet5,
          initialValues: <double>[3.5, 3.8, 4.0],
          minValues: <double>[1, 2.7, 1],
          maxValues: <double>[11, 11, 11],
          damping: 0.00001,
          maxIterations: 100,
          errorTolerance: 1e-7,
        ),
        parameters: [2.0, 3.0, 5.0],
        start: -2.6581,
        stop: 49.6526,
        count: 154,
        // Assertions
        expectedParameters: [2.0, 3.0, 5.0],
      );
      verifyLevenbergMarquardt(
        '2*sin(2*x)',
        LevenbergMarquardt(
          sinFunction,
          initialValues: {#a: 3.0, #b: 3.0},
          maxIterations: 100,
          gradientDifference: 0.1,
          damping: 0.1,
          dampingStepDown: 1.0,
          dampingStepUp: 1.0,
        ),
        parameters: {#a: 2.0, #b: 2.0},
        count: 20,
        start: 0,
        stop: 19,
        // Assertions
        expectedParameters: {#a: 2.0, #b: 2.0},
      );
      // Strangely this test fails on GitHub Actions:
      //
      // verifyLevenbergMarquardt(
      //   'sin function with lowest error',
      //   LevenbergMarquardt(
      //     sinFunction,
      //     initialValues: {#a: 0.594398586701882, #b: 0.3506424963635226},
      //     damping: 1.5,
      //     gradientDifference: 1e-2,
      //     maxIterations: 100,
      //     errorTolerance: 1e-2,
      //   ),
      //   xs: [
      //     0.0,
      //     0.6283185307179586,
      //     1.2566370614359172,
      //     1.8849555921538759,
      //     2.5132741228718345,
      //     3.141592653589793,
      //     3.7699111843077517,
      //     4.39822971502571,
      //     5.026548245743669,
      //     5.654866776461628,
      //   ].toVector(),
      //   ys: [
      //     0.0,
      //     1.902113032590307,
      //     1.1755705045849465,
      //     -1.175570504584946,
      //     -1.9021130325903073,
      //     -4.898587196589413e-16,
      //     1.902113032590307,
      //     1.1755705045849467,
      //     -1.1755705045849456,
      //     -1.9021130325903075,
      //   ].toVector(),
      //   // Assertions
      //   expectedError: 15.527598503066368,
      //   expectedIterations: 100,
      // );
      verifyLevenbergMarquardt(
        'sigmoid',
        LevenbergMarquardt(
          sigmodid,
          initialValues: [3.0, 3.0, 3.0],
          damping: 0.1,
          maxIterations: 200,
        ),
        parameters: [2.0, 2.0, 2.0],
        count: 20,
        start: 0,
        stop: 19,
        // Assertions
        expectedParameters: [2.0, 2.0, 2.0],
        expectedParametersEpsilon: 0.1,
      );
      verifyLevenbergMarquardt(
        'lorentzians',
        LevenbergMarquardt(
          lorentzians,
          initialValues: [1.1, 0.15, 0.29, 4.05, 0.17, 0.3].toVector(),
          gradientDifferences: [
            0.01,
            0.0001,
            0.0001,
            0.01,
            0.0001,
            0.0,
          ].toVector(),
          damping: 0.01,
          maxIterations: 500,
        ),
        parameters: [1.05, 0.1, 0.3, 4.0, 0.15, 0.3].toVector(),
        count: 100,
        start: 0,
        stop: 99,
        // Assertions
        expectedParameters: [1.05, 0.1, 0.3, 4.0, 0.15, 0.3].toVector(),
        expectedParametersEpsilon: 0.1,
      );
      verifyLevenbergMarquardt(
        'lorentzians with central differences',
        LevenbergMarquardt(
          lorentzians,
          initialValues: [1.1, 0.15, 0.29, 4.05, 0.17, 0.28].toVector(),
          gradientDifferences: [0.01, 0.0001, 0.0001, 0.01, 0.0001].toVector(),
          damping: 0.01,
          centralDifference: true,
          maxIterations: 500,
          errorTolerance: 10e-8,
        ),
        parameters: [1.0, 0.1, 0.3, 4.0, 0.15, 0.3].toVector(),
        count: 100,
        start: 0,
        stop: 99,
        // Assertions
        expectedParameters: [1.0, 0.1, 0.3, 4.0, 0.15, 0.3].toVector(),
        expectedParametersEpsilon: 0.1,
      );
      verifyLevenbergMarquardt(
        'noisy real-world data',
        LevenbergMarquardt(
          ParametrizedUnaryFunction<double>.positional(
            DataType.float,
            4,
            (double a, double b, double c, double d) =>
                (double x) => a + (b - a) / (1 + pow(c, d) * pow(x, -d)),
          ),
          initialValues: [0.0, 100.0, 1.0, 0.1].toVector(),
          damping: 0.00001,
          maxIterations: 200,
        ),
        xs: [
          9.22e-12,
          5.53e-11,
          3.32e-10,
          1.99e-9,
          1.19e-8,
          7.17e-8,
          4.3e-7,
          0.00000258,
          0.0000155,
          0.0000929,
        ].toVector(),
        ys: [
          7.807,
          -3.74,
          21.119,
          2.382,
          4.269,
          41.57,
          73.401,
          98.535,
          97.059,
          92.147,
        ].toVector(),
        // Assertions
        expectedIterations: 200,
        expectedParameters: [-16.7697, 43.4549, 1018.8938, -4.3514],
        expectedError: 16398.0009709,
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
          final result = fitter.fit(xs: height, ys: mass);
          expect(result.polynomial.degree, 0);
          expect(result.polynomial[0], isCloseTo(62.078000));
        });
        test('linear', () {
          final fitter = PolynomialRegression(degree: 1);
          final result = fitter.fit(xs: height, ys: mass);
          expect(result.polynomial.degree, 1);
          expect(result.polynomial[0], isCloseTo(-39.061956));
          expect(result.polynomial[1], isCloseTo(61.272187));
        });
        test('quadratic', () {
          final fitter = PolynomialRegression(degree: 2);
          final result = fitter.fit(xs: height, ys: mass);
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
          final result = fitter.fit(xs: data.first, ys: data.second);
          expect(result.polynomial.degree, fitter.degree);
          for (var i = 0; i <= fitter.degree; i++) {
            expect(
              result.polynomial[i],
              isCloseTo(1.0 / i.factorial()),
              reason: '$i-th coefficient',
            );
          }
        });
        test('sin', () {
          final fitter = PolynomialRegression(degree: 10);
          final data = generateSamples(sin, count: 50);
          final result = fitter.fit(xs: data.first, ys: data.second);
          expect(result.polynomial.degree, fitter.degree);
          for (var i = 0; i <= fitter.degree; i++) {
            expect(
              result.polynomial[i],
              isCloseTo(i.isOdd ? pow(-1, (i - 1) ~/ 2) / i.factorial() : 0.0),
              reason: '$i-th coefficient',
            );
          }
        });
        test('cos', () {
          final fitter = PolynomialRegression(degree: 10);
          final data = generateSamples(cos, count: 50);
          final result = fitter.fit(xs: data.first, ys: data.second);
          expect(result.polynomial.degree, fitter.degree);
          for (var i = 0; i <= fitter.degree; i++) {
            expect(
              result.polynomial[i],
              isCloseTo(i.isEven ? pow(-1, i ~/ 2) / i.factorial() : 0.0),
              reason: '$i-th coefficient',
            );
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
        expect(
          derivative(sin, 0.0 * pi, derivative: 2, accuracy: a),
          isCloseTo(0.0),
        );
        expect(
          derivative(sin, 0.5 * pi, derivative: 2, accuracy: a),
          isCloseTo(-1.0),
        );
        expect(
          derivative(sin, 1.0 * pi, derivative: 2, accuracy: a),
          isCloseTo(0.0),
        );
        expect(
          derivative(sin, 1.5 * pi, derivative: 2, accuracy: a),
          isCloseTo(1.0),
        );
        // cos-function
        expect(
          derivative(cos, 0.0 * pi, derivative: 2, accuracy: a),
          isCloseTo(-1.0),
        );
        expect(
          derivative(cos, 0.5 * pi, derivative: 2, accuracy: a),
          isCloseTo(0.0),
        );
        expect(
          derivative(cos, 1.0 * pi, derivative: 2, accuracy: a),
          isCloseTo(1.0),
        );
        expect(
          derivative(cos, 1.5 * pi, derivative: 2, accuracy: a),
          isCloseTo(0.0),
        );
        // exp-function
        expect(
          derivative(exp, -1.0, derivative: 2, accuracy: a),
          isCloseTo(1 / e),
        );
        expect(
          derivative(exp, 0.0, derivative: 2, accuracy: a),
          isCloseTo(1.0),
        );
        expect(derivative(exp, 1.0, derivative: 2, accuracy: a), isCloseTo(e));
      }
    });
    group('error', () {
      test('derivative', () {
        expect(
          () => derivative(sin, 0, derivative: 0),
          throwsA(
            isA<ArgumentError>()
                .having((error) => error.name, 'name', 'derivative')
                .having(
                  (error) => error.message,
                  'message',
                  'Must be one of 1, 2, 3, 4, 5, 6',
                ),
          ),
        );
      });
      test('accuracy', () {
        expect(
          () => derivative(sin, 0, accuracy: 0),
          throwsA(
            isA<ArgumentError>()
                .having((error) => error.name, 'name', 'accuracy')
                .having(
                  (error) => error.message,
                  'message',
                  'Must be one of 2, 4, 6, 8',
                ),
          ),
        );
      });
    });
  });
  group('fft', () {
    test('empty', () {
      final source = <Complex>[];
      final forward = fft([...source]);
      expect(forward, isEmpty);
      final backward = fft([...forward], inverse: true);
      expect(backward, isEmpty);
    });
    test('single', () {
      final values = [
        Complex.zero,
        Complex.one,
        Complex.i,
        -Complex.one,
        -Complex.i,
      ];
      for (final value in values) {
        final source = [value];
        final forward = fft([...source]);
        expect(forward, isCloseTo(source));
        final backward = fft([...forward], inverse: true);
        expect(backward, isCloseTo(source));
      }
    });
    test('zeros', () {
      for (var i = 2; i <= 256; i *= 2) {
        final source = List.filled(i, Complex.zero);
        final forward = fft([...source]);
        final backward = fft([...forward], inverse: true);
        expect(backward, isCloseTo(source));
      }
    });
    test('constant', () {
      final random = Random(22562);
      for (var i = 2; i <= 256; i *= 2) {
        final constant = Complex(
          2.0 * random.nextDouble() - 1.0,
          2.0 * random.nextDouble() - 1.0,
        );
        final source = List.filled(i, constant);
        final forward = fft([...source]);
        final backward = fft([...forward], inverse: true);
        expect(backward, isCloseTo(source));
      }
    });
    test('alternate (real)', () {
      final values = [Complex.one, -Complex.one];
      for (var i = 2; i <= 256; i *= 2) {
        final source = List.generate(i, (j) => values[j % values.length]);
        final forward = fft([...source]);
        final backward = fft([...forward], inverse: true);
        expect(backward, isCloseTo(source));
      }
    });
    test('alternate (imaginary)', () {
      final values = [Complex.i, -Complex.i];
      for (var i = 2; i <= 256; i *= 2) {
        final source = List.generate(i, (j) => values[j % values.length]);
        final forward = fft([...source]);
        final backward = fft([...forward], inverse: true);
        expect(backward, isCloseTo(source));
      }
    });
    test('alternate (real + imaginary)', () {
      final values = [Complex.one, Complex.i, -Complex.one, -Complex.i];
      for (var i = 2; i <= 256; i *= 2) {
        final source = List.generate(i, (j) => values[j % values.length]);
        final forward = fft([...source]);
        final backward = fft([...forward], inverse: true);
        expect(backward, isCloseTo(source));
      }
    });
    test('rotation', () {
      final random = Random(12881922);
      for (var i = 128; i <= 8192; i *= 2) {
        final radius = 0.75 * random.nextDouble() + 0.25;
        final period = 2.0 * pi * random.nextDouble();
        final shift = 2.0 * pi * random.nextDouble();
        final source = List.generate(
          i,
          (j) => Complex.fromPolar(radius, j / period + shift),
        );
        final forward = fft([...source]);
        final backward = fft([...forward], inverse: true);
        expect(backward, isCloseTo(source));
      }
    });
    test('spike', () {
      final random = Random(12881922);
      for (var i = 128; i <= 8192; i *= 2) {
        final source = List.generate(i, (i) => Complex.zero);
        source[random.nextInt(source.length - 1)] = Complex(
          2.0 * random.nextDouble() - 1.0,
          2.0 * random.nextDouble() - 1.0,
        );
        final forward = fft([...source]);
        final backward = fft([...forward], inverse: true);
        expect(backward, isCloseTo(source));
      }
    });
    test('random', () {
      final random = Random(98712);
      for (var i = 2; i <= 128; i++) {
        final source = List.generate(
          i,
          (i) => Complex(
            2.0 * random.nextDouble() - 1.0,
            2.0 * random.nextDouble() - 1.0,
          ),
        );
        final forward = fft([...source]);
        expect(forward.length.hasSingleBit, isTrue);
        final backward = fft([...forward], inverse: true);
        expect(backward.length.hasSingleBit, isTrue);
        while (source.length < backward.length) {
          source.add(Complex.zero);
        }
        expect(backward, isCloseTo(source));
      }
    });
  });
  group('functions', () {
    test('list', () {
      final function = ParametrizedUnaryFunction<String>.list(
        DataType.string,
        3,
        (params) =>
            (x) => 'f_${params[0]},${params[1]},${params[2]}($x)',
      );
      expect(function.dataType, DataType.string);
      expect(function.count, 3);
      expect(function.toVector(['a', 'b'], defaultParam: 'c').iterable, [
        'a',
        'b',
        'c',
      ]);
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
        (params) =>
            (x) => 'f_${params[#a]},${params[#b]},${params[#c]}($x)',
      );
      expect(function.dataType, DataType.string);
      expect(function.count, 3);
      expect(
        function.toVector({#b: 'b', #a: 'a'}, defaultParam: 'c').iterable,
        ['a', 'b', 'c'],
      );
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
            (String x) => 'f_$a,$b,$c($x)',
      );
      expect(function.dataType, DataType.string);
      expect(function.count, 3);
      expect(
        function.toVector({#b: 'b', #a: 'a'}, defaultParam: 'c').iterable,
        ['a', 'b', 'c'],
      );
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
        (String a, String b, String c) =>
            (String x) => 'f_$a,$b,$c($x)',
      );
      expect(function.dataType, DataType.string);
      expect(function.count, 3);
      expect(function.toVector(['a', 'b'], defaultParam: 'c').iterable, [
        'a',
        'b',
        'c',
      ]);
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
        (params) =>
            (x) => 'f_${params[0]},${params[1]},${params[2]}($x)',
      );
      expect(function.dataType, DataType.string);
      expect(function.count, 3);
      expect(
        function.toVector(['a', 'b'].toVector(), defaultParam: 'c').iterable,
        ['a', 'b', 'c'],
      );
      final arguments = ['a', 'b', 'c'].toVector();
      final bindings = function.toBindings(arguments);
      final bound = function.bind(arguments);
      arguments[0] = 'x';
      expect((bindings as Vector<String>).toList(), ['a', 'b', 'c']);
      expect(bound('1'), 'f_a,b,c(1)');
    });
    test('default params', () {
      final function = ParametrizedUnaryFunction<int>.list(
        DataType.int32,
        2,
        (params) =>
            (x) => fail('not tested'),
      );
      expect(
        function.toVector(null, defaultParam: 7),
        isCloseTo([7, 7].toVector()),
      );
      expect(
        function.toVector(<int>[], defaultParam: 7),
        isCloseTo([7, 7].toVector()),
      );
      expect(
        function.toVector([3], defaultParam: 7),
        isCloseTo([3, 7].toVector()),
      );
      expect(
        function.toVector([3, 4], defaultParam: 7),
        isCloseTo([3, 4].toVector()),
      );
      expect(() => function.toVector(null), throwsArgumentError);
      expect(() => function.toVector([]), throwsArgumentError);
      expect(() => function.toVector([42]), throwsArgumentError);
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
          expect(
            vector.iterable,
            isCloseTo([100, 215.443469, 464.15888336, 1000]),
          );
        });
        test('without endpoint', () {
          final vector = logarithmicSpaced(
            2,
            3,
            count: 4,
            includeEndpoint: false,
          );
          expect(
            vector.iterable,
            isCloseTo([100, 177.827941, 316.22776602, 562.34132519]),
          );
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
          final vector = geometricSpaced(
            1,
            1000,
            count: 4,
            includeEndpoint: false,
          );
          expect(
            vector.iterable,
            isCloseTo([1, 5.62341325, 31.6227766, 177.827941]),
          );
        });
      });
    });
    group('lagrange', () {
      test('0 samples', () {
        final xs = <double>[];
        final ys = <double>[];
        expect(
          () => lagrangeInterpolation(
            DataType.float,
            xs: xs.toVector(),
            ys: ys.toVector(),
          ),
          throwsArgumentError,
        );
      });
      test('1 sample: f(x) = 2', () {
        final xs = <double>[1].toVector();
        final ys = <double>[2].toVector();
        final actual = lagrangeInterpolation(DataType.float, xs: xs, ys: ys);
        verifySamples<double>(DataType.float, actual: actual, xs: xs, ys: ys);
        verifyFunction<double>(
          DataType.float,
          actual: actual,
          expected: (x) => 2,
          range: DoubleRange(0.0, 3.0, 0.1),
        );
      });
      test('2 samples: f(x) = 4 * x - 7', () {
        final xs = <double>[2, 3].toVector();
        final ys = <double>[1, 5].toVector();
        final actual = lagrangeInterpolation(DataType.float, xs: xs, ys: ys);
        verifySamples<double>(DataType.float, actual: actual, xs: xs, ys: ys);
        verifyFunction<double>(
          DataType.float,
          actual: actual,
          expected: (x) => 4 * x - 7,
          range: DoubleRange(0.0, 4.0, 0.1),
        );
      });
      test('3 samples: f(x) = 5/4 * x^2 - x + 1', () {
        final xs = <double>[0, 2, 4].toVector();
        final ys = <double>[1, 4, 17].toVector();
        final actual = lagrangeInterpolation(DataType.float, xs: xs, ys: ys);
        verifySamples<double>(DataType.float, actual: actual, xs: xs, ys: ys);
        verifyFunction<double>(
          DataType.float,
          actual: actual,
          expected: (x) => 5 / 4 * x * x - x + 1,
          range: DoubleRange(-1.0, 5.0, 0.1),
        );
      });
    });
    group('linear', () {
      test('increasing', () {
        final f = linearInterpolation(
          DataType.float,
          xs: [1.0, 2.0].toVector(),
          ys: [3.0, 4.0].toVector(),
        );
        expect(f(0.5), isCloseTo(2.5));
        expect(f(1.0), isCloseTo(3.0));
        expect(f(1.5), isCloseTo(3.5));
        expect(f(2.0), isCloseTo(4.0));
        expect(f(2.5), isCloseTo(4.5));
      });
      test('decreasing', () {
        final f = linearInterpolation(
          DataType.float,
          xs: [1.0, 2.0].toVector(),
          ys: [4.0, 3.0].toVector(),
        );
        expect(f(0.5), isCloseTo(4.5));
        expect(f(1.0), isCloseTo(4.0));
        expect(f(1.5), isCloseTo(3.5));
        expect(f(2.0), isCloseTo(3.0));
        expect(f(2.5), isCloseTo(2.5));
      });
      test('custom bounds', () {
        final f = linearInterpolation(
          DataType.float,
          xs: [1.0, 2.0].toVector(),
          ys: [3.0, 4.0].toVector(),
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
        final f = linearInterpolation(DataType.float, xs: x, ys: y);
        for (var i = -1.0; i <= 1.0; i += 0.25) {
          expect(f(i), isCloseTo(exp(i), epsilon: 0.1));
        }
      });
    });
    group('nearest', () {
      test('prefer lower', () {
        final f = nearestInterpolation(
          xs: [1.0, 2.0].toVector(),
          ys: [3.0, 4.0].toVector(),
        );
        expect(f(0.5), isCloseTo(3.0));
        expect(f(1.0), isCloseTo(3.0));
        expect(f(1.2), isCloseTo(3.0));
        expect(f(1.5), isCloseTo(3.0));
        expect(f(1.8), isCloseTo(4.0));
        expect(f(2.0), isCloseTo(4.0));
        expect(f(2.5), isCloseTo(4.0));
      });
      test('prefer upper', () {
        final f = nearestInterpolation(
          xs: [1.0, 2.0].toVector(),
          ys: [3.0, 4.0].toVector(),
          preferLower: false,
        );
        expect(f(0.5), isCloseTo(3.0));
        expect(f(1.0), isCloseTo(3.0));
        expect(f(1.2), isCloseTo(3.0));
        expect(f(1.5), isCloseTo(4.0));
        expect(f(1.8), isCloseTo(4.0));
        expect(f(2.0), isCloseTo(4.0));
        expect(f(2.5), isCloseTo(4.0));
      });
    });
    test('previous', () {
      final f = previousInterpolation(
        xs: [1.0, 2.0].toVector(),
        ys: [3.0, 4.0].toVector(),
      );
      expect(f(0.5), isCloseTo(double.nan));
      expect(f(1.0), isCloseTo(3.0));
      expect(f(1.2), isCloseTo(3.0));
      expect(f(1.5), isCloseTo(3.0));
      expect(f(1.8), isCloseTo(3.0));
      expect(f(2.0), isCloseTo(4.0));
      expect(f(2.5), isCloseTo(4.0));
    });
    test('next', () {
      final f = nextInterpolation(
        xs: [1.0, 2.0].toVector(),
        ys: [3.0, 4.0].toVector(),
      );
      expect(f(0.5), isCloseTo(3.0));
      expect(f(1.0), isCloseTo(3.0));
      expect(f(1.2), isCloseTo(4.0));
      expect(f(1.5), isCloseTo(4.0));
      expect(f(1.8), isCloseTo(4.0));
      expect(f(2.0), isCloseTo(4.0));
      expect(f(2.5), isCloseTo(double.nan));
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
          integrate(sqrt, 0, 1, depth: 25),
          isCloseTo(2 / 3 * pow(1, 3 / 2)),
        );
        expect(
          integrate(sqrt, 0, 2, depth: 25),
          isCloseTo(2 / 3 * pow(2, 3 / 2)),
        );
        expect(
          integrate(sqrt, 0, 3, depth: 30),
          isCloseTo(2 / 3 * pow(3, 3 / 2)),
        );
        expect(
          integrate(sqrt, 0, 4, depth: 30),
          isCloseTo(2 / 3 * pow(4, 3 / 2)),
        );
        expect(
          integrate(sqrt, 0, 5, depth: 40),
          isCloseTo(2 / 3 * pow(5, 3 / 2)),
        );
      });
      test('other', () {
        expect(
          integrate((x) => sqrt(1 - x * x), 0, 1, depth: 30),
          isCloseTo(pi / 4),
        );
        expect(
          integrate((x) => exp(-x), 0, double.infinity, depth: 30),
          isCloseTo(1),
        );
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
        expect(
          integrate(f, double.negativeInfinity, double.infinity),
          isCloseTo(sqrt(pi)),
        );
      });
      test('lower unbounded', () {
        expect(
          integrate(f, double.negativeInfinity, 0),
          isCloseTo(sqrt(pi) / 2.0),
        );
        expect(integrate(g, double.negativeInfinity, -1), isCloseTo(1.0));
      });
      test('upper unbounded', () {
        expect(integrate(f, 0, double.infinity), isCloseTo(sqrt(pi) / 2.0));
        expect(integrate(g, 1, double.infinity), isCloseTo(1.0));
      });
      test('inverted unbounded', () {
        expect(
          integrate(f, double.infinity, double.negativeInfinity),
          isCloseTo(-sqrt(pi)),
        );
      });
      test('inverted lower unbounded', () {
        expect(
          integrate(f, 0, double.negativeInfinity),
          isCloseTo(-sqrt(pi) / 2.0),
        );
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
      integrate(
        (x) {
          expect(
            evaluationPoints.add(x),
            isTrue,
            reason: 'No repeated evaluations.',
          );
          return exp(x);
        },
        0,
        1,
      );
      expect(
        evaluationPoints,
        hasLength(lessThan(20)),
        reason: 'No more than 20 evaluation necessary.',
      );
    });
    group('warnings', () {
      test('does not converge', () {
        expect(
          () => integrate(exp, 0, 1, epsilon: 0),
          throwsA(
            isA<IntegrateError>()
                .having(
                  (err) => err.type,
                  'type',
                  IntegrateWarning.doesNotConverge,
                )
                .having((err) => err.x, 'x', isCloseTo(0.5))
                .having(
                  (err) => err.toString(),
                  'toString',
                  startsWith('IntegrateError'),
                ),
          ),
        );
      });
      test('does not converge (custom)', () {
        final warnings = <(IntegrateWarning, double)>[];
        integrate(
          exp,
          0,
          1,
          epsilon: 0,
          onWarning: (type, x) => warnings.add((type, x)),
        );
        expect(warnings, const [(IntegrateWarning.doesNotConverge, 0.5)]);
      });
      test('depth too shallow', () {
        expect(
          () => integrate(exp, 0, 1, depth: 1),
          throwsA(
            isA<IntegrateError>()
                .having(
                  (err) => err.type,
                  'type',
                  IntegrateWarning.depthTooShallow,
                )
                .having((err) => err.x, 'x', isCloseTo(0.25))
                .having(
                  (err) => err.toString(),
                  'toString',
                  startsWith('IntegrateError'),
                ),
          ),
        );
      });
      test('depth too shallow (custom)', () {
        final warnings = <(IntegrateWarning, double)>[];
        integrate(
          exp,
          0,
          1,
          depth: 1,
          onWarning: (type, x) => warnings.add((type, x)),
        );
        expect(warnings, const [
          (IntegrateWarning.depthTooShallow, 0.25),
          (IntegrateWarning.depthTooShallow, 0.75),
        ]);
      });
    });
    group('errors', () {
      test('invalid lower bound', () {
        expect(
          () => integrate(exp, double.nan, 0),
          throwsA(
            isA<ArgumentError>()
                .having((error) => error.name, 'name', 'a')
                .having(
                  (error) => error.message,
                  'message',
                  'Invalid lower bound',
                ),
          ),
        );
      });
      test('invalid upper bound', () {
        expect(
          () => integrate(exp, 0, double.nan),
          throwsA(
            isA<ArgumentError>()
                .having((error) => error.name, 'name', 'b')
                .having(
                  (error) => error.message,
                  'message',
                  'Invalid upper bound',
                ),
          ),
        );
      });
    });
    group('beauties', () {
      test('sophomore\'s dream', () {
        expect(
          integrate((x) => pow(x, -x).toDouble(), 0, 1, depth: 15),
          isCloseTo(1.2912859970),
        );
        expect(
          integrate((x) => pow(x, x).toDouble(), 0, 1, depth: 15),
          isCloseTo(0.7834305107),
        );
      });
      test('pi', () {
        expect(
          integrate(
            (x) => 1 / (1 + x * x),
            double.negativeInfinity,
            double.infinity,
          ),
          isCloseTo(pi),
        );
        expect(
          22 / 7 - integrate((x) => pow(x - x * x, 4) / (1 + x * x), 0, 1),
          isCloseTo(pi),
        );
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
