import '../../assumptions.dart';
import '../../ast.dart';
import '../../functions/fn.dart';
import '../../oracle/domain_oracle.dart';
import 'additive.dart';
import 'complex.dart';
import 'multiplicative.dart';
import 'power.dart';
import 'transcendental.dart';

/// Returns `true` if [expr] is known to be real-valued under [assumptions].
bool isProvenReal(Expr expr, Assumptions assumptions) => switch (expr) {
  RealNumeric() => true,
  ComplexNumber(:final imaginary) => imaginary.isZero,
  Constant(:final isReal) => isReal,
  Variable(:final name) => assumptions.isReal(name),
  _ => DomainOracle(assumptions).isReal(expr),
};

/// Returns `true` if [expr] is known to be strictly negative under [assumptions].
bool isNegativeExpr(Expr expr, {required Assumptions assumptions}) =>
    switch (expr) {
      RealNumeric(:final isNegative) => isNegative,
      ComplexNumber(:final real, :final imaginary) =>
        imaginary.isZero && real.isNegative,
      Constant(:final isReal, :final value) =>
        isReal && value.b == 0.0 && value.a < 0.0,
      _ => DomainOracle(assumptions).isNegative(expr),
    };

/// Returns `true` if [expr] is known to be strictly positive under [assumptions].
bool isPositiveExpr(Expr expr, {required Assumptions assumptions}) =>
    switch (expr) {
      RealNumeric(:final isNegative, :final isZero) => !isNegative && !isZero,
      ComplexNumber(:final real, :final imaginary) =>
        imaginary.isZero && !real.isNegative && !real.isZero,
      Constant(:final isReal, :final value) =>
        isReal && value.b == 0.0 && value.a > 0.0,
      _ => DomainOracle(assumptions).isPositive(expr),
    };

/// Returns `true` if [expr] is syntactically non-negative under [assumptions].
bool isNonNegativeExpr(Expr expr, {required Assumptions assumptions}) =>
    switch (expr) {
      RealNumeric(:final isNegative) => !isNegative,
      ComplexNumber(:final real, :final imaginary) =>
        imaginary.isZero && !real.isNegative,
      Constant(:final isReal, :final value) =>
        isReal && value.b == 0.0 && value.a >= 0.0,
      _ => DomainOracle(assumptions).isNonNegative(expr),
    };

/// Returns `true` if [expr] is syntactically non-positive under [assumptions].
bool isNonPositiveExpr(Expr expr, {required Assumptions assumptions}) =>
    switch (expr) {
      RealNumeric(:final isNegative, :final isZero) => isNegative || isZero,
      ComplexNumber(:final real, :final imaginary) =>
        imaginary.isZero && (real.isNegative || real.isZero),
      Constant(:final isReal, :final value) =>
        isReal && value.b == 0.0 && value.a <= 0.0,
      _ => DomainOracle(assumptions).isNonPositive(expr),
    };

/// Returns `true` if [expr] is syntactically integer-valued under [assumptions].
bool isIntegerExpr(Expr expr, {required Assumptions assumptions}) =>
    switch (expr) {
      IntegerNumber() => true,
      FractionNumber() ||
      RealNumber() ||
      ComplexNumber() ||
      Constant() => false,
      Variable(:final name) => assumptions.isInteger(name),
      _ => DomainOracle(assumptions).isInteger(expr),
    };

/// Returns `true` if [expr] is an even integer expression under [assumptions].
bool isEvenIntegerExpr(Expr expr, {required Assumptions assumptions}) =>
    switch (expr) {
      IntegerNumber(:final value) => value.isEven,
      FractionNumber() ||
      RealNumber() ||
      ComplexNumber() ||
      Constant() => false,
      Variable(:final name) => assumptions.isEven(name),
      _ => DomainOracle(assumptions).isEvenInteger(expr),
    };

/// Evaluates [expr] to a floating-point real number if it is constant and real,
/// or returns `null`.
double? tryStaticRealValue(Expr expr) =>
    DomainOracle(Assumptions.none).tryStaticRealValue(expr);

/// Decomposes an expression into its Cartesian real and imaginary components
/// `(u, v)` such that `expr = u + i v`.
({Expr re, Expr im}) decomposeComplex(Expr expr, Assumptions assumptions) {
  if (isProvenReal(expr, assumptions)) {
    return (re: expr, im: IntegerNumber.zero);
  }
  switch (expr) {
    case ComplexNumber(:final real, :final imaginary):
      return (re: real, im: imaginary);
    case Variable():
      return (re: Fn.re(expr), im: Fn.im(expr));
    case Call(id: FunctionId.conj, args: [final inner]):
      final (:re, :im) = decomposeComplex(inner, assumptions);
      return (re: re, im: simplifyNeg(im, assumptions: assumptions));
    case Add(:final terms):
      final reTerms = <Expr>[];
      final imTerms = <Expr>[];
      for (final term in terms) {
        final (:re, :im) = decomposeComplex(term, assumptions);
        reTerms.add(re);
        imTerms.add(im);
      }
      return (
        re: simplifyAdd(reTerms, assumptions: assumptions),
        im: simplifyAdd(imTerms, assumptions: assumptions),
      );
    case Mul(:final factors):
      var accRe = IntegerNumber.one as Expr;
      var accIm = IntegerNumber.zero as Expr;
      for (final factor in factors) {
        final (:re, :im) = decomposeComplex(factor, assumptions);
        final nextRe = simplifyAdd([
          simplifyMul([accRe, re], assumptions: assumptions),
          simplifyNeg(
            simplifyMul([accIm, im], assumptions: assumptions),
            assumptions: assumptions,
          ),
        ], assumptions: assumptions);
        final nextIm = simplifyAdd([
          simplifyMul([accRe, im], assumptions: assumptions),
          simplifyMul([accIm, re], assumptions: assumptions),
        ], assumptions: assumptions);
        accRe = nextRe;
        accIm = nextIm;
      }
      return (re: accRe, im: accIm);
    case Pow(base: Constant.e, :final exponent):
      final (:re, :im) = decomposeComplex(exponent, assumptions);
      final mag = simplifyPow(Constant.e, re, assumptions: assumptions);
      return (
        re: simplifyMul([
          mag,
          simplifyCos(im, assumptions: assumptions),
        ], assumptions: assumptions),
        im: simplifyMul([
          mag,
          simplifySin(im, assumptions: assumptions),
        ], assumptions: assumptions),
      );
    case Pow(:final base, exponent: IntegerNumber(asInt: final n?))
        when n >= -6 && n <= 6:
      final (:re, :im) = decomposeComplex(base, assumptions);
      if (n == 0) return (re: IntegerNumber.one, im: IntegerNumber.zero);
      final absN = n.abs();
      var powRe = re;
      var powIm = im;
      for (var i = 1; i < absN; i++) {
        final nextRe = simplifyAdd([
          simplifyMul([powRe, re], assumptions: assumptions),
          simplifyNeg(
            simplifyMul([powIm, im], assumptions: assumptions),
            assumptions: assumptions,
          ),
        ], assumptions: assumptions);
        final nextIm = simplifyAdd([
          simplifyMul([powRe, im], assumptions: assumptions),
          simplifyMul([powIm, re], assumptions: assumptions),
        ], assumptions: assumptions);
        powRe = nextRe;
        powIm = nextIm;
      }
      if (n < 0) {
        final denom = simplifyAdd([
          simplifyPow(powRe, IntegerNumber.two, assumptions: assumptions),
          simplifyPow(powIm, IntegerNumber.two, assumptions: assumptions),
        ], assumptions: assumptions);
        final invDenom = simplifyPow(
          denom,
          IntegerNumber.negativeOne,
          assumptions: assumptions,
        );
        return (
          re: simplifyMul([powRe, invDenom], assumptions: assumptions),
          im: simplifyNeg(
            simplifyMul([powIm, invDenom], assumptions: assumptions),
            assumptions: assumptions,
          ),
        );
      }
      return (re: powRe, im: powIm);
    case Call(id: FunctionId.sin, args: [final inner]):
      final (:re, :im) = decomposeComplex(inner, assumptions);
      return (
        re: simplifyMul([
          simplifySin(re, assumptions: assumptions),
          simplifyCosh(im, assumptions: assumptions),
        ], assumptions: assumptions),
        im: simplifyMul([
          simplifyCos(re, assumptions: assumptions),
          simplifySinh(im, assumptions: assumptions),
        ], assumptions: assumptions),
      );
    case Call(id: FunctionId.cos, args: [final inner]):
      final (:re, :im) = decomposeComplex(inner, assumptions);
      return (
        re: simplifyMul([
          simplifyCos(re, assumptions: assumptions),
          simplifyCosh(im, assumptions: assumptions),
        ], assumptions: assumptions),
        im: simplifyNeg(
          simplifyMul([
            simplifySin(re, assumptions: assumptions),
            simplifySinh(im, assumptions: assumptions),
          ], assumptions: assumptions),
          assumptions: assumptions,
        ),
      );
    case Call(id: FunctionId.sinh, args: [final inner]):
      final (:re, :im) = decomposeComplex(inner, assumptions);
      return (
        re: simplifyMul([
          simplifySinh(re, assumptions: assumptions),
          simplifyCos(im, assumptions: assumptions),
        ], assumptions: assumptions),
        im: simplifyMul([
          simplifyCosh(re, assumptions: assumptions),
          simplifySin(im, assumptions: assumptions),
        ], assumptions: assumptions),
      );
    case Call(id: FunctionId.cosh, args: [final inner]):
      final (:re, :im) = decomposeComplex(inner, assumptions);
      return (
        re: simplifyMul([
          simplifyCosh(re, assumptions: assumptions),
          simplifyCos(im, assumptions: assumptions),
        ], assumptions: assumptions),
        im: simplifyMul([
          simplifySinh(re, assumptions: assumptions),
          simplifySin(im, assumptions: assumptions),
        ], assumptions: assumptions),
      );
    case Call(id: FunctionId.ln, args: [final inner]):
      return (
        re: simplifyLn(
          simplifyAbs(inner, assumptions: assumptions),
          assumptions: assumptions,
        ),
        im: simplifyArg(inner, assumptions: assumptions),
      );
    default:
      return (re: Fn.re(expr), im: Fn.im(expr));
  }
}
