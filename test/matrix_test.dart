library data.test.matrix;

import 'dart:math';

import 'package:data/matrix.dart';
import 'package:data/type.dart';
import 'package:data/vector.dart' as v;
import 'package:test/test.dart';

void matrixTest(String name, Builder builder) {
  group(name, () {
    group('builder', () {
      test('call', () {
        final matrix = builder.withType(DataType.int8)(4, 5);
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
      test('call, error', () {
        expect(() => builder(-4, 5), throwsRangeError);
        expect(() => builder(4, -5), throwsRangeError);
        expect(() => builder.withType(null)(4, 5), throwsArgumentError);
        expect(() => builder.withFormat(null)(4, 5), throwsArgumentError);
      });
      test('call square', () {
        final matrix = builder.withType(DataType.int8)(4);
        expect(matrix.dataType, DataType.int8);
        expect(matrix.rowCount, 4);
        expect(matrix.colCount, 4);
        expect(matrix.storage, [matrix]);
        expect(matrix.shape, [matrix.rowCount, matrix.colCount]);
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
        expect(matrix.storage, [matrix]);
        expect(matrix.copy(), matrix);
        expect(matrix.shape, [matrix.rowCount, matrix.colCount]);
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
        expect(matrix.storage, [matrix]);
        expect(matrix.shape, [matrix.rowCount, matrix.colCount]);
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
        expect(matrix.storage, [matrix]);
        expect(matrix.shape, [matrix.rowCount, matrix.colCount]);
        expect(matrix.copy(), matrix);
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
        expect(matrix.shape, [matrix.rowCount, matrix.colCount]);
        expect(matrix.storage, [matrix]);
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
      test('generate, lazy', () {
        final matrix = builder
            .withType(DataType.string)
            .generate(7, 8, (row, col) => '($row, $col)', lazy: true);
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
        final copy = matrix.copy();
        expect(copy, same(matrix));
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
        expect(matrix.shape, [matrix.rowCount, matrix.colCount]);
        expect(matrix.storage, [matrix]);
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), '($r, $c): Point($r, $c)');
          }
        }
        matrix.set(0, 0, '*');
        expect(matrix.get(0, 0), '*');
      });
      test('transform, lazy', () {
        final source = builder
            .withType(DataType.object)
            .generate(8, 7, (row, col) => Point(row, col));
        final matrix = builder.withType(DataType.string).transform(
            source, (row, col, value) => '($row, $col): $value',
            lazy: true);
        expect(matrix.dataType, DataType.string);
        expect(matrix.rowCount, 8);
        expect(matrix.colCount, 7);
        expect(matrix.shape, [matrix.rowCount, matrix.colCount]);
        expect(matrix.storage, [source]);
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), '($r, $c): Point($r, $c)');
          }
        }
        expect(() => matrix.set(0, 0, '*'), throwsUnsupportedError);
      });
      test('horizontal', () {
        final source1 = builder.withType(DataType.string).fromRows([
          ['a'],
          ['b'],
        ]);
        final source2 = builder.withType(DataType.string).fromRows([
          ['c', 'e'],
          ['d', 'f'],
        ]);
        final source3 = builder.withType(DataType.string).fromRows([
          ['g', 'i', 'k'],
          ['h', 'j', 'l'],
        ]);
        final matrix = builder
            .withType(DataType.string)
            .horizontal([source1, source2, source3, source1]);
        expect(matrix.dataType, DataType.string);
        expect(matrix.rowCount, 2);
        expect(matrix.colCount, 7);
        expect(matrix.shape, [matrix.rowCount, matrix.colCount]);
        expect(matrix.storage, [matrix]);
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), ['acegika', 'bdfhjlb'][r][c]);
          }
        }
        matrix.set(0, 0, '*');
        matrix.set(1, 5, '!');
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), ['*cegika', 'bdfhj!b'][r][c]);
          }
        }
      });
      test('horizontal, lazy', () {
        final source1 = builder.withType(DataType.string).fromRows([
          ['a'],
          ['b'],
        ]);
        final source2 = builder.withType(DataType.string).fromRows([
          ['c', 'e'],
          ['d', 'f'],
        ]);
        final source3 = builder.withType(DataType.string).fromRows([
          ['g', 'i', 'k'],
          ['h', 'j', 'l'],
        ]);
        final matrix = builder
            .withType(DataType.string)
            .horizontal([source1, source2, source3, source1], lazy: true);
        expect(matrix.dataType, DataType.string);
        expect(matrix.rowCount, 2);
        expect(matrix.colCount, 7);
        expect(matrix.shape, [matrix.rowCount, matrix.colCount]);
        expect(matrix.storage, unorderedMatches([source1, source2, source3]));
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), ['acegika', 'bdfhjlb'][r][c]);
          }
        }
        matrix.set(0, 0, '*');
        matrix.set(1, 5, '!');
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), ['*cegik*', 'bdfhj!b'][r][c]);
          }
        }
        final copy = matrix.copy();
        expect(copy, isNot(same(matrix)));
      });
      test('vertical', () {
        final source1 = builder.withType(DataType.string).fromRows([
          ['a', 'b'],
        ]);
        final source2 = builder.withType(DataType.string).fromRows([
          ['c', 'd'],
          ['e', 'f'],
        ]);
        final source3 = builder.withType(DataType.string).fromRows([
          ['g', 'h'],
          ['i', 'j'],
          ['k', 'l'],
        ]);
        final matrix = builder
            .withType(DataType.string)
            .vertical([source1, source2, source3, source1]);
        expect(matrix.dataType, DataType.string);
        expect(matrix.rowCount, 7);
        expect(matrix.colCount, 2);
        expect(matrix.shape, [matrix.rowCount, matrix.colCount]);
        expect(matrix.storage, [matrix]);
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c),
                ['ab', 'cd', 'ef', 'gh', 'ij', 'kl', 'ab'][r][c]);
          }
        }
      });
      test('vertical, lazy', () {
        final source1 = builder.withType(DataType.string).fromRows([
          ['a', 'b'],
        ]);
        final source2 = builder.withType(DataType.string).fromRows([
          ['c', 'd'],
          ['e', 'f'],
        ]);
        final source3 = builder.withType(DataType.string).fromRows([
          ['g', 'h'],
          ['i', 'j'],
          ['k', 'l'],
        ]);
        final matrix = builder
            .withType(DataType.string)
            .vertical([source1, source2, source3, source1], lazy: true);
        expect(matrix.dataType, DataType.string);
        expect(matrix.rowCount, 7);
        expect(matrix.colCount, 2);
        expect(matrix.shape, [matrix.rowCount, matrix.colCount]);
        expect(matrix.storage, unorderedMatches([source1, source2, source3]));
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c),
                ['ab', 'cd', 'ef', 'gh', 'ij', 'kl', 'ab'][r][c]);
          }
        }
        matrix.set(0, 0, '*');
        matrix.set(5, 1, '!');
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c),
                ['*b', 'cd', 'ef', 'gh', 'ij', 'k!', '*b'][r][c]);
          }
        }
        final copy = matrix.copy();
        expect(copy, isNot(same(matrix)));
      });
      test('fromMatrix', () {
        final source = builder
            .withType(DataType.string)
            .generate(5, 6, (row, col) => '($row, $col)');
        final matrix = builder.withType(DataType.string).fromMatrix(source);
        expect(matrix.dataType, DataType.string);
        expect(matrix.rowCount, 5);
        expect(matrix.colCount, 6);
        expect(matrix.shape, [matrix.rowCount, matrix.colCount]);
        expect(matrix.storage, [matrix]);
        for (var r = 0; r < source.rowCount; r++) {
          for (var c = 0; c < source.colCount; c++) {
            expect(matrix.get(r, c), '($r, $c)');
          }
        }
      });
      test('fromRow', () {
        final source =
            v.Vector.builder.withType(DataType.int8).fromList([2, 5, 6]);
        final matrix = builder.withType(DataType.int16).fromRow(source);
        expect(matrix.dataType, DataType.int16);
        expect(matrix.rowCount, 1);
        expect(matrix.colCount, 3);
        expect(matrix.shape, [matrix.rowCount, matrix.colCount]);
        expect(matrix.storage, [matrix]);
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), source[c]);
          }
        }
      });
      test('fromRow, lazy', () {
        final source =
            v.Vector.builder.withType(DataType.int8).fromList([2, 5, 6]);
        final matrix =
            builder.withType(DataType.int16).fromRow(source, lazy: true);
        expect(matrix.dataType, DataType.int8);
        expect(matrix.rowCount, 1);
        expect(matrix.colCount, 3);
        expect(matrix.shape, [matrix.rowCount, matrix.colCount]);
        expect(matrix.storage, [source]);
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), source[c]);
          }
        }
        matrix.set(0, 2, 7);
        expect(matrix.get(0, 2), 7);
        expect(source[2], 7);
        final copy = matrix.copy();
        expect(copy, isNot(same(matrix)));
      });
      test('fromColumn', () {
        final source =
            v.Vector.builder.withType(DataType.int8).fromList([2, 5, 6]);
        final matrix = builder.withType(DataType.int16).fromColumn(source);
        expect(matrix.dataType, DataType.int16);
        expect(matrix.rowCount, 3);
        expect(matrix.colCount, 1);
        expect(matrix.shape, [matrix.rowCount, matrix.colCount]);
        expect(matrix.storage, [matrix]);
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), source[r]);
          }
        }
      });
      test('fromColumn, lazy', () {
        final source =
            v.Vector.builder.withType(DataType.int8).fromList([2, 5, 6]);
        final matrix =
            builder.withType(DataType.int16).fromColumn(source, lazy: true);
        expect(matrix.dataType, DataType.int8);
        expect(matrix.rowCount, 3);
        expect(matrix.colCount, 1);
        expect(matrix.shape, [matrix.rowCount, matrix.colCount]);
        expect(matrix.storage, [source]);
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), source[r]);
          }
        }
        matrix.set(2, 0, 7);
        expect(matrix.get(2, 0), 7);
        expect(source[2], 7);
        final copy = matrix.copy();
        expect(copy, isNot(same(matrix)));
      });
      test('fromDiagonal', () {
        final source =
            v.Vector.builder.withType(DataType.int8).fromList([2, 5, 6]);
        final matrix = builder.withType(DataType.int16).fromDiagonal(source);
        expect(matrix.dataType, DataType.int16);
        expect(matrix.rowCount, 3);
        expect(matrix.colCount, 3);
        expect(matrix.shape, [matrix.rowCount, matrix.colCount]);
        expect(matrix.storage, [matrix]);
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), r == c ? source[r] : 0);
          }
        }
      });
      test('fromDiagonal, lazy', () {
        final source =
            v.Vector.builder.withType(DataType.int8).fromList([2, 5, 6]);
        final matrix =
            builder.withType(DataType.int16).fromDiagonal(source, lazy: true);
        expect(matrix.dataType, DataType.int8);
        expect(matrix.rowCount, 3);
        expect(matrix.colCount, 3);
        expect(matrix.shape, [matrix.rowCount, matrix.colCount]);
        expect(matrix.storage, [source]);
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            expect(matrix.get(r, c), r == c ? source[r] : 0);
          }
        }
        expect(() => matrix.set(1, 2, 7), throwsArgumentError);
        matrix.set(2, 2, 7);
        expect(matrix.get(2, 2), 7);
        expect(source[2], 7);
        final copy = matrix.copy();
        expect(copy, isNot(same(matrix)));
      });
      test('fromRows', () {
        final matrix = builder.withType(DataType.int8).fromRows([
          [1, 2, 3],
          [4, 5, 6],
        ]);
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
      test('fromRows (argument error)', () {
        expect(
            () => builder.fromRows([
                  [1],
                  [1, 2]
                ]),
            throwsArgumentError);
      });
      test('fromRowVectors', () {
        final matrix = builder.withType(DataType.int8).fromRowVectors([
          v.Vector.builder.withType(DataType.int8).fromList([1, 2, 3]),
          v.Vector.builder.withType(DataType.int8).fromList([4, 5, 6]),
        ]);
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
      test('fromRowVectors (argument error)', () {
        expect(
            () => builder.fromRowVectors([
                  v.Vector.builder.withType(DataType.int8).fromList([1]),
                  v.Vector.builder.withType(DataType.int8).fromList([1, 2]),
                ]),
            throwsArgumentError);
      });
      test('fromPackedRows', () {
        final matrix = builder.fromPackedRows(2, 3, [1, 2, 3, 4, 5, 6]);
        expect(matrix.dataType, DataType.object);
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
        expect(matrix.shape, [matrix.rowCount, matrix.colCount]);
        expect(matrix.storage, [matrix]);
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
      test('fromColumnVectors', () {
        final matrix = builder.withType(DataType.int8).fromColumnVectors([
          v.Vector.builder.withType(DataType.int8).fromList([1, 2, 3]),
          v.Vector.builder.withType(DataType.int8).fromList([4, 5, 6]),
        ]);
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
      test('fromColumnVectors (argument error)', () {
        expect(
            () => builder.fromColumnVectors([
                  v.Vector.builder.withType(DataType.int8).fromList([1]),
                  v.Vector.builder.withType(DataType.int8).fromList([1, 2]),
                ]),
            throwsArgumentError);
      });
      test('fromPackedColumns', () {
        final matrix = builder.fromPackedColumns(2, 3, [1, 2, 3, 4, 5, 6]);
        expect(matrix.dataType, DataType.object);
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
      test('operator (read)', () {
        expect(matrix[0][0], 1);
        expect(matrix[0][1], 2);
        expect(matrix[0][2], 3);
        expect(matrix[1][0], 4);
        expect(matrix[1][1], 5);
        expect(matrix[1][2], 6);
      });
      test('operator (write)', () {
        final copy = builder(matrix.rowCount, matrix.colCount);
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            copy[r][c] = matrix.get(r, c);
          }
        }
        expect(compare(copy, matrix), isTrue);
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
      test('format', () {
        final matrix =
            builder.withType(DataType.uint16).generate(30, 30, (r, c) => r * c);
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
            '[2, 3, ${matrix.dataType.name}]:\n'
            '1 2 3\n'
            '4 5 6');
      });
    });
    group('views', () {
      test('copy', () {
        final source = builder
            .withType(DataType.object)
            .generate(8, 6, (row, col) => Point(row, col));
        final copy = source.copy();
        expect(copy.dataType, source.dataType);
        expect(copy.rowCount, source.rowCount);
        expect(copy.colCount, source.colCount);
        expect(copy.storage, [copy]);
        expect(compare(source, copy), isTrue);
        source.set(3, 5, null);
        expect(copy.get(3, 5), const Point(3, 5));
      });
      test('row', () {
        final source = builder
            .withType(DataType.string)
            .generate(4, 5, (r, c) => '($r, $c)');
        for (var r = 0; r < source.rowCount; r++) {
          final row = source.row(r);
          expect(row.dataType, source.dataType);
          expect(row.count, source.colCount);
          expect(row.storage, [source]);
          expect(v.compare(row.copy(), row), isTrue);
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
      test('rows', () {
        final source = builder
            .withType(DataType.object)
            .generate(7, 5, (r, c) => Point(r, c));
        var r = 0;
        for (var row in source.rows) {
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
      test('col', () {
        final source = builder
            .withType(DataType.string)
            .generate(5, 4, (r, c) => '($r, $c)');
        for (var c = 0; c < source.colCount; c++) {
          final column = source.col(c);
          expect(column.dataType, source.dataType);
          expect(column.count, source.rowCount);
          expect(column.storage, [source]);
          expect(v.compare(column.copy(), column), isTrue);
          for (var r = 0; r < source.rowCount; r++) {
            expect(column[r], '($r, $c)');
            column[r] += '*';
          }
          expect(() => column[-1], throwsRangeError);
          expect(() => column[source.rowCount], throwsRangeError);
          expect(() => column[-1] += '*', throwsRangeError);
          expect(() => column[source.rowCount] += '*', throwsRangeError);
        }
        expect(() => source.col(-1), throwsRangeError);
        expect(() => source.col(4), throwsRangeError);
        for (var r = 0; r < source.rowCount; r++) {
          for (var c = 0; c < source.colCount; c++) {
            expect(source.get(r, c), '($r, $c)*');
          }
        }
      });
      test('cols', () {
        final source = builder
            .withType(DataType.object)
            .generate(5, 8, (r, c) => Point(r, c));
        var c = 0;
        for (var column in source.cols) {
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
      group('diagonal', () {
        test('vertical', () {
          final source = builder
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
            final diagonal = source.diagonal(offset);
            expect(diagonal.dataType, source.dataType);
            expect(diagonal.count, expected.length);
            expect(diagonal.storage, [source]);
            expect(v.compare(diagonal.copy(), diagonal), isTrue);
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
          final source = builder
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
            final diagonal = source.diagonal(offset);
            expect(diagonal.dataType, source.dataType);
            expect(diagonal.count, expected.length);
            expect(diagonal.storage, [source]);
            expect(v.compare(diagonal.copy(), diagonal), isTrue);
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
        final source = builder.generate(7, 8, (row, col) => Point(row, col));
        test('row', () {
          final range = source.rowRange(1, 3);
          expect(range.dataType, source.dataType);
          expect(range.rowCount, 2);
          expect(range.colCount, source.colCount);
          expect(range.storage, [source]);
          expect(compare(range.copy(), range), isTrue);
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
          expect(compare(range.copy(), range), isTrue);
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
          expect(compare(range.copy(), range), isTrue);
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
          expect(compare(range.copy(), range), isTrue);
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
          final original = builder.fromMatrix(source);
          final range = original.range(2, 3, 3, 4);
          range.set(0, 0, '*');
          expect(range.get(0, 0), '*');
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
          final index = source.rowIndex([5, 0, 4]);
          expect(index.dataType, source.dataType);
          expect(index.rowCount, 3);
          expect(index.colCount, source.colCount);
          expect(index.storage, [source]);
          expect(compare(index.copy(), index), isTrue);
          for (var r = 0; r < index.rowCount; r++) {
            for (var c = 0; c < index.colCount; c++) {
              expect(index.get(r, c), Point(r == 0 ? 5 : r == 1 ? 0 : 4, c));
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
          expect(compare(index.copy(), index), isTrue);
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
          expect(compare(index.copy(), index), isTrue);
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
          final original = builder.fromMatrix(source);
          final index = original.index([2], [3]);
          index.set(0, 0, '*');
          expect(index.get(0, 0), '*');
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
        final source = builder.generate(3, 4, (row, col) => Point(row, col));
        test('to string', () {
          final mapped = source.map(
              (row, col, value) => '${value.x + 10 * value.y}',
              DataType.string);
          expect(mapped.dataType, DataType.string);
          expect(mapped.rowCount, source.rowCount);
          expect(mapped.colCount, source.colCount);
          expect(mapped.storage, [source]);
          expect(compare(mapped.copy(), mapped), isTrue);
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
      });
      test('transposed', () {
        final source = builder
            .withType(DataType.string)
            .generate(7, 6, (row, col) => '($row, $col)');
        final transposed = source.transposed;
        expect(transposed.dataType, source.dataType);
        expect(transposed.rowCount, 6);
        expect(transposed.colCount, 7);
        expect(transposed.storage, [source]);
        expect(compare(transposed.copy(), transposed), isTrue);
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
        expect(transposed.transposed, source);
      });
      test('unmodifiable', () {
        final source = builder
            .withType(DataType.string)
            .generate(2, 3, (row, col) => '($row, $col)');
        final readonly = source.unmodifiable;
        expect(readonly.dataType, source.dataType);
        expect(readonly.rowCount, 2);
        expect(readonly.colCount, 3);
        expect(readonly.storage, [source]);
        expect(compare(readonly.copy(), readonly), isTrue);
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
    });
    group('testing', () {
      final random = Random();
      final matrix = builder.withType(DataType.int32);
      final identity8x9 = matrix.identity(8, 9, 1);
      final identity9x8 = matrix.identity(9, 8, 1);
      final identity8x8 = matrix.identity(8, 8, 1);
      final fullAsymmetric =
          matrix.generate(8, 8, (r, c) => random.nextInt(1000));
      final fullSymmetric = add(fullAsymmetric, fullAsymmetric.transposed);
      final lowerTriangle =
          matrix.generate(8, 8, (r, c) => r >= c ? random.nextInt(1000) : 0);
      final upperTriangle =
          matrix.generate(8, 8, (r, c) => r <= c ? random.nextInt(1000) : 0);
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
        final target = scale(sourceA, 2);
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
          expect(compare<int>(sourceA, negated, equals: (a, b) => a == -b),
              isTrue);
        });
      });
      group('lerp', () {
        final v0 = builder.withType(DataType.float32).fromRows([
          [1, 6],
          [9, 9],
        ]);
        final v1 = builder.withType(DataType.float32).fromRows([
          [9, -2],
          [9, -9],
        ]);
        test('at start', () {
          final v = lerp(v0, v1, 0.0);
          expect(v.dataType, v0.dataType);
          expect(v.rowCount, v0.rowCount);
          expect(v.colCount, v0.colCount);
          expect(v.get(0, 0), 1.0);
          expect(v.get(0, 1), 6.0);
          expect(v.get(1, 0), 9.0);
          expect(v.get(1, 1), 9.0);
        });
        test('at middle', () {
          final v = lerp(v0, v1, 0.5);
          expect(v.dataType, v0.dataType);
          expect(v.rowCount, v0.rowCount);
          expect(v.colCount, v0.colCount);
          expect(v.get(0, 0), 5.0);
          expect(v.get(0, 1), 2.0);
          expect(v.get(1, 0), 9.0);
          expect(v.get(1, 1), 0.0);
        });
        test('at end', () {
          final v = lerp(v0, v1, 1.0);
          expect(v.dataType, v0.dataType);
          expect(v.rowCount, v0.rowCount);
          expect(v.colCount, v0.colCount);
          expect(v.get(0, 0), 9.0);
          expect(v.get(0, 1), -2.0);
          expect(v.get(1, 0), 9.0);
          expect(v.get(1, 1), -9.0);
        });
        test('at outside', () {
          final v = lerp(v0, v1, 2.0);
          expect(v.dataType, v0.dataType);
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
              final value = v.dot(sourceA.row(r), sourceB.col(c));
              expect(target.get(r, c), value);
            }
          }
        });
        test('error in-place', () {
          final derivedA = sourceA.range(0, 8, 0, 8);
          final derivedB = sourceB.range(0, 8, 0, 8);
          expect(() => mul(derivedA, derivedB, target: derivedA),
              throwsArgumentError);
          expect(() => mul(derivedA, derivedB, target: derivedB),
              throwsArgumentError);
          expect(() => mul(derivedA.transposed, derivedB, target: derivedA),
              throwsArgumentError);
          expect(() => mul(derivedA, derivedB.transposed, target: derivedB),
              throwsArgumentError);
          expect(() => mul(derivedA, derivedB, target: derivedA.transposed),
              throwsArgumentError);
          expect(() => mul(derivedA, derivedB, target: derivedB.transposed),
              throwsArgumentError);
        });
        test('error dimensions', () {
          expect(() => mul(sourceA, sourceA), throwsArgumentError);
          expect(() => mul(sourceB, sourceB), throwsArgumentError);
          expect(() => mul(sourceB, sourceA), throwsArgumentError);
        });
      });
    });
    group('decomposition', () {
      // Decomposition primarily works with floating point matrices:
      final factory = builder.withType(DataType.float64);
      // Comparator for floating point numbers:
      final epsilon = pow(2.0, -32.0);
      void expectMatrix(Matrix<num> expected, Matrix<num> actual) => expect(
            compare<num>(actual, expected,
                equals: (a, b) => (a - b).abs() <= epsilon),
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
        final result = mul(decomp.U, mul(decomp.S, decomp.V.transposed));
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
        final expected =
            factory.identity(matrix.rowCount, matrix.colCount, 1.0);
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
        final expected =
            factory.constant(second.rowCount, second.colCount, 1.0);
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
          expectMatrix(
              matrix, mul(triangularFactor, triangularFactor.transposed));
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
