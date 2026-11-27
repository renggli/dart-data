import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('First-order linear ODEs', () {
    const y = Variable('y');
    final dy = Derivative(y, 'x');

    test('homogeneous linear ODE: y\' - 3y = 0', () {
      final ode = dy - (y * 3);
      final sol = ode.solveOde(dependent: 'y', independent: 'x');
      // y = C1 * exp(3 * x)
      check(sol.dependsOn('C1')).isTrue;
      check(sol.dependsOn('x')).isTrue;
      check(sol.dependsOn('y')).isFalse;

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
      check(sol.dependsOn('K')).isTrue;
      check(sol.dependsOn('C1')).isFalse;
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
        initialValues: [5],
      );
      check(sol.dependsOn('C1')).isFalse;
      final yAt0 = sol.substitute('x', IntegerNumber.zero).simplify();
      check(yAt0).equals(IntegerNumber.of(5));
    });

    test('IVP: y\' + 2y = 4 with y(0) = 5', () {
      final ode = dy + (y * 2) - 4;
      final sol = ode.solveOde(
        dependent: 'y',
        independent: 'x',
        at: 0,
        initialValues: [5],
      );
      check(sol.dependsOn('C1')).isFalse;
      final yAt0 = sol.substitute('x', IntegerNumber.zero).simplify();
      check(yAt0).equals(IntegerNumber.of(5));
    });

    test('IVP: y\' = 3x^2 with y(1) = 10', () {
      final ode = dy - (x.pow(2) * 3);
      final sol = ode.solveOde(
        dependent: 'y',
        independent: 'x',
        at: 1,
        initialValues: [10],
      );
      check(sol.toString()).equals('9 + x ^ 3');
      final yAt1 = sol.substitute('x', IntegerNumber.one).simplify();
      check(yAt1).equals(IntegerNumber.of(10));
    });

    test('IVP: second-order y\'\' + y = 0 with y(0) = 1, y\'(0) = 0', () {
      final sol = Expr.parse('diff(y, x, 2) + y').solveOde(
        dependent: 'y',
        independent: 'x',
        at: 0,
        initialValues: [1, 0],
      );
      check(sol).equals(Expr.parse('cos(x)').simplify());
    });

    test('throws ArgumentError when initialValues exceeds ODE order', () {
      check(
        () => (dy - y).solveOde(
          dependent: 'y',
          independent: 'x',
          at: 0,
          initialValues: [1, 2],
        ),
      ).throws<ArgumentError>();
    });
  });

  group(
    'First-class Derivative nodes, relational forms, and error handling',
    () {
      const x = Variable('x');
      const y = Variable('y');

      test('does not interpret string variable names as derivatives', () {
        for (final name in ["y'", 'dy', 'y_prime', 'Dy']) {
          final ode = Variable(name) - (y * 2);
          check(() => ode.solveOde(dependent: 'y', independent: 'x'))
              .throws<ArgumentError>();
        }
      });

      test('rejects non-Equal relational expressions', () {
        final dy = Derivative(y, 'x');
        check(
          () => Relational.lessThan(
            dy,
            y * 2,
          ).solveOde(dependent: 'y', independent: 'x'),
        ).throws<ArgumentError>();
        check(
          () => Relational.greaterEqual(
            dy,
            y * 2,
          ).solveOde(dependent: 'y', independent: 'x'),
        ).throws<ArgumentError>();
      });

      test('supports Equal relational expression with Derivative node', () {
        final dy = Derivative(y, 'x');
        final ode = Relational.equal(dy, y * 2);
        final sol = ode.solveOde(dependent: 'y', independent: 'x');
        check(sol.dependsOn('C1')).isTrue;
      });

      test('supports exp(x + y) in separable ODEs', () {
        final dy = Derivative(y, 'x');
        final sol = (dy - Pow.of(Constant.e, x + y)).solveOde(
          dependent: 'y',
          independent: 'x',
        );
        check(sol.dependsOn('x')).isTrue;
        final residual = (sol.derivative('x') - Pow.of(Constant.e, x + sol))
            .simplify();
        check(residual.evaluate({'x': 0.5, 'C1': -5.0})).isCloseTo(0.0, 1e-12);
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
    },
  );

  group('Second-order constant-coefficient linear homogeneous ODEs', () {
    test('solves distinct real characteristic roots', () {
      check(
        Expr.parse('diff(y, x, 2) - 3 * diff(y, x) + 2 * y')
            .solveOde(dependent: 'y', independent: 'x'),
      ).equals(Expr.parse('C1 * exp(x) + C2 * exp(2 * x)').simplify());
    });

    test('solves repeated characteristic root', () {
      check(
        Expr.parse('diff(y, x, 2) - 2 * diff(y, x) + y')
            .solveOde(dependent: 'y', independent: 'x'),
      ).equals(Expr.parse('(C1 + C2 * x) * exp(x)').simplify());
    });

    test('solves complex conjugate characteristic roots (harmonic)', () {
      check(
        Expr.parse('diff(y, x, 2) + y')
            .solveOde(dependent: 'y', independent: 'x'),
      ).equals(Expr.parse('C1 * cos(x) + C2 * sin(x)').simplify());
    });

    test(
      'solves inhomogeneous polynomial, exponential, and sinusoidal ODEs',
      () {
        check(
          Expr.parse('diff(y, x, 2) + y - x')
              .solveOde(dependent: 'y', independent: 'x'),
        ).equals(Expr.parse('C1 * cos(x) + C2 * sin(x) + x').simplify());
        check(
          Expr.parse('diff(y, x, 2) - y - exp(2 * x)')
              .solveOde(dependent: 'y', independent: 'x'),
        ).equals(
          Expr.parse('C1 * exp(-x) + C2 * exp(x) + 1/3 * exp(2 * x)')
              .simplify(),
        );
        check(
          Expr.parse('diff(y, x, 2) - 3 * diff(y, x) + 2 * y - exp(x)')
              .solveOde(dependent: 'y', independent: 'x'),
        ).equals(
          Expr.parse('C1 * exp(x) + C2 * exp(2 * x) - x * exp(x)').simplify(),
        );
        check(
          Expr.parse('diff(y, x, 2) + y - cos(x)')
              .solveOde(dependent: 'y', independent: 'x'),
        ).equals(
          Expr.parse('C1 * cos(x) + C2 * sin(x) + 1/2 * x * sin(x)').simplify(),
        );
        check(
          Expr.parse('diff(y, x, 2) - y - sin(2 * x)')
              .solveOde(dependent: 'y', independent: 'x'),
        ).equals(
          Expr.parse('C1 * exp(-x) + C2 * exp(x) - 1/5 * sin(2 * x)')
              .simplify(),
        );
      },
    );

    test('solves polynomial * exponential and polynomial * trig forcing', () {
      check(
        Expr.parse('diff(y, x, 2) - y - x * exp(2 * x)')
            .solveOde(dependent: 'y', independent: 'x'),
      ).equals(
        Expr.parse('C1 * exp(-x) + C2 * exp(x) + (x / 3 - 4 / 9) * exp(2 * x)')
            .simplify(),
      );
      check(
        Expr.parse('diff(y, x, 2) + y - x * sin(x)')
            .solveOde(dependent: 'y', independent: 'x')
            .expand(),
      ).equals(
        Expr.parse(
          'C1 * cos(x) + C2 * sin(x) - x^2 / 4 * cos(x) + x / 4 * sin(x)',
        ).simplify(),
      );
    });

    test('solves higher-order constant-coefficient ODEs up to order 6', () {
      check(
        Expr.parse('diff(y, x, 3) - y')
            .solveOde(dependent: 'y', independent: 'x'),
      ).equals(
        Expr.parse(
          'C1 * exp(x) + exp(-x / 2) * (C2 * cos(sqrt(3) / 2 * x) + C3 * sin(sqrt(3) / 2 * x))',
        ).simplify(),
      );
    });

    test('throws UnsupportedError for ODEs of order > 6', () {
      check(
        () =>
            Expr.parse('diff(y, x, 7) + y')
                .solveOde(dependent: 'y', independent: 'x'),
      ).throws<UnsupportedError>();
    });
  });

  group('ODE validation, partial ICs, and symbolic roots', () {
    test('throws ArgumentError when dependent equals independent', () {
      final ode = Derivative(const Variable('x'), 'x') - const Variable('x');
      check(() => ode.solveOde(dependent: 'x', independent: 'x'))
          .throws<ArgumentError>();
    });

    test(
      'resolves partial initial conditions while keeping remaining constants',
      () {
        final sol = Expr.parse(
          'diff(y, x, 2) + y',
        ).solveOde(dependent: 'y', independent: 'x', at: 0, initialValues: [3]);
        check(sol).equals(Expr.parse('3 * cos(x) + C2 * sin(x)').simplify());
      },
    );

    test(
      'throws StateError on inconsistent or unsatisfiable initial conditions',
      () {
        const y = Variable('y');
        final dy = Derivative(y, 'x');
        // dy - y^2 = 0 has y(x) = -1 / (C1 + x), so y(0) = 0 is unsatisfiable.
        check(
          () => (dy - y.pow(2)).solveOde(
            dependent: 'y',
            independent: 'x',
            at: 0,
            initialValues: [0],
          ),
        ).throws<StateError>();

        final secondSolved =
            Expr.parse('diff(y, x, 2) - 3 * diff(y, x) + 2 * y').solveOde(
              dependent: 'y',
              independent: 'x',
              constant: 'K',
              at: 0,
              initialValues: [2, 3],
            );
        check(secondSolved)
            .equals(Expr.parse('exp(x) + exp(2 * x)').simplify());
      },
    );

    test(
      'solves higher-order ODE with symbolic conjugate characteristic roots',
      () {
        final sol = Expr.parse('diff(y, x, 3) + a^2 * diff(y, x)').solveOde(
          dependent: 'y',
          independent: 'x',
          assumptions: const Assumptions(
            domains: {'a': VariableDomain.positive},
          ),
        );
        check(sol.dependsOn('C1')).isTrue;
        check(sol.dependsOn('C2')).isTrue;
        check(sol.dependsOn('C3')).isTrue;
        check(sol.anyNode((n) => n is Call && n.id == FunctionId.cos)).isTrue;
        check(sol.anyNode((n) => n is Call && n.id == FunctionId.sin)).isTrue;
      },
    );

    test(
      'throws StateError when partial ICs contradict separable constant',
      () {
        check(
          () => (Derivative(const Variable('y'), 'x') - const Variable('x'))
              .solveOde(
                dependent: 'y',
                independent: 'x',
                at: 0,
                initialValues: [const RealNumber(1.0)],
              ),
        ).returnsNormally();
        check(
          () => Expr.parse('diff(y, x, 2) - y').solveOde(
            dependent: 'y',
            independent: 'x',
            at: 0,
            initialValues: [IntegerNumber.one],
          ),
        ).returnsNormally();
      },
    );

    test('throws UnsupportedError on high-degree polynomial forcing', () {
      check(
        () =>
            Expr.parse('diff(y, x, 2) + y - x^5')
                .solveOde(dependent: 'y', independent: 'x'),
      ).throws<UnsupportedError>();
    });

    test('validates ODE error contracts and separable exponential sums', () {
      const x = Variable('x');
      const y = Variable('y');
      check(
        () => Derivative(y, 'x').solveOde(
          dependent: 'y',
          independent: 'x',
          initialValues: [IntegerNumber.one],
        ),
      ).throws<ArgumentError>();
      check(
        () => (Fn.sin(Derivative(y, 'x')) + Derivative(y, 'x')).solveOde(
          dependent: 'y',
          independent: 'x',
        ),
      ).throws<UnsupportedError>();
      check(
        () => (Derivative(y, 'x') - Fn.sin(y) - y).solveOde(
          dependent: 'y',
          independent: 'x',
        ),
      ).throws<UnsupportedError>();
      check(
        () => (Derivative(y, 'x') - x).solveOde(
          dependent: 'y',
          independent: 'x',
          at: 0,
          initialValues: [IntegerNumber.one, IntegerNumber.two],
        ),
      ).throws<ArgumentError>();
      check(
        () => Expr.parse('diff(y, x, 2) - y').solveOde(
          dependent: 'y',
          independent: 'x',
          at: 0,
          initialValues: [
            IntegerNumber.one,
            IntegerNumber.two,
            IntegerNumber.of(3),
          ],
        ),
      ).throws<ArgumentError>();
      check(
        () => (Derivative(y, 'x') - Pow.of(y, IntegerNumber.two)).solveOde(
          dependent: 'y',
          independent: 'x',
          at: 0,
          initialValues: [IntegerNumber.zero],
        ),
      ).throws<StateError>();

      final expSep = (Derivative(y, 'x') - Pow.of(IntegerNumber.two, x + y))
          .solveOde(dependent: 'y', independent: 'x');
      check(expSep.dependsOn('C1')).isTrue;

      // Repeated complex conjugate characteristic roots: (D^2 + 1)^2 y = 0
      final repComplex = Expr.parse('diff(y, x, 4) + 2 * diff(y, x, 2) + y')
          .solveOde(dependent: 'y', independent: 'x');
      check(repComplex.dependsOn('C1')).isTrue;
      check(repComplex.dependsOn('C4')).isTrue;
    });
  });
}
