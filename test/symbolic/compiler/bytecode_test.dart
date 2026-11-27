import 'dart:math' as math;
import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/src/symbolic/compiler/bytecode.dart';
import 'package:data/symbolic.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/scaffolding.dart';

void main() {
  group('Bytecode compiler and shared subexpressions', () {
    test('deduplicates shared composite subtrees into registers', () {
      final sub = Expr.parse('sin(x^2 + 3*x + 1)');
      final pw = Piecewise([
        (relation: Relational.lessThan(sub, IntegerNumber.zero), expr: -sub),
      ], otherwise: sub);
      final integral = Integral(
        sub,
        't',
        lower: IntegerNumber.zero,
        upper: IntegerNumber.one,
      );
      final expr =
          sub + Pow.of(sub, IntegerNumber.two) + Fn.cos(sub) + pw + integral;

      final optEval = compileToBytecode(expr.simplify(), ['x'], optimize: true);
      final unoptEval = compileToBytecode(expr.simplify(), [
        'x',
      ], optimize: false);

      check(optEval.sharedCount).isGreaterThan(0);
      check(unoptEval.sharedCount).equals(0);
      check(optEval.instructionCount).isLessThan(unoptEval.instructionCount);
      check(optEval.disassemble().length).equals(optEval.instructionCount);

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

    test('shared registers in Piecewise branches are not assumed initialized across branches', () {
      final pwExpr = Expr.parse('piecewise(x > 0, sin(x) + 1, sin(x) - 1)');
      final fn = pwExpr.toFunction1D('x');
      final valPos = fn(math.pi / 2);
      check(valPos).isCloseTo(2.0, 1e-12);
      final valNeg = fn(-math.pi / 2);
      check(valNeg).isCloseTo(-2.0, 1e-12);
    });

    test('dynamic variable discovery and unbound variable errors', () {
      const x = Variable('x');
      final dynEval = compileToBytecode(
        Add.of([
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
    test('compiles empty Add, empty Mul, Constant, and powInt fast paths', () {
      check(compileToBytecode(Constant.pi, const []).evaluateList(const []))
          .isCloseTo(math.pi, 1e-15);
      check(
        compileToBytecode(Add.of(const []), const []).evaluateList(const []),
      ).equals(0.0);
      check(
        compileToBytecode(Mul.of(const []), const []).evaluateList(const []),
      ).equals(1.0);
      const x = Variable('x');
      final powEval = compileToBytecode(Pow.of(x, IntegerNumber.of(7)), const [
        'x',
      ]);
      check(powEval.disassemble().single).contains('powInt');
      check(powEval.evaluate1D(2.0)).equals(128.0);
    });

    test('reuses temporary registers across disjoint Piecewise branches', () {
      const x = Variable('x');
      final pw4 = Piecewise([
        (
          relation: Relational.lessThan(x, IntegerNumber.one),
          expr: IntegerNumber.of(10),
        ),
        (
          relation: Relational.lessThan(x, IntegerNumber.two),
          expr: IntegerNumber.of(20),
        ),
        (
          relation: Relational.lessThan(x, IntegerNumber.of(3)),
          expr: IntegerNumber.of(30),
        ),
        (
          relation: Relational.lessThan(x, IntegerNumber.of(4)),
          expr: IntegerNumber.of(40),
        ),
      ], otherwise: IntegerNumber.of(50));
      final pw10 = Piecewise([
        for (var i = 1; i <= 10; i++)
          (
            relation: Relational.lessThan(x, IntegerNumber.of(i)),
            expr: IntegerNumber.of(i),
          ),
      ], otherwise: IntegerNumber.zero);
      final eval4 = compileToBytecode(pw4, const ['x']);
      final eval10 = compileToBytecode(pw10, const ['x']);
      check(eval4.registerCount - eval4.constCount)
          .equals(eval10.registerCount - eval10.constCount);
      check(eval4.registerCount - eval4.constCount).isLessThan(5);
      check(eval10.evaluate1D(3.5)).equals(4.0);
      check(eval10.evaluate1D(20.0)).equals(0.0);
    });

    test('evaluates powInt for negative and complex powers cleanly', () {
      const x = Variable('x');
      final negCube = compileToBytecode(Pow.of(x, IntegerNumber.of(-3)), const [
        'x',
      ]);
      check(negCube.disassemble().single).contains('powInt');
      check(negCube.evaluate1D(2.0)).isCloseTo(0.125, 1e-15);
      check(negCube.evaluate1D(0.0).isInfinite).isTrue;
      check(negCube.evaluateComplex1D(Complex.i)).equals(Complex.i);
      check(negCube.evaluateComplex1D(Complex.zero).a.isInfinite).isTrue;

      final zeroPow = compileToBytecode(Pow.raw(x, IntegerNumber.zero), const [
        'x',
      ]);
      check(zeroPow.evaluate1D(0.0)).equals(1.0);
      check(zeroPow.evaluateComplex1D(Complex.zero)).equals(Complex.one);
    });

    test('evaluates tensor buffers and reentrant inner bytecode nodes', () {
      const x = Variable('x');
      final expr = Piecewise([
        (
          relation: Relational.greaterThan(x, IntegerNumber.zero),
          expr: Fn.sin(x) * Pow.of(Constant.e, -x) + Fn.sin(x),
        ),
      ], otherwise: x * x + IntegerNumber.one);
      final kernel = expr.compileTensorKernel(const ['x']);
      final input = Float64List.fromList([-2.0, -0.5, 0.5, 1.5]);
      final output = Float64List(4);
      kernel([input], output);
      for (var i = 0; i < input.length; i++) {
        check(output[i]).isCloseTo(expr.evaluate({'x': input[i]}), 1e-12);
      }

      const k = Variable('k');
      final nested = Sum(
        Integral(
          x + k,
          'x',
          lower: IntegerNumber.zero,
          upper: IntegerNumber.one,
        ),
        'k',
        IntegerNumber.one,
        IntegerNumber.of(3),
      );
      check(nested.evaluate()).isCloseTo(7.5, 1e-12);
    });
  });

  group('Disassembly metadata and register formatting', () {
    test(
      'exposes preloaded constants, shared bindings, and annotated disassembly',
      () {
        final expr = Expr.parse('sin(x + 3) + cos(x + 3) + 2');
        final eval = compileToBytecode(expr.simplify(), ['x'], optimize: true);

        check(eval.constants)
            .deepEquals([const Complex(2.0), const Complex(3.0)]);
        check(eval.sharedExpressions.length).equals(eval.sharedCount);
        check(
          eval.sharedExpressions.values.any((e) => e == Expr.parse('3 + x')),
        ).isTrue;
        check(eval.formatRegister(0)).equals('r0(x)');
        check(eval.formatRegister(1)).equals('r1(2)');
        check(eval.formatRegister(2)).equals('r2(3)');

        final lines = eval.disassemble();
        check(lines.length).equals(eval.instructionCount);
        check(lines.any((l) => l.contains('; shared: 3 + x'))).isTrue;
        check(lines.any((l) => l.contains('r1(2)'))).isTrue;
        check(lines.any((l) => l.contains('r2(3)'))).isTrue;
      },
    );

    test('formats complex constants and special values in formatRegister and hypergeometric disassembly', () {
      const x = Variable('x');
      final complexExpr = Piecewise([
        (
          relation: Relational.lessThan(x, Constant.infinity),
          expr:
              ComplexNumber.i * Fn.sin(x) +
              Fn.cos(
                x + ComplexNumber(IntegerNumber.two, IntegerNumber.of(-3)),
              ) +
              const RealNumber(1.5) * Fn.tan(x),
        ),
      ], otherwise: IntegerNumber.zero);
      final complexEval = compileToBytecode(complexExpr, [
        'x',
      ], optimize: false);
      final labels = [
        for (var i = 0; i < complexEval.constCount; i++)
          complexEval.formatRegister(1 + i),
      ];
      check(labels.any((l) => l.contains('(i)'))).isTrue;
      check(labels.any((l) => l.contains('(2-3*i)'))).isTrue;
      check(labels.any((l) => l.contains('(infinity)'))).isTrue;
      check(labels.any((l) => l.contains('(1.5)'))).isTrue;

      final hypEval = compileToBytecode(
        Fn.hypergeometric(
          Fn.tuple([IntegerNumber.one, IntegerNumber.two]),
          Fn.tuple([IntegerNumber.of(3)]),
          x,
        ),
        ['x'],
      );
      final hypLine = hypEval.disassemble().single;
      check(hypLine).contains('hypergeometric([r1(1), r2(2)], [r3(3)], r0(x))');

      final pwExpr = Expr.parse(
        'piecewise(x > 0, (x + 1)^2 + (x + 1)^3, (x + 1)^2 - 1)',
      );
      final pwEval = compileToBytecode(pwExpr.simplify(), [
        'x',
      ], optimize: true);
      check(pwEval.sharedExpressions).isNotEmpty;
    });
  });
}
