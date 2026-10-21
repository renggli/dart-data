import 'dart:math' as math;
import 'dart:typed_data';

import '../../type/types/complex.dart';

/// Pure Dart reference implementation of Fast Fourier Transforms.
abstract final class FftDart {
  /// Computes the 1D discrete Fourier transform in-place on [buffer].
  static void fft({required Float64ComplexList buffer, required bool inverse}) {
    final length = buffer.length;
    if (length <= 1) return;
    if ((length & (length - 1)) != 0) {
      throw ArgumentError.value(
        length,
        'buffer.length',
        'Length must be a power of 2',
      );
    }
    fftInterleaved(data: buffer.data, length: length, inverse: inverse);
  }

  /// Cooley-Tukey decimation-in-time radix-2 FFT kernel operating directly on
  /// interleaved [data] buffer `[re0, im0, re1, im1, ...]`.
  static void fftInterleaved({
    required Float64List data,
    required int length,
    required bool inverse,
    int offset = 0,
  }) {
    // Bit-reversal permutation on interleaved buffer
    for (var i = 1, j = 0; i < length; i++) {
      var bit = length >> 1;
      for (; j & bit != 0; bit >>= 1) {
        j ^= bit;
      }
      j ^= bit;
      if (i < j) {
        final idxI = offset + (i << 1);
        final idxJ = offset + (j << 1);
        final tempR = data[idxI];
        final tempI = data[idxI + 1];
        data[idxI] = data[idxJ];
        data[idxI + 1] = data[idxJ + 1];
        data[idxJ] = tempR;
        data[idxJ + 1] = tempI;
      }
    }

    // Cooley-Tukey decimation-in-time radix-2 FFT
    for (var len = 2; len <= length; len <<= 1) {
      final halfLen = len >> 1;
      final step = halfLen << 1;
      final angle = (inverse ? 2.0 : -2.0) * math.pi / len;
      final wStepR = math.cos(angle);
      final wStepI = math.sin(angle);
      for (var i = 0; i < length; i += len) {
        var omegaR = 1.0;
        var omegaI = 0.0;
        var uIdx = offset + (i << 1);
        var vIdx = uIdx + step;
        for (var j = 0; j < halfLen; j++) {
          final uR = data[uIdx];
          final uI = data[uIdx + 1];
          final vR = data[vIdx];
          final vI = data[vIdx + 1];

          final vProdR = vR * omegaR - vI * omegaI;
          final vProdI = vR * omegaI + vI * omegaR;

          data[uIdx] = uR + vProdR;
          data[uIdx + 1] = uI + vProdI;
          data[vIdx] = uR - vProdR;
          data[vIdx + 1] = uI - vProdI;

          final nextOmegaR = omegaR * wStepR - omegaI * wStepI;
          final nextOmegaI = omegaR * wStepI + omegaI * wStepR;
          omegaR = nextOmegaR;
          omegaI = nextOmegaI;

          uIdx += 2;
          vIdx += 2;
        }
      }
    }

    if (inverse) {
      final factor = 1.0 / length;
      final end = offset + (length << 1);
      for (var i = offset; i < end; i++) {
        data[i] *= factor;
      }
    }
  }

  /// Computes the 2D discrete Fourier transform in-place on a flat row-major
  /// [buffer] of dimensions [rows] x [cols].
  static void fft2({
    required Float64ComplexList buffer,
    required int rows,
    required int cols,
    required bool inverse,
  }) {
    if (rows <= 0 || cols <= 0) return;
    if ((rows & (rows - 1)) != 0) {
      throw ArgumentError.value(rows, 'rows', 'Rows must be a power of 2');
    }
    if ((cols & (cols - 1)) != 0) {
      throw ArgumentError.value(cols, 'cols', 'Cols must be a power of 2');
    }
    if (buffer.length != rows * cols) {
      throw ArgumentError.value(
        buffer.length,
        'buffer.length',
        'Buffer length must equal rows * cols ($rows * $cols = ${rows * cols})',
      );
    }
    fft2Interleaved(
      data: buffer.data,
      rows: rows,
      cols: cols,
      inverse: inverse,
    );
  }

  /// 2D FFT kernel operating directly on flat interleaved [data] buffer of size
  /// [rows] x [cols].
  static void fft2Interleaved({
    required Float64List data,
    required int rows,
    required int cols,
    required bool inverse,
  }) {
    final rowStride = cols << 1;

    // 1. In-place 1D row transforms directly on contiguous interleaved data
    var rowOffset = 0;
    for (var r = 0; r < rows; r++, rowOffset += rowStride) {
      fftInterleaved(
        data: data,
        length: cols,
        inverse: inverse,
        offset: rowOffset,
      );
    }

    // 2. In-place 1D column transforms with pointer stepping
    final colBuffer = Float64List(rows << 1);
    for (var c = 0; c < cols; c++) {
      var srcIdx = c << 1;
      var colIdx = 0;
      for (var r = 0; r < rows; r++) {
        colBuffer[colIdx] = data[srcIdx];
        colBuffer[colIdx + 1] = data[srcIdx + 1];
        colIdx += 2;
        srcIdx += rowStride;
      }
      fftInterleaved(data: colBuffer, length: rows, inverse: inverse);
      var dstIdx = c << 1;
      colIdx = 0;
      for (var r = 0; r < rows; r++) {
        data[dstIdx] = colBuffer[colIdx];
        data[dstIdx + 1] = colBuffer[colIdx + 1];
        colIdx += 2;
        dstIdx += rowStride;
      }
    }
  }

  /// Computes next power of 2 for [value].
  static int nextPowerOf2({required int value}) {
    if (value <= 1) return 1;
    var power = value - 1;
    power |= power >> 1;
    power |= power >> 2;
    power |= power >> 4;
    power |= power >> 8;
    power |= power >> 16;
    power |= power >> 32;
    return power + 1;
  }
}
