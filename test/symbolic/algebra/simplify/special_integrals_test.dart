import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Special integrals & hypergeometric simplification', () {
    const x = Variable('x');
    final z = ComplexNumber.of(const RealNumber(0.3), const RealNumber(0.4));
    const r = RealNumber(0.4);

    test(
      'simplifies elliptic integrals on real, float, and complex inputs',
      () {
        check(Fn.ellipticK(r).simplify()).isA<RealNumber>();
        check(Fn.ellipticK(z).simplify()).isA<ComplexNumber>();
        check(Fn.ellipticK(Constant.undefined).simplify())
            .equals(Constant.undefined);

        check(Fn.ellipticE(IntegerNumber.one).simplify())
            .equals(IntegerNumber.one);
        check(Fn.ellipticE(r).simplify()).isA<RealNumber>();
        check(Fn.ellipticE(z).simplify()).isA<ComplexNumber>();
        check(Fn.ellipticE(IntegerNumber.zero, r).simplify())
            .equals(IntegerNumber.zero);
        check(Fn.ellipticE(r, IntegerNumber.zero).simplify()).equals(r);
        check(Fn.ellipticE(Constant.pi / IntegerNumber.two, x).simplify())
            .equals(Fn.ellipticE(x));
        check(Fn.ellipticE(const RealNumber(0.5), r).simplify())
            .isA<RealNumber>();
        check(Fn.ellipticE(z, z).simplify()).isA<ComplexNumber>();

        check(
          Fn.ellipticPi(
            const RealNumber(0.2),
            const RealNumber(0.5),
            r,
          ).simplify(),
        ).isA<RealNumber>();
        check(Fn.ellipticPi(z, const RealNumber(0.5), z).simplify())
            .isA<ComplexNumber>();
        check(Fn.ellipticPi(r, r, r).simplify()).isA<RealNumber>();
        check(Fn.ellipticPi(z, z, z).simplify()).isA<ComplexNumber>();
      },
    );

    test('simplifies erfi, Fresnel, and exponential/trig integrals', () {
      check(Fn.erfi(z).simplify()).isA<ComplexNumber>();
      check(Fn.fresnelS(z).simplify()).isA<ComplexNumber>();
      check(Fn.fresnelC(z).simplify()).isA<ComplexNumber>();

      check(Fn.ei(IntegerNumber.zero).simplify()).equals(-Constant.infinity);
      check(Fn.ei(Constant.infinity).simplify()).equals(Constant.infinity);
      check(Fn.ei(-Constant.infinity).simplify()).equals(IntegerNumber.zero);
      check(Fn.ei(z).simplify()).isA<ComplexNumber>();

      check(Fn.li(IntegerNumber.zero).simplify()).equals(IntegerNumber.zero);
      check(Fn.li(IntegerNumber.one).simplify()).equals(-Constant.infinity);
      check(Fn.li(z).simplify()).isA<ComplexNumber>();

      check(Fn.si(z).simplify()).isA<ComplexNumber>();
      check(Fn.ci(z).simplify()).isA<ComplexNumber>();
      check(Fn.shi(z).simplify()).isA<ComplexNumber>();
      check(Fn.chi(z).simplify()).isA<ComplexNumber>();
    });

    test('simplifies incomplete gamma, polylog, and expIntegralE', () {
      check(Fn.upperGamma(z, z).simplify()).isA<ComplexNumber>();
      check(Fn.lowerGamma(z, z).simplify()).isA<ComplexNumber>();
      check(Fn.polylog(z, z).simplify()).isA<ComplexNumber>();

      check(Fn.expIntegralE(IntegerNumber.two, IntegerNumber.zero).simplify())
          .equals(IntegerNumber.one);
      check(Fn.expIntegralE(IntegerNumber.one, IntegerNumber.zero).simplify())
          .equals(Constant.undefined);
      check(Fn.expIntegralE(z, r).simplify()).isA<ComplexNumber>();
      check(
        Fn.expIntegralE(
          const RealNumber(1.5),
          const RealNumber(-1.0),
        ).simplify(),
      ).isA<ComplexNumber>();
    });

    test('simplifies generalized hypergeometric and AppellF1 forms', () {
      check(
        Fn.hypergeometric(
          Fn.tuple([IntegerNumber.zero]),
          Fn.tuple([IntegerNumber.negativeOne]),
          x,
        ).simplify(),
      ).equals(Constant.undefined);
      check(
        Fn.hypergeometric(
          Fn.tuple([IntegerNumber.zero]),
          Fn.tuple([IntegerNumber.two]),
          x,
        ).simplify(),
      ).equals(IntegerNumber.one);
      check(
        Fn.hypergeometric(
          Fn.tuple([IntegerNumber.two]),
          Fn.tuple([IntegerNumber.two]),
          x,
        ).simplify().toString(),
      ).equals('exp(x)');
      check(
        Fn.hypergeometric(
          Fn.tuple([IntegerNumber.two]),
          Fn.tuple(const []),
          x,
        ).simplify().toString(),
      ).equals('(1 - x) ^ (-2)');
      check(
        Fn.hypergeometric(
          Fn.tuple([z]),
          Fn.tuple([const RealNumber(1.5)]),
          z,
        ).simplify(),
      ).isA<ComplexNumber>();

      check(
        Fn.appellF1([
          IntegerNumber.one,
          IntegerNumber.two,
          IntegerNumber.of(3),
          IntegerNumber.negativeOne,
          x,
          x,
        ]).simplify(),
      ).equals(Constant.undefined);
      check(
        Fn.appellF1([
          IntegerNumber.of(-2),
          IntegerNumber.two,
          IntegerNumber.of(3),
          IntegerNumber.negativeOne,
          x,
          x,
        ]).simplify(),
      ).equals(Constant.undefined);
      check(
        Fn.appellF1([
          IntegerNumber.two,
          IntegerNumber.one,
          IntegerNumber.of(3),
          IntegerNumber.of(4),
          IntegerNumber.zero,
          x,
        ]).simplify().toString(),
      ).equals('hypergeometric([2, 3], [4], x)');
      check(
        Fn.appellF1([
          IntegerNumber.two,
          IntegerNumber.one,
          IntegerNumber.of(3),
          IntegerNumber.of(4),
          x,
          IntegerNumber.zero,
        ]).simplify().toString(),
      ).equals('hypergeometric([2, 1], [4], x)');
      check(
        Fn.appellF1([
          IntegerNumber.two,
          IntegerNumber.one,
          IntegerNumber.of(3),
          IntegerNumber.of(4),
          x,
          x,
        ]).simplify().toString(),
      ).equals('(1 - x) ^ (-2)');
      check(
        Fn.appellF1([
          const RealNumber(0.5),
          z,
          const RealNumber(0.3),
          const RealNumber(1.5),
          const RealNumber(0.2),
          const RealNumber(-0.1),
        ]).simplify(),
      ).isA<ComplexNumber>();
    });
  });
}
