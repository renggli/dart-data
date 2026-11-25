import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/stats.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('fisherExactTest', () {
    test('evaluates two-sided, greater, and less hypotheses on 2x2 tables', () {
      final table = Matrix<int>.fromRows(const [
        [3, 1],
        [1, 3],
      ], type: DataType.integer);

      final twoSided = fisherExactTest(table);
      check(twoSided.testName).equals("Fisher's Exact Test");
      check(twoSided.statistic).isCloseTo(9.0, 1e-12);
      check(twoSided.pValue).isCloseTo(34.0 / 70.0, 1e-12);

      final greater = fisherExactTest(
        table,
        alternative: AlternativeHypothesis.greater,
      );
      check(greater.pValue).isCloseTo(17.0 / 70.0, 1e-12);

      final less = fisherExactTest(
        table,
        alternative: AlternativeHypothesis.less,
      );
      check(less.pValue).isCloseTo(69.0 / 70.0, 1e-12);
    });

    test('identifies strong associations cleanly', () {
      final table = Matrix<int>.fromRows(const [
        [15, 2],
        [1, 16],
      ], type: DataType.integer);
      final res = fisherExactTest(table);
      check(res.statistic).isGreaterThan(50.0);
      check(res.pValue).isLessThan(0.001);
      check(res.isSignificant).isTrue;
    });

    test('handles zero cells and empty zero-total tables', () {
      final diagonal = Matrix<int>.fromRows(const [
        [5, 0],
        [0, 5],
      ], type: DataType.integer);
      final resDiag = fisherExactTest(diagonal);
      check(resDiag.statistic).equals(double.infinity);
      check(resDiag.pValue).isLessThan(0.05);

      final zeroBoth = Matrix<int>.fromRows(const [
        [0, 0],
        [1, 1],
      ], type: DataType.integer);
      check(fisherExactTest(zeroBoth).statistic.isNaN).isTrue;

      final empty = Matrix<int>.fromRows(const [
        [0, 0],
        [0, 0],
      ], type: DataType.integer);
      final emptyRes = fisherExactTest(empty);
      check(emptyRes.statistic.isNaN).isTrue;
      check(emptyRes.pValue.isNaN).isTrue;
    });

    test('validates 2x2 dimensions, non-negative counts, and alpha', () {
      check(
        () => fisherExactTest(
          Matrix<int>.fromRows(const [
            [1, 2],
          ], type: DataType.integer),
        ),
      ).throws<ArgumentError>();
      check(
        () => fisherExactTest(
          Matrix<int>.fromRows(const [
            [1, 2, 3],
            [4, 5, 6],
          ], type: DataType.integer),
        ),
      ).throws<ArgumentError>();
      check(
        () => fisherExactTest(
          Matrix<int>.fromRows(const [
            [-1, 2],
            [3, 4],
          ], type: DataType.integer),
        ),
      ).throws<ArgumentError>();
      check(
        () => fisherExactTest(
          Matrix<int>.fromRows(const [
            [3, 1],
            [1, 3],
          ], type: DataType.integer),
          alpha: 0.0,
        ),
      ).throws<ArgumentError>();
    });
  });
}
