import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:data/type.dart' show Complex;
import 'package:test/scaffolding.dart';

void main() {
  group('Erf & Erfc evaluation and properties', () {
    test('Erf known values', () {
      const erf0 = Erf(Variable('x'));
      check(erf0.evaluate({'x': 0.0})).isCloseTo(0.0, 1e-12);
      check(erf0.evaluate({'x': 1.0})).isCloseTo(0.8427007929497148, 1e-7);
      check(erf0.evaluate({'x': -1.0})).isCloseTo(-0.8427007929497148, 1e-7);
    });

    test('Erfc known values', () {
      const erfc0 = Erfc(Variable('x'));
      check(erfc0.evaluate({'x': 0.0})).isCloseTo(1.0, 1e-12);
      check(erfc0.evaluate({'x': 1.0}))
          .isCloseTo(1.0 - 0.8427007929497148, 1e-7);
    });

    test('Erf and Erfc complex evaluation', () {
      const erfNode = Erf(Variable('z'));
      const erfcNode = Erfc(Variable('z'));
      final c0 = erfNode.evaluateComplex({'z': const Complex(0.0, 0.0)});
      check(c0.a).isCloseTo(0.0, 1e-12);
      check(c0.b).isCloseTo(0.0, 1e-12);

      final cErfc0 = erfcNode.evaluateComplex({'z': const Complex(0.0, 0.0)});
      check(cErfc0.a).isCloseTo(1.0, 1e-12);
    });
  });

  group('Gamma & Beta evaluation and singularities', () {
    test('Gamma integer factorial values', () {
      const gammaNode = Gamma(Variable('x'));
      check(gammaNode.evaluate({'x': 1.0})).isCloseTo(1.0, 1e-12);
      check(gammaNode.evaluate({'x': 2.0})).isCloseTo(1.0, 1e-12);
      check(gammaNode.evaluate({'x': 3.0})).isCloseTo(2.0, 1e-12);
      check(gammaNode.evaluate({'x': 4.0})).isCloseTo(6.0, 1e-12);
      check(gammaNode.evaluate({'x': 5.0})).isCloseTo(24.0, 1e-12);
    });

    test('Gamma half-integer value Gamma(1/2) = sqrt(pi)', () {
      const gammaNode = Gamma(Variable('x'));
      check(gammaNode.evaluate({'x': 0.5}))
          .isCloseTo(math.sqrt(math.pi), 1e-10);
    });

    test('Gamma non-positive integer singularity throws ArgumentError', () {
      const gammaNode = Gamma(Variable('x'));
      check(() => gammaNode.evaluate({'x': 0.0})).throws<ArgumentError>();
      check(() => gammaNode.evaluate({'x': -1.0})).throws<ArgumentError>();
      check(() => gammaNode.evaluate({'x': -2.0})).throws<ArgumentError>();
      check(() => gammaNode.evaluate({'x': -3.0})).throws<ArgumentError>();
    });

    test('Gamma negative non-integer evaluation Gamma(-1/2) = -2*sqrt(pi)', () {
      const gammaNode = Gamma(Variable('x'));
      check(gammaNode.evaluate({'x': -0.5}))
          .isCloseTo(-2.0 * math.sqrt(math.pi), 1e-10);
    });

    test('Beta function values', () {
      const betaNode = Beta(Variable('x'), Variable('y'));
      check(betaNode.evaluate({'x': 1.0, 'y': 1.0})).isCloseTo(1.0, 1e-12);
      check(betaNode.evaluate({'x': 2.0, 'y': 3.0}))
          .isCloseTo(1.0 / 12.0, 1e-10);
    });
  });

  group('Inverse hyperbolic evaluation and domains', () {
    test('Asinh values across domain', () {
      const asinhNode = Asinh(Variable('x'));
      check(asinhNode.evaluate({'x': 0.0})).isCloseTo(0.0, 1e-12);
      check(asinhNode.evaluate({'x': 1.0}))
          .isCloseTo(math.log(1.0 + math.sqrt(2.0)), 1e-12);
      check(asinhNode.evaluate({'x': -1.0}))
          .isCloseTo(-math.log(1.0 + math.sqrt(2.0)), 1e-12);
    });

    test('Acosh domain validation (x >= 1)', () {
      const acoshNode = Acosh(Variable('x'));
      check(acoshNode.evaluate({'x': 1.0})).isCloseTo(0.0, 1e-12);
      check(acoshNode.evaluate({'x': 2.0}))
          .isCloseTo(math.log(2.0 + math.sqrt(3.0)), 1e-12);
      check(() => acoshNode.evaluate({'x': 0.5})).throws<ArgumentError>();
      check(() => acoshNode.evaluate({'x': -1.0})).throws<ArgumentError>();
    });

    test('Atanh domain validation (|x| < 1)', () {
      const atanhNode = Atanh(Variable('x'));
      check(atanhNode.evaluate({'x': 0.0})).isCloseTo(0.0, 1e-12);
      check(atanhNode.evaluate({'x': 0.5}))
          .isCloseTo(0.5 * math.log(3.0), 1e-12);
      check(() => atanhNode.evaluate({'x': 1.0})).throws<ArgumentError>();
      check(() => atanhNode.evaluate({'x': 1.5})).throws<ArgumentError>();
      check(() => atanhNode.evaluate({'x': -1.0})).throws<ArgumentError>();
    });
  });

  group('Special functions substitution and formatting', () {
    test('substitutions update operands', () {
      const erfNode = Erf(Variable('x'));
      check(erfNode.substitute('x', const Variable('y')))
          .equals(const Erf(Variable('y')));

      const betaNode = Beta(Variable('x'), Variable('y'));
      check(betaNode.substitute('x', const Variable('u')))
          .equals(const Beta(Variable('u'), Variable('y')));
    });

    test('formatting and LaTeX', () {
      check(const Erf(Variable('x')).toString()).equals('erf(x)');
      check(const Erfc(Variable('x')).toString()).equals('erfc(x)');
      check(const Gamma(Variable('x')).toString()).equals('gamma(x)');
      check(const Beta(Variable('a'), Variable('b')).toString())
          .equals('beta(a, b)');
      check(const Asinh(Variable('x')).toString()).equals('asinh(x)');
      check(const Acosh(Variable('x')).toString()).equals('acosh(x)');
      check(const Atanh(Variable('x')).toString()).equals('atanh(x)');

      check(const Erf(Variable('x')).toLatex())
          .equals(r'\operatorname{erf}(x)');
      check(const Gamma(Variable('x')).toLatex()).equals(r'\Gamma(x)');
      check(const Beta(Variable('a'), Variable('b')).toLatex())
          .equals(r'\operatorname{B}(a, b)');
    });
  });
}
