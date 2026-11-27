import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/scaffolding.dart';

void main() {
  group('Constant built-ins', () {
    test('pi, e, infinity, and undefined properties and evaluation', () {
      check(Constant.pi.name).equals('pi');
      check(Constant.pi.isReal).isTrue;
      check(Constant.pi.evaluate()).isCloseTo(math.pi, 1e-15);
      check(Constant.e.evaluate()).isCloseTo(math.e, 1e-15);
      check(Constant.infinity.evaluate()).equals(double.infinity);
      check(Constant.infinity.isReal).isFalse;
      check(Constant.undefined.evaluate().isNaN).isTrue;
      check(Constant.undefined.isReal).isFalse;

      check(Fn.im(Constant.undefined).simplify()).equals(Constant.undefined);
      check(Fn.re(Constant.undefined).simplify()).equals(Constant.undefined);
      check(Fn.conj(Constant.undefined).simplify()).equals(Constant.undefined);
      check(Fn.arg(Constant.undefined).simplify()).equals(Constant.undefined);
    });
  });

  group('Custom Constant and equality', () {
    test(
      'custom constants, structural equality, and complex evaluation error',
      () {
        // ignore: prefer_const_constructors
        final dynUndef = Constant(
          'undefined',
          Complex.nan,
          latex: r'\text{undefined}',
          mathMl: '<mtext>undefined</mtext>',
        );
        // ignore: prefer_const_constructors
        final dynPi = Constant(
          'pi',
          // ignore: prefer_const_constructors
          Complex(math.pi),
          latex: r'\pi',
          mathMl: '<mi>π</mi>',
        );
        check(Constant.undefined == dynUndef).isTrue;
        check(Constant.pi == dynPi).isTrue;
        check(Constant.undefined.hashCode).equals(dynUndef.hashCode);
        check(Constant.pi.hashCode).equals(dynPi.hashCode);

        const complexConst = Constant(
          'omega',
          Complex(-0.5, 0.8660254037844386),
        );
        check(complexConst.isReal).isFalse;
        check(complexConst.latex).equals('omega');
        check(complexConst.mathMl).equals('<mi>omega</mi>');
        check(complexConst.freeVariables).isEmpty;
        check(complexConst.dependsOn('x')).isFalse;
        check(complexConst.substitute('x', IntegerNumber.one))
            .equals(complexConst);
        check(complexConst.mapChildren((e) => IntegerNumber.one))
            .equals(complexConst);
        check(complexConst.anyNode((e) => e == complexConst)).isTrue;
        check(() => complexConst.evaluate()).throws<UnsupportedError>();
      },
    );

    test(
      'custom constants with built-in names stay isolated from built-ins',
      () {
        const customE = Constant('e', Complex(10));
        const customPi = Constant('pi', Complex(42));
        const customInf = Constant('infinity', Complex(99));
        const customUndef = Constant('undefined', Complex(7));

        check(customE == Constant.e).isFalse;
        check(customPi == Constant.pi).isFalse;
        check(customInf == Constant.infinity).isFalse;
        check(customUndef == Constant.undefined).isFalse;

        check(Fn.ln(customE).simplify()).equals(Fn.ln(customE));
        check(Fn.sin(customPi).simplify()).equals(Fn.sin(customPi));
        check((customInf - customInf).simplify()).equals(IntegerNumber.zero);
        check((customUndef + IntegerNumber.one).simplify())
            .equals(Add.of([IntegerNumber.one, customUndef]));

        check(customE.derivative('x')).equals(IntegerNumber.zero);
        check(customE.format()).equals('e');
        check(customPi.toLatex()).equals('pi');
        check(customPi.toMathMl()).equals('<math><mi>pi</mi></math>');

        check(customE.approximate()).equals(const RealNumber(10.0));
        check(customPi.approximate()).equals(const RealNumber(42.0));
        check(customInf.approximate()).equals(const RealNumber(99.0));
        check(customUndef.approximate()).equals(const RealNumber(7.0));
      },
    );
  });
}
