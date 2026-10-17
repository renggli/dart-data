import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

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
    });
  });

  group('LaTeX operators, radicals, and functions', () {
    test('renders sums, products, powers, roots, and all functions', () {
      const x = Variable('x');
      const y = Variable('y');

      check(Add(const []).toLatex()).equals('0');
      check(Add([x]).toLatex()).equals('x');
      check(Mul(const []).toLatex()).equals('1');
      check(Mul([x]).toLatex()).equals('x');

      check(Expr.parse('sqrt(x + 1)').toLatex()).equals(r'\sqrt{x + 1}');
      check(Pow(x, FractionNumber.third).toLatex()).equals(r'\sqrt[3]{x}');
      check(Expr.parse('a / b').toLatex()).equals(r'\frac{a}{b}');
      check(Mul([IntegerNumber.negativeOne, x, y]).toLatex())
          .equals(r'-x \, y');
      check(Mul([IntegerNumber.negativeOne, x + y]).toLatex())
          .equals('-(x + y)');
      check(
        Add([
          x,
          Mul([ComplexNumber.negativeI, y]),
        ]).toLatex(),
      ).equals(r'x - i \, y');
      check(Add([x, ComplexNumber.negativeI]).toLatex()).equals('x - i');
      check(
        Add([
          x,
          Mul([IntegerNumber.of(-2), y]),
        ]).toLatex(),
      ).equals(r'x - 2 \, y');

      check(Sin(x).toLatex()).equals(r'\sin(x)');
      check(Cos(x).toLatex()).equals(r'\cos(x)');
      check(Tan(x).toLatex()).equals(r'\tan(x)');
      check(Asin(x).toLatex()).equals(r'\arcsin(x)');
      check(Acos(x).toLatex()).equals(r'\arccos(x)');
      check(Atan(x).toLatex()).equals(r'\arctan(x)');
      check(Sinh(x).toLatex()).equals(r'\sinh(x)');
      check(Cosh(x).toLatex()).equals(r'\cosh(x)');
      check(Tanh(x).toLatex()).equals(r'\tanh(x)');
      check(Asinh(x).toLatex()).equals(r'\operatorname{arsinh}(x)');
      check(Acosh(x).toLatex()).equals(r'\operatorname{arcosh}(x)');
      check(Atanh(x).toLatex()).equals(r'\operatorname{artanh}(x)');
      check(Abs(x).toLatex()).equals(r'\left|x\right|');
      check(Ln(x).toLatex()).equals(r'\ln(x)');
      check(LambertW(x).toLatex()).equals('W(x)');
      check(LambertW(x, branch: -1).toLatex()).equals('W_{-1}(x)');
      check(Erf(x).toLatex()).equals(r'\operatorname{erf}(x)');
      check(Erfc(x).toLatex()).equals(r'\operatorname{erfc}(x)');
      check(Gamma(x).toLatex()).equals(r'\Gamma(x)');
      check(Beta(x, y).toLatex()).equals(r'\operatorname{B}(x, y)');
    });

    test('renders OrderTerm, Piecewise, RelationalExpr, and Integral', () {
      const x = Variable('x');
      check(const OrderTerm('x', 0).toLatex()).equals('O(1)');
      check(const OrderTerm('x', 1).toLatex()).equals('O(x)');
      check(const OrderTerm('x', 3).toLatex()).equals('O(x^{3})');
      check(const OrderTerm('x', 1, point: IntegerNumber.one).toLatex())
          .equals('O(x - 1)');
      check(const OrderTerm('x', 3, point: IntegerNumber.one).toLatex())
          .equals('O((x - 1)^{3})');

      check(LessThan(x, IntegerNumber.zero).toLatex()).equals('x < 0');
      check(LessEqual(x, IntegerNumber.zero).toLatex()).equals(r'x \le 0');
      check(GreaterThan(x, IntegerNumber.zero).toLatex()).equals('x > 0');
      check(GreaterEqual(x, IntegerNumber.zero).toLatex()).equals(r'x \ge 0');
      check(Equal(x, IntegerNumber.zero).toLatex()).equals('x = 0');

      check(Expr.parse('piecewise(x < 0, -x, x)').toLatex())
          .contains(r'\begin{cases}');
      check(
        Piecewise([(relation: LessThan(x, IntegerNumber.zero), expr: -x)])
            .toLatex(),
      ).contains(r'\begin{cases}');

      check(Integral(Expr.parse('exp(x^2)'), 'x').toLatex())
          .equals(r'\int e^{{x}^{2}} \, dx');
      check(
        Integral(
          Expr.parse('sin(t^2)'),
          't',
          lower: IntegerNumber.zero,
          upper: x,
        ).toLatex(),
      ).equals(r'\int_{0}^{x} \sin({t}^{2}) \, dt');
    });

    test('partitions product fractions, formats function powers, and handles multiplication dots', () {
      const x = Variable('x');
      check(Expr.parse('(1 / 2) * x').simplify().toLatex())
          .equals(r'\frac{x}{2}');
      check(Expr.parse('(-3 / 4) * x / y').simplify().toLatex())
          .equals(r'-\frac{3 \, x}{4 \, y}');
      check((RationalNumber(2, 3) * Expr.parse('1 + x')).toLatex())
          .equals(r'\frac{2 \, (1 + x)}{3}');
      check(
        Mul([IntegerNumber.negativeOne, Pow(x, IntegerNumber.of(-2))])
            .toLatex(),
      ).equals(r'-\frac{1}{{x}^{2}}');
      check(
        Mul([IntegerNumber.of(-3), Pow(x, IntegerNumber.negativeOne)])
            .toLatex(),
      ).equals(r'-\frac{3}{x}');

      check(Expr.parse('sin(x)^2').toLatex()).equals(r'\sin^{2}(x)');
      check(Expr.parse('cos(2*x)^3').toLatex()).equals(r'\cos^{3}(2 \, x)');
      check(Expr.parse('tan(x)^2').toLatex()).equals(r'\tan^{2}(x)');
      check(Expr.parse('sinh(x)^2').toLatex()).equals(r'\sinh^{2}(x)');
      check(Expr.parse('cosh(x)^2').toLatex()).equals(r'\cosh^{2}(x)');
      check(Expr.parse('tanh(x)^2').toLatex()).equals(r'\tanh^{2}(x)');
      check(Expr.parse('ln(x)^2').toLatex()).equals(r'\ln^{2}(x)');
      check(Expr.parse('sin(x)^(-1)').toLatex()).equals(r'\frac{1}{\sin(x)}');

      check(Expr.parse('2 * x').toLatex()).equals(r'2 \, x');
      check(Expr.parse('2 * x * y').toLatex()).equals(r'2 \, x \, y');
      check(Expr.parse('ab * c').toLatex()).equals(r'ab \, c');
      check(Expr.parse('x * ln(x)').toLatex()).equals(r'x \, \ln(x)');
      check(Expr.parse('(x - 1) * (x + 1)').toLatex())
          .equals(r'(x - 1) \, (x + 1)');
      check(Expr.parse('1 / (pi * (1 + x^2))').toLatex())
          .equals(r'\frac{1}{\pi \, (1 + {x}^{2})}');
      check(
        Mul([Pow(IntegerNumber.two, IntegerNumber.of(3)), IntegerNumber.of(3)])
            .toLatex(),
      ).equals(r'{2}^{3} \cdot 3');
      check(Mul([IntegerNumber.two, IntegerNumber.of(3)]).toLatex())
          .equals(r'2 \cdot 3');
      check(
        Pow(
          const ComplexNumber(IntegerNumber.one, IntegerNumber.two),
          IntegerNumber.two,
        ).toLatex(),
      ).equals('{(1 + 2 i)}^{2}');
    });
  });
}
