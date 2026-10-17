import '../../ast.dart';
import '../exact_constants.dart';
import '../simplify.dart';
import '../structural_order.dart';

/// Simplifies a sine expression $\sin(expr)$.
Expr simplifySin(Expr expr) {
  if (expr is Number && expr.isZero) return IntegerNumber.zero;

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
    if (piMult.isInteger) {
      return IntegerNumber.zero;
    }
    if (piMult.denominator == Integer.two) {
      final k = (piMult.numerator - Integer.one) ~/ Integer.two;
      return k.isEven ? IntegerNumber.one : IntegerNumber.negativeOne;
    }
  }

  return Sin(expr, isSimplified: true);
}

/// Simplifies a cosine expression $\cos(expr)$.
Expr simplifyCos(Expr expr) {
  if (expr is Number && expr.isZero) return IntegerNumber.one;

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
    if (piMult.isInteger) {
      return piMult.numerator.isEven
          ? IntegerNumber.one
          : IntegerNumber.negativeOne;
    }
    if (piMult.denominator == Integer.two && piMult.numerator.isOdd) {
      return IntegerNumber.zero;
    }
  }

  return Cos(expr, isSimplified: true);
}

/// Simplifies a tangent expression $\tan(expr)$.
Expr simplifyTan(Expr expr) {
  if (expr is Number && expr.isZero) return IntegerNumber.zero;

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
    if (piMult.isInteger) {
      return IntegerNumber.zero;
    }
    if (piMult.denominator == const Integer(4)) {
      final rem = (piMult.numerator % const Integer(4)).toInt();
      if (rem == 1) return IntegerNumber.one;
      if (rem == 3) return IntegerNumber.negativeOne;
    }
  }

  return Tan(expr, isSimplified: true);
}

/// Simplifies an arcsine expression $\arcsin(expr)$.
Expr simplifyAsin(Expr expr) {
  if (expr is Number && expr.isZero) return IntegerNumber.zero;
  if (expr is Number && expr.isOne) {
    return Mul([FractionNumber.half, Constant.pi], isSimplified: true);
  }
  if (expr is Number && expr.isNegativeOne) {
    return Mul([FractionNumber.negativeHalf, Constant.pi], isSimplified: true);
  }

  // Involution: asin(sin(u)) = u
  if (expr is Sin) return expr.expr;

  // Parity: asin(-u) = -asin(u)
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(simplifyAsin(posExpr));
  }

  if (isHalf(posExpr)) {
    return Mul([
      const FractionNumber(Integer.one, Integer(6)),
      Constant.pi,
    ], isSimplified: true);
  }
  if (isSqrt2Over2(posExpr)) {
    return Mul([FractionNumber.quarter, Constant.pi], isSimplified: true);
  }
  if (isSqrt3Over2(posExpr)) {
    return Mul([FractionNumber.third, Constant.pi], isSimplified: true);
  }

  return Asin(expr, isSimplified: true);
}

/// Simplifies an arccosine expression $\arccos(expr)$.
Expr simplifyAcos(Expr expr) {
  if (expr is Number && expr.isOne) return IntegerNumber.zero;
  if (expr is Number && expr.isZero) {
    return Mul([FractionNumber.half, Constant.pi], isSimplified: true);
  }
  if (expr is Number && expr.isNegativeOne) {
    return Constant.pi;
  }

  // Involution: acos(cos(u)) = u
  if (expr is Cos) return expr.expr;

  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    if (posExpr is Number && posExpr.isOne) return Constant.pi;
    if (isHalf(posExpr)) {
      return Mul([
        const FractionNumber(Integer.two, Integer(3)),
        Constant.pi,
      ], isSimplified: true);
    }
    if (isSqrt2Over2(posExpr)) {
      return Mul([
        const FractionNumber(Integer(3), Integer(4)),
        Constant.pi,
      ], isSimplified: true);
    }
    if (isSqrt3Over2(posExpr)) {
      return Mul([
        const FractionNumber(Integer(5), Integer(6)),
        Constant.pi,
      ], isSimplified: true);
    }
  }

  if (isHalf(posExpr)) {
    return Mul([FractionNumber.third, Constant.pi], isSimplified: true);
  }
  if (isSqrt2Over2(posExpr)) {
    return Mul([FractionNumber.quarter, Constant.pi], isSimplified: true);
  }
  if (isSqrt3Over2(posExpr)) {
    return Mul([
      const FractionNumber(Integer.one, Integer(6)),
      Constant.pi,
    ], isSimplified: true);
  }

  return Acos(expr, isSimplified: true);
}

/// Simplifies an arctangent expression $\arctan(expr)$.
Expr simplifyAtan(Expr expr) {
  if (expr is Number && expr.isZero) return IntegerNumber.zero;
  if (expr is Number && expr.isOne) {
    return Mul([FractionNumber.quarter, Constant.pi], isSimplified: true);
  }
  if (expr is Number && expr.isNegativeOne) {
    return Mul([
      const FractionNumber(Integer.negativeOne, Integer(4)),
      Constant.pi,
    ], isSimplified: true);
  }

  // Involution: atan(tan(u)) = u
  if (expr is Tan) return expr.expr;

  // Parity: atan(-u) = -atan(u)
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(simplifyAtan(posExpr));
  }

  if (isSqrt3Over3(posExpr)) {
    return Mul([
      const FractionNumber(Integer.one, Integer(6)),
      Constant.pi,
    ], isSimplified: true);
  }
  if (isSqrt3(posExpr)) {
    return Mul([FractionNumber.third, Constant.pi], isSimplified: true);
  }

  return Atan(expr, isSimplified: true);
}

/// Simplifies a hyperbolic sine expression $\sinh(expr)$.
Expr simplifySinh(Expr expr) {
  if (expr is Number && expr.isZero) return IntegerNumber.zero;

  // Parity: sinh(-u) = -sinh(u)
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(simplifySinh(posExpr));
  }

  return Sinh(expr, isSimplified: true);
}

/// Simplifies a hyperbolic cosine expression $\cosh(expr)$.
Expr simplifyCosh(Expr expr) {
  if (expr is Number && expr.isZero) return IntegerNumber.one;

  // Parity: cosh(-u) = cosh(u)
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyCosh(posExpr);
  }

  return Cosh(expr, isSimplified: true);
}

/// Simplifies a hyperbolic tangent expression $\tanh(expr)$.
Expr simplifyTanh(Expr expr) {
  if (expr is Number && expr.isZero) return IntegerNumber.zero;

  // Parity: tanh(-u) = -tanh(u)
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(simplifyTanh(posExpr));
  }

  return Tanh(expr, isSimplified: true);
}

/// Simplifies an absolute value expression $|expr|$.
Expr simplifyAbs(Expr expr) {
  if (expr is RationalNumber) {
    return expr.isNegative ? expr.neg() : expr;
  }
  if (expr is RealNumber) {
    return RealNumber(expr.value.abs());
  }
  // Parity: |-u| = |u|
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyAbs(posExpr);
  }

  if (_isNonNegativeExpr(expr)) {
    return expr;
  }

  return Abs(expr, isSimplified: true);
}

bool _isNonNegativeExpr(Expr expr) => switch (expr) {
  RealNumeric(:final isNegative) => !isNegative,
  Constant(:final value) => value.b == 0 && value.a >= 0,
  Variable(:final domain) => domain == VariableDomain.positive,
  Abs() => true,
  Pow(base: Constant.e) => true,
  Pow(:final base, :final exponent) =>
    _isNonNegativeExpr(base) ||
        (exponent is IntegerNumber && exponent.value.isEven),
  Mul(:final factors) => factors.every(_isNonNegativeExpr),
  _ => false,
};

/// Simplifies an exponential expression $e^{expr}$.
Expr simplifyExp(Expr expr) => simplifyPow(Constant.e, expr);

/// Simplifies a natural logarithm expression $\ln(expr)$.
Expr simplifyLn(Expr expr) {
  if (expr == Constant.e) return IntegerNumber.one;
  if (expr is RealNumeric && (expr.isNegative || expr.isZero)) {
    throw ArgumentError(
      'Natural logarithm domain error: non-positive argument',
    );
  }
  if (expr is Number && expr.isOne) {
    return IntegerNumber.zero;
  }

  // ln(e^u) = u and ln(u^k) = k * ln(u)
  if (expr is Pow) {
    if (expr.base == Constant.e) return expr.exponent;
    return simplifyMul([expr.exponent, Ln(expr.base, isSimplified: true)]);
  }

  return Ln(expr, isSimplified: true);
}

/// Extracts the sign of [expr], returning the non-negative magnitude and sign flag.
(Expr, bool) extractSign(Expr expr) => switch (expr) {
  final RealNumeric n when n.isNegative => (n.neg(), true),
  Mul(factors: [final RealNumeric first, ...final rest])
      when first.isNegative =>
    () {
      final posFirst = first.neg();
      if (posFirst.isOne) {
        return (
          switch (rest) {
            [final single] => single,
            _ => simplifyMul(rest),
          },
          true,
        );
      }
      return (simplifyMul([posFirst, ...rest]), true);
    }(),
  _ => (expr, false),
};

/// Matches if [expr] is a rational multiple of $\pi$.
RationalNumber? matchPiMultiple(Expr expr) => switch (expr) {
  Constant.pi => IntegerNumber.one,
  Mul(factors: [final RationalNumber r, Constant.pi]) ||
  Mul(factors: [Constant.pi, final RationalNumber r]) => r,
  Mul(
    factors: [
      Constant.pi,
      Pow(
        base: IntegerNumber(:final value),
        exponent: IntegerNumber.negativeOne,
      ),
    ],
  ) =>
    RationalNumber.of(Integer.one, value),
  _ => null,
};

/// Simplifies a Lambert W expression $W_b(expr)$.
Expr simplifyLambertW(Expr expr, int branch) {
  if (branch == 0) {
    if (expr is Number && expr.isZero) {
      return IntegerNumber.zero;
    }
    if (expr == Constant.e) {
      return IntegerNumber.one;
    }
  }
  // W(-1 / e) = -1
  if (expr case Mul(
    factors: [
      IntegerNumber.negativeOne,
      Pow(base: Constant.e, exponent: IntegerNumber.negativeOne),
    ],
  )) {
    return IntegerNumber.negativeOne;
  }
  return LambertW(expr, branch: branch, isSimplified: true);
}

/// Simplifies an error function expression $\operatorname{erf}(expr)$.
Expr simplifyErf(Expr expr) {
  if (expr is Number && expr.isZero) {
    return IntegerNumber.zero;
  }
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(simplifyErf(posExpr));
  }
  if (expr == Constant.infinity) {
    return IntegerNumber.one;
  }
  return Erf(expr, isSimplified: true);
}

/// Simplifies a complementary error function expression $\operatorname{erfc}(expr)$.
Expr simplifyErfc(Expr expr) {
  if (expr is Number && expr.isZero) {
    return IntegerNumber.one;
  }
  if (expr == Constant.infinity) {
    return IntegerNumber.zero;
  }
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg && posExpr == Constant.infinity) {
    return IntegerNumber.two;
  }
  return Erfc(expr, isSimplified: true);
}

/// Simplifies an Euler gamma function expression $\Gamma(expr)$.
Expr simplifyGamma(Expr expr) {
  if (expr case IntegerNumber(asInt: final n?) when n > 0 && n <= 18) {
    var fact = Integer.one;
    for (var k = 2; k < n; k++) {
      fact = fact * Integer(k);
    }
    return IntegerNumber(fact);
  }
  if (expr == FractionNumber.half) {
    return Pow(Constant.pi, FractionNumber.half, isSimplified: true);
  }
  return Gamma(expr, isSimplified: true);
}

/// Simplifies an Euler beta function expression $\operatorname{B}(a, b)$.
Expr simplifyBeta(Expr a, Expr b) {
  if (compareStructural(a, b) > 0) {
    return simplifyBeta(b, a);
  }
  if (a case IntegerNumber(asInt: final m?) when m > 0) {
    if (b case IntegerNumber(asInt: final n?) when n > 0 && m + n <= 18) {
      var factM = Integer.one;
      for (var k = 2; k < m; k++) {
        factM = factM * Integer(k);
      }
      var factN = Integer.one;
      for (var k = 2; k < n; k++) {
        factN = factN * Integer(k);
      }
      var factTotal = Integer.one;
      for (var k = 2; k < m + n; k++) {
        factTotal = factTotal * Integer(k);
      }
      return RationalNumber.of(factM * factN, factTotal);
    }
    if (m == 1) {
      return simplifyPow(b, IntegerNumber.negativeOne);
    }
  }
  if (b == IntegerNumber.one) {
    return simplifyPow(a, IntegerNumber.negativeOne);
  }
  return Beta(a, b, isSimplified: true);
}

/// Simplifies an inverse hyperbolic sine expression $\operatorname{asinh}(expr)$.
Expr simplifyAsinh(Expr expr) {
  if (expr is Number && expr.isZero) {
    return IntegerNumber.zero;
  }
  if (expr is Sinh) return expr.expr;
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(simplifyAsinh(posExpr));
  }
  return Asinh(expr, isSimplified: true);
}

/// Simplifies an inverse hyperbolic cosine expression $\operatorname{acosh}(expr)$.
Expr simplifyAcosh(Expr expr) {
  if (expr is Number && expr.isOne) {
    return IntegerNumber.zero;
  }
  if (expr is Cosh) return expr.expr;
  return Acosh(expr, isSimplified: true);
}

/// Simplifies an inverse hyperbolic tangent expression $\operatorname{atanh}(expr)$.
Expr simplifyAtanh(Expr expr) {
  if (expr is Number && expr.isZero) {
    return IntegerNumber.zero;
  }
  if (expr is Tanh) return expr.expr;
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(simplifyAtanh(posExpr));
  }
  return Atanh(expr, isSimplified: true);
}

/// Simplifies a relational expression.
Expr simplifyRelational(RelationalExpr expr) {
  final left = expr.left.simplify();
  final right = expr.right.simplify();
  final vL = realScalarValue(left);
  final vR = realScalarValue(right);
  if (vL != null && vR != null) {
    final matched = switch (expr) {
      LessThan() => vL < vR,
      LessEqual() => vL <= vR,
      GreaterThan() => vL > vR,
      GreaterEqual() => vL >= vR,
      Equal() => vL == vR,
    };
    return matched ? IntegerNumber.one : IntegerNumber.zero;
  }
  return switch (expr) {
    LessThan() => LessThan(left, right, isSimplified: true),
    LessEqual() => LessEqual(left, right, isSimplified: true),
    GreaterThan() => GreaterThan(left, right, isSimplified: true),
    GreaterEqual() => GreaterEqual(left, right, isSimplified: true),
    Equal() => Equal(left, right, isSimplified: true),
  };
}

/// Simplifies a piecewise expression.
Expr simplifyPiecewise(Piecewise expr) {
  final simplifiedBranches = <PiecewiseBranch>[];
  for (final (:relation, expr: branchExpr) in expr.branches) {
    final sCond = relation.simplify();
    if (sCond is Number && sCond.isZero) {
      continue;
    }
    final sExpr = branchExpr.simplify();
    if (sCond is Number && sCond.isOne) {
      if (simplifiedBranches.isEmpty) {
        return sExpr;
      }
      return Piecewise(
        simplifiedBranches,
        otherwise: sExpr,
        isSimplified: true,
      );
    }
    final relCond = sCond is RelationalExpr ? sCond : relation;
    simplifiedBranches.add((relation: relCond, expr: sExpr));
  }
  final sOtherwise = expr.otherwise?.simplify();
  if (simplifiedBranches.isEmpty) {
    return sOtherwise ?? IntegerNumber.zero;
  }
  return Piecewise(
    simplifiedBranches,
    otherwise: sOtherwise,
    isSimplified: true,
  );
}

/// Simplifies a symbolic [Integral] node.
Expr simplifyIntegral(
  Expr integrand,
  String variable, {
  Expr? lower,
  Expr? upper,
}) {
  final sIntegrand = integrand.simplify();
  if (sIntegrand is Number && sIntegrand.isZero) {
    return IntegerNumber.zero;
  }
  final sLower = lower?.simplify();
  final sUpper = upper?.simplify();
  if (sLower != null && sUpper != null && sLower == sUpper) {
    return IntegerNumber.zero;
  }
  return Integral(
    sIntegrand,
    variable,
    lower: sLower,
    upper: sUpper,
    isSimplified: true,
  );
}
