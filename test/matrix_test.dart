library data.test.matrix;

import 'dart:math';

import 'package:data/matrix.dart';
import 'package:data/type.dart';
import 'package:data/vector.dart' show Vector;
import 'package:test/test.dart';

void matrixTest(String name, Builder builder) {
  group(name, () {
    group('builder', () {
      test('call', () {
        final matrix = builder.withType(DataType.int8)(4, 5);
        expect(matrix.dataType, DataType.int8);
        expect(matrix.rowCount, 4);
        expect(matrix.colCount, 5);
        for (var row = 0; row < matrix.rowCount; row++) {
          for (var col = 0; col < matrix.colCount; col++) {
            expect(matrix.get(row, col), 0);
          }
        }
      });
      test('constant', () {
        final matrix = builder.withType(DataType.int8).constant(5, 6, 123);
        expect(matrix.dataType, DataType.int8);
        expect(matrix.rowCount, 5);
        expect(matrix.colCount, 6);
        for (var row = 0; row < matrix.rowCount; row++) {
          for (var col = 0; col < matrix.colCount; col++) {
            expect(matrix.get(row, col), 123);
          }
        }
      });
      test('identity', () {
        final matrix = builder.withType(DataType.int8).identity(6, -1);
        expect(matrix.dataType, DataType.int8);
        expect(matrix.rowCount, 6);
        expect(matrix.colCount, 6);
        for (var row = 0; row < matrix.rowCount; row++) {
          for (var col = 0; col < matrix.colCount; col++) {
            expect(matrix.get(row, col), row == col ? -1 : 0);
          }
        }
      });
      test('generate', () {
        final matrix = builder
            .withType(DataType.string)
            .generate(7, 8, (row, col) => '($row, $col)');
        expect(matrix.dataType, DataType.string);
        expect(matrix.rowCount, 7);
        expect(matrix.colCount, 8);
        for (var row = 0; row < matrix.rowCount; row++) {
          for (var col = 0; col < matrix.colCount; col++) {
            expect(matrix.get(row, col), '($row, $col)');
          }
        }
      });
      test('transform', () {
        final source = builder
            .withType(DataType.object)
            .generate(8, 7, (row, col) => Point(row, col));
        final matrix = builder
            .withType(DataType.string)
            .transform(source, (row, col, value) => '($row, $col): $value');
        expect(matrix.dataType, DataType.string);
        expect(matrix.rowCount, 8);
        expect(matrix.colCount, 7);
        for (var row = 0; row < matrix.rowCount; row++) {
          for (var col = 0; col < matrix.colCount; col++) {
            expect(matrix.get(row, col), '($row, $col): Point($row, $col)');
          }
        }
      });
      test('fromMatrix', () {
        final source = builder
            .withType(DataType.string)
            .generate(5, 6, (row, col) => '($row, $col)');
        final matrix = builder.withType(DataType.string).fromMatrix(source);
        expect(matrix.dataType, DataType.string);
        expect(matrix.rowCount, 5);
        expect(matrix.colCount, 6);
        for (var row = 0; row < source.rowCount; row++) {
          for (var col = 0; col < source.colCount; col++) {
            expect(matrix.get(row, col), '($row, $col)');
          }
        }
      });
      test('fromVectorRow', () {
        final source =
            Vector.builder.withType(DataType.int8).fromList([2, 5, 6]);
        final matrix = builder.withType(DataType.int16).fromVectorRow(source);
        expect(matrix.dataType, DataType.int16);
        expect(matrix.rowCount, 1);
        expect(matrix.colCount, 3);
        for (var row = 0; row < matrix.rowCount; row++) {
          for (var col = 0; col < matrix.colCount; col++) {
            expect(matrix.get(row, col), source[col]);
          }
        }
      });
      test('fromVectorColumn', () {
        final source =
            Vector.builder.withType(DataType.int8).fromList([2, 5, 6]);
        final matrix =
            builder.withType(DataType.int16).fromVectorColumn(source);
        expect(matrix.dataType, DataType.int16);
        expect(matrix.rowCount, 3);
        expect(matrix.colCount, 1);
        for (var row = 0; row < matrix.rowCount; row++) {
          for (var col = 0; col < matrix.colCount; col++) {
            expect(matrix.get(row, col), source[row]);
          }
        }
      });
      test('fromVectorDiagonal', () {
        final source =
            Vector.builder.withType(DataType.int8).fromList([2, 5, 6]);
        final matrix =
            builder.withType(DataType.int16).fromVectorDiagonal(source);
        expect(matrix.dataType, DataType.int16);
        expect(matrix.rowCount, 3);
        expect(matrix.colCount, 3);
        for (var row = 0; row < matrix.rowCount; row++) {
          for (var col = 0; col < matrix.colCount; col++) {
            expect(matrix.get(row, col), row == col ? source[row] : 0);
          }
        }
      });
      test('fromRanges', () {
        final source = builder
            .withType(DataType.string)
            .generate(5, 6, (row, col) => '($row, $col)');
        final matrix =
            builder.withType(DataType.string).fromRanges(source, 1, 4, 3, 5);
        expect(matrix.dataType, DataType.string);
        expect(matrix.rowCount, 3);
        expect(matrix.colCount, 2);
        expect(matrix.get(0, 0), '(1, 3)');
        expect(matrix.get(0, 1), '(1, 4)');
        expect(matrix.get(1, 0), '(2, 3)');
        expect(matrix.get(1, 1), '(2, 4)');
        expect(matrix.get(2, 0), '(3, 3)');
        expect(matrix.get(2, 1), '(3, 4)');
      });
      test('fromRangeAndIndices', () {
        final source = builder
            .withType(DataType.string)
            .generate(5, 6, (row, col) => '($row, $col)');
        final matrix = builder
            .withType(DataType.string)
            .fromRangeAndIndices(source, 1, 3, [0, 0, 5]);
        expect(matrix.dataType, DataType.string);
        expect(matrix.rowCount, 2);
        expect(matrix.colCount, 3);
        expect(matrix.get(0, 0), '(1, 0)');
        expect(matrix.get(0, 1), '(1, 0)');
        expect(matrix.get(0, 2), '(1, 5)');
        expect(matrix.get(1, 0), '(2, 0)');
        expect(matrix.get(1, 1), '(2, 0)');
        expect(matrix.get(1, 2), '(2, 5)');
      });
      test('fromIndicesAndRanges', () {
        final source = builder
            .withType(DataType.string)
            .generate(5, 6, (row, col) => '($row, $col)');
        final matrix = builder
            .withType(DataType.string)
            .fromIndicesAndRange(source, [0, 4, 0], 1, 3);
        expect(matrix.dataType, DataType.string);
        expect(matrix.rowCount, 3);
        expect(matrix.colCount, 2);
        expect(matrix.get(0, 0), '(0, 1)');
        expect(matrix.get(0, 1), '(0, 2)');
        expect(matrix.get(1, 0), '(4, 1)');
        expect(matrix.get(1, 1), '(4, 2)');
        expect(matrix.get(2, 0), '(0, 1)');
        expect(matrix.get(2, 1), '(0, 2)');
      });
      test('fromIndices', () {
        final source = builder
            .withType(DataType.string)
            .generate(5, 6, (row, col) => '($row, $col)');
        final matrix = builder
            .withType(DataType.string)
            .fromIndices(source, [3, 2, 2], [1, 0]);
        expect(matrix.dataType, DataType.string);
        expect(matrix.rowCount, 3);
        expect(matrix.colCount, 2);
        expect(matrix.get(0, 0), '(3, 1)');
        expect(matrix.get(0, 1), '(3, 0)');
        expect(matrix.get(1, 0), '(2, 1)');
        expect(matrix.get(1, 1), '(2, 0)');
        expect(matrix.get(2, 0), '(2, 1)');
        expect(matrix.get(2, 1), '(2, 0)');
      });
      test('fromRows', () {
        final matrix = builder.withType(DataType.int8).fromRows([
          [1, 2, 3],
          [4, 5, 6],
        ]);
        expect(matrix.dataType, DataType.int8);
        expect(matrix.rowCount, 2);
        expect(matrix.colCount, 3);
        expect(matrix.get(0, 0), 1);
        expect(matrix.get(1, 0), 4);
        expect(matrix.get(0, 1), 2);
        expect(matrix.get(1, 1), 5);
        expect(matrix.get(0, 2), 3);
        expect(matrix.get(1, 2), 6);
      });
      test('fromCols', () {
        final matrix = builder.withType(DataType.int8).fromCols([
          [1, 2, 3],
          [4, 5, 6],
        ]);
        expect(matrix.dataType, DataType.int8);
        expect(matrix.rowCount, 3);
        expect(matrix.colCount, 2);
        expect(matrix.get(0, 0), 1);
        expect(matrix.get(1, 0), 2);
        expect(matrix.get(2, 0), 3);
        expect(matrix.get(0, 1), 4);
        expect(matrix.get(1, 1), 5);
        expect(matrix.get(2, 1), 6);
      });
    });
    group('accessing', () {
      final matrix = builder.withType(DataType.int8).fromRows([
        [1, 2, 3],
        [4, 5, 6],
      ]);
      test('random order', () {
        final matrix = builder(8, 12);
        final points = <Point>[];
        for (var row = 0; row < matrix.rowCount; row++) {
          for (var col = 0; col < matrix.colCount; col++) {
            points.add(Point(row, col));
          }
        }
        // add values
        points.shuffle();
        for (var point in points) {
          matrix.set(point.x, point.y, point);
        }
        for (var row = 0; row < matrix.rowCount; row++) {
          for (var col = 0; col < matrix.colCount; col++) {
            expect(matrix.get(row, col), Point(row, col));
          }
        }
        // update values
        points.shuffle();
        for (var point in points) {
          matrix.set(point.x, point.y, Point(point.x + 1, point.y + 1));
        }
        for (var row = 0; row < matrix.rowCount; row++) {
          for (var col = 0; col < matrix.colCount; col++) {
            expect(matrix.get(row, col), Point(row + 1, col + 1));
          }
        }
        // remove values
        points.shuffle();
        for (var point in points) {
          matrix.set(point.x, point.y, matrix.dataType.nullValue);
        }
        for (var row = 0; row < matrix.rowCount; row++) {
          for (var col = 0; col < matrix.colCount; col++) {
            expect(matrix.get(row, col), matrix.dataType.nullValue);
          }
        }
      });
      test('read (out of bounds)', () {
        expect(() => matrix.get(-1, 0), throwsRangeError);
        expect(() => matrix.get(0, -1), throwsRangeError);
        expect(() => matrix.get(matrix.rowCount, 0), throwsRangeError);
        expect(() => matrix.get(0, matrix.colCount), throwsRangeError);
      });
      test('write (out of bounds)', () {
        expect(() => matrix.set(-1, 0, 0), throwsRangeError);
        expect(() => matrix.set(0, -1, 0), throwsRangeError);
        expect(() => matrix.set(matrix.rowCount, 0, 0), throwsRangeError);
        expect(() => matrix.set(0, matrix.colCount, 0), throwsRangeError);
      });
      test('toString', () {
        expect(
            matrix.toString(),
            '${matrix.runtimeType}[${matrix.rowCount}, ${matrix.colCount}]:\n'
            '  1  2  3\n'
            '  4  5  6');
      });
    });
    group('views', () {
      test('row', () {
        final matrix = builder
            .withType(DataType.string)
            .generate(4, 5, (r, c) => '($r, $c)');
        for (var r = 0; r < matrix.rowCount; r++) {
          final row = matrix.row(r);
          expect(row.dataType, matrix.dataType);
          for (var c = 0; c < matrix.colCount; c++) {
            expect(row[c], '($r, $c)');
            row[c] += '*';
          }
          expect(() => row[-1], throwsRangeError);
          expect(() => row[matrix.colCount], throwsRangeError);
          expect(() => row[-1] += '*', throwsRangeError);
          expect(() => row[matrix.colCount] += '*', throwsRangeError);
        }
        expect(() => matrix.row(-1), throwsRangeError);
        expect(() => matrix.row(4), throwsRangeError);
        for (var row = 0; row < matrix.rowCount; row++) {
          for (var col = 0; col < matrix.colCount; col++) {
            expect(matrix.get(row, col), '($row, $col)*');
          }
        }
      });
      test('column', () {
        final matrix = builder
            .withType(DataType.string)
            .generate(5, 4, (r, c) => '($r, $c)');
        for (var c = 0; c < matrix.colCount; c++) {
          final column = matrix.column(c);
          expect(column.dataType, matrix.dataType);
          for (var r = 0; r < matrix.rowCount; r++) {
            expect(column[r], '($r, $c)');
            column[r] += '*';
          }
          expect(() => column[-1], throwsRangeError);
          expect(() => column[matrix.rowCount], throwsRangeError);
          expect(() => column[-1] += '*', throwsRangeError);
          expect(() => column[matrix.rowCount] += '*', throwsRangeError);
        }
        expect(() => matrix.column(-1), throwsRangeError);
        expect(() => matrix.column(4), throwsRangeError);
        for (var row = 0; row < matrix.rowCount; row++) {
          for (var col = 0; col < matrix.colCount; col++) {
            expect(matrix.get(row, col), '($row, $col)*');
          }
        }
      });
      group('diagonal', () {
        test('vertical', () {
          final matrix = builder
              .withType(DataType.string)
              .generate(2, 3, (row, col) => '($row, $col)');
          final offsets = {
            1: ['(1, 0)'],
            0: ['(0, 0)', '(1, 1)'],
            -1: ['(0, 1)', '(1, 2)'],
            -2: ['(0, 2)'],
          };
          for (var offset in offsets.keys) {
            final expected = offsets[offset];
            final diagonal = matrix.diagonal(offset);
            expect(diagonal.dataType, matrix.dataType);
            expect(diagonal.count, expected.length);
            for (var i = 0; i < expected.length; i++) {
              expect(diagonal[i], expected[i]);
              diagonal[i] += '*';
            }
          }
          expect(() => matrix.diagonal(2), throwsRangeError);
          expect(() => matrix.diagonal(-3), throwsRangeError);
          for (var row = 0; row < matrix.rowCount; row++) {
            for (var col = 0; col < matrix.colCount; col++) {
              expect(matrix.get(row, col), '($row, $col)*');
            }
          }
        });
        test('horizontal', () {
          final matrix = builder
              .withType(DataType.string)
              .generate(3, 2, (row, col) => '($row, $col)');
          final offsets = {
            2: ['(2, 0)'],
            1: ['(1, 0)', '(2, 1)'],
            0: ['(0, 0)', '(1, 1)'],
            -1: ['(0, 1)'],
          };
          for (var offset in offsets.keys) {
            final expected = offsets[offset];
            final diagonal = matrix.diagonal(offset);
            expect(diagonal.dataType, matrix.dataType);
            expect(diagonal.count, expected.length);
            for (var i = 0; i < expected.length; i++) {
              expect(diagonal[i], expected[i]);
              diagonal[i] += '*';
            }
            expect(() => diagonal[-1], throwsRangeError);
            expect(() => diagonal[diagonal.count], throwsRangeError);
          }
          expect(() => matrix.diagonal(3), throwsRangeError);
          expect(() => matrix.diagonal(-2), throwsRangeError);
          for (var row = 0; row < matrix.rowCount; row++) {
            for (var col = 0; col < matrix.colCount; col++) {
              expect(matrix.get(row, col), '($row, $col)*');
            }
          }
        });
      });
      test('transpose', () {
        final matrix = builder
            .withType(DataType.string)
            .generate(7, 6, (row, col) => '($row, $col)');
        final view = matrix.transpose;
        expect(view.dataType, matrix.dataType);
        expect(view.rowCount, 6);
        expect(view.colCount, 7);
        for (var row = 0; row < view.rowCount; row++) {
          for (var col = 0; col < view.colCount; col++) {
            expect(view.get(row, col), '($col, $row)');
            view.set(row, col, '${view.get(row, col)}*');
          }
        }
        for (var row = 0; row < matrix.rowCount; row++) {
          for (var col = 0; col < matrix.colCount; col++) {
            expect(matrix.get(row, col), '($row, $col)*');
          }
        }
        expect(view.transpose, matrix);
      });
    });
    group('operators', () {
      final random = Random();
      test('add', () {
        final sourceA = builder
            .withType(DataType.uint8)
            .generate(4, 5, (row, col) => random.nextInt(DataType.uint8.max));
        final sourceB = builder
            .withType(DataType.uint8)
            .generate(4, 5, (row, col) => random.nextInt(DataType.uint8.max));
        final target =
            add(sourceA, sourceB, builder: builder.withType(DataType.int16));
        expect(target.dataType, DataType.int16);
        expect(target.rowCount, 4);
        expect(target.colCount, 5);
        for (var row = 0; row < target.rowCount; row++) {
          for (var col = 0; col < target.colCount; col++) {
            expect(target.get(row, col),
                sourceA.get(row, col) + sourceB.get(row, col));
          }
        }
      });
      test('sub', () {
        final sourceA = builder
            .withType(DataType.uint8)
            .generate(5, 4, (row, col) => random.nextInt(DataType.uint8.max));
        final sourceB = builder
            .withType(DataType.uint8)
            .generate(5, 4, (row, col) => random.nextInt(DataType.uint8.max));
        final target =
            sub(sourceA, sourceB, builder: builder.withType(DataType.int16));
        expect(target.dataType, DataType.int16);
        expect(target.rowCount, 5);
        expect(target.colCount, 4);
        for (var row = 0; row < target.rowCount; row++) {
          for (var col = 0; col < target.colCount; col++) {
            expect(target.get(row, col),
                sourceA.get(row, col) - sourceB.get(row, col));
          }
        }
      });
      test('mul', () {
        final sourceA = builder
            .withType(DataType.uint8)
            .generate(4, 5, (row, col) => random.nextInt(DataType.uint8.max));
        final sourceB = builder
            .withType(DataType.uint8)
            .generate(5, 6, (row, col) => random.nextInt(DataType.uint8.max));
        final target =
            mul(sourceA, sourceB, builder: builder.withType(DataType.int32));
        expect(target.dataType, DataType.int32);
        expect(target.rowCount, 4);
        expect(target.colCount, 6);
        for (var row = 0; row < target.rowCount; row++) {
          for (var col = 0; col < target.colCount; col++) {
            // TODO(renggli): verify the multiplication
            //expect(target.get(row, col),
            //    sourceA.get(row, col) * sourceB.get(row, col));
          }
        }
      });
    });
  });
}

void main() {
  matrixTest('row major', Matrix.builder.rowMajor);
  matrixTest('col major', Matrix.builder.columnMajor);
  matrixTest('sparse-coo', Matrix.builder.coordinateList);
  matrixTest('sparse-csr', Matrix.builder.compressedRow);
  matrixTest('sparse-csc', Matrix.builder.compressedColumn);
  matrixTest('sparse-dia', Matrix.builder.diagonal);
  matrixTest('sparse-dok', Matrix.builder.keyed);
}
