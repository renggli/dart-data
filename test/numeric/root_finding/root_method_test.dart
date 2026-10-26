import 'package:checks/checks.dart';
import 'package:data/numeric.dart';
import 'package:test/test.dart';

void main() {
  group('RootMethod', () {
    test('values include brent, newtonRaphson, and bisection', () {
      check(RootMethod.values).deepEquals([
        RootMethod.brent,
        RootMethod.newtonRaphson,
        RootMethod.bisection,
      ]);
    });
  });
}
