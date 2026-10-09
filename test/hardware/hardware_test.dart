import 'dart:typed_data';

import 'package:data/hardware.dart';
import 'package:data/tensor.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('HardwareManager status & fallback toggle', () {
    test('hardware availability probe', () {
      expect(HardwareManager.isEnabled, isTrue);
      // On macOS, Accelerate framework should be found and loaded
      // On CI or non-native platforms, it may be false
      final nativeAvail = HardwareManager.isNativeAvailable;
      expect(HardwareManager.isAccelerated, nativeAvail);
    });

    test('fallback toggle disables acceleration cleanly', () {
      HardwareManager.isEnabled = false;
      expect(HardwareManager.isAccelerated, isFalse);
      HardwareManager.isEnabled = true;
    });
  });

  group('Native BLAS operations', () {
    test('dgemm and sgemm if native available', () {
      if (!HardwareManager.isNativeAvailable) return;

      // 2x2 double matrix multiply
      final a = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final b = Float64List.fromList([5.0, 6.0, 7.0, 8.0]);
      final c = Float64List(4);

      final successD = HardwareManager.dgemm(
        m: 2,
        n: 2,
        k: 2,
        alpha: 1.0,
        a: a,
        lda: 2,
        b: b,
        ldb: 2,
        beta: 0.0,
        c: c,
        ldc: 2,
      );
      expect(successD, isTrue);
      expect(c[0], 19.0);
      expect(c[1], 22.0);
      expect(c[2], 43.0);
      expect(c[3], 50.0);

      // 2x2 float matrix multiply
      final a32 = Float32List.fromList([1.0, 2.0, 3.0, 4.0]);
      final b32 = Float32List.fromList([5.0, 6.0, 7.0, 8.0]);
      final c32 = Float32List(4);

      final successS = HardwareManager.sgemm(
        m: 2,
        n: 2,
        k: 2,
        alpha: 1.0,
        a: a32,
        lda: 2,
        b: b32,
        ldb: 2,
        beta: 0.0,
        c: c32,
        ldc: 2,
      );
      expect(successS, isTrue);
      expect(c32[0], 19.0);
      expect(c32[1], 22.0);
      expect(c32[2], 43.0);
      expect(c32[3], 50.0);
    });

    test('ddot and dnrm2 if native available', () {
      if (!HardwareManager.isNativeAvailable) return;

      final x = Float64List.fromList([1.0, 2.0, 3.0]);
      final y = Float64List.fromList([4.0, 5.0, 6.0]);

      final dotVal = HardwareManager.ddot(n: 3, x: x, y: y);
      expect(dotVal, isNotNull);
      expect(dotVal, 32.0);

      final normVal = HardwareManager.dnrm2(n: 3, x: x);
      expect(normVal, isNotNull);
      // sqrt(1 + 4 + 9) = sqrt(14) ~ 3.741657
      expect(normVal, closeTo(3.741657, 1e-5));
    });
  });

  group('SimdEngine (Float32x4)', () {
    test('SIMD add, sub, mul, dot', () {
      final a = Float32List.fromList([1.0, 2.0, 3.0, 4.0, 5.0]);
      final b = Float32List.fromList([10.0, 20.0, 30.0, 40.0, 50.0]);
      final out = Float32List(5);

      SimdEngine.addFloat32(a, b, out);
      expect(out, [11.0, 22.0, 33.0, 44.0, 55.0]);

      SimdEngine.subFloat32(b, a, out);
      expect(out, [9.0, 18.0, 27.0, 36.0, 45.0]);

      SimdEngine.mulFloat32(a, b, out);
      expect(out, [10.0, 40.0, 90.0, 160.0, 250.0]);

      final dot = SimdEngine.dotFloat32(a, b);
      expect(dot, 10.0 + 40.0 + 90.0 + 160.0 + 250.0);
    });
  });

  group('Tensor.matmul hardware vs fallback parity', () {
    test('produces identical results with hardware enabled and disabled', () {
      final t1 = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0, 4.0],
        shape: [2, 2],
        type: DataType.float64,
      );
      final t2 = Tensor<double>.fromIterable(
        [5.0, 6.0, 7.0, 8.0],
        shape: [2, 2],
        type: DataType.float64,
      );

      HardwareManager.isEnabled = true;
      final resHardware = t1.matmul(t2);

      HardwareManager.isEnabled = false;
      final resFallback = t1.matmul(t2);
      HardwareManager.isEnabled = true;

      expect(resHardware.toFlatList(), resFallback.toFlatList());
      expect(resHardware.toFlatList(), [19.0, 22.0, 43.0, 50.0]);
    });
  });
}
