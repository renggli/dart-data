import 'dart:math' as math;
import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Expression AST creation & evaluation', () {
    test('basic arithmetic and evaluation', () {
      const x = Variable('x');
      final expr = (x * 2) + 5;
      check(expr.freeVariables).unorderedEquals({'x'});
      check(expr.dependsOn('x')).isTrue();
      check(expr.dependsOn('y')).isFalse();
      check(expr.evaluate({'x': 3.0})).equals(11.0);
      check(() => expr.evaluate({})).throws<ArgumentError>();
    });

    test('operator overloads and constructors', () {
      const x = Variable('x');
      const y = Variable('y');

      final add = x + y;
      check(add).isA<Add>();
      final sub = x - y;
      check(sub).isA<Sub>();
      final mul = x * y;
      check(mul).isA<Mul>();
      final div = x / y;
      check(div).isA<Div>();
      final neg = -x;
      check(neg).isA<Neg>();
      final pow = x.pow(y);
      check(pow).isA<Pow>();

      // Wrapping numeric scalars
      final addNum = x + 3;
      check(addNum).isA<Add>();
      final subNum = x - 3;
      check(subNum).isA<Sub>();
      final mulNum = x * 3;
      check(mulNum).isA<Mul>();
      final divNum = x / 3;
      check(divNum).isA<Div>();
      final powNum = x.pow(3);
      check(powNum).isA<Pow>();
    });

    test('LaTeX and string formatting for all AST nodes', () {
      const x = Variable('x');
      const y = Variable('y');

      check(x.toLatex()).equals('x');
      check(x.toString()).equals('x');

      check(const RationalNumber(4).toLatex()).equals('4');
      check(const RationalNumber(9, 2).toLatex()).equals(r'\frac{9}{2}');
      check(const RealNumber(3.14).toLatex()).equals('3.14');
      check(ConstantNumber.pi.toLatex()).equals(r'\pi');
      check(ConstantNumber.pi.toString()).equals('pi');
      check(ConstantNumber.e.toLatex()).equals('e');
      check(ConstantNumber.e.toString()).equals('e');
      check(pi.toLatex()).equals(r'\pi');
      check(e.toLatex()).equals('e');

      const add = Add(x, y);
      check(add.toLatex()).equals('x + y');
      check(add.toString()).equals('x + y');

      const sub = Sub(x, y);
      check(sub.toLatex()).equals('x - y');
      check(sub.toString()).equals('x - y');

      const mul = Mul(x, y);
      check(mul.toLatex()).equals('x \\cdot y');
      check(mul.toString()).equals('x * y');

      const div = Div(x, y);
      check(div.toLatex()).equals('\\frac{x}{y}');
      check(div.toString()).equals('x / y');

      const pow = Pow(x, y);
      check(pow.toLatex()).equals('{x}^{y}');
      check(pow.toString()).equals('x ^ y');

      const neg = Neg(x);
      check(neg.toLatex()).equals('-x');
      check(neg.toString()).equals('-x');

      const sin = Sin(x);
      check(sin.toLatex()).equals('\\sin(x)');
      check(sin.toString()).equals('sin(x)');

      const cos = Cos(x);
      check(cos.toLatex()).equals('\\cos(x)');
      check(cos.toString()).equals('cos(x)');

      const exp = Exp(x);
      check(exp.toLatex()).equals('e^{x}');
      check(exp.toString()).equals('exp(x)');

      const ln = Ln(x);
      check(ln.toLatex()).equals('\\ln(x)');
      check(ln.toString()).equals('ln(x)');

      // Precedence & nested string textualization
      const compound = Mul(
        Exp(Mul(RationalNumber(-2), x)),
        Cos(Mul(RationalNumber(3), x)),
      );
      check(compound.toString()).equals('exp(-2 * x) * cos(3 * x)');

      const poly = Add(
        Sub(Pow(x, RationalNumber(3)), Mul(RationalNumber(3), x)),
        RationalNumber(1),
      );
      check(poly.toString()).equals('x ^ 3 - 3 * x + 1');

      const parenMul = Mul(
        Add(x, RationalNumber(1)),
        Sub(x, RationalNumber(1)),
      );
      check(parenMul.toString()).equals('(x + 1) * (x - 1)');

      const parenDiv = Div(
        RationalNumber(1),
        Add(RationalNumber(1), Pow(x, RationalNumber(2))),
      );
      check(parenDiv.toString()).equals('1 / (1 + x ^ 2)');
    });

    test('Equality and hashCode across AST nodes', () {
      const x = Variable('x');
      const y = Variable('y');

      check(const Variable('x') == x).isTrue();
      check(const Variable('x').hashCode).equals(x.hashCode);
      check(x == y).isFalse();

      check(const RationalNumber(3) == const RationalNumber(3)).isTrue();
      check(const RationalNumber(3).hashCode)
          .equals(const RationalNumber(3).hashCode);
      check(const RationalNumber(3) == const RationalNumber(4)).isFalse();
      check(const RealNumber(3.14) == const RealNumber(3.14)).isTrue();
      check(ConstantNumber.pi == ConstantNumber.pi).isTrue();

      check(const Add(x, y) == const Add(x, y)).isTrue();
      check(const Add(x, y).hashCode).equals(const Add(x, y).hashCode);
      check(const Sub(x, y) == const Sub(x, y)).isTrue();
      check(const Sub(x, y).hashCode).equals(const Sub(x, y).hashCode);
      check(const Mul(x, y) == const Mul(x, y)).isTrue();
      check(const Mul(x, y).hashCode).equals(const Mul(x, y).hashCode);
      check(const Div(x, y) == const Div(x, y)).isTrue();
      check(const Div(x, y).hashCode).equals(const Div(x, y).hashCode);
      check(const Pow(x, y) == const Pow(x, y)).isTrue();
      check(const Pow(x, y).hashCode).equals(const Pow(x, y).hashCode);
      check(const Neg(x) == const Neg(x)).isTrue();
      check(const Neg(x).hashCode).equals(const Neg(x).hashCode);
      check(const Sin(x) == const Sin(x)).isTrue();
      check(const Sin(x).hashCode).equals(const Sin(x).hashCode);
      check(const Cos(x) == const Cos(x)).isTrue();
      check(const Cos(x).hashCode).equals(const Cos(x).hashCode);
      check(const Tan(x) == const Tan(x)).isTrue();
      check(const Tan(x).hashCode).equals(const Tan(x).hashCode);
      check(const Asin(x) == const Asin(x)).isTrue();
      check(const Asin(x).hashCode).equals(const Asin(x).hashCode);
      check(const Acos(x) == const Acos(x)).isTrue();
      check(const Acos(x).hashCode).equals(const Acos(x).hashCode);
      check(const Atan(x) == const Atan(x)).isTrue();
      check(const Atan(x).hashCode).equals(const Atan(x).hashCode);
      check(const Sinh(x) == const Sinh(x)).isTrue();
      check(const Sinh(x).hashCode).equals(const Sinh(x).hashCode);
      check(const Cosh(x) == const Cosh(x)).isTrue();
      check(const Cosh(x).hashCode).equals(const Cosh(x).hashCode);
      check(const Tanh(x) == const Tanh(x)).isTrue();
      check(const Tanh(x).hashCode).equals(const Tanh(x).hashCode);
      check(const Abs(x) == const Abs(x)).isTrue();
      check(const Abs(x).hashCode).equals(const Abs(x).hashCode);
      check(
        const Pow(x, RationalNumber(1, 2)) ==
            const Pow(x, RationalNumber(1, 2)),
      ).isTrue();
      check(const Pow(x, RationalNumber(1, 2)).hashCode)
          .equals(const Pow(x, RationalNumber(1, 2)).hashCode);
      check(const Exp(x) == const Exp(x)).isTrue();
      check(const Exp(x).hashCode).equals(const Exp(x).hashCode);
      check(const Ln(x) == const Ln(x)).isTrue();
      check(const Ln(x).hashCode).equals(const Ln(x).hashCode);
      const customI = ConstantNumber(
        'i',
        Pow(RationalNumber.negativeOne, RationalNumber(1, 2)),
      );
      check(ConstantNumber.i == customI).isTrue();
      check(ConstantNumber.i.hashCode).equals(customI.hashCode);
    });

    test('named mathematical constants pi and e', () {
      check(pi.value).equals(const RealNumber(math.pi));
      check(e.value).equals(const RealNumber(math.e));
      check(pi.toDouble()).equals(math.pi);
      check(e.toDouble()).equals(math.e);
      check(ConstantNumber.pi).equals(pi);
      check(ConstantNumber.e).equals(e);

      check(pi.freeVariables).isEmpty();
      check(e.freeVariables).isEmpty();
      check(pi.dependsOn('x')).isFalse();
      check(e.dependsOn('x')).isFalse();

      check(pi.evaluate({})).equals(math.pi);
      check(e.evaluate({})).equals(math.e);

      check(pi.substitute('x', const Variable('y'))).equals(pi);
      check(e.substitute('x', const Variable('y'))).equals(e);

      check(pi.derivative('x')).equals(const RationalNumber(0));
      check(e.derivative('x')).equals(const RationalNumber(0));
    });

    test('Substitution and freeVariables', () {
      const x = Variable('x');
      const y = Variable('y');
      const z = Variable('z');

      final expr =
          (x + y) * (x - y) / const Pow(x, z) +
          const Neg(Sin(x)) -
          const Cos(y) * const Exp(z) / const Ln(x);
      check(expr.freeVariables).unorderedEquals({'x', 'y', 'z'});
      check(expr.dependsOn('x')).isTrue();
      check(expr.dependsOn('w')).isFalse();

      final substituted = expr.substitute('x', const RationalNumber(2));
      check(substituted.freeVariables).unorderedEquals({'y', 'z'});
      check(substituted.dependsOn('x')).isFalse();
    });

    test('UnaryExpr and BinaryExpr hierarchy and hash non-collision', () {
      const x = Variable('x');
      const y = Variable('y');

      // Hierarchy
      check(const Sin(x)).isA<UnaryExpr>();
      check(const Cos(x)).isA<UnaryExpr>();
      check(const Exp(x)).isA<UnaryExpr>();
      check(const Ln(x)).isA<UnaryExpr>();
      check(const Neg(x)).isA<UnaryExpr>();
      check(const Add(x, y)).isA<BinaryExpr>();
      check(const Sub(x, y)).isA<BinaryExpr>();
      check(const Mul(x, y)).isA<BinaryExpr>();
      check(const Div(x, y)).isA<BinaryExpr>();
      check(const Pow(x, y)).isA<BinaryExpr>();

      // Pow aliases
      const p = Pow(x, y);
      check(p.base).equals(p.left);
      check(p.exponent).equals(p.right);

      // Hash collision resolution
      check(const Sin(x).hashCode == const Cos(x).hashCode).isFalse();
      check(const Sin(x).hashCode == const Neg(x).hashCode).isFalse();
      check(const Exp(x).hashCode == const Ln(x).hashCode).isFalse();
      check(const Add(x, y).hashCode == const Sub(x, y).hashCode).isFalse();
      check(const Mul(x, y).hashCode == const Div(x, y).hashCode).isFalse();
      check(const Add(x, y).hashCode == const Pow(x, y).hashCode).isFalse();

      // Equality
      check(const Sin(x) == const Sin(x)).isTrue();
      check(const Sin(x) == const Cos(x)).isFalse();
      check(const Add(x, y) == const Add(x, y)).isTrue();
      check(const Add(x, y) == const Sub(x, y)).isFalse();

      // collectFreeVariables allocation-free collection
      final vars = <String>{};
      p.collectFreeVariables(vars);
      check(vars).unorderedEquals({'x', 'y'});

      const complex = Add(Mul(x, Sin(y)), Exp(Ln(x)));
      final complexVars = <String>{};
      complex.collectFreeVariables(complexVars);
      check(complexVars).unorderedEquals({'x', 'y'});
      check(complex.freeVariables).unorderedEquals({'x', 'y'});

      // Number collectFreeVariables no-op
      const num = RationalNumber(42);
      final numVars = <String>{};
      num.collectFreeVariables(numVars);
      check(numVars).isEmpty();
      check(num.freeVariables).isEmpty();
    });
  });

  group('Exact Analytical Differentiation', () {
    test('polynomial differentiation', () {
      const x = Variable('x');
      final expr = x.pow(3);
      final df = expr.derivative('x').simplify();
      final fn = df.toFunction1D('x');
      check(fn(2.0)).equals(12.0); // 3 * 4 = 12
    });

    test('product and quotient rule', () {
      const x = Variable('x');
      // Product: x^2 * sin(x)
      final expr = (x.pow(2)) * const Sin(x);
      final df = expr.derivative('x').simplify();
      final dfCompiled = df.toFunction1D('x');
      check(dfCompiled(0.0)).equals(0.0);

      // Quotient: (x + 1) / (x - 1)
      final quotient = (x + 1) / (x - 1);
      final dq = quotient.derivative('x').simplify();
      // d/dx ((x+1)/(x-1)) = ((x-1) - (x+1))/(x-1)^2 = -2 / (x-1)^2 -> at x =
      // 3: -2 / 4 = -0.5
      final dqCompiled = dq.toFunction1D('x');
      check(dqCompiled(3.0)).isCloseTo(-0.5, 1e-6);
    });

    test('chain rule: exp(2*x) and cos(x)', () {
      const x = Variable('x');
      final expr = Exp(x * 2);
      final df = expr.derivative('x').simplify();
      final dfCompiled = df.toFunction1D('x');
      check(dfCompiled(0.0)).equals(2.0);

      const cosine = Cos(x);
      final dc = cosine.derivative('x').simplify();
      final dcCompiled = dc.toFunction1D('x');
      check(dcCompiled(0.0)).equals(0.0);
    });

    test('logarithm: ln(x)', () {
      const x = Variable('x');
      const expr = Ln(x);
      final df = expr.derivative('x').simplify();
      final dfCompiled = df.toFunction1D('x');
      check(dfCompiled(2.0)).equals(0.5);
    });

    test('power rule branches', () {
      const x = Variable('x');

      // Neither depends
      check(const Pow(RationalNumber(2), RationalNumber(3)).derivative('x'))
          .equals(const RationalNumber(0));

      // Base only depends: x^3
      final bOnly = const Pow(x, RationalNumber(3)).derivative('x');
      check(bOnly.evaluate({'x': 2.0})).equals(12.0);

      // Exponent only depends: 2^x -> d/dx (2^x) = 2^x * ln(2)
      final eOnly = const Pow(RationalNumber(2), x).derivative('x');
      check(eOnly.evaluate({'x': 3.0})).isCloseTo(8.0 * math.log(2.0), 1e-6);

      // Both depend: x^x -> d/dx (x^x) = x^x * (ln(x) + 1)
      final both = const Pow(x, x).derivative('x');
      check(both.evaluate({'x': 2.0}))
          .isCloseTo(4.0 * (math.log(2.0) + 1.0), 1e-6);
    });

    test('expanded functions analytical derivatives', () {
      const x = Variable('x');

      // d/dx tan(x) = 1 + tan(x)^2
      const exprTan = Tan(x);
      final dTan = exprTan.derivative('x');
      check(dTan.evaluate({'x': 0.0})).equals(1.0);

      // d/dx asin(x) = 1 / sqrt(1 - x^2)
      const exprAsin = Asin(x);
      final dAsin = exprAsin.derivative('x');
      check(dAsin.evaluate({'x': 0.0})).equals(1.0);

      // d/dx acos(x) = -1 / sqrt(1 - x^2)
      const exprAcos = Acos(x);
      final dAcos = exprAcos.derivative('x');
      check(dAcos.evaluate({'x': 0.0})).equals(-1.0);

      // d/dx atan(x) = 1 / (1 + x^2)
      const exprAtan = Atan(x);
      final dAtan = exprAtan.derivative('x');
      check(dAtan.evaluate({'x': 0.0})).equals(1.0);

      // d/dx sinh(x) = cosh(x)
      const exprSinh = Sinh(x);
      final dSinh = exprSinh.derivative('x');
      check(dSinh.evaluate({'x': 0.0})).equals(1.0);

      // d/dx cosh(x) = sinh(x)
      const exprCosh = Cosh(x);
      final dCosh = exprCosh.derivative('x');
      check(dCosh.evaluate({'x': 0.0})).equals(0.0);

      // d/dx tanh(x) = 1 - tanh(x)^2
      const exprTanh = Tanh(x);
      final dTanh = exprTanh.derivative('x');
      check(dTanh.evaluate({'x': 0.0})).equals(1.0);

      // d/dx abs(x) = x / |x|
      const exprAbs = Abs(x);
      final dAbs = exprAbs.derivative('x');
      check(dAbs.evaluate({'x': 3.0})).equals(1.0);
      check(dAbs.evaluate({'x': -3.0})).equals(-1.0);

      // d/dx sqrt(x) = 1 / (2 * sqrt(x))
      const exprSqrt = Pow(x, RationalNumber(1, 2));
      final dSqrt = exprSqrt.derivative('x');
      check(dSqrt.evaluate({'x': 4.0})).equals(0.25);

      // d/dx log(b, x) = 1 / (x * ln(b))
      const exprLog = Div(Ln(x), Ln(RationalNumber(2)));
      final dLog = exprLog.derivative('x');
      check(dLog.evaluate({'x': 1.0})).isCloseTo(1.0 / math.log(2.0), 1e-9);
    });
  });

  group('Algebraic Simplification', () {
    test('identity reduction and constant folding', () {
      const x = Variable('x');
      const y = Variable('y');

      // (x * 0) + (1 * y) -> y
      final expr1 = (x * 0) + (y * 1);
      check(expr1.simplify()).equals(y);

      // (4 + 6) -> 10
      final expr2 = const RationalNumber(4) + const RationalNumber(6);
      check(expr2.simplify()).equals(const RationalNumber(10));

      // (10 - 4) -> 6
      final exprSub = const RationalNumber(10) - const RationalNumber(4);
      check(exprSub.simplify()).equals(const RationalNumber(6));

      // x - x -> 0
      final expr3 = x - x;
      check(expr3.simplify()).equals(const RationalNumber(0));

      // x - 0 -> x
      check((x - 0).simplify()).equals(x);

      // 0 + x -> x, x + 0 -> x
      check((const RationalNumber(0) + x).simplify()).equals(x);
      check((x + const RationalNumber(0)).simplify()).equals(x);

      // x * 1 -> x, 1 * x -> x
      check((x * 1).simplify()).equals(x);
      check((const RationalNumber(1) * x).simplify()).equals(x);

      // x * -1 -> -x, -1 * x -> -x
      check((x * -1).simplify()).equals(const Neg(x));
      check((const RationalNumber(-1) * x).simplify()).equals(const Neg(x));

      // 0 * x -> 0
      check((const RationalNumber(0) * x).simplify())
          .equals(const RationalNumber(0));

      // 0 / x -> 0, x / 1 -> x, x / x -> 1
      check((const RationalNumber(0) / x).simplify())
          .equals(const RationalNumber(0));
      check((x / 1).simplify()).equals(x);
      check((x / x).simplify()).equals(const RationalNumber(1));
      check((const RationalNumber(6) / const RationalNumber(2)).simplify())
          .equals(const RationalNumber(3));
      check(
        () => (const RationalNumber(6) / const RationalNumber(0)).simplify(),
      ).throws<UnsupportedError>();

      // x^0 -> 1, x^1 -> x, 0^x -> 0, 1^x -> 1
      check(x.pow(0).simplify()).equals(const RationalNumber(1));
      check(x.pow(1).simplify()).equals(x);
      check(const RationalNumber(0).pow(x).simplify())
          .equals(const RationalNumber(0));
      check(const RationalNumber(1).pow(x).simplify())
          .equals(const RationalNumber(1));
      check(const RationalNumber(2).pow(const RationalNumber(3)).simplify())
          .equals(const RationalNumber(8));

      // Neg(-(-x)) -> x
      check(const Neg(Neg(x)).simplify()).equals(x);
      check(const Neg(RationalNumber(5)).simplify())
          .equals(const RationalNumber(-5));

      // Sin, Cos, Exp, Ln of Constants
      check(const Sin(RationalNumber(0)).simplify())
          .equals(const RationalNumber(0));
      check(const Cos(RationalNumber(0)).simplify())
          .equals(const RationalNumber(1));
      check(const Exp(RationalNumber(0)).simplify())
          .equals(const RationalNumber(1));
      check(const Ln(RationalNumber(1)).simplify())
          .equals(const RationalNumber(0));
      check(() => const Ln(RationalNumber(0)).simplify())
          .throws<ArgumentError>();

      // Constants pi and e simplifications
      check(const Sin(ConstantNumber.pi).simplify())
          .equals(const RationalNumber(0));
      check(const Cos(ConstantNumber.pi).simplify())
          .equals(const RationalNumber(-1));
      check(const Ln(ConstantNumber.e).simplify())
          .equals(const RationalNumber(1));
      check(const Exp(RationalNumber(1)).simplify()).equals(ConstantNumber.e);
      check(ConstantNumber.e.pow(x).simplify()).equals(const Exp(x));
      check(const Ln(Exp(x)).simplify()).equals(x);
      check(const Exp(Ln(x)).simplify()).equals(x);
      check(const Neg(ConstantNumber.pi).simplify())
          .equals(const Neg(ConstantNumber.pi));
      check(const Neg(Neg(ConstantNumber.pi)).simplify())
          .equals(ConstantNumber.pi);
      check((ConstantNumber.pi * const RationalNumber(1)).simplify())
          .equals(ConstantNumber.pi);
      check((const RationalNumber(1) * ConstantNumber.pi).simplify())
          .equals(ConstantNumber.pi);
      check((ConstantNumber.pi + const RationalNumber(0)).simplify())
          .equals(ConstantNumber.pi);
      check((const RationalNumber(0) + ConstantNumber.pi).simplify())
          .equals(ConstantNumber.pi);
      check((ConstantNumber.pi - const RationalNumber(0)).simplify())
          .equals(ConstantNumber.pi);
      check((ConstantNumber.pi / const RationalNumber(1)).simplify())
          .equals(ConstantNumber.pi);
      check(ConstantNumber.pi.pow(const RationalNumber(1)).simplify())
          .equals(ConstantNumber.pi);
      check(ConstantNumber.pi.pow(const RationalNumber(0)).simplify())
          .equals(const RationalNumber(1));
      check((ConstantNumber.pi - ConstantNumber.pi).simplify())
          .equals(const RationalNumber(0));
      check((ConstantNumber.e * const RationalNumber(1)).simplify())
          .equals(ConstantNumber.e);
      check((ConstantNumber.e + const RationalNumber(0)).simplify())
          .equals(ConstantNumber.e);
      check(ConstantNumber.e.pow(const RationalNumber(0)).simplify())
          .equals(const RationalNumber(1));
      check(ConstantNumber.e.pow(const RationalNumber(1)).simplify())
          .equals(ConstantNumber.e);
    });

    test('like-term additions and subtractions', () {
      const x = Variable('x');
      const y = Variable('y');

      // x + x => 2 * x
      check((x + x).simplify()).equals(const Mul(RationalNumber(2), x));
      check((x + x + x).simplify()).equals(const Mul(RationalNumber(3), x));

      // c1 * x + c2 * x => (c1 + c2) * x
      final c1xPlusC2x =
          const RationalNumber(3) * x + const RationalNumber(5) * x;
      check(c1xPlusC2x.simplify()).equals(const Mul(RationalNumber(8), x));

      // x + c * x => (c + 1) * x, c * x + x => (c + 1) * x
      check((x + const RationalNumber(4) * x).simplify())
          .equals(const Mul(RationalNumber(5), x));
      check((const RationalNumber(4) * x + x).simplify())
          .equals(const Mul(RationalNumber(5), x));

      // Subtraction like-terms
      check((const RationalNumber(3) * x - x).simplify())
          .equals(const Mul(RationalNumber(2), x));
      check((x - const RationalNumber(3) * x).simplify())
          .equals(const Mul(RationalNumber(-2), x));
      check(
        (const RationalNumber(2) * x - const RationalNumber(2) * x).simplify(),
      ).equals(const RationalNumber(0));
      check((x - const RationalNumber(2) * x).simplify()).equals(const Neg(x));
      check((const RationalNumber(2) * x - x).simplify()).equals(x);

      // Additive term cancellation across mixed expressions
      check(((x + y) - x).simplify()).equals(y);
      check(((x - y) + y).simplify()).equals(x);
      check(((const RationalNumber(2) * x + y) - x).simplify())
          .equals(const Add(x, y));

      // Like terms on named constants
      check(
        (const RationalNumber(2) * ConstantNumber.pi +
                const RationalNumber(3) * ConstantNumber.pi)
            .simplify(),
      ).equals(const Mul(RationalNumber(5), ConstantNumber.pi));

      // Higher degree like terms
      final x2 = x.pow(const RationalNumber(2));
      check((x2 + x2).simplify()).equals(Mul(const RationalNumber(2), x2));
      check(
        (const RationalNumber(3) * x2 + const RationalNumber(4) * x2)
            .simplify(),
      ).equals(Mul(const RationalNumber(7), x2));
    });

    test('like-factor multiplications and power combinations', () {
      const x = Variable('x');
      const y = Variable('y');
      const a = Variable('a');
      const b = Variable('b');

      // x * x => x ^ 2
      check((x * x).simplify()).equals(x.pow(const RationalNumber(2)));
      check((x * x * x).simplify()).equals(x.pow(const RationalNumber(3)));

      // x^a * x^b => x^(a+b)
      final x2 = x.pow(const RationalNumber(2));
      final x3 = x.pow(const RationalNumber(3));
      check((x2 * x3).simplify()).equals(x.pow(const RationalNumber(5)));
      check((x * x2).simplify()).equals(x.pow(const RationalNumber(3)));
      check((x2 * x).simplify()).equals(x.pow(const RationalNumber(3)));

      // Symbolic exponents
      check((x.pow(a) * x.pow(b)).simplify()).equals(x.pow(const Add(a, b)));
      check((x * x.pow(b)).simplify())
          .equals(x.pow(const Add(b, RationalNumber(1))));
      check((x.pow(a) * x).simplify())
          .equals(x.pow(const Add(a, RationalNumber(1))));

      // Exponents cancelling
      check((x2 * x.pow(const RationalNumber(-1))).simplify()).equals(x);
      check((x2 * x.pow(const RationalNumber(-2))).simplify())
          .equals(const RationalNumber(1));

      // Scaled products: (c1 * x) * (c2 * x) => (c1 * c2) * x^2
      check(
        ((const RationalNumber(2) * x) * (const RationalNumber(3) * x))
            .simplify(),
      ).equals(Mul(const RationalNumber(6), x2));
      check(((const RationalNumber(2) * x) * x).simplify())
          .equals(Mul(const RationalNumber(2), x2));
      check((x * (const RationalNumber(2) * x)).simplify())
          .equals(Mul(const RationalNumber(2), x2));

      // Associative like-factor multiplications: (x * y) * x => x^2 * y
      check(((x * y) * x).simplify()).equals(Mul(x2, y));
      check((x * (x * y)).simplify()).equals(Mul(x2, y));
    });

    test('associative constant folding', () {
      const x = Variable('x');

      // Additive constant folding: x + 1 + 2 => x + 3
      check((x + 1 + 2).simplify()).equals(const Add(x, RationalNumber(3)));
      check((const RationalNumber(1) + x + const RationalNumber(2)).simplify())
          .equals(const Add(x, RationalNumber(3)));
      check((x + const RationalNumber(5) - const RationalNumber(2)).simplify())
          .equals(const Add(x, RationalNumber(3)));
      check((x - const RationalNumber(1) - const RationalNumber(2)).simplify())
          .equals(const Sub(x, RationalNumber(3)));

      // Multiplicative constant folding: x * 2 * 3 => 6 * x
      check(((x * 2) * 3).simplify()).equals(const Mul(RationalNumber(6), x));
      check(((const RationalNumber(2) * x) * 3).simplify())
          .equals(const Mul(RationalNumber(6), x));
      check(
        (const RationalNumber(2) * (const RationalNumber(3) * x)).simplify(),
      ).equals(const Mul(RationalNumber(6), x));
      check((const RationalNumber(2) * (x * 3)).simplify())
          .equals(const Mul(RationalNumber(6), x));
      check((((x * 2) * 3) * 4).simplify())
          .equals(const Mul(RationalNumber(24), x));
    });

    test('canonical polynomial term sorting in descending degree', () {
      const x = Variable('x');
      const y = Variable('y');
      final x2 = x.pow(const RationalNumber(2));
      final x3 = x.pow(const RationalNumber(3));

      // x + x^2 => x^2 + x
      check((x + x2).simplify()).equals(Add(x2, x));

      // 1 + x => x + 1
      check((const RationalNumber(1) + x).simplify())
          .equals(const Add(x, RationalNumber(1)));

      // 1 + x + x^2 => x^2 + x + 1
      check((const RationalNumber(1) + x + x2).simplify())
          .equals(Add(Add(x2, x), const RationalNumber(1)));

      // 3 + 2x + x^2 => x^2 + 2x + 3
      final poly1 = const RationalNumber(3) + const RationalNumber(2) * x + x2;
      check(poly1.simplify()).equals(
        Add(Add(x2, const Mul(RationalNumber(2), x)), const RationalNumber(3)),
      );

      // x^3 + 2x + 5x^2 + 1 => x^3 + 5x^2 + 2x + 1
      final poly2 =
          x3 +
          const RationalNumber(2) * x +
          const RationalNumber(5) * x2 +
          const RationalNumber(1);
      check(poly2.simplify()).equals(
        Add(
          Add(
            Add(x3, Mul(const RationalNumber(5), x2)),
            const Mul(RationalNumber(2), x),
          ),
          const RationalNumber(1),
        ),
      );

      // Polynomial with subtractions: x^2 - 2x - 3
      final polySub =
          x2 - const RationalNumber(2) * x - const RationalNumber(3);
      check(polySub.simplify()).equals(
        Sub(Sub(x2, const Mul(RationalNumber(2), x)), const RationalNumber(3)),
      );

      // Variable sorting: y + x => x + y
      check((y + x).simplify()).equals(const Add(x, y));

      // Multi-variable graded degree sorting: x^2 + y^2 + x + y
      final y2 = y.pow(const RationalNumber(2));
      check((y + x2 + y2 + x).simplify()).equals(Add(Add(Add(x2, y2), x), y));
    });
  });

  group('JIT Compilation & Tensor Kernel', () {
    test('toFunction1D zero-AST closure execution for all nodes', () {
      const x = Variable('x');
      const y = Variable('y');

      // Unbound variable in 1D throws ArgumentError
      check(() => y.toFunction1D('x')).throws<ArgumentError>();

      const complexExpr = Add(
        Sub(Mul(x, RationalNumber(2)), Div(x, RationalNumber(2))),
        Add(
          Pow(x, RationalNumber(2)),
          Add(Neg(x), Add(Sin(x), Add(Cos(x), Add(Exp(x), Ln(x))))),
        ),
      );

      final fn = complexExpr.toFunction1D('x');
      final val = fn(2.0);
      check(val).isCloseTo(
        (2.0 * 2.0 - 2.0 / 2.0) +
            4.0 -
            2.0 +
            math.sin(2.0) +
            math.cos(2.0) +
            math.exp(2.0) +
            math.log(2.0),
        1e-6,
      );
    });

    test('compile multi-variable closure', () {
      const x = Variable('x');
      const y = Variable('y');
      final expr =
          (x * 2) +
          (y * 3) +
          const Neg(x) +
          const Sin(y) +
          const Cos(x) +
          const Exp(y) +
          const Ln(x) +
          const Pow(x, y);
      final compiled = expr.compile(['x', 'y']);

      final res = compiled([2.0, 1.0]);
      check(res).isCloseTo(
        4.0 +
            3.0 -
            2.0 +
            math.sin(1.0) +
            math.cos(2.0) +
            math.exp(1.0) +
            math.log(2.0) +
            2.0,
        1e-6,
      );

      // Unbound variable throws
      check(() => expr.compile(['x'])([2.0])).throws<ArgumentError>();
    });

    test('compileTensorKernel vectorized flat loop', () {
      const x = Variable('x');
      const y = Variable('y');
      final expr = (x * 2) + y;
      final kernel = expr.compileTensorKernel(['x', 'y']);

      final xData = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final yData = Float64List.fromList([10.0, 20.0, 30.0, 40.0]);
      final out = Float64List(4);

      kernel([xData, yData], out);
      check(out.toList()).deepEquals([12.0, 24.0, 36.0, 48.0]);
    });
  });

  group('Multivariable Calculus', () {
    test('Gradient and Hessian of f(x, y) = x^2 + 3xy + y^3', () {
      const x = Variable('x');
      const y = Variable('y');
      final expr = x.pow(2) + (x * y * 3) + y.pow(3);

      final grad = expr.gradient(['x', 'y']);
      check(grad.length).equals(2);

      final dfDx = grad[0].compile(['x', 'y']);
      final dfDy = grad[1].compile(['x', 'y']);

      check(dfDx([1.0, 2.0])).equals(8.0);
      check(dfDy([1.0, 2.0])).equals(15.0);

      final hess = expr.hessian(['x', 'y']);
      check(hess.rowCount).equals(2);
      check(hess.colCount).equals(2);
      check(hess[0].length).equals(2);
      final d2fDx2 = hess[0][0].compile(['x', 'y']);
      check(d2fDx2([1.0, 2.0])).equals(2.0);
      final d2fDxDy = hess[0][1].compile(['x', 'y']);
      check(d2fDxDy([1.0, 2.0])).equals(3.0);
      final d2fDy2 = hess[1][1].compile(['x', 'y']);
      check(d2fDy2([1.0, 2.0])).equals(12.0);
    });

    test('Jacobian matrix', () {
      const x = Variable('x');
      const y = Variable('y');
      // f1(x, y) = x^2 + y
      // f2(x, y) = 3*x*y
      final f1 = x.pow(2) + y;
      final f2 = x * y * 3;

      final J = [f1, f2].jacobian(['x', 'y']);
      check(J.rowCount).equals(2);
      check(J.colCount).equals(2);
      check(J[0].length).equals(2);

      // J[0][0] = 2x, J[0][1] = 1
      check(J[0][0].evaluate({'x': 3.0, 'y': 2.0})).equals(6.0);
      check(J[0][1].evaluate({'x': 3.0, 'y': 2.0})).equals(1.0);

      // J[1][0] = 3y, J[1][1] = 3x
      check(J[1][0].evaluate({'x': 3.0, 'y': 2.0})).equals(6.0);
      check(J[1][1].evaluate({'x': 3.0, 'y': 2.0})).equals(9.0);
    });

    test('Taylor series expansion of exp(x)', () {
      const x = Variable('x');
      const expr = Exp(x);
      final taylor = expr.taylorSeries('x', around: 0.0, order: 4);

      final fn = taylor.toFunction1D('x');
      check(fn(0.5)).isCloseTo(1.6484375, 1e-4);
    });

    test(
      'Taylor series expansion of hyperbolic and inverse trig functions',
      () {
        const x = Variable('x');

        // sinh(x) ~ x + x^3/6
        const sinhExpr = Sinh(x);
        final taylorSinh = sinhExpr.taylorSeries('x', around: 0.0, order: 3);
        final fnSinh = taylorSinh.toFunction1D('x');
        check(fnSinh(0.2)).isCloseTo(0.2 + (0.008 / 6.0), 1e-6);

        // cosh(x) ~ 1 + x^2/2 + x^4/24
        const coshExpr = Cosh(x);
        final taylorCosh = coshExpr.taylorSeries('x', around: 0.0, order: 4);
        final fnCosh = taylorCosh.toFunction1D('x');
        check(fnCosh(0.2))
            .isCloseTo(1.0 + (0.04 / 2.0) + (0.0016 / 24.0), 1e-6);

        // atan(x) ~ x - x^3/3
        const atanExpr = Atan(x);
        final taylorAtan = atanExpr.taylorSeries('x', around: 0.0, order: 3);
        final fnAtan = taylorAtan.toFunction1D('x');
        check(fnAtan(0.2)).isCloseTo(0.2 - (0.008 / 3.0), 1e-6);
      },
    );

    test('compilePositional with Sub and Div', () {
      const x = Variable('x');
      const y = Variable('y');
      const z = Variable('z');
      final expr = (x - y) / z;
      final fn = expr.compile(['x', 'y', 'z']);
      check(fn([10.0, 4.0, 2.0])).equals(3.0);
    });
  });
}
