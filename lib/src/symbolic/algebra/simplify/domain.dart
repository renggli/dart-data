import 'dart:math' as math;

import '../../assumptions.dart';
import '../../ast.dart';
import '../../compiler.dart';
import '../../number/integer.dart';
import 'additive.dart';
import 'complex.dart';
import 'multiplicative.dart';
import 'power.dart';
import 'transcendental.dart';

/// Returns `true` if [expr] is known to be real-valued under [assumptions].
bool isProvenReal(Expr expr, Assumptions assumptions) => switch (expr) {
  RealNumeric() || Abs() || Re() || Im() || Arg() => true,
  Floor(:final expr) ||
  Ceil(:final expr) ||
  Round(:final expr) ||
  Sign(:final expr) ||
  Factorial(:final expr) => isProvenReal(expr, assumptions),
  Binomial(:final left, :final right) =>
    isProvenReal(left, assumptions) && isProvenReal(right, assumptions),
  LambertW(:final expr, :final branch) => switch (branch) {
    0 =>
      isProvenReal(expr, assumptions) &&
          (isNonNegativeExpr(expr, assumptions: assumptions) ||
              switch (tryStaticRealValue(expr)) {
                final v? => v >= -1.0 / math.e - 1e-12,
                _ => false,
              }),
    -1 =>
      isProvenReal(expr, assumptions) &&
          switch (tryStaticRealValue(expr)) {
            final v? => v >= -1.0 / math.e - 1e-12 && v < 0.0,
            _ => false,
          },
    _ => false,
  },
  ComplexNumber(:final imaginary) => imaginary.isZero,
  Constant(:final isReal) => isReal,
  Variable(:final name) => switch (assumptions.domainOf(name)) {
    VariableDomain.real ||
    VariableDomain.positive ||
    VariableDomain.integer => true,
    _ => false,
  },
  Add(:final terms) => terms.every((t) => isProvenReal(t, assumptions)),
  Mul(:final factors) => factors.every((f) => isProvenReal(f, assumptions)),
  Pow(base: Constant.e, :final exponent) => isProvenReal(exponent, assumptions),
  Pow(:final base, :final exponent) =>
    (isProvenReal(base, assumptions) &&
            exponent is IntegerNumber &&
            (!exponent.isNegative ||
                isPositiveExpr(base, assumptions: assumptions) ||
                isNegativeExpr(base, assumptions: assumptions))) ||
        (isPositiveExpr(base, assumptions: assumptions) &&
            isProvenReal(exponent, assumptions)) ||
        (isNonNegativeExpr(base, assumptions: assumptions) &&
            isPositiveExpr(exponent, assumptions: assumptions)),
  Sin(:final expr) ||
  Cos(:final expr) ||
  Tan(:final expr) ||
  Atan(:final expr) ||
  Sinh(:final expr) ||
  Cosh(:final expr) ||
  Tanh(:final expr) ||
  Asinh(:final expr) ||
  Erf(:final expr) ||
  Erfc(:final expr) ||
  Erfi(:final expr) ||
  FresnelS(:final expr) ||
  FresnelC(:final expr) ||
  ExpIntegralEi(:final expr) ||
  SinIntegralSi(:final expr) ||
  SinhIntegralShi(:final expr) => isProvenReal(expr, assumptions),
  Zeta(:final expr, :final shift) =>
    isProvenReal(expr, assumptions) &&
        (shift == null || isProvenReal(shift, assumptions)),
  ExpIntegralE(:final left, :final right) =>
    isProvenReal(left, assumptions) && isProvenReal(right, assumptions),
  Hypergeometric(:final upper, :final lower, :final argument) =>
    upper.every((e) => isProvenReal(e, assumptions)) &&
        lower.every((e) => isProvenReal(e, assumptions)) &&
        isProvenReal(argument, assumptions),
  Min(:final args) ||
  Max(:final args) => args.every((e) => isProvenReal(e, assumptions)),
  Gamma(:final expr) || Digamma(:final expr) =>
    isProvenReal(expr, assumptions) &&
        (isPositiveExpr(expr, assumptions: assumptions) ||
            switch (tryStaticRealValue(expr)) {
              final v? => v > 0.0 || (v != v.floorToDouble()),
              _ => false,
            }),
  LogIntegralLi(:final expr) ||
  CosIntegralCi(:final expr) ||
  CoshIntegralChi(:final expr) =>
    isProvenReal(expr, assumptions) &&
        switch (tryStaticRealValue(expr)) {
          final v? => v > 0.0,
          _ => false,
        },
  EllipticK(:final expr) =>
    isProvenReal(expr, assumptions) &&
        switch (tryStaticRealValue(expr)) {
          final v? => v.abs() < 1.0,
          _ => false,
        },
  EllipticE(:final expr) =>
    isProvenReal(expr, assumptions) &&
        switch (tryStaticRealValue(expr)) {
          final v? => v.abs() <= 1.0,
          _ => false,
        },
  Polygamma(:final left, :final right) ||
  EllipticF(:final left, :final right) ||
  EllipticEIncomplete(:final left, :final right) ||
  Atan2(
    :final left,
    :final right,
  ) => isProvenReal(left, assumptions) && isProvenReal(right, assumptions),
  EllipticPi(:final characteristic, :final amplitude, :final modulus) =>
    isProvenReal(characteristic, assumptions) &&
        isProvenReal(amplitude, assumptions) &&
        isProvenReal(modulus, assumptions),
  BesselJ(:final left, :final right) || BesselI(:final left, :final right) =>
    isProvenReal(left, assumptions) &&
        isProvenReal(right, assumptions) &&
        (isIntegerExpr(left, assumptions: assumptions) ||
            isNonNegativeExpr(right, assumptions: assumptions)),
  BesselY(:final left, :final right) ||
  BesselK(:final left, :final right) ||
  UpperGamma(:final left, :final right) ||
  LowerGamma(:final left, :final right) =>
    isProvenReal(left, assumptions) &&
        isPositiveExpr(right, assumptions: assumptions),
  Polylog(:final left, :final right) =>
    isProvenReal(left, assumptions) &&
        isProvenReal(right, assumptions) &&
        switch (tryStaticRealValue(right)) {
          final v? => v <= 1.0,
          _ => false,
        },
  Asin(:final expr) || Acos(:final expr) =>
    isProvenReal(expr, assumptions) &&
        switch (tryStaticRealValue(expr)) {
          final v? => v.abs() <= 1.0 + 1e-12,
          _ => false,
        },
  Acosh(:final expr) =>
    isProvenReal(expr, assumptions) &&
        switch (tryStaticRealValue(expr)) {
          final v? => v >= 1.0 - 1e-12,
          _ => false,
        },
  Atanh(:final expr) =>
    isProvenReal(expr, assumptions) &&
        switch (tryStaticRealValue(expr)) {
          final v? => v.abs() < 1.0 - 1e-12,
          _ => false,
        },
  Ln(:final expr) => isPositiveExpr(expr, assumptions: assumptions),
  Beta(:final left, :final right) || Mod(:final left, :final right) =>
    isProvenReal(left, assumptions) && isProvenReal(right, assumptions),
  _ => false,
};

/// Returns `true` if [expr] is known to be strictly negative under [assumptions].
bool isNegativeExpr(Expr expr, {required Assumptions assumptions}) {
  final (pos, isNeg) = extractSign(expr);
  return isNeg && isPositiveExpr(pos, assumptions: assumptions);
}

/// Returns `true` if [expr] is known to be strictly positive under [assumptions].
bool isPositiveExpr(Expr expr, {required Assumptions assumptions}) =>
    switch (expr) {
      RealNumeric(:final isNegative, :final isZero) => !isNegative && !isZero,
      Constant(:final value) => value.b == 0.0 && value.a > 0.0,
      Variable(:final name) =>
        assumptions.domainOf(name) == VariableDomain.positive,
      Pow(base: Constant.e, :final exponent) => isProvenReal(
        exponent,
        assumptions,
      ),
      Pow(:final base, :final exponent) =>
        (isPositiveExpr(base, assumptions: assumptions) &&
                isProvenReal(exponent, assumptions)) ||
            (isProvenReal(base, assumptions) &&
                (isPositiveExpr(base, assumptions: assumptions) ||
                    isNegativeExpr(base, assumptions: assumptions)) &&
                exponent is IntegerNumber &&
                exponent.value > Integer.zero &&
                exponent.value.isEven),
      Ln(:final expr) =>
        expr == Constant.e ||
            switch (tryStaticRealValue(expr)) {
              final v? => v > 1.0,
              _ => false,
            },
      Sin() || Cos() => switch (tryStaticRealValue(expr)) {
        final v? => v > 0.0,
        _ => false,
      },
      Cosh(:final expr) => isProvenReal(expr, assumptions),
      Add(:final terms) =>
        terms.every((t) => isNonNegativeExpr(t, assumptions: assumptions)) &&
            terms.any((t) => isPositiveExpr(t, assumptions: assumptions)),
      Mul(:final factors) => () {
        var negCount = 0;
        for (final f in factors) {
          if (isPositiveExpr(f, assumptions: assumptions)) continue;
          if (isNegativeExpr(f, assumptions: assumptions)) {
            negCount++;
            continue;
          }
          return false;
        }
        return negCount.isEven;
      }(),
      _ => false,
    };

/// Returns `true` if [expr] is syntactically non-negative under [assumptions].
bool isNonNegativeExpr(
  Expr expr, {
  required Assumptions assumptions,
}) => switch (expr) {
  RealNumeric(:final isNegative) => !isNegative,
  Constant(:final value) => value.b == 0 && value.a >= 0,
  Variable(:final name) =>
    assumptions.domainOf(name) == VariableDomain.positive,
  Abs(:final expr) => expr != Constant.undefined && expr != Constant.infinity,
  Pow(base: Constant.e, :final exponent) => isProvenReal(exponent, assumptions),
  Pow(:final base, :final exponent) =>
    (isPositiveExpr(base, assumptions: assumptions) &&
            isProvenReal(exponent, assumptions)) ||
        (isNonNegativeExpr(base, assumptions: assumptions) &&
            isNonNegativeExpr(exponent, assumptions: assumptions)) ||
        (isProvenReal(base, assumptions) &&
            exponent is IntegerNumber &&
            exponent.value > Integer.zero &&
            exponent.value.isEven),
  Cosh(:final expr) => isProvenReal(expr, assumptions),
  Add(:final terms) => terms.every(
    (t) => isNonNegativeExpr(t, assumptions: assumptions),
  ),
  Mul(:final factors) => factors.every(
    (f) => isNonNegativeExpr(f, assumptions: assumptions),
  ),
  _ => false,
};

/// Returns `true` if [expr] is syntactically integer-valued under [assumptions].
bool isIntegerExpr(Expr expr, {required Assumptions assumptions}) =>
    switch (expr) {
      IntegerNumber() => true,
      Floor(:final expr) ||
      Ceil(:final expr) ||
      Round(:final expr) => isProvenReal(expr, assumptions),
      Sign(:final expr) => isProvenReal(expr, assumptions),
      Factorial(:final expr) =>
        isIntegerExpr(expr, assumptions: assumptions) &&
            isNonNegativeExpr(expr, assumptions: assumptions),
      Binomial(:final left, :final right) =>
        isIntegerExpr(left, assumptions: assumptions) &&
            isIntegerExpr(right, assumptions: assumptions),
      Variable(:final name) =>
        assumptions.domainOf(name) == VariableDomain.integer,
      Add(:final terms) => terms.every(
        (t) => isIntegerExpr(t, assumptions: assumptions),
      ),
      Mul(:final factors) => factors.every(
        (f) => isIntegerExpr(f, assumptions: assumptions),
      ),
      Pow(:final base, :final exponent) =>
        isIntegerExpr(base, assumptions: assumptions) &&
            exponent is IntegerNumber &&
            !exponent.isNegative,
      _ => false,
    };

/// Returns `true` if [expr] is an even integer expression under [assumptions].
bool isEvenIntegerExpr(Expr expr, {required Assumptions assumptions}) =>
    switch (expr) {
      IntegerNumber(:final value) => value.isEven,
      Mul(:final factors) =>
        factors.every((f) => isIntegerExpr(f, assumptions: assumptions)) &&
            factors.any((f) => isEvenIntegerExpr(f, assumptions: assumptions)),
      Add(:final terms) => terms.every(
        (t) => isEvenIntegerExpr(t, assumptions: assumptions),
      ),
      Pow(:final base, :final exponent) =>
        isEvenIntegerExpr(base, assumptions: assumptions) &&
            exponent is IntegerNumber &&
            exponent.value > Integer.zero,
      _ => false,
    };

/// Decomposes an expression into its Cartesian real and imaginary components
/// $(u, v)$ such that $expr = u + i v$.
({Expr re, Expr im}) decomposeComplex(Expr expr, Assumptions assumptions) {
  if (isProvenReal(expr, assumptions)) {
    return (re: expr, im: IntegerNumber.zero);
  }
  switch (expr) {
    case ComplexNumber(:final real, :final imaginary):
      return (re: real, im: imaginary);
    case Variable():
      return (
        re: Re(expr, isSimplified: true),
        im: Im(expr, isSimplified: true),
      );
    case Conjugate(:final expr):
      final (:re, :im) = decomposeComplex(expr, assumptions);
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
    case Sin(:final expr):
      final (:re, :im) = decomposeComplex(expr, assumptions);
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
    case Cos(:final expr):
      final (:re, :im) = decomposeComplex(expr, assumptions);
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
    case Sinh(:final expr):
      final (:re, :im) = decomposeComplex(expr, assumptions);
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
    case Cosh(:final expr):
      final (:re, :im) = decomposeComplex(expr, assumptions);
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
    case Ln(:final expr):
      return (
        re: simplifyLn(
          simplifyAbs(expr, assumptions: assumptions),
          assumptions: assumptions,
        ),
        im: simplifyArg(expr, assumptions: assumptions),
      );
    default:
      return (
        re: Re(expr, isSimplified: true),
        im: Im(expr, isSimplified: true),
      );
  }
}

/// Evaluates [expr] to a floating-point real number if it is constant and real,
/// or returns `null`.
double? tryStaticRealValue(Expr expr) {
  switch (expr) {
    case RealNumeric():
      return expr.toDouble();
    case Constant(:final isReal, :final value) when isReal:
      return value.a.toDouble();
    case _ when expr.freeVariables.isEmpty:
      try {
        final c = expr.evaluateComplex();
        if (c.b.abs() < 1e-12 && c.a.isFinite) {
          return c.a.toDouble();
        }
      } on Object {
        // Fall back to null if evaluation fails.
      }
      return null;
    case _:
      return null;
  }
}
