import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('First-order linear ODEs', () {
    const y = Variable('y');
    final dy = Derivative(y, 'x');

    test('homogeneous linear ODE: y\' - 3y = 0', () {
      final ode = dy - (y * 3);
      final sol = ode.solveOde(dependent: 'y', independent: 'x');
      // y = C1 * exp(3 * x)
      check(sol.dependsOn('C1')).isTrue();
      check(sol.dependsOn('x')).isTrue();
      check(sol.dependsOn('y')).isFalse();

      // Verify that dy/dx - 3y simplifies to 0
      final deriv = sol.derivative('x').simplify();
      final residual = (deriv - (sol * 3)).simplify();
      check(residual).equals(IntegerNumber.zero);
    });

    test('homogeneous linear ODE: y\' + y = 0', () {
      final ode = dy + y;
      final sol = ode.solveOde(dependent: 'y', independent: 'x');
      final deriv = sol.derivative('x').simplify();
      final residual = (deriv + sol).simplify();
      check(residual).equals(IntegerNumber.zero);
    });

    test('non-homogeneous linear ODE: y\' + 2y = 4', () {
      final ode = dy + (y * 2) - 4;
      final sol = ode.solveOde(dependent: 'y', independent: 'x');
      final deriv = sol.derivative('x').simplify();
      final residual = (deriv + (sol * 2) - 4).simplify();
      check(residual).equals(IntegerNumber.zero);
    });

    test('custom constant name: y\' + 2y = 0 with constant K', () {
      final ode = dy + (y * 2);
      final sol = ode.solveOde(dependent: 'y', independent: 'x', constant: 'K');
      check(sol.dependsOn('K')).isTrue();
      check(sol.dependsOn('C1')).isFalse();
    });
  });

  group('Separable ODEs', () {
    const x = Variable('x');
    const y = Variable('y');
    final dy = Derivative(y, 'x');

    test('direct integration: y\' = 3 * x^2', () {
      final ode = dy - (x.pow(2) * 3);
      final sol = ode.solveOde(dependent: 'y', independent: 'x');
      check(sol.toString()).equals('C1 + x ^ 3');
    });

    test('separable ODE: y\' = x * y', () {
      final ode = dy - (x * y);
      final sol = ode.solveOde(dependent: 'y', independent: 'x');
      final deriv = sol.derivative('x').simplify();
      final residual = (deriv - (x * sol)).simplify();
      check(residual).equals(IntegerNumber.zero);
    });

    test('separable ODE: y\' = y^2', () {
      final ode = dy - y.pow(2);
      final sol = ode.solveOde(dependent: 'y', independent: 'x');
      // y = -1 / (C1 + x)
      final deriv = sol.derivative('x').simplify();
      final residual = (deriv - sol.pow(2)).simplify();
      check(residual).equals(IntegerNumber.zero);
    });
  });

  group('Initial Value Problems (IVPs)', () {
    const x = Variable('x');
    const y = Variable('y');
    final dy = Derivative(y, 'x');

    test('IVP: y\' = 2y with y(0) = 5', () {
      final ode = dy - (y * 2);
      final sol = ode.solveOde(
        dependent: 'y',
        independent: 'x',
        at: 0,
        initialValue: 5,
      );
      check(sol.dependsOn('C1')).isFalse();
      final yAt0 = sol.substitute('x', IntegerNumber.zero).simplify();
      check(yAt0).equals(IntegerNumber.of(5));
    });

    test('IVP: y\' + 2y = 4 with y(0) = 5', () {
      final ode = dy + (y * 2) - 4;
      final sol = ode.solveOde(
        dependent: 'y',
        independent: 'x',
        at: 0,
        initialValue: 5,
      );
      check(sol.dependsOn('C1')).isFalse();
      final yAt0 = sol.substitute('x', IntegerNumber.zero).simplify();
      check(yAt0).equals(IntegerNumber.of(5));
    });

    test('IVP: y\' = 3x^2 with y(1) = 10', () {
      final ode = dy - (x.pow(2) * 3);
      final sol = ode.solveOde(
        dependent: 'y',
        independent: 'x',
        at: 1,
        initialValue: 10,
      );
      check(sol.toString()).equals('9 + x ^ 3');
      final yAt1 = sol.substitute('x', IntegerNumber.one).simplify();
      check(yAt1).equals(IntegerNumber.of(10));
    });
  });

  group('Derivative notation variants & error handling', () {
    const x = Variable('x');
    const y = Variable('y');

    test('supports y\' notation', () {
      const yPrime = Variable("y'");
      final ode = yPrime - (y * 2);
      final sol = ode.solveOde(dependent: 'y', independent: 'x');
      check(sol.dependsOn('C1')).isTrue();
    });

    test('supports dy notation', () {
      const dy = Variable('dy');
      final ode = dy - (y * 2);
      final sol = ode.solveOde(dependent: 'y', independent: 'x');
      check(sol.dependsOn('C1')).isTrue();
    });

    test('supports y_prime notation', () {
      const yPrime = Variable('y_prime');
      final ode = yPrime - (y * 2);
      final sol = ode.solveOde(dependent: 'y', independent: 'x');
      check(sol.dependsOn('C1')).isTrue();
    });

    test('supports Equal relational expression', () {
      final dy = Derivative(y, 'x');
      final ode = Equal(dy, y * 2);
      final sol = ode.solveOde(dependent: 'y', independent: 'x');
      check(sol.dependsOn('C1')).isTrue();
    });

    test('equation without derivative throws ArgumentError', () {
      final noDeriv = x + y - 5;
      check(() => noDeriv.solveOde(dependent: 'y', independent: 'x'))
          .throws<ArgumentError>();
    });

    test('unsupported nonlinear ODE throws UnsupportedError', () {
      final dy = Derivative(y, 'x');
      final unsupported = dy.pow(2) + (x * y) - 1;
      check(() => unsupported.solveOde(dependent: 'y', independent: 'x'))
          .throws<UnsupportedError>();
    });
  });
}
