library data.test.polynomial;

import 'dart:math';

import 'package:data/polynomial.dart';
import 'package:data/type.dart';
import 'package:data/vector.dart' as vector;
import 'package:test/test.dart';

void polynomialTest(String name, Builder builder) {
  group(name, () {
    group('builder', () {
      test('call', () {
        final polynomial = builder.withType(DataType.int8)();
        expect(polynomial.dataType, DataType.int8);
        expect(polynomial.degree, -1);
        expect(polynomial.count, greaterThan(polynomial.degree));
        expect(polynomial.shape, [polynomial.degree]);
        expect(polynomial.storage, [polynomial]);
        for (var i = 0; i < 10; i++) {
          expect(polynomial[i], 0);
        }
      });
      test('call (with degree)', () {
        final polynomial = builder.withType(DataType.int8)(4);
        expect(polynomial.dataType, DataType.int8);
        expect(polynomial.degree, -1);
        expect(polynomial.count, greaterThan(polynomial.degree));
        expect(polynomial.shape, [polynomial.degree]);
        expect(polynomial.storage, [polynomial]);
        for (var i = 0; i < 10; i++) {
          expect(polynomial[i], 0);
        }
      });
      test('call, error', () {
        expect(() => builder(-2), throwsRangeError);
        expect(() => builder.withType(null)(4), throwsArgumentError);
        expect(() => builder.withFormat(null)(4), throwsArgumentError);
      });
//      test('constant', () {
//        final polynomial = builder.withType(DataType.int8).constant(5, 123);
//        expect(polynomial.dataType, DataType.int8);
//        expect(polynomial.count, 5);
//        expect(polynomial.shape, [polynomial.count]);
//        expect(polynomial.storage, [polynomial]);
//        expect(polynomial.copy(), polynomial);
//        for (var i = 0; i < polynomial.count; i++) {
//          expect(polynomial[i], 123);
//        }
//        expect(() => polynomial[3] = 1, throwsUnsupportedError);
//      });
//      test('constant, mutable', () {
//        final polynomial =
//            builder.withType(DataType.int8).constant(5, 123, mutable: true);
//        expect(polynomial.dataType, DataType.int8);
//        expect(polynomial.count, 5);
//        expect(polynomial.shape, [polynomial.count]);
//        expect(polynomial.storage, [polynomial]);
//        for (var i = 0; i < polynomial.count; i++) {
//          expect(polynomial[i], 123);
//        }
//        polynomial[3] = 1;
//        expect(polynomial[3], 1);
//      });
      test('generate', () {
        final polynomial =
            builder.withType(DataType.int16).generate(7, (i) => i - 4);
        expect(polynomial.dataType, DataType.int16);
        expect(polynomial.degree, 7);
        expect(polynomial.count, greaterThan(polynomial.degree));
        expect(polynomial.shape, [polynomial.degree]);
        expect(polynomial.storage, [polynomial]);
        for (var i = 0; i <= polynomial.degree; i++) {
          expect(polynomial[i], i - 4);
        }
        expect(polynomial[8], 0);
        polynomial[3] = 42;
        expect(polynomial[3], 42);
      });
      test('generate, lazy', () {
        final polynomial = builder
            .withType(DataType.int16)
            .generate(7, (i) => i - 4, lazy: true);
        expect(polynomial.dataType, DataType.int16);
        expect(polynomial.degree, 7);
        expect(polynomial.count, greaterThan(polynomial.degree));
        expect(polynomial.shape, [polynomial.degree]);
        for (var i = 0; i <= polynomial.degree; i++) {
          expect(polynomial[i], i - 4);
        }
        expect(polynomial[8], 0);
        expect(() => polynomial[3] = 42, throwsUnsupportedError);
        final copy = polynomial.copy();
        expect(copy, same(polynomial));
      });
      test('fromPolynomial', () {
        final source =
            builder.withType(DataType.int8).generate(5, (i) => i - 2);
        final polynomial =
            builder.withType(DataType.int8).fromPolynomial(source);
        expect(polynomial.dataType, DataType.int8);
        expect(polynomial.degree, 5);
        expect(polynomial.count, greaterThan(polynomial.degree));
        expect(polynomial.shape, [polynomial.degree]);
        expect(polynomial.storage, [polynomial]);
        for (var i = 0; i <= polynomial.degree; i++) {
          expect(polynomial[i], i - 2);
        }
      });
      test('fromVector', () {
        final source =
            vector.Vector.builder.withType(DataType.int8).fromList([-1, 0, 2]);
        final polynomial = builder.withType(DataType.int8).fromVector(source);
        expect(polynomial.dataType, DataType.int8);
        expect(polynomial.degree, 2);
        expect(polynomial.count, greaterThan(polynomial.degree));
        expect(polynomial.shape, [polynomial.degree]);
        expect(polynomial.storage, [polynomial]);
        expect(polynomial[0], -1);
        expect(polynomial[1], 0);
        expect(polynomial[2], 2);
        expect(polynomial[3], 0);
      });
      test('fromList', () {
        final source = [-1, 0, 2];
        final polynomial = builder.withType(DataType.int8).fromList(source);
        expect(polynomial.dataType, DataType.int8);
        expect(polynomial.degree, 2);
        expect(polynomial.count, greaterThan(polynomial.degree));
        expect(polynomial.shape, [polynomial.degree]);
        expect(polynomial.storage, [polynomial]);
        expect(polynomial[0], -1);
        expect(polynomial[1], 0);
        expect(polynomial[2], 2);
        expect(polynomial[3], 0);
      });
    });
    group('accesssing', () {
      test('random', () {
        const degree = 100;
        final polynomial = builder(degree);
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
          polynomial[value] = polynomial.dataType.nullValue;
        }
        for (var i = 0; i < values.length; i++) {
          expect(polynomial[i], polynomial.dataType.nullValue);
        }
      });
      test('read (range error)', () {
        final polynomial = builder.withType(DataType.int8).fromList([1, 2]);
        expect(() => polynomial[-1], throwsRangeError);
        expect(polynomial[2], 0);
      });
      test('write (range error)', () {
        final polynomial = builder.withType(DataType.int8).fromList([1, 2]);
        expect(() => polynomial[-1] = 1, throwsRangeError);
        polynomial[2] = 3;
      });
    });
    group('view', () {
      test('differentiate', () {
        final source =
            builder.withType(DataType.int16).fromCoefficients([2, 5, 7, 11]);
        final result = source.differentiate;
        expect(result.dataType, source.dataType);
        expect(result.storage, [source]);
        expect(result.degree, source.degree - 1);
        expect(result[0], 7);
        expect(result[1], 10);
        expect(result[2], 6);
        expect(result[3], 0);
      });
      test('integrate', () {
        final source =
            builder.withType(DataType.int16).fromCoefficients([12, 6, 10, 7]);
        final result = source.integrate;
        expect(result.dataType, source.dataType);
        expect(result.storage, [source]);
        expect(result.degree, source.degree + 1);
        expect(result[0], 0);
        expect(result[1], 7);
        expect(result[2], 5);
        expect(result[3], 2);
        expect(result[4], 3);
        expect(result[5], 0);
      });
      test('copy', () {
        final source = builder.generate(7, (i) => i - 4);
        final copy = source.copy();
        expect(copy.dataType, source.dataType);
        expect(copy.degree, source.degree);
        expect(copy.count, source.count);
        expect(copy.storage, [copy]);
        for (var i = 0; i <= source.degree; i++) {
          source[i] = i.isEven ? 0 : -i;
          copy[i] = i.isEven ? -i : 0;
        }
        for (var i = 0; i <= source.degree; i++) {
          expect(source[i], i.isEven ? 0 : -i);
          expect(copy[i], i.isEven ? -i : 0);
        }
      });
      group('format', () {
        test('empty', () {
          final polynomial =
              builder.withType(DataType.int8).fromCoefficients([]);
          expect(polynomial.format(), '0');
        });
        test('constant', () {
          final polynomial =
              builder.withType(DataType.int8).fromCoefficients([1]);
          expect(polynomial.format(), '1');
        });
        test('2th-degree', () {
          final polynomial =
              builder.withType(DataType.int8).fromCoefficients([1, 2]);
          expect(polynomial.format(), 'x + 2');
        });
        test('3rd-degree', () {
          final polynomial =
              builder.withType(DataType.int8).fromCoefficients([1, 2, 3]);
          expect(polynomial.format(), 'x^2 + 2 x + 3');
        });
        test('null values (skipped)', () {
          final polynomial =
              builder.withType(DataType.int8).fromCoefficients([2, 0, 0, 1]);
          expect(polynomial.format(), '2 x^3 + 1');
        });
        test('null values (not skipped)', () {
          final polynomial =
              builder.withType(DataType.int8).fromCoefficients([2, 0, 1]);
          expect(polynomial.format(skipNulls: false), '2 x^2 + 0 x + 1');
        });
        test('limit', () {
          final polynomial =
              builder.withType(DataType.int8).generate(19, (i) => i - 10);
          expect(polynomial.format(),
              '9 x^19 + 8 x^18 + 7 x^17 + … + -8 x^2 + -9 x + -10');
        });
      });
      test('toString', () {
        final polynomial =
            builder.withType(DataType.int8).fromCoefficients([1, 2, 3]);
        expect(
            polynomial.toString(),
            '${polynomial.runtimeType}'
            '[2, ${polynomial.dataType.name}]:\n'
            'x^2 + 2 x + 3');
      });
    });
    group('iterables', () {
      test('basic', () {
        final source =
            builder.withType(DataType.int16).generate(4, (i) => i - 2);
        final list = source.iterable;
        expect(list, [-2, -1, 0, 1, 2]);
        expect(list.length, source.degree + 1);
        expect(() => list.length = 0, throwsUnsupportedError);
        list[2] = 42;
        expect(list, [-2, -1, 42, 1, 2]);
        source[2] = 43;
        expect(list, [-2, -1, 43, 1, 2]);
      });
    });
    group('operators', () {
      final random = Random();
      final sourceA = builder
          .withType(DataType.int32)
          .generate(100, (i) => random.nextInt(100));
      final sourceB = builder
          .withType(DataType.int32)
          .generate(100, (i) => random.nextInt(100));
      test('unary', () {
        final result = unaryOperator(sourceA, (a) => a * a);
        expect(result.dataType, sourceA.dataType);
        expect(result.degree, sourceA.degree);
        for (var i = 0; i <= result.degree; i++) {
          final a = sourceA[i];
          expect(result[i], a * a);
        }
      });
      test('binary', () {
        final result =
            binaryOperator(sourceA, sourceB, (a, b) => a * a + b * b);
        expect(result.dataType, sourceA.dataType);
        expect(result.degree, sourceA.degree);
        for (var i = 0; i <= result.degree; i++) {
          final a = sourceA[i];
          final b = sourceB[i];
          expect(result[i], a * a + b * b);
        }
      });
      group('add', () {
        test('default', () {
          final result = add(sourceA, sourceB);
          expect(result.dataType, sourceA.dataType);
          expect(result.degree, sourceA.degree);
          for (var i = 0; i <= result.degree; i++) {
            expect(result[i], sourceA[i] + sourceB[i]);
          }
        });
        test('default, different degree', () {
          final sourceB = builder.withType(DataType.int8).fromList([1, 2]);
          final result = add(sourceA, sourceB);
          expect(result.dataType, sourceA.dataType);
          expect(result.degree, sourceA.degree);
          for (var i = 0; i <= result.degree; i++) {
            expect(result[i], sourceA[i] + sourceB[i]);
          }
        });
        test('target', () {
          final target = builder.withType(DataType.int16)(sourceA.degree);
          final result = add(sourceA, sourceB, target: target);
          expect(target.dataType, DataType.int16);
          expect(target.degree, sourceA.degree);
          for (var i = 0; i <= target.degree; i++) {
            expect(target[i], sourceA[i] + sourceB[i]);
          }
          expect(result, target);
        });
        test('target, different degree', () {
          final target = builder.withType(DataType.int16)(2);
          final result = add(sourceA, sourceB, target: target);
          expect(target.dataType, DataType.int16);
          expect(target.degree, sourceA.degree);
          for (var i = 0; i <= target.degree; i++) {
            expect(target[i], sourceA[i] + sourceB[i]);
          }
          expect(result, target);
        });
        test('builder', () {
          final result =
              add(sourceA, sourceB, builder: builder.withType(DataType.int16));
          expect(result.dataType, DataType.int16);
          expect(result.degree, sourceA.degree);
          for (var i = 0; i <= result.degree; i++) {
            expect(result[i], sourceA[i] + sourceB[i]);
          }
        });
      });
      test('sub', () {
        final target = sub(sourceA, sourceB);
        expect(target.dataType, sourceA.dataType);
        expect(target.degree, sourceA.degree);
        for (var i = 0; i <= target.degree; i++) {
          expect(target[i], sourceA[i] - sourceB[i]);
        }
      });
      test('neg', () {
        final target = neg(sourceA);
        expect(target.dataType, sourceA.dataType);
        expect(target.degree, sourceA.degree);
        for (var i = 0; i <= target.degree; i++) {
          expect(target[i], -sourceA[i]);
        }
      });
      test('scale', () {
        final target = scale(sourceA, 2);
        expect(target.dataType, sourceA.dataType);
        expect(target.degree, sourceA.degree);
        for (var i = 0; i < target.degree; i++) {
          expect(target[i], 2 * sourceA[i]);
        }
      });
      group('lerp', () {
        final v0 = builder.withType(DataType.float32).fromList([1, 6, 8]);
        final v1 = builder.withType(DataType.float32).fromList([9, -2, 8]);
        test('at start', () {
          final p = lerp(v0, v1, 0.0);
          expect(p.dataType, v1.dataType);
          expect(p.degree, v1.degree);
          expect(p[0], v0[0]);
          expect(p[1], v0[1]);
          expect(p[2], v0[2]);
        });
        test('at middle', () {
          final p = lerp(v0, v1, 0.5);
          expect(p.dataType, v1.dataType);
          expect(p.degree, v1.degree);
          expect(p[0], 5.0);
          expect(p[1], 2.0);
          expect(p[2], 8.0);
        });
        test('at end', () {
          final p = lerp(v0, v1, 1.0);
          expect(p.dataType, v1.dataType);
          expect(p.degree, v1.degree);
          expect(p[0], v1[0]);
          expect(p[1], v1[1]);
          expect(p[2], v1[2]);
        });
        test('at outside', () {
          final p = lerp(v0, v1, 2.0);
          expect(p.dataType, v1.dataType);
          expect(p.degree, v1.degree);
          expect(p[0], 17.0);
          expect(p[1], -10.0);
          expect(p[2], 8.0);
        });
        test('different degree', () {
          final v3 = builder.withType(DataType.float32).fromList([9, -2]);
          final p = lerp(v0, v3, 0.5);
          expect(p.dataType, v0.dataType);
          expect(p.degree, v0.degree);
          expect(p[0], 5.0);
          expect(p[1], 2.0);
          expect(p[2], 4.0);
        });
      });
      group('compare', () {
        test('identity', () {
          expect(compare(sourceA, sourceA), isTrue);
          expect(compare(sourceB, sourceB), isTrue);
          expect(compare(sourceA, sourceB), isFalse);
          expect(compare(sourceB, sourceA), isFalse);
        });
        test('custom', () {
          final negated = neg(sourceA);
          expect(compare(sourceA, negated), isFalse);
          expect(compare(sourceA, negated, equals: (a, b) => a == -b), isTrue);
        });
      });
    });
  });
}

void main() {
  polynomialTest('standard', Polynomial.builder.standard);
  polynomialTest('keyed', Polynomial.builder.keyed);
  polynomialTest('list', Polynomial.builder.list);
}
