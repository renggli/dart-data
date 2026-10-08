import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:more/math.dart';
import 'package:more/number.dart' show Complex;

/// Performs an in-place Discrete Fast Fourier transformation on the provided
/// [values]. If necessary, extends the size the provided list to a power of
/// two. Returns the modified collection of transformed values.
///
/// If [inverse] is `true`, the inverse transformation is computed.
///
/// ```dart
/// final values = [
///   Complex(1, 0),
///   Complex(1, 0),
///   Complex(1, 0),
///   Complex(1, 0),
/// ];
/// final result = fft(values);
/// print(result);  // [Complex(4.0, 0.0), Complex(0.0, 0.0),
///                 //  Complex(0.0, 0.0), Complex(0.0, 0.0)]
/// ```
List<Complex> fft(List<Complex> values, {bool inverse = false}) {
  if (values.length <= 1) {
    return values;
  }
  var result = values;
  final n = values.length.bitCeil;
  if (result.length < n) {
    try {
      while (result.length < n) {
        result.add(Complex.zero);
      }
    } on UnsupportedError {
      result = [...result, ...List.filled(n - result.length, Complex.zero)];
    }
  }
  // Permute the elements.
  for (var i = 1, j = 0; i < n; i++) {
    var bit = n >> 1;
    for (; j & bit != 0; bit >>= 1) {
      j ^= bit;
    }
    j ^= bit;
    if (i < j) {
      result.swap(i, j);
    }
  }
  // Transform the elements.
  for (var len = 2; len <= n; len <<= 1) {
    final halfLen = len >> 1;
    final a = (inverse ? 2 : -2) * math.pi / len;
    final r = Complex(math.cos(a), math.sin(a));
    var w = Complex.one;
    for (var j = 0; j < halfLen; j++) {
      for (var i = j; i < n; i += len) {
        final ui = i, vi = ui + halfLen;
        final u = result[ui], v = result[vi] * w;
        result[ui] = u + v;
        result[vi] = u - v;
      }
      w *= r;
    }
  }
  // Invert the transformation.
  if (inverse) {
    for (var i = 0; i < n; i++) {
      result[i] /= n;
    }
  }
  return result;
}
