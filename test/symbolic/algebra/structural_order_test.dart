import 'package:checks/checks.dart';
import 'package:data/src/symbolic/algebra/structural_order.dart';
import 'package:data/symbolic.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('Node tags and cross-type ordering', () {
    test('assigns strictly increasing tags across all 33 AST node types', () {
      const x = Variable('x');
      final allVariants = <Expr>[
        IntegerNumber.one, // 0
        Constant.pi, // 1
        x, // 2
        Cos(x), // 3
        Ln(x), // 4
        Sin(x), // 5
        Tan(x), // 6
        Asin(x), // 7
        Acos(x), // 8
        Atan(x), // 9
        Sinh(x), // 10
        Cosh(x), // 11
        Tanh(x), // 12
        Asinh(x), // 13
        Acosh(x), // 14
        Atanh(x), // 15
        Abs(x), // 16
        Pow(x, IntegerNumber.two), // 17
        Mul([IntegerNumber.two, x]), // 18
        Add([IntegerNumber.one, x]), // 19
        LambertW(x), // 20
        Erf(x), // 21
        Erfc(x), // 22
        Gamma(x), // 23
        Beta(x, x), // 24
        LessThan(x, IntegerNumber.one), // 25
        LessEqual(x, IntegerNumber.one), // 26
        GreaterThan(x, IntegerNumber.one), // 27
        GreaterEqual(x, IntegerNumber.one), // 28
        Equal(x, IntegerNumber.one), // 29
        Piecewise([(LessThan(x, IntegerNumber.zero), x)]), // 30
        Integral(x, 'x'), // 31
        const OrderTerm('x', 3), // 32
      ];

      for (var i = 0; i < allVariants.length; i++) {
        check(nodeTag(allVariants[i])).equals(i);
        check(compareStructural(allVariants[i], allVariants[i])).equals(0);
        for (var j = i + 1; j < allVariants.length; j++) {
          check(compareStructural(allVariants[i], allVariants[j]))
              .isLessThan(0);
          check(compareStructural(allVariants[j], allVariants[i]))
              .isGreaterThan(0);
        }
      }
    });
  });

  group('Within-type structural comparisons', () {
    test('compares Number subtypes and ComplexNumber components', () {
      final n1 = IntegerNumber.of(-2);
      const n2 = FractionNumber.half;
      const n3 = RealNumber(1.5);
      final c1 = ComplexNumber.of(IntegerNumber.one, IntegerNumber.one);
      final c2 = ComplexNumber.of(IntegerNumber.one, IntegerNumber.two);
      final c3 = ComplexNumber.of(IntegerNumber.two, IntegerNumber.one);

      check(compareStructural(n1, n2)).isLessThan(0);
      check(compareStructural(n2, n3)).isLessThan(0);
      check(compareStructural(n3, c1)).isLessThan(0);
      check(compareStructural(c1, n3)).isGreaterThan(0);
      check(compareStructural(c1, c2)).isLessThan(0);
      check(compareStructural(c2, c1)).isGreaterThan(0);
      check(compareStructural(c1, c3)).isLessThan(0);
      check(compareStructural(c3, c1)).isGreaterThan(0);

      check(realScalarValue(n2)).equals(0.5);
      check(realScalarValue(c1)).isNull();
      check(realScalarValue(const Variable('x'))).isNull();
    });

    test('compares Constant nodes by name, value (including NaN), latex, and mathMl', () {
      check(compareStructural(Constant.e, Constant.pi)).isLessThan(0);

      const cReal1 = Constant('c', Complex(1.0));
      const cReal2 = Constant('c', Complex(2.0));
      const cNanA = Constant('c', Complex.nan, latex: 'a');
      const cNanB = Constant('c', Complex.nan, latex: 'b');
      const cImag1 = Constant('c', Complex(1.0, 1.0));
      const cImag2 = Constant('c', Complex(1.0, 2.0));
      const cMathMl1 = Constant(
        'c',
        Complex(1.0),
        latex: 'c',
        mathMl: '<mi>a</mi>',
      );
      const cMathMl2 = Constant(
        'c',
        Complex(1.0),
        latex: 'c',
        mathMl: '<mi>b</mi>',
      );

      check(compareStructural(cReal1, cReal2)).isLessThan(0);
      check(compareStructural(cReal1, cNanA)).isLessThan(0);
      check(compareStructural(cNanA, cReal1)).isGreaterThan(0);
      check(compareStructural(cNanA, cNanB)).isLessThan(0);
      check(compareStructural(cImag1, cImag2)).isLessThan(0);
      check(compareStructural(cMathMl1, cMathMl2)).isLessThan(0);
    });

    test('compares Variable by name and VariableDomain', () {
      const xUnknown = Variable('x');
      const xReal = Variable('x', domain: VariableDomain.real);
      const xPos = Variable('x', domain: VariableDomain.positive);
      const yUnknown = Variable('y');

      check(compareStructural(xUnknown, yUnknown)).isLessThan(0);
      check(compareStructural(xUnknown, xReal)).isLessThan(0);
      check(compareStructural(xReal, xPos)).isLessThan(0);
      check(compareStructural(xPos, xReal)).isGreaterThan(0);
    });

    test('compares UnaryExpr, BinaryExpr, LambertW, Add, and Mul', () {
      const x = Variable('x');
      const y = Variable('y');

      check(compareStructural(Sin(x), Sin(y))).isLessThan(0);
      check(compareStructural(LambertW(x, branch: -1), LambertW(x)))
          .isLessThan(0);
      check(compareStructural(LambertW(x), LambertW(y))).isLessThan(0);

      check(
        compareStructural(Pow(x, IntegerNumber.two), Pow(y, IntegerNumber.two)),
      ).isLessThan(0);
      check(
        compareStructural(
          Pow(x, IntegerNumber.two),
          Pow(x, IntegerNumber.of(3)),
        ),
      ).isLessThan(0);

      check(compareStructural(Add([x, y]), Add([x, y, IntegerNumber.one])))
          .isLessThan(0);
      check(compareStructural(Mul([x, y]), Mul([x, IntegerNumber.two])))
          .isGreaterThan(0);
    });

    test('compares Integral, OrderTerm, and Piecewise across all fields', () {
      const x = Variable('x');
      const y = Variable('y');

      // Integral comparisons
      final intX = Integral(x, 'x');
      final intY = Integral(x, 'y');
      final intX2 = Integral(y, 'x');
      final intDef1 = Integral(
        x,
        'x',
        lower: IntegerNumber.zero,
        upper: IntegerNumber.one,
      );
      final intDef2 = Integral(
        x,
        'x',
        lower: IntegerNumber.one,
        upper: IntegerNumber.two,
      );
      final intDef3 = Integral(
        x,
        'x',
        lower: IntegerNumber.zero,
        upper: IntegerNumber.two,
      );

      check(compareStructural(intX, intY)).isLessThan(0);
      check(compareStructural(intX, intX2)).isLessThan(0);
      check(compareStructural(intX, Integral(x, 'x'))).equals(0);
      check(compareStructural(intX, intDef1)).isLessThan(0);
      check(compareStructural(intDef1, intX)).isGreaterThan(0);
      check(compareStructural(intDef1, intDef2)).isLessThan(0);
      check(compareStructural(intDef1, intDef3)).isLessThan(0);

      // OrderTerm comparisons
      const ordX2 = OrderTerm('x', 2);
      const ordY2 = OrderTerm('y', 2);
      const ordX3 = OrderTerm('x', 3);
      const ordX2Shifted = OrderTerm('x', 2, point: IntegerNumber.one);

      check(compareStructural(ordX2, ordY2)).isLessThan(0);
      check(compareStructural(ordX2, ordX3)).isLessThan(0);
      check(compareStructural(ordX2, ordX2Shifted)).isLessThan(0);

      // Piecewise comparisons
      final cond1 = LessThan(x, IntegerNumber.zero);
      final cond2 = LessThan(x, IntegerNumber.one);
      final pw1 = Piecewise([(cond1, x)]);
      final pw2 = Piecewise([(cond1, x), (cond2, y)]);
      final pwCondDiff = Piecewise([(cond2, x)]);
      final pwValDiff = Piecewise([(cond1, y)]);
      final pwWithOther1 = Piecewise([
        (cond1, x),
      ], otherwise: IntegerNumber.zero);
      final pwWithOther2 = Piecewise([
        (cond1, x),
      ], otherwise: IntegerNumber.one);

      check(compareStructural(pw1, Piecewise([(cond1, x)]))).equals(0);
      check(compareStructural(pw1, pw2)).isLessThan(0);
      check(compareStructural(pw1, pwCondDiff)).isLessThan(0);
      check(compareStructural(pw1, pwValDiff)).isLessThan(0);
      check(compareStructural(pw1, pwWithOther1)).isLessThan(0);
      check(compareStructural(pwWithOther1, pw1)).isGreaterThan(0);
      check(compareStructural(pwWithOther1, pwWithOther2)).isLessThan(0);
    });
  });
}
