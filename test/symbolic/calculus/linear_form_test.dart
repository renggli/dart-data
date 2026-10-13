import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  const x = Variable('x');
  const y = Variable('y');

  group('LinearFormExtension - matchLinear', () {
    test('matchLinear decomposes affine expressions', () {
      // 3x + 5 -> a = 3, b = 5
      final expr1 = (const RationalNumber(3) * x) + const RationalNumber(5);
      final lin1 = expr1.matchLinear('x');
      check(lin1).isNotNull();
      check(lin1!.a).equals(const RationalNumber(3));
      check(lin1.b).equals(const RationalNumber(5));

      // -x -> a = -1, b = 0
      final negX = -x;
      final linNeg = negX.matchLinear('x');
      check(linNeg).isNotNull();
      check(linNeg!.a).equals(const RationalNumber(-1));
      check(linNeg.b).equals(const RationalNumber(0));

      // x / 2 -> a = 0.5, b = 0
      final halfX = x / const RationalNumber(2);
      final linDiv = halfX.matchLinear('x');
      check(linDiv).isNotNull();
      check(linDiv!.a.evaluate(const {})).equals(0.5);
      check(linDiv.b).equals(RationalNumber.zero);

      // 4 - 2x -> a = -2, b = 4
      final expr2 = const RationalNumber(4) - (const RationalNumber(2) * x);
      final lin2 = expr2.matchLinear('x');
      check(lin2).isNotNull();
      check(lin2!.a.evaluate(const {})).equals(-2.0);
      check(lin2.b.evaluate(const {})).equals(4.0);
    });

    test(
      'matchLinear returns null for independent and non-linear expressions',
      () {
        check(y.matchLinear('x')).isNull();
        check(const RationalNumber(7).matchLinear('x')).isNull();
        check(x.pow(2).matchLinear('x')).isNull();
        check(const Sin(x).matchLinear('x')).isNull();
        check((x * y).matchLinear('x'))
            .isNotNull(); // affine in x with coefficient y
        check((x * y).matchLinear('x')!.a).equals(y);
      },
    );
  });

  group('LinearFormExtension - matchScalarMultiple', () {
    test('matchScalarMultiple checks scalar proportionality', () {
      final u = x.pow(2);
      final twoU = const RationalNumber(2) * x.pow(2);
      final k = twoU.matchScalarMultiple(u, 'x');
      check(k).isNotNull();
      check(k!.evaluate(const {})).equals(2.0);

      // Fractional scalar multiple
      final halfU = x.pow(2) / const RationalNumber(2);
      final kHalf = halfU.matchScalarMultiple(u, 'x');
      check(kHalf).isNotNull();
      check(kHalf!.evaluate(const {})).equals(0.5);

      // Negative scalar multiple
      final negU = -x.pow(2);
      final kNeg = negU.matchScalarMultiple(u, 'x');
      check(kNeg).isNotNull();
      check(kNeg!.evaluate(const {})).equals(-1.0);

      // Non-multiple returns null
      check(x.matchScalarMultiple(x.pow(2), 'x')).isNull();
      check(x.pow(3).matchScalarMultiple(x.pow(2), 'x')).isNull();
      check((x + 1).matchScalarMultiple(x, 'x')).isNull();
    });
  });

  group('LinearFormExtension - scale', () {
    test('scale scales expression with identity and constant folding', () {
      final expr = x + const RationalNumber(2);
      check(expr.scale(const RationalNumber(1))).equals(expr);
      check(expr.scale(const RationalNumber(0)))
          .equals(const RationalNumber(0));
      check(const RationalNumber(3).scale(const RationalNumber(2)))
          .equals(const RationalNumber(6));
      check((x * 2).scale(const RationalNumber(3)).evaluate({'x': 4.0}))
          .equals(24.0);
    });
  });
}
