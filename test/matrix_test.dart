library data.test.matrix;

import 'package:data/matrix.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

typedef Matrix MatrixConstructor(DataType type, int rows, int cols);

void matrixTest(String name, MatrixConstructor constructor) {
  group(name, () {
    test('construction', () {
      final matrix = constructor(DataType.int8, 3, 4);
      expect(matrix.rowCount, 3);
      expect(matrix.colCount, 4);
      expect(matrix.dataType, DataType.int8);
      for (var r = 0; r < matrix.rowCount; r++) {
        for (var c = 0; c < matrix.colCount; c++) {
          expect(matrix.get(r, c), 0);
        }
      }
      expect(() => matrix.get(-1, 0), throwsRangeError);
      expect(() => matrix.get(0, -1), throwsRangeError);
      expect(() => matrix.get(matrix.rowCount, 0), throwsRangeError);
      expect(() => matrix.get(0, matrix.colCount), throwsRangeError);
    });

    final matrix = constructor(DataType.string, 5, 6);
    for (var r = 0; r < matrix.rowCount; r++) {
      for (var c = 0; c < matrix.colCount; c++) {
        matrix.set(r, c, '$r-$c');
      }
    }
    print(matrix);
    test('get', () {
      for (var r = 0; r < matrix.rowCount; r++) {
        for (var c = 0; c < matrix.colCount; c++) {
          expect(matrix.get(r, c), '$r-$c');
        }
      }
    });
    test('row-view', () {
      for (var r = 0; r < matrix.rowCount; r++) {
        final row = matrix.row(r);
        for (var c = 0; c < matrix.colCount; c++) {
          expect(row[c], '$r-$c');
        }
        expect(() => row[-1], throwsRangeError);
        expect(() => row[matrix.colCount], throwsRangeError);
      }
    });
    test('col-view', () {
      for (var c = 0; c < matrix.colCount; c++) {
        final col = matrix.col(c);
        for (var r = 0; r < matrix.rowCount; r++) {
          expect(col[r], '$r-$c');
        }
        expect(() => col[-1], throwsRangeError);
        expect(() => col[matrix.rowCount], throwsRangeError);
      }
    });
  });
}

void main() {
  matrixTest(
      'row-major', (type, rows, cols) => RowMajorMatrix(type, rows, cols));
  matrixTest('column-major',
      (type, rows, cols) => ColumnMajorMatrix(type, rows, cols));
  matrixTest('sparse-coo',
      (type, rows, cols) => CoordinateListSparseMatrix(type, rows, cols));
  matrixTest('sparse-csr',
      (type, rows, cols) => CompressedSparseRowMatrix(type, rows, cols));
  matrixTest('sparse-csc',
      (type, rows, cols) => CompressedSparseColumnMatrix(type, rows, cols));
}
