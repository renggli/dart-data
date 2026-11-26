import 'package:checks/checks.dart';
import 'package:data/src/symbolic/algebra/simplify/domain.dart';
import 'package:data/src/symbolic/algebra/simplify/special.dart';
import 'package:data/src/symbolic/algebra/structural_order.dart';
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

        check(ExpIntegral(Constant.undefined).simplify())
            .equals(Constant.undefined);
        check(ExpIntegral(const RealNumber(1.0)).simplify()).isA<RealNumber>();

        check(LogIntegral(IntegerNumber.zero).simplify())
            .equals(IntegerNumber.zero);
        check(LogIntegral(Constant.undefined).simplify())
            .equals(Constant.undefined);
        check(LogIntegral(const RealNumber(2.0)).simplify()).isA<RealNumber>();

        check(SinIntegral(IntegerNumber.zero).simplify())
            .equals(IntegerNumber.zero);
        check(SinIntegral(-x).simplify()).equals(-SinIntegral(x));
        check(SinIntegral(Constant.undefined).simplify())
            .equals(Constant.undefined);
        check(SinIntegral(const RealNumber(1.0)).simplify()).isA<RealNumber>();

        check(CosIntegral(Constant.undefined).simplify())
            .equals(Constant.undefined);
        check(CosIntegral(const RealNumber(1.0)).simplify()).isA<RealNumber>();

        check(SinhIntegral(IntegerNumber.zero).simplify())
            .equals(IntegerNumber.zero);
        check(SinhIntegral(-x).simplify()).equals(-SinhIntegral(x));
        check(SinhIntegral(Constant.undefined).simplify())
            .equals(Constant.undefined);
        check(SinhIntegral(const RealNumber(1.0)).simplify()).isA<RealNumber>();

        check(CoshIntegral(Constant.undefined).simplify())
            .equals(Constant.undefined);
        check(CoshIntegral(const RealNumber(1.0)).simplify()).isA<RealNumber>();

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

        check(EllipticE(x, amplitude: IntegerNumber.zero).simplify())
            .equals(IntegerNumber.zero);
        check(EllipticE(IntegerNumber.zero, amplitude: x).simplify()).equals(x);
        check(EllipticE(x, amplitude: halfPi).simplify()).equals(EllipticE(x));
        check(EllipticE(x, amplitude: Constant.undefined).simplify())
            .equals(Constant.undefined);
        check(
          EllipticE(
            const RealNumber(0.5),
            amplitude: const RealNumber(0.5),
          ).simplify(),
        ).isA<RealNumber>();

        // Structural ordering across all new AST nodes
        final ordered = [
          EllipticE(FractionNumber.half, amplitude: x),
          Erfi(x),
          FresnelS(x),
          FresnelC(x),
          ExpIntegral(x),
          LogIntegral(x),
          SinIntegral(x),
          CosIntegral(x),
          SinhIntegral(x),
          CoshIntegral(x),
          UpperGamma(IntegerNumber.two, x),
          LowerGamma(IntegerNumber.two, x),
          Polylog(IntegerNumber.two, x),
          EllipticF(x, FractionNumber.half),
        ];
        for (var i = 0; i < ordered.length - 1; i++) {
          check(compareStructural(ordered[i], ordered[i + 1])).isLessThan(0);
        }

        // Domain checks (isProvenReal)
        check(isProvenReal(Erfi(x), realAssumptions)).isTrue;
        check(isProvenReal(FresnelS(x), realAssumptions)).isTrue;
        check(isProvenReal(FresnelC(x), realAssumptions)).isTrue;
        check(isProvenReal(ExpIntegral(x), realAssumptions)).isTrue;
        check(isProvenReal(SinIntegral(x), realAssumptions)).isTrue;
        check(isProvenReal(SinhIntegral(x), realAssumptions)).isTrue;
        check(isProvenReal(LogIntegral(IntegerNumber.two), realAssumptions))
            .isTrue;
        check(isProvenReal(LogIntegral(IntegerNumber.zero), realAssumptions))
            .isFalse;
        check(isProvenReal(CosIntegral(IntegerNumber.two), realAssumptions))
            .isTrue;
        check(isProvenReal(CoshIntegral(IntegerNumber.two), realAssumptions))
            .isTrue;
        check(isProvenReal(UpperGamma(IntegerNumber.two, x), realAssumptions))
            .isFalse;
        check(isProvenReal(LowerGamma(IntegerNumber.two, x), realAssumptions))
            .isFalse;
        check(
          isProvenReal(UpperGamma(IntegerNumber.two, x), Assumptions.positive),
        ).isTrue;
        check(
          isProvenReal(LowerGamma(IntegerNumber.two, x), Assumptions.positive),
        ).isTrue;
        check(
          isProvenReal(
            Polylog(IntegerNumber.two, FractionNumber.half),
            realAssumptions,
          ),
        ).isTrue;
        check(
          isProvenReal(
            Polylog(IntegerNumber.two, IntegerNumber.two),
            realAssumptions,
          ),
        ).isFalse;
        check(isProvenReal(EllipticF(x, FractionNumber.half), realAssumptions))
            .isTrue;
        check(
          isProvenReal(
            EllipticE(FractionNumber.half, amplitude: x),
            realAssumptions,
          ),
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

        check(Beta(FractionNumber.half, RationalNumber(3, 2)).simplify())
            .equals((Constant.pi / IntegerNumber.two).simplify());
        check(
          EllipticPi(
            ComplexNumber(const RealNumber(0.2), const RealNumber(0.1)),
            ComplexNumber(const RealNumber(0.5), const RealNumber(0.1)),
            ComplexNumber(const RealNumber(0.4), const RealNumber(0.1)),
          ).simplify(),
        ).isA<ComplexNumber>();
      },
    );

    test('simplifies ExpIntegral and LogIntegral boundary values', () {
      check(ExpIntegral(IntegerNumber.zero).simplify())
          .equals(-Constant.infinity);
      check(ExpIntegral(Constant.infinity).simplify())
          .equals(Constant.infinity);
      check(ExpIntegral(-Constant.infinity).simplify())
          .equals(IntegerNumber.zero);
      check(LogIntegral(IntegerNumber.one).simplify())
          .equals(-Constant.infinity);
    });

    test('simplifies large positive integer Beta values via factorials', () {
      check(Beta(IntegerNumber.of(1011), IntegerNumber.of(1011)).simplify())
          .equals(Expr.parse('1010!^2 / 2021!').simplify());
    });
  });
}
