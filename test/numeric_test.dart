import 'dart:math';

import 'package:data/numeric.dart';
import 'package:test/test.dart';

const epsilon = 1.0e-5;

void main() {
  group('derivative', () {
    test('first derivative at different accuracies', () {
      for (var a = 2; a <= 8; a += 2) {
        // sin-function
        expect(derivative(sin, 0.0 * pi, accuracy: a), closeTo(1.0, epsilon));
        expect(derivative(sin, 0.5 * pi, accuracy: a), closeTo(0.0, epsilon));
        expect(derivative(sin, 1.0 * pi, accuracy: a), closeTo(-1.0, epsilon));
        expect(derivative(sin, 1.5 * pi, accuracy: a), closeTo(0.0, epsilon));
        // cos-function
        expect(derivative(cos, 0.0 * pi, accuracy: a), closeTo(0.0, epsilon));
        expect(derivative(cos, 0.5 * pi, accuracy: a), closeTo(-1.0, epsilon));
        expect(derivative(cos, 1.0 * pi, accuracy: a), closeTo(0.0, epsilon));
        expect(derivative(cos, 1.5 * pi, accuracy: a), closeTo(1.0, epsilon));
        // exp-function
        expect(derivative(exp, -1.0, accuracy: a), closeTo(1 / e, epsilon));
        expect(derivative(exp, 0.0, accuracy: a), closeTo(1.0, epsilon));
        expect(derivative(exp, 1.0, accuracy: a), closeTo(e, epsilon));
      }
    });
    test('second derivative at different accuracies', () {
      for (var a = 2; a <= 8; a += 2) {
        // sin-function
        expect(derivative(sin, 0.0 * pi, derivative: 2, accuracy: a),
            closeTo(0.0, epsilon));
        expect(derivative(sin, 0.5 * pi, derivative: 2, accuracy: a),
            closeTo(-1.0, epsilon));
        expect(derivative(sin, 1.0 * pi, derivative: 2, accuracy: a),
            closeTo(0.0, epsilon));
        expect(derivative(sin, 1.5 * pi, derivative: 2, accuracy: a),
            closeTo(1.0, epsilon));
        // cos-function
        expect(derivative(cos, 0.0 * pi, derivative: 2, accuracy: a),
            closeTo(-1.0, epsilon));
        expect(derivative(cos, 0.5 * pi, derivative: 2, accuracy: a),
            closeTo(0.0, epsilon));
        expect(derivative(cos, 1.0 * pi, derivative: 2, accuracy: a),
            closeTo(1.0, epsilon));
        expect(derivative(cos, 1.5 * pi, derivative: 2, accuracy: a),
            closeTo(0.0, epsilon));
        // exp-function
        expect(derivative(exp, -1.0, derivative: 2, accuracy: a),
            closeTo(1 / e, epsilon));
        expect(derivative(exp, 0.0, derivative: 2, accuracy: a),
            closeTo(1.0, epsilon));
        expect(derivative(exp, 1.0, derivative: 2, accuracy: a),
            closeTo(e, epsilon));
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
  group('integrate', () {
    void unexpectedWarning(IntegrateWarning warning) =>
        fail('Unexpected warning: $warning');
    group('common', () {
      test('exp', () {
        expect(integrate(exp, 0, 1, onWarning: unexpectedWarning),
            closeTo(e - 1, epsilon));
        expect(integrate(exp, -1, 0, onWarning: unexpectedWarning),
            closeTo(1 - 1 / e, epsilon));
        expect(integrate(exp, -1, 1, onWarning: unexpectedWarning),
            closeTo(e - 1 / e, epsilon));
      });
      test('sin', () {
        expect(integrate(sin, 0, 2 * pi, onWarning: unexpectedWarning),
            closeTo(0, epsilon));
        expect(integrate(sin, -2 * pi, 0, onWarning: unexpectedWarning),
            closeTo(0, epsilon));
        expect(integrate(sin, -2 * pi, 2 * pi, onWarning: unexpectedWarning),
            closeTo(0, epsilon));
      });
      test('cos', () {
        expect(integrate(cos, 0, 2 * pi, onWarning: unexpectedWarning),
            closeTo(0, epsilon));
        expect(integrate(cos, -2 * pi, 0, onWarning: unexpectedWarning),
            closeTo(0, epsilon));
        expect(integrate(cos, -2 * pi, 2 * pi, onWarning: unexpectedWarning),
            closeTo(0, epsilon));
      });
      test('sqr', () {
        double sqr(double x) => x * x;
        expect(integrate(sqr, -1, 1, onWarning: unexpectedWarning),
            closeTo(2 / 3, epsilon));
        expect(integrate(sqr, 0, 2, onWarning: unexpectedWarning),
            closeTo(8 / 3, epsilon));
        expect(integrate(sqr, -1, 2, onWarning: unexpectedWarning),
            closeTo(3, epsilon));
      });
      test('sqrt', () {
        expect(integrate(sqrt, 0, 1, depth: 25, onWarning: unexpectedWarning),
            closeTo(2 / 3 * pow(1, 3 / 2), epsilon));
        expect(integrate(sqrt, 0, 2, depth: 25, onWarning: unexpectedWarning),
            closeTo(2 / 3 * pow(2, 3 / 2), epsilon));
        expect(integrate(sqrt, 0, 3, depth: 30, onWarning: unexpectedWarning),
            closeTo(2 / 3 * pow(3, 3 / 2), epsilon));
        expect(integrate(sqrt, 0, 4, depth: 30, onWarning: unexpectedWarning),
            closeTo(2 / 3 * pow(4, 3 / 2), epsilon));
        expect(integrate(sqrt, 0, 5, depth: 40, onWarning: unexpectedWarning),
            closeTo(2 / 3 * pow(5, 3 / 2), epsilon));
      });
      test('other', () {
        expect(
            integrate((x) => sqrt(1 - x * x), 0, 1,
                depth: 30, onWarning: unexpectedWarning),
            closeTo(pi / 4, epsilon));
        expect(
            integrate((x) => exp(-x), 0, double.infinity,
                depth: 30, onWarning: unexpectedWarning),
            closeTo(1, epsilon));
      });
    });
    group('bounds', () {
      double f(double x) => exp(-x * x);
      test('empty', () {
        expect(
            integrate((x) => fail('No evaluation'), pi, pi,
                onWarning: unexpectedWarning),
            closeTo(0, epsilon));
      });
      test('inverted', () {
        expect(integrate(exp, 1, 0, onWarning: unexpectedWarning),
            closeTo(1 - e, epsilon));
      });
      test('unbounded', () {
        expect(
            integrate(f, double.negativeInfinity, double.infinity,
                onWarning: unexpectedWarning),
            closeTo(sqrt(pi), epsilon));
      });
      test('lower unbounded', () {
        expect(
            integrate(f, double.negativeInfinity, 0,
                onWarning: unexpectedWarning),
            closeTo(sqrt(pi) / 2.0, epsilon));
      });
      test('upper unbounded', () {
        expect(integrate(f, 0, double.infinity, onWarning: unexpectedWarning),
            closeTo(sqrt(pi) / 2.0, epsilon));
      });
      test('inverted unbounded', () {
        expect(
            integrate(f, double.infinity, double.negativeInfinity,
                onWarning: unexpectedWarning),
            closeTo(-sqrt(pi), epsilon));
      });
      test('inverted lower unbounded', () {
        expect(
            integrate(f, 0, double.negativeInfinity,
                onWarning: unexpectedWarning),
            closeTo(-sqrt(pi) / 2.0, epsilon));
      });
      test('inverted upper unbounded', () {
        expect(integrate(f, double.infinity, 0, onWarning: unexpectedWarning),
            closeTo(-sqrt(pi) / 2.0, epsilon));
      });
    });
    test('evaluation points', () {
      final evaluationPoints = <double>{};
      integrate((x) {
        expect(evaluationPoints.add(x), isTrue,
            reason: 'No repeated evaluations.');
        return exp(x);
      }, 0, 1, onWarning: unexpectedWarning);
      expect(evaluationPoints, hasLength(lessThan(20)),
          reason: 'No more than 20 evaluation necessary.');
    });
    group('warnings', () {
      test('does not converge', () {
        final warnings = <IntegrateWarning>{};
        integrate(exp, 0, 1, epsilon: 0, onWarning: warnings.add);
        expect(warnings, {IntegrateWarning.doesNotConverge});
      });
      test('depth too shallow', () {
        final warnings = <IntegrateWarning>{};
        integrate(exp, 0, 1, depth: 1, onWarning: warnings.add);
        expect(warnings, {IntegrateWarning.depthTooShallow});
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
  });
}
