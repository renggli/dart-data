import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('Vector element access', () {
    test('operator [], operator []=, getUnchecked, setUnchecked', () {
      final vector = Vector<double>.fromList([
        10.0,
        20.0,
        30.0,
        40.0,
      ], type: DataType.float64);

      check(vector.length).equals(4);
      for (var i = 0; i < vector.length; i++) {
        check(vector[i]).equals((i + 1) * 10.0);
        check(vector.getUnchecked(i)).equals((i + 1) * 10.0);
      }

      vector[1] = 99.0;
      check(vector[1]).equals(99.0);
      check(vector.getUnchecked(1)).equals(99.0);

      vector.setUnchecked(2, 77.0);
      check(vector[2]).equals(77.0);
      check(vector.getUnchecked(2)).equals(77.0);
    });

    test('bounds validation throws RangeError', () {
      final vector = Vector<int>.fromList([1, 2, 3], type: DataType.int32);

      check(() => vector[-1]).throws<RangeError>();
      check(() => vector[3]).throws<RangeError>();
      check(() => vector[100]).throws<RangeError>();

      check(() => vector[-1] = 0).throws<RangeError>();
      check(() => vector[3] = 0).throws<RangeError>();
      check(() => vector[100] = 0).throws<RangeError>();
    });

    test('subVector indexing and updates', () {
      final vector = Vector<int>.fromList([
        0,
        10,
        20,
        30,
        40,
      ], type: DataType.int32);
      final sub = vector.subVector(1, 4);

      check(sub.length).equals(3);
      check(sub[0]).equals(10);
      check(sub.getUnchecked(0)).equals(10);
      check(sub[1]).equals(20);
      check(sub.getUnchecked(1)).equals(20);
      check(sub[2]).equals(30);
      check(sub.getUnchecked(2)).equals(30);

      check(() => sub[-1]).throws<RangeError>();
      check(() => sub[3]).throws<RangeError>();

      sub[0] = 999;
      check(vector[1]).equals(999);
      check(sub.getUnchecked(0)).equals(999);
    });

    test('0-sized vectors and bounds checking', () {
      final v0 = Vector<double>.filled(0, 0.0);
      check(v0.length).equals(0);
      check(() => v0[0]).throws<RangeError>();
      check(() => v0[-1]).throws<RangeError>();
      check(() => v0.setUnchecked(0, 1.0)).throws<RangeError>();

      final vGen0 = Vector<int>.generate(0, (i) => i);
      check(vGen0.length).equals(0);
      check(() => vGen0[0]).throws<RangeError>();
    });

    test('Vector.generate direct buffer initialization', () {
      final v = Vector<int>.generate(5, (i) => i * 3);
      check(v.length).equals(5);
      for (var i = 0; i < 5; i++) {
        check(v[i]).equals(i * 3);
        check(v.getUnchecked(i)).equals(i * 3);
      }
    });
  });

  group('Vector cumsum and cumprod', () {
    test('cumsum with integer vectors', () {
      final v = Vector<int>.fromList([1, 2, 3, 4, 5], type: DataType.int32);
      final cs = v.cumsum();

      check(cs.length).equals(5);
      check(cs.toList()).deepEquals([1, 3, 6, 10, 15]);
      // Verify original vector is unchanged
      check(v.toList()).deepEquals([1, 2, 3, 4, 5]);
    });

    test('cumsum with float vectors', () {
      final v = Vector<double>.fromList([
        0.5,
        1.5,
        2.0,
      ], type: DataType.float64);
      final cs = v.cumsum();

      check(cs.length).equals(3);
      check(cs[0]).isCloseTo(0.5, 1e-10);
      check(cs[1]).isCloseTo(2.0, 1e-10);
      check(cs[2]).isCloseTo(4.0, 1e-10);
    });

    test('cumsum in-place when target is this', () {
      final v = Vector<int>.fromList([2, 4, 6, 8], type: DataType.int32);
      final ret = v.cumsum(target: v);

      check(identical(ret, v)).isTrue();
      check(v.toList()).deepEquals([2, 6, 12, 20]);
    });

    test('cumsum with explicit target vector', () {
      final v = Vector<int>.fromList([10, 20, 30], type: DataType.int32);
      final target = Vector<int>.filled(3, 0, type: DataType.int32);
      final ret = v.cumsum(target: target);

      check(identical(ret, target)).isTrue();
      check(target.toList()).deepEquals([10, 30, 60]);
      check(v.toList()).deepEquals([10, 20, 30]);
    });

    test('cumsum with overlapping subVector target alias', () {
      final v = Vector<int>.fromList([1, 2, 3, 4, 5], type: DataType.int32);
      final src = v.subVector(0, 3); // [1, 2, 3]
      final dst = v.subVector(1, 4); // target range [2, 3, 4]
      src.cumsum(target: dst);

      check(dst.toList()).deepEquals([1, 3, 6]);
      check(v.toList()).deepEquals([1, 1, 3, 6, 5]);
    });

    test('cumsum on non-contiguous strided vector', () {
      final v = Vector<int>.fromList([
        10,
        20,
        30,
        40,
        50,
      ], type: DataType.int32);
      final sub = v.subVector(1, 4); // [20, 30, 40]
      final cs = sub.cumsum();

      check(cs.toList()).deepEquals([20, 50, 90]);
    });

    test('cumsum on empty vector', () {
      final v = Vector<int>.filled(0, 0, type: DataType.int32);
      final cs = v.cumsum();

      check(cs.length).equals(0);
    });

    test('cumsum throws on mismatched target length', () {
      final v = Vector<int>.fromList([1, 2, 3], type: DataType.int32);
      final badTarget = Vector<int>.filled(2, 0, type: DataType.int32);

      check(() => v.cumsum(target: badTarget)).throws<ArgumentError>();
    });

    test('cumprod with integer vectors', () {
      final v = Vector<int>.fromList([1, 2, 3, 4], type: DataType.int32);
      final cp = v.cumprod();

      check(cp.length).equals(4);
      check(cp.toList()).deepEquals([1, 2, 6, 24]);
      check(v.toList()).deepEquals([1, 2, 3, 4]);
    });

    test('cumprod with zeroes and negative values', () {
      final v = Vector<int>.fromList([2, -3, 0, 5], type: DataType.int32);
      final cp = v.cumprod();

      check(cp.toList()).deepEquals([2, -6, 0, 0]);
    });

    test('cumprod with float vectors', () {
      final v = Vector<double>.fromList([
        2.0,
        0.5,
        4.0,
      ], type: DataType.float64);
      final cp = v.cumprod();

      check(cp.length).equals(3);
      check(cp[0]).isCloseTo(2.0, 1e-10);
      check(cp[1]).isCloseTo(1.0, 1e-10);
      check(cp[2]).isCloseTo(4.0, 1e-10);
    });

    test('cumprod in-place when target is this', () {
      final v = Vector<int>.fromList([3, 2, 4], type: DataType.int32);
      final ret = v.cumprod(target: v);

      check(identical(ret, v)).isTrue();
      check(v.toList()).deepEquals([3, 6, 24]);
    });

    test('cumprod with explicit target vector', () {
      final v = Vector<int>.fromList([2, 3, 4], type: DataType.int32);
      final target = Vector<int>.filled(3, 0, type: DataType.int32);
      final ret = v.cumprod(target: target);

      check(identical(ret, target)).isTrue();
      check(target.toList()).deepEquals([2, 6, 24]);
      check(v.toList()).deepEquals([2, 3, 4]);
    });

    test('cumprod with overlapping subVector target alias', () {
      final v = Vector<int>.fromList([2, 3, 4, 5, 6], type: DataType.int32);
      final src = v.subVector(0, 3); // [2, 3, 4]
      final dst = v.subVector(1, 4); // target range [3, 4, 5]
      src.cumprod(target: dst);

      check(dst.toList()).deepEquals([2, 6, 24]);
      check(v.toList()).deepEquals([2, 2, 6, 24, 6]);
    });

    test('cumprod on non-contiguous strided vector', () {
      final v = Vector<int>.fromList([1, 2, 3, 4, 5], type: DataType.int32);
      final sub = v.subVector(1, 4); // [2, 3, 4]
      final cp = sub.cumprod();

      check(cp.toList()).deepEquals([2, 6, 24]);
    });

    test('cumprod on empty vector', () {
      final v = Vector<int>.filled(0, 0, type: DataType.int32);
      final cp = v.cumprod();

      check(cp.length).equals(0);
    });

    test('cumprod throws on mismatched target length', () {
      final v = Vector<int>.fromList([1, 2, 3], type: DataType.int32);
      final badTarget = Vector<int>.filled(4, 0, type: DataType.int32);

      check(() => v.cumprod(target: badTarget)).throws<ArgumentError>();
    });
  });

  group('Vector operations and arithmetic', () {
    test('creation and element access', () {
      final vector = Vector<double>.fromList([1.0, 2.0, 3.0]);
      check(vector.length).equals(3);
      check(vector[0]).equals(1.0);
      check(vector[2]).equals(3.0);
      vector[1] = 5.0;
      check(vector[1]).equals(5.0);
      check(vector.toList()).deepEquals([1.0, 5.0, 3.0]);
    });

    test('arithmetic operations', () {
      final a = Vector<double>.fromList([1.0, 2.0, 3.0]);
      final b = Vector<double>.fromList([4.0, 5.0, 6.0]);

      check((a + b).toList()).deepEquals([5.0, 7.0, 9.0]);
      check((b - a).toList()).deepEquals([3.0, 3.0, 3.0]);
      check((a * b).toList()).deepEquals([4.0, 10.0, 18.0]);
      check((b / a).toList()).deepEquals([4.0, 2.5, 2.0]);
      check((-a).toList()).deepEquals([-1.0, -2.0, -3.0]);
      check(a.scale(2.0).toList()).deepEquals([2.0, 4.0, 6.0]);
    });

    test('dot product and outer product', () {
      final a = Vector<double>.fromList([1.0, 2.0, 3.0]);
      final b = Vector<double>.fromList([4.0, 5.0, 6.0]);
      check(a.dot(b)).equals(32.0);

      final outer = a.outer(b);
      check(outer.rowCount).equals(3);
      check(outer.colCount).equals(3);
      check(outer.get(0, 0)).equals(4.0);
      check(outer.get(0, 1)).equals(5.0);
      check(outer.get(1, 0)).equals(8.0);
      check(outer.get(2, 2)).equals(18.0);
    });

    test('norm and normalized', () {
      final vector = Vector<double>.fromList([3.0, 4.0]);
      check(vector.norm(2)).equals(5.0);
      check(vector.norm(1)).equals(7.0);
      check(vector.norm(double.infinity)).equals(4.0);

      final normalized = vector.normalized();
      check(normalized[0]).isCloseTo(0.6, 1e-10);
      check(normalized[1]).isCloseTo(0.8, 1e-10);
      check(normalized.norm(2)).isCloseTo(1.0, 1e-10);
    });

    test('matrix conversion and subVector', () {
      final vector = Vector<double>.fromList([1.0, 2.0, 3.0, 4.0]);
      final colMat = vector.toMatrix(asColumn: true);
      check(colMat.rowCount).equals(4);
      check(colMat.colCount).equals(1);
      check(colMat.get(2, 0)).equals(3.0);

      final sub = vector.subVector(1, 3);
      check(sub.length).equals(2);
      check(sub.toList()).deepEquals([2.0, 3.0]);
    });

    test('Vector comprehensive constructors, operations, and errors', () {
      final filledVec = Vector<double>.filled(3, 7.0);
      check(filledVec.toList()).deepEquals([7.0, 7.0, 7.0]);

      final genVec = Vector<int>.generate(4, (i) => i * 3);
      check(genVec.toList()).deepEquals([0, 3, 6, 9]);

      final nativeVec = Vector<double>.filled(3, 0.0);
      check(nativeVec.length).equals(3);

      final fromIter = Vector<int>.fromIterable([10, 20, 30]);
      check(fromIter.toList()).deepEquals([10, 20, 30]);

      final copyVec = fromIter.copy();
      check(copyVec.toList()).deepEquals(fromIter.toList());
      check(copyVec.sum).equals(60);
      check(copyVec.toString()).equals('Vector([10, 20, 30])');

      check(fromIter.subVector(1).toList()).deepEquals([20, 30]);

      final vector = Vector<double>.fromList([1.0, 2.0, 2.0]);
      check(vector.norm(3)).isCloseTo(2.57128159, 1e-5);

      final intNormVec = Vector<int>.fromList([3, 4]);
      check(intNormVec.norm(2)).equals(5.0);

      final zeroVec = Vector<double>.fromList([0.0, 0.0]);
      check(zeroVec.normalized).throws<StateError>();

      final v3 = Vector<double>.fromList([1.0, 2.0, 3.0]);
      final v2 = Vector<double>.fromList([1.0, 2.0]);
      check(() => v3.dot(v2)).throws<ArgumentError>();
      check(() => v3.addScaled(v2, 2.0)).throws<ArgumentError>();

      final vInt1 = Vector<int>.fromList([1, 2, 3]);
      final vInt2 = Vector<int>.fromList([10, 20, 30]);
      vInt1.addScaled(vInt2, 2);
      check(vInt1.toList()).deepEquals([21, 42, 63]);

      vInt1.scaleInPlace(2);
      check(vInt1.toList()).deepEquals([42, 84, 126]);

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
      check(f32_1.dot(f32_2)).equals(32.0);
      check(f32_1.norm(2)).isCloseTo(3.741657, 1e-4);

      f32_1.addScaled(f32_2, 2.0);
      check(f32_1.toList()[0]).isCloseTo(9.0, 1e-4);

      f32_1.scaleInPlace(0.5);
      check(f32_1.toList()[0]).isCloseTo(4.5, 1e-4);

      // Non-contiguous dot and non-contiguous cumsum/cumprod target
      final mat = Matrix<int>.fromRows([
        [1, 2],
        [3, 4],
        [5, 6],
      ]);
      final col0 = mat.col(0);
      final col1 = mat.col(1);
      check(col0.dot(col1)).equals(1 * 2 + 3 * 4 + 5 * 6);
      final targetCol = Matrix<int>.filled(3, 2, 0).col(0);
      col0.cumsum(target: targetCol);
      check(targetCol.toList()).deepEquals([1, 4, 9]);
    });
  });
}
