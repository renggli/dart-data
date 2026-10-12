import 'dart:math' as math;

import 'package:more/number.dart' show Fraction;

import 'ast.dart';

extension on Fraction {
  bool get isZero => a == 0;
}

/// Canonical algebraic simplification extension on [Expr].
extension SimplifierExtension on Expr {
  /// Canonically simplifies this expression by performing constant folding,
  /// like-term and like-factor reductions, and algebraic canonicalization.
  ///
  /// Conceptually, this simplifies expressions using algebraic identities such
  /// as $x + x \to 2x$, $x \cdot x \to x^2$, $x + 0 \to x$, $x \cdot 1 \to x$,
  /// evaluates constant sub-expressions such as $2 + 3 \to 5$, and canonicalizes
  /// polynomial terms in descending order of power and degree. Formally, this
  /// executes confluent rewriting rules to reduce algebraic expressions into
  /// canonical normal form.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final expr = (x + 1) + (x + 2);
  /// final s = expr.simplify(); // 2 * x + 3
  /// ```
  Expr simplify() => _simplify(this);
}

Expr _simplify(Expr expr) => switch (expr) {
  Number() || Variable() => expr,
  Add(:final left, :final right) => _simplifyAdd(
    _simplify(left),
    _simplify(right),
  ),
  Sub(:final left, :final right) => _simplifySub(
    _simplify(left),
    _simplify(right),
  ),
  Mul(:final left, :final right) => _simplifyMul(
    _simplify(left),
    _simplify(right),
  ),
  Div(:final left, :final right) => _simplifyDiv(
    _simplify(left),
    _simplify(right),
  ),
  Pow(:final base, :final exponent) => _simplifyPow(
    _simplify(base),
    _simplify(exponent),
  ),
  Neg(:final expr) => _simplifyNeg(_simplify(expr)),
  Sin(:final expr) => _simplifySin(_simplify(expr)),
  Cos(:final expr) => _simplifyCos(_simplify(expr)),
  Tan(:final expr) => _simplifyTan(_simplify(expr)),
  Asin(:final expr) => _simplifyAsin(_simplify(expr)),
  Acos(:final expr) => _simplifyAcos(_simplify(expr)),
  Atan(:final expr) => _simplifyAtan(_simplify(expr)),
  Sinh(:final expr) => _simplifySinh(_simplify(expr)),
  Cosh(:final expr) => _simplifyCosh(_simplify(expr)),
  Tanh(:final expr) => _simplifyTanh(_simplify(expr)),
  Abs(:final expr) => _simplifyAbs(_simplify(expr)),
  Sqrt(:final expr) => _simplifySqrt(_simplify(expr)),
  Exp(:final expr) => _simplifyExp(_simplify(expr)),
  Ln(:final expr) => _simplifyLn(_simplify(expr)),
  Log(:final base, :final expr) => _simplifyLog(
    _simplify(base),
    _simplify(expr),
  ),
};

Expr _simplifyAdd(Expr left, Expr right) =>
    _simplifyAdditive(left, right, isSubtraction: false);

Expr _simplifySub(Expr left, Expr right) =>
    _simplifyAdditive(left, right, isSubtraction: true);

Expr _simplifyAdditive(Expr left, Expr right, {required bool isSubtraction}) {
  // Fast paths for zero identities and constant evaluation
  if (!isSubtraction) {
    if (left is RationalNumber && left.isZero) return right;
    if (right is RationalNumber && right.isZero) return left;
    if (left is RealNumber && left.value == 0.0) return right;
    if (right is RealNumber && right.value == 0.0) return left;
    if (left is RationalNumber && right is RationalNumber) {
      return RationalNumber.fraction(left.toFraction() + right.toFraction());
    }
    if (left is RealNumber && right is RealNumber) {
      return RealNumber(left.value + right.value);
    }
  } else {
    if (left == right) return RationalNumber.zero;
    if (right is RationalNumber && right.isZero) return left;
    if (right is RealNumber && right.value == 0.0) return left;
    if (left is RationalNumber && left.isZero) return _simplifyNeg(right);
    if (left is RealNumber && left.value == 0.0) return _simplifyNeg(right);
    if (left is RationalNumber && right is RationalNumber) {
      return RationalNumber.fraction(left.toFraction() - right.toFraction());
    }
    if (left is RealNumber && right is RealNumber) {
      return RealNumber(left.value - right.value);
    }
  }

  final acc = _TermAccumulator();
  acc.add(left, Fraction.one);
  acc.add(right, isSubtraction ? -Fraction.one : Fraction.one);

  acc.reduceIdentities();

  // Filter out terms with zero coefficient
  acc.terms.removeWhere((_, coeff) => coeff.isZero);

  // If no symbolic terms exist and no real value, return rational constant value
  if (acc.terms.isEmpty && acc.realValue == 0.0) {
    if (acc.constantValue.isZero) return RationalNumber.zero;
    return RationalNumber.fraction(acc.constantValue);
  }

  // Single symbolic term with no constants
  if (acc.terms.length == 1 &&
      acc.constantValue.isZero &&
      acc.realValue == 0.0) {
    final entry = acc.terms.entries.first;
    final base = entry.key;
    final coeff = entry.value;
    if (coeff == Fraction.one) return base;
    if (coeff == -Fraction.one) return _simplifyNeg(base);
    return Mul(RationalNumber.fraction(coeff), base);
  }

  // Sort terms canonically: descending power/degree for polynomial terms
  final sortedEntries = acc.terms.entries.toList()
    ..sort((a, b) => _compareTerms(a.key, a.value, b.key, b.value));

  Expr? result;
  for (final entry in sortedEntries) {
    final base = entry.key;
    final coeff = entry.value;

    if (result == null) {
      if (coeff == Fraction.one) {
        result = base;
      } else if (coeff == -Fraction.one) {
        result = _simplifyNeg(base);
      } else {
        result = Mul(RationalNumber.fraction(coeff), base);
      }
    } else {
      if (coeff > Fraction.zero) {
        final term = coeff == Fraction.one
            ? base
            : Mul(RationalNumber.fraction(coeff), base);
        result = Add(result, term);
      } else {
        final absCoeff = -coeff;
        final term = absCoeff == Fraction.one
            ? base
            : Mul(RationalNumber.fraction(absCoeff), base);
        result = Sub(result, term);
      }
    }
  }

  if (!acc.constantValue.isZero) {
    if (result == null) {
      result = RationalNumber.fraction(acc.constantValue);
    } else if (acc.constantValue > Fraction.zero) {
      result = Add(result, RationalNumber.fraction(acc.constantValue));
    } else {
      result = Sub(result, RationalNumber.fraction(-acc.constantValue));
    }
  }

  if (acc.realValue != 0.0) {
    if (result == null) {
      result = RealNumber(acc.realValue);
    } else if (acc.realValue > 0.0) {
      result = Add(result, RealNumber(acc.realValue));
    } else {
      result = Sub(result, RealNumber(-acc.realValue));
    }
  }

  return result ?? RationalNumber.zero;
}

Expr _simplifyMul(Expr left, Expr right) {
  // Annihilator: 0 * x = x * 0 = 0
  if (left is RationalNumber && left.isZero) return RationalNumber.zero;
  if (right is RationalNumber && right.isZero) return RationalNumber.zero;
  if (left is RealNumber && left.value == 0.0) return RationalNumber.zero;
  if (right is RealNumber && right.value == 0.0) return RationalNumber.zero;

  // Multiplicative identity: 1 * x = x, x * 1 = x
  if (left is RationalNumber && left.isOne) return right;
  if (right is RationalNumber && right.isOne) return left;
  if (left is RealNumber && left.value == 1.0) return right;
  if (right is RealNumber && right.value == 1.0) return left;

  // Negation: -1 * x = -x, x * -1 = -x
  if (left is RationalNumber && left.isNegativeOne) return _simplifyNeg(right);
  if (right is RationalNumber && right.isNegativeOne) return _simplifyNeg(left);
  if (left is RealNumber && left.value == -1.0) return _simplifyNeg(right);
  if (right is RealNumber && right.value == -1.0) return _simplifyNeg(left);

  // Two numbers:
  if (left is RationalNumber && right is RationalNumber) {
    return RationalNumber.fraction(left.toFraction() * right.toFraction());
  }
  if (left is RealNumber && right is RealNumber) {
    return RealNumber(left.value * right.value);
  }

  // Exponential multiplication: e^a * e^b => e^(a + b)
  if (left is Exp && right is Exp) {
    return _simplifyExp(_simplifyAdd(left.expr, right.expr));
  }
  // Radical multiplication: sqrt(a) * sqrt(b) => sqrt(a * b)
  if (left is Sqrt && right is Sqrt) {
    return _simplifySqrt(_simplifyMul(left.expr, right.expr));
  }

  // Associative constant folding:
  // (expr * c1) * c2 => expr * (c1 * c2)
  if (left is Mul && left.right is RationalNumber && right is RationalNumber) {
    return _simplifyMul(
      left.left,
      RationalNumber.fraction(
        (left.right as RationalNumber).toFraction() * right.toFraction(),
      ),
    );
  }
  // (c1 * expr) * c2 => (c1 * c2) * expr
  if (left is Mul && left.left is RationalNumber && right is RationalNumber) {
    return _simplifyMul(
      RationalNumber.fraction(
        (left.left as RationalNumber).toFraction() * right.toFraction(),
      ),
      left.right,
    );
  }
  // c1 * (c2 * expr) => (c1 * c2) * expr
  if (left is RationalNumber && right is Mul && right.left is RationalNumber) {
    return _simplifyMul(
      RationalNumber.fraction(
        left.toFraction() * (right.left as RationalNumber).toFraction(),
      ),
      right.right,
    );
  }
  // c1 * (expr * c2) => (c1 * c2) * expr
  if (left is RationalNumber && right is Mul && right.right is RationalNumber) {
    return _simplifyMul(
      RationalNumber.fraction(
        left.toFraction() * (right.right as RationalNumber).toFraction(),
      ),
      right.left,
    );
  }

  // Pull out constant scalar from left or right to fold factors:
  // (c1 * inner) * right => c1 * (inner * right)
  if (left is Mul && left.left is RationalNumber) {
    final c1 = left.left as RationalNumber;
    final sub = _simplifyMul(left.right, right);
    return _simplifyMul(c1, sub);
  }
  // (inner * c1) * right => c1 * (inner * right)
  if (left is Mul && left.right is RationalNumber) {
    final c1 = left.right as RationalNumber;
    final sub = _simplifyMul(left.left, right);
    return _simplifyMul(c1, sub);
  }
  // left * (c2 * inner) => c2 * (left * inner)
  if (right is Mul && right.left is RationalNumber) {
    final c2 = right.left as RationalNumber;
    final sub = _simplifyMul(left, right.right);
    return _simplifyMul(c2, sub);
  }
  // left * (inner * c2) => c2 * (left * inner)
  if (right is Mul && right.right is RationalNumber) {
    final c2 = right.right as RationalNumber;
    final sub = _simplifyMul(left, right.left);
    return _simplifyMul(c2, sub);
  }

  // Like-factor multiplications:
  // x * x => x ^ 2, x^a * x^b => x^(a+b)
  final (baseL, expL) = _decomposeFactor(left);
  final (baseR, expR) = _decomposeFactor(right);
  if (baseL == baseR) {
    final newExp = _simplifyAdd(expL, expR);
    return _simplifyPow(baseL, newExp);
  }

  // Associative like-factor multiplications:
  // (a * b) * c where b and c have same base => a * (b * c)
  if (left is Mul) {
    final (baseSubR, _) = _decomposeFactor(left.right);
    if (baseSubR == baseR) {
      return _simplifyMul(left.left, _simplifyMul(left.right, right));
    }
    final (baseSubL, _) = _decomposeFactor(left.left);
    if (baseSubL == baseR) {
      return _simplifyMul(_simplifyMul(left.left, right), left.right);
    }
  }
  if (right is Mul) {
    final (baseSubL, _) = _decomposeFactor(right.left);
    if (baseSubL == baseL) {
      return _simplifyMul(_simplifyMul(left, right.left), right.right);
    }
    final (baseSubR, _) = _decomposeFactor(right.right);
    if (baseSubR == baseL) {
      return _simplifyMul(right.left, _simplifyMul(left, right.right));
    }
  }

  // Put constant on the left if on the right: expr * c => c * expr
  if (right is Number && left is! Number) {
    return _simplifyMul(right, left);
  }

  return Mul(left, right);
}

Expr _simplifyDiv(Expr left, Expr right) {
  if (right is RationalNumber && right.isZero) {
    throw UnsupportedError('Division by zero in simplification');
  }
  if (right is RealNumber && right.value == 0.0) {
    throw UnsupportedError('Division by zero in simplification');
  }
  if (left == right) return RationalNumber.one;
  if (left is RationalNumber && left.isZero) return RationalNumber.zero;
  if (left is RealNumber && left.value == 0.0) return RationalNumber.zero;
  if (left is RationalNumber && right is RationalNumber) {
    return RationalNumber.fraction(left.toFraction() / right.toFraction());
  }
  if (left is RealNumber && right is RealNumber) {
    return RealNumber(left.value / right.value);
  }

  // Exponential division: e^a / e^b => e^(a - b)
  if (left is Exp && right is Exp) {
    return _simplifyExp(_simplifySub(left.expr, right.expr));
  }
  // Radical division: sqrt(a) / sqrt(b) => sqrt(a / b)
  if (left is Sqrt && right is Sqrt) {
    return _simplifySqrt(_simplifyDiv(left.expr, right.expr));
  }
  if (right is RationalNumber && right.isOne) return left;
  if (right is RealNumber && right.value == 1.0) return left;
  if (right is RationalNumber && right.isNegativeOne) return _simplifyNeg(left);
  if (right is RealNumber && right.value == -1.0) return _simplifyNeg(left);

  // Canonicalize expr / RationalNumber(c) => RationalNumber(1/c) * expr
  if (right is RationalNumber) {
    return _simplifyMul(
      RationalNumber.fraction(Fraction.one / right.toFraction()),
      left,
    );
  }

  // Like factors: x^a / x^b => x^(a - b)
  final (baseL, expL) = _decomposeFactor(left);
  final (baseR, expR) = _decomposeFactor(right);
  if (baseL == baseR) {
    final newExp = _simplifySub(expL, expR);
    return _simplifyPow(baseL, newExp);
  }

  // Mul numerator: (c * r) / r => c, (a * b) / r
  if (left is Mul) {
    final (baseSubL, _) = _decomposeFactor(left.left);
    if (baseSubL == baseR) {
      return _simplifyMul(_simplifyDiv(left.left, right), left.right);
    }
    final (baseSubR, _) = _decomposeFactor(left.right);
    if (baseSubR == baseR) {
      return _simplifyMul(left.left, _simplifyDiv(left.right, right));
    }
  }

  // Distribute over Add / Sub if both parts simplify cleanly:
  if (left is Add) {
    final dL = _simplifyDiv(left.left, right);
    final dR = _simplifyDiv(left.right, right);
    if (dL is! Div && dR is! Div) {
      return _simplifyAdd(dL, dR);
    }
  }
  if (left is Sub) {
    final dL = _simplifyDiv(left.left, right);
    final dR = _simplifyDiv(left.right, right);
    if (dL is! Div && dR is! Div) {
      return _simplifySub(dL, dR);
    }
  }

  return Div(left, right);
}

Expr _simplifyPow(Expr base, Expr exponent) => switch ((base, exponent)) {
  (_, RationalNumber(isZero: true)) => RationalNumber.one,
  (final b, RationalNumber(isOne: true)) => b,
  (_, RealNumber(value: 0.0)) => RationalNumber.one,
  (final b, RealNumber(value: 1.0)) => b,
  (RationalNumber(isZero: true), _) => RationalNumber.zero,
  (RealNumber(value: 0.0), _) => RationalNumber.zero,
  (RationalNumber(isOne: true), _) => RationalNumber.one,
  (RealNumber(value: 1.0), _) => RationalNumber.one,
  (ConstantNumber(name: 'e'), final exponent) => Exp(exponent),
  (
    RationalNumber(:final numerator, :final denominator),
    RationalNumber(isInteger: true, numerator: final expInt),
  ) =>
    _foldRationalPower(numerator, denominator, expInt),
  (RationalNumber() && final b, RationalNumber() && final e) =>
    _foldGeneralPower(b, e),
  (
    Pow(base: final innerBase, exponent: RationalNumber() && final e1),
    RationalNumber() && final e2,
  ) =>
    _simplifyPow(innerBase, _simplifyMul(e1, e2)),
  (Exp(:final expr), final exponent) => _simplifyExp(
    _simplifyMul(expr, exponent),
  ),
  (
    Sqrt(:final expr),
    RationalNumber(numerator: 2, denominator: 1) || RealNumber(value: 2.0),
  ) =>
    expr,
  (Sqrt(:final expr), RationalNumber(:final numerator, :final denominator))
      when numerator.isEven =>
    _simplifyPow(expr, RationalNumber(numerator ~/ 2, denominator)),
  (
    Abs(:final expr),
    RationalNumber(numerator: 2, denominator: 1) || RealNumber(value: 2.0),
  ) =>
    _simplifyPow(expr, exponent),
  _ => Pow(base, exponent),
};

Expr _foldRationalPower(int num, int den, int exp) {
  if (exp == 0) return RationalNumber.one;
  if (exp > 0 && exp <= 10) {
    var n = 1;
    var d = 1;
    for (var i = 0; i < exp; i++) {
      n *= num;
      d *= den;
    }
    return RationalNumber(n, d);
  }
  if (exp < 0 && -exp <= 10 && num != 0) {
    final absExp = -exp;
    var n = 1;
    var d = 1;
    for (var i = 0; i < absExp; i++) {
      n *= den;
      d *= num;
    }
    if (d < 0) {
      n = -n;
      d = -d;
    }
    return RationalNumber(n, d);
  }
  return Pow(RationalNumber(num, den), RationalNumber(exp));
}

Expr _foldGeneralPower(RationalNumber base, RationalNumber exp) {
  if (exp.numerator == 1 && exp.denominator == 2 && base.numerator >= 0) {
    final numSqrt = math.sqrt(base.numerator).round();
    final denSqrt = math.sqrt(base.denominator).round();
    if (numSqrt * numSqrt == base.numerator &&
        denSqrt * denSqrt == base.denominator) {
      return RationalNumber(numSqrt, denSqrt);
    }
  }
  return Pow(base, exp);
}

Expr _simplifyNeg(Expr expr) => switch (expr) {
  RationalNumber(isZero: true) => RationalNumber.zero,
  RealNumber(value: 0.0) => RationalNumber.zero,
  RationalNumber() => RationalNumber.fraction(-expr.toFraction()),
  RealNumber(:final value) => RealNumber(-value),
  Neg(:final expr) => expr,
  _ => Neg(expr),
};

Expr _simplifySin(Expr expr) {
  if (expr is RationalNumber && expr.isZero) return RationalNumber.zero;
  if (expr is RealNumber && expr.value == 0.0) return RationalNumber.zero;

  // Involution: sin(asin(u)) = u
  if (expr is Asin) return expr.expr;

  // Parity: sin(-u) = -sin(u)
  final (posExpr, isNeg) = _extractSign(expr);
  if (isNeg) {
    return _simplifyNeg(_simplifySin(posExpr));
  }

  // Multiples of pi
  final piMult = _matchPiMultiple(expr);
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

Expr _simplifyCos(Expr expr) {
  if (expr is RationalNumber && expr.isZero) return RationalNumber.one;
  if (expr is RealNumber && expr.value == 0.0) return RationalNumber.one;

  // Involution: cos(acos(u)) = u
  if (expr is Acos) return expr.expr;

  // Parity: cos(-u) = cos(u)
  final (posExpr, isNeg) = _extractSign(expr);
  if (isNeg) {
    return _simplifyCos(posExpr);
  }

  // Multiples of pi
  final piMult = _matchPiMultiple(expr);
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

Expr _simplifyTan(Expr expr) {
  if (expr is RationalNumber && expr.isZero) return RationalNumber.zero;
  if (expr is RealNumber && expr.value == 0.0) return RationalNumber.zero;

  // Involution: tan(atan(u)) = u
  if (expr is Atan) return expr.expr;

  // Parity: tan(-u) = -tan(u)
  final (posExpr, isNeg) = _extractSign(expr);
  if (isNeg) {
    return _simplifyNeg(_simplifyTan(posExpr));
  }

  // Multiples of pi
  final piMult = _matchPiMultiple(expr);
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

Expr _simplifyAsin(Expr expr) {
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
  final (posExpr, isNeg) = _extractSign(expr);
  if (isNeg) {
    return _simplifyNeg(_simplifyAsin(posExpr));
  }

  return Asin(expr);
}

Expr _simplifyAcos(Expr expr) {
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

  return Acos(expr);
}

Expr _simplifyAtan(Expr expr) {
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
  final (posExpr, isNeg) = _extractSign(expr);
  if (isNeg) {
    return _simplifyNeg(_simplifyAtan(posExpr));
  }

  return Atan(expr);
}

Expr _simplifySinh(Expr expr) {
  if (expr is RationalNumber && expr.isZero) return RationalNumber.zero;
  if (expr is RealNumber && expr.value == 0.0) return RationalNumber.zero;

  // Parity: sinh(-u) = -sinh(u)
  final (posExpr, isNeg) = _extractSign(expr);
  if (isNeg) {
    return _simplifyNeg(_simplifySinh(posExpr));
  }

  return Sinh(expr);
}

Expr _simplifyCosh(Expr expr) {
  if (expr is RationalNumber && expr.isZero) return RationalNumber.one;
  if (expr is RealNumber && expr.value == 0.0) return RationalNumber.one;

  // Parity: cosh(-u) = cosh(u)
  final (posExpr, isNeg) = _extractSign(expr);
  if (isNeg) {
    return _simplifyCosh(posExpr);
  }

  return Cosh(expr);
}

Expr _simplifyTanh(Expr expr) {
  if (expr is RationalNumber && expr.isZero) return RationalNumber.zero;
  if (expr is RealNumber && expr.value == 0.0) return RationalNumber.zero;

  // Parity: tanh(-u) = -tanh(u)
  final (posExpr, isNeg) = _extractSign(expr);
  if (isNeg) {
    return _simplifyNeg(_simplifyTanh(posExpr));
  }

  return Tanh(expr);
}

Expr _simplifyAbs(Expr expr) {
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
  final (posExpr, isNeg) = _extractSign(expr);
  if (isNeg) {
    return _simplifyAbs(posExpr);
  }

  return Abs(expr);
}

Expr _simplifySqrt(Expr expr) {
  if (expr is RationalNumber) {
    if (expr.isZero) return RationalNumber.zero;
    if (expr.isOne) return RationalNumber.one;
    if (expr.numerator > 0) {
      final sqrtNum = math.sqrt(expr.numerator).round();
      final sqrtDen = math.sqrt(expr.denominator).round();
      if (sqrtNum * sqrtNum == expr.numerator &&
          sqrtDen * sqrtDen == expr.denominator) {
        return RationalNumber(sqrtNum, sqrtDen);
      }
    }
  }
  if (expr is RealNumber) {
    if (expr.value == 0.0) return RationalNumber.zero;
    if (expr.value == 1.0) return RationalNumber.one;
    final s = math.sqrt(expr.value);
    if ((s - s.round()).abs() < 1e-12) {
      return RationalNumber(s.round());
    }
  }

  // Involution: sqrt(u^2) = |u|
  if (expr is Pow) {
    final exp = expr.exponent;
    if ((exp is RationalNumber && exp.numerator == 2 && exp.denominator == 1) ||
        (exp is RealNumber && exp.value == 2.0)) {
      return _simplifyAbs(expr.base);
    }
  }

  return Sqrt(expr);
}

Expr _simplifyLog(Expr base, Expr expr) {
  // log(b, 1) = 0
  if (expr case RationalNumber(isOne: true) || RealNumber(value: 1.0)) {
    return RationalNumber.zero;
  }
  // log(b, b) = 1
  if (base == expr) {
    return RationalNumber.one;
  }
  // log(b, b^k) = k
  if (expr is Pow && expr.base == base) {
    return expr.exponent;
  }
  // log(e, expr) = ln(expr)
  if (base is ConstantNumber && base.name == 'e') {
    return _simplifyLn(expr);
  }

  return Log(base, expr);
}

Expr _simplifyExp(Expr expr) {
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
      return _simplifyPow((expr.left as Ln).expr, expr.right);
    }
    if (expr.right is Ln) {
      return _simplifyPow((expr.right as Ln).expr, expr.left);
    }
  }
  if (expr is Neg && expr.expr is Ln) {
    return _simplifyPow((expr.expr as Ln).expr, RationalNumber.negativeOne);
  }
  return Exp(expr);
}

Expr _simplifyLn(Expr expr) {
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
    return _simplifyMul(expr.exponent, Ln(expr.base));
  }
  // ln(sqrt(u)) = 1/2 * ln(u)
  if (expr is Sqrt) {
    return _simplifyMul(const RationalNumber(1, 2), Ln(expr.expr));
  }

  return Ln(expr);
}

(Expr, bool) _extractSign(Expr expr) {
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
      return (_simplifyMul(posLeft, expr.right), true);
    }
    if (expr.right is RationalNumber &&
        (expr.right as RationalNumber).isNegative) {
      final posRight = RationalNumber.fraction(
        -(expr.right as RationalNumber).toFraction(),
      );
      return (_simplifyMul(expr.left, posRight), true);
    }
  }
  return (expr, false);
}

Fraction? _matchPiMultiple(Expr expr) {
  if (expr is ConstantNumber && expr.name == 'pi') {
    return Fraction.one;
  }
  if (expr is Neg) {
    final sub = _matchPiMultiple(expr.expr);
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

class _TermAccumulator {
  Fraction constantValue = Fraction.zero;
  double realValue = 0.0;
  final Map<Expr, Fraction> terms = {};

  void add(Expr expr, Fraction sign) {
    if (expr is RationalNumber) {
      constantValue += sign * expr.toFraction();
      return;
    }
    if (expr is RealNumber) {
      realValue += (sign.a / sign.b) * expr.value;
      return;
    }
    if (expr is Add) {
      add(expr.left, sign);
      add(expr.right, sign);
      return;
    }
    if (expr is Sub) {
      add(expr.left, sign);
      add(expr.right, -sign);
      return;
    }
    if (expr is Neg) {
      add(expr.expr, -sign);
      return;
    }
    final (c, base) = _decomposeTerm(expr);
    final totalCoeff = sign * c;
    final current = terms[base] ?? Fraction.zero;
    terms[base] = current + totalCoeff;
  }

  void reduceIdentities() {
    _reducePythagorean();
    _reduceHyperbolicPythagorean();
    _reduceLogarithms();
  }

  void _reducePythagorean() {
    final sinSquares = <Expr, (Expr, Fraction)>{};
    final cosSquares = <Expr, (Expr, Fraction)>{};

    for (final entry in terms.entries) {
      final uSin = _isSquareOf(entry.key, Sin);
      if (uSin != null) {
        sinSquares[uSin] = (entry.key, entry.value);
      }
      final uCos = _isSquareOf(entry.key, Cos);
      if (uCos != null) {
        cosSquares[uCos] = (entry.key, entry.value);
      }
    }

    for (final u in sinSquares.keys) {
      if (cosSquares.containsKey(u)) {
        final (sinKey, sinCoeff) = sinSquares[u]!;
        final (cosKey, cosCoeff) = cosSquares[u]!;

        if (sinCoeff == cosCoeff) {
          terms.remove(sinKey);
          terms.remove(cosKey);
          constantValue += sinCoeff;
        } else if (sinCoeff > Fraction.zero && cosCoeff > Fraction.zero) {
          final m = sinCoeff < cosCoeff ? sinCoeff : cosCoeff;
          final newSin = sinCoeff - m;
          final newCos = cosCoeff - m;
          if (newSin.isZero) {
            terms.remove(sinKey);
          } else {
            terms[sinKey] = newSin;
          }
          if (newCos.isZero) {
            terms.remove(cosKey);
          } else {
            terms[cosKey] = newCos;
          }
          constantValue += m;
        }
      }
    }

    if (constantValue == Fraction.one) {
      for (final entry in terms.entries.toList()) {
        final uSin = _isSquareOf(entry.key, Sin);
        if (uSin != null && entry.value == -Fraction.one) {
          terms.remove(entry.key);
          constantValue = Fraction.zero;
          final cos2 = Pow(Cos(uSin), const RationalNumber(2));
          terms[cos2] = (terms[cos2] ?? Fraction.zero) + Fraction.one;
          break;
        }
        final uCos = _isSquareOf(entry.key, Cos);
        if (uCos != null && entry.value == -Fraction.one) {
          terms.remove(entry.key);
          constantValue = Fraction.zero;
          final sin2 = Pow(Sin(uCos), const RationalNumber(2));
          terms[sin2] = (terms[sin2] ?? Fraction.zero) + Fraction.one;
          break;
        }
      }
    }
  }

  void _reduceHyperbolicPythagorean() {
    final coshSquares = <Expr, (Expr, Fraction)>{};
    final sinhSquares = <Expr, (Expr, Fraction)>{};

    for (final entry in terms.entries) {
      final uCosh = _isSquareOf(entry.key, Cosh);
      if (uCosh != null) {
        coshSquares[uCosh] = (entry.key, entry.value);
      }
      final uSinh = _isSquareOf(entry.key, Sinh);
      if (uSinh != null) {
        sinhSquares[uSinh] = (entry.key, entry.value);
      }
    }

    for (final u in coshSquares.keys) {
      if (sinhSquares.containsKey(u)) {
        final (coshKey, coshCoeff) = coshSquares[u]!;
        final (sinhKey, sinhCoeff) = sinhSquares[u]!;

        if (coshCoeff == -sinhCoeff && coshCoeff > Fraction.zero) {
          terms.remove(coshKey);
          terms.remove(sinhKey);
          constantValue += coshCoeff;
        }
      }
    }

    if (constantValue == Fraction.one) {
      for (final entry in terms.entries.toList()) {
        final uSinh = _isSquareOf(entry.key, Sinh);
        if (uSinh != null && entry.value == Fraction.one) {
          terms.remove(entry.key);
          constantValue = Fraction.zero;
          final cosh2 = Pow(Cosh(uSinh), const RationalNumber(2));
          terms[cosh2] = (terms[cosh2] ?? Fraction.zero) + Fraction.one;
          break;
        }
      }
    }

    if (constantValue == -Fraction.one) {
      for (final entry in terms.entries.toList()) {
        final uCosh = _isSquareOf(entry.key, Cosh);
        if (uCosh != null && entry.value == Fraction.one) {
          terms.remove(entry.key);
          constantValue = Fraction.zero;
          final sinh2 = Pow(Sinh(uCosh), const RationalNumber(2));
          terms[sinh2] = (terms[sinh2] ?? Fraction.zero) + Fraction.one;
          break;
        }
      }
    }
  }

  void _reduceLogarithms() {
    final lnEntries = [
      for (final e in terms.entries)
        if (e.key is Ln &&
            (e.value == Fraction.one || e.value == -Fraction.one))
          e,
    ];

    if (lnEntries.length >= 2) {
      Expr? num;
      Expr? den;

      for (final e in lnEntries) {
        final inner = (e.key as Ln).expr;
        if (e.value == Fraction.one) {
          num = num == null ? inner : _simplifyMul(num, inner);
        } else {
          den = den == null ? inner : _simplifyMul(den, inner);
        }
        terms.remove(e.key);
      }

      if (num != null && den != null) {
        final combined = _simplifyLn(_simplifyDiv(num, den));
        add(combined, Fraction.one);
      } else if (num != null) {
        final combined = _simplifyLn(num);
        add(combined, Fraction.one);
      } else if (den != null) {
        final combined = _simplifyLn(_simplifyDiv(RationalNumber.one, den));
        add(combined, Fraction.one);
      }
    }
  }
}

Expr? _isSquareOf(Expr term, Type targetType) {
  if (term is Pow) {
    final exp = term.exponent;
    final isSquare =
        (exp is RationalNumber && exp.numerator == 2 && exp.denominator == 1) ||
        (exp is RealNumber && exp.value == 2.0);
    if (isSquare &&
        term.base.runtimeType == targetType &&
        term.base is UnaryExpr) {
      return (term.base as UnaryExpr).expr;
    }
  }
  return null;
}

(Fraction, Expr) _decomposeTerm(Expr expr) {
  if (expr is Neg) {
    final (c, b) = _decomposeTerm(expr.expr);
    return (-c, b);
  }
  if (expr is Mul) {
    if (expr.left is RationalNumber) {
      final c1 = (expr.left as RationalNumber).toFraction();
      final (c2, b) = _decomposeTerm(expr.right);
      return (c1 * c2, b);
    }
    if (expr.right is RationalNumber) {
      final c1 = (expr.right as RationalNumber).toFraction();
      final (c2, b) = _decomposeTerm(expr.left);
      return (c1 * c2, b);
    }
  }
  if (expr is Div && expr.right is RationalNumber) {
    final c1 = (expr.right as RationalNumber).toFraction();
    final (c2, b) = _decomposeTerm(expr.left);
    return (c2 / c1, b);
  }
  return (Fraction.one, expr);
}

(Expr, Expr) _decomposeFactor(Expr expr) {
  if (expr is Pow) {
    return (expr.base, expr.exponent);
  }
  return (expr, RationalNumber.one);
}

int _compareTerms(Expr baseA, Fraction coeffA, Expr baseB, Fraction coeffB) {
  final degA = _termDegree(baseA);
  final degB = _termDegree(baseB);
  if (degA != degB) {
    return degB.compareTo(degA); // Descending degree
  }
  final signA = coeffA > Fraction.zero ? 1 : -1;
  final signB = coeffB > Fraction.zero ? 1 : -1;
  if (signA != signB) {
    return signB.compareTo(signA); // Positive terms first
  }
  final symA = _primarySymbol(baseA);
  final symB = _primarySymbol(baseB);
  final cmp = symA.compareTo(symB);
  if (cmp != 0) return cmp;
  return _compareStructural(baseA, baseB);
}

double _termDegree(Expr expr) => switch (expr) {
  Variable() => 1.0,
  Pow(base: Variable(), exponent: Number(:final value)) => value,
  Pow(base: Variable(), exponent: Neg(expr: Number(:final value))) => -value,
  Mul(left: final l, right: final r) => _termDegree(l) + _termDegree(r),
  Neg(:final expr) => _termDegree(expr),
  Number() => 0.0,
  _ => 0.0,
};

String _primarySymbol(Expr expr) => switch (expr) {
  Variable(:final name) => name,
  ConstantNumber(:final name) => name,
  Pow(base: final b) => _primarySymbol(b),
  Neg(:final expr) => _primarySymbol(expr),
  Mul(left: final l) => _primarySymbol(l),
  Div(left: final l) => _primarySymbol(l),
  UnaryExpr(:final expr) => _primarySymbol(expr),
  _ => '',
};

int _compareStructural(Expr a, Expr b) {
  if (identical(a, b)) return 0;
  final tagA = _nodeTag(a);
  final tagB = _nodeTag(b);
  if (tagA != tagB) return tagA.compareTo(tagB);

  return switch (a) {
    RationalNumber() => _compareRational(a, b as RationalNumber),
    RealNumber(:final value) => value.compareTo((b as RealNumber).value),
    ConstantNumber(:final name, :final value) => switch (name.compareTo(
      (b as ConstantNumber).name,
    )) {
      0 => value.compareTo(b.value),
      final cmp => cmp,
    },
    Variable(:final name) => name.compareTo((b as Variable).name),
    UnaryExpr(:final expr) => _compareStructural(expr, (b as UnaryExpr).expr),
    BinaryExpr(:final left, :final right) => switch (_compareStructural(
      left,
      (b as BinaryExpr).left,
    )) {
      0 => _compareStructural(right, b.right),
      final cmp => cmp,
    },
  };
}

int _compareRational(RationalNumber a, RationalNumber b) {
  if (a.numerator == b.numerator && a.denominator == b.denominator) {
    return 0;
  }
  final delta = a.numerator * b.denominator - b.numerator * a.denominator;
  if (delta < 0) return -1;
  if (delta > 0) return 1;
  return a.denominator.compareTo(b.denominator);
}

int _nodeTag(Expr expr) => switch (expr) {
  RationalNumber() => 0,
  RealNumber() => 1,
  ConstantNumber() => 2,
  Variable() => 3,
  Neg() => 4,
  Cos() => 5,
  Exp() => 6,
  Ln() => 7,
  Sin() => 8,
  Tan() => 9,
  Asin() => 10,
  Acos() => 11,
  Atan() => 12,
  Sinh() => 13,
  Cosh() => 14,
  Tanh() => 15,
  Abs() => 16,
  Sqrt() => 17,
  Log() => 18,
  Pow() => 20,
  Mul() => 21,
  Div() => 22,
  Add() => 23,
  Sub() => 24,
};
