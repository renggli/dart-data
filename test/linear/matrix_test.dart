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
      final x = a.solve(b);

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
      final x = a.solve(b);

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
      final x = a.solve(b);
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
      check(() => a.solve(bDeficient)).throws<StateError>();

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
      check(() => aInc.solve(bInc)).throws<StateError>();
    });

    test('Matrix.solve cross-type casting of Vector and Matrix RHS', () {
      final a = Matrix<double>.fromRows([
        [2.0, 0.0],
        [0.0, 3.0],
      ]);
      final bVec = Vector<num>.fromList([4, 9]);
      final xVec = a.solve<Vector<num>>(bVec);
      check(xVec[0]).isCloseTo(2.0, 1e-10);
      check(xVec[1]).isCloseTo(3.0, 1e-10);

      final bMat = Matrix<num>.fromRows([
        [4, 8],
        [9, 6],
      ]);
      final xMat = a.solve<Matrix<num>>(bMat);
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

      check(() => a.solve(v3)).throws<ArgumentError>();
      check(() => a.solve(m3)).throws<ArgumentError>();
      check(() => a.solve('invalid')).throws<ArgumentError>();
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
        final x = a.solve(b);
        check(x.length).equals(3);
        final ax = a.apply(x);
        check(ax[0]).isCloseTo(1.0, 1e-10);
        check(ax[1]).isCloseTo(2.0, 1e-10);
      } finally {
        AccelerationManager.mode = prev;
      }
    });

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
  });
}
