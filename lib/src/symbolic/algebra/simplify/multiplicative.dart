import '../../assumptions.dart';
import '../../ast.dart';
import '../../number/integer.dart';
import '../structural_order.dart';
import '../term_accumulator.dart';
import 'additive.dart';
import 'power.dart';
import 'transcendental.dart';

/// Simplifies an N-ary multiplication expression across [factors].
Expr simplifyMul(
  List<Expr> factors, {
  Assumptions assumptions = Assumptions.none,
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
        return (coeff is RealNumber ||
                (coeff is ComplexNumber &&
                    (coeff.real is RealNumber ||
                        coeff.imaginary is RealNumber)))
            ? const RealNumber(0.0)
            : IntegerNumber.zero;
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
          baseExponents.remove(base);
        } else {
          baseExponents[base] = sumExp;
        }
      } else {
        baseExponents[base] = exp;
      }
    }
  }

  // Combine radical factors with matching fractional exponents (e.g. sqrt(x) * sqrt(y) -> sqrt(x * y))
  _combineRadicalBases(baseExponents, assumptions: assumptions);

  // Fold rational coefficient factors into matching integer radical bases (e.g. 2 * 2^(-1/2) -> 2^(1/2))
  if (coeff is RationalNumber && !coeff.isOne && !coeff.isNegativeOne) {
    coeff = _absorbRationalCoeffIntoRadicals(coeff, baseExponents);
  }

  final remainingFactors = <Expr>[];
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
        if (coeff.isZero) return IntegerNumber.zero;
      case Mul(:final factors):
        for (final sub in factors) {
          if (sub is Number) {
            coeff = coeff.mul(sub);
            if (coeff.isZero) return IntegerNumber.zero;
          } else {
            remainingFactors.add(sub);
          }
        }
      default:
        remainingFactors.add(term);
    }
  }

  // Check if an Add factor is cleanly divisible by negative-power factors (e.g. (x^2 + x) / x -> 1 + x)
  final distributed = _tryDistributeExactDivision(
    coeff,
    remainingFactors,
    assumptions: assumptions,
  );
  if (distributed != null) {
    return distributed;
  }

  return simplifySymbolicProduct(coeff, remainingFactors);
}

/// Simplifies a binary division `left / right`.
Expr simplifyDiv(
  Expr left,
  Expr right, {
  Assumptions assumptions = Assumptions.none,
}) {
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
  Assumptions assumptions = Assumptions.none,
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
  Assumptions assumptions = Assumptions.none,
}) {
  if (factors.length < 2) return null;
  var addIndex = -1;
  Add? addNode;
  List<int>? negPowIndices;

  for (var i = 0; i < factors.length; i++) {
    switch (factors[i]) {
      case final Add a:
        if (addIndex != -1) return null;
        addIndex = i;
        addNode = a;
      case Pow(exponent: RealNumeric(isNegative: true)):
        (negPowIndices ??= []).add(i);
      default:
        break;
    }
  }

  if (addNode == null || negPowIndices == null) return null;

  final negFactors = [for (final idx in negPowIndices) factors[idx]];

  final dividedTerms = <Expr>[];
  for (final term in addNode.terms) {
    final divTerm = simplifyMul([
      term,
      ...negFactors,
    ], assumptions: assumptions);
    if (_hasNegativePowerFactor(divTerm)) {
      return null;
    }
    dividedTerms.add(divTerm);
  }

  final sum = simplifyAdd(dividedTerms, assumptions: assumptions);
  final otherFactors = <Expr>[
    for (var i = 0; i < factors.length; i++)
      if (i != addIndex && !negPowIndices.contains(i)) factors[i],
  ];
  return simplifyMul([
    if (!coeff.isOne) coeff,
    sum,
    ...otherFactors,
  ], assumptions: assumptions);
}

bool _hasNegativePowerFactor(Expr expr) => switch (expr) {
  Pow(exponent: RealNumeric(isNegative: true)) => true,
  Mul(:final factors) => factors.any(_hasNegativePowerFactor),
  _ => false,
};

Expr? _multiplyWithOrderTerm(
  OrderTerm orderTerm,
  Expr other, {
  Assumptions assumptions = Assumptions.none,
}) {
  final v = orderTerm.variable;
  final p = orderTerm.point;
  final n = orderTerm.order;
  final isZeroPoint = p is Number && p.isZero;

  switch (other) {
    case Number(:final isZero):
      return isZero ? IntegerNumber.zero : orderTerm;
    case Constant():
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
