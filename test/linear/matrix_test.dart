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

  group('Matrix trace', () {
    test('square numeric matrices (int and double)', () {
      final matD = Matrix<double>.fromRows([
        [1.0, 2.0],
        [3.0, 4.0],
      ]);
      check(matD.trace).equals(5.0);

      final matI = Matrix<int>.fromRows([
        [10, 2, 3],
        [4, 20, 6],
        [7, 8, 30],
      ]);
      check(matI.trace).equals(60);
    });

    test('square non-num matrix with Field (Complex)', () {
      final matC = Matrix<Complex>.fromRows([
        [const Complex(1.0, 2.0), const Complex(3.0, 4.0)],
        [const Complex(5.0, 6.0), const Complex(7.0, 8.0)],
      ]);
      check(matC.trace).equals(const Complex(8.0, 10.0));
    });

    test('square non-numeric matrix without Field throws UnsupportedError', () {
      final matS = Matrix<String>.fromRows([
        ['a', 'b'],
        ['c', 'd'],
      ], type: DataType.string);
      check(() => matS.trace).throws<UnsupportedError>();
    });

    test('non-square matrix throws ArgumentError', () {
      final wide = Matrix<int>.filled(2, 3, 1);
      check(() => wide.trace).throws<ArgumentError>();

      final tall = Matrix<double>.filled(3, 2, 1.0);
      check(() => tall.trace).throws<ArgumentError>();
    });

    test('empty matrix trace', () {
      final empty = Matrix<double>.generate(0, 0, (r, c) => 0.0);
      check(empty.trace).equals(0.0);
    });

    test('sliced submatrix and transposed trace', () {
      final mat = Matrix<double>.fromRows([
        [1.0, 2.0, 3.0],
        [4.0, 5.0, 6.0],
        [7.0, 8.0, 9.0],
      ]);
      check(mat.transpose().trace).equals(15.0);
      check(mat.subMatrix(rowStart: 0, rowEnd: 2, colStart: 0, colEnd: 2).trace)
          .equals(6.0);
      check(mat.subMatrix(rowStart: 1, rowEnd: 3, colStart: 1, colEnd: 3).trace)
          .equals(14.0);
    });
  });

  group('Matrix decompositions', () {
    test('numeric decompositions on Matrix<double>', () {
      final a = Matrix<double>.fromRows([
        [4.0, 2.0],
        [2.0, 5.0],
      ]);

      final lu = a.lu;
      check(lu.det).isCloseTo(16.0, 1e-10);

      final qr = a.qr;
      check(qr.isFullRank).isTrue();

      final chol = a.cholesky;
      check(chol.isSymmetricPositiveDefinite).isTrue();

      final svd = a.svd;
      check(svd.s.length).equals(2);
      check(svd.norm2).isGreaterThan(0.0);

      final eig = a.eigenvalue;
      check(eig.realEigenvalues.length).equals(2);
    });

    test('numeric decompositions on Matrix<int>', () {
      final a = Matrix<int>.fromRows([
        [2, 0],
        [0, 2],
      ]);

      final lu = a.lu;
      check(lu.det).isCloseTo(4.0, 1e-10);

      final qr = a.qr;
      check(qr.isFullRank).isTrue();

      final chol = a.cholesky;
      check(chol.isSymmetricPositiveDefinite).isTrue();

      final svd = a.svd;
      check(svd.s.length).equals(2);

      final eig = a.eigenvalue;
      check(eig.realEigenvalues.length).equals(2);
    });

    test('numeric decompositions on Matrix<num>', () {
      final a = Matrix<num>.fromRows([
        [4.0, 2.0],
        [2.0, 5.0],
      ], type: DataType.float64);

      final lu = a.lu;
      check(lu.det).isCloseTo(16.0, 1e-10);

      final qr = a.qr;
      check(qr.isFullRank).isTrue();

      final chol = a.cholesky;
      check(chol.isSymmetricPositiveDefinite).isTrue();

      final svd = a.svd;
      check(svd.s.length).equals(2);
      check(svd.norm2).isGreaterThan(0.0);

      final eig = a.eigenvalue;
      check(eig.realEigenvalues.length).equals(2);
    });

    test('non-numeric matrices have no decomposition getters and avoid downcast TypeError', () {
      final strMat = Matrix<String>.fromRows([
        ['a', 'b'],
        ['c', 'd'],
      ], type: DataType.string);

      // At compile-time, `strMat.lu` etc. are unavailable because MatrixDecompositionExtension
      // is constrained to `T extends num`.
      // If invoked dynamically, NoSuchMethodError is thrown rather than an internal TypeError
      // from an unsafe `this as Matrix<num>` cast.
      // ignore: avoid_dynamic_calls
      check(() => (strMat as dynamic).lu).throws<NoSuchMethodError>();
      // ignore: avoid_dynamic_calls
      check(() => (strMat as dynamic).qr).throws<NoSuchMethodError>();
      // ignore: avoid_dynamic_calls
      check(() => (strMat as dynamic).cholesky).throws<NoSuchMethodError>();
      // ignore: avoid_dynamic_calls
      check(() => (strMat as dynamic).svd).throws<NoSuchMethodError>();
      // ignore: avoid_dynamic_calls
      check(() => (strMat as dynamic).eigenvalue).throws<NoSuchMethodError>();
    });
  });
}
