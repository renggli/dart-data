import 'package:checks/checks.dart';
import 'package:data/numeric.dart';
import 'package:test/test.dart';

void main() {
  group('OdeMethod', () {
    test('values include rk4, dormandPrince45, and bdf2', () {
      check(
        OdeMethod.values,
      ).deepEquals([OdeMethod.rk4, OdeMethod.dormandPrince45, OdeMethod.bdf2]);
    });
  });
}
