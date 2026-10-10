import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/tensor.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('Vector', () {
    test('creation and element access', () {
      final vector = Vector<double>.fromList([1.0, 2.0, 3.0]);
      check(vector.length).equals(3);
      check(vector[0]).equals(1.0);
      check(vector[2]).equals(3.0);
      vector[1] = 5.0;
      check(vector[1]).equals(5.0);
      check(vector.toList()).deepEquals([1.0, 5.0, 3.0]);
    });

    test('arithmetic operations', () {
      final a = Vector<double>.fromList([1.0, 2.0, 3.0]);
      final b = Vector<double>.fromList([4.0, 5.0, 6.0]);

      check((a + b).toList()).deepEquals([5.0, 7.0, 9.0]);
      check((b - a).toList()).deepEquals([3.0, 3.0, 3.0]);
      check((a * b).toList()).deepEquals([4.0, 10.0, 18.0]);
      check((b / a).toList()).deepEquals([4.0, 2.5, 2.0]);
      check((-a).toList()).deepEquals([-1.0, -2.0, -3.0]);
      check(a.scale(2.0).toList()).deepEquals([2.0, 4.0, 6.0]);
    });

    test('dot product and outer product', () {
      final a = Vector<double>.fromList([1.0, 2.0, 3.0]);
      final b = Vector<double>.fromList([4.0, 5.0, 6.0]);
      // 1*4 + 2*5 + 3*6 = 4 + 10 + 18 = 32
      check(a.dot(b)).equals(32.0);

      final outer = a.outer(b);
      check(outer.rowCount).equals(3);
      check(outer.colCount).equals(3);
      check(outer.get(0, 0)).equals(4.0);
      check(outer.get(0, 1)).equals(5.0);
      check(outer.get(1, 0)).equals(8.0);
      check(outer.get(2, 2)).equals(18.0);
    });

    test('norm and normalized', () {
      final vector = Vector<double>.fromList([3.0, 4.0]);
      check(vector.norm(2)).equals(5.0);
      check(vector.norm(1)).equals(7.0);
      check(vector.norm(double.infinity)).equals(4.0);

      final normalized = vector.normalized();
      check(normalized[0]).isCloseTo(0.6, 1e-10);
      check(normalized[1]).isCloseTo(0.8, 1e-10);
      check(normalized.norm(2)).isCloseTo(1.0, 1e-10);
    });

    test('matrix conversion and subVector', () {
      final vector = Vector<double>.fromList([1.0, 2.0, 3.0, 4.0]);
      final colMat = vector.toMatrix(asColumn: true);
      check(colMat.rowCount).equals(4);
      check(colMat.colCount).equals(1);
      check(colMat.get(2, 0)).equals(3.0);

      final sub = vector.subVector(1, 3);
      check(sub.length).equals(2);
      check(sub.toList()).deepEquals([2.0, 3.0]);
    });
  });

  group('Matrix', () {
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

      final mt = m.transpose();
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

      // Matrix product:
      // [1*5 + 2*7, 1*6 + 2*8] = [19, 22]
      // [3*5 + 4*7, 3*6 + 4*8] = [43, 50]
      final prod = a * b;
      check(prod.toNestedList() as List).deepEquals([
        [19.0, 22.0],
        [43.0, 50.0],
      ]);
    });

    test('LinearOperator apply and applyTranspose', () {
      final a = Matrix<double>.fromRows([
        [1.0, 2.0, 3.0],
        [4.0, 5.0, 6.0],
      ]);
      final x = Vector<double>.fromList([1.0, 0.0, 2.0]);
      // A * x = [1*1 + 2*0 + 3*2, 4*1 + 5*0 + 6*2] = [7, 16]
      final y = a.apply(x);
      check(y.toList()).deepEquals([7.0, 16.0]);

      final yt = Vector<double>.fromList([2.0, 1.0]);
      // A^T * yt = [1*2 + 4*1, 2*2 + 5*1, 3*2 + 6*1] = [6, 9, 12]
      final xt = a.applyTranspose(yt);
      check(xt.toList()).deepEquals([6.0, 9.0, 12.0]);
    });
  });

  group('Sparse matrices: COO, CSR, CSC', () {
    test('creation and roundtrip conversions', () {
      // 3x3 matrix:
      // [1, 0, 2]
      // [0, 0, 3]
      // [4, 5, 6]
      final dense = Matrix<double>.fromRows([
        [1.0, 0.0, 2.0],
        [0.0, 0.0, 3.0],
        [4.0, 5.0, 6.0],
      ]);

      final coo = CooMatrix.fromDense(dense);
      check(coo.nnz).equals(6);

      final csr = coo.toCsr();
      check(csr.nnz).equals(6);
      check(csr.get(0, 0)).equals(1.0);
      check(csr.get(0, 1)).equals(0.0);
      check(csr.get(0, 2)).equals(2.0);
      check(csr.get(1, 2)).equals(3.0);
      check(csr.get(2, 0)).equals(4.0);

      final csc = csr.toCsc();
      check(csc.nnz).equals(6);
      check(csc.get(2, 1)).equals(5.0);

      final denseFromCsr = csr.toDense();
      check(denseFromCsr.toNestedList() as List)
          .deepEquals(dense.toNestedList() as List);

      final denseFromCsc = csc.toDense();
      check(denseFromCsc.toNestedList() as List)
          .deepEquals(dense.toNestedList() as List);
    });

    test('SpMV apply matches dense apply', () {
      final dense = Matrix<double>.fromRows([
        [10.0, 0.0, 0.0, 2.0],
        [0.0, 3.0, 0.0, 0.0],
        [1.0, 0.0, 4.0, 5.0],
      ]);
      final x = Vector<double>.fromList([2.0, 3.0, 1.0, 4.0]);

      final expected = dense.apply(x);
      final expectedT = dense.applyTranspose(
        Vector<double>.fromList([1.0, 2.0, 3.0]),
      );

      final coo = CooMatrix.fromDense(dense);
      final csr = coo.toCsr();
      final csc = coo.toCsc();

      check(coo.apply(x).toList()).deepEquals(expected.toList());
      check(csr.apply(x).toList()).deepEquals(expected.toList());
      check(csc.apply(x).toList()).deepEquals(expected.toList());

      final yT = Vector<double>.fromList([1.0, 2.0, 3.0]);
      check(coo.applyTranspose(yT).toList()).deepEquals(expectedT.toList());
      check(csr.applyTranspose(yT).toList()).deepEquals(expectedT.toList());
      check(csc.applyTranspose(yT).toList()).deepEquals(expectedT.toList());
    });
  });

  group('Iterative solvers', () {
    test('Conjugate Gradient on symmetric positive-definite system', () {
      // 3x3 SPD matrix:
      // [4, 1, 0]
      // [1, 3, 1]
      // [0, 1, 2]
      final a = Matrix<double>.fromRows([
        [4.0, 1.0, 0.0],
        [1.0, 3.0, 1.0],
        [0.0, 1.0, 2.0],
      ]);
      // True solution x = [1, 2, 3]
      // b = A * x = [4*1 + 1*2, 1*1 + 3*2 + 1*3, 1*2 + 2*3] = [6, 10, 8]
      final b = Vector<double>.fromList([6.0, 10.0, 8.0]);

      final x = conjugateGradient(a, b);
      check(x[0]).isCloseTo(1.0, 1e-6);
      check(x[1]).isCloseTo(2.0, 1e-6);
      check(x[2]).isCloseTo(3.0, 1e-6);

      // Test with CSR sparse representation
      final csr = CooMatrix.fromDense(a).toCsr();
      final xSparse = conjugateGradient(csr, b);
      check(xSparse[0]).isCloseTo(1.0, 1e-6);
      check(xSparse[1]).isCloseTo(2.0, 1e-6);
      check(xSparse[2]).isCloseTo(3.0, 1e-6);
    });

    test('GMRES on non-symmetric system', () {
      // Non-symmetric 3x3 matrix:
      // [2, 1, 0]
      // [0, 3, 2]
      // [1, 0, 4]
      final a = Matrix<double>.fromRows([
        [2.0, 1.0, 0.0],
        [0.0, 3.0, 2.0],
        [1.0, 0.0, 4.0],
      ]);
      // True solution x = [1, 2, 3]
      // b = [2*1 + 1*2, 3*2 + 2*3, 1*1 + 4*3] = [4, 12, 13]
      final b = Vector<double>.fromList([4.0, 12.0, 13.0]);

      final x = gmres(a, b);
      check(x[0]).isCloseTo(1.0, 1e-6);
      check(x[1]).isCloseTo(2.0, 1e-6);
      check(x[2]).isCloseTo(3.0, 1e-6);
    });

    test('GMRES on non-symmetric system with negative matrix entries', () {
      final a = Matrix<double>.fromRows([
        [-2.0, 1.0, 0.0],
        [1.0, -3.0, 2.0],
        [0.0, 1.0, -4.0],
      ]);
      // True solution x = [1, 2, 3]
      // b = [-2*1 + 1*2 = 0, 1*1 - 3*2 + 2*3 = 1, 1*2 - 4*3 = -10]
      final b = Vector<double>.fromList([0.0, 1.0, -10.0]);

      final x = gmres(a, b);
      check(x[0]).isCloseTo(1.0, 1e-5);
      check(x[1]).isCloseTo(2.0, 1e-5);
      check(x[2]).isCloseTo(3.0, 1e-5);
    });

    test('Matrix.solve direct solver method', () {
      final a = Matrix<double>.fromRows([
        [2.0, 1.0],
        [1.0, 3.0],
      ]);
      final b = Vector<double>.fromList([4.0, 7.0]);
      final x = a.solve(b);
      check(x[0]).isCloseTo(1.0, 1e-6);
      check(x[1]).isCloseTo(2.0, 1e-6);
    });

    test('Matrix diagonal, trace, and transposed getters', () {
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

    test('Matrix and CooMatrix constructors with non-double types', () {
      final emptyRows = Matrix<int>.fromRows([]);
      check(emptyRows.rowCount).equals(0);
      check(emptyRows.colCount).equals(0);

      final emptyCols = Matrix<int>.fromColumns([]);
      check(emptyCols.rowCount).equals(0);
      check(emptyCols.colCount).equals(0);

      final id3 = Matrix<int>.identity(3);
      check(id3.rowCount).equals(3);
      check(id3.colCount).equals(3);
      check(id3.get(0, 0)).equals(1);
      check(id3.get(0, 1)).equals(0);

      final cooEmpty = CooMatrix<int>.fromEntries(2, 2, []);
      check(cooEmpty.nnz).equals(0);
      check(cooEmpty.get(0, 0)).equals(0);
    });

    test('CsrMatrix and CscMatrix direct constructors', () {
      final dense = Matrix<double>.fromRows([
        [1.0, 0.0, 2.0],
        [0.0, 3.0, 0.0],
      ]);
      final csr = CsrMatrix<double>.fromDense(dense);
      check(csr.nnz).equals(3);
      check(csr.get(0, 2)).equals(2.0);

      final csc = CscMatrix<double>.fromDense(dense);
      check(csc.nnz).equals(3);
      check(csc.get(1, 1)).equals(3.0);
    });
    test(
      'Matrix predicates: isSquare, isSymmetric, isDiagonal, triangular',
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

        final lower = Matrix<int>.fromRows([
          [1, 0],
          [2, 3],
        ]);
        check(lower.isLowerTriangular).isTrue();
        check(lower.isUpperTriangular).isFalse();

        final upper = Matrix<int>.fromRows([
          [1, 2],
          [0, 3],
        ]);
        check(upper.isUpperTriangular).isTrue();
        check(upper.isLowerTriangular).isFalse();
      },
    );

    test('Matrix transformations: flipped, rotated, concatenated', () {
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

    test('Matrix norms, condition, and rank', () {
      final a = Matrix<double>.fromRows([
        [1.0, 2.0],
        [3.0, 4.0],
      ]);
      // Frobenius: sqrt(1 + 4 + 9 + 16) = sqrt(30) ≈ 5.477225575
      check(a.normFrobenius).isCloseTo(5.477225575, 1e-6);
      // 1-norm: max col sum = max(1+3, 2+4) = 6.0
      check(a.norm1).equals(6.0);
      // Infinity norm: max row sum = max(1+2, 3+4) = 7.0
      check(a.normInfinity).equals(7.0);
      // 2-norm: largest singular value ≈ 5.4649857
      check(a.norm2).isCloseTo(5.4649857, 1e-4);
      // Rank: 2
      check(a.rank).equals(2);
      check(a.cond).isGreaterThan(1.0);
      check(a.trace).equals(5.0);
    });

    test('Matrix constructors, operations, and inversion errors', () {
      final nativeMat = Matrix<double>.native(2, 2);
      check(nativeMat.rowCount).equals(2);
      check(nativeMat.colCount).equals(2);

      // Inconsistent columns throw
      check(
        () => Matrix<int>.fromColumns([
          [1, 2],
          [3],
        ]),
      ).throws<ArgumentError>();

      // Submatrix out of bounds
      final m = Matrix<int>.fromRows([
        [1, 2],
        [3, 4],
      ]);
      check(() => m.subMatrix(rowStart: -1, rowEnd: 2, colStart: 0, colEnd: 2))
          .throws<RangeError>();
      check(() => m.subMatrix(rowStart: 0, rowEnd: 3, colStart: 0, colEnd: 2))
          .throws<RangeError>();

      // Apply dimension mismatch
      final vecWrong = Vector<double>.fromList([1.0, 2.0, 3.0]);
      final a = Matrix<double>.fromRows([
        [1.0, 2.0],
        [3.0, 4.0],
      ]);
      check(() => a.apply(vecWrong)).throws<ArgumentError>();
      check(() => a.applyTranspose(vecWrong)).throws<ArgumentError>();

      // LU decomposition errors: non-square det, singular solve
      final nonSquare = Matrix<double>.fromRows([
        [1.0, 2.0, 3.0],
        [4.0, 5.0, 6.0],
      ]);
      check(() => nonSquare.lu.det).throws<ArgumentError>();

      final singular = Matrix<double>.fromRows([
        [1.0, 2.0],
        [2.0, 4.0],
      ]);
      check(
        () => singular.lu.solve(
          Matrix<double>.identity(2, type: DataType.float64),
        ),
      ).throws<ArgumentError>();

      // Cholesky decomposition errors: non-SPD det, solve
      final nonSpd = Matrix<double>.fromRows([
        [-1.0, 0.0],
        [0.0, -1.0],
      ]);
      check(() => nonSpd.cholesky.det).throws<ArgumentError>();
      check(
        () => nonSpd.cholesky.solve(
          Matrix<double>.identity(2, type: DataType.float64),
        ),
      ).throws<ArgumentError>();
      final nonSquareChol = CholeskyDecomposition(nonSquare);
      check(nonSquareChol.isSymmetricPositiveDefinite).isFalse();
      check(nonSpd.cholesky.L.rowCount).equals(2);

      // Non-double / Float32 Matrix.apply
      final intMat = Matrix<int>.fromRows([
        [1, 2],
        [3, 4],
      ]);
      final intVec = Vector<int>.fromList([5, 6]);
      check(intMat.apply(intVec).toList()).deepEquals([17, 39]);
      check(intMat.applyTranspose(intVec).toList()).deepEquals([23, 34]);
    });

    test('Vector comprehensive constructors, operations, and errors', () {
      final filledVec = Vector<double>.filled(3, 7.0);
      check(filledVec.toList()).deepEquals([7.0, 7.0, 7.0]);

      final genVec = Vector<int>.generate(4, (i) => i * 3);
      check(genVec.toList()).deepEquals([0, 3, 6, 9]);

      final nativeVec = Vector<double>.native(3);
      check(nativeVec.length).equals(3);

      final fromIter = Vector<int>.fromIterable([10, 20, 30]);
      check(fromIter.toList()).deepEquals([10, 20, 30]);

      final copyVec = fromIter.copy();
      check(copyVec.toList()).deepEquals(fromIter.toList());
      check(copyVec.sum).equals(60);
      check(copyVec.toString()).equals('Vector([10, 20, 30])');

      // subVector with omitted end
      check(fromIter.subVector(1).toList()).deepEquals([20, 30]);

      // Vector norms
      final vector = Vector<double>.fromList([1.0, 2.0, 2.0]);
      check(vector.norm(3)).isCloseTo(math.pow(17.0, 1.0 / 3.0), 1e-6);

      final intNormVec = Vector<int>.fromList([3, 4]);
      check(intNormVec.norm(2)).equals(5.0);

      // Zero vector normalization throws
      final zeroVec = Vector<double>.fromList([0.0, 0.0]);
      check(zeroVec.normalized).throws<StateError>();

      // Dimension mismatch throws
      final v3 = Vector<double>.fromList([1.0, 2.0, 3.0]);
      final v2 = Vector<double>.fromList([1.0, 2.0]);
      check(() => v3.dot(v2)).throws<ArgumentError>();
      check(() => v3.addScaled(v2, 2.0)).throws<ArgumentError>();

      // Generic addScaled & scaleInPlace
      final vInt1 = Vector<int>.fromList([1, 2, 3]);
      final vInt2 = Vector<int>.fromList([10, 20, 30]);
      vInt1.addScaled(vInt2, 2);
      check(vInt1.toList()).deepEquals([21, 42, 63]);

      vInt1.scaleInPlace(2);
      check(vInt1.toList()).deepEquals([42, 84, 126]);

      // Float32List dot, addScaled, scaleInPlace, norm
      final f32_1 = Vector<double>.fromList([
        1.0,
        2.0,
        3.0,
      ], type: DataType.float32);
      final f32_2 = Vector<double>.fromList([
        4.0,
        5.0,
        6.0,
      ], type: DataType.float32);
      check(f32_1.dot(f32_2)).equals(32.0);
      check(f32_1.norm(2)).isCloseTo(math.sqrt(14.0), 1e-4);

      f32_1.addScaled(f32_2, 2.0);
      check(f32_1.toList()[0]).isCloseTo(9.0, 1e-4);

      f32_1.scaleInPlace(0.5);
      check(f32_1.toList()[0]).isCloseTo(4.5, 1e-4);
    });

    test(
      'Sparse matrices comprehensive suite: conversions, matmul, errors',
      () {
        final dense = Matrix<double>.fromRows([
          [1.0, 2.0],
          [0.0, 3.0],
        ]);
        final coo = CooMatrix.fromDense(dense);
        final csr = coo.toCsr();
        final csc = csr.toCsc();

        // toDense and toCoo roundtrips
        check(csc.toCoo().toDense().toNestedList() as List)
            .deepEquals(dense.toNestedList() as List);

        // matmul between sparse and dense
        final matmulRes = csr.matmul(dense);
        check(matmulRes.rowCount).equals(2);
        check(matmulRes.colCount).equals(2);

        final cscMatmul = csc.matmul(dense);
        check(cscMatmul.rowCount).equals(2);

        final cooMatmul = coo.matmul(dense);
        check(cooMatmul.rowCount).equals(2);

        // Errors: get out of bounds
        check(() => coo.get(-1, 0)).throws<RangeError>();
        check(() => coo.get(0, 5)).throws<RangeError>();
        check(() => csr.get(-1, 0)).throws<RangeError>();
        check(() => csr.get(0, 5)).throws<RangeError>();
        check(() => csc.get(-1, 0)).throws<RangeError>();
        check(() => csc.get(0, 5)).throws<RangeError>();

        // Coordinate out of bounds during CooMatrix creation
        check(() => CooMatrix<double>.fromEntries(2, 2, [(-1, 0, 1.0)]))
            .throws<RangeError>();

        // Dimension mismatch on apply, applyTranspose, matmul
        final vWrong = Vector<double>.fromList([1.0, 2.0, 3.0]);
        check(() => coo.apply(vWrong)).throws<ArgumentError>();
        check(() => coo.applyTranspose(vWrong)).throws<ArgumentError>();
        check(() => csr.apply(vWrong)).throws<ArgumentError>();
        check(() => csr.applyTranspose(vWrong)).throws<ArgumentError>();
        check(() => csc.apply(vWrong)).throws<ArgumentError>();
        check(() => csc.applyTranspose(vWrong)).throws<ArgumentError>();

        final wrongOp = Matrix<double>.filled(3, 2, 0.0);
        check(() => csr.matmul(wrongOp)).throws<ArgumentError>();

        final cscEntries = CscMatrix<double>.fromEntries(2, 2, [(0, 0, 5.0)]);
        check(cscEntries.get(0, 0)).equals(5.0);
        check(cscEntries.get(1, 0)).equals(0.0);
        check(cscEntries.get(0, 1)).equals(0.0);

        // Non-contiguous applyTranspose on CSC
        final vFlipped = Vector<double>(
          Tensor<double>.fromIterable([1.0, 2.0]).flip(),
        );
        check(vFlipped.tensor.isContiguous).isFalse();
        check(cscEntries.applyTranspose(vFlipped)[0]).equals(10.0);
      },
    );

    test('Iterative solvers comprehensive suite: errors and fast returns', () {
      final nonSquare = Matrix<double>.filled(2, 3, 1.0);
      final b2 = Vector<double>.fromList([1.0, 2.0]);
      final b3 = Vector<double>.fromList([1.0, 2.0, 3.0]);

      // Conjugate gradient errors
      check(() => conjugateGradient(nonSquare, b2)).throws<ArgumentError>();
      final square2 = Matrix<double>.identity(2);
      check(() => conjugateGradient(square2, b3)).throws<ArgumentError>();

      // Fast return when initial residual is zero
      final xExact = Vector<double>.fromList([1.0, 2.0]);
      final bExact = square2.apply(xExact);
      final xSolved = conjugateGradient(square2, bExact, x0: xExact);
      check(xSolved.toList()).deepEquals(xExact.toList());

      // GMRES errors and fast return
      check(() => gmres(nonSquare, b2)).throws<ArgumentError>();
      check(() => gmres(square2, b3)).throws<ArgumentError>();

      final xGmresExact = gmres(square2, bExact, x0: xExact);
      check(xGmresExact.toList()).deepEquals(xExact.toList());

      // GMRES with small restart
      final a = Matrix<double>.fromRows([
        [4.0, 1.0],
        [1.0, 3.0],
      ]);
      final b = Vector<double>.fromList([5.0, 4.0]);
      final xRestart = gmres(a, b, restart: 1);
      check(xRestart[0]).isCloseTo(1.0, 1e-5);
      check(xRestart[1]).isCloseTo(1.0, 1e-5);
    });

    test('Matrix operations, representations, error handling, and norms', () {
      // 1. Matrix.fromRows ragged error
      check(
        () => Matrix.fromRows([
          [1, 2],
          [3],
        ]),
      ).throws<ArgumentError>();

      // 2. Matrix.trace on non-square matrix
      final nonSquare = Matrix<int>.filled(2, 3, 1);
      check(() => nonSquare.trace).throws<StateError>();

      // 3. Matrix.rotated(3)
      final m2 = Matrix<int>.fromRows([
        [1, 2],
        [3, 4],
      ]);
      final rot3 = m2.rotated(3);
      check(rot3.toNestedList() as List).deepEquals([
        [2, 4],
        [1, 3],
      ]);

      // 4. concatHorizontal & concatVertical errors
      final diffRows = Matrix<int>.filled(3, 2, 1);
      final diffCols = Matrix<int>.filled(2, 3, 1);
      check(() => m2.concatHorizontal(diffRows)).throws<ArgumentError>();
      check(() => m2.concatVertical(diffCols)).throws<ArgumentError>();

      // 5. solve errors
      final v2 = Vector<double>.fromList([1.0, 2.0]);
      final v3 = Vector<double>.fromList([1.0, 2.0, 3.0]);
      final m2d = Matrix<double>.fromRows([
        [2.0, 1.0],
        [1.0, 2.0],
      ]);
      final nonSquareD = Matrix<double>.filled(2, 3, 1.0);
      check(() => nonSquareD.solve(v2)).throws<StateError>();
      check(() => m2d.solve(v3)).throws<ArgumentError>();

      // 6. solve on non-double matrix (falls back to GMRES)
      final mComp = Matrix<Complex>.fromRows([
        [const Complex(2.0), const Complex(0.0)],
        [const Complex(0.0), const Complex(3.0)],
      ]);
      final vComp = Vector<Complex>.fromList([
        const Complex(4.0),
        const Complex(9.0),
      ]);
      final xComp = mComp.solve(vComp);
      check(xComp[0].a).isCloseTo(2.0, 1e-5);
      check(xComp[1].a).isCloseTo(3.0, 1e-5);

      // 7. Unary negation
      final negM = -m2;
      check(negM.toNestedList() as List).deepEquals([
        [-1, -2],
        [-3, -4],
      ]);

      // 8. matmul with generic LinearOperator and dimension mismatch
      final op = CooMatrix<int>.fromDense(m2);
      final composed = m2.matmul(op);
      check((composed as Matrix<int>).toNestedList() as List).deepEquals([
        [7, 10],
        [15, 22],
      ]);
      check(() => m2.matmul(diffRows)).throws<ArgumentError>();

      // 9. apply and applyTranspose with non-contiguous matrices/vectors and Float32List
      final mTransposed = m2.transpose();
      final applied = mTransposed.apply(Vector<int>.fromList([1, 2]));
      check(applied.toList()).deepEquals([7, 10]);

      final m32 = Matrix<double>.fromRows([
        [1.0, 2.0],
        [3.0, 4.0],
      ], type: DataType.float32);
      final v32 = Vector<double>.fromList([1.0, 2.0], type: DataType.float32);
      final appliedTrans32 = m32.applyTranspose(v32);
      check(appliedTrans32.toList()).deepEquals([7.0, 10.0]);

      // 10. syrk fallback (pure Dart)
      final syrkInt = m2.syrk();
      check(syrkInt.toNestedList() as List).deepEquals([
        [5, 11],
        [11, 25],
      ]);

      // 11. toString
      check(m2.toString()).contains('Matrix(2 x 2');

      // 12. norm.dart: trace extension and Frobenius norm scale branch
      final mNorm = Matrix<double>.fromRows([
        [10.0, 1.0],
        [0.0, 2.0],
      ]);
      check(mNorm.trace).equals(12.0);
      check(MatrixNormExtension(mNorm).trace).equals(12.0);
      check(mNorm.normFrobenius).isCloseTo(math.sqrt(100 + 1 + 4), 1e-6);
    });
  });
}
