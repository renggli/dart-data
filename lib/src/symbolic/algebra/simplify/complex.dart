import 'dart:math' as math;

import '../../assumptions.dart';
import '../../ast.dart';
import '../simplify.dart';
import '../structural_order.dart';
import 'additive.dart';
import 'domain.dart';
import 'multiplicative.dart';
import 'power.dart';
import 'special.dart';
import 'special_integrals.dart';
import 'transcendental.dart';

/// Simplifies a real-part expression `re(z)`.
Expr simplifyRe(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  switch (expr) {
    case RealNumeric():
      return expr;
    case ComplexNumber(:final real, :final imaginary):
      return imaginary is RealNumber && real is! RealNumber
          ? RealNumber.fromDouble(real.toDouble())
          : real;
    case Re() || Im() || Arg() || Abs():
      return expr;
    case Conjugate(:final expr):
      return simplifyRe(expr, assumptions: assumptions);
    case Add(:final terms):
      return simplifyAdd([
        for (final term in terms) simplifyRe(term, assumptions: assumptions),
      ], assumptions: assumptions);
    case _:
      if (isProvenReal(expr, assumptions)) {
        return expr;
      }
      final (:re, im: _) = decomposeComplex(expr, assumptions);
      return re;
  }
}

/// Simplifies an imaginary-part expression `im(z)`.
Expr simplifyIm(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  switch (expr) {
    case RealNumber():
      return const RealNumber(0.0);
    case RealNumeric() || Re() || Im() || Arg() || Abs():
      return IntegerNumber.zero;
    case ComplexNumber(:final real, :final imaginary):
      return real is RealNumber && imaginary is! RealNumber
          ? RealNumber.fromDouble(imaginary.toDouble())
          : imaginary;
    case Conjugate(:final expr):
      return simplifyNeg(
        simplifyIm(expr, assumptions: assumptions),
        assumptions: assumptions,
      );
    case Add(:final terms):
      return simplifyAdd([
        for (final term in terms) simplifyIm(term, assumptions: assumptions),
      ], assumptions: assumptions);
    case _:
      if (isProvenReal(expr, assumptions)) {
        return IntegerNumber.zero;
      }
      final (re: _, :im) = decomposeComplex(expr, assumptions);
      return im;
  }
}

/// Simplifies a complex argument expression `arg(z)`.
Expr simplifyArg(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  switch (expr) {
    case RealNumber(:final value):
      return RealNumber.fromDouble(math.atan2(0.0, value));
    case RealNumeric(:final isNegative):
      return isNegative ? Constant.pi : IntegerNumber.zero;
    case ComplexNumber(:final real, :final imaginary)
        when real is RealNumber || imaginary is RealNumber:
      return RealNumber.fromDouble(
        math.atan2(imaginary.toDouble(), real.toDouble()),
      );
    case ComplexNumber(:final real, :final imaginary):
      if (real.isZero) {
        final coeff = imaginary.isNegative
            ? FractionNumber.negativeHalf
            : FractionNumber.half;
        return Mul([coeff, Constant.pi], isSimplified: true);
      }
      if (real == imaginary) {
        final coeff = real.isNegative
            ? RationalNumber(-3, 4)
            : RationalNumber(1, 4);
        return Mul([coeff, Constant.pi], isSimplified: true);
      }
      if (real == imaginary.neg()) {
        final coeff = real.isNegative
            ? RationalNumber(3, 4)
            : RationalNumber(-1, 4);
        return Mul([coeff, Constant.pi], isSimplified: true);
      }
      final atanTerm = simplifyAtan(
        simplifyMul([
          imaginary,
          simplifyPow(
            real,
            IntegerNumber.negativeOne,
            assumptions: assumptions,
          ),
        ], assumptions: assumptions),
        assumptions: assumptions,
      );
      if (!real.isNegative) {
        return atanTerm;
      }
      final piTerm = imaginary.isNegative ? -Constant.pi : Constant.pi;
      return simplifyAdd([atanTerm, piTerm], assumptions: assumptions);
    case Conjugate(:final expr)
        when isPositiveExpr(expr, assumptions: assumptions) ||
            (expr is ComplexNumber && !expr.imaginary.isZero):
      return simplifyNeg(
        simplifyArg(expr, assumptions: assumptions),
        assumptions: assumptions,
      );
    case _:
      if (isNonNegativeExpr(expr, assumptions: assumptions)) {
        return IntegerNumber.zero;
      }
      return Arg(expr, isSimplified: true);
  }
}

/// Simplifies a complex conjugate expression `conj(z)`.
Expr simplifyConjugate(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  switch (expr) {
    case RealNumeric() || Re() || Im() || Arg() || Abs() || OrderTerm():
      return expr;
    case ComplexNumber():
      return expr.conjugate;
    case Conjugate(:final expr):
      return expr;
    case Add(:final terms):
      return simplifyAdd([
        for (final term in terms)
          simplifyConjugate(term, assumptions: assumptions),
      ], assumptions: assumptions);
    case Mul(:final factors):
      return simplifyMul([
        for (final factor in factors)
          simplifyConjugate(factor, assumptions: assumptions),
      ], assumptions: assumptions);
    case Pow(base: Constant.e, :final exponent):
      return simplifyPow(
        Constant.e,
        simplifyConjugate(exponent, assumptions: assumptions),
        assumptions: assumptions,
      );
    case Pow(:final base, :final exponent)
        when isPositiveExpr(base, assumptions: assumptions):
      return simplifyPow(
        base,
        simplifyConjugate(exponent, assumptions: assumptions),
        assumptions: assumptions,
      );
    case Pow(:final base, :final exponent) when exponent is IntegerNumber:
      return simplifyPow(
        simplifyConjugate(base, assumptions: assumptions),
        exponent,
        assumptions: assumptions,
      );
    case Sin(:final expr):
      return simplifySin(
        simplifyConjugate(expr, assumptions: assumptions),
        assumptions: assumptions,
      );
    case Cos(:final expr):
      return simplifyCos(
        simplifyConjugate(expr, assumptions: assumptions),
        assumptions: assumptions,
      );
    case Tan(:final expr):
      return simplifyTan(
        simplifyConjugate(expr, assumptions: assumptions),
        assumptions: assumptions,
      );
    case Sinh(:final expr):
      return simplifySinh(
        simplifyConjugate(expr, assumptions: assumptions),
        assumptions: assumptions,
      );
    case Cosh(:final expr):
      return simplifyCosh(
        simplifyConjugate(expr, assumptions: assumptions),
        assumptions: assumptions,
      );
    case Tanh(:final expr):
      return simplifyTanh(
        simplifyConjugate(expr, assumptions: assumptions),
        assumptions: assumptions,
      );
    case Erf(:final expr):
      return simplifyErf(
        simplifyConjugate(expr, assumptions: assumptions),
        assumptions: assumptions,
      );
    case Erfc(:final expr):
      return simplifyErfc(
        simplifyConjugate(expr, assumptions: assumptions),
        assumptions: assumptions,
      );
    case Erfi(:final expr):
      return simplifyErfi(
        simplifyConjugate(expr, assumptions: assumptions),
        assumptions: assumptions,
      );
    case FresnelS(:final expr):
      return simplifyFresnelS(
        simplifyConjugate(expr, assumptions: assumptions),
        assumptions: assumptions,
      );
    case FresnelC(:final expr):
      return simplifyFresnelC(
        simplifyConjugate(expr, assumptions: assumptions),
        assumptions: assumptions,
      );
    case SinIntegral(:final expr):
      return simplifySinIntegralSi(
        simplifyConjugate(expr, assumptions: assumptions),
        assumptions: assumptions,
      );
    case SinhIntegral(:final expr):
      return simplifySinhIntegralShi(
        simplifyConjugate(expr, assumptions: assumptions),
        assumptions: assumptions,
      );
    case Atan(:final expr)
        when isProvenReal(expr, assumptions) ||
            (expr is ComplexNumber &&
                (!expr.real.isZero || expr.imaginary.toDouble().abs() < 1.0)):
      return simplifyAtan(
        simplifyConjugate(expr, assumptions: assumptions),
        assumptions: assumptions,
      );
    case Asinh(:final expr)
        when isProvenReal(expr, assumptions) ||
            (expr is ComplexNumber &&
                (!expr.real.isZero || expr.imaginary.toDouble().abs() < 1.0)):
      return simplifyAsinh(
        simplifyConjugate(expr, assumptions: assumptions),
        assumptions: assumptions,
      );
    case _:
      if (isProvenReal(expr, assumptions)) {
        return expr;
      }
      return Conjugate(expr, isSimplified: true);
  }
}

/// Rewrites [expr] into rectangular normal form `a + b * i`.
Expr toRectangularExpr(Expr expr, {required Assumptions assumptions}) {
  final simplified = simplifyExpr(expr, assumptions: assumptions);
  final (:re, :im) = decomposeComplex(simplified, assumptions);
  if (im is Number && im.isZero) {
    return re;
  }
  if (re is RealNumeric && im is RealNumeric) {
    return ComplexNumber.of(re, im);
  }
  final imTerm = simplifyMul([ComplexNumber.i, im], assumptions: assumptions);
  if (re is Number && re.isZero) {
    return imTerm;
  }
  return simplifyAdd([re, imTerm], assumptions: assumptions);
}

/// Rewrites [expr] into polar normal form `r * e^(i * θ)`.
Expr toPolarExpr(Expr expr, {required Assumptions assumptions}) {
  final simplified = simplifyExpr(expr, assumptions: assumptions);
  if (simplified is Number && simplified.isZero) {
    return simplified is RealNumber
        ? const RealNumber(0.0)
        : IntegerNumber.zero;
  }
  final (:re, :im) = decomposeComplex(simplified, assumptions);
  var r = simplifyAbs(simplified, assumptions: assumptions);
  if (r is Abs && !(im is Number && im.isZero)) {
    r = simplifyPow(
      simplifyAdd([
        simplifyPow(re, IntegerNumber.two, assumptions: assumptions),
        simplifyPow(im, IntegerNumber.two, assumptions: assumptions),
      ], assumptions: assumptions),
      FractionNumber.half,
      assumptions: assumptions,
    );
  }
  final theta = simplifyArg(simplified, assumptions: assumptions);
  if (theta is Number && theta.isZero) {
    return r;
  }
  final expPart = Pow(
    Constant.e,
    simplifyMul([ComplexNumber.i, theta], assumptions: assumptions),
    isSimplified: true,
  );
  if (r is Number && r.isOne) {
    return r is RealNumber ? Mul([r, expPart], isSimplified: true) : expPart;
  }
  final factors = <Expr>[
    if (r case Mul(factors: final rf)) ...rf else r,
    expPart,
  ]..sort(compareStructural);
  return Mul(factors, isSimplified: true);
}
