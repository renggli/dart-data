import 'package:checks/checks.dart';
import 'package:data/acceleration.dart';
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

    test('natural 2D indexing syntax [r][c] and record write [(r, c)]', () {
      final matrix = Matrix<int>.generate(
        2,
        3,
        (r, c) => r + c,
        type: DataType.int32,
      );

      check(matrix[0][0]).equals(0);
      check(matrix[0][2]).equals(2);
      check(matrix[1][1]).equals(2);
      check(matrix[1][2]).equals(3);

      matrix[0][1] = 42;
      check(matrix[0][1]).equals(42);
      check(matrix.get(0, 1)).equals(42);
      check(matrix.getUnchecked(0, 1)).equals(42);

      matrix[(0, 1)] = 99;
      check(matrix[0][1]).equals(99);
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

      check(() => matrix[-1]).throws<RangeError>();
      check(() => matrix[2]).throws<RangeError>();
      check(() => matrix[0][-1]).throws<RangeError>();
      check(() => matrix[0][3]).throws<RangeError>();

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
          check(trans[r][c]).equals(matrix[c][r]);
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

      check(sub[0][0]).equals(matrix[1][1]);
      check(sub.getUnchecked(0, 0)).equals(matrix.getUnchecked(1, 1));
      check(sub[1][2]).equals(matrix[2][3]);
      check(sub.getUnchecked(1, 2)).equals(matrix.getUnchecked(2, 3));

      sub[0][0] = 999;
      check(matrix[1][1]).equals(999);
    });

    test('0-sized matrices bounds and factories', () {
      final m00 = Matrix<double>.generate(0, 0, (r, c) => 0.0);
      check(m00.rowCount).equals(0);
      check(m00.colCount).equals(0);
      check(() => m00.get(0, 0)).throws<RangeError>();
      check(() => m00[0]).throws<RangeError>();

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

      final emptyFromColList = Matrix<int>.fromColumns([[]]);
      check(emptyFromColList.rowCount).equals(0);
      check(emptyFromColList.colCount).equals(1);

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
      check(mat.transposed.trace).equals(15.0);
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

      // At compile-time, `strMat.lu` etc. are unavailable because decomposition
      // extensions are constrained to `T extends num` or `Complex`.
      // If invoked dynamically, NoSuchMethodError is thrown rather than an
      // internal TypeError
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

  group('Matrix.solve', () {
    test('square matrix with Vector RHS (Ax = b)', () {
      final a = Matrix<double>.fromRows([
        [2.0, 1.0],
        [1.0, 3.0],
      ]);
      final b = Vector<double>.fromList([4.0, 7.0]);
      final x = a.solveVector(b);

      check(x.length).equals(2);
      check(x[0]).isCloseTo(1.0, 1e-10);
      check(x[1]).isCloseTo(2.0, 1e-10);
    });

    test('square matrix with multi-column Matrix RHS (AX = B)', () {
      final a = Matrix<double>.fromRows([
        [2.0, 1.0],
        [1.0, 3.0],
      ]);
      final b = Matrix<double>.fromRows([
        [4.0, 5.0],
        [7.0, 5.0],
      ]);
      final x = a.solve(b);

      check(x.rowCount).equals(2);
      check(x.colCount).equals(2);
      // Col 0: [1.0, 2.0]
      check(x[0][0]).isCloseTo(1.0, 1e-10);
      check(x[1][0]).isCloseTo(2.0, 1e-10);
      // Col 1: [2.0, 1.0]
      check(x[0][1]).isCloseTo(2.0, 1e-10);
      check(x[1][1]).isCloseTo(1.0, 1e-10);

      // Verify A * X == B
      final ax = a * x;
      check(ax[0][0]).isCloseTo(4.0, 1e-10);
      check(ax[0][1]).isCloseTo(5.0, 1e-10);
      check(ax[1][0]).isCloseTo(7.0, 1e-10);
      check(ax[1][1]).isCloseTo(5.0, 1e-10);
    });

    test('overdetermined rectangular matrix with Vector RHS (least-squares via QR)', () {
      // 3 data points: (1, 2), (2, 3), (3, 5) fitted to y = c0 + c1 * x
      final a = Matrix<double>.fromRows([
        [1.0, 1.0],
        [1.0, 2.0],
        [1.0, 3.0],
      ]);
      final b = Vector<double>.fromList([2.0, 3.0, 5.0]);
      final x = a.solveVector(b);

      check(x.length).equals(2);
      // Normal equations: A^T A x = A^T b
      // A^T A = [[3, 6], [6, 14]], A^T b = [10, 23]
      // x = [1/3, 3/2] = [0.33333333, 1.5]
      check(x[0]).isCloseTo(1.0 / 3.0, 1e-10);
      check(x[1]).isCloseTo(1.5, 1e-10);
    });

    test('overdetermined rectangular matrix with Matrix RHS (least-squares via QR)', () {
      final a = Matrix<double>.fromRows([
        [1.0, 1.0],
        [1.0, 2.0],
        [1.0, 3.0],
      ]);
      final b = Matrix<double>.fromRows([
        [2.0, 4.0],
        [3.0, 6.0],
        [5.0, 10.0],
      ]);
      final x = a.solve(b);

      check(x.rowCount).equals(2);
      check(x.colCount).equals(2);
      // Col 0: [1/3, 1.5]
      check(x[0][0]).isCloseTo(1.0 / 3.0, 1e-10);
      check(x[1][0]).isCloseTo(1.5, 1e-10);
      // Col 1: [2/3, 3.0]
      check(x[0][1]).isCloseTo(2.0 / 3.0, 1e-10);
      check(x[1][1]).isCloseTo(3.0, 1e-10);
    });

    test('underdetermined rectangular matrix with Matrix RHS', () {
      final a = Matrix<double>.fromRows([
        [1.0, 2.0, 3.0],
        [2.0, 1.0, 0.0],
      ]);
      final b = Matrix<double>.fromRows([
        [1.0, 2.0],
        [3.0, 4.0],
      ]);
      final x = a.solve(b);
      check(x.rowCount).equals(3);
      check(x.colCount).equals(2);
      final ax = a * x;
      check(ax[0][0]).isCloseTo(1.0, 1e-10);
      check(ax[0][1]).isCloseTo(2.0, 1e-10);
      check(ax[1][0]).isCloseTo(3.0, 1e-10);
      check(ax[1][1]).isCloseTo(4.0, 1e-10);
    });

    test('exact solve with Fraction and row swap in RREF', () {
      final a = Matrix<Fraction>.fromRows([
        [Fraction.zero, Fraction.one],
        [Fraction.one, Fraction.one],
      ]);
      final b = Vector<Fraction>.fromList([Fraction(2), Fraction(5)]);
      final x = a.solveVector(b);
      check(x[0]).equals(Fraction(3));
      check(x[1]).equals(Fraction(2));

      final bMat = Matrix<Fraction>.fromRows([
        [Fraction(2), Fraction(4)],
        [Fraction(5), Fraction(7)],
      ]);
      final xMat = a.solve(bMat);
      check(xMat[0][0]).equals(Fraction(3));
      check(xMat[1][0]).equals(Fraction(2));
      check(xMat[0][1]).equals(Fraction(3));
      check(xMat[1][1]).equals(Fraction(4));
    });

    test('RREF inconsistent and rank deficient systems throw StateError', () {
      final a = Matrix<Fraction>.fromRows([
        [Fraction.one, Fraction.one],
        [Fraction(2), Fraction(2)],
        [Fraction(3), Fraction(3)],
      ]);
      final bDeficient = Vector<Fraction>.fromList([
        Fraction(1),
        Fraction(2),
        Fraction(3),
      ]);
      check(() => a.solveVector(bDeficient)).throws<StateError>();

      final aInc = Matrix<Fraction>.fromRows([
        [Fraction.one, Fraction.one],
        [Fraction.one, Fraction.one],
        [Fraction.zero, Fraction.zero],
      ]);
      final bInc = Vector<Fraction>.fromList([
        Fraction(1),
        Fraction(2),
        Fraction(1),
      ]);
      check(() => aInc.solveVector(bInc)).throws<StateError>();
    });

    test('Matrix.solve and Matrix.solveVector on diagonal matrix', () {
      final a = Matrix<double>.fromRows([
        [2.0, 0.0],
        [0.0, 3.0],
      ]);
      final bVec = Vector<double>.fromList([4.0, 9.0]);
      final xVec = a.solveVector(bVec);
      check(xVec[0]).isCloseTo(2.0, 1e-10);
      check(xVec[1]).isCloseTo(3.0, 1e-10);

      final bMat = Matrix<double>.fromRows([
        [4.0, 8.0],
        [9.0, 6.0],
      ]);
      final xMat = a.solve(bMat);
      check(xMat[0][0]).isCloseTo(2.0, 1e-10);
      check(xMat[1][0]).isCloseTo(3.0, 1e-10);
      check(xMat[0][1]).isCloseTo(4.0, 1e-10);
      check(xMat[1][1]).isCloseTo(2.0, 1e-10);
    });

    test('dimension mismatch and invalid argument errors', () {
      final a = Matrix<double>.fromRows([
        [1.0, 2.0],
        [3.0, 4.0],
      ]);
      final v3 = Vector<double>.fromList([1.0, 2.0, 3.0]);
      final m3 = Matrix<double>.filled(3, 2, 1.0);

      check(() => a.solveVector(v3)).throws<ArgumentError>();
      check(() => a.solve(m3)).throws<ArgumentError>();
    });
  });

  group('Matrix.det and Matrix.inverse', () {
    test('determinant of 2x2 and 3x3 matrices', () {
      final a2 = Matrix<double>.fromRows([
        [3.0, 8.0],
        [4.0, 6.0],
      ]);
      check(a2.det).isCloseTo(-14.0, 1e-10);

      final a3 = Matrix<double>.fromRows([
        [6.0, 1.0, 1.0],
        [4.0, -2.0, 5.0],
        [2.0, 8.0, 7.0],
      ]);
      // det = 6*(-14 - 40) - 1*(28 - 10) + 1*(32 - (-4)) = 6*(-54) - 18 + 36 =
      // -324 - 18 + 36 = -306
      check(a3.det).isCloseTo(-306.0, 1e-10);
    });

    test('inverse of 2x2 and 3x3 invertible matrices', () {
      final a2 = Matrix<double>.fromRows([
        [4.0, 7.0],
        [2.0, 6.0],
      ]);
      final inv2 = a2.inverse;
      final ident2 = a2 * inv2;

      check(ident2[0][0]).isCloseTo(1.0, 1e-10);
      check(ident2[0][1]).isCloseTo(0.0, 1e-10);
      check(ident2[1][0]).isCloseTo(0.0, 1e-10);
      check(ident2[1][1]).isCloseTo(1.0, 1e-10);

      final a3 = Matrix<double>.fromRows([
        [1.0, 2.0, 3.0],
        [0.0, 1.0, 4.0],
        [5.0, 6.0, 0.0],
      ]);
      final inv3 = a3.inverse;
      final ident3 = a3 * inv3;

      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 3; c++) {
          check(ident3[r][c]).isCloseTo(r == c ? 1.0 : 0.0, 1e-10);
        }
      }
    });

    test('inverse error conditions: non-square and singular', () {
      final nonSquare = Matrix<double>.filled(2, 3, 1.0);
      check(() => nonSquare.inverse).throws<ArgumentError>();

      final singular = Matrix<double>.fromRows([
        [1.0, 2.0],
        [2.0, 4.0],
      ]);
      check(() => singular.inverse).throws<ArgumentError>();
    });

    test('Float64Matrix det and inverse', () {
      final m = Float64Matrix.fromRows([
        [2.0, 1.0],
        [1.0, 2.0],
      ]);
      check(m.det).isCloseTo(3.0, 1e-10);

      final inv = m.inverse;
      check(inv[0][0]).isCloseTo(2.0 / 3.0, 1e-10);
      check(inv[0][1]).isCloseTo(-1.0 / 3.0, 1e-10);
      check(inv[1][0]).isCloseTo(-1.0 / 3.0, 1e-10);
      check(inv[1][1]).isCloseTo(2.0 / 3.0, 1e-10);
    });

    test('Complex matrix det and inverse', () {
      final cMat = Matrix<Complex>.fromRows([
        [const Complex(1.0, 1.0), const Complex(0.0, 0.0)],
        [const Complex(0.0, 0.0), const Complex(2.0, 0.0)],
      ]);
      check(cMat.det.a).isCloseTo(2.0, 1e-10);
      check(cMat.det.b).isCloseTo(2.0, 1e-10);

      final cInv = cMat.inverse;
      // 1 / (1 + i) = (1 - i) / 2 = 0.5 - 0.5i
      check(cInv[0][0].a).isCloseTo(0.5, 1e-10);
      check(cInv[0][0].b).isCloseTo(-0.5, 1e-10);
      check(cInv[1][1].a).isCloseTo(0.5, 1e-10);
      check(cInv[1][1].b).isCloseTo(0.0, 1e-10);
    });

    test('solve non-square matrix with Fraction Matrix RHS', () {
      final a = Matrix<Fraction>.fromRows([
        [Fraction(1), Fraction(2), Fraction(0)],
        [Fraction(0), Fraction(1), Fraction(1)],
      ], type: DataType.fraction);
      final b = Matrix<Fraction>.fromRows([
        [Fraction(5), Fraction(1)],
        [Fraction(3), Fraction(2)],
      ], type: DataType.fraction);
      final x = a.solve(b);
      check(x.rowCount).equals(3);
      check(x.colCount).equals(2);
      check((a * x).toNestedList()).deepEquals(b.toNestedList());
    });

    test('solve underdetermined system with Vector RHS in pure Dart', () {
      final prev = AccelerationManager.mode;
      try {
        AccelerationManager.mode = AccelerationMode.dart;
        final a = Matrix<double>.fromRows([
          [1.0, 2.0, 3.0],
          [4.0, 5.0, 6.0],
        ], type: DataType.float64);
        final b = Vector<double>.fromList([1.0, 2.0], type: DataType.float64);
        final x = a.solveVector(b);
        check(x.length).equals(3);
        final ax = a.apply(x);
        check(ax[0]).isCloseTo(1.0, 1e-10);
        check(ax[1]).isCloseTo(2.0, 1e-10);
      } finally {
        AccelerationManager.mode = prev;
      }
    });

    test('rectangular solve via dgels with Matrix and Vector RHS', () {
      // Overdetermined 3x2:
      final aOver = Matrix<double>.fromRows([
        [1.0, 0.0],
        [0.0, 1.0],
        [1.0, 1.0],
      ], type: DataType.float64);
      final bOverVec = Vector<double>.fromList([
        1.0,
        2.0,
        3.0,
      ], type: DataType.float64);
      final xOverVec = aOver.solveVector(bOverVec);
      check(xOverVec.length).equals(2);
      check(xOverVec[0]).isCloseTo(1.0, 1e-10);
      check(xOverVec[1]).isCloseTo(2.0, 1e-10);

      final bOverMat = Matrix<double>.fromRows([
        [1.0, 2.0],
        [2.0, 1.0],
        [3.0, 3.0],
      ], type: DataType.float64);
      final xOverMat = aOver.solve(bOverMat);
      check(xOverMat.rowCount).equals(2);
      check(xOverMat.colCount).equals(2);
      check(xOverMat[0][0]).isCloseTo(1.0, 1e-10);
      check(xOverMat[1][0]).isCloseTo(2.0, 1e-10);
      check(xOverMat[0][1]).isCloseTo(2.0, 1e-10);
      check(xOverMat[1][1]).isCloseTo(1.0, 1e-10);

      // Underdetermined 2x3:
      final aUnder = Matrix<double>.fromRows([
        [1.0, 0.0, 0.0],
        [0.0, 1.0, 0.0],
      ], type: DataType.float64);
      final bUnderVec = Vector<double>.fromList([
        3.0,
        4.0,
      ], type: DataType.float64);
      final xUnderVec = aUnder.solveVector(bUnderVec);
      check(xUnderVec.length).equals(3);
      check(xUnderVec[0]).isCloseTo(3.0, 1e-10);
      check(xUnderVec[1]).isCloseTo(4.0, 1e-10);
      check(xUnderVec[2]).isCloseTo(0.0, 1e-10);
    });

    test('complex underdetermined solve satisfies A * x = b', () {
      final a = Matrix<Complex>.fromRows([
        [
          const Complex(1.0, 2.0),
          const Complex(3.0, -1.0),
          const Complex(0.0, 4.0),
        ],
        [
          const Complex(2.0, -1.0),
          const Complex(1.0, 1.0),
          const Complex(-1.0, 2.0),
        ],
      ], type: DataType.complex);
      final b = Vector<Complex>.fromList([
        const Complex(5.0, 3.0),
        const Complex(-2.0, 4.0),
      ], type: DataType.complex);
      final x = a.solveVector(b);
      final ax = a.apply(x);
      check(ax[0].a).isCloseTo(5.0, 1e-9);
      check(ax[0].b).isCloseTo(3.0, 1e-9);
      check(ax[1].a).isCloseTo(-2.0, 1e-9);
      check(ax[1].b).isCloseTo(4.0, 1e-9);

      final bMat = Matrix<Complex>.fromRows([
        [const Complex(5.0, 3.0), const Complex(1.0, -1.0)],
        [const Complex(-2.0, 4.0), const Complex(3.0, 2.0)],
      ], type: DataType.complex);
      final xMat = a.solve(bMat);
      final axMat = a * xMat;
      for (var r = 0; r < 2; r++) {
        for (var c = 0; c < 2; c++) {
          check(axMat[r][c].a).isCloseTo(bMat[r][c].a, 1e-9);
          check(axMat[r][c].b).isCloseTo(bMat[r][c].b, 1e-9);
        }
      }
    });

    test(
      '0-dimension matrices in solve, multiply, apply, and negative indexing',
      () {
        final m0x0 = Float64Matrix.filled(0, 0, 0.0);
        final v0 = Float64Vector.filled(0, 0.0);
        check(m0x0.solveVector(v0).length).equals(0);
        check(m0x0.solve(m0x0).rowCount).equals(0);
        check((m0x0 * m0x0).rowCount).equals(0);
        check(m0x0.apply(v0).length).equals(0);

        final m0x2 = Float64Matrix.filled(0, 2, 0.0);
        final m2x0 = Float64Matrix.filled(2, 0, 0.0);
        check(m0x2.solveVector(v0).length).equals(2);
        final prod2x2 = m2x0 * m0x2;
        check(prod2x2.rowCount).equals(2);
        check(prod2x2.colCount).equals(2);
        check(prod2x2[0][0]).equals(0.0);
        check(m2x0.apply(v0).length).equals(2);

        final m = Float64Matrix.fromRows([
          [1.0, 2.0],
          [3.0, 4.0],
        ]);
        check(m.row(-1)[0]).equals(3.0);
        check(m.col(-1)[0]).equals(2.0);
      },
    );

    test('subMatrix with omitted rowEnd and colEnd', () {
      final m = Matrix<int>.fromRows([
        [1, 2, 3],
        [4, 5, 6],
        [7, 8, 9],
      ]);
      final sub = m.subMatrix(rowStart: 1, colStart: 1);
      check(sub.rowCount).equals(2);
      check(sub.colCount).equals(2);
      check(sub[0][0]).equals(5);
      check(sub[1][1]).equals(9);
    });

    test('transposed matrix vector apply both directions', () {
      final m = Matrix<double>.fromRows([
        [1.0, 2.0, 3.0],
        [4.0, 5.0, 6.0],
      ], type: DataType.float64);
      final v = Vector<double>.fromList([1.0, 2.0], type: DataType.float64);
      final mt = m.transposed;
      final res1 = mt.apply(v);
      check(res1.length).equals(3);
      check(res1[0]).equals(9.0);

      final v3 = Vector<double>.fromList([
        1.0,
        2.0,
        3.0,
      ], type: DataType.float64);
      final res2 = mt.applyTranspose(v3);
      check(res2.length).equals(2);
    });

    test('syrk fallback on integer matrix', () {
      final m = Matrix<int>.fromRows([
        [1, 2],
        [3, 4],
      ]);
      final res = m.syrk();
      check(res.rowCount).equals(2);
      check(res.colCount).equals(2);
    });

    test('applyTranspose vs applyConjugateTranspose on complex matrix', () {
      final a = Matrix<Complex>.fromRows([
        [const Complex(1, 2), const Complex(3, 4)],
        [const Complex(5, 6), const Complex(7, 8)],
      ], type: DataType.complex);
      final v = Vector<Complex>.fromList([
        const Complex(1, 0),
        const Complex(0, 1),
      ], type: DataType.complex);

      final atV = a.applyTranspose(v);
      final atVExpected = a.transposed.apply(v);
      check(atV.toList()).deepEquals(atVExpected.toList());
      check(atV[0]).equals(const Complex(-5, 7));
      check(atV[1]).equals(const Complex(-5, 11));

      final ahV = a.applyConjugateTranspose(v);
      final ahVExpected = a.conjugateTranspose.apply(v);
      check(ahV.toList()).deepEquals(ahVExpected.toList());
      check(ahV[0]).equals(const Complex(7, 3));
      check(ahV[1]).equals(const Complex(11, 3));
    });
  });

  group('Matrix constructors, views, and arithmetic', () {
    test('constructors: identity, fromRows, fromColumns, diagonal', () {
      final eye = Matrix<double>.identity(3);
      check(eye.rowCount).equals(3);
      check(eye.colCount).equals(3);
      check(eye.get(0, 0)).equals(1.0);
      check(eye.get(0, 1)).equals(0.0);
      check(eye.get(1, 1)).equals(1.0);

      final fromRows = Matrix<int>.fromRows([
        [1, 2],
        [3, 4],
      ]);
      check(fromRows.get(1, 0)).equals(3);

      final fromCols = Matrix<int>.fromColumns([
        [1, 3],
        [2, 4],
      ]);
      check(fromCols.get(1, 0)).equals(3);

      final diag = Matrix<double>.diagonal(Vector<double>.fromList([2.0, 5.0]));
      check(diag.get(0, 0)).equals(2.0);
      check(diag.get(1, 1)).equals(5.0);
      check(diag.get(0, 1)).equals(0.0);
    });

    test('views: row, col, transpose, subMatrix', () {
      final m = Matrix<int>.fromRows([
        [1, 2, 3],
        [4, 5, 6],
      ]);
      check(m.row(0).toList()).deepEquals([1, 2, 3]);
      check(m.col(2).toList()).deepEquals([3, 6]);

      final mt = m.transposed;
      check(mt.rowCount).equals(3);
      check(mt.colCount).equals(2);
      check(mt.get(2, 1)).equals(6);

      final sub = m.subMatrix(rowStart: 0, rowEnd: 2, colStart: 1, colEnd: 3);
      check(sub.rowCount).equals(2);
      check(sub.colCount).equals(2);
      check(sub.toNestedList() as List).deepEquals([
        [2, 3],
        [5, 6],
      ]);
    });

    test('matrix arithmetic and multiplication', () {
      final a = Matrix<double>.fromRows([
        [1.0, 2.0],
        [3.0, 4.0],
      ]);
      final b = Matrix<double>.fromRows([
        [5.0, 6.0],
        [7.0, 8.0],
      ]);

      check((a + b).toNestedList() as List).deepEquals([
        [6.0, 8.0],
        [10.0, 12.0],
      ]);

      check(a.hadamard(b).toNestedList() as List).deepEquals([
        [5.0, 12.0],
        [21.0, 32.0],
      ]);

      final prod = a * b;
      check(prod.toNestedList() as List).deepEquals([
        [19.0, 22.0],
        [43.0, 50.0],
      ]);
    });

    test('matrix diagonal, trace, and transposed getters', () {
      final m = Matrix<int>.fromRows([
        [1, 2, 3],
        [4, 5, 6],
        [7, 8, 9],
      ]);
      final diag = m.diagonal();
      check(diag.toList()).deepEquals([1, 5, 9]);
      check(diag.sum).equals(15);
      check(m.trace).equals(15);
      check(m.transposed.get(0, 1)).equals(4);
    });

    test(
      'matrix predicates: isSquare, isSymmetric, isDiagonal, triangular',
      () {
        final square = Matrix<int>.fromRows([
          [1, 2],
          [2, 3],
        ]);
        check(square.isSquare).isTrue();
        check(square.isSymmetric).isTrue();
        check(square.isDiagonal).isFalse();

        final rect = Matrix<int>.fromRows([
          [1, 2, 3],
          [4, 5, 6],
        ]);
        check(rect.isSquare).isFalse();
        check(rect.isSymmetric).isFalse();

        final diag = Matrix<int>.fromRows([
          [5, 0],
          [0, 8],
        ]);
        check(diag.isDiagonal).isTrue();
        check(diag.isLowerTriangular).isTrue();
        check(diag.isUpperTriangular).isTrue();
      },
    );

    test('matrix transformations: flipped, rotated, concatenated', () {
      final m = Matrix<int>.fromRows([
        [1, 2],
        [3, 4],
      ]);

      final flipH = m.flippedHorizontal();
      check(flipH.toNestedList() as List).deepEquals([
        [2, 1],
        [4, 3],
      ]);

      final flipV = m.flippedVertical();
      check(flipV.toNestedList() as List).deepEquals([
        [3, 4],
        [1, 2],
      ]);

      final rot1 = m.rotated(1);
      check(rot1.toNestedList() as List).deepEquals([
        [3, 1],
        [4, 2],
      ]);

      final rot2 = m.rotated(2);
      check(rot2.toNestedList() as List).deepEquals([
        [4, 3],
        [2, 1],
      ]);

      final m2 = Matrix<int>.fromRows([
        [5, 6],
        [7, 8],
      ]);
      final catH = m.concatHorizontal(m2);
      check(catH.toNestedList() as List).deepEquals([
        [1, 2, 5, 6],
        [3, 4, 7, 8],
      ]);

      final catV = m.concatVertical(m2);
      check(catV.toNestedList() as List).deepEquals([
        [1, 2],
        [3, 4],
        [5, 6],
        [7, 8],
      ]);
    });

    test('matrix norms and condition', () {
      final a = Matrix<double>.fromRows([
        [1.0, 2.0],
        [3.0, 4.0],
      ]);
      check(a.normFrobenius).isCloseTo(5.477225575, 1e-6);
      check(a.norm1).equals(6.0);
      check(a.normInfinity).equals(7.0);
      check(a.norm2).isCloseTo(5.4649857, 1e-4);
      check(a.rank).equals(2);
      check(a.cond).isGreaterThan(1.0);
      check(a.trace).equals(5.0);
    });

    test('matrix error handling on invalid shapes', () {
      check(
        () => Matrix.fromRows([
          [1, 2],
          [3],
        ]),
      ).throws<ArgumentError>();

      final nonSquare = Matrix<int>.filled(2, 3, 1);
      check(() => nonSquare.trace).throws<ArgumentError>();

      final m2 = Matrix<int>.fromRows([
        [1, 2],
        [3, 4],
      ]);
      final diffRows = Matrix<int>.filled(3, 2, 1);
      final diffCols = Matrix<int>.filled(2, 3, 1);
      check(() => m2.concatHorizontal(diffRows)).throws<ArgumentError>();
      check(() => m2.concatVertical(diffCols)).throws<ArgumentError>();
    });
  });

  group('Matrix<Complex> conjugateTranspose', () {
    test('conjugates and transposes elements', () {
      final a = Matrix<Complex>.fromRows([
        [const Complex(1.0, 2.0), const Complex(3.0, -4.0)],
        [const Complex(5.0, 0.0), const Complex(0.0, -6.0)],
      ], type: DataType.complex);

      final aH = a.conjugateTranspose;
      check(aH.rowCount).equals(2);
      check(aH.colCount).equals(2);

      check(aH.get(0, 0)).equals(const Complex(1.0, -2.0));
      check(aH.get(0, 1)).equals(const Complex(5.0, 0.0));
      check(aH.get(1, 0)).equals(const Complex(3.0, 4.0));
      check(aH.get(1, 1)).equals(const Complex(0.0, 6.0));

      final aHH = aH.conjugateTranspose;
      for (var r = 0; r < 2; r++) {
        for (var c = 0; c < 2; c++) {
          check(aHH.get(r, c)).equals(a.get(r, c));
        }
      }
    });

    test('conjugate transpose on rectangular matrix', () {
      final a = Matrix<Complex>.fromRows([
        [
          const Complex(1.0, 1.0),
          const Complex(2.0, 0.0),
          const Complex(0.0, -3.0),
        ],
        [
          const Complex(-1.0, 4.0),
          const Complex(5.0, -2.0),
          const Complex(6.0, 1.0),
        ],
      ], type: DataType.complex);

      final aH = a.conjugateTranspose;
      check(aH.rowCount).equals(3);
      check(aH.colCount).equals(2);

      check(aH.get(0, 0)).equals(const Complex(1.0, -1.0));
      check(aH.get(0, 1)).equals(const Complex(-1.0, -4.0));
      check(aH.get(2, 0)).equals(const Complex(0.0, 3.0));
      check(aH.get(2, 1)).equals(const Complex(6.0, -1.0));
    });

    test('0-dimension matrix operations, normFrobenius with multiple infinities, and Float64 redeclares', () {
      final m20 = Matrix<double>.filled(2, 0, 0.0);
      final m02 = Matrix<double>.filled(0, 2, 0.0);
      final prod = m20 * m02;
      check(prod.rowCount).equals(2);
      check(prod.colCount).equals(2);

      check(m20.apply(Vector<double>.filled(0, 0.0)).length).equals(2);
      check(m02.applyTranspose(Vector<double>.filled(0, 0.0)).length).equals(2);
      check(m02.applyConjugateTranspose(Vector<double>.filled(0, 0.0)).length)
          .equals(2);
      check(m20.syrk().rowCount).equals(2);
      check(m02.syrk().rowCount).equals(0);

      final infMat = Matrix<double>.fromRows([
        [double.infinity, double.infinity],
        [1.0, 2.0],
      ]);
      check(infMat.normFrobenius).equals(double.infinity);

      final nanVec = Vector<double>.fromList([1.0, double.nan, 3.0]);
      check(nanVec.norm(double.infinity).isNaN).isTrue();

      final f64v = Float64Vector.fromList([3.0, 4.0]);
      check(f64v.normalized().norm()).isCloseTo(1.0, 1e-12);
      check(f64v.copy()).equals(f64v);
      check(f64v.cumsum().toList()).deepEquals([3.0, 7.0]);
      check(f64v.cumprod().toList()).deepEquals([3.0, 12.0]);

      final f64m = Float64Matrix.fromRows([
        [2.0, 1.0],
        [1.0, 3.0],
      ]);
      check(f64m.copy()).equals(f64m);
      check(f64m.hadamard(f64m)[0][0]).equals(4.0);
      check(f64m.flippedHorizontal()[0][0]).equals(1.0);
      check(f64m.flippedVertical()[0][0]).equals(1.0);
      check(f64m.rotated(1).rowCount).equals(2);
      check(f64m.concatHorizontal(f64m).colCount).equals(4);
      check(f64m.concatVertical(f64m).rowCount).equals(4);
      check(f64m.solveVector(f64v).length).equals(2);
      check(f64m.solve(f64m).rowCount).equals(2);
      check(f64m.applyTranspose(f64v).length).equals(2);
      check(f64m.applyConjugateTranspose(f64v).length).equals(2);
      check(f64m.syrk().rowCount).equals(2);

      // Additional coverage: rotated(3), unary -, fromColumns mismatch, Float32 solve/syrk/apply, rank-deficient underdetermined
      check(f64m.rotated(3)[0][0]).equals(1.0);
      final genericMat = Matrix<int>.fromRows([
        [1, -2],
        [3, -4],
      ]);
      final negMat = -genericMat;
      check(negMat[0][0]).equals(-1);
      check(genericMat.toString()).contains('Matrix(2 x 2');
      check(genericMat.hashCode).equals(genericMat.tensor.hashCode);
      check(
        () => Matrix<int>.fromColumns([
          [1, 2],
          [3],
        ]),
      ).throws<ArgumentError>();

      final f32Mat = Matrix<double>.fromRows([
        [2.0, 1.0],
        [1.0, 3.0],
        [0.0, 1.0],
      ], type: DataType.float32);
      final f32B = Matrix<double>.fromRows([
        [5.0],
        [7.0],
        [2.0],
      ], type: DataType.float32);
      final f32Sol = f32Mat.solve(f32B);
      check(f32Sol.rowCount).equals(2);
      check(f32Mat.syrk().rowCount).equals(3);
      check(f32Mat.transposed.syrk(transpose: true).rowCount).equals(3);
      final f32Vec = Vector<double>.fromList([
        1.0,
        2.0,
      ], type: DataType.float32);
      check(f32Mat.apply(f32Vec).length).equals(3);
      check(f32Mat.transposed.applyTranspose(f32Vec).length).equals(3);

      final f32Under = Matrix<double>.fromRows([
        [1.0, 2.0, 3.0],
        [4.0, 5.0, 6.0],
      ], type: DataType.float32);
      final f32UnderB = Matrix<double>.fromRows([
        [1.0],
        [2.0],
      ], type: DataType.float32);
      check(f32Under.solve(f32UnderB).rowCount).equals(3);

      final rankDefUnder = Matrix<double>.fromRows([
        [0.0, 0.0, 0.0],
        [1.0, 2.0, 3.0],
      ], type: DataType.float32);
      check(() => rankDefUnder.solve(f32UnderB)).throws<StateError>();
    });
  });
}
