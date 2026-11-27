import 'dart:math' as math;

import '../../assumptions.dart';
import '../../ast.dart';
import '../../compiler.dart';
import '../../functions/fn.dart';
import 'additive.dart';
import 'complex.dart';
import 'multiplicative.dart';
import 'power.dart';
import 'transcendental.dart';

/// Returns `true` if [expr] is known to be real-valued under [assumptions].
bool isProvenReal(Expr expr, Assumptions assumptions) => switch (expr) {
  RealNumeric() => true,
  Call(
    id: FunctionId.abs || FunctionId.re || FunctionId.im || FunctionId.arg,
    args: [final inner],
  ) =>
    !inner.anyNode((n) => n == Constant.undefined),
  Call(
    id: FunctionId.floor ||
        FunctionId.ceil ||
        FunctionId.round ||
        FunctionId.sign,
    args: [final inner],
  ) =>
    isProvenReal(inner, assumptions),
  Call(id: FunctionId.factorial, args: [final inner]) =>
    isProvenReal(inner, assumptions) &&
        (isNonNegativeExpr(inner, assumptions: assumptions) ||
            switch (tryStaticRealValue(inner)) {
              final v? => v >= 0.0 || (v != v.floorToDouble()),
              _ => false,
            }),
  Call(id: FunctionId.binomial, args: [final left, final right]) =>
    isProvenReal(left, assumptions) && isProvenReal(right, assumptions),
  Call(id: FunctionId.lambertW, :final args) => () {
    final inner = args[0];
    final branch = args.length == 1
        ? 0
        : (args[1] is IntegerNumber ? (args[1] as IntegerNumber).asInt : null);
    return switch (branch) {
      0 =>
        isProvenReal(inner, assumptions) &&
            (isNonNegativeExpr(inner, assumptions: assumptions) ||
                switch (tryStaticRealValue(inner)) {
                  final v? => v >= -1.0 / math.e,
                  _ => false,
                }),
      -1 =>
        isProvenReal(inner, assumptions) &&
            switch (tryStaticRealValue(inner)) {
              final v? => v >= -1.0 / math.e && v < 0.0,
              _ => false,
            },
      _ => false,
    };
  }(),
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
  Call(
    id: FunctionId.sin ||
        FunctionId.cos ||
        FunctionId.tan ||
        FunctionId.atan ||
        FunctionId.sinh ||
        FunctionId.cosh ||
        FunctionId.tanh ||
        FunctionId.asinh ||
        FunctionId.erf ||
        FunctionId.erfc ||
        FunctionId.erfi ||
        FunctionId.fresnelS ||
        FunctionId.fresnelC ||
        FunctionId.ei ||
        FunctionId.si ||
        FunctionId.shi,
    args: [final inner],
  ) =>
    isProvenReal(inner, assumptions),
  Call(id: FunctionId.zeta, :final args) =>
    isProvenReal(args[0], assumptions) &&
        switch (tryStaticRealValue(args[0])) {
          final v? => v != 1.0,
          _ => false,
        } &&
        (args.length < 2 || isProvenReal(args[1], assumptions)),
  Call(id: FunctionId.expIntegralE, args: [final left, final right]) =>
    isProvenReal(left, assumptions) &&
        isPositiveExpr(right, assumptions: assumptions),
  Call(
    id: FunctionId.hypergeometric,
    args: [final upperArg, final lowerArg, final argument],
  ) =>
    () {
      final upper = upperArg is Call && upperArg.id == FunctionId.tuple
          ? upperArg.args
          : [upperArg];
      final lower = lowerArg is Call && lowerArg.id == FunctionId.tuple
          ? lowerArg.args
          : [lowerArg];
      return upper.every((e) => isProvenReal(e, assumptions)) &&
          lower.every((e) => isProvenReal(e, assumptions)) &&
          isProvenReal(argument, assumptions) &&
          switch (tryStaticRealValue(argument)) {
            final v? => v <= 1.0,
            _ => false,
          };
    }(),
  Call(
    id: FunctionId.appellF1,
    args: [final a, final b1, final b2, final c, final x, final y],
  ) =>
    isProvenReal(a, assumptions) &&
        isProvenReal(b1, assumptions) &&
        isProvenReal(b2, assumptions) &&
        isProvenReal(c, assumptions) &&
        isProvenReal(x, assumptions) &&
        isProvenReal(y, assumptions) &&
        switch ((tryStaticRealValue(x), tryStaticRealValue(y))) {
          (final vx?, final vy?) => vx < 1.0 && vy < 1.0,
          _ => false,
        },
  Call(id: FunctionId.logGamma, args: [final inner]) => isPositiveExpr(
    inner,
    assumptions: assumptions,
  ),
  Call(
    id: FunctionId.min ||
        FunctionId.max ||
        FunctionId.gcd ||
        FunctionId.lcm ||
        FunctionId.tuple,
    :final args,
  ) =>
    args.every((e) => isProvenReal(e, assumptions)),
  Call(id: FunctionId.gamma || FunctionId.digamma, args: [final inner]) =>
    isProvenReal(inner, assumptions) &&
        (isPositiveExpr(inner, assumptions: assumptions) ||
            switch (tryStaticRealValue(inner)) {
              final v? => v > 0.0 || (v != v.floorToDouble()),
              _ => false,
            }),
  Call(
    id: FunctionId.li || FunctionId.ci || FunctionId.chi,
    args: [final inner],
  ) =>
    isProvenReal(inner, assumptions) &&
        switch (tryStaticRealValue(inner)) {
          final v? => v > 0.0,
          _ => false,
        },
  Call(id: FunctionId.ellipticK, args: [final inner]) =>
    isProvenReal(inner, assumptions) &&
        switch (tryStaticRealValue(inner)) {
          final v? => v.abs() < 1.0,
          _ => false,
        },
  Call(id: FunctionId.ellipticE, :final args) =>
    args.length == 1
        ? isProvenReal(args[0], assumptions) &&
              switch (tryStaticRealValue(args[0])) {
                final v? => v.abs() <= 1.0,
                _ => false,
              }
        : isProvenReal(args[1], assumptions) &&
              switch (tryStaticRealValue(args[1])) {
                final v? => v.abs() <= 1.0,
                _ => false,
              } &&
              isProvenReal(args[0], assumptions),
  Call(
    id: FunctionId.polygamma || FunctionId.ellipticF || FunctionId.atan2,
    args: [final left, final right],
  ) =>
    isProvenReal(left, assumptions) && isProvenReal(right, assumptions),
  Call(
    id: FunctionId.ellipticPi,
    args: [final characteristic, final amplitude, final modulus],
  ) =>
    isProvenReal(characteristic, assumptions) &&
        isProvenReal(amplitude, assumptions) &&
        isProvenReal(modulus, assumptions),
  Call(
    id: FunctionId.besselJ || FunctionId.besselI,
    args: [final left, final right],
  ) =>
    isProvenReal(left, assumptions) &&
        isProvenReal(right, assumptions) &&
        (isIntegerExpr(left, assumptions: assumptions) ||
            isNonNegativeExpr(right, assumptions: assumptions)),
  Call(
    id: FunctionId.besselY ||
        FunctionId.besselK ||
        FunctionId.upperGamma ||
        FunctionId.lowerGamma,
    args: [final left, final right],
  ) =>
    isProvenReal(left, assumptions) &&
        isPositiveExpr(right, assumptions: assumptions),
  Call(id: FunctionId.polylog, args: [final left, final right]) =>
    isProvenReal(left, assumptions) &&
        isProvenReal(right, assumptions) &&
        switch (tryStaticRealValue(right)) {
          final v? => v <= 1.0,
          _ => false,
        },
  Call(id: FunctionId.asin || FunctionId.acos, args: [final inner]) =>
    isProvenReal(inner, assumptions) &&
        switch (tryStaticRealValue(inner)) {
          final v? => v.abs() <= 1.0,
          _ => false,
        },
  Call(id: FunctionId.acosh, args: [final inner]) =>
    isProvenReal(inner, assumptions) &&
        switch (tryStaticRealValue(inner)) {
          final v? => v >= 1.0,
          _ => false,
        },
  Call(id: FunctionId.atanh, args: [final inner]) =>
    isProvenReal(inner, assumptions) &&
        switch (tryStaticRealValue(inner)) {
          final v? => v.abs() < 1.0,
          _ => false,
        },
  Call(id: FunctionId.ln, args: [final inner]) => isPositiveExpr(
    inner,
    assumptions: assumptions,
  ),
  Call(id: FunctionId.beta, args: [final left, final right]) =>
    isProvenReal(left, assumptions) &&
        isProvenReal(right, assumptions) &&
        isPositiveExpr(left, assumptions: assumptions) &&
        isPositiveExpr(right, assumptions: assumptions),
  Call(id: FunctionId.mod, args: [final left, final right]) =>
    isProvenReal(left, assumptions) && isProvenReal(right, assumptions),
  _ => false,
};

/// Returns `true` if [expr] is known to be strictly negative under [assumptions].
bool isNegativeExpr(Expr expr, {required Assumptions assumptions}) {
  if (expr is Add) {
    var hasNegative = false;
    for (final term in expr.terms) {
      if (isNegativeExpr(term, assumptions: assumptions)) {
        hasNegative = true;
      } else if (term is! Number || !term.isZero) {
        return false;
      }
    }
    return hasNegative;
  }
  final (pos, isNeg) = extractSign(expr);
  return isNeg && isPositiveExpr(pos, assumptions: assumptions);
}

/// Returns `true` if [expr] is known to be strictly positive under [assumptions].
bool isPositiveExpr(Expr expr, {required Assumptions assumptions}) =>
    switch (expr) {
      RealNumeric(:final isNegative, :final isZero) => !isNegative && !isZero,
      Constant(:final isReal, :final value) =>
        isReal && value.b == 0.0 && value.a > 0.0,
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
                exponent.value > BigInt.zero &&
                exponent.value.isEven),
      Call(id: FunctionId.ln, args: [final inner]) =>
        inner == Constant.e ||
            switch (tryStaticRealValue(inner)) {
              final v? => v > 1.0,
              _ => false,
            },
      Call(id: FunctionId.sin || FunctionId.cos) => switch (tryStaticRealValue(
        expr,
      )) {
        final v? => v > 1e-12,
        _ => false,
      },
      Call(id: FunctionId.cosh, args: [final inner]) => isProvenReal(
        inner,
        assumptions,
      ),
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
bool isNonNegativeExpr(Expr expr, {required Assumptions assumptions}) =>
    switch (expr) {
      RealNumeric(:final isNegative) => !isNegative,
      Constant(:final isReal, :final value) =>
        isReal && value.b == 0 && value.a >= 0,
      Variable(:final name) =>
        assumptions.domainOf(name) == VariableDomain.positive,
      Call(id: FunctionId.abs, args: [final inner]) =>
        inner != Constant.undefined && inner != Constant.infinity,
      Pow(base: Constant.e, :final exponent) => isProvenReal(
        exponent,
        assumptions,
      ),
      Pow(:final base, :final exponent) =>
        (isPositiveExpr(base, assumptions: assumptions) &&
                isProvenReal(exponent, assumptions)) ||
            (isNonNegativeExpr(base, assumptions: assumptions) &&
                isNonNegativeExpr(exponent, assumptions: assumptions)) ||
            (isProvenReal(base, assumptions) &&
                exponent is IntegerNumber &&
                exponent.value > BigInt.zero &&
                exponent.value.isEven),
      Call(id: FunctionId.cosh, args: [final inner]) => isProvenReal(
        inner,
        assumptions,
      ),
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
      Call(
        id: FunctionId.floor ||
            FunctionId.ceil ||
            FunctionId.round ||
            FunctionId.sign,
        args: [final inner],
      ) =>
        isProvenReal(inner, assumptions),
      Call(id: FunctionId.factorial, args: [final inner]) =>
        isIntegerExpr(inner, assumptions: assumptions) &&
            isNonNegativeExpr(inner, assumptions: assumptions),
      Call(id: FunctionId.binomial, args: [final left, final right]) =>
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
            exponent.value > BigInt.zero,
      _ => false,
    };

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
