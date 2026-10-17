import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/test.dart';

void main() {
  group('Expr parsing', () {
    test('parse and tryParse with standard and custom syntax', () {
      check(Expr.parse('x + 1')).equals(const Variable('x') + 1);
      check(Expr.tryParse('x + 1')).equals(const Variable('x') + 1);
      check(Expr.tryParse('invalid ???')).isNull();

      final syntax = ExprSyntax(constants: {'k': IntegerNumber.of(7)});
      check(Expr.parse('k', syntax: syntax)).equals(IntegerNumber.of(7));
      check(Expr.tryParse('k', syntax: syntax)).equals(IntegerNumber.of(7));
    });
  });

  group('Expr operator overloading and wrapping', () {
    test('arithmetic operators accept Expr, int, BigInt, double, Complex, and String', () {
      const x = Variable('x');
      final big = BigInt.from(10);

      check(x + 2).equals(Add([x, IntegerNumber.two]));
      check(x + big).equals(Add([x, IntegerNumber(Integer.big(big))]));
      check(x + 1.5).equals(Add([x, const RealNumber(1.5)]));
      check(
        x + const Complex(2, 3),
      ).equals(Add([x, ComplexNumber(IntegerNumber.two, IntegerNumber.of(3))]));
      check(x + const Complex(2.0, 0.0)).equals(Add([x, IntegerNumber.two]));
      check(x + const Complex(2.5, 0.0))
          .equals(Add([x, const RealNumber(2.5)]));
      check(x + const Complex(double.infinity, 0.0))
          .equals(Add([x, Constant.infinity]));
      check(x + const Complex(double.infinity, 2.0)).equals(
        Add([
          x,
          Constant.infinity,
          Mul([IntegerNumber.two, ComplexNumber.i]),
        ]),
      );
      check(x + 'y').equals(Add([x, const Variable('y')]));

      check(x - 3).equals(Add([x, IntegerNumber.of(-3)]));
      check(x * 3).equals(Mul([x, IntegerNumber.of(3)]));
      check(x * (x * 2)).equals(Mul([x, x, IntegerNumber.two]));
      check(
        x / 3,
      ).equals(Mul([x, Pow(IntegerNumber.of(3), IntegerNumber.negativeOne)]));
      check(x.pow(2)).equals(Pow(x, IntegerNumber.two));
      check(x.pow(big)).equals(Pow(x, IntegerNumber(Integer.big(big))));
      check(x.pow(0.5)).equals(Pow(x, const RealNumber(0.5)));
      check(x.pow(const Complex(1, 1))).equals(
        Pow(x, const ComplexNumber(IntegerNumber.one, IntegerNumber.one)),
      );
      check(x.pow('n')).equals(Pow(x, const Variable('n')));

      check(() => x + Object()).throws<ArgumentError>();
      check(() => x.pow(Object())).throws<ArgumentError>();
    });

    test('unary negation on numbers, products, and general expressions', () {
      const x = Variable('x');
      const y = Variable('y');

      check(-IntegerNumber.two).equals(IntegerNumber.of(-2));
      check(-ComplexNumber.i).equals(ComplexNumber.negativeI);

      final negX = -x;
      check(negX).equals(Mul([IntegerNumber.negativeOne, x]));
      check(-negX).equals(x);

      final negProd3 = Mul([IntegerNumber.negativeOne, x, y]);
      check(-negProd3).equals(Mul([x, y]));

      final scaled = Mul([IntegerNumber.two, x]);
      check(-scaled).equals(Mul([IntegerNumber.of(-2), x]));

      final unscaled = Mul([x, y]);
      check(-unscaled).equals(Mul([IntegerNumber.negativeOne, x, y]));
    });

    test('isReal detects complex literals in AST subtrees', () {
      const x = Variable('x');
      check((x + IntegerNumber.two).isReal).isTrue();
      check((x + ComplexNumber.i).isReal).isFalse();
      check(Sin(ComplexNumber.i).isReal).isFalse();
    });
  });
}
