import 'dart:math' as math;

import '../../assumptions.dart';
import '../../ast.dart';
import '../../number/integer.dart';
import '../structural_order.dart';
import '../term_accumulator.dart';
import 'additive.dart';
import 'domain.dart';
import 'power.dart';

/// Simplifies an N-ary multiplication expression across [factors].
Expr simplifyMul(
  List<Expr> factors, {
  required Assumptions assumptions,
  int distributeBudget = 4,
  int recombineBudget = 2,
}) {
  if (factors.isEmpty) return IntegerNumber.one;

  final flatFactors = <Expr>[];
  void flatten(Expr e) {
    if (e is Mul) {
      for (final f in e.factors) {
        flatten(f);
      }
    } else {
      flatFactors.add(e);
    }
  }

  for (final f in factors) {
    flatten(f);
  }

  if (flatFactors.isEmpty) return IntegerNumber.one;
  if (flatFactors.length == 1) return flatFactors.first;

  // Undefined annihilator: anything * undefined = undefined
  if (flatFactors.any((f) => f == Constant.undefined)) {
    return Constant.undefined;
  }

  // Check for 0 * infinity:
  final hasZero = flatFactors.any((f) => f is Number && f.isZero);
  final hasInfinity = flatFactors.any(
    (f) =>
        f == Constant.infinity ||
        (f is Mul && f.factors.contains(Constant.infinity)),
  );
  if (hasZero && hasInfinity) {
    return Constant.undefined;
  }

  // Fast annihilator check: 0 * anything = 0
  if (hasZero) {
    if (flatFactors.any(
      (f) =>
          f is RealNumber ||
          (f is ComplexNumber &&
              (f.real is RealNumber || f.imaginary is RealNumber)),
    )) {
      return const RealNumber(0.0);
    }
    return IntegerNumber.zero;
  }

  // Handle OrderTerm products and scalings if any factor is an OrderTerm
  final orderIdx = flatFactors.indexWhere((f) => f is OrderTerm);
  if (orderIdx != -1) {
    var currentOrder = flatFactors[orderIdx] as OrderTerm;
    final unabsorbed = <Expr>[];
    for (var i = 0; i < flatFactors.length; i++) {
      if (i == orderIdx) continue;
      final other = flatFactors[i];
      if (other is OrderTerm &&
          other.variable == currentOrder.variable &&
          other.point == currentOrder.point) {
        currentOrder = OrderTerm(
          currentOrder.variable,
          currentOrder.order + other.order,
          point: currentOrder.point,
        );
      } else {
        final merged = _multiplyWithOrderTerm(
          currentOrder,
          other,
          assumptions: assumptions,
        );
        if (merged is OrderTerm) {
          currentOrder = merged;
        } else if (merged != null) {
          // e.g. distributed over Add
          final remaining = [
            ...unabsorbed,
            merged,
            ...flatFactors.sublist(i + 1),
          ];
          return remaining.length == 1
              ? remaining.first
              : simplifyMul(remaining, assumptions: assumptions);
        } else {
          unabsorbed.add(other);
        }
      }
    }
    if (unabsorbed.isEmpty) {
      return currentOrder;
    }
    unabsorbed.add(currentOrder);
    return simplifySymbolicProduct(IntegerNumber.one, unabsorbed);
  }

  Number coeff = IntegerNumber.one;
  final baseExponents = <Expr, Expr>{};

  for (final f in flatFactors) {
    if (f is Number) {
      coeff = coeff.mul(f);
      if (coeff.isZero) {
        return coeff is RealNumber ? const RealNumber(0.0) : IntegerNumber.zero;
      }
    } else {
      final (base, exp) = decomposeFactor(f);
      final existingExp = baseExponents[base];
      if (existingExp != null) {
        final sumExp = simplifyAdd([
          existingExp,
          exp,
        ], assumptions: assumptions);
        if (sumExp is Number && sumExp.isZero) {
          if (base == Constant.infinity) return Constant.undefined;
          if (sumExp is RealNumber || base is RealNumber) {
            coeff = coeff.mul(const RealNumber(1.0));
          }
          baseExponents.remove(base);
        } else {
          baseExponents[base] = sumExp;
        }
      } else {
        baseExponents[base] = exp;
      }
    }
  }

  // Cancel Factorial, Gamma, and Binomial ratios with integer argument shifts
  coeff = _reduceFactorialAndGammaFactors(
    coeff,
    baseExponents,
    assumptions: assumptions,
  );
  if (coeff.isZero) {
    return coeff is RealNumber ? const RealNumber(0.0) : IntegerNumber.zero;
  }

  // Combine radical factors with matching fractional exponents (e.g. sqrt(x) * sqrt(y) -> sqrt(x * y))
  _combineRadicalBases(baseExponents, assumptions: assumptions);

  // Fold rational coefficient factors into matching integer radical bases (e.g. 2 * 2^(-1/2) -> 2^(1/2))
  if (coeff is RationalNumber && !coeff.isOne && !coeff.isNegativeOne) {
    coeff = _absorbRationalCoeffIntoRadicals(coeff, baseExponents);
  }

  final remainingFactors = <Expr>[];
  var needsRecombine = false;
  for (final MapEntry(key: base, value: exp) in baseExponents.entries) {
    final term =
        (exp == IntegerNumber.one &&
            base.isSimplified &&
            (identical(assumptions, Assumptions.none) || assumptions.isEmpty))
        ? base
        : simplifyPow(base, exp, assumptions: assumptions);
    switch (term) {
      case final Number n:
        coeff = coeff.mul(n);
        if (coeff.isZero) {
          return coeff is RealNumber
              ? const RealNumber(0.0)
              : IntegerNumber.zero;
        }
      case Mul(:final factors):
        needsRecombine = true;
        for (final sub in factors) {
          if (sub is Number) {
            coeff = coeff.mul(sub);
            if (coeff.isZero) {
              return coeff is RealNumber
                  ? const RealNumber(0.0)
                  : IntegerNumber.zero;
            }
          } else {
            remainingFactors.add(sub);
          }
        }
      default:
        if (term is Pow && term.base != base) {
          needsRecombine = true;
        }
        remainingFactors.add(term);
    }
  }

  if (needsRecombine && recombineBudget > 0 && remainingFactors.length > 1) {
    return simplifyMul(
      [if (!coeff.isOne) coeff, ...remainingFactors],
      assumptions: assumptions,
      distributeBudget: distributeBudget,
      recombineBudget: recombineBudget - 1,
    );
  }

  // Check if an Add factor is cleanly divisible by negative-power factors (e.g. (x^2 + x) / x -> 1 + x)
  if (distributeBudget > 0) {
    final distributed = _tryDistributeExactDivision(
      coeff,
      remainingFactors,
      assumptions: assumptions,
      distributeBudget: distributeBudget,
    );
    if (distributed != null) {
      return distributed;
    }
  }

  return simplifySymbolicProduct(coeff, remainingFactors);
}

/// Simplifies a binary division `left / right`.
Expr simplifyDiv(Expr left, Expr right, {required Assumptions assumptions}) {
  if (left == Constant.undefined || right == Constant.undefined) {
    return Constant.undefined;
  }
  if (right is Number && right.isZero) {
    return Constant.undefined;
  }
  if (left is Number && right is Number) {
    return left.div(right);
  }
  return simplifyMul([
    left,
    simplifyPow(right, IntegerNumber.negativeOne, assumptions: assumptions),
  ], assumptions: assumptions);
}

/// Canonically sorts [remainingFactors] and combines with [coeff] into a
/// simplified product expression.
Expr simplifySymbolicProduct(Number coeff, List<Expr> remainingFactors) {
  if (coeff.isZero) {
    return coeff;
  }
  if (remainingFactors.isEmpty) {
    return coeff;
  }

  remainingFactors.sort((a, b) {
    final (baseA, _) = decomposeFactor(a);
    final (baseB, _) = decomposeFactor(b);
    final cmpBase = compareStructural(baseA, baseB);
    if (cmpBase != 0) return cmpBase;
    return compareStructural(a, b);
  });

  if (coeff.isOne) {
    return remainingFactors.length == 1
        ? remainingFactors.first
        : Mul(remainingFactors, isSimplified: true);
  }
  return Mul([coeff, ...remainingFactors], isSimplified: true);
}

void _combineRadicalBases(
  Map<Expr, Expr> baseExponents, {
  required Assumptions assumptions,
}) {
  if (baseExponents.length < 2) return;
  var fractionCount = 0;
  for (final exp in baseExponents.values) {
    if (exp is FractionNumber) {
      fractionCount++;
      if (fractionCount >= 2) break;
    }
  }
  if (fractionCount < 2) return;

  final entries = baseExponents.entries.toList();
  final used = <Expr>{};

  for (var i = 0; i < entries.length; i++) {
    final baseA = entries[i].key;
    if (used.contains(baseA)) continue;
    final expA = baseExponents[baseA];
    if (expA is! FractionNumber) continue;
    if (baseA == Constant.e) continue;

    final absNumA = expA.numerator.abs();
    final denA = expA.denominator;
    final posExp = FractionNumber(absNumA, denA);

    final matchingNumBases = <Expr>[];
    final matchingDenBases = <Expr>[];
    var nonPositiveNumBases = 0;
    if (expA.isNegative) {
      if (!isPositiveExpr(baseA, assumptions: assumptions)) continue;
      matchingDenBases.add(baseA);
    } else {
      if (!isPositiveExpr(baseA, assumptions: assumptions)) {
        nonPositiveNumBases++;
      }
      matchingNumBases.add(baseA);
    }

    final matchedB = <Expr>[];
    for (var j = i + 1; j < entries.length; j++) {
      final baseB = entries[j].key;
      if (used.contains(baseB) || baseB == Constant.e) continue;
      final expB = baseExponents[baseB];
      if (expB is FractionNumber &&
          expB.denominator == denA &&
          expB.numerator.abs() == absNumA) {
        if (expB.isNegative) {
          if (!isPositiveExpr(baseB, assumptions: assumptions)) continue;
          matchingDenBases.add(baseB);
        } else {
          final isPos = isPositiveExpr(baseB, assumptions: assumptions);
          if (!isPos) {
            if (nonPositiveNumBases >= 1) continue;
            nonPositiveNumBases++;
          }
          matchingNumBases.add(baseB);
        }
        matchedB.add(baseB);
      }
    }

    if (matchingNumBases.length + matchingDenBases.length >= 2 &&
        matchingNumBases.isNotEmpty) {
      used.add(baseA);
      used.addAll(matchedB);
      for (final b in matchingNumBases) {
        baseExponents.remove(b);
      }
      for (final b in matchingDenBases) {
        baseExponents.remove(b);
      }
      final combinedFactors = <Expr>[
        ...matchingNumBases,
        for (final b in matchingDenBases)
          simplifyPow(b, IntegerNumber.negativeOne, assumptions: assumptions),
      ];
      final combinedBase = simplifyMul(
        combinedFactors,
        assumptions: assumptions,
      );
      final existing = baseExponents[combinedBase];
      if (existing != null) {
        final sum = simplifyAdd([existing, posExp], assumptions: assumptions);
        if (sum is Number && sum.isZero) {
          baseExponents.remove(combinedBase);
        } else {
          baseExponents[combinedBase] = sum;
        }
      } else {
        baseExponents[combinedBase] = posExp;
      }
    }
  }
}

RationalNumber _absorbRationalCoeffIntoRadicals(
  RationalNumber coeff,
  Map<Expr, Expr> baseExponents,
) {
  var currentCoeff = coeff;
  for (final MapEntry(key: base, value: exp)
      in baseExponents.entries.toList()) {
    if ((base, exp)
        case (final IntegerNumber intBase, final FractionNumber fracExp)
        when intBase.value > Integer.one && fracExp.isNegative) {
      final b = intBase.value;
      RationalNumber newExp = fracExp;
      while (newExp is FractionNumber &&
          newExp.isNegative &&
          (currentCoeff.numerator % b).isZero) {
        currentCoeff = currentCoeff.divRational(intBase);
        newExp = newExp.addRational(IntegerNumber.one);
      }
      baseExponents[base] = newExp;
    }
  }
  return currentCoeff;
}

Expr? _tryDistributeExactDivision(
  Number coeff,
  List<Expr> factors, {
  required Assumptions assumptions,
  required int distributeBudget,
}) {
  if (factors.length < 2) return null;
  final addIndices = <int>[];
  final negPowIndices = <int>[];

  for (var i = 0; i < factors.length; i++) {
    switch (factors[i]) {
      case Add():
        addIndices.add(i);
      case Pow(exponent: RealNumeric(isNegative: true)):
        negPowIndices.add(i);
      default:
        break;
    }
  }

  if (addIndices.isEmpty || negPowIndices.isEmpty) return null;

  Expr? tryDivideAdd(Add a, Expr divisor) {
    final dividedTerms = <Expr>[];
    for (final term in a.terms) {
      final divTerm = simplifyMul(
        [term, divisor],
        assumptions: assumptions,
        distributeBudget: 0,
      );
      if (_hasNegativePowerFactor(divTerm)) return null;
      dividedTerms.add(divTerm);
    }
    return simplifyAdd(dividedTerms, assumptions: assumptions);
  }

  for (final negIdx in negPowIndices) {
    final negFactor = factors[negIdx] as Pow;
    final candidates = <Expr>[
      negFactor,
      if (negFactor.exponent case IntegerNumber(asInt: final k?) when k < -1)
        Pow(negFactor.base, IntegerNumber.negativeOne, isSimplified: true),
    ];

    for (final divisor in candidates) {
      for (final addIdx in addIndices) {
        final addNode = factors[addIdx] as Add;
        final divided = tryDivideAdd(addNode, divisor);
        if (divided == null) continue;

        final updatedFactors = <Expr>[];
        for (var i = 0; i < factors.length; i++) {
          if (i == addIdx) {
            updatedFactors.add(divided);
          } else if (i == negIdx) {
            if (!identical(divisor, negFactor)) {
              final remExp = (negFactor.exponent as IntegerNumber).add(
                IntegerNumber.one,
              );
              updatedFactors.add(
                simplifyPow(negFactor.base, remExp, assumptions: assumptions),
              );
            }
          } else {
            updatedFactors.add(factors[i]);
          }
        }
        return simplifyMul(
          [if (!coeff.isOne) coeff, ...updatedFactors],
          assumptions: assumptions,
          distributeBudget: distributeBudget - 1,
        );
      }
    }
  }

  return null;
}

bool _hasNegativePowerFactor(Expr expr) => switch (expr) {
  Pow(exponent: RealNumeric(isNegative: true)) => true,
  Mul(:final factors) => factors.any(_hasNegativePowerFactor),
  _ => false,
};

Expr? _multiplyWithOrderTerm(
  OrderTerm orderTerm,
  Expr other, {
  required Assumptions assumptions,
}) {
  final v = orderTerm.variable;
  final p = orderTerm.point;
  final n = orderTerm.order;
  final isZeroPoint = p is Number && p.isZero;

  switch (other) {
    case Number(:final isZero):
      return isZero ? IntegerNumber.zero : orderTerm;
    case Constant():
      if (other == Constant.infinity || other == Constant.undefined) {
        return Constant.undefined;
      }
      return orderTerm;
    case Variable(:final name) when isZeroPoint && name == v:
      return OrderTerm(v, n + 1, point: p);
    case Pow(
          base: Variable(:final name),
          exponent: IntegerNumber(asInt: final k?),
        )
        when isZeroPoint && name == v && k > 0:
      return OrderTerm(v, n + k, point: p);
    default:
      break;
  }

  if (!isZeroPoint) {
    final shifted = simplifySub(Variable(v), p, assumptions: assumptions);
    final rawShifted = Variable(v) - p;
    if (other == shifted || other == rawShifted) {
      return OrderTerm(v, n + 1, point: p);
    }
    if (other case Pow(:final base, exponent: IntegerNumber(asInt: final k?))
        when (base == shifted || base == rawShifted) && k > 0) {
      return OrderTerm(v, n + k, point: p);
    }
  }

  if (other case Add(:final terms)) {
    return simplifyAdd([
      for (final term in terms)
        simplifyMul([term, orderTerm], assumptions: assumptions),
    ], assumptions: assumptions);
  }

  return null;
}

Number _reduceFactorialAndGammaFactors(
  Number coeff,
  Map<Expr, Expr> baseExponents, {
  required Assumptions assumptions,
}) {
  final expMap = <Expr, int>{};
  final posBinomials = <Expr>[];
  final negBinomials = <Expr>[];
  final posGammas = <Expr>[];
  final negGammas = <Expr>[];

  for (final MapEntry(key: base, value: exp) in baseExponents.entries) {
    if (exp case IntegerNumber(asInt: final e?) when e != 0) {
      if (base is Binomial) {
        expMap[base] = e;
        if (e > 0) {
          posBinomials.add(base);
        } else {
          negBinomials.add(base);
        }
      } else if (base is Factorial || base is Gamma) {
        expMap[base] = e;
        if (e > 0) {
          posGammas.add(base);
        } else {
          negGammas.add(base);
        }
      }
    }
  }

  var currentCoeff = coeff;

  void addFactorPower(Expr factor, int power) {
    if (power == 0) return;
    if (factor is Number) {
      final powered = factor.powNumber(IntegerNumber.of(power));
      if (powered != null) {
        currentCoeff = currentCoeff.mul(powered);
        return;
      }
    }
    if (factor is Mul) {
      for (final sub in factor.factors) {
        addFactorPower(sub, power);
      }
      return;
    }
    final (base, baseExp) = decomposeFactor(factor);
    final scaledExp = simplifyMul([
      baseExp,
      IntegerNumber.of(power),
    ], assumptions: assumptions);
    final existing = baseExponents[base];
    if (existing != null) {
      final sumExp = simplifyAdd([
        existing,
        scaledExp,
      ], assumptions: assumptions);
      if (sumExp is Number && sumExp.isZero) {
        baseExponents.remove(base);
      } else {
        baseExponents[base] = sumExp;
      }
    } else {
      baseExponents[base] = scaledExp;
    }
  }

  List<(Expr, int)>? collectGammaRatio(Expr a, Expr b, int d, int power) {
    if (d == 0) return const [];
    if (a case IntegerNumber(:final value) when value <= Integer.zero) {
      return null;
    }
    if (b case IntegerNumber(:final value) when value <= Integer.zero) {
      return null;
    }
    final start = d > 0 ? b : a;
    final count = d.abs();
    final signPower = d > 0 ? power : -power;
    final terms = <(Expr, int)>[];
    for (var j = 0; j < count; j++) {
      final term = j == 0
          ? start
          : simplifyAdd([start, IntegerNumber.of(j)], assumptions: assumptions);
      if (term is Number && term.isZero) {
        return null;
      }
      terms.add((term, signPower));
    }
    return terms;
  }

  void applyCollected(List<(Expr, int)> terms) {
    for (final (term, signPower) in terms) {
      addFactorPower(term, signPower);
    }
  }

  final initialExp = Map<Expr, int>.of(expMap);

  // Pairwise Binomial cancellation
  if (posBinomials.isNotEmpty && negBinomials.isNotEmpty) {
    for (final p in posBinomials) {
      var pExp = expMap[p]!;
      if (pExp <= 0) continue;
      final b1 = p as Binomial;
      for (final q in negBinomials) {
        final qExp = expMap[q]!;
        if (qExp >= 0) continue;
        final b2 = q as Binomial;
        final dn = simplifySub(b1.left, b2.left, assumptions: assumptions);
        final dk = simplifySub(b1.right, b2.right, assumptions: assumptions);
        if (dn case IntegerNumber(asInt: final dnInt?)) {
          if (dk case IntegerNumber(asInt: final dkInt?)
              when dnInt.abs() + dkInt.abs() <= 1000) {
            final units = math.min(pExp, -qExp);
            final n1p1 = simplifyAdd([
              b1.left,
              IntegerNumber.one,
            ], assumptions: assumptions);
            final n2p1 = simplifyAdd([
              b2.left,
              IntegerNumber.one,
            ], assumptions: assumptions);
            final k1p1 = simplifyAdd([
              b1.right,
              IntegerNumber.one,
            ], assumptions: assumptions);
            final k2p1 = simplifyAdd([
              b2.right,
              IntegerNumber.one,
            ], assumptions: assumptions);
            final nk1p1 = simplifyAdd([
              simplifySub(b1.left, b1.right, assumptions: assumptions),
              IntegerNumber.one,
            ], assumptions: assumptions);
            final nk2p1 = simplifyAdd([
              simplifySub(b2.left, b2.right, assumptions: assumptions),
              IntegerNumber.one,
            ], assumptions: assumptions);

            final r1 = collectGammaRatio(n1p1, n2p1, dnInt, units);
            if (r1 == null) continue;
            final r2 = collectGammaRatio(k2p1, k1p1, -dkInt, units);
            if (r2 == null) continue;
            final r3 = collectGammaRatio(nk2p1, nk1p1, dkInt - dnInt, units);
            if (r3 == null) continue;

            applyCollected(r1);
            applyCollected(r2);
            applyCollected(r3);

            pExp -= units;
            expMap[p] = pExp;
            expMap[q] = qExp + units;
            if (pExp == 0) break;
          }
        }
      }
    }
  }

  // Pairwise Factorial / Gamma cancellation
  if (posGammas.isNotEmpty && negGammas.isNotEmpty) {
    Expr gammaArg(Expr node) => switch (node) {
      Gamma(:final expr) => expr,
      Factorial(:final expr) => simplifyAdd([
        expr,
        IntegerNumber.one,
      ], assumptions: assumptions),
      _ => node,
    };

    for (final p in posGammas) {
      var pExp = expMap[p]!;
      if (pExp <= 0) continue;
      final a = gammaArg(p);
      for (final q in negGammas) {
        final qExp = expMap[q]!;
        if (qExp >= 0) continue;
        final b = gammaArg(q);
        final diff = simplifySub(a, b, assumptions: assumptions);
        if (diff case IntegerNumber(asInt: final d?) when d.abs() <= 1000) {
          final units = math.min(pExp, -qExp);
          final r = collectGammaRatio(a, b, d, units);
          if (r == null) continue;
          applyCollected(r);
          pExp -= units;
          expMap[p] = pExp;
          expMap[q] = qExp + units;
          if (pExp == 0) break;
        }
      }
    }
  }

  for (final MapEntry(:key, :value) in expMap.entries) {
    final delta = value - (initialExp[key] ?? 0);
    if (delta == 0) continue;
    final current = baseExponents[key];
    final currentVal = current is IntegerNumber ? current.asInt ?? 0 : 0;
    final updated = currentVal + delta;
    if (updated == 0) {
      baseExponents.remove(key);
    } else {
      baseExponents[key] = IntegerNumber.of(updated);
    }
  }

  return currentCoeff;
}
