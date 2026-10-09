import 'dart:math' as math;

import 'package:data/src/numeric/fft.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('Fast Fourier Transform (FFT)', () {
    test('1D FFT of DC signal', () {
      final input = [
        const Complex(1.0, 0.0),
        const Complex(1.0, 0.0),
        const Complex(1.0, 0.0),
        const Complex(1.0, 0.0),
      ];
      final output = fft(input);
      expect(output.length, 4);
      expect(output[0].a, closeTo(4.0, 1e-9));
      expect(output[0].b, closeTo(0.0, 1e-9));
      expect(output[1].abs(), closeTo(0.0, 1e-9));
      expect(output[2].abs(), closeTo(0.0, 1e-9));
      expect(output[3].abs(), closeTo(0.0, 1e-9));

      // Input was not mutated
      expect(input[0].a, 1.0);
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
      expect(reconstructed.length, signal.length);
      for (var i = 0; i < signal.length; i++) {
        expect(reconstructed[i].a, closeTo(signal[i].a, 1e-6));
        expect(reconstructed[i].b, closeTo(signal[i].b, 1e-6));
      }
    });

    test('rfft and irfft on real cosine wave', () {
      const n = 16;
      final wave = List<double>.generate(
        n,
        (i) => math.cos(2.0 * math.pi * 2.0 * i / n),
      );
      final rSpectrum = rfft(wave);
      expect(rSpectrum.length, n ~/ 2 + 1);
      // Frequency bin 2 should have peak magnitude n/2 = 8
      expect(rSpectrum[2].a, closeTo(8.0, 1e-6));

      final recovered = irfft(rSpectrum, n);
      for (var i = 0; i < n; i++) {
        expect(recovered[i], closeTo(wave[i], 1e-6));
      }
    });

    test('2D FFT and IFFT', () {
      final image = [
        [const Complex(1.0, 0.0), const Complex(2.0, 0.0)],
        [const Complex(3.0, 0.0), const Complex(4.0, 0.0)],
      ];
      final spectrum2d = fft2(image);
      expect(spectrum2d.length, 2);
      expect(spectrum2d[0].length, 2);
      // DC component is sum of all elements = 1 + 2 + 3 + 4 = 10
      expect(spectrum2d[0][0].a, closeTo(10.0, 1e-9));

      final restored2d = ifft2(spectrum2d);
      for (var r = 0; r < 2; r++) {
        for (var c = 0; c < 2; c++) {
          expect(restored2d[r][c].a, closeTo(image[r][c].a, 1e-6));
          expect(restored2d[r][c].b, closeTo(image[r][c].b, 1e-6));
        }
      }
    });
  });
}
