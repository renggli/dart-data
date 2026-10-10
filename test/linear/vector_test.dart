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
}
