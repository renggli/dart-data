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
  });
}
