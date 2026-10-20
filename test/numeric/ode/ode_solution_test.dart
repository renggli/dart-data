import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/numeric.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('OdeSolution', () {
    test('properties', () {
      final y0 = Vector<double>.fromList([1.0, 2.0], type: DataType.float64);
      final y1 = Vector<double>.fromList([3.0, 4.0], type: DataType.float64);
      final sol = OdeSolution(t: [0.0, 1.0], y: [y0, y1]);

      check(sol.stepCount).equals(2);
      check(sol.t).deepEquals([0.0, 1.0]);
      check(sol.y).deepEquals([y0, y1]);
      check(sol.last).equals(y1);
    });
  });
}
