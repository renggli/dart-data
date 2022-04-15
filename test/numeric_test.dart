import 'dart:math';

import 'package:data/data.dart';
import 'package:more/tuple.dart';
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
    group('common', () {
      test('exp', () {
        expect(integrate(exp, 0, 1), closeTo(e - 1, epsilon));
        expect(integrate(exp, -1, 0), closeTo(1 - 1 / e, epsilon));
        expect(integrate(exp, -1, 1), closeTo(e - 1 / e, epsilon));
      });
      test('sin', () {
        expect(integrate(sin, 0, 2 * pi), closeTo(0, epsilon));
        expect(integrate(sin, -2 * pi, 0), closeTo(0, epsilon));
        expect(integrate(sin, -2 * pi, 2 * pi), closeTo(0, epsilon));
      });
      test('cos', () {
        expect(integrate(cos, 0, 2 * pi), closeTo(0, epsilon));
        expect(integrate(cos, -2 * pi, 0), closeTo(0, epsilon));
        expect(integrate(cos, -2 * pi, 2 * pi), closeTo(0, epsilon));
      });
      test('sqr', () {
        double sqr(double x) => x * x;
        expect(integrate(sqr, -1, 1), closeTo(2 / 3, epsilon));
        expect(integrate(sqr, 0, 2), closeTo(8 / 3, epsilon));
        expect(integrate(sqr, -1, 2), closeTo(3, epsilon));
      });
      test('sqrt', () {
        expect(integrate(sqrt, 0, 1, depth: 25),
            closeTo(2 / 3 * pow(1, 3 / 2), epsilon));
        expect(integrate(sqrt, 0, 2, depth: 25),
            closeTo(2 / 3 * pow(2, 3 / 2), epsilon));
        expect(integrate(sqrt, 0, 3, depth: 30),
            closeTo(2 / 3 * pow(3, 3 / 2), epsilon));
        expect(integrate(sqrt, 0, 4, depth: 30),
            closeTo(2 / 3 * pow(4, 3 / 2), epsilon));
        expect(integrate(sqrt, 0, 5, depth: 40),
            closeTo(2 / 3 * pow(5, 3 / 2), epsilon));
      });
      test('other', () {
        expect(integrate((x) => sqrt(1 - x * x), 0, 1, depth: 30),
            closeTo(pi / 4, epsilon));
        expect(integrate((x) => exp(-x), 0, double.infinity, depth: 30),
            closeTo(1, epsilon));
      });
    });
    group('bounds', () {
      double f(double x) => exp(-x * x);
      double g(double x) => 1.0 / (x * x);
      test('empty', () {
        expect(integrate((x) => fail('No evaluation'), pi, pi),
            closeTo(0, epsilon));
      });
      test('inverted', () {
        expect(integrate(exp, 1, 0), closeTo(1 - e, epsilon));
      });
      test('unbounded', () {
        expect(integrate(f, double.negativeInfinity, double.infinity),
            closeTo(sqrt(pi), epsilon));
      });
      test('lower unbounded', () {
        expect(integrate(f, double.negativeInfinity, 0),
            closeTo(sqrt(pi) / 2.0, epsilon));
        expect(
            integrate(g, double.negativeInfinity, -1), closeTo(1.0, epsilon));
      });
      test('upper unbounded', () {
        expect(
            integrate(f, 0, double.infinity), closeTo(sqrt(pi) / 2.0, epsilon));
        expect(integrate(g, 1, double.infinity), closeTo(1.0, epsilon));
      });
      test('inverted unbounded', () {
        expect(integrate(f, double.infinity, double.negativeInfinity),
            closeTo(-sqrt(pi), epsilon));
      });
      test('inverted lower unbounded', () {
        expect(integrate(f, 0, double.negativeInfinity),
            closeTo(-sqrt(pi) / 2.0, epsilon));
        expect(
            integrate(g, -1, double.negativeInfinity), closeTo(-1.0, epsilon));
      });
      test('inverted upper unbounded', () {
        expect(integrate(f, double.infinity, 0),
            closeTo(-sqrt(pi) / 2.0, epsilon));
        expect(integrate(g, double.infinity, 1), closeTo(-1.0, epsilon));
      });
    });
    group('poles', () {
      double f(double x) => x.roundToDouble() == x && x.round().isEven
          ? throw ArgumentError('Pole was evaluated at $x.')
          : 1.0;
      test('at lower bound', () {
        expect(integrate(f, -1, 0, poles: [0]), closeTo(1, epsilon));
      });
      test('at upper bound', () {
        expect(integrate(f, 0, 1.5, poles: [0]), closeTo(1.5, epsilon));
      });
      test('at both bounds', () {
        expect(integrate(f, 0, 2, poles: [0, 2]), closeTo(2, epsilon));
      });
      test('at the center', () {
        expect(integrate(f, -1.5, 1.5, poles: [0]), closeTo(3, epsilon));
      });
      test('multiple poles', () {
        expect(integrate(f, -3, 3, poles: [0, 2, -2]), closeTo(6, epsilon));
      });
      test('irrelevant poles', () {
        expect(integrate(f, 0.5, 1.5, poles: [0, 2, -2]), closeTo(1, epsilon));
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
                .having((err) => err.x, 'x', closeTo(0.5, epsilon))));
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
                .having((err) => err.x, 'x', closeTo(0.25, epsilon))));
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
            closeTo(1.2912859970, epsilon));
        expect(integrate((x) => pow(x, x).toDouble(), 0, 1, depth: 15),
            closeTo(0.7834305107, epsilon));
      });
      test('pi', () {
        expect(
            integrate((x) => 1 / (1 + x * x), double.negativeInfinity,
                double.infinity),
            closeTo(pi, epsilon));
        expect(22 / 7 - integrate((x) => pow(x - x * x, 4) / (1 + x * x), 0, 1),
            closeTo(pi, epsilon));
      });
    });
  });
  group('solve', () {
    test('raising bracket', () {
      expect(solve(cos, 4, 6), closeTo(3 * pi / 2, epsilon));
    });
    test('descending bracket', () {
      expect(solve(sin, 2, 4), closeTo(pi, epsilon));
    });
    test('polynomial', () {
      double f(double x) => (x + 3) * (x - 1) * (x - 1);
      expect(solve(f, -4, 0), closeTo(-3, epsilon));
    });
  });
}
