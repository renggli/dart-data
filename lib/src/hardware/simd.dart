import 'dart:typed_data';

/// Pure Dart SIMD acceleration routines using [Float32x4].
class SimdEngine {
  const new();

  /// Adds [a] and [b] element-wise into [out] using 128-bit SIMD instructions.
  static void addFloat32(Float32List a, Float32List b, Float32List out) {
    final len = a.length;
    final simdLen = len ~/ 4;

    final aSimd = Float32x4List.view(a.buffer, a.offsetInBytes, simdLen);
    final bSimd = Float32x4List.view(b.buffer, b.offsetInBytes, simdLen);
    final outSimd = Float32x4List.view(out.buffer, out.offsetInBytes, simdLen);

    for (var i = 0; i < simdLen; i++) {
      outSimd[i] = aSimd[i] + bSimd[i];
    }
    for (var i = simdLen * 4; i < len; i++) {
      out[i] = a[i] + b[i];
    }
  }

  /// Subtracts [b] from [a] element-wise into [out] using 128-bit SIMD instructions.
  static void subFloat32(Float32List a, Float32List b, Float32List out) {
    final len = a.length;
    final simdLen = len ~/ 4;

    final aSimd = Float32x4List.view(a.buffer, a.offsetInBytes, simdLen);
    final bSimd = Float32x4List.view(b.buffer, b.offsetInBytes, simdLen);
    final outSimd = Float32x4List.view(out.buffer, out.offsetInBytes, simdLen);

    for (var i = 0; i < simdLen; i++) {
      outSimd[i] = aSimd[i] - bSimd[i];
    }
    for (var i = simdLen * 4; i < len; i++) {
      out[i] = a[i] - b[i];
    }
  }

  /// Multiplies [a] and [b] element-wise into [out] using 128-bit SIMD instructions.
  static void mulFloat32(Float32List a, Float32List b, Float32List out) {
    final len = a.length;
    final simdLen = len ~/ 4;

    final aSimd = Float32x4List.view(a.buffer, a.offsetInBytes, simdLen);
    final bSimd = Float32x4List.view(b.buffer, b.offsetInBytes, simdLen);
    final outSimd = Float32x4List.view(out.buffer, out.offsetInBytes, simdLen);

    for (var i = 0; i < simdLen; i++) {
      outSimd[i] = aSimd[i] * bSimd[i];
    }
    for (var i = simdLen * 4; i < len; i++) {
      out[i] = a[i] * b[i];
    }
  }

  /// Computes the dot product of [a] and [b] using 128-bit SIMD instructions.
  static double dotFloat32(Float32List a, Float32List b) {
    final len = a.length;
    final simdLen = len ~/ 4;

    final aSimd = Float32x4List.view(a.buffer, a.offsetInBytes, simdLen);
    final bSimd = Float32x4List.view(b.buffer, b.offsetInBytes, simdLen);

    var acc = Float32x4.zero();
    for (var i = 0; i < simdLen; i++) {
      acc += aSimd[i] * bSimd[i];
    }
    var sum = acc.x + acc.y + acc.z + acc.w;
    for (var i = simdLen * 4; i < len; i++) {
      sum += a[i] * b[i];
    }
    return sum;
  }
}
