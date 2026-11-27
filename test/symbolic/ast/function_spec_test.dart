import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/scaffolding.dart';

void main() {
  group('FunctionSpec hierarchy', () {
    test('enforces fixed and optional arities across spec subtypes', () {
      const x = Variable('x');
      const y = Variable('y');
      const z = Variable('z');

      check(Fn.sin.id).equals(FunctionId.sin);
      check(Fn.sin.name).equals('sin');
      check(Fn.sin(x)).equals(Call(Fn.sin, [x]));

      check(Fn.atan2.id).equals(FunctionId.atan2);
      check(Fn.atan2(y, x)).equals(Call(Fn.atan2, [y, x]));

      check(Fn.lambertW(x).args.length).equals(1);
      check(Fn.lambertW(x, IntegerNumber.negativeOne).args.length).equals(2);
      check(Fn.zeta(x).args.length).equals(1);
      check(Fn.zeta(x, y).args.length).equals(2);
      check(Fn.ellipticE(x).args.length).equals(1);
      check(Fn.ellipticE(y, x).args.length).equals(2);

      check(Fn.ellipticPi(x, y, z).args.length).equals(3);
      check(Fn.appellF1([x, x, x, x, y, z]).args.length).equals(6);

      check(() => Fn.min([x])).returnsNormally();
      check(() => Fn.min(const [])).throws<ArgumentError>();

      const sym = SymbolicFunctionSpec('custom');
      check(sym.id).equals(FunctionId.symbolic);
      check(sym.name).equals('custom');
      check(sym.call([x, y])).equals(Fn.symbolic('custom', [x, y]));
      check(() => sym.evaluateReal([1.0])).throws<UnsupportedError>();
      check(() => sym.evaluateComplex([Complex.one]))
          .throws<UnsupportedError>();

      check(Fn.sin.evaluateReal([0.0])).equals(0.0);
      check(Fn.sin.evaluateComplex([Complex.zero])).equals(Complex.zero);
      check(Fn.atan2.evaluateReal([0.0, 1.0])).equals(0.0);
      check(Fn.atan2.evaluateComplex([Complex.zero, Complex.one]))
          .equals(Complex.zero);
    });
  });
}
