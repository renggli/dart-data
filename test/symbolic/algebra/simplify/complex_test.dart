import 'package:checks/checks.dart';
import 'package:data/src/symbolic/algebra/simplify/complex.dart';
import 'package:data/src/symbolic/algebra/simplify/discrete.dart';
import 'package:data/src/symbolic/algebra/simplify/domain.dart';
import 'package:data/src/symbolic/algebra/simplify/special.dart';
import 'package:data/src/symbolic/algebra/simplify/transcendental.dart';
import 'package:data/src/symbolic/algebra/structural_order.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Complex decomposition and conjugation simplification', () {
    test('complex decomposition and syntactic real simplification', () {
      const realAssumptions = Assumptions(
        domains: {'x': VariableDomain.real, 'y': VariableDomain.real},
      );
      const x = Variable('x');
      const y = Variable('y');
      const w = Variable('w');

      const complexW = Assumptions(domains: {'w': VariableDomain.complex});
      // Complex variable without decomposition returns Re(w) and Im(w)
      check(simplifyRe(w, assumptions: complexW))
          .equals(Re(w, isSimplified: true));
      check(simplifyIm(w, assumptions: complexW))
          .equals(Im(w, isSimplified: true));

      // Syntactically real expressions: Tanh, Asinh, Erf, Erfc, Gamma, Ln, Binomial, Beta, Mod
      check(simplifyIm(Tanh(x), assumptions: realAssumptions))
          .equals(IntegerNumber.zero);
      check(simplifyIm(Asinh(x), assumptions: realAssumptions))
          .equals(IntegerNumber.zero);
      check(simplifyIm(Erf(x), assumptions: realAssumptions))
          .equals(IntegerNumber.zero);
      check(simplifyIm(Erfc(x), assumptions: realAssumptions))
          .equals(IntegerNumber.zero);
      check(simplifyIm(Gamma(x), assumptions: realAssumptions))
          .equals(IntegerNumber.zero);
      check(simplifyIm(Binomial(x, y), assumptions: realAssumptions))
          .equals(IntegerNumber.zero);
      check(simplifyIm(Beta(x, y), assumptions: realAssumptions))
          .equals(IntegerNumber.zero);
      check(simplifyIm(Mod(x, y), assumptions: realAssumptions))
          .equals(IntegerNumber.zero);

      // Decompose Conjugate, Re, Im via toRectangularExpr
      final expr = Add([
        x,
        Mul([ComplexNumber.i, y]),
      ]);
      check(
        toRectangularExpr(
          Conjugate(expr),
          assumptions: realAssumptions,
        ).toString(),
      ).equals('x - i * y');
      check(toRectangularExpr(Re(expr), assumptions: realAssumptions))
          .equals(x);
      check(toRectangularExpr(Im(expr), assumptions: realAssumptions))
          .equals(y);

      // NotEqual simplification
      check(Expr.parse('1 != 2').simplify()).equals(IntegerNumber.one);
      check(Expr.parse('2 != 2').simplify()).equals(IntegerNumber.zero);

      // Polar and rectangular decompositions for unconstrained and constant expressions
      const z = Variable('z');
      const complexZ = Assumptions(domains: {'z': VariableDomain.complex});
      final polarZ = toPolarExpr(z, assumptions: complexZ);
      check(polarZ is Mul).isTrue();

      final polar22 = toPolarExpr(
        ComplexNumber.of(IntegerNumber.two, IntegerNumber.two),
      );
      check(polar22.toString()).equals('2 * sqrt(2) * exp(1/4 * i * pi)');
      check(polar22.anyNode((n) => n is Mul && n.factors.any((f) => f is Mul)))
          .isFalse();

      final rectC = toRectangularExpr(Constant.pi);
      check(rectC).equals(Constant.pi);
      final rectExpr = toRectangularExpr(
        Add([
          IntegerNumber.one,
          Mul([ComplexNumber.i, IntegerNumber.two]),
        ]),
      );
      check(rectExpr.toString()).equals('1 + 2 * i');
      check(toRectangularExpr(Conjugate(z), assumptions: complexZ).toString())
          .equals('re(z) - i * im(z)');
      check(toRectangularExpr(Re(z), assumptions: complexZ))
          .equals(Re(z, isSimplified: true));
      check(toRectangularExpr(Im(z), assumptions: complexZ))
          .equals(Im(z, isSimplified: true));

      // Abs of exp with complex exponent: |exp(3 + 4i)| = exp(3)
      final expComp = Pow(
        Constant.e,
        Add([
          IntegerNumber.of(3),
          Mul([ComplexNumber.i, IntegerNumber.of(4)]),
        ]),
      );
      check(simplifyAbs(expComp))
          .equals(Pow(Constant.e, IntegerNumber.of(3), isSimplified: true));

      // isEvenIntegerExpr on Add and Pow
      check(isEvenIntegerExpr(Add([IntegerNumber.of(2), IntegerNumber.of(4)])))
          .isTrue();
      check(isEvenIntegerExpr(Pow(IntegerNumber.of(2), IntegerNumber.of(3))))
          .isTrue();

      // isIntegerExpr guards non-integer Factorial, Binomial, and complex Sign
      check(isIntegerExpr(Factorial(FractionNumber.half))).isFalse();
      check(isIntegerExpr(Binomial(FractionNumber.half, IntegerNumber.two)))
          .isFalse();
      check(isIntegerExpr(Sign(z), assumptions: complexZ)).isFalse();
      check(isIntegerExpr(Sign(x), assumptions: realAssumptions)).isTrue();
      check(Floor(Factorial(x)).simplify()).isA<Floor>();

      // RealNumber contagion in Mod, Re, Im, Arg, and toPolarExpr
      check(simplifyMod(const RealNumber(0.0), IntegerNumber.of(3)))
          .equals(const RealNumber(0.0));
      check(simplifyRe(ComplexNumber(IntegerNumber.two, const RealNumber(1.0))))
          .equals(const RealNumber(2.0));
      check(simplifyIm(const RealNumber(3.5))).equals(const RealNumber(0.0));
      check(simplifyArg(const RealNumber(-2.0))).isA<RealNumber>();
      check(toPolarExpr(const RealNumber(0.0))).equals(const RealNumber(0.0));

      // Exact quadrant multiples of pi/6, pi/4, pi/3, pi/2 across sin, cos, tan
      for (final numVal in [1, 2, 3, 4, 5, 7, 11]) {
        for (final denVal in [2, 3, 4, 6]) {
          final angle = Mul([
            RationalNumber.of(Integer(numVal), Integer(denVal)),
            Constant.pi,
          ]);
          check(simplifySin(angle).evaluate())
              .isCloseTo(Sin(angle).evaluate(), 1e-12);
          check(simplifyCos(angle).evaluate())
              .isCloseTo(Cos(angle).evaluate(), 1e-12);
          if ((numVal * 12 ~/ denVal) % 12 != 6) {
            check(simplifyTan(angle).evaluate())
                .isCloseTo(Tan(angle).evaluate(), 1e-12);
          } else {
            check(simplifyTan(angle)).equals(Constant.undefined);
          }
        }
      }

      // Complex decomposition of Sin, Cos, Sinh, Cosh, Pow
      final cArg = Add([
        x,
        Mul([ComplexNumber.i, y]),
      ]);
      check(toRectangularExpr(Sin(cArg), assumptions: realAssumptions))
          .isA<Add>();
      check(toRectangularExpr(Cos(cArg), assumptions: realAssumptions))
          .isA<Add>();
      check(toRectangularExpr(Sinh(cArg), assumptions: realAssumptions))
          .isA<Add>();
      check(toRectangularExpr(Cosh(cArg), assumptions: realAssumptions))
          .isA<Add>();
      check(
        toRectangularExpr(
          Pow(cArg, IntegerNumber.two),
          assumptions: realAssumptions,
        ),
      ).isA<Add>();

      // RealNumber branches across special functions, rounding, and sign
      check(simplifyLambertW(const RealNumber(0.5), 0)).isA<RealNumber>();
      check(simplifyLambertW(const RealNumber(-0.2), -1)).isA<RealNumber>();
      check(simplifyLambertW(const RealNumber(-1.0), 0))
          .equals(Constant.undefined);
      check(simplifyErf(const RealNumber(0.5))).isA<RealNumber>();
      check(simplifyErfc(const RealNumber(0.5))).isA<RealNumber>();
      check(simplifyGamma(const RealNumber(2.5))).isA<RealNumber>();
      check(simplifyGamma(const RealNumber(-1.0))).equals(Constant.undefined);
      check(simplifyBeta(const RealNumber(2.0), const RealNumber(3.0)))
          .isA<RealNumber>();
      check(simplifyBeta(const RealNumber(-1.0), const RealNumber(2.0)))
          .equals(Constant.undefined);
      check(simplifyAsinh(const RealNumber(1.0))).isA<RealNumber>();
      check(simplifyAcosh(const RealNumber(2.0))).isA<RealNumber>();
      check(simplifyAcosh(const RealNumber(0.5))).equals(Constant.undefined);
      check(simplifyAtanh(const RealNumber(0.5))).isA<RealNumber>();
      check(simplifyAtanh(const RealNumber(2.0))).equals(Constant.undefined);
      check(simplifyFactorial(const RealNumber(2.5))).isA<RealNumber>();
      check(simplifyBinomial(const RealNumber(4.0), const RealNumber(2.0)))
          .isA<RealNumber>();
      check(simplifyBinomial(x, const RealNumber(1.0))).equals(x);
      check(simplifyFloor(Add([const RealNumber(1.2), Constant.pi])))
          .equals(const RealNumber(4.0));
      check(simplifyCeil(Add([const RealNumber(1.2), Constant.pi])))
          .equals(const RealNumber(5.0));
      check(simplifyRound(Add([const RealNumber(1.2), Constant.pi])))
          .equals(const RealNumber(4.0));
      check(simplifySign(const RealNumber(2.5))).equals(const RealNumber(1.0));
      check(simplifySign(Add([const RealNumber(1.0), Constant.pi])))
          .equals(const RealNumber(1.0));
      check(
        simplifyArg(
          ComplexNumber(const RealNumber(1.0), const RealNumber(1.0)),
        ),
      ).isA<RealNumber>();
      check(simplifyRe(z, assumptions: complexZ))
          .equals(Re(z, isSimplified: true));
      check(simplifyIm(z, assumptions: complexZ))
          .equals(Im(z, isSimplified: true));
      check(simplifySinh(const RealNumber(1.0))).isA<RealNumber>();
      check(simplifyCosh(const RealNumber(1.0))).isA<RealNumber>();
      check(simplifyTanh(const RealNumber(1.0))).isA<RealNumber>();
      check(simplifyExp(const RealNumber(1.0))).isA<RealNumber>();
      check(simplifyLn(Pow(x, FractionNumber.half))).isA<Mul>();
      check(toRectangularExpr(ComplexNumber.i)).equals(ComplexNumber.i);
      check(toPolarExpr(const RealNumber(-1.0))).isA<Mul>();
      check(simplifyIm(ComplexNumber(const RealNumber(1.0), IntegerNumber.two)))
          .equals(const RealNumber(2.0));

      // Propagation of Constant.undefined across simplify* functions
      check(simplifySin(Constant.undefined)).equals(Constant.undefined);
      check(simplifyCos(Constant.undefined)).equals(Constant.undefined);
      check(simplifyTan(Constant.undefined)).equals(Constant.undefined);
      check(simplifyAsin(Constant.undefined)).equals(Constant.undefined);
      check(simplifyAcos(Constant.undefined)).equals(Constant.undefined);
      check(simplifyAtan(Constant.undefined)).equals(Constant.undefined);
      check(simplifySinh(Constant.undefined)).equals(Constant.undefined);
      check(simplifyCosh(Constant.undefined)).equals(Constant.undefined);
      check(simplifyTanh(Constant.undefined)).equals(Constant.undefined);
      check(simplifyAbs(Constant.undefined)).equals(Constant.undefined);
      check(simplifyExp(Constant.undefined)).equals(Constant.undefined);
      check(simplifyLn(Constant.undefined)).equals(Constant.undefined);
      check(simplifyLambertW(Constant.undefined, 0)).equals(Constant.undefined);
      check(simplifyErf(Constant.undefined)).equals(Constant.undefined);
      check(simplifyErfc(Constant.undefined)).equals(Constant.undefined);
      check(simplifyGamma(Constant.undefined)).equals(Constant.undefined);
      check(simplifyBeta(Constant.undefined, IntegerNumber.one))
          .equals(Constant.undefined);
      check(simplifyBeta(IntegerNumber.one, Constant.undefined))
          .equals(Constant.undefined);
      check(simplifyAsinh(Constant.undefined)).equals(Constant.undefined);
      check(simplifyAcosh(Constant.undefined)).equals(Constant.undefined);
      check(simplifyAtanh(Constant.undefined)).equals(Constant.undefined);
      check(simplifyFactorial(Constant.undefined)).equals(Constant.undefined);
      check(simplifyBinomial(Constant.undefined, IntegerNumber.one))
          .equals(Constant.undefined);
      check(simplifyBinomial(IntegerNumber.one, Constant.undefined))
          .equals(Constant.undefined);
      check(simplifyFloor(Constant.undefined)).equals(Constant.undefined);
      check(simplifyCeil(Constant.undefined)).equals(Constant.undefined);
      check(simplifyRound(Constant.undefined)).equals(Constant.undefined);
      check(simplifySign(Constant.undefined)).equals(Constant.undefined);
      check(simplifyMod(Constant.undefined, IntegerNumber.one))
          .equals(Constant.undefined);
      check(simplifyMod(IntegerNumber.one, Constant.undefined))
          .equals(Constant.undefined);
      check(Sin(Asin(const RealNumber(2.0))).simplify())
          .equals(Constant.undefined);

      // isProvenReal on non-negative base with real exponent, and isIntegerExpr on Factorial and Binomial
      check(isProvenReal(Pow(Abs(x), y), realAssumptions)).isTrue();
      check(isProvenReal(Factorial(ComplexNumber.i))).isFalse();
      check(isProvenReal(Binomial(ComplexNumber.i, IntegerNumber.one)))
          .isFalse();
      check(isProvenReal(Floor(ComplexNumber.i))).isFalse();
      check(isProvenReal(Ceil(ComplexNumber.i))).isFalse();
      check(isProvenReal(Round(ComplexNumber.i))).isFalse();
      check(isProvenReal(Sign(ComplexNumber.i))).isFalse();
      check(Im(Factorial(ComplexNumber.i)).simplify())
          .not((it) => it.equals(IntegerNumber.zero));
      check(isProvenReal(LambertW(IntegerNumber.of(-1)))).isFalse();
      check(isProvenReal(LambertW(IntegerNumber.one, branch: -1))).isFalse();
      check(isProvenReal(LambertW(IntegerNumber.one))).isTrue();
      check(isProvenReal(Asin(Constant.pi))).isFalse();
      check(isProvenReal(Acos(Constant.pi))).isFalse();
      check(isProvenReal(Atanh(Constant.e))).isFalse();
      check(isProvenReal(Acosh(IntegerNumber.zero))).isFalse();
      const intAssumptions = Assumptions(
        domains: {'x': VariableDomain.positive, 'y': VariableDomain.integer},
      );
      check(
        isIntegerExpr(
          Factorial(IntegerNumber.of(3)),
          assumptions: intAssumptions,
        ),
      ).isTrue();
      check(isIntegerExpr(Binomial(y, y), assumptions: intAssumptions))
          .isTrue();

      // Derivative structural comparison with point
      final d0 = Derivative(x, 'x');
      final d1 = Derivative(x, 'x', point: IntegerNumber.zero);
      final d2 = Derivative(x, 'x', point: IntegerNumber.one);
      check(compareStructural(d0, d0)).equals(0);
      check(compareStructural(d0, d1)).isLessThan(0);
      check(compareStructural(d1, d0)).isGreaterThan(0);
      check(compareStructural(d1, d2)).isLessThan(0);

      // Special functions: Zeta, Digamma, Polygamma, Bessel, Elliptic simplification and domain
      check(simplifyZeta(Constant.undefined)).equals(Constant.undefined);
      check(simplifyDigamma(Constant.undefined)).equals(Constant.undefined);
      check(simplifyPolygamma(Constant.undefined, x))
          .equals(Constant.undefined);
      check(simplifyPolygamma(IntegerNumber.one, Constant.undefined))
          .equals(Constant.undefined);
      check(simplifyBesselJ(Constant.undefined, x)).equals(Constant.undefined);
      check(simplifyBesselJ(IntegerNumber.zero, Constant.undefined))
          .equals(Constant.undefined);
      check(simplifyBesselY(Constant.undefined, x)).equals(Constant.undefined);
      check(simplifyBesselI(Constant.undefined, x)).equals(Constant.undefined);
      check(simplifyBesselK(Constant.undefined, x)).equals(Constant.undefined);
      check(simplifyEllipticK(Constant.undefined)).equals(Constant.undefined);
      check(simplifyEllipticE(Constant.undefined)).equals(Constant.undefined);

      // Real domain checks
      check(isProvenReal(Zeta(IntegerNumber.two), realAssumptions)).isTrue();
      check(isProvenReal(Zeta(ComplexNumber.i), realAssumptions)).isFalse();
      check(isProvenReal(Digamma(IntegerNumber.two), realAssumptions)).isTrue();
      check(isProvenReal(Digamma(ComplexNumber.i), realAssumptions)).isFalse();
      check(
        isProvenReal(
          Polygamma(IntegerNumber.one, IntegerNumber.two),
          realAssumptions,
        ),
      ).isTrue();
      check(
        isProvenReal(
          BesselJ(IntegerNumber.zero, IntegerNumber.one),
          realAssumptions,
        ),
      ).isTrue();
      check(
        isProvenReal(
          BesselY(IntegerNumber.zero, IntegerNumber.one),
          realAssumptions,
        ),
      ).isTrue();
      check(
        isProvenReal(
          BesselI(IntegerNumber.zero, IntegerNumber.one),
          realAssumptions,
        ),
      ).isTrue();
      check(
        isProvenReal(
          BesselK(IntegerNumber.zero, IntegerNumber.one),
          realAssumptions,
        ),
      ).isTrue();
      check(isProvenReal(EllipticK(FractionNumber.half), realAssumptions))
          .isTrue();
      check(isProvenReal(EllipticK(IntegerNumber.two), realAssumptions))
          .isFalse();
      check(isProvenReal(EllipticE(FractionNumber.half), realAssumptions))
          .isTrue();
      check(isProvenReal(EllipticE(IntegerNumber.two), realAssumptions))
          .isFalse();
    });
  });
}
