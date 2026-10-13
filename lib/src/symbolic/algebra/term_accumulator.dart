import 'dart:math' as math;

import 'package:more/number.dart' show Fraction;

import '../ast.dart';
import 'simplify.dart';
import 'structural_order.dart';

extension on Fraction {
  bool get isZero => a == 0;
}

/// Accumulates additive and monomial terms, separating exact rational constants,
/// floating-point real constants, and variable monomials.
class MonomialAccumulator {
  /// Creates an empty monomial accumulator.
  ///
  /// An optional [simplify] callback performs sub-expression reduction during
  /// logarithmic combination.
  new({this.simplify});

  /// Optional simplifier callback.
  final Expr Function(Expr)? simplify;

  /// Map of (variable, point) to minimum Landau order term exponent.
  final Map<(String, Expr), int> orderTerms = {};

  /// Accumulated exact rational constant value.
  Fraction constantRational = Fraction.zero;

  /// Accumulated floating-point real constant value.
  double constantReal = 0.0;

  /// Whether any real constant or real coefficient has been folded.
  bool hasReal = false;

  /// Map of symbolic term bases to their exact rational coefficients.
  final Map<Expr, Fraction> rationalTerms = {};

  /// Map of symbolic term bases to their floating-point real coefficients.
  final Map<Expr, double> realTerms = {};

  /// Whether any transcendental term (Sin, Cos, Sinh, Cosh, Ln, etc.) was added.
  bool hasTranscendental = false;

  /// Backward-compatibility getter for exact rational constant value.
  Fraction get constantValue => constantRational;
  set constantValue(Fraction value) => constantRational = value;

  /// Backward-compatibility getter for floating-point real constant value.
  double get realValue => constantReal;
  set realValue(double value) => constantReal = value;

  /// Recursively flattens and accumulates [expr] multiplied by [scale].
  void add(Expr expr, [Fraction scale = Fraction.one]) {
    switch (expr) {
      case Add(:final left, :final right):
        add(left, scale);
        add(right, scale);
      case Sub(:final left, :final right):
        add(left, scale);
        add(right, -scale);
      case Neg(:final expr):
        add(expr, -scale);
      case OrderTerm(:final variable, :final order, :final point):
        if (!scale.isZero) {
          final key = (variable, point);
          orderTerms[key] = math.min(orderTerms[key] ?? order, order);
        }
      case RationalNumber():
        constantRational += scale * expr.toFraction();
      case RealNumber(:final value):
        hasReal = true;
        constantReal += (scale.a / scale.b) * value;
      case ComplexNumber(:final real, :final imaginary) when imaginary == 0.0:
        hasReal = true;
        constantReal += (scale.a / scale.b) * real;
      default:
        _addMonomialTerm(expr, scale);
    }
  }

  void _addMonomialTerm(Expr expr, Fraction scale) {
    if (_isTranscendental(expr)) {
      hasTranscendental = true;
    }
    final (c, base, realCoeff) = _decomposeMonomial(expr);
    if (base == RationalNumber.one) {
      if (realCoeff != null) {
        hasReal = true;
        constantReal += realCoeff * (scale.a / scale.b);
      } else {
        constantRational += scale * c;
      }
      return;
    }
    if (realCoeff != null) {
      hasReal = true;
      final totalReal = realCoeff * (scale.a / scale.b);
      realTerms[base] = (realTerms[base] ?? 0.0) + totalReal;
    } else {
      final totalCoeff = scale * c;
      rationalTerms[base] = (rationalTerms[base] ?? Fraction.zero) + totalCoeff;
    }
  }

  /// Recursively extracts all additive terms into [target] without intermediate list allocations.
  static void collectTerms(Expr expr, List<Expr> target, {int sign = 1}) {
    switch (expr) {
      case Add(:final left, :final right):
        collectTerms(left, target, sign: sign);
        collectTerms(right, target, sign: sign);
      case Sub(:final left, :final right):
        collectTerms(left, target, sign: sign);
        collectTerms(right, target, sign: -sign);
      case Neg(:final expr):
        collectTerms(expr, target, sign: -sign);
      default:
        target.add(sign == 1 ? expr : negateMonomial(expr));
    }
  }

  /// Negates a monomial term preserving its canonical structure without extra wrappers.
  static Expr negateMonomial(Expr expr) => switch (expr) {
    RationalNumber() => RationalNumber.fraction(-expr.toFraction()),
    RealNumber(:final value) => RealNumber(-value),
    ComplexNumber(:final real, :final imaginary)
        when real == 0.0 && imaginary == 1.0 =>
      Neg(expr),
    ComplexNumber(:final real, :final imaginary) => ComplexNumber(
      -real,
      -imaginary,
    ),
    Neg(:final expr) => expr,
    _ => Neg(expr),
  };

  /// Extracts polynomial coefficients with respect to [variable].
  ///
  /// Returns a map where each key $k \ge 0$ is the power of [variable] and the
  /// value is the coefficient expression independent of [variable].
  ///
  /// Returns `null` if the accumulated expression contains non-polynomial terms
  /// in [variable] (e.g. division by [variable], negative or fractional powers,
  /// transcendental functions of [variable]).
  Map<int, Expr>? extractPolynomialCoefficients(String variable) {
    final coeffMap = <int, Expr>{};

    void addCoeff(int power, Expr value) {
      if (coeffMap.containsKey(power)) {
        coeffMap[power] = Add(coeffMap[power]!, value).simplify();
      } else {
        coeffMap[power] = value;
      }
    }

    // 1. Process rational terms
    for (final entry in rationalTerms.entries) {
      if (entry.value.isZero) continue;
      final base = entry.key;
      final coeff = RationalNumber.fraction(entry.value);

      if (!base.dependsOn(variable)) {
        addCoeff(
          0,
          (coeff == RationalNumber.one ? base : Mul(coeff, base)).simplify(),
        );
      } else {
        final monomial = _extractBaseMonomial(base, variable);
        if (monomial == null) return null;
        final totalCoeff =
            (coeff == RationalNumber.one
                    ? monomial.coeff
                    : Mul(coeff, monomial.coeff))
                .simplify();
        addCoeff(monomial.power, totalCoeff);
      }
    }

    // 2. Process real terms
    for (final entry in realTerms.entries) {
      if (entry.value == 0.0) continue;
      final base = entry.key;
      final coeff = RealNumber(entry.value);

      if (!base.dependsOn(variable)) {
        addCoeff(0, Mul(coeff, base).simplify());
      } else {
        final monomial = _extractBaseMonomial(base, variable);
        if (monomial == null) return null;
        final totalCoeff = Mul(coeff, monomial.coeff).simplify();
        addCoeff(monomial.power, totalCoeff);
      }
    }

    // 3. Process constant numeric folding
    if (hasReal || constantReal != 0.0) {
      final total = constantReal + constantRational.toDouble();
      if (total != 0.0) addCoeff(0, RealNumber(total));
    } else if (!constantRational.isZero) {
      addCoeff(0, RationalNumber.fraction(constantRational));
    }

    coeffMap.removeWhere((_, c) => _isZero(c));
    return coeffMap;
  }

  /// Reduces trigonometric Pythagorean, hyperbolic Pythagorean, and
  /// logarithmic identities.
  void reduceIdentities() {
    if (!hasTranscendental) return; // O(1) bypass for polynomial expressions
    _reducePythagorean();
    _reduceHyperbolicPythagorean();
    _reduceLogarithms();
  }

  void _reducePythagorean() {
    final sinSquares = <Expr, (Expr, Fraction)>{};
    final cosSquares = <Expr, (Expr, Fraction)>{};

    for (final entry in rationalTerms.entries) {
      final uSin = _isSquareOfSin(entry.key);
      if (uSin != null) sinSquares[uSin] = (entry.key, entry.value);
      final uCos = _isSquareOfCos(entry.key);
      if (uCos != null) cosSquares[uCos] = (entry.key, entry.value);
    }

    for (final u in sinSquares.keys) {
      if (cosSquares.containsKey(u)) {
        final (sinKey, sinCoeff) = sinSquares[u]!;
        final (cosKey, cosCoeff) = cosSquares[u]!;
        if (sinCoeff == cosCoeff) {
          rationalTerms.remove(sinKey);
          rationalTerms.remove(cosKey);
          constantRational += sinCoeff;
        } else if (sinCoeff > Fraction.zero && cosCoeff > Fraction.zero) {
          final m = sinCoeff < cosCoeff ? sinCoeff : cosCoeff;
          final newSin = sinCoeff - m;
          final newCos = cosCoeff - m;
          if (newSin.isZero) {
            rationalTerms.remove(sinKey);
          } else {
            rationalTerms[sinKey] = newSin;
          }
          if (newCos.isZero) {
            rationalTerms.remove(cosKey);
          } else {
            rationalTerms[cosKey] = newCos;
          }
          constantRational += m;
        }
      }
    }

    if (constantRational == Fraction.one) {
      for (final entry in rationalTerms.entries.toList()) {
        final uSin = _isSquareOfSin(entry.key);
        if (uSin != null && entry.value == -Fraction.one) {
          rationalTerms.remove(entry.key);
          constantRational = Fraction.zero;
          final cos2 = Pow(Cos(uSin), const RationalNumber(2));
          rationalTerms[cos2] =
              (rationalTerms[cos2] ?? Fraction.zero) + Fraction.one;
          break;
        }
        final uCos = _isSquareOfCos(entry.key);
        if (uCos != null && entry.value == -Fraction.one) {
          rationalTerms.remove(entry.key);
          constantRational = Fraction.zero;
          final sin2 = Pow(Sin(uCos), const RationalNumber(2));
          rationalTerms[sin2] =
              (rationalTerms[sin2] ?? Fraction.zero) + Fraction.one;
          break;
        }
      }
    }
  }

  void _reduceHyperbolicPythagorean() {
    final coshSquares = <Expr, (Expr, Fraction)>{};
    final sinhSquares = <Expr, (Expr, Fraction)>{};

    for (final entry in rationalTerms.entries) {
      final uCosh = _isSquareOfCosh(entry.key);
      if (uCosh != null) coshSquares[uCosh] = (entry.key, entry.value);
      final uSinh = _isSquareOfSinh(entry.key);
      if (uSinh != null) sinhSquares[uSinh] = (entry.key, entry.value);
    }

    for (final u in coshSquares.keys) {
      if (sinhSquares.containsKey(u)) {
        final (coshKey, coshCoeff) = coshSquares[u]!;
        final (sinhKey, sinhCoeff) = sinhSquares[u]!;
        if (coshCoeff == -sinhCoeff && coshCoeff > Fraction.zero) {
          rationalTerms.remove(coshKey);
          rationalTerms.remove(sinhKey);
          constantRational += coshCoeff;
        }
      }
    }

    if (constantRational == Fraction.one) {
      for (final entry in rationalTerms.entries.toList()) {
        final uSinh = _isSquareOfSinh(entry.key);
        if (uSinh != null && entry.value == Fraction.one) {
          rationalTerms.remove(entry.key);
          constantRational = Fraction.zero;
          final cosh2 = Pow(Cosh(uSinh), const RationalNumber(2));
          rationalTerms[cosh2] =
              (rationalTerms[cosh2] ?? Fraction.zero) + Fraction.one;
          break;
        }
      }
    }

    if (constantRational == -Fraction.one) {
      for (final entry in rationalTerms.entries.toList()) {
        final uCosh = _isSquareOfCosh(entry.key);
        if (uCosh != null && entry.value == Fraction.one) {
          rationalTerms.remove(entry.key);
          constantRational = Fraction.zero;
          final sinh2 = Pow(Sinh(uCosh), const RationalNumber(2));
          rationalTerms[sinh2] =
              (rationalTerms[sinh2] ?? Fraction.zero) + Fraction.one;
          break;
        }
      }
    }
  }

  void _reduceLogarithms() {
    final lnEntries = [
      for (final e in rationalTerms.entries)
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
          num = num == null
              ? inner
              : (simplify != null
                    ? simplify!(Mul(num, inner))
                    : Mul(num, inner));
        } else {
          den = den == null
              ? inner
              : (simplify != null
                    ? simplify!(Mul(den, inner))
                    : Mul(den, inner));
        }
        rationalTerms.remove(e.key);
      }

      if (num != null && den != null) {
        final ratio = simplify != null
            ? simplify!(Div(num, den))
            : Div(num, den);
        final combined = simplify != null ? simplify!(Ln(ratio)) : Ln(ratio);
        add(combined, Fraction.one);
      } else if (num != null) {
        final combined = simplify != null ? simplify!(Ln(num)) : Ln(num);
        add(combined, Fraction.one);
      } else if (den != null) {
        final inv = simplify != null
            ? simplify!(Div(RationalNumber.one, den))
            : Div(RationalNumber.one, den);
        final combined = simplify != null ? simplify!(Ln(inv)) : Ln(inv);
        add(combined, Fraction.one);
      }
    }
  }

  /// Reconstructs the canonical [Expr] AST tree from accumulated terms and constants.
  Expr build() {
    _absorbOrderTerms();
    rationalTerms.removeWhere((_, coeff) => coeff.isZero);
    realTerms.removeWhere((_, coeff) => coeff == 0.0);

    // Merge rational terms into real terms where bases overlap
    for (final base in realTerms.keys.toList()) {
      if (rationalTerms.containsKey(base)) {
        final combined =
            realTerms[base]! + rationalTerms.remove(base)!.toDouble();
        if (combined == 0.0) {
          realTerms.remove(base);
        } else {
          realTerms[base] = combined;
        }
      }
    }

    final variableTerms = <(Expr, Fraction?, double?)>[];
    final realConstantTerms = <(Expr, Fraction?, double?)>[];
    final imaginaryTerms = <(Expr, Fraction?, double?)>[];

    for (final entry in rationalTerms.entries) {
      final item = (entry.key, entry.value, null);
      if (entry.key.freeVariables.isNotEmpty) {
        variableTerms.add(item);
      } else if (containsImaginaryUnit(entry.key)) {
        imaginaryTerms.add(item);
      } else {
        realConstantTerms.add(item);
      }
    }

    for (final entry in realTerms.entries) {
      final item = (entry.key, null, entry.value);
      if (entry.key.freeVariables.isNotEmpty) {
        variableTerms.add(item);
      } else if (containsImaginaryUnit(entry.key)) {
        imaginaryTerms.add(item);
      } else {
        realConstantTerms.add(item);
      }
    }

    int compareEntries(
      (Expr, Fraction?, double?) a,
      (Expr, Fraction?, double?) b,
    ) {
      final fracA = a.$2 ?? (a.$3! > 0.0 ? Fraction.one : -Fraction.one);
      final fracB = b.$2 ?? (b.$3! > 0.0 ? Fraction.one : -Fraction.one);
      return compareTerms(a.$1, fracA, b.$1, fracB);
    }

    variableTerms.sort(compareEntries);
    realConstantTerms.sort(compareEntries);
    imaginaryTerms.sort(compareEntries);

    Expr? result;

    Expr appendEntry(Expr? current, (Expr, Fraction?, double?) item) {
      final (base, ratCoeff, realCoeff) = item;
      if (ratCoeff != null) {
        if (current == null) {
          if (ratCoeff == Fraction.one) return base;
          if (ratCoeff == -Fraction.one) return _negate(base);
          return Mul(RationalNumber.fraction(ratCoeff), base);
        }
        final absCoeff = ratCoeff < Fraction.zero ? -ratCoeff : ratCoeff;
        final term = absCoeff == Fraction.one
            ? base
            : Mul(RationalNumber.fraction(absCoeff), base);
        return ratCoeff > Fraction.zero
            ? Add(current, term)
            : Sub(current, term);
      } else {
        final coeff = realCoeff!;
        if (current == null) {
          if (coeff == 1.0) return base;
          if (coeff == -1.0) return _negate(base);
          return Mul(RealNumber(coeff), base);
        }
        final absCoeff = coeff < 0.0 ? -coeff : coeff;
        final term = absCoeff == 1.0 ? base : Mul(RealNumber(absCoeff), base);
        return coeff > 0.0 ? Add(current, term) : Sub(current, term);
      }
    }

    // 1. Variable polynomial terms first
    for (final item in variableTerms) {
      result = appendEntry(result, item);
    }

    // 2. Pure real numbers / rational constants
    if (hasReal || constantReal != 0.0) {
      final total = constantReal + constantRational.toDouble();
      if (result == null) {
        result = RealNumber(total);
      } else if (total > 0.0) {
        result = Add(result, RealNumber(total));
      } else if (total < 0.0) {
        result = Sub(result, RealNumber(-total));
      }
    } else if (!constantRational.isZero) {
      if (result == null) {
        result = RationalNumber.fraction(constantRational);
      } else if (constantRational > Fraction.zero) {
        result = Add(result, RationalNumber.fraction(constantRational));
      } else {
        result = Sub(result, RationalNumber.fraction(-constantRational));
      }
    }

    // 3. Real transcendental constants (e, pi)
    for (final item in realConstantTerms) {
      result = appendEntry(result, item);
    }

    // 4. Imaginary terms containing i strictly at the end
    for (final item in imaginaryTerms) {
      result = appendEntry(result, item);
    }

    // 5. Append trailing OrderTerm instances
    for (final entry in orderTerms.entries) {
      final (variable, point) = entry.key;
      final order = entry.value;
      final term = OrderTerm(variable, order, point: point);
      result = result == null ? term : Add(result, term);
    }

    return result ?? (hasReal ? const RealNumber(0.0) : RationalNumber.zero);
  }

  void _absorbOrderTerms() {
    if (orderTerms.isEmpty) return;
    for (final entry in orderTerms.entries) {
      final (variable, point) = entry.key;
      final order = entry.value;
      final isZeroPoint = point is RationalNumber && point.isZero;

      if (isZeroPoint) {
        if (order <= 0) {
          constantRational = Fraction.zero;
          constantReal = 0.0;
        }
        rationalTerms.removeWhere((base, _) {
          final m = _extractBaseMonomial(base, variable);
          return m != null && m.power >= order;
        });
        realTerms.removeWhere((base, _) {
          final m = _extractBaseMonomial(base, variable);
          return m != null && m.power >= order;
        });
      } else {
        if (order <= 0) {
          constantRational = Fraction.zero;
          constantReal = 0.0;
        }
        rationalTerms.removeWhere(
          (base, _) => _matchesShiftedPower(base, variable, point, order),
        );
        realTerms.removeWhere(
          (base, _) => _matchesShiftedPower(base, variable, point, order),
        );
      }
    }
  }

  static bool _matchesShiftedPower(
    Expr base,
    String variable,
    Expr point,
    int minOrder,
  ) {
    if (base is Sub &&
        base.left is Variable &&
        (base.left as Variable).name == variable &&
        base.right == point) {
      return 1 >= minOrder;
    }
    if (base is Pow) {
      final pBase = base.base;
      final exp = base.exponent;
      if (pBase is Sub &&
          pBase.left is Variable &&
          (pBase.left as Variable).name == variable &&
          pBase.right == point) {
        if (exp is RationalNumber &&
            exp.isInteger &&
            exp.numerator >= minOrder) {
          return true;
        }
      }
    }
    return false;
  }

  /// Backward-compatible alias for [build].
  Expr toExpr() => build();

  static Expr _negate(Expr expr) => expr is Neg ? expr.expr : Neg(expr);
}

/// Compatibility alias for [MonomialAccumulator].
typedef TermAccumulator = MonomialAccumulator;

Expr? _isSquareOfSin(Expr term) => switch (term) {
  Pow(base: Sin(:final expr), exponent: final exp) when _isTwo(exp) => expr,
  _ => null,
};

Expr? _isSquareOfCos(Expr term) => switch (term) {
  Pow(base: Cos(:final expr), exponent: final exp) when _isTwo(exp) => expr,
  _ => null,
};

Expr? _isSquareOfSinh(Expr term) => switch (term) {
  Pow(base: Sinh(:final expr), exponent: final exp) when _isTwo(exp) => expr,
  _ => null,
};

Expr? _isSquareOfCosh(Expr term) => switch (term) {
  Pow(base: Cosh(:final expr), exponent: final exp) when _isTwo(exp) => expr,
  _ => null,
};

bool _isTwo(Expr exp) => switch (exp) {
  RationalNumber(numerator: 2, denominator: 1) => true,
  RealNumber(value: 2.0) => true,
  _ => false,
};

bool _isTranscendental(Expr expr) => switch (expr) {
  Sin() || Cos() || Tan() || Asin() || Acos() || Atan() => true,
  Sinh() || Cosh() || Tanh() => true,
  Exp() || Ln() => true,
  Pow(:final base, :final exponent) =>
    _isTranscendental(base) || _isTranscendental(exponent),
  Mul(:final left, :final right) =>
    _isTranscendental(left) || _isTranscendental(right),
  Div(:final left, :final right) =>
    _isTranscendental(left) || _isTranscendental(right),
  Add(:final left, :final right) =>
    _isTranscendental(left) || _isTranscendental(right),
  Sub(:final left, :final right) =>
    _isTranscendental(left) || _isTranscendental(right),
  Neg(:final expr) => _isTranscendental(expr),
  _ => false,
};

(Fraction, Expr, double?) _decomposeMonomial(Expr expr) {
  if (expr is RationalNumber) {
    return (expr.toFraction(), RationalNumber.one, null);
  }
  if (expr is RealNumber) return (Fraction.one, RationalNumber.one, expr.value);
  if (expr is ComplexNumber && expr.real == 0.0) {
    if (expr.imaginary == 1.0) {
      return (Fraction.one, ComplexNumber.i, null);
    }
    if (expr.imaginary == -1.0) {
      return (-Fraction.one, ComplexNumber.i, null);
    }
    return (Fraction.one, ComplexNumber.i, expr.imaginary);
  }
  if (expr is Neg) {
    final (c, b, r) = _decomposeMonomial(expr.expr);
    return (-c, b, r != null ? -r : null);
  }
  if (expr is Mul) {
    if (expr.left is RationalNumber) {
      final c1 = (expr.left as RationalNumber).toFraction();
      final (c2, b, r) = _decomposeMonomial(expr.right);
      return (c1 * c2, b, r != null ? (c1.a / c1.b) * r : null);
    }
    if (expr.right is RationalNumber) {
      final c1 = (expr.right as RationalNumber).toFraction();
      final (c2, b, r) = _decomposeMonomial(expr.left);
      return (c1 * c2, b, r != null ? (c1.a / c1.b) * r : null);
    }
    if (expr.left is RealNumber) {
      final r1 = (expr.left as RealNumber).value;
      final (c2, b, r2) = _decomposeMonomial(expr.right);
      return (Fraction.one, b, r1 * (r2 ?? (c2.a / c2.b)));
    }
    if (expr.right is RealNumber) {
      final r1 = (expr.right as RealNumber).value;
      final (c2, b, r2) = _decomposeMonomial(expr.left);
      return (Fraction.one, b, r1 * (r2 ?? (c2.a / c2.b)));
    }
  }
  if (expr is Div) {
    if (expr.right is RationalNumber) {
      final c1 = (expr.right as RationalNumber).toFraction();
      final (c2, b, r) = _decomposeMonomial(expr.left);
      return (c2 / c1, b, r != null ? r / (c1.a / c1.b) : null);
    }
    if (expr.right is RealNumber) {
      final r1 = (expr.right as RealNumber).value;
      final (c2, b, r2) = _decomposeMonomial(expr.left);
      return (Fraction.one, b, (r2 ?? (c2.a / c2.b)) / r1);
    }
  }
  return (Fraction.one, expr, null);
}

({int power, Expr coeff})? _extractBaseMonomial(Expr expr, String variable) {
  if (!expr.dependsOn(variable)) {
    return (power: 0, coeff: expr);
  }

  switch (expr) {
    case Variable(:final name) when name == variable:
      return (power: 1, coeff: RationalNumber.one);

    case Pow(:final base, :final exponent):
      if (base is Variable && base.name == variable) {
        if (exponent.dependsOn(variable)) return null;
        final p = _asPositiveInt(exponent);
        if (p == null) return null;
        return (power: p, coeff: RationalNumber.one);
      }
      return null;

    case Neg(:final expr):
      final sub = _extractBaseMonomial(expr, variable);
      if (sub == null) return null;
      return (power: sub.power, coeff: Neg(sub.coeff).simplify());

    case Mul(:final left, :final right):
      final leftDep = left.dependsOn(variable);
      final rightDep = right.dependsOn(variable);
      if (!leftDep && rightDep) {
        final sub = _extractBaseMonomial(right, variable);
        if (sub == null) return null;
        return (power: sub.power, coeff: Mul(left, sub.coeff).simplify());
      } else if (leftDep && !rightDep) {
        final sub = _extractBaseMonomial(left, variable);
        if (sub == null) return null;
        return (power: sub.power, coeff: Mul(right, sub.coeff).simplify());
      } else if (leftDep && rightDep) {
        final subL = _extractBaseMonomial(left, variable);
        final subR = _extractBaseMonomial(right, variable);
        if (subL == null || subR == null) return null;
        return (
          power: subL.power + subR.power,
          coeff: Mul(subL.coeff, subR.coeff).simplify(),
        );
      }
      return null;

    case Div(:final left, :final right):
      if (right.dependsOn(variable)) return null;
      final sub = _extractBaseMonomial(left, variable);
      if (sub == null) return null;
      return (power: sub.power, coeff: Div(sub.coeff, right).simplify());

    default:
      return null;
  }
}

int? _asPositiveInt(Expr exponent) {
  if (exponent is RationalNumber) {
    if (exponent.denominator == 1 && exponent.numerator > 0) {
      return exponent.numerator;
    }
  } else if (exponent is RealNumber) {
    if (exponent.value > 0 &&
        exponent.value == exponent.value.roundToDouble()) {
      return exponent.value.round();
    }
  }
  return null;
}

bool _isZero(Expr expr) => switch (expr) {
  RationalNumber(isZero: true) => true,
  RealNumber(value: 0.0) => true,
  ComplexNumber(real: 0.0, imaginary: 0.0) => true,
  _ => false,
};

/// Tests whether [term] is of the form $f(u)^2$ where $f$ is [targetType].
Expr? isSquareOf(Expr term, Type targetType) => switch (term) {
  Pow(:final base, :final exponent) when _isTwo(exponent) => switch (base) {
    Sin(:final expr) when targetType == Sin => expr,
    Cos(:final expr) when targetType == Cos => expr,
    Sinh(:final expr) when targetType == Sinh => expr,
    Cosh(:final expr) when targetType == Cosh => expr,
    Tan(:final expr) when targetType == Tan => expr,
    Tanh(:final expr) when targetType == Tanh => expr,
    _ => null,
  },
  _ => null,
};

/// Decomposes an expression into a scalar rational coefficient and symbolic base.
(Fraction, Expr) decomposeTerm(Expr expr) {
  if (expr is RationalNumber) {
    return (expr.toFraction(), RationalNumber.one);
  }
  if (expr is Neg) {
    final (c, b) = decomposeTerm(expr.expr);
    return (-c, b);
  }
  if (expr is Mul) {
    if (expr.left is RationalNumber) {
      final c1 = (expr.left as RationalNumber).toFraction();
      final (c2, b) = decomposeTerm(expr.right);
      return (c1 * c2, b);
    }
    if (expr.right is RationalNumber) {
      final c1 = (expr.right as RationalNumber).toFraction();
      final (c2, b) = decomposeTerm(expr.left);
      return (c1 * c2, b);
    }
  }
  if (expr is Div && expr.right is RationalNumber) {
    final c1 = (expr.right as RationalNumber).toFraction();
    final (c2, b) = decomposeTerm(expr.left);
    return (c2 / c1, b);
  }
  return (Fraction.one, expr);
}

/// Decomposes an expression into a base and an exponent factor.
(Expr, Expr) decomposeFactor(Expr expr) {
  if (expr is Pow) {
    return (expr.base, expr.exponent);
  }
  return (expr, RationalNumber.one);
}
