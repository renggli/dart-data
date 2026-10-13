import 'package:more/number.dart' show Fraction;

import '../ast.dart';
import 'simplify.dart';
import 'structural_order.dart';
import 'term_accumulator.dart';

/// Algebraic expansion extension on [Expr].
extension ExpandExtension on Expr {
  /// Expands multiplications over additions and integer powers of sums.
  ///
  /// Conceptually, this distributes products such as $(A + B)(C + D) \to AC + AD + BC + BD$,
  /// expands integer powers of sums such as $(x + y)^2 \to x^2 + 2xy + y^2$, and
  /// recursively expands sub-expressions within mathematical functions such as
  /// $\sin((x + 1)^2) \to \sin(x^2 + 2x + 1)$. Formally, this applies the distributive
  /// property of the commutative ring of algebraic expressions.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final expr = (x - 2) * (x - 3);
  /// final expanded = expr.expand(); // x^2 - 5 * x + 6
  /// ```
  Expr expand() => _expand(this);
}

Expr _expand(Expr expr) => switch (expr) {
  Number() || Variable() => expr,
  Neg(:final expr) => _expandNeg(_expand(expr)),
  Add(:final left, :final right) => _expandAdd(_expand(left), _expand(right)),
  Sub(:final left, :final right) => _expandSub(_expand(left), _expand(right)),
  Mul(:final left, :final right) => _expandMul(_expand(left), _expand(right)),
  Div(:final left, :final right) => _expandDiv(_expand(left), _expand(right)),
  Pow(:final base, :final exponent) => _expandPow(
    _expand(base),
    _expand(exponent),
  ),
  Sin(:final expr) => Sin(_expand(expr)),
  Cos(:final expr) => Cos(_expand(expr)),
  Tan(:final expr) => Tan(_expand(expr)),
  Asin(:final expr) => Asin(_expand(expr)),
  Acos(:final expr) => Acos(_expand(expr)),
  Atan(:final expr) => Atan(_expand(expr)),
  Sinh(:final expr) => Sinh(_expand(expr)),
  Cosh(:final expr) => Cosh(_expand(expr)),
  Tanh(:final expr) => Tanh(_expand(expr)),
  Abs(:final expr) => Abs(_expand(expr)),
  Exp(:final expr) => Exp(_expand(expr)),
  Ln(:final expr) => Ln(_expand(expr)),
};

Expr _expandNeg(Expr inner) {
  final acc = MonomialAccumulator();
  acc.add(inner, -Fraction.one);
  acc.reduceIdentities();
  return acc.build();
}

Expr _expandAdd(Expr left, Expr right) {
  final acc = MonomialAccumulator();
  acc.add(left);
  acc.add(right);
  acc.reduceIdentities();
  return acc.build();
}

Expr _expandSub(Expr left, Expr right) {
  final acc = MonomialAccumulator();
  acc.add(left);
  acc.add(right, -Fraction.one);
  acc.reduceIdentities();
  return acc.build();
}

Expr _expandMul(Expr left, Expr right) {
  final leftTerms = <Expr>[];
  MonomialAccumulator.collectTerms(left, leftTerms);
  final rightTerms = <Expr>[];
  MonomialAccumulator.collectTerms(right, rightTerms);

  if (leftTerms.length == 1 && rightTerms.length == 1) {
    return _multiplyMonomials(leftTerms.first, rightTerms.first);
  }

  final acc = MonomialAccumulator();
  for (final l in leftTerms) {
    for (final r in rightTerms) {
      final termProduct = _multiplyMonomials(l, r);
      acc.add(termProduct);
    }
  }
  acc.reduceIdentities();
  return acc.build();
}

void _collectFactors(Expr expr, List<Expr> target) {
  if (expr is Mul) {
    _collectFactors(expr.left, target);
    _collectFactors(expr.right, target);
  } else if (expr is Neg) {
    target.add(RationalNumber.negativeOne);
    _collectFactors(expr.expr, target);
  } else {
    target.add(expr);
  }
}

void _collectFactorInto(
  Expr f,
  Map<Expr, Expr> symbolicBases,
  List<Expr> orderedBases,
) {
  final (base, exp) = f is Pow
      ? (f.base, f.exponent)
      : (f, const RationalNumber(1));

  if (symbolicBases.containsKey(base)) {
    final currentExp = symbolicBases[base]!;
    final newExp = (currentExp + exp).simplify();
    if (newExp is RationalNumber && newExp.isZero) {
      symbolicBases.remove(base);
      orderedBases.remove(base);
    } else {
      symbolicBases[base] = newExp;
    }
  } else {
    symbolicBases[base] = exp;
    orderedBases.add(base);
  }
}

Expr _multiplyMonomials(Expr left, Expr right) {
  if (left is Number && right is Number) {
    return Mul(left, right).simplify();
  }
  if ((left is RationalNumber && left.isZero) ||
      (right is RationalNumber && right.isZero) ||
      (left is RealNumber && left.value == 0.0) ||
      (right is RealNumber && right.value == 0.0)) {
    return RationalNumber.zero;
  }

  final factors = <Expr>[];
  _collectFactors(left, factors);
  _collectFactors(right, factors);

  var ratCoeff = Fraction.one;
  var realCoeff = 1.0;
  var hasReal = false;

  final symbolicBases = <Expr, Expr>{};
  final orderedBases = <Expr>[];

  for (final f in factors) {
    if (f is RationalNumber) {
      ratCoeff *= f.toFraction();
    } else if (f is RealNumber) {
      hasReal = true;
      realCoeff *= f.value;
    } else if (f is Neg) {
      final inner = f.expr;
      if (inner is RationalNumber) {
        ratCoeff *= -inner.toFraction();
      } else if (inner is RealNumber) {
        hasReal = true;
        realCoeff *= -inner.value;
      } else {
        ratCoeff = -ratCoeff;
        _collectFactorInto(inner, symbolicBases, orderedBases);
      }
    } else {
      _collectFactorInto(f, symbolicBases, orderedBases);
    }
  }

  if (ratCoeff.a == 0 || (hasReal && realCoeff == 0.0)) {
    return RationalNumber.zero;
  }

  orderedBases.sort(compareStructural);

  Expr? symbolicPart;
  for (final base in orderedBases) {
    final exp = symbolicBases[base]!;
    final factor = exp == const RationalNumber(1) ? base : Pow(base, exp);
    symbolicPart = symbolicPart == null ? factor : Mul(symbolicPart, factor);
  }

  if (hasReal) {
    final scalar = RealNumber(realCoeff * ratCoeff.toDouble());
    if (symbolicPart == null) return scalar;
    if (scalar.value == 1.0) return symbolicPart;
    if (scalar.value == -1.0) {
      return MonomialAccumulator.negateMonomial(symbolicPart);
    }
    return Mul(scalar, symbolicPart);
  } else {
    if (symbolicPart == null) return RationalNumber.fraction(ratCoeff);
    if (ratCoeff == Fraction.one) return symbolicPart;
    if (ratCoeff == -Fraction.one) {
      return MonomialAccumulator.negateMonomial(symbolicPart);
    }
    return Mul(RationalNumber.fraction(ratCoeff), symbolicPart);
  }
}

Expr _expandPow(Expr base, Expr exponent) {
  if (exponent is RationalNumber && exponent.denominator == 1) {
    final n = exponent.numerator;
    if (n == 0) return const RationalNumber(1);
    if (n == 1) return base;
    if (n > 1) {
      return _expandPowInteger(base, n);
    }
    if (n < 0) {
      final pos = _expandPowInteger(base, -n);
      return Div(const RationalNumber(1), pos).simplify();
    }
  } else if (exponent is RealNumber &&
      exponent.value == exponent.value.roundToDouble()) {
    final n = exponent.value.round();
    if (n == 0) return const RationalNumber(1);
    if (n == 1) return base;
    if (n > 1) {
      return _expandPowInteger(base, n);
    }
    if (n < 0) {
      final pos = _expandPowInteger(base, -n);
      return Div(const RationalNumber(1), pos).simplify();
    }
  }
  return Pow(base, exponent).simplify();
}

Expr _expandPowInteger(Expr base, int exponent) {
  Expr result = const RationalNumber(1);
  var current = base;
  var exp = exponent;
  while (exp > 0) {
    if (exp.isOdd) {
      result = _expandMul(result, current);
    }
    exp ~/= 2;
    if (exp > 0) {
      current = _expandMul(current, current);
    }
  }
  return result;
}

Expr _expandDiv(Expr left, Expr right) {
  if (right is RationalNumber) {
    if (right.isZero) {
      throw UnsupportedError('Division by zero in expansion');
    }
    final inv = RationalNumber.fraction(Fraction.one / right.toFraction());
    return _expandMul(left, inv);
  }
  if (right is RealNumber) {
    if (right.value == 0.0) {
      throw UnsupportedError('Division by zero in expansion');
    }
    final inv = RealNumber(1.0 / right.value);
    return _expandMul(left, inv);
  }

  final terms = <Expr>[];
  MonomialAccumulator.collectTerms(left, terms);
  if (terms.length > 1) {
    final acc = MonomialAccumulator();
    for (final term in terms) {
      acc.add(Div(term, right).simplify());
    }
    acc.reduceIdentities();
    return acc.build();
  }

  return Div(left, right).simplify();
}
