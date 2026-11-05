import 'dart:math' as math;

import '../../assumptions.dart';
import '../../ast.dart';
import '../../compiler.dart';
import '../../number/integer.dart';
import 'additive.dart';
import 'multiplicative.dart';
import 'power.dart';
import 'transcendental.dart';

/// Returns `true` if [expr] is known to be real-valued under [assumptions].
bool isProvenReal(Expr expr, [Assumptions assumptions = Assumptions.none]) =>
    switch (expr) {
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
      Pow(base: Constant.e, :final exponent) => isProvenReal(
        exponent,
        assumptions,
      ),
      Pow(:final base, :final exponent) =>
        (isProvenReal(base, assumptions) && exponent is IntegerNumber) ||
            (isNonNegativeExpr(base, assumptions: assumptions) &&
                isProvenReal(exponent, assumptions)),
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
      Gamma(:final expr) => isProvenReal(expr, assumptions),
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

/// Returns `true` if [expr] is known to be strictly positive under [assumptions].
bool isPositiveExpr(Expr expr, {Assumptions assumptions = Assumptions.none}) =>
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
        isPositiveExpr(base, assumptions: assumptions) &&
            isProvenReal(exponent, assumptions),
      Mul(:final factors) => factors.every(
        (f) => isPositiveExpr(f, assumptions: assumptions),
      ),
      _ => false,
    };

/// Returns `true` if [expr] is syntactically non-negative under [assumptions].
bool isNonNegativeExpr(
  Expr expr, {
  Assumptions assumptions = Assumptions.none,
}) => switch (expr) {
  RealNumeric(:final isNegative) => !isNegative,
  Constant(:final value) => value.b == 0 && value.a >= 0,
  Variable(:final name) =>
    assumptions.domainOf(name) == VariableDomain.positive,
  Abs() => true,
  Pow(base: Constant.e, :final exponent) => isProvenReal(exponent, assumptions),
  Pow(:final base, :final exponent) =>
    isNonNegativeExpr(base, assumptions: assumptions) ||
        (isProvenReal(base, assumptions) &&
            exponent is IntegerNumber &&
            exponent.value.isEven),
  Mul(:final factors) => factors.every(
    (f) => isNonNegativeExpr(f, assumptions: assumptions),
  ),
  _ => false,
};

/// Returns `true` if [expr] is syntactically integer-valued under [assumptions].
bool isIntegerExpr(Expr expr, {Assumptions assumptions = Assumptions.none}) =>
    switch (expr) {
      IntegerNumber() || Floor() || Ceil() || Round() => true,
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
bool isEvenIntegerExpr(
  Expr expr, {
  Assumptions assumptions = Assumptions.none,
}) => switch (expr) {
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
      return (re: re, im: simplifyNeg(im));
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
          simplifyNeg(simplifyMul([accIm, im], assumptions: assumptions)),
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
          simplifyNeg(simplifyMul([powIm, im], assumptions: assumptions)),
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
          ),
        );
      }
      return (re: powRe, im: powIm);
    case Sin(:final expr):
      final (:re, :im) = decomposeComplex(expr, assumptions);
      return (
        re: simplifyMul([
          simplifySin(re, assumptions: assumptions),
          simplifyCosh(im),
        ], assumptions: assumptions),
        im: simplifyMul([
          simplifyCos(re, assumptions: assumptions),
          simplifySinh(im),
        ], assumptions: assumptions),
      );
    case Cos(:final expr):
      final (:re, :im) = decomposeComplex(expr, assumptions);
      return (
        re: simplifyMul([
          simplifyCos(re, assumptions: assumptions),
          simplifyCosh(im),
        ], assumptions: assumptions),
        im: simplifyNeg(
          simplifyMul([
            simplifySin(re, assumptions: assumptions),
            simplifySinh(im),
          ], assumptions: assumptions),
        ),
      );
    case Sinh(:final expr):
      final (:re, :im) = decomposeComplex(expr, assumptions);
      return (
        re: simplifyMul([
          simplifySinh(re),
          simplifyCos(im, assumptions: assumptions),
        ], assumptions: assumptions),
        im: simplifyMul([
          simplifyCosh(re),
          simplifySin(im, assumptions: assumptions),
        ], assumptions: assumptions),
      );
    case Cosh(:final expr):
      final (:re, :im) = decomposeComplex(expr, assumptions);
      return (
        re: simplifyMul([
          simplifyCosh(re),
          simplifyCos(im, assumptions: assumptions),
        ], assumptions: assumptions),
        im: simplifyMul([
          simplifySinh(re),
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
