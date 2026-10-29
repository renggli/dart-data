import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('CooMatrix construction and conversions', () {
    test('fromDense and conversions', () {
      final dense = Matrix<double>.fromRows([
        [1.0, 0.0, 2.0],
        [0.0, 0.0, 3.0],
        [4.0, 5.0, 6.0],
      ]);
      final coo = CooMatrix.fromDense(dense);
      check(coo.rowCount).equals(3);
      check(coo.colCount).equals(3);
      check(coo.nnz).equals(6);
      check(coo.get(0, 0)).equals(1.0);
      check(coo.get(0, 1)).equals(0.0);
      check(coo.get(0, 2)).equals(2.0);
      check(coo.get(2, 1)).equals(5.0);

      final denseRoundtrip = coo.toDense();
      check(denseRoundtrip.toNestedList() as List)
          .deepEquals(dense.toNestedList() as List);
    });

    test('fromEntries and duplicates handling', () {
      final coo = CooMatrix<double>.fromEntries(2, 2, [
        (0, 0, 1.0),
        (0, 0, 4.0),
        (0, 1, 2.0),
        (1, 1, 3.0),
      ], type: DataType.float64);
      check(coo.nnz).equals(4);
      check(coo.get(0, 0)).equals(5.0);
      check(coo.get(0, 1)).equals(2.0);
      check(coo.get(1, 0)).equals(0.0);
      check(coo.get(1, 1)).equals(3.0);

      final dense = coo.toDense();
      check(dense.get(0, 0)).equals(5.0);

      final csr = coo.toCsr();
      check(csr.nnz).equals(3);
      check(csr.get(0, 0)).equals(5.0);
      check(csr.toDense().get(0, 0)).equals(5.0);

      final csc = coo.toCsc();
      check(csc.nnz).equals(3);
      check(csc.get(0, 0)).equals(5.0);
      check(csc.toDense().get(0, 0)).equals(5.0);
    });
  });

  group('CooMatrix operations', () {
    test('SpMV apply and applyTranspose', () {
      final dense = Matrix<double>.fromRows([
        [10.0, 0.0, 0.0, 2.0],
        [0.0, 3.0, 0.0, 0.0],
        [1.0, 0.0, 4.0, 5.0],
      ]);
      final coo = CooMatrix.fromDense(dense);
      final x = Vector<double>.fromList([2.0, 3.0, 1.0, 4.0]);

      final expected = dense.apply(x);
      check(coo.apply(x).toList()).deepEquals(expected.toList());

      final yT = Vector<double>.fromList([1.0, 2.0, 3.0]);
      final expectedT = dense.applyTranspose(yT);
      check(coo.applyTranspose(yT).toList()).deepEquals(expectedT.toList());
    });

    test('matmul with dense matrix', () {
      final dense = Matrix<double>.fromRows([
        [1.0, 2.0],
        [0.0, 3.0],
      ]);
      final coo = CooMatrix.fromDense(dense);
      final res = coo.matmul(dense);
      check(res.rowCount).equals(2);
      check(res.colCount).equals(2);
      final x = Vector<double>.fromList([1.0, 0.0]);
      check(res.apply(x).toList()).deepEquals([1.0, 0.0]);
    });

    test('complex applyTranspose vs applyConjugateTranspose', () {
      final dense = Matrix<Complex>.fromRows([
        [const Complex(1, 2), const Complex(3, 4)],
        [const Complex(5, 6), const Complex(7, 8)],
      ], type: DataType.complex);
      final coo = CooMatrix<Complex>.fromDense(dense);
      final v = Vector<Complex>.fromList([
        const Complex(1, 0),
        const Complex(0, 1),
      ], type: DataType.complex);

      final vtA = coo.applyTranspose(v);
      final vHA = coo.applyConjugateTranspose(v);
      check(vtA[0]).equals(const Complex(-5, 7));
      check(vHA[0]).equals(const Complex(7, 3));
    });
  });

  group('CooMatrix error validation', () {
    test('bounds and dimension validation', () {
      final coo = CooMatrix<double>.fromDense(Matrix<double>.identity(2));
      check(() => coo.get(-1, 0)).throws<RangeError>();
      check(() => coo.get(0, 5)).throws<RangeError>();
      check(() => CooMatrix<double>.fromEntries(2, 2, [(-1, 0, 1.0)]))
          .throws<RangeError>();

      final vWrong = Vector<double>.fromList([1.0, 2.0, 3.0]);
      check(() => coo.apply(vWrong)).throws<ArgumentError>();
      check(() => coo.applyTranspose(vWrong)).throws<ArgumentError>();

      check(
        () => CooMatrix<double>(
          rowCount: -1,
          colCount: 2,
          rowIndices: [],
          colIndices: [],
          values: [],
          type: DataType.float64,
        ),
      ).throws<ArgumentError>();
      check(
        () => CooMatrix<double>(
          rowCount: 2,
          colCount: 2,
          rowIndices: [0],
          colIndices: [],
          values: [1.0],
          type: DataType.float64,
        ),
      ).throws<ArgumentError>();
      check(
        () => CooMatrix<double>(
          rowCount: 2,
          colCount: 2,
          rowIndices: [2],
          colIndices: [0],
          values: [1.0],
          type: DataType.float64,
        ),
      ).throws<RangeError>();
      check(
        () => CooMatrix<double>(
          rowCount: 2,
          colCount: 2,
          rowIndices: [0],
          colIndices: [-1],
          values: [1.0],
          type: DataType.float64,
        ),
      ).throws<RangeError>();
    });
  });
}
