import 'package:checks/checks.dart';
import 'package:data/src/symbolic/oracle/domain_oracle.dart' show Sign;
import 'package:data/src/symbolic/oracle/sign.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Sign inference oracle', () {
    const x = Variable('x');
    const y = Variable('y');

    test('infers exact signs of numeric and constant expressions', () {
      check(inferSign(IntegerNumber.of(5))).equals(Sign.positive);
      check(inferSign(IntegerNumber.of(-3))).equals(Sign.negative);
      check(inferSign(IntegerNumber.zero)).equals(Sign.zero);
      check(inferSign(const RealNumber(0.0))).equals(Sign.zero);
      check(inferSign(RealNumber.fromDouble(double.nan))).equals(Sign.unknown);
      check(inferSign(ComplexNumber.i)).equals(Sign.nonZero);
      check(inferSign(Constant.pi)).equals(Sign.positive);
      check(inferSign(Constant.e)).equals(Sign.positive);
      check(inferSign(Constant.infinity)).equals(Sign.positive);
      check(inferSign(Constant.undefined)).equals(Sign.unknown);
      check(inferSign(Constant.pi - IntegerNumber.of(3))).equals(Sign.positive);
      check(inferSign(Constant.pi - IntegerNumber.of(4))).equals(Sign.negative);
    });

    test(
      'infers composite sign across sums, products, powers, and relations',
      () {
        final posX = Assumptions.none.withPositive('x');
        final negY = Assumptions.none.withNegative('y');
        final nonNegX = Assumptions.none.withNonNegative('x');
        final mixed = posX.withNegative('y');

        check(inferSign(x, assumptions: posX)).equals(Sign.positive);
        check(inferSign(y, assumptions: negY)).equals(Sign.negative);
        check(inferSign(x, assumptions: nonNegX)).equals(Sign.nonNegative);
        check(inferSign(x * y, assumptions: mixed)).equals(Sign.negative);
        check(inferSign(y * y, assumptions: mixed)).equals(Sign.positive);
        check(inferSign(x + IntegerNumber.one, assumptions: nonNegX))
            .equals(Sign.positive);
        check(inferSign(Pow.of(Constant.e, y), assumptions: negY))
            .equals(Sign.positive);
        check(inferSign(Pow.of(y, IntegerNumber.of(3)), assumptions: negY))
            .equals(Sign.negative);
        check(
          inferSign(
            Pow.of(x, IntegerNumber.two),
            assumptions: Assumptions.real,
          ),
        ).equals(Sign.nonNegative);
        check(inferSign(Fn.abs(x), assumptions: mixed)).equals(Sign.positive);
        check(inferSign(Fn.abs(x), assumptions: Assumptions.real))
            .equals(Sign.nonNegative);

        final ordered = Assumptions.none.withRelation(
          Relational.greaterThan(x, y),
        );
        check(inferSign(x - y, assumptions: ordered)).equals(Sign.positive);
        check(inferSign(y - x, assumptions: ordered)).equals(Sign.negative);
      },
    );
  });

  group('Integer parity and real-domain oracle predicates', () {
    const k = Variable('k');
    const n = Variable('n');

    test('detects even and odd integer expressions under assumptions', () {
      final evenN = Assumptions.none.withEven('n');
      final oddK = Assumptions.none.withOdd('k');
      final both = evenN.withOdd('k');

      check(isIntegerValue(n, assumptions: evenN)).isTrue;
      check(isEvenInteger(n, assumptions: evenN)).isTrue;
      check(isOddInteger(n, assumptions: evenN)).isFalse;
      check(isOddInteger(k, assumptions: oddK)).isTrue;
      check(isEvenInteger(k, assumptions: oddK)).isFalse;
      check(isEvenInteger(n + IntegerNumber.two, assumptions: both)).isTrue;
      check(isOddInteger(n + k, assumptions: both)).isTrue;
      check(isEvenInteger(k + k, assumptions: oddK)).isTrue;
      check(isEvenInteger(n * k, assumptions: both)).isTrue;
      check(isOddInteger(k * k, assumptions: oddK)).isTrue;
      check(isOddInteger(Pow.of(k, IntegerNumber.of(3)), assumptions: oddK))
          .isTrue;
    });

    test('validates real domain and static real evaluation', () {
      check(
        isRealValue(
          Fn.sinh(const Variable('x')),
          assumptions: Assumptions.real,
        ),
      ).isTrue;
      check(
        isRealValue(Fn.ln(const Variable('x')), assumptions: Assumptions.real),
      ).isFalse;
      check(
        isRealValue(
          Fn.ln(const Variable('x')),
          assumptions: Assumptions.positive,
        ),
      ).isTrue;
      check(tryStaticRealValue(Constant.pi)).isNotNull();
      check(tryStaticRealValue(ComplexNumber.i)).isNull;
    });
  });
}
