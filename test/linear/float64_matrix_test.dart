import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/acceleration.dart';
import 'package:data/linear.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('Float64Matrix', () {
    test('filled constructor', () {
      final m = Float64Matrix.filled(2, 3, 1.5);
      check(m.rowCount).equals(2);
      check(m.colCount).equals(3);
      check(m.asTypedList).isA<Float64List>();
      check(m.asTypedList).deepEquals([1.5, 1.5, 1.5, 1.5, 1.5, 1.5]);
      check(m.get(1, 2)).equals(1.5);
    });

    test('generate constructor', () {
      final m = Float64Matrix.generate(2, 2, (r, c) => (r * 2 + c).toDouble());
      check(m.asTypedList).deepEquals([0.0, 1.0, 2.0, 3.0]);
      check(m.get(1, 0)).equals(2.0);
    });

    test('fromRows and fromColumns', () {
      final m1 = Float64Matrix.fromRows([
        [1.0, 2.0],
        [3.0, 4.0],
      ]);
      check(m1.get(0, 1)).equals(2.0);
      check(m1.get(1, 0)).equals(3.0);

      final m2 = Float64Matrix.fromColumns([
        [1.0, 3.0],
        [2.0, 4.0],
      ]);
      check(m2.get(0, 1)).equals(2.0);
      check(m2.get(1, 0)).equals(3.0);
    });

    test('fromList, identity, and diagonal constructors', () {
      final m = Float64Matrix.fromList(2, 3, [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]);
      check(m.rowCount).equals(2);
      check(m.colCount).equals(3);
      check(m.get(0, 2)).equals(3.0);

      final id = Float64Matrix.identity(3);
      check(id.get(0, 0)).equals(1.0);
      check(id.get(1, 1)).equals(1.0);
      check(id.get(0, 1)).equals(0.0);

      final diag = Float64Matrix.diagonal(Float64Vector.fromList([5.0, 10.0]));
      check(diag.get(0, 0)).equals(5.0);
      check(diag.get(1, 1)).equals(10.0);
      check(diag.get(0, 1)).equals(0.0);
    });

    test('element access and mutation', () {
      final m = Float64Matrix.filled(2, 2, 0.0);
      m.set(0, 1, 4.5);
      m[(1, 0)] = 8.5;
      check(m.get(0, 1)).equals(4.5);
      check(m[0][1]).equals(4.5);
      check(m.get(1, 0)).equals(8.5);
      check(m[1][0]).equals(8.5);
      m[0][0] = 1.5;
      check(m[0][0]).equals(1.5);
      check(m.asTypedList).deepEquals([1.5, 4.5, 8.5, 0.0]);
    });

    test('row, col, diagonal slices, and transposition', () {
      final m = Float64Matrix.fromList(2, 3, [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]);

      final r0 = m.row(0);
      check(r0.toList()).deepEquals([1.0, 2.0, 3.0]);

      final c1 = m.col(1);
      check(c1.toList()).deepEquals([2.0, 5.0]);

      final sq = Float64Matrix.fromList(2, 2, [1.0, 2.0, 3.0, 4.0]);
      final d = sq.diagonal();
      check(d.toList()).deepEquals([1.0, 4.0]);

      final t = m.transposed;
      check(t.rowCount).equals(3);
      check(t.colCount).equals(2);
      check(t.get(0, 1)).equals(4.0);
      check(t.get(2, 0)).equals(3.0);
    });

    test('matrix multiplication (BLAS dgemm)', () {
      final a = Float64Matrix.fromList(2, 3, [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]);
      final b = Float64Matrix.fromList(3, 2, [7.0, 8.0, 9.0, 1.0, 2.0, 3.0]);

      // [1*7+2*9+3*2, 1*8+2*1+3*3] = [7+18+6, 8+2+9] = [31, 19]
      // [4*7+5*9+6*2, 4*8+5*1+6*3] = [28+45+12, 32+5+18] = [85, 55]
      final c = a * b;
      check(c.rowCount).equals(2);
      check(c.colCount).equals(2);
      check(c.asTypedList).deepEquals([31.0, 19.0, 85.0, 55.0]);
    });

    test('matrix-vector multiplication (BLAS dgemv)', () {
      final a = Float64Matrix.fromList(2, 3, [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]);
      final x = Float64Vector.fromList([2.0, 3.0, 4.0]);

      // [1*2+2*3+3*4, 4*2+5*3+6*4] = [2+6+12, 8+15+24] = [20, 47]
      final y = a.apply(x);
      check(y.length).equals(2);
      check(y.asTypedList).deepEquals([20.0, 47.0]);
    });

    test('inlined arithmetic operators', () {
      final a = Float64Matrix.fromList(2, 2, [1.0, 2.0, 3.0, 4.0]);
      final b = Float64Matrix.fromList(2, 2, [10.0, 20.0, 30.0, 40.0]);

      final sum = a + b;
      check(sum.asTypedList).deepEquals([11.0, 22.0, 33.0, 44.0]);

      final diff = b - a;
      check(diff.asTypedList).deepEquals([9.0, 18.0, 27.0, 36.0]);

      final neg = -a;
      check(neg.asTypedList).deepEquals([-1.0, -2.0, -3.0, -4.0]);

      final scaled = a.scale(2.0);
      check(scaled.asTypedList).deepEquals([2.0, 4.0, 6.0, 8.0]);
    });

    test('pure Dart fallback execution mode', () {
      final prev = AccelerationManager.mode;
      try {
        AccelerationManager.mode = AccelerationMode.dart;
        final a = Float64Matrix.fromList(2, 2, [1.0, 2.0, 3.0, 4.0]);
        final b = Float64Matrix.fromList(2, 2, [10.0, 20.0, 30.0, 40.0]);
        final x = Float64Vector.fromList([2.0, 3.0]);

        check((a * b).asTypedList).deepEquals([70.0, 100.0, 150.0, 220.0]);
        check(a.apply(x).asTypedList).deepEquals([8.0, 18.0]);
        check((a + b).asTypedList).deepEquals([11.0, 22.0, 33.0, 44.0]);
        check((b - a).asTypedList).deepEquals([9.0, 18.0, 27.0, 36.0]);
        check((-a).asTypedList).deepEquals([-1.0, -2.0, -3.0, -4.0]);
        check(a.scale(2.0).asTypedList).deepEquals([2.0, 4.0, 6.0, 8.0]);
      } finally {
        AccelerationManager.mode = prev;
      }
    });

    test('dimension mismatch error handling', () {
      final a = Float64Matrix.filled(2, 3, 1.0);
      final b = Float64Matrix.filled(2, 2, 1.0);
      final x = Float64Vector.filled(2, 1.0);

      check(() => a + b).throws<ArgumentError>();
      check(() => a - b).throws<ArgumentError>();
      check(() => a * b).throws<ArgumentError>();
      check(() => a.apply(x)).throws<ArgumentError>();
    });

    test('operations with generic Matrix<double> and non-contiguous views', () {
      final a = Float64Matrix.fromList(2, 2, [1.0, 2.0, 3.0, 4.0]);
      final genericMat = Matrix<double>.generate(
        2,
        2,
        (r, c) => (r * 2 + c + 1) * 10.0,
      );

      final sum = a + genericMat;
      check(sum.asTypedList).deepEquals([11.0, 22.0, 33.0, 44.0]);

      final diff = a - genericMat;
      check(diff.asTypedList).deepEquals([-9.0, -18.0, -27.0, -36.0]);

      final prod = a * genericMat;
      check(prod.asTypedList).deepEquals([70.0, 100.0, 150.0, 220.0]);

      final full = Float64Matrix.fromList(3, 3, [
        0.0,
        0.0,
        0.0,
        0.0,
        10.0,
        20.0,
        0.0,
        30.0,
        40.0,
      ]);
      final offsetMat = full.subMatrix(rowStart: 1, colStart: 1);
      final sumOffset = a + offsetMat;
      check(sumOffset.asTypedList).deepEquals([11.0, 22.0, 33.0, 44.0]);
      final diffOffset = a - offsetMat;
      check(diffOffset.asTypedList).deepEquals([-9.0, -18.0, -27.0, -36.0]);
    });

    test('subMatrix and row/col out-of-bounds indexing throws RangeError', () {
      final full = Float64Matrix.fromList(3, 3, [
        1.0,
        2.0,
        3.0,
        4.0,
        5.0,
        6.0,
        7.0,
        8.0,
        9.0,
      ]);
      final sub = full.subMatrix(
        rowStart: 0,
        rowEnd: 2,
        colStart: 0,
        colEnd: 2,
      );
      check(sub.rowCount).equals(2);
      check(sub.colCount).equals(2);
      check(sub.get(0, 0)).equals(1.0);
      check(sub.get(1, 1)).equals(5.0);

      // Checked access
      check(() => sub.get(2, 0)).throws<RangeError>();
      check(() => sub.get(0, 2)).throws<RangeError>();
      check(() => sub.get(-1, 0)).throws<RangeError>();
      check(() => sub.get(0, -1)).throws<RangeError>();

      check(() => sub.set(2, 0, 99.0)).throws<RangeError>();
      check(() => sub.set(0, 2, 99.0)).throws<RangeError>();
      check(() => sub.set(-1, 0, 99.0)).throws<RangeError>();
      check(() => sub.set(0, -1, 99.0)).throws<RangeError>();

      // operator [] row and col
      check(() => sub[2]).throws<RangeError>();
      check(() => sub[-1]).throws<RangeError>();
      check(() => sub[0][2]).throws<RangeError>();
      check(() => sub[0][-1]).throws<RangeError>();
      check(() => sub[0][2] = 99.0).throws<RangeError>();

      check(() => sub.row(2)).throws<RangeError>();
      check(() => sub.row(-1)).throws<RangeError>();
      check(() => sub.col(2)).throws<RangeError>();
      check(() => sub.col(-1)).throws<RangeError>();

      // getUnchecked and setUnchecked bypass bounds checks
      check(sub.getUnchecked(0, 2)).equals(3.0);
      sub.setUnchecked(0, 2, 33.0);
      check(full.get(0, 2)).equals(33.0);
      full.set(0, 2, 3.0);
    });

    test(
      'constructor rejects non-Float64List backing and fromDoubleMatrix copies',
      () {
        final f32Mat = Matrix<double>.filled(2, 2, 1.0, type: DataType.float32);
        check(() => Float64Matrix(f32Mat)).throws<ArgumentError>();

        final copied = Float64Matrix.fromDoubleMatrix(f32Mat);
        check(copied.rowCount).equals(2);
        check(copied.colCount).equals(2);
        check(copied.asTypedList).isA<Float64List>();
        check(copied.asTypedList).deepEquals([1.0, 1.0, 1.0, 1.0]);
        copied.set(0, 0, 42.0);
        check(copied.get(0, 0)).equals(42.0);
        check(f32Mat.get(0, 0)).equals(1.0);
      },
    );
  });
}
