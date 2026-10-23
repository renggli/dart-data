import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/tensor.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('CscMatrix construction and conversions', () {
    test('fromDense, toCoo, and toDense roundtrip', () {
      final dense = Matrix<double>.fromRows([
        [1.0, 0.0, 2.0],
        [0.0, 0.0, 3.0],
        [4.0, 5.0, 6.0],
      ]);
      final coo = CooMatrix.fromDense(dense);
      final csc = coo.toCsc();

      check(csc.rowCount).equals(3);
      check(csc.colCount).equals(3);
      check(csc.nnz).equals(6);
      check(csc.get(0, 0)).equals(1.0);
      check(csc.get(0, 1)).equals(0.0);
      check(csc.get(0, 2)).equals(2.0);
      check(csc.get(1, 2)).equals(3.0);
      check(csc.get(2, 0)).equals(4.0);
      check(csc.get(2, 1)).equals(5.0);

      final denseFromCsc = csc.toDense();
      check(denseFromCsc.toNestedList() as List)
          .deepEquals(dense.toNestedList() as List);

      final cooFromCsc = csc.toCoo();
      check(cooFromCsc.nnz).equals(6);
      check(cooFromCsc.toDense().toNestedList() as List)
          .deepEquals(dense.toNestedList() as List);
    });

    test('fromEntries constructor', () {
      final cscEntries = CscMatrix<double>.fromEntries(2, 2, [(0, 0, 5.0)]);
      check(cscEntries.get(0, 0)).equals(5.0);
      check(cscEntries.get(1, 0)).equals(0.0);
      check(cscEntries.get(0, 1)).equals(0.0);
    });
  });

  group('CscMatrix operations', () {
    test('SpMV apply and applyTranspose', () {
      final dense = Matrix<double>.fromRows([
        [10.0, 0.0, 0.0, 2.0],
        [0.0, 3.0, 0.0, 0.0],
        [1.0, 0.0, 4.0, 5.0],
      ]);
      final csc = CooMatrix.fromDense(dense).toCsc();
      final x = Vector<double>.fromList([2.0, 3.0, 1.0, 4.0]);

      final expected = dense.apply(x);
      check(csc.apply(x).toList()).deepEquals(expected.toList());

      final yT = Vector<double>.fromList([1.0, 2.0, 3.0]);
      final expectedT = dense.applyTranspose(yT);
      check(csc.applyTranspose(yT).toList()).deepEquals(expectedT.toList());
    });

    test('non-contiguous applyTranspose', () {
      final cscEntries = CscMatrix<double>.fromEntries(2, 2, [
        (0, 0, 5.0),
        (1, 1, 10.0),
      ]);
      final vFlipped = Vector<double>(
        Tensor<double>.fromIterable([1.0, 2.0]).flip(),
      );
      check(vFlipped.tensor.isContiguous).isFalse();
      final res = cscEntries.applyTranspose(vFlipped);
      check(res[0]).equals(10.0);
      check(res[1]).equals(10.0);
    });

    test('matmul with dense matrix', () {
      final dense = Matrix<double>.fromRows([
        [1.0, 2.0],
        [0.0, 3.0],
      ]);
      final csc = CooMatrix.fromDense(dense).toCsc();
      final matmulRes = csc.matmul(dense);
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
      final csc = CooMatrix<Complex>.fromDense(dense).toCsc();
      final v = Vector<Complex>.fromList([
        const Complex(1, 0),
        const Complex(0, 1),
      ], type: DataType.complex);

      final vtA = csc.applyTranspose(v);
      final vHA = csc.applyConjugateTranspose(v);
      check(vtA[0]).equals(const Complex(-5, 7));
      check(vHA[0]).equals(const Complex(7, 3));
    });
  });

  group('CscMatrix error validation', () {
    test('bounds and dimension validation', () {
      final csc = CooMatrix<double>.fromDense(Matrix<double>.identity(2))
          .toCsc();
      check(() => csc.get(-1, 0)).throws<RangeError>();
      check(() => csc.get(0, 5)).throws<RangeError>();

      final vWrong = Vector<double>.fromList([1.0, 2.0, 3.0]);
      check(() => csc.apply(vWrong)).throws<ArgumentError>();
      check(() => csc.applyTranspose(vWrong)).throws<ArgumentError>();
    });
  });
}
