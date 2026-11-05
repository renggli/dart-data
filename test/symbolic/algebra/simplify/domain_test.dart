import 'package:checks/checks.dart';
import 'package:data/src/symbolic/algebra/simplify/domain.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Domain and complex decomposition helpers', () {
    const x = Variable('x');
    const realAssumptions = Assumptions(domains: {'x': VariableDomain.real});
    const posAssumptions = Assumptions(domains: {'x': VariableDomain.positive});
    const intAssumptions = Assumptions(domains: {'x': VariableDomain.integer});

    group('isProvenReal', () {
      test('identifies real numbers and constants', () {
        check(isProvenReal(IntegerNumber.of(5))).isTrue();
        check(isProvenReal(FractionNumber.half)).isTrue();
        check(isProvenReal(const RealNumber(3.14))).isTrue();
        check(isProvenReal(Constant.pi)).isTrue();
        check(isProvenReal(Constant.e)).isTrue();
        check(isProvenReal(ComplexNumber.i)).isFalse();
      });

      test('respects variable assumptions', () {
        check(isProvenReal(x)).isFalse();
        check(isProvenReal(x, realAssumptions)).isTrue();
        check(isProvenReal(x, posAssumptions)).isTrue();
        check(isProvenReal(x, intAssumptions)).isTrue();
        check(
          isProvenReal(
            x,
            const Assumptions(domains: {'x': VariableDomain.complex}),
          ),
        ).isFalse();
      });

      test('checks composite expressions', () {
        check(isProvenReal(Add([IntegerNumber.one, Constant.pi]))).isTrue();
        check(isProvenReal(Add([IntegerNumber.one, ComplexNumber.i])))
            .isFalse();
        check(isProvenReal(Sin(x), realAssumptions)).isTrue();
        check(isProvenReal(Cos(x), realAssumptions)).isTrue();
        check(isProvenReal(Pow(x, IntegerNumber.two), realAssumptions))
            .isTrue();
        check(isProvenReal(Abs(x))).isTrue();
        check(isProvenReal(Re(x))).isTrue();
        check(isProvenReal(Im(x))).isTrue();
        check(isProvenReal(Arg(x))).isTrue();
      });
    });

    group('isPositiveExpr and isNonNegativeExpr', () {
      test('detects positive numbers and expressions', () {
        check(isPositiveExpr(IntegerNumber.of(3))).isTrue();
        check(isPositiveExpr(IntegerNumber.zero)).isFalse();
        check(isPositiveExpr(IntegerNumber.of(-2))).isFalse();
        check(isPositiveExpr(x)).isFalse();
        check(isPositiveExpr(x, assumptions: posAssumptions)).isTrue();
        check(isPositiveExpr(Pow(Constant.e, x), assumptions: realAssumptions))
            .isTrue();

        check(isNonNegativeExpr(IntegerNumber.zero)).isTrue();
        check(isNonNegativeExpr(IntegerNumber.of(5))).isTrue();
        check(isNonNegativeExpr(IntegerNumber.of(-1))).isFalse();
        check(isNonNegativeExpr(Abs(x))).isTrue();
      });
    });

    group('isIntegerExpr and isEvenIntegerExpr', () {
      test('identifies integers', () {
        check(isIntegerExpr(IntegerNumber.of(42))).isTrue();
        check(isIntegerExpr(FractionNumber.half)).isFalse();
        check(isIntegerExpr(x)).isFalse();
        check(isIntegerExpr(x, assumptions: intAssumptions)).isTrue();

        check(isEvenIntegerExpr(IntegerNumber.of(4))).isTrue();
        check(isEvenIntegerExpr(IntegerNumber.of(5))).isFalse();
        check(
          isEvenIntegerExpr(
            Mul([IntegerNumber.two, x]),
            assumptions: intAssumptions,
          ),
        ).isTrue();
      });
    });

    group('tryStaticRealValue', () {
      test('extracts real values from numeric and constant expressions', () {
        check(tryStaticRealValue(IntegerNumber.of(7))).equals(7.0);
        check(tryStaticRealValue(const RealNumber(2.5))).equals(2.5);
        check(tryStaticRealValue(Constant.pi)).isNotNull();
        check(tryStaticRealValue(ComplexNumber.i)).isNull();
        check(tryStaticRealValue(x)).isNull();
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
          Conjugate(ComplexNumber.of(IntegerNumber.one, IntegerNumber.two)),
          Assumptions.none,
        );
        check(conj.re).equals(IntegerNumber.one);
        check(conj.im).equals(IntegerNumber.of(-2));
      });

      test('decomposes variables', () {
        final decomp = decomposeComplex(x, Assumptions.none);
        check(decomp.re).isA<Re>();
        check(decomp.im).isA<Im>();

        final realDecomp = decomposeComplex(x, realAssumptions);
        check(realDecomp.re).equals(x);
        check(realDecomp.im).equals(IntegerNumber.zero);
      });

      test('decomposes addition and multiplication', () {
        final sumDecomp = decomposeComplex(
          Add([
            ComplexNumber.of(IntegerNumber.one, IntegerNumber.two),
            ComplexNumber.of(IntegerNumber.of(3), IntegerNumber.of(4)),
          ]),
          Assumptions.none,
        );
        check(sumDecomp.re).equals(IntegerNumber.of(4));
        check(sumDecomp.im).equals(IntegerNumber.of(6));

        final prodDecomp = decomposeComplex(
          Mul([
            ComplexNumber.of(IntegerNumber.one, IntegerNumber.two),
            ComplexNumber.of(IntegerNumber.of(3), IntegerNumber.of(4)),
          ]),
          Assumptions.none,
        );
        // (1 + 2i)(3 + 4i) = (3 - 8) + (4 + 6)i = -5 + 10i
        check(prodDecomp.re).equals(IntegerNumber.of(-5));
        check(prodDecomp.im).equals(IntegerNumber.of(10));
      });
    });
  });
}
