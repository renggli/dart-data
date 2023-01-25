import 'dart:math';

import 'package:data/data.dart';
import 'package:data/src/matrix/view/rotated_matrix.dart';
import 'package:test/test.dart';

import 'utils/matchers.dart';

const pointType = ObjectDataType<Point<int>>(Point(0, 0));

void matrixTest(String name, MatrixFormat format) {
  group(name, () {
    group('constructor', () {
      test('empty', () {
        final matrix = Matrix(DataType.int8, 0, 0, format: format);
        expect(matrix.dataType, DataType.int8);
        expect(matrix.rowCount, 0);
        expect(matrix.colCount, 0);
        expect(matrix.storage, [matrix]);
        expect(matrix.shape, [matrix.rowCount, matrix.colCount]);
      });
      test('default', () {
        final matrix = Matrix(DataType.int8, 4, 5, format: format);
        expect(matrix.dataType, DataType.int8);
        expect(matrix.rowCount, 4);
        expect(matrix.colCount, 5);
        expect(matrix.storage, [matrix]);
        expect(matrix.shape, [matrix.rowCount, matrix.colCount]);
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), 0);
          }
        }
      });
      test('default with error', () {
        expect(() => Matrix(DataType.int8, -4, 5, format: format),
            throwsRangeError);
        expect(() => Matrix(DataType.int8, 4, -5, format: format),
            throwsRangeError);
      });
      group('concat horizontal', () {
        final a = Matrix.fromRows(
            DataType.int8,
            [
              [1, 2],
              [4, 5]
            ],
            format: format);
        final b = Matrix.fromRows(
            DataType.int8,
            [
              [3],
              [6]
            ],
            format: format);
        final expected = Matrix.fromRows(
            DataType.int8,
            [
              [1, 2, 3],
              [4, 5, 6]
            ],
            format: format);
        test('default', () {
          final matrix = Matrix.concatHorizontal(DataType.int8, [a, b]);
          expect(matrix.compare(expected), isTrue);
          expect(matrix.dataType, a.dataType);
          expect(matrix.rowCount, 2);
          expect(matrix.colCount, 3);
          expect(matrix.storage, [a, b]);
        });
        test('writing', () {
          final first = a.toMatrix(format: format);
          final second = b.toMatrix(format: format);
          final matrix =
              Matrix.concatHorizontal(DataType.int8, [first, second]);
          for (var r = 0; r < matrix.rowCount; r++) {
            for (var c = 0; c < matrix.colCount; c++) {
              matrix.set(r, c, -1);
            }
          }
          expect(first.rowMajor, everyElement(-1));
          expect(second.rowMajor, everyElement(-1));
        });
        test('with format', () {
          final matrix =
              Matrix.concatHorizontal(DataType.int8, [a, b], format: format);
          expect(matrix.compare(expected), isTrue);
        });
        test('single', () {
          final matrix = Matrix.concatHorizontal(DataType.int8, [a]);
          expect(matrix, a);
        });
        test('error', () {
          expect(() => Matrix.concatHorizontal(DataType.int8, []),
              throwsArgumentError);
        });
      });
      group('concat vertical', () {
        final a = Matrix.fromRows(
            DataType.int8,
            [
              [1, 4],
              [2, 5]
            ],
            format: format);
        final b = Matrix.fromRows(
            DataType.int8,
            [
              [3, 6]
            ],
            format: format);
        final expected = Matrix.fromRows(
            DataType.int8,
            [
              [1, 4],
              [2, 5],
              [3, 6]
            ],
            format: format);
        test('default', () {
          final matrix = Matrix.concatVertical(DataType.int8, [a, b]);
          expect(matrix.compare(expected), isTrue);
          expect(matrix.dataType, a.dataType);
          expect(matrix.rowCount, 3);
          expect(matrix.colCount, 2);
          expect(matrix.storage, [a, b]);
        });
        test('writing', () {
          final first = a.toMatrix(format: format);
          final second = b.toMatrix(format: format);
          final matrix = Matrix.concatVertical(DataType.int8, [first, second]);
          for (var r = 0; r < matrix.rowCount; r++) {
            for (var c = 0; c < matrix.colCount; c++) {
              matrix.set(r, c, -1);
            }
          }
          expect(first.rowMajor, everyElement(-1));
          expect(second.rowMajor, everyElement(-1));
        });
        test('with format', () {
          final matrix =
              Matrix.concatVertical(DataType.int8, [a, b], format: format);
          expect(matrix.compare(expected), isTrue);
        });
        test('single', () {
          final matrix = Matrix.concatVertical(DataType.int8, [a]);
          expect(matrix, a);
        });
        test('error', () {
          expect(() => Matrix.concatVertical(DataType.int8, []),
              throwsArgumentError);
        });
      });
      test('constant', () {
        final matrix = Matrix.constant(DataType.int8, 5, 6);
        expect(matrix.dataType, DataType.int8);
        expect(matrix.rowCount, 5);
        expect(matrix.colCount, 6);
        expect(matrix.storage, [matrix]);
        expect(matrix.shape, [matrix.rowCount, matrix.colCount]);
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), 0);
          }
        }
        expect(() => matrix.set(0, 0, 1), throwsUnsupportedError);
      });
      test('constant with value', () {
        final matrix = Matrix.constant(DataType.int8, 5, 6, value: 123);
        expect(matrix.dataType, DataType.int8);
        expect(matrix.rowCount, 5);
        expect(matrix.colCount, 6);
        expect(matrix.storage, [matrix]);
        expect(matrix.shape, [matrix.rowCount, matrix.colCount]);
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), 123);
          }
        }
        expect(() => matrix.set(0, 0, 1), throwsUnsupportedError);
      });
      test('constant with format', () {
        final matrix = Matrix.constant(DataType.int8, 5, 6, format: format);
        expect(matrix.dataType, DataType.int8);
        expect(matrix.rowCount, 5);
        expect(matrix.colCount, 6);
        expect(matrix.storage, [matrix]);
        expect(matrix.shape, [matrix.rowCount, matrix.colCount]);
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), 0);
          }
        }
        matrix.set(0, 0, 1);
        expect(matrix.get(0, 0), 1);
      });
      test('identity', () {
        final matrix = Matrix.identity(DataType.int8, 6, 7);
        expect(matrix.dataType, DataType.int8);
        expect(matrix.rowCount, 6);
        expect(matrix.colCount, 7);
        expect(matrix.storage, [matrix]);
        expect(matrix.shape, [matrix.rowCount, matrix.colCount]);
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), r == c ? 1 : 0);
          }
        }
        expect(() => matrix.set(0, 0, 1), throwsUnsupportedError);
      });
      test('identity with value', () {
        final matrix = Matrix.identity(DataType.int8, 6, 7, value: -1);
        expect(matrix.dataType, DataType.int8);
        expect(matrix.rowCount, 6);
        expect(matrix.colCount, 7);
        expect(matrix.storage, [matrix]);
        expect(matrix.shape, [matrix.rowCount, matrix.colCount]);
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), r == c ? -1 : 0);
          }
        }
        expect(() => matrix.set(0, 0, -1), throwsUnsupportedError);
      });
      test('identity with format', () {
        final matrix = Matrix.identity(DataType.int8, 6, 7, format: format);
        expect(matrix.dataType, DataType.int8);
        expect(matrix.rowCount, 6);
        expect(matrix.colCount, 7);
        expect(matrix.storage, [matrix]);
        expect(matrix.shape, [matrix.rowCount, matrix.colCount]);
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), r == c ? 1 : 0);
          }
        }
        matrix.set(0, 0, -1);
        expect(matrix.get(0, 0), -1);
      });
      test('generate', () {
        final matrix = Matrix.generate(
            DataType.string, 7, 8, (row, col) => '($row, $col)');
        expect(matrix.dataType, DataType.string);
        expect(matrix.rowCount, 7);
        expect(matrix.colCount, 8);
        expect(matrix.shape, [matrix.rowCount, matrix.colCount]);
        expect(matrix.storage, [matrix]);
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), '($r, $c)');
          }
        }
        expect(() => matrix.set(0, 0, '*'), throwsUnsupportedError);
      });
      test('generate with format', () {
        final matrix = Matrix.generate(
            DataType.string, 7, 8, (row, col) => '($row, $col)',
            format: format);
        expect(matrix.dataType, DataType.string);
        expect(matrix.rowCount, 7);
        expect(matrix.colCount, 8);
        expect(matrix.shape, [matrix.rowCount, matrix.colCount]);
        expect(matrix.storage, [matrix]);
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), '($r, $c)');
          }
        }
        matrix.set(0, 0, '*');
        expect(matrix.get(0, 0), '*');
      });
      test('vandermonde', () {
        final data = Vector.fromIterable(DataType.int8, [2, 3, 5]);
        final matrix = Matrix.vandermonde(DataType.int32, data, 4);
        expect(matrix.dataType, DataType.int32);
        expect(matrix.rowCount, data.count);
        expect(matrix.colCount, 4);
        expect(matrix.shape, [data.count, 4]);
        expect(matrix.storage, [matrix]);
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), pow(data[r], c));
          }
        }
        expect(() => matrix.set(0, 0, 42), throwsUnsupportedError);
      });
      test('vandermonde with format', () {
        final data = Vector.fromIterable(DataType.int8, [-7, 3, 1, 0, 7]);
        final matrix =
            Matrix.vandermonde(DataType.int32, data, 7, format: format);
        expect(matrix.dataType, DataType.int32);
        expect(matrix.rowCount, data.count);
        expect(matrix.colCount, 7);
        expect(matrix.shape, [data.count, 7]);
        expect(matrix.storage, [matrix]);
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), pow(data[r], c));
          }
        }
        matrix.set(0, 0, 42);
        expect(matrix.get(0, 0), 42);
      });
      test('fromRows', () {
        final matrix = Matrix.fromRows(
            DataType.int8,
            [
              [1, 2, 3],
              [4, 5, 6],
            ],
            format: format);
        expect(matrix.dataType, DataType.int8);
        expect(matrix.rowCount, 2);
        expect(matrix.colCount, 3);
        expect(matrix.shape, [matrix.rowCount, matrix.colCount]);
        expect(matrix.storage, [matrix]);
        expect(matrix.get(0, 0), 1);
        expect(matrix.get(1, 0), 4);
        expect(matrix.get(0, 1), 2);
        expect(matrix.get(1, 1), 5);
        expect(matrix.get(0, 2), 3);
        expect(matrix.get(1, 2), 6);
      });
      test('fromRows with error', () {
        expect(
            () => Matrix.fromRows(
                DataType.int8,
                [
                  [1],
                  [1, 2]
                ],
                format: format),
            throwsArgumentError);
      });
      test('fromPackedRows', () {
        final matrix = Matrix.fromPackedRows(
            DataType.numeric, 2, 3, [1, 2, 3, 4, 5, 6],
            format: format);
        expect(matrix.dataType, DataType.numeric);
        expect(matrix.rowCount, 2);
        expect(matrix.colCount, 3);
        expect(matrix.shape, [matrix.rowCount, matrix.colCount]);
        expect(matrix.storage, [matrix]);
        expect(matrix.get(0, 0), 1);
        expect(matrix.get(0, 1), 2);
        expect(matrix.get(0, 2), 3);
        expect(matrix.get(1, 0), 4);
        expect(matrix.get(1, 1), 5);
        expect(matrix.get(1, 2), 6);
      });
      test('fromPackedRows with error', () {
        expect(
            () => Matrix.fromPackedRows(DataType.numeric, 2, 3, <num>[],
                format: format),
            throwsArgumentError);
      });
      test('fromColumns', () {
        final matrix = Matrix.fromColumns(
            DataType.int8,
            [
              [1, 2, 3],
              [4, 5, 6],
            ],
            format: format);
        expect(matrix.dataType, DataType.int8);
        expect(matrix.rowCount, 3);
        expect(matrix.colCount, 2);
        expect(matrix.shape, [matrix.rowCount, matrix.colCount]);
        expect(matrix.storage, [matrix]);
        expect(matrix.get(0, 0), 1);
        expect(matrix.get(1, 0), 2);
        expect(matrix.get(2, 0), 3);
        expect(matrix.get(0, 1), 4);
        expect(matrix.get(1, 1), 5);
        expect(matrix.get(2, 1), 6);
      });
      test('fromColumns with error', () {
        expect(
            () => Matrix.fromColumns(
                DataType.int8,
                [
                  [1],
                  [1, 2]
                ],
                format: format),
            throwsArgumentError);
      });
      test('fromPackedColumns', () {
        final matrix = Matrix.fromPackedColumns(
            DataType.numeric, 2, 3, [1, 2, 3, 4, 5, 6],
            format: format);
        expect(matrix.dataType, DataType.numeric);
        expect(matrix.rowCount, 2);
        expect(matrix.colCount, 3);
        expect(matrix.shape, [matrix.rowCount, matrix.colCount]);
        expect(matrix.storage, [matrix]);
        expect(matrix.get(0, 0), 1);
        expect(matrix.get(1, 0), 2);
        expect(matrix.get(0, 1), 3);
        expect(matrix.get(1, 1), 4);
        expect(matrix.get(0, 2), 5);
        expect(matrix.get(1, 2), 6);
      });
      test('fromPackedColumns with error', () {
        expect(
            () => Matrix.fromPackedColumns(DataType.numeric, 2, 3, <num>[],
                format: format),
            throwsArgumentError);
      });
    });
    group('accessing', () {
      final matrix = Matrix.fromRows(
          DataType.int8,
          [
            [1, 2, 3],
            [4, 5, 6]
          ],
          format: format);
      test('random', () {
        final matrix = Matrix(pointType, 8, 12, format: format);
        final points = <Point<int>>[];
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            points.add(Point(r, c));
          }
        }
        // add values
        points.shuffle();
        for (final point in points) {
          matrix.set(point.x, point.y, point);
        }
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), Point(r, c));
          }
        }
        // update values
        points.shuffle();
        for (final point in points) {
          matrix.set(point.x, point.y, Point(point.x + 1, point.y + 1));
        }
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), Point(r + 1, c + 1));
          }
        }
        // remove values
        points.shuffle();
        for (final point in points) {
          matrix.set(point.x, point.y, matrix.dataType.defaultValue);
        }
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), matrix.dataType.defaultValue);
          }
        }
      });
      test('read operator', () {
        expect(matrix[0][0], 1);
        expect(matrix[0][1], 2);
        expect(matrix[0][2], 3);
        expect(matrix[1][0], 4);
        expect(matrix[1][1], 5);
        expect(matrix[1][2], 6);
      });
      test('write operator', () {
        final copy = Matrix(matrix.dataType, matrix.rowCount, matrix.colCount,
            format: format);
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            copy[r][c] = matrix.get(r, c);
          }
        }
        expect(copy.compare(matrix), isTrue);
      });
      test('read with range error', () {
        expect(() => matrix.get(-1, 0), throwsRangeError);
        expect(() => matrix.get(0, -1), throwsRangeError);
        expect(() => matrix.get(matrix.rowCount, 0), throwsRangeError);
        expect(() => matrix.get(0, matrix.colCount), throwsRangeError);
      });
      test('write with range error', () {
        expect(() => matrix.set(-1, 0, 0), throwsRangeError);
        expect(() => matrix.set(0, -1, 0), throwsRangeError);
        expect(() => matrix.set(matrix.rowCount, 0, 0), throwsRangeError);
        expect(() => matrix.set(0, matrix.colCount, 0), throwsRangeError);
      });
      test('format', () {
        final matrix = Matrix.generate(DataType.uint16, 30, 30, (r, c) => r * c,
            format: format);
        expect(
            matrix.format(),
            '0 0 0 … 0 0 0\n'
            '0 1 2 … 27 28 29\n'
            '0 2 4 … 54 56 58\n'
            '⋮ ⋮ ⋮ ⋱ ⋮ ⋮ ⋮\n'
            '0 27 54 … 729 756 783\n'
            '0 28 56 … 756 784 812\n'
            '0 29 58 … 783 812 841');
      });
      test('toString', () {
        expect(
            matrix.toString(),
            '${matrix.runtimeType}'
            '(dataType: int8, rowCount: 2, columnCount: 3):\n'
            '1 2 3\n'
            '4 5 6');
      });
    });
    group('view', () {
      test('copy', () {
        final source = Matrix.generate(
            pointType, 8, 6, (row, col) => Point(row, col),
            format: format);
        final copy = source.toMatrix(format: format);
        expect(copy.dataType, source.dataType);
        expect(copy.rowCount, source.rowCount);
        expect(copy.colCount, source.colCount);
        expect(copy.storage, [copy]);
        expect(source.compare(copy), isTrue);
        source.set(3, 5, const Point(32, 64));
        expect(copy.get(3, 5), const Point(3, 5));
      });
      test('copyInto', () {
        final source =
            Matrix.generate(DataType.int32, 8, 6, (row, col) => 8 * row + col);
        final target = Matrix(DataType.int32, 8, 6, format: format);
        expect(source.copyInto(target), target);
        expect(target, isCloseTo(source));
      });
      test('row', () {
        final source = Matrix.generate(
            DataType.string, 4, 5, (r, c) => '($r, $c)',
            format: format);
        for (var r = 0; r < source.rowCount; r++) {
          final row = source.row(r);
          expect(row.dataType, source.dataType);
          expect(row.count, source.colCount);
          expect(row.storage, [source]);
          for (var c = 0; c < source.colCount; c++) {
            expect(row[c], '($r, $c)');
            row[c] += '*';
          }
          expect(() => row[-1], throwsRangeError);
          expect(() => row[source.colCount], throwsRangeError);
          expect(() => row[-1] += '*', throwsRangeError);
          expect(() => row[source.colCount] += '*', throwsRangeError);
        }
        expect(() => source.row(-1), throwsRangeError);
        expect(() => source.row(4), throwsRangeError);
        for (var r = 0; r < source.rowCount; r++) {
          for (var c = 0; c < source.colCount; c++) {
            expect(source.get(r, c), '($r, $c)*');
          }
        }
      });
      test('column', () {
        final source = Matrix.generate(
            DataType.string, 5, 4, (r, c) => '($r, $c)',
            format: format);
        for (var c = 0; c < source.colCount; c++) {
          final column = source.column(c);
          expect(column.dataType, source.dataType);
          expect(column.count, source.rowCount);
          expect(column.storage, [source]);
          for (var r = 0; r < source.rowCount; r++) {
            expect(column[r], '($r, $c)');
            column[r] += '*';
          }
          expect(() => column[-1], throwsRangeError);
          expect(() => column[source.rowCount], throwsRangeError);
          expect(() => column[-1] += '*', throwsRangeError);
          expect(() => column[source.rowCount] += '*', throwsRangeError);
        }
        expect(() => source.column(-1), throwsRangeError);
        expect(() => source.column(4), throwsRangeError);
        for (var r = 0; r < source.rowCount; r++) {
          for (var c = 0; c < source.colCount; c++) {
            expect(source.get(r, c), '($r, $c)*');
          }
        }
      });
      group('diagonal', () {
        test('vertical', () {
          final source = Matrix.generate(
              DataType.string, 2, 3, (row, col) => '($row, $col)',
              format: format);
          final offsets = {
            1: ['(1, 0)'],
            0: ['(0, 0)', '(1, 1)'],
            -1: ['(0, 1)', '(1, 2)'],
            -2: ['(0, 2)'],
          };
          for (final offset in offsets.keys) {
            final expected = offsets[offset]!;
            final diagonal = source.diagonal(offset);
            expect(diagonal.dataType, source.dataType);
            expect(diagonal.count, expected.length);
            expect(diagonal.storage, [source]);
            for (var i = 0; i < expected.length; i++) {
              expect(diagonal[i], expected[i]);
              diagonal[i] += '*';
            }
          }
          expect(() => source.diagonal(2), throwsRangeError);
          expect(() => source.diagonal(-3), throwsRangeError);
          for (var r = 0; r < source.rowCount; r++) {
            for (var c = 0; c < source.colCount; c++) {
              expect(source.get(r, c), '($r, $c)*');
            }
          }
        });
        test('horizontal', () {
          final source = Matrix.generate(
              DataType.string, 3, 2, (row, col) => '($row, $col)',
              format: format);
          final offsets = {
            2: ['(2, 0)'],
            1: ['(1, 0)', '(2, 1)'],
            0: ['(0, 0)', '(1, 1)'],
            -1: ['(0, 1)'],
          };
          for (final offset in offsets.keys) {
            final expected = offsets[offset]!;
            final diagonal = source.diagonal(offset);
            expect(diagonal.dataType, source.dataType);
            expect(diagonal.count, expected.length);
            expect(diagonal.storage, [source]);
            for (var i = 0; i < expected.length; i++) {
              expect(diagonal[i], expected[i]);
              diagonal[i] += '*';
            }
            expect(() => diagonal[-1], throwsRangeError);
            expect(() => diagonal[diagonal.count], throwsRangeError);
          }
          expect(() => source.diagonal(3), throwsRangeError);
          expect(() => source.diagonal(-2), throwsRangeError);
          for (var r = 0; r < source.rowCount; r++) {
            for (var c = 0; c < source.colCount; c++) {
              expect(source.get(r, c), '($r, $c)*');
            }
          }
        });
      });
      group('range', () {
        final source = Matrix.generate(
            pointType, 7, 8, (row, col) => Point(row, col),
            format: format);
        test('row', () {
          final range = source.rowRange(1, 3);
          expect(range.dataType, source.dataType);
          expect(range.rowCount, 2);
          expect(range.colCount, source.colCount);
          expect(range.storage, [source]);
          for (var r = 0; r < range.rowCount; r++) {
            for (var c = 0; c < range.colCount; c++) {
              expect(range.get(r, c), Point(r + 1, c));
            }
          }
        });
        test('row unchecked', () {
          source.rowRangeUnchecked(-1, source.rowCount);
          source.rowRangeUnchecked(0, source.rowCount + 1);
        });
        test('column', () {
          final range = source.colRange(1, 4);
          expect(range.dataType, source.dataType);
          expect(range.rowCount, source.rowCount);
          expect(range.colCount, 3);
          expect(range.storage, [source]);
          for (var r = 0; r < range.rowCount; r++) {
            for (var c = 0; c < range.colCount; c++) {
              expect(range.get(r, c), Point(r, c + 1));
            }
          }
        });
        test('column unchecked', () {
          source.colRangeUnchecked(-1, source.colCount);
          source.colRangeUnchecked(0, source.colCount + 1);
        });
        test('row and column', () {
          final range = source.range(1, 3, 2, 4);
          expect(range.dataType, source.dataType);
          expect(range.rowCount, 2);
          expect(range.colCount, 2);
          expect(range.storage, [source]);
          for (var r = 0; r < range.rowCount; r++) {
            for (var c = 0; c < range.colCount; c++) {
              expect(range.get(r, c), Point(r + 1, c + 2));
            }
          }
        });
        test('sub range', () {
          final range = source
              .range(1, source.rowCount - 2, 1, source.colCount - 2)
              .range(1, source.rowCount - 3, 1, source.colCount - 3);
          expect(range.dataType, source.dataType);
          expect(range.rowCount, source.rowCount - 4);
          expect(range.colCount, source.colCount - 4);
          expect(range.storage, [source]);
          for (var r = 0; r < range.rowCount; r++) {
            for (var c = 0; c < range.colCount; c++) {
              expect(range.get(r, c), Point(r + 2, c + 2));
            }
          }
        });
        test('full range', () {
          final range = source.range(0, source.rowCount, 0, source.colCount);
          expect(range, source);
        });
        test('write', () {
          const marker = Point(-1, -1);
          final original = source.toMatrix(format: format);
          final range = original.range(2, 3, 3, 4);
          range.set(0, 0, marker);
          expect(range.get(0, 0), marker);
          expect(original.get(2, 3), marker);
        });
        test('range error', () {
          expect(() => source.range(-1, source.rowCount, 0, source.colCount),
              throwsRangeError);
          expect(() => source.range(0, source.rowCount + 1, 0, source.colCount),
              throwsRangeError);
          expect(() => source.range(0, source.rowCount, -1, source.colCount),
              throwsRangeError);
          expect(() => source.range(0, source.rowCount, 0, source.colCount + 1),
              throwsRangeError);
        });
      });
      group('index', () {
        final source = Matrix.generate(
            pointType, 6, 4, (row, col) => Point(row, col),
            format: format);
        test('row', () {
          final index = source.rowIndex([5, 0, 4]);
          expect(index.dataType, source.dataType);
          expect(index.rowCount, 3);
          expect(index.colCount, source.colCount);
          expect(index.storage, [source]);
          for (var r = 0; r < index.rowCount; r++) {
            for (var c = 0; c < index.colCount; c++) {
              expect(
                  index.get(r, c),
                  Point(
                      r == 0
                          ? 5
                          : r == 1
                              ? 0
                              : 4,
                      c));
            }
          }
        });
        test('row unchecked', () {
          source.rowIndexUnchecked([-1, source.rowCount - 1]);
          source.rowIndexUnchecked([0, source.rowCount]);
        });
        test('column', () {
          final index = source.colIndex([3, 0, 0]);
          expect(index.dataType, source.dataType);
          expect(index.rowCount, source.rowCount);
          expect(index.colCount, 3);
          expect(index.storage, [source]);
          for (var r = 0; r < index.rowCount; r++) {
            for (var c = 0; c < index.colCount; c++) {
              expect(index.get(r, c), Point(r, c == 0 ? 3 : 0));
            }
          }
        });
        test('column unchecked', () {
          source.colIndexUnchecked([-1, source.colCount - 1]);
          source.colIndexUnchecked([0, source.colCount]);
        });
        test('row and column', () {
          final index = source.index([0, 5], [3, 0]);
          expect(index.dataType, source.dataType);
          expect(index.rowCount, 2);
          expect(index.colCount, 2);
          expect(index.storage, [source]);
          for (var r = 0; r < index.rowCount; r++) {
            for (var c = 0; c < index.colCount; c++) {
              expect(index.get(r, c), Point(r == 0 ? 0 : 5, c == 0 ? 3 : 0));
            }
          }
        });
        test('sub index', () {
          final index = source.index([2, 3, 0], [1, 2]).index([2], [1]);
          expect(index.dataType, source.dataType);
          expect(index.rowCount, 1);
          expect(index.colCount, 1);
          expect(index.storage, [source]);
          expect(index.get(0, 0), const Point(0, 2));
        });
        test('write', () {
          const marker = Point(-1, -1);
          final original = source.toMatrix(format: format);
          final index = original.index([2], [3]);
          index.set(0, 0, marker);
          expect(index.get(0, 0), marker);
          expect(original.get(2, 3), marker);
        });
        test('range error', () {
          expect(
              () => source
                  .index([-1, source.rowCount - 1], [0, source.colCount - 1]),
              throwsRangeError);
          expect(
              () =>
                  source.index([0, source.rowCount], [0, source.colCount - 1]),
              throwsRangeError);
          expect(
              () => source
                  .index([0, source.rowCount - 1], [-1, source.colCount - 1]),
              throwsRangeError);
          expect(
              () =>
                  source.index([0, source.rowCount - 1], [0, source.colCount]),
              throwsRangeError);
        });
      });
      group('overlay', () {
        final base = Matrix.generate(
            DataType.string, 8, 10, (row, col) => '($row, $col)',
            format: format);
        test('offset', () {
          final top = Matrix.generate(
              DataType.string, 2, 3, (row, col) => '[$row, $col]',
              format: format);
          final composite = top.overlay(base, rowOffset: 4, colOffset: 5);
          expect(composite.dataType, top.dataType);
          expect(composite.rowCount, base.rowCount);
          expect(composite.colCount, base.colCount);
          expect(composite.storage, unorderedMatches([base, top]));
          final copy = composite.toMatrix(format: format);
          expect(copy.compare(composite), isTrue);
          for (var r = 0; r < composite.rowCount; r++) {
            for (var c = 0; c < composite.colCount; c++) {
              expect(
                  composite.get(r, c),
                  4 <= r && r <= 5 && 5 <= c && c <= 7
                      ? '[${r - 4}, ${c - 5}]'
                      : '($r, $c)');
              copy.set(r, c, '${copy.get(r, c)}*');
            }
          }
        });
        test('mask', () {
          final top = Matrix.generate(DataType.string, base.rowCount,
              base.colCount, (row, col) => '[$row, $col]',
              format: format);
          final mask = Matrix.generate(DataType.boolean, base.rowCount,
              base.colCount, (row, col) => row.isEven && col.isOdd,
              format: format);
          final composite = top.overlay(base, mask: mask);
          expect(composite.dataType, top.dataType);
          expect(composite.rowCount, base.rowCount);
          expect(composite.colCount, base.colCount);
          expect(composite.storage, unorderedMatches([base, top, mask]));
          final copy = composite.toMatrix(format: format);
          expect(copy.compare(composite), isTrue);
          for (var r = 0; r < composite.rowCount; r++) {
            for (var c = 0; c < composite.colCount; c++) {
              expect(composite.get(r, c),
                  r.isEven && c.isOdd ? '[$r, $c]' : '($r, $c)');
              copy.set(r, c, '${copy.get(r, c)}*');
            }
          }
        });
        test('errors', () {
          expect(() => base.overlay(base), throwsArgumentError);
          expect(() => base.overlay(base, rowOffset: 1), throwsArgumentError);
          expect(() => base.overlay(base, colOffset: 1), throwsArgumentError);
          expect(
              () => base.overlay(
                  Matrix.constant(
                      DataType.string, base.rowCount + 1, base.colCount,
                      value: '', format: format),
                  mask: Matrix.constant(
                      DataType.boolean, base.rowCount, base.colCount,
                      value: true, format: format)),
              throwsArgumentError);
          expect(
              () => base.overlay(
                  Matrix.constant(
                      DataType.string, base.rowCount, base.colCount + 1,
                      value: '', format: format),
                  mask: Matrix.constant(
                      DataType.boolean, base.rowCount, base.colCount,
                      value: true, format: format)),
              throwsArgumentError);
          expect(
              () => base.overlay(base,
                  mask: Matrix.constant(
                      DataType.boolean, base.rowCount + 1, base.colCount,
                      value: true, format: format)),
              throwsArgumentError);
          expect(
              () => base.overlay(base,
                  mask: Matrix.constant(
                      DataType.boolean, base.rowCount, base.colCount + 1,
                      value: true, format: format)),
              throwsArgumentError);
        });
      });
      group('transform', () {
        final source = Matrix.generate(
            pointType, 3, 4, (row, col) => Point(row, col),
            format: format);
        test('to string', () {
          final mapped = source.map(
              (row, col, value) => '${value.x + 10 * value.y}',
              DataType.string);
          expect(mapped.dataType, DataType.string);
          expect(mapped.rowCount, source.rowCount);
          expect(mapped.colCount, source.colCount);
          expect(mapped.storage, [source]);
          for (var r = 0; r < mapped.rowCount; r++) {
            for (var c = 0; c < mapped.colCount; c++) {
              expect(mapped.get(r, c), '${r + 10 * c}');
            }
          }
        });
        test('to int', () {
          final mapped = source.map(
              (row, col, value) => value.x + 10 * value.y, DataType.int32);
          expect(mapped.dataType, DataType.int32);
          expect(mapped.rowCount, source.rowCount);
          expect(mapped.colCount, source.colCount);
          expect(mapped.storage, [source]);
          for (var r = 0; r < mapped.rowCount; r++) {
            for (var c = 0; c < mapped.colCount; c++) {
              expect(mapped.get(r, c), r + 10 * c);
            }
          }
        });
        test('to float', () {
          final mapped = source.map(
              (row, col, value) => value.x + 10.0 * value.y, DataType.float64);
          expect(mapped.dataType, DataType.float64);
          expect(mapped.rowCount, source.rowCount);
          expect(mapped.colCount, source.colCount);
          expect(mapped.storage, [source]);
          for (var r = 0; r < mapped.rowCount; r++) {
            for (var c = 0; c < mapped.colCount; c++) {
              expect(mapped.get(r, c), r + 10.0 * c);
            }
          }
        });
        test('readonly', () {
          final map = source.map<int>((row, col, value) => row, DataType.int32);
          expect(() => map.setUnchecked(1, 2, 3), throwsUnsupportedError);
        });
        test('mutable', () {
          final source = Matrix.generate(
              DataType.uint8, 8, 8, (row, col) => 32 + 8 * row + col,
              format: format);
          final transform = source.transform<String>(
            (row, col, value) => String.fromCharCode(value),
            write: (row, col, value) => value.codeUnitAt(0),
            dataType: DataType.string,
          );
          expect(transform.dataType, DataType.string);
          expect(transform.rowCount, source.rowCount);
          expect(transform.colCount, source.colCount);
          expect(transform.storage, [source]);
          for (var r = 0; r < transform.rowCount; r++) {
            for (var c = 0; c < transform.colCount; c++) {
              expect(transform.get(r, c), String.fromCharCode(32 + 8 * r + c));
            }
          }
          transform.set(6, 7, '*');
          expect(transform.get(6, 7), '*');
          expect(source.get(6, 7), 42);
        });
      });
      group('cast', () {
        final source = Matrix.generate(
            DataType.int32, 3, 5, (row, col) => row * col,
            format: format);
        test('default', () {
          final matrix = source.cast(DataType.string);
          expect(matrix.dataType, DataType.string);
          expect(matrix.rowCount, source.rowCount);
          expect(matrix.colCount, source.colCount);
          expect(matrix.storage, [source]);
          for (var r = 0; r < matrix.rowCount; r++) {
            for (var c = 0; c < matrix.colCount; c++) {
              expect(matrix.get(r, c), '${r * c}');
            }
          }
        });
        test('write', () {
          final copy = source.toMatrix(format: format);
          final matrix = copy.cast(DataType.string);
          matrix.set(0, 0, '-1');
          expect(copy.get(0, 0), -1);
          copy.set(0, 0, -2);
          expect(matrix.get(0, 0), '-2');
        });
      });
      test('transposed', () {
        final source = Matrix.generate(
            DataType.string, 7, 6, (row, col) => '($row, $col)',
            format: format);
        final transposed = source.transposed;
        expect(transposed.dataType, source.dataType);
        expect(transposed.rowCount, source.colCount);
        expect(transposed.colCount, source.rowCount);
        expect(transposed.storage, [source]);
        expect(transposed.transposed, same(source));
        for (var r = 0; r < transposed.rowCount; r++) {
          for (var c = 0; c < transposed.colCount; c++) {
            expect(transposed.get(r, c), '($c, $r)');
            transposed.set(r, c, '${transposed.get(r, c)}*');
          }
        }
        for (var r = 0; r < source.rowCount; r++) {
          for (var c = 0; c < source.colCount; c++) {
            expect(source.get(r, c), '($r, $c)*');
          }
        }
      });
      test('flippedHorizontal', () {
        final source = Matrix.generate(
            DataType.string, 7, 6, (row, col) => '($row, $col)',
            format: format);
        final flipped = source.flippedHorizontal;
        expect(flipped.dataType, source.dataType);
        expect(flipped.rowCount, source.rowCount);
        expect(flipped.colCount, source.colCount);
        expect(flipped.storage, [source]);
        expect(flipped.flippedHorizontal, same(source));
        for (var r = 0; r < flipped.rowCount; r++) {
          for (var c = 0; c < flipped.colCount; c++) {
            expect(flipped.get(r, c), '(${source.rowCount - r - 1}, $c)');
            flipped.set(r, c, '${flipped.get(r, c)}*');
          }
        }
        for (var r = 0; r < source.rowCount; r++) {
          for (var c = 0; c < source.colCount; c++) {
            expect(source.get(r, c), '($r, $c)*');
          }
        }
      });
      test('flippedVertical', () {
        final source = Matrix.generate(
            DataType.string, 7, 6, (row, col) => '($row, $col)',
            format: format);
        final flipped = source.flippedVertical;
        expect(flipped.dataType, source.dataType);
        expect(flipped.rowCount, source.rowCount);
        expect(flipped.colCount, source.colCount);
        expect(flipped.storage, [source]);
        expect(flipped.flippedVertical, same(source));
        for (var r = 0; r < flipped.rowCount; r++) {
          for (var c = 0; c < flipped.colCount; c++) {
            expect(flipped.get(r, c), '($r, ${source.colCount - c - 1})');
            flipped.set(r, c, '${flipped.get(r, c)}*');
          }
        }
        for (var r = 0; r < source.rowCount; r++) {
          for (var c = 0; c < source.colCount; c++) {
            expect(source.get(r, c), '($r, $c)*');
          }
        }
      });
      group('rotated', () {
        test('0', () {
          final source = Matrix.generate(
              DataType.string, 2, 3, (row, col) => '($row, $col)',
              format: format);
          final rotated = source.rotated(count: 0);
          expect(rotated, same(source));
        });
        test('90', () {
          final source = Matrix.generate(
              DataType.string, 2, 3, (row, col) => '($row, $col)',
              format: format);
          final rotated = source.rotated();
          expect(rotated.dataType, source.dataType);
          expect(rotated.rowCount, source.colCount);
          expect(rotated.colCount, source.rowCount);
          expect(rotated.storage, [source]);
          for (var r = 0; r < rotated.rowCount; r++) {
            for (var c = 0; c < rotated.colCount; c++) {
              expect(rotated.get(r, c), '(${source.rowCount - c - 1}, $r)');
              rotated.set(r, c, '${rotated.get(r, c)}*');
            }
          }
          for (var r = 0; r < source.rowCount; r++) {
            for (var c = 0; c < source.colCount; c++) {
              expect(source.get(r, c), '($r, $c)*');
            }
          }
        });
        test('180', () {
          final source = Matrix.generate(
              DataType.string, 2, 3, (row, col) => '($row, $col)',
              format: format);
          final rotated = source.rotated(count: 2);
          expect(rotated.dataType, source.dataType);
          expect(rotated.rowCount, source.rowCount);
          expect(rotated.colCount, source.colCount);
          expect(rotated.storage, [source]);
          for (var r = 0; r < rotated.rowCount; r++) {
            for (var c = 0; c < rotated.colCount; c++) {
              expect(
                  rotated.get(r, c),
                  '(${source.rowCount - r - 1}, '
                  '${source.colCount - c - 1})');
              rotated.set(r, c, '${rotated.get(r, c)}*');
            }
          }
          for (var r = 0; r < source.rowCount; r++) {
            for (var c = 0; c < source.colCount; c++) {
              expect(source.get(r, c), '($r, $c)*');
            }
          }
        });
        test('270', () {
          final source = Matrix.generate(
              DataType.string, 2, 3, (row, col) => '($row, $col)',
              format: format);
          final rotated = source.rotated(count: 3);
          expect(rotated.dataType, source.dataType);
          expect(rotated.rowCount, source.colCount);
          expect(rotated.colCount, source.rowCount);
          expect(rotated.storage, [source]);
          for (var r = 0; r < rotated.rowCount; r++) {
            for (var c = 0; c < rotated.colCount; c++) {
              expect(rotated.get(r, c), '($c, ${source.colCount - r - 1})');
              rotated.set(r, c, '${rotated.get(r, c)}*');
            }
          }
          for (var r = 0; r < source.rowCount; r++) {
            for (var c = 0; c < source.colCount; c++) {
              expect(source.get(r, c), '($r, $c)*');
            }
          }
        });
        test('360', () {
          final source = Matrix.generate(
              DataType.string, 2, 3, (row, col) => '($row, $col)',
              format: format);
          final rotated = source.rotated(count: 4);
          expect(rotated, same(source));
        });
        test('repeat rotation', () {
          final source = Matrix.generate(
              DataType.string, 2, 3, (row, col) => '($row, $col)',
              format: format);
          final rotated = source.rotated().rotated();
          expect(
              rotated,
              isA<RotatedMatrix<String>>()
                  .having((matrix) => matrix.count, 'count', 2));
        });
        test('error', () {
          final source = Matrix.generate(
              DataType.string, 2, 3, (row, col) => '($row, $col)',
              format: format);
          final rotated = RotatedMatrix(source, 4);
          expect(() => rotated.get(0, 0), throwsArgumentError);
          expect(() => rotated.set(0, 0, '*'), throwsArgumentError);
        });
      });
      test('unmodifiable', () {
        final source = Matrix.generate(
            DataType.string, 2, 3, (row, col) => '($row, $col)',
            format: format);
        final readonly = source.unmodifiable;
        expect(readonly.dataType, source.dataType);
        expect(readonly.rowCount, 2);
        expect(readonly.colCount, 3);
        expect(readonly.storage, [source]);
        for (var r = 0; r < readonly.rowCount; r++) {
          for (var c = 0; c < readonly.colCount; c++) {
            expect(readonly.get(r, c), '($r, $c)');
            expect(() => readonly.set(r, c, '${readonly.get(r, c)}*'),
                throwsUnsupportedError);
          }
        }
        for (var r = 0; r < source.rowCount; r++) {
          for (var c = 0; c < source.colCount; c++) {
            source.set(r, c, '${source.get(r, c)}!');
          }
        }
        for (var r = 0; r < readonly.rowCount; r++) {
          for (var c = 0; c < readonly.colCount; c++) {
            expect(readonly.get(r, c), '($r, $c)!');
          }
        }
        expect(readonly.unmodifiable, readonly);
      });
      group('convolution', () {
        final matrix1 = Matrix.fromRows(DataType.int32, [
          [0, 2, 5, 9, 4],
          [1, 4, 8, 3, 8],
          [3, 7, 2, 7, 1],
          [6, 1, 6, 0, 3],
          [0, 5, 9, 2, 4],
        ]);
        final kernel1 = Matrix.fromRows(DataType.int32, [
          [1, 0, 0],
          [0, 0, 0],
          [0, 0, -1],
        ]);
        final matrix2 = Matrix.fromRows(DataType.float, [
          [1.0, 2.0, 3.0],
          [4.0, 5.0, 6.0],
          [7.0, 8.0, 9.0],
        ]);
        final kernel2 = Matrix.fromRows(DataType.float, [
          [-0.1, 0.2, -0.3],
          [0.4, -0.5, 0.6],
          [-0.7, 0.8, -0.9],
        ]);
        test('full', () {
          final result1 = matrix1.convolve(kernel1);
          expect(
              result1,
              isCloseTo(Matrix.fromRows(DataType.int32, [
                [0, 2, 5, 9, 4, 0, 0],
                [1, 4, 8, 3, 8, 0, 0],
                [3, 7, 2, 5, -4, -9, -4],
                [6, 1, 5, -4, -5, -3, -8],
                [0, 5, 6, -5, 2, -7, -1],
                [0, 0, -6, -1, -6, 0, -3],
                [0, 0, 0, -5, -9, -2, -4],
              ])));
          final result2 = matrix2.convolve(kernel2, mode: ConvolutionMode.full);
          expect(
              result2,
              isCloseTo(Matrix.fromRows(DataType.float, [
                [-0.1, 0.0, -0.2, 0.0, -0.9],
                [0.0, 0.6, 0.0, -0.6, 0.0],
                [0.2, 0.0, -0.5, 0.0, -1.8],
                [0.0, -0.6, 0.0, 0.6, 0.0],
                [-4.9, 0.0, -6.2, 0.0, -8.1],
              ])));
        });
        test('valid', () {
          final result1 =
              matrix1.convolve(kernel1, mode: ConvolutionMode.valid);
          expect(
              result1,
              isCloseTo(Matrix.fromRows(DataType.int32, [
                [2, 5, -4],
                [5, -4, -5],
                [6, -5, 2],
              ])));
          final result2 =
              matrix2.convolve(kernel2, mode: ConvolutionMode.valid);
          expect(
              result2,
              isCloseTo(Matrix.fromRows(DataType.float, [
                [-0.5],
              ])));
        });
        test('same', () {
          final result1 = matrix1.convolve(kernel1, mode: ConvolutionMode.same);
          expect(
              result1,
              isCloseTo(Matrix.fromRows(DataType.int32, [
                [4, 8, 3, 8, 0],
                [7, 2, 5, -4, -9],
                [1, 5, -4, -5, -3],
                [5, 6, -5, 2, -7],
                [0, -6, -1, -6, 0],
              ])));
          final result2 = matrix2.convolve(kernel2, mode: ConvolutionMode.same);
          expect(
              result2,
              isCloseTo(Matrix.fromRows(DataType.float, [
                [0.6, 0.0, -0.6],
                [0.0, -0.5, 0.0],
                [-0.6, 0.0, 0.6],
              ])));
        });
      });
    });
    group('iterables', () {
      group('forEach', () {
        test('empty', () {
          final source = Matrix(DataType.string, 0, 0, format: format);
          source.forEach((row, col, value) => fail('Should not be called'));
        });
        test('default', () {
          final source = Matrix(DataType.string, 5, 7, format: format);
          source.forEach((row, col, value) => fail('Should not be called'));
        });
        test('complete', () {
          final defined = <String>{};
          final source = Matrix.generate(DataType.string, 13, 17, (row, col) {
            final value = '$row*$col';
            defined.add(value);
            return value;
          }, format: format);
          source.forEach((row, col, value) {
            expect(value, '$row*$col');
            expect(defined.remove(value), isTrue);
          });
          expect(defined, isEmpty);
        });
        test('sparse', () {
          final defined = <String>{};
          final random = Random(73462);
          final source = Matrix.generate(DataType.string, 13, 17, (row, col) {
            if (random.nextDouble() < 0.2) {
              final value = '$row*$col';
              defined.add(value);
              return value;
            } else {
              return DataType.string.defaultValue;
            }
          }, format: format);
          source.forEach((row, col, value) {
            expect(value, '$row*$col');
            expect(defined.remove(value), isTrue);
          });
          expect(defined, isEmpty);
        });
      });
      test('rows', () {
        final source = Matrix.generate(pointType, 7, 5, (r, c) => Point(r, c),
            format: format);
        var r = 0;
        for (final row in source.rows) {
          expect(row.dataType, source.dataType);
          expect(row.count, source.colCount);
          expect(row.storage, [source]);
          for (var c = 0; c < source.colCount; c++) {
            expect(row[c], source.get(r, c));
          }
          r++;
        }
        expect(r, source.rowCount);
      });
      test('columns', () {
        final source = Matrix.generate(pointType, 5, 8, (r, c) => Point(r, c),
            format: format);
        var c = 0;
        for (final column in source.columns) {
          expect(column.dataType, source.dataType);
          expect(column.count, source.rowCount);
          expect(column.storage, [source]);
          for (var r = 0; r < source.rowCount; r++) {
            expect(column[r], source.get(r, c));
          }
          c++;
        }
        expect(c, source.colCount);
      });
      test('diagonals', () {
        final source = Matrix.generate(DataType.string, 3, 4, (r, c) => '$r,$c',
            format: format);
        final values = <List<String>>[];
        for (final diagonal in source.diagonals) {
          expect(diagonal.dataType, source.dataType);
          expect(diagonal.storage, [source]);
          values.add(diagonal.iterable.toList());
        }
        expect(values, [
          ['0,3'],
          ['0,2', '1,3'],
          ['0,1', '1,2', '2,3'],
          ['0,0', '1,1', '2,2'],
          ['1,0', '2,1'],
          ['2,0']
        ]);
      });
      group('spiral', () {
        test('3x2', () {
          final source = Matrix.generate(
              DataType.string, 3, 2, (r, c) => '$r,$c',
              format: format);
          expect(source.spiral, ['0,0', '0,1', '1,1', '2,1', '2,0', '1,0']);
        });
        test('2x3', () {
          final source = Matrix.generate(
              DataType.string, 2, 3, (r, c) => '$r,$c',
              format: format);
          expect(source.spiral, ['0,0', '0,1', '0,2', '1,2', '1,1', '1,0']);
        });
        test('3x3', () {
          final source = Matrix.generate(
              DataType.string, 3, 3, (r, c) => '$r,$c',
              format: format);
          expect(source.spiral,
              ['0,0', '0,1', '0,2', '1,2', '2,2', '2,1', '2,0', '1,0', '1,1']);
        });
      });
      group('zig-zag', () {
        test('3x2', () {
          final source = Matrix.generate(
              DataType.string, 3, 2, (r, c) => '$r,$c',
              format: format);
          expect(source.zigZag, ['0,0', '0,1', '1,0', '2,0', '1,1', '2,1']);
        });
        test('2x3', () {
          final source = Matrix.generate(
              DataType.string, 2, 3, (r, c) => '$r,$c',
              format: format);
          expect(source.zigZag, ['0,0', '0,1', '1,0', '1,1', '0,2', '1,2']);
        });
        test('3x3', () {
          final source = Matrix.generate(
              DataType.string, 3, 3, (r, c) => '$r,$c',
              format: format);
          expect(source.zigZag,
              ['0,0', '0,1', '1,0', '2,0', '1,1', '0,2', '1,2', '2,1', '2,2']);
        });
      });
      test('rowMajor', () {
        final source = Matrix.generate(DataType.string, 3, 2, (r, c) => '$r,$c',
            format: format);
        expect(source.rowMajor, ['0,0', '0,1', '1,0', '1,1', '2,0', '2,1']);
      });
      test('columnMajor', () {
        final source = Matrix.generate(DataType.string, 3, 2, (r, c) => '$r,$c',
            format: format);
        expect(source.columnMajor, ['0,0', '1,0', '2,0', '0,1', '1,1', '2,1']);
      });
    });
    group('testing', () {
      final random = Random(164593560);
      final identity8x9 =
          Matrix.identity(DataType.int32, 8, 9, value: 1, format: format);
      final identity9x8 =
          Matrix.identity(DataType.int32, 9, 8, value: 1, format: format);
      final identity8x8 =
          Matrix.identity(DataType.int32, 8, 8, value: 1, format: format);
      final fullAsymmetric = Matrix.generate(
          DataType.int32, 8, 8, (r, c) => random.nextInt(1000),
          format: format);
      final fullSymmetric = fullAsymmetric + fullAsymmetric.transposed;
      final lowerTriangle = Matrix.generate(
          DataType.int32, 8, 8, (r, c) => r >= c ? random.nextInt(1000) : 0,
          format: format);
      final upperTriangle = Matrix.generate(
          DataType.int32, 8, 8, (r, c) => r <= c ? random.nextInt(1000) : 0,
          format: format);
      test('isSquare', () {
        expect(identity8x9.isSquare, isFalse);
        expect(identity9x8.isSquare, isFalse);
        expect(identity8x8.isSquare, isTrue);
        expect(fullAsymmetric.isSquare, isTrue);
        expect(fullSymmetric.isSquare, isTrue);
        expect(lowerTriangle.isSquare, isTrue);
        expect(upperTriangle.isSquare, isTrue);
      });
      test('isSymmetric', () {
        expect(identity8x9.isSymmetric, isFalse);
        expect(identity9x8.isSymmetric, isFalse);
        expect(identity8x8.isSymmetric, isTrue);
        expect(fullAsymmetric.isSymmetric, isFalse);
        expect(fullSymmetric.isSymmetric, isTrue);
        expect(lowerTriangle.isSymmetric, isFalse);
        expect(upperTriangle.isSymmetric, isFalse);
      });
      test('isDiagonal', () {
        expect(identity8x9.isDiagonal, isTrue);
        expect(identity9x8.isDiagonal, isTrue);
        expect(identity8x8.isDiagonal, isTrue);
        expect(fullAsymmetric.isDiagonal, isFalse);
        expect(fullSymmetric.isDiagonal, isFalse);
        expect(lowerTriangle.isDiagonal, isFalse);
        expect(upperTriangle.isDiagonal, isFalse);
      });
      test('isLowerTriangular', () {
        expect(identity8x9.isLowerTriangular, isTrue);
        expect(identity9x8.isLowerTriangular, isTrue);
        expect(identity8x8.isLowerTriangular, isTrue);
        expect(fullAsymmetric.isLowerTriangular, isFalse);
        expect(fullSymmetric.isLowerTriangular, isFalse);
        expect(lowerTriangle.isLowerTriangular, isTrue);
        expect(upperTriangle.isLowerTriangular, isFalse);
      });
      test('isUpperTriangular', () {
        expect(identity8x9.isUpperTriangular, isTrue);
        expect(identity9x8.isUpperTriangular, isTrue);
        expect(identity8x8.isUpperTriangular, isTrue);
        expect(fullAsymmetric.isUpperTriangular, isFalse);
        expect(fullSymmetric.isUpperTriangular, isFalse);
        expect(lowerTriangle.isUpperTriangular, isFalse);
        expect(upperTriangle.isUpperTriangular, isTrue);
      });
    });
    group('operators', () {
      final random = Random(559756105);
      final sourceA = Matrix.generate(
          DataType.int32, 5, 4, (row, col) => random.nextInt(100),
          format: format);
      final sourceB = Matrix.generate(
          DataType.int32, 5, 4, (row, col) => random.nextInt(100),
          format: format);
      test('add', () {
        final result = sourceA + sourceB;
        expect(result.dataType, sourceA.dataType);
        expect(result.rowCount, sourceA.rowCount);
        expect(result.colCount, sourceA.colCount);
        for (var r = 0; r < result.rowCount; r++) {
          for (var c = 0; c < result.colCount; c++) {
            expect(result.get(r, c), sourceA.get(r, c) + sourceB.get(r, c));
          }
        }
      });
      group('apply', () {
        test('by row', () {
          final vector = Vector.generate(
              sourceA.dataType, sourceA.rowCount, (i) => random.nextInt(100),
              format: VectorFormat.standard);
          final target = sourceA.applyByRow(sourceA.dataType.field.add, vector);
          expect(target.dataType, sourceA.dataType);
          expect(target.rowCount, sourceA.rowCount);
          expect(target.colCount, sourceA.colCount);
          for (var r = 0; r < target.rowCount; r++) {
            for (var c = 0; c < target.colCount; c++) {
              expect(target.get(r, c), sourceA.get(r, c) + vector[r]);
            }
          }
          expect(
              () => sourceA.transposed
                  .applyByRow(sourceA.dataType.field.sub, vector),
              throwsArgumentError);
        });
        test('by column', () {
          final vector = Vector.generate(
              sourceA.dataType, sourceA.colCount, (i) => random.nextInt(100),
              format: VectorFormat.standard);
          final target =
              sourceA.applyByColumn(sourceA.dataType.field.mul, vector);
          expect(target.dataType, sourceA.dataType);
          expect(target.rowCount, sourceA.rowCount);
          expect(target.colCount, sourceA.colCount);
          for (var r = 0; r < target.rowCount; r++) {
            for (var c = 0; c < target.colCount; c++) {
              expect(target.get(r, c), sourceA.get(r, c) * vector[c]);
            }
          }
          expect(
              () => sourceA.transposed
                  .applyByColumn(sourceA.dataType.field.div, vector),
              throwsArgumentError);
        });
      });
      test('sub', () {
        final target = sourceA - sourceB;
        expect(target.dataType, sourceA.dataType);
        expect(target.rowCount, sourceA.rowCount);
        expect(target.colCount, sourceA.colCount);
        for (var r = 0; r < target.rowCount; r++) {
          for (var c = 0; c < target.colCount; c++) {
            expect(target.get(r, c), sourceA.get(r, c) - sourceB.get(r, c));
          }
        }
      });
      test('neg', () {
        final target = -sourceA;
        expect(target.dataType, sourceA.dataType);
        expect(target.rowCount, sourceA.rowCount);
        expect(target.colCount, sourceA.colCount);
        for (var r = 0; r < target.rowCount; r++) {
          for (var c = 0; c < target.colCount; c++) {
            expect(target.get(r, c), -sourceA.get(r, c));
          }
        }
      });
      group('compare', () {
        test('identity', () {
          expect(sourceA.compare(sourceA), isTrue);
          expect(sourceB.compare(sourceB), isTrue);
          expect(sourceA.compare(sourceB), isFalse);
          expect(sourceB.compare(sourceA), isFalse);
        });
        test('views', () {
          expect(sourceA.rowRange(0, 3).compare(sourceA.rowIndex([0, 1, 2])),
              isTrue);
          expect(sourceA.colRange(0, 3).compare(sourceA.colIndex([0, 1, 2])),
              isTrue);
          expect(sourceA.rowRange(0, 3).compare(sourceA.rowIndex([3, 1, 0])),
              isFalse,
              reason: 'row order mismatch');
          expect(sourceA.colRange(0, 3).compare(sourceA.colIndex([2, 1, 0])),
              isFalse,
              reason: 'col order mismatch');
          expect(
              sourceA.rowRange(0, 3).compare(sourceA.rowIndex([0, 1])), isFalse,
              reason: 'row count mismatch');
          expect(
              sourceA.colRange(0, 3).compare(sourceA.colIndex([0, 1])), isFalse,
              reason: 'col count mismatch');
        });
        test('custom', () {
          final negated = -sourceA;
          expect(sourceA.compare(negated), isFalse);
          expect(sourceA.compare(negated, equals: (a, b) => a == -b), isTrue);
        });
      });
      group('lerp', () {
        final v0 = Matrix.fromRows(
            DataType.float32,
            [
              [1.0, 6.0],
              [9.0, 9.0],
            ],
            format: format);
        final v1 = Matrix.fromRows(
            DataType.float32,
            [
              [9.0, -2.0],
              [9.0, -9.0],
            ],
            format: format);
        test('at start', () {
          final v = v0.lerp(v1, 0.0);
          expect(v.dataType, v0.dataType);
          expect(v.rowCount, v0.rowCount);
          expect(v.colCount, v0.colCount);
          expect(v.get(0, 0), 1.0);
          expect(v.get(0, 1), 6.0);
          expect(v.get(1, 0), 9.0);
          expect(v.get(1, 1), 9.0);
        });
        test('at middle', () {
          final v = v0.lerp(v1, 0.5);
          expect(v.dataType, v0.dataType);
          expect(v.rowCount, v0.rowCount);
          expect(v.colCount, v0.colCount);
          expect(v.get(0, 0), 5.0);
          expect(v.get(0, 1), 2.0);
          expect(v.get(1, 0), 9.0);
          expect(v.get(1, 1), 0.0);
        });
        test('at end', () {
          final v = v0.lerp(v1, 1.0);
          expect(v.dataType, v0.dataType);
          expect(v.rowCount, v0.rowCount);
          expect(v.colCount, v0.colCount);
          expect(v.get(0, 0), 9.0);
          expect(v.get(0, 1), -2.0);
          expect(v.get(1, 0), 9.0);
          expect(v.get(1, 1), -9.0);
        });
        test('at outside', () {
          final v = v0.lerp(v1, 2.0);
          expect(v.dataType, v0.dataType);
          expect(v.rowCount, v0.rowCount);
          expect(v.colCount, v0.colCount);
          expect(v.get(0, 0), 17.0);
          expect(v.get(0, 1), -10.0);
          expect(v.get(1, 0), 9.0);
          expect(v.get(1, 1), -27.0);
        });
      });
      group('mul', () {
        final matrixA = Matrix.generate(
            DataType.int32, 13, 42, (row, col) => random.nextInt(100),
            format: format);
        final matrixB = Matrix.generate(
            DataType.int32, 42, 27, (row, col) => random.nextInt(100),
            format: format);
        final vectorB = Vector.generate(
            DataType.int32, matrixA.colCount, (i) => random.nextInt(100),
            format: VectorFormat.standard);
        group('matrix', () {
          test('operator', () {
            final target = matrixA * matrixB;
            expect(target.dataType, DataType.int32);
            expect(target.rowCount, matrixA.rowCount);
            expect(target.colCount, matrixB.colCount);
            for (var r = 0; r < target.rowCount; r++) {
              for (var c = 0; c < target.colCount; c++) {
                final value = matrixA.row(r).dot(matrixB.column(c));
                expect(target.get(r, c), value);
              }
            }
          });
          test('primitive', () {
            final target = matrixA.mulMatrix(matrixB);
            expect(target.dataType, DataType.int32);
            expect(target.rowCount, matrixA.rowCount);
            expect(target.colCount, matrixB.colCount);
            for (var r = 0; r < target.rowCount; r++) {
              for (var c = 0; c < target.colCount; c++) {
                final value = matrixA.row(r).dot(matrixB.column(c));
                expect(target.get(r, c), value);
              }
            }
          });
        });
        group('vector', () {
          test('operator', () {
            final result = matrixA * vectorB;
            for (var i = 0; i < result.rowCount; i++) {
              expect(result.get(i, 0), matrixA.row(i).dot(vectorB));
            }
          });
          test('primitive', () {
            final result = matrixA.mulVector(vectorB);
            for (var i = 0; i < result.count; i++) {
              expect(result[i], matrixA.row(i).dot(vectorB));
            }
          });
        });
        group('scalar', () {
          test('operator', () {
            final target = matrixA * 2;
            expect(target.dataType, matrixA.dataType);
            expect(target.rowCount, matrixA.rowCount);
            expect(target.colCount, matrixA.colCount);
            for (var r = 0; r < target.rowCount; r++) {
              for (var c = 0; c < target.colCount; c++) {
                expect(target.get(r, c), 2 * matrixA.get(r, c));
              }
            }
          });
          test('primitive', () {
            final target = matrixA.mulScalar(2);
            expect(target.dataType, matrixA.dataType);
            expect(target.rowCount, matrixA.rowCount);
            expect(target.colCount, matrixA.colCount);
            for (var r = 0; r < target.rowCount; r++) {
              for (var c = 0; c < target.colCount; c++) {
                expect(target.get(r, c), 2 * matrixA.get(r, c));
              }
            }
          });
        });
      });
    });
    group('decomposition', () {
      final epsilon = pow(2.0, -32.0);
      // Example matrices:
      final matrix3 = Matrix.fromRows(
          DataType.float64,
          [
            [1.0, 4.0, 7.0, 10.0],
            [2.0, 5.0, 8.0, 11.0],
            [3.0, 6.0, 9.0, 12.0],
          ],
          format: format);
      final matrix4 = Matrix.fromRows(
          DataType.float64,
          [
            [1.0, 5.0, 9.0],
            [2.0, 6.0, 10.0],
            [3.0, 7.0, 11.0],
            [4.0, 8.0, 12.0],
          ],
          format: format);
      final matrix3int = Matrix.fromRows(
          DataType.int32,
          [
            [1, 4, 7, 10],
            [2, 5, 8, 11],
            [3, 6, 9, 12],
          ],
          format: format);
      test('norm1', () {
        final result = matrix3.norm1;
        expect(result, isCloseTo(33.0, epsilon: epsilon));
      });
      test('norm1 (int)', () {
        final result = matrix3int.norm1;
        expect(result, 33);
      });
      test('norm2', () {
        final result = matrix3.norm2;
        expect(result, isCloseTo(25.46240743603639, epsilon: epsilon));
      });
      test('normInfinity', () {
        final result = matrix3.normInfinity;
        expect(result, isCloseTo(30.0, epsilon: epsilon));
      });
      test('normInfinity (int)', () {
        final result = matrix3int.normInfinity;
        expect(result, 30);
      });
      test('normFrobenius', () {
        final result = matrix3.normFrobenius;
        expect(result, isCloseTo(sqrt(650), epsilon: epsilon));
      });
      test('trace', () {
        final result = matrix3.trace;
        expect(result, isCloseTo(15.0, epsilon: epsilon));
      });
      test('trace (int)', () {
        final result = matrix3int.trace;
        expect(result, 15);
      });
      test('det', () {
        final result =
            matrix3.range(0, matrix3.rowCount, 0, matrix3.rowCount).det;
        expect(result, isCloseTo(0.0, epsilon: epsilon));
      });
      group('QR Decomposition', () {
        final decomp = matrix4.qr;
        test('isFullRank', () {
          final result = decomp.isFullRank;
          expect(result, isTrue);
        });
        test('householder', () {
          final result = decomp.householder;
          expect(result.isLowerTriangular, isTrue);
        });
        test('orthogonal', () {
          final result = decomp.orthogonal * decomp.upper;
          expect(result, isCloseTo(matrix4, epsilon: epsilon));
        });
        test('upper', () {
          final result = decomp.upper;
          expect(result.isUpperTriangular, isTrue);
        });
        test('solve', () {
          final first = Matrix<double>.fromRows(
              DataType.float64,
              [
                [5, 8],
                [6, 9],
              ],
              format: format);
          final second = Matrix<double>.fromRows(
              DataType.float64,
              [
                [13],
                [15],
              ],
              format: format);
          final actual = first.qr.solve(second);
          final expected = Matrix<double>.constant(
              DataType.float64, second.rowCount, second.colCount,
              value: 1);
          expect(actual, isCloseTo(expected, epsilon: epsilon));
        });
      });
      group('Singluar value decomposition', () {
        Matrix<double> random(int rows, int cols, int seed) {
          final m = Matrix(DataType.float64, rows, cols, format: format);
          const normal = NormalDistribution(0.0, 1.0);
          final random = Random(seed);
          for (var r = 0; r < m.rowCount; r++) {
            for (var c = 0; c < m.colCount; c++) {
              m.set(r, c, normal.sample(random: random));
            }
          }
          return m;
        }

        test('can factorize identity', () {
          final orders = [1, 10, 100];

          for (var i = 0; i < orders.length; i++) {
            var order = orders[i];
            var matrixI =
                Matrix.identity(DataType.float64, order, order, format: format);
            var factorSvd = matrixI.singularValueDecomposition();
            var u = factorSvd.U;
            var vt = factorSvd.VT;
            var w = factorSvd.W;

            expect(matrixI.rowCount, u.rowCount);
            expect(matrixI.rowCount, u.colCount);

            expect(matrixI.colCount, vt.rowCount);
            expect(matrixI.colCount, vt.colCount);

            expect(matrixI.rowCount, w.rowCount);
            expect(matrixI.colCount, w.colCount);

            for (var i = 0; i < w.rowCount; i++) {
              for (var j = 0; j < w.colCount; j++) {
                expect(i == j ? 1.0 : 0.0, w.getUnchecked(i, j));
              }
            }
          }
        });
        test('A = USV*', () {
          final decomp = matrix4.singularValueDecomposition();
          final result = decomp.U * (decomp.W * decomp.VT);
          expect(result, isCloseTo(matrix4, epsilon: epsilon));
        });
        test('A = USV* for random', () {
          var rows = [1, 4, 8, 9, 10, 45];
          var cols = [1, 4, 8, 10, 9, 50];

          for (var k = 0; k < rows.length; k++) {
            final m = random(rows[k], cols[k], 5);
            final decomp = m.singularValueDecomposition();

            final uu = decomp.U * decomp.U.transposed;
            var I = Matrix<double>.identity(
                DataType.float64, uu.rowCount, uu.colCount);
            expect(uu, isCloseTo(I, epsilon: epsilon));

            final vv = decomp.VT.transposed * decomp.VT;
            I = Matrix<double>.identity(
                DataType.float64, vv.rowCount, vv.colCount);
            expect(vv, isCloseTo(I, epsilon: epsilon));

            final result = decomp.U * (decomp.W * decomp.VT);
            expect(result.rowCount, m.rowCount);
            expect(result.colCount, m.colCount);
            expect(result, isCloseTo(m, epsilon: epsilon));
          }
        });
        test('rank accepatance', () {
          final m = Matrix.fromRows(
              DataType.float64,
              [
                [4.0, 4.0, 1.0, 3.0],
                [1.0, -2.0, 1.0, 0.0],
                [4.0, 0.0, 2.0, 2.0],
                [7.0, 6.0, 2.0, 5.0]
              ],
              format: format);
          var svd = m.singularValueDecomposition();
          expect(svd.rank, 2);
        });
        test('rank of square', () {
          final orders = [10, 50, 100];

          for (var i = 0; i < orders.length; i++) {
            final order = orders[i];
            final matrixA = random(order, order, 5);
            final factorSvd = matrixA.singularValueDecomposition();
            if (factorSvd.determinant != 0) {
              expect(factorSvd.rank, order);
            } else {
              expect(factorSvd.rank, order - 1);
            }
          }
        });
        test('rank of square singular', () {
          final orders = [10, 50, 100];
          for (var i = 0; i < orders.length; i++) {
            final order = orders[0];
            final matrixA =
                Matrix(DataType.float64, order, order, format: format);
            matrixA.set(0, 0, 1);
            matrixA.set(order - 1, order - 1, 1);
            for (var i = 1; i < order - 1; i++) {
              matrixA.set(i, i - 1, 1);
              matrixA.set(i, i + 1, 1);
              matrixA.set(i - 1, i, 1);
              matrixA.set(i + 1, i, 1);
            }
            final factorSvd = matrixA.singularValueDecomposition();
            expect(factorSvd.determinant, 0);
            expect(factorSvd.rank, order - 1);
          }
        });
        test('can solve for random matrix', () {
          final rows = [1, 4, 7, 10, 45, 80, 100];
          final cols = [1, 4, 8, 10, 50, 100, 90];

          for (var k = 0; k < rows.length; k++) {
            final matrixA = random(rows[k], cols[k], 5);
            final matrixB = random(rows[k], cols[k], 5);

            final factorSvd = matrixA.singularValueDecomposition();
            final matrixX = factorSvd.solve(matrixB) as Matrix<double>;

            // The solution X row dimension is equal to the column dimension of A
            expect(matrixA.colCount, matrixX.rowCount);

            // The solution X has the same number of columns as B
            expect(matrixB.colCount, matrixX.colCount);

            // Check the reconstruction.
            final matrixBReconstruct = matrixA * matrixX;
            expect(matrixB, isCloseTo(matrixBReconstruct, epsilon: 1E-10));
          }
        });
      });
      test('LU Decomposition', () {
        final matrix =
            matrix4.range(0, matrix4.colCount - 1, 0, matrix4.colCount - 1);
        final decomp = matrix.lu;
        final result1 = matrix.rowIndex(decomp.pivot);
        final result2 = decomp.lower * decomp.upper;
        expect(result2, isCloseTo(result1, epsilon: epsilon));
      });
      test('rank', () {
        final result = matrix3.rank;
        expect(result, min(matrix3.rowCount, matrix3.colCount) - 1);
      });
      test('cond', () {
        final matrix = Matrix.fromRows(
            DataType.float64,
            [
              [1.0, 3.0],
              [7.0, 9.0],
            ],
            format: format);
        final decomp = matrix.singularValueDecomposition();
        final singularValues = decomp.S;
        expect(
            matrix.conditionNumber,
            singularValues[0] /
                singularValues[min(matrix.rowCount, matrix.colCount) - 1]);
      });
      test('inverse', () {
        final matrix = Matrix.fromRows(
            DataType.float64,
            [
              [0.0, 5.0, 9.0],
              [2.0, 6.0, 10.0],
              [3.0, 7.0, 11.0],
            ],
            format: format);
        final actual = matrix * matrix.inverse;
        final expected =
            Matrix.identity(DataType.float64, matrix.rowCount, matrix.colCount);
        expect(actual, isCloseTo(expected, epsilon: epsilon));
      });
      test('solve', () {
        final first = Matrix<double>.fromRows(
            DataType.float64,
            [
              [5, 8],
              [6, 9],
            ],
            format: format);
        final second = Matrix<double>.fromRows(
            DataType.float64,
            [
              [13],
              [15],
            ],
            format: format);
        final actual = first.solve(second);
        final expected = Matrix<double>.constant(
            DataType.float64, second.rowCount, second.colCount,
            value: 1);
        expect(actual, isCloseTo(expected, epsilon: epsilon));
      });
      test('solveTranspose', () {
        final first = Matrix<double>.fromRows(
            DataType.float64,
            [
              [5, 6],
              [8, 9],
            ],
            format: format);
        final second = Matrix<double>.fromRows(
            DataType.float64,
            [
              [13, 15],
            ],
            format: format);
        final actual = first.solveTranspose(second);
        final expected = Matrix<double>.constant(
            DataType.float64, second.rowCount, second.colCount,
            value: 1);
        expect(actual, isCloseTo(expected, epsilon: epsilon));
      });
      group('choleski', () {
        final matrix = Matrix<double>.fromRows(
            DataType.float64,
            [
              [4, 1, 1],
              [1, 2, 3],
              [1, 3, 6],
            ],
            format: format);
        final decomposition = matrix.cholesky;
        test('isSymmetricPositiveDefinite', () {
          final isSPD = decomposition.isSymmetricPositiveDefinite;
          expect(isSPD, isTrue);
        });
        test('triangular factor', () {
          final triangularFactor = decomposition.L;
          expect(triangularFactor * triangularFactor.transposed,
              isCloseTo(matrix, epsilon: epsilon));
        });
        test('solve', () {
          final identity = Matrix<double>.identity(DataType.float64, 3, 3,
              value: 1, format: format);
          final solution = decomposition.solve(identity);
          expect(matrix * solution, isCloseTo(identity, epsilon: epsilon));
        });
      });
      group('eigen', () {
        test('symmetric', () {
          final a = Matrix.fromRows(
              DataType.float64,
              [
                [4.0, 1.0, 1.0],
                [1.0, 2.0, 3.0],
                [1.0, 3.0, 6.0],
              ],
              format: format);
          final decomposition = a.eigenvalue;
          final d = decomposition.D;
          final v = decomposition.V;
          expect(v * d, isCloseTo(a * v, epsilon: epsilon));
        });
        test('non-symmetric', () {
          final a = Matrix.fromRows(
              DataType.float64,
              [
                [0.0, 1.0, 0.0, 0.0],
                [1.0, 0.0, 2.0e-7, 0.0],
                [0.0, -2.0e-7, 0.0, 1.0],
                [0.0, 0.0, 1.0, 0.0],
              ],
              format: format);
          final decomposition = a.eigenvalue;
          final d = decomposition.D;
          final v = decomposition.V;
          expect(v * d, isCloseTo(a * v, epsilon: epsilon));
        });
        test('bad', () {
          final a = Matrix.fromRows(
              DataType.float64,
              [
                [0.0, 0.0, 0.0, 0.0, 0.0],
                [0.0, 0.0, 0.0, 0.0, 1.0],
                [0.0, 0.0, 0.0, 1.0, 0.0],
                [1.0, 1.0, 0.0, 0.0, 1.0],
                [1.0, 0.0, 1.0, 0.0, 1.0],
              ],
              format: format);
          final decomposition = a.eigenvalue;
          final d = decomposition.D;
          final v = decomposition.V;
          expect(v * d, isCloseTo(a * v, epsilon: epsilon));
        });
      });
    });
  });
}

void main() {
  matrixTest('rowMajor', MatrixFormat.rowMajor);
  matrixTest('columnMajor', MatrixFormat.columnMajor);
  matrixTest('nestedRow', MatrixFormat.nestedRow);
  matrixTest('nestedColumn', MatrixFormat.nestedColumn);
  matrixTest('compressedRow', MatrixFormat.compressedRow);
  matrixTest('compressedColumn', MatrixFormat.compressedColumn);
  matrixTest('coordinateList', MatrixFormat.coordinateList);
  matrixTest('keyed', MatrixFormat.keyed);
  matrixTest('diagonal', MatrixFormat.diagonal);
}
