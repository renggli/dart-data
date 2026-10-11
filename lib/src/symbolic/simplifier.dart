import 'dart:math' as math;

import 'package:more/number.dart' show Fraction;

import 'ast.dart';
import 'textualization/string.dart';

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
  Exp(:final expr) => _simplifyExp(_simplify(expr)),
  Ln(:final expr) => _simplifyLn(_simplify(expr)),
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

Expr _simplifySin(Expr expr) => switch (expr) {
  RationalNumber(isZero: true) => RationalNumber.zero,
  RealNumber(value: 0.0) => RationalNumber.zero,
  ConstantNumber(name: 'pi') => RationalNumber.zero,
  Neg(expr: ConstantNumber(name: 'pi')) => RationalNumber.zero,
  _ => Sin(expr),
};

Expr _simplifyCos(Expr expr) => switch (expr) {
  RationalNumber(isZero: true) => RationalNumber.one,
  RealNumber(value: 0.0) => RationalNumber.one,
  ConstantNumber(name: 'pi') => RationalNumber.negativeOne,
  Neg(expr: ConstantNumber(name: 'pi')) => RationalNumber.negativeOne,
  _ => Cos(expr),
};

Expr _simplifyExp(Expr expr) => switch (expr) {
  RationalNumber(isZero: true) => RationalNumber.one,
  RealNumber(value: 0.0) => RationalNumber.one,
  RationalNumber(isOne: true) => ConstantNumber.e,
  Ln(:final expr) => expr,
  _ => Exp(expr),
};

Expr _simplifyLn(Expr expr) => switch (expr) {
  ConstantNumber(name: 'e') => RationalNumber.one,
  RationalNumber(:final isNegative, :final isZero) when isNegative || isZero =>
    throw ArgumentError(
      'Natural logarithm domain error: non-positive argument',
    ),
  RealNumber(:final value) when value <= 0.0 => throw ArgumentError(
    'Natural logarithm domain error: non-positive argument',
  ),
  RationalNumber(isOne: true) => RationalNumber.zero,
  RealNumber(value: 1.0) => RationalNumber.zero,
  Exp(:final expr) => expr,
  _ => Ln(expr),
};

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
  return formatExpr(baseA).compareTo(formatExpr(baseB));
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
  Sin(:final expr) => 'sin_${_primarySymbol(expr)}',
  Cos(:final expr) => 'cos_${_primarySymbol(expr)}',
  Exp(:final expr) => 'exp_${_primarySymbol(expr)}',
  Ln(:final expr) => 'ln_${_primarySymbol(expr)}',
  Mul(left: final l) => _primarySymbol(l),
  Div(left: final l) => _primarySymbol(l),
  Number() => '',
  _ => expr.toString(),
};
