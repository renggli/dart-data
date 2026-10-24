import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  const x = Variable('x');
  const y = Variable('y');
  const z = Variable('z');

  group('Affine linear form decomposition (matchLinear)', () {
    test('decomposes variables, products, and sums into a * x + b', () {
      final vLin = x.matchLinear('x');
      check(vLin).isNotNull();
      check(vLin!.a).equals(IntegerNumber.one);
      check(vLin.b).equals(IntegerNumber.zero);

      final lin1 = Expr.parse('3 * x - 7').matchLinear('x');
      check(lin1).isNotNull();
      check(lin1!.a).equals(IntegerNumber.of(3));
      check(lin1.b).equals(IntegerNumber.of(-7));

      final lin2 = Expr.parse('(2 * x + y) / 5').matchLinear('x');
      check(lin2).isNotNull();
      check(lin2!.a).equals(RationalNumber(2, 5));
      check(lin2.b.simplify()).equals((y / IntegerNumber.of(5)).simplify());

      final linMultiConst = (IntegerNumber.two * y * (x + IntegerNumber.one))
          .matchLinear('x');
      check(linMultiConst).isNotNull();
      check(linMultiConst!.a).equals((IntegerNumber.two * y).simplify());
      check(linMultiConst.b).equals((IntegerNumber.two * y).simplify());

      final linNestedAdd =
          (z + y * (x + IntegerNumber.one) + IntegerNumber.two * x).matchLinear(
            'x',
          );
      check(linNestedAdd).isNotNull();
      check(linNestedAdd!.a).equals((IntegerNumber.two + y).simplify());
      check(linNestedAdd.b).equals((y + z).simplify());

      final linNoB = (x + y * x).matchLinear('x');
      check(linNoB).isNotNull();
      check(linNoB!.a).equals((IntegerNumber.one + y).simplify());
      check(linNoB.b).equals(IntegerNumber.zero);
    });

    test('rejects constants, cancelled slopes, and non-linear expressions', () {
      check(IntegerNumber.of(5).matchLinear('x')).isNull();
      check(y.matchLinear('x')).isNull();
      check(Expr.parse('x^2 + 1').matchLinear('x')).isNull();
      check(Expr.parse('sin(x)').matchLinear('x')).isNull();
      check((x * Sin(x)).matchLinear('x')).isNull();
      check((IntegerNumber.two * Sin(x)).matchLinear('x')).isNull();
      check((y * (x + IntegerNumber.one) - y * x).matchLinear('x')).isNull();
    });
  });

  group('Scalar multiple matching (matchScalarMultiple)', () {
    test('matches identical, product, affine, and quotient multiples', () {
      check(x.matchScalarMultiple(x, 'x')).equals(IntegerNumber.one);
      check(
        (IntegerNumber.of(6) * x).matchScalarMultiple(
          IntegerNumber.two * x,
          'x',
        ),
      ).equals(IntegerNumber.of(3));
      check(
        (IntegerNumber.two * y * x * Sin(x)).matchScalarMultiple(
          x * Sin(x),
          'x',
        ),
      ).equals((IntegerNumber.two * y).simplify());
      check((IntegerNumber.two * y).matchScalarMultiple(y, 'x'))
          .equals(IntegerNumber.two);
      check(IntegerNumber.of(6).matchScalarMultiple(IntegerNumber.two, 'x'))
          .equals(IntegerNumber.of(3));

      check(
        (IntegerNumber.two * x + IntegerNumber.of(4)).matchScalarMultiple(
          x + IntegerNumber.two,
          'x',
        ),
      ).equals(IntegerNumber.two);

      check(
        Pow(
          Constant.e,
          x + IntegerNumber.one,
        ).matchScalarMultiple(Pow(Constant.e, x), 'x'),
      ).equals(Constant.e);
    });

    test(
      'returns null when expressions are not scalar multiples in variable',
      () {
        check(
          (IntegerNumber.two * x + IntegerNumber.of(5)).matchScalarMultiple(
            x + IntegerNumber.two,
            'x',
          ),
        ).isNull();
        check((x * x).matchScalarMultiple(x, 'x')).isNull();
      },
    );
  });

  group('Expression scaling (scale)', () {
    test('handles zero, unit, negative unit, and distributive scaling', () {
      final sum = x + IntegerNumber.two;
      check(sum.scale(IntegerNumber.zero)).equals(IntegerNumber.zero);
      check(sum.scale(IntegerNumber.one)).equals(sum);
      check(sum.scale(IntegerNumber.negativeOne)).equals((-sum).simplify());
      check(sum.scale(IntegerNumber.of(3)))
          .equals((IntegerNumber.of(3) * x + IntegerNumber.of(6)).simplify());
      check(x.scale(y)).equals((x * y).simplify());
    });
  });
}
