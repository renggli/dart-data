import 'dart:math' as math;

import 'package:more/number.dart' show Complex, Fraction;

import '../ast.dart';
import 'term_accumulator.dart';

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

  final acc = TermAccumulator(simplify: _simplify);
  acc.add(left, Fraction.one);
  acc.add(right, isSubtraction ? -Fraction.one : Fraction.one);
  acc.reduceIdentities();
  return acc.toExpr();
}

Expr _simplifyMul(Expr left, Expr right) {
  // Imaginary unit multiplication fast path: i * i = -1
  if (left == ConstantNumber.i && right == ConstantNumber.i) {
    return RationalNumber.negativeOne;
  }

  // Negation pull-through: (-a) * b => -(a * b), a * (-b) => -(a * b)
  if (left is Neg) {
    return _simplifyNeg(_simplifyMul(left.expr, right));
  }
  if (right is Neg) {
    return _simplifyNeg(_simplifyMul(left, right.expr));
  }

  // Annihilator: 0 * x = x * 0 = 0
  if (left is RationalNumber && left.isZero) return RationalNumber.zero;
  if (right is RationalNumber && right.isZero) return RationalNumber.zero;
  if (left is RealNumber && left.value == 0.0) return RationalNumber.zero;
  if (right is RealNumber && right.value == 0.0) return RationalNumber.zero;
  if (left is ComplexNumber && left.complex == Complex.zero) {
    return RationalNumber.zero;
  }
  if (right is ComplexNumber && right.complex == Complex.zero) {
    return RationalNumber.zero;
  }

  // Multiplicative identity: 1 * x = x, x * 1 = x
  if (left is RationalNumber && left.isOne) return right;
  if (right is RationalNumber && right.isOne) return left;
  if (left is RealNumber && left.value == 1.0) return right;
  if (right is RealNumber && right.value == 1.0) return left;
  if (left is ComplexNumber && left.complex == Complex.one) return right;
  if (right is ComplexNumber && right.complex == Complex.one) return left;

  // Negation: -1 * x = -x, x * -1 = -x
  if (left is RationalNumber && left.isNegativeOne) return _simplifyNeg(right);
  if (right is RationalNumber && right.isNegativeOne) return _simplifyNeg(left);
  if (left is RealNumber && left.value == -1.0) return _simplifyNeg(right);
  if (right is RealNumber && right.value == -1.0) return _simplifyNeg(left);
  if (left is ComplexNumber && left.complex == -Complex.one) {
    return _simplifyNeg(right);
  }
  if (right is ComplexNumber && right.complex == -Complex.one) {
    return _simplifyNeg(left);
  }

  // Two numbers:
  if (left is RationalNumber && right is RationalNumber) {
    return RationalNumber.fraction(left.toFraction() * right.toFraction());
  }
  if (left is RealNumber && right is RealNumber) {
    return RealNumber(left.value * right.value);
  }
  if (left is ComplexNumber && right is ComplexNumber) {
    return _complexToCanonical(left.complex * right.complex);
  }
  if (left is ComplexNumber && right is RationalNumber) {
    return _complexToCanonical(left.complex * Complex(right.toDouble(), 0));
  }
  if (left is RationalNumber && right is ComplexNumber) {
    return _complexToCanonical(Complex(left.toDouble(), 0) * right.complex);
  }
  if (left is ComplexNumber && right is RealNumber) {
    return _complexToCanonical(left.complex * Complex(right.value, 0));
  }
  if (left is RealNumber && right is ComplexNumber) {
    return _complexToCanonical(Complex(left.value, 0) * right.complex);
  }
  if (left is ComplexNumber && right == ConstantNumber.i) {
    return _complexToCanonical(left.complex * Complex.i);
  }
  if (left == ConstantNumber.i && right is ComplexNumber) {
    return _complexToCanonical(Complex.i * right.complex);
  }

  // Exponential multiplication: e^a * e^b => e^(a + b)
  if (left is Exp && right is Exp) {
    return _simplifyExp(_simplifyAdd(left.expr, right.expr));
  }
  // Power multiplication with identical exponents: a^k * b^k => (a * b)^k
  if (left is Pow && right is Pow && left.exponent == right.exponent) {
    if (left.base == right.base) {
      return _simplifyPow(
        left.base,
        _simplifyAdd(left.exponent, right.exponent),
      );
    }
    return _simplifyPow(_simplifyMul(left.base, right.base), left.exponent);
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
  if (left is Mul && left.left is RationalNumber) {
    final c1 = left.left as RationalNumber;
    final sub = _simplifyMul(left.right, right);
    return _simplifyMul(c1, sub);
  }
  if (left is Mul && left.right is RationalNumber) {
    final c1 = left.right as RationalNumber;
    final sub = _simplifyMul(left.left, right);
    return _simplifyMul(c1, sub);
  }
  if (right is Mul && right.left is RationalNumber) {
    final c2 = right.left as RationalNumber;
    final sub = _simplifyMul(left, right.right);
    return _simplifyMul(c2, sub);
  }
  if (right is Mul && right.right is RationalNumber) {
    final c2 = right.right as RationalNumber;
    final sub = _simplifyMul(left, right.left);
    return _simplifyMul(c2, sub);
  }

  // Like-factor multiplications:
  final (baseL, expL) = decomposeFactor(left);
  final (baseR, expR) = decomposeFactor(right);
  if (baseL == baseR) {
    final newExp = _simplifyAdd(expL, expR);
    return _simplifyPow(baseL, newExp);
  }

  // Associative like-factor multiplications:
  if (left is Mul) {
    final (baseSubR, _) = decomposeFactor(left.right);
    if (baseSubR == baseR) {
      return _simplifyMul(left.left, _simplifyMul(left.right, right));
    }
    final (baseSubL, _) = decomposeFactor(left.left);
    if (baseSubL == baseR) {
      return _simplifyMul(_simplifyMul(left.left, right), left.right);
    }
  }
  if (right is Mul) {
    final (baseSubL, _) = decomposeFactor(right.left);
    if (baseSubL == baseL) {
      return _simplifyMul(_simplifyMul(left, right.left), right.right);
    }
    final (baseSubR, _) = decomposeFactor(right.right);
    if (baseSubR == baseL) {
      return _simplifyMul(right.left, _simplifyMul(left, right.right));
    }
  }

  // Put numbers on the left of non-numbers, and scalar numbers on the left of constant/complex numbers:
  if (right is Number && left is! Number) {
    return _simplifyMul(right, left);
  }
  if ((right is RationalNumber || right is RealNumber) &&
      (left is ConstantNumber || left is ComplexNumber)) {
    return _simplifyMul(right, left);
  }

  return Mul(left, right);
}

Expr _simplifyDiv(Expr left, Expr right) {
  // Division by imaginary unit: z / i => -z * i, z / (-i) => z * i
  if (right == ConstantNumber.i) {
    return _simplifyMul(_simplifyNeg(left), ConstantNumber.i);
  }
  if (right is Neg && right.expr == ConstantNumber.i) {
    return _simplifyMul(left, ConstantNumber.i);
  }

  if (right is RationalNumber && right.isZero) {
    throw UnsupportedError('Division by zero in simplification');
  }
  if (right is RealNumber && right.value == 0.0) {
    throw UnsupportedError('Division by zero in simplification');
  }
  if (right is ComplexNumber && right.complex == Complex.zero) {
    throw UnsupportedError('Division by zero in simplification');
  }
  if (left == right) return RationalNumber.one;
  if (left is RationalNumber && left.isZero) return RationalNumber.zero;
  if (left is RealNumber && left.value == 0.0) return RationalNumber.zero;
  if (left is ComplexNumber && left.complex == Complex.zero) {
    return RationalNumber.zero;
  }
  if (left is RationalNumber && right is RationalNumber) {
    return RationalNumber.fraction(left.toFraction() / right.toFraction());
  }
  if (left is RealNumber && right is RealNumber) {
    return RealNumber(left.value / right.value);
  }
  if (left is ComplexNumber && right is ComplexNumber) {
    return _complexToCanonical(left.complex / right.complex);
  }
  if (left is ComplexNumber && right is RationalNumber) {
    return _complexToCanonical(left.complex / Complex(right.toDouble(), 0));
  }
  if (left is RationalNumber && right is ComplexNumber) {
    return _complexToCanonical(Complex(left.toDouble(), 0) / right.complex);
  }
  if (left is ComplexNumber && right is RealNumber) {
    return _complexToCanonical(left.complex / Complex(right.value, 0));
  }
  if (left is RealNumber && right is ComplexNumber) {
    return _complexToCanonical(Complex(left.value, 0) / right.complex);
  }
  if (left is ComplexNumber && right == ConstantNumber.i) {
    return _complexToCanonical(left.complex / Complex.i);
  }
  if (left == ConstantNumber.i && right is ComplexNumber) {
    return _complexToCanonical(Complex.i / right.complex);
  }

  // Exponential division: e^a / e^b => e^(a - b)
  if (left is Exp && right is Exp) {
    return _simplifyExp(_simplifySub(left.expr, right.expr));
  }
  // Power division with identical exponents: a^k / b^k => (a / b)^k
  if (left is Pow && right is Pow && left.exponent == right.exponent) {
    return _simplifyPow(_simplifyDiv(left.base, right.base), left.exponent);
  }
  if (right is RationalNumber && right.isOne) return left;
  if (right is RealNumber && right.value == 1.0) return left;
  if (right is ComplexNumber && right.complex == Complex.one) return left;
  if (right is RationalNumber && right.isNegativeOne) return _simplifyNeg(left);
  if (right is RealNumber && right.value == -1.0) return _simplifyNeg(left);
  if (right is ComplexNumber && right.complex == -Complex.one) {
    return _simplifyNeg(left);
  }

  // Canonicalize expr / RationalNumber(c) => RationalNumber(1/c) * expr
  if (right is RationalNumber) {
    return _simplifyMul(
      RationalNumber.fraction(Fraction.one / right.toFraction()),
      left,
    );
  }

  // Like factors: x^a / x^b => x^(a - b)
  final (baseL, expL) = decomposeFactor(left);
  final (baseR, expR) = decomposeFactor(right);
  if (baseL == baseR) {
    final newExp = _simplifySub(expL, expR);
    return _simplifyPow(baseL, newExp);
  }

  // Mul numerator: (c * r) / r => c, (a * b) / r
  if (left is Mul) {
    final (baseSubL, _) = decomposeFactor(left.left);
    if (baseSubL == baseR) {
      return _simplifyMul(_simplifyDiv(left.left, right), left.right);
    }
    final (baseSubR, _) = decomposeFactor(left.right);
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
    ConstantNumber(name: 'i'),
    RationalNumber(isInteger: true, numerator: final expInt),
  ) =>
    switch (((expInt % 4) + 4) % 4) {
      0 => RationalNumber.one,
      1 => ConstantNumber.i,
      2 => RationalNumber.negativeOne,
      3 => const Neg(ConstantNumber.i),
      _ => Pow(base, exponent),
    },
  (
    Neg(expr: ConstantNumber(name: 'i')),
    RationalNumber(isInteger: true, numerator: final expInt),
  ) =>
    switch (((expInt % 4) + 4) % 4) {
      0 => RationalNumber.one,
      1 => const Neg(ConstantNumber.i),
      2 => RationalNumber.negativeOne,
      3 => ConstantNumber.i,
      _ => Pow(base, exponent),
    },
  (ConstantNumber(name: 'i'), RealNumber(:final value))
      when value == value.truncateToDouble() =>
    switch (((value.toInt() % 4) + 4) % 4) {
      0 => RationalNumber.one,
      1 => ConstantNumber.i,
      2 => RationalNumber.negativeOne,
      3 => const Neg(ConstantNumber.i),
      _ => Pow(base, exponent),
    },
  (Neg(expr: ConstantNumber(name: 'i')), RealNumber(:final value))
      when value == value.truncateToDouble() =>
    switch (((value.toInt() % 4) + 4) % 4) {
      0 => RationalNumber.one,
      1 => const Neg(ConstantNumber.i),
      2 => RationalNumber.negativeOne,
      3 => ConstantNumber.i,
      _ => Pow(base, exponent),
    },
  (
    Mul(
      left: RationalNumber(:final numerator, :final denominator),
      right: ConstantNumber(name: 'i'),
    ),
    RationalNumber(isInteger: true, numerator: final expInt),
  ) =>
    switch (((expInt % 4) + 4) % 4) {
      0 => _foldRationalPower(numerator, denominator, expInt),
      1 => _simplifyMul(
        _foldRationalPower(numerator, denominator, expInt),
        ConstantNumber.i,
      ),
      2 => _simplifyMul(
        RationalNumber.negativeOne,
        _foldRationalPower(numerator, denominator, expInt),
      ),
      3 => _simplifyMul(
        _simplifyMul(
          RationalNumber.negativeOne,
          _foldRationalPower(numerator, denominator, expInt),
        ),
        ConstantNumber.i,
      ),
      _ => Pow(base, exponent),
    },
  (
    Mul(
      left: ConstantNumber(name: 'i'),
      right: RationalNumber(:final numerator, :final denominator),
    ),
    RationalNumber(isInteger: true, numerator: final expInt),
  ) =>
    switch (((expInt % 4) + 4) % 4) {
      0 => _foldRationalPower(numerator, denominator, expInt),
      1 => _simplifyMul(
        _foldRationalPower(numerator, denominator, expInt),
        ConstantNumber.i,
      ),
      2 => _simplifyMul(
        RationalNumber.negativeOne,
        _foldRationalPower(numerator, denominator, expInt),
      ),
      3 => _simplifyMul(
        _simplifyMul(
          RationalNumber.negativeOne,
          _foldRationalPower(numerator, denominator, expInt),
        ),
        ConstantNumber.i,
      ),
      _ => Pow(base, exponent),
    },
  (
    ComplexNumber(:final complex),
    RationalNumber(isInteger: true, numerator: final expInt),
  ) =>
    _complexToCanonical(_complexPow(complex, Complex(expInt.toDouble(), 0))),
  (ComplexNumber(:final complex), RealNumber(:final value))
      when value == value.truncateToDouble() =>
    _complexToCanonical(_complexPow(complex, Complex(value, 0))),
  (
    RationalNumber(:final numerator, :final denominator),
    RationalNumber(isInteger: true, numerator: final expInt),
  ) =>
    _foldRationalPower(numerator, denominator, expInt),
  (RationalNumber() && final b, RationalNumber() && final e) =>
    _foldGeneralPower(b, e),
  // Involution: (u^2)^(1/2) => |u|
  (
    Pow(
      base: final innerBase,
      exponent: RationalNumber(numerator: 2, denominator: 1) ||
          RealNumber(value: 2.0),
    ),
    RationalNumber(numerator: 1, denominator: 2) || RealNumber(value: 0.5),
  ) =>
    _simplifyAbs(innerBase),
  (
    Pow(base: final innerBase, exponent: RationalNumber() && final e1),
    RationalNumber() && final e2,
  ) =>
    _simplifyPow(innerBase, _simplifyMul(e1, e2)),
  (Exp(:final expr), final exponent) => _simplifyExp(
    _simplifyMul(expr, exponent),
  ),
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

Expr _complexToCanonical(Complex c) {
  if (!c.a.isFinite || !c.b.isFinite) {
    return ComplexNumber(c);
  }
  if (c.a == 0 && c.b == 0) return RationalNumber.zero;

  if (c.b == 0) {
    if (c.a == c.a.truncateToDouble()) {
      return RationalNumber(c.a.toInt());
    }
    return RealNumber(c.a.toDouble());
  }

  if (c.a == 0) {
    if (c.b == 1.0) return ConstantNumber.i;
    if (c.b == -1.0) return const Neg(ConstantNumber.i);
    final bExpr = c.b == c.b.truncateToDouble()
        ? RationalNumber(c.b.toInt())
        : (Fraction.fromDouble(c.b.toDouble()).denominator <= 64
              ? RationalNumber.fraction(Fraction.fromDouble(c.b.toDouble()))
              : RealNumber(c.b.toDouble()));
    return Mul(bExpr, ConstantNumber.i);
  }

  final aExpr = c.a == c.a.truncateToDouble()
      ? RationalNumber(c.a.toInt())
      : (Fraction.fromDouble(c.a.toDouble()).denominator <= 64
            ? RationalNumber.fraction(Fraction.fromDouble(c.a.toDouble()))
            : RealNumber(c.a.toDouble()));

  final absB = c.b.abs();
  final imagPart = absB == 1.0
      ? ConstantNumber.i
      : Mul(
          absB == absB.truncateToDouble()
              ? RationalNumber(absB.toInt())
              : (Fraction.fromDouble(absB.toDouble()).denominator <= 64
                    ? RationalNumber.fraction(
                        Fraction.fromDouble(absB.toDouble()),
                      )
                    : RealNumber(absB.toDouble())),
          ConstantNumber.i,
        );

  return c.b > 0 ? Add(aExpr, imagPart) : Sub(aExpr, imagPart);
}

Complex _complexPow(Complex base, Complex exponent) {
  if (base.a == 0 && base.b == 0) {
    if (exponent.a == 0 && exponent.b == 0) return Complex.one;
    if (exponent.a > 0) return Complex.zero;
    if (exponent.a < 0) {
      return exponent.b == 0
          ? const Complex(double.infinity, 0.0)
          : const Complex(double.infinity, double.nan);
    }
    return Complex.nan;
  }
  return base.pow(exponent);
}
