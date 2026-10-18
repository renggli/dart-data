import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/test.dart';

import '../web/distributions/config.dart';
import '../web/expressions/algebra.dart';
import '../web/expressions/presets.dart';

Expr _parsePresetBound(String raw) {
  final trimmed = raw.trim();
  if (trimmed == '-infinity' || trimmed == '-∞') return -Constant.infinity;
  if (trimmed == 'infinity' || trimmed == '+infinity' || trimmed == '∞') {
    return Constant.infinity;
  }
  return Expr.parse(trimmed);
}

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
        final testPoint = def.isContinuous ? 0.0 : 0;
        final prob = dist.probability(testPoint);
        check(prob.isNaN).isFalse();

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
    test('all presets parse successfully and support simplification, expansion, factoring, and rewriting', () {
      for (final preset in expressionPresets) {
        final expr = Expr.tryParse(preset.formula);
        check(expr).isNotNull();

        final assumptions = preset.defaultDomain == VariableDomain.unknown
            ? Assumptions.none
            : Assumptions(defaultDomain: preset.defaultDomain);

        final simplified = expr!.simplify(assumptions: assumptions);
        check(simplified.toString().isNotEmpty).isTrue();

        final expanded = expr.expand(assumptions: assumptions);
        check(expanded.toString().isNotEmpty).isTrue();

        final factored = expr.factor(assumptions: assumptions);
        check(factored.toString().isNotEmpty).isTrue();

        final apart = expr.apart('x', assumptions: assumptions);
        check(apart.toString().isNotEmpty).isTrue();

        final together = expr.together(assumptions: assumptions);
        check(together.toString().isNotEmpty).isTrue();

        final canceled = expr.cancel(assumptions: assumptions);
        check(canceled.toString().isNotEmpty).isTrue();

        final trigExpanded = expr.expandTrig(assumptions: assumptions);
        check(trigExpanded.toString().isNotEmpty).isTrue();

        final trigSimplified = expr.simplifyTrig(assumptions: assumptions);
        check(trigSimplified.toString().isNotEmpty).isTrue();

        final latex = simplified.toLatex();
        check(latex.isNotEmpty).isTrue();

        final mathml = simplified.toMathMl();
        check(mathml.startsWith('<math>')).isTrue();
        check(mathml.endsWith('</math>')).isTrue();
      }
    });

    test(
      'all presets support symbolic differentiation, limits, and compilation',
      () {
        for (final preset in expressionPresets) {
          final expr = Expr.parse(preset.formula);
          final assumptions = preset.defaultDomain == VariableDomain.unknown
              ? Assumptions.none
              : Assumptions(defaultDomain: preset.defaultDomain);

          final d1 = expr
              .derivative('x', assumptions: assumptions)
              .simplify(assumptions: assumptions);
          final d2 = d1
              .derivative('x', assumptions: assumptions)
              .simplify(assumptions: assumptions);
          check(d1.toString().isNotEmpty).isTrue();
          check(d2.toString().isNotEmpty).isTrue();

          final x0Expr = _parsePresetBound(preset.defaultPointX);
          final ptDouble = x0Expr.evaluateComplex().a.toDouble();
          Expr lim;
          try {
            lim = expr.limit('x', x0Expr, assumptions: assumptions);
            check(lim.toString().isNotEmpty).isTrue();
          } on UnsupportedError {
            final limLeft = expr.limit(
              'x',
              x0Expr,
              direction: LimitDirection.fromBelow,
              assumptions: assumptions,
            );
            final limRight = expr.limit(
              'x',
              x0Expr,
              direction: LimitDirection.fromAbove,
              assumptions: assumptions,
            );
            check(limLeft).not((it) => it.equals(limRight));
            lim = Constant.undefined;
          }

          final hasUnevaluatedDerivative = d1.anyNode(
            (node) => node is Derivative,
          );

          if (containsImaginary(expr)) {
            final cfn = expr.toComplexFunction1D('x');
            final y0 = cfn(Complex(ptDouble, 0));
            check(y0.a.isNaN).isFalse();
            check(y0.b.isNaN).isFalse();
            if (!hasUnevaluatedDerivative) {
              final cdf = d1.toComplexFunction1D('x');
              final slope = cdf(Complex(ptDouble, 0));
              check(slope.a.isNaN).isFalse();
              check(slope.b.isNaN).isFalse();
            }
          } else {
            final fn = expr.toFunction1D('x');
            final y0 = fn(ptDouble);
            check(y0.isFinite || lim != Constant.undefined).isTrue();
            if (!hasUnevaluatedDerivative) {
              final df = d1.toFunction1D('x');
              final slope = df(ptDouble);
              check(
                slope.isFinite ||
                    lim != Constant.undefined ||
                    preset.id == 'piecewise_jump',
              ).isTrue();
            }
          }
        }
      },
    );

    test('all presets support symbolic definite integration, series, and summation', () {
      for (final preset in expressionPresets) {
        final expr = Expr.parse(preset.formula);
        final assumptions = preset.defaultDomain == VariableDomain.unknown
            ? Assumptions.none
            : Assumptions(defaultDomain: preset.defaultDomain);

        final aExpr = _parsePresetBound(preset.defaultIntA);
        final bExpr = _parsePresetBound(preset.defaultIntB);
        final defInt = expr
            .integrate('x', from: aExpr, to: bExpr, assumptions: assumptions)
            .simplify(assumptions: assumptions);
        check(defInt.toString().isNotEmpty).isTrue();

        final sumExpr = expr
            .sum(
              'x',
              IntegerNumber.one,
              const Variable('n'),
              assumptions: assumptions,
            )
            .simplify(assumptions: assumptions);
        check(sumExpr.toString().isNotEmpty).isTrue();

        final prodExpr = expr
            .product(
              'x',
              IntegerNumber.one,
              const Variable('n'),
              assumptions: assumptions,
            )
            .simplify(assumptions: assumptions);
        check(prodExpr.toString().isNotEmpty).isTrue();

        try {
          final taylor = expr
              .series(
                'x',
                point: _parsePresetBound(preset.defaultPointX),
                order: 3,
                includeOrder: false,
                assumptions: assumptions,
              )
              .simplify(assumptions: assumptions);
          check(taylor.toString().isNotEmpty).isTrue();
        } on UnsupportedError {
          // Functions with non-elementary series at the point throw UnsupportedError.
        }
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
      test('factorExpr factors polynomials and integer numbers', () {
        check(factorExpr(IntegerNumber.zero)).equals(IntegerNumber.zero);
        check(factorExpr(IntegerNumber.one)).equals(IntegerNumber.one);
        check(factorExpr(IntegerNumber.negativeOne))
            .equals(IntegerNumber.negativeOne);
        check(factorExpr(IntegerNumber.of(7))).equals(IntegerNumber.of(7));

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
