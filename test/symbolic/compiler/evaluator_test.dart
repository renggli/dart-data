import 'package:checks/checks.dart';
import 'package:data/src/symbolic/compiler/bytecode.dart';
import 'package:data/symbolic.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/test.dart';

void main() {
  group('Real and Complex VM opcodes', () {
    test('evaluates all elementary, hyperbolic, inverse hyperbolic, and special function opcodes', () {
      const x = Variable('x');
      const y = Variable('y');

      final unaryCases = <(Expr, double, Complex)>[
        (-x, 2.0, const Complex(2.0, -1.0)),
        (Pow(Constant.e, x), 0.5, const Complex(0.5, 0.3)),
        (Pow(x, FractionNumber.half), 4.0, const Complex(3.0, 4.0)),
        (Pow(x, const RealNumber(0.5)), 9.0, const Complex(4.0, 0.0)),
        (Pow(x, IntegerNumber.negativeOne), 2.0, const Complex(1.0, 1.0)),
        (Pow(x, const RealNumber(2.5)), 2.0, const Complex(2.0, 1.0)),
        (Sin(x), 0.6, const Complex(0.6, 0.2)),
        (Cos(x), 0.6, const Complex(0.6, 0.2)),
        (Tan(x), 0.6, const Complex(0.6, 0.2)),
        (Asin(x), 0.5, const Complex(0.5, 0.2)),
        (Acos(x), 0.5, const Complex(0.5, 0.2)),
        (Atan(x), 0.5, const Complex(0.5, 0.2)),
        (Sinh(x), 1e-7, const Complex(0.4, 0.2)),
        (Sinh(x), 0.8, const Complex(0.8, 0.2)),
        (Cosh(x), 0.8, const Complex(0.8, 0.2)),
        (Tanh(x), 0.8, const Complex(0.8, 0.2)),
        (Tanh(x), 25.0, const Complex(5.0, 0.0)),
        (Tanh(x), -25.0, const Complex(-5.0, 0.0)),
        (Asinh(x), 0.8, const Complex(0.8, 0.2)),
        (Acosh(x), 2.0, const Complex(2.0, 0.5)),
        (Atanh(x), 0.5, const Complex(0.5, 0.2)),
        (Abs(x), -3.5, const Complex(3.0, 4.0)),
        (Ln(x), 2.5, const Complex(2.5, 1.0)),
        (LambertW(x), 1.0, const Complex(1.0)),
        (LambertW(x, branch: -1), -0.2, const Complex(-0.2)),
        (Erf(x), 0.5, const Complex(0.5)),
        (Erfc(x), 0.5, const Complex(0.5)),
        (Gamma(x), 3.5, const Complex(3.5)),
        (const OrderTerm('x', 3), 2.0, const Complex(2.0, 1.0)),
      ];

      for (final (node, realIn, complexIn) in unaryCases) {
        final eval = compileToBytecode(node, ['x'], optimize: false);
        final realExpected = node.evaluate({'x': realIn});
        check(eval.evaluate1D(realIn)).isCloseTo(realExpected, 1e-12);

        final complexExpected = node.evaluateComplex({'x': complexIn});
        final complexActual = eval.evaluateComplex1D(complexIn);
        check(complexActual.a).isCloseTo(complexExpected.a, 1e-12);
        check(complexActual.b).isCloseTo(complexExpected.b, 1e-12);
      }

      final betaNode = Beta(x, y);
      final betaEval = compileToBytecode(betaNode, ['x', 'y']);
      check(betaEval.evaluateList([2.0, 3.0])).isCloseTo(1.0 / 12.0, 1e-12);
      check(
        betaEval.evaluateComplexList([
          const Complex(2.0),
          const Complex(3.0),
        ]).a,
      ).isCloseTo(1.0 / 12.0, 1e-12);
    });
  });

  group('VM boundary cases and control flow', () {
    test('boundary cases for Gamma, Acosh, Atanh, Pow, and special functions in VM', () {
      const x = Variable('x');
      const y = Variable('y');

      final gammaEval = compileToBytecode(Gamma(x), ['x']);
      check(() => gammaEval.evaluate1D(0.0)).throws<ArgumentError>();
      check(() => gammaEval.evaluate1D(-2.0)).throws<ArgumentError>();
      check(() => gammaEval.evaluateComplex1D(const Complex(1, 1)))
          .throws<UnsupportedError>();

      final acoshEval = compileToBytecode(Acosh(x), ['x']);
      check(acoshEval.evaluate1D(0.5).isNaN).isTrue();

      final atanhEval = compileToBytecode(Atanh(x), ['x']);
      check(atanhEval.evaluate1D(1.5).isNaN).isTrue();
      check(atanhEval.evaluate1D(-1.5).isNaN).isTrue();
      check(atanhEval.evaluate1D(1.0)).equals(double.infinity);
      check(atanhEval.evaluate1D(-1.0)).equals(double.negativeInfinity);

      check(
        () => compileToBytecode(LambertW(x), [
          'x',
        ]).evaluateComplex1D(const Complex(1, 1)),
      ).throws<UnsupportedError>();
      check(
        () => compileToBytecode(LambertW(x, branch: -1), [
          'x',
        ]).evaluateComplex1D(const Complex(-0.2, 1)),
      ).throws<UnsupportedError>();
      check(
        () => compileToBytecode(Erf(x), [
          'x',
        ]).evaluateComplex1D(const Complex(1, 1)),
      ).throws<UnsupportedError>();
      check(
        () => compileToBytecode(Erfc(x), [
          'x',
        ]).evaluateComplex1D(const Complex(1, 1)),
      ).throws<UnsupportedError>();
      check(
        () => compileToBytecode(Beta(x, y), [
          'x',
          'y',
        ]).evaluateComplexList([const Complex(1, 1), const Complex(2, 0)]),
      ).throws<UnsupportedError>();

      final powEval = compileToBytecode(Pow(x, y), ['x', 'y'], optimize: false);
      check(powEval.evaluateComplexList([const Complex(2, 3), Complex.zero]))
          .equals(Complex.one);
      check(powEval.evaluateComplexList([Complex.zero, const Complex(2, 0)]))
          .equals(Complex.zero);
      check(powEval.evaluateComplexList([Complex.zero, const Complex(-2, 0)]).a)
          .equals(double.infinity);
      check(
        powEval.evaluateComplexList([Complex.zero, const Complex(0, 1)]).isNaN,
      ).isTrue();
      check(powEval.evaluateComplexList([const Complex(2, 1), Complex.one]))
          .equals(const Complex(2, 1));
      check(
        powEval.evaluateComplexList([const Complex(1, 1), const Complex(2, 0)]),
      ).equals(const Complex(0, 2));
      check(
        powEval.evaluateComplexList([
          const Complex(0, 1),
          const Complex(-1, 0),
        ]),
      ).equals(const Complex(0, -1));
      check(
        powEval.evaluateComplexList([const Complex(0, 1), const Complex(3, 0)]),
      ).equals(const Complex(0, -1));
      check(
        powEval.evaluateComplexList([
          const Complex(0, 1),
          const Complex(-3, 0),
        ]),
      ).equals(const Complex(0, 1));
      final binomEval = compileToBytecode(Binomial(x, y), ['x', 'y']);
      check(binomEval.evaluateList([5.0, 2.0])).isCloseTo(10.0, 1e-12);
      check(binomEval.evaluateList([double.nan, 2.0])).isNaN();
      check(binomEval.evaluateList([5.0, -1.0])).equals(0.0);
      check(binomEval.evaluateList([3.0, 5.0])).equals(0.0);
      check(
        binomEval.evaluateComplexList([
          const Complex(5.0),
          const Complex(2.0),
        ]).a,
      ).isCloseTo(10.0, 1e-12);
      check(
        () => binomEval.evaluateComplexList([
          const Complex(1, 1),
          const Complex(2, 0),
        ]),
      ).throws<UnsupportedError>();

      final modEval = compileToBytecode(Mod(x, y), ['x', 'y']);
      check(modEval.evaluateList([17.0, 5.0])).equals(2.0);
      check(modEval.evaluateList([17.0, 0.0])).isNaN();
      check(
        modEval.evaluateComplexList([const Complex(17.0), const Complex(5.0)]),
      ).equals(const Complex(2.0));
      check(
        () => modEval.evaluateComplexList([
          const Complex(1, 1),
          const Complex(2, 0),
        ]),
      ).throws<UnsupportedError>();

      for (final node in <Expr>[Factorial(x), Floor(x), Ceil(x), Round(x)]) {
        final eval = compileToBytecode(node, ['x']);
        check(eval.evaluate1D(3.5)).isCloseTo(node.evaluate({'x': 3.5}), 1e-12);
        check(eval.evaluateComplex1D(const Complex(3.5)).a)
            .isCloseTo(node.evaluate({'x': 3.5}), 1e-12);
        check(() => eval.evaluateComplex1D(const Complex(1, 1)))
            .throws<UnsupportedError>();
      }

      final signEval = compileToBytecode(Sign(x), ['x']);
      check(signEval.evaluate1D(0.0)).equals(0.0);
      check(signEval.evaluate1D(-2.0)).equals(-1.0);
      check(signEval.evaluate1D(2.0)).equals(1.0);
      check(signEval.evaluateComplex1D(Complex.zero)).equals(Complex.zero);
      check(signEval.evaluateComplex1D(const Complex(-2.0)))
          .equals(const Complex(-1.0));
      check(signEval.evaluateComplex1D(const Complex(3.0, 4.0)))
          .equals(const Complex(0.6, 0.8));

      final reEval = compileToBytecode(Re(x), ['x'], optimize: false);
      final imEval = compileToBytecode(Im(x), ['x'], optimize: false);
      final argEval = compileToBytecode(Arg(x), ['x'], optimize: false);
      final conjEval = compileToBytecode(Conjugate(x), ['x'], optimize: false);
      check(reEval.evaluate1D(3.0)).equals(3.0);
      check(imEval.evaluate1D(3.0)).equals(0.0);
      check(argEval.evaluate1D(3.0)).equals(0.0);
      check(argEval.evaluate1D(-3.0)).isCloseTo(3.141592653589793, 1e-12);
      check(conjEval.evaluate1D(3.0)).equals(3.0);
      check(argEval.evaluateComplex1D(const Complex(0, 1)).a)
          .isCloseTo(1.5707963267948966, 1e-12);
    });

    test('relational, Piecewise, Integral, and direct Op.sub instructions', () {
      const x = Variable('x');
      final relations = <Expr>[
        LessThan(x, IntegerNumber.zero),
        LessEqual(x, IntegerNumber.zero),
        GreaterThan(x, IntegerNumber.zero),
        GreaterEqual(x, IntegerNumber.zero),
        Equal(x, IntegerNumber.zero),
        NotEqual(x, IntegerNumber.zero),
      ];

      for (final rel in relations) {
        final eval = compileToBytecode(rel, ['x']);
        for (final v in [-1.0, 0.0, 1.0]) {
          check(eval.evaluate1D(v)).equals(rel.evaluate({'x': v}));
          check(eval.evaluateComplex1D(Complex(v)))
              .equals(rel.evaluateComplex({'x': Complex(v)}));
        }
      }

      final pwNoOtherwise = compileToBytecode(
        Piecewise([(relation: LessThan(x, IntegerNumber.zero), expr: -x)]),
        ['x'],
      );
      check(pwNoOtherwise.evaluate1D(-2.0)).equals(2.0);
      check(pwNoOtherwise.evaluate1D(2.0).isNaN).isTrue();
      check(pwNoOtherwise.evaluateComplex1D(const Complex(-2.0)))
          .equals(const Complex(2.0));
      check(pwNoOtherwise.evaluateComplex1D(const Complex(2.0)).isNaN).isTrue();

      final intEval = compileToBytecode(
        Integral(const Variable('t'), 't', lower: IntegerNumber.zero, upper: x),
        ['x'],
      );
      check(intEval.evaluateComplex1D(const Complex(2.0)).a)
          .isCloseTo(2.0, 1e-12);

      final subEval = BytecodeEvaluator(
        variables: const ['x', 'y'],
        instructions: const [
          Instruction.loadVar(0),
          Instruction.loadVar(1),
          Instruction.op(Op.sub),
        ],
        maxStack: 4,
        registerCount: 0,
      );
      check(subEval.evaluateList([7.0, 2.5])).equals(4.5);
      check(
        subEval.evaluateComplexList([const Complex(7, 3), const Complex(2, 1)]),
      ).equals(const Complex(5, 2));
    });
  });

  group('Direct evaluateComplex extension', () {
    test('evaluates arithmetic, powers, and elementary functions in C', () {
      const x = Variable('x');
      check(() => x.evaluateComplex({})).throws<ArgumentError>();

      check(Constant.pi.evaluateComplex())
          .equals(const Complex(3.141592653589793));
      check(
        (x + ComplexNumber.i * 2).evaluateComplex({'x': const Complex(3, 1)}),
      ).equals(const Complex(3, 3));

      check(
        Pow(x, IntegerNumber.zero).evaluateComplex({'x': const Complex(2, 3)}),
      ).equals(Complex.one);
      check(Pow(IntegerNumber.zero, IntegerNumber.two).evaluateComplex())
          .equals(Complex.zero);
      check(
        Pow(IntegerNumber.zero, IntegerNumber.negativeOne).evaluateComplex().a,
      ).equals(double.infinity);
      check(Pow(IntegerNumber.zero, ComplexNumber.i).evaluateComplex().isNaN)
          .isTrue();
      check(
        Pow(x, IntegerNumber.one).evaluateComplex({'x': const Complex(2, 3)}),
      ).equals(const Complex(2, 3));
      check(
        Pow(x, IntegerNumber.two).evaluateComplex({'x': const Complex(1, 1)}),
      ).equals(const Complex(0, 2));
      check(
        Pow(
          x,
          IntegerNumber.negativeOne,
        ).evaluateComplex({'x': const Complex(0, 1)}),
      ).equals(const Complex(0, -1));
      check(
        Pow(x, IntegerNumber.of(3)).evaluateComplex({'x': const Complex(0, 1)}),
      ).equals(const Complex(0, -1));
      check(
        Pow(
          x,
          IntegerNumber.of(-3),
        ).evaluateComplex({'x': const Complex(0, 1)}),
      ).equals(const Complex(0, 1));
      check(Pow(x, ComplexNumber.i).evaluateComplex({'x': Complex.one}))
          .equals(Complex.one);

      const z = Complex(0.4, 0.3);
      check(Sin(x).evaluateComplex({'x': z})).equals(z.sin());
      check(Cos(x).evaluateComplex({'x': z})).equals(z.cos());
      check(Tan(x).evaluateComplex({'x': z})).equals(z.tan());
      check(Asin(x).evaluateComplex({'x': z})).equals(z.asin());
      check(Acos(x).evaluateComplex({'x': z})).equals(z.acos());
      check(Atan(x).evaluateComplex({'x': z})).equals(z.atan());
      check(Sinh(x).evaluateComplex({'x': z})).equals(z.sinh());
      check(Cosh(x).evaluateComplex({'x': z})).equals(z.cosh());
      check(Tanh(x).evaluateComplex({'x': z})).equals(z.tanh());
      check(Ln(x).evaluateComplex({'x': z})).equals(z.log());
      check(Abs(x).evaluateComplex({'x': const Complex(3, 4)}))
          .equals(const Complex(5));

      final asinhZ = Asinh(x).evaluateComplex({'x': z});
      check(Sinh(x).evaluateComplex({'x': asinhZ}).a).isCloseTo(z.a, 1e-12);
      check(Sinh(x).evaluateComplex({'x': asinhZ}).b).isCloseTo(z.b, 1e-12);

      const z2 = Complex(1.5, 0.5);
      final acoshZ = Acosh(x).evaluateComplex({'x': z2});
      check(Cosh(x).evaluateComplex({'x': acoshZ}).a).isCloseTo(z2.a, 1e-12);
      check(Cosh(x).evaluateComplex({'x': acoshZ}).b).isCloseTo(z2.b, 1e-12);

      final atanhZ = Atanh(x).evaluateComplex({'x': z});
      check(Tanh(x).evaluateComplex({'x': atanhZ}).a).isCloseTo(z.a, 1e-12);
      check(Tanh(x).evaluateComplex({'x': atanhZ}).b).isCloseTo(z.b, 1e-12);
    });

    test(
      'evaluates special functions, Piecewise, Integral, and OrderTerm in C',
      () {
        const x = Variable('x');
        const y = Variable('y');
        const realZ = Complex(0.5);
        const nonRealZ = Complex(0.5, 1.0);

        check(Erf(x).evaluateComplex({'x': realZ}).a)
            .isCloseTo(Erf(x).evaluate({'x': 0.5}), 1e-14);
        check(() => Erf(x).evaluateComplex({'x': nonRealZ}))
            .throws<UnsupportedError>();

        check(Erfc(x).evaluateComplex({'x': realZ}).a)
            .isCloseTo(Erfc(x).evaluate({'x': 0.5}), 1e-14);
        check(() => Erfc(x).evaluateComplex({'x': nonRealZ}))
            .throws<UnsupportedError>();

        check(Gamma(x).evaluateComplex({'x': const Complex(4.0)}).a)
            .isCloseTo(6.0, 1e-12);
        check(() => Gamma(x).evaluateComplex({'x': nonRealZ}))
            .throws<UnsupportedError>();

        check(
          Beta(x, y).evaluateComplex({
            'x': const Complex(2.0),
            'y': const Complex(3.0),
          }).a,
        ).isCloseTo(1.0 / 12.0, 1e-12);
        check(() => Beta(x, y).evaluateComplex({'x': nonRealZ, 'y': realZ}))
            .throws<UnsupportedError>();

        check(() => LambertW(x).evaluateComplex({'x': nonRealZ}))
            .throws<UnsupportedError>();

        final pw = Piecewise([
          (relation: LessThan(x, IntegerNumber.zero), expr: -x),
        ], otherwise: x);
        check(pw.evaluateComplex({'x': const Complex(-2)}))
            .equals(const Complex(2));
        check(pw.evaluateComplex({'x': const Complex(3)}))
            .equals(const Complex(3));

        final defInt = Integral(
          x,
          'x',
          lower: IntegerNumber.zero,
          upper: IntegerNumber.two,
        );
        check(defInt.evaluateComplex().a).isCloseTo(2.0, 1e-12);
        check(Integral(x, 'x').evaluateComplex().isNaN).isTrue();
        check(Derivative(x, 'x').evaluateComplex().isNaN).isTrue();
        check(Limit(x, 'x', IntegerNumber.zero).evaluateComplex().isNaN)
            .isTrue();
        check(const OrderTerm('x', 3).evaluateComplex()).equals(Complex.zero);
      },
    );
  });
}
