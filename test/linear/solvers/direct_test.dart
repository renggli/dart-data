import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/type.dart';
import 'package:more/number.dart' show Fraction;
import 'package:test/scaffolding.dart';

void main() {
  group('Direct linear solvers', () {
    test('solveDirect square system', () {
      final a = Matrix<double>.fromRows([
        [2.0, 1.0],
        [1.0, 3.0],
      ]);
      final b = Matrix<double>.fromRows([
        [4.0],
        [7.0],
      ]);
      final x = solveDirect(a, b);
      check(x.rowCount).equals(2);
      check(x.colCount).equals(1);
      check(x.get(0, 0)).isCloseTo(1.0, 1e-10);
      check(x.get(1, 0)).isCloseTo(2.0, 1e-10);
    });

    test('solveRref with Fraction exact arithmetic', () {
      final a = Matrix<Fraction>.fromRows([
        [Fraction(1), Fraction(2)],
        [Fraction(3), Fraction(4)],
      ]);
      final b = Matrix<Fraction>.fromRows([
        [Fraction(5)],
        [Fraction(11)],
      ]);
      final x = solveRref(a, b);
      check(x.get(0, 0)).equals(Fraction(1));
      check(x.get(1, 0)).equals(Fraction(2));
    });

    test('solveUnderdeterminedMatrix finds minimum norm solution', () {
      final a = Matrix<double>.fromRows([
        [1.0, 1.0, 1.0],
      ]);
      final b = Matrix<double>.fromRows([
        [3.0],
      ]);
      final x = solveUnderdeterminedMatrix(a, b);
      check(x.rowCount).equals(3);
      check(x.colCount).equals(1);
      check(x.get(0, 0)).isCloseTo(1.0, 1e-10);
      check(x.get(1, 0)).isCloseTo(1.0, 1e-10);
      check(x.get(2, 0)).isCloseTo(1.0, 1e-10);
    });

    test('solveDirect handles 0-col, 0-row, and m x 0 consistent/inconsistent systems', () {
      final empty = Matrix<double>.filled(0, 0, 0.0);
      check(solveDirect(empty, empty).rowCount).equals(0);

      final zeroCols = Matrix<double>.filled(2, 0, 0.0);
      final zeroRhs = Matrix<double>.filled(2, 2, 0.0);
      final sol = solveDirect(zeroCols, zeroRhs);
      check(sol.rowCount).equals(0);
      check(sol.colCount).equals(2);

      final nonZeroRhs = Matrix<double>.fromRows([
        [0.0],
        [1.0],
      ]);
      check(() => solveDirect(zeroCols, nonZeroRhs)).throws<StateError>();

      final emptyColRhs = Matrix<double>.filled(2, 0, 0.0);
      final sq2 = Matrix<double>.identity(2);
      final emptyColSol = solveDirect(sq2, emptyColRhs);
      check(emptyColSol.rowCount).equals(2);
      check(emptyColSol.colCount).equals(0);
    });
  });
}
