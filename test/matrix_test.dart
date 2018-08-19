library data.test.matrix;

import 'dart:math';

import 'package:data/matrix.dart';
import 'package:data/type.dart';
import 'package:data/vector.dart' as vector;
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
      test('call square', () {
        final matrix = builder.withType(DataType.int8)(4);
        expect(matrix.dataType, DataType.int8);
        expect(matrix.rowCount, 4);
        expect(matrix.colCount, 4);
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
      test('fromRow', () {
        final source =
            vector.Vector.builder.withType(DataType.int8).fromList([2, 5, 6]);
        final matrix = builder.withType(DataType.int16).fromRow(source);
        expect(matrix.dataType, DataType.int16);
        expect(matrix.rowCount, 1);
        expect(matrix.colCount, 3);
        for (var row = 0; row < matrix.rowCount; row++) {
          for (var col = 0; col < matrix.colCount; col++) {
            expect(matrix.get(row, col), source[col]);
          }
        }
      });
      test('fromColumn', () {
        final source =
            vector.Vector.builder.withType(DataType.int8).fromList([2, 5, 6]);
        final matrix = builder.withType(DataType.int16).fromColumn(source);
        expect(matrix.dataType, DataType.int16);
        expect(matrix.rowCount, 3);
        expect(matrix.colCount, 1);
        for (var row = 0; row < matrix.rowCount; row++) {
          for (var col = 0; col < matrix.colCount; col++) {
            expect(matrix.get(row, col), source[row]);
          }
        }
      });
      test('fromDiagonal', () {
        final source =
            vector.Vector.builder.withType(DataType.int8).fromList([2, 5, 6]);
        final matrix = builder.withType(DataType.int16).fromDiagonal(source);
        expect(matrix.dataType, DataType.int16);
        expect(matrix.rowCount, 3);
        expect(matrix.colCount, 3);
        for (var row = 0; row < matrix.rowCount; row++) {
          for (var col = 0; col < matrix.colCount; col++) {
            expect(matrix.get(row, col), row == col ? source[row] : 0);
          }
        }
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
      test('fromRows (argument error)', () {
        expect(
            () => builder.fromRows([
                  [1],
                  [1, 2]
                ]),
            throwsArgumentError);
      });
      test('fromPackedRows', () {
        final matrix = builder.fromPackedRows(2, 3, [1, 2, 3, 4, 5, 6]);
        expect(matrix.dataType, DataType.object);
        expect(matrix.rowCount, 2);
        expect(matrix.colCount, 3);
        expect(matrix.get(0, 0), 1);
        expect(matrix.get(0, 1), 2);
        expect(matrix.get(0, 2), 3);
        expect(matrix.get(1, 0), 4);
        expect(matrix.get(1, 1), 5);
        expect(matrix.get(1, 2), 6);
      });
      test('fromPackedRows (argument errror)', () {
        expect(() => builder.fromPackedRows(2, 3, []), throwsArgumentError);
      });
      test('fromColumns', () {
        final matrix = builder.withType(DataType.int8).fromColumns([
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
      test('fromColumns (argument error)', () {
        expect(
            () => builder.fromColumns([
                  [1],
                  [1, 2]
                ]),
            throwsArgumentError);
      });
      test('fromPackedColumns', () {
        final matrix = builder.fromPackedColumns(2, 3, [1, 2, 3, 4, 5, 6]);
        expect(matrix.dataType, DataType.object);
        expect(matrix.rowCount, 2);
        expect(matrix.colCount, 3);
        expect(matrix.get(0, 0), 1);
        expect(matrix.get(1, 0), 2);
        expect(matrix.get(0, 1), 3);
        expect(matrix.get(1, 1), 4);
        expect(matrix.get(0, 2), 5);
        expect(matrix.get(1, 2), 6);
      });
      test('fromPackedColumns (argument error)', () {
        expect(() => builder.fromPackedColumns(2, 3, []), throwsArgumentError);
      });
    });
    group('accessing', () {
      final matrix = builder.withType(DataType.int8).fromRows([
        [1, 2, 3],
        [4, 5, 6],
      ]);
      test('random', () {
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
      test('read (range error)', () {
        expect(() => matrix.get(-1, 0), throwsRangeError);
        expect(() => matrix.get(0, -1), throwsRangeError);
        expect(() => matrix.get(matrix.rowCount, 0), throwsRangeError);
        expect(() => matrix.get(0, matrix.colCount), throwsRangeError);
      });
      test('write (range error)', () {
        expect(() => matrix.set(-1, 0, 0), throwsRangeError);
        expect(() => matrix.set(0, -1, 0), throwsRangeError);
        expect(() => matrix.set(matrix.rowCount, 0, 0), throwsRangeError);
        expect(() => matrix.set(0, matrix.colCount, 0), throwsRangeError);
      });
      test('toString', () {
        expect(
            matrix.toString(),
            '${matrix.runtimeType}[2, 3]:\n'
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
          final column = matrix.col(c);
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
        expect(() => matrix.col(-1), throwsRangeError);
        expect(() => matrix.col(4), throwsRangeError);
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
      group('range', () {
        final source = builder.generate(7, 8, (row, col) => Point(row, col));
        test('row', () {
          final matrix = source.rowRange(1, 3);
          expect(matrix.dataType, source.dataType);
          expect(matrix.rowCount, 2);
          expect(matrix.colCount, source.colCount);
          for (var row = 0; row < matrix.rowCount; row++) {
            for (var col = 0; col < matrix.colCount; col++) {
              expect(matrix.get(row, col), Point(row + 1, col));
            }
          }
        });
        test('row unchecked', () {
          source.rowRangeUnchecked(-1, source.rowCount);
          source.rowRangeUnchecked(0, source.rowCount + 1);
        });
        test('column', () {
          final matrix = source.colRange(1, 4);
          expect(matrix.dataType, source.dataType);
          expect(matrix.rowCount, source.rowCount);
          expect(matrix.colCount, 3);
          for (var row = 0; row < matrix.rowCount; row++) {
            for (var col = 0; col < matrix.colCount; col++) {
              expect(matrix.get(row, col), Point(row, col + 1));
            }
          }
        });
        test('column unchecked', () {
          source.colRangeUnchecked(-1, source.colCount);
          source.colRangeUnchecked(0, source.colCount + 1);
        });
        test('row and column', () {
          final view = source.range(1, 3, 2, 4);
          expect(view.dataType, source.dataType);
          expect(view.rowCount, 2);
          expect(view.colCount, 2);
          for (var row = 0; row < view.rowCount; row++) {
            for (var col = 0; col < view.colCount; col++) {
              expect(view.get(row, col), Point(row + 1, col + 2));
            }
          }
        });
        test('sub range', () {
          final view = source
              .range(1, source.rowCount - 2, 1, source.colCount - 2)
              .range(1, source.rowCount - 3, 1, source.colCount - 3);
          expect(view.dataType, source.dataType);
          expect(view.rowCount, source.rowCount - 4);
          expect(view.colCount, source.colCount - 4);
          for (var row = 0; row < view.rowCount; row++) {
            for (var col = 0; col < view.colCount; col++) {
              expect(view.get(row, col), Point(row + 2, col + 2));
            }
          }
        });
        test('full range', () {
          final view = source.range(0, source.rowCount, 0, source.colCount);
          expect(view, source);
        });
        test('write', () {
          final original = builder.fromMatrix(source);
          final view = original.range(2, 3, 3, 4);
          view.set(0, 0, '*');
          expect(view.get(0, 0), '*');
          expect(original.get(2, 3), '*');
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
        final source = builder.generate(6, 4, (row, col) => Point(row, col));
        test('row', () {
          final matrix = source.rowIndex([5, 0, 4]);
          expect(matrix.dataType, source.dataType);
          expect(matrix.rowCount, 3);
          expect(matrix.colCount, source.colCount);
          for (var row = 0; row < matrix.rowCount; row++) {
            for (var col = 0; col < matrix.colCount; col++) {
              expect(matrix.get(row, col),
                  Point(row == 0 ? 5 : row == 1 ? 0 : 4, col));
            }
          }
        });
        test('row unchecked', () {
          source.rowIndexUnchecked([-1, source.rowCount - 1]);
          source.rowIndexUnchecked([0, source.rowCount]);
        });
        test('column', () {
          final matrix = source.colIndex([3, 0, 0]);
          expect(matrix.dataType, source.dataType);
          expect(matrix.rowCount, source.rowCount);
          expect(matrix.colCount, 3);
          for (var row = 0; row < matrix.rowCount; row++) {
            for (var col = 0; col < matrix.colCount; col++) {
              expect(matrix.get(row, col), Point(row, col == 0 ? 3 : 0));
            }
          }
        });
        test('column unchecked', () {
          source.colIndexUnchecked([-1, source.colCount - 1]);
          source.colIndexUnchecked([0, source.colCount]);
        });
        test('row and column', () {
          final view = source.index([0, 5], [3, 0]);
          expect(view.dataType, source.dataType);
          expect(view.rowCount, 2);
          expect(view.colCount, 2);
          for (var row = 0; row < view.rowCount; row++) {
            for (var col = 0; col < view.colCount; col++) {
              expect(view.get(row, col),
                  Point(row == 0 ? 0 : 5, col == 0 ? 3 : 0));
            }
          }
        });
        test('sub index', () {
          final view = source.index([2, 3, 0], [1, 2]).index([2], [1]);
          expect(view.dataType, source.dataType);
          expect(view.rowCount, 1);
          expect(view.colCount, 1);
          expect(view.get(0, 0), const Point(0, 2));
        });
        test('write', () {
          final original = builder.fromMatrix(source);
          final view = original.index([2], [3]);
          view.set(0, 0, '*');
          expect(view.get(0, 0), '*');
          expect(original.get(2, 3), '*');
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
      group('map', () {
        final matrix = builder.generate(3, 4, (row, col) => Point(row, col));
        test('to specific type', () {
          final view = matrix.map((row, col, value) {
            expect(row, value.x);
            expect(col, value.y);
            return value.x + 10 * value.y;
          }, DataType.uint16);
          expect(view.dataType, DataType.uint16);
          expect(view.rowCount, matrix.rowCount);
          expect(view.colCount, matrix.colCount);
          for (var row = 0; row < view.rowCount; row++) {
            for (var col = 0; col < view.colCount; col++) {
              expect(view.get(row, col), row + 10 * col);
            }
          }
        });
        test('to string', () {
          final view =
              matrix.map((row, col, value) => '${value.x + 10 * value.y}');
          expect(view.dataType, DataType.string);
          for (var row = 0; row < view.rowCount; row++) {
            for (var col = 0; col < view.colCount; col++) {
              expect(view.get(row, col), '${row + 10 * col}');
            }
          }
        });
        test('to int', () {
          final view =
              matrix.map<int>((row, col, value) => value.x + 10 * value.y);
          expect(view.dataType, DataType.int64);
          for (var row = 0; row < view.rowCount; row++) {
            for (var col = 0; col < view.colCount; col++) {
              expect(view.get(row, col), row + 10 * col);
            }
          }
        });
        test('to float', () {
          final view =
              matrix.map<double>((row, col, value) => value.x + 10.0 * value.y);
          expect(view.dataType, DataType.float64);
          for (var row = 0; row < view.rowCount; row++) {
            for (var col = 0; col < view.colCount; col++) {
              expect(view.get(row, col), row + 10.0 * col);
            }
          }
        });
        test('readonly', () {
          final view = matrix.map<int>((row, col, value) => row);
          expect(() => view.setUnchecked(1, 2, 3), throwsUnsupportedError);
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
      test('unmodifiable', () {
        final matrix = builder
            .withType(DataType.string)
            .generate(2, 3, (row, col) => '($row, $col)');
        final view = matrix.unmodifiable;
        expect(view.dataType, matrix.dataType);
        expect(view.rowCount, 2);
        expect(view.colCount, 3);
        for (var row = 0; row < view.rowCount; row++) {
          for (var col = 0; col < view.colCount; col++) {
            expect(view.get(row, col), '($row, $col)');
            expect(() => view.set(row, col, '${view.get(row, col)}*'),
                throwsUnsupportedError);
          }
        }
        for (var row = 0; row < matrix.rowCount; row++) {
          for (var col = 0; col < matrix.colCount; col++) {
            matrix.set(row, col, '${matrix.get(row, col)}!');
          }
        }
        for (var row = 0; row < view.rowCount; row++) {
          for (var col = 0; col < view.colCount; col++) {
            expect(view.get(row, col), '($row, $col)!');
          }
        }
        expect(view.unmodifiable, view);
      });
    });
    group('operators', () {
      final random = Random();
      final sourceA = builder
          .withType(DataType.int32)
          .generate(5, 4, (row, col) => random.nextInt(100));
      final sourceB = builder
          .withType(DataType.int32)
          .generate(5, 4, (row, col) => random.nextInt(100));
      group('add', () {
        final sourceA = builder
            .withType(DataType.uint16)
            .generate(4, 5, (row, col) => random.nextInt(100));
        final sourceB = builder
            .withType(DataType.uint16)
            .generate(4, 5, (row, col) => random.nextInt(100));
        test('default', () {
          final result = add(sourceA, sourceB);
          expect(result.dataType, sourceA.dataType);
          expect(result.rowCount, sourceA.rowCount);
          expect(result.colCount, sourceA.colCount);
          for (var row = 0; row < result.rowCount; row++) {
            for (var col = 0; col < result.colCount; col++) {
              expect(result.get(row, col),
                  sourceA.get(row, col) + sourceB.get(row, col));
            }
          }
        });
        test('default, bad count', () {
          final sourceB = builder.withType(DataType.uint32)(
              sourceA.colCount, sourceA.rowCount);
          expect(() => add(sourceA, sourceB), throwsArgumentError);
        });
        test('target', () {
          final target = builder.withType(DataType.uint32)(
              sourceA.rowCount, sourceA.colCount);
          final result = add(sourceA, sourceB, target: target);
          expect(result.dataType, DataType.uint32);
          expect(result.rowCount, sourceA.rowCount);
          expect(result.colCount, sourceA.colCount);
          for (var row = 0; row < result.rowCount; row++) {
            for (var col = 0; col < result.colCount; col++) {
              expect(result.get(row, col),
                  sourceA.get(row, col) + sourceB.get(row, col));
            }
          }
          expect(result, target);
        });
        test('target, bad count', () {
          final target = builder.withType(DataType.uint32)(
              sourceA.colCount, sourceA.rowCount);
          expect(
              () => add(sourceA, sourceB, target: target), throwsArgumentError);
        });
        test('builder', () {
          final result =
              add(sourceA, sourceB, builder: builder.withType(DataType.uint32));
          expect(result.dataType, DataType.uint32);
          expect(result.rowCount, sourceA.rowCount);
          expect(result.colCount, sourceA.colCount);
          for (var row = 0; row < result.rowCount; row++) {
            for (var col = 0; col < result.colCount; col++) {
              expect(result.get(row, col),
                  sourceA.get(row, col) + sourceB.get(row, col));
            }
          }
        });
      });
      test('sub', () {
        final target = sub(sourceA, sourceB);
        expect(target.dataType, sourceA.dataType);
        expect(target.rowCount, sourceA.rowCount);
        expect(target.colCount, sourceA.colCount);
        for (var row = 0; row < target.rowCount; row++) {
          for (var col = 0; col < target.colCount; col++) {
            expect(target.get(row, col),
                sourceA.get(row, col) - sourceB.get(row, col));
          }
        }
      });
      test('neg', () {
        final target = neg(sourceA);
        expect(target.dataType, sourceA.dataType);
        expect(target.rowCount, sourceA.rowCount);
        expect(target.colCount, sourceA.colCount);
        for (var row = 0; row < target.rowCount; row++) {
          for (var col = 0; col < target.colCount; col++) {
            expect(target.get(row, col), -sourceA.get(row, col));
          }
        }
      });
      test('scale', () {
        final target = scale(2, sourceA);
        expect(target.dataType, sourceA.dataType);
        expect(target.rowCount, sourceA.rowCount);
        expect(target.colCount, sourceA.colCount);
        for (var row = 0; row < target.rowCount; row++) {
          for (var col = 0; col < target.colCount; col++) {
            expect(target.get(row, col), 2 * sourceA.get(row, col));
          }
        }
      });
      group('lerp', () {
        final v0 = builder.withType(DataType.int8).fromRows([
          [1, 6],
          [9, 9],
        ]);
        final v1 = builder.withType(DataType.int8).fromRows([
          [9, -2],
          [9, -9],
        ]);
        test('at start', () {
          final v = lerp(v0, v1, 0.0);
          expect(v.dataType, DataType.float64);
          expect(v.rowCount, v0.rowCount);
          expect(v.colCount, v0.colCount);
          expect(v.get(0, 0), 1.0);
          expect(v.get(0, 1), 6.0);
          expect(v.get(1, 0), 9.0);
          expect(v.get(1, 1), 9.0);
        });
        test('at middle', () {
          final v = lerp(v0, v1, 0.5);
          expect(v.dataType, DataType.float64);
          expect(v.rowCount, v0.rowCount);
          expect(v.colCount, v0.colCount);
          expect(v.get(0, 0), 5.0);
          expect(v.get(0, 1), 2.0);
          expect(v.get(1, 0), 9.0);
          expect(v.get(1, 1), 0.0);
        });
        test('at end', () {
          final v = lerp(v0, v1, 1.0);
          expect(v.dataType, DataType.float64);
          expect(v.rowCount, v0.rowCount);
          expect(v.colCount, v0.colCount);
          expect(v.get(0, 0), 9.0);
          expect(v.get(0, 1), -2.0);
          expect(v.get(1, 0), 9.0);
          expect(v.get(1, 1), -9.0);
        });
        test('at outside', () {
          final v = lerp(v0, v1, 2.0);
          expect(v.dataType, DataType.float64);
          expect(v.rowCount, v0.rowCount);
          expect(v.colCount, v0.colCount);
          expect(v.get(0, 0), 17.0);
          expect(v.get(0, 1), -10.0);
          expect(v.get(1, 0), 9.0);
          expect(v.get(1, 1), -27.0);
        });
        test('error', () {
          final other = builder.withType(DataType.int8).fromRows([
            [1, 2, 3],
            [4, 5, 6]
          ]);
          expect(() => lerp(v0, other, 2.0), throwsArgumentError);
        });
      });
      test('mul', () {
        final sourceA = builder
            .withType(DataType.int32)
            .generate(13, 42, (row, col) => random.nextInt(100));
        final sourceB = builder
            .withType(DataType.int32)
            .generate(42, 27, (row, col) => random.nextInt(100));
        final target = mul(sourceA, sourceB);
        expect(target.dataType, DataType.int32);
        expect(target.rowCount, sourceA.rowCount);
        expect(target.colCount, sourceB.colCount);
        for (var r = 0; r < target.rowCount; r++) {
          for (var c = 0; c < target.colCount; c++) {
            final value = vector.dot(sourceA.row(r), sourceB.col(c));
            expect(target.get(r, c), value);
          }
        }
        expect(() => mul(sourceA, sourceA), throwsArgumentError);
      });
    });
  });
}

void main() {
  matrixTest('rowMajor', Matrix.builder.rowMajor);
  matrixTest('columnMajor', Matrix.builder.columnMajor);
  matrixTest('coordinateList', Matrix.builder.coordinateList);
  matrixTest('compressedRow', Matrix.builder.compressedRow);
  matrixTest('compressedColumn', Matrix.builder.compressedColumn);
  matrixTest('diagonal', Matrix.builder.diagonal);
  matrixTest('keyed', Matrix.builder.keyed);
}
