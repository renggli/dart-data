import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/linear.dart';
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
      check(v.norm2()).equals(5.0);
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

    test('dimension mismatch error handling', () {
      final a = Float64Vector.filled(3, 1.0);
      final b = Float64Vector.filled(4, 2.0);

      check(() => a + b).throws<ArgumentError>();
      check(() => a - b).throws<ArgumentError>();
      check(() => a * b).throws<ArgumentError>();
      check(() => a / b).throws<ArgumentError>();
      check(() => a.dot(b)).throws<ArgumentError>();
    });
  });
}
