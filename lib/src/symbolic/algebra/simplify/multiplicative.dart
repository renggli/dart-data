import '../../ast.dart';
import '../simplify.dart';
import '../structural_order.dart';
import '../term_accumulator.dart';

/// Simplifies an N-ary multiplication expression across [factors].
Expr simplifyMul(List<Expr> factors) {
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

  // Fast annihilator check: 0 * anything = 0
  for (final f in flatFactors) {
    if (f is Number && f.isZero) {
      return IntegerNumber.zero;
    }
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
        final merged = _multiplyWithOrderTerm(currentOrder, other);
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
              : simplifyMul(remaining);
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
      if (coeff.isZero) return IntegerNumber.zero;
    } else {
      final (base, exp) = decomposeFactor(f);
      final existingExp = baseExponents[base];
      if (existingExp != null) {
        final sumExp = simplifyAdd([existingExp, exp]);
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
  _combineRadicalBases(baseExponents);

  // Fold rational coefficient factors into matching integer radical bases (e.g. 2 * 2^(-1/2) -> 2^(1/2))
  if (coeff is RationalNumber && !coeff.isOne && !coeff.isNegativeOne) {
    coeff = _absorbRationalCoeffIntoRadicals(coeff, baseExponents);
  }

  final remainingFactors = <Expr>[];
  for (final MapEntry(key: base, value: exp) in baseExponents.entries) {
    final term = (exp == IntegerNumber.one && base.isSimplified)
        ? base
        : simplifyPow(base, exp);
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
  final distributed = _tryDistributeExactDivision(coeff, remainingFactors);
  if (distributed != null) {
    return distributed;
  }

  return simplifySymbolicProduct(coeff, remainingFactors);
}

/// Simplifies a binary division `left / right`.
Expr simplifyDiv(Expr left, Expr right) {
  if (right is Number && right.isZero) {
    throw UnsupportedError('Division by zero in simplification');
  }
  if (left is Number && right is Number) {
    return left.div(right);
  }
  return simplifyMul([left, simplifyPow(right, IntegerNumber.negativeOne)]);
}

/// Canonically sorts [remainingFactors] and combines with [coeff] into a
/// simplified product expression.
Expr simplifySymbolicProduct(Number coeff, List<Expr> remainingFactors) {
  if (remainingFactors.isEmpty) {
    return coeff;
  }

  remainingFactors.sort((a, b) {
    final cmpBase = compareStructural(
      decomposeFactor(a).$1,
      decomposeFactor(b).$1,
    );
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

void _combineRadicalBases(Map<Expr, Expr> baseExponents) {
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
    if (expA.isNegative) {
      matchingDenBases.add(baseA);
    } else {
      matchingNumBases.add(baseA);
    }

    for (var j = i + 1; j < entries.length; j++) {
      final baseB = entries[j].key;
      if (used.contains(baseB) || baseB == Constant.e) continue;
      final expB = baseExponents[baseB];
      if (expB is FractionNumber &&
          expB.denominator == denA &&
          expB.numerator.abs() == absNumA) {
        if (expB.isNegative) {
          matchingDenBases.add(baseB);
        } else {
          matchingNumBases.add(baseB);
        }
        used.add(baseB);
      }
    }

    if (matchingNumBases.length + matchingDenBases.length >= 2 &&
        matchingNumBases.isNotEmpty) {
      used.add(baseA);
      for (final b in matchingNumBases) {
        baseExponents.remove(b);
      }
      for (final b in matchingDenBases) {
        baseExponents.remove(b);
      }
      final combinedFactors = <Expr>[
        ...matchingNumBases,
        for (final b in matchingDenBases)
          simplifyPow(b, IntegerNumber.negativeOne),
      ];
      final combinedBase = simplifyMul(combinedFactors);
      final existing = baseExponents[combinedBase];
      if (existing != null) {
        final sum = simplifyAdd([existing, posExp]);
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

Expr? _tryDistributeExactDivision(Number coeff, List<Expr> factors) {
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
    final divTerm = simplifyMul([term, ...negFactors]);
    if (_hasNegativePowerFactor(divTerm)) {
      return null;
    }
    dividedTerms.add(divTerm);
  }

  final sum = simplifyAdd(dividedTerms);
  final otherFactors = <Expr>[
    for (var i = 0; i < factors.length; i++)
      if (i != addIndex && !negPowIndices.contains(i)) factors[i],
  ];
  return simplifyMul([if (!coeff.isOne) coeff, sum, ...otherFactors]);
}

bool _hasNegativePowerFactor(Expr expr) => switch (expr) {
  Pow(exponent: RealNumeric(isNegative: true)) => true,
  Mul(:final factors) => factors.any(_hasNegativePowerFactor),
  _ => false,
};

Expr? _multiplyWithOrderTerm(OrderTerm orderTerm, Expr other) {
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
    final shifted = simplifySub(Variable(v), p);
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
      for (final term in terms) simplifyMul([term, orderTerm]),
    ]);
  }

  return null;
}
