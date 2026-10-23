import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/acceleration.dart';
import 'package:data/linear.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('Float64Vector', () {
    test('filled constructor', () {
      final v = Float64Vector.filled(4, 2.5);
      check(v.length).equals(4);
      check(v.asTypedList).isA<Float64List>();
      check(v.asTypedList).deepEquals([2.5, 2.5, 2.5, 2.5]);
      check(v[0]).equals(2.5);
      check(v[3]).equals(2.5);
    });

    test('generate constructor', () {
      final v = Float64Vector.generate(4, (i) => i * 1.5);
      check(v.asTypedList).deepEquals([0.0, 1.5, 3.0, 4.5]);
      check(v[2]).equals(3.0);
    });

    test('fromList and fromIterable', () {
      final v1 = Float64Vector.fromList([1.0, 2.0, 3.0]);
      check(v1.length).equals(3);
      check(v1[1]).equals(2.0);

      final v2 = Float64Vector.fromIterable([4.0, 5.0, 6.0]);
      check(v2.length).equals(3);
      check(v2[0]).equals(4.0);
    });

    test('indexing and mutation', () {
      final v = Float64Vector.filled(3, 0.0);
      v[0] = 10.0;
      v[1] = 20.0;
      v[2] = 30.0;
      check(v[0]).equals(10.0);
      check(v[1]).equals(20.0);
      check(v[2]).equals(30.0);
      check(v.asTypedList).deepEquals([10.0, 20.0, 30.0]);
    });

    test('algebraic inner product (dot) and norm2', () {
      final a = Float64Vector.fromList([1.0, 2.0, 3.0]);
      final b = Float64Vector.fromList([4.0, -5.0, 6.0]);
      // 1*4 + 2*(-5) + 3*6 = 4 - 10 + 18 = 12
      check(a.dot(b)).equals(12.0);

      final v = Float64Vector.fromList([3.0, 4.0]);
      check(v.norm()).equals(5.0);
    });

    test('inlined arithmetic operations', () {
      final a = Float64Vector.fromList([1.0, 2.0, 3.0]);
      final b = Float64Vector.fromList([10.0, 20.0, 30.0]);

      final sum = a + b;
      check(sum.asTypedList).deepEquals([11.0, 22.0, 33.0]);

      final diff = b - a;
      check(diff.asTypedList).deepEquals([9.0, 18.0, 27.0]);

      final prod = a * b;
      check(prod.asTypedList).deepEquals([10.0, 40.0, 90.0]);

      final div = b / a;
      check(div.asTypedList).deepEquals([10.0, 10.0, 10.0]);

      final neg = -a;
      check(neg.asTypedList).deepEquals([-1.0, -2.0, -3.0]);

      final scaled = a.scale(3.0);
      check(scaled.asTypedList).deepEquals([3.0, 6.0, 9.0]);
    });

    test('pure Dart fallback execution mode', () {
      final prev = AccelerationManager.mode;
      try {
        AccelerationManager.mode = AccelerationMode.dart;
        final a = Float64Vector.fromList([1.0, 2.0, 3.0]);
        final b = Float64Vector.fromList([4.0, 5.0, 6.0]);

        check(a.dot(b)).equals(32.0);
        check(Float64Vector.fromList([3.0, 4.0]).norm()).equals(5.0);
        check((a + b).asTypedList).deepEquals([5.0, 7.0, 9.0]);
        check((b - a).asTypedList).deepEquals([3.0, 3.0, 3.0]);
        check((a * b).asTypedList).deepEquals([4.0, 10.0, 18.0]);
        check((b / a).asTypedList).deepEquals([4.0, 2.5, 2.0]);
        check((-a).asTypedList).deepEquals([-1.0, -2.0, -3.0]);
        check(a.scale(2.0).asTypedList).deepEquals([2.0, 4.0, 6.0]);
      } finally {
        AccelerationManager.mode = prev;
      }
    });

    test('non-contiguous strided dot product', () {
      final m1 = Matrix<double>.fromRows([
        [1.0, 2.0],
        [3.0, 4.0],
      ]);
      final m2 = Matrix<double>.fromRows([
        [5.0, 6.0],
        [7.0, 8.0],
      ]);
      // Column vectors have stride > 1
      final c1 = Float64Vector(m1.col(0));
      final c2 = Float64Vector(m2.col(0));
      // 1*5 + 3*7 = 5 + 21 = 26
      check(c1.dot(c2)).equals(26.0);
    });

    test('dimension mismatch error handling', () {
      final a = Float64Vector.filled(3, 1.0);
      final b = Float64Vector.filled(4, 2.0);

      check(() => a + b).throws<ArgumentError>();
      check(() => a - b).throws<ArgumentError>();
      check(() => a * b).throws<ArgumentError>();
      check(() => a / b).throws<ArgumentError>();
      check(() => a.dot(b)).throws<ArgumentError>();
    });

    test('operations with generic Vector<double> and non-contiguous views', () {
      final a = Float64Vector.fromList([1.0, 2.0, 3.0]);
      // Generic Vector backed by List<double> (not Float64Vector)
      final genericVec = Vector<double>.generate(3, (i) => (i + 1) * 10.0);

      // dot
      check(a.dot(genericVec)).equals(140.0);

      // +
      final sum = a + genericVec;
      check(sum.asTypedList).deepEquals([11.0, 22.0, 33.0]);

      // -
      final diff = a - genericVec;
      check(diff.asTypedList).deepEquals([-9.0, -18.0, -27.0]);

      // *
      final prod = a * genericVec;
      check(prod.asTypedList).deepEquals([10.0, 40.0, 90.0]);

      // /
      final div = a / genericVec;
      check(div[0]).isCloseTo(0.1, 1e-9);

      // Vector with non-zero offset
      final full = Float64Vector.fromList([0.0, 10.0, 20.0, 30.0, 0.0]);
      final offsetVec = full.subVector(1, 4);
      final sumOffset = a + offsetVec;
      check(sumOffset.asTypedList).deepEquals([11.0, 22.0, 33.0]);
      final diffOffset = a - offsetVec;
      check(diffOffset.asTypedList).deepEquals([-9.0, -18.0, -27.0]);
      final prodOffset = a * offsetVec;
      check(prodOffset.asTypedList).deepEquals([10.0, 40.0, 90.0]);
      final divOffset = a / offsetVec;
      check(divOffset[0]).isCloseTo(0.1, 1e-9);
    });

    test('subVector out-of-bounds indexing throws RangeError', () {
      final v = Float64Vector.fromList([10.0, 20.0, 30.0, 40.0]);
      final sub = v.subVector(0, 2);
      check(sub.length).equals(2);
      check(sub[0]).equals(10.0);
      check(sub[1]).equals(20.0);

      check(() => sub[2]).throws<RangeError>();
      check(() => sub[3]).throws<RangeError>();
      check(() => sub[-1]).throws<RangeError>();
      check(() => sub[2] = 99.0).throws<RangeError>();
      check(() => sub[-1] = 99.0).throws<RangeError>();

      // getUnchecked and setUnchecked bypass bounds checks
      check(sub.getUnchecked(2)).equals(30.0);
      sub.setUnchecked(2, 35.0);
      check(v[2]).equals(35.0);
      v[2] = 30.0;
    });

    test(
      'constructor rejects non-Float64List backing and fromDoubleVector copies',
      () {
        final f32Vec = Vector<double>.filled(3, 1.0, type: DataType.float32);
        check(() => Float64Vector(f32Vec)).throws<ArgumentError>();

        final copied = Float64Vector.fromDoubleVector(f32Vec);
        check(copied.length).equals(3);
        check(copied.asTypedList).isA<Float64List>();
        check(copied.asTypedList).deepEquals([1.0, 1.0, 1.0]);
        copied[0] = 42.0;
        check(copied[0]).equals(42.0);
        check(f32Vec[0]).equals(1.0);
      },
    );
  });
}
