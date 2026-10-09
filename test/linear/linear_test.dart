import 'package:data/linear.dart';
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
    });
  });
}
