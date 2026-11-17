import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/symbolic.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/test.dart';

void main() {
  group('CompilerExtension and closure targets', () {
    test('toFunction1D and toComplexFunction1D evaluate accurately', () {
      final f = Expr.parse('x^3 - 2*x + 1').toFunction1D('x');
      check(f(2.0)).equals(5.0);

      final cf = Expr.parse('exp(i * x)').toComplexFunction1D('x');
      final val = cf(const Complex(0.0));
      check(val.a).isCloseTo(1.0, 1e-12);
      check(val.b).isCloseTo(0.0, 1e-12);
    });

    test('compileComplex evaluates named complex variable bindings', () {
      final expr = Expr.parse('x + i * y');
      final fn = expr.compileComplex();
      final res = fn({'x': const Complex(2, 1), 'y': const Complex(3, -1)});
      check(res).equals(const Complex(3, 4));
    });

    test('toVectorFunction, compile, and compileTensorKernel evaluate multivariable expressions', () {
      final expr = Expr.parse('x^2 + 2*y');
      final vfn = expr.toVectorFunction(['x', 'y']);
      check(vfn(Vector.fromList([3.0, 4.0]))).equals(17.0);

      final cfn = expr.compile(['x', 'y']);
      check(cfn([3.0, 4.0])).equals(17.0);

      final kernel = expr.compileTensorKernel(['x', 'y']);
      final out = Float64List(2);
      kernel([
        Float64List.fromList([1.0, 3.0]),
        Float64List.fromList([2.0, 4.0]),
      ], out);
      check(out[0]).equals(5.0);
      check(out[1]).equals(17.0);
    });

    test(
      'CompilerIterableExtension compiles vector systems of expressions',
      () {
        const x = Variable('x');
        const y = Variable('y');
        final sys = [x + y, x - y].toVectorFunction(['x', 'y']);
        final v = sys(Vector.fromList([5.0, 2.0]));
        check(v[0]).equals(7.0);
        check(v[1]).equals(3.0);
      },
    );

    test(
      'evaluates Re and Im on expressions with complex intermediate branches',
      () {
        const x = Variable('x');
        final imSqrt = Im(Pow(x, FractionNumber.half));
        final reSqrt = Re(Pow(x, FractionNumber.half));
        check(imSqrt.evaluate({'x': -4.0})).equals(2.0);
        check(reSqrt.evaluate({'x': -4.0})).equals(0.0);
        check(imSqrt.toFunction1D('x')(-4.0)).equals(2.0);
        check(reSqrt.toFunction1D('x')(-4.0)).equals(0.0);
        check(Expr.parse('abs(sqrt(x))').toFunction1D('x')(-4.0)).equals(2.0);
        check(Expr.parse('sqrt(x)').toFunction1D('x')(-4.0).isNaN).isTrue();
      },
    );

    test('evaluateComplex on branch-cut expressions matches finite-difference derivatives', () {
      const h = Complex(1e-7, 0);
      const z = Complex(0.37, 0.29);
      const params = {'a': Complex(0.63, 0.19), 'b': Complex(0.94, 0.12)};

      for (final source in [
        '(x - sqrt(a + x^2))^b',
        'ln(x - sqrt(x^2 + 1))',
        'sqrt(x^2 - 16)',
      ]) {
        final expr = Expr.parse(source);
        final deriv = expr.derivative('x');
        final fPlus = expr.evaluateComplex({...params, 'x': z + h});
        final fMinus = expr.evaluateComplex({...params, 'x': z - h});
        final fd = (fPlus - fMinus) / (h * const Complex(2));
        final exact = deriv.evaluateComplex({...params, 'x': z});
        check((exact - fd).abs()).isLessThan(1e-6);
      }
    });
  });

  group('Compiler error handling', () {
    test('rejects complex literals in real mode, missing bindings, and mismatched tensor buffers', () {
      const x = Variable('x');
      final complexExpr = x + ComplexNumber.i;
      check(() => complexExpr.toFunction1D('x')).throws<UnsupportedError>();
      check(() => complexExpr.toVectorFunction(['x']))
          .throws<UnsupportedError>();
      check(() => complexExpr.compile(['x'])).throws<UnsupportedError>();
      check(() => complexExpr.compileTensorKernel(['x']))
          .throws<UnsupportedError>();

      const nonRealConst = Constant('c', Complex(1, 2));
      check(() => (x + nonRealConst).toFunction1D('x'))
          .throws<UnsupportedError>();
      check((x + nonRealConst).toComplexFunction1D('x')(const Complex(2, 0)))
          .equals(const Complex(3, 2));

      final exprXY = x + const Variable('y');
      check(() => exprXY.evaluate({'x': 1.0})).throws<ArgumentError>();
      check(() => exprXY.evaluateComplex({'x': Complex.one}))
          .throws<ArgumentError>();

      final kernelXY = exprXY.compileTensorKernel(['x', 'y']);
      final out = Float64List(3);
      check(() => kernelXY([Float64List(3)], out)).throws<ArgumentError>();
      check(() => kernelXY([Float64List(3), Float64List(2)], out))
          .throws<ArgumentError>();
    });

    test('evaluates special integral and polylog functions in real and complex modes', () {
      const x = Variable('x');
      final realCases = <(Expr, double)>[
        (Erfi(x), 1.6504257587975428),
        (FresnelS(x), 0.43825914739035476),
        (FresnelC(x), 0.7798934003768228),
        (ExpIntegralEi(x), 1.8951178163559368),
        (LogIntegralLi(IntegerNumber.two * x), 1.0451637801174928),
        (SinIntegralSi(x), 0.946083070367183),
        (CosIntegralCi(x), 0.33740392290096813),
        (SinhIntegralShi(x), 1.0572508753757285),
        (CoshIntegralChi(x), 0.8378669409802082),
        (UpperGamma(IntegerNumber.two, x), 0.7357588823428847),
        (LowerGamma(IntegerNumber.two, x), 0.2642411176571153),
        (
          Polylog(IntegerNumber.two, FractionNumber.half * x),
          0.5822405264650125,
        ),
        (EllipticF(x, FractionNumber.half), 1.0373561200021775),
        (EllipticEIncomplete(x, FractionNumber.half), 0.9648764587424907),
      ];

      for (final (expr, expected) in realCases) {
        check(expr.evaluate({'x': 1.0})).isCloseTo(expected, 1e-10);
        final cVal = expr.evaluateComplex({'x': Complex.one});
        check(cVal.a).isCloseTo(expected, 1e-10);
        check(cVal.b).isCloseTo(0.0, 1e-12);
      }

      // Complex polylog evaluation with non-zero imaginary part
      final polyC = Polylog(
        IntegerNumber.two,
        x,
      ).evaluateComplex({'x': const Complex(0.3, 0.4)});
      check(polyC.a.isFinite).isTrue();
      check(polyC.b.isFinite).isTrue();

      // Complex-input UnsupportedError for real-only special opcodes
      const z = Complex(1.0, 0.5);
      for (final expr in [
        Erfi(x),
        FresnelS(x),
        FresnelC(x),
        ExpIntegralEi(x),
        LogIntegralLi(x),
        SinIntegralSi(x),
        CosIntegralCi(x),
        SinhIntegralShi(x),
        CoshIntegralChi(x),
        UpperGamma(IntegerNumber.two, x),
        LowerGamma(IntegerNumber.two, x),
        EllipticF(x, FractionNumber.half),
        EllipticEIncomplete(x, FractionNumber.half),
      ]) {
        check(() => expr.evaluateComplex({'x': z})).throws<UnsupportedError>();
      }
    });
  });
}
