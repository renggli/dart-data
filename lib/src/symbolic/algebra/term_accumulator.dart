import 'dart:math' as math;

import '../ast.dart';
import 'expand.dart';
import 'simplify.dart';
import 'structural_order.dart';

/// Accumulates additive and monomial terms, separating numeric constants
/// and symbolic monomials.
class MonomialAccumulator {
  /// Creates an empty monomial accumulator.
  ///
  /// An optional [simplify] callback performs sub-expression reduction during
  /// logarithmic and fraction combination.
  new({this.simplify});

  /// Optional simplifier callback.
  final Expr Function(Expr)? simplify;

  /// Map of (variable, point) to minimum Landau order term exponent.
  final Map<(String, Expr), int> orderTerms = {};

  /// Accumulated numeric constant value.
  Number constant = IntegerNumber.zero;

  /// Whether any floating-point [RealNumber] has been accumulated.
  bool hasReal = false;

  /// Map of symbolic term bases to their numeric coefficients.
  final Map<Expr, Number> terms = {};

  /// Whether any transcendental term (Sin, Cos, Sinh, Cosh, Ln, etc.) was added.
  bool hasTranscendental = false;

  /// Recursively flattens and accumulates [expr] multiplied by [scale].
  void add(Expr expr, [Number scale = IntegerNumber.one]) {
    if (_containsRealNumber(scale)) {
      hasReal = true;
    }
    if (scale.isZero) return;

    switch (expr) {
      case Add(:final terms):
        for (final term in terms) {
          add(term, scale);
        }
      case Mul(factors: [Number(isNegativeOne: true), final Add innerAdd]):
        add(innerAdd, scale.neg());
      case OrderTerm(:final variable, :final order, :final point):
        final key = (variable, point);
        orderTerms[key] = math.min(orderTerms[key] ?? order, order);
      case Number():
        if (_containsRealNumber(expr)) {
          hasReal = true;
        }
        constant = constant.add(scale.mul(expr));
      default:
        _addMonomialTerm(expr, scale);
    }
  }

  void _addMonomialTerm(Expr expr, Number scale) {
    final (c, base) = decomposeTerm(expr);
    addDecomposed(scale.mul(c), base);
  }

  /// Directly accumulates a pre-decomposed [coeff] and canonical symbolic [base].
  void addDecomposed(Number coeff, Expr base) {
    if (_containsRealNumber(coeff)) {
      hasReal = true;
    }
    if (coeff.isZero) return;
    if (base is Number && base.isOne) {
      constant = constant.add(coeff);
      return;
    }
    if (!hasTranscendental && _isReducibleTranscendentalBase(base)) {
      hasTranscendental = true;
    }
    final existing = terms[base];
    final nextCoeff = existing == null ? coeff : existing.add(coeff);
    if (nextCoeff.isZero) {
      terms.remove(base);
    } else {
      terms[base] = nextCoeff;
    }
  }

  /// Recursively extracts all additive terms into [target] without intermediate list allocations.
  static void collectTerms(Expr expr, List<Expr> target, {int sign = 1}) {
    switch (expr) {
      case Add(:final terms):
        for (final term in terms) {
          collectTerms(term, target, sign: sign);
        }
      case Mul(factors: [Number(isNegativeOne: true), final Add innerAdd]):
        collectTerms(innerAdd, target, sign: -sign);
      default:
        target.add(sign == 1 ? expr : negateMonomial(expr));
    }
  }

  /// Negates a monomial term preserving its canonical structure without extra wrappers.
  static Expr negateMonomial(Expr expr) => switch (expr) {
    Number() => expr.neg(),
    Mul(factors: [final Number first, ...final rest], :final isSimplified) =>
      () {
        final negFirst = first.neg();
        if (negFirst.isOne) {
          return switch (rest) {
            [final single] => single,
            _ => Mul(rest, isSimplified: isSimplified),
          };
        }
        return Mul([negFirst, ...rest], isSimplified: isSimplified);
      }(),
    Mul(:final factors, :final isSimplified) when factors.isNotEmpty => Mul([
      IntegerNumber.negativeOne,
      ...factors,
    ], isSimplified: isSimplified),
    _ => Mul([
      IntegerNumber.negativeOne,
      expr,
    ], isSimplified: expr.isSimplified),
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
        coeffMap[power] = simplifyAdd([coeffMap[power]!, value]);
      } else {
        coeffMap[power] = value;
      }
    }

    for (final MapEntry(key: base, value: coeff) in terms.entries) {
      if (coeff.isZero) continue;

      if (!base.dependsOn(variable)) {
        addCoeff(0, coeff.isOne ? base : simplifyMul([coeff, base]));
      } else {
        final monomial = _extractBaseMonomial(base, variable);
        if (monomial == null) return null;
        final totalCoeff = coeff.isOne
            ? monomial.coeff
            : simplifyMul([coeff, monomial.coeff]);
        addCoeff(monomial.power, totalCoeff);
      }
    }

    if (!constant.isZero) {
      addCoeff(0, constant);
    }

    coeffMap.removeWhere((_, c) => c is Number && c.isZero);
    return coeffMap;
  }

  /// Reduces trigonometric Pythagorean, hyperbolic Pythagorean, and
  /// logarithmic identities.
  void reduceIdentities() {
    if (!hasTranscendental) return;
    _reducePythagorean();
    _reduceHyperbolicPythagorean();
    _reduceLogarithms();
  }

  void _reducePythagorean() {
    final sinSquares = <Expr, (Expr, RationalNumber)>{};
    final cosSquares = <Expr, (Expr, RationalNumber)>{};

    for (final MapEntry(:key, value: coeff) in terms.entries) {
      if (coeff is! RationalNumber) continue;
      final uSin = _isSquareOfSin(key);
      if (uSin != null) sinSquares[uSin] = (key, coeff);
      final uCos = _isSquareOfCos(key);
      if (uCos != null) cosSquares[uCos] = (key, coeff);
    }

    for (final u in sinSquares.keys) {
      if (cosSquares.containsKey(u)) {
        final (sinKey, sinCoeff) = sinSquares[u]!;
        final (cosKey, cosCoeff) = cosSquares[u]!;
        if (sinCoeff == cosCoeff) {
          terms.remove(sinKey);
          terms.remove(cosKey);
          constant = constant.add(sinCoeff);
        } else if (!sinCoeff.isNegative && !cosCoeff.isNegative) {
          final m = sinCoeff.compareTo(cosCoeff) < 0 ? sinCoeff : cosCoeff;
          final newSin = sinCoeff.subRational(m);
          final newCos = cosCoeff.subRational(m);
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
          constant = constant.add(m);
        }
      }
    }

    if (constant == IntegerNumber.one) {
      for (final MapEntry(:key, :value) in terms.entries.toList()) {
        final uSin = _isSquareOfSin(key);
        if (uSin != null && value == IntegerNumber.negativeOne) {
          terms.remove(key);
          constant = IntegerNumber.zero;
          final cos2 = Pow(
            Cos(uSin, isSimplified: true),
            IntegerNumber.two,
            isSimplified: true,
          );
          final existing = terms[cos2];
          terms[cos2] = existing == null
              ? IntegerNumber.one
              : existing.add(IntegerNumber.one);
          break;
        }
        final uCos = _isSquareOfCos(key);
        if (uCos != null && value == IntegerNumber.negativeOne) {
          terms.remove(key);
          constant = IntegerNumber.zero;
          final sin2 = Pow(
            Sin(uCos, isSimplified: true),
            IntegerNumber.two,
            isSimplified: true,
          );
          final existing = terms[sin2];
          terms[sin2] = existing == null
              ? IntegerNumber.one
              : existing.add(IntegerNumber.one);
          break;
        }
      }
    }
  }

  void _reduceHyperbolicPythagorean() {
    final coshSquares = <Expr, (Expr, RationalNumber)>{};
    final sinhSquares = <Expr, (Expr, RationalNumber)>{};

    for (final MapEntry(:key, value: coeff) in terms.entries) {
      if (coeff is! RationalNumber) continue;
      final uCosh = _isSquareOfCosh(key);
      if (uCosh != null) coshSquares[uCosh] = (key, coeff);
      final uSinh = _isSquareOfSinh(key);
      if (uSinh != null) sinhSquares[uSinh] = (key, coeff);
    }

    for (final u in coshSquares.keys) {
      if (sinhSquares.containsKey(u)) {
        final (coshKey, coshCoeff) = coshSquares[u]!;
        final (sinhKey, sinhCoeff) = sinhSquares[u]!;
        if (coshCoeff == sinhCoeff.neg() && !coshCoeff.isNegative) {
          terms.remove(coshKey);
          terms.remove(sinhKey);
          constant = constant.add(coshCoeff);
        }
      }
    }

    if (constant == IntegerNumber.one) {
      for (final MapEntry(:key, :value) in terms.entries.toList()) {
        final uSinh = _isSquareOfSinh(key);
        if (uSinh != null && value == IntegerNumber.one) {
          terms.remove(key);
          constant = IntegerNumber.zero;
          final cosh2 = Pow(
            Cosh(uSinh, isSimplified: true),
            IntegerNumber.two,
            isSimplified: true,
          );
          final existing = terms[cosh2];
          terms[cosh2] = existing == null
              ? IntegerNumber.one
              : existing.add(IntegerNumber.one);
          break;
        }
      }
    }

    if (constant == IntegerNumber.negativeOne) {
      for (final MapEntry(:key, :value) in terms.entries.toList()) {
        final uCosh = _isSquareOfCosh(key);
        if (uCosh != null && value == IntegerNumber.one) {
          terms.remove(key);
          constant = IntegerNumber.zero;
          final sinh2 = Pow(
            Sinh(uCosh, isSimplified: true),
            IntegerNumber.two,
            isSimplified: true,
          );
          final existing = terms[sinh2];
          terms[sinh2] = existing == null
              ? IntegerNumber.one
              : existing.add(IntegerNumber.one);
          break;
        }
      }
    }
  }

  void _reduceLogarithms() {
    final lnEntries = [
      for (final e in terms.entries)
        if (e.key is Ln &&
            e.value is RationalNumber &&
            (e.value.isOne || e.value.isNegativeOne))
          e,
    ];

    if (simplify != null && lnEntries.length >= 2) {
      Expr? num;
      Expr? den;

      for (final MapEntry(key: lnKey, :value) in lnEntries) {
        final inner = (lnKey as Ln).expr;
        if (value.isOne) {
          num = num == null ? inner : simplifyMul([num, inner]);
        } else {
          den = den == null ? inner : simplifyMul([den, inner]);
        }
        terms.remove(lnKey);
      }

      if (num != null && den != null) {
        final ratio = simplifyDiv(num, den);
        final isNonPositiveRatio = switch (ratio) {
          RealNumeric(:final isNegative, :final isZero) => isNegative || isZero,
          Mul(factors: [RealNumeric(isNegative: true), ...]) => true,
          _ => false,
        };
        if (isNonPositiveRatio) {
          for (final MapEntry(:key, :value) in lnEntries) {
            terms[key] = value;
          }
        } else {
          final combined = simplifyLn(ratio);
          add(combined, IntegerNumber.one);
        }
      } else if (num != null) {
        final combined = simplifyLn(num);
        add(combined, IntegerNumber.one);
      } else if (den != null) {
        final inv = simplifyPow(den, IntegerNumber.negativeOne);
        final combined = simplifyLn(inv);
        add(combined, IntegerNumber.one);
      }
    }
  }

  /// Reconstructs the canonical [Expr] AST tree from accumulated terms and constants.
  Expr build() {
    _absorbOrderTerms();
    if (simplify != null) {
      combineFractions();
    }
    terms.removeWhere((_, coeff) => coeff.isZero);

    final sortedKeys = terms.keys.toList()..sort(compareStructural);
    final resultTerms = <Expr>[];

    // 1. Non-zero numeric constant first (Number has nodeTag == 0)
    if (!constant.isZero) {
      resultTerms.add(
        hasReal && constant is RationalNumber
            ? RealNumber(constant.toDouble())
            : constant,
      );
    }

    // 2. Symbolic terms in canonical structural order
    for (final base in sortedKeys) {
      final coeff = terms[base]!;
      if (coeff.isOne) {
        resultTerms.add(base);
      } else if (base case Mul(:final factors)) {
        resultTerms.add(Mul([coeff, ...factors], isSimplified: true));
      } else {
        resultTerms.add(Mul([coeff, base], isSimplified: true));
      }
    }

    // 3. Trailing OrderTerm instances (OrderTerm has nodeTag == 31)
    if (orderTerms.isNotEmpty) {
      final sortedOrderEntries = orderTerms.entries.toList()
        ..sort((a, b) {
          final (varA, pointA) = a.key;
          final (varB, pointB) = b.key;
          final cmpVar = varA.compareTo(varB);
          if (cmpVar != 0) return cmpVar;
          final cmpOrd = a.value.compareTo(b.value);
          if (cmpOrd != 0) return cmpOrd;
          return compareStructural(pointA, pointB);
        });
      for (final MapEntry(key: (variable, point), value: order)
          in sortedOrderEntries) {
        resultTerms.add(OrderTerm(variable, order, point: point));
      }
    }

    return switch (resultTerms) {
      [] => hasReal ? RealNumber.zero : IntegerNumber.zero,
      [final single] => single,
      _ => Add(resultTerms, isSimplified: true),
    };
  }

  void _absorbOrderTerms() {
    if (orderTerms.isEmpty) return;
    for (final MapEntry(key: (variable, point), value: order)
        in orderTerms.entries) {
      final isZeroPoint = point is Number && point.isZero;

      if (isZeroPoint) {
        if (order <= 0) {
          constant = IntegerNumber.zero;
        }
        terms.removeWhere((base, _) {
          final m = _extractBaseMonomial(base, variable);
          return m != null && m.power >= order;
        });
      } else {
        if (order <= 0) {
          constant = IntegerNumber.zero;
        }
        terms.removeWhere(
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
    final shifted = simplifySub(Variable(variable), point);
    final rawShifted = Variable(variable) - point;
    if (base == shifted || base == rawShifted) {
      return 1 >= minOrder;
    }
    return switch (base) {
      Pow(base: final pBase, exponent: IntegerNumber(asInt: final k?))
          when (pBase == shifted || pBase == rawShifted) && k >= minOrder =>
        true,
      Mul(:final factors) => factors.any(
        (f) => _matchesShiftedPower(f, variable, point, minOrder),
      ),
      _ => false,
    };
  }

  bool _isCombiningFractions = false;

  /// Combines fractions with identical denominators.
  void combineFractions() {
    if (_isCombiningFractions) return;
    _isCombiningFractions = true;
    try {
      _doCombineFractions();
    } finally {
      _isCombiningFractions = false;
    }
  }

  void _doCombineFractions() {
    if (terms.length < 2) return;
    Map<Expr, List<(Expr base, Expr numPart, Number coeff)>>? groups;

    for (final MapEntry(key: base, value: coeff) in terms.entries) {
      if (coeff.isZero) continue;

      if (_splitFractionBase(base) case (final numPart, final denPart)) {
        (groups ??= {}).putIfAbsent(denPart, () => []).add((
          base,
          numPart,
          coeff,
        ));
      }
    }

    if (groups == null) return;

    for (final MapEntry(key: den, value: items) in groups.entries) {
      if (items.length < 2) continue;

      for (final (base, _, _) in items) {
        terms.remove(base);
      }

      final numerators = <Expr>[];
      for (final (_, numPart, coeff) in items) {
        if (coeff.isOne) {
          numerators.add(numPart);
        } else if (coeff.isNegativeOne) {
          numerators.add(simplifyNeg(numPart));
        } else {
          numerators.add(simplifyMul([coeff, numPart]));
        }
      }

      final totalNum = Add(numerators);
      final simplifiedNum = totalNum.expand().simplify();

      if (simplifiedNum is Number && simplifiedNum.isZero) {
        // Combined numerator is 0: sum is 0, nothing added.
      } else if (simplifiedNum == den ||
          _isAlgebraicallyZero(simplifySub(simplifiedNum, den))) {
        add(IntegerNumber.one);
      } else if (_isAlgebraicallyZero(simplifyAdd([simplifiedNum, den]))) {
        add(IntegerNumber.negativeOne);
      } else {
        final combined = simplifyDiv(simplifiedNum, den);
        add(combined);
      }
    }
  }

  static bool _isNegativePower(Expr expr) => switch (expr) {
    Pow(exponent: RealNumeric(isNegative: true)) => true,
    _ => false,
  };

  static (Expr numPart, Expr denPart)? _splitFractionBase(Expr base) {
    if (base case Pow(base: final innerBase, exponent: final RealNumeric exp)
        when exp.isNegative) {
      final posExp = exp.neg();
      final den = posExp.isOne
          ? innerBase
          : Pow(innerBase, posExp, isSimplified: true);
      return (IntegerNumber.one, den);
    }
    if (base case Mul(:final factors) when factors.any(_isNegativePower)) {
      final numFactors = <Expr>[];
      final denFactors = <Expr>[];
      for (final f in factors) {
        if (f case Pow(base: final innerBase, exponent: final RealNumeric exp)
            when exp.isNegative) {
          final posExp = exp.neg();
          denFactors.add(
            posExp.isOne
                ? innerBase
                : Pow(innerBase, posExp, isSimplified: true),
          );
        } else {
          numFactors.add(f);
        }
      }
      final numPart = switch (numFactors) {
        [] => IntegerNumber.one,
        [final single] => single,
        _ => Mul(numFactors, isSimplified: true),
      };
      final denPart = switch (denFactors) {
        [final single] => single,
        _ => Mul(denFactors, isSimplified: true),
      };
      return (numPart, denPart);
    }
    return null;
  }

  static bool _isAlgebraicallyZero(Expr expr) {
    if (expr is Number && expr.isZero) return true;
    final s = expr.expand().simplify();
    return s is Number && s.isZero;
  }
}

/// Decomposes an expression into a scalar [Number] coefficient and symbolic base.
(Number, Expr) decomposeTerm(Expr expr) {
  if (expr is Number) {
    return (expr, IntegerNumber.one);
  }
  if (expr is Mul) {
    var coeff = IntegerNumber.one as Number;
    final nonNumeric = <Expr>[];

    void collect(Expr e) {
      switch (e) {
        case Mul(:final factors):
          for (final f in factors) {
            collect(f);
          }
        case Number():
          coeff = coeff.mul(e);
        default:
          nonNumeric.add(e);
      }
    }

    collect(expr);
    if (coeff.isZero || nonNumeric.isEmpty) {
      return (coeff, IntegerNumber.one);
    }
    return switch (nonNumeric) {
      [final single] => (coeff, single),
      _ => (coeff, Mul(nonNumeric, isSimplified: expr.isSimplified)),
    };
  }
  return (IntegerNumber.one, expr);
}

/// Decomposes an expression into a base and an exponent factor.
(Expr, Expr) decomposeFactor(Expr expr) => switch (expr) {
  Pow(:final base, :final exponent) => (base, exponent),
  _ => (expr, IntegerNumber.one),
};

/// Splits an expression into `(numerator, denominator)` by extracting
/// [FractionNumber] denominators and negative-exponent [Pow] factors.
///
/// When [expr] has no denominator factors, returns `(expr, IntegerNumber.one)`.
(Expr, Expr) splitNumeratorDenominator(Expr expr) => switch (expr) {
  FractionNumber(:final numerator, :final denominator) => (
    IntegerNumber(numerator),
    IntegerNumber(denominator),
  ),
  Pow(:final base, exponent: final RealNumeric exp, :final isSimplified)
      when exp.isNegative =>
    () {
      final posExp = exp.neg();
      final den = posExp.isOne
          ? base
          : Pow(base, posExp, isSimplified: isSimplified);
      return (IntegerNumber.one, den);
    }(),
  Mul(:final factors, :final isSimplified) => () {
    final numFactors = <Expr>[];
    final denFactors = <Expr>[];
    for (final f in factors) {
      switch (f) {
        case FractionNumber(:final numerator, :final denominator):
          if (!numerator.isOne) {
            numFactors.add(IntegerNumber(numerator));
          }
          denFactors.add(IntegerNumber(denominator));
        case Pow(
              :final base,
              exponent: final RealNumeric exp,
              isSimplified: final fSimplified,
            )
            when exp.isNegative:
          final posExp = exp.neg();
          denFactors.add(
            posExp.isOne ? base : Pow(base, posExp, isSimplified: fSimplified),
          );
        default:
          numFactors.add(f);
      }
    }
    if (denFactors.isEmpty) return (expr, IntegerNumber.one);
    final numPart = switch (numFactors) {
      [] => IntegerNumber.one,
      [final single] => single,
      _ => Mul(numFactors, isSimplified: isSimplified),
    };
    final denPart = switch (denFactors) {
      [final single] => single,
      _ => Mul(denFactors, isSimplified: isSimplified),
    };
    return (numPart, denPart);
  }(),
  _ => (expr, IntegerNumber.one),
};

/// Computes the degree of [expr] as a univariate polynomial in [variable],
/// or returns `null` if [expr] is not a polynomial in [variable].
int? polynomialDegree(Expr expr, String variable) {
  if (!expr.dependsOn(variable)) return 0;
  return switch (expr) {
    Variable(:final name) when name == variable => 1,
    Add(:final terms) => () {
      var maxD = 0;
      for (final t in terms) {
        final d = polynomialDegree(t, variable);
        if (d == null) return null;
        if (d > maxD) maxD = d;
      }
      return maxD;
    }(),
    Mul(:final factors) => () {
      var sumD = 0;
      for (final f in factors) {
        final d = polynomialDegree(f, variable);
        if (d == null) return null;
        sumD += d;
      }
      return sumD;
    }(),
    Pow(:final base, exponent: IntegerNumber(:final value))
        when value >= Integer.zero && !value.isBig =>
      () {
        final db = polynomialDegree(base, variable);
        return db != null ? db * value.toInt() : null;
      }(),
    Pow(:final base, exponent: RealNumber(:final value))
        when value >= 0 && value == value.roundToDouble() =>
      () {
        final db = polynomialDegree(base, variable);
        return db != null ? db * value.round() : null;
      }(),
    _ => null,
  };
}

/// Extracts univariate polynomial coefficients for [expr] in [variable].
///
/// Returns a map where each key $k \ge 0$ is the power of [variable] and the
/// value is the coefficient expression independent of [variable], or `null` if
/// [expr] is not a polynomial in [variable].
Map<int, Expr>? extractPolynomialCoefficients(Expr expr, String variable) {
  final expanded = expr.expand().simplify();
  if (!expanded.dependsOn(variable)) {
    return expanded is Number && expanded.isZero
        ? {0: IntegerNumber.zero}
        : {0: expanded};
  }
  if (polynomialDegree(expanded, variable) == null) return null;
  final acc = MonomialAccumulator()..add(expanded);
  return acc.extractPolynomialCoefficients(variable);
}

/// Returns the maximum degree $k \ge 0$ with a non-zero coefficient in [coeffs],
/// or `-1` if [coeffs] has no non-zero terms.
int maxPolynomialDegree(Map<int, Expr> coeffs) {
  var maxD = -1;
  for (final MapEntry(key: deg, value: coeff) in coeffs.entries) {
    if (!MonomialAccumulator._isAlgebraicallyZero(coeff) && deg > maxD) {
      maxD = deg;
    }
  }
  return maxD;
}

/// Reconstructs a simplified polynomial [Expr] in [variable] from a
/// degree-to-coefficient map [coeffs].
Expr buildPolynomialFromCoefficients(Map<int, Expr> coeffs, String variable) {
  final x = Variable(variable);
  final terms = <Expr>[];
  final sortedDegrees = coeffs.keys.toList()..sort();
  for (final deg in sortedDegrees) {
    final c = coeffs[deg]!.simplify();
    if (MonomialAccumulator._isAlgebraicallyZero(c)) continue;
    final xPow = deg == 0
        ? IntegerNumber.one
        : deg == 1
        ? x
        : Pow(x, IntegerNumber.of(deg));
    terms.add(deg == 0 ? c : (c * xPow).simplify());
  }
  return switch (terms) {
    [] => IntegerNumber.zero,
    [final single] => single,
    _ => Add(terms).simplify(),
  };
}

bool _containsRealNumber(Number n) => switch (n) {
  RealNumber() => true,
  ComplexNumber(:final real, :final imaginary) =>
    real is RealNumber || imaginary is RealNumber,
  _ => false,
};

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

bool _isTwo(Expr exp) =>
    exp == IntegerNumber.two || (exp is RealNumber && exp.value == 2.0);

bool _isReducibleTranscendentalBase(Expr base) => switch (base) {
  Ln() => true,
  Pow(base: Sin() || Cos() || Sinh() || Cosh()) => true,
  _ => false,
};

({int power, Expr coeff})? _extractBaseMonomial(Expr expr, String variable) {
  if (!expr.dependsOn(variable)) {
    return (power: 0, coeff: expr);
  }

  switch (expr) {
    case Variable(:final name) when name == variable:
      return (power: 1, coeff: IntegerNumber.one);

    case Pow(base: Variable(:final name), :final exponent)
        when name == variable && !exponent.dependsOn(variable):
      final p = _asPositiveInt(exponent);
      if (p == null) return null;
      return (power: p, coeff: IntegerNumber.one);

    case Mul(:final factors):
      var totalPower = 0;
      final coeffFactors = <Expr>[];
      for (final f in factors) {
        if (!f.dependsOn(variable)) {
          coeffFactors.add(f);
        } else {
          final sub = _extractBaseMonomial(f, variable);
          if (sub == null) return null;
          totalPower += sub.power;
          if (sub.coeff case final c when !(c is Number && c.isOne)) {
            coeffFactors.add(c);
          }
        }
      }
      final totalCoeff = coeffFactors.isEmpty
          ? IntegerNumber.one
          : simplifyMul(coeffFactors);
      return (power: totalPower, coeff: totalCoeff);

    default:
      return null;
  }
}

int? _asPositiveInt(Expr exponent) => switch (exponent) {
  IntegerNumber(asInt: final v?) when v > 0 => v,
  RealNumber(:final value) when value > 0 && value == value.roundToDouble() =>
    value.round(),
  _ => null,
};
