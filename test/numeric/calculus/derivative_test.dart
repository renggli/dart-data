import 'package:checks/checks.dart';
import 'package:data/numeric.dart';
import 'package:test/test.dart';

void main() {
  group('derivative', () {
    test('derivative and higher order derivative of scalar function', () {
      // f(x) = x^3 => f'(2) = 12, f''(2) = 12, f'''(2) = 6
      double function(double x) => x * x * x;
      check(derivative(function, 2.0)).isCloseTo(12.0, 1e-4);
      check(derivative(function, 2.0, order: 2)).isCloseTo(12.0, 1e-3);
      check(derivative(function, 2.0, accuracy: 4)).isCloseTo(12.0, 1e-6);
      check(derivative(function, 2.0, order: 2, accuracy: 4))
          .isCloseTo(12.0, 1e-4);
      check(derivative(function, 2.0, order: 3)).isCloseTo(6.0, 1e-3);

      // f(x) = x^6 => f^(4)(1) = 360, f^(5)(1) = 720, f^(6)(1) = 720
      double poly6(double x) => x * x * x * x * x * x;
      check(derivative(poly6, 1.0, order: 4)).isCloseTo(360.0, 1.0);
      check(derivative(poly6, 1.0, order: 5)).isCloseTo(720.0, 5.0);
      check(derivative(poly6, 1.0, order: 6)).isCloseTo(720.0, 15.0);

      // Invalid orders and accuracies
      check(() => derivative(function, 2.0, order: 0)).throws<ArgumentError>();
      check(() => derivative(function, 2.0, order: 7)).throws<ArgumentError>();
      check(() => derivative(function, 2.0, accuracy: 5))
          .throws<ArgumentError>();
      check(() => derivative(function, 2.0, step: 0.0)).throws<ArgumentError>();
      check(() => derivative(function, 2.0, step: -1.0))
          .throws<ArgumentError>();
      check(() => derivative(function, 2.0, step: double.nan))
          .throws<ArgumentError>();
    });

    test(
      'scales finite-difference step size for large coordinate |x| >= 10^8',
      () {
        double poly(double x) => x * x;
        // d/dx(x^2) at x = 1e9 is 2e9
        final d = derivative(poly, 1e9);
        check((d - 2e9).abs() / 2e9).isLessThan(1e-4);

        // Explicit step is respected without rescaling by |x|
        var evaluatedH = 0.0;
        derivative(
          (x) {
            evaluatedH = (x - 100.0).abs();
            return x * x;
          },
          100.0,
          step: 0.05,
        );
        check(evaluatedH).isCloseTo(0.05, 1e-12);

        // Function with removable or infinite singularity at x is not evaluated at center node for order 1
        double fSingularAt0(double x) => x == 0.0 ? double.infinity : x * x;
        check(derivative(fSingularAt0, 0.0, order: 1)).isCloseTo(0.0, 1e-5);
      },
    );
  });
}
