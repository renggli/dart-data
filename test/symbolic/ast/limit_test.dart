import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  const x = Variable('x');
  const y = Variable('y');
  const z = Variable('z');

  group('Limit construction and properties', () {
    test('constructs limit with default and explicit directions', () {
      final lim = Limit(Sin(x) / x, 'x', IntegerNumber.zero);
      check(lim.expr).equals(Sin(x) / x);
      check(lim.variable).equals('x');
      check(lim.point).equals(IntegerNumber.zero);
      check(lim.direction).equals(LimitDirection.both);
      check(lim.isSimplified).isFalse();

      final limAbove = Limit(
        IntegerNumber.one / x,
        'x',
        IntegerNumber.zero,
        direction: LimitDirection.fromAbove,
        isSimplified: true,
      );
      check(limAbove.direction).equals(LimitDirection.fromAbove);
      check(limAbove.isSimplified).isTrue();
    });

    test('equality and hashCode', () {
      final a = Limit(
        x + y,
        'x',
        IntegerNumber.zero,
        direction: LimitDirection.fromBelow,
      );
      final b = Limit(
        x + y,
        'x',
        IntegerNumber.zero,
        direction: LimitDirection.fromBelow,
      );
      final c = Limit(
        x + y,
        'x',
        IntegerNumber.zero,
        direction: LimitDirection.fromAbove,
      );
      final d = Limit(
        x + y,
        'x',
        IntegerNumber.one,
        direction: LimitDirection.fromBelow,
      );
      check(a).equals(b);
      check(a.hashCode).equals(b.hashCode);
      check(a == c).isFalse();
      check(a == d).isFalse();
    });
  });

  group('Limit evaluation and tree operations', () {
    test('evaluate returns NaN', () {
      final lim = Limit(Sin(x) / x, 'x', IntegerNumber.zero);
      check(lim.evaluate({'x': 1.0})).isNaN();
    });

    test(
      'freeVariables and dependsOn exclude bound variable unless in point',
      () {
        final lim = Limit(x * y, 'x', z);
        check(lim.freeVariables).deepEquals({'y', 'z'});
        check(lim.dependsOn('x')).isFalse();
        check(lim.dependsOn('y')).isTrue();
        check(lim.dependsOn('z')).isTrue();
        check(lim.dependsOn('w')).isFalse();

        final limShadow = Limit(x * y, 'x', x);
        check(limShadow.dependsOn('x')).isTrue();
      },
    );

    test('substitute respects bound variable in expr', () {
      final lim = Limit(x + y, 'x', y);
      final subY = lim.substitute('y', IntegerNumber.two);
      check(subY).equals(Limit(x + IntegerNumber.two, 'x', IntegerNumber.two));

      final subX = lim.substitute('x', IntegerNumber.two);
      check(subX).equals(Limit(x + y, 'x', y));

      // Alpha-renaming prevents variable capture when replacing free variable with expr containing bound variable
      final subAlpha = lim.substitute('y', x + IntegerNumber.one) as Limit;
      check(subAlpha.variable).equals('x_1');
      check(subAlpha.point).equals(x + IntegerNumber.one);
      check(subAlpha.expr)
          .equals(Add([const Variable('x_1'), x + IntegerNumber.one]));
    });

    test('mapChildren and anyNode', () {
      final lim = Limit(
        Sin(x),
        'x',
        IntegerNumber.zero,
        direction: LimitDirection.fromAbove,
      );
      final mapped = lim.mapChildren((child) => child + IntegerNumber.one);
      check(mapped).equals(
        Limit(
          Sin(x) + IntegerNumber.one,
          'x',
          IntegerNumber.zero + IntegerNumber.one,
          direction: LimitDirection.fromAbove,
        ),
      );

      check(lim.anyNode((node) => node is Limit)).isTrue();
      check(lim.anyNode((node) => node is Sin)).isTrue();
      check(lim.anyNode((node) => node is IntegerNumber)).isTrue();
      check(lim.anyNode((node) => node is Cos)).isFalse();
    });
  });
}
