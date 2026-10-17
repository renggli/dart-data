import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('LaTeX textualization', () {
    test('renders numbers, fractions, and complex literals', () {
      check(IntegerNumber.of(42).toLatex()).equals('42');
      check(RationalNumber(3, 4).toLatex()).equals(r'\frac{3}{4}');
      check(RationalNumber(-3, 4).toLatex()).equals(r'-\frac{3}{4}');
      check(ComplexNumber.i.toLatex()).equals('i');
      check(ComplexNumber(IntegerNumber.of(2), IntegerNumber.of(3)).toLatex())
          .equals('2 + 3 i');
      check(ComplexNumber(IntegerNumber.of(2), IntegerNumber.of(-1)).toLatex())
          .equals('2 - i');
    });

    test('renders radicals, fractions, constants, and functions', () {
      check(Expr.parse('sqrt(x + 1)').toLatex()).equals(r'\sqrt{x + 1}');
      check(Constant.pi.toLatex()).equals(r'\pi');
      check(Constant.infinity.toLatex()).equals(r'\infty');
      check(Expr.parse('a / b').toLatex()).equals(r'\frac{a}{b}');
      check(Expr.parse('sin(x) + ln(x)').toLatex()).equals(r'\sin(x) + \ln(x)');
      check(const OrderTerm('x', 3).toLatex()).equals(r'O(x^{3})');
      check(Expr.parse('piecewise(x < 0, -x, x)').toLatex())
          .contains(r'\begin{cases}');
    });

    test('partitions product fractions, formats function powers, and renders integrals', () {
      check(Expr.parse('(1 / 2) * x').simplify().toLatex())
          .equals(r'\frac{x}{2}');
      check(Expr.parse('(-3 / 4) * x / y').simplify().toLatex())
          .equals(r'-\frac{3 x}{4 y}');
      check((RationalNumber(2, 3) * Expr.parse('1 + x')).toLatex())
          .equals(r'\frac{2 (1 + x)}{3}');

      check(Expr.parse('sin(x)^2').toLatex()).equals(r'\sin^{2}(x)');
      check(Expr.parse('cos(2*x)^3').toLatex()).equals(r'\cos^{3}(2 x)');
      check(Expr.parse('ln(x)^2').toLatex()).equals(r'\ln^{2}(x)');
      check(Expr.parse('sin(x)^(-1)').toLatex()).equals(r'\frac{1}{\sin(x)}');

      check(Integral(Expr.parse('exp(x^2)'), 'x').toLatex())
          .equals(r'\int e^{{x}^{2}} \, dx');
      check(
        Integral(
          Expr.parse('sin(t^2)'),
          't',
          lower: IntegerNumber.zero,
          upper: const Variable('x'),
        ).toLatex(),
      ).equals(r'\int_{0}^{x} \sin({t}^{2}) \, dt');
    });
  });
}
