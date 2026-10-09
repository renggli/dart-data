import 'dart:math' as math;

import 'package:data/linear.dart';
import 'package:data/tensor.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('Vector', () {
    test('creation and element access', () {
      final v = Vector<double>.fromList([1.0, 2.0, 3.0]);
      expect(v.length, 3);
      expect(v[0], 1.0);
      expect(v[2], 3.0);
      v[1] = 5.0;
      expect(v[1], 5.0);
      expect(v.toList(), [1.0, 5.0, 3.0]);
    });

    test('arithmetic operations', () {
      final a = Vector<double>.fromList([1.0, 2.0, 3.0]);
      final b = Vector<double>.fromList([4.0, 5.0, 6.0]);

      expect((a + b).toList(), [5.0, 7.0, 9.0]);
      expect((b - a).toList(), [3.0, 3.0, 3.0]);
      expect((a * b).toList(), [4.0, 10.0, 18.0]);
      expect((b / a).toList(), [4.0, 2.5, 2.0]);
      expect((-a).toList(), [-1.0, -2.0, -3.0]);
      expect(a.scale(2.0).toList(), [2.0, 4.0, 6.0]);
    });

    test('dot product and outer product', () {
      final a = Vector<double>.fromList([1.0, 2.0, 3.0]);
      final b = Vector<double>.fromList([4.0, 5.0, 6.0]);
      // 1*4 + 2*5 + 3*6 = 4 + 10 + 18 = 32
      expect(a.dot(b), 32.0);

      final outer = a.outer(b);
      expect(outer.rowCount, 3);
      expect(outer.colCount, 3);
      expect(outer.get(0, 0), 4.0);
      expect(outer.get(0, 1), 5.0);
      expect(outer.get(1, 0), 8.0);
      expect(outer.get(2, 2), 18.0);
    });

    test('norm and normalized', () {
      final v = Vector<double>.fromList([3.0, 4.0]);
      expect(v.norm(2), 5.0);
      expect(v.norm(1), 7.0);
      expect(v.norm(double.infinity), 4.0);

      final u = v.normalized();
      expect(u[0], closeTo(0.6, 1e-10));
      expect(u[1], closeTo(0.8, 1e-10));
      expect(u.norm(2), closeTo(1.0, 1e-10));
    });

    test('matrix conversion and subVector', () {
      final v = Vector<double>.fromList([1.0, 2.0, 3.0, 4.0]);
      final colMat = v.toMatrix(asColumn: true);
      expect(colMat.rowCount, 4);
      expect(colMat.colCount, 1);
      expect(colMat.get(2, 0), 3.0);

      final sub = v.subVector(1, 3);
      expect(sub.length, 2);
      expect(sub.toList(), [2.0, 3.0]);
    });
  });

  group('Matrix', () {
    test('constructors: identity, fromRows, fromColumns, diagonal', () {
      final eye = Matrix<double>.identity(3);
      expect(eye.rowCount, 3);
      expect(eye.colCount, 3);
      expect(eye.get(0, 0), 1.0);
      expect(eye.get(0, 1), 0.0);
      expect(eye.get(1, 1), 1.0);

      final fromRows = Matrix<int>.fromRows([
        [1, 2],
        [3, 4],
      ]);
      expect(fromRows.get(1, 0), 3);

      final fromCols = Matrix<int>.fromColumns([
        [1, 3],
        [2, 4],
      ]);
      expect(fromCols.get(1, 0), 3);

      final diag = Matrix<double>.diagonal(Vector<double>.fromList([2.0, 5.0]));
      expect(diag.get(0, 0), 2.0);
      expect(diag.get(1, 1), 5.0);
      expect(diag.get(0, 1), 0.0);
    });

    test('views: row, col, transpose, subMatrix', () {
      final m = Matrix<int>.fromRows([
        [1, 2, 3],
        [4, 5, 6],
      ]);
      expect(m.row(0).toList(), [1, 2, 3]);
      expect(m.col(2).toList(), [3, 6]);

      final mt = m.transpose();
      expect(mt.rowCount, 3);
      expect(mt.colCount, 2);
      expect(mt.get(2, 1), 6);

      final sub = m.subMatrix(rowStart: 0, rowEnd: 2, colStart: 1, colEnd: 3);
      expect(sub.rowCount, 2);
      expect(sub.colCount, 2);
      expect(sub.toNestedList(), [
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

      expect((a + b).toNestedList(), [
        [6.0, 8.0],
        [10.0, 12.0],
      ]);

      expect(a.hadamard(b).toNestedList(), [
        [5.0, 12.0],
        [21.0, 32.0],
      ]);

      // Matrix product:
      // [1*5 + 2*7, 1*6 + 2*8] = [19, 22]
      // [3*5 + 4*7, 3*6 + 4*8] = [43, 50]
      final prod = a * b;
      expect(prod.toNestedList(), [
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
      expect(y.toList(), [7.0, 16.0]);

      final yt = Vector<double>.fromList([2.0, 1.0]);
      // A^T * yt = [1*2 + 4*1, 2*2 + 5*1, 3*2 + 6*1] = [6, 9, 12]
      final xt = a.applyTranspose(yt);
      expect(xt.toList(), [6.0, 9.0, 12.0]);
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
      expect(coo.nnz, 6);

      final csr = coo.toCsr();
      expect(csr.nnz, 6);
      expect(csr.get(0, 0), 1.0);
      expect(csr.get(0, 1), 0.0);
      expect(csr.get(0, 2), 2.0);
      expect(csr.get(1, 2), 3.0);
      expect(csr.get(2, 0), 4.0);

      final csc = csr.toCsc();
      expect(csc.nnz, 6);
      expect(csc.get(2, 1), 5.0);

      final denseFromCsr = csr.toDense();
      expect(denseFromCsr.toNestedList(), dense.toNestedList());

      final denseFromCsc = csc.toDense();
      expect(denseFromCsc.toNestedList(), dense.toNestedList());
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

      expect(coo.apply(x).toList(), expected.toList());
      expect(csr.apply(x).toList(), expected.toList());
      expect(csc.apply(x).toList(), expected.toList());

      final yT = Vector<double>.fromList([1.0, 2.0, 3.0]);
      expect(coo.applyTranspose(yT).toList(), expectedT.toList());
      expect(csr.applyTranspose(yT).toList(), expectedT.toList());
      expect(csc.applyTranspose(yT).toList(), expectedT.toList());
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
      expect(x[0], closeTo(1.0, 1e-6));
      expect(x[1], closeTo(2.0, 1e-6));
      expect(x[2], closeTo(3.0, 1e-6));

      // Test with CSR sparse representation
      final csr = CooMatrix.fromDense(a).toCsr();
      final xSparse = conjugateGradient(csr, b);
      expect(xSparse[0], closeTo(1.0, 1e-6));
      expect(xSparse[1], closeTo(2.0, 1e-6));
      expect(xSparse[2], closeTo(3.0, 1e-6));
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
      expect(x[0], closeTo(1.0, 1e-6));
      expect(x[1], closeTo(2.0, 1e-6));
      expect(x[2], closeTo(3.0, 1e-6));
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
      expect(x[0], closeTo(1.0, 1e-5));
      expect(x[1], closeTo(2.0, 1e-5));
      expect(x[2], closeTo(3.0, 1e-5));
    });

    test('Matrix.solve direct solver method', () {
      final a = Matrix<double>.fromRows([
        [2.0, 1.0],
        [1.0, 3.0],
      ]);
      final b = Vector<double>.fromList([4.0, 7.0]);
      final x = a.solve(b);
      expect(x[0], closeTo(1.0, 1e-6));
      expect(x[1], closeTo(2.0, 1e-6));
    });

    test('Matrix diagonal, trace, and transposed getters', () {
      final m = Matrix<int>.fromRows([
        [1, 2, 3],
        [4, 5, 6],
        [7, 8, 9],
      ]);
      final diag = m.diagonal();
      expect(diag.toList(), [1, 5, 9]);
      expect(diag.sum, 15);
      expect(m.trace, 15);
      expect(m.transposed.get(0, 1), 4);
    });

    test('Matrix and CooMatrix constructors with non-double types', () {
      final emptyRows = Matrix<int>.fromRows([]);
      expect(emptyRows.rowCount, 0);
      expect(emptyRows.colCount, 0);

      final emptyCols = Matrix<int>.fromColumns([]);
      expect(emptyCols.rowCount, 0);
      expect(emptyCols.colCount, 0);

      final id3 = Matrix<int>.identity(3);
      expect(id3.rowCount, 3);
      expect(id3.colCount, 3);
      expect(id3.get(0, 0), 1);
      expect(id3.get(0, 1), 0);

      final cooEmpty = CooMatrix<int>.fromEntries(2, 2, []);
      expect(cooEmpty.nnz, 0);
      expect(cooEmpty.get(0, 0), 0);
    });

    test('CsrMatrix and CscMatrix direct constructors', () {
      final dense = Matrix<double>.fromRows([
        [1.0, 0.0, 2.0],
        [0.0, 3.0, 0.0],
      ]);
      final csr = CsrMatrix<double>.fromDense(dense);
      expect(csr.nnz, 3);
      expect(csr.get(0, 2), 2.0);

      final csc = CscMatrix<double>.fromDense(dense);
      expect(csc.nnz, 3);
      expect(csc.get(1, 1), 3.0);
    });
    test(
      'Matrix predicates: isSquare, isSymmetric, isDiagonal, triangular',
      () {
        final square = Matrix<int>.fromRows([
          [1, 2],
          [2, 3],
        ]);
        expect(square.isSquare, isTrue);
        expect(square.isSymmetric, isTrue);
        expect(square.isDiagonal, isFalse);

        final rect = Matrix<int>.fromRows([
          [1, 2, 3],
          [4, 5, 6],
        ]);
        expect(rect.isSquare, isFalse);
        expect(rect.isSymmetric, isFalse);

        final diag = Matrix<int>.fromRows([
          [5, 0],
          [0, 8],
        ]);
        expect(diag.isDiagonal, isTrue);
        expect(diag.isLowerTriangular, isTrue);
        expect(diag.isUpperTriangular, isTrue);

        final lower = Matrix<int>.fromRows([
          [1, 0],
          [2, 3],
        ]);
        expect(lower.isLowerTriangular, isTrue);
        expect(lower.isUpperTriangular, isFalse);

        final upper = Matrix<int>.fromRows([
          [1, 2],
          [0, 3],
        ]);
        expect(upper.isUpperTriangular, isTrue);
        expect(upper.isLowerTriangular, isFalse);
      },
    );

    test('Matrix transformations: flipped, rotated, concatenated', () {
      final m = Matrix<int>.fromRows([
        [1, 2],
        [3, 4],
      ]);

      final flipH = m.flippedHorizontal();
      expect(flipH.toNestedList(), [
        [2, 1],
        [4, 3],
      ]);

      final flipV = m.flippedVertical();
      expect(flipV.toNestedList(), [
        [3, 4],
        [1, 2],
      ]);

      final rot1 = m.rotated(1);
      expect(rot1.toNestedList(), [
        [3, 1],
        [4, 2],
      ]);

      final rot2 = m.rotated(2);
      expect(rot2.toNestedList(), [
        [4, 3],
        [2, 1],
      ]);

      final m2 = Matrix<int>.fromRows([
        [5, 6],
        [7, 8],
      ]);
      final catH = m.concatHorizontal(m2);
      expect(catH.toNestedList(), [
        [1, 2, 5, 6],
        [3, 4, 7, 8],
      ]);

      final catV = m.concatVertical(m2);
      expect(catV.toNestedList(), [
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
      expect(a.normFrobenius, closeTo(5.477225575, 1e-6));
      // 1-norm: max col sum = max(1+3, 2+4) = 6.0
      expect(a.norm1, 6.0);
      // Infinity norm: max row sum = max(1+2, 3+4) = 7.0
      expect(a.normInfinity, 7.0);
      // 2-norm: largest singular value ≈ 5.4649857
      expect(a.norm2, closeTo(5.4649857, 1e-4));
      // Rank: 2
      expect(a.rank, 2);
      expect(a.cond, greaterThan(1.0));
      expect(a.trace, 5.0);
    });

    test('Matrix constructors, operations, and inversion errors', () {
      final nativeMat = Matrix<double>.native(2, 2);
      expect(nativeMat.rowCount, 2);
      expect(nativeMat.colCount, 2);

      // Inconsistent columns throw
      expect(
        () => Matrix<int>.fromColumns([
          [1, 2],
          [3],
        ]),
        throwsArgumentError,
      );

      // Submatrix out of bounds
      final m = Matrix<int>.fromRows([
        [1, 2],
        [3, 4],
      ]);
      expect(
        () => m.subMatrix(rowStart: -1, rowEnd: 2, colStart: 0, colEnd: 2),
        throwsRangeError,
      );
      expect(
        () => m.subMatrix(rowStart: 0, rowEnd: 3, colStart: 0, colEnd: 2),
        throwsRangeError,
      );

      // Apply dimension mismatch
      final vecWrong = Vector<double>.fromList([1.0, 2.0, 3.0]);
      final a = Matrix<double>.fromRows([
        [1.0, 2.0],
        [3.0, 4.0],
      ]);
      expect(() => a.apply(vecWrong), throwsArgumentError);
      expect(() => a.applyTranspose(vecWrong), throwsArgumentError);

      // LU decomposition errors: non-square det, singular solve
      final nonSquare = Matrix<double>.fromRows([
        [1.0, 2.0, 3.0],
        [4.0, 5.0, 6.0],
      ]);
      expect(() => nonSquare.lu.det, throwsArgumentError);

      final singular = Matrix<double>.fromRows([
        [1.0, 2.0],
        [2.0, 4.0],
      ]);
      expect(
        () => singular.lu.solve(
          Matrix<double>.identity(2, type: DataType.float64),
        ),
        throwsArgumentError,
      );

      // Cholesky decomposition errors: non-SPD det, solve
      final nonSpd = Matrix<double>.fromRows([
        [-1.0, 0.0],
        [0.0, -1.0],
      ]);
      expect(() => nonSpd.cholesky.det, throwsArgumentError);
      expect(
        () => nonSpd.cholesky.solve(
          Matrix<double>.identity(2, type: DataType.float64),
        ),
        throwsArgumentError,
      );
      final nonSquareChol = CholeskyDecomposition(nonSquare);
      expect(nonSquareChol.isSymmetricPositiveDefinite, isFalse);
      expect(nonSpd.cholesky.L.rowCount, 2);

      // Non-double / Float32 Matrix.apply
      final intMat = Matrix<int>.fromRows([
        [1, 2],
        [3, 4],
      ]);
      final intVec = Vector<int>.fromList([5, 6]);
      expect(intMat.apply(intVec).toList(), [17, 39]);
      expect(intMat.applyTranspose(intVec).toList(), [23, 34]);
    });

    test('Vector comprehensive constructors, operations, and errors', () {
      final filledVec = Vector<double>.filled(3, 7.0);
      expect(filledVec.toList(), [7.0, 7.0, 7.0]);

      final genVec = Vector<int>.generate(4, (i) => i * 3);
      expect(genVec.toList(), [0, 3, 6, 9]);

      final nativeVec = Vector<double>.native(3);
      expect(nativeVec.length, 3);

      final fromIter = Vector<int>.fromIterable([10, 20, 30]);
      expect(fromIter.toList(), [10, 20, 30]);

      final copyVec = fromIter.copy();
      expect(copyVec.toList(), fromIter.toList());
      expect(copyVec.sum, 60);
      expect(copyVec.toString(), 'Vector([10, 20, 30])');

      // subVector with omitted end
      expect(fromIter.subVector(1).toList(), [20, 30]);

      // Vector norms
      final v = Vector<double>.fromList([1.0, 2.0, 2.0]);
      expect(v.norm(3), closeTo(math.pow(17.0, 1.0 / 3.0), 1e-6));

      final intNormVec = Vector<int>.fromList([3, 4]);
      expect(intNormVec.norm(2), 5.0);

      // Zero vector normalization throws
      final zeroVec = Vector<double>.fromList([0.0, 0.0]);
      expect(zeroVec.normalized, throwsStateError);

      // Dimension mismatch throws
      final v3 = Vector<double>.fromList([1.0, 2.0, 3.0]);
      final v2 = Vector<double>.fromList([1.0, 2.0]);
      expect(() => v3.dot(v2), throwsArgumentError);
      expect(() => v3.addScaled(v2, 2.0), throwsArgumentError);

      // Generic addScaled & scaleInPlace
      final vInt1 = Vector<int>.fromList([1, 2, 3]);
      final vInt2 = Vector<int>.fromList([10, 20, 30]);
      vInt1.addScaled(vInt2, 2);
      expect(vInt1.toList(), [21, 42, 63]);

      vInt1.scaleInPlace(2);
      expect(vInt1.toList(), [42, 84, 126]);

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
      expect(f32_1.dot(f32_2), 32.0);
      expect(f32_1.norm(2), closeTo(math.sqrt(14.0), 1e-4));

      f32_1.addScaled(f32_2, 2.0);
      expect(f32_1.toList()[0], closeTo(9.0, 1e-4));

      f32_1.scaleInPlace(0.5);
      expect(f32_1.toList()[0], closeTo(4.5, 1e-4));
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
        expect(csc.toCoo().toDense().toNestedList(), dense.toNestedList());

        // matmul between sparse and dense
        final matmulRes = csr.matmul(dense);
        expect(matmulRes.rowCount, 2);
        expect(matmulRes.colCount, 2);

        final cscMatmul = csc.matmul(dense);
        expect(cscMatmul.rowCount, 2);

        final cooMatmul = coo.matmul(dense);
        expect(cooMatmul.rowCount, 2);

        // Errors: get out of bounds
        expect(() => coo.get(-1, 0), throwsRangeError);
        expect(() => coo.get(0, 5), throwsRangeError);
        expect(() => csr.get(-1, 0), throwsRangeError);
        expect(() => csr.get(0, 5), throwsRangeError);
        expect(() => csc.get(-1, 0), throwsRangeError);
        expect(() => csc.get(0, 5), throwsRangeError);

        // Coordinate out of bounds during CooMatrix creation
        expect(
          () => CooMatrix<double>.fromEntries(2, 2, [(-1, 0, 1.0)]),
          throwsRangeError,
        );

        // Dimension mismatch on apply, applyTranspose, matmul
        final vWrong = Vector<double>.fromList([1.0, 2.0, 3.0]);
        expect(() => coo.apply(vWrong), throwsArgumentError);
        expect(() => coo.applyTranspose(vWrong), throwsArgumentError);
        expect(() => csr.apply(vWrong), throwsArgumentError);
        expect(() => csr.applyTranspose(vWrong), throwsArgumentError);
        expect(() => csc.apply(vWrong), throwsArgumentError);
        expect(() => csc.applyTranspose(vWrong), throwsArgumentError);

        final wrongOp = Matrix<double>.filled(3, 2, 0.0);
        expect(() => csr.matmul(wrongOp), throwsArgumentError);

        final cscEntries = CscMatrix<double>.fromEntries(2, 2, [(0, 0, 5.0)]);
        expect(cscEntries.get(0, 0), 5.0);
        expect(cscEntries.get(1, 0), 0.0);
        expect(cscEntries.get(0, 1), 0.0);

        // Non-contiguous applyTranspose on CSC
        final vFlipped = Vector<double>(
          Tensor<double>.fromIterable([1.0, 2.0]).flip(),
        );
        expect(vFlipped.tensor.isContiguous, isFalse);
        expect(cscEntries.applyTranspose(vFlipped)[0], 10.0);
      },
    );

    test('Iterative solvers comprehensive suite: errors and fast returns', () {
      final nonSquare = Matrix<double>.filled(2, 3, 1.0);
      final b2 = Vector<double>.fromList([1.0, 2.0]);
      final b3 = Vector<double>.fromList([1.0, 2.0, 3.0]);

      // Conjugate gradient errors
      expect(() => conjugateGradient(nonSquare, b2), throwsArgumentError);
      final square2 = Matrix<double>.identity(2);
      expect(() => conjugateGradient(square2, b3), throwsArgumentError);

      // Fast return when initial residual is zero
      final xExact = Vector<double>.fromList([1.0, 2.0]);
      final bExact = square2.apply(xExact);
      final xSolved = conjugateGradient(square2, bExact, x0: xExact);
      expect(xSolved.toList(), xExact.toList());

      // GMRES errors and fast return
      expect(() => gmres(nonSquare, b2), throwsArgumentError);
      expect(() => gmres(square2, b3), throwsArgumentError);

      final xGmresExact = gmres(square2, bExact, x0: xExact);
      expect(xGmresExact.toList(), xExact.toList());

      // GMRES with small restart
      final a = Matrix<double>.fromRows([
        [4.0, 1.0],
        [1.0, 3.0],
      ]);
      final b = Vector<double>.fromList([5.0, 4.0]);
      final xRestart = gmres(a, b, restart: 1);
      expect(xRestart[0], closeTo(1.0, 1e-5));
      expect(xRestart[1], closeTo(1.0, 1e-5));
    });

    test('Matrix operations, representations, error handling, and norms', () {
      // 1. Matrix.fromRows ragged error
      expect(
        () => Matrix.fromRows([
          [1, 2],
          [3],
        ]),
        throwsArgumentError,
      );

      // 2. Matrix.trace on non-square matrix
      final nonSquare = Matrix<int>.filled(2, 3, 1);
      expect(() => nonSquare.trace, throwsStateError);

      // 3. Matrix.rotated(3)
      final m2 = Matrix<int>.fromRows([
        [1, 2],
        [3, 4],
      ]);
      final rot3 = m2.rotated(3);
      expect(rot3.toNestedList(), [
        [2, 4],
        [1, 3],
      ]);

      // 4. concatHorizontal & concatVertical errors
      final diffRows = Matrix<int>.filled(3, 2, 1);
      final diffCols = Matrix<int>.filled(2, 3, 1);
      expect(() => m2.concatHorizontal(diffRows), throwsArgumentError);
      expect(() => m2.concatVertical(diffCols), throwsArgumentError);

      // 5. solve errors
      final v2 = Vector<double>.fromList([1.0, 2.0]);
      final v3 = Vector<double>.fromList([1.0, 2.0, 3.0]);
      final m2d = Matrix<double>.fromRows([
        [2.0, 1.0],
        [1.0, 2.0],
      ]);
      final nonSquareD = Matrix<double>.filled(2, 3, 1.0);
      expect(() => nonSquareD.solve(v2), throwsStateError);
      expect(() => m2d.solve(v3), throwsArgumentError);

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
      expect(xComp[0].a, closeTo(2.0, 1e-5));
      expect(xComp[1].a, closeTo(3.0, 1e-5));

      // 7. Unary negation
      final negM = -m2;
      expect(negM.toNestedList(), [
        [-1, -2],
        [-3, -4],
      ]);

      // 8. matmul with generic LinearOperator and dimension mismatch
      final op = CooMatrix<int>.fromDense(m2);
      final composed = m2.matmul(op);
      expect((composed as Matrix<int>).toNestedList(), [
        [7, 10],
        [15, 22],
      ]);
      expect(() => m2.matmul(diffRows), throwsArgumentError);

      // 9. apply and applyTranspose with non-contiguous matrices/vectors and Float32List
      final mTransposed = m2.transpose();
      final applied = mTransposed.apply(Vector<int>.fromList([1, 2]));
      expect(applied.toList(), [7, 10]);

      final m32 = Matrix<double>.fromRows([
        [1.0, 2.0],
        [3.0, 4.0],
      ], type: DataType.float32);
      final v32 = Vector<double>.fromList([1.0, 2.0], type: DataType.float32);
      final appliedTrans32 = m32.applyTranspose(v32);
      expect(appliedTrans32.toList(), [7.0, 10.0]);

      // 10. syrk fallback (pure Dart)
      final syrkInt = m2.syrk();
      expect(syrkInt.toNestedList(), [
        [5, 11],
        [11, 25],
      ]);

      // 11. toString
      expect(m2.toString(), contains('Matrix(2 x 2'));

      // 12. norm.dart: trace extension and Frobenius norm scale branch
      final mNorm = Matrix<double>.fromRows([
        [10.0, 1.0],
        [0.0, 2.0],
      ]);
      expect(mNorm.trace, 12.0);
      expect(MatrixNormExtension(mNorm).trace, 12.0);
      expect(mNorm.normFrobenius, closeTo(math.sqrt(100 + 1 + 4), 1e-6));
    });
  });
}
