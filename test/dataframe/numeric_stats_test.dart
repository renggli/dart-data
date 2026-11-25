import 'package:checks/checks.dart';
import 'package:data/src/dataframe/numeric_stats.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('computeNumericMean', () {
    test('returns null on empty or all-null inputs', () {
      check(computeNumericMean(0, (_) => null)).isNull;
      check(computeNumericMean(3, (_) => null)).isNull;
    });

    test('propagates NaN and handles signed infinities', () {
      final withNaN = [1.0, double.nan, 3.0];
      check(computeNumericMean(withNaN.length, (i) => withNaN[i])!).isNaN;

      final posInf = [1.0, double.infinity];
      check(computeNumericMean(posInf.length, (i) => posInf[i]))
          .equals(double.infinity);

      final negInf = [1.0, double.negativeInfinity];
      check(computeNumericMean(negInf.length, (i) => negInf[i]))
          .equals(double.negativeInfinity);

      final mixedInf = [double.infinity, double.negativeInfinity];
      check(computeNumericMean(mixedInf.length, (i) => mixedInf[i])!).isNaN;
    });

    test('avoids overflow on huge finite values', () {
      final huge = [1e308, 1e308];
      check(computeNumericMean(huge.length, (i) => huge[i])!)
          .isCloseTo(1e308, 1e294);
    });
  });

  group('computeNumericVariance', () {
    test('returns null for insufficient samples', () {
      check(computeNumericVariance(0, (_) => null, population: true)).isNull;
      check(computeNumericVariance(1, (_) => 5.0, population: false)).isNull;
      check(computeNumericVariance(1, (_) => 5.0, population: true))
          .equals(0.0);
    });

    test('returns NaN on NaN or non-finite inputs', () {
      final nanVals = [1.0, double.nan];
      check(
        computeNumericVariance(
          nanVals.length,
          (i) => nanVals[i],
          population: true,
        )!,
      ).isNaN;

      final infVals = [1.0, double.infinity];
      check(
        computeNumericVariance(
          infVals.length,
          (i) => infVals[i],
          population: true,
        )!,
      ).isNaN;
    });

    test('handles extreme finite values without spurious overflow', () {
      final identicalHuge = [1e308, 1e308];
      check(
        computeNumericVariance(
          identicalHuge.length,
          (i) => identicalHuge[i],
          population: false,
        ),
      ).equals(0.0);

      final scaledHuge = List<double>.generate(
        10,
        (i) => i.isEven ? 0.0 : 6e153,
      );
      check(
        computeNumericVariance(
          scaledHuge.length,
          (i) => scaledHuge[i],
          population: true,
        )!,
      ).isCloseTo(9e306, 1e294);

      final wideHuge = [-1e308, 1e308];
      check(
        computeNumericVariance(
          wideHuge.length,
          (i) => wideHuge[i],
          population: true,
        ),
      ).equals(double.infinity);
    });
  });

  group('interpolateQuantile and computeQuantileInPlace', () {
    test(
      'interpolateQuantile handles boundary fractions and overflow diffs',
      () {
        check(interpolateQuantile(3.0, 3.0, 0.5)).equals(3.0);
        check(interpolateQuantile(1.0, 9.0, 0.0)).equals(1.0);
        check(interpolateQuantile(1.0, 9.0, 1.0)).equals(9.0);
        check(interpolateQuantile(-1e308, 1e308, 0.5)).equals(0.0);
      },
    );

    test(
      'computeQuantileInPlace validates range and handles odd/even sets',
      () {
        check(() => computeQuantileInPlace([1.0], -0.1)).throws<RangeError>();
        check(() => computeQuantileInPlace([1.0], 1.1)).throws<RangeError>();
        check(() => computeQuantileInPlace([1.0], double.nan))
            .throws<RangeError>();
        check(computeQuantileInPlace([], 0.5)).isNull;
        check(computeQuantileInPlace([1.0, double.nan], 0.5)!).isNaN;

        check(computeQuantileInPlace([30.0, 10.0, 20.0], 0.5)).equals(20.0);
        check(computeQuantileInPlace([40.0, 10.0, 30.0, 20.0], 0.5))
            .equals(25.0);
        check(computeQuantileInPlace([40.0, 10.0, 30.0, 20.0], 0.25))
            .equals(17.5);
      },
    );
  });
}
