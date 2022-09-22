import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:more/number.dart' show Complex;

/// Performs an in-place Discrete Fast Fourier transformation on the provided
/// [values]. If [inverse] is `true`, the inverse transformation is computed.
/// Returns the transformed [values].
List<Complex> fft(List<Complex> values, {bool inverse = false}) {
  if (values.length <= 1) {
    return values;
  }
  // Adjust list size.
  var n = 1;
  while (n < values.length) {
    n <<= 1;
  }
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
        final u = values[i + j];
        final v = values[i + j + halfLen] * w;
        values[i + j] = u + v;
        values[i + j + halfLen] = u - v;
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
