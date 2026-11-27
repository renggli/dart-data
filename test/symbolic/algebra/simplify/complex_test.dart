import 'package:checks/checks.dart';
import 'package:data/src/symbolic/algebra/simplify/complex.dart';
import 'package:data/src/symbolic/algebra/simplify/discrete.dart';
import 'package:data/src/symbolic/algebra/simplify/domain.dart';
import 'package:data/src/symbolic/algebra/simplify/special.dart';
import 'package:data/src/symbolic/algebra/simplify/special_integrals.dart';
import 'package:data/src/symbolic/algebra/simplify/transcendental.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

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
      check(simplifyRe(w, assumptions: complexW)).equals(Fn.re(w));
      check(simplifyIm(w, assumptions: complexW)).equals(Fn.im(w));

      // Syntactically real expressions: Tanh, Asinh, Erf, Erfc, Gamma, Ln, Binomial, Beta, Mod
      check(simplifyIm(Fn.tanh(x), assumptions: realAssumptions))
          .equals(IntegerNumber.zero);
      check(simplifyIm(Fn.asinh(x), assumptions: realAssumptions))
          .equals(IntegerNumber.zero);
      check(simplifyIm(Fn.erf(x), assumptions: realAssumptions))
          .equals(IntegerNumber.zero);
      check(simplifyIm(Fn.erfc(x), assumptions: realAssumptions))
          .equals(IntegerNumber.zero);
      check(simplifyIm(Fn.gamma(x), assumptions: Assumptions.positive))
          .equals(IntegerNumber.zero);
      check(simplifyIm(Fn.binomial(x, y), assumptions: realAssumptions))
          .equals(IntegerNumber.zero);
      check(simplifyIm(Fn.beta(x, y), assumptions: Assumptions.positive))
          .equals(IntegerNumber.zero);
      check(simplifyIm(Fn.mod(x, y), assumptions: realAssumptions))
          .equals(IntegerNumber.zero);

      // Decompose Conjugate, Re, Im via toRectangularExpr
      final expr = Add.of([
        x,
        Mul.of([ComplexNumber.i, y]),
      ]);
      check(
        toRectangularExpr(
          Fn.conj(expr),
          assumptions: realAssumptions,
        ).toString(),
      ).equals('x - i * y');
      check(toRectangularExpr(Fn.re(expr), assumptions: realAssumptions))
          .equals(x);
      check(toRectangularExpr(Fn.im(expr), assumptions: realAssumptions))
          .equals(y);

      // NotEqual simplification
      check(Expr.parse('1 != 2').simplify()).equals(IntegerNumber.one);
      check(Expr.parse('2 != 2').simplify()).equals(IntegerNumber.zero);

      // Polar and rectangular decompositions for unconstrained and constant expressions
      const z = Variable('z');
      const complexZ = Assumptions(domains: {'z': VariableDomain.complex});
      final polarZ = toPolarExpr(z, assumptions: complexZ);
      check(polarZ is Mul).isTrue;

      final polar22 = toPolarExpr(
        ComplexNumber.of(IntegerNumber.two, IntegerNumber.two),
        assumptions: Assumptions.none,
      );
      check(polar22.toString()).equals('2 * sqrt(2) * exp(1/4 * i * pi)');
      check(polar22.anyNode((n) => n is Mul && n.factors.any((f) => f is Mul)))
          .isFalse;

      final rectC = toRectangularExpr(
        Constant.pi,
        assumptions: Assumptions.none,
      );
      check(rectC).equals(Constant.pi);
      final rectExpr = toRectangularExpr(
        Add.of([
          IntegerNumber.one,
          Mul.of([ComplexNumber.i, IntegerNumber.two]),
        ]),
        assumptions: Assumptions.none,
      );
      check(rectExpr.toString()).equals('1 + 2 * i');
      check(toRectangularExpr(Fn.conj(z), assumptions: complexZ).toString())
          .equals('re(z) - i * im(z)');
      check(toRectangularExpr(Fn.re(z), assumptions: complexZ))
          .equals(Fn.re(z));
      check(toRectangularExpr(Fn.im(z), assumptions: complexZ))
          .equals(Fn.im(z));

      // Abs of exp with complex exponent: |exp(3 + 4i)| = exp(3)
      final expComp = Pow.of(
        Constant.e,
        Add.of([
          IntegerNumber.of(3),
          Mul.of([ComplexNumber.i, IntegerNumber.of(4)]),
        ]),
      );
      check(simplifyAbs(expComp, assumptions: Assumptions.none))
          .equals(Pow.of(Constant.e, IntegerNumber.of(3)));

      // isEvenIntegerExpr on Add and Pow
      check(
        isEvenIntegerExpr(
          Add.of([IntegerNumber.of(2), IntegerNumber.of(4)]),
          assumptions: Assumptions.none,
        ),
      ).isTrue;
      check(
        isEvenIntegerExpr(
          Pow.of(IntegerNumber.of(2), IntegerNumber.of(3)),
          assumptions: Assumptions.none,
        ),
      ).isTrue;

      // isIntegerExpr guards non-integer Factorial, Binomial, and complex Sign
      check(
        isIntegerExpr(
          Fn.factorial(FractionNumber.half),
          assumptions: Assumptions.none,
        ),
      ).isFalse;
      check(
        isIntegerExpr(
          Fn.binomial(FractionNumber.half, IntegerNumber.two),
          assumptions: Assumptions.none,
        ),
      ).isFalse;
      check(isIntegerExpr(Fn.sign(z), assumptions: complexZ)).isFalse;
      check(isIntegerExpr(Fn.sign(x), assumptions: realAssumptions)).isTrue;
      check(Fn.floor(Fn.factorial(x)).simplify())
          .isA<Call>()
          .has('id', (Call c) => c.id)
          .equals(FunctionId.floor);

      // RealNumber contagion in Mod, Re, Im, Arg, and toPolarExpr
      check(
        simplifyMod(
          const RealNumber(0.0),
          IntegerNumber.of(3),
          assumptions: Assumptions.none,
        ),
      ).equals(const RealNumber(0.0));
      check(
        simplifyRe(
          ComplexNumber(IntegerNumber.two, const RealNumber(1.0)),
          assumptions: Assumptions.none,
        ),
      ).equals(const RealNumber(2.0));
      check(simplifyIm(const RealNumber(3.5), assumptions: Assumptions.none))
          .equals(const RealNumber(0.0));
      check(simplifyArg(const RealNumber(-2.0), assumptions: Assumptions.none))
          .isA<RealNumber>();
      check(toPolarExpr(const RealNumber(0.0), assumptions: Assumptions.none))
          .equals(const RealNumber(0.0));

      // Exact quadrant multiples of pi/6, pi/4, pi/3, pi/2 across sin, cos, tan
      for (final numVal in [1, 2, 3, 4, 5, 7, 11]) {
        for (final denVal in [2, 3, 4, 6]) {
          final angle = Mul.of([
            RationalNumber.of(BigInt.from(numVal), BigInt.from(denVal)),
            Constant.pi,
          ]);
          check(simplifySin(angle, assumptions: Assumptions.none).evaluate())
              .isCloseTo(Fn.sin(angle).evaluate(), 1e-12);
          check(simplifyCos(angle, assumptions: Assumptions.none).evaluate())
              .isCloseTo(Fn.cos(angle).evaluate(), 1e-12);
          if ((numVal * 12 ~/ denVal) % 12 != 6) {
            check(simplifyTan(angle, assumptions: Assumptions.none).evaluate())
                .isCloseTo(Fn.tan(angle).evaluate(), 1e-12);
          } else {
            check(simplifyTan(angle, assumptions: Assumptions.none))
                .equals(Constant.undefined);
          }
        }
      }

      // Complex decomposition of Sin, Cos, Sinh, Cosh, Pow
      final cArg = Add.of([
        x,
        Mul.of([ComplexNumber.i, y]),
      ]);
      check(toRectangularExpr(Fn.sin(cArg), assumptions: realAssumptions))
          .isA<Add>();
      check(toRectangularExpr(Fn.cos(cArg), assumptions: realAssumptions))
          .isA<Add>();
      check(toRectangularExpr(Fn.sinh(cArg), assumptions: realAssumptions))
          .isA<Add>();
      check(toRectangularExpr(Fn.cosh(cArg), assumptions: realAssumptions))
          .isA<Add>();
      check(
        toRectangularExpr(
          Pow.of(cArg, IntegerNumber.two),
          assumptions: realAssumptions,
        ),
      ).isA<Add>();

      // RealNumber branches across special functions, rounding, and sign
      check(
        simplifyLambertW(
          const RealNumber(0.5),
          0,
          assumptions: Assumptions.none,
        ),
      ).isA<RealNumber>();
      check(
        simplifyLambertW(
          const RealNumber(-0.2),
          -1,
          assumptions: Assumptions.none,
        ),
      ).isA<RealNumber>();
      check(
        simplifyLambertW(
          const RealNumber(-1.0),
          0,
          assumptions: Assumptions.none,
        ),
      ).equals(Constant.undefined);
      check(simplifyErf(const RealNumber(0.5), assumptions: Assumptions.none))
          .isA<RealNumber>();
      check(simplifyErfc(const RealNumber(0.5), assumptions: Assumptions.none))
          .isA<RealNumber>();
      check(simplifyGamma(const RealNumber(2.5), assumptions: Assumptions.none))
          .isA<RealNumber>();
      check(
        simplifyGamma(const RealNumber(-1.0), assumptions: Assumptions.none),
      ).equals(Constant.undefined);
      check(
        simplifyBeta(
          const RealNumber(2.0),
          const RealNumber(3.0),
          assumptions: Assumptions.none,
        ),
      ).isA<RealNumber>();
      check(
        simplifyBeta(
          const RealNumber(-1.0),
          const RealNumber(2.0),
          assumptions: Assumptions.none,
        ),
      ).equals(Constant.undefined);
      check(simplifyAsinh(const RealNumber(1.0), assumptions: Assumptions.none))
          .isA<RealNumber>();
      check(simplifyAcosh(const RealNumber(2.0), assumptions: Assumptions.none))
          .isA<RealNumber>();
      check(simplifyAcosh(const RealNumber(0.5), assumptions: Assumptions.none))
          .equals(Constant.undefined);
      check(simplifyAtanh(const RealNumber(0.5), assumptions: Assumptions.none))
          .isA<RealNumber>();
      check(simplifyAtanh(const RealNumber(2.0), assumptions: Assumptions.none))
          .equals(Constant.undefined);
      check(
        simplifyFactorial(const RealNumber(2.5), assumptions: Assumptions.none),
      ).isA<RealNumber>();
      check(
        simplifyBinomial(
          const RealNumber(4.0),
          const RealNumber(2.0),
          assumptions: Assumptions.none,
        ),
      ).isA<RealNumber>();
      check(
        simplifyBinomial(
          x,
          const RealNumber(1.0),
          assumptions: Assumptions.none,
        ),
      ).equals(x);
      check(
        simplifyFloor(
          Add.of([const RealNumber(1.2), Constant.pi]),
          assumptions: Assumptions.none,
        ),
      ).equals(const RealNumber(4.0));
      check(
        simplifyCeil(
          Add.of([const RealNumber(1.2), Constant.pi]),
          assumptions: Assumptions.none,
        ),
      ).equals(const RealNumber(5.0));
      check(
        simplifyRound(
          Add.of([const RealNumber(1.2), Constant.pi]),
          assumptions: Assumptions.none,
        ),
      ).equals(const RealNumber(4.0));
      check(simplifySign(const RealNumber(2.5), assumptions: Assumptions.none))
          .equals(const RealNumber(1.0));
      check(
        simplifySign(
          Add.of([const RealNumber(1.0), Constant.pi]),
          assumptions: Assumptions.none,
        ),
      ).equals(const RealNumber(1.0));
      check(
        simplifyArg(
          ComplexNumber(const RealNumber(1.0), const RealNumber(1.0)),
          assumptions: Assumptions.none,
        ),
      ).isA<RealNumber>();
      check(simplifyRe(z, assumptions: complexZ)).equals(Fn.re(z));
      check(simplifyIm(z, assumptions: complexZ)).equals(Fn.im(z));
      check(simplifySinh(const RealNumber(1.0), assumptions: Assumptions.none))
          .isA<RealNumber>();
      check(simplifyCosh(const RealNumber(1.0), assumptions: Assumptions.none))
          .isA<RealNumber>();
      check(simplifyTanh(const RealNumber(1.0), assumptions: Assumptions.none))
          .isA<RealNumber>();
      check(simplifyExp(const RealNumber(1.0), assumptions: Assumptions.none))
          .isA<RealNumber>();
      check(
        simplifyLn(
          Pow.of(x, FractionNumber.half),
          assumptions: Assumptions.none,
        ),
      ).isA<Mul>();
      check(toRectangularExpr(ComplexNumber.i, assumptions: Assumptions.none))
          .equals(ComplexNumber.i);
      check(toPolarExpr(const RealNumber(-1.0), assumptions: Assumptions.none))
          .isA<Pow>();
      check(
        simplifyIm(
          ComplexNumber(const RealNumber(1.0), IntegerNumber.two),
          assumptions: Assumptions.none,
        ),
      ).equals(const RealNumber(2.0));

      // Propagation of Constant.undefined across simplify* functions
      check(simplifySin(Constant.undefined, assumptions: Assumptions.none))
          .equals(Constant.undefined);
      check(simplifyCos(Constant.undefined, assumptions: Assumptions.none))
          .equals(Constant.undefined);
      check(simplifyTan(Constant.undefined, assumptions: Assumptions.none))
          .equals(Constant.undefined);
      check(simplifyAsin(Constant.undefined, assumptions: Assumptions.none))
          .equals(Constant.undefined);
      check(simplifyAcos(Constant.undefined, assumptions: Assumptions.none))
          .equals(Constant.undefined);
      check(simplifyAtan(Constant.undefined, assumptions: Assumptions.none))
          .equals(Constant.undefined);
      check(simplifySinh(Constant.undefined, assumptions: Assumptions.none))
          .equals(Constant.undefined);
      check(simplifyCosh(Constant.undefined, assumptions: Assumptions.none))
          .equals(Constant.undefined);
      check(simplifyTanh(Constant.undefined, assumptions: Assumptions.none))
          .equals(Constant.undefined);
      check(simplifyAbs(Constant.undefined, assumptions: Assumptions.none))
          .equals(Constant.undefined);
      check(simplifyExp(Constant.undefined, assumptions: Assumptions.none))
          .equals(Constant.undefined);
      check(simplifyLn(Constant.undefined, assumptions: Assumptions.none))
          .equals(Constant.undefined);
      check(
        simplifyLambertW(Constant.undefined, 0, assumptions: Assumptions.none),
      ).equals(Constant.undefined);
      check(simplifyErf(Constant.undefined, assumptions: Assumptions.none))
          .equals(Constant.undefined);
      check(simplifyErfc(Constant.undefined, assumptions: Assumptions.none))
          .equals(Constant.undefined);
      check(simplifyGamma(Constant.undefined, assumptions: Assumptions.none))
          .equals(Constant.undefined);
      check(
        simplifyBeta(
          Constant.undefined,
          IntegerNumber.one,
          assumptions: Assumptions.none,
        ),
      ).equals(Constant.undefined);
      check(
        simplifyBeta(
          IntegerNumber.one,
          Constant.undefined,
          assumptions: Assumptions.none,
        ),
      ).equals(Constant.undefined);
      check(simplifyAsinh(Constant.undefined, assumptions: Assumptions.none))
          .equals(Constant.undefined);
      check(simplifyAcosh(Constant.undefined, assumptions: Assumptions.none))
          .equals(Constant.undefined);
      check(simplifyAtanh(Constant.undefined, assumptions: Assumptions.none))
          .equals(Constant.undefined);
      check(
        simplifyFactorial(Constant.undefined, assumptions: Assumptions.none),
      ).equals(Constant.undefined);
      check(
        simplifyBinomial(
          Constant.undefined,
          IntegerNumber.one,
          assumptions: Assumptions.none,
        ),
      ).equals(Constant.undefined);
      check(
        simplifyBinomial(
          IntegerNumber.one,
          Constant.undefined,
          assumptions: Assumptions.none,
        ),
      ).equals(Constant.undefined);
      check(simplifyFloor(Constant.undefined, assumptions: Assumptions.none))
          .equals(Constant.undefined);
      check(simplifyCeil(Constant.undefined, assumptions: Assumptions.none))
          .equals(Constant.undefined);
      check(simplifyRound(Constant.undefined, assumptions: Assumptions.none))
          .equals(Constant.undefined);
      check(simplifySign(Constant.undefined, assumptions: Assumptions.none))
          .equals(Constant.undefined);
      check(
        simplifyMod(
          Constant.undefined,
          IntegerNumber.one,
          assumptions: Assumptions.none,
        ),
      ).equals(Constant.undefined);
      check(
        simplifyMod(
          IntegerNumber.one,
          Constant.undefined,
          assumptions: Assumptions.none,
        ),
      ).equals(Constant.undefined);
      check(Fn.sin(Fn.asin(const RealNumber(2.0))).simplify())
          .equals(Constant.undefined);

      // isProvenReal on non-negative base with real exponent, and isIntegerExpr on Factorial and Binomial
      check(isProvenReal(Pow.of(Fn.abs(x), y), Assumptions.positive)).isTrue;
      check(isProvenReal(Fn.factorial(ComplexNumber.i), Assumptions.none))
          .isFalse;
      check(
        isProvenReal(
          Fn.binomial(ComplexNumber.i, IntegerNumber.one),
          Assumptions.none,
        ),
      ).isFalse;
      check(isProvenReal(Fn.floor(ComplexNumber.i), Assumptions.none)).isFalse;
      check(isProvenReal(Fn.ceil(ComplexNumber.i), Assumptions.none)).isFalse;
      check(isProvenReal(Fn.round(ComplexNumber.i), Assumptions.none)).isFalse;
      check(isProvenReal(Fn.sign(ComplexNumber.i), Assumptions.none)).isFalse;
      check(Fn.im(Fn.factorial(ComplexNumber.i)).simplify())
          .not(.it()..equals(IntegerNumber.zero));
      check(isProvenReal(Fn.lambertW(IntegerNumber.of(-1)), Assumptions.none))
          .isFalse;
      check(
        isProvenReal(
          Fn.lambertW(IntegerNumber.one, IntegerNumber.negativeOne),
          Assumptions.none,
        ),
      ).isFalse;
      check(isProvenReal(Fn.lambertW(IntegerNumber.one), Assumptions.none))
          .isTrue;
      check(isProvenReal(Fn.asin(Constant.pi), Assumptions.none)).isFalse;
      check(isProvenReal(Fn.acos(Constant.pi), Assumptions.none)).isFalse;
      check(isProvenReal(Fn.atanh(Constant.e), Assumptions.none)).isFalse;
      check(isProvenReal(Fn.acosh(IntegerNumber.zero), Assumptions.none))
          .isFalse;
      const intAssumptions = Assumptions(
        domains: {'x': VariableDomain.positive, 'y': VariableDomain.integer},
      );
      check(
        isIntegerExpr(
          Fn.factorial(IntegerNumber.of(3)),
          assumptions: intAssumptions,
        ),
      ).isTrue;
      check(isIntegerExpr(Fn.binomial(y, y), assumptions: intAssumptions))
          .isTrue;

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
      check(
        simplifyEllipticK(Constant.undefined, assumptions: Assumptions.none),
      ).equals(Constant.undefined);
      check(
        simplifyEllipticE(Constant.undefined, assumptions: Assumptions.none),
      ).equals(Constant.undefined);

      // Real domain checks
      check(isProvenReal(Fn.zeta(IntegerNumber.two), realAssumptions)).isTrue;
      check(isProvenReal(Fn.zeta(ComplexNumber.i), realAssumptions)).isFalse;
      check(isProvenReal(Fn.digamma(IntegerNumber.two), realAssumptions))
          .isTrue;
      check(isProvenReal(Fn.digamma(ComplexNumber.i), realAssumptions)).isFalse;
      check(
        isProvenReal(
          Fn.polygamma(IntegerNumber.one, IntegerNumber.two),
          realAssumptions,
        ),
      ).isTrue;
      check(
        isProvenReal(
          Fn.besselJ(IntegerNumber.zero, IntegerNumber.one),
          realAssumptions,
        ),
      ).isTrue;
      check(
        isProvenReal(
          Fn.besselY(IntegerNumber.zero, IntegerNumber.one),
          realAssumptions,
        ),
      ).isTrue;
      check(
        isProvenReal(
          Fn.besselI(IntegerNumber.zero, IntegerNumber.one),
          realAssumptions,
        ),
      ).isTrue;
      check(
        isProvenReal(
          Fn.besselK(IntegerNumber.zero, IntegerNumber.one),
          realAssumptions,
        ),
      ).isTrue;
      check(isProvenReal(Fn.ellipticK(FractionNumber.half), realAssumptions))
          .isTrue;
      check(isProvenReal(Fn.ellipticK(IntegerNumber.two), realAssumptions))
          .isFalse;
      check(isProvenReal(Fn.ellipticE(FractionNumber.half), realAssumptions))
          .isTrue;
      check(isProvenReal(Fn.ellipticE(IntegerNumber.two), realAssumptions))
          .isFalse;
    });
  });
}
