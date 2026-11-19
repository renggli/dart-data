import 'package:checks/checks.dart';
import 'package:data/src/symbolic/algebra/simplify/domain.dart';
import 'package:data/src/symbolic/algebra/simplify/special.dart';
import 'package:data/src/symbolic/algebra/structural_order.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

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
          Mul([
            IntegerNumber.negativeOne,
            Pow(Constant.e, IntegerNumber.negativeOne, isSimplified: true),
          ]),
          0,
          assumptions: Assumptions.none,
        ),
      ).equals(IntegerNumber.negativeOne);
      check(simplifyLambertW(x, -1, assumptions: Assumptions.none))
          .equals(LambertW(x, branch: -1, isSimplified: true));

      check(simplifyErf(Constant.infinity, assumptions: Assumptions.none))
          .equals(IntegerNumber.one);
      check(
        simplifyErf(
          Mul([IntegerNumber.negativeOne, Constant.infinity]),
          assumptions: Assumptions.none,
        ),
      ).equals(IntegerNumber.negativeOne);
      check(simplifyErf(x, assumptions: Assumptions.none))
          .equals(Erf(x, isSimplified: true));

      check(simplifyErfc(Constant.infinity, assumptions: Assumptions.none))
          .equals(IntegerNumber.zero);
      check(
        simplifyErfc(
          Mul([IntegerNumber.negativeOne, Constant.infinity]),
          assumptions: Assumptions.none,
        ),
      ).equals(IntegerNumber.two);
      check(simplifyErfc(x, assumptions: Assumptions.none))
          .equals(Erfc(x, isSimplified: true));

      check(
        simplifyGamma(
          FractionNumber.half,
          assumptions: Assumptions.none,
        ).toString(),
      ).equals('sqrt(pi)');
      check(simplifyGamma(x, assumptions: Assumptions.none))
          .equals(Gamma(x, isSimplified: true));

      // Beta symmetry, integer factorial evaluation, unit argument identities, and general form
      check(
        simplifyBeta(
          IntegerNumber.of(3),
          IntegerNumber.of(4),
          assumptions: Assumptions.none,
        ),
      ).equals(RationalNumber(1, 60));
      check(simplifyBeta(y, x, assumptions: Assumptions.none))
          .equals(Beta(x, y, isSimplified: true));
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
        check(Erfi(IntegerNumber.zero).simplify()).equals(IntegerNumber.zero);
        check(Erfi(-x).simplify()).equals(-Erfi(x));
        check(Erfi(Constant.undefined).simplify()).equals(Constant.undefined);
        check(Erfi(const RealNumber(1.0)).simplify()).isA<RealNumber>();

        check(FresnelS(IntegerNumber.zero).simplify())
            .equals(IntegerNumber.zero);
        check(FresnelS(-x).simplify()).equals(-FresnelS(x));
        check(FresnelS(Constant.undefined).simplify())
            .equals(Constant.undefined);
        check(FresnelS(const RealNumber(1.0)).simplify()).isA<RealNumber>();

        check(FresnelC(IntegerNumber.zero).simplify())
            .equals(IntegerNumber.zero);
        check(FresnelC(-x).simplify()).equals(-FresnelC(x));
        check(FresnelC(Constant.undefined).simplify())
            .equals(Constant.undefined);
        check(FresnelC(const RealNumber(1.0)).simplify()).isA<RealNumber>();

        check(ExpIntegralEi(Constant.undefined).simplify())
            .equals(Constant.undefined);
        check(ExpIntegralEi(const RealNumber(1.0)).simplify())
            .isA<RealNumber>();

        check(LogIntegralLi(IntegerNumber.zero).simplify())
            .equals(IntegerNumber.zero);
        check(LogIntegralLi(Constant.undefined).simplify())
            .equals(Constant.undefined);
        check(LogIntegralLi(const RealNumber(2.0)).simplify())
            .isA<RealNumber>();

        check(SinIntegralSi(IntegerNumber.zero).simplify())
            .equals(IntegerNumber.zero);
        check(SinIntegralSi(-x).simplify()).equals(-SinIntegralSi(x));
        check(SinIntegralSi(Constant.undefined).simplify())
            .equals(Constant.undefined);
        check(SinIntegralSi(const RealNumber(1.0)).simplify())
            .isA<RealNumber>();

        check(CosIntegralCi(Constant.undefined).simplify())
            .equals(Constant.undefined);
        check(CosIntegralCi(const RealNumber(1.0)).simplify())
            .isA<RealNumber>();

        check(SinhIntegralShi(IntegerNumber.zero).simplify())
            .equals(IntegerNumber.zero);
        check(SinhIntegralShi(-x).simplify()).equals(-SinhIntegralShi(x));
        check(SinhIntegralShi(Constant.undefined).simplify())
            .equals(Constant.undefined);
        check(SinhIntegralShi(const RealNumber(1.0)).simplify())
            .isA<RealNumber>();

        check(CoshIntegralChi(Constant.undefined).simplify())
            .equals(Constant.undefined);
        check(CoshIntegralChi(const RealNumber(1.0)).simplify())
            .isA<RealNumber>();

        check(UpperGamma(IntegerNumber.two, IntegerNumber.zero).simplify())
            .equals(IntegerNumber.one);
        check(UpperGamma(IntegerNumber.one, x).simplify())
            .equals(Pow(Constant.e, -x));
        check(UpperGamma(Constant.undefined, x).simplify())
            .equals(Constant.undefined);
        check(
          UpperGamma(const RealNumber(2.0), const RealNumber(1.0)).simplify(),
        ).isA<RealNumber>();

        check(LowerGamma(IntegerNumber.two, IntegerNumber.zero).simplify())
            .equals(IntegerNumber.zero);
        check(LowerGamma(IntegerNumber.one, x).simplify())
            .equals((IntegerNumber.one - Pow(Constant.e, -x)).simplify());
        check(LowerGamma(Constant.undefined, x).simplify())
            .equals(Constant.undefined);
        check(
          LowerGamma(const RealNumber(2.0), const RealNumber(1.0)).simplify(),
        ).isA<RealNumber>();

        check(Polylog(IntegerNumber.two, IntegerNumber.zero).simplify())
            .equals(IntegerNumber.zero);
        check(Polylog(IntegerNumber.one, x).simplify())
            .equals((-Ln(IntegerNumber.one - x)).simplify());
        check(Polylog(IntegerNumber.zero, x).simplify())
            .equals((x / (IntegerNumber.one - x)).simplify());
        check(Polylog(IntegerNumber.two, IntegerNumber.one).simplify()).equals(
          (Pow(Constant.pi, IntegerNumber.two) / IntegerNumber.of(6))
              .simplify(),
        );
        check(Polylog(Constant.undefined, x).simplify())
            .equals(Constant.undefined);
        check(Polylog(const RealNumber(2.0), const RealNumber(0.5)).simplify())
            .isA<RealNumber>();

        check(EllipticF(IntegerNumber.zero, x).simplify())
            .equals(IntegerNumber.zero);
        check(EllipticF(x, IntegerNumber.zero).simplify()).equals(x);
        check(EllipticF(halfPi, x).simplify()).equals(EllipticK(x));
        check(EllipticF(Constant.undefined, x).simplify())
            .equals(Constant.undefined);
        check(
          EllipticF(const RealNumber(0.5), const RealNumber(0.5)).simplify(),
        ).isA<RealNumber>();

        check(EllipticEIncomplete(IntegerNumber.zero, x).simplify())
            .equals(IntegerNumber.zero);
        check(EllipticEIncomplete(x, IntegerNumber.zero).simplify()).equals(x);
        check(EllipticEIncomplete(halfPi, x).simplify()).equals(EllipticE(x));
        check(EllipticEIncomplete(Constant.undefined, x).simplify())
            .equals(Constant.undefined);
        check(
          EllipticEIncomplete(
            const RealNumber(0.5),
            const RealNumber(0.5),
          ).simplify(),
        ).isA<RealNumber>();

        // Structural ordering across all new AST nodes
        final ordered = [
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
          Polylog(IntegerNumber.two, x),
          EllipticF(x, FractionNumber.half),
          EllipticEIncomplete(x, FractionNumber.half),
        ];
        for (var i = 0; i < ordered.length - 1; i++) {
          check(compareStructural(ordered[i], ordered[i + 1])).isLessThan(0);
        }

        // Domain checks (isProvenReal)
        check(isProvenReal(Erfi(x), realAssumptions)).isTrue();
        check(isProvenReal(FresnelS(x), realAssumptions)).isTrue();
        check(isProvenReal(FresnelC(x), realAssumptions)).isTrue();
        check(isProvenReal(ExpIntegralEi(x), realAssumptions)).isTrue();
        check(isProvenReal(SinIntegralSi(x), realAssumptions)).isTrue();
        check(isProvenReal(SinhIntegralShi(x), realAssumptions)).isTrue();
        check(isProvenReal(LogIntegralLi(IntegerNumber.two), realAssumptions))
            .isTrue();
        check(isProvenReal(LogIntegralLi(IntegerNumber.zero), realAssumptions))
            .isFalse();
        check(isProvenReal(CosIntegralCi(IntegerNumber.two), realAssumptions))
            .isTrue();
        check(isProvenReal(CoshIntegralChi(IntegerNumber.two), realAssumptions))
            .isTrue();
        check(isProvenReal(UpperGamma(IntegerNumber.two, x), realAssumptions))
            .isFalse();
        check(isProvenReal(LowerGamma(IntegerNumber.two, x), realAssumptions))
            .isFalse();
        check(
          isProvenReal(UpperGamma(IntegerNumber.two, x), Assumptions.positive),
        ).isTrue();
        check(
          isProvenReal(LowerGamma(IntegerNumber.two, x), Assumptions.positive),
        ).isTrue();
        check(
          isProvenReal(
            Polylog(IntegerNumber.two, FractionNumber.half),
            realAssumptions,
          ),
        ).isTrue();
        check(
          isProvenReal(
            Polylog(IntegerNumber.two, IntegerNumber.two),
            realAssumptions,
          ),
        ).isFalse();
        check(isProvenReal(EllipticF(x, FractionNumber.half), realAssumptions))
            .isTrue();
        check(
          isProvenReal(
            EllipticEIncomplete(x, FractionNumber.half),
            realAssumptions,
          ),
        ).isTrue();
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
      check(Polygamma(const RealNumber(1.5), const RealNumber(2.0)).simplify())
          .isA<Polygamma>();
    });

    test(
      'simplifies large integer beta and real binomial without overflow',
      () {
        check(Expr.parse('beta(2, 10000)').simplify())
            .equals(FractionNumber(Integer.one, Integer.from(100010000)));
        check(Expr.parse('binomial(1000.0, 2.0)').simplify())
            .equals(const RealNumber(499500.0));
        final negBinomReal = Expr.parse('binomial(-0.5, 2.0)').simplify();
        check(negBinomReal).isA<RealNumber>();
        check((negBinomReal as RealNumber).value).isCloseTo(0.375, 1e-12);
      },
    );
  });
}
