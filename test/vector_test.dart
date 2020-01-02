library data.test.vector;

import 'dart:math';

import 'package:data/matrix.dart' as matrix;
import 'package:data/type.dart';
import 'package:data/vector.dart';
import 'package:test/test.dart';

void vectorTest(String name, VectorFormat format) {
  group(name, () {
    group('constructor', () {
      test('default', () {
        final vector = Vector(DataType.int8, 4, format: format);
        expect(vector.dataType, DataType.int8);
        expect(vector.count, 4);
        expect(vector.shape, [vector.count]);
        expect(vector.storage, [vector]);
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], 0);
        }
      });
      test('default with error', () {
        expect(() => Vector(null, 5, format: format), throwsArgumentError);
        expect(
            () => Vector(DataType.int8, -4, format: format), throwsRangeError);
      });
      test('constant', () {
        final vector = Vector.constant(DataType.int8, 5);
        expect(vector.dataType, DataType.int8);
        expect(vector.count, 5);
        expect(vector.shape, [vector.count]);
        expect(vector.storage, [vector]);
        expect(vector.copy(), vector);
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], 0);
        }
        expect(() => vector[3] = 1, throwsUnsupportedError);
      });
      test('constant with value', () {
        final vector = Vector.constant(DataType.int8, 5, value: 1);
        expect(vector.dataType, DataType.int8);
        expect(vector.count, 5);
        expect(vector.shape, [vector.count]);
        expect(vector.storage, [vector]);
        expect(vector.copy(), vector);
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], 1);
        }
        expect(() => vector[3] = 1, throwsUnsupportedError);
      });
      test('constant with format', () {
        final vector = Vector.constant(DataType.int8, 5, format: format);
        expect(vector.dataType, DataType.int8);
        expect(vector.count, 5);
        expect(vector.shape, [vector.count]);
        expect(vector.storage, [vector]);
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], 0);
        }
        vector[3] = 1;
        expect(vector[3], 1);
      });
      test('generate', () {
        final vector = Vector.generate(DataType.string, 7, (i) => '$i');
        expect(vector.dataType, DataType.string);
        expect(vector.count, 7);
        expect(vector.shape, [vector.count]);
        expect(vector.storage, [vector]);
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], '$i');
        }
        expect(() => vector[3] = '*', throwsUnsupportedError);
      });
      test('generate with format', () {
        final vector =
            Vector.generate(DataType.string, 7, (i) => '$i', format: format);
        expect(vector.dataType, DataType.string);
        expect(vector.count, 7);
        expect(vector.shape, [vector.count]);
        expect(vector.storage, [vector]);
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], '$i');
        }
        vector[3] = '*';
        expect(vector[3], '*');
      });
      test('fromList', () {
        final vector =
            Vector.fromList(DataType.int8, [2, 1, 3], format: format);
        expect(vector.dataType, DataType.int8);
        expect(vector.count, 3);
        expect(vector.shape, [vector.count]);
        expect(vector.storage, [vector]);
        expect(vector[0], 2);
        expect(vector[1], 1);
        expect(vector[2], 3);
      });
    });
    group('accesssing', () {
      final vector = Vector.fromList(DataType.int8, [2, 4, 6], format: format);
      test('random', () {
        final vector = Vector(DataType.int8, 100, format: format);
        final values = <int>[];
        for (var i = 0; i < vector.count; i++) {
          values.add(i);
        }
        // add values
        values.shuffle();
        for (final value in values) {
          vector[value] = value;
        }
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], i);
        }
        // update values
        values.shuffle();
        for (final value in values) {
          vector[value] = value + 1;
        }
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], i + 1);
        }
        // remove values
        values.shuffle();
        for (final value in values) {
          vector[value] = vector.dataType.nullValue;
        }
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], vector.dataType.nullValue);
        }
      });
      test('read operator', () {
        expect(vector[0], 2);
        expect(vector[1], 4);
        expect(vector[2], 6);
      });
      test('write operator', () {
        final copy = Vector(vector.dataType, vector.count, format: format);
        for (var i = 0; i < vector.count; i++) {
          copy[i] = vector[i];
        }
        expect(compare(copy, vector), isTrue);
      });
      test('read with range error', () {
        final vector = Vector.fromList(DataType.int8, [1, 2], format: format);
        expect(() => vector[-1], throwsRangeError);
        expect(() => vector[vector.count], throwsRangeError);
      });
      test('write with range error', () {
        final vector = Vector.fromList(DataType.int8, [1, 2], format: format);
        expect(() => vector[-1] = 1, throwsRangeError);
        expect(() => vector[vector.count] = 1, throwsRangeError);
      });
      test('format', () {
        final vector =
            Vector.generate(DataType.int8, 100, (i) => i, format: format);
        expect(vector.format(), '0 1 2 … 97 98 99');
      });
      test('toString', () {
        final vector =
            Vector.fromList(DataType.int8, [3, 2, 1], format: format);
        expect(
            vector.toString(),
            '${vector.runtimeType}'
            '(dataType: int8, count: 3):\n'
            '3 2 1');
      });
    });
    group('view', () {
      test('copy', () {
        final source =
            Vector.generate(DataType.int32, 30, (i) => i, format: format);
        final copy = source.copy();
        expect(copy.dataType, source.dataType);
        expect(copy.count, source.count);
        expect(copy.storage, [copy]);
        for (var i = 0; i < source.count; i++) {
          source[i] = i.isEven ? 0 : -i;
          copy[i] = i.isEven ? -i : 0;
        }
        for (var i = 0; i < source.count; i++) {
          expect(source[i], i.isEven ? 0 : -i);
          expect(copy[i], i.isEven ? -i : 0);
        }
      });
      group('range', () {
        test('default', () {
          final source =
              Vector.generate(DataType.string, 6, (i) => '$i', format: format);
          final range = source.range(1, 4);
          expect(range.dataType, DataType.string);
          expect(range.count, 3);
          expect(range.storage, [source]);
          expect(compare(range.copy(), range), isTrue);
          expect(range[0], '1');
          expect(range[1], '2');
          expect(range[2], '3');
          range[1] += '*';
          expect(range[1], '2*');
          expect(source[2], '2*');
        });
        test('full range', () {
          final source = Vector.fromList(DataType.int8, [1, 2], format: format);
          expect(source.range(0, source.count), source);
        });
        test('sub range', () {
          final source =
              Vector.generate(DataType.string, 6, (i) => '$i', format: format);
          final range = source.range(1, 4).range(1, 2);
          expect(range.dataType, DataType.string);
          expect(range.count, 1);
          expect(range.storage, [source]);
          expect(range[0], '2');
          range[0] += '*';
          expect(range[0], '2*');
          expect(source[2], '2*');
        });
        test('error', () {
          final source = Vector.fromList(DataType.int8, [1, 2], format: format);
          expect(source.range(0, source.count), source);
          expect(() => source.range(-1, source.count), throwsRangeError);
          expect(() => source.range(0, source.count + 1), throwsRangeError);
        });
      });
      group('index', () {
        test('default', () {
          final source =
              Vector.generate(DataType.string, 6, (i) => '$i', format: format);
          final index = source.index([3, 2, 2]);
          expect(index.dataType, DataType.string);
          expect(index.count, 3);
          expect(index.storage, [source]);
          expect(compare(index.copy(), index), isTrue);
          expect(index[0], '3');
          expect(index[1], '2');
          expect(index[2], '2');
          index[1] += '*';
          expect(index[1], '2*');
          expect(source[2], '2*');
        });
        test('sub index', () {
          final source =
              Vector.generate(DataType.string, 6, (i) => '$i', format: format);
          final index = source.index([3, 2, 2]).index([1]);
          expect(index.dataType, DataType.string);
          expect(index.count, 1);
          expect(index.storage, [source]);
          expect(index[0], '2');
          index[0] += '*';
          expect(index[0], '2*');
          expect(source[2], '2*');
        });
        test('error', () {
          final source = Vector.fromList(DataType.int8, [1, 2], format: format);
          expect(() => source.index([0, 1]), isNot(throwsRangeError));
          expect(() => source.index([-1, source.count - 1]), throwsRangeError);
          expect(() => source.index([0, source.count]), throwsRangeError);
        });
      });
      group('overlay', () {
        final base = Vector.generate(DataType.string, 8, (index) => '($index)',
            format: format);
        test('offset', () {
          final top = Vector.generate(DataType.string, 2, (index) => '[$index]',
              format: format);
          final composite = top.overlay(base, offset: 4);
          expect(composite.dataType, top.dataType);
          expect(composite.count, base.count);
          expect(composite.storage, unorderedMatches([base, top]));
          final copy = composite.copy();
          expect(compare(copy, composite), isTrue);
          for (var i = 0; i < composite.count; i++) {
            expect(composite[i], 4 <= i && i <= 5 ? '[${i - 4}]' : '($i)');
            copy[i] = '${copy[i]}*';
          }
        });
        test('mask', () {
          final top = Vector.generate(
              DataType.string, base.count, (index) => '[$index]',
              format: format);
          final mask = Vector.generate(
              DataType.boolean, base.count, (index) => index.isEven,
              format: format);
          final composite = top.overlay(base, mask: mask);
          expect(composite.dataType, top.dataType);
          expect(composite.count, base.count);
          expect(composite.storage, unorderedMatches([base, top, mask]));
          final copy = composite.copy();
          expect(compare(copy, composite), isTrue);
          for (var i = 0; i < composite.count; i++) {
            expect(composite[i], i.isEven ? '[$i]' : '($i)');
            copy[i] = '${copy[i]}*';
          }
        });
        test('errors', () {
          expect(() => base.overlay(base), throwsArgumentError);
          expect(
              () => base.overlay(
                  Vector.constant(DataType.string, base.count + 1,
                      value: '', format: format),
                  mask: Vector.constant(DataType.boolean, base.count,
                      value: true, format: format)),
              throwsArgumentError);
          expect(
              () => base.overlay(
                  Vector.constant(DataType.string, base.count,
                      value: '', format: format),
                  mask: Vector.constant(DataType.boolean, base.count + 1,
                      value: true, format: format)),
              throwsArgumentError);
        });
      });
      group('transform', () {
        final source =
            Vector.generate(DataType.int8, 4, (index) => index, format: format);
        test('to string', () {
          final mapped =
              source.map((index, value) => '$index', DataType.string);
          expect(mapped.dataType, DataType.string);
          expect(mapped.count, source.count);
          expect(mapped.storage, [source]);
          for (var i = 0; i < mapped.count; i++) {
            expect(mapped[i], '$i');
          }
        });
        test('to int', () {
          final mapped = source.map((index, value) => index, DataType.int32);
          expect(mapped.dataType, DataType.int32);
          expect(mapped.count, source.count);
          expect(mapped.storage, [source]);
          for (var i = 0; i < mapped.count; i++) {
            expect(mapped[i], i);
          }
        });
        test('to float', () {
          final mapped =
              source.map((index, value) => index.toDouble(), DataType.float64);
          expect(mapped.dataType, DataType.float64);
          expect(mapped.count, source.count);
          expect(mapped.storage, [source]);
          for (var i = 0; i < mapped.count; i++) {
            expect(mapped[i], i.toDouble());
          }
        });
        test('readonly', () {
          final mapped = source.map((index, value) => index, DataType.int32);
          expect(() => mapped.setUnchecked(0, 1), throwsUnsupportedError);
        });
        test('mutable', () {
          final source = Vector.generate(
              DataType.uint8, 6, (index) => index + 97,
              format: format);
          final transform = source.transform<String>(
            (index, value) => String.fromCharCode(value),
            write: (index, value) => value.codeUnitAt(0),
            dataType: DataType.string,
          );
          expect(transform.dataType, DataType.string);
          expect(transform.count, source.count);
          expect(transform.storage, [source]);
          for (var i = 0; i < transform.count; i++) {
            expect(transform[i], 'abcdef'[i]);
          }
          transform[2] = '*';
          expect(transform[2], '*');
          expect(source[2], 42);
        });
        test('copy', () {
          final mapped = source.map((index, value) => index, DataType.int32);
          expect(compare(mapped.copy(), mapped), isTrue);
        });
      });
      group('cast', () {
        final source = Vector.generate(DataType.int32, 256, (index) => index,
            format: format);
        test('to string', () {
          final cast = source.cast(DataType.string);
          expect(cast.dataType, DataType.string);
          expect(cast.count, source.count);
          expect(cast.storage, [source]);
          for (var i = 0; i < cast.count; i++) {
            expect(cast[i], '$i');
          }
        });
        test('copy', () {
          final cast = source.cast(DataType.int32);
          expect(compare(cast.copy(), cast), isTrue);
        });
      });
      test('reversed', () {
        final source =
            Vector.fromList(DataType.int8, [1, 2, 3], format: format);
        final reversed = source.reversed;
        expect(reversed.dataType, source.dataType);
        expect(reversed.count, source.count);
        expect(reversed.storage, [source]);
        expect(reversed.reversed, same(source));
        expect(compare(reversed.copy(), reversed), isTrue);
        for (var i = 0; i < source.count; i++) {
          expect(reversed[i], source[source.count - i - 1]);
        }
        reversed[1] = 42;
        expect(reversed[1], 42);
        expect(source[1], 42);
      });
      test('unmodifiable', () {
        final source = Vector.fromList(DataType.int8, [1, 2], format: format);
        final readonly = source.unmodifiable;
        expect(readonly.dataType, source.dataType);
        expect(readonly.count, source.count);
        expect(readonly.storage, [source]);
        expect(compare(readonly.copy(), readonly), isTrue);
        for (var i = 0; i < source.count; i++) {
          expect(source[i], readonly[i]);
          expect(() => readonly[i] = 0, throwsUnsupportedError);
        }
        source[1] = 3;
        expect(readonly[1], 3);
        expect(readonly.unmodifiable, readonly);
      });
    });
    group('iterables', () {
      test('basic', () {
        final source =
            Vector.generate(DataType.string, 5, (i) => '$i', format: format);
        final list = source.iterable;
        expect(list, ['0', '1', '2', '3', '4']);
        expect(list.length, source.count);
        expect(() => list.length = 0, throwsUnsupportedError);
        list[2] = '*';
        expect(list, ['0', '1', '*', '3', '4']);
        source[2] = '!';
        expect(list, ['0', '1', '!', '3', '4']);
      });
    });
    group('operators', () {
      final random = Random();
      final sourceA = Vector.generate(
          DataType.int32, 100, (i) => random.nextInt(100),
          format: format);
      final sourceB = Vector.generate(
          DataType.int32, 100, (i) => random.nextInt(100),
          format: format);
      test('unary', () {
        final result = unaryOperator(sourceA, (a) => a * a);
        expect(result.dataType, sourceA.dataType);
        expect(result.count, sourceA.count);
        for (var i = 0; i < result.count; i++) {
          final a = sourceA[i];
          expect(result[i], a * a);
        }
      });
      test('binary', () {
        final result =
            binaryOperator(sourceA, sourceB, (a, b) => a * a + b * b);
        expect(result.dataType, sourceA.dataType);
        expect(result.count, sourceA.count);
        for (var i = 0; i < result.count; i++) {
          final a = sourceA[i];
          final b = sourceB[i];
          expect(result[i], a * a + b * b);
        }
      });
      group('add', () {
        test('default', () {
          final target = add(sourceA, sourceB);
          expect(target.dataType, sourceA.dataType);
          expect(target.count, sourceA.count);
          for (var i = 0; i < target.count; i++) {
            expect(target[i], sourceA[i] + sourceB[i]);
          }
        });
        test('default, bad count', () {
          final sourceA =
              Vector.fromList(DataType.int8, [1, 2], format: format);
          expect(() => add(sourceA, sourceB), throwsArgumentError);
        });
        test('target', () {
          final target = Vector(DataType.int16, sourceA.count, format: format);
          final result = add(sourceA, sourceB, target: target);
          expect(target.dataType, DataType.int16);
          expect(target.count, sourceA.count);
          for (var i = 0; i < target.count; i++) {
            expect(target[i], sourceA[i] + sourceB[i]);
          }
          expect(result, target);
        });
        test('target, bad count', () {
          final target =
              Vector(DataType.int16, sourceA.count - 1, format: format);
          expect(
              () => add(sourceA, sourceB, target: target), throwsArgumentError);
        });
        test('builder', () {
          final target =
              add(sourceA, sourceB, dataType: DataType.int16, format: format);
          expect(target.dataType, DataType.int16);
          expect(target.count, sourceA.count);
          for (var i = 0; i < target.count; i++) {
            expect(target[i], sourceA[i] + sourceB[i]);
          }
        });
      });
      test('sub', () {
        final target = sub(sourceA, sourceB);
        expect(target.dataType, sourceA.dataType);
        expect(target.count, sourceA.count);
        for (var i = 0; i < target.count; i++) {
          expect(target[i], sourceA[i] - sourceB[i]);
        }
      });
      test('neg', () {
        final target = neg(sourceA);
        expect(target.dataType, sourceA.dataType);
        expect(target.count, sourceA.count);
        for (var i = 0; i < target.count; i++) {
          expect(target[i], -sourceA[i]);
        }
      });
      test('scale', () {
        final target = scale(sourceA, 2);
        expect(target.dataType, sourceA.dataType);
        expect(target.count, sourceA.count);
        for (var i = 0; i < target.count; i++) {
          expect(target[i], 2 * sourceA[i]);
        }
      });
      group('lerp', () {
        final v0 = Vector<double>.fromList(DataType.float32, [1, 6, 9],
            format: format);
        final v1 = Vector<double>.fromList(DataType.float32, [9, -2, 9],
            format: format);
        test('at start', () {
          final v = lerp(v0, v1, 0.0);
          expect(v.dataType, v1.dataType);
          expect(v.count, v1.count);
          expect(v[0], v0[0]);
          expect(v[1], v0[1]);
          expect(v[2], v0[2]);
        });
        test('at middle', () {
          final v = lerp(v0, v1, 0.5);
          expect(v.dataType, v1.dataType);
          expect(v.count, v1.count);
          expect(v[0], 5.0);
          expect(v[1], 2.0);
          expect(v[2], 9.0);
        });
        test('at end', () {
          final v = lerp(v0, v1, 1.0);
          expect(v.dataType, v1.dataType);
          expect(v.count, v1.count);
          expect(v[0], v1[0]);
          expect(v[1], v1[1]);
          expect(v[2], v1[2]);
        });
        test('at outside', () {
          final v = lerp(v0, v1, 2.0);
          expect(v.dataType, v1.dataType);
          expect(v.count, v1.count);
          expect(v[0], 17.0);
          expect(v[1], -10.0);
          expect(v[2], 9.0);
        });
        test('error', () {
          final other =
              Vector<double>.fromList(DataType.float32, [0, 1], format: format);
          expect(() => lerp(v0, other, 2.0), throwsArgumentError);
        });
      });
      group('compare', () {
        test('identity', () {
          expect(compare(sourceA, sourceA), isTrue);
          expect(compare(sourceB, sourceB), isTrue);
          expect(compare(sourceA, sourceB), isFalse);
          expect(compare(sourceB, sourceA), isFalse);
        });
        test('views', () {
          expect(
              compare(sourceA.range(0, 3), sourceA.index([0, 1, 2])), isTrue);
          expect(
              compare(sourceA.range(0, 3), sourceA.index([3, 1, 0])), isFalse,
              reason: 'order missmatch');
          expect(compare(sourceA.range(0, 3), sourceA.index([0, 1])), isFalse,
              reason: 'count missmatch');
        });
        test('custom', () {
          final negated = neg(sourceA);
          expect(compare(sourceA, negated), isFalse);
          expect(compare(sourceA, negated, equals: (a, b) => a == -b), isTrue);
        });
      });
      group('mul', () {
        final sourceA = matrix.Matrix.generate(
            DataType.int32, 37, 42, (r, c) => random.nextInt(100),
            format: matrix.defaultMatrixFormat);
        final sourceB = Vector.generate(
            DataType.int8, sourceA.columnCount, (i) => random.nextInt(100),
            format: format);
        test('default', () {
          final v = mul(sourceA, sourceB);
          for (var i = 0; i < v.count; i++) {
            expect(v[i], dot(sourceA.row(i), sourceB));
          }
        });
        test('error in-place', () {
          final derivedA = sourceA.range(0, 8, 0, 8);
          final derivedB = sourceB.range(0, 8);
          expect(() => mul(derivedA, derivedB, target: derivedB),
              throwsArgumentError);
          expect(() => mul(derivedA, derivedB, target: derivedA.row(0)),
              throwsArgumentError);
          expect(() => mul(derivedA, derivedB, target: derivedA.column(0)),
              throwsArgumentError);
        });
        test('error dimensions', () {
          expect(() => mul(sourceA.colRange(1), sourceB), throwsArgumentError);
          expect(() => mul(sourceA, sourceB.range(1)), throwsArgumentError);
        });
      });
      test('dot', () {
        var expected = 0;
        for (var i = 0; i < sourceA.count; i++) {
          expected += sourceA[i] * sourceB[i];
        }
        expect(dot(sourceA, sourceB), expected);
      });
      test('dot (dimension missmatch)', () {
        final sourceB =
            Vector(DataType.uint8, sourceA.count - 1, format: format);
        expect(() => dot(sourceA, sourceB), throwsArgumentError);
      });
      test('sum', () {
        final source =
            Vector.fromList(DataType.uint8, [1, 2, 3, 4], format: format);
        expect(sum(source), 10);
      });
      test('length', () {
        final source = Vector.fromList(DataType.uint8, [3, 4], format: format);
        expect(length(source), 5.0);
      });
      test('length2', () {
        final source = Vector.fromList(DataType.uint8, [4, 3], format: format);
        expect(length2(source), 25);
      });
    });
  });
}

void main() {
  vectorTest('standard', VectorFormat.standard);
  vectorTest('keyed', VectorFormat.keyed);
  vectorTest('list', VectorFormat.list);
}
