import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Gradient and Hessian operators', () {
    test('computes gradient vector and symmetric Hessian matrix', () {
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
    });
  });

  group('Jacobian matrix operator', () {
    test('computes Jacobian matrix for vector-valued systems', () {
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
    });
  });

  group('Laplacian operator', () {
    test('computes Laplacian of 2D and 3D scalar fields', () {
      final f2d = Expr.parse('x^3 + y^3');
      final lap2d = f2d.laplacian(['x', 'y']);
      check(lap2d.toString()).equals('6 * x + 6 * y');

      // Top-level function
      final f3d = Expr.parse('x^2 * y + y^2 * z');
      final lap3d = laplacian(f3d, ['x', 'y', 'z']);
      check(lap3d.toString()).equals('2 * y + 2 * z');

      // Harmonic function has Laplacian 0
      final harmonic = Expr.parse('x^2 - y^2');
      check(harmonic.laplacian(['x', 'y'])).equals(IntegerNumber.zero);

      // Empty variables
      check(f2d.laplacian([])).equals(IntegerNumber.zero);
    });
  });

  group('Divergence operator', () {
    test('computes divergence of 2D and 3D vector fields', () {
      final div2d = [
        Expr.parse('x^2 * y'),
        Expr.parse('x * y^2'),
      ].divergence(['x', 'y']);
      check(div2d.toString()).equals('4 * x * y');

      // Top-level function
      final div3d = divergence(
        [Expr.parse('x * y'), Expr.parse('y * z'), Expr.parse('z * x')],
        ['x', 'y', 'z'],
      );
      check(div3d.toString()).equals('x + y + z');

      // Solenoidal field has divergence 0
      final solenoidal = [
        Expr.parse('-y'),
        Expr.parse('x'),
        IntegerNumber.zero,
      ];
      check(solenoidal.divergence(['x', 'y', 'z'])).equals(IntegerNumber.zero);

      // Dimension mismatch throws ArgumentError
      check(() => [Expr.parse('x')].divergence(['x', 'y']))
          .throws<ArgumentError>();
    });
  });

  group('Curl operator', () {
    test('computes curl of 3D vector field', () {
      final c = [
        Expr.parse('-y'),
        Expr.parse('x'),
        IntegerNumber.zero,
      ].curl(['x', 'y', 'z']);
      check(c.length).equals(3);
      check(c[0]).equals(IntegerNumber.zero);
      check(c[1]).equals(IntegerNumber.zero);
      check(c[2]).equals(IntegerNumber.of(2));

      // Irrotational (gradient) field has curl 0
      final gradField = [
        Expr.parse('2 * x'),
        Expr.parse('2 * y'),
        Expr.parse('2 * z'),
      ];
      final curlGrad = curl(gradField, ['x', 'y', 'z']);
      check(curlGrad[0]).equals(IntegerNumber.zero);
      check(curlGrad[1]).equals(IntegerNumber.zero);
      check(curlGrad[2]).equals(IntegerNumber.zero);

      // Non-3D throws ArgumentError
      check(() => [Expr.parse('x'), Expr.parse('y')].curl(['x', 'y']))
          .throws<ArgumentError>();
      check(
        () => [
          Expr.parse('x'),
          Expr.parse('y'),
          Expr.parse('z'),
        ].curl(['x', 'y']),
      ).throws<ArgumentError>();
    });
  });
}
