import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/src/numeric/fft.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Fast Fourier Transform (FFT)', () {
    test('empty inputs', () {
      check(fft([])).isEmpty();
      check(rfft([])).isEmpty();
      check(irfft([])).isEmpty();
      check(fft2([])).isEmpty();
    });

    test('1D FFT of DC signal', () {
      final input = [
        const Complex(1.0, 0.0),
        const Complex(1.0, 0.0),
        const Complex(1.0, 0.0),
        const Complex(1.0, 0.0),
      ];
      final output = fft(input);
      check(output).length.equals(4);
      check(output[0].a).isCloseTo(4.0, 1e-9);
      check(output[0].b).isCloseTo(0.0, 1e-9);
      check(output[1].abs()).isCloseTo(0.0, 1e-9);
      check(output[2].abs()).isCloseTo(0.0, 1e-9);
      check(output[3].abs()).isCloseTo(0.0, 1e-9);

      // Input was not mutated
      check(input[0].a).equals(1.0);
    });

    test('1D FFT roundtrip (fft then ifft)', () {
      final signal = [
        const Complex(2.0, 1.0),
        const Complex(-1.5, 0.5),
        const Complex(3.0, -2.0),
        const Complex(0.5, 4.0),
      ];
      final spectrum = fft(signal);
      final reconstructed = ifft(spectrum);
      check(reconstructed).length.equals(signal.length);
      for (var i = 0; i < signal.length; i++) {
        check(reconstructed[i].a).isCloseTo(signal[i].a, 1e-6);
        check(reconstructed[i].b).isCloseTo(signal[i].b, 1e-6);
      }
    });

    test('rfft and irfft on real cosine wave', () {
      const n = 16;
      final wave = List<double>.generate(
        n,
        (i) => math.cos(2.0 * math.pi * 2.0 * i / n),
      );
      final rSpectrum = rfft(wave);
      check(rSpectrum).length.equals(n ~/ 2 + 1);
      // Frequency bin 2 should have peak magnitude n/2 = 8
      check(rSpectrum[2].a).isCloseTo(8.0, 1e-6);

      final recovered = irfft(rSpectrum, n);
      for (var i = 0; i < n; i++) {
        check(recovered[i]).isCloseTo(wave[i], 1e-6);
      }
    });

    test('2D FFT and IFFT power of 2', () {
      final image = [
        [const Complex(1.0, 0.0), const Complex(2.0, 0.0)],
        [const Complex(3.0, 0.0), const Complex(4.0, 0.0)],
      ];
      final spectrum2d = fft2(image);
      check(spectrum2d).length.equals(2);
      check(spectrum2d[0]).length.equals(2);
      // DC component is sum of all elements = 1 + 2 + 3 + 4 = 10
      check(spectrum2d[0][0].a).isCloseTo(10.0, 1e-9);

      final restored2d = ifft2(spectrum2d);
      for (var r = 0; r < 2; r++) {
        for (var c = 0; c < 2; c++) {
          check(restored2d[r][c].a).isCloseTo(image[r][c].a, 1e-6);
          check(restored2d[r][c].b).isCloseTo(image[r][c].b, 1e-6);
        }
      }
    });

    test('2D FFT and IFFT non-power of 2 (3x3)', () {
      final image = [
        [
          const Complex(1.0, 0.0),
          const Complex(2.0, 0.0),
          const Complex(3.0, 0.0),
        ],
        [
          const Complex(4.0, 0.0),
          const Complex(5.0, 0.0),
          const Complex(6.0, 0.0),
        ],
        [
          const Complex(7.0, 0.0),
          const Complex(8.0, 0.0),
          const Complex(9.0, 0.0),
        ],
      ];
      final spectrum2d = fft2(image);
      // Padded to 4x4
      check(spectrum2d).length.equals(4);
      check(spectrum2d[0]).length.equals(4);
      // DC component is sum of all elements = 45
      check(spectrum2d[0][0].a).isCloseTo(45.0, 1e-9);

      final restored2d = ifft2(spectrum2d);
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 3; c++) {
          check(restored2d[r][c].a).isCloseTo(image[r][c].a, 1e-6);
          check(restored2d[r][c].b).isCloseTo(image[r][c].b, 1e-6);
        }
      }
    });
  });
}
