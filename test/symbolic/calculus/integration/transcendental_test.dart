import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  void verifyIndefinite(
    String source, {
    Map<String, double> env = const {'x': 1.7},
  }) {
    final integrand = Expr.parse(source);
    final antideriv = integrand.integrate('x');
    check(antideriv.anyNode((n) => n is Integral)).isFalse;
    final deriv = antideriv.derivative('x');
    check(deriv.evaluate(env)).isCloseTo(integrand.evaluate(env), 1e-7);
  }

  group('Transcendental tower integration', () {
    test('reduces multiple factors in exponential tower by Hermite', () {
      verifyIndefinite(
        '(-x - 1) * exp(x) / (4 * exp(x)^2 * x^2 + 8 * exp(x) * x + 4)',
        env: const {'x': 0.8},
      );
      verifyIndefinite(
        '(-x + 1) * exp(x) / (exp(x)^2 + 2 * exp(x) * x + x^2)',
        env: const {'x': 0.8},
      );
    });

    test('reduces multiple factors in logarithmic tower by Hermite', () {
      verifyIndefinite(
        '(1296 * ln(x) - 1296) / (ln(x)^2 + 216 * x * ln(x) + 11664 * x^2)',
        env: const {'x': 2.5},
      );
      verifyIndefinite(
        '(ln(x) - 2) / (ln(x)^2 + (2 * x - 2) * ln(x) + x^2 - 2 * x + 1)',
        env: const {'x': 2.5},
      );
    });

    test('integrates logarithmic derivatives and linear tower quotients', () {
      verifyIndefinite(
        '(-x * ln(x) + 3 * x - 1) / (x * ln(x) - 3 * x)',
        env: const {'x': 2.3},
      );
      verifyIndefinite(
        '((-2 * x^2 + x + 1) * ln(5 * x) + 4 * x - 1) / (x * ln(5 * x) - 2)',
        env: const {'x': 2.3},
      );
      verifyIndefinite(
        '(x + 1) * ln(x) / (x * ln(x) - 1)',
        env: const {'x': 2.3},
      );
      verifyIndefinite(
        '((x^5 + 4 * x^4 + 4 * x) * ln(x) + x^4 + 4) / ((x^5 + 4 * x) * ln(x))',
        env: const {'x': 2.1},
      );
    });

    test('solves Risch exponential ODE for rational and nested exponents', () {
      verifyIndefinite(
        '(700 * x^2 + 3050 * x - 275) * exp(x)^2 / (196 * x^2 + 140 * x + 25)',
        env: const {'x': 0.7},
      );
      verifyIndefinite(
        '(-2 * x^2 + 1) * exp(x^2) / x^2',
        env: const {'x': 0.8},
      );
      verifyIndefinite(
        '(x^6 + x^4 - x^2 - 1) * exp(x + 1 / x) / x^4',
        env: const {'x': 1.3},
      );
      verifyIndefinite('(2 * ln(x) + 1) * exp(ln(x)^2)', env: const {'x': 1.7});
    });

    test('integrates self-power expressions via exponential tower', () {
      verifyIndefinite('x^(x^2 + 1) * (1 + 2 * ln(x))', env: const {'x': 1.4});
    });

    test('terminates within budget on high-degree and large-coefficient cases', () {
      final cases = [
        // High exp(x)^16 degree tower (Hebisch #3076-style).
        '(-314928*exp(x)^8 - 12*x - 8472) / '
            '(387420489*exp(x)^16 + 10331213040*exp(x)^15 + 9*x^4 + 2235957977344)',
        // High variable exponent x^34 in Risch ODE (Hebisch #3169-style).
        '(-54*x^34 + 408*x^33 + 51539607552) * '
            'exp((-x^34 + 8589934592) / (x^16 - 64*x^15 + 4294967296)) / '
            '(x^17 - 68*x^16 - 17179869184)',
        // Degree-4 rational in exp(x) with symbolic constant exp(8) (Hebisch #5951).
        '(-32*exp(x)^2 + (32*x + 32)*exp(x) - 32*x + 8) / '
            '(4*exp(x)^4 - 16*x*exp(x)^3 + (4*exp(8) + 24*x^2 - 4*x + 40)*exp(x)^2 + '
            '(-8*x*exp(8) - 16*x^3 + 8*x^2 - 80*x)*exp(x) + exp(8)^2 + '
            '(4*x^2 - 2*x + 20)*exp(8) + 4*x^4 - 4*x^3 + 41*x^2 - 20*x + 100)',
        // High-degree rational in exp(x) & x^10 causing GCD blowup (Hebisch #7928).
        '((2*exp(x)^2*x^2 + 1024*x^6*exp(x) + 131072*x^10)*exp(ln(2) + 2*x) - exp(x)^2 + (-512*x^4 - 4*x^2)*exp(x) - 65536*x^8 - 4096*x^5) / '
            '((exp(x)^2*x^2 + 512*x^6*exp(x) + 65536*x^10)*exp(ln(2) + 2*x) + (4*x^2 + x)*exp(x)^2 + (2048*x^6 + 512*x^5 + 4*x^2)*exp(x) + 262144*x^10 + 65536*x^9 + 1024*x^6)',
      ];
      for (final source in cases) {
        final expr = Expr.parse(source);
        final sw = Stopwatch()..start();
        final res = expr.integrate('x');
        sw.stop();
        check(sw.elapsedMilliseconds)
            .isLessThan(identical(0, 0.0) ? 1500 : 500);
        check(res).isA<Expr>();
      }
    });
  });
}
