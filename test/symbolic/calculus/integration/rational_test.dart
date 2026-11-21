import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  void verifyAntiderivative(
    Expr f, {
    List<double> points = const [0.4, 0.7, 1.3],
  }) {
    final antideriv = f.integrate('x');
    check(antideriv).isNotA<Integral>();
    final diff = antideriv.derivative('x');
    for (final pt in points) {
      check(diff.evaluate({'x': pt})).isCloseTo(f.evaluate({'x': pt}), 1e-8);
    }
  }

  group('Repeated quadratic and cyclotomic rational integration', () {
    test('integrates repeated irreducible quadratic denominators', () {
      verifyAntiderivative(
        Expr.parse('1 / (x^2 + 1)^2'),
        points: const [0.2, 0.7, 1.3],
      );
      verifyAntiderivative(
        Expr.parse('x^2 / (x^2 + 1)^2'),
        points: const [0.2, 0.7, 1.3],
      );
      verifyAntiderivative(
        Expr.parse('1 / (x^2 + 2 * x + 5)^2'),
        points: const [0.2, 0.7, 1.3],
      );
    });

    test(
      'integrates cyclotomic cubic/quartic denominators and guards high degree',
      () {
        verifyAntiderivative(
          Expr.parse('x / (x^3 + 1)'),
          points: const [0.2, 0.7, 1.3],
        );
        verifyAntiderivative(
          Expr.parse('1 / (x^4 + 1)'),
          points: const [0.2, 0.7, 1.3],
        );

        verifyAntiderivative(
          Expr.parse('1 / (x^4 + 2 * x^2 + 1)'),
          points: const [0.2, 0.7, 1.3],
        );
        verifyAntiderivative(
          Expr.parse('1 / (x + 1 / x)^2'),
          points: const [0.4, 0.7, 1.3],
        );
        verifyAntiderivative(
          Expr.parse('x^9 / (x^20 - 48 * x^10 + 575)'),
          points: const [0.4, 0.7, 0.9],
        );
        verifyAntiderivative(
          Expr.parse('(2 * x^2022 + 1) / (x^2023 + x)'),
          points: const [1.0, 1.01, 1.02],
        );

        final highDeg = Expr.parse('1 / (x^2023 + x + 1)');
        check(highDeg.integrate('x').toString()).contains('integrate(');
      },
    );

    test(
      'handles irrational discriminants and zero-discriminant biquadratics',
      () {
        verifyAntiderivative(
          Expr.parse('1 / (x^4 + 3 * x^2 - 1)'),
          points: const [0.3, 0.8, 1.4],
        );

        final repQuad = Expr.parse('sqrt(c + d * x) / (a + b * x)^2')
            .integrate('x');
        check(repQuad).isNotA<Integral>();
        check(repQuad.anyNode((n) => n == Constant.undefined)).isFalse;

        final symQuad = Expr.parse('1 / (x^2 + a)').integrate('x');
        check(symQuad).isNotA<Integral>();
        check(symQuad.anyNode((n) => n is Abs)).isFalse;
      },
    );

    test('integrates high-degree Laurent polynomials P(x) / (c * x^n)', () {
      final res1 = Expr.parse('(a + b * x^2)^3 / x^13').integrate('x');
      check(res1).isNotA<Integral>();
      final diff1 =
          (res1.derivative('x') - Expr.parse('(a + b * x^2)^3 / x^13'))
              .expand()
              .simplify();
      check(diff1).equals(IntegerNumber.zero);

      final res2 = Expr.parse('(A + B * x^3) * (a + b * x^3)^5 / x^19')
          .integrate('x');
      check(res2).isNotA<Integral>();
      final diff2 =
          (res2.derivative('x') -
                  Expr.parse('(A + B * x^3) * (a + b * x^3)^5 / x^19'))
              .expand()
              .simplify(assumptions: Assumptions.positive);
      check(diff2).equals(IntegerNumber.zero);
    });

    test('integrates high-degree linear-power denominators quickly', () {
      final res = Expr.parse('(c + d * x)^7 / (a + b * x)^8').integrate('x');
      check(res).isNotA<Integral>();
      verifyAntiderivative(
        Expr.parse('(2 + 3 * x)^7 / (1 + 2 * x)^8'),
        points: const [0.3, 0.7, 1.2],
      );
    });

    test('integrates x^n / ln(c * x)^k for scaled logs and negative n', () {
      for (final expr in const [
        'x^3 / ln(c * x)',
        '1 / (x^2 * ln(c * x))',
        'x^3 / ln(c * x)^2',
        '1 / (x * ln(c * x)^2)',
      ]) {
        check(Expr.parse(expr).integrate('x')).isNotA<Integral>();
      }

      verifyAntiderivative(
        Expr.parse('x^3 / ln(2 * x)'),
        points: const [1.2, 2.0, 3.0],
      );
      verifyAntiderivative(
        Expr.parse('1 / (x^2 * ln(2 * x))'),
        points: const [1.2, 2.0, 3.0],
      );
      verifyAntiderivative(
        Expr.parse('x^3 / ln(2 * x)^2'),
        points: const [1.2, 2.0, 3.0],
      );
    });

    test('integrates shifted trig/hyperbolic over linear powers and sinh/cosh powers', () {
      for (final expr in const [
        '(c + d * x)^4 * sinh(a + b * x)^2',
        'sinh(a + b * x) / (c + d * x)^2',
        'cosh(a + b * x) / (c + d * x)',
        'sinh(a + b * x)^2 / (c + d * x)^2',
        'sin(a + b * x) / (c + d * x)^2',
      ]) {
        check(Expr.parse(expr).integrate('x')).isNotA<Integral>();
      }

      verifyAntiderivative(
        Expr.parse('(1 + 2 * x)^4 * sinh(1 + 3 * x)^2'),
        points: const [0.2, 0.5, 0.8],
      );
      verifyAntiderivative(
        Expr.parse('sinh(1 + 2 * x) / (1 + 3 * x)^2'),
        points: const [0.2, 0.5, 0.8],
      );
      verifyAntiderivative(
        Expr.parse('sin(1 + 2 * x) / (1 + 3 * x)^2'),
        points: const [0.2, 0.5, 0.8],
      );
    });

    test(
      'integrates shifted exponentials over linear powers and polynomials',
      () {
        check(Expr.parse('exp(a + b * x) / (c + d * x)^2').integrate('x'))
            .isNotA<Integral>();
        verifyAntiderivative(
          Expr.parse('exp(2 * x) / (x^2 - 3 * x + 2)'),
          points: const [2.5, 3.0, 4.0],
        );
        verifyAntiderivative(
          Expr.parse('exp(1 + 2 * x) / (1 + 3 * x)^2'),
          points: const [0.2, 0.5, 0.8],
        );
      },
    );

    test('integrates products of two and three linear powers via fast partial fractions', () {
      check(Expr.parse('1 / (x^3 * (a + b * x)^10)').integrate('x'))
          .isNotA<Integral>();
      check(Expr.parse('1 / ((a + b * x)^3 * (c + d * x)^3)').integrate('x'))
          .isNotA<Integral>();
      check(Expr.parse('1 / (x^2 * (a + b * x) * (c + d * x))').integrate('x'))
          .isNotA<Integral>();

      verifyAntiderivative(
        Expr.parse('1 / ((1 + 2 * x)^3 * (3 + 5 * x)^2)'),
        points: const [0.2, 0.6, 1.1],
      );
      verifyAntiderivative(
        Expr.parse('(x^2 + 1) / ((1 + 2 * x)^3 * (3 + 5 * x)^2)'),
        points: const [0.2, 0.6, 1.1],
      );
      verifyAntiderivative(
        Expr.parse('1 / (x^2 * (1 + 2 * x) * (3 + 5 * x))'),
        points: const [0.2, 0.6, 1.1],
      );
    });
  });
}
