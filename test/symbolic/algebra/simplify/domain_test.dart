import 'package:checks/checks.dart';
import 'package:data/src/symbolic/algebra/simplify/domain.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Domain and complex decomposition helpers', () {
    const x = Variable('x');
    const realAssumptions = Assumptions(domains: {'x': VariableDomain.real});
    const posAssumptions = Assumptions(domains: {'x': VariableDomain.positive});
    const intAssumptions = Assumptions(domains: {'x': VariableDomain.integer});

    group('isProvenReal', () {
      test('identifies real numbers and constants', () {
        check(isProvenReal(IntegerNumber.of(5), Assumptions.none)).isTrue;
        check(isProvenReal(FractionNumber.half, Assumptions.none)).isTrue;
        check(isProvenReal(const RealNumber(3.14), Assumptions.none)).isTrue;
        check(isProvenReal(Constant.pi, Assumptions.none)).isTrue;
        check(isProvenReal(Constant.e, Assumptions.none)).isTrue;
        check(isProvenReal(ComplexNumber.i, Assumptions.none)).isFalse;
      });

      test('respects variable assumptions', () {
        check(isProvenReal(x, Assumptions.none)).isFalse;
        check(isProvenReal(x, realAssumptions)).isTrue;
        check(isProvenReal(x, posAssumptions)).isTrue;
        check(isProvenReal(x, intAssumptions)).isTrue;
        check(
          isProvenReal(
            x,
            const Assumptions(domains: {'x': VariableDomain.complex}),
          ),
        ).isFalse;
      });

      test('checks composite expressions', () {
        check(
          isProvenReal(
            Add.of([IntegerNumber.one, Constant.pi]),
            Assumptions.none,
          ),
        ).isTrue;
        check(
          isProvenReal(
            Add.of([IntegerNumber.one, ComplexNumber.i]),
            Assumptions.none,
          ),
        ).isFalse;
        check(isProvenReal(Fn.sin(x), realAssumptions)).isTrue;
        check(isProvenReal(Fn.cos(x), realAssumptions)).isTrue;
        check(isProvenReal(Pow.of(x, IntegerNumber.two), realAssumptions))
            .isTrue;
        check(isProvenReal(Fn.abs(x), Assumptions.none)).isTrue;
        check(isProvenReal(Fn.re(x), Assumptions.none)).isTrue;
        check(isProvenReal(Fn.im(x), Assumptions.none)).isTrue;
        check(isProvenReal(Fn.arg(x), Assumptions.none)).isTrue;
      });
    });

    group('isPositiveExpr and isNonNegativeExpr', () {
      test('detects positive numbers and expressions', () {
        check(
          isPositiveExpr(IntegerNumber.of(3), assumptions: Assumptions.none),
        ).isTrue;
        check(isPositiveExpr(IntegerNumber.zero, assumptions: Assumptions.none))
            .isFalse;
        check(
          isPositiveExpr(IntegerNumber.of(-2), assumptions: Assumptions.none),
        ).isFalse;
        check(isPositiveExpr(x, assumptions: Assumptions.none)).isFalse;
        check(isPositiveExpr(x, assumptions: posAssumptions)).isTrue;
        check(
          isPositiveExpr(Pow.of(Constant.e, x), assumptions: realAssumptions),
        ).isTrue;

        check(
          isNonNegativeExpr(IntegerNumber.zero, assumptions: Assumptions.none),
        ).isTrue;
        check(
          isNonNegativeExpr(IntegerNumber.of(5), assumptions: Assumptions.none),
        ).isTrue;
        check(
          isNonNegativeExpr(
            IntegerNumber.of(-1),
            assumptions: Assumptions.none,
          ),
        ).isFalse;
        check(isNonNegativeExpr(Fn.abs(x), assumptions: Assumptions.none))
            .isTrue;
      });
    });

    group('isIntegerExpr and isEvenIntegerExpr', () {
      test('identifies integers', () {
        check(
          isIntegerExpr(IntegerNumber.of(42), assumptions: Assumptions.none),
        ).isTrue;
        check(isIntegerExpr(FractionNumber.half, assumptions: Assumptions.none))
            .isFalse;
        check(isIntegerExpr(x, assumptions: Assumptions.none)).isFalse;
        check(isIntegerExpr(x, assumptions: intAssumptions)).isTrue;

        check(
          isEvenIntegerExpr(IntegerNumber.of(4), assumptions: Assumptions.none),
        ).isTrue;
        check(
          isEvenIntegerExpr(IntegerNumber.of(5), assumptions: Assumptions.none),
        ).isFalse;
        check(
          isEvenIntegerExpr(
            Mul.of([IntegerNumber.two, x]),
            assumptions: intAssumptions,
          ),
        ).isTrue;
      });
    });

    group('tryStaticRealValue', () {
      test('extracts real values from numeric and constant expressions', () {
        check(tryStaticRealValue(IntegerNumber.of(7))).equals(7.0);
        check(tryStaticRealValue(const RealNumber(2.5))).equals(2.5);
        check(tryStaticRealValue(Constant.pi)).isNotNull();
        check(tryStaticRealValue(ComplexNumber.i)).isNull;
        check(tryStaticRealValue(x)).isNull;
      });
    });

    group('decomposeComplex', () {
      test('decomposes real and complex numbers', () {
        final realPart = decomposeComplex(
          IntegerNumber.of(3),
          Assumptions.none,
        );
        check(realPart.re).equals(IntegerNumber.of(3));
        check(realPart.im).equals(IntegerNumber.zero);

        final complexPart = decomposeComplex(
          ComplexNumber.of(IntegerNumber.two, IntegerNumber.of(5)),
          Assumptions.none,
        );
        check(complexPart.re).equals(IntegerNumber.two);
        check(complexPart.im).equals(IntegerNumber.of(5));
      });

      test('decomposes conjugate', () {
        final conj = decomposeComplex(
          Fn.conj(ComplexNumber.of(IntegerNumber.one, IntegerNumber.two)),
          Assumptions.none,
        );
        check(conj.re).equals(IntegerNumber.one);
        check(conj.im).equals(IntegerNumber.of(-2));
      });

      test('decomposes variables', () {
        final decomp = decomposeComplex(x, Assumptions.none);
        check(decomp.re)
            .isA<Call>()
            .has('id', (Call c) => c.id)
            .equals(FunctionId.re);
        check(decomp.im)
            .isA<Call>()
            .has('id', (Call c) => c.id)
            .equals(FunctionId.im);

        final realDecomp = decomposeComplex(x, realAssumptions);
        check(realDecomp.re).equals(x);
        check(realDecomp.im).equals(IntegerNumber.zero);
      });

      test('decomposes addition and multiplication', () {
        final sumDecomp = decomposeComplex(
          Add.of([
            ComplexNumber.of(IntegerNumber.one, IntegerNumber.two),
            ComplexNumber.of(IntegerNumber.of(3), IntegerNumber.of(4)),
          ]),
          Assumptions.none,
        );
        check(sumDecomp.re).equals(IntegerNumber.of(4));
        check(sumDecomp.im).equals(IntegerNumber.of(6));

        final prodDecomp = decomposeComplex(
          Mul.of([
            ComplexNumber.of(IntegerNumber.one, IntegerNumber.two),
            ComplexNumber.of(IntegerNumber.of(3), IntegerNumber.of(4)),
          ]),
          Assumptions.none,
        );
        // (1 + 2i)(3 + 4i) = (3 - 8) + (4 + 6)i = -5 + 10i
        check(prodDecomp.re).equals(IntegerNumber.of(-5));
        check(prodDecomp.im).equals(IntegerNumber.of(10));
      });

      test('sound domain predicates for Pow, Add, Cosh, and Elliptic', () {
        check(
          isNonNegativeExpr(
            Pow.of(IntegerNumber.two, ComplexNumber.i),
            assumptions: Assumptions.none,
          ),
        ).isFalse;
        check(
          isPositiveExpr(Expr.parse('x^2 + 1'), assumptions: Assumptions.real),
        ).isTrue;
        check(
          Expr.parse('abs(x^2 + 1)').simplify(assumptions: Assumptions.real),
        ).equals(Expr.parse('1 + x^2').simplify());
        check(
          Expr.parse('sqrt((x^2 + 1)^2)')
              .simplify(assumptions: Assumptions.real),
        ).equals(Expr.parse('1 + x^2').simplify());
        check(isProvenReal(Fn.ellipticK(x), Assumptions.real)).isFalse;
        check(isProvenReal(Fn.ellipticK(FractionNumber.half), Assumptions.real))
            .isTrue;
        check(isProvenReal(Fn.ellipticK(IntegerNumber.one), Assumptions.none))
            .isFalse;
        check(isProvenReal(Fn.ellipticE(IntegerNumber.one), Assumptions.none))
            .isTrue;
        check(isPositiveExpr(Fn.cosh(x), assumptions: Assumptions.real)).isTrue;
      });

      test(
        'sound domain predicates for Bessel, Gamma, Floor, and negative Mul',
        () {
          check(
            isIntegerExpr(
              Fn.floor(Constant.undefined),
              assumptions: Assumptions.none,
            ),
          ).isFalse;
          check(
            isIntegerExpr(
              Fn.floor(const Variable('x')),
              assumptions: Assumptions.real,
            ),
          ).isTrue;
          check(
            isProvenReal(
              Fn.besselK(IntegerNumber.zero, IntegerNumber.negativeOne),
              Assumptions.none,
            ),
          ).isFalse;
          check(
            isProvenReal(
              Fn.besselY(IntegerNumber.zero, IntegerNumber.negativeOne),
              Assumptions.none,
            ),
          ).isFalse;
          check(
            isProvenReal(
              Fn.upperGamma(IntegerNumber.one, IntegerNumber.negativeOne),
              Assumptions.none,
            ),
          ).isFalse;
          check(isProvenReal(Fn.gamma(IntegerNumber.zero), Assumptions.none))
              .isFalse;
          check(
            isPositiveExpr(
              Expr.parse('(-2) * (-x)'),
              assumptions: Assumptions.positive,
            ),
          ).isTrue;
          check(
            isNegativeExpr(
              Expr.parse('-2 * x'),
              assumptions: Assumptions.positive,
            ),
          ).isTrue;
          check(
            isNonNegativeExpr(
              Pow.of(IntegerNumber.zero, IntegerNumber.negativeOne),
              assumptions: Assumptions.none,
            ),
          ).isFalse;
          check(
            isNonNegativeExpr(
              Fn.abs(Constant.undefined),
              assumptions: Assumptions.none,
            ),
          ).isFalse;
        },
      );
    });
  });
}
