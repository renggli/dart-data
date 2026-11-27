import 'dart:math' as math;

import '../assumptions.dart';
import '../ast.dart';
import 'expand.dart';
import 'helpers.dart';
import 'simplify.dart';
import 'simplify/additive.dart';
import 'simplify/domain.dart';
import 'simplify/multiplicative.dart';
import 'simplify/power.dart';
import 'simplify/transcendental.dart';

/// Accumulates additive and monomial terms, separating numeric constants
/// and symbolic monomials.
class MonomialAccumulator {
  /// Creates an empty monomial accumulator.
  ///
  /// An optional [simplify] callback performs sub-expression reduction during
  /// logarithmic and fraction combination.
  new({this.simplify, required this.assumptions});

  /// Optional simplifier callback.
  final Expr Function(Expr)? simplify;

  /// Assumptions context.
  final Assumptions assumptions;

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

  /// Whether an undefined / indeterminate result was encountered.
  bool hasUndefined = false;

  /// Direction of infinity: +1 for +inf, -1 for -inf.
  int? infinitySign;

  bool _isCombiningFractions = false;
  bool _hasNegativePowerTerm = false;

  /// Recursively flattens and accumulates [expr] multiplied by [scale].
  void add(Expr expr, [Number? scale]) {
    final s = scale ?? IntegerNumber.one;
    if (_containsRealNumber(s)) {
      hasReal = true;
    }
    if (s.isZero) return;
    if (expr == Constant.undefined) {
      hasUndefined = true;
      return;
    }

    switch (expr) {
      case Add(:final terms):
        for (final term in terms) {
          add(term, s);
        }
      case Mul(factors: [Number(isNegativeOne: true), final Add innerAdd]):
        add(innerAdd, s.neg());
      case OrderTerm(:final variable, :final order, :final point):
        final key = (variable, point);
        orderTerms[key] = math.min(orderTerms[key] ?? order, order);
      case Number():
        if (_containsRealNumber(expr)) {
          hasReal = true;
        }
        constant = constant.add(s.mul(expr));
      default:
        _addMonomialTerm(expr, s);
    }
  }

  /// Directly accumulates a pre-decomposed [coeff] and canonical symbolic [base].
  void addDecomposed(Number coeff, Expr base) {
    if (_containsRealNumber(coeff)) {
      hasReal = true;
    }
    if (coeff.isZero) return;
    if (base == Constant.undefined) {
      hasUndefined = true;
      return;
    }
    if (base == Constant.infinity) {
      if (coeff is RealNumeric) {
        final sign = coeff.isNegative ? -1 : 1;
        if ((infinitySign == null && terms.containsKey(Constant.infinity)) ||
            (infinitySign != null && infinitySign != sign)) {
          hasUndefined = true;
          terms.remove(Constant.infinity);
          return;
        }
        infinitySign = sign;
        terms[Constant.infinity] = sign == 1
            ? IntegerNumber.one
            : IntegerNumber.negativeOne;
        return;
      }
      if (infinitySign != null) {
        hasUndefined = true;
        terms.remove(Constant.infinity);
        return;
      }
      final existingInf = terms[Constant.infinity];
      if (existingInf != null) {
        final combined = existingInf.add(coeff);
        if (combined.isZero) {
          hasUndefined = true;
          terms.remove(Constant.infinity);
        } else {
          terms[Constant.infinity] = combined;
        }
        return;
      }
      terms[Constant.infinity] = coeff;
      return;
    }
    if (base is Number && base.isOne) {
      constant = constant.add(coeff);
      return;
    }
    if (!hasTranscendental && _isReducibleTranscendentalBase(base)) {
      hasTranscendental = true;
    }
    if (!_hasNegativePowerTerm && _containsNegativePower(base)) {
      _hasNegativePowerTerm = true;
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
    Mul(factors: [final Number first, ...final rest]) => () {
      final negFirst = first.neg();
      if (negFirst.isOne) {
        return switch (rest) {
          [final single] => single,
          _ => Mul.of(rest),
        };
      }
      return Mul.of([negFirst, ...rest]);
    }(),
    Mul(:final factors) when factors.isNotEmpty => Mul.of([
      IntegerNumber.negativeOne,
      ...factors,
    ]),
    _ => Mul.of([IntegerNumber.negativeOne, expr]),
  };

  /// Extracts polynomial coefficients with respect to [variable].
  ///
  /// Returns a map where each key `k >=0` is the power of [variable] and the
  /// value is the coefficient expression independent of [variable].
  ///
  /// Returns `null` if the accumulated expression contains non-polynomial terms
  /// in [variable] (e.g. division by [variable], negative or fractional powers,
  /// transcendental functions of [variable]).
  Map<int, Expr>? extractPolynomialCoefficients(String variable) {
    final coeffMap = <int, Expr>{};

    void addCoeff(int power, Expr value) {
      if (coeffMap.containsKey(power)) {
        coeffMap[power] = simplifyAdd([
          coeffMap[power]!,
          value,
        ], assumptions: assumptions);
      } else {
        coeffMap[power] = value;
      }
    }

    for (final MapEntry(key: base, value: coeff) in terms.entries) {
      if (coeff.isZero) continue;

      if (!base.dependsOn(variable)) {
        addCoeff(
          0,
          coeff.isOne
              ? base
              : simplifyMul([coeff, base], assumptions: assumptions),
        );
      } else {
        final monomial = _extractBaseMonomial(base, variable);
        if (monomial == null) return null;
        final totalCoeff = coeff.isOne
            ? monomial.coeff
            : simplifyMul([coeff, monomial.coeff], assumptions: assumptions);
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

  /// Combines fractions with identical denominators.
  void combineFractions() {
    if (_isCombiningFractions || !_hasNegativePowerTerm || terms.length < 2) {
      return;
    }
    _isCombiningFractions = true;
    try {
      _doCombineFractions();
    } finally {
      _isCombiningFractions = false;
    }
  }

  /// Reconstructs the canonical [Expr] AST tree from accumulated terms and constants.
  Expr build() {
    if (hasUndefined) return Constant.undefined;
    _absorbOrderTerms();
    if (simplify != null) {
      combineFractions();
    }
    terms.removeWhere((_, coeff) => coeff.isZero);

    final sortedKeys = terms.keys.toList()..sort(compareStructural);
    final resultTerms = <Expr>[];

    final isUnassumed =
        identical(assumptions, Assumptions.none) || assumptions.isEmpty;

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
        resultTerms.add(
          Mul.canonical([coeff, ...factors], simplified: isUnassumed),
        );
      } else {
        resultTerms.add(Mul.canonical([coeff, base], simplified: isUnassumed));
      }
    }

    // 3. Trailing OrderTerm instances (OrderTerm has highest tag)
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
      _ => Add.canonical(resultTerms, simplified: isUnassumed),
    };
  }

  void _addMonomialTerm(Expr expr, Number scale) {
    final (c, base) = decomposeTerm(expr);
    addDecomposed(scale.mul(c), base);
  }

  void _reducePythagorean() {
    final sinSquares = <({Expr arg, Expr cofactor}), (Expr, RationalNumber)>{};
    final cosSquares = <({Expr arg, Expr cofactor}), (Expr, RationalNumber)>{};

    for (final MapEntry(:key, value: coeff) in terms.entries) {
      if (coeff is! RationalNumber) continue;
      final match = _extractTrigSquare(key, isHyperbolic: false);
      if (match == null) continue;
      final pairKey = (arg: match.arg, cofactor: match.cofactor);
      if (match.isFirst) {
        sinSquares[pairKey] = (key, coeff);
      } else {
        cosSquares[pairKey] = (key, coeff);
      }
    }

    for (final pairKey in sinSquares.keys) {
      if (cosSquares.containsKey(pairKey)) {
        final (sinKey, sinCoeff) = sinSquares[pairKey]!;
        final (cosKey, cosCoeff) = cosSquares[pairKey]!;
        if (sinCoeff.sign == cosCoeff.sign) {
          final m = sinCoeff.abs().compareTo(cosCoeff.abs()) < 0
              ? sinCoeff
              : cosCoeff;
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
          if (_hasRealSquareExponent(sinKey) ||
              _hasRealSquareExponent(cosKey)) {
            hasReal = true;
          }
          addDecomposed(m, pairKey.cofactor);
        }
      }
    }

    if (constant case final RationalNumber c when !c.isZero) {
      final negC = c.neg();
      for (final MapEntry(:key, :value) in terms.entries.toList()) {
        final uSin = _isSquareOfSin(key);
        if (uSin != null && value == negC) {
          terms.remove(key);
          constant = IntegerNumber.zero;
          final exp = key is Pow ? key.exponent : IntegerNumber.two;
          final cos2 = simplifyPow(
            simplifyCos(uSin, assumptions: assumptions),
            exp,
            assumptions: assumptions,
          );
          final existing = terms[cos2];
          terms[cos2] = existing == null ? c : existing.add(c);
          break;
        }
        final uCos = _isSquareOfCos(key);
        if (uCos != null && value == negC) {
          terms.remove(key);
          constant = IntegerNumber.zero;
          final exp = key is Pow ? key.exponent : IntegerNumber.two;
          final sin2 = simplifyPow(
            simplifySin(uCos, assumptions: assumptions),
            exp,
            assumptions: assumptions,
          );
          final existing = terms[sin2];
          terms[sin2] = existing == null ? c : existing.add(c);
          break;
        }
      }
    }
  }

  void _reduceHyperbolicPythagorean() {
    final coshSquares = <({Expr arg, Expr cofactor}), (Expr, RationalNumber)>{};
    final sinhSquares = <({Expr arg, Expr cofactor}), (Expr, RationalNumber)>{};

    for (final MapEntry(:key, value: coeff) in terms.entries) {
      if (coeff is! RationalNumber) continue;
      final match = _extractTrigSquare(key, isHyperbolic: true);
      if (match == null) continue;
      final pairKey = (arg: match.arg, cofactor: match.cofactor);
      if (match.isFirst) {
        coshSquares[pairKey] = (key, coeff);
      } else {
        sinhSquares[pairKey] = (key, coeff);
      }
    }

    for (final pairKey in coshSquares.keys) {
      if (sinhSquares.containsKey(pairKey)) {
        final (coshKey, coshCoeff) = coshSquares[pairKey]!;
        final (sinhKey, sinhCoeff) = sinhSquares[pairKey]!;
        if (coshCoeff == sinhCoeff.neg()) {
          terms.remove(coshKey);
          terms.remove(sinhKey);
          if (_hasRealSquareExponent(coshKey) ||
              _hasRealSquareExponent(sinhKey)) {
            hasReal = true;
          }
          addDecomposed(coshCoeff, pairKey.cofactor);
        }
      }
    }

    if (constant case final RationalNumber c when !c.isZero) {
      final negC = c.neg();
      for (final MapEntry(:key, :value) in terms.entries.toList()) {
        final uSinh = _isSquareOfSinh(key);
        if (uSinh != null && value == c) {
          terms.remove(key);
          constant = IntegerNumber.zero;
          final exp = key is Pow ? key.exponent : IntegerNumber.two;
          final cosh2 = simplifyPow(
            simplifyCosh(uSinh, assumptions: assumptions),
            exp,
            assumptions: assumptions,
          );
          final existing = terms[cosh2];
          terms[cosh2] = existing == null ? c : existing.add(c);
          break;
        }
        final uCosh = _isSquareOfCosh(key);
        if (uCosh != null && value == negC) {
          terms.remove(key);
          constant = IntegerNumber.zero;
          final exp = key is Pow ? key.exponent : IntegerNumber.two;
          final sinh2 = simplifyPow(
            simplifySinh(uCosh, assumptions: assumptions),
            exp,
            assumptions: assumptions,
          );
          final existing = terms[sinh2];
          terms[sinh2] = existing == null ? negC : existing.add(negC);
          break;
        }
      }
    }
  }

  void _reduceLogarithms() {
    final lnEntries = [
      for (final e in terms.entries)
        if (e.key case Call(id: FunctionId.ln, args: [final inner])
            when e.value is IntegerNumber &&
                !e.value.isZero &&
                isPositiveExpr(inner, assumptions: assumptions))
          (key: e.key, inner: inner, coeff: e.value as IntegerNumber),
    ];

    if (simplify != null && lnEntries.length >= 2) {
      var g = lnEntries.first.coeff.value.abs();
      for (var i = 1; i < lnEntries.length; i++) {
        g = g.gcd(lnEntries[i].coeff.value.abs());
      }
      final scaled = [
        for (final entry in lnEntries)
          (
            key: entry.key,
            inner: entry.inner,
            exp: (entry.coeff.value ~/ g).isValidInt
                ? (entry.coeff.value ~/ g).toInt()
                : null,
          ),
      ];
      if (scaled.any((e) => e.exp == null || e.exp!.abs() > 8)) return;

      Expr? num;
      Expr? den;

      for (final (:key, :inner, :exp) in scaled) {
        final s = exp!;
        if (s > 0) {
          final factor = s == 1
              ? inner
              : simplifyPow(
                  inner,
                  IntegerNumber.of(s),
                  assumptions: assumptions,
                );
          num = num == null
              ? factor
              : simplifyMul([num, factor], assumptions: assumptions);
        } else {
          final posExp = -s;
          final factor = posExp == 1
              ? inner
              : simplifyPow(
                  inner,
                  IntegerNumber.of(posExp),
                  assumptions: assumptions,
                );
          den = den == null
              ? factor
              : simplifyMul([den, factor], assumptions: assumptions);
        }
        terms.remove(key);
      }

      final gNum = IntegerNumber(g);
      if (num != null && den != null) {
        final ratio = simplifyDiv(num, den, assumptions: assumptions);
        final combined = simplifyLn(ratio, assumptions: assumptions);
        add(combined, gNum);
      } else if (num != null) {
        final combined = simplifyLn(num, assumptions: assumptions);
        add(combined, gNum);
      } else if (den != null) {
        final combined = simplifyLn(den, assumptions: assumptions);
        add(combined, gNum.neg());
      }
    }
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
    if (minOrder <= 0 && !base.dependsOn(variable)) {
      return true;
    }
    final shifted = simplifySub(
      Variable(variable),
      point,
      assumptions: Assumptions.none,
    );
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

    if (groups.length >= 2) {
      final byBase = <Expr, List<({Expr denPart, int exp})>>{};
      for (final denPart in groups.keys) {
        if (denPart
            case Pow(
              base: final innerBase,
              exponent: IntegerNumber(asInt: final m?),
            )
            when m >= 1) {
          byBase.putIfAbsent(innerBase, () => []).add((
            denPart: denPart,
            exp: m,
          ));
        } else {
          byBase.putIfAbsent(denPart, () => []).add((denPart: denPart, exp: 1));
        }
      }
      for (final MapEntry(key: baseExpr, value: entries) in byBase.entries) {
        if (entries.length < 2) continue;
        entries.sort((a, b) => b.exp.compareTo(a.exp));
        var i = 0;
        while (i < entries.length) {
          final maxEntry = entries[i];
          final mMax = maxEntry.exp;
          if (mMax <= 16) break;
          var j = i + 1;
          while (j < entries.length && mMax - entries[j].exp <= 4) {
            j++;
          }
          if (j - i >= 2) {
            final targetItems = groups[maxEntry.denPart]!;
            for (var k = i + 1; k < j; k++) {
              final subEntry = entries[k];
              final shift = mMax - subEntry.exp;
              final shiftFactor = shift == 1
                  ? baseExpr
                  : Pow.of(baseExpr, IntegerNumber.of(shift));
              final subItems = groups.remove(subEntry.denPart)!;
              for (final (termBase, numPart, coeff) in subItems) {
                final alignedNum = numPart is Number && numPart.isOne
                    ? shiftFactor
                    : simplifyMul([
                        numPart,
                        shiftFactor,
                      ], assumptions: assumptions);
                targetItems.add((termBase, alignedNum, coeff));
              }
            }
          }
          i = j;
        }
      }
    }

    for (final MapEntry(key: den, value: items) in groups.entries) {
      if (items.length < 2 ||
          items.length > 16 ||
          exceedsNodeBudget(den, 400)) {
        continue;
      }
      var hasLargeNumerator = false;
      for (final (_, numPart, _) in items) {
        if (exceedsNodeBudget(numPart, 300)) {
          hasLargeNumerator = true;
          break;
        }
      }
      if (hasLargeNumerator) continue;

      for (final (base, _, _) in items) {
        terms.remove(base);
      }

      final numerators = <Expr>[];
      for (final (_, numPart, coeff) in items) {
        if (coeff.isOne) {
          numerators.add(numPart);
        } else if (coeff.isNegativeOne) {
          numerators.add(simplifyNeg(numPart, assumptions: assumptions));
        } else {
          numerators.add(
            simplifyMul([coeff, numPart], assumptions: assumptions),
          );
        }
      }

      final totalNum = Add.of(numerators);
      final simplifiedNum = _expandAndSimplifyGuarded(
        totalNum,
        assumptions: assumptions,
      );

      if (simplifiedNum is Number && simplifiedNum.isZero) {
        // Combined numerator is 0: sum is 0, nothing added.
      } else if (simplifiedNum == den ||
          isAlgebraicallyZero(
            simplifySub(simplifiedNum, den, assumptions: assumptions),
          )) {
        add(IntegerNumber.one);
      } else if (isAlgebraicallyZero(
        simplifyAdd([simplifiedNum, den], assumptions: assumptions),
      )) {
        add(IntegerNumber.negativeOne);
      } else {
        final combined = simplifyDiv(
          simplifiedNum,
          den,
          assumptions: assumptions,
        );
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
      final den = posExp.isOne ? innerBase : Pow.of(innerBase, posExp);
      return (IntegerNumber.one, den);
    }
    if (base case Mul(:final factors) when factors.any(_isNegativePower)) {
      final numFactors = <Expr>[];
      final denFactors = <Expr>[];
      for (final f in factors) {
        if (f case Pow(base: final innerBase, exponent: final RealNumeric exp)
            when exp.isNegative) {
          final posExp = exp.neg();
          denFactors.add(posExp.isOne ? innerBase : Pow.of(innerBase, posExp));
        } else {
          numFactors.add(f);
        }
      }
      final numPart = switch (numFactors) {
        [] => IntegerNumber.one,
        [final single] => single,
        _ => Mul.of(numFactors),
      };
      final denPart = switch (denFactors) {
        [final single] => single,
        _ => Mul.of(denFactors),
      };
      return (numPart, denPart);
    }
    return null;
  }

  static Expr _expandAndSimplifyGuarded(
    Expr expr, {
    required Assumptions assumptions,
    int maxExponent = 16,
  }) {
    if (exceedsNodeBudget(expr, 400)) {
      return expr.simplify(assumptions: assumptions);
    }
    final placeholders = <Variable, Expr>{};
    final reverseMap = <Expr, Variable>{};
    final existingVars = expr.freeVariables;
    var counter = 0;

    Expr replaceHighPowers(Expr e) {
      if (e case Pow(base: Add(), exponent: IntegerNumber(:final value))
          when value.abs() > BigInt.from(maxExponent)) {
        return reverseMap.putIfAbsent(e, () {
          var candidate = '_hp_${counter++}';
          while (existingVars.contains(candidate)) {
            candidate = '_hp_${counter++}';
          }
          final v = Variable(candidate);
          placeholders[v] = e;
          return v;
        });
      }
      return e.mapChildren(replaceHighPowers);
    }

    final guarded = replaceHighPowers(expr);
    if (placeholders.isEmpty) {
      return expr
          .expand(assumptions: assumptions)
          .simplify(assumptions: assumptions);
    }
    var result = guarded
        .expand(assumptions: assumptions)
        .simplify(assumptions: assumptions);
    for (final MapEntry(:key, :value) in placeholders.entries) {
      result = result.substitute(key.name, value);
    }
    return result.simplify(assumptions: assumptions);
  }

  /// Returns whether [expr] simplifies to zero after guarded expansion.
  static bool isAlgebraicallyZero(
    Expr expr, {
    Assumptions assumptions = Assumptions.none,
  }) {
    if (expr is Number && expr.isZero) return true;
    final s = _expandAndSimplifyGuarded(expr, assumptions: assumptions);
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
      _ => (coeff, Mul.of(nonNumeric)),
    };
  }
  return (IntegerNumber.one, expr);
}

/// Decomposes an expression into a base and an exponent factor.
(Expr, Expr) decomposeFactor(Expr expr) => switch (expr) {
  Pow(:final base, :final exponent) => (base, exponent),
  _ => (expr, IntegerNumber.one),
};

bool _containsRealNumber(Number n) => switch (n) {
  RealNumber() => true,
  ComplexNumber(:final real, :final imaginary) =>
    real is RealNumber || imaginary is RealNumber,
  _ => false,
};

Expr? _isSquareOfSin(Expr term) => switch (term) {
  Pow(base: Call(id: FunctionId.sin, args: [final expr]), exponent: final exp)
      when _isTwo(exp) =>
    expr,
  _ => null,
};

Expr? _isSquareOfCos(Expr term) => switch (term) {
  Pow(base: Call(id: FunctionId.cos, args: [final expr]), exponent: final exp)
      when _isTwo(exp) =>
    expr,
  _ => null,
};

Expr? _isSquareOfSinh(Expr term) => switch (term) {
  Pow(base: Call(id: FunctionId.sinh, args: [final expr]), exponent: final exp)
      when _isTwo(exp) =>
    expr,
  _ => null,
};

Expr? _isSquareOfCosh(Expr term) => switch (term) {
  Pow(base: Call(id: FunctionId.cosh, args: [final expr]), exponent: final exp)
      when _isTwo(exp) =>
    expr,
  _ => null,
};

bool _isTwo(Expr exp) =>
    exp == IntegerNumber.two || (exp is RealNumber && exp.value == 2.0);

bool _hasRealSquareExponent(Expr expr) => switch (expr) {
  Pow(:final exponent) => exponent is RealNumber,
  Mul(:final factors) => factors.any(_hasRealSquareExponent),
  _ => false,
};

({Expr arg, bool isFirst, Expr cofactor})? _extractTrigSquare(
  Expr term, {
  required bool isHyperbolic,
}) {
  (Expr arg, bool isFirst)? matchPow(Expr e) {
    if (e case Pow(base: Call(:final id, :final args), :final exponent)
        when _isTwo(exponent) && args.length == 1) {
      if (isHyperbolic) {
        if (id == FunctionId.cosh) return (args[0], true);
        if (id == FunctionId.sinh) return (args[0], false);
      } else {
        if (id == FunctionId.sin) return (args[0], true);
        if (id == FunctionId.cos) return (args[0], false);
      }
    }
    return null;
  }

  if (matchPow(term) case (final arg, final isFirst)) {
    return (arg: arg, isFirst: isFirst, cofactor: IntegerNumber.one);
  }
  if (term case Mul(:final factors)) {
    for (var i = 0; i < factors.length; i++) {
      if (matchPow(factors[i]) case (final arg, final isFirst)) {
        final rest = [
          for (var j = 0; j < factors.length; j++)
            if (j != i) factors[j],
        ];
        final cofactor = rest.length == 1 ? rest.first : Mul.of(rest);
        return (arg: arg, isFirst: isFirst, cofactor: cofactor);
      }
    }
  }
  return null;
}

bool _containsNegativePower(Expr expr) => switch (expr) {
  Pow(exponent: RealNumeric(isNegative: true)) => true,
  Mul(:final factors) => factors.any(_containsNegativePower),
  _ => false,
};

bool _isReducibleTranscendentalBase(Expr base) => switch (base) {
  Call(id: FunctionId.ln) => true,
  Pow(
    base: Call(
      id: FunctionId.sin ||
          FunctionId.cos ||
          FunctionId.sinh ||
          FunctionId.cosh,
    ),
  ) =>
    true,
  Mul(:final factors) => factors.any(_isReducibleTranscendentalBase),
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
      return (
        power: p,
        coeff: exponent is RealNumber
            ? const RealNumber(1.0)
            : IntegerNumber.one,
      );

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
          if (sub.coeff case final c when !(c is RationalNumber && c.isOne)) {
            coeffFactors.add(c);
          }
        }
      }
      final totalCoeff = coeffFactors.isEmpty
          ? IntegerNumber.one
          : simplifyMul(coeffFactors, assumptions: Assumptions.none);
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
