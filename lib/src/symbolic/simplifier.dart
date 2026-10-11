import 'dart:math' as math;

import 'ast.dart';
import 'textualization/string.dart';

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
  Constant() || Variable() => expr,
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
    if (left is Constant && left.value == 0.0) return right;
    if (right is Constant && right.value == 0.0) return left;
    if (left is Constant &&
        left.name == null &&
        right is Constant &&
        right.name == null) {
      return Constant(left.value + right.value);
    }
  } else {
    if (left == right) return const Constant(0.0);
    if (right is Constant && right.value == 0.0) return left;
    if (left is Constant && left.value == 0.0) return _simplifyNeg(right);
    if (left is Constant &&
        left.name == null &&
        right is Constant &&
        right.name == null) {
      return Constant(left.value - right.value);
    }
  }

  final acc = _TermAccumulator();
  acc.add(left, 1.0);
  acc.add(right, isSubtraction ? -1.0 : 1.0);

  // Filter out terms with zero coefficient
  acc.terms.removeWhere((_, coeff) => coeff == 0.0 || coeff.abs() < 1e-14);

  // If no symbolic terms exist, return constant value
  if (acc.terms.isEmpty) {
    if (acc.constantValue == 0.0) return const Constant(0.0);
    return Constant(acc.constantValue);
  }

  // Single symbolic term with no constant
  if (acc.terms.length == 1 && acc.constantValue == 0.0) {
    final entry = acc.terms.entries.first;
    final base = entry.key;
    final coeff = entry.value;
    if (coeff == 1.0) return base;
    if (coeff == -1.0) return _simplifyNeg(base);
    return Mul(Constant(coeff), base);
  }

  // Sort terms canonically: descending power/degree for polynomial terms
  final sortedEntries = acc.terms.entries.toList()
    ..sort((a, b) => _compareTerms(a.key, a.value, b.key, b.value));

  Expr? result;
  for (final entry in sortedEntries) {
    final base = entry.key;
    final coeff = entry.value;

    if (result == null) {
      if (coeff == 1.0) {
        result = base;
      } else if (coeff == -1.0) {
        result = _simplifyNeg(base);
      } else {
        result = Mul(Constant(coeff), base);
      }
    } else {
      if (coeff > 0) {
        final term = coeff == 1.0 ? base : Mul(Constant(coeff), base);
        result = Add(result, term);
      } else {
        final absCoeff = -coeff;
        final term = absCoeff == 1.0 ? base : Mul(Constant(absCoeff), base);
        result = Sub(result, term);
      }
    }
  }

  if (acc.constantValue != 0.0) {
    if (result == null) {
      result = Constant(acc.constantValue);
    } else if (acc.constantValue > 0) {
      result = Add(result, Constant(acc.constantValue));
    } else {
      result = Sub(result, Constant(-acc.constantValue));
    }
  }

  return result ?? const Constant(0.0);
}

Expr _simplifyMul(Expr left, Expr right) {
  // Annihilator: 0 * x = x * 0 = 0
  if (left is Constant && left.value == 0.0) return const Constant(0.0);
  if (right is Constant && right.value == 0.0) return const Constant(0.0);

  // Multiplicative identity: 1 * x = x, x * 1 = x
  if (left is Constant && left.value == 1.0) return right;
  if (right is Constant && right.value == 1.0) return left;

  // Negation: -1 * x = -x, x * -1 = -x
  if (left is Constant && left.value == -1.0) return _simplifyNeg(right);
  if (right is Constant && right.value == -1.0) return _simplifyNeg(left);

  // Two unnamed constants: c1 * c2 => Constant(c1 * c2)
  if (left is Constant &&
      left.name == null &&
      right is Constant &&
      right.name == null) {
    return Constant(left.value * right.value);
  }

  // Associative constant folding:
  // (expr * c1) * c2 => expr * (c1 * c2)
  if (left is Mul &&
      left.right is Constant &&
      (left.right as Constant).name == null &&
      right is Constant &&
      right.name == null) {
    return _simplifyMul(
      left.left,
      Constant((left.right as Constant).value * right.value),
    );
  }
  // (c1 * expr) * c2 => (c1 * c2) * expr
  if (left is Mul &&
      left.left is Constant &&
      (left.left as Constant).name == null &&
      right is Constant &&
      right.name == null) {
    return _simplifyMul(
      Constant((left.left as Constant).value * right.value),
      left.right,
    );
  }
  // c1 * (c2 * expr) => (c1 * c2) * expr
  if (left is Constant &&
      left.name == null &&
      right is Mul &&
      right.left is Constant &&
      (right.left as Constant).name == null) {
    return _simplifyMul(
      Constant(left.value * (right.left as Constant).value),
      right.right,
    );
  }
  // c1 * (expr * c2) => (c1 * c2) * expr
  if (left is Constant &&
      left.name == null &&
      right is Mul &&
      right.right is Constant &&
      (right.right as Constant).name == null) {
    return _simplifyMul(
      Constant(left.value * (right.right as Constant).value),
      right.left,
    );
  }

  // Pull out constant scalar from left or right to fold factors:
  // (c1 * inner) * right => c1 * (inner * right)
  if (left is Mul &&
      left.left is Constant &&
      (left.left as Constant).name == null) {
    final c1 = left.left as Constant;
    final sub = _simplifyMul(left.right, right);
    return _simplifyMul(c1, sub);
  }
  // (inner * c1) * right => c1 * (inner * right)
  if (left is Mul &&
      left.right is Constant &&
      (left.right as Constant).name == null) {
    final c1 = left.right as Constant;
    final sub = _simplifyMul(left.left, right);
    return _simplifyMul(c1, sub);
  }
  // left * (c2 * inner) => c2 * (left * inner)
  if (right is Mul &&
      right.left is Constant &&
      (right.left as Constant).name == null) {
    final c2 = right.left as Constant;
    final sub = _simplifyMul(left, right.right);
    return _simplifyMul(c2, sub);
  }
  // left * (inner * c2) => c2 * (left * inner)
  if (right is Mul &&
      right.right is Constant &&
      (right.right as Constant).name == null) {
    final c2 = right.right as Constant;
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

  return Mul(left, right);
}

Expr _simplifyDiv(Expr left, Expr right) => switch ((left, right)) {
  (_, Constant(value: 0.0)) => throw UnsupportedError(
    'Division by zero in simplification',
  ),
  _ when left == right => const Constant(1.0),
  (Constant(value: 0.0), _) => const Constant(0.0),
  (
    Constant(name: null, value: final l),
    Constant(name: null, value: final r),
  ) =>
    Constant(l / r),
  (final l, Constant(value: 1.0)) => l,
  (final l, Constant(value: -1.0)) => Neg(l),
  _ => Div(left, right),
};

Expr _simplifyPow(Expr base, Expr exponent) => switch ((base, exponent)) {
  (_, Constant(value: 0.0)) => const Constant(1.0),
  (final b, Constant(value: 1.0)) => b,
  (Constant(value: 0.0), _) => const Constant(0.0),
  (Constant(value: 1.0), _) => const Constant(1.0),
  (Constant(name: 'e'), final exponent) => Exp(exponent),
  (
    Constant(name: null, value: final b),
    Constant(name: null, value: final e),
  ) =>
    Constant(math.pow(b, e).toDouble()),
  (
    Pow(base: final innerBase, exponent: Constant(name: null, value: final e1)),
    Constant(name: null, value: final e2),
  ) =>
    _simplifyPow(innerBase, Constant(e1 * e2)),
  _ => Pow(base, exponent),
};

Expr _simplifyNeg(Expr expr) => switch (expr) {
  Constant(value: 0.0) => const Constant(0.0),
  Constant(name: null, :final value) => Constant(-value),
  Neg(:final expr) => expr,
  _ => Neg(expr),
};

Expr _simplifySin(Expr expr) => switch (expr) {
  Constant(value: 0.0) => const Constant(0.0),
  Constant(name: 'pi') => const Constant(0.0),
  Neg(expr: Constant(name: 'pi')) => const Constant(0.0),
  Constant(name: null, :final value) => Constant(math.sin(value)),
  _ => Sin(expr),
};

Expr _simplifyCos(Expr expr) => switch (expr) {
  Constant(value: 0.0) => const Constant(1.0),
  Constant(name: 'pi') => const Constant(-1.0),
  Neg(expr: Constant(name: 'pi')) => const Constant(-1.0),
  Constant(name: null, :final value) => Constant(math.cos(value)),
  _ => Cos(expr),
};

Expr _simplifyExp(Expr expr) => switch (expr) {
  Constant(value: 0.0) => const Constant(1.0),
  Constant(value: 1.0) => Constant.e,
  Ln(:final expr) => expr,
  Constant(name: null, :final value) => Constant(math.exp(value)),
  _ => Exp(expr),
};

Expr _simplifyLn(Expr expr) => switch (expr) {
  Constant(name: 'e') => const Constant(1.0),
  Constant(:final value) when value <= 0.0 => throw ArgumentError(
    'Natural logarithm domain error: $value <= 0',
  ),
  Constant(value: 1.0) => const Constant(0.0),
  Exp(:final expr) => expr,
  Constant(name: null, :final value) => Constant(math.log(value)),
  _ => Ln(expr),
};

class _TermAccumulator {
  double constantValue = 0.0;
  final Map<Expr, double> terms = {};

  void add(Expr expr, double sign) {
    if (expr is Constant && expr.name == null) {
      constantValue += sign * expr.value;
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
    terms[base] = (terms[base] ?? 0.0) + totalCoeff;
  }
}

(double, Expr) _decomposeTerm(Expr expr) {
  if (expr is Neg) {
    final (c, b) = _decomposeTerm(expr.expr);
    return (-c, b);
  }
  if (expr is Mul) {
    if (expr.left is Constant && (expr.left as Constant).name == null) {
      final c1 = (expr.left as Constant).value;
      final (c2, b) = _decomposeTerm(expr.right);
      return (c1 * c2, b);
    }
    if (expr.right is Constant && (expr.right as Constant).name == null) {
      final c1 = (expr.right as Constant).value;
      final (c2, b) = _decomposeTerm(expr.left);
      return (c1 * c2, b);
    }
  }
  return (1.0, expr);
}

(Expr, Expr) _decomposeFactor(Expr expr) {
  if (expr is Pow) {
    return (expr.base, expr.exponent);
  }
  return (expr, const Constant(1.0));
}

int _compareTerms(Expr baseA, double coeffA, Expr baseB, double coeffB) {
  final degA = _termDegree(baseA);
  final degB = _termDegree(baseB);
  if (degA != degB) {
    return degB.compareTo(degA); // Descending degree
  }
  final signA = coeffA > 0 ? 1 : -1;
  final signB = coeffB > 0 ? 1 : -1;
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
  Pow(base: Variable(), exponent: Constant(name: null, value: final v)) => v,
  Pow(
    base: Variable(),
    exponent: Neg(expr: Constant(name: null, value: final v)),
  ) =>
    -v,
  Mul(left: final l, right: final r) => _termDegree(l) + _termDegree(r),
  Neg(:final expr) => _termDegree(expr),
  Constant() => 0.0,
  _ => 0.0,
};

String _primarySymbol(Expr expr) => switch (expr) {
  Variable(:final name) => name,
  Pow(base: final b) => _primarySymbol(b),
  Neg(:final expr) => _primarySymbol(expr),
  Sin(:final expr) => 'sin_${_primarySymbol(expr)}',
  Cos(:final expr) => 'cos_${_primarySymbol(expr)}',
  Exp(:final expr) => 'exp_${_primarySymbol(expr)}',
  Ln(:final expr) => 'ln_${_primarySymbol(expr)}',
  Mul(left: final l) => _primarySymbol(l),
  Div(left: final l) => _primarySymbol(l),
  Constant(:final name) => name ?? '',
  _ => expr.toString(),
};
