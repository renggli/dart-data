import '../assumptions.dart';
import '../ast.dart';
import 'simplify.dart';
import 'term_accumulator.dart';

/// Algebraic expansion extension on [Expr].
extension ExpandExtension on Expr {
  /// Expands multiplications over additions and integer powers of sums.
  ///
  /// Conceptually, this distributes products such as $(A + B)(C + D) \to AC + AD + BC + BD$,
  /// expands integer powers of sums such as $(x + y)^2 \to 1 \cdot x^2 + 2xy + y^2$, and
  /// recursively expands sub-expressions within mathematical functions such as
  /// $\sin((x + 1)^2) \to \sin(1 + 2x + x^2)$. Formally, this applies the distributive
  /// property of the commutative ring of algebraic expressions.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final expr = (x - 2) * (x - 3);
  /// final expanded = expr.expand(); // 6 - 5 * x + x^2
  /// ```
  Expr expand({Assumptions assumptions = Assumptions.none}) {
    final expanded = _expand(this);
    return (identical(assumptions, Assumptions.none) || assumptions.isEmpty)
        ? expanded
        : expanded.simplify(assumptions: assumptions);
  }
}

Expr _expand(Expr expr) => switch (expr) {
  Add(:final terms) => _expandAdd(terms),
  Mul(:final factors) => _expandMul(factors),
  Pow(:final base, :final exponent) => _expandPow(
    _expand(base),
    _expand(exponent),
  ),
  _ => expr.mapChildren(_expand),
};

Expr _expandAdd(List<Expr> terms) {
  final acc = MonomialAccumulator();
  for (final term in terms) {
    acc.add(_expand(term));
  }
  acc.reduceIdentities();
  return acc.build();
}

Expr _expandMul(List<Expr> factors) {
  if (factors.isEmpty) return IntegerNumber.one;
  var current = _expand(factors.first);
  for (var i = 1; i < factors.length; i++) {
    final next = _expand(factors[i]);
    current = _expandMulPair(current, next);
  }
  return current;
}

Expr _expandMulPair(Expr left, Expr right) {
  final leftTerms = <Expr>[];
  MonomialAccumulator.collectTerms(left, leftTerms);
  final rightTerms = <Expr>[];
  MonomialAccumulator.collectTerms(right, rightTerms);

  if (leftTerms.length == 1 && rightTerms.length == 1) {
    return simplifyMul([leftTerms.first, rightTerms.first]);
  }

  final parsedLeft = leftTerms.map(_parsePolyMonomial).toList(growable: false);
  final parsedRight = rightTerms
      .map(_parsePolyMonomial)
      .toList(growable: false);

  final acc = MonomialAccumulator();
  for (var i = 0; i < leftTerms.length; i++) {
    final pL = parsedLeft[i];
    final rawL = leftTerms[i];
    for (var j = 0; j < rightTerms.length; j++) {
      final pR = parsedRight[j];
      if (pL != null && pR != null) {
        final coeff = pL.coeff.mul(pR.coeff);
        if (!coeff.isZero) {
          final base = _mergePolyFactors(pL.factors, pR.factors);
          acc.addDecomposed(coeff, base);
        }
      } else {
        acc.add(simplifyMul([rawL, rightTerms[j]]));
      }
    }
  }
  acc.reduceIdentities();
  return acc.build();
}

class _PolyFactor {
  const new(this.variable, this.exponent, this.node);
  final Variable variable;
  final IntegerNumber exponent;
  final Expr node;
}

class _PolyMonomial {
  const new(this.coeff, this.factors);
  final Number coeff;
  final List<_PolyFactor> factors;
}

_PolyMonomial? _parsePolyMonomial(Expr expr) => switch (expr) {
  Number() => _PolyMonomial(expr, const []),
  Variable() => _PolyMonomial(IntegerNumber.one, [
    _PolyFactor(expr, IntegerNumber.one, expr),
  ]),
  Pow(base: final Variable base, exponent: final IntegerNumber exp) =>
    _PolyMonomial(IntegerNumber.one, [_PolyFactor(base, exp, expr)]),
  Mul(:final factors) => () {
    Number coeff = IntegerNumber.one;
    final polyFactors = <_PolyFactor>[];
    for (final f in factors) {
      switch (f) {
        case Number():
          coeff = coeff.mul(f);
        case Variable():
          polyFactors.add(_PolyFactor(f, IntegerNumber.one, f));
        case Pow(base: final Variable base, exponent: final IntegerNumber exp):
          polyFactors.add(_PolyFactor(base, exp, f));
        default:
          return null;
      }
    }
    return _PolyMonomial(coeff, polyFactors);
  }(),
  _ => null,
};

Expr _mergePolyFactors(List<_PolyFactor> a, List<_PolyFactor> b) {
  if (a.isEmpty && b.isEmpty) return IntegerNumber.one;
  if (a.isEmpty) {
    return b.length == 1
        ? b.first.node
        : Mul([for (final f in b) f.node], isSimplified: true);
  }
  if (b.isEmpty) {
    return a.length == 1
        ? a.first.node
        : Mul([for (final f in a) f.node], isSimplified: true);
  }

  final merged = <Expr>[];
  var i = 0;
  var j = 0;
  while (i < a.length && j < b.length) {
    final fA = a[i];
    final fB = b[j];
    final cmp = fA.variable.name.compareTo(fB.variable.name);
    if (cmp < 0) {
      merged.add(fA.node);
      i++;
    } else if (cmp > 0) {
      merged.add(fB.node);
      j++;
    } else {
      final sumExp = IntegerNumber(fA.exponent.value + fB.exponent.value);
      if (!sumExp.isZero) {
        merged.add(
          sumExp.isOne
              ? fA.variable
              : Pow(fA.variable, sumExp, isSimplified: true),
        );
      }
      i++;
      j++;
    }
  }
  while (i < a.length) {
    merged.add(a[i++].node);
  }
  while (j < b.length) {
    merged.add(b[j++].node);
  }
  return switch (merged) {
    [] => IntegerNumber.one,
    [final single] => single,
    _ => Mul(merged, isSimplified: true),
  };
}

Expr _expandPow(Expr base, Expr exponent) {
  final intExp = switch (exponent) {
    IntegerNumber(:final asInt) => asInt,
    RealNumber(:final value)
        when value == value.roundToDouble() && value.abs() < 1e9 =>
      value.round(),
    _ => null,
  };

  if (intExp != null) {
    if (intExp < 0 && base is Number && base.isZero) {
      throw UnsupportedError('Division by zero in expansion');
    }
    if (intExp == 0) return IntegerNumber.one;
    if (intExp == 1) return base;
    if (intExp > 1) {
      return _expandPowInteger(base, intExp);
    }
    if (intExp < 0) {
      final pos = _expandPowInteger(base, -intExp);
      return simplifyPow(pos, IntegerNumber.negativeOne);
    }
  }
  return simplifyPow(base, exponent);
}

Expr _expandPowInteger(Expr base, int exponent) {
  Expr result = IntegerNumber.one;
  var current = base;
  var exp = exponent;
  while (exp > 0) {
    if (exp.isOdd) {
      result = _expandMulPair(result, current);
    }
    exp ~/= 2;
    if (exp > 0) {
      current = _expandMulPair(current, current);
    }
  }
  return result;
}
