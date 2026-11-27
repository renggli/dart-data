import 'package:checks/checks.dart';
import 'package:data/numeric.dart';
import 'package:data/symbolic.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/test.dart';

import '../web/distributions/config.dart';
import '../web/expressions/algebra.dart';
import '../web/expressions/presets.dart';

Expr _parsePresetBound(String raw) => Expr.parse(raw.trim());

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
    test('all presets parse cleanly under strict ExprSyntax.standard and support algebraic transformations', () {
      for (final preset in expressionPresets) {
        final expr = Expr.tryParse(preset.formula);
        check(expr).isNotNull();
        check(
          expr!.anyNode((n) => n is Call && n.id == FunctionId.symbolic),
          because: 'Preset ${preset.id} used non-standard symbolic call',
        ).isFalse;

        final assumptions = preset.buildAssumptions(expr.freeVariables);

        final simplified = expr.simplify(assumptions: assumptions);
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
          final assumptions = preset.buildAssumptions(expr.freeVariables);

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
              try {
                final puiseux = expr.toPuiseuxSeries(
                  'x',
                  point: pt,
                  order: 4,
                  assumptions: assumptions,
                );
                check(puiseux.toExpr(includeOrder: false).toString().isNotEmpty)
                    .isTrue;
              } on UnsupportedError {
                // Non-elementary series at point.
              }
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

    test('groups 72 presets contiguously across 10 ordered categories', () {
      check(expressionPresets.length).equals(72);

      const expectedOrder = [
        'Algebra & Rational Functions',
        'Domains, Parity & Constraints',
        'Trigonometric, Hyperbolic & Complex',
        'Limits, Piecewise & Discrete',
        'Symbolic & Improper Integration',
        'Series, Summations & Products',
        'Equations & Lambert W',
        'Multivariable 3D Surfaces',
        'Gamma, Zeta & Special Integrals',
        'Waves, Elliptic & Hypergeometric',
      ];

      final actualOrder = <String>[];
      final counts = <String, int>{};
      for (final p in expressionPresets) {
        if (actualOrder.isEmpty || actualOrder.last != p.category) {
          check(
            actualOrder.contains(p.category),
            because: 'Category ${p.category} must appear contiguously',
          ).isFalse;
          actualOrder.add(p.category);
        }
        counts[p.category] = (counts[p.category] ?? 0) + 1;
      }

      check(actualOrder).deepEquals(expectedOrder);
      for (final c in expectedOrder) {
        check(counts[c]!).isGreaterOrEqual(3);
      }
    });

    test(
      'Algebra & Rational Functions presets match their advertised behavior',
      () {
        ExpressionPreset byId(String id) =>
            expressionPresets.firstWhere((p) => p.id == id);

        // factored_cubic
        final cubic = Expr.parse(byId('factored_cubic').formula);
        check(cubic.expand().format()).equals('4 - 4 * x - x ^ 2 + x ^ 3');
        check(cubic.factor().format()).equals('(-2 + x) * (-1 + x) * (2 + x)');
        check(cubic.solve('x')).unorderedEquals([
          IntegerNumber.of(-2),
          IntegerNumber.one,
          IntegerNumber.two,
        ]);
        check(cubic.derivative('x').solve('x').length).equals(2);

        // sophie_germain
        final sophie = Expr.parse(byId('sophie_germain').formula);
        check(sophie.factor().format())
            .equals('(2 - 2 * x + x ^ 2) * (2 + 2 * x + x ^ 2)');
        check(sophie.solve('x')).unorderedEquals([
          IntegerNumber.one + ComplexNumber.i,
          IntegerNumber.one - ComplexNumber.i,
          IntegerNumber.negativeOne + ComplexNumber.i,
          IntegerNumber.negativeOne - ComplexNumber.i,
        ]);

        // chebyshev_minimax
        final cheb = Expr.parse(byId('chebyshev_minimax').formula);
        check(cheb.format()).equals('5 * x - 20 * x ^ 3 + 16 * x ^ 5');
        check(cheb.solve('x').length).equals(5);

        // binomial_polynomial
        final binom = Expr.parse(byId('binomial_polynomial').formula);
        check(binom.solve('x')).unorderedEquals([
          IntegerNumber.zero,
          IntegerNumber.one,
          IntegerNumber.two,
        ]);
        check(binom.derivative('x').solve('x').length).equals(2);
        check(binom.indefiniteSum('x')?.format()).equals('binomial(x, 4)');
        check(binom.sum('x', 1, const Variable('n')).format())
            .equals('binomial(1 + n, 4)');
        check(binom.series('x', order: 4, includeOrder: false).format())
            .equals('1/3 * x - 1/2 * x ^ 2 + 1/6 * x ^ 3');

        // decimal_rationalize
        check(
          Expr.parse(byId('decimal_rationalize').formula)
              .rationalize()
              .format(),
        ).equals('-1/3 + 1/8 * x + 15/8 * x ^ 2');

        // radical_denesting
        final denest = Expr.parse(byId('radical_denesting').formula);
        check(denest.simplify().format())
            .equals('-sqrt(2) + sqrt(3) + x * (1 + sqrt(2))');
        check(denest.solve('x').single.format())
            .equals('(sqrt(2) - sqrt(3)) / (1 + sqrt(2))');

        // rational_gcd_cancel
        final gcdRat = Expr.parse(byId('rational_gcd_cancel').formula);
        check(gcdRat.cancel().format()).equals('(1 + x + x ^ 2) / (1 + x)');
        check(gcdRat.apart('x').format()).equals('x + 1 / (1 + x)');
        check(gcdRat.limit('x', 1).format()).equals('3/2');

        // rational_together
        final tog = Expr.parse(byId('rational_together').formula);
        check(tog.together().format())
            .equals('4 * x / ((-1 + x) * (1 + x) * (1 + x ^ 2))');
        check(tog.cancel().format())
            .equals('4 * x / ((-1 + x) * (1 + x) * (1 + x ^ 2))');

        // partial_fractions
        final pf = Expr.parse(byId('partial_fractions').formula);
        check(pf.apart('x').format())
            .equals('-5 / x + 4 / (-1 + x) + 1 / (1 + x)');
      },
    );

    test(
      'Domains, Parity & Constraints presets match their advertised behavior',
      () {
        ExpressionPreset byId(String id) =>
            expressionPresets.firstWhere((p) => p.id == id);

        // domain_radical_abs
        final dom = byId('domain_radical_abs');
        final domExpr = Expr.parse(dom.formula);
        check(domExpr.simplify().format()).equals('abs(x) + sqrt(x ^ 2)');
        check(
          domExpr.simplify(assumptions: dom.buildAssumptions(['x'])).format(),
        ).equals('2 * abs(x)');
        check(
          domExpr
              .simplify(assumptions: Assumptions.none.withPositive('x'))
              .format(),
        ).equals('2 * x');
        check(
          domExpr
              .simplify(assumptions: Assumptions.none.withNegative('x'))
              .format(),
        ).equals('-2 * x');

        // bounded_abs_radical
        final bounded = byId('bounded_abs_radical');
        final boundedExpr = Expr.parse(bounded.formula);
        check(
          boundedExpr
              .simplify(assumptions: bounded.buildAssumptions(['x']))
              .format(),
        ).equals('-4 + 2 * x');
        check(
          boundedExpr
              .simplify(
                assumptions: Assumptions.none
                    .withBounds('x', upper: IntegerNumber.two)
                    .withRelation(
                      Relational.lessThan(
                        const Variable('x'),
                        IntegerNumber.two,
                      ),
                    ),
              )
              .format(),
        ).equals('4 - 2 * x');

        // parity_alternating
        final parity = byId('parity_alternating');
        final parityExpr = Expr.parse(parity.formula);
        check(
          parityExpr
              .simplify(assumptions: parity.buildAssumptions(['x']))
              .format(),
        ).equals('-2');
        check(
          parityExpr
              .simplify(assumptions: Assumptions.none.withEven('x'))
              .format(),
        ).equals('2');
        check(
          parityExpr
              .simplify(assumptions: Assumptions.none.withInteger('x'))
              .format(),
        ).equals('2 * (-1) ^ x');
      },
    );

    test('Trigonometric, Hyperbolic & Complex presets match their advertised behavior', () {
      ExpressionPreset byId(String id) =>
          expressionPresets.firstWhere((p) => p.id == id);

      // multiple_angle_trig
      check(
        Expr.parse(byId('multiple_angle_trig').formula).expandTrig().format(),
      ).equals(
        'cos(x) ^ 2 - sin(x) ^ 2 - sin(x) ^ 3 + 3 * sin(x) * cos(x) ^ 2',
      );

      // double_angle_quotient
      final daq = Expr.parse(byId('double_angle_quotient').formula);
      check(daq.simplifyTrig().format())
          .equals('sin(2 * x) / ((cos(x) + sin(x)) * (cos(x) - sin(x)))');
      check(daq.toBytecode(variables: ['x']).sharedCount).isGreaterThan(0);

      // trig_power_reduction
      final tpr = byId('trig_power_reduction');
      final tprExpr = Expr.parse(tpr.formula);
      check(
        tprExpr
            .integrate(
              'x',
              from: Expr.parse(tpr.defaultIntA),
              to: Expr.parse(tpr.defaultIntB),
            )
            .simplify()
            .format(),
      ).equals('1/16 * pi');

      // quad_trig_equation
      final qt = Expr.parse(byId('quad_trig_equation').formula);
      check(qt.simplify().format()).equals('sin(x) ^ 2 + 3 * cos(x) * sin(x)');
      check(qt.solve('x').length).equals(4);

      // atan2_sawtooth
      check(Expr.parse(byId('atan2_sawtooth').formula).derivative('x').format())
          .equals('1');

      // exp_atanh_identity
      final eah = Expr.parse(byId('exp_atanh_identity').formula);
      check(eah.simplify().format()).equals('(1 + x) / (1 - x)');
      check(eah.apart('x').format()).equals('-1 - 2 / (-1 + x)');

      // damped_oscillator
      final damp = Expr.parse(byId('damped_oscillator').formula);
      check(damp.derivative('x').simplify().format()).equals(
        '-1/4 * cos(2 * x) * exp(-1/4 * x) - 2 * sin(2 * x) * exp(-1/4 * x)',
      );
      check(
        damp.integrate('x', from: 0, to: Constant.infinity).simplify().format(),
      ).equals('4/65');
      check(damp.limit('x', Constant.infinity).format()).equals('0');

      // euler_formula
      final euler = byId('euler_formula');
      check(
        Expr.parse(euler.formula)
            .toRectangular(assumptions: euler.buildAssumptions(['x']))
            .format(),
      ).equals('cos(x) + i * sin(x)');

      // complex_binomial
      final cb = byId('complex_binomial');
      final cbExpr = Expr.parse(cb.formula);
      check(cbExpr.expand().format())
          .equals('-i - 3 * x + 3 * i * x ^ 2 + x ^ 3');
      check(
        cbExpr.toRectangular(assumptions: cb.buildAssumptions(['x'])).format(),
      ).equals('-2 * x + x * (-1 + x ^ 2) + i * (-1 + 3 * x ^ 2)');
    });

    test(
      'Limits, Piecewise & Discrete presets match their advertised behavior',
      () {
        ExpressionPreset byId(String id) =>
            expressionPresets.firstWhere((p) => p.id == id);

        // sinc_limit
        final sinc = Expr.parse(byId('sinc_limit').formula);
        check(sinc.limit('x', 0).format()).equals('1');
        check(sinc.limit('x', Constant.infinity).format()).equals('0');
        check(sinc.limit('x', -Constant.infinity).format()).equals('0');
        check(sinc.integrate('x').simplify().format()).equals('Si(x)');

        // radical_conjugate_limit
        final rc = Expr.parse(byId('radical_conjugate_limit').formula);
        check(rc.limit('x', 0).format()).equals('1/4');
        check(rc.integrate('x').simplify().format())
            .equals('-4 * ln(abs(2 + sqrt(4 + x))) + 2 * sqrt(4 + x)');

        // lhopital_cubic
        check(Expr.parse(byId('lhopital_cubic').formula).limit('x', 0).format())
            .equals('1/6');

        // euler_compound_limit
        final ec = Expr.parse(byId('euler_compound_limit').formula);
        check(ec.limit('x', Constant.infinity).format()).equals('e');
        check(ec.limit('x', -Constant.infinity).format()).equals('e');

        // piecewise_jump
        final pw = byId('piecewise_jump');
        final pwExpr = Expr.parse(pw.formula);
        check(
          pwExpr.limit('x', 0, direction: LimitDirection.fromBelow).format(),
        ).equals('-1');
        check(
          pwExpr.limit('x', 0, direction: LimitDirection.fromAbove).format(),
        ).equals('1');
        check(
          pwExpr
              .integrate(
                'x',
                from: Expr.parse(pw.defaultIntA),
                to: Expr.parse(pw.defaultIntB),
              )
              .simplify()
              .format(),
        ).equals('-2/3');

        // sawtooth_floor
        final saw = byId('sawtooth_floor');
        final sawExpr = Expr.parse(saw.formula);
        check(sawExpr.derivative('x').simplify().format()).equals('1');
        check(
          sawExpr
              .integrate(
                'x',
                from: Expr.parse(saw.defaultIntA),
                to: Expr.parse(saw.defaultIntB),
              )
              .simplify()
              .format(),
        ).equals('3/2');
      },
    );

    test(
      'Symbolic & Improper Integration presets match their advertised behavior',
      () {
        ExpressionPreset byId(String id) =>
            expressionPresets.firstWhere((p) => p.id == id);

        // witch_agnesi
        final witch = byId('witch_agnesi');
        final witchExpr = Expr.parse(witch.formula);
        check(witchExpr.integrate('x').simplify().format()).equals('atan(x)');
        check(
          witchExpr
              .integrate(
                'x',
                from: Expr.parse(witch.defaultIntA),
                to: Expr.parse(witch.defaultIntB),
              )
              .simplify()
              .format(),
        ).equals('1/2 * pi');
        check(
          witchExpr
              .integrate('x', from: -Constant.infinity, to: Constant.infinity)
              .simplify()
              .format(),
        ).equals('pi');

        // rootsum_rational
        final cubicRat = Expr.parse(byId('rootsum_rational').formula);
        check(cubicRat.integrate('x').simplify().format()).contains('atan(');
        check(cubicRat.derivative('x').solve('x'))
            .deepEquals([IntegerNumber.zero]);

        // log_ibp
        final logIbp = byId('log_ibp');
        final logExpr = Expr.parse(logIbp.formula);
        check(logExpr.integrate('x').simplify().format())
            .equals('-1/9 * x ^ 3 + 1/3 * ln(x) * x ^ 3');
        check(
          logExpr
              .integrate(
                'x',
                from: Expr.parse(logIbp.defaultIntA),
                to: Expr.parse(logIbp.defaultIntB),
              )
              .simplify()
              .format(),
        ).equals('1/9 + 2/9 * exp(3)');
        check(logExpr.solve('x')).deepEquals([IntegerNumber.one]);

        // cyclic_ibp
        final cyc = byId('cyclic_ibp');
        final cycExpr = Expr.parse(cyc.formula);
        check(cycExpr.integrate('x').simplify().format())
            .equals('1/5 * exp(-x) * (-2 * cos(2 * x) - sin(2 * x))');
        check(
          cycExpr
              .integrate(
                'x',
                from: Expr.parse(cyc.defaultIntA),
                to: Expr.parse(cyc.defaultIntB),
              )
              .simplify()
              .format(),
        ).equals('2/5');

        // semicircle_integral
        final semi = byId('semicircle_integral');
        final semiExpr = Expr.parse(semi.formula);
        check(semiExpr.integrate('x').simplify().format())
            .equals('2 * asin(1/2 * x) + 1/2 * x * sqrt(4 - x ^ 2)');
        check(
          semiExpr
              .integrate(
                'x',
                from: Expr.parse(semi.defaultIntA),
                to: Expr.parse(semi.defaultIntB),
              )
              .simplify()
              .format(),
        ).equals('2 * pi');

        // weierstrass_trig
        final weier = byId('weierstrass_trig');
        final weierExpr = Expr.parse(weier.formula);
        check(weierExpr.integrate('x').simplify().format())
            .equals('2/3 * atan(1/3 * tan(1/2 * x) * sqrt(3)) * sqrt(3)');
        check(
          weierExpr
              .integrate(
                'x',
                from: Expr.parse(weier.defaultIntA),
                to: Expr.parse(weier.defaultIntB),
              )
              .simplify()
              .format(),
        ).equals('1/3 * pi * sqrt(3)');

        // cbrt_binomial
        final cbrt = Expr.parse(byId('cbrt_binomial').formula);
        check(cbrt.integrate('x').simplify().format()).equals(
          '3 * ln(abs(1 + x ^ (1/3))) - 3 * x ^ (1/3) + 3/2 * x ^ (2/3)',
        );
        check(cbrt.toPuiseuxSeries('x', point: 0, order: 2).toExpr().format())
            .contains('x ^ (1/3)');

        // trig_symmetry_integral
        final kings = byId('trig_symmetry_integral');
        check(
          Expr.parse(kings.formula)
              .integrate(
                'x',
                from: Expr.parse(kings.defaultIntA),
                to: Expr.parse(kings.defaultIntB),
              )
              .simplify()
              .format(),
        ).equals('1/4 * pi');

        // polylog_integral
        check(
          Expr.parse(byId('polylog_integral').formula)
              .integrate('x')
              .simplify()
              .format(),
        ).equals('polylog(2, -x) + ln(x) * ln(1 + x)');

        // gaussian_integral
        final gauss = byId('gaussian_integral');
        final gaussExpr = Expr.parse(gauss.formula);
        check(gaussExpr.integrate('x').simplify().format())
            .equals('1/2 * erf(x) * sqrt(pi)');
        check(
          gaussExpr
              .integrate(
                'x',
                from: Expr.parse(gauss.defaultIntA),
                to: Expr.parse(gauss.defaultIntB),
              )
              .simplify()
              .format(),
        ).equals('sqrt(pi)');
        check(
          gaussExpr
              .integrate('x', from: 0, to: Constant.infinity)
              .simplify()
              .format(),
        ).equals('1/2 * sqrt(pi)');

        // ftc_gaussian_binder
        final ftcExpr = Expr.parse(byId('ftc_gaussian_binder').formula);
        check(ftcExpr.derivative('x').simplify().format())
            .equals('exp(-x ^ 2)');
        check(ftcExpr.toBytecode(variables: ['x']).nodes.length).equals(1);
      },
    );

    test(
      'Series, Summations & Products presets match their advertised behavior',
      () {
        ExpressionPreset byId(String id) =>
            expressionPresets.firstWhere((p) => p.id == id);

        // laurent_pole
        check(
          Expr.parse(byId('laurent_pole').formula)
              .series('x', order: 4)
              .format(),
        ).equals('-1/2 + x ^ (-2) + 1/24 * x ^ 2 + O(x^4)');

        // puiseux_branch
        final puiseux = byId('puiseux_branch');
        final puiseuxExpr = Expr.parse(puiseux.formula);
        check(
          puiseuxExpr
              .toPuiseuxSeries('x', point: 0, order: 4)
              .toExpr(includeOrder: true)
              .format(),
        ).equals(
          'x ^ (1/3) - x ^ (4/3) + 1/2 * x ^ (7/3) - 1/6 * x ^ (10/3) + O(x^4)',
        );
        check(
          puiseuxExpr
              .integrate(
                'x',
                from: Expr.parse(puiseux.defaultIntA),
                to: Expr.parse(puiseux.defaultIntB),
              )
              .simplify()
              .format(),
        ).equals('gamma(4/3)');

        // telescoping_sum
        final tele = byId('telescoping_sum');
        final teleExpr = Expr.parse(tele.formula);
        check(teleExpr.apart('x').format()).equals('1 / x - 1 / (1 + x)');
        check(teleExpr.indefiniteSum('x')?.format()).equals('-1 / x');
        check(teleExpr.sum('x', 1, const Variable('n')).format())
            .equals('1 - 1 / (1 + n)');
        check(
          teleExpr
              .integrate(
                'x',
                from: Expr.parse(tele.defaultIntA),
                to: Expr.parse(tele.defaultIntB),
              )
              .simplify()
              .format(),
        ).equals('ln(2)');

        // arithmetico_geometric
        final ag = Expr.parse(byId('arithmetico_geometric').formula);
        check(ag.indefiniteSum('x')?.format())
            .equals('2 ^ (-x) * (-2 - 2 * x)');
        check(ag.sum('x', 1, const Variable('n')).format())
            .equals('2 - 4 * 2 ^ (-1 - n) - 2 * n * 2 ^ (-1 - n)');
        check(
          ag.integrate('x', from: 0, to: Constant.infinity).simplify().format(),
        ).equals('ln(2) ^ (-2)');

        // gosper_factorial
        final gosp = Expr.parse(byId('gosper_factorial').formula);
        check(gosp.indefiniteSum('x')?.format()).equals('x!');
        check(gosp.sum('x', 1, const Variable('n')).format())
            .equals('-1 + (1 + n)!');

        // telescoping_product
        final tprod = Expr.parse(byId('telescoping_product').formula);
        check(tprod.product('x', 1, const Variable('n')).format())
            .equals('1 + n');
        check(tprod.apart('x').format()).equals('1 + 1 / x');
      },
    );

    test('Equations & Lambert W presets match their advertised behavior', () {
      ExpressionPreset byId(String id) =>
          expressionPresets.firstWhere((p) => p.id == id);

      // lambert_equation
      final lamEq = Expr.parse(byId('lambert_equation').formula);
      check(lamEq.solve('x').single.format()).equals('lambertW(2)');
      check(lamEq.derivative('x').solve('x'))
          .deepEquals([IntegerNumber.negativeOne]);

      // self_exponentiation
      final selfExp = Expr.parse(byId('self_exponentiation').formula);
      check(selfExp.solve('x').single.format()).equals('exp(lambertW(ln(2)))');
      check(selfExp.derivative('x').simplify().format())
          .equals('x ^ x * (1 + ln(x))');
      check(selfExp.derivative('x').solve('x').single.format())
          .equals('exp(-1)');

      // lambert_w_branch
      final lw = byId('lambert_w_branch');
      final lwExpr = Expr.parse(lw.formula);
      check(lwExpr.derivative('x').simplify().format())
          .equals('exp(-lambertW(x)) / (1 + lambertW(x))');
      check(lwExpr.integrate('x').simplify().format())
          .equals('exp(lambertW(x)) + x * (-1 + lambertW(x))');
      check(
        lwExpr
            .integrate(
              'x',
              from: Expr.parse(lw.defaultIntA),
              to: Expr.parse(lw.defaultIntB),
            )
            .simplify()
            .format(),
      ).equals('-1 + e');
      check(lwExpr.series('x', order: 4).format())
          .equals('x - x ^ 2 + 3/2 * x ^ 3 + O(x^4)');

      // lambert_w_lower
      final lwm1 = byId('lambert_w_lower');
      final lwm1Expr = Expr.parse(lwm1.formula);
      check(
        lwm1Expr
            .substitute('x', Expr.parse(lwm1.defaultPointX))
            .simplify()
            .format(),
      ).equals('-1');
      check(lwm1Expr.derivative('x').simplify().format())
          .equals('exp(-lambertW(x, -1)) / (1 + lambertW(x, -1))');
    });

    test(
      'Multivariable 3D Surfaces presets match their advertised behavior',
      () {
        ExpressionPreset byId(String id) =>
            expressionPresets.firstWhere((p) => p.id == id);

        // harmonic_saddle
        final saddle = Expr.parse(byId('harmonic_saddle').formula);
        check(saddle.laplacian(['x', 'y']).simplify().format()).equals('0');
        check(saddle.hessian(['x', 'y']).determinant().simplify().format())
            .equals('-36 * x ^ 2 - 36 * y ^ 2');
        check(saddle.gradient(['x', 'y']).toList().solve(['x', 'y']))
            .deepEquals([
              {'x': IntegerNumber.zero, 'y': IntegerNumber.zero},
            ]);

        // rosenbrock_potential
        final rosen = Expr.parse(byId('rosenbrock_potential').formula);
        check(rosen.gradient(['x', 'y']).toList().solve(['x', 'y']))
            .deepEquals([
              {'x': IntegerNumber.one, 'y': IntegerNumber.one},
            ]);

        // egg_carton_3d
        final egg = Expr.parse(byId('egg_carton_3d').formula);
        check(egg.laplacian(['x', 'y']).simplify().format())
            .equals('-2 * cos(y) * sin(x)');

        // bivariate_gaussian
        final bgauss = Expr.parse(byId('bivariate_gaussian').formula);
        check(bgauss.hessian(['x', 'y']).determinant().simplify().format())
            .contains('4 * exp(-2 * x ^ 2 - 2 * y ^ 2)');

        // sinc_ripple_3d
        final ripple = Expr.parse(byId('sinc_ripple_3d').formula);
        check(ripple.limit('x', Constant.infinity).format()).equals('0');
        check(ripple.toBytecode(variables: ['x', 'y']).sharedCount)
            .isGreaterThan(0);
      },
    );

    test(
      'Gamma, Zeta & Special Integrals presets match their advertised behavior',
      () {
        ExpressionPreset byId(String id) =>
            expressionPresets.firstWhere((p) => p.id == id);

        // gamma_function
        final gam = byId('gamma_function');
        final gamExpr = Expr.parse(gam.formula);
        check(
          gamExpr
              .substitute('x', Expr.parse(gam.defaultPointX))
              .simplify()
              .format(),
        ).equals('sqrt(pi)');
        check(gamExpr.derivative('x').simplify().format())
            .equals('gamma(x) * digamma(x)');
        check(gamExpr.limit('x', Constant.infinity).format())
            .equals('infinity');

        // log_gamma
        final lgam = Expr.parse(byId('log_gamma').formula);
        check(lgam.substitute('x', IntegerNumber.one).simplify().format())
            .equals('0');
        check(lgam.derivative('x').simplify().format()).equals('digamma(x)');

        // digamma_function
        check(
          Expr.parse(byId('digamma_function').formula)
              .derivative('x')
              .simplify()
              .format(),
        ).equals('polygamma(1, x)');

        // upper_gamma
        final ugam = Expr.parse(byId('upper_gamma').formula);
        check(ugam.derivative('x').simplify().format()).equals('-x * exp(-x)');
        check(ugam.series('x', order: 4).format())
            .equals('1 - 1/2 * x ^ 2 + 1/3 * x ^ 3 + O(x^4)');

        // euler_beta
        final beta = byId('euler_beta');
        final betaExpr = Expr.parse(beta.formula);
        check(betaExpr.simplify().format())
            .equals('2 / (x * (1 + x) * (2 + x))');
        check(
          betaExpr
              .integrate(
                'x',
                from: Expr.parse(beta.defaultIntA),
                to: Expr.parse(beta.defaultIntB),
              )
              .simplify()
              .format(),
        ).equals('-ln(3/4)');

        // riemann_zeta
        final zeta = Expr.parse(byId('riemann_zeta').formula);
        check(zeta.substitute('x', IntegerNumber.two).simplify().format())
            .equals('1/6 * pi ^ 2');
        check(zeta.substitute('x', IntegerNumber.zero).simplify().format())
            .equals('-1/2');

        // error_function
        final erfExpr = Expr.parse(byId('error_function').formula);
        check(erfExpr.derivative('x').simplify().format())
            .equals('2 * exp(-x ^ 2) * pi ^ (-1/2)');
        check(erfExpr.limit('x', Constant.infinity).format()).equals('1');
        check(erfExpr.limit('x', -Constant.infinity).format()).equals('-1');

        // fresnel_sine
        final fsExpr = Expr.parse(byId('fresnel_sine').formula);
        check(fsExpr.derivative('x').simplify().format())
            .equals('sin(1/2 * pi * x ^ 2)');
        check(fsExpr.integrate('x').simplify().format())
            .equals('x * fresnelS(x) + cos(1/2 * pi * x ^ 2) / pi');

        // sine_integral
        final siExpr = Expr.parse(byId('sine_integral').formula);
        check(siExpr.derivative('x').simplify().format()).equals('sin(x) / x');
        check(siExpr.integrate('x').simplify().format())
            .equals('cos(x) + x * Si(x)');

        // exp_integral
        final eiExpr = Expr.parse(byId('exp_integral').formula);
        check(eiExpr.derivative('x').simplify().format()).equals('exp(x) / x');
        check(eiExpr.integrate('x').simplify().format())
            .equals('-exp(x) + x * Ei(x)');

        // log_integral
        final liExpr = Expr.parse(byId('log_integral').formula);
        check(liExpr.derivative('x').simplify().format()).equals('1 / ln(x)');
        check(liExpr.integrate('x').simplify().format())
            .equals('-Ei(2 * ln(x)) + x * li(x)');
      },
    );

    test('Waves, Elliptic & Hypergeometric presets match their advertised behavior', () {
      ExpressionPreset byId(String id) =>
          expressionPresets.firstWhere((p) => p.id == id);

      // quantum_hermite
      final hermite = byId('quantum_hermite');
      final hermiteExpr = Expr.parse(hermite.formula);
      check(
        hermiteExpr
            .integrate(
              'x',
              from: Expr.parse(hermite.defaultIntA),
              to: Expr.parse(hermite.defaultIntB),
            )
            .simplify()
            .format(),
      ).equals('12 * sqrt(2 * pi)');
      check(hermiteExpr.solve('x').length).equals(4);
      check(hermiteExpr.toBytecode(variables: ['x']).sharedCount)
          .isGreaterThan(0);

      // bessel_wave
      final bessel = Expr.parse(byId('bessel_wave').formula);
      check(bessel.derivative('x').simplify().format())
          .equals('-besselJ(1, x)');
      check(bessel.series('x', order: 4).format())
          .equals('1 - 1/4 * x ^ 2 + O(x^4)');

      // dilogarithm
      final dilog = Expr.parse(byId('dilogarithm').formula);
      check(dilog.derivative('x').simplify().format()).equals('-ln(1 - x) / x');
      check(dilog.series('x', order: 4).format())
          .equals('x + 1/4 * x ^ 2 + 1/9 * x ^ 3 + O(x^4)');

      // gauss_hypergeometric
      final hyper = Expr.parse(byId('gauss_hypergeometric').formula);
      check(hyper.derivative('x').simplify().format())
          .equals('1/4 * hypergeometric([3/2, 3/2], [2], x)');

      // appell_f1
      final appell = Expr.parse(byId('appell_f1').formula);
      check(appell.substitute('x', IntegerNumber.zero).simplify().format())
          .equals('1');
      check(appell.derivative('x').simplify().format()).contains('appellF1(');

      // elliptic_k_complete
      final ellK = Expr.parse(byId('elliptic_k_complete').formula);
      check(ellK.substitute('x', IntegerNumber.zero).simplify().format())
          .equals('1/2 * pi');
      check(ellK.derivative('x').simplify().format()).contains('ellipticE(x)');

      // elliptic_f_incomplete
      final ellF = Expr.parse(byId('elliptic_f_incomplete').formula);
      check(ellF.derivative('x').simplify().format())
          .equals('(1 - 1/4 * sin(x) ^ 2) ^ (-1/2)');

      // elliptic_pi_incomplete
      final ellPi = Expr.parse(byId('elliptic_pi_incomplete').formula);
      check(ellPi.derivative('x').simplify().format())
          .equals('(1 - 1/4 * sin(x) ^ 2) ^ (-1/2) / (1 - 1/2 * sin(x) ^ 2)');
    });
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
