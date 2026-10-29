import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/test.dart';

void main() {
  group('Constant built-ins', () {
    test('pi, e, infinity, and undefined properties and evaluation', () {
      check(Constant.pi.name).equals('pi');
      check(Constant.pi.isSimplified).isTrue();
      check(Constant.pi.isReal).isTrue();
      check(Constant.pi.evaluate()).isCloseTo(math.pi, 1e-15);
      check(Constant.e.evaluate()).isCloseTo(math.e, 1e-15);
      check(Constant.infinity.evaluate()).equals(double.infinity);
      check(Constant.infinity.isReal).isFalse();
      check(Constant.undefined.evaluate().isNaN).isTrue();
      check(Constant.undefined.isReal).isFalse();

      check(Im(Constant.undefined).simplify()).equals(Constant.undefined);
      check(Re(Constant.undefined).simplify()).equals(Constant.undefined);
      check(Conjugate(Constant.undefined).simplify())
          .equals(Constant.undefined);
      check(Arg(Constant.undefined).simplify()).equals(Constant.undefined);
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
        check(Constant.undefined == dynUndef).isTrue();
        check(Constant.pi == dynPi).isTrue();
        check(Constant.undefined.hashCode).equals(dynUndef.hashCode);
        check(Constant.pi.hashCode).equals(dynPi.hashCode);

        const complexConst = Constant(
          'omega',
          Complex(-0.5, 0.8660254037844386),
        );
        check(complexConst.isReal).isFalse();
        check(complexConst.latex).equals('omega');
        check(complexConst.mathMl).equals('<mi>omega</mi>');
        check(complexConst.freeVariables).isEmpty();
        check(complexConst.dependsOn('x')).isFalse();
        check(complexConst.substitute('x', IntegerNumber.one))
            .equals(complexConst);
        check(complexConst.mapChildren((e) => IntegerNumber.one))
            .equals(complexConst);
        check(complexConst.anyNode((e) => e == complexConst)).isTrue();
        check(() => complexConst.evaluate()).throws<UnsupportedError>();
      },
    );
  });
}
