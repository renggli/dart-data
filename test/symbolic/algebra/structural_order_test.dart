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
        Factorial(x), // 25
        Binomial(x, x), // 26
        Floor(x), // 27
        Ceil(x), // 28
        Round(x), // 29
        Sign(x), // 30
        Mod(x, x), // 31
        Re(x), // 32
        Im(x), // 33
        Arg(x), // 34
        Conjugate(x), // 35
        LessThan(x, IntegerNumber.one), // 36
        LessEqual(x, IntegerNumber.one), // 37
        GreaterThan(x, IntegerNumber.one), // 38
        GreaterEqual(x, IntegerNumber.one), // 39
        Equal(x, IntegerNumber.one), // 40
        NotEqual(x, IntegerNumber.one), // 41
        Piecewise([(relation: LessThan(x, IntegerNumber.zero), expr: x)]), // 42
        Integral(x, 'x'), // 43
        Derivative(x, 'x'), // 44
        Limit(x, 'x', IntegerNumber.zero), // 45
        const OrderTerm('x', 3), // 46
        VariableFunction('f', const [x]), // 47
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

    test('compares Variable by name', () {
      const x1 = Variable('x');
      const x2 = Variable('x');
      const y = Variable('y');

      check(compareStructural(x1, x2)).equals(0);
      check(compareStructural(x1, y)).isLessThan(0);
      check(compareStructural(y, x1)).isGreaterThan(0);
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
      final pw1 = Piecewise([(relation: cond1, expr: x)]);
      final pw2 = Piecewise([
        (relation: cond1, expr: x),
        (relation: cond2, expr: y),
      ]);
      final pwCondDiff = Piecewise([(relation: cond2, expr: x)]);
      final pwValDiff = Piecewise([(relation: cond1, expr: y)]);
      final pwWithOther1 = Piecewise([
        (relation: cond1, expr: x),
      ], otherwise: IntegerNumber.zero);
      final pwWithOther2 = Piecewise([
        (relation: cond1, expr: x),
      ], otherwise: IntegerNumber.one);

      check(compareStructural(pw1, Piecewise([(relation: cond1, expr: x)])))
          .equals(0);
      check(compareStructural(pw1, pw2)).isLessThan(0);
      check(compareStructural(pw1, pwCondDiff)).isLessThan(0);
      check(compareStructural(pw1, pwValDiff)).isLessThan(0);
      check(compareStructural(pw1, pwWithOther1)).isLessThan(0);
      check(compareStructural(pwWithOther1, pw1)).isGreaterThan(0);
      check(compareStructural(pwWithOther1, pwWithOther2)).isLessThan(0);

      // VariableFunction comparisons
      final vf1 = VariableFunction('f', const [x]);
      final vf2 = VariableFunction('g', const [x]);
      final vf3 = VariableFunction('f', const [y]);
      final vf4 = VariableFunction('f', const [x, y]);
      check(compareStructural(vf1, vf2)).isLessThan(0);
      check(compareStructural(vf1, vf3)).isLessThan(0);
      check(compareStructural(vf1, vf4)).isLessThan(0);

      // Derivative comparisons
      final d1 = Derivative(x, 'x');
      final d2 = Derivative(x, 'y');
      final d3 = Derivative(x, 'x', order: 2);
      final d4 = Derivative(y, 'x');
      check(compareStructural(d1, d2)).isLessThan(0);
      check(compareStructural(d1, d3)).isLessThan(0);
      check(compareStructural(d1, d4)).isLessThan(0);

      // Limit comparisons
      final l1 = Limit(x, 'x', IntegerNumber.zero);
      final l2 = Limit(x, 'y', IntegerNumber.zero);
      final l3 = Limit(
        x,
        'x',
        IntegerNumber.zero,
        direction: LimitDirection.fromAbove,
      );
      final l4 = Limit(x, 'x', IntegerNumber.one);
      final l5 = Limit(y, 'x', IntegerNumber.zero);
      check(compareStructural(l1, l2)).isLessThan(0);
      check(compareStructural(l1, l3)).isLessThan(0);
      check(compareStructural(l1, l4)).isLessThan(0);
      check(compareStructural(l1, l5)).isLessThan(0);
    });
  });
}
