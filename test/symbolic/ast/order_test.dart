import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Structural ordering invariants', () {
    test('provides strict total ordering across all AST node variants', () {
      const x = Variable('x');
      final allVariants = <Expr>[
        IntegerNumber.one,
        Constant.pi,
        x,
        Fn.cos(x),
        Fn.ln(x),
        Fn.sin(x),
        Fn.tan(x),
        Fn.asin(x),
        Fn.acos(x),
        Fn.atan(x),
        Fn.sinh(x),
        Fn.cosh(x),
        Fn.tanh(x),
        Fn.asinh(x),
        Fn.acosh(x),
        Fn.atanh(x),
        Fn.abs(x),
        Fn.lambertW(x),
        Fn.erf(x),
        Fn.erfc(x),
        Fn.gamma(x),
        Fn.beta(x, x),
        Fn.factorial(x),
        Fn.binomial(x, x),
        Fn.floor(x),
        Fn.ceil(x),
        Fn.round(x),
        Fn.sign(x),
        Fn.mod(x, x),
        Fn.re(x),
        Fn.im(x),
        Fn.arg(x),
        Fn.conj(x),
        Fn.symbolic('f', const [x]),
        Pow.of(x, IntegerNumber.two),
        Mul.of([IntegerNumber.two, x]),
        Add.of([IntegerNumber.one, x]),
        Relational.equal(x, IntegerNumber.one),
        Relational.notEqual(x, IntegerNumber.one),
        Relational.lessThan(x, IntegerNumber.one),
        Relational.lessEqual(x, IntegerNumber.one),
        Relational.greaterThan(x, IntegerNumber.one),
        Relational.greaterEqual(x, IntegerNumber.one),
        Piecewise([
          (relation: Relational.lessThan(x, IntegerNumber.zero), expr: x),
        ]),
        Derivative(x, 'x'),
        Integral(x, 'x'),
        Limit(x, 'x', IntegerNumber.zero),
        Sum(x, 'x', IntegerNumber.one, const Variable('n')),
        Product(x, 'x', IntegerNumber.one, const Variable('n')),
        RootSum(x.pow(2) - 1, 'x', x),
        OrderTerm('x', 3),
      ];

      for (var i = 0; i < allVariants.length; i++) {
        check(compareStructural(allVariants[i], allVariants[i])).equals(0);
        for (var j = i + 1; j < allVariants.length; j++) {
          final cmp = compareStructural(allVariants[i], allVariants[j]);
          check(cmp == 0).isFalse;
          check(compareStructural(allVariants[j], allVariants[i])).equals(-cmp);
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
      check(realScalarValue(c1)).isNull;
      check(realScalarValue(const Variable('x'))).isNull;
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

    test('compares Call, Pow, Add, and Mul', () {
      const x = Variable('x');
      const y = Variable('y');

      check(compareStructural(Fn.sin(x), Fn.sin(y))).isLessThan(0);
      check(
        compareStructural(
          Fn.lambertW(x, IntegerNumber.negativeOne),
          Fn.lambertW(x),
        ),
      ).isGreaterThan(0);
      check(compareStructural(Fn.lambertW(x), Fn.lambertW(y))).isLessThan(0);

      check(
        compareStructural(
          Pow.of(x, IntegerNumber.two),
          Pow.of(y, IntegerNumber.two),
        ),
      ).isLessThan(0);
      check(
        compareStructural(
          Pow.of(x, IntegerNumber.two),
          Pow.of(x, IntegerNumber.of(3)),
        ),
      ).isLessThan(0);

      check(
        compareStructural(Add.of([x, y]), Add.of([x, y, const Variable('z')])),
      ).isLessThan(0);
      check(compareStructural(Mul.of([x, y]), Mul.of([x, IntegerNumber.two])))
          .isGreaterThan(0);
    });

    test('compares Integral, OrderTerm, Piecewise, Call, Derivative, Limit, Sum, and Product', () {
      const x = Variable('x');
      const y = Variable('y');

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

      final ordX2 = OrderTerm('x', 2);
      final ordY2 = OrderTerm('y', 2);
      final ordX3 = OrderTerm('x', 3);
      final ordX2Shifted = OrderTerm('x', 2, point: IntegerNumber.one);

      check(compareStructural(ordX2, ordY2)).isLessThan(0);
      check(compareStructural(ordX2, ordX3)).isLessThan(0);
      check(compareStructural(ordX2, ordX2Shifted)).isLessThan(0);

      final cond1 = Relational.lessThan(x, IntegerNumber.zero);
      final cond2 = Relational.lessThan(x, IntegerNumber.one);
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

      final vf1 = Fn.symbolic('f', const [x]);
      final vf2 = Fn.symbolic('g', const [x]);
      final vf3 = Fn.symbolic('f', const [y]);
      final vf4 = Fn.symbolic('f', const [x, y]);
      check(compareStructural(vf1, vf2)).isLessThan(0);
      check(compareStructural(vf1, vf3)).isLessThan(0);
      check(compareStructural(vf1, vf4)).isLessThan(0);

      final d1 = Derivative(x, 'x');
      final d2 = Derivative(x, 'y');
      final d3 = Derivative(x, 'x', order: 2);
      final d4 = Derivative(y, 'x');
      check(compareStructural(d1, d2)).isLessThan(0);
      check(compareStructural(d1, d3)).isLessThan(0);
      check(compareStructural(d1, d4)).isLessThan(0);

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

      final s1 = Sum(x, 'x', IntegerNumber.zero, IntegerNumber.one);
      final s2 = Sum(x, 'y', IntegerNumber.zero, IntegerNumber.one);
      final s3 = Sum(x, 'x', IntegerNumber.one, IntegerNumber.one);
      final s4 = Sum(x, 'x', IntegerNumber.zero, IntegerNumber.two);
      final s5 = Sum(y, 'x', IntegerNumber.zero, IntegerNumber.one);
      check(compareStructural(s1, s2)).isLessThan(0);
      check(compareStructural(s1, s3)).isLessThan(0);
      check(compareStructural(s1, s4)).isLessThan(0);
      check(compareStructural(s1, s5)).isLessThan(0);

      final p1 = Product(x, 'x', IntegerNumber.zero, IntegerNumber.one);
      final p2 = Product(x, 'y', IntegerNumber.zero, IntegerNumber.one);
      final p3 = Product(x, 'x', IntegerNumber.one, IntegerNumber.one);
      final p4 = Product(x, 'x', IntegerNumber.zero, IntegerNumber.two);
      final p5 = Product(y, 'x', IntegerNumber.zero, IntegerNumber.one);
      check(compareStructural(p1, p2)).isLessThan(0);
      check(compareStructural(p1, p3)).isLessThan(0);
      check(compareStructural(p1, p4)).isLessThan(0);
      check(compareStructural(p1, p5)).isLessThan(0);

      final i1 = Integral(x, 'x');
      final i2 = Integral(
        x,
        'x',
        lower: IntegerNumber.zero,
        upper: IntegerNumber.one,
      );
      final i3 = Integral(
        x,
        'x',
        lower: IntegerNumber.zero,
        upper: IntegerNumber.two,
      );
      check(compareStructural(i1, i2)).isLessThan(0);
      check(compareStructural(i2, i3)).isLessThan(0);
    });

    test('breaks ties deterministically between numerically equal RationalNumber and RealNumber', () {
      check(compareStructural(IntegerNumber.one, RealNumber.one)).equals(-1);
      check(compareStructural(RealNumber.one, IntegerNumber.one)).equals(1);
      final cRat = ComplexNumber.of(IntegerNumber.one, IntegerNumber.one);
      final cReal = ComplexNumber.of(IntegerNumber.one, RealNumber.one);
      check(compareStructural(cRat, cReal)).equals(-1);
      check(compareStructural(cReal, cRat)).equals(1);
    });
  });
}
