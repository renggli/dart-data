import '../../assumptions.dart';
import '../../ast.dart';
import '../../compiler.dart';
import '../exact_constants.dart';
import '../simplify.dart';
import '../structural_order.dart';

/// Simplifies a sine expression $\sin(expr)$.
Expr simplifySin(Expr expr, {Assumptions assumptions = Assumptions.none}) {
  if (expr is Number && expr.isZero) return IntegerNumber.zero;

  // Involution: sin(asin(u)) = u
  if (expr is Asin) return expr.expr;

  // Parity: sin(-u) = -sin(u)
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(simplifySin(posExpr, assumptions: assumptions));
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
  if (_matchIntegerPiMultiple(expr, assumptions) != null) {
    return IntegerNumber.zero;
  }

  return Sin(expr, isSimplified: true);
}

/// Simplifies a cosine expression $\cos(expr)$.
Expr simplifyCos(Expr expr, {Assumptions assumptions = Assumptions.none}) {
  if (expr is Number && expr.isZero) return IntegerNumber.one;

  // Involution: cos(acos(u)) = u
  if (expr is Acos) return expr.expr;

  // Parity: cos(-u) = cos(u)
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyCos(posExpr, assumptions: assumptions);
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
  if (_matchIntegerPiMultiple(expr, assumptions) case final intFactor?) {
    if (isEvenIntegerExpr(intFactor, assumptions: assumptions)) {
      return IntegerNumber.one;
    }
    return simplifyPow(
      IntegerNumber.negativeOne,
      intFactor,
      assumptions: assumptions,
    );
  }

  return Cos(expr, isSimplified: true);
}

/// Simplifies a tangent expression $\tan(expr)$.
Expr simplifyTan(Expr expr, {Assumptions assumptions = Assumptions.none}) {
  if (expr is Number && expr.isZero) return IntegerNumber.zero;

  // Involution: tan(atan(u)) = u
  if (expr is Atan) return expr.expr;

  // Parity: tan(-u) = -tan(u)
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(simplifyTan(posExpr, assumptions: assumptions));
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
  if (_matchIntegerPiMultiple(expr, assumptions) != null) {
    return IntegerNumber.zero;
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
Expr simplifyAbs(Expr expr, {Assumptions assumptions = Assumptions.none}) {
  if (expr is RationalNumber) {
    return expr.isNegative ? expr.neg() : expr;
  }
  if (expr is RealNumber) {
    return RealNumber(expr.value.abs());
  }
  if (expr case ComplexNumber(:final real, :final imaginary)) {
    return simplifyPow(
      simplifyAdd([
        simplifyPow(real, IntegerNumber.two),
        simplifyPow(imaginary, IntegerNumber.two),
      ]),
      FractionNumber.half,
    );
  }
  // Parity: |-u| = |u|
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyAbs(posExpr, assumptions: assumptions);
  }

  if (expr case Pow(base: Constant.e, :final exponent)
      when !isRealExpr(exponent, assumptions)) {
    final reExp = simplifyRe(exponent, assumptions: assumptions);
    if (reExp is Number && reExp.isZero) {
      return IntegerNumber.one;
    }
    return simplifyPow(Constant.e, reExp, assumptions: assumptions);
  }

  if (isNonNegativeExpr(expr, assumptions: assumptions)) {
    return expr;
  }

  return Abs(expr, isSimplified: true);
}

/// Returns `true` if [expr] is known to be real-valued under [assumptions].
bool isProvenReal(Expr expr, [Assumptions assumptions = Assumptions.none]) =>
    switch (expr) {
      RealNumeric() ||
      Abs() ||
      Re() ||
      Im() ||
      Arg() ||
      Floor() ||
      Ceil() ||
      Round() ||
      Sign() ||
      Factorial() ||
      Binomial() => true,
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
      Pow(:final base, :final exponent) =>
        isProvenReal(base, assumptions) &&
            (exponent is IntegerNumber ||
                isNonNegativeExpr(base, assumptions: assumptions)),
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

/// Returns `true` if [expr] contains no complex numbers, non-real constants,
/// or variables assumed [VariableDomain.complex] under [assumptions].
bool isRealExpr(Expr expr, [Assumptions assumptions = Assumptions.none]) =>
    switch (expr) {
      RealNumeric() || Abs() || Re() || Im() || Arg() => true,
      ComplexNumber(:final imaginary) => imaginary.isZero,
      Constant(:final isReal) => isReal,
      Variable(:final name) =>
        assumptions.domainOf(name) != VariableDomain.complex,
      _ => !expr.anyNode(
        (node) =>
            (node is ComplexNumber && !node.imaginary.isZero) ||
            (node is Constant && !node.isReal) ||
            (node is Variable &&
                assumptions.domainOf(node.name) == VariableDomain.complex),
      ),
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
  Pow(base: Constant.e, :final exponent) => isRealExpr(exponent, assumptions),
  Pow(:final base, :final exponent) =>
    isNonNegativeExpr(base, assumptions: assumptions) ||
        (isRealExpr(base, assumptions) &&
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
      IntegerNumber() ||
      Floor() ||
      Ceil() ||
      Round() ||
      Sign() ||
      Factorial() ||
      Binomial() => true,
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

Expr? _matchIntegerPiMultiple(Expr expr, Assumptions assumptions) {
  if (expr == Constant.pi) return IntegerNumber.one;
  if (expr case Mul(:final factors)) {
    final piIdx = factors.indexOf(Constant.pi);
    if (piIdx != -1) {
      final other = <Expr>[
        for (var i = 0; i < factors.length; i++)
          if (i != piIdx) factors[i],
      ];
      if (other.isNotEmpty &&
          other.every((f) => isIntegerExpr(f, assumptions: assumptions))) {
        return other.length == 1 ? other.first : Mul(other, isSimplified: true);
      }
    }
  }
  return null;
}

/// Simplifies an exponential expression $e^{expr}$.
Expr simplifyExp(Expr expr, {Assumptions assumptions = Assumptions.none}) =>
    simplifyPow(Constant.e, expr, assumptions: assumptions);

/// Simplifies a natural logarithm expression $\ln(expr)$.
Expr simplifyLn(Expr expr, {Assumptions assumptions = Assumptions.none}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr == Constant.e) return IntegerNumber.one;
  if (expr is Number && expr.isZero) {
    return simplifyNeg(Constant.infinity);
  }
  if (expr is RealNumeric && expr.isNegative) {
    final absLn = simplifyLn(expr.abs(), assumptions: assumptions);
    return simplifyAdd([
      absLn,
      Mul([ComplexNumber.i, Constant.pi], isSimplified: true),
    ], assumptions: assumptions);
  }
  if (expr is Number && expr.isOne) {
    return IntegerNumber.zero;
  }
  if (expr == Constant.infinity) {
    return Constant.infinity;
  }

  // ln(e^u) = u
  if (expr is Pow && expr.base == Constant.e) {
    return expr.exponent;
  }

  // ln(u^k)
  if (expr is Pow) {
    final k = expr.exponent;
    final u = expr.base;
    if (k is IntegerNumber && k.value.isEven) {
      if (isPositiveExpr(u, assumptions: assumptions)) {
        return simplifyMul([
          k,
          Ln(u, isSimplified: true),
        ], assumptions: assumptions);
      }
      if (isProvenReal(u, assumptions)) {
        return simplifyMul([
          k,
          Ln(simplifyAbs(u, assumptions: assumptions), isSimplified: true),
        ], assumptions: assumptions);
      }
      return Ln(expr, isSimplified: true);
    }
    return simplifyMul([
      k,
      Ln(u, isSimplified: true),
    ], assumptions: assumptions);
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
    return IntegerNumber(Integer.from(n - 1).factorial());
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
      final factM = Integer.from(m - 1).factorial();
      final factN = Integer.from(n - 1).factorial();
      final factTotal = Integer.from(m + n - 1).factorial();
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
Expr simplifyRelational(
  RelationalExpr expr, {
  Assumptions assumptions = Assumptions.none,
}) {
  final left = expr.left.simplify(assumptions: assumptions);
  final right = expr.right.simplify(assumptions: assumptions);
  final vL = realScalarValue(left);
  final vR = realScalarValue(right);
  if (vL != null && vR != null) {
    final matched = switch (expr) {
      LessThan() => vL < vR,
      LessEqual() => vL <= vR,
      GreaterThan() => vL > vR,
      GreaterEqual() => vL >= vR,
      Equal() => vL == vR,
      NotEqual() => vL != vR,
    };
    return matched ? IntegerNumber.one : IntegerNumber.zero;
  }
  return switch (expr) {
    LessThan() => LessThan(left, right, isSimplified: true),
    LessEqual() => LessEqual(left, right, isSimplified: true),
    GreaterThan() => GreaterThan(left, right, isSimplified: true),
    GreaterEqual() => GreaterEqual(left, right, isSimplified: true),
    Equal() => Equal(left, right, isSimplified: true),
    NotEqual() => NotEqual(left, right, isSimplified: true),
  };
}

/// Simplifies a piecewise expression.
Expr simplifyPiecewise(
  Piecewise expr, {
  Assumptions assumptions = Assumptions.none,
}) {
  final simplifiedBranches = <PiecewiseBranch>[];
  for (final (:relation, expr: branchExpr) in expr.branches) {
    final sCond = relation.simplify(assumptions: assumptions);
    if (sCond is Number && sCond.isZero) {
      continue;
    }
    final sExpr = branchExpr.simplify(assumptions: assumptions);
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
  final sOtherwise = expr.otherwise?.simplify(assumptions: assumptions);
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
  Assumptions assumptions = Assumptions.none,
}) {
  final sIntegrand = integrand.simplify(assumptions: assumptions);
  if (sIntegrand is Number && sIntegrand.isZero) {
    return IntegerNumber.zero;
  }
  final sLower = lower?.simplify(assumptions: assumptions);
  final sUpper = upper?.simplify(assumptions: assumptions);
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

/// Simplifies a symbolic [Derivative] node.
Expr simplifyDerivative(
  Expr expr,
  String variable, {
  int order = 1,
  Assumptions assumptions = Assumptions.none,
}) {
  final sExpr = expr.simplify(assumptions: assumptions);
  if (!sExpr.dependsOn(variable)) {
    return IntegerNumber.zero;
  }
  if (sExpr
      case Derivative(
        expr: final inner,
        variable: final innerVar,
        order: final innerOrder,
      )
      when innerVar == variable) {
    return Derivative(
      inner,
      variable,
      order: innerOrder + order,
      isSimplified: true,
    );
  }
  return Derivative(sExpr, variable, order: order, isSimplified: true);
}

/// Simplifies a symbolic [Limit] node.
Expr simplifyLimit(
  Expr expr,
  String variable,
  Expr point, {
  LimitDirection direction = LimitDirection.both,
  Assumptions assumptions = Assumptions.none,
}) {
  final sExpr = expr.simplify(assumptions: assumptions);
  final sPoint = point.simplify(assumptions: assumptions);
  if (!sExpr.dependsOn(variable)) {
    return sExpr;
  }
  return Limit(
    sExpr,
    variable,
    sPoint,
    direction: direction,
    isSimplified: true,
  );
}

/// Simplifies a factorial expression $n!$.
Expr simplifyFactorial(Expr expr) {
  if (expr case IntegerNumber(asInt: final n?) when n >= 0 && n <= 100) {
    return IntegerNumber(Integer.from(n).factorial());
  }
  if (expr == FractionNumber.negativeHalf) {
    return Pow(Constant.pi, FractionNumber.half, isSimplified: true);
  }
  return Factorial(expr, isSimplified: true);
}

/// Simplifies a binomial coefficient $\binom{n}{k}$.
Expr simplifyBinomial(Expr nExpr, Expr kExpr) {
  if (kExpr is Number && kExpr.isZero) {
    return IntegerNumber.one;
  }
  if (kExpr is Number && kExpr.isOne) {
    return nExpr;
  }
  if (nExpr == kExpr) {
    return IntegerNumber.one;
  }
  if (kExpr case IntegerNumber(:final value) when value.isNegative) {
    return IntegerNumber.zero;
  }
  if (nExpr case IntegerNumber(asInt: final n?) when n >= 0) {
    if (kExpr case IntegerNumber(asInt: final k?)) {
      if (k < 0 || k > n) return IntegerNumber.zero;
      final m = k < n - k ? k : n - k;
      if (m <= 1000) {
        return IntegerNumber(Integer.from(n).binomial(Integer.from(k)));
      }
    }
  }
  return Binomial(nExpr, kExpr, isSimplified: true);
}

/// Simplifies a floor expression $\lfloor x \rfloor$.
Expr simplifyFloor(Expr expr, {Assumptions assumptions = Assumptions.none}) {
  if (isIntegerExpr(expr, assumptions: assumptions)) return expr;
  switch (expr) {
    case IntegerNumber():
      return expr;
    case FractionNumber(:final numerator, :final denominator):
      final q = numerator ~/ denominator;
      return IntegerNumber(
        numerator.isNegative && !(numerator % denominator).isZero
            ? q - Integer.one
            : q,
      );
    case RealNumber(:final value):
      return RealNumber.fromDouble(value.floorToDouble());
    default:
      if (expr.freeVariables.isEmpty) {
        try {
          final v = expr.evaluate();
          if (v.isFinite) return IntegerNumber(Integer.from(v.floor()));
        } on Object {
          // Keep symbolic
        }
      }
      return Floor(expr, isSimplified: true);
  }
}

/// Simplifies a ceiling expression $\lceil x \rceil$.
Expr simplifyCeil(Expr expr, {Assumptions assumptions = Assumptions.none}) {
  if (isIntegerExpr(expr, assumptions: assumptions)) return expr;
  switch (expr) {
    case IntegerNumber():
      return expr;
    case FractionNumber(:final numerator, :final denominator):
      final q = numerator ~/ denominator;
      return IntegerNumber(
        !numerator.isNegative && !(numerator % denominator).isZero
            ? q + Integer.one
            : q,
      );
    case RealNumber(:final value):
      return RealNumber.fromDouble(value.ceilToDouble());
    default:
      if (expr.freeVariables.isEmpty) {
        try {
          final v = expr.evaluate();
          if (v.isFinite) return IntegerNumber(Integer.from(v.ceil()));
        } on Object {
          // Keep symbolic
        }
      }
      return Ceil(expr, isSimplified: true);
  }
}

/// Simplifies a rounding expression $\operatorname{round}(x)$.
Expr simplifyRound(Expr expr, {Assumptions assumptions = Assumptions.none}) {
  if (isIntegerExpr(expr, assumptions: assumptions)) return expr;
  switch (expr) {
    case IntegerNumber():
      return expr;
    case FractionNumber(:final numerator, :final denominator):
      return IntegerNumber(
        Integer.from((numerator.toDouble() / denominator.toDouble()).round()),
      );
    case RealNumber(:final value):
      return RealNumber.fromDouble(value.roundToDouble());
    default:
      if (expr.freeVariables.isEmpty) {
        try {
          final v = expr.evaluate();
          if (v.isFinite) return IntegerNumber(Integer.from(v.round()));
        } on Object {
          // Keep symbolic
        }
      }
      return Round(expr, isSimplified: true);
  }
}

/// Simplifies a signum expression $\operatorname{sgn}(x)$.
Expr simplifySign(Expr expr, {Assumptions assumptions = Assumptions.none}) {
  if (expr is RealNumeric) {
    return IntegerNumber.of(expr.sign);
  }
  if (expr case Variable(:final name)
      when assumptions.domainOf(name) == VariableDomain.positive) {
    return IntegerNumber.one;
  }
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(simplifySign(posExpr, assumptions: assumptions));
  }
  if (expr.freeVariables.isEmpty && isRealExpr(expr, assumptions)) {
    try {
      final v = expr.evaluate();
      if (v.isFinite) {
        return IntegerNumber.of(v == 0.0 ? 0 : (v > 0.0 ? 1 : -1));
      }
    } on Object {
      // Keep symbolic
    }
  }
  return Sign(expr, isSimplified: true);
}

/// Simplifies a modulo expression $a \bmod b$.
Expr simplifyMod(
  Expr left,
  Expr right, {
  Assumptions assumptions = Assumptions.none,
}) {
  if (right is Number && right.isZero) {
    return Constant.undefined;
  }
  if (left is Number && left.isZero) {
    return IntegerNumber.zero;
  }
  if (right is Number &&
      right.isOne &&
      isIntegerExpr(left, assumptions: assumptions)) {
    return IntegerNumber.zero;
  }
  if (left is RationalNumber && right is RationalNumber) {
    final q = simplifyFloor(
      left.divRational(right),
      assumptions: assumptions,
    ) as IntegerNumber;
    return left.subRational(right.mulRational(q));
  }
  if (left is RealNumeric && right is RealNumeric) {
    final a = left.toDouble();
    final b = right.toDouble();
    return RealNumber.fromDouble(a - b * (a / b).floorToDouble());
  }
  return Mod(left, right, isSimplified: true);
}

/// Simplifies a real-part expression $\Re(z)$.
Expr simplifyRe(Expr expr, {Assumptions assumptions = Assumptions.none}) {
  switch (expr) {
    case RealNumeric():
      return expr;
    case ComplexNumber(:final real):
      return real;
    case Re() || Im() || Arg() || Abs():
      return expr;
    case Conjugate(:final expr):
      return simplifyRe(expr, assumptions: assumptions);
    case Add(:final terms):
      return simplifyAdd([
        for (final term in terms) simplifyRe(term, assumptions: assumptions),
      ], assumptions: assumptions);
    case _:
      if (_isSyntacticallyReal(expr, assumptions)) {
        return expr;
      }
      final (:re, :im) = _decomposeComplex(expr, assumptions);
      if (re is! Re || re.expr != expr || im != IntegerNumber.zero) {
        return re;
      }
      return Re(expr, isSimplified: true);
  }
}

/// Simplifies an imaginary-part expression $\Im(z)$.
Expr simplifyIm(Expr expr, {Assumptions assumptions = Assumptions.none}) {
  switch (expr) {
    case RealNumeric() || Re() || Im() || Arg() || Abs():
      return IntegerNumber.zero;
    case ComplexNumber(:final imaginary):
      return imaginary;
    case Conjugate(:final expr):
      return simplifyNeg(simplifyIm(expr, assumptions: assumptions));
    case Add(:final terms):
      return simplifyAdd([
        for (final term in terms) simplifyIm(term, assumptions: assumptions),
      ], assumptions: assumptions);
    case _:
      if (_isSyntacticallyReal(expr, assumptions)) {
        return IntegerNumber.zero;
      }
      final (:re, :im) = _decomposeComplex(expr, assumptions);
      if (im is! Im || im.expr != expr || re != IntegerNumber.zero) {
        return im;
      }
      return Im(expr, isSimplified: true);
  }
}

/// Simplifies a complex argument expression $\arg(z)$.
Expr simplifyArg(Expr expr, {Assumptions assumptions = Assumptions.none}) {
  switch (expr) {
    case RealNumeric(:final isNegative):
      return isNegative ? Constant.pi : IntegerNumber.zero;
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
      return simplifyAtan(
            simplifyMul([
              imaginary,
              simplifyPow(real, IntegerNumber.negativeOne),
            ]),
          ) +
          (real.isNegative
              ? (imaginary.isNegative ? -Constant.pi : Constant.pi)
              : IntegerNumber.zero);
    case Conjugate(:final expr):
      return simplifyNeg(simplifyArg(expr, assumptions: assumptions));
    case _:
      if (isNonNegativeExpr(expr, assumptions: assumptions)) {
        return IntegerNumber.zero;
      }
      return Arg(expr, isSimplified: true);
  }
}

/// Simplifies a complex conjugate expression $\overline{z}$.
Expr simplifyConjugate(
  Expr expr, {
  Assumptions assumptions = Assumptions.none,
}) {
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
      return simplifySinh(simplifyConjugate(expr, assumptions: assumptions));
    case Cosh(:final expr):
      return simplifyCosh(simplifyConjugate(expr, assumptions: assumptions));
    case Tanh(:final expr):
      return simplifyTanh(simplifyConjugate(expr, assumptions: assumptions));
    case _:
      if (_isSyntacticallyReal(expr, assumptions)) {
        return expr;
      }
      return Conjugate(expr, isSimplified: true);
  }
}

/// Rewrites [expr] into rectangular normal form $a + b i$.
Expr toRectangularExpr(
  Expr expr, {
  Assumptions assumptions = Assumptions.none,
}) {
  final simplified = simplifyExpr(expr, assumptions: assumptions);
  final (:re, :im) = _decomposeComplex(simplified, assumptions);
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
  return Add([
    if (re case Add(:final terms)) ...terms else re,
    if (imTerm case Add(:final terms)) ...terms else imTerm,
  ], isSimplified: true);
}

/// Rewrites [expr] into polar normal form $r e^{i \theta}$.
Expr toPolarExpr(Expr expr, {Assumptions assumptions = Assumptions.none}) {
  final simplified = simplifyExpr(expr, assumptions: assumptions);
  if (simplified is Number && simplified.isZero) {
    return IntegerNumber.zero;
  }
  final (:re, :im) = _decomposeComplex(simplified, assumptions);
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
  if (r is Number && r.isZero) {
    return IntegerNumber.zero;
  }
  var theta = simplifyArg(simplified, assumptions: assumptions);
  if (theta is Arg && re is RealNumeric && im is RealNumeric && !im.isZero) {
    theta = simplifyArg(ComplexNumber.of(re, im), assumptions: assumptions);
  }
  if (theta is Number && theta.isZero) {
    return r;
  }
  final expPart = simplifyPow(
    Constant.e,
    simplifyMul([ComplexNumber.i, theta], assumptions: assumptions),
    assumptions: assumptions,
  );
  if (r is Number && r.isOne) {
    return expPart;
  }
  return simplifyMul([r, expPart], assumptions: assumptions);
}

bool _isSyntacticallyReal(Expr expr, Assumptions assumptions) => switch (expr) {
  RealNumeric() => true,
  ComplexNumber() => false,
  Constant(:final isReal) => isReal,
  Variable(:final name) => assumptions.domainOf(name) != VariableDomain.complex,
  Re() ||
  Im() ||
  Arg() ||
  Abs() ||
  Floor() ||
  Ceil() ||
  Round() ||
  Sign() => true,
  Add(:final terms) => terms.every((t) => _isSyntacticallyReal(t, assumptions)),
  Mul(:final factors) => factors.every(
    (f) => _isSyntacticallyReal(f, assumptions),
  ),
  Pow(base: Constant.e, :final exponent) => _isSyntacticallyReal(
    exponent,
    assumptions,
  ),
  Pow(:final base, :final exponent) =>
    (_isSyntacticallyReal(base, assumptions) && exponent is IntegerNumber) ||
        (isNonNegativeExpr(base, assumptions: assumptions) &&
            _isSyntacticallyReal(exponent, assumptions)),
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
  Gamma(:final expr) ||
  Factorial(:final expr) => _isSyntacticallyReal(expr, assumptions),
  Ln(:final expr) => isNonNegativeExpr(expr, assumptions: assumptions),
  Binomial(:final left, :final right) ||
  Beta(:final left, :final right) ||
  Mod(:final left, :final right) =>
    _isSyntacticallyReal(left, assumptions) &&
        _isSyntacticallyReal(right, assumptions),
  _ => false,
};

({Expr re, Expr im}) _decomposeComplex(Expr expr, Assumptions assumptions) {
  if (_isSyntacticallyReal(expr, assumptions)) {
    return (re: expr, im: IntegerNumber.zero);
  }
  switch (expr) {
    case RealNumeric():
      return (re: expr, im: IntegerNumber.zero);
    case ComplexNumber(:final real, :final imaginary):
      return (re: real, im: imaginary);
    case Constant(:final value):
      return (
        re: RealNumber.fromDouble(value.real.toDouble()),
        im: RealNumber.fromDouble(value.imaginary.toDouble()),
      );
    case Variable():
      return (
        re: Re(expr, isSimplified: true),
        im: Im(expr, isSimplified: true),
      );
    case Conjugate(:final expr):
      final (:re, :im) = _decomposeComplex(expr, assumptions);
      return (re: re, im: simplifyNeg(im));
    case Re(:final expr):
      return (
        re: _decomposeComplex(expr, assumptions).re,
        im: IntegerNumber.zero,
      );
    case Im(:final expr):
      return (
        re: _decomposeComplex(expr, assumptions).im,
        im: IntegerNumber.zero,
      );
    case Add(:final terms):
      final reTerms = <Expr>[];
      final imTerms = <Expr>[];
      for (final term in terms) {
        final (:re, :im) = _decomposeComplex(term, assumptions);
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
        final (:re, :im) = _decomposeComplex(factor, assumptions);
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
      final (:re, :im) = _decomposeComplex(exponent, assumptions);
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
      final (:re, :im) = _decomposeComplex(base, assumptions);
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
      final (:re, :im) = _decomposeComplex(expr, assumptions);
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
      final (:re, :im) = _decomposeComplex(expr, assumptions);
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
      final (:re, :im) = _decomposeComplex(expr, assumptions);
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
      final (:re, :im) = _decomposeComplex(expr, assumptions);
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
    default:
      return (
        re: Re(expr, isSimplified: true),
        im: Im(expr, isSimplified: true),
      );
  }
}
