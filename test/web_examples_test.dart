import 'package:checks/checks.dart';
import 'package:data/numeric.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

import '../web/distributions/config.dart';
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

    test('all presets support differentiation and high-speed compilation', () {
      for (final preset in expressionPresets) {
        final expr = Expr.tryParse(preset.formula)!;
        final d1 = expr.diff('x').simplify();
        final d2 = d1.diff('x').simplify();

        check(d1.toString().isNotEmpty).isTrue();
        check(d2.toString().isNotEmpty).isTrue();

        final fn = expr.toFunction1D('x');
        final df = d1.toFunction1D('x');

        // Evaluate at default point
        final y0 = fn(preset.defaultPointX);
        final slope = df(preset.defaultPointX);
        check(y0.isNaN).isFalse();
        check(slope.isNaN).isFalse();
      }
    });

    test(
      'all presets can compute numerical integrals and Taylor expansions',
      () {
        for (final preset in expressionPresets) {
          final expr = Expr.tryParse(preset.formula)!;
          final fn = expr.toFunction1D('x');

          // Numerical quadrature in default interval
          final area = integrate(
            fn,
            preset.defaultIntA,
            preset.defaultIntB,
            method: IntegrationMethod.gaussKronrod,
          );
          check(area.isNaN).isFalse();

          // Taylor series expansion
          final taylor = expr
              .taylorSeries('x', order: 2, around: preset.defaultPointX)
              .simplify();
          check(taylor.toString().isNotEmpty).isTrue();
        }
      },
    );
  });
}
