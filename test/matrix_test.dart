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
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), 0);
          }
        }
      });
      test('call square', () {
        final matrix = builder.withType(DataType.int8)(4);
        expect(matrix.dataType, DataType.int8);
        expect(matrix.rowCount, 4);
        expect(matrix.colCount, 4);
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), 0);
          }
        }
      });
      test('constant', () {
        final matrix = builder.withType(DataType.int8).constant(5, 6, 123);
        expect(matrix.dataType, DataType.int8);
        expect(matrix.rowCount, 5);
        expect(matrix.colCount, 6);
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), 123);
          }
        }
        expect(() => matrix.set(0, 0, 1), throwsUnsupportedError);
      });
      test('constant, mutable', () {
        final matrix =
            builder.withType(DataType.int8).constant(6, 5, 123, mutable: true);
        expect(matrix.dataType, DataType.int8);
        expect(matrix.rowCount, 6);
        expect(matrix.colCount, 5);
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), 123);
          }
        }
        matrix.set(0, 0, 1);
        expect(matrix.get(0, 0), 1);
      });
      test('identity', () {
        final matrix = builder.withType(DataType.int8).identity(6, 7, -1);
        expect(matrix.dataType, DataType.int8);
        expect(matrix.rowCount, 6);
        expect(matrix.colCount, 7);
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), r == c ? -1 : 0);
          }
        }
        expect(() => matrix.set(0, 0, 1), throwsUnsupportedError);
      });
      test('identity, mutable', () {
        final matrix =
            builder.withType(DataType.int8).identity(7, 6, -1, mutable: true);
        expect(matrix.dataType, DataType.int8);
        expect(matrix.rowCount, 7);
        expect(matrix.colCount, 6);
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), r == c ? -1 : 0);
          }
        }
        matrix.set(0, 0, 1);
        expect(matrix.get(0, 0), 1);
      });
      test('generate', () {
        final matrix = builder
            .withType(DataType.string)
            .generate(7, 8, (row, col) => '($row, $col)');
        expect(matrix.dataType, DataType.string);
        expect(matrix.rowCount, 7);
        expect(matrix.colCount, 8);
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), '($r, $c)');
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
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), '($r, $c): Point($r, $c)');
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
        for (var r = 0; r < source.rowCount; r++) {
          for (var c = 0; c < source.colCount; c++) {
            expect(matrix.get(r, c), '($r, $c)');
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
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), source[c]);
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
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), source[r]);
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
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), r == c ? source[r] : 0);
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
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            points.add(Point(r, c));
          }
        }
        // add values
        points.shuffle();
        for (var point in points) {
          matrix.set(point.x, point.y, point);
        }
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), Point(r, c));
          }
        }
        // update values
        points.shuffle();
        for (var point in points) {
          matrix.set(point.x, point.y, Point(point.x + 1, point.y + 1));
        }
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), Point(r + 1, c + 1));
          }
        }
        // remove values
        points.shuffle();
        for (var point in points) {
          matrix.set(point.x, point.y, matrix.dataType.nullValue);
        }
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), matrix.dataType.nullValue);
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
        expect(matrix.toString(), '${matrix.runtimeType}[2, 3]: 1 2 3\n4 5 6');
      });
    });
    group('views', () {
      test('copy', () {
        final view = builder
            .withType(DataType.object)
            .generate(8, 6, (row, col) => Point(row, col));
        final copy = view.copy();
        expect(view.dataType, copy.dataType);
        expect(view.rowCount, copy.rowCount);
        expect(view.colCount, copy.colCount);
        expect(compare(view, copy), isTrue);
        view.set(3, 5, null);
        expect(copy.get(3, 5), const Point(3, 5));
      });
      test('row', () {
        final view = builder
            .withType(DataType.string)
            .generate(4, 5, (r, c) => '($r, $c)');
        for (var r = 0; r < view.rowCount; r++) {
          final row = view.row(r);
          expect(row.dataType, view.dataType);
          expect(row.count, view.colCount);
          expect(vector.compare(row.copy(), row), isTrue);
          for (var c = 0; c < view.colCount; c++) {
            expect(row[c], '($r, $c)');
            row[c] += '*';
          }
          expect(() => row[-1], throwsRangeError);
          expect(() => row[view.colCount], throwsRangeError);
          expect(() => row[-1] += '*', throwsRangeError);
          expect(() => row[view.colCount] += '*', throwsRangeError);
        }
        expect(() => view.row(-1), throwsRangeError);
        expect(() => view.row(4), throwsRangeError);
        for (var r = 0; r < view.rowCount; r++) {
          for (var c = 0; c < view.colCount; c++) {
            expect(view.get(r, c), '($r, $c)*');
          }
        }
      });
      test('column', () {
        final view = builder
            .withType(DataType.string)
            .generate(5, 4, (r, c) => '($r, $c)');
        for (var c = 0; c < view.colCount; c++) {
          final column = view.col(c);
          expect(column.dataType, view.dataType);
          expect(column.count, view.rowCount);
          expect(vector.compare(column.copy(), column), isTrue);
          for (var r = 0; r < view.rowCount; r++) {
            expect(column[r], '($r, $c)');
            column[r] += '*';
          }
          expect(() => column[-1], throwsRangeError);
          expect(() => column[view.rowCount], throwsRangeError);
          expect(() => column[-1] += '*', throwsRangeError);
          expect(() => column[view.rowCount] += '*', throwsRangeError);
        }
        expect(() => view.col(-1), throwsRangeError);
        expect(() => view.col(4), throwsRangeError);
        for (var r = 0; r < view.rowCount; r++) {
          for (var c = 0; c < view.colCount; c++) {
            expect(view.get(r, c), '($r, $c)*');
          }
        }
      });
      group('diagonal', () {
        test('vertical', () {
          final view = builder
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
            final diagonal = view.diagonal(offset);
            expect(diagonal.dataType, view.dataType);
            expect(diagonal.count, expected.length);
            expect(vector.compare(diagonal.copy(), diagonal), isTrue);
            for (var i = 0; i < expected.length; i++) {
              expect(diagonal[i], expected[i]);
              diagonal[i] += '*';
            }
          }
          expect(() => view.diagonal(2), throwsRangeError);
          expect(() => view.diagonal(-3), throwsRangeError);
          for (var r = 0; r < view.rowCount; r++) {
            for (var c = 0; c < view.colCount; c++) {
              expect(view.get(r, c), '($r, $c)*');
            }
          }
        });
        test('horizontal', () {
          final view = builder
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
            final diagonal = view.diagonal(offset);
            expect(diagonal.dataType, view.dataType);
            expect(diagonal.count, expected.length);
            expect(vector.compare(diagonal.copy(), diagonal), isTrue);
            for (var i = 0; i < expected.length; i++) {
              expect(diagonal[i], expected[i]);
              diagonal[i] += '*';
            }
            expect(() => diagonal[-1], throwsRangeError);
            expect(() => diagonal[diagonal.count], throwsRangeError);
          }
          expect(() => view.diagonal(3), throwsRangeError);
          expect(() => view.diagonal(-2), throwsRangeError);
          for (var r = 0; r < view.rowCount; r++) {
            for (var c = 0; c < view.colCount; c++) {
              expect(view.get(r, c), '($r, $c)*');
            }
          }
        });
      });
      group('range', () {
        final source = builder.generate(7, 8, (row, col) => Point(row, col));
        test('row', () {
          final view = source.rowRange(1, 3);
          expect(view.dataType, source.dataType);
          expect(view.rowCount, 2);
          expect(view.colCount, source.colCount);
          expect(compare(view.copy(), view), isTrue);
          for (var r = 0; r < view.rowCount; r++) {
            for (var c = 0; c < view.colCount; c++) {
              expect(view.get(r, c), Point(r + 1, c));
            }
          }
        });
        test('row unchecked', () {
          source.rowRangeUnchecked(-1, source.rowCount);
          source.rowRangeUnchecked(0, source.rowCount + 1);
        });
        test('column', () {
          final view = source.colRange(1, 4);
          expect(view.dataType, source.dataType);
          expect(view.rowCount, source.rowCount);
          expect(view.colCount, 3);
          expect(compare(view.copy(), view), isTrue);
          for (var r = 0; r < view.rowCount; r++) {
            for (var c = 0; c < view.colCount; c++) {
              expect(view.get(r, c), Point(r, c + 1));
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
          expect(compare(view.copy(), view), isTrue);
          for (var r = 0; r < view.rowCount; r++) {
            for (var c = 0; c < view.colCount; c++) {
              expect(view.get(r, c), Point(r + 1, c + 2));
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
          expect(compare(view.copy(), view), isTrue);
          for (var r = 0; r < view.rowCount; r++) {
            for (var c = 0; c < view.colCount; c++) {
              expect(view.get(r, c), Point(r + 2, c + 2));
            }
          }
        });
        test('full range', () {
          final matrix = source.range(0, source.rowCount, 0, source.colCount);
          expect(matrix, source);
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
          final view = source.rowIndex([5, 0, 4]);
          expect(view.dataType, source.dataType);
          expect(view.rowCount, 3);
          expect(view.colCount, source.colCount);
          expect(compare(view.copy(), view), isTrue);
          for (var r = 0; r < view.rowCount; r++) {
            for (var c = 0; c < view.colCount; c++) {
              expect(view.get(r, c), Point(r == 0 ? 5 : r == 1 ? 0 : 4, c));
            }
          }
        });
        test('row unchecked', () {
          source.rowIndexUnchecked([-1, source.rowCount - 1]);
          source.rowIndexUnchecked([0, source.rowCount]);
        });
        test('column', () {
          final view = source.colIndex([3, 0, 0]);
          expect(view.dataType, source.dataType);
          expect(view.rowCount, source.rowCount);
          expect(view.colCount, 3);
          expect(compare(view.copy(), view), isTrue);
          for (var r = 0; r < view.rowCount; r++) {
            for (var c = 0; c < view.colCount; c++) {
              expect(view.get(r, c), Point(r, c == 0 ? 3 : 0));
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
          expect(compare(view.copy(), view), isTrue);
          for (var r = 0; r < view.rowCount; r++) {
            for (var c = 0; c < view.colCount; c++) {
              expect(view.get(r, c), Point(r == 0 ? 0 : 5, c == 0 ? 3 : 0));
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
        test('to string', () {
          final view = matrix.map(
              (row, col, value) => '${value.x + 10 * value.y}',
              DataType.string);
          expect(view.dataType, DataType.string);
          expect(view.rowCount, matrix.rowCount);
          expect(view.colCount, matrix.colCount);
          expect(compare(view.copy(), view), isTrue);
          for (var r = 0; r < view.rowCount; r++) {
            for (var c = 0; c < view.colCount; c++) {
              expect(view.get(r, c), '${r + 10 * c}');
            }
          }
        });
        test('to int', () {
          final view = matrix.map(
              (row, col, value) => value.x + 10 * value.y, DataType.int32);
          expect(view.dataType, DataType.int32);
          expect(view.rowCount, matrix.rowCount);
          expect(view.colCount, matrix.colCount);
          for (var r = 0; r < view.rowCount; r++) {
            for (var c = 0; c < view.colCount; c++) {
              expect(view.get(r, c), r + 10 * c);
            }
          }
        });
        test('to float', () {
          final view = matrix.map(
              (row, col, value) => value.x + 10.0 * value.y, DataType.float64);
          expect(view.dataType, DataType.float64);
          expect(view.rowCount, matrix.rowCount);
          expect(view.colCount, matrix.colCount);
          for (var r = 0; r < view.rowCount; r++) {
            for (var c = 0; c < view.colCount; c++) {
              expect(view.get(r, c), r + 10.0 * c);
            }
          }
        });
        test('readonly', () {
          final view =
              matrix.map<int>((row, col, value) => row, DataType.int32);
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
        expect(compare(view.copy(), view), isTrue);
        for (var r = 0; r < view.rowCount; r++) {
          for (var c = 0; c < view.colCount; c++) {
            expect(view.get(r, c), '($c, $r)');
            view.set(r, c, '${view.get(r, c)}*');
          }
        }
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), '($r, $c)*');
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
        expect(compare(view.copy(), view), isTrue);
        for (var r = 0; r < view.rowCount; r++) {
          for (var c = 0; c < view.colCount; c++) {
            expect(view.get(r, c), '($r, $c)');
            expect(() => view.set(r, c, '${view.get(r, c)}*'),
                throwsUnsupportedError);
          }
        }
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            matrix.set(r, c, '${matrix.get(r, c)}!');
          }
        }
        for (var r = 0; r < view.rowCount; r++) {
          for (var c = 0; c < view.colCount; c++) {
            expect(view.get(r, c), '($r, $c)!');
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
          for (var r = 0; r < result.rowCount; r++) {
            for (var c = 0; c < result.colCount; c++) {
              expect(result.get(r, c), sourceA.get(r, c) + sourceB.get(r, c));
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
          for (var r = 0; r < result.rowCount; r++) {
            for (var c = 0; c < result.colCount; c++) {
              expect(result.get(r, c), sourceA.get(r, c) + sourceB.get(r, c));
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
          for (var r = 0; r < result.rowCount; r++) {
            for (var c = 0; c < result.colCount; c++) {
              expect(result.get(r, c), sourceA.get(r, c) + sourceB.get(r, c));
            }
          }
        });
      });
      test('sub', () {
        final target = sub(sourceA, sourceB);
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
        final target = neg(sourceA);
        expect(target.dataType, sourceA.dataType);
        expect(target.rowCount, sourceA.rowCount);
        expect(target.colCount, sourceA.colCount);
        for (var r = 0; r < target.rowCount; r++) {
          for (var c = 0; c < target.colCount; c++) {
            expect(target.get(r, c), -sourceA.get(r, c));
          }
        }
      });
      test('scale', () {
        final target = scale(2, sourceA);
        expect(target.dataType, sourceA.dataType);
        expect(target.rowCount, sourceA.rowCount);
        expect(target.colCount, sourceA.colCount);
        for (var r = 0; r < target.rowCount; r++) {
          for (var c = 0; c < target.colCount; c++) {
            expect(target.get(r, c), 2 * sourceA.get(r, c));
          }
        }
      });
      group('compare', () {
        test('identity', () {
          expect(compare(sourceA, sourceA), isTrue);
          expect(compare(sourceB, sourceB), isTrue);
          expect(compare(sourceA, sourceB), isFalse);
          expect(compare(sourceB, sourceA), isFalse);
        });
        test('views', () {
          expect(compare(sourceA.rowRange(0, 3), sourceA.rowIndex([0, 1, 2])),
              isTrue);
          expect(compare(sourceA.colRange(0, 3), sourceA.colIndex([0, 1, 2])),
              isTrue);
          expect(compare(sourceA.rowRange(0, 3), sourceA.rowIndex([3, 1, 0])),
              isFalse,
              reason: 'row order missmatch');
          expect(compare(sourceA.colRange(0, 3), sourceA.colIndex([2, 1, 0])),
              isFalse,
              reason: 'col order missmatch');
          expect(compare(sourceA.rowRange(0, 3), sourceA.rowIndex([0, 1])),
              isFalse,
              reason: 'row count missmatch');
          expect(compare(sourceA.colRange(0, 3), sourceA.colIndex([0, 1])),
              isFalse,
              reason: 'col count missmatch');
        });
        test('custom', () {
          final negated = neg(sourceA);
          expect(compare(sourceA, negated), isFalse);
          expect(compare<int, int>(sourceA, negated, equals: (a, b) => a == -b),
              isTrue);
        });
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
      group('mul', () {
        final sourceA = builder
            .withType(DataType.int32)
            .generate(13, 42, (row, col) => random.nextInt(100));
        final sourceB = builder
            .withType(DataType.int32)
            .generate(42, 27, (row, col) => random.nextInt(100));
        test('default', () {
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
        });
        test('error in-place', () {
          final squareA = sourceA.range(0, 8, 0, 8);
          final squareB = sourceB.range(0, 8, 0, 8);
          expect(() => mul(squareA, squareB, target: squareA),
              throwsArgumentError);
          expect(() => mul(squareA, squareB, target: squareB),
              throwsArgumentError);
        });
        test('error dimensions', () {
          expect(() => mul(sourceA, sourceA), throwsArgumentError);
          expect(() => mul(sourceB, sourceB), throwsArgumentError);
          expect(() => mul(sourceB, sourceA), throwsArgumentError);
        });
      });
    });
  });
  group('decomposition', () {
    // Decomposition primarily works with floating point matrices:
    final factory = builder.withType(DataType.float64);
    // Comparator for floating point numbers:
    final epsilon = pow(2.0, -32.0);
    void expectMatrix(Matrix<num> expected, Matrix<num> actual) => expect(
          compare(actual, expected, equals: (a, b) => (a - b).abs() <= epsilon),
          isTrue,
          reason: 'Expected $expected, but got $actual.',
        );
    // Example matrices:
    final matrix3 = factory.fromRows([
      [1.0, 4.0, 7.0, 10.0],
      [2.0, 5.0, 8.0, 11.0],
      [3.0, 6.0, 9.0, 12.0],
    ]);
    final matrix4 = factory.fromRows([
      [1.0, 5.0, 9.0],
      [2.0, 6.0, 10.0],
      [3.0, 7.0, 11.0],
      [4.0, 8.0, 12.0],
    ]);
    test('norm1', () {
      final result = norm1(matrix3);
      expect(result, closeTo(33.0, epsilon));
    });
    test('normInf', () {
      final result = normInfinity(matrix3);
      expect(result, closeTo(30.0, epsilon));
    });
    test('normFrobenius', () {
      final result = normFrobenius(matrix3);
      expect(result, closeTo(sqrt(650), epsilon));
    });
    test('trace', () {
      final result = trace(matrix3);
      expect(result, closeTo(15.0, epsilon));
    });
    test('det', () {
      final result =
          det(matrix3.range(0, matrix3.rowCount, 0, matrix3.rowCount));
      expect(result, closeTo(0.0, epsilon));
    });
    test('QR Decomposition', () {
      final decomp = qr(matrix4);
      final result = mul(decomp.orthogonal, decomp.upper);
      expectMatrix(matrix4, result);
    });
    test('Singular Value Decomposition', () {
      final decomp = singularValue(matrix4);
      final result = mul(decomp.U, mul(decomp.S, decomp.V.transpose));
      expectMatrix(matrix4, result);
    });
    test('LU Decomposition', () {
      final matrix =
          matrix4.range(0, matrix4.colCount - 1, 0, matrix4.colCount - 1);
      final decomp = lu(matrix);
      final result1 = matrix.rowIndex(decomp.pivot);
      final result2 = mul(decomp.lower, decomp.upper);
      expectMatrix(result1, result2);
    });
    test('rank', () {
      final result = rank(matrix3);
      expect(result, min(matrix3.rowCount, matrix3.colCount) - 1);
    });
    test('cond', () {
      final matrix = factory.fromRows([
        [1.0, 3.0],
        [7.0, 9.0],
      ]);
      final decomp = singularValue(matrix);
      final singularValues = decomp.s;
      expect(
          cond(matrix),
          singularValues[0] /
              singularValues[min(matrix.rowCount, matrix.colCount) - 1]);
    });
    test('inverse', () {
      final matrix = factory.fromRows([
        [0.0, 5.0, 9.0],
        [2.0, 6.0, 10.0],
        [3.0, 7.0, 11.0],
      ]);
      final actual = mul(matrix, inverse(matrix));
      final expected = factory.identity(matrix.rowCount, matrix.colCount, 1.0);
      expectMatrix(expected, actual);
    });
    test('solve', () {
      final first = factory.fromRows([
        [5.0, 8.0],
        [6.0, 9.0],
      ]);
      final second = factory.fromRows([
        [13.0],
        [15.0],
      ]);
      final actual = solve(first, second);
      final expected = factory.constant(second.rowCount, second.colCount, 1.0);
      expectMatrix(expected, actual);
    });
    group('choleski', () {
      final matrix = factory.fromRows([
        [4.0, 1.0, 1.0],
        [1.0, 2.0, 3.0],
        [1.0, 3.0, 6.0],
      ]);
      final decomposition = cholesky(matrix);
      test('triangular factor', () {
        final triangularFactor = decomposition.L;
        expectMatrix(matrix, mul(triangularFactor, triangularFactor.transpose));
      });
      test('solve', () {
        final identity = factory.identity(3, 3, 1.0);
        final solution = decomposition.solve(identity);
        expectMatrix(identity, mul(matrix, solution));
      });
    });
    group('eigen', () {
      test('symmetric', () {
        final a = factory.fromRows([
          [4.0, 1.0, 1.0],
          [1.0, 2.0, 3.0],
          [1.0, 3.0, 6.0],
        ]);
        final decomposition = eigenvalue(a);
        final d = decomposition.D;
        final v = decomposition.V;
        expectMatrix(mul(a, v), mul(v, d));
      });
      test('non-symmetric', () {
        final a = factory.fromRows([
          [0.0, 1.0, 0.0, 0.0],
          [1.0, 0.0, 2.0e-7, 0.0],
          [0.0, -2.0e-7, 0.0, 1.0],
          [0.0, 0.0, 1.0, 0.0],
        ]);
        final decomposition = eigenvalue(a);
        final d = decomposition.D;
        final v = decomposition.V;
        expectMatrix(mul(a, v), mul(v, d));
      });
      test('bad', () {
        final a = factory.fromRows([
          [0.0, 0.0, 0.0, 0.0, 0.0],
          [0.0, 0.0, 0.0, 0.0, 1.0],
          [0.0, 0.0, 0.0, 1.0, 0.0],
          [1.0, 1.0, 0.0, 0.0, 1.0],
          [1.0, 0.0, 1.0, 0.0, 1.0],
        ]);
        final decomposition = eigenvalue(a);
        final d = decomposition.D;
        final v = decomposition.V;
        expectMatrix(mul(a, v), mul(v, d));
      });
    });

//  try {
//  print("\nTesting Eigenvalue; If this hangs, we've failed\n");
//  Matrix bA = new Matrix(badeigs);
//  EigenvalueDecomposition bEig = bA.eig();
//  try_success("EigenvalueDecomposition (hang)...", "");
//  } catch (java.lang.RuntimeException e) {
//  errorCount = try_failure(errorCount, "EigenvalueDecomposition (hang)...",
//  "incorrect termination");
//  }
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
