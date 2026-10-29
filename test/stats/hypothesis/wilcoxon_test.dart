import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('wilcoxon', () {
    test('Wilcoxon signed-rank test', () {
      // One-sample test: median > 0
      final x = [3.0, 4.0, 2.5, 5.0, 6.2, 4.1, 5.5, 3.8, 4.9, 6.0];
      final resOneSample = wilcoxonSignedRankTest(x);
      check(resOneSample.isSignificant).isTrue();
      check(resOneSample.pValue).isLessThan(0.01);

      // Paired test with significant difference
      final before = [120.0, 125.0, 130.0, 118.0, 140.0, 135.0, 122.0, 128.0];
      final after = [110.0, 115.0, 122.0, 112.0, 128.0, 125.0, 118.0, 120.0];
      final resPaired = wilcoxonSignedRankTest(before, y: after);
      check(resPaired.isSignificant).isTrue();
      check(resPaired.pValue).isLessThan(0.05);

      // Directional alternatives
      final resGreater = wilcoxonSignedRankTest(
        before,
        y: after,
        alternative: AlternativeHypothesis.greater,
      );
      check(resGreater.isSignificant).isTrue();
      check(resGreater.pValue).isLessThan(0.05);

      final resLess = wilcoxonSignedRankTest(
        before,
        y: after,
        alternative: AlternativeHypothesis.less,
      );
      check(resLess.pValue).isGreaterThan(0.95);

      // Errors
      check(() => wilcoxonSignedRankTest([1.0], y: [1.0, 2.0]))
          .throws<ArgumentError>();
      check(() => wilcoxonSignedRankTest([1.0, 2.0], y: [1.0, 2.0]))
          .throws<ArgumentError>();
    });

    test('Wilcoxon signed-rank test with NaN returns NaN', () {
      final res = wilcoxonSignedRankTest([1.0, double.nan, 3.0]);
      check(res.statistic.isNaN).isTrue();
      check(res.pValue.isNaN).isTrue();

      final resPaired = wilcoxonSignedRankTest(
        [1.0, 2.0],
        y: [double.nan, 5.0],
      );
      check(resPaired.statistic.isNaN).isTrue();
      check(resPaired.pValue.isNaN).isTrue();
    });
  });
}
