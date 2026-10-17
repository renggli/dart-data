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
  if (_matchIntegerPiMultiple(expr) != null) {
    return IntegerNumber.zero;
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
  if (_matchIntegerPiMultiple(expr) case final intFactor?) {
    if (isEvenIntegerExpr(intFactor)) {
      return IntegerNumber.one;
    }
    return simplifyPow(IntegerNumber.negativeOne, intFactor);
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
  if (_matchIntegerPiMultiple(expr) != null) {
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
    return simplifyAbs(posExpr);
  }

  if (expr case Pow(base: Constant.e, :final exponent) when !exponent.isReal) {
    final reExp = simplifyRe(exponent);
    if (reExp is Number && reExp.isZero) {
      return IntegerNumber.one;
    }
    return simplifyPow(Constant.e, reExp);
  }

  if (isNonNegativeExpr(expr)) {
    return expr;
  }

  return Abs(expr, isSimplified: true);
}

/// Returns `true` if [expr] is syntactically non-negative under active domain assumptions.
bool isNonNegativeExpr(Expr expr) => switch (expr) {
  RealNumeric(:final isNegative) => !isNegative,
  Constant(:final value) => value.b == 0 && value.a >= 0,
  Variable(:final domain) => domain == VariableDomain.positive,
  Abs() => true,
  Pow(base: Constant.e, :final exponent) => exponent.isReal,
  Pow(:final base, :final exponent) =>
    isNonNegativeExpr(base) ||
        (base.isReal && exponent is IntegerNumber && exponent.value.isEven),
  Mul(:final factors) => factors.every(isNonNegativeExpr),
  _ => false,
};

/// Returns `true` if [expr] is syntactically integer-valued under active domain assumptions.
bool isIntegerExpr(Expr expr) => switch (expr) {
  IntegerNumber() ||
  Floor() ||
  Ceil() ||
  Round() ||
  Sign() ||
  Factorial() ||
  Binomial() => true,
  Variable(:final domain) => domain == VariableDomain.integer,
  Add(:final terms) => terms.every(isIntegerExpr),
  Mul(:final factors) => factors.every(isIntegerExpr),
  Pow(:final base, :final exponent) =>
    isIntegerExpr(base) && exponent is IntegerNumber && !exponent.isNegative,
  _ => false,
};

/// Returns `true` if [expr] is an even integer expression under active domain assumptions.
bool isEvenIntegerExpr(Expr expr) => switch (expr) {
  IntegerNumber(:final value) => value.isEven,
  Mul(:final factors) =>
    factors.every(isIntegerExpr) && factors.any(isEvenIntegerExpr),
  Add(:final terms) => terms.every(isEvenIntegerExpr),
  Pow(:final base, :final exponent) =>
    isEvenIntegerExpr(base) &&
        exponent is IntegerNumber &&
        exponent.value > Integer.zero,
  _ => false,
};

Expr? _matchIntegerPiMultiple(Expr expr) {
  if (expr == Constant.pi) return IntegerNumber.one;
  if (expr case Mul(:final factors)) {
    final piIdx = factors.indexOf(Constant.pi);
    if (piIdx != -1) {
      final other = <Expr>[
        for (var i = 0; i < factors.length; i++)
          if (i != piIdx) factors[i],
      ];
      if (other.isNotEmpty && other.every(isIntegerExpr)) {
        return other.length == 1 ? other.first : Mul(other, isSimplified: true);
      }
    }
  }
  return null;
}

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

/// Simplifies a symbolic [Derivative] node.
Expr simplifyDerivative(Expr expr, String variable, {int order = 1}) {
  final sExpr = expr.simplify();
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
}) {
  final sExpr = expr.simplify();
  final sPoint = point.simplify();
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
    var fact = Integer.one;
    for (var k = 2; k <= n; k++) {
      fact = fact * Integer(k);
    }
    return IntegerNumber(fact);
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
        var res = Integer.one;
        for (var i = 1; i <= m; i++) {
          res = (res * Integer(n - m + i)) ~/ Integer(i);
        }
        return IntegerNumber(res);
      }
    }
  }
  return Binomial(nExpr, kExpr, isSimplified: true);
}

/// Simplifies a floor expression $\lfloor x \rfloor$.
Expr simplifyFloor(Expr expr) {
  if (isIntegerExpr(expr)) return expr;
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
Expr simplifyCeil(Expr expr) {
  if (isIntegerExpr(expr)) return expr;
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
Expr simplifyRound(Expr expr) {
  if (isIntegerExpr(expr)) return expr;
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
Expr simplifySign(Expr expr) {
  if (expr is RealNumeric) {
    return IntegerNumber.of(expr.sign);
  }
  if (expr case Variable(domain: VariableDomain.positive)) {
    return IntegerNumber.one;
  }
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(simplifySign(posExpr));
  }
  if (expr.freeVariables.isEmpty && expr.isReal) {
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
Expr simplifyMod(Expr left, Expr right) {
  if (right is Number && right.isZero) {
    return Constant.undefined;
  }
  if (left is Number && left.isZero) {
    return IntegerNumber.zero;
  }
  if (right is Number && right.isOne && isIntegerExpr(left)) {
    return IntegerNumber.zero;
  }
  if (left is RationalNumber && right is RationalNumber) {
    final q = simplifyFloor(left.divRational(right)) as IntegerNumber;
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
Expr simplifyRe(Expr expr) {
  switch (expr) {
    case RealNumeric():
      return expr;
    case ComplexNumber(:final real):
      return real;
    case Re() || Im() || Arg() || Abs():
      return expr;
    case Conjugate(:final expr):
      return simplifyRe(expr);
    case Add(:final terms):
      return simplifyAdd([for (final term in terms) simplifyRe(term)]);
    case _:
      if (_isSyntacticallyReal(expr)) {
        return expr;
      }
      final (:re, :im) = _decomposeComplex(expr);
      if (re is! Re || re.expr != expr || im != IntegerNumber.zero) {
        return re;
      }
      return Re(expr, isSimplified: true);
  }
}

/// Simplifies an imaginary-part expression $\Im(z)$.
Expr simplifyIm(Expr expr) {
  switch (expr) {
    case RealNumeric() || Re() || Im() || Arg() || Abs():
      return IntegerNumber.zero;
    case ComplexNumber(:final imaginary):
      return imaginary;
    case Conjugate(:final expr):
      return simplifyNeg(simplifyIm(expr));
    case Add(:final terms):
      return simplifyAdd([for (final term in terms) simplifyIm(term)]);
    case _:
      if (_isSyntacticallyReal(expr)) {
        return IntegerNumber.zero;
      }
      final (:re, :im) = _decomposeComplex(expr);
      if (im is! Im || im.expr != expr || re != IntegerNumber.zero) {
        return im;
      }
      return Im(expr, isSimplified: true);
  }
}

/// Simplifies a complex argument expression $\arg(z)$.
Expr simplifyArg(Expr expr) {
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
      return simplifyNeg(simplifyArg(expr));
    case _:
      if (isNonNegativeExpr(expr)) {
        return IntegerNumber.zero;
      }
      return Arg(expr, isSimplified: true);
  }
}

/// Simplifies a complex conjugate expression $\overline{z}$.
Expr simplifyConjugate(Expr expr) {
  switch (expr) {
    case RealNumeric() || Re() || Im() || Arg() || Abs() || OrderTerm():
      return expr;
    case ComplexNumber():
      return expr.conjugate;
    case Conjugate(:final expr):
      return expr;
    case Add(:final terms):
      return simplifyAdd([for (final term in terms) simplifyConjugate(term)]);
    case Mul(:final factors):
      return simplifyMul([
        for (final factor in factors) simplifyConjugate(factor),
      ]);
    case Pow(base: Constant.e, :final exponent):
      return simplifyPow(Constant.e, simplifyConjugate(exponent));
    case Pow(:final base, :final exponent) when exponent is IntegerNumber:
      return simplifyPow(simplifyConjugate(base), exponent);
    case Sin(:final expr):
      return simplifySin(simplifyConjugate(expr));
    case Cos(:final expr):
      return simplifyCos(simplifyConjugate(expr));
    case Tan(:final expr):
      return simplifyTan(simplifyConjugate(expr));
    case Sinh(:final expr):
      return simplifySinh(simplifyConjugate(expr));
    case Cosh(:final expr):
      return simplifyCosh(simplifyConjugate(expr));
    case Tanh(:final expr):
      return simplifyTanh(simplifyConjugate(expr));
    case _:
      if (_isSyntacticallyReal(expr)) {
        return expr;
      }
      return Conjugate(expr, isSimplified: true);
  }
}

/// Rewrites [expr] into rectangular normal form $a + b i$.
Expr toRectangularExpr(Expr expr) {
  final simplified = simplifyExpr(expr);
  final (:re, :im) = _decomposeComplex(simplified);
  if (im is Number && im.isZero) {
    return re;
  }
  if (re is RealNumeric && im is RealNumeric) {
    return ComplexNumber.of(re, im);
  }
  final imTerm = simplifyMul([ComplexNumber.i, im]);
  if (re is Number && re.isZero) {
    return imTerm;
  }
  return Add([
    if (re case Add(:final terms)) ...terms else re,
    if (imTerm case Add(:final terms)) ...terms else imTerm,
  ], isSimplified: true);
}

/// Rewrites [expr] into polar normal form $r e^{i \theta}$.
Expr toPolarExpr(Expr expr) {
  final simplified = simplifyExpr(expr);
  if (simplified is Number && simplified.isZero) {
    return IntegerNumber.zero;
  }
  final (:re, :im) = _decomposeComplex(simplified);
  var r = simplifyAbs(simplified);
  if (r is Abs && !(im is Number && im.isZero)) {
    r = simplifyPow(
      simplifyAdd([
        simplifyPow(re, IntegerNumber.two),
        simplifyPow(im, IntegerNumber.two),
      ]),
      FractionNumber.half,
    );
  }
  if (r is Number && r.isZero) {
    return IntegerNumber.zero;
  }
  var theta = simplifyArg(simplified);
  if (theta is Arg && re is RealNumeric && im is RealNumeric && !im.isZero) {
    theta = simplifyArg(ComplexNumber.of(re, im));
  }
  if (theta is Number && theta.isZero) {
    return r;
  }
  final expPart = simplifyPow(
    Constant.e,
    simplifyMul([ComplexNumber.i, theta]),
  );
  if (r is Number && r.isOne) {
    return expPart;
  }
  return simplifyMul([r, expPart]);
}

bool _isSyntacticallyReal(Expr expr) => switch (expr) {
  RealNumeric() => true,
  ComplexNumber() => false,
  Constant(:final isReal) => isReal,
  Variable(:final domain) => domain != VariableDomain.complex,
  Re() ||
  Im() ||
  Arg() ||
  Abs() ||
  Floor() ||
  Ceil() ||
  Round() ||
  Sign() => true,
  Add(:final terms) => terms.every(_isSyntacticallyReal),
  Mul(:final factors) => factors.every(_isSyntacticallyReal),
  Pow(base: Constant.e, :final exponent) => _isSyntacticallyReal(exponent),
  Pow(:final base, :final exponent) =>
    (_isSyntacticallyReal(base) && exponent is IntegerNumber) ||
        (isNonNegativeExpr(base) && _isSyntacticallyReal(exponent)),
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
  Factorial(:final expr) => _isSyntacticallyReal(expr),
  Ln(:final expr) => isNonNegativeExpr(expr),
  Binomial(:final left, :final right) ||
  Beta(:final left, :final right) ||
  Mod(
    :final left,
    :final right,
  ) => _isSyntacticallyReal(left) && _isSyntacticallyReal(right),
  _ => false,
};

({Expr re, Expr im}) _decomposeComplex(Expr expr) {
  if (_isSyntacticallyReal(expr)) {
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
      final (:re, :im) = _decomposeComplex(expr);
      return (re: re, im: simplifyNeg(im));
    case Re(:final expr):
      return (re: _decomposeComplex(expr).re, im: IntegerNumber.zero);
    case Im(:final expr):
      return (re: _decomposeComplex(expr).im, im: IntegerNumber.zero);
    case Add(:final terms):
      final reTerms = <Expr>[];
      final imTerms = <Expr>[];
      for (final term in terms) {
        final (:re, :im) = _decomposeComplex(term);
        reTerms.add(re);
        imTerms.add(im);
      }
      return (re: simplifyAdd(reTerms), im: simplifyAdd(imTerms));
    case Mul(:final factors):
      var accRe = IntegerNumber.one as Expr;
      var accIm = IntegerNumber.zero as Expr;
      for (final factor in factors) {
        final (:re, :im) = _decomposeComplex(factor);
        final nextRe = simplifyAdd([
          simplifyMul([accRe, re]),
          simplifyNeg(simplifyMul([accIm, im])),
        ]);
        final nextIm = simplifyAdd([
          simplifyMul([accRe, im]),
          simplifyMul([accIm, re]),
        ]);
        accRe = nextRe;
        accIm = nextIm;
      }
      return (re: accRe, im: accIm);
    case Pow(base: Constant.e, :final exponent):
      final (:re, :im) = _decomposeComplex(exponent);
      final mag = simplifyPow(Constant.e, re);
      return (
        re: simplifyMul([mag, simplifyCos(im)]),
        im: simplifyMul([mag, simplifySin(im)]),
      );
    case Pow(:final base, exponent: IntegerNumber(asInt: final n?))
        when n >= -6 && n <= 6:
      final (:re, :im) = _decomposeComplex(base);
      if (n == 0) return (re: IntegerNumber.one, im: IntegerNumber.zero);
      final absN = n.abs();
      var powRe = re;
      var powIm = im;
      for (var i = 1; i < absN; i++) {
        final nextRe = simplifyAdd([
          simplifyMul([powRe, re]),
          simplifyNeg(simplifyMul([powIm, im])),
        ]);
        final nextIm = simplifyAdd([
          simplifyMul([powRe, im]),
          simplifyMul([powIm, re]),
        ]);
        powRe = nextRe;
        powIm = nextIm;
      }
      if (n < 0) {
        final denom = simplifyAdd([
          simplifyPow(powRe, IntegerNumber.two),
          simplifyPow(powIm, IntegerNumber.two),
        ]);
        final invDenom = simplifyPow(denom, IntegerNumber.negativeOne);
        return (
          re: simplifyMul([powRe, invDenom]),
          im: simplifyNeg(simplifyMul([powIm, invDenom])),
        );
      }
      return (re: powRe, im: powIm);
    case Sin(:final expr):
      final (:re, :im) = _decomposeComplex(expr);
      return (
        re: simplifyMul([simplifySin(re), simplifyCosh(im)]),
        im: simplifyMul([simplifyCos(re), simplifySinh(im)]),
      );
    case Cos(:final expr):
      final (:re, :im) = _decomposeComplex(expr);
      return (
        re: simplifyMul([simplifyCos(re), simplifyCosh(im)]),
        im: simplifyNeg(simplifyMul([simplifySin(re), simplifySinh(im)])),
      );
    case Sinh(:final expr):
      final (:re, :im) = _decomposeComplex(expr);
      return (
        re: simplifyMul([simplifySinh(re), simplifyCos(im)]),
        im: simplifyMul([simplifyCosh(re), simplifySin(im)]),
      );
    case Cosh(:final expr):
      final (:re, :im) = _decomposeComplex(expr);
      return (
        re: simplifyMul([simplifyCosh(re), simplifyCos(im)]),
        im: simplifyMul([simplifySinh(re), simplifySin(im)]),
      );
    default:
      return (
        re: Re(expr, isSimplified: true),
        im: Im(expr, isSimplified: true),
      );
  }
}
