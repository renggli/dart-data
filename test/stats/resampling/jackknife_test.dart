import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:more/collection.dart' show IntegerRange;
import 'package:test/scaffolding.dart';

void main() {
  group('Jackknife estimation and influence metrics', () {
    test(
      'computes mean estimates, pseudo-values, influence values, and interval',
      () {
        final samples = <int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
        final jackknife = Jackknife<int>(samples, mean);

        check(jackknife.confidenceLevel).equals(0.95);
        check(jackknife.resamples.length).equals(10);
        check(jackknife.resampleEstimates.length).equals(10);
        check(jackknife.pseudoValues.length).equals(10);
        check(jackknife.influenceValues.length).equals(10);
        for (var i = 0; i < 10; i++) {
          check(jackknife.resamples[i]).deepEquals([
            ...IntegerRange(0, i),
            ...IntegerRange(i + 1, samples.length),
          ]);
          check(jackknife.pseudoValues[i])
              .isCloseTo(samples[i].toDouble(), 1e-12);
        }

        check(jackknife.estimate).isCloseTo(4.5, 1e-12);
        check(jackknife.bias).isCloseTo(0.0, 1e-12);
        check(jackknife.acceleration).isCloseTo(0.0, 1e-12);
        check(jackknife.standardError).isCloseTo(0.95742710, 1e-6);
        check(jackknife.lowerBound).isCloseTo(2.62347735, 1e-6);
        check(jackknife.upperBound).isCloseTo(6.37652265, 1e-6);
        check(jackknife.confidenceInterval.lower).equals(jackknife.lowerBound);
        check(jackknife.confidenceInterval.upper).equals(jackknife.upperBound);
      },
    );

    test(
      'computes bias-corrected population variance and skewed acceleration',
      () {
        final samples = <int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
        final jackknife = Jackknife<int>(
          samples,
          (list) => variance(list, population: true),
        );
        check(jackknife.estimate).isCloseTo(9.16666667, 1e-6);
        check(jackknife.bias).isCloseTo(-0.91666667, 1e-6);
        check(jackknife.standardError).isCloseTo(2.69124476, 1e-6);

        // Acceleration stays scale-invariant even at extreme magnitudes.
        final skewedBase = Jackknife<double>(const [1.0, 2.0, 3.0, 20.0], mean);
        final skewedHuge = Jackknife<double>(const [
          1e100,
          2e100,
          3e100,
          2e101,
        ], mean);
        check(skewedHuge.acceleration)
            .isCloseTo(skewedBase.acceleration, 1e-12);
      },
    );

    test('handles size-2 samples and enforces immutability and validation', () {
      final mutable = <int>[2, 4];
      final jackknife = Jackknife<int>(mutable, mean, confidenceLevel: 0.90);
      mutable[0] = 99;
      check(jackknife.samples).deepEquals([2, 4]);
      check(jackknife.estimate).isCloseTo(3.0, 1e-12);
      check(jackknife.standardError).isCloseTo(1.0, 1e-12);
      check(jackknife.lowerBound).isCloseTo(1.35514638, 1e-6);
      check(jackknife.upperBound).isCloseTo(4.64485361, 1e-6);
      check(jackknife.toString()).contains('Jackknife');

      check(() => jackknife.samples[0] = 0).throws<UnsupportedError>();
      check(() => jackknife.resamples[0][0] = 0).throws<UnsupportedError>();
      check(() => jackknife.resamples[0][-1]).throws<RangeError>();
      check(() => jackknife.resamples[0][1]).throws<RangeError>();

      check(() => Jackknife<int>(const <int>[], mean)).throws<ArgumentError>();
      check(() => Jackknife<int>(const [1], mean)).throws<ArgumentError>();
      check(() => Jackknife<int>(const [1, 2], mean, confidenceLevel: 0.0))
          .throws<ArgumentError>();
      check(
        () => Jackknife<int>(const [1, 2], mean, confidenceLevel: double.nan),
      ).throws<ArgumentError>();
    });
  });
}
