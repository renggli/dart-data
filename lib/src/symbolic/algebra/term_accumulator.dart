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
  static Expr negateMonomial(Expr expr) {
    if (expr is Number) {
      return expr.neg();
    }
    if (expr is Mul && expr.factors.isNotEmpty) {
      final first = expr.factors.first;
      if (first is Number) {
        final negFirst = first.neg();
        final rest = expr.factors.sublist(1);
        if (negFirst.isOne) {
          return rest.length == 1
              ? rest.first
              : Mul(rest, isSimplified: expr.isSimplified);
        }
        return Mul([negFirst, ...rest], isSimplified: expr.isSimplified);
      }
      return Mul([
        IntegerNumber.negativeOne,
        ...expr.factors,
      ], isSimplified: expr.isSimplified);
    }
    return Mul([
      IntegerNumber.negativeOne,
      expr,
    ], isSimplified: expr.isSimplified);
  }

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

    for (final entry in terms.entries) {
      final coeff = entry.value;
      if (coeff.isZero) continue;
      final base = entry.key;

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

    for (final entry in terms.entries) {
      final coeff = entry.value;
      if (coeff is! RationalNumber) continue;
      final uSin = _isSquareOfSin(entry.key);
      if (uSin != null) sinSquares[uSin] = (entry.key, coeff);
      final uCos = _isSquareOfCos(entry.key);
      if (uCos != null) cosSquares[uCos] = (entry.key, coeff);
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
      for (final entry in terms.entries.toList()) {
        final uSin = _isSquareOfSin(entry.key);
        if (uSin != null && entry.value == IntegerNumber.negativeOne) {
          terms.remove(entry.key);
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
        final uCos = _isSquareOfCos(entry.key);
        if (uCos != null && entry.value == IntegerNumber.negativeOne) {
          terms.remove(entry.key);
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

    for (final entry in terms.entries) {
      final coeff = entry.value;
      if (coeff is! RationalNumber) continue;
      final uCosh = _isSquareOfCosh(entry.key);
      if (uCosh != null) coshSquares[uCosh] = (entry.key, coeff);
      final uSinh = _isSquareOfSinh(entry.key);
      if (uSinh != null) sinhSquares[uSinh] = (entry.key, coeff);
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
      for (final entry in terms.entries.toList()) {
        final uSinh = _isSquareOfSinh(entry.key);
        if (uSinh != null && entry.value == IntegerNumber.one) {
          terms.remove(entry.key);
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
      for (final entry in terms.entries.toList()) {
        final uCosh = _isSquareOfCosh(entry.key);
        if (uCosh != null && entry.value == IntegerNumber.one) {
          terms.remove(entry.key);
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

      for (final e in lnEntries) {
        final inner = (e.key as Ln).expr;
        if (e.value.isOne) {
          num = num == null ? inner : simplifyMul([num, inner]);
        } else {
          den = den == null ? inner : simplifyMul([den, inner]);
        }
        terms.remove(e.key);
      }

      if (num != null && den != null) {
        final ratio = simplifyDiv(num, den);
        if ((ratio is RealNumeric && (ratio.isNegative || ratio.isZero)) ||
            (ratio is Mul &&
                ratio.factors.isNotEmpty &&
                ratio.factors.first is RealNumeric &&
                (ratio.factors.first as RealNumeric).isNegative)) {
          for (final e in lnEntries) {
            terms[e.key] = e.value;
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
      } else if (base is Mul) {
        resultTerms.add(Mul([coeff, ...base.factors], isSimplified: true));
      } else {
        resultTerms.add(Mul([coeff, base], isSimplified: true));
      }
    }

    // 3. Trailing OrderTerm instances (OrderTerm has nodeTag == 31)
    if (orderTerms.isNotEmpty) {
      final sortedOrderEntries = orderTerms.entries.toList()
        ..sort((a, b) {
          final cmpVar = a.key.$1.compareTo(b.key.$1);
          if (cmpVar != 0) return cmpVar;
          final cmpOrd = a.value.compareTo(b.value);
          if (cmpOrd != 0) return cmpOrd;
          return compareStructural(a.key.$2, b.key.$2);
        });
      for (final entry in sortedOrderEntries) {
        final (variable, point) = entry.key;
        final order = entry.value;
        resultTerms.add(OrderTerm(variable, order, point: point));
      }
    }

    if (resultTerms.isEmpty) {
      return hasReal ? RealNumber.zero : IntegerNumber.zero;
    }
    if (resultTerms.length == 1) {
      return resultTerms.first;
    }
    return Add(resultTerms, isSimplified: true);
  }

  void _absorbOrderTerms() {
    if (orderTerms.isEmpty) return;
    for (final entry in orderTerms.entries) {
      final (variable, point) = entry.key;
      final order = entry.value;
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
    if (base is Pow) {
      final pBase = base.base;
      final exp = base.exponent;
      if ((pBase == shifted || pBase == rawShifted) && exp is IntegerNumber) {
        final k = exp.asInt;
        if (k != null && k >= minOrder) {
          return true;
        }
      }
    }
    if (base is Mul) {
      return base.factors.any(
        (f) => _matchesShiftedPower(f, variable, point, minOrder),
      );
    }
    return false;
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

    for (final entry in terms.entries) {
      final base = entry.key;
      final coeff = entry.value;
      if (coeff.isZero) continue;

      final split = _splitFractionBase(base);
      if (split != null) {
        final (numPart, denPart) = split;
        (groups ??= {}).putIfAbsent(denPart, () => []).add((
          base,
          numPart,
          coeff,
        ));
      }
    }

    if (groups == null) return;

    for (final entry in groups.entries) {
      final den = entry.key;
      final items = entry.value;
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

  static bool _isNegativePower(Expr expr) =>
      expr is Pow &&
      expr.exponent is RealNumeric &&
      (expr.exponent as RealNumeric).isNegative;

  static (Expr numPart, Expr denPart)? _splitFractionBase(Expr base) {
    if (_isNegativePower(base)) {
      final pow = base as Pow;
      final posExp = (pow.exponent as RealNumeric).neg();
      final den = posExp.isOne
          ? pow.base
          : Pow(pow.base, posExp, isSimplified: true);
      return (IntegerNumber.one, den);
    }
    if (base is Mul && base.factors.any(_isNegativePower)) {
      final numFactors = <Expr>[];
      final denFactors = <Expr>[];
      for (final f in base.factors) {
        if (_isNegativePower(f)) {
          final pow = f as Pow;
          final posExp = (pow.exponent as RealNumeric).neg();
          denFactors.add(
            posExp.isOne ? pow.base : Pow(pow.base, posExp, isSimplified: true),
          );
        } else {
          numFactors.add(f);
        }
      }
      final numPart = numFactors.isEmpty
          ? IntegerNumber.one
          : (numFactors.length == 1
                ? numFactors.first
                : Mul(numFactors, isSimplified: true));
      final denPart = denFactors.length == 1
          ? denFactors.first
          : Mul(denFactors, isSimplified: true);
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

/// Decomposes an expression into a scalar [Number] coefficient and symbolic base.
(Number, Expr) decomposeTerm(Expr expr) {
  if (expr is Number) {
    return (expr, IntegerNumber.one);
  }
  if (expr is Mul) {
    var coeff = IntegerNumber.one as Number;
    final nonNumeric = <Expr>[];

    void collect(Expr e) {
      if (e is Mul) {
        for (final f in e.factors) {
          collect(f);
        }
      } else if (e is Number) {
        coeff = coeff.mul(e);
      } else {
        nonNumeric.add(e);
      }
    }

    collect(expr);
    if (coeff.isZero || nonNumeric.isEmpty) {
      return (coeff, IntegerNumber.one);
    }
    if (nonNumeric.length == 1) {
      return (coeff, nonNumeric.first);
    }
    return (coeff, Mul(nonNumeric, isSimplified: expr.isSimplified));
  }
  return (IntegerNumber.one, expr);
}

/// Decomposes an expression into a base and an exponent factor.
(Expr, Expr) decomposeFactor(Expr expr) {
  if (expr is Pow) {
    return (expr.base, expr.exponent);
  }
  return (expr, IntegerNumber.one);
}

/// Splits an expression into `(numerator, denominator)` by extracting
/// [FractionNumber] denominators and negative-exponent [Pow] factors.
///
/// When [expr] has no denominator factors, returns `(expr, IntegerNumber.one)`.
(Expr, Expr) splitNumeratorDenominator(Expr expr) {
  if (expr is FractionNumber) {
    return (IntegerNumber(expr.numerator), IntegerNumber(expr.denominator));
  }
  if (expr is Pow &&
      expr.exponent is RealNumeric &&
      (expr.exponent as RealNumeric).isNegative) {
    final posExp = (expr.exponent as RealNumeric).neg();
    final den = posExp.isOne
        ? expr.base
        : Pow(expr.base, posExp, isSimplified: expr.isSimplified);
    return (IntegerNumber.one, den);
  }
  if (expr is Mul) {
    final numFactors = <Expr>[];
    final denFactors = <Expr>[];
    for (final f in expr.factors) {
      if (f is FractionNumber) {
        if (!f.numerator.isOne) {
          numFactors.add(IntegerNumber(f.numerator));
        }
        denFactors.add(IntegerNumber(f.denominator));
      } else if (f is Pow &&
          f.exponent is RealNumeric &&
          (f.exponent as RealNumeric).isNegative) {
        final posExp = (f.exponent as RealNumeric).neg();
        denFactors.add(
          posExp.isOne
              ? f.base
              : Pow(f.base, posExp, isSimplified: f.isSimplified),
        );
      } else {
        numFactors.add(f);
      }
    }
    if (denFactors.isEmpty) return (expr, IntegerNumber.one);
    final numPart = numFactors.isEmpty
        ? IntegerNumber.one
        : (numFactors.length == 1
              ? numFactors.first
              : Mul(numFactors, isSimplified: expr.isSimplified));
    final denPart = denFactors.length == 1
        ? denFactors.first
        : Mul(denFactors, isSimplified: expr.isSimplified);
    return (numPart, denPart);
  }
  return (expr, IntegerNumber.one);
}

({int power, Expr coeff})? _extractBaseMonomial(Expr expr, String variable) {
  if (!expr.dependsOn(variable)) {
    return (power: 0, coeff: expr);
  }

  switch (expr) {
    case Variable(:final name) when name == variable:
      return (power: 1, coeff: IntegerNumber.one);

    case Pow(:final base, :final exponent):
      if (base is Variable && base.name == variable) {
        if (exponent.dependsOn(variable)) return null;
        final p = _asPositiveInt(exponent);
        if (p == null) return null;
        return (power: p, coeff: IntegerNumber.one);
      }
      return null;

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
          if (!(sub.coeff is Number && (sub.coeff as Number).isOne)) {
            coeffFactors.add(sub.coeff);
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

int? _asPositiveInt(Expr exponent) {
  if (exponent is IntegerNumber) {
    final v = exponent.asInt;
    if (v != null && v > 0) return v;
  } else if (exponent is RealNumber) {
    if (exponent.value > 0 &&
        exponent.value == exponent.value.roundToDouble()) {
      return exponent.value.round();
    }
  }
  return null;
}
