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
      check(matmulRes).isA<Matrix<double>>();
      check(matmulRes.rowCount).equals(2);
      check(matmulRes.colCount).equals(2);
      final x = Vector<double>.fromList([1.0, 0.0]);
      check(matmulRes.apply(x).toList()).deepEquals([1.0, 0.0]);

      // Check dense-sparse equivalence with larger rectangular matrices
      final denseA = Matrix<double>.fromRows([
        [2.0, 0.0, 1.0],
        [0.0, 3.0, 0.0],
      ]);
      final denseB = Matrix<double>.fromRows([
        [1.0, 2.0, 0.0, 4.0],
        [0.0, 1.0, 3.0, 0.0],
        [5.0, 0.0, 2.0, 1.0],
      ]);
      final csrA = CooMatrix.fromDense(denseA).toCsr();
      final denseAB = csrA.matmul(denseB);
      check(denseAB).isA<Matrix<double>>();
      final expectedAB = denseA * denseB;
      for (var r = 0; r < 2; r++) {
        for (var c = 0; c < 4; c++) {
          check(
            denseAB.apply(
              Vector<double>.fromList([
                for (var i = 0; i < 4; i++)
                  if (i == c) 1.0 else 0.0,
              ]),
            )[r],
          ).isCloseTo(expectedAB.get(r, c), 1e-10);
        }
      }
    });

    test('matmul with CsrMatrix produces sparse CsrMatrix', () {
      final denseA = Matrix<double>.fromRows([
        [10.0, 0.0, 0.0, 2.0],
        [0.0, 3.0, 0.0, 0.0],
        [1.0, 0.0, 4.0, 5.0],
      ]);
      final denseB = Matrix<double>.fromRows([
        [1.0, 0.0],
        [0.0, 2.0],
        [3.0, 1.0],
        [0.0, 4.0],
      ]);

      final csrA = CooMatrix.fromDense(denseA).toCsr();
      final csrB = CooMatrix.fromDense(denseB).toCsr();

      final res = csrA.matmul(csrB);
      check(res).isA<CsrMatrix<double>>();
      final csrRes = res as CsrMatrix<double>;

      final expected = denseA * denseB;
      final denseRes = csrRes.toDense();
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 2; c++) {
          check(denseRes.get(r, c)).isCloseTo(expected.get(r, c), 1e-10);
        }
      }
    });

    test('matmul with CooMatrix and CscMatrix', () {
      final denseA = Matrix<double>.fromRows([
        [1.0, 2.0],
        [3.0, 4.0],
      ]);
      final denseB = Matrix<double>.fromRows([
        [5.0, 6.0],
        [7.0, 8.0],
      ]);
      final csrA = CooMatrix.fromDense(denseA).toCsr();
      final cooB = CooMatrix.fromDense(denseB);
      final cscB = cooB.toCsc();

      final resFromCoo = csrA.matmul(cooB);
      check(resFromCoo).isA<CsrMatrix<double>>();
      final resFromCsc = csrA.matmul(cscB);
      check(resFromCsc).isA<CsrMatrix<double>>();

      final expected = denseA * denseB;
      for (var r = 0; r < 2; r++) {
        for (var c = 0; c < 2; c++) {
          check((resFromCoo as CsrMatrix<double>).toDense().get(r, c))
              .isCloseTo(expected.get(r, c), 1e-10);
          check((resFromCsc as CsrMatrix<double>).toDense().get(r, c))
              .isCloseTo(expected.get(r, c), 1e-10);
        }
      }
    });

    test('matmul sparse cancellation drops exact zeros', () {
      final denseA = Matrix<double>.fromRows([
        [1.0, 1.0],
      ]);
      final denseB = Matrix<double>.fromRows([
        [2.0],
        [-2.0],
      ]);
      final csrA = CooMatrix.fromDense(denseA).toCsr();
      final csrB = CooMatrix.fromDense(denseB).toCsr();

      final res = csrA.matmul(csrB) as CsrMatrix<double>;
      check(res.rowCount).equals(1);
      check(res.colCount).equals(1);
      check(res.nnz).equals(0);
      check(res.toDense().get(0, 0)).equals(0.0);
    });

    test('matmul with custom LinearOperator', () {
      final denseA = Matrix<double>.fromRows([
        [2.0, 0.0],
        [0.0, 3.0],
      ]);
      final csrA = CooMatrix.fromDense(denseA).toCsr();
      final customOp = _CustomScaleOperator(2, 2, DataType.float64, 5.0);

      final res = csrA.matmul(customOp);
      check(res).isA<Matrix<double>>();
      check(res.rowCount).equals(2);
      check(res.colCount).equals(2);
      final x = Vector<double>.fromList([1.0, 2.0]);
      check(res.apply(x).toList()).deepEquals([10.0, 30.0]);
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
    final csr = CooMatrix<double>.fromDense(Matrix<double>.identity(2)).toCsr();

    test('out of bounds index throws RangeError', () {
      check(() => csr.get(-1, 0)).throws<RangeError>();
      check(() => csr.get(0, 5)).throws<RangeError>();
    });

    test('incompatible operator dimension throws ArgumentError', () {
      final vWrong = Vector<double>.fromList([1.0, 2.0, 3.0]);
      check(() => csr.apply(vWrong)).throws<ArgumentError>();
      check(() => csr.applyTranspose(vWrong)).throws<ArgumentError>();

      final wrongOp = Matrix<double>.filled(3, 2, 0.0);
      check(() => csr.matmul(wrongOp)).throws<ArgumentError>();
    });

    test('invalid internal buffer length or indexing throws', () {
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
      check(
        () => CsrMatrix<double>(
          rowCount: 2,
          colCount: 2,
          rowPointers: [1, 1, 1],
          colIndices: [],
          values: [],
          type: DataType.float64,
        ),
      ).throws<ArgumentError>();
      check(
        () => CsrMatrix<double>(
          rowCount: 2,
          colCount: 2,
          rowPointers: [0, 2, 1],
          colIndices: [0],
          values: [1.0],
          type: DataType.float64,
        ),
      ).throws<ArgumentError>();
      check(
        () => CsrMatrix<double>(
          rowCount: 2,
          colCount: 2,
          rowPointers: [0, 1, 2],
          colIndices: [0, 2],
          values: [1.0, 2.0],
          type: DataType.float64,
        ),
      ).throws<RangeError>();
      check(
        () => CsrMatrix<double>(
          rowCount: -1,
          colCount: 2,
          rowPointers: const [],
          colIndices: const [],
          values: const [],
          type: DataType.float64,
        ),
      ).throws<ArgumentError>();
    });

    test('unsorted column indices access', () {
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

    test('conversions and vector operations', () {
      final fromDense = CsrMatrix<double>.fromDense(Matrix<double>.identity(2));
      check(fromDense.toCsc().nnz).equals(2);
      final vFlipped = Vector<double>(
        Vector<double>.fromList([1.0, 2.0]).tensor.flip(),
      );
      check(fromDense.apply(vFlipped).toList()).deepEquals([2.0, 1.0]);
      final vWrong = Vector<double>.fromList([1.0, 2.0, 3.0]);
      check(() => fromDense.applyConjugateTranspose(vWrong))
          .throws<ArgumentError>();
    });
  });

  group('CsrMatrix algebra', () {
    final a = CooMatrix<double>.fromEntries(2, 3, [
      (0, 0, 1.0),
      (0, 2, 2.0),
      (1, 1, 3.0),
    ]).toCsr();

    final b = CooMatrix<double>.fromEntries(2, 3, [
      (0, 0, 10.0),
      (1, 1, -3.0),
      (1, 2, 5.0),
    ]).toCsr();

    test('transposed', () {
      final at = a.transposed;
      check(at.rowCount).equals(3);
      check(at.colCount).equals(2);
      check(at.get(0, 0)).equals(1.0);
      check(at.get(2, 0)).equals(2.0);
      check(at.get(1, 1)).equals(3.0);
      check(at.transposed == a).isTrue();
    });

    test('scale', () {
      final scaled = a.scale(2.0);
      check(scaled.get(0, 0)).equals(2.0);
      check(scaled.get(0, 2)).equals(4.0);
      check(scaled.get(1, 1)).equals(6.0);
    });

    test('addition and subtraction', () {
      final sum = a + b;
      check(sum.rowCount).equals(2);
      check(sum.colCount).equals(3);
      check(sum.get(0, 0)).equals(11.0);
      check(sum.get(1, 1)).equals(0.0);
      check(sum.get(1, 2)).equals(5.0);

      final diff = a - b;
      check(diff.get(0, 0)).equals(-9.0);
      check(diff.get(1, 1)).equals(6.0);
    });

    test('dimension mismatch throws ArgumentError', () {
      final badDim = CooMatrix<double>.fromEntries(3, 2, []).toCsr();
      check(() => a + badDim).throws<ArgumentError>();
      check(() => a - badDim).throws<ArgumentError>();
    });

    test('equality and hashCode', () {
      final a2 = CooMatrix<double>.fromEntries(2, 3, [
        (0, 2, 2.0),
        (1, 1, 3.0),
        (0, 0, 1.0),
      ]).toCsr();
      check(a == a2).isTrue();
      check(a.hashCode).equals(a2.hashCode);
      check(a == b).isFalse();
    });

    test('string conversion', () {
      check(a.toString()).contains('CsrMatrix<double>(2 x 3, nnz: 3)');
    });
  });
}

class _CustomScaleOperator implements LinearOperator<double> {
  new(this.rowCount, this.colCount, this.type, this.scale);

  @override
  final int rowCount;

  @override
  final int colCount;

  @override
  final DataType<double> type;

  final double scale;

  @override
  Vector<double> apply(Vector<double> x) =>
      Vector<double>.generate(rowCount, (i) => x[i] * scale, type: type);

  @override
  Vector<double> applyTranspose(Vector<double> x) => apply(x);

  @override
  Vector<double> applyConjugateTranspose(Vector<double> x) => apply(x);

  @override
  LinearOperator<double> matmul(LinearOperator<double> other) =>
      throw UnimplementedError();
}
