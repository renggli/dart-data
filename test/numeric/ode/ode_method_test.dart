import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/numeric.dart';
import 'package:test/test.dart';

void main() {
  group('OdeMethod', () {
    test('values include rk4, dormandPrince45, and bdf2', () {
      check(
        OdeMethod.values,
      ).deepEquals([OdeMethod.rk4, OdeMethod.dormandPrince45, OdeMethod.bdf2]);
    });

    test('solveOde validation errors and degenerate t0 == tEnd with tEval', () {
      final y0 = Vector<double>.fromList([1.0]);
      Vector<double> f(double t, Vector<double> y) => y;

      check(() => solveOde(f: f, y0: y0, t0: double.nan, tEnd: 1.0))
          .throws<ArgumentError>();
      check(() => solveOde(f: f, y0: y0, t0: 0.0, tEnd: double.infinity))
          .throws<ArgumentError>();
      check(
        () => solveOde(f: f, y0: y0, t0: 0.0, tEnd: 1.0, relativeTolerance: 0),
      ).throws<ArgumentError>();
      check(
        () => solveOde(f: f, y0: y0, t0: 0.0, tEnd: 1.0, absoluteTolerance: 0),
      ).throws<ArgumentError>();
      check(() => solveOde(f: f, y0: y0, t0: 0.0, tEnd: 1.0, minStep: 0))
          .throws<ArgumentError>();
      check(
        () => solveOde(
          f: f,
          y0: y0,
          t0: 0.0,
          tEnd: 1.0,
          minStep: 0.1,
          maxStep: 0.01,
        ),
      ).throws<ArgumentError>();

      final sol = solveOde(f: f, y0: y0, t0: 1.0, tEnd: 1.0, tEval: [1.0, 1.0]);
      check(sol.t).deepEquals([1.0, 1.0]);
      check(sol.y.length).equals(2);
    });
  });
}
