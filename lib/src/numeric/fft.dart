import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:more/math.dart';
import 'package:more/number.dart' show Complex;

/// Performs an in-place Discrete Fast Fourier transformation on the provided
/// [values]. If necessary, extends the size the provided list to a power of
/// two. collection to a power of two. Returns the modified collection of
/// transformed values.
///
/// If [inverse] is `true`, the inverse transformation is computed.
List<Complex> fft(List<Complex> values, {bool inverse = false}) {
  if (values.length <= 1) {
    return values;
  }
  final n = values.length.bitCeil;
  while (values.length < n) {
    values.add(Complex.zero);
  }
  // Permute the elements.
  for (var i = 1, j = 0; i < n; i++) {
    var bit = n >> 1;
    for (; j & bit != 0; bit >>= 1) {
      j ^= bit;
    }
    j ^= bit;
    if (i < j) {
      values.swap(i, j);
    }
  }
  // Transform the elements.
  for (var len = 2; len <= n; len <<= 1) {
    final halfLen = len >> 1;
    final a = 2.0 * math.pi / len * (inverse ? -1 : 1);
    final r = Complex(math.cos(a), math.sin(a));
    for (var i = 0; i < n; i += len) {
      var w = Complex.one;
      for (var j = 0; j < halfLen; j++) {
        final ui = i + j, vi = ui + halfLen;
        final u = values[ui], v = values[vi] * w;
        values[ui] = u + v;
        values[vi] = u - v;
        w *= r;
      }
    }
  }
  // Invert the transformation.
  if (inverse) {
    for (var i = 0; i < n; i++) {
      values[i] /= n;
    }
  }
  return values;
}
