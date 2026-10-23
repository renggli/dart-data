import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('LinearOperator', () {
    test('rowCount, colCount, type, and apply', () {
      final LinearOperator<double> op = Matrix<double>.fromRows([
        [1.0, 2.0, 3.0],
        [4.0, 5.0, 6.0],
      ], type: DataType.float64);

      check(op.rowCount).equals(2);
      check(op.colCount).equals(3);
      check(op.type).equals(DataType.float64);

      final x = Vector<double>.fromList([1.0, 0.0, 2.0]);
      // A * x = [1*1 + 2*0 + 3*2, 4*1 + 5*0 + 6*2] = [7, 16]
      final y = op.apply(x);
      check(y.toList()).deepEquals([7.0, 16.0]);

      final yt = Vector<double>.fromList([2.0, 1.0]);
      // A^T * yt = [1*2 + 4*1, 2*2 + 5*1, 3*2 + 6*1] = [6, 9, 12]
      final xt = op.applyTranspose(yt);
      check(xt.toList()).deepEquals([6.0, 9.0, 12.0]);
    });

    test('applyConjugateTranspose on complex LinearOperator', () {
      final LinearOperator<Complex> op = Matrix<Complex>.fromRows([
        [const Complex(1.0, 1.0), const Complex(2.0, -1.0)],
        [const Complex(3.0, 0.0), const Complex(0.0, 4.0)],
      ], type: DataType.complex);

      final v = Vector<Complex>.fromList([
        const Complex(1.0, 2.0),
        const Complex(2.0, -1.0),
      ], type: DataType.complex);

      final res = op.applyConjugateTranspose(v);
      check(res.length).equals(2);
      // Row 0 of A^H: [1 - i, 3] . [1 + 2i, 2 - i] = (1-i)(1+2i) + 3(2-i)
      // (1 - i)(1 + 2i) = 1 + 2i - i + 2 = 3 + i
      // 3(2 - i) = 6 - 3i
      // Total: 9 - 2i
      check(res[0].a).isCloseTo(9.0, 1e-10);
      check(res[0].b).isCloseTo(-2.0, 1e-10);
    });

    test('matmul composition and dimension validation', () {
      final m1 = Matrix<int>.fromRows([
        [1, 2],
        [3, 4],
      ]);
      final op2 = CooMatrix<int>.fromDense(m1);
      final composed = m1.matmul(op2);
      check((composed as Matrix<int>).toNestedList() as List).deepEquals([
        [7, 10],
        [15, 22],
      ]);

      final badDim = Matrix<int>.filled(3, 2, 1);
      check(() => m1.matmul(badDim)).throws<ArgumentError>();
    });
  });
}
