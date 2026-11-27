import 'package:checks/checks.dart';
import 'package:data/src/symbolic/algebra/simplify/special.dart';
import 'package:data/src/symbolic/oracle/sign.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Special function simplification', () {
    test('simplifies LambertW, Erf, Erfc, Gamma, and Beta', () {
      const x = Variable('x');
      const y = Variable('y');

      check(
        simplifyLambertW(IntegerNumber.zero, 0, assumptions: Assumptions.none),
      ).equals(IntegerNumber.zero);
      check(simplifyLambertW(Constant.e, 0, assumptions: Assumptions.none))
          .equals(IntegerNumber.one);
      check(
        simplifyLambertW(
          Mul.of([
            IntegerNumber.negativeOne,
            Pow.of(Constant.e, IntegerNumber.negativeOne),
          ]),
          0,
          assumptions: Assumptions.none,
        ),
      ).equals(IntegerNumber.negativeOne);
      check(simplifyLambertW(x, -1, assumptions: Assumptions.none))
          .equals(Fn.lambertW(x, IntegerNumber.negativeOne));

      check(simplifyErf(Constant.infinity, assumptions: Assumptions.none))
          .equals(IntegerNumber.one);
      check(
        simplifyErf(
          Mul.of([IntegerNumber.negativeOne, Constant.infinity]),
          assumptions: Assumptions.none,
        ),
      ).equals(IntegerNumber.negativeOne);
      check(simplifyErf(x, assumptions: Assumptions.none)).equals(Fn.erf(x));

      check(simplifyErfc(Constant.infinity, assumptions: Assumptions.none))
          .equals(IntegerNumber.zero);
      check(
        simplifyErfc(
          Mul.of([IntegerNumber.negativeOne, Constant.infinity]),
          assumptions: Assumptions.none,
        ),
      ).equals(IntegerNumber.two);
      check(simplifyErfc(x, assumptions: Assumptions.none)).equals(Fn.erfc(x));

      check(
        simplifyGamma(
          FractionNumber.half,
          assumptions: Assumptions.none,
        ).toString(),
      ).equals('sqrt(pi)');
      check(simplifyGamma(x, assumptions: Assumptions.none))
          .equals(Fn.gamma(x));

      // Beta symmetry, integer factorial evaluation, unit argument identities, and general form
      check(
        simplifyBeta(
          IntegerNumber.of(3),
          IntegerNumber.of(4),
          assumptions: Assumptions.none,
        ),
      ).equals(RationalNumber(1, 60));
      check(simplifyBeta(y, x, assumptions: Assumptions.none))
          .equals(Fn.beta(x, y));
      check(
        simplifyBeta(
          IntegerNumber.one,
          x,
          assumptions: Assumptions.none,
        ).toString(),
      ).equals('1 / x');
      check(
        simplifyBeta(
          FractionNumber.half,
          IntegerNumber.one,
          assumptions: Assumptions.none,
        ),
      ).equals(IntegerNumber.two);
    });

    test(
      'simplifies and checks domain of special integral and polylog functions',
      () {
        const x = Variable('x');
        const realAssumptions = Assumptions(
          domains: {'x': VariableDomain.real},
        );
        final halfPi = Constant.pi / IntegerNumber.two;

        // Zero, odd symmetry, undefined, and RealNumber folding
        check(Fn.erfi(IntegerNumber.zero).simplify())
            .equals(IntegerNumber.zero);
        check(Fn.erfi(-x).simplify()).equals(-Fn.erfi(x));
        check(Fn.erfi(Constant.undefined).simplify())
            .equals(Constant.undefined);
        check(Fn.erfi(const RealNumber(1.0)).simplify()).isA<RealNumber>();

        check(Fn.fresnelS(IntegerNumber.zero).simplify())
            .equals(IntegerNumber.zero);
        check(Fn.fresnelS(-x).simplify()).equals(-Fn.fresnelS(x));
        check(Fn.fresnelS(Constant.undefined).simplify())
            .equals(Constant.undefined);
        check(Fn.fresnelS(const RealNumber(1.0)).simplify()).isA<RealNumber>();

        check(Fn.fresnelC(IntegerNumber.zero).simplify())
            .equals(IntegerNumber.zero);
        check(Fn.fresnelC(-x).simplify()).equals(-Fn.fresnelC(x));
        check(Fn.fresnelC(Constant.undefined).simplify())
            .equals(Constant.undefined);
        check(Fn.fresnelC(const RealNumber(1.0)).simplify()).isA<RealNumber>();

        check(Fn.ei(Constant.undefined).simplify()).equals(Constant.undefined);
        check(Fn.ei(const RealNumber(1.0)).simplify()).isA<RealNumber>();

        check(Fn.li(IntegerNumber.zero).simplify()).equals(IntegerNumber.zero);
        check(Fn.li(Constant.undefined).simplify()).equals(Constant.undefined);
        check(Fn.li(const RealNumber(2.0)).simplify()).isA<RealNumber>();

        check(Fn.si(IntegerNumber.zero).simplify()).equals(IntegerNumber.zero);
        check(Fn.si(-x).simplify()).equals(-Fn.si(x));
        check(Fn.si(Constant.undefined).simplify()).equals(Constant.undefined);
        check(Fn.si(const RealNumber(1.0)).simplify()).isA<RealNumber>();

        check(Fn.ci(Constant.undefined).simplify()).equals(Constant.undefined);
        check(Fn.ci(const RealNumber(1.0)).simplify()).isA<RealNumber>();

        check(Fn.shi(IntegerNumber.zero).simplify()).equals(IntegerNumber.zero);
        check(Fn.shi(-x).simplify()).equals(-Fn.shi(x));
        check(Fn.shi(Constant.undefined).simplify()).equals(Constant.undefined);
        check(Fn.shi(const RealNumber(1.0)).simplify()).isA<RealNumber>();

        check(Fn.chi(Constant.undefined).simplify()).equals(Constant.undefined);
        check(Fn.chi(const RealNumber(1.0)).simplify()).isA<RealNumber>();

        check(Fn.upperGamma(IntegerNumber.two, IntegerNumber.zero).simplify())
            .equals(IntegerNumber.one);
        check(Fn.upperGamma(IntegerNumber.one, x).simplify())
            .equals(Pow.of(Constant.e, -x));
        check(Fn.upperGamma(Constant.undefined, x).simplify())
            .equals(Constant.undefined);
        check(
          Fn.upperGamma(
            const RealNumber(2.0),
            const RealNumber(1.0),
          ).simplify(),
        ).isA<RealNumber>();

        check(Fn.lowerGamma(IntegerNumber.two, IntegerNumber.zero).simplify())
            .equals(IntegerNumber.zero);
        check(Fn.lowerGamma(IntegerNumber.one, x).simplify())
            .equals((IntegerNumber.one - Pow.of(Constant.e, -x)).simplify());
        check(Fn.lowerGamma(Constant.undefined, x).simplify())
            .equals(Constant.undefined);
        check(
          Fn.lowerGamma(
            const RealNumber(2.0),
            const RealNumber(1.0),
          ).simplify(),
        ).isA<RealNumber>();

        check(Fn.polylog(IntegerNumber.two, IntegerNumber.zero).simplify())
            .equals(IntegerNumber.zero);
        check(Fn.polylog(IntegerNumber.one, x).simplify())
            .equals((-Fn.ln(IntegerNumber.one - x)).simplify());
        check(Fn.polylog(IntegerNumber.zero, x).simplify())
            .equals((x / (IntegerNumber.one - x)).simplify());
        check(Fn.polylog(IntegerNumber.two, IntegerNumber.one).simplify())
            .equals(
              (Pow.of(Constant.pi, IntegerNumber.two) / IntegerNumber.of(6))
                  .simplify(),
            );
        check(Fn.polylog(Constant.undefined, x).simplify())
            .equals(Constant.undefined);
        check(
          Fn.polylog(const RealNumber(2.0), const RealNumber(0.5)).simplify(),
        ).isA<RealNumber>();

        check(Fn.ellipticF(IntegerNumber.zero, x).simplify())
            .equals(IntegerNumber.zero);
        check(Fn.ellipticF(x, IntegerNumber.zero).simplify()).equals(x);
        check(Fn.ellipticF(halfPi, x).simplify()).equals(Fn.ellipticK(x));
        check(Fn.ellipticF(Constant.undefined, x).simplify())
            .equals(Constant.undefined);
        check(
          Fn.ellipticF(const RealNumber(0.5), const RealNumber(0.5)).simplify(),
        ).isA<RealNumber>();

        check(Fn.ellipticE(IntegerNumber.zero, x).simplify())
            .equals(IntegerNumber.zero);
        check(Fn.ellipticE(x, IntegerNumber.zero).simplify()).equals(x);
        check(Fn.ellipticE(halfPi, x).simplify()).equals(Fn.ellipticE(x));
        check(Fn.ellipticE(Constant.undefined, x).simplify())
            .equals(Constant.undefined);
        check(
          Fn.ellipticE(const RealNumber(0.5), const RealNumber(0.5)).simplify(),
        ).isA<RealNumber>();

        // Structural ordering across all new AST nodes
        final ordered = [
          Fn.erfi(x),
          Fn.fresnelS(x),
          Fn.fresnelC(x),
          Fn.ei(x),
          Fn.li(x),
          Fn.si(x),
          Fn.ci(x),
          Fn.shi(x),
          Fn.chi(x),
          Fn.upperGamma(IntegerNumber.two, x),
          Fn.lowerGamma(IntegerNumber.two, x),
          Fn.polylog(IntegerNumber.two, x),
          Fn.ellipticE(x, FractionNumber.half),
          Fn.ellipticF(x, FractionNumber.half),
        ];
        for (var i = 0; i < ordered.length - 1; i++) {
          check(compareStructural(ordered[i], ordered[i + 1])).isLessThan(0);
        }

        // Domain checks (isProvenReal)
        check(isProvenReal(Fn.erfi(x), realAssumptions)).isTrue;
        check(isProvenReal(Fn.fresnelS(x), realAssumptions)).isTrue;
        check(isProvenReal(Fn.fresnelC(x), realAssumptions)).isTrue;
        check(isProvenReal(Fn.ei(x), realAssumptions)).isTrue;
        check(isProvenReal(Fn.si(x), realAssumptions)).isTrue;
        check(isProvenReal(Fn.shi(x), realAssumptions)).isTrue;
        check(isProvenReal(Fn.li(IntegerNumber.two), realAssumptions)).isTrue;
        check(isProvenReal(Fn.li(IntegerNumber.zero), realAssumptions)).isFalse;
        check(isProvenReal(Fn.ci(IntegerNumber.two), realAssumptions)).isTrue;
        check(isProvenReal(Fn.chi(IntegerNumber.two), realAssumptions)).isTrue;
        check(
          isProvenReal(Fn.upperGamma(IntegerNumber.two, x), realAssumptions),
        ).isFalse;
        check(
          isProvenReal(Fn.lowerGamma(IntegerNumber.two, x), realAssumptions),
        ).isFalse;
        check(
          isProvenReal(
            Fn.upperGamma(IntegerNumber.two, x),
            Assumptions.positive,
          ),
        ).isTrue;
        check(
          isProvenReal(
            Fn.lowerGamma(IntegerNumber.two, x),
            Assumptions.positive,
          ),
        ).isTrue;
        check(
          isProvenReal(
            Fn.polylog(IntegerNumber.two, FractionNumber.half),
            realAssumptions,
          ),
        ).isTrue;
        check(
          isProvenReal(
            Fn.polylog(IntegerNumber.two, IntegerNumber.two),
            realAssumptions,
          ),
        ).isFalse;
        check(
          isProvenReal(Fn.ellipticF(x, FractionNumber.half), realAssumptions),
        ).isTrue;
        check(
          isProvenReal(Fn.ellipticE(x, FractionNumber.half), realAssumptions),
        ).isTrue;
      },
    );

    test('exact gamma poles, half-integers, polygamma order, and negative binomial', () {
      check(Expr.parse('gamma(0)').simplify()).equals(Constant.undefined);
      check(Expr.parse('(-1)!').simplify()).equals(Constant.undefined);
      check((Expr.parse('gamma(20)') - Expr.parse('19!')).simplify())
          .equals(IntegerNumber.zero);
      check(Expr.parse('gamma(-1/2)').simplify())
          .equals(Expr.parse('-2 * sqrt(pi)').simplify());
      check(Expr.parse('(1/2)!').simplify())
          .equals(Expr.parse('1/2 * sqrt(pi)').simplify());
      check(Expr.parse('(3/2)!').simplify())
          .equals(Expr.parse('3/4 * sqrt(pi)').simplify());
      check(Expr.parse('(-3/2)!').simplify())
          .equals(Expr.parse('-2 * sqrt(pi)').simplify());
      check(Expr.parse('gamma(39/2)').simplify())
          .equals(Expr.parse('(38! / (4^19 * 19!)) * sqrt(pi)').simplify());
      check(Expr.parse('gamma(41/2)').simplify())
          .equals(Expr.parse('(40! / (4^20 * 20!)) * sqrt(pi)').simplify());
      check(Expr.parse('binomial(-1, 3)').simplify())
          .equals(IntegerNumber.negativeOne);
      check(
        Fn.polygamma(const RealNumber(1.5), const RealNumber(2.0)).simplify(),
      ).isA<Call>().has('id', (Call c) => c.id).equals(FunctionId.polygamma);
    });

    test(
      'simplifies large integer beta and real binomial without overflow',
      () {
        check(Expr.parse('beta(2, 10000)').simplify())
            .equals(RationalNumber.of(BigInt.one, BigInt.from(100010000)));
        check(Expr.parse('binomial(1000.0, 2.0)').simplify())
            .equals(const RealNumber(499500.0));
        final negBinomReal = Expr.parse('binomial(-0.5, 2.0)').simplify();
        check(negBinomReal).isA<RealNumber>();
        check((negBinomReal as RealNumber).value).isCloseTo(0.375, 1e-12);

        check(Fn.beta(FractionNumber.half, RationalNumber(3, 2)).simplify())
            .equals((Constant.pi / IntegerNumber.two).simplify());
        check(
          Fn.ellipticPi(
            ComplexNumber(const RealNumber(0.2), const RealNumber(0.1)),
            ComplexNumber(const RealNumber(0.5), const RealNumber(0.1)),
            ComplexNumber(const RealNumber(0.4), const RealNumber(0.1)),
          ).simplify(),
        ).isA<ComplexNumber>();
      },
    );

    test('simplifies ExpIntegral and LogIntegral boundary values', () {
      check(Fn.ei(IntegerNumber.zero).simplify()).equals(-Constant.infinity);
      check(Fn.ei(Constant.infinity).simplify()).equals(Constant.infinity);
      check(Fn.ei(-Constant.infinity).simplify()).equals(IntegerNumber.zero);
      check(Fn.li(IntegerNumber.one).simplify()).equals(-Constant.infinity);
    });

    test('simplifies large positive integer Beta values via factorials', () {
      check(Fn.beta(IntegerNumber.of(1011), IntegerNumber.of(1011)).simplify())
          .equals(Expr.parse('1010!^2 / 2021!').simplify());
    });
  });
}
