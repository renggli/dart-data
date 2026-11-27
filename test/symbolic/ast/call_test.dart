import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/scaffolding.dart';

void main() {
  group('Call AST node', () {
    test(
      'constructs built-in and symbolic calls with equality and caching',
      () {
        const x = Variable('x');
        const y = Variable('y');

        final c1 = Fn.sin(x);
        final c2 = Call(Fn.sin, [x]);
        check(c1).isA<Call>();
        check(c1).equals(c2);
        check(c1.hashCode).equals(c2.hashCode);
        check(c1.id).equals(FunctionId.sin);
        check(c1.name).equals('sin');
        check(c1.args).deepEquals([x]);

        final sym = Fn.symbolic('myFunc', [x, y]);
        check(sym.id).equals(FunctionId.symbolic);
        check(sym.name).equals('myFunc');
        check(sym.freeVariables).unorderedEquals(['x', 'y']);
        check(sym.dependsOn('x')).isTrue;
        check(sym.dependsOn('z')).isFalse;
        check(sym.anyNode((n) => n == y)).isTrue;
        check(sym.substitute('x', IntegerNumber.two))
            .equals(Fn.symbolic('myFunc', [IntegerNumber.two, y]));
        check(sym.mapChildren((e) => e == x ? y : e))
            .equals(Fn.symbolic('myFunc', [y, y]));
      },
    );

    test('evaluates real, complex, and unsupported symbolic calls', () {
      const x = Variable('x');
      check(Fn.sin(x).evaluate({'x': 0.0})).equals(0.0);
      check(Fn.sin(x).evaluateComplex({'x': const Complex(0.0)}))
          .equals(Complex.zero);

      final sym = Fn.symbolic('f', [x]);
      check(() => sym.evaluate({'x': 1.0})).throws<UnsupportedError>();
      check(() => sym.evaluateComplex({'x': Complex.one}))
          .throws<UnsupportedError>();
    });
  });
}
