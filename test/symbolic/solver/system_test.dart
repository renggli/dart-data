import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Symbolic linear system solver', () {
    test('solves determined 2x2 and 3x3 symbolic linear systems', () {
      final sol2 = [
        Expr.parse('2*x + y - 5'),
        Expr.parse('x - y - 1'),
      ].solveSystem(['x', 'y']);
      check(sol2).isNotNull();
      check(sol2!['x']).equals(IntegerNumber.two);
      check(sol2['y']).equals(IntegerNumber.one);

      final sol3 = [
        Expr.parse('x + y + z - 6'),
        Expr.parse('2*x - y + z - 3'),
        Expr.parse('x + 2*y - z - 2'),
      ].solveSystem(['x', 'y', 'z']);
      check(sol3).isNotNull();
      check(sol3!['x']).equals(IntegerNumber.one);
      check(sol3['y']).equals(IntegerNumber.two);
      check(sol3['z']).equals(IntegerNumber.of(3));
    });

    test('returns null for singular or inconsistent linear systems', () {
      final singular = [
        Expr.parse('x + y - 1'),
        Expr.parse('2*x + 2*y - 3'),
      ].solveSystem(['x', 'y']);
      check(singular).isNull();
    });
  });
}
