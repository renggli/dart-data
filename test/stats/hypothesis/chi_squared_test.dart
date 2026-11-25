import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/stats.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('chiSquaredTest', () {
    test('evaluates fair and biased observed counts against uniform and explicit expectations', () {
      final fairRolls = [19, 21, 20, 18, 22, 20];
      final resFair = chiSquaredTest(fairRolls);
      check(resFair.isSignificant).isFalse;
      check(resFair.pValue).isGreaterThan(0.9);
      check(resFair.degreesOfFreedom).equals(5.0);

      // Expected counts with different sum are scaled automatically.
      final scaledExp = chiSquaredTest(
        fairRolls,
        expected: const [1, 1, 1, 1, 1, 1],
        ddof: 1,
      );
      check(scaledExp.degreesOfFreedom).equals(4.0);
      check(scaledExp.statistic).isCloseTo(resFair.statistic, 1e-12);

      final biasedRolls = [5, 5, 10, 10, 30, 60];
      final resBiased = chiSquaredTest(biasedRolls);
      check(resBiased.isSignificant).isTrue;
      check(resBiased.pValue).isLessThan(1e-5);
    });

    test(
      'validates categories, non-negative finite counts, ddof, and alpha',
      () {
        check(() => chiSquaredTest(const [5])).throws<ArgumentError>();
        check(() => chiSquaredTest(const [5, -1])).throws<ArgumentError>();
        check(() => chiSquaredTest(const [5, double.nan]))
            .throws<ArgumentError>();
        check(() => chiSquaredTest(const [0, 0])).throws<ArgumentError>();
        check(() => chiSquaredTest(const [0, 0], expected: const [5, 5]))
            .throws<ArgumentError>();
        check(() => chiSquaredTest(const [5, 5], expected: const [1, 2, 3]))
            .throws<ArgumentError>();
        check(() => chiSquaredTest(const [5, 5], expected: const [0, 5]))
            .throws<ArgumentError>();
        check(() => chiSquaredTest(const [5, 5], ddof: -1))
            .throws<ArgumentError>();
        check(() => chiSquaredTest(const [5, 5], ddof: 2))
            .throws<ArgumentError>();
        check(() => chiSquaredTest(const [5, 5], alpha: 0.0))
            .throws<ArgumentError>();
      },
    );
  });

  group('chiSquaredContingency', () {
    test('tests independence and optional Yates continuity correction on 2x2 tables', () {
      final table = Matrix<int>.fromRows(const [
        [20, 30],
        [40, 10],
      ], type: DataType.int32);

      final res = chiSquaredContingency(table);
      check(res.isSignificant).isTrue;
      check(res.degreesOfFreedom).equals(1.0);
      check(res.pValue).isLessThan(0.001);

      final resYates = chiSquaredContingency(table, continuityCorrection: true);
      check(resYates.statistic).isLessThan(res.statistic);
      check(resYates.pValue).isGreaterThan(res.pValue);
      check(resYates.isSignificant).isTrue;
    });

    test('rejects invalid table dimensions, negative entries, zero marginals, and invalid alpha', () {
      final oneRow = Matrix<int>.fromRows(const [
        [10, 20],
      ], type: DataType.int32);
      check(() => chiSquaredContingency(oneRow)).throws<ArgumentError>();

      final negEntry = Matrix<int>.fromRows(const [
        [10, -5],
        [20, 15],
      ], type: DataType.int32);
      check(() => chiSquaredContingency(negEntry)).throws<ArgumentError>();

      final allZero = Matrix<int>.fromRows(const [
        [0, 0],
        [0, 0],
      ], type: DataType.int32);
      check(() => chiSquaredContingency(allZero)).throws<ArgumentError>();

      final zeroRow = Matrix<int>.fromRows(const [
        [0, 0],
        [20, 15],
      ], type: DataType.int32);
      check(() => chiSquaredContingency(zeroRow)).throws<ArgumentError>();

      final zeroCol = Matrix<int>.fromRows(const [
        [0, 20],
        [0, 15],
      ], type: DataType.int32);
      check(() => chiSquaredContingency(zeroCol)).throws<ArgumentError>();

      final valid = Matrix<int>.fromRows(const [
        [10, 20],
        [20, 10],
      ], type: DataType.int32);
      check(() => chiSquaredContingency(valid, alpha: 1.0))
          .throws<ArgumentError>();
    });
  });
}
