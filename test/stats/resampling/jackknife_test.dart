import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:more/collection.dart' show IntegerRange;
import 'package:test/test.dart';

void main() {
  group('jackknife', () {
    test('mean', () {
      final samples = <int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
      final jackknife = Jackknife<int>(samples, (list) => list.mean());
      check(jackknife.samples).identicalTo(samples);
      check(jackknife.confidenceLevel).equals(0.95);
      check(jackknife.resamples).length.equals(10);
      for (var i = 0; i < 10; i++) {
        check(jackknife.resamples[i]).deepEquals([
          ...IntegerRange(0, i),
          ...IntegerRange(i + 1, samples.length),
        ]);
        check(() => jackknife.resamples[i][0] = 0).throws<UnsupportedError>();
      }
      check(jackknife.estimate).isCloseTo(4.5, 1e-6);
      check(jackknife.bias).isCloseTo(0.0, 1e-6);
      check(jackknife.standardError).isCloseTo(0.95742710, 1e-6);
      check(jackknife.lowerBound).isCloseTo(2.62347735, 1e-6);
      check(jackknife.upperBound).isCloseTo(6.37652265, 1e-6);
      check(jackknife.confidenceInterval.lower).isCloseTo(2.62347735, 1e-6);
      check(jackknife.confidenceInterval.upper).isCloseTo(6.37652265, 1e-6);
    });

    test('variance', () {
      final samples = <int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
      final jackknife = Jackknife<int>(
        samples,
        (list) => list.variance(population: true),
      );
      check(jackknife.samples).identicalTo(samples);
      check(jackknife.confidenceLevel).equals(0.95);
      check(jackknife.resamples).length.equals(10);
      for (var i = 0; i < 10; i++) {
        check(jackknife.resamples[i]).deepEquals([
          ...IntegerRange(0, i),
          ...IntegerRange(i + 1, samples.length),
        ]);
        check(() => jackknife.resamples[i][0] = 0).throws<UnsupportedError>();
      }
      check(jackknife.estimate).isCloseTo(9.16666667, 1e-6);
      check(jackknife.bias).isCloseTo(-0.91666667, 1e-6);
      check(jackknife.standardError).isCloseTo(2.69124476, 1e-6);
      check(jackknife.lowerBound).isCloseTo(3.89192387, 1e-6);
      check(jackknife.upperBound).isCloseTo(14.44140947, 1e-6);
    });

    test('small samples', () {
      final samples = <int>[2, 4];
      final jackknife = Jackknife<int>(
        samples,
        (list) => list.mean(),
        confidenceLevel: 0.90,
      );
      check(jackknife.estimate).isCloseTo(3.0, 1e-6);
      check(jackknife.bias).isCloseTo(0.0, 1e-6);
      check(jackknife.standardError).isCloseTo(1.0, 1e-6);
      check(jackknife.lowerBound).isCloseTo(1.35514638, 1e-6);
      check(jackknife.upperBound).isCloseTo(4.64485361, 1e-6);
    });

    test('toString and validation', () {
      final samples = [1.0, 2.0, 3.0];
      final jackknife = Jackknife<double>(samples, (list) => list.mean());
      check(jackknife.toString()).contains('Jackknife');

      check(() => Jackknife<int>([], (list) => list.mean()))
          .throws<ArgumentError>();
      check(() => Jackknife<int>([1], (list) => list.mean()))
          .throws<ArgumentError>();
      check(
        () => Jackknife<int>(
          samples.map((e) => e.toInt()).toList(),
          (list) => list.mean(),
          confidenceLevel: 0.0,
        ),
      ).throws<ArgumentError>();
      check(
        () => Jackknife<int>(
          samples.map((e) => e.toInt()).toList(),
          (list) => list.mean(),
          confidenceLevel: 1.0,
        ),
      ).throws<ArgumentError>();
    });
  });
}
