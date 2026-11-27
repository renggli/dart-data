import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:more/number.dart' show Complex, Fraction;
import 'package:test/scaffolding.dart';

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
          .equals(IntegerNumber(BigInt.from(12345)));
    });

    test('wraps Fraction', () {
      check(Expr.wrap(Fraction(3, 4)))
          .equals(FractionNumber(BigInt.from(3), BigInt.from(4)));
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
      check(Expr.tryWrap(null)).isNull;
      check(Expr.tryWrap(Object())).isNull;
      check(Expr.tryWrap([1, 2, 3])).isNull;
      check(Expr.tryWrap('invalid ???')).isNull;
    });
  });

  group('Expr parsing', () {
    test('parse and tryParse with standard and custom syntax', () {
      check(Expr.parse('x + 1')).equals(const Variable('x') + 1);
      check(Expr.tryParse('x + 1')).equals(const Variable('x') + 1);
      check(Expr.tryParse('invalid ???')).isNull;

      final syntax = ExprSyntax(constants: {'k': IntegerNumber.of(7)});
      check(Expr.parse('k', syntax: syntax)).equals(IntegerNumber.of(7));
      check(Expr.tryParse('k', syntax: syntax)).equals(IntegerNumber.of(7));
    });
  });

  group('Expr operator overloading and wrapping', () {
    test('arithmetic operators accept Expr, int, BigInt, double, Complex, and String', () {
      const x = Variable('x');
      final big = BigInt.from(10);

      check(x + 2).equals(Add.of([x, IntegerNumber.two]));
      check(x + big).equals(Add.of([x, IntegerNumber(big)]));
      check(x + 1.5).equals(Add.of([x, const RealNumber(1.5)]));
      check(x + const Complex(2, 3)).equals(
        Add.of([x, ComplexNumber(IntegerNumber.two, IntegerNumber.of(3))]),
      );
      check(x + const Complex(2.5, 0.0))
          .equals(Add.of([x, const RealNumber(2.5)]));
      check(x + const Complex(double.infinity, 0.0))
          .equals(Add.of([x, Constant.infinity]));
      check(x + const Complex(double.infinity, 2.5)).equals(
        Add.of([
          x,
          Constant.infinity,
          ComplexNumber(const RealNumber(0.0), const RealNumber(2.5)),
        ]),
      );
      check(x + 'y').equals(Add.of([x, const Variable('y')]));

      check(x - 3).equals(Add.of([x, IntegerNumber.of(-3)]));
      check(x * 3).equals(Mul.of([x, IntegerNumber.of(3)]));
      check(x * (x * 2))
          .equals(Mul.of([IntegerNumber.two, Pow.of(x, IntegerNumber.two)]));
      check(x / 3).equals(
        Mul.of([x, Pow.of(IntegerNumber.of(3), IntegerNumber.negativeOne)]),
      );
      check(x.pow(2)).equals(Pow.of(x, IntegerNumber.two));
      check(x.pow(big)).equals(Pow.of(x, IntegerNumber(big)));
      check(x.pow(0.5)).equals(Pow.of(x, const RealNumber(0.5)));
      check(
        x.pow(const Complex(1, 1)),
      ).equals(Pow.of(x, ComplexNumber(IntegerNumber.one, IntegerNumber.one)));
      check(x.pow('n')).equals(Pow.of(x, const Variable('n')));

      check(() => x + Object()).throws<ArgumentError>();
      check(() => x.pow(Object())).throws<ArgumentError>();
    });

    test('symmetric ComplexNumber operator folding and precision matching', () {
      final i = ComplexNumber.i;
      final two = IntegerNumber.two;
      const realTwo = RealNumber(2.0);

      // Symmetric addition
      check(two + i).equals(ComplexNumber(two, IntegerNumber.one));
      check(i + two).equals(ComplexNumber(two, IntegerNumber.one));
      check(i + i).equals(ComplexNumber(IntegerNumber.zero, two));

      // Symmetric subtraction
      check(two - i).equals(ComplexNumber(two, IntegerNumber.negativeOne));
      check(i - two)
          .equals(ComplexNumber(IntegerNumber.of(-2), IntegerNumber.one));
      check(i - i).equals(IntegerNumber.zero);

      // Symmetric multiplication
      check(two * i).equals(ComplexNumber(IntegerNumber.zero, two));
      check(i * two).equals(ComplexNumber(IntegerNumber.zero, two));
      check(i * i).equals(IntegerNumber.negativeOne);

      // Division with ComplexNumber
      check(i / 2)
          .equals(ComplexNumber(IntegerNumber.zero, FractionNumber.half));
      check(i / i).equals(IntegerNumber.one);
      check((two * i) / i).equals(two);

      // RealNumber precision matching across operators
      check(realTwo * i)
          .equals(ComplexNumber(const RealNumber(0.0), const RealNumber(2.0)));
      check(i * realTwo)
          .equals(ComplexNumber(const RealNumber(0.0), const RealNumber(2.0)));
      check(realTwo + i)
          .equals(ComplexNumber(const RealNumber(2.0), const RealNumber(1.0)));
      check(i + realTwo)
          .equals(ComplexNumber(const RealNumber(2.0), const RealNumber(1.0)));
      check(realTwo - i)
          .equals(ComplexNumber(const RealNumber(2.0), const RealNumber(-1.0)));
      check(i - realTwo)
          .equals(ComplexNumber(const RealNumber(-2.0), const RealNumber(1.0)));
      check(i / realTwo)
          .equals(ComplexNumber(const RealNumber(0.0), const RealNumber(0.5)));
    });

    test('unary negation on numbers, products, and general expressions', () {
      const x = Variable('x');
      const y = Variable('y');

      check(-IntegerNumber.two).equals(IntegerNumber.of(-2));
      check(-ComplexNumber.i).equals(ComplexNumber.negativeI);

      final negX = -x;
      check(negX).equals(Mul.of([IntegerNumber.negativeOne, x]));
      check(-negX).equals(x);

      final negProd3 = Mul.of([IntegerNumber.negativeOne, x, y]);
      check(-negProd3).equals(Mul.of([x, y]));

      final scaled = Mul.of([IntegerNumber.two, x]);
      check(-scaled).equals(Mul.of([IntegerNumber.of(-2), x]));

      final unscaled = Mul.of([x, y]);
      check(-unscaled).equals(Mul.of([IntegerNumber.negativeOne, x, y]));
    });

    test('isReal detects complex literals in AST subtrees', () {
      const x = Variable('x');
      check((x + IntegerNumber.two).isReal).isTrue;
      check((x + ComplexNumber.i).isReal).isFalse;
      check(Fn.sin(ComplexNumber.i).isReal).isFalse;
      check(Fn.asin(Constant.pi).isReal).isFalse;
      check(Fn.acos(Constant.pi).isReal).isFalse;
      check(Fn.atanh(Constant.e).isReal).isFalse;
      check(Fn.acosh(IntegerNumber.zero).isReal).isFalse;
      check(Fn.lambertW(IntegerNumber.of(-1)).isReal).isFalse;
      check(Fn.lambertW(IntegerNumber.one, IntegerNumber.negativeOne).isReal)
          .isFalse;
      check(Fn.lambertW(IntegerNumber.one).isReal).isTrue;
      check(Fn.ln(IntegerNumber.of(-2)).isReal).isFalse;
      check(
        Fn.hypergeometric(
          Fn.tuple([IntegerNumber.one]),
          Fn.tuple([IntegerNumber.two]),
          x,
        ).isReal,
      ).isTrue;
      check(
        Fn.hypergeometric(
          Fn.tuple([ComplexNumber.i]),
          Fn.tuple([IntegerNumber.two]),
          x,
        ).isReal,
      ).isFalse;
      check(Fn.min([x, IntegerNumber.one]).isReal).isTrue;
      check(Fn.max([x, IntegerNumber.one]).isReal).isTrue;
      check(Fn.gcd([x, IntegerNumber.one]).isReal).isTrue;
      check(Fn.lcm([x, IntegerNumber.one]).isReal).isTrue;
      check(Fn.tuple([x, IntegerNumber.one]).isReal).isTrue;
      check(Fn.beta(x, IntegerNumber.two).isReal).isTrue;
      check(Fn.polygamma(IntegerNumber.one, x).isReal).isTrue;
      check(Fn.ellipticF(x, FractionNumber.half).isReal).isTrue;
      check(Fn.ellipticPi(FractionNumber.half, x, FractionNumber.half).isReal)
          .isTrue;
    });
  });
}
