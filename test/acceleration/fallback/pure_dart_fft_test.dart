import 'package:checks/checks.dart';
import 'package:data/src/acceleration/fallback/pure_dart_fft.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/test.dart';

void main() {
  group('PureDartFft', () {
    test('rfft and irfft round-trip', () {
      final input = [1.0, 2.0, 3.0, 4.0];
      final spectrum = PureDartFft.rfft(input);
      check(spectrum.length).equals(3); // (4 >> 1) + 1 = 3

      final recovered = PureDartFft.irfft(spectrum, input.length);
      check(recovered.length).equals(4);
      for (var i = 0; i < input.length; i++) {
        check(recovered[i]).isCloseTo(input[i], 1e-10);
      }
    });

    test('rfft and irfft empty input', () {
      check(PureDartFft.rfft(const [])).isEmpty();
      check(PureDartFft.irfft(const [])).isEmpty();
    });

    test('fft2 base cases and empty matrix', () {
      check(PureDartFft.fft2(const [], inverse: false)).isEmpty();
      check(PureDartFft.fft2([const []], inverse: false)).isEmpty();

      final matrix = [
        [Complex.one, Complex.zero],
        [Complex.zero, Complex.one],
      ];
      final transformed = PureDartFft.fft2(matrix, inverse: false);
      check(transformed.length).equals(2);
      check(transformed[0].length).equals(2);

      final inverted = PureDartFft.fft2(transformed, inverse: true);
      for (var r = 0; r < 2; r++) {
        for (var c = 0; c < 2; c++) {
          check(inverted[r][c].a).isCloseTo(matrix[r][c].a, 1e-10);
          check(inverted[r][c].b).isCloseTo(matrix[r][c].b, 1e-10);
        }
      }
    });
  });
}
