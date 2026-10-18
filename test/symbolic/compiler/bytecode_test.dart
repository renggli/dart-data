import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/src/symbolic/compiler/bytecode.dart';
import 'package:data/symbolic.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/test.dart';

void main() {
  group('Bytecode compiler and CSE', () {
    test('deduplicates shared composite subtrees into registers', () {
      final sub = Expr.parse('sin(x^2 + 3*x + 1)');
      final pw = Piecewise([
        (relation: LessThan(sub, IntegerNumber.zero), expr: -sub),
      ], otherwise: sub);
      final integral = Integral(
        sub,
        't',
        lower: IntegerNumber.zero,
        upper: IntegerNumber.one,
      );
      final expr = sub + Pow(sub, IntegerNumber.two) + Cos(sub) + pw + integral;

      final optEval = compileToBytecode(expr.simplify(), ['x'], optimize: true);
      final unoptEval = compileToBytecode(expr.simplify(), [
        'x',
      ], optimize: false);

      check(optEval.registerCount).isGreaterThan(0);
      check(unoptEval.registerCount).equals(0);
      check(optEval.instructions.length)
          .isLessThan(unoptEval.instructions.length);

      for (final xVal in [-1.5, 0.0, 0.75, 2.5]) {
        final expected = expr.evaluate({'x': xVal});
        check(optEval.evaluate1D(xVal)).isCloseTo(expected, 1e-12);
        check(unoptEval.evaluate1D(xVal)).isCloseTo(expected, 1e-12);
        check(optEval.evaluateMap({'x': xVal})).isCloseTo(expected, 1e-12);
        check(optEval.evaluateComplex1D(Complex(xVal)).a)
            .isCloseTo(expected, 1e-12);
        check(unoptEval.evaluateComplex1D(Complex(xVal)).a)
            .isCloseTo(expected, 1e-12);
      }
    });

    test('dynamic variable discovery and unbound variable errors', () {
      const x = Variable('x');
      final dynEval = compileToBytecode(
        Add([
          x,
          Integral(
            const Variable('y'),
            't',
            lower: IntegerNumber.zero,
            upper: IntegerNumber.one,
          ),
        ]),
        const [],
        allowDynamicVars: true,
      );
      check(dynEval.variables).unorderedEquals(['x', 'y']);
      check(dynEval.evaluateMap({'x': 2.0, 'y': 3.0})).isCloseTo(5.0, 1e-12);

      check(() => compileToBytecode(x, const [], allowDynamicVars: false))
          .throws<ArgumentError>();
      check(
        () => compileToBytecode(
          Integral(x, 't', lower: IntegerNumber.zero, upper: x),
          const [],
          allowDynamicVars: false,
        ),
      ).throws<ArgumentError>();
    });
  });

  group('Degenerate AST nodes in bytecode compilation', () {
    test('compiles empty Add, empty Mul, and Constant leaves', () {
      check(compileToBytecode(Constant.pi, const []).evaluateList(const []))
          .isCloseTo(math.pi, 1e-15);
      check(compileToBytecode(Add(const []), const []).evaluateList(const []))
          .equals(0.0);
      check(compileToBytecode(Mul(const []), const []).evaluateList(const []))
          .equals(1.0);
    });
  });
}
