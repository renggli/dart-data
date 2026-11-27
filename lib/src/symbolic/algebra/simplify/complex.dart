import 'dart:math' as math;

import '../../assumptions.dart';
import '../../ast.dart';
import '../../functions/fn.dart';
import '../simplify.dart';
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
    case Call(
      id: FunctionId.re || FunctionId.im || FunctionId.arg || FunctionId.abs,
    ):
      return expr;
    case Call(id: FunctionId.conj, args: [final inner]):
      return simplifyRe(inner, assumptions: assumptions);
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
    case RealNumeric() ||
        Call(
          id: FunctionId.re ||
              FunctionId.im ||
              FunctionId.arg ||
              FunctionId.abs,
        ):
      return IntegerNumber.zero;
    case ComplexNumber(:final real, :final imaginary):
      return real is RealNumber && imaginary is! RealNumber
          ? RealNumber.fromDouble(imaginary.toDouble())
          : imaginary;
    case Call(id: FunctionId.conj, args: [final inner]):
      return simplifyNeg(
        simplifyIm(inner, assumptions: assumptions),
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
        return Mul.of([coeff, Constant.pi]);
      }
      if (real == imaginary) {
        final coeff = real.isNegative
            ? RationalNumber(-3, 4)
            : RationalNumber(1, 4);
        return Mul.of([coeff, Constant.pi]);
      }
      if (real == imaginary.neg()) {
        final coeff = real.isNegative
            ? RationalNumber(3, 4)
            : RationalNumber(-1, 4);
        return Mul.of([coeff, Constant.pi]);
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
    case Call(id: FunctionId.conj, args: [final inner])
        when isPositiveExpr(inner, assumptions: assumptions) ||
            (inner is ComplexNumber && !inner.imaginary.isZero):
      return simplifyNeg(
        simplifyArg(inner, assumptions: assumptions),
        assumptions: assumptions,
      );
    case _:
      if (isNonNegativeExpr(expr, assumptions: assumptions)) {
        return IntegerNumber.zero;
      }
      return Fn.arg(expr);
  }
}

/// Simplifies a complex conjugate expression `conj(z)`.
Expr simplifyConjugate(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  switch (expr) {
    case RealNumeric() ||
        OrderTerm() ||
        Call(
          id: FunctionId.re ||
              FunctionId.im ||
              FunctionId.arg ||
              FunctionId.abs,
        ):
      return expr;
    case ComplexNumber():
      return expr.conjugate;
    case Call(id: FunctionId.conj, args: [final inner]):
      return inner;
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
    case Pow(base: Constant(name: 'e'), :final exponent):
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
    case Call(id: FunctionId.sin, args: [final inner]):
      return simplifySin(
        simplifyConjugate(inner, assumptions: assumptions),
        assumptions: assumptions,
      );
    case Call(id: FunctionId.cos, args: [final inner]):
      return simplifyCos(
        simplifyConjugate(inner, assumptions: assumptions),
        assumptions: assumptions,
      );
    case Call(id: FunctionId.tan, args: [final inner]):
      return simplifyTan(
        simplifyConjugate(inner, assumptions: assumptions),
        assumptions: assumptions,
      );
    case Call(id: FunctionId.sinh, args: [final inner]):
      return simplifySinh(
        simplifyConjugate(inner, assumptions: assumptions),
        assumptions: assumptions,
      );
    case Call(id: FunctionId.cosh, args: [final inner]):
      return simplifyCosh(
        simplifyConjugate(inner, assumptions: assumptions),
        assumptions: assumptions,
      );
    case Call(id: FunctionId.tanh, args: [final inner]):
      return simplifyTanh(
        simplifyConjugate(inner, assumptions: assumptions),
        assumptions: assumptions,
      );
    case Call(id: FunctionId.erf, args: [final inner]):
      return simplifyErf(
        simplifyConjugate(inner, assumptions: assumptions),
        assumptions: assumptions,
      );
    case Call(id: FunctionId.erfc, args: [final inner]):
      return simplifyErfc(
        simplifyConjugate(inner, assumptions: assumptions),
        assumptions: assumptions,
      );
    case Call(id: FunctionId.erfi, args: [final inner]):
      return simplifyErfi(
        simplifyConjugate(inner, assumptions: assumptions),
        assumptions: assumptions,
      );
    case Call(id: FunctionId.fresnelS, args: [final inner]):
      return simplifyFresnelS(
        simplifyConjugate(inner, assumptions: assumptions),
        assumptions: assumptions,
      );
    case Call(id: FunctionId.fresnelC, args: [final inner]):
      return simplifyFresnelC(
        simplifyConjugate(inner, assumptions: assumptions),
        assumptions: assumptions,
      );
    case Call(id: FunctionId.si, args: [final inner]):
      return simplifySinIntegralSi(
        simplifyConjugate(inner, assumptions: assumptions),
        assumptions: assumptions,
      );
    case Call(id: FunctionId.shi, args: [final inner]):
      return simplifySinhIntegralShi(
        simplifyConjugate(inner, assumptions: assumptions),
        assumptions: assumptions,
      );
    case Call(id: FunctionId.atan, args: [final inner])
        when isProvenReal(inner, assumptions) ||
            (inner is ComplexNumber &&
                (!inner.real.isZero || inner.imaginary.toDouble().abs() < 1.0)):
      return simplifyAtan(
        simplifyConjugate(inner, assumptions: assumptions),
        assumptions: assumptions,
      );
    case Call(id: FunctionId.asinh, args: [final inner])
        when isProvenReal(inner, assumptions) ||
            (inner is ComplexNumber &&
                (!inner.real.isZero || inner.imaginary.toDouble().abs() < 1.0)):
      return simplifyAsinh(
        simplifyConjugate(inner, assumptions: assumptions),
        assumptions: assumptions,
      );
    case _:
      if (isProvenReal(expr, assumptions)) {
        return expr;
      }
      return Fn.conj(expr);
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
  if (r is Call && r.id == FunctionId.abs && !(im is Number && im.isZero)) {
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
  final expPart = Pow.of(
    Constant.e,
    simplifyMul([ComplexNumber.i, theta], assumptions: assumptions),
  );
  if (r is Number && r.isOne) {
    return r is RealNumber ? Mul.of([r, expPart]) : expPart;
  }
  final factors = <Expr>[
    if (r case Mul(factors: final rf)) ...rf else r,
    expPart,
  ]..sort(compareStructural);
  return Mul.of(factors);
}
