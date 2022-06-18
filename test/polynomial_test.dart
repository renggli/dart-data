import 'dart:math';

import 'package:data/data.dart';
import 'package:more/collection.dart';
import 'package:test/test.dart';

import 'utils/assertions.dart';
import 'utils/config.dart';
import 'utils/matchers.dart';

final Matcher throwsDivisionByZero = throwsA(
    const TypeMatcher<UnsupportedError>().having(
        (exception) => exception.message,
        'message',
        startsWith('Division by zero')));

void polynomialTest(String name, PolynomialFormat format) {
  group(name, () {
    group('constructor', () {
      test('default', () {
        final polynomial = Polynomial(DataType.int32, format: format);
        expect(polynomial.dataType, DataType.int32);
        expect(polynomial.degree, -1);
        expect(polynomial.shape, [0]);
        expect(polynomial.storage, [polynomial]);
        for (var i = 0; i < 10; i++) {
          expect(polynomial[i], 0);
        }
      });
      test('default with degree', () {
        final polynomial =
            Polynomial(DataType.int32, desiredDegree: 4, format: format);
        expect(polynomial.dataType, DataType.int32);
        expect(polynomial.degree, -1);
        expect(polynomial.shape, [0]);
        expect(polynomial.storage, [polynomial]);
        for (var i = 0; i < 10; i++) {
          expect(polynomial[i], 0);
        }
      });
      test('generate', () {
        final polynomial = Polynomial.generate(DataType.int32, 7, (i) => i - 4);
        expect(polynomial.dataType, DataType.int32);
        expect(polynomial.degree, 7);
        expect(polynomial.shape, [8]);
        expect(polynomial.storage, [polynomial]);
        for (var i = 0; i <= polynomial.degree; i++) {
          expect(polynomial[i], i - 4);
        }
        expect(polynomial[8], 0);
        expect(() => polynomial[3] = 42, throwsUnsupportedError);
        final copy = polynomial.copy();
        expect(copy, same(polynomial));
      });
      test('generate with format', () {
        final polynomial = Polynomial.generate(DataType.int32, 7, (i) => i - 4,
            format: format);
        expect(polynomial.dataType, DataType.int32);
        expect(polynomial.degree, 7);
        expect(polynomial.shape, [8]);
        expect(polynomial.storage, [polynomial]);
        for (var i = 0; i <= polynomial.degree; i++) {
          expect(polynomial[i], i - 4);
        }
        expect(polynomial[8], 0);
        polynomial[3] = 42;
        expect(polynomial[3], 42);
      });
      group('fromRoots', () {
        test('empty', () {
          final actual =
              Polynomial.fromRoots(DataType.int32, <int>[], format: format);
          final expected =
              Polynomial.fromList(DataType.int32, <int>[], format: format);
          expect(actual.toString(), expected.toString());
        });
        test('linear', () {
          final actual =
              Polynomial.fromRoots(DataType.int32, [1], format: format);
          final expected =
              Polynomial.fromList(DataType.int32, [-1, 1], format: format);
          expect(actual.toString(), expected.toString());
        });
        test('cubic', () {
          final actual =
              Polynomial.fromRoots(DataType.int32, [1, -2], format: format);
          final expected =
              Polynomial.fromList(DataType.int32, [-2, 1, 1], format: format);
          expect(actual.toString(), expected.toString());
        });
        test('septic', () {
          final actual = Polynomial.fromRoots(
              DataType.int32, [8, -4, -7, 3, 1, 1, 0],
              format: format);
          final expected = Polynomial.fromList(
              DataType.int32, [0, 672, -1388, 691, 94, -68, -2, 1],
              format: format);
          expect(actual.toString(), expected.toString());
        });
      });
      group('lagrange', () {
        test('0 samples', () {
          final xs = <double>[];
          final ys = <double>[];
          expect(
              () => Polynomial.lagrange(
                    DataType.float,
                    xs: xs.toVector(),
                    ys: ys.toVector(),
                  ),
              throwsArgumentError);
        }, skip: !hasAssertions());
        test('1 sample: f(x) = 2', () {
          final xs = <double>[1].toVector();
          final ys = <double>[2].toVector();
          final actual = Polynomial.lagrange(DataType.float, xs: xs, ys: ys);
          expect(actual.toList(), isCloseTo([2]));
          verifySamples<double>(DataType.float, actual: actual, xs: xs, ys: ys);
          verifyFunction<double>(DataType.float,
              actual: actual,
              expected: (x) => 2,
              range: DoubleRange(0.0, 3.0, 0.1));
        });
        test('2 samples: f(x) = 4 * x - 7', () {
          final xs = <double>[2, 3].toVector();
          final ys = <double>[1, 5].toVector();
          final actual = Polynomial.lagrange(DataType.float, xs: xs, ys: ys);
          expect(actual.toList(), isCloseTo([-7, 4]));
          verifySamples<double>(DataType.float, actual: actual, xs: xs, ys: ys);
          verifyFunction<double>(DataType.float,
              actual: actual,
              expected: (x) => 4 * x - 7,
              range: DoubleRange(0.0, 4.0, 0.1));
        });
        test('3 samples: f(x) = 5/4 * x^2 - x + 1', () {
          final xs = <double>[0, 2, 4].toVector();
          final ys = <double>[1, 4, 17].toVector();
          final actual = Polynomial.lagrange(DataType.float, xs: xs, ys: ys);
          expect(actual.toList(), isCloseTo([1, -1, 5 / 4]));
          verifySamples<double>(DataType.float, actual: actual, xs: xs, ys: ys);
          verifyFunction<double>(DataType.float,
              actual: actual,
              expected: (x) => 5 / 4 * x * x - x + 1,
              range: DoubleRange(-1.0, 5.0, 0.1));
        });
      });
      test('fromList', () {
        final source = [-1, 0, 2];
        final polynomial =
            Polynomial.fromList(DataType.int32, source, format: format);
        expect(polynomial.dataType, DataType.int32);
        expect(polynomial.degree, 2);
        expect(polynomial.shape, [source.length]);
        expect(polynomial.storage, [polynomial]);
        expect(polynomial[0], -1);
        expect(polynomial[1], 0);
        expect(polynomial[2], 2);
        expect(polynomial[3], 0);
      });
    });
    group('accessing', () {
      for (final type in <DataType<num>>[DataType.int32, DataType.numeric]) {
        group(type.name, () {
          test('degree', () {
            final polynomial =
                Polynomial(type, format: format, desiredDegree: 5);
            expect(polynomial.degree, -1);
            polynomial[0] = 0;
            expect(polynomial.degree, -1);
            polynomial[5] = 1;
            expect(polynomial.degree, 5);
            polynomial[0] = 2;
            expect(polynomial.degree, 5);
            polynomial[5] = 0;
            expect(polynomial.degree, 0);
          });
          test('lead', () {
            final polynomial =
                Polynomial(type, format: format, desiredDegree: 5);
            expect(polynomial.lead, 0);
            polynomial[0] = 0;
            expect(polynomial.lead, 0);
            polynomial[5] = 1;
            expect(polynomial.lead, 1);
            polynomial[0] = 2;
            expect(polynomial.lead, 1);
            polynomial[5] = 0;
            expect(polynomial.lead, 2);
          });
          test('random', () {
            const degree = 100;
            final polynomial =
                Polynomial(type, format: format, desiredDegree: degree);
            final values = <int>[];
            for (var i = 0; i <= degree; i++) {
              values.add(i);
            }
            // add values
            values.shuffle();
            for (final value in values) {
              polynomial[value] = value;
            }
            for (var i = 0; i < values.length; i++) {
              expect(polynomial[i], i);
            }
            // update values
            values.shuffle();
            for (final value in values) {
              polynomial[value] = value + 1;
            }
            for (var i = 0; i < values.length; i++) {
              expect(polynomial[i], i + 1);
            }
            // remove values
            values.shuffle();
            for (final value in values) {
              polynomial[value] = polynomial.dataType.defaultValue;
            }
            for (var i = 0; i < values.length; i++) {
              expect(polynomial[i], polynomial.dataType.field.additiveIdentity);
            }
          });
          test('sparse value', () {
            final polynomial =
                Polynomial(type, format: format, desiredDegree: 2);
            polynomial[1] = 42;
            expect(polynomial.degree, 1);
            expect(polynomial.lead, 42);
            expect(polynomial[0], 0);
            expect(polynomial[1], 42);
            expect(polynomial[2], 0);
          });
          test('zero value', () {
            final polynomial =
                Polynomial(type, format: format, desiredDegree: 2);
            polynomial[1] = 42;
            polynomial[1] = 0;
            expect(polynomial.degree, -1);
            expect(polynomial.lead, 0);
            expect(polynomial[0], 0);
            expect(polynomial[1], 0);
            expect(polynomial[2], 0);
          });
          test('read range error', () {
            final polynomial = Polynomial(type, format: format);
            expect(() => polynomial[-1], throwsRangeError);
          });
          test('write range error', () {
            final polynomial = Polynomial(type, format: format);
            expect(() => polynomial[-1] = 1, throwsRangeError);
          });
          group('evaluating', () {
            test('empty', () {
              final polynomial = Polynomial(type, format: format);
              expect(polynomial(-1), 0);
              expect(polynomial(0), 0);
              expect(polynomial(1), 0);
              expect(polynomial(2), 0);
            });
            test('constant', () {
              final polynomial = Polynomial.fromList(
                  type, type.castList(<num>[2]),
                  format: format);
              expect(polynomial(-1), 2);
              expect(polynomial(0), 2);
              expect(polynomial(1), 2);
              expect(polynomial(2), 2);
            });
            test('linear', () {
              final polynomial = Polynomial.fromList(
                  type, type.castList(<num>[1, 2]),
                  format: format);
              expect(polynomial(-1), -1);
              expect(polynomial(0), 1);
              expect(polynomial(1), 3);
              expect(polynomial(2), 5);
            });
            test('square', () {
              final polynomial = Polynomial.fromList(
                  type, type.castList(<num>[2, 0, 3]),
                  format: format);
              expect(polynomial(-1), 5);
              expect(polynomial(0), 2);
              expect(polynomial(1), 5);
              expect(polynomial(2), 14);
            });
          });
        });
      }
      group('format', () {
        test('empty', () {
          final polynomial = Polynomial.fromCoefficients(DataType.int8, <int>[],
              format: format);
          expect(polynomial.format(), '0');
        });
        test('constant', () {
          final polynomial =
              Polynomial.fromCoefficients(DataType.int8, [1], format: format);
          expect(polynomial.format(), '1');
        });
        test('2th-degree', () {
          final polynomial = Polynomial.fromCoefficients(DataType.int8, [1, 2],
              format: format);
          expect(polynomial.format(), 'x + 2');
        });
        test('3rd-degree', () {
          final polynomial = Polynomial.fromCoefficients(
              DataType.int8, [1, 2, 3],
              format: format);
          expect(polynomial.format(), 'x^2 + 2x + 3');
        });
        test('null values (skipped)', () {
          final polynomial = Polynomial.fromCoefficients(
              DataType.int8, [2, 0, 0, 1],
              format: format);
          expect(polynomial.format(), '2x^3 + 1');
        });
        test('null values (not skipped)', () {
          final polynomial = Polynomial.fromCoefficients(
              DataType.int8, [2, 0, 1],
              format: format);
          expect(polynomial.format(skipNulls: false), '2x^2 + 0x + 1');
        });
        test('limit', () {
          final polynomial = Polynomial.generate(
              DataType.int8, 19, (i) => i - 10,
              format: format);
          expect(polynomial.format(),
              '9x^19 + 8x^18 + 7x^17 + … + -8x^2 + -9x + -10');
        });
      });
      test('toString', () {
        final polynomial = Polynomial.fromCoefficients(
            DataType.int32, [1, 2, 3],
            format: format);
        expect(
            polynomial.toString(),
            '${polynomial.runtimeType}'
            '(dataType: int32, degree: 2):\n'
            'x^2 + 2x + 3');
      });
    });
    group('roots', () {
      final epsilon = pow(2.0, -32.0).toDouble();
      test('empty', () {
        final polynomial =
            Polynomial.fromList(DataType.int32, <int>[], format: format);
        final solutions = polynomial.roots;
        expect(solutions, isEmpty);
      });
      test('constant', () {
        final polynomial =
            Polynomial.fromList(DataType.int32, [2], format: format);
        final solutions = polynomial.roots;
        expect(solutions, isEmpty);
      });
      test('linear', () {
        final polynomial =
            Polynomial.fromList(DataType.int32, [1, 2], format: format);
        final solutions = polynomial.roots;
        expect(solutions, hasLength(1));
        expect(solutions[0].closeTo(const Complex(-0.5), epsilon), isTrue);
      });
      test('square', () {
        final polynomial =
            Polynomial.fromList(DataType.int32, [2, 0, 3], format: format);
        final solutions = polynomial.roots;
        expect(solutions, hasLength(2));
        expect(solutions[0].closeTo(Complex(0, sqrt(2 / 3)), epsilon), isTrue);
        expect(solutions[1].closeTo(Complex(0, -sqrt(2 / 3)), epsilon), isTrue);
      });
      test('cubic', () {
        final polynomial =
            Polynomial.fromList(DataType.int32, [6, -5, -2, 1], format: format);
        final solutions = polynomial.roots;
        expect(solutions, hasLength(3));
        expect(solutions[0].closeTo(Complex.one, epsilon), isTrue);
        expect(solutions[1].closeTo(const Complex(3), epsilon), isTrue);
        expect(solutions[2].closeTo(const Complex(-2), epsilon), isTrue);
      });
      test('septic', () {
        final polynomial = Polynomial.fromList(
            DataType.int32, [5, -8, 7, -3, 0, -3, 5, -4],
            format: format);
        final solutions = polynomial.roots;
        expect(solutions, hasLength(7));
        expect(
            solutions[0]
                .closeTo(const Complex(-0.8850843987, 0.6981874373), epsilon),
            isTrue);
        expect(
            solutions[1]
                .closeTo(const Complex(-0.8850843987, -0.6981874373), epsilon),
            isTrue);
        expect(
            solutions[2]
                .closeTo(const Complex(0.2543482521, 0.9163091163), epsilon),
            isTrue);
        expect(
            solutions[3]
                .closeTo(const Complex(0.2543482521, -0.9163091163), epsilon),
            isTrue);
        expect(
            solutions[4]
                .closeTo(const Complex(0.9247965171, 0.0000000000), epsilon),
            isTrue);
        expect(
            solutions[5]
                .closeTo(const Complex(0.7933378880, 0.7394177680), epsilon),
            isTrue);
        expect(
            solutions[6]
                .closeTo(const Complex(0.7933378880, -0.7394177680), epsilon),
            isTrue);
      });
    });
    group('view', () {
      test('copy', () {
        final source = Polynomial.generate(DataType.int32, 7, (i) => i - 4,
            format: format);
        final copy = source.copy();
        expect(copy.dataType, source.dataType);
        expect(copy.degree, source.degree);
        expect(copy.storage, [copy]);
        for (var i = source.degree; i >= 0; i--) {
          source[i] = i.isEven ? 0 : -i;
          copy[i] = i.isEven ? -i : 0;
        }
        for (var i = source.degree; i >= 0; i--) {
          expect(source[i], i.isEven ? 0 : -i);
          expect(copy[i], i.isEven ? -i : 0);
        }
      });
      group('differentiate', () {
        const cs0 = [11, 7, 5, 2, 0];
        const cs1 = [7, 10, 6, 0, 0];
        test('read', () {
          final source =
              Polynomial.fromList(DataType.int32, cs0, format: format);
          final result = source.differentiate;
          expect(result.dataType, source.dataType);
          expect(result.storage, [source]);
          expect(result.degree, source.degree - 1);
          expect(result.copy().compare(result), isTrue);
          for (var i = 0; i < cs1.length; i++) {
            expect(source[i], cs0[i]);
            expect(result[i], cs1[i]);
          }
        });
        test('write', () {
          final source = Polynomial(DataType.int32,
              format: format, desiredDegree: cs1.length);
          final result = source.differentiate;
          expect(result.degree, -1);
          for (var i = 0; i < cs1.length; i++) {
            result[i] = cs1[i];
          }
          for (var i = 0; i < cs1.length; i++) {
            expect(source[i], i == 0 ? 0 : cs0[i]);
            expect(result[i], cs1[i]);
          }
        });
      });
      group('integrate', () {
        const cs0 = [7, 10, 6, 12, 0, 0];
        const cs1 = [0, 7, 5, 2, 3, 0];
        test('read', () {
          final source =
              Polynomial.fromList(DataType.int32, cs0, format: format);
          final result = source.integrate;
          expect(result.dataType, source.dataType);
          expect(result.storage, [source]);
          expect(result.degree, source.degree + 1);
          expect(result.copy().compare(result), isTrue);
          for (var i = 0; i < cs1.length; i++) {
            expect(source[i], cs0[i]);
            expect(result[i], cs1[i]);
          }
        });
        test('write', () {
          final source = Polynomial(DataType.int32,
              format: format, desiredDegree: cs1.length);
          final result = source.integrate;
          expect(result.degree, -1);
          for (var i = 0; i < cs1.length; i++) {
            result[i] = cs1[i];
          }
          for (var i = 0; i < cs1.length; i++) {
            expect(source[i], cs0[i]);
            expect(result[i], cs1[i]);
          }
        });
      });
      group('shift', () {
        for (var offset = -5; offset <= 5; offset++) {
          test('offset = $offset', () {
            final list = [1, 2, 3, 4];
            final source =
                Polynomial.fromList(DataType.int32, list, format: format);
            final actual = source.shift(offset);
            final expected = offset < 0
                ? list.sublist(min(-offset, list.length))
                : offset > 0
                    ? List<int>.generate(offset, (i) => 0) + list
                    : list;
            expect(actual.dataType, source.dataType);
            expect(actual.degree, max(source.degree + offset, -1));
            expect(actual.storage, {source});
            expect(actual.iterable, expected);
            expect(actual.copy().iterable, expected);
            expect(actual.shift(-offset), source);
            if (-3 <= offset && offset <= 0) {
              actual[0] = -1;
              expect(actual[0], -1);
            }
          });
          test('offset = $offset, empty', () {
            final list = <int>[];
            final source =
                Polynomial.fromList(DataType.int32, list, format: format);
            final actual = source.shift(offset);
            final expected = <int>[];
            expect(actual.dataType, source.dataType);
            expect(actual.degree, -1);
            expect(actual.storage, {source});
            expect(actual.iterable, expected);
            expect(actual.copy().iterable, expected);
            expect(actual.shift(-offset), source);
          });
        }
      });
      test('unmodifiable', () {
        final source = Polynomial.generate(DataType.int32, 7, (i) => i + 1,
            format: format);
        final readonly = source.unmodifiable;
        expect(readonly.dataType, source.dataType);
        expect(readonly.degree, 7);
        expect(readonly.storage, [source]);
        expect(readonly.unmodifiable, readonly);
        expect(readonly.copy().compare(readonly), isTrue);
        for (var i = readonly.degree; i >= 0; i--) {
          expect(readonly[i], i + 1);
          expect(() => readonly[i] = i, throwsUnsupportedError);
        }
        for (var i = source.degree; i >= 0; i--) {
          expect(source[i], i + 1);
          source[i] = -source[i];
        }
        for (var i = readonly.degree; i >= 0; i--) {
          expect(readonly[i], -i - 1);
        }
      });
      group('toPolynomial', () {
        test('view', () {
          final list = [0, 1, 2, 3, 0];
          final polynomial = list.toPolynomial();
          expect(polynomial.dataType, DataType.intDataType);
          expect(polynomial.degree, 3);
          expect(polynomial[0], 0);
          expect(polynomial[1], 1);
          expect(polynomial[2], 2);
          expect(polynomial[3], 3);
          expect(polynomial[4], 0);
          expect(polynomial[5], 0);
          list
            ..add(4)
            ..removeAt(0)
            ..removeAt(0);
          expect(polynomial.degree, 3);
          expect(polynomial[0], 2);
          expect(polynomial[1], 3);
          expect(polynomial[2], 0);
          expect(polynomial[3], 4);
          polynomial[1] = -4;
          expect(list, [2, -4, 0, 4]);
        });
        test('copy', () {
          final list = [0, 1, 2, 3, 0];
          final polynomial = list.toPolynomial(format: format);
          expect(polynomial.dataType, DataType.intDataType);
          expect(polynomial.degree, 3);
          expect(polynomial[0], 0);
          expect(polynomial[1], 1);
          expect(polynomial[2], 2);
          expect(polynomial[3], 3);
          expect(polynomial[4], 0);
          expect(polynomial[5], 0);
          list
            ..add(4)
            ..removeAt(0)
            ..removeAt(0);
          expect(polynomial.degree, 3);
          expect(polynomial[0], 0);
          expect(polynomial[1], 1);
          expect(polynomial[2], 2);
          expect(polynomial[3], 3);
          expect(polynomial[4], 0);
          expect(polynomial[5], 0);
          polynomial[1] = -4;
          expect(list, [2, 3, 0, 4]);
        });
      });
      group('toList', () {
        test('default', () {
          final polynomial = Polynomial.generate(
              DataType.int32, 5, (i) => 5 - i,
              format: format);
          final list = polynomial.toList();
          expect(list.length, polynomial.degree + 1);
          for (var i = 0; i < list.length; i++) {
            expect(list[i], 5 - i);
            list[i] = i;
            expect(polynomial[i], i);
          }
          expect(() => list.add(42), throwsUnsupportedError);
        });
        test('growable: true', () {
          final polynomial = Polynomial.generate(
              DataType.int32, 5, (i) => 5 - i,
              format: format);
          final list = polynomial.toList(growable: true);
          expect(list.length, polynomial.degree + 1);
          for (var i = 0; i < list.length; i++) {
            expect(list[i], 5 - i);
            list[i] = i;
            expect(polynomial[i], 5 - i);
          }
          list.add(42);
          expect(list, [0, 1, 2, 3, 4, 42]);
        });
        test('growable: false', () {
          final polynomial = Polynomial.generate(
              DataType.int32, 5, (i) => 5 - i,
              format: format);
          final list = polynomial.toList(growable: false);
          expect(list.length, polynomial.degree + 1);
          for (var i = 0; i < list.length; i++) {
            expect(list[i], 5 - i);
            list[i] = i;
            expect(polynomial[i], 5 - i);
          }
          expect(() => list.add(42), throwsUnsupportedError);
          expect(list, [0, 1, 2, 3, 4]);
        });
      });
    });
    group('iterables', () {
      test('basic', () {
        final source = Polynomial.generate(DataType.int32, 4, (i) => i - 2,
            format: format);
        final list = source.iterable;
        expect(list, [-2, -1, 0, 1, 2]);
        expect(list.length, source.degree + 1);
        expect(() => list.length = 0, throwsUnsupportedError);
        list[2] = 42;
        expect(list, [-2, -1, 42, 1, 2]);
        source[2] = 43;
        expect(list, [-2, -1, 43, 1, 2]);
      });
      group('forEach', () {
        test('default', () {
          final source = Polynomial(DataType.int32, format: format);
          source.forEach((index, value) => fail('Should not be called'));
        });
        test('complete', () {
          final exponents = <int>[];
          final coefficients = <int, double>{};
          final random = Random(7834354);
          final source = Polynomial.generate(DataType.float64, 13, (index) {
            final value = random.nextDouble();
            coefficients[index] = value;
            exponents.insert(0, index);
            return value;
          }, format: format);
          source.forEach((index, value) {
            expect(exponents.removeLast(), index);
            expect(coefficients[index], value);
          });
          expect(exponents, isEmpty);
        });
        test('sparse', () {
          final exponents = <int>[];
          final coefficients = <int, double>{};
          final random = Random(5123562);
          final source = Polynomial.generate(DataType.float64, 63, (index) {
            if (random.nextDouble() < 0.2) {
              final value = random.nextDouble();
              coefficients[index] = value;
              exponents.insert(0, index);
              return value;
            } else {
              return DataType.float64.field.additiveIdentity;
            }
          }, format: format);
          source.forEach((index, value) {
            expect(exponents.removeLast(), index);
            expect(coefficients[index], value);
          });
          expect(exponents, isEmpty);
        });
      });
    });
    group('operators', () {
      final random = Random(997984835);
      final sourceA = Polynomial.generate(
          DataType.int32, 100, (i) => 1 + random.nextInt(99),
          format: format);
      final sourceB = Polynomial.generate(
          DataType.int32, 100, (i) => 1 + random.nextInt(99),
          format: format);
      group('add', () {
        test('default', () {
          final result = sourceA.add(sourceB);
          expect(result.dataType, sourceA.dataType);
          expect(result.degree, sourceA.degree);
          for (var i = 0; i <= result.degree; i++) {
            expect(result[i], sourceA[i] + sourceB[i]);
          }
        });
        test('operator', () {
          final result = sourceA + sourceB;
          expect(result.dataType, sourceA.dataType);
          expect(result.degree, sourceA.degree);
          for (var i = 0; i <= result.degree; i++) {
            expect(result[i], sourceA[i] + sourceB[i]);
          }
        });
        test('different degree', () {
          final sourceB =
              Polynomial.fromList(DataType.int32, [1, 2], format: format);
          final result = sourceA.add(sourceB);
          expect(result.dataType, sourceA.dataType);
          expect(result.degree, sourceA.degree);
          for (var i = 0; i <= result.degree; i++) {
            expect(result[i], sourceA[i] + sourceB[i]);
          }
        });
        test('target', () {
          final result =
              sourceA.add(sourceB, dataType: DataType.uint8, format: format);
          expect(result.dataType, DataType.uint8);
          expect(result.degree, sourceA.degree);
          for (var i = 0; i <= result.degree; i++) {
            expect(result[i], sourceA[i] + sourceB[i]);
          }
        });
      });
      group('sub', () {
        test('default', () {
          final target = sourceA.sub(sourceB);
          expect(target.dataType, sourceA.dataType);
          expect(target.degree, sourceA.degree);
          for (var i = 0; i <= target.degree; i++) {
            expect(target[i], sourceA[i] - sourceB[i]);
          }
        });
        test('operator', () {
          final target = sourceA - sourceB;
          expect(target.dataType, sourceA.dataType);
          expect(target.degree, sourceA.degree);
          for (var i = 0; i <= target.degree; i++) {
            expect(target[i], sourceA[i] - sourceB[i]);
          }
        });
      });
      group('neg', () {
        test('default', () {
          final target = sourceA.neg();
          expect(target.dataType, sourceA.dataType);
          expect(target.degree, sourceA.degree);
          for (var i = 0; i <= target.degree; i++) {
            expect(target[i], -sourceA[i]);
          }
        });
        test('operator', () {
          final target = -sourceA;
          expect(target.dataType, sourceA.dataType);
          expect(target.degree, sourceA.degree);
          for (var i = 0; i <= target.degree; i++) {
            expect(target[i], -sourceA[i]);
          }
        });
      });
      group('lerp', () {
        final v0 = Polynomial<double>.fromList(DataType.float32, [1, 6, 8],
            format: format);
        final v1 = Polynomial<double>.fromList(DataType.float32, [9, -2, 8],
            format: format);
        test('at start', () {
          final p = v0.lerp(v1, 0.0);
          expect(p.dataType, v1.dataType);
          expect(p.degree, v1.degree);
          expect(p[0], v0[0]);
          expect(p[1], v0[1]);
          expect(p[2], v0[2]);
        });
        test('at middle', () {
          final p = v0.lerp(v1, 0.5);
          expect(p.dataType, v1.dataType);
          expect(p.degree, v1.degree);
          expect(p[0], 5.0);
          expect(p[1], 2.0);
          expect(p[2], 8.0);
        });
        test('at end', () {
          final p = v0.lerp(v1, 1.0);
          expect(p.dataType, v1.dataType);
          expect(p.degree, v1.degree);
          expect(p[0], v1[0]);
          expect(p[1], v1[1]);
          expect(p[2], v1[2]);
        });
        test('at outside', () {
          final p = v0.lerp(v1, 2.0);
          expect(p.dataType, v1.dataType);
          expect(p.degree, v1.degree);
          expect(p[0], 17.0);
          expect(p[1], -10.0);
          expect(p[2], 8.0);
        });
        test('different degree', () {
          final v3 = Polynomial<double>.fromList(DataType.float32, [9, -2],
              format: format);
          final p = v0.lerp(v3, 0.5);
          expect(p.dataType, v0.dataType);
          expect(p.degree, v0.degree);
          expect(p[0], 5.0);
          expect(p[1], 2.0);
          expect(p[2], 4.0);
        });
      });
      group('mul', () {
        final sourceA =
            Polynomial.fromList(DataType.int32, [2, 3, 4], format: format);
        final sourceB =
            Polynomial.fromList(DataType.int32, [-2, 4, 9, -3], format: format);
        test('default', () {
          final expected = Polynomial.fromList(
              DataType.int32, [-4, 2, 22, 37, 27, -12],
              format: format);
          final first = sourceA.mul(sourceB);
          expect(first.dataType, DataType.int32);
          expect(first.degree, 5);
          expect(first.compare(expected), isTrue);
          final second = sourceB.mul(sourceA);
          expect(second.dataType, DataType.int32);
          expect(second.degree, 5);
          expect(second.compare(expected), isTrue);
        });
        test('operator', () {
          final expected = Polynomial.fromList(
              DataType.int32, [-4, 2, 22, 37, 27, -12],
              format: format);
          final first = sourceA * sourceB;
          expect(first.dataType, DataType.int32);
          expect(first.degree, 5);
          expect(first.compare(expected), isTrue);
          final second = sourceB * sourceA;
          expect(second.dataType, DataType.int32);
          expect(second.degree, 5);
          expect(second.compare(expected), isTrue);
        });
        test('zero', () {
          final zero = Polynomial(DataType.int32, format: format);
          final first = sourceA.mul(zero);
          expect(first.compare(zero), isTrue);
          final second = zero.mul(sourceA);
          expect(second.compare(zero), isTrue);
        });
        test('constant', () {
          final constant =
              Polynomial.fromList(DataType.int32, [3], format: format);
          final first = sourceA.mul(constant);
          expect(first.compare(sourceA.mul(3)), isTrue);
          final second = constant.mul(sourceA);
          expect(second.compare(sourceA.mul(3)), isTrue);
        });
        test('scale', () {
          final target = sourceA.mul(2);
          expect(target.dataType, sourceA.dataType);
          expect(target.degree, sourceA.degree);
          for (var i = 0; i < target.degree; i++) {
            expect(target[i], 2 * sourceA[i]);
          }
        });
      });
      group('div', () {
        PolynomialDivision<T> divWithInvariant<T>(
            Polynomial<T> dividend, Polynomial<T> divisor) {
          final result = dividend / divisor;
          final reverse = result.quotient * divisor + result.remainder;
          expect(dividend.iterable, reverse.iterable);
          expect(result.quotient.dataType, dividend.dataType);
          expect(result.remainder.dataType, dividend.dataType);
          final quotient = dividend ~/ divisor;
          expect(quotient.iterable, result.quotient.iterable);
          final remainder = dividend % divisor;
          expect(remainder.iterable, result.remainder.iterable);
          return result;
        }

        test('zero divisor', () {
          final dividend = Polynomial.fromList(DataType.int32, [-42, 0, -12, 1],
              format: format);
          final divisor = Polynomial(DataType.int32, format: format);
          expect(() => dividend.div(divisor), throwsDivisionByZero);
        });
        test('zero dividend', () {
          final dividend = Polynomial(DataType.int32, format: format);
          final divisor = Polynomial.fromList(DataType.int32, [-42, 0, -12, 1],
              format: format);
          final result = divWithInvariant(dividend, divisor);
          expect(result.quotient.iterable, <int>[]);
          expect(result.remainder.iterable, <int>[]);
        });
        test('constant divisor', () {
          final dividend = Polynomial.fromList(DataType.int32, [-42, 0, -12, 2],
              format: format);
          final divisor =
              Polynomial.fromList(DataType.int32, [-2], format: format);
          final result = divWithInvariant(dividend, divisor);
          expect(result.quotient.iterable, [21, 0, 6, -1]);
          expect(result.remainder.iterable, <int>[]);
        });
        test('large divisor', () {
          final dividend =
              Polynomial.fromList(DataType.int32, [-3, 5, 1], format: format);
          final divisor = Polynomial.fromList(DataType.int32, [-42, 0, -12, 1],
              format: format);
          final result = divWithInvariant(dividend, divisor);
          expect(result.quotient.iterable, <int>[]);
          expect(result.remainder.iterable, [-3, 5, 1]);
        });
        test('example.dart 1', () {
          final dividend = Polynomial.fromList(DataType.int32, [-42, 0, -12, 1],
              format: format);
          final divisor =
              Polynomial.fromList(DataType.int32, [-3, 1], format: format);
          final result = divWithInvariant(dividend, divisor);
          expect(result.quotient.iterable, [-27, -9, 1]);
          expect(result.remainder.iterable, [-123]);
        });
        test('example.dart 2', () {
          final dividend = Polynomial.fromList(DataType.int32, [-2, 0, 0, 0, 1],
              format: format);
          final divisor =
              Polynomial.fromList(DataType.int32, [1, 1, 1, 1], format: format);
          final result = divWithInvariant(dividend, divisor);
          expect(result.quotient.iterable, [-1, 1]);
          expect(result.remainder.iterable, [-1]);
        }, skip: 'fractional polygon cannot be represented in <int>');
        test('example.dart 3', () {
          final dividend = Polynomial.fromList(DataType.int32, [-7, 0, 5, 6],
              format: format);
          final divisor =
              Polynomial.fromList(DataType.int32, [-1, -2, 3], format: format);
          final result = divWithInvariant(dividend, divisor);
          expect(result.quotient.iterable, [3, 2]);
          expect(result.remainder.iterable, [-4, 8]);
        }, skip: 'fractional polygon cannot be represented in <int>');
      });
      group('compare', () {
        test('identity', () {
          expect(sourceA.compare(sourceA), isTrue);
          expect(sourceB.compare(sourceB), isTrue);
          expect(sourceA.compare(sourceB), isFalse);
          expect(sourceB.compare(sourceA), isFalse);
        });
        test('custom', () {
          final negated = sourceA.neg();
          expect(sourceA.compare(negated), isFalse);
          expect(sourceA.compare(negated, equals: (a, b) => a == -b), isTrue);
        });
      });
    });
  });
}

void main() {
  polynomialTest('standard', PolynomialFormat.standard);
  polynomialTest('compressed', PolynomialFormat.compressed);
  polynomialTest('keyed', PolynomialFormat.keyed);
  polynomialTest('list', PolynomialFormat.list);
}
