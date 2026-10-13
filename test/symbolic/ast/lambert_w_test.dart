import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:data/type.dart' show Complex;
import 'package:test/scaffolding.dart';

void main() {
  group('LambertW construction & properties', () {
    test('default branch is 0', () {
      const w = LambertW(Variable('x'));
      check(w.branch).equals(0);
      check(w.expr).equals(const Variable('x'));
    });

    test('branch -1 construction', () {
      const w = LambertW(Variable('x'), branch: -1);
      check(w.branch).equals(-1);
    });

    test('dependency and variable collection', () {
      const w = LambertW(Mul(Variable('x'), Variable('y')));
      check(w.dependsOn('x')).isTrue();
      check(w.dependsOn('y')).isTrue();
      check(w.dependsOn('z')).isFalse();
      check(w.freeVariables).unorderedEquals({'x', 'y'});
    });

    test('substitution', () {
      const w0 = LambertW(Variable('x'), branch: 0);
      const wNeg = LambertW(Variable('x'), branch: -1);
      final sub0 = w0.substitute('x', const Variable('y'));
      final subNeg = wNeg.substitute('x', const Variable('y'));

      check(sub0).equals(const LambertW(Variable('y'), branch: 0));
      check(subNeg).equals(const LambertW(Variable('y'), branch: -1));
    });

    test('equality and hashCode distinguish branches', () {
      const w0 = LambertW(Variable('x'), branch: 0);
      const wNeg = LambertW(Variable('x'), branch: -1);
      const w0Copy = LambertW(Variable('x'), branch: 0);

      check(w0).equals(w0Copy);
      check(w0.hashCode).equals(w0Copy.hashCode);
      check(w0 == wNeg).isFalse();
    });
  });

  group('LambertW real evaluation', () {
    test('branch 0 known values', () {
      const invE = 1.0 / math.e;
      check(evaluateLambertW(0.0, 0)).isCloseTo(0.0, 1e-12);
      check(evaluateLambertW(math.e, 0)).isCloseTo(1.0, 1e-12);
      check(evaluateLambertW(-invE, 0)).isCloseTo(-1.0, 1e-12);
      check(evaluateLambertW(1.0, 0)).isCloseTo(0.5671432904097838, 1e-12);
      check(evaluateLambertW(2.0, 0)).isCloseTo(0.8526055020137255, 1e-12);
    });

    test('branch -1 known values', () {
      const invE = 1.0 / math.e;
      check(evaluateLambertW(-invE, -1)).isCloseTo(-1.0, 1e-12);
      check(evaluateLambertW(-0.1, -1)).isCloseTo(-3.577152063957297, 1e-12);
      check(evaluateLambertW(-0.2, -1)).isCloseTo(-2.5426413577735265, 1e-12);
    });

    test('branch 0 domain violation throws RangeError', () {
      check(() => evaluateLambertW(-0.4, 0)).throws<RangeError>();
      check(() => evaluateLambertW(-0.5, 0)).throws<RangeError>();
    });

    test('branch -1 domain violation throws RangeError', () {
      check(() => evaluateLambertW(-0.4, -1)).throws<RangeError>();
      check(() => evaluateLambertW(-0.5, -1)).throws<RangeError>();
      check(() => evaluateLambertW(0.0, -1)).throws<RangeError>();
      check(() => evaluateLambertW(0.1, -1)).throws<RangeError>();
    });

    test('AST evaluate wrapper across branches and branch points', () {
      const w0 = LambertW(Variable('x'), branch: 0);
      const wNeg = LambertW(Variable('x'), branch: -1);
      const invE = 1.0 / math.e;
      check(w0.evaluate({'x': 0.0})).isCloseTo(0.0, 1e-12);
      check(w0.evaluate({'x': math.e})).isCloseTo(1.0, 1e-12);
      check(w0.evaluate({'x': -invE})).isCloseTo(-1.0, 1e-12);
      check(wNeg.evaluate({'x': -invE})).isCloseTo(-1.0, 1e-12);
      check(() => w0.evaluate({'x': -0.5})).throws<RangeError>();
      check(() => wNeg.evaluate({'x': 0.1})).throws<RangeError>();
    });
  });

  group('LambertW complex evaluation', () {
    test('real inputs match real branch', () {
      const w = LambertW(Variable('x'));
      final c0 = w.evaluateComplex({'x': const Complex(0.0, 0.0)});
      check(c0.a).isCloseTo(0.0, 1e-12);
      check(c0.b).isCloseTo(0.0, 1e-12);

      final ce = w.evaluateComplex({'x': const Complex(math.e, 0.0)});
      check(ce.a).isCloseTo(1.0, 1e-12);
      check(ce.b).isCloseTo(0.0, 1e-12);
    });

    test('complex inputs satisfy W(z) * exp(W(z)) == z', () {
      const z = Complex(1.0, 2.0);
      final w = evaluateComplexLambertW(z, 0);
      final product = w * w.exp();
      check(product.a).isCloseTo(z.a, 1e-10);
      check(product.b).isCloseTo(z.b, 1e-10);
    });
  });

  group('LambertW series expansions', () {
    test('Puiseux series around branch point -1/e', () {
      final p0 = lambertWPuiseuxSeries('x', branch: 0, order: 3);
      final pNeg = lambertWPuiseuxSeries('x', branch: -1, order: 3);
      check(p0.dependsOn('x')).isTrue();
      check(pNeg.dependsOn('x')).isTrue();
    });

    test('De Bruijn asymptotic expansion', () {
      final asymp = lambertWAsymptoticExpansion('x', order: 3);
      check(asymp.dependsOn('x')).isTrue();
    });
  });

  group('LambertW formatting', () {
    test('toString formatting', () {
      const w0 = LambertW(Variable('x'), branch: 0);
      const wNeg = LambertW(Variable('x'), branch: -1);
      check(w0.toString()).equals('LambertW(x)');
      check(wNeg.toString()).equals('LambertW(x, -1)');
    });

    test('LaTeX formatting', () {
      const w0 = LambertW(Variable('x'), branch: 0);
      const wNeg = LambertW(Variable('x'), branch: -1);
      check(w0.toLatex()).equals(r'W(x)');
      check(wNeg.toLatex()).equals(r'W_{-1}(x)');
    });

    test('MathML formatting', () {
      const w0 = LambertW(Variable('x'), branch: 0);
      check(w0.toMathMl()).contains('W');
    });
  });
}
