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
}
