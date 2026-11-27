import 'package:checks/checks.dart';
import 'package:data/numeric.dart';
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
    test('contains all 24 univariate and 3 multivariate distributions', () {
      check(distributions.length).equals(24);
      final continuousCount = distributions.where((d) => d.isContinuous).length;
      final discreteCount = distributions.where((d) => !d.isContinuous).length;
      check(continuousCount).equals(16);
      check(discreteCount).equals(8);
      check(multivariateDistributions.length).equals(3);
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
        check(prob.isNaN).isFalse;

        final samples = dist.samples().take(5).toList();
        check(samples.length).equals(5);
      }

      for (final def in multivariateDistributions) {
        final defaultParams = def.parameters
            .map((p) => p.defaultValue)
            .toList();
        final dist = def.creator(defaultParams);
        check(dist.dimensions).equals(def.dimensions);
        final samples = dist.samples().take(5).toList();
        check(samples.length).equals(5);
        for (final s in samples) {
          check(s.length).equals(def.dimensions);
        }
      }
    });

    test('all parameter bounds are consistent', () {
      for (final def in distributions) {
        for (final p in def.parameters) {
          check(p.min <= p.max).isTrue;
          check(p.defaultValue >= p.min && p.defaultValue <= p.max).isTrue;
          check(p.step > 0).isTrue;
        }
      }
      for (final def in multivariateDistributions) {
        for (final p in def.parameters) {
          check(p.min <= p.max).isTrue;
          check(p.defaultValue >= p.min && p.defaultValue <= p.max).isTrue;
          check(p.step > 0).isTrue;
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
        check(simplified.toString().isNotEmpty).isTrue;

        final expanded = expr.expand(assumptions: assumptions);
        check(expanded.toString().isNotEmpty).isTrue;

        final factored = expr.factor(assumptions: assumptions);
        check(factored.toString().isNotEmpty).isTrue;

        final apart = expr.apart('x', assumptions: assumptions);
        check(apart.toString().isNotEmpty).isTrue;

        final together = expr.together(assumptions: assumptions);
        check(together.toString().isNotEmpty).isTrue;

        final canceled = expr.cancel(assumptions: assumptions);
        check(canceled.toString().isNotEmpty).isTrue;

        final trigExpanded = expr.expandTrig(assumptions: assumptions);
        check(trigExpanded.toString().isNotEmpty).isTrue;

        final trigSimplified = expr.simplifyTrig(assumptions: assumptions);
        check(trigSimplified.toString().isNotEmpty).isTrue;

        final latex = simplified.toLatex();
        check(latex.isNotEmpty).isTrue;

        final mathml = simplified.toMathMl();
        check(mathml.startsWith('<math>')).isTrue;
        check(mathml.endsWith('</math>')).isTrue;
      }
    });

    test('supports multivariable assumptions and domains', () {
      final expr = Expr.parse('sqrt(x^2) + sqrt(y^2)');
      const assumptions = Assumptions(
        domains: {'x': VariableDomain.positive, 'y': VariableDomain.real},
      );
      final simplified = expr.simplify(assumptions: assumptions);
      check(simplified.format()).equals('x + abs(y)');
    });

    test(
      'all presets pass full demo pipeline within per-preset latency budget',
      () {
        for (final preset in expressionPresets) {
          final sw = Stopwatch()..start();
          final expr = Expr.parse(preset.formula);
          final assumptions = preset.defaultDomain == VariableDomain.unknown
              ? Assumptions.none
              : Assumptions(defaultDomain: preset.defaultDomain);

          // 1. Outputs & Normal Forms
          final simplified = expr.simplify(assumptions: assumptions);
          check(simplified.format().isNotEmpty).isTrue;
          check(simplified.toLatex().isNotEmpty).isTrue;
          final mathml = simplified.toMathMl();
          check(mathml.startsWith('<math>')).isTrue;
          check(mathml.endsWith('</math>')).isTrue;
          check(expr.expand(assumptions: assumptions).toString().isNotEmpty)
              .isTrue;
          check(expr.factor(assumptions: assumptions).toString().isNotEmpty)
              .isTrue;
          check(expr.approximate().toString().isNotEmpty).isTrue;
          check(expr.rationalize().toString().isNotEmpty).isTrue;

          // 2. Rational & Trig/Complex Algebra
          check(expr.apart('x', assumptions: assumptions).toString().isNotEmpty)
              .isTrue;
          check(expr.together(assumptions: assumptions).toString().isNotEmpty)
              .isTrue;
          check(expr.cancel(assumptions: assumptions).toString().isNotEmpty)
              .isTrue;
          check(
            expr.collect('x', assumptions: assumptions).toString().isNotEmpty,
          ).isTrue;
          check(expr.numerator.toString().isNotEmpty).isTrue;
          check(expr.denominator.toString().isNotEmpty).isTrue;
          check(expr.expandTrig(assumptions: assumptions).toString().isNotEmpty)
              .isTrue;
          check(
            expr.simplifyTrig(assumptions: assumptions).toString().isNotEmpty,
          ).isTrue;
          check(
            expr
                .rewrite(RewriteTarget.exp, assumptions: assumptions)
                .toString()
                .isNotEmpty,
          ).isTrue;
          check(
            expr
                .rewrite(RewriteTarget.trig, assumptions: assumptions)
                .toString()
                .isNotEmpty,
          ).isTrue;
          check(
            expr.toRectangular(assumptions: assumptions).toString().isNotEmpty,
          ).isTrue;
          check(expr.toPolar(assumptions: assumptions).toString().isNotEmpty)
              .isTrue;

          // 3. Calculus (Differentiation & Integration)
          final d1 = expr
              .derivative('x', assumptions: assumptions)
              .simplify(assumptions: assumptions);
          final d2 = d1
              .derivative('x', assumptions: assumptions)
              .simplify(assumptions: assumptions);
          final d3 = d2
              .derivative('x', assumptions: assumptions)
              .simplify(assumptions: assumptions);
          check(d1.toString().isNotEmpty).isTrue;
          check(d2.toString().isNotEmpty).isTrue;
          check(d3.toString().isNotEmpty).isTrue;

          check(
            expr.integrate('x', assumptions: assumptions).toString().isNotEmpty,
          ).isTrue;
          final aExpr = _parsePresetBound(preset.defaultIntA);
          final bExpr = _parsePresetBound(preset.defaultIntB);
          check(
            expr
                .integrate(
                  'x',
                  from: aExpr,
                  to: bExpr,
                  assumptions: assumptions,
                )
                .simplify(assumptions: assumptions)
                .toString()
                .isNotEmpty,
          ).isTrue;
          check(
            expr
                .integrate(
                  'x',
                  from: IntegerNumber.zero,
                  to: Constant.infinity,
                  assumptions: assumptions,
                )
                .toString()
                .isNotEmpty,
          ).isTrue;
          check(
            expr
                .integrate(
                  'x',
                  from: -Constant.infinity,
                  to: Constant.infinity,
                  assumptions: assumptions,
                )
                .toString()
                .isNotEmpty,
          ).isTrue;

          // 4. Series, Sums, Products & Limits
          final x0Expr = _parsePresetBound(preset.defaultPointX);
          final ptDouble = x0Expr.evaluateComplex().a.toDouble();
          for (final pt in [IntegerNumber.zero, x0Expr]) {
            try {
              final s = expr.series(
                'x',
                point: pt,
                order: 4,
                includeOrder: false,
                assumptions: assumptions,
              );
              check(s.toString().isNotEmpty).isTrue;
            } on UnsupportedError {
              // Non-elementary series at point.
            }
          }
          check(
            expr
                .sum(
                  'x',
                  IntegerNumber.one,
                  const Variable('n'),
                  assumptions: assumptions,
                )
                .toString()
                .isNotEmpty,
          ).isTrue;
          check(
            expr
                .indefiniteSum('x', assumptions: assumptions)
                .toString()
                .isNotEmpty,
          ).isTrue;
          check(
            expr
                .product(
                  'x',
                  IntegerNumber.one,
                  const Variable('n'),
                  assumptions: assumptions,
                )
                .toString()
                .isNotEmpty,
          ).isTrue;

          Expr lim;
          try {
            lim = expr.limit('x', x0Expr, assumptions: assumptions);
            check(lim.toString().isNotEmpty).isTrue;
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
            check(limLeft).not(.it()..equals(limRight));
            lim = Constant.undefined;
          }
          for (final dir in [
            LimitDirection.fromBelow,
            LimitDirection.fromAbove,
          ]) {
            try {
              check(
                expr
                    .limit(
                      'x',
                      x0Expr,
                      direction: dir,
                      assumptions: assumptions,
                    )
                    .toString()
                    .isNotEmpty,
              ).isTrue;
            } on UnsupportedError {
              // Non-existent one-sided limit.
            }
          }
          for (final infPt in [Constant.infinity, -Constant.infinity]) {
            try {
              check(
                expr
                    .limit('x', infPt, assumptions: assumptions)
                    .toString()
                    .isNotEmpty,
              ).isTrue;
            } on UnsupportedError {
              // Oscillatory or undefined at infinity.
            }
          }

          // 5. Roots, Extrema & Multivariable
          for (final target in [expr, d1, d2]) {
            try {
              target.solve('x', assumptions: assumptions);
            } on UnsupportedError {
              // Transcendental equations without closed-form roots.
            }
          }

          if (preset.defaultMvVars != null) {
            final vars = preset.defaultMvVars!
                .split(',')
                .map((s) => s.trim())
                .toList();
            final grad = expr.gradient(vars, assumptions: assumptions);
            check(grad.length).equals(vars.length);
            final hessian = expr.hessian(vars, assumptions: assumptions);
            check(hessian.rowCount).equals(vars.length);
            check(hessian.colCount).equals(vars.length);
            check(hessian.determinant().toString().isNotEmpty).isTrue;
            check(hessian.trace.toString().isNotEmpty).isTrue;
            try {
              grad.toList().solve(vars, assumptions: assumptions);
            } on UnsupportedError {
              // Nonlinear gradient system without closed-form solution.
            } on ArgumentError {
              // Non-polynomial gradient system.
            }
            final bc = expr.toBytecode(variables: vars);
            check(bc.instructionCount).isGreaterThan(0);
          } else {
            // 6. Bytecode Compilation & Curve Sampling (including unevaluated derivatives)
            final isComplex = containsImaginary(expr);
            final fn = isComplex ? null : expr.toFunction1D('x');
            final cfn = expr.toComplexFunction1D('x');
            final df = containsImaginary(d1) ? null : d1.toFunction1D('x');
            final cdf = d1.toComplexFunction1D('x');

            if (isComplex) {
              final y0 = cfn(Complex(ptDouble, 0));
              check(y0.a.isNaN).isFalse;
              check(y0.b.isNaN).isFalse;
              final slope = cdf(Complex(ptDouble, 0));
              check(slope.a.isNaN).isFalse;
              check(slope.b.isNaN).isFalse;
            } else {
              final y0 = fn!(ptDouble);
              check(y0.isFinite || lim != Constant.undefined).isTrue;
              final slope = df!(ptDouble);
              check(
                slope.isFinite ||
                    lim != Constant.undefined ||
                    preset.id == 'piecewise_jump',
              ).isTrue;
            }

            double evalSafeReal(double Function(double) f, double x) {
              try {
                return f(x);
              } on Object {
                return double.nan;
              }
            }

            final fSample = sampleCurve(
              (x) => fn == null
                  ? cfn(Complex(x, 0)).a.toDouble()
                  : evalSafeReal(fn, x),
              preset.defaultMinX,
              preset.defaultMaxX,
              maxPoints: 1200,
              initialPoints: 97,
            );
            check(fSample.segments).isNotEmpty;

            final d1Sample = sampleCurve(
              (x) => df == null
                  ? cdf(Complex(x, 0)).a.toDouble()
                  : evalSafeReal(df, x),
              preset.defaultMinX,
              preset.defaultMaxX,
              maxPoints: 1200,
              initialPoints: 97,
            );
            check(d1Sample.segments).isNotEmpty;

            if (preset.id == 'dilogarithm') {
              for (final seg in fSample.segments) {
                for (var i = 0; i < seg.y.length; i++) {
                  check(seg.y[i].abs()).isLessThan(1e12);
                }
              }
            }
          }

          // 7. Per-Preset Latency Guard (< 5000ms)
          sw.stop();
          const budgetMs = 5000;
          check(
            sw.elapsedMilliseconds,
            because: 'Preset ${preset.id} took ${sw.elapsedMilliseconds}ms',
          ).isLessThan(budgetMs);
        }
      },
    );
  });

  group('Web Expressions Algebra Utilities', () {
    group('containsImaginary', () {
      test(
        'detects presence of imaginary constant i in various AST locations',
        () {
          check(containsImaginary(ComplexNumber.i)).isTrue;
          check(containsImaginary(Expr.parse('exp(i * x)'))).isTrue;
          check(containsImaginary(Expr.parse('(x + i)^2'))).isTrue;
          check(containsImaginary(Expr.parse('sin(2 * i)'))).isTrue;
          check(containsImaginary(Expr.parse('x^3 - 3*x + 1'))).isFalse;
          check(containsImaginary(Expr.parse('sqrt(x)'))).isFalse;
          check(containsImaginary(Expr.parse('ln(1 + exp(x))'))).isFalse;
        },
      );
    });
  });
}
