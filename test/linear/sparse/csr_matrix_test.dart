import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('CsrMatrix construction and conversions', () {
    test('fromDense, toCoo, and toDense roundtrip', () {
      final dense = Matrix<double>.fromRows([
        [1.0, 0.0, 2.0],
        [0.0, 0.0, 3.0],
        [4.0, 5.0, 6.0],
      ]);
      final coo = CooMatrix.fromDense(dense);
      final csr = coo.toCsr();

      check(csr.rowCount).equals(3);
      check(csr.colCount).equals(3);
      check(csr.nnz).equals(6);
      check(csr.get(0, 0)).equals(1.0);
      check(csr.get(0, 1)).equals(0.0);
      check(csr.get(0, 2)).equals(2.0);
      check(csr.get(1, 2)).equals(3.0);
      check(csr.get(2, 0)).equals(4.0);

      final denseFromCsr = csr.toDense();
      check(denseFromCsr.toNestedList() as List)
          .deepEquals(dense.toNestedList() as List);

      final cooFromCsr = csr.toCoo();
      check(cooFromCsr.nnz).equals(6);
      check(cooFromCsr.toDense().toNestedList() as List)
          .deepEquals(dense.toNestedList() as List);
    });

    test('fromEntries constructor', () {
      final csr = CsrMatrix<double>.fromEntries(2, 2, [
        (0, 0, 5.0),
        (1, 1, 10.0),
      ], type: DataType.float64);
      check(csr.nnz).equals(2);
      check(csr.get(0, 0)).equals(5.0);
      check(csr.get(0, 1)).equals(0.0);
      check(csr.get(1, 1)).equals(10.0);
    });
  });

  group('CsrMatrix operations', () {
    test('SpMV apply and applyTranspose', () {
      final dense = Matrix<double>.fromRows([
        [10.0, 0.0, 0.0, 2.0],
        [0.0, 3.0, 0.0, 0.0],
        [1.0, 0.0, 4.0, 5.0],
      ]);
      final csr = CooMatrix.fromDense(dense).toCsr();
      final x = Vector<double>.fromList([2.0, 3.0, 1.0, 4.0]);

      final expected = dense.apply(x);
      check(csr.apply(x).toList()).deepEquals(expected.toList());

      final yT = Vector<double>.fromList([1.0, 2.0, 3.0]);
      final expectedT = dense.applyTranspose(yT);
      check(csr.applyTranspose(yT).toList()).deepEquals(expectedT.toList());
    });

    test('matmul with dense matrix', () {
      final dense = Matrix<double>.fromRows([
        [1.0, 2.0],
        [0.0, 3.0],
      ]);
      final csr = CooMatrix.fromDense(dense).toCsr();
      final matmulRes = csr.matmul(dense);
      check(matmulRes.rowCount).equals(2);
      check(matmulRes.colCount).equals(2);
      final x = Vector<double>.fromList([1.0, 0.0]);
      check(matmulRes.apply(x).toList()).deepEquals([1.0, 0.0]);
    });

    test('complex applyTranspose vs applyConjugateTranspose', () {
      final dense = Matrix<Complex>.fromRows([
        [const Complex(1, 2), const Complex(3, 4)],
        [const Complex(5, 6), const Complex(7, 8)],
      ], type: DataType.complex);
      final csr = CooMatrix<Complex>.fromDense(dense).toCsr();
      final v = Vector<Complex>.fromList([
        const Complex(1, 0),
        const Complex(0, 1),
      ], type: DataType.complex);

      final vtA = csr.applyTranspose(v);
      final vHA = csr.applyConjugateTranspose(v);
      check(vtA[0]).equals(const Complex(-5, 7));
      check(vHA[0]).equals(const Complex(7, 3));
    });
  });

  group('CsrMatrix error validation', () {
    test('bounds and dimension validation', () {
      final csr = CooMatrix<double>.fromDense(Matrix<double>.identity(2))
          .toCsr();
      check(() => csr.get(-1, 0)).throws<RangeError>();
      check(() => csr.get(0, 5)).throws<RangeError>();

      final vWrong = Vector<double>.fromList([1.0, 2.0, 3.0]);
      check(() => csr.apply(vWrong)).throws<ArgumentError>();
      check(() => csr.applyTranspose(vWrong)).throws<ArgumentError>();

      final wrongOp = Matrix<double>.filled(3, 2, 0.0);
      check(() => csr.matmul(wrongOp)).throws<ArgumentError>();

      check(
        () => CsrMatrix<double>(
          rowCount: 2,
          colCount: 2,
          rowPointers: [0, 1],
          colIndices: [0],
          values: [1.0],
          type: DataType.float64,
        ),
      ).throws<ArgumentError>();
      check(
        () => CsrMatrix<double>(
          rowCount: 2,
          colCount: 2,
          rowPointers: [0, 1, 1],
          colIndices: [0, 1],
          values: [1.0],
          type: DataType.float64,
        ),
      ).throws<ArgumentError>();

      final unsortedCsr = CsrMatrix<double>(
        rowCount: 1,
        colCount: 3,
        rowPointers: [0, 2],
        colIndices: [2, 0],
        values: [5.0, 3.0],
        type: DataType.float64,
      );
      check(unsortedCsr.get(0, 0)).equals(3.0);
      check(unsortedCsr.get(0, 2)).equals(5.0);
    });
  });
}
