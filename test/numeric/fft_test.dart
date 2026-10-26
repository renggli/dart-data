import 'package:checks/checks.dart';
import 'package:data/src/numeric/fft.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('Fast Fourier Transform (FFT)', () {
    test('empty inputs', () {
      final empty = <Complex>[];
      fft(empty);
      check(empty).isEmpty();

      final empty2 = <Complex>[];
      fft2(empty2, rows: 0, cols: 0);
      check(empty2).isEmpty();
    });

    test('1D FFT of DC signal in-place on List<Complex>', () {
      final input = [
        const Complex(1.0, 0.0),
        const Complex(1.0, 0.0),
        const Complex(1.0, 0.0),
        const Complex(1.0, 0.0),
      ];
      fft(input);
      check(input.length).equals(4);
      check(input[0].a).isCloseTo(4.0, 1e-9);
      check(input[0].b).isCloseTo(0.0, 1e-9);
      check(input[1].abs()).isCloseTo(0.0, 1e-9);
      check(input[2].abs()).isCloseTo(0.0, 1e-9);
      check(input[3].abs()).isCloseTo(0.0, 1e-9);
    });

    test('1D FFT of DC signal in-place on Float64ComplexList', () {
      final input = Float64ComplexList.fromList([
        const Complex(1.0, 0.0),
        const Complex(1.0, 0.0),
        const Complex(1.0, 0.0),
        const Complex(1.0, 0.0),
      ]);
      fft(input);
      check(input.length).equals(4);
      check(input[0].a).isCloseTo(4.0, 1e-9);
      check(input[0].b).isCloseTo(0.0, 1e-9);
      check(input[1].abs()).isCloseTo(0.0, 1e-9);
      check(input[2].abs()).isCloseTo(0.0, 1e-9);
      check(input[3].abs()).isCloseTo(0.0, 1e-9);
    });

    test('1D FFT roundtrip on List<Complex>', () {
      final signal = [
        const Complex(2.0, 1.0),
        const Complex(-1.5, 0.5),
        const Complex(3.0, -2.0),
        const Complex(0.5, 4.0),
      ];
      final orig = List.of(signal);

      fft(signal);
      fft(signal, inverse: true);

      check(signal.length).equals(orig.length);
      for (var i = 0; i < signal.length; i++) {
        check(signal[i].a).isCloseTo(orig[i].a, 1e-6);
        check(signal[i].b).isCloseTo(orig[i].b, 1e-6);
      }
    });

    test('2D FFT and IFFT power of 2 (List<Complex>)', () {
      final image = [
        const Complex(1.0, 0.0),
        const Complex(2.0, 0.0),
        const Complex(3.0, 0.0),
        const Complex(4.0, 0.0),
      ];
      final orig = List.of(image);

      fft2(image, rows: 2, cols: 2);
      // DC component is sum of all elements = 1 + 2 + 3 + 4 = 10
      check(image[0].a).isCloseTo(10.0, 1e-9);

      fft2(image, rows: 2, cols: 2, inverse: true);
      for (var i = 0; i < 4; i++) {
        check(image[i].a).isCloseTo(orig[i].a, 1e-6);
        check(image[i].b).isCloseTo(orig[i].b, 1e-6);
      }
    });

    test('2D FFT and IFFT power of 2 (Float64ComplexList)', () {
      final image = Float64ComplexList.fromList([
        const Complex(1.0, 0.0),
        const Complex(2.0, 0.0),
        const Complex(3.0, 0.0),
        const Complex(4.0, 0.0),
      ]);
      final orig = List<Complex>.from(image);

      fft2(image, rows: 2, cols: 2);
      check(image[0].a).isCloseTo(10.0, 1e-9);

      fft2(image, rows: 2, cols: 2, inverse: true);
      for (var i = 0; i < 4; i++) {
        check(image[i].a).isCloseTo(orig[i].a, 1e-6);
        check(image[i].b).isCloseTo(0.0, 1e-6);
      }
    });

    test('1D FFT of non-power-of-2 signals via Bluestein', () {
      for (final length in [3, 5, 6, 7, 10, 15]) {
        final signal = [
          for (var i = 0; i < length; i++)
            Complex(i.toDouble() + 1.0, (length - i).toDouble()),
        ];
        final orig = List.of(signal);

        fft(signal);
        fft(signal, inverse: true);

        check(signal.length).equals(orig.length);
        for (var i = 0; i < signal.length; i++) {
          check(signal[i].a).isCloseTo(orig[i].a, 1e-5);
          check(signal[i].b).isCloseTo(orig[i].b, 1e-5);
        }
      }
    });

    test('convolve with ConvolutionMode full, same, and valid', () {
      final signal = [1.0, 2.0, 3.0, 4.0, 5.0];
      final filter = [1.0, 2.0];

      final full = convolve(signal, filter, mode: ConvolutionMode.full);
      check(full.length).equals(6);
      check(full[0]).isCloseTo(1.0, 1e-9);
      check(full[1]).isCloseTo(4.0, 1e-9);
      check(full[2]).isCloseTo(7.0, 1e-9);
      check(full[3]).isCloseTo(10.0, 1e-9);
      check(full[4]).isCloseTo(13.0, 1e-9);
      check(full[5]).isCloseTo(10.0, 1e-9);

      final same = convolve(signal, filter, mode: ConvolutionMode.same);
      check(same.length).equals(5);
      check(same[0]).isCloseTo(1.0, 1e-9);
      check(same[1]).isCloseTo(4.0, 1e-9);
      check(same[2]).isCloseTo(7.0, 1e-9);
      check(same[3]).isCloseTo(10.0, 1e-9);
      check(same[4]).isCloseTo(13.0, 1e-9);

      final valid = convolve(signal, filter, mode: ConvolutionMode.valid);
      check(valid.length).equals(4);
      check(valid[0]).isCloseTo(4.0, 1e-9);
      check(valid[1]).isCloseTo(7.0, 1e-9);
      check(valid[2]).isCloseTo(10.0, 1e-9);
      check(valid[3]).isCloseTo(13.0, 1e-9);
    });

    test('correlate 1D valid cross-correlation', () {
      final signal = [1.0, 2.0, 3.0, 4.0, 5.0];
      final filter = [1.0, 2.0];
      final result = correlate(signal, filter);
      check(result.length).equals(4);
      check(result[0]).isCloseTo(5.0, 1e-9);
      check(result[1]).isCloseTo(8.0, 1e-9);
      check(result[2]).isCloseTo(11.0, 1e-9);
      check(result[3]).isCloseTo(14.0, 1e-9);
    });

    test(
      'fft2 validation errors for non-power-of-two and mismatched length',
      () {
        final buf = Float64ComplexList(4);
        check(() => fft2(buf, rows: 3, cols: 2)).throws<ArgumentError>();
        check(() => fft2(buf, rows: 2, cols: 3)).throws<ArgumentError>();
        check(() => fft2(buf, rows: 2, cols: 4)).throws<ArgumentError>();
      },
    );
  });
}
