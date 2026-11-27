import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('LaTeX numbers, constants, and complex literals', () {
    test('renders integers, reals, fractions, and complex numbers', () {
      check(IntegerNumber.of(42).toLatex()).equals('42');
      check(const RealNumber(2.5).toLatex()).equals('2.5');
      check(RationalNumber(3, 4).toLatex()).equals(r'\frac{3}{4}');
      check(RationalNumber(-3, 4).toLatex()).equals(r'-\frac{3}{4}');
      check(ComplexNumber.i.toLatex()).equals('i');
      check(ComplexNumber.negativeI.toLatex()).equals('-i');
      check(ComplexNumber(IntegerNumber.zero, IntegerNumber.of(3)).toLatex())
          .equals('3 i');
      check(ComplexNumber(IntegerNumber.zero, IntegerNumber.of(-3)).toLatex())
          .equals('-3 i');
      check(ComplexNumber(IntegerNumber.of(2), IntegerNumber.one).toLatex())
          .equals('2 + i');
      check(ComplexNumber(IntegerNumber.of(2), IntegerNumber.of(-1)).toLatex())
          .equals('2 - i');
      check(ComplexNumber(IntegerNumber.of(2), IntegerNumber.of(3)).toLatex())
          .equals('2 + 3 i');
      check(ComplexNumber(IntegerNumber.of(2), IntegerNumber.of(-3)).toLatex())
          .equals('2 - 3 i');
      check(Constant.pi.toLatex()).equals(r'\pi');
      check(Constant.infinity.toLatex()).equals(r'\infty');

      check(const RealNumber(1.875).toLatex()).equals('1.875');
      check(const RealNumber(1.0530000000000002).toLatex()).equals('1.053');
      check(const RealNumber(1.0530000000000002).toLatex(decimalPlaces: 2))
          .equals('1.05');
    });
  });

  group('LaTeX operators, radicals, and functions', () {
    test('renders sums, products, powers, roots, and all functions', () {
      const x = Variable('x');
      const y = Variable('y');

      check(Add.of(const []).toLatex()).equals('0');
      check(Add.of([x]).toLatex()).equals('x');
      check(Mul.of(const []).toLatex()).equals('1');
      check(Mul.of([x]).toLatex()).equals('x');

      check(Expr.parse('sqrt(x + 1)').toLatex()).equals(r'\sqrt{1 + x}');
      check(Pow.of(x, FractionNumber.third).toLatex()).equals(r'\sqrt[3]{x}');
      check(Expr.parse('a / b').toLatex()).equals(r'\frac{a}{b}');
      check(Mul.of([IntegerNumber.negativeOne, x, y]).toLatex())
          .equals(r'-x y');
      check(Mul.of([IntegerNumber.negativeOne, x + y]).toLatex())
          .equals('-(x + y)');
      check(
        Add.of([
          x,
          Mul.of([ComplexNumber.negativeI, y]),
        ]).toLatex(),
      ).equals(r'x - i y');
      check(Add.of([x, ComplexNumber.negativeI]).toLatex()).equals('-i + x');
      check(
        Add.of([
          x,
          Mul.of([IntegerNumber.of(-2), y]),
        ]).toLatex(),
      ).equals(r'x - 2 y');

      check(Fn.sin(x).toLatex()).equals(r'\sin(x)');
      check(Fn.cos(x).toLatex()).equals(r'\cos(x)');
      check(Fn.tan(x).toLatex()).equals(r'\tan(x)');
      check(Fn.asin(x).toLatex()).equals(r'\arcsin(x)');
      check(Fn.acos(x).toLatex()).equals(r'\arccos(x)');
      check(Fn.atan(x).toLatex()).equals(r'\arctan(x)');
      check(Fn.sinh(x).toLatex()).equals(r'\sinh(x)');
      check(Fn.cosh(x).toLatex()).equals(r'\cosh(x)');
      check(Fn.tanh(x).toLatex()).equals(r'\tanh(x)');
      check(Fn.asinh(x).toLatex()).equals(r'\operatorname{arsinh}(x)');
      check(Fn.acosh(x).toLatex()).equals(r'\operatorname{arcosh}(x)');
      check(Fn.atanh(x).toLatex()).equals(r'\operatorname{artanh}(x)');
      check(Fn.abs(x).toLatex()).equals(r'\left|x\right|');
      check(Fn.ln(x).toLatex()).equals(r'\ln(x)');
      check(Fn.lambertW(x).toLatex()).equals('W(x)');
      check(Fn.lambertW(x, IntegerNumber.negativeOne).toLatex())
          .equals('W_{-1}(x)');
      check(Fn.erf(x).toLatex()).equals(r'\operatorname{erf}(x)');
      check(Fn.erfc(x).toLatex()).equals(r'\operatorname{erfc}(x)');
      check(Fn.gamma(x).toLatex()).equals(r'\Gamma(x)');
      check(Fn.beta(x, y).toLatex()).equals(r'\operatorname{B}(x, y)');
      check(Fn.zeta(x).toLatex()).equals(r'\zeta(x)');
      check(Fn.digamma(x).toLatex()).equals(r'\psi(x)');
      check(Fn.polygamma(IntegerNumber.one, x).toLatex())
          .equals(r'\psi^{(1)}(x)');
      check(Fn.besselJ(IntegerNumber.zero, x).toLatex()).equals(r'J_{0}(x)');
      check(Fn.besselY(IntegerNumber.one, x).toLatex()).equals(r'Y_{1}(x)');
      check(Fn.besselI(IntegerNumber.zero, x).toLatex()).equals(r'I_{0}(x)');
      check(Fn.besselK(IntegerNumber.one, x).toLatex()).equals(r'K_{1}(x)');
      check(Fn.ellipticK(x).toLatex()).equals(r'K(x)');
      check(Fn.ellipticE(x).toLatex()).equals(r'E(x)');
    });

    test('renders OrderTerm, Piecewise, Relational, and Integral', () {
      const x = Variable('x');
      check(OrderTerm('x', 0).toLatex()).equals('O(1)');
      check(OrderTerm('x', 0, point: IntegerNumber.one).toLatex())
          .equals('O(1)');
      check(OrderTerm('x', 1).toLatex()).equals('O(x)');
      check(OrderTerm('x', 3).toLatex()).equals('O(x^{3})');
      check(OrderTerm('x', 1, point: IntegerNumber.one).toLatex())
          .equals('O(x - 1)');
      check(OrderTerm('x', 3, point: IntegerNumber.one).toLatex())
          .equals('O((x - 1)^{3})');

      check(Relational.lessThan(x, IntegerNumber.zero).toLatex())
          .equals('x < 0');
      check(Relational.lessEqual(x, IntegerNumber.zero).toLatex())
          .equals(r'x \le 0');
      check(Relational.greaterThan(x, IntegerNumber.zero).toLatex())
          .equals('x > 0');
      check(Relational.greaterEqual(x, IntegerNumber.zero).toLatex())
          .equals(r'x \ge 0');
      check(Relational.equal(x, IntegerNumber.zero).toLatex()).equals('x = 0');

      check(Expr.parse('piecewise(x < 0, -x, x)').toLatex())
          .contains(r'\begin{cases}');
      check(
        Piecewise([
          (relation: Relational.lessThan(x, IntegerNumber.zero), expr: -x),
        ]).toLatex(),
      ).contains(r'\begin{cases}');

      check(Integral(Expr.parse('exp(x^2)'), 'x').toLatex())
          .equals(r'\int e^{{x}^{2}} \, \mathrm{d}x');
      check(
        Integral(
          Expr.parse('sin(t^2)'),
          't',
          lower: IntegerNumber.zero,
          upper: x,
        ).toLatex(),
      ).equals(r'\int_{0}^{x} \sin({t}^{2}) \, \mathrm{d}t');
      check(Integral(x + IntegerNumber.one, 'x').toLatex())
          .equals(r'\int (1 + x) \, \mathrm{d}x');
      check(Integral(const Variable('theta'), 'theta').toLatex())
          .contains(r'\mathrm{d}\theta');
      check(Derivative(const Variable('theta'), 'theta').toLatex())
          .contains(r'\frac{d}{d\theta}');
      check(Expr.parse('sum(2 * abs(x), x, 1, n)').toLatex())
          .equals(r'\sum_{x=1}^{n} 2 \left|x\right|');
      check(Expr.parse('product(2 * abs(x), x, 1, n)').toLatex())
          .equals(r'\prod_{x=1}^{n} 2 \left|x\right|');
    });

    test('partitions product fractions, formats function powers, and handles multiplication dots', () {
      const x = Variable('x');
      check(Expr.parse('(1 / 2) * x').simplify().toLatex())
          .equals(r'\frac{x}{2}');
      check(Expr.parse('(-3 / 4) * x / y').simplify().toLatex())
          .equals(r'-\frac{3 x}{4 y}');
      check((RationalNumber(2, 3) * Expr.parse('1 + x')).toLatex())
          .equals(r'\frac{2 (1 + x)}{3}');
      check(
        Mul.of([IntegerNumber.negativeOne, Pow.of(x, IntegerNumber.of(-2))])
            .toLatex(),
      ).equals(r'-\frac{1}{{x}^{2}}');
      check(
        Mul.of([IntegerNumber.of(-3), Pow.of(x, IntegerNumber.negativeOne)])
            .toLatex(),
      ).equals(r'-\frac{3}{x}');

      check(Expr.parse('sin(x)^2').toLatex()).equals(r'\sin^{2}(x)');
      check(Expr.parse('cos(2*x)^3').toLatex()).equals(r'\cos^{3}(2 x)');
      check(Expr.parse('tan(x)^2').toLatex()).equals(r'\tan^{2}(x)');
      check(Expr.parse('sinh(x)^2').toLatex()).equals(r'\sinh^{2}(x)');
      check(Expr.parse('cosh(x)^2').toLatex()).equals(r'\cosh^{2}(x)');
      check(Expr.parse('tanh(x)^2').toLatex()).equals(r'\tanh^{2}(x)');
      check(Expr.parse('ln(x)^2').toLatex()).equals(r'\ln^{2}(x)');
      check(Expr.parse('sin(x)^(-1)').toLatex()).equals(r'\frac{1}{\sin(x)}');

      check(Expr.parse('2 * x').toLatex()).equals(r'2 x');
      check(Expr.parse('2 * x * y').toLatex()).equals(r'2 x y');
      check(Expr.parse('ab * c').toLatex()).equals(r'ab c');
      check(Expr.parse('x * ln(x)').toLatex()).equals(r'x \ln(x)');
      check(Expr.parse('(x - 1) * (x + 1)').toLatex())
          .equals(r'(-1 + x) (1 + x)');
      check(Expr.parse('1 / (pi * (1 + x^2))').toLatex())
          .equals(r'\frac{1}{\pi (1 + {x}^{2})}');

      final c12 = ComplexNumber(IntegerNumber.one, IntegerNumber.two);
      check(Pow.of(c12, IntegerNumber.two).toLatex()).equals('-3 + 4 i');
      check(Mul.of([c12, x]).toLatex()).equals('(1 + 2 i) x');
      check(
        Add.of([
          x,
          Mul.of([IntegerNumber.negativeOne, c12]),
        ]).toLatex(),
      ).equals('-1 - 2 i + x');
      check(Pow.of(Fn.mod(x, IntegerNumber.of(3)), IntegerNumber.two).toLatex())
          .equals(r'{(x \bmod 3)}^{2}');
      check(Mul.of([Fn.mod(x, IntegerNumber.of(3)), x]).toLatex())
          .equals(r'x (x \bmod 3)');
      check(
        Mul.of([Pow.of(IntegerNumber.two, x), Pow.of(IntegerNumber.of(3), x)])
            .toLatex(),
      ).equals(r'{2}^{x} \cdot {3}^{x}');

      // NotEqual, Derivative evaluated at a point (orders 1 and 2), and Relational in Add
      check(Relational.notEqual(x, IntegerNumber.zero).toLatex())
          .equals(r'x \ne 0');
      check(Derivative(x, 'x', order: 1, point: IntegerNumber.one).toLatex())
          .contains(r'\right|_{x = 1}');
      check(Derivative(x, 'x', order: 2, point: IntegerNumber.one).toLatex())
          .contains(r'\right|_{x = 1}');
      check(Add.of([x, Fn.mod(x, IntegerNumber.two)]).toLatex())
          .contains(r'\left(x \bmod 2\right)');
    });

    test('formats special integral and polylogarithm functions to LaTeX', () {
      const x = Variable('x');
      const k = Variable('k');
      check(Fn.erfi(x).toLatex()).equals(r'\operatorname{erfi}(x)');
      check(Fn.fresnelS(x).toLatex()).equals('S(x)');
      check(Fn.fresnelC(x).toLatex()).equals('C(x)');
      check(Fn.ei(x).toLatex()).equals(r'\operatorname{Ei}(x)');
      check(Fn.li(x).toLatex()).equals(r'\operatorname{li}(x)');
      check(Fn.si(x).toLatex()).equals(r'\operatorname{Si}(x)');
      check(Fn.ci(x).toLatex()).equals(r'\operatorname{Ci}(x)');
      check(Fn.shi(x).toLatex()).equals(r'\operatorname{Shi}(x)');
      check(Fn.chi(x).toLatex()).equals(r'\operatorname{Chi}(x)');
      check(Fn.upperGamma(IntegerNumber.two, x).toLatex())
          .equals(r'\Gamma(2, x)');
      check(Fn.lowerGamma(IntegerNumber.two, x).toLatex())
          .equals(r'\gamma(2, x)');
      check(Fn.polylog(IntegerNumber.two, x).toLatex())
          .equals(r'\operatorname{Li}_{2}(x)');
      check(Fn.ellipticF(x, k).toLatex()).equals('F(x, k)');
      check(Fn.ellipticE(x, k).toLatex()).equals('E(x, k)');
    });

    test('formats negative-shifted OrderTerm and subscripted variables', () {
      check(OrderTerm('x', 2, point: IntegerNumber.negativeOne).toLatex())
          .equals('O((x + 1)^{2})');
      check(OrderTerm('x', 1, point: IntegerNumber.negativeOne).toLatex())
          .equals('O(x + 1)');
      check(const Variable('alpha_0').toLatex()).equals(r'\alpha_{0}');
      check(const Variable('x_1').toLatex()).equals('x_{1}');
    });
  });
}
