import 'dart:math' as math;
import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/src/symbolic/compiler/bytecode.dart';
import 'package:data/symbolic.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/scaffolding.dart';

void main() {
  group('Real and Complex VM opcodes', () {
    test('evaluates all elementary, hyperbolic, inverse hyperbolic, and special function opcodes', () {
      const x = Variable('x');
      const y = Variable('y');

      final unaryCases = <(Expr, double, Complex)>[
        (-x, 2.0, const Complex(2.0, -1.0)),
        (Pow.of(Constant.e, x), 0.5, const Complex(0.5, 0.3)),
        (Pow.of(x, FractionNumber.half), 4.0, const Complex(3.0, 4.0)),
        (Pow.of(x, const RealNumber(0.5)), 9.0, const Complex(4.0, 0.0)),
        (Pow.of(x, IntegerNumber.negativeOne), 2.0, const Complex(1.0, 1.0)),
        (Pow.of(x, const RealNumber(2.5)), 2.0, const Complex(2.0, 1.0)),
        (Fn.sin(x), 0.6, const Complex(0.6, 0.2)),
        (Fn.cos(x), 0.6, const Complex(0.6, 0.2)),
        (Fn.tan(x), 0.6, const Complex(0.6, 0.2)),
        (Fn.asin(x), 0.5, const Complex(0.5, 0.2)),
        (Fn.acos(x), 0.5, const Complex(0.5, 0.2)),
        (Fn.atan(x), 0.5, const Complex(0.5, 0.2)),
        (Fn.sinh(x), 1e-7, const Complex(0.4, 0.2)),
        (Fn.sinh(x), 0.8, const Complex(0.8, 0.2)),
        (Fn.cosh(x), 0.8, const Complex(0.8, 0.2)),
        (Fn.tanh(x), 0.8, const Complex(0.8, 0.2)),
        (Fn.tanh(x), 25.0, const Complex(5.0, 0.0)),
        (Fn.tanh(x), -25.0, const Complex(-5.0, 0.0)),
        (Fn.asinh(x), 0.8, const Complex(0.8, 0.2)),
        (Fn.acosh(x), 2.0, const Complex(2.0, 0.5)),
        (Fn.atanh(x), 0.5, const Complex(0.5, 0.2)),
        (Fn.abs(x), -3.5, const Complex(3.0, 4.0)),
        (Fn.ln(x), 2.5, const Complex(2.5, 1.0)),
        (Fn.lambertW(x), 1.0, const Complex(1.0)),
        (Fn.lambertW(x, IntegerNumber.negativeOne), -0.2, const Complex(-0.2)),
        (Fn.erf(x), 0.5, const Complex(0.5)),
        (Fn.erfc(x), 0.5, const Complex(0.5)),
        (Fn.gamma(x), 3.5, const Complex(3.5)),
        (Fn.zeta(x), 2.5, const Complex(2.5)),
        (Fn.digamma(x), 2.5, const Complex(2.5)),
        (Fn.ellipticK(x), 0.5, const Complex(0.5)),
        (Fn.ellipticE(x), 0.5, const Complex(0.5)),
        (OrderTerm('x', 3), 2.0, const Complex(2.0, 1.0)),
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

      final betaNode = Fn.beta(x, y);
      final betaEval = compileToBytecode(betaNode, ['x', 'y']);
      check(betaEval.evaluateList([2.0, 3.0])).isCloseTo(1.0 / 12.0, 1e-12);
      check(
        betaEval.evaluateComplexList([
          const Complex(2.0),
          const Complex(3.0),
        ]).a,
      ).isCloseTo(1.0 / 12.0, 1e-12);

      final polygammaNode = Fn.polygamma(x, y);
      final polygammaEval = compileToBytecode(polygammaNode, ['x', 'y']);
      check(polygammaEval.evaluateList([1.0, 1.0]))
          .isCloseTo(1.6449340668482264, 1e-12);

      final besselJNode = Fn.besselJ(x, y);
      final besselJEval = compileToBytecode(besselJNode, ['x', 'y']);
      check(besselJEval.evaluateList([0.0, 1.0]))
          .isCloseTo(0.7651976865579666, 1e-7);

      final besselYNode = Fn.besselY(x, y);
      final besselYEval = compileToBytecode(besselYNode, ['x', 'y']);
      check(besselYEval.evaluateList([0.0, 1.0]))
          .isCloseTo(0.08825696421567697, 1e-7);

      final besselINode = Fn.besselI(x, y);
      final besselIEval = compileToBytecode(besselINode, ['x', 'y']);
      check(besselIEval.evaluateList([0.0, 1.0]))
          .isCloseTo(1.2660658777520084, 1e-7);

      final besselKNode = Fn.besselK(x, y);
      final besselKEval = compileToBytecode(besselKNode, ['x', 'y']);
      check(besselKEval.evaluateList([0.0, 1.0]))
          .isCloseTo(0.42102443824070834, 1e-7);
    });
  });

  group('VM boundary cases and control flow', () {
    test('boundary cases for Gamma, Acosh, Atanh, Pow, and special functions in VM', () {
      const x = Variable('x');
      const y = Variable('y');

      final gammaEval = compileToBytecode(Fn.gamma(x), ['x']);
      check(gammaEval.evaluate1D(0.0)).isNaN;
      check(gammaEval.evaluate1D(-2.0)).isNaN;
      check(gammaEval.evaluateComplex1D(const Complex(1, 1)).isFinite).isTrue;

      final acoshEval = compileToBytecode(Fn.acosh(x), ['x']);
      check(acoshEval.evaluate1D(0.5).isNaN).isTrue;

      final atanhEval = compileToBytecode(Fn.atanh(x), ['x']);
      check(atanhEval.evaluate1D(1.5).isNaN).isTrue;
      check(atanhEval.evaluate1D(-1.5).isNaN).isTrue;
      check(atanhEval.evaluate1D(1.0)).equals(double.infinity);
      check(atanhEval.evaluate1D(-1.0)).equals(double.negativeInfinity);

      check(
        compileToBytecode(Fn.lambertW(x), [
          'x',
        ]).evaluateComplex1D(const Complex(1, 1)).isFinite,
      ).isTrue;
      check(
        compileToBytecode(Fn.lambertW(x, IntegerNumber.negativeOne), [
          'x',
        ]).evaluateComplex1D(const Complex(-0.2, 1)).isFinite,
      ).isTrue;
      check(
        compileToBytecode(Fn.erf(x), [
          'x',
        ]).evaluateComplex1D(const Complex(1, 1)).isFinite,
      ).isTrue;
      check(
        compileToBytecode(Fn.erfc(x), [
          'x',
        ]).evaluateComplex1D(const Complex(1, 1)).isFinite,
      ).isTrue;
      check(
        compileToBytecode(Fn.beta(x, y), ['x', 'y']).evaluateComplexList([
          const Complex(1, 1),
          const Complex(2, 0),
        ]).isFinite,
      ).isTrue;
      check(
        compileToBytecode(Fn.zeta(x), [
          'x',
        ]).evaluateComplex1D(const Complex(1, 1)).isFinite,
      ).isTrue;
      check(
        compileToBytecode(Fn.digamma(x), [
          'x',
        ]).evaluateComplex1D(const Complex(1, 1)).isFinite,
      ).isTrue;
      check(
        compileToBytecode(Fn.besselJ(IntegerNumber.zero, x), [
          'x',
        ]).evaluateComplex1D(const Complex(1, 1)).isFinite,
      ).isTrue;
      check(
        compileToBytecode(Fn.ellipticK(x), [
          'x',
        ]).evaluateComplex1D(const Complex(1, 1)).isFinite,
      ).isTrue;

      final powEval = compileToBytecode(Pow.of(x, y), [
        'x',
        'y',
      ], optimize: false);
      check(powEval.evaluateComplexList([const Complex(2, 3), Complex.zero]))
          .equals(Complex.one);
      check(powEval.evaluateComplexList([Complex.zero, const Complex(2, 0)]))
          .equals(Complex.zero);
      check(powEval.evaluateComplexList([Complex.zero, const Complex(-2, 0)]).a)
          .equals(double.infinity);
      check(
        powEval.evaluateComplexList([Complex.zero, const Complex(0, 1)]).isNaN,
      ).isTrue;
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
      final binomEval = compileToBytecode(Fn.binomial(x, y), ['x', 'y']);
      check(binomEval.evaluateList([5.0, 2.0])).isCloseTo(10.0, 1e-12);
      check(binomEval.evaluateList([double.nan, 2.0])).isNaN;
      check(binomEval.evaluateList([5.0, -1.0])).equals(0.0);
      check(binomEval.evaluateList([3.0, 5.0])).equals(0.0);
      check(
        binomEval.evaluateComplexList([
          const Complex(5.0),
          const Complex(2.0),
        ]).a,
      ).isCloseTo(10.0, 1e-12);
      check(
        binomEval.evaluateComplexList([
          const Complex(1, 1),
          const Complex(2, 0),
        ]).a,
      ).isCloseTo(-0.5, 1e-12);

      final modEval = compileToBytecode(Fn.mod(x, y), ['x', 'y']);
      check(modEval.evaluateList([17.0, 5.0])).equals(2.0);
      check(modEval.evaluateList([17.0, 0.0])).isNaN;
      check(
        modEval.evaluateComplexList([const Complex(17.0), const Complex(5.0)]),
      ).equals(const Complex(2.0));
      check(
        () => modEval.evaluateComplexList([
          const Complex(1, 1),
          const Complex(2, 0),
        ]),
      ).throws<UnsupportedError>();

      final factEval = compileToBytecode(Fn.factorial(x), ['x']);
      check(factEval.evaluate1D(3.5))
          .isCloseTo(Fn.factorial(x).evaluate({'x': 3.5}), 1e-12);
      check(factEval.evaluateComplex1D(const Complex(3.5)).a)
          .isCloseTo(Fn.factorial(x).evaluate({'x': 3.5}), 1e-12);
      check(factEval.evaluateComplex1D(const Complex(1, 1)).isFinite).isTrue;

      for (final node in <Expr>[Fn.floor(x), Fn.ceil(x), Fn.round(x)]) {
        final eval = compileToBytecode(node, ['x']);
        check(eval.evaluate1D(3.5)).isCloseTo(node.evaluate({'x': 3.5}), 1e-12);
        check(eval.evaluateComplex1D(const Complex(3.5)).a)
            .isCloseTo(node.evaluate({'x': 3.5}), 1e-12);
        check(() => eval.evaluateComplex1D(const Complex(1, 1)))
            .throws<UnsupportedError>();
      }

      final signEval = compileToBytecode(Fn.sign(x), ['x']);
      check(signEval.evaluate1D(0.0)).equals(0.0);
      check(signEval.evaluate1D(-2.0)).equals(-1.0);
      check(signEval.evaluate1D(2.0)).equals(1.0);
      check(signEval.evaluateComplex1D(Complex.zero)).equals(Complex.zero);
      check(signEval.evaluateComplex1D(const Complex(-2.0)))
          .equals(const Complex(-1.0));
      check(signEval.evaluateComplex1D(const Complex(3.0, 4.0)))
          .equals(const Complex(0.6, 0.8));

      final reEval = compileToBytecode(Fn.re(x), ['x'], optimize: false);
      final imEval = compileToBytecode(Fn.im(x), ['x'], optimize: false);
      final argEval = compileToBytecode(Fn.arg(x), ['x'], optimize: false);
      final conjEval = compileToBytecode(Fn.conj(x), ['x'], optimize: false);
      check(reEval.evaluate1D(3.0)).equals(3.0);
      check(imEval.evaluate1D(3.0)).equals(0.0);
      check(argEval.evaluate1D(3.0)).equals(0.0);
      check(argEval.evaluate1D(-3.0)).isCloseTo(3.141592653589793, 1e-12);
      check(conjEval.evaluate1D(3.0)).equals(3.0);
      check(argEval.evaluateComplex1D(const Complex(0, 1)).a)
          .isCloseTo(1.5707963267948966, 1e-12);

      check(Expr.parse('binomial(1000, 500)').evaluate())
          .isCloseTo(2.7028824094543656e299, 1e286);
      check(Expr.parse('binomial(-3, 4)').evaluate()).isCloseTo(15.0, 1e-12);
    });

    test('relational, Piecewise, Integral, and direct Op.sub instructions', () {
      const x = Variable('x');
      final relations = <Expr>[
        Relational.lessThan(x, IntegerNumber.zero),
        Relational.lessEqual(x, IntegerNumber.zero),
        Relational.greaterThan(x, IntegerNumber.zero),
        Relational.greaterEqual(x, IntegerNumber.zero),
        Relational.equal(x, IntegerNumber.zero),
        Relational.notEqual(x, IntegerNumber.zero),
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
        Piecewise([
          (relation: Relational.lessThan(x, IntegerNumber.zero), expr: -x),
        ]),
        ['x'],
      );
      check(pwNoOtherwise.evaluate1D(-2.0)).equals(2.0);
      check(pwNoOtherwise.evaluate1D(2.0).isNaN).isTrue;
      check(pwNoOtherwise.evaluateComplex1D(const Complex(-2.0)))
          .equals(const Complex(2.0));
      check(pwNoOtherwise.evaluateComplex1D(const Complex(2.0)).isNaN).isTrue;

      final intEval = compileToBytecode(
        Integral(const Variable('t'), 't', lower: IntegerNumber.zero, upper: x),
        ['x'],
      );
      check(intEval.evaluateComplex1D(const Complex(2.0)).a)
          .isCloseTo(2.0, 1e-12);

      final subEval = BytecodeEvaluator(
        variables: const ['x', 'y'],
        code: Int32List.fromList([Op.sub.index, 2, 0, 1]),
        registerCount: 3,
        resultReg: 2,
      );
      check(subEval.evaluateList([7.0, 2.5])).equals(4.5);
      check(
        subEval.evaluateComplexList([const Complex(7, 3), const Complex(2, 1)]),
      ).equals(const Complex(5, 2));
    });

    test('caches inner bytecode programs across repeated Sum evaluations', () {
      final sumExpr = Expr.parse('sum(k*x, k, 1, 100)');
      final evaluator = compileToBytecode(sumExpr, const ['x']);
      for (var i = 0; i < 1000; i++) {
        evaluator.evaluate1D(i.toDouble());
      }
      // 1 for lower (1), 1 for upper (100), 1 for inner summand (k * x) = 3 total
      check(evaluator.innerCompileCount).equals(3);
    });

    test(
      'complex relational comparisons return NaN for non-real or NaN operands',
      () {
        const x = Variable('x');
        final ltExpr = Relational.lessThan(x, IntegerNumber.one);
        check(ltExpr.evaluateComplex({'x': const Complex(0, 1)}).isNaN).isTrue;
        check(ltExpr.evaluateComplex({'x': const Complex(double.nan, 0)}).isNaN)
            .isTrue;
        check(ltExpr.evaluateComplex({'x': Complex.zero})).equals(Complex.one);
      },
    );
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
        Pow.of(
          x,
          IntegerNumber.zero,
        ).evaluateComplex({'x': const Complex(2, 3)}),
      ).equals(Complex.one);
      check(Pow.of(IntegerNumber.zero, IntegerNumber.two).evaluateComplex())
          .equals(Complex.zero);
      check(
        Pow.of(
          IntegerNumber.zero,
          IntegerNumber.negativeOne,
        ).evaluateComplex().a,
      ).equals(double.infinity);
      check(Pow.of(IntegerNumber.zero, ComplexNumber.i).evaluateComplex().isNaN)
          .isTrue;
      check(
        Pow.of(
          x,
          IntegerNumber.one,
        ).evaluateComplex({'x': const Complex(2, 3)}),
      ).equals(const Complex(2, 3));
      check(
        Pow.of(
          x,
          IntegerNumber.two,
        ).evaluateComplex({'x': const Complex(1, 1)}),
      ).equals(const Complex(0, 2));
      check(
        Pow.of(
          x,
          IntegerNumber.negativeOne,
        ).evaluateComplex({'x': const Complex(0, 1)}),
      ).equals(const Complex(0, -1));
      check(
        Pow.of(
          x,
          IntegerNumber.of(3),
        ).evaluateComplex({'x': const Complex(0, 1)}),
      ).equals(const Complex(0, -1));
      check(
        Pow.of(
          x,
          IntegerNumber.of(-3),
        ).evaluateComplex({'x': const Complex(0, 1)}),
      ).equals(const Complex(0, 1));
      check(Pow.of(x, ComplexNumber.i).evaluateComplex({'x': Complex.one}))
          .equals(Complex.one);

      const z = Complex(0.4, 0.3);
      check(Fn.sin(x).evaluateComplex({'x': z})).equals(z.sin());
      check(Fn.cos(x).evaluateComplex({'x': z})).equals(z.cos());
      check(Fn.tan(x).evaluateComplex({'x': z})).equals(z.tan());
      check(Fn.asin(x).evaluateComplex({'x': z})).equals(z.asin());
      check(Fn.acos(x).evaluateComplex({'x': z})).equals(z.acos());
      check(Fn.atan(x).evaluateComplex({'x': z})).equals(z.atan());
      check(Fn.sinh(x).evaluateComplex({'x': z})).equals(z.sinh());
      check(Fn.cosh(x).evaluateComplex({'x': z})).equals(z.cosh());
      check(Fn.tanh(x).evaluateComplex({'x': z})).equals(z.tanh());
      check(Fn.ln(x).evaluateComplex({'x': z})).equals(z.log());
      check(Fn.abs(x).evaluateComplex({'x': const Complex(3, 4)}))
          .equals(const Complex(5));

      final asinhZ = Fn.asinh(x).evaluateComplex({'x': z});
      check(Fn.sinh(x).evaluateComplex({'x': asinhZ}).a).isCloseTo(z.a, 1e-12);
      check(Fn.sinh(x).evaluateComplex({'x': asinhZ}).b).isCloseTo(z.b, 1e-12);

      const z2 = Complex(1.5, 0.5);
      final acoshZ = Fn.acosh(x).evaluateComplex({'x': z2});
      check(Fn.cosh(x).evaluateComplex({'x': acoshZ}).a).isCloseTo(z2.a, 1e-12);
      check(Fn.cosh(x).evaluateComplex({'x': acoshZ}).b).isCloseTo(z2.b, 1e-12);

      final atanhZ = Fn.atanh(x).evaluateComplex({'x': z});
      check(Fn.tanh(x).evaluateComplex({'x': atanhZ}).a).isCloseTo(z.a, 1e-12);
      check(Fn.tanh(x).evaluateComplex({'x': atanhZ}).b).isCloseTo(z.b, 1e-12);
    });

    test(
      'evaluates special functions, Piecewise, Integral, and OrderTerm in C',
      () {
        const x = Variable('x');
        const y = Variable('y');
        const realZ = Complex(0.5);
        const nonRealZ = Complex(0.5, 1.0);

        check(Fn.erf(x).evaluateComplex({'x': realZ}).a)
            .isCloseTo(Fn.erf(x).evaluate({'x': 0.5}), 1e-14);
        check(Fn.erf(x).evaluateComplex({'x': nonRealZ}).isFinite).isTrue;

        check(Fn.erfc(x).evaluateComplex({'x': realZ}).a)
            .isCloseTo(Fn.erfc(x).evaluate({'x': 0.5}), 1e-14);
        check(Fn.erfc(x).evaluateComplex({'x': nonRealZ}).isFinite).isTrue;

        check(Fn.gamma(x).evaluateComplex({'x': const Complex(4.0)}).a)
            .isCloseTo(6.0, 1e-12);
        check(Fn.gamma(x).evaluateComplex({'x': nonRealZ}).isFinite).isTrue;

        check(
          Fn.beta(x, y).evaluateComplex({
            'x': const Complex(2.0),
            'y': const Complex(3.0),
          }).a,
        ).isCloseTo(1.0 / 12.0, 1e-12);
        check(
          Fn.beta(x, y).evaluateComplex({'x': nonRealZ, 'y': realZ}).isFinite,
        ).isTrue;

        check(Fn.lambertW(x).evaluateComplex({'x': nonRealZ}).isFinite).isTrue;

        final pw = Piecewise([
          (relation: Relational.lessThan(x, IntegerNumber.zero), expr: -x),
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
        check(Integral(x, 'x').evaluateComplex().isNaN).isTrue;

        // Node evaluation in real mode for calculus and iterated nodes:
        final derivNode = Derivative(
          Pow.of(x, IntegerNumber.two),
          'x',
          point: IntegerNumber.of(3),
        );
        check(derivNode.evaluate()).isCloseTo(6.0, 1e-12);

        final limitNode = Limit(Fn.sin(x) / x, 'x', IntegerNumber.zero);
        check(limitNode.evaluate()).isCloseTo(1.0, 1e-12);

        final sumNode = Sum(
          const Variable('k'),
          'k',
          IntegerNumber.one,
          IntegerNumber.of(5),
        );
        check(sumNode.evaluate()).isCloseTo(15.0, 1e-12);

        final prodNode = Product(
          const Variable('k'),
          'k',
          IntegerNumber.one,
          IntegerNumber.of(4),
        );
        check(prodNode.evaluate()).isCloseTo(24.0, 1e-12);

        // Real evaluation with complex literals evaluating to real values:
        final complexMul = ComplexNumber.i * ComplexNumber.i;
        check(complexMul.evaluate()).equals(-1.0);
        check((x * ComplexNumber.i * ComplexNumber.i).evaluate({'x': 5.0}))
            .equals(-5.0);
        check(() => (x + ComplexNumber.i).evaluate({'x': 1.0}))
            .throws<UnsupportedError>();

        check(OrderTerm('x', 3).evaluateComplex()).equals(Complex.zero);
      },
    );

    test('evaluates special functions at complex points', () {
      final z = ComplexNumber(const RealNumber(0.5), const RealNumber(0.25));
      final n = IntegerNumber.of(2);
      const k = RealNumber(0.5);

      check(Fn.erf(z).evaluateComplex()).isNotNull();
      check(Fn.erf(z).evaluateComplex().abs())
          .isCloseTo(Fn.erf(z).evaluateComplex().abs(), 1e-12);
      check((Fn.erf(z) + Fn.erfc(z)).evaluateComplex().real)
          .isCloseTo(1.0, 1e-12);
      check((Fn.erf(z) + Fn.erfc(z)).evaluateComplex().imaginary)
          .isCloseTo(0.0, 1e-12);

      // Gamma(z + 1) == z * Gamma(z)
      final gz = Fn.gamma(z).evaluateComplex();
      final gz1 = Fn.gamma(z + IntegerNumber.one).evaluateComplex();
      check(gz1.real).isCloseTo((const Complex(0.5, 0.25) * gz).real, 1e-12);
      check(gz1.imaginary)
          .isCloseTo((const Complex(0.5, 0.25) * gz).imaginary, 1e-12);

      check(Fn.digamma(z).evaluateComplex().isFinite).isTrue;
      check(Fn.polygamma(n, z).evaluateComplex().isFinite).isTrue;
      check(Fn.besselJ(n, z).evaluateComplex().isFinite).isTrue;
      check(Fn.ellipticF(z, k).evaluateComplex().isFinite).isTrue;
      check(Fn.ellipticE(z, k).evaluateComplex().isFinite).isTrue;
      check(Fn.upperGamma(n, z).evaluateComplex().isFinite).isTrue;
      check(Fn.beta(z, n).evaluateComplex().isFinite).isTrue;
      check(Fn.binomial(z, n).evaluateComplex().isFinite).isTrue;
      check(Fn.lambertW(z).evaluateComplex().isFinite).isTrue;

      final piExpr = Fn.ellipticPi(n, z, k);
      check(piExpr.evaluateComplex().isFinite).isTrue;
      check(
        Fn.ellipticPi(
          const RealNumber(0.3),
          const RealNumber(0.8),
          const RealNumber(0.5),
        ).evaluate(),
      ).isFinite;

      final a2 = Fn.atan2(const Variable('y'), const Variable('x'));
      check(a2.evaluate({'y': 1.0, 'x': -1.0}))
          .isCloseTo(3.0 * 3.141592653589793 / 4.0, 1e-12);
      check(
        a2.evaluateComplex({
          'y': const Complex(0.5, 0.2),
          'x': const Complex(1.0, -0.3),
        }).isFinite,
      ).isTrue;
    });

    test('unevaluated Derivative falls back to numeric finite difference', () {
      final dZeta = Expr.parse('zeta(x)').derivative('x');
      final fn = dZeta.toFunction1D('x');
      check(fn(2.0)).isCloseTo(-0.9375482543158437, 1e-8);

      final d2Zeta = Expr.parse('zeta(x)').derivative('x', order: 2);
      final fn2 = d2Zeta.toFunction1D('x');
      check(fn2(2.0)).isCloseTo(1.989280234298901, 5e-5);

      // Improper and definite Integral evaluation via numeric.integrate
      final gaussHalf = Integral(
        Expr.parse('exp(-x^2)'),
        'x',
        lower: IntegerNumber.zero,
        upper: Constant.infinity,
      );
      check(gaussHalf.evaluate()).isCloseTo(0.8862269254527579, 1e-8);
      final gaussFull = Integral(
        Expr.parse('exp(-x^2)'),
        'x',
        lower: -Constant.infinity,
        upper: Constant.infinity,
      );
      check(gaussFull.evaluate()).isCloseTo(1.7724538509055159, 1e-8);
    });

    test('unevaluated Limit returns NaN instead of recursing infinitely', () {
      final limInf = Limit(
        Expr.parse('(-2 + sqrt(4 + x)) / x'),
        'x',
        Constant.infinity,
      );
      check(limInf.evaluate()).isNaN;
      check(limInf.evaluateComplex().isNaN).isTrue;
    });

    test('evaluates special functions on complex inputs via bytecode and toBytecode', () {
      const z = Variable('z');
      for (final expr in <Expr>[
        Fn.gamma(z),
        Fn.digamma(z),
        Fn.zeta(z),
        Fn.besselJ(IntegerNumber.zero, z),
        Fn.hypergeometric(
          Fn.tuple([IntegerNumber.one, IntegerNumber.two]),
          Fn.tuple([IntegerNumber.of(3)]),
          z,
        ),
        Fn.ellipticK(z),
        Fn.ellipticE(z),
        Fn.lambertW(z),
      ]) {
        final bc = expr.toBytecode(variables: const ['z']);
        final direct = expr.evaluateComplex({'z': const Complex(0.4, 0.2)});
        final compiled = bc.evaluateComplex1D(const Complex(0.4, 0.2));
        check(compiled.a).isCloseTo(direct.a, 1e-10);
        check(compiled.b).isCloseTo(direct.b, 1e-10);
      }
      check(
        Constant.undefined
            .toBytecode(variables: const <String>[])
            .evaluate1D(0.0)
            .isNaN,
      ).isTrue;
    });

    test('evaluates remaining special and discrete functions via VM and direct evaluate', () {
      const x = Variable('x');
      const y = Variable('y');
      final realExprs = <Expr>[
        Fn.besselY(IntegerNumber.zero, x),
        Fn.besselI(IntegerNumber.zero, x),
        Fn.besselK(IntegerNumber.one, x),
        Fn.upperGamma(IntegerNumber.two, x),
        Fn.lowerGamma(IntegerNumber.two, x),
        Fn.polygamma(IntegerNumber.one, x),
        Fn.ellipticF(x, y),
        Fn.ellipticPi(y, x, y),
        Fn.ei(x),
        Fn.expIntegralE(IntegerNumber.two, x),
        Fn.li(x + IntegerNumber.two),
        Fn.si(x),
        Fn.ci(x),
        Fn.shi(x),
        Fn.chi(x),
        Fn.fresnelS(x),
        Fn.fresnelC(x),
        Fn.polylog(IntegerNumber.two, y),
        Fn.erfi(x),
        Fn.atan2(x, y),
        Fn.min([x, y]),
        Fn.max([x, y]),
        Fn.gcd([IntegerNumber.of(12), IntegerNumber.of(18)]),
        Fn.lcm([IntegerNumber.of(4), IntegerNumber.of(6)]),
        Fn.mod(IntegerNumber.of(7), IntegerNumber.of(3)),
        Fn.floor(x),
        Fn.ceil(x),
        Fn.round(x),
        Fn.sign(x),
      ];
      const env = {'x': 0.8, 'y': 0.4};
      for (final expr in realExprs) {
        final expected = expr.evaluate(env);
        final bc = expr.toBytecode(variables: const ['x', 'y']);
        check(bc.evaluateList(const [0.8, 0.4])).isCloseTo(expected, 1e-10);
      }
    });

    test('normalizes signed zero for principal complex branch cuts', () {
      const x = Variable('x');
      final recipSqrt = Pow.of(IntegerNumber.one / x, FractionNumber.half);
      final sqrtRecip = Pow.of(x, FractionNumber.negativeHalf);
      final v1 = recipSqrt.evaluateComplex(const {'x': Complex(-1.0)});
      final v2 = sqrtRecip.evaluateComplex(const {'x': Complex(-1.0)});
      check(v1.a).isCloseTo(0.0, 1e-12);
      check(v1.b).isCloseTo(1.0, 1e-12);
      check((v1 + v2).abs()).isCloseTo(0.0, 1e-12);

      final lnNeg = Fn.ln(IntegerNumber.one / x);
      final vLn = lnNeg.evaluateComplex(const {'x': Complex(-1.0)});
      check(vLn.a).isCloseTo(0.0, 1e-12);
      check(vLn.b).isCloseTo(math.pi, 1e-12);

      final bc = Fn.ln(-x).toBytecode(variables: const ['x']);
      final vNegLn = bc.evaluateComplex1D(const Complex(1.0));
      check(vNegLn.a).isCloseTo(0.0, 1e-12);
      check(vNegLn.b).isCloseTo(math.pi, 1e-12);

      final vSqrt = Pow.of(IntegerNumber.one / x, FractionNumber.half)
          .toBytecode(variables: const ['x'])
          .evaluateComplex1D(const Complex(-4.0));
      check(vSqrt.a).isCloseTo(0.0, 1e-12);
      check(vSqrt.b).isCloseTo(0.5, 1e-12);
    });
  });
}
