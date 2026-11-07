import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('fisher-exact', () {
    test('Lady tasting tea 2x2 contingency table', () {
      // Classic example: 4 milk first, 4 tea first
      // Table: [[3, 1], [1, 3]]
      final table = [
        [3, 1],
        [1, 3],
      ];

      final twoSided = fisherExactTest(table);
      check(twoSided.testName).equals("Fisher's Exact Test");
      check(twoSided.statistic).isCloseTo(9.0, 1e-6);
      check(twoSided.pValue).isCloseTo(34.0 / 70.0, 1e-4);

      final matTable = Matrix<int>.fromRows([
        [3, 1],
        [1, 3],
      ]);
      final matRes = fisherExactTest(matTable);
      check(matRes.statistic).isCloseTo(9.0, 1e-6);
      check(matRes.pValue).isCloseTo(34.0 / 70.0, 1e-4);

      final greater = fisherExactTest(
        table,
        alternative: AlternativeHypothesis.greater,
      );
      check(greater.pValue).isCloseTo(17.0 / 70.0, 1e-4);
    });

    test('strong association produces significant p-value', () {
      final table = [
        [15, 2],
        [1, 16],
      ];
      final res = fisherExactTest(table);
      check(res.statistic).isGreaterThan(50.0);
      check(res.pValue).isLessThan(0.001);
      check(res.isSignificant).isTrue();
    });

    test('table with zero cells', () {
      final table = [
        [5, 0],
        [0, 5],
      ];
      final res = fisherExactTest(table);
      check(res.statistic).equals(double.infinity);
      check(res.pValue).isLessThan(0.05);
    });

    test('edge cases and argument validation', () {
      check(
        () => fisherExactTest([
          [1, 2],
        ]),
      ).throws<ArgumentError>();
      check(
        () => fisherExactTest([
          [1, 2, 3],
          [4, 5, 6],
        ]),
      ).throws<ArgumentError>();
      check(
        () => fisherExactTest([
          [-1, 2],
          [3, 4],
        ]),
      ).throws<ArgumentError>();
      check(
        () => fisherExactTest(
          Matrix<int>.fromRows([
            [1, 2, 3],
            [4, 5, 6],
          ]),
        ),
      ).throws<ArgumentError>();
      check(() => fisherExactTest('invalid')).throws<ArgumentError>();

      final emptyRes = fisherExactTest([
        [0, 0],
        [0, 0],
      ]);
      check(emptyRes.statistic.isNaN).isTrue();
      check(emptyRes.pValue.isNaN).isTrue();
    });
  });
}
