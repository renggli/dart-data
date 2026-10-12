import 'package:more/number.dart' show Fraction;

import '../ast.dart';
import 'structural_order.dart';

extension on Fraction {
  bool get isZero => a == 0;
}

/// Accumulates additive terms, folding exact rational and real constants,
/// combining like terms, and applying trigonometric, hyperbolic, and
/// logarithmic identities.
class TermAccumulator {
  /// Creates an empty term accumulator.
  ///
  /// An optional [simplify] closure can be supplied to perform sub-expression
  /// simplification during logarithmic product/quotient combining.
  new({this.simplify});

  /// Optional simplifier callback.
  final Expr Function(Expr)? simplify;

  /// Accumulated exact rational constant value.
  Fraction constantValue = Fraction.zero;

  /// Accumulated floating-point real constant value.
  double realValue = 0.0;

  /// Map of symbolic term bases to their rational coefficients.
  final Map<Expr, Fraction> terms = {};

  /// Recursively flattens and accumulates [expr] multiplied by [sign].
  void add(Expr expr, Fraction sign) {
    if (expr is RationalNumber) {
      constantValue += sign * expr.toFraction();
      return;
    }
    if (expr is RealNumber) {
      realValue += (sign.a / sign.b) * expr.value;
      return;
    }
    if (expr is ComplexNumber) {
      final c = expr.complex;
      if (c.a != 0) {
        if (c.a == c.a.truncateToDouble()) {
          constantValue += sign * Fraction(c.a.toInt(), 1);
        } else {
          realValue += (sign.a / sign.b) * c.a;
        }
      }
      if (c.b != 0) {
        final bFrac = c.b == c.b.truncateToDouble()
            ? Fraction(c.b.toInt(), 1)
            : Fraction.fromDouble(c.b.toDouble(), maxDenominator: 1000000);
        final totalCoeff = sign * bFrac;
        final current = terms[ConstantNumber.i] ?? Fraction.zero;
        terms[ConstantNumber.i] = current + totalCoeff;
      }
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
    final (c, base) = decomposeTerm(expr);
    final totalCoeff = sign * c;
    final current = terms[base] ?? Fraction.zero;
    terms[base] = current + totalCoeff;
  }

  /// Reduces trigonometric Pythagorean, hyperbolic Pythagorean, and
  /// logarithmic sum/difference identities.
  void reduceIdentities() {
    _reducePythagorean();
    _reduceHyperbolicPythagorean();
    _reduceLogarithms();
  }

  void _reducePythagorean() {
    final sinSquares = <Expr, (Expr, Fraction)>{};
    final cosSquares = <Expr, (Expr, Fraction)>{};

    for (final entry in terms.entries) {
      final uSin = isSquareOf(entry.key, Sin);
      if (uSin != null) {
        sinSquares[uSin] = (entry.key, entry.value);
      }
      final uCos = isSquareOf(entry.key, Cos);
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
        final uSin = isSquareOf(entry.key, Sin);
        if (uSin != null && entry.value == -Fraction.one) {
          terms.remove(entry.key);
          constantValue = Fraction.zero;
          final cos2 = Pow(Cos(uSin), const RationalNumber(2));
          terms[cos2] = (terms[cos2] ?? Fraction.zero) + Fraction.one;
          break;
        }
        final uCos = isSquareOf(entry.key, Cos);
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
      final uCosh = isSquareOf(entry.key, Cosh);
      if (uCosh != null) {
        coshSquares[uCosh] = (entry.key, entry.value);
      }
      final uSinh = isSquareOf(entry.key, Sinh);
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
        final uSinh = isSquareOf(entry.key, Sinh);
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
        final uCosh = isSquareOf(entry.key, Cosh);
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
        terms.remove(e.key);
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

  /// Reconstructs a canonical [Expr] tree from accumulated terms and constants.
  Expr toExpr() {
    // Filter out terms with zero coefficient
    terms.removeWhere((_, coeff) => coeff.isZero);

    final iCoeff = terms[ConstantNumber.i];
    final nonITerms = [
      for (final entry in terms.entries)
        if (entry.key != ConstantNumber.i) entry,
    ];

    // Case 1: Purely numerical / complex (no variable terms)
    if (nonITerms.isEmpty) {
      // 1a. Pure real constant
      if (iCoeff == null) {
        if (realValue != 0.0) {
          return RealNumber(realValue + constantValue.toDouble());
        }
        if (constantValue.isZero) return RationalNumber.zero;
        return RationalNumber.fraction(constantValue);
      }

      // 1b. Pure imaginary constant (no real part)
      if (constantValue.isZero && realValue == 0.0) {
        if (iCoeff == Fraction.one) return ConstantNumber.i;
        if (iCoeff == -Fraction.one) return const Neg(ConstantNumber.i);
        return Mul(RationalNumber.fraction(iCoeff), ConstantNumber.i);
      }

      // 1c. Gaussian complex number: a + b*i or a - b*i
      final realPart = realValue != 0.0
          ? RealNumber(realValue + constantValue.toDouble())
          : (!constantValue.isZero
                ? RationalNumber.fraction(constantValue)
                : RationalNumber.zero);
      final absCoeff = iCoeff < Fraction.zero ? -iCoeff : iCoeff;
      final imagPart = absCoeff == Fraction.one
          ? ConstantNumber.i
          : Mul(RationalNumber.fraction(absCoeff), ConstantNumber.i);
      return iCoeff > Fraction.zero
          ? Add(realPart, imagPart)
          : Sub(realPart, imagPart);
    }

    // Case 2: General polynomial terms with variables
    final sortedEntries = nonITerms
      ..sort((a, b) => compareTerms(a.key, a.value, b.key, b.value));

    Expr? result;
    for (final entry in sortedEntries) {
      final base = entry.key;
      final coeff = entry.value;

      if (result == null) {
        if (coeff == Fraction.one) {
          result = base;
        } else if (coeff == -Fraction.one) {
          result = _negate(base);
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

    if (realValue != 0.0) {
      final total = realValue + constantValue.toDouble();
      if (result == null) {
        result = RealNumber(total);
      } else if (total > 0.0) {
        result = Add(result, RealNumber(total));
      } else {
        result = Sub(result, RealNumber(-total));
      }
    } else if (!constantValue.isZero) {
      if (result == null) {
        result = RationalNumber.fraction(constantValue);
      } else if (constantValue > Fraction.zero) {
        result = Add(result, RationalNumber.fraction(constantValue));
      } else {
        result = Sub(result, RationalNumber.fraction(-constantValue));
      }
    }

    if (iCoeff != null) {
      final absCoeff = iCoeff < Fraction.zero ? -iCoeff : iCoeff;
      final imagPart = absCoeff == Fraction.one
          ? ConstantNumber.i
          : Mul(RationalNumber.fraction(absCoeff), ConstantNumber.i);
      if (result == null) {
        result = iCoeff > Fraction.zero ? imagPart : _negate(imagPart);
      } else if (iCoeff > Fraction.zero) {
        result = Add(result, imagPart);
      } else {
        result = Sub(result, imagPart);
      }
    }

    return result ?? RationalNumber.zero;
  }

  static Expr _negate(Expr expr) => expr is Neg ? expr.expr : Neg(expr);
}

/// Tests whether [term] is of the form $f(u)^2$ where $f$ is [targetType].
Expr? isSquareOf(Expr term, Type targetType) {
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
