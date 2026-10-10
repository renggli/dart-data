import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('Matrix element access', () {
    test('get, set, getUnchecked, setUnchecked', () {
      final matrix = Matrix<double>.generate(
        3,
        4,
        (r, c) => (r * 10 + c).toDouble(),
        type: DataType.float64,
      );

      check(matrix.rowCount).equals(3);
      check(matrix.colCount).equals(4);

      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 4; c++) {
          final expected = (r * 10 + c).toDouble();
          check(matrix.get(r, c)).equals(expected);
          check(matrix.getUnchecked(r, c)).equals(expected);
        }
      }

      matrix.set(1, 2, 99.0);
      check(matrix.get(1, 2)).equals(99.0);
      check(matrix.getUnchecked(1, 2)).equals(99.0);

      matrix.setUnchecked(2, 3, 123.0);
      check(matrix.get(2, 3)).equals(123.0);
      check(matrix.getUnchecked(2, 3)).equals(123.0);
    });

    test('record indexing syntax [(r, c)]', () {
      final matrix = Matrix<int>.generate(
        2,
        3,
        (r, c) => r + c,
        type: DataType.int32,
      );

      check(matrix[(0, 0)]).equals(0);
      check(matrix[(0, 2)]).equals(2);
      check(matrix[(1, 1)]).equals(2);
      check(matrix[(1, 2)]).equals(3);

      matrix[(0, 1)] = 42;
      check(matrix[(0, 1)]).equals(42);
      check(matrix.get(0, 1)).equals(42);
      check(matrix.getUnchecked(0, 1)).equals(42);
    });

    test('bounds validation throws RangeError', () {
      final matrix = Matrix<double>.generate(
        2,
        3,
        (r, c) => 1.0,
        type: DataType.float64,
      );

      check(() => matrix.get(-1, 0)).throws<RangeError>();
      check(() => matrix.get(0, -1)).throws<RangeError>();
      check(() => matrix.get(2, 0)).throws<RangeError>();
      check(() => matrix.get(0, 3)).throws<RangeError>();

      check(() => matrix.set(-1, 0, 0.0)).throws<RangeError>();
      check(() => matrix.set(0, -1, 0.0)).throws<RangeError>();
      check(() => matrix.set(2, 0, 0.0)).throws<RangeError>();
      check(() => matrix.set(0, 3, 0.0)).throws<RangeError>();

      check(() => matrix[(-1, 0)]).throws<RangeError>();
      check(() => matrix[(0, -1)]).throws<RangeError>();
      check(() => matrix[(2, 0)]).throws<RangeError>();
      check(() => matrix[(0, 3)]).throws<RangeError>();

      check(() => matrix[(-1, 0)] = 0.0).throws<RangeError>();
      check(() => matrix[(0, -1)] = 0.0).throws<RangeError>();
      check(() => matrix[(2, 0)] = 0.0).throws<RangeError>();
      check(() => matrix[(0, 3)] = 0.0).throws<RangeError>();
    });

    test('transposed view indexing preserves correctness', () {
      final matrix = Matrix<int>.generate(
        2,
        3,
        (r, c) => r * 10 + c,
        type: DataType.int32,
      );
      final trans = matrix.transposed;

      check(trans.rowCount).equals(3);
      check(trans.colCount).equals(2);

      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 2; c++) {
          check(trans.get(r, c)).equals(matrix.get(c, r));
          check(trans.getUnchecked(r, c)).equals(matrix.getUnchecked(c, r));
          check(trans[(r, c)]).equals(matrix[(c, r)]);
        }
      }

      trans[(1, 0)] = 88;
      check(matrix.get(0, 1)).equals(88);
      check(trans.getUnchecked(1, 0)).equals(88);
    });

    test('submatrix and non-zero offset indexing', () {
      final matrix = Matrix<int>.generate(
        4,
        4,
        (r, c) => r * 4 + c,
        type: DataType.int32,
      );
      final sub = matrix.subMatrix(
        rowStart: 1,
        rowEnd: 3,
        colStart: 1,
        colEnd: 4,
      );

      check(sub.rowCount).equals(2);
      check(sub.colCount).equals(3);

      check(sub[(0, 0)]).equals(matrix[(1, 1)]);
      check(sub.getUnchecked(0, 0)).equals(matrix.getUnchecked(1, 1));
      check(sub[(1, 2)]).equals(matrix[(2, 3)]);
      check(sub.getUnchecked(1, 2)).equals(matrix.getUnchecked(2, 3));

      sub[(0, 0)] = 999;
      check(matrix.get(1, 1)).equals(999);
    });

    test('0-sized matrices bounds and factories', () {
      final m00 = Matrix<double>.generate(0, 0, (r, c) => 0.0);
      check(m00.rowCount).equals(0);
      check(m00.colCount).equals(0);
      check(() => m00.get(0, 0)).throws<RangeError>();
      check(() => m00[(0, 0)]).throws<RangeError>();

      final m03 = Matrix<double>.generate(0, 3, (r, c) => 0.0);
      check(m03.rowCount).equals(0);
      check(m03.colCount).equals(3);
      check(() => m03.get(0, 1)).throws<RangeError>();

      final m30 = Matrix<double>.generate(3, 0, (r, c) => 0.0);
      check(m30.rowCount).equals(3);
      check(m30.colCount).equals(0);
      check(() => m30.get(1, 0)).throws<RangeError>();

      final emptyFromRows = Matrix<int>.fromRows([]);
      check(emptyFromRows.rowCount).equals(0);
      check(emptyFromRows.colCount).equals(0);

      final emptyFromCols = Matrix<int>.fromColumns([]);
      check(emptyFromCols.rowCount).equals(0);
      check(emptyFromCols.colCount).equals(0);

      final emptyNestedRows = Matrix<int>.fromRows([[], []]);
      check(emptyNestedRows.rowCount).equals(2);
      check(emptyNestedRows.colCount).equals(0);
    });

    test('factories fromRows and fromColumns direct buffer initialization', () {
      final mRows = Matrix<int>.fromRows([
        [1, 2, 3],
        [4, 5, 6],
      ]);
      check(mRows.rowCount).equals(2);
      check(mRows.colCount).equals(3);
      check(mRows.getUnchecked(0, 0)).equals(1);
      check(mRows.getUnchecked(1, 2)).equals(6);

      final mCols = Matrix<int>.fromColumns([
        [1, 4],
        [2, 5],
        [3, 6],
      ]);
      check(mCols.rowCount).equals(2);
      check(mCols.colCount).equals(3);
      check(mCols.getUnchecked(0, 0)).equals(1);
      check(mCols.getUnchecked(1, 2)).equals(6);
    });

    test('matrix properties and toNestedList', () {
      final sym = Matrix<int>.fromRows([
        [1, 2, 3],
        [2, 5, 6],
        [3, 6, 9],
      ]);
      check(sym.isSymmetric).isTrue();
      check(sym.isDiagonal).isFalse();

      final diag = Matrix<int>.fromRows([
        [1, 0, 0],
        [0, 2, 0],
        [0, 0, 3],
      ]);
      check(diag.isDiagonal).isTrue();
      check(diag.isLowerTriangular).isTrue();
      check(diag.isUpperTriangular).isTrue();

      final lower = Matrix<int>.fromRows([
        [1, 0, 0],
        [4, 5, 0],
        [7, 8, 9],
      ]);
      check(lower.isLowerTriangular).isTrue();
      check(lower.isUpperTriangular).isFalse();

      final nested = lower.toNestedList();
      check(nested).deepEquals([
        [1, 0, 0],
        [4, 5, 0],
        [7, 8, 9],
      ]);
    });

    test('matrix norms and trace', () {
      final mat = Matrix<double>.fromRows([
        [1.0, -2.0],
        [3.0, 4.0],
      ]);
      check(mat.trace).equals(5.0);
      check(mat.norm1).equals(6.0);
      check(mat.normInfinity).equals(7.0);
    });

    test('solveVector with LU and Cholesky', () {
      final a = Matrix<double>.fromRows([
        [2.0, 1.0],
        [1.0, 3.0],
      ]);
      final b = Vector<double>.fromList([4.0, 7.0]);

      final luSol = a.lu.solveVector(b);
      check(luSol[0]).which((it) => it.isCloseTo(1.0, 1e-12));
      check(luSol[1]).which((it) => it.isCloseTo(2.0, 1e-12));

      final choleskySol = a.cholesky.solveVector(b);
      check(choleskySol[0]).which((it) => it.isCloseTo(1.0, 1e-12));
      check(choleskySol[1]).which((it) => it.isCloseTo(2.0, 1e-12));
    });
  });
}
