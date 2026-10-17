import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Multivariable calculus operators', () {
    test(
      'gradient, hessian, and jacobian return Vector<Expr> and Matrix<Expr>',
      () {
        final f = Expr.parse('x^2 * y + y^3');
        final grad = f.gradient(['x', 'y']);
        check(grad.length).equals(2);
        check(grad[0].toString()).equals('2 * x * y');
        check(grad[1].toString()).equals('x ^ 2 + 3 * y ^ 2');

        final hess = f.hessian(['x', 'y']);
        check(hess.rowCount).equals(2);
        check(hess.colCount).equals(2);
        check(hess.get(0, 0).toString()).equals('2 * y');
        check(hess.get(0, 1).toString()).equals('2 * x');
        check(hess.get(1, 0).toString()).equals('2 * x');
        check(hess.get(1, 1).toString()).equals('6 * y');

        final jac = [
          Expr.parse('x * y'),
          Expr.parse('x + y'),
        ].jacobian(['x', 'y']);
        check(jac.rowCount).equals(2);
        check(jac.colCount).equals(2);
        check(jac.get(0, 0)).equals(const Variable('y'));
        check(jac.get(0, 1)).equals(const Variable('x'));
        check(jac.get(1, 0)).equals(IntegerNumber.one);
        check(jac.get(1, 1)).equals(IntegerNumber.one);
      },
    );
  });
}
