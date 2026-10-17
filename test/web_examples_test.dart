import 'package:checks/checks.dart';
import 'package:data/numeric.dart';
import 'package:data/symbolic.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/test.dart';

import '../web/distributions/config.dart';
import '../web/expressions/algebra.dart';
import '../web/expressions/presets.dart';

void main() {
  group('Distributions Web Example Config', () {
    test('contains all 24 univariate distributions', () {
      check(distributions.length).equals(24);
      final continuousCount = distributions.where((d) => d.isContinuous).length;
      final discreteCount = distributions.where((d) => !d.isContinuous).length;
      check(continuousCount).equals(16);
      check(discreteCount).equals(8);
    });

    test('all distributions can be instantiated with default parameters', () {
      for (final def in distributions) {
        final defaultParams = def.parameters
            .map((p) => p.defaultValue)
            .toList();
        final dist = def.creator(defaultParams);

        check(dist).isNotNull();
        // Check that probability calculation does not throw
        final testPoint = def.isContinuous ? 0.0 : 0;
        final prob = dist.probability(testPoint);
        check(prob.isNaN).isFalse();

        // Check sampling
        final samples = dist.samples().take(5).toList();
        check(samples.length).equals(5);
      }
    });

    test('all parameter bounds are consistent', () {
      for (final def in distributions) {
        for (final p in def.parameters) {
          check(p.min <= p.max).isTrue();
          check(p.defaultValue >= p.min && p.defaultValue <= p.max).isTrue();
          check(p.step > 0).isTrue();
        }
      }
    });
  });

  group('Expressions Web Example Presets', () {
    test('all presets parse successfully into valid symbolic expressions', () {
      for (final preset in expressionPresets) {
        final expr = Expr.tryParse(preset.formula);
        check(expr).isNotNull();

        final simplified = expr!.simplify();
        check(simplified.toString().isNotEmpty).isTrue();

        final latex = simplified.toLatex();
        check(latex.isNotEmpty).isTrue();
      }
    });

    test('all presets support differentiation or report non-elementary derivatives, and high-speed compilation', () {
      for (final preset in expressionPresets) {
        final expr = Expr.tryParse(preset.formula)!;
        Expr? d1;
        try {
          d1 = expr.derivative('x').simplify();
          final d2 = d1.derivative('x').simplify();
          check(d1.toString().isNotEmpty).isTrue();
          check(d2.toString().isNotEmpty).isTrue();
        } on UnsupportedError {
          // Functions like Gamma and Beta have non-elementary derivatives.
        }

        if (containsImaginary(expr)) {
          final cfn = expr.toComplexFunction1D('x');
          final y0 = cfn(Complex(preset.defaultPointX, 0));
          check(y0.a.isNaN).isFalse();
          check(y0.b.isNaN).isFalse();
          if (d1 != null) {
            final cdf = d1.toComplexFunction1D('x');
            final slope = cdf(Complex(preset.defaultPointX, 0));
            check(slope.a.isNaN).isFalse();
            check(slope.b.isNaN).isFalse();
          }
        } else {
          final fn = expr.toFunction1D('x');
          final y0 = fn(preset.defaultPointX);
          check(y0.isNaN).isFalse();
          if (d1 != null) {
            final df = d1.toFunction1D('x');
            final slope = df(preset.defaultPointX);
            check(slope.isNaN).isFalse();
          }
        }
      }
    });

    test(
      'all presets can compute numerical integrals and Taylor expansions',
      () {
        for (final preset in expressionPresets) {
          final expr = Expr.tryParse(preset.formula)!;
          if (containsImaginary(expr)) {
            final cfn = expr.toComplexFunction1D('x');
            final realArea = integrate(
              (x) => cfn(Complex(x, 0)).a.toDouble(),
              preset.defaultIntA,
              preset.defaultIntB,
              method: IntegrationMethod.gaussKronrod,
            );
            final imagArea = integrate(
              (x) => cfn(Complex(x, 0)).b.toDouble(),
              preset.defaultIntA,
              preset.defaultIntB,
              method: IntegrationMethod.gaussKronrod,
            );
            check(realArea.isNaN).isFalse();
            check(imagArea.isNaN).isFalse();
          } else {
            final fn = expr.toFunction1D('x');

            // Numerical quadrature in default interval
            final area = integrate(
              fn,
              preset.defaultIntA,
              preset.defaultIntB,
              method: IntegrationMethod.gaussKronrod,
            );
            check(area.isNaN).isFalse();
          }

          // Taylor series expansion
          try {
            final taylor = expr
                .series(
                  'x',
                  point: preset.defaultPointX,
                  order: 3,
                  includeOrder: false,
                )
                .simplify();
            check(taylor.toString().isNotEmpty).isTrue();
          } on UnsupportedError {
            // Functions with non-elementary series at the point throw UnsupportedError.
          }
        }
      },
    );

    test('all presets support expansion, factoring, and MathML rendering', () {
      for (final preset in expressionPresets) {
        final expr = Expr.tryParse(preset.formula)!;
        final expanded = expr.expand();
        check(expanded.toString().isNotEmpty).isTrue();

        final factored = expr.factor();
        check(factored.toString().isNotEmpty).isTrue();

        final mathml = expr.toMathMl();
        check(mathml.startsWith('<math>')).isTrue();
        check(mathml.endsWith('</math>')).isTrue();
      }
    });
  });

  group('Web Expressions Algebra Utilities', () {
    group('formatComplex', () {
      test('formats real values without imaginary component', () {
        check(formatComplex(const Complex(5, 0))).equals('5');
        check(formatComplex(const Complex(3.14159, 0), precision: 2))
            .equals('3.14');
        check(formatComplex(const Complex(0, 0))).equals('0');
      });

      test('formats pure imaginary values', () {
        check(formatComplex(const Complex(0, 1))).equals('i');
        check(formatComplex(const Complex(0, -1))).equals('-i');
        check(formatComplex(const Complex(0, 4))).equals('4i');
        check(formatComplex(const Complex(0, -2.5), precision: 1))
            .equals('-2.5i');
      });

      test('formats mixed complex numbers', () {
        check(formatComplex(const Complex(1, 1))).equals('1 + i');
        check(formatComplex(const Complex(1, -1))).equals('1 - i');
        check(formatComplex(const Complex(3, 4))).equals('3 + 4i');
        check(formatComplex(const Complex(3, -4))).equals('3 - 4i');
        check(formatComplex(const Complex(-2, 5))).equals('-2 + 5i');
        check(formatComplex(const Complex(-2, -5))).equals('-2 - 5i');
      });

      test('handles NaN and undefined inputs safely', () {
        check(formatComplex(const Complex(double.nan, 0))).equals('Undefined');
        check(formatComplex(const Complex(0, double.nan))).equals('Undefined');
        check(formatComplex(const Complex(double.nan, double.nan)))
            .equals('Undefined');
      });

      test('handles infinite values', () {
        check(formatComplex(const Complex(double.infinity, 0))).equals('∞');
        check(formatComplex(const Complex(double.negativeInfinity, 0)))
            .equals('-∞');
        check(formatComplex(const Complex(0, double.infinity))).equals('∞i');
      });
    });

    group('integer & expression factoring', () {
      test(
        'factorIntegerExpr decomposes composite numbers into prime powers',
        () {
          check(factorIntegerExpr(0)).equals(IntegerNumber.zero);
          check(factorIntegerExpr(1)).equals(IntegerNumber.one);
          check(factorIntegerExpr(-1)).equals(IntegerNumber.negativeOne);
          check(factorIntegerExpr(7)).equals(IntegerNumber.of(7));

          final factored24 = factorIntegerExpr(24);
          check(factored24.toString()).equals('2 ^ 3 * 3');

          final factoredNeg60 = factorIntegerExpr(-60);
          check(factoredNeg60.toString()).equals('-(2 ^ 2 * 3 * 5)');
        },
      );

      test('factorExpr factors polynomials and integer numbers', () {
        final poly = Expr.parse('x^2 - 4');
        check(factorExpr(poly).toString()).equals('(-2 + x) * (2 + x)');

        final intExpr = Expr.parse('24');
        check(factorExpr(intExpr).toString()).equals('2 ^ 3 * 3');

        final negIntExpr = Expr.parse('-60');
        check(factorExpr(negIntExpr).toString()).equals('-(2 ^ 2 * 3 * 5)');

        final calcExpr = Mul([IntegerNumber.of(12), IntegerNumber.of(2)]);
        check(factorExpr(calcExpr).toString()).equals('2 ^ 3 * 3');
      });
    });

    group('containsImaginary', () {
      test(
        'detects presence of imaginary constant i in various AST locations',
        () {
          check(containsImaginary(ComplexNumber.i)).isTrue();
          check(containsImaginary(Expr.parse('exp(i * x)'))).isTrue();
          check(containsImaginary(Expr.parse('(x + i)^2'))).isTrue();
          check(containsImaginary(Expr.parse('sin(2 * i)'))).isTrue();
          check(containsImaginary(Expr.parse('x^3 - 3*x + 1'))).isFalse();
          check(containsImaginary(Expr.parse('sqrt(x)'))).isFalse();
          check(containsImaginary(Expr.parse('ln(1 + exp(x))'))).isFalse();
        },
      );
    });
  });
}
