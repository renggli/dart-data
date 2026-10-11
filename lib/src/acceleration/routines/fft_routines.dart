import 'dart:math' as math;
import 'dart:typed_data';

import 'package:more/number.dart' show Complex;

import '../acceleration_manager.dart';
import '../acceleration_mode.dart';
import '../fallback/pure_dart_fft.dart';
import '../vdsp/vdsp.dart';

/// Fast Fourier Transform routines with native hardware acceleration and pure
/// Dart fallback.
abstract final class FftRoutines {
  /// Computes the 1D discrete Fourier transform of [input].
  static List<Complex> fft(
    Iterable<Complex> input, {
    required VdspLibrary vdsp,
    bool inverse = false,
  }) {
    final mode = AccelerationManager.mode;
    if (mode == AccelerationMode.dart) {
      return PureDartFft.fft(input, inverse: inverse);
    }

    if (mode == AccelerationMode.accelerated && !vdsp.hasFft) {
      throw StateError(
        'AccelerationMode.accelerated requested but native FFT acceleration is unavailable.',
      );
    }

    final list = input.toList();
    if (list.length <= 1) {
      return List<Complex>.of(list);
    }

    final length = PureDartFft.nextPowerOf2(list.length);
    final log2n = (math.log(length) / math.ln2).round();

    if (vdsp.hasFft && (1 << log2n) == length) {
      final real = Float64List(length);
      final imag = Float64List(length);
      for (var i = 0; i < list.length; i++) {
        final c = list[i];
        real[i] = c.a.toDouble();
        imag[i] = c.b.toDouble();
      }

      final success = vdsp.fft1d(
        real: real,
        imag: imag,
        log2n: log2n,
        inverse: inverse,
      );

      if (success) {
        return List<Complex>.generate(
          length,
          (i) => Complex(real[i], imag[i]),
          growable: false,
        );
      }
    }

    if (mode == AccelerationMode.accelerated) {
      throw StateError('Native hardware FFT execution failed.');
    }

    return PureDartFft.fft(input, inverse: inverse);
  }

  /// Computes the 1D discrete Fourier transform for real-valued signals.
  static List<Complex> rfft(Iterable<num> input, {required VdspLibrary vdsp}) {
    if (input.isEmpty) return const [];
    final complexInput = [for (final x in input) Complex(x.toDouble(), 0.0)];
    final full = fft(complexInput, vdsp: vdsp, inverse: false);
    final fullLen = full.length;
    final half = (fullLen >> 1) + 1;
    return full.sublist(0, half);
  }

  /// Computes the inverse discrete Fourier transform for real-valued signals.
  static List<double> irfft(
    List<Complex> input, {
    required VdspLibrary vdsp,
    int? n,
  }) {
    if (input.isEmpty) return const [];
    final targetLength = n ?? (2 * (input.length - 1));
    final fullLength = PureDartFft.nextPowerOf2(targetLength);
    final fullSpectrum = List<Complex>.filled(fullLength, Complex.zero);

    for (var i = 0; i < input.length && i < fullLength; i++) {
      fullSpectrum[i] = input[i];
    }
    for (var i = 1; i < input.length - 1 && i < (fullLength >> 1); i++) {
      final orig = input[i];
      fullSpectrum[fullLength - i] = Complex(orig.a, -orig.b);
    }

    final reconstructed = fft(fullSpectrum, vdsp: vdsp, inverse: true);
    return [
      for (var i = 0; i < targetLength; i++) reconstructed[i].a.toDouble(),
    ];
  }

  /// Computes the 2D discrete Fourier transform of [matrix].
  static List<List<Complex>> fft2(
    List<List<Complex>> matrix, {
    required VdspLibrary vdsp,
    bool inverse = false,
  }) {
    final mode = AccelerationManager.mode;
    if (mode == AccelerationMode.dart) {
      return PureDartFft.fft2(matrix, inverse: inverse);
    }

    if (mode == AccelerationMode.accelerated && !vdsp.hasFft) {
      throw StateError(
        'AccelerationMode.accelerated requested but native FFT acceleration is unavailable.',
      );
    }

    if (matrix.isEmpty || matrix[0].isEmpty) return const [];
    final rowCount = matrix.length;
    final colCount = matrix[0].length;
    final targetRows = PureDartFft.nextPowerOf2(rowCount);
    final targetCols = PureDartFft.nextPowerOf2(colCount);
    final log2rows = (math.log(targetRows) / math.ln2).round();
    final log2cols = (math.log(targetCols) / math.ln2).round();

    if (vdsp.hasFft &&
        (1 << log2rows) == targetRows &&
        (1 << log2cols) == targetCols) {
      final total = targetRows * targetCols;
      final real = Float64List(total);
      final imag = Float64List(total);

      for (var r = 0; r < rowCount; r++) {
        final row = matrix[r];
        final rowOffset = r * targetCols;
        for (var c = 0; c < row.length && c < targetCols; c++) {
          real[rowOffset + c] = row[c].a.toDouble();
          imag[rowOffset + c] = row[c].b.toDouble();
        }
      }

      final success = vdsp.fft2d(
        real: real,
        imag: imag,
        log2rows: log2rows,
        log2cols: log2cols,
        inverse: inverse,
      );

      if (success) {
        return List.generate(targetRows, (r) {
          final rowOffset = r * targetCols;
          return List<Complex>.generate(
            targetCols,
            (c) => Complex(real[rowOffset + c], imag[rowOffset + c]),
            growable: false,
          );
        });
      }
    }

    if (mode == AccelerationMode.accelerated) {
      throw StateError('Native hardware 2D FFT execution failed.');
    }

    return PureDartFft.fft2(matrix, inverse: inverse);
  }
}
