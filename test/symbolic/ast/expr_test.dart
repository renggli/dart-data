import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:more/number.dart' show Complex, Fraction;
import 'package:test/test.dart';

void main() {
  group('Expr.wrap', () {
    test('wraps Expr directly', () {
      const x = Variable('x');
      check(Expr.wrap(x)).equals(x);
    });

    test('wraps int and BigInt', () {
      check(Expr.wrap(42)).equals(IntegerNumber.of(42));
      check(Expr.wrap(-7)).equals(IntegerNumber.of(-7));
      check(Expr.wrap(BigInt.from(12345)))
          .equals(IntegerNumber(Integer.big(BigInt.from(12345))));
    });

    test('wraps Integer', () {
      check(Expr.wrap(Integer.from(100) as Object))
          .equals(IntegerNumber.of(100));
    });

    test('wraps Fraction', () {
      check(Expr.wrap(Fraction(3, 4)))
          .equals(FractionNumber(Integer.from(3), Integer.from(4)));
      check(Expr.wrap(Fraction(6, 2))).equals(IntegerNumber.of(3));
    });

    test('wraps double', () {
      check(Expr.wrap(2.5)).equals(const RealNumber(2.5));
      check(Expr.wrap(double.infinity)).equals(Constant.infinity);
      check(Expr.wrap(double.negativeInfinity)).equals(-Constant.infinity);
      check(Expr.wrap(double.nan)).equals(Constant.undefined);
    });

    test('wraps Complex', () {
      check(Expr.wrap(const Complex(5, 0))).equals(IntegerNumber.of(5));
      check(Expr.wrap(const Complex(2.5, 0))).equals(const RealNumber(2.5));
      check(Expr.wrap(const Complex(0, 1))).equals(ComplexNumber.i);
      check(Expr.wrap(const Complex(3, 4)))
          .equals(ComplexNumber(IntegerNumber.of(3), IntegerNumber.of(4)));
    });

    test('wraps String via parsing', () {
      check(Expr.wrap('x')).equals(const Variable('x'));
      check(Expr.wrap('x + 1')).equals(const Variable('x') + 1);
      check(() => Expr.wrap('invalid ???')).throws<ArgumentError>();
    });

    test('throws ArgumentError on unsupported types', () {
      check(() => Expr.wrap(Object())).throws<ArgumentError>();
      check(() => Expr.wrap([1, 2, 3])).throws<ArgumentError>();
    });
  });

  group('Expr.tryWrap', () {
    test('returns Expr or converted value on success', () {
      const x = Variable('x');
      check(Expr.tryWrap(x)).equals(x);
      check(Expr.tryWrap(42)).equals(IntegerNumber.of(42));
      check(Expr.tryWrap('x + 1')).equals(const Variable('x') + 1);
    });

    test('returns null on failure', () {
      check(Expr.tryWrap(null)).isNull();
      check(Expr.tryWrap(Object())).isNull();
      check(Expr.tryWrap([1, 2, 3])).isNull();
      check(Expr.tryWrap('invalid ???')).isNull();
    });
  });

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
      check(x + const Complex(2.5, 0.0))
          .equals(Add([x, const RealNumber(2.5)]));
      check(x + const Complex(double.infinity, 0.0))
          .equals(Add([x, Constant.infinity]));
      check(x + const Complex(double.infinity, 2.5)).equals(
        Add([
          x,
          Constant.infinity,
          const ComplexNumber(IntegerNumber.zero, RealNumber(2.5)),
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
      check(Asin(Constant.pi).isReal).isFalse();
      check(Acos(Constant.pi).isReal).isFalse();
      check(Atanh(Constant.e).isReal).isFalse();
      check(Acosh(IntegerNumber.zero).isReal).isFalse();
      check(LambertW(IntegerNumber.of(-1)).isReal).isFalse();
      check(LambertW(IntegerNumber.one, branch: -1).isReal).isFalse();
      check(LambertW(IntegerNumber.one).isReal).isTrue();
      check(Ln(IntegerNumber.of(-2)).isReal).isFalse();
    });
  });
}
