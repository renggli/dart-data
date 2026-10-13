import 'package:more/number.dart' show Fraction;

import '../../ast.dart';
import '../exact_constants.dart';
import '../simplify.dart';
import '../structural_order.dart';

/// Simplifies a sine expression $\sin(expr)$.
Expr simplifySin(Expr expr) {
  if (expr is RationalNumber && expr.isZero) return RationalNumber.zero;
  if (expr is RealNumber && expr.value == 0.0) return RationalNumber.zero;

  // Involution: sin(asin(u)) = u
  if (expr is Asin) return expr.expr;

  // Parity: sin(-u) = -sin(u)
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(simplifySin(posExpr));
  }

  // Multiples of pi
  final piMult = matchPiMultiple(expr);
  if (piMult != null) {
    if (piMult.denominator == 1) {
      return RationalNumber.zero;
    }
    if (piMult.denominator == 2) {
      final k = (piMult.numerator - 1) ~/ 2;
      return (k % 2 == 0) ? RationalNumber.one : RationalNumber.negativeOne;
    }
  }

  return Sin(expr);
}

/// Simplifies a cosine expression $\cos(expr)$.
Expr simplifyCos(Expr expr) {
  if (expr is RationalNumber && expr.isZero) return RationalNumber.one;
  if (expr is RealNumber && expr.value == 0.0) return RationalNumber.one;

  // Involution: cos(acos(u)) = u
  if (expr is Acos) return expr.expr;

  // Parity: cos(-u) = cos(u)
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyCos(posExpr);
  }

  // Multiples of pi
  final piMult = matchPiMultiple(expr);
  if (piMult != null) {
    if (piMult.denominator == 1) {
      return (piMult.numerator % 2 == 0)
          ? RationalNumber.one
          : RationalNumber.negativeOne;
    }
    if (piMult.denominator == 2 && piMult.numerator.isOdd) {
      return RationalNumber.zero;
    }
  }

  return Cos(expr);
}

/// Simplifies a tangent expression $\tan(expr)$.
Expr simplifyTan(Expr expr) {
  if (expr is RationalNumber && expr.isZero) return RationalNumber.zero;
  if (expr is RealNumber && expr.value == 0.0) return RationalNumber.zero;

  // Involution: tan(atan(u)) = u
  if (expr is Atan) return expr.expr;

  // Parity: tan(-u) = -tan(u)
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(simplifyTan(posExpr));
  }

  // Multiples of pi
  final piMult = matchPiMultiple(expr);
  if (piMult != null) {
    if (piMult.denominator == 1) {
      return RationalNumber.zero;
    }
    if (piMult.denominator == 4) {
      final rem = piMult.numerator % 4;
      if (rem == 1 || rem == -3) return RationalNumber.one;
      if (rem == 3 || rem == -1) return RationalNumber.negativeOne;
    }
  }

  return Tan(expr);
}

/// Simplifies an arcsine expression $\arcsin(expr)$.
Expr simplifyAsin(Expr expr) {
  if (expr is RationalNumber && expr.isZero) return RationalNumber.zero;
  if (expr is RealNumber && expr.value == 0.0) return RationalNumber.zero;
  if (expr is RationalNumber && expr.isOne) {
    return const Mul(RationalNumber(1, 2), ConstantNumber.pi);
  }
  if (expr is RealNumber && expr.value == 1.0) {
    return const Mul(RationalNumber(1, 2), ConstantNumber.pi);
  }
  if (expr is RationalNumber && expr == RationalNumber.negativeOne) {
    return const Mul(RationalNumber(-1, 2), ConstantNumber.pi);
  }
  if (expr is RealNumber && expr.value == -1.0) {
    return const Mul(RationalNumber(-1, 2), ConstantNumber.pi);
  }

  // Involution: asin(sin(u)) = u
  if (expr is Sin) return expr.expr;

  // Parity: asin(-u) = -asin(u)
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(simplifyAsin(posExpr));
  }

  if (isHalf(posExpr)) {
    return const Mul(RationalNumber(1, 6), ConstantNumber.pi);
  }
  if (isSqrt2Over2(posExpr)) {
    return const Mul(RationalNumber(1, 4), ConstantNumber.pi);
  }
  if (isSqrt3Over2(posExpr)) {
    return const Mul(RationalNumber(1, 3), ConstantNumber.pi);
  }

  return Asin(expr);
}

/// Simplifies an arccosine expression $\arccos(expr)$.
Expr simplifyAcos(Expr expr) {
  if (expr is RationalNumber && expr.isOne) return RationalNumber.zero;
  if (expr is RealNumber && expr.value == 1.0) return RationalNumber.zero;
  if (expr is RationalNumber && expr.isZero) {
    return const Mul(RationalNumber(1, 2), ConstantNumber.pi);
  }
  if (expr is RealNumber && expr.value == 0.0) {
    return const Mul(RationalNumber(1, 2), ConstantNumber.pi);
  }
  if (expr is RationalNumber && expr == RationalNumber.negativeOne) {
    return ConstantNumber.pi;
  }
  if (expr is RealNumber && expr.value == -1.0) {
    return ConstantNumber.pi;
  }

  // Involution: acos(cos(u)) = u
  if (expr is Cos) return expr.expr;

  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    if (posExpr is RationalNumber && posExpr.isOne) return ConstantNumber.pi;
    if (posExpr is RealNumber && posExpr.value == 1.0) return ConstantNumber.pi;
    if (isHalf(posExpr)) {
      return const Mul(RationalNumber(2, 3), ConstantNumber.pi);
    }
    if (isSqrt2Over2(posExpr)) {
      return const Mul(RationalNumber(3, 4), ConstantNumber.pi);
    }
    if (isSqrt3Over2(posExpr)) {
      return const Mul(RationalNumber(5, 6), ConstantNumber.pi);
    }
  }

  if (isHalf(posExpr)) {
    return const Mul(RationalNumber(1, 3), ConstantNumber.pi);
  }
  if (isSqrt2Over2(posExpr)) {
    return const Mul(RationalNumber(1, 4), ConstantNumber.pi);
  }
  if (isSqrt3Over2(posExpr)) {
    return const Mul(RationalNumber(1, 6), ConstantNumber.pi);
  }

  return Acos(expr);
}

/// Simplifies an arctangent expression $\arctan(expr)$.
Expr simplifyAtan(Expr expr) {
  if (expr is RationalNumber && expr.isZero) return RationalNumber.zero;
  if (expr is RealNumber && expr.value == 0.0) return RationalNumber.zero;
  if (expr is RationalNumber && expr.isOne) {
    return const Mul(RationalNumber(1, 4), ConstantNumber.pi);
  }
  if (expr is RealNumber && expr.value == 1.0) {
    return const Mul(RationalNumber(1, 4), ConstantNumber.pi);
  }
  if (expr is RationalNumber && expr == RationalNumber.negativeOne) {
    return const Mul(RationalNumber(-1, 4), ConstantNumber.pi);
  }
  if (expr is RealNumber && expr.value == -1.0) {
    return const Mul(RationalNumber(-1, 4), ConstantNumber.pi);
  }

  // Involution: atan(tan(u)) = u
  if (expr is Tan) return expr.expr;

  // Parity: atan(-u) = -atan(u)
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(simplifyAtan(posExpr));
  }

  if (isSqrt3Over3(posExpr)) {
    return const Mul(RationalNumber(1, 6), ConstantNumber.pi);
  }
  if (isSqrt3(posExpr)) {
    return const Mul(RationalNumber(1, 3), ConstantNumber.pi);
  }

  return Atan(expr);
}

/// Simplifies a hyperbolic sine expression $\sinh(expr)$.
Expr simplifySinh(Expr expr) {
  if (expr is RationalNumber && expr.isZero) return RationalNumber.zero;
  if (expr is RealNumber && expr.value == 0.0) return RationalNumber.zero;

  // Parity: sinh(-u) = -sinh(u)
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(simplifySinh(posExpr));
  }

  return Sinh(expr);
}

/// Simplifies a hyperbolic cosine expression $\cosh(expr)$.
Expr simplifyCosh(Expr expr) {
  if (expr is RationalNumber && expr.isZero) return RationalNumber.one;
  if (expr is RealNumber && expr.value == 0.0) return RationalNumber.one;

  // Parity: cosh(-u) = cosh(u)
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyCosh(posExpr);
  }

  return Cosh(expr);
}

/// Simplifies a hyperbolic tangent expression $\tanh(expr)$.
Expr simplifyTanh(Expr expr) {
  if (expr is RationalNumber && expr.isZero) return RationalNumber.zero;
  if (expr is RealNumber && expr.value == 0.0) return RationalNumber.zero;

  // Parity: tanh(-u) = -tanh(u)
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(simplifyTanh(posExpr));
  }

  return Tanh(expr);
}

/// Simplifies an absolute value expression $|expr|$.
Expr simplifyAbs(Expr expr) {
  if (expr is RationalNumber) {
    return expr.isNegative ? RationalNumber.fraction(-expr.toFraction()) : expr;
  }
  if (expr is RealNumber) {
    return RealNumber(expr.value.abs());
  }

  // Idempotence: ||u|| = |u|
  if (expr is Abs) return expr;

  // Exp is strictly positive for real inputs: |exp(u)| = exp(u)
  if (expr is Exp) return expr;

  // Parity: |-u| = |u|
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyAbs(posExpr);
  }

  return Abs(expr);
}

/// Simplifies an exponential expression $\exp(expr)$.
Expr simplifyExp(Expr expr) {
  if (expr case RationalNumber(isZero: true) || RealNumber(value: 0.0)) {
    return RationalNumber.one;
  }
  if (expr case RationalNumber(isOne: true)) {
    return ConstantNumber.e;
  }
  // e^(ln(u)) = u
  if (expr is Ln) {
    return expr.expr;
  }
  // e^(k * ln(u)) = u^k
  if (expr is Mul) {
    if (expr.left is Ln) {
      return simplifyPow((expr.left as Ln).expr, expr.right);
    }
    if (expr.right is Ln) {
      return simplifyPow((expr.right as Ln).expr, expr.left);
    }
  }
  if (expr is Neg && expr.expr is Ln) {
    return simplifyPow((expr.expr as Ln).expr, RationalNumber.negativeOne);
  }
  return Exp(expr);
}

/// Simplifies a natural logarithm expression $\ln(expr)$.
Expr simplifyLn(Expr expr) {
  if (expr case ConstantNumber(name: 'e')) return RationalNumber.one;
  if (expr case RationalNumber(:final isNegative, :final isZero)
      when isNegative || isZero) {
    throw ArgumentError(
      'Natural logarithm domain error: non-positive argument',
    );
  }
  if (expr case RealNumber(:final value) when value <= 0.0) {
    throw ArgumentError(
      'Natural logarithm domain error: non-positive argument',
    );
  }
  if (expr case RationalNumber(isOne: true) || RealNumber(value: 1.0)) {
    return RationalNumber.zero;
  }
  // ln(exp(u)) = u
  if (expr is Exp) return expr.expr;

  // ln(u^k) = k * ln(u)
  if (expr is Pow) {
    return simplifyMul(expr.exponent, Ln(expr.base));
  }

  // ln(1 / u) = -ln(u)
  if (expr case Div(left: RationalNumber(isOne: true), right: final right)) {
    return simplifyNeg(simplifyLn(right));
  }

  return Ln(expr);
}

/// Extracts the sign of [expr], returning the non-negative magnitude and sign flag.
(Expr, bool) extractSign(Expr expr) {
  if (expr is Neg) {
    return (expr.expr, true);
  }
  if (expr is RationalNumber && expr.isNegative) {
    return (RationalNumber.fraction(-expr.toFraction()), true);
  }
  if (expr is RealNumber && expr.value < 0.0) {
    return (RealNumber(-expr.value), true);
  }
  if (expr is Mul) {
    if (expr.left is RationalNumber &&
        (expr.left as RationalNumber).isNegative) {
      final posLeft = RationalNumber.fraction(
        -(expr.left as RationalNumber).toFraction(),
      );
      return (simplifyMul(posLeft, expr.right), true);
    }
    if (expr.right is RationalNumber &&
        (expr.right as RationalNumber).isNegative) {
      final posRight = RationalNumber.fraction(
        -(expr.right as RationalNumber).toFraction(),
      );
      return (simplifyMul(expr.left, posRight), true);
    }
  }
  return (expr, false);
}

/// Matches if [expr] is a rational multiple of $\pi$.
Fraction? matchPiMultiple(Expr expr) {
  if (expr is ConstantNumber && expr.name == 'pi') {
    return Fraction.one;
  }
  if (expr is Neg) {
    final sub = matchPiMultiple(expr.expr);
    return sub != null ? -sub : null;
  }
  if (expr is Mul) {
    if (expr.left is ConstantNumber &&
        (expr.left as ConstantNumber).name == 'pi') {
      if (expr.right is RationalNumber) {
        return (expr.right as RationalNumber).toFraction();
      }
    }
    if (expr.right is ConstantNumber &&
        (expr.right as ConstantNumber).name == 'pi') {
      if (expr.left is RationalNumber) {
        return (expr.left as RationalNumber).toFraction();
      }
    }
  }
  if (expr is Div) {
    if (expr.left is ConstantNumber &&
        (expr.left as ConstantNumber).name == 'pi') {
      if (expr.right is RationalNumber) {
        return Fraction.one / (expr.right as RationalNumber).toFraction();
      }
    }
  }
  return null;
}

/// Simplifies a Lambert W expression $W_b(expr)$.
Expr simplifyLambertW(Expr expr, int branch) {
  if (branch == 0) {
    if (expr case RationalNumber(isZero: true) || RealNumber(value: 0.0)) {
      return RationalNumber.zero;
    }
    if (expr == ConstantNumber.e) {
      return RationalNumber.one;
    }
  }
  if (expr
      case Div(
            left: RationalNumber(isNegativeOne: true),
            right: ConstantNumber.e,
          ) ||
          Neg(
            expr: Div(
              left: RationalNumber(isOne: true),
              right: ConstantNumber.e,
            ),
          )) {
    return RationalNumber.negativeOne;
  }
  return LambertW(expr, branch: branch);
}

/// Simplifies an error function expression $\operatorname{erf}(expr)$.
Expr simplifyErf(Expr expr) {
  if (expr case RationalNumber(isZero: true) || RealNumber(value: 0.0)) {
    return RationalNumber.zero;
  }
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(simplifyErf(posExpr));
  }
  return Erf(expr);
}

/// Simplifies a complementary error function expression $\operatorname{erfc}(expr)$.
Expr simplifyErfc(Expr expr) {
  if (expr case RationalNumber(isZero: true) || RealNumber(value: 0.0)) {
    return RationalNumber.one;
  }
  return Erfc(expr);
}

/// Simplifies an Euler gamma function expression $\Gamma(expr)$.
Expr simplifyGamma(Expr expr) {
  if (expr case RationalNumber(:final isInteger, :final numerator)
      when isInteger && numerator > 0) {
    var fact = 1;
    for (var k = 2; k < numerator; k++) {
      fact *= k;
    }
    return RationalNumber(fact);
  }
  if (expr case RationalNumber(numerator: 1, denominator: 2)) {
    return const Pow(ConstantNumber.pi, RationalNumber(1, 2));
  }
  return Gamma(expr);
}

/// Simplifies an Euler beta function expression $\operatorname{B}(a, b)$.
Expr simplifyBeta(Expr a, Expr b) {
  if (compareStructural(a, b) > 0) {
    return simplifyBeta(b, a);
  }
  if (a case RationalNumber(isInteger: true, numerator: final m) when m > 0) {
    if (b case RationalNumber(isInteger: true, numerator: final n) when n > 0) {
      var factM = 1;
      for (var k = 2; k < m; k++) {
        factM *= k;
      }
      var factN = 1;
      for (var k = 2; k < n; k++) {
        factN *= k;
      }
      var factTotal = 1;
      for (var k = 2; k < m + n; k++) {
        factTotal *= k;
      }
      final frac = Fraction(factM * factN, factTotal);
      return RationalNumber(frac.numerator, frac.denominator);
    }
    if (m == 1) {
      return Div(RationalNumber.one, b).simplify();
    }
  }
  if (b case RationalNumber(isInteger: true, numerator: 1)) {
    return Div(RationalNumber.one, a).simplify();
  }
  return Beta(a, b);
}

/// Simplifies an inverse hyperbolic sine expression $\operatorname{asinh}(expr)$.
Expr simplifyAsinh(Expr expr) {
  if (expr case RationalNumber(isZero: true) || RealNumber(value: 0.0)) {
    return RationalNumber.zero;
  }
  if (expr is Sinh) return expr.expr;
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(simplifyAsinh(posExpr));
  }
  return Asinh(expr);
}

/// Simplifies an inverse hyperbolic cosine expression $\operatorname{acosh}(expr)$.
Expr simplifyAcosh(Expr expr) {
  if (expr case RationalNumber(isOne: true) || RealNumber(value: 1.0)) {
    return RationalNumber.zero;
  }
  if (expr is Cosh) return expr.expr;
  return Acosh(expr);
}

/// Simplifies an inverse hyperbolic tangent expression $\operatorname{atanh}(expr)$.
Expr simplifyAtanh(Expr expr) {
  if (expr case RationalNumber(isZero: true) || RealNumber(value: 0.0)) {
    return RationalNumber.zero;
  }
  if (expr is Tanh) return expr.expr;
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(simplifyAtanh(posExpr));
  }
  return Atanh(expr);
}

/// Simplifies a relational expression.
Expr simplifyRelational(RelationalExpr expr) {
  final left = expr.left.simplify();
  final right = expr.right.simplify();
  if (left is Number &&
      right is Number &&
      left is! ComplexNumber &&
      right is! ComplexNumber) {
    final vL = left.value;
    final vR = right.value;
    final matched = switch (expr) {
      LessThan() => vL < vR,
      LessEqual() => vL <= vR,
      GreaterThan() => vL > vR,
      GreaterEqual() => vL >= vR,
      Equal() => vL == vR,
    };
    return matched ? RationalNumber.one : RationalNumber.zero;
  }
  return switch (expr) {
    LessThan() => LessThan(left, right),
    LessEqual() => LessEqual(left, right),
    GreaterThan() => GreaterThan(left, right),
    GreaterEqual() => GreaterEqual(left, right),
    Equal() => Equal(left, right),
  };
}

/// Simplifies a piecewise expression.
Expr simplifyPiecewise(Piecewise expr) {
  final simplifiedBranches = <(Expr, Expr)>[];
  for (final (cond, branchExpr) in expr.branches) {
    final sCond = cond.simplify();
    if (sCond case RationalNumber(isZero: true) || RealNumber(value: 0.0)) {
      continue;
    }
    final sExpr = branchExpr.simplify();
    if (sCond case RationalNumber(isOne: true) || RealNumber(value: 1.0)) {
      if (simplifiedBranches.isEmpty) {
        return sExpr;
      }
      simplifiedBranches.add((sCond, sExpr));
      return Piecewise(simplifiedBranches);
    }
    simplifiedBranches.add((sCond, sExpr));
  }
  final sOtherwise = expr.otherwise?.simplify();
  if (simplifiedBranches.isEmpty) {
    return sOtherwise ?? RationalNumber.zero;
  }
  return Piecewise(simplifiedBranches, otherwise: sOtherwise);
}
