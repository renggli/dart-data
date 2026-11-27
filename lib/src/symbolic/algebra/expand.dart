import 'dart:collection';
import 'dart:math' as math;

import '../assumptions.dart';
import '../ast.dart';
import 'simplify.dart';
import 'simplify/multiplicative.dart';
import 'simplify/power.dart';
import 'term_accumulator.dart';

/// Expands `a * b - c * d` directly into canonical expanded form without
/// allocating intermediate unexpanded sum/product AST nodes.
Expr expandMulDiff(
  Expr a,
  Expr b,
  Expr c,
  Expr d, {
  Assumptions assumptions = Assumptions.none,
}) {
  final eA = _expand(a, assumptions);
  final eB = _expand(b, assumptions);
  final eC = _expand(c, assumptions);
  final eD = _expand(d, assumptions);

  final tA = <Expr>[];
  final tB = <Expr>[];
  final tC = <Expr>[];
  final tD = <Expr>[];
  MonomialAccumulator.collectTerms(eA, tA);
  MonomialAccumulator.collectTerms(eB, tB);
  MonomialAccumulator.collectTerms(eC, tC);
  MonomialAccumulator.collectTerms(eD, tD);

  final pA = [for (final t in tA) _parsePolyMonomial(t)];
  final pB = [for (final t in tB) _parsePolyMonomial(t)];
  final pC = [for (final t in tC) _parsePolyMonomial(t)];
  final pD = [for (final t in tD) _parsePolyMonomial(t)];

  if (_tryPackMulDiff(pA, pB, pC, pD) case (
    :final polyA,
    :final polyB,
    :final polyC,
    :final polyD,
    :final basis,
  )) {
    final res = _mulSubPacked(polyA, polyB, polyC, polyD, basis.totalSize);
    final mat = _materializePackedPoly(res, basis, assumptions);
    return (identical(assumptions, Assumptions.none) || assumptions.isEmpty)
        ? mat
        : mat.simplify(assumptions: assumptions);
  }

  final ab = _expandMulPair(eA, eB, assumptions);
  final cd = _expandMulPair(eC, eD, assumptions);
  final acc = MonomialAccumulator(assumptions: assumptions)
    ..add(ab)
    ..add(cd, IntegerNumber.negativeOne)
    ..reduceIdentities();
  final built = acc.build();
  return (identical(assumptions, Assumptions.none) || assumptions.isEmpty)
      ? built
      : built.simplify(assumptions: assumptions);
}

/// Algebraic expansion extension on [Expr].
extension ExpandExtension on Expr {
  /// Expands multiplications over additions and integer powers of sums.
  ///
  /// Conceptually, this distributes products such as `(A + B)(C + D) -> AC + AD + BC + BD`,
  /// expands integer powers of sums such as `(x + y)^2 -> 1 * x^2 + 2xy + y^2`, and
  /// recursively expands sub-expressions within mathematical functions such as
  /// `sin((x + 1)^2) -> sin(1 + 2x + x^2)`. Formally, this applies the distributive
  /// property of the commutative ring of algebraic expressions.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final expr = (x - 2) * (x - 3);
  /// final expanded = expr.expand(); // 6 - 5 * x + x^2
  /// ```
  Expr expand({Assumptions assumptions = Assumptions.none}) {
    final expanded = _expand(this, assumptions);
    return (identical(assumptions, Assumptions.none) || assumptions.isEmpty)
        ? expanded
        : expanded.simplify(assumptions: assumptions);
  }
}

bool _isPolyAtom(Expr e) => switch (e) {
  Number() || Variable() => true,
  Pow(base: Variable(), exponent: IntegerNumber(asInt: final n?)) => n >= 2,
  _ => false,
};

bool _isPolyMonomialExpr(Expr e) =>
    _isPolyAtom(e) || (e is Mul && e.factors.every(_isPolyAtom));

bool _isExpandedPoly(Expr e) =>
    _isPolyMonomialExpr(e) || (e is Add && e.terms.every(_isPolyMonomialExpr));

Expr _expand(Expr expr, Assumptions assumptions) {
  if (_isExpandedPoly(expr)) return expr;
  return switch (expr) {
    Add(:final terms) => _expandAdd(terms, assumptions),
    Mul(:final factors) => _expandMul(factors, assumptions),
    Pow(:final base, :final exponent) => _expandPow(
      _expand(base, assumptions),
      _expand(exponent, assumptions),
      assumptions,
    ),
    _ => expr.mapChildren((c) => _expand(c, assumptions)),
  };
}

Expr _expandAdd(List<Expr> terms, Assumptions assumptions) {
  final acc = MonomialAccumulator(assumptions: assumptions);
  for (final term in terms) {
    acc.add(_expand(term, assumptions));
  }
  acc.reduceIdentities();
  return acc.build();
}

Expr _expandMul(List<Expr> factors, Assumptions assumptions) {
  if (factors.isEmpty) return IntegerNumber.one;
  var current = _expand(factors.first, assumptions);
  for (var i = 1; i < factors.length; i++) {
    final next = _expand(factors[i], assumptions);
    current = _expandMulPair(current, next, assumptions);
  }
  return current;
}

Expr _expandMulPair(Expr left, Expr right, Assumptions assumptions) {
  final leftTerms = <Expr>[];
  MonomialAccumulator.collectTerms(left, leftTerms);
  final rightTerms = <Expr>[];
  MonomialAccumulator.collectTerms(right, rightTerms);

  if (leftTerms.length == 1 && rightTerms.length == 1) {
    return simplifyMul([
      leftTerms.first,
      rightTerms.first,
    ], assumptions: assumptions);
  }

  final parsedLeft = leftTerms.map(_parsePolyMonomial).toList(growable: false);
  final parsedRight = rightTerms
      .map(_parsePolyMonomial)
      .toList(growable: false);

  if (_tryPackMulPair(parsedLeft, parsedRight) case (
    :final polyA,
    :final polyB,
    :final basis,
  )) {
    final prod = _multiplyPacked(polyA, polyB, basis.totalSize);
    return _materializePackedPoly(prod, basis, assumptions);
  }

  final acc = MonomialAccumulator(assumptions: assumptions);
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
        acc.add(simplifyMul([rawL, rightTerms[j]], assumptions: assumptions));
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
    if (polyFactors.length > 1) {
      polyFactors.sort((a, b) => a.variable.name.compareTo(b.variable.name));
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
        : Mul.canonical([for (final f in b) f.node], simplified: true);
  }
  if (b.isEmpty) {
    return a.length == 1
        ? a.first.node
        : Mul.canonical([for (final f in a) f.node], simplified: true);
  }

  final vars = <Expr>[];
  final pows = <Expr>[];
  void pushFactor(Expr node) {
    if (node is Variable) {
      vars.add(node);
    } else {
      pows.add(node);
    }
  }

  var i = 0;
  var j = 0;
  while (i < a.length && j < b.length) {
    final fA = a[i];
    final fB = b[j];
    final cmp = fA.variable.name.compareTo(fB.variable.name);
    if (cmp < 0) {
      pushFactor(fA.node);
      i++;
    } else if (cmp > 0) {
      pushFactor(fB.node);
      j++;
    } else {
      final aInt = fA.exponent.asInt;
      final bInt = fB.exponent.asInt;
      final IntegerNumber sumExp;
      if (aInt != null &&
          bInt != null &&
          aInt.abs() <= 4503599627370495 &&
          bInt.abs() <= 4503599627370495) {
        sumExp = IntegerNumber.of(aInt + bInt);
      } else {
        sumExp = IntegerNumber(fA.exponent.value + fB.exponent.value);
      }
      if (!sumExp.isZero) {
        if (sumExp.isOne) {
          vars.add(fA.variable);
        } else {
          pows.add(Pow.canonical(fA.variable, sumExp, simplified: true));
        }
      }
      i++;
      j++;
    }
  }
  while (i < a.length) {
    pushFactor(a[i++].node);
  }
  while (j < b.length) {
    pushFactor(b[j++].node);
  }
  final merged = vars.isEmpty
      ? pows
      : (pows.isEmpty ? vars : [...vars, ...pows]);
  return switch (merged) {
    [] => IntegerNumber.one,
    [final single] => single,
    _ => Mul.canonical(merged, simplified: true),
  };
}

Expr _expandPow(Expr base, Expr exponent, Assumptions assumptions) {
  if (base == Constant.undefined || exponent == Constant.undefined) {
    return Constant.undefined;
  }
  if (exponent case IntegerNumber(asInt: final intExp?)) {
    if (intExp == 0) {
      if (base == Constant.infinity) return Constant.undefined;
      return base.anyNode((n) => n is RealNumber)
          ? const RealNumber(1.0)
          : IntegerNumber.one;
    }
    if (intExp < 0 && base is Number && base.isZero) {
      return Constant.undefined;
    }
    if (intExp == 1) return base;
    final hasAdd = base is Add || base.anyNode((n) => n is Add);
    final expCap = hasAdd ? 64 : 1024;
    if (intExp > 1) {
      if (intExp > expCap) {
        return simplifyPow(base, exponent, assumptions: assumptions);
      }
      return _expandPowInteger(base, intExp, assumptions);
    }
    if (intExp < 0) {
      if (intExp < -expCap) {
        return simplifyPow(base, exponent, assumptions: assumptions);
      }
      final pos = _expandPowInteger(base, -intExp, assumptions);
      return simplifyPow(
        pos,
        IntegerNumber.negativeOne,
        assumptions: assumptions,
      );
    }
  }
  return simplifyPow(base, exponent, assumptions: assumptions);
}

Expr _expandPowInteger(Expr base, int exponent, Assumptions assumptions) {
  final baseTerms = <Expr>[];
  MonomialAccumulator.collectTerms(base, baseTerms);
  if (baseTerms.length > 1) {
    final parsed = baseTerms.map(_parsePolyMonomial).toList(growable: false);
    if (_tryPackPow(parsed, exponent) case (:final poly, :final basis)) {
      _PackedPoly? result;
      var current = poly;
      var exp = exponent;
      while (exp > 0) {
        if (exp.isOdd) {
          result = result == null
              ? current
              : _multiplyPacked(result, current, basis.totalSize);
        }
        exp ~/= 2;
        if (exp > 0) {
          current = _multiplyPacked(current, current, basis.totalSize);
        }
      }
      return _materializePackedPoly(result!, basis, assumptions);
    }
  }

  Expr result = IntegerNumber.one;
  var current = base;
  var exp = exponent;
  while (exp > 0) {
    if (exp.isOdd) {
      result = _expandMulPair(result, current, assumptions);
    }
    exp ~/= 2;
    if (exp > 0) {
      current = _expandMulPair(current, current, assumptions);
    }
  }
  return result;
}

const int _maxPackedPolySize = 536870911;
const int _densePolyThreshold = 8192;

typedef _PackedPoly = ({List<int> keys, List<Number> coeffs, bool hasReal});

typedef _PackedBasis = ({
  List<Variable> vars,
  List<int> strides,
  int totalSize,
});

bool _isPackedCoeffReal(Number n) =>
    n is RealNumber ||
    (n is ComplexNumber && (n.real is RealNumber || n.imaginary is RealNumber));

bool _allNonNegIntExps(List<_PolyMonomial?> terms) {
  for (var i = 0; i < terms.length; i++) {
    final t = terms[i];
    if (t == null) return false;
    final factors = t.factors;
    for (var j = 0; j < factors.length; j++) {
      final expInt = factors[j].exponent.asInt;
      if (expInt == null || expInt < 0) return false;
    }
  }
  return true;
}

(List<Variable>, Map<String, int>) _collectSortedVariables(
  List<List<_PolyMonomial?>> groups,
) {
  final varMap = <String, Variable>{};
  for (final group in groups) {
    for (var i = 0; i < group.length; i++) {
      final factors = group[i]!.factors;
      for (var j = 0; j < factors.length; j++) {
        final v = factors[j].variable;
        varMap.putIfAbsent(v.name, () => v);
      }
    }
  }
  final vars = varMap.values.toList(growable: false)
    ..sort((a, b) => a.name.compareTo(b.name));
  final index = <String, int>{
    for (var i = 0; i < vars.length; i++) vars[i].name: i,
  };
  return (vars, index);
}

List<int> _maxExponentsForGroup(
  List<_PolyMonomial?> group,
  Map<String, int> varIndex,
) {
  final maxExps = List<int>.filled(varIndex.length, 0);
  for (var i = 0; i < group.length; i++) {
    final factors = group[i]!.factors;
    for (var j = 0; j < factors.length; j++) {
      final f = factors[j];
      final idx = varIndex[f.variable.name]!;
      final e = f.exponent.asInt!;
      if (e > maxExps[idx]) maxExps[idx] = e;
    }
  }
  return maxExps;
}

_PackedBasis? _buildPackedBasis(List<Variable> vars, List<int> maxOut) {
  final k = vars.length;
  var totalSize = 1;
  final strides = List<int>.filled(k, 1);
  for (var v = k - 1; v >= 0; v--) {
    final radix = maxOut[v] + 1;
    if (radix <= 0 || totalSize > _maxPackedPolySize ~/ radix) {
      return null;
    }
    strides[v] = totalSize;
    totalSize *= radix;
  }
  return (vars: vars, strides: strides, totalSize: totalSize);
}

_PackedPoly _encodeGroup(
  List<_PolyMonomial?> group,
  Map<String, int> varIndex,
  List<int> strides,
) {
  final keys = List<int>.filled(group.length, 0);
  final coeffs = List<Number>.filled(group.length, IntegerNumber.zero);
  var hasReal = false;
  for (var i = 0; i < group.length; i++) {
    final m = group[i]!;
    if (!hasReal && _isPackedCoeffReal(m.coeff)) {
      hasReal = true;
    }
    var key = 0;
    final factors = m.factors;
    for (var j = 0; j < factors.length; j++) {
      final f = factors[j];
      key += f.exponent.asInt! * strides[varIndex[f.variable.name]!];
    }
    keys[i] = key;
    coeffs[i] = m.coeff;
  }
  return (keys: keys, coeffs: coeffs, hasReal: hasReal);
}

({_PackedPoly polyA, _PackedPoly polyB, _PackedBasis basis})? _tryPackMulPair(
  List<_PolyMonomial?> parsedLeft,
  List<_PolyMonomial?> parsedRight,
) {
  if (!_allNonNegIntExps(parsedLeft) || !_allNonNegIntExps(parsedRight)) {
    return null;
  }
  final (vars, varIndex) = _collectSortedVariables([parsedLeft, parsedRight]);
  final maxL = _maxExponentsForGroup(parsedLeft, varIndex);
  final maxR = _maxExponentsForGroup(parsedRight, varIndex);
  final maxOut = <int>[for (var v = 0; v < vars.length; v++) maxL[v] + maxR[v]];
  final basis = _buildPackedBasis(vars, maxOut);
  if (basis == null) return null;
  return (
    polyA: _encodeGroup(parsedLeft, varIndex, basis.strides),
    polyB: _encodeGroup(parsedRight, varIndex, basis.strides),
    basis: basis,
  );
}

({
  _PackedPoly polyA,
  _PackedPoly polyB,
  _PackedPoly polyC,
  _PackedPoly polyD,
  _PackedBasis basis,
})?
_tryPackMulDiff(
  List<_PolyMonomial?> pA,
  List<_PolyMonomial?> pB,
  List<_PolyMonomial?> pC,
  List<_PolyMonomial?> pD,
) {
  if (!_allNonNegIntExps(pA) ||
      !_allNonNegIntExps(pB) ||
      !_allNonNegIntExps(pC) ||
      !_allNonNegIntExps(pD)) {
    return null;
  }
  final (vars, varIndex) = _collectSortedVariables([pA, pB, pC, pD]);
  final maxA = _maxExponentsForGroup(pA, varIndex);
  final maxB = _maxExponentsForGroup(pB, varIndex);
  final maxC = _maxExponentsForGroup(pC, varIndex);
  final maxD = _maxExponentsForGroup(pD, varIndex);
  final maxOut = <int>[
    for (var v = 0; v < vars.length; v++)
      math.max(maxA[v] + maxB[v], maxC[v] + maxD[v]),
  ];
  final basis = _buildPackedBasis(vars, maxOut);
  if (basis == null) return null;
  return (
    polyA: _encodeGroup(pA, varIndex, basis.strides),
    polyB: _encodeGroup(pB, varIndex, basis.strides),
    polyC: _encodeGroup(pC, varIndex, basis.strides),
    polyD: _encodeGroup(pD, varIndex, basis.strides),
    basis: basis,
  );
}

({_PackedPoly poly, _PackedBasis basis})? _tryPackPow(
  List<_PolyMonomial?> parsed,
  int exponent,
) {
  if (!_allNonNegIntExps(parsed)) return null;
  final (vars, varIndex) = _collectSortedVariables([parsed]);
  final maxBase = _maxExponentsForGroup(parsed, varIndex);
  final maxOut = List<int>.filled(vars.length, 0);
  for (var v = 0; v < vars.length; v++) {
    final m = maxBase[v];
    if (m > _maxPackedPolySize ~/ exponent) return null;
    maxOut[v] = m * exponent;
  }
  final basis = _buildPackedBasis(vars, maxOut);
  if (basis == null) return null;
  return (poly: _encodeGroup(parsed, varIndex, basis.strides), basis: basis);
}

_PackedPoly _multiplyPacked(_PackedPoly a, _PackedPoly b, int totalSize) {
  final hasReal = a.hasReal || b.hasReal;
  final keysA = a.keys;
  final coeffsA = a.coeffs;
  final keysB = b.keys;
  final coeffsB = b.coeffs;

  if (totalSize <= _densePolyThreshold) {
    final dense = List<Number?>.filled(totalSize, null);
    final touched = <int>[];
    for (var i = 0; i < keysA.length; i++) {
      final kA = keysA[i];
      final cA = coeffsA[i];
      for (var j = 0; j < keysB.length; j++) {
        final k = kA + keysB[j];
        final prod = cA.mul(coeffsB[j]);
        final cur = dense[k];
        if (cur == null) {
          dense[k] = prod;
          touched.add(k);
        } else {
          dense[k] = cur.add(prod);
        }
      }
    }
    final outKeys = <int>[];
    final outCoeffs = <Number>[];
    for (var idx = 0; idx < touched.length; idx++) {
      final k = touched[idx];
      final c = dense[k]!;
      if (!c.isZero) {
        outKeys.add(k);
        outCoeffs.add(c);
      }
    }
    return (keys: outKeys, coeffs: outCoeffs, hasReal: hasReal);
  }

  final map = HashMap<int, Number>();
  for (var i = 0; i < keysA.length; i++) {
    final kA = keysA[i];
    final cA = coeffsA[i];
    for (var j = 0; j < keysB.length; j++) {
      final k = kA + keysB[j];
      final prod = cA.mul(coeffsB[j]);
      final cur = map[k];
      if (cur == null) {
        if (!prod.isZero) map[k] = prod;
      } else {
        final sum = cur.add(prod);
        if (sum.isZero) {
          map.remove(k);
        } else {
          map[k] = sum;
        }
      }
    }
  }
  return (
    keys: map.keys.toList(growable: false),
    coeffs: map.values.toList(growable: false),
    hasReal: hasReal,
  );
}

_PackedPoly _mulSubPacked(
  _PackedPoly a,
  _PackedPoly b,
  _PackedPoly c,
  _PackedPoly d,
  int totalSize,
) {
  final hasReal = a.hasReal || b.hasReal || c.hasReal || d.hasReal;
  if (totalSize <= _densePolyThreshold) {
    final dense = List<Number?>.filled(totalSize, null);
    final touched = <int>[];
    void addProd(_PackedPoly x, _PackedPoly y, bool negate) {
      final kx = x.keys;
      final cx = x.coeffs;
      final ky = y.keys;
      final cy = y.coeffs;
      for (var i = 0; i < kx.length; i++) {
        final kX = kx[i];
        final cX = cx[i];
        for (var j = 0; j < ky.length; j++) {
          final k = kX + ky[j];
          final rawProd = cX.mul(cy[j]);
          final prod = negate ? rawProd.neg() : rawProd;
          final cur = dense[k];
          if (cur == null) {
            dense[k] = prod;
            touched.add(k);
          } else {
            dense[k] = cur.add(prod);
          }
        }
      }
    }

    addProd(a, b, false);
    addProd(c, d, true);

    final outKeys = <int>[];
    final outCoeffs = <Number>[];
    for (var idx = 0; idx < touched.length; idx++) {
      final k = touched[idx];
      final val = dense[k]!;
      if (!val.isZero) {
        outKeys.add(k);
        outCoeffs.add(val);
      }
    }
    return (keys: outKeys, coeffs: outCoeffs, hasReal: hasReal);
  }

  final map = HashMap<int, Number>();
  void addProdMap(_PackedPoly x, _PackedPoly y, bool negate) {
    final kx = x.keys;
    final cx = x.coeffs;
    final ky = y.keys;
    final cy = y.coeffs;
    for (var i = 0; i < kx.length; i++) {
      final kX = kx[i];
      final cX = cx[i];
      for (var j = 0; j < ky.length; j++) {
        final k = kX + ky[j];
        final rawProd = cX.mul(cy[j]);
        final prod = negate ? rawProd.neg() : rawProd;
        final cur = map[k];
        if (cur == null) {
          if (!prod.isZero) map[k] = prod;
        } else {
          final sum = cur.add(prod);
          if (sum.isZero) {
            map.remove(k);
          } else {
            map[k] = sum;
          }
        }
      }
    }
  }

  addProdMap(a, b, false);
  addProdMap(c, d, true);
  return (
    keys: map.keys.toList(growable: false),
    coeffs: map.values.toList(growable: false),
    hasReal: hasReal,
  );
}

Expr _materializePackedPoly(
  _PackedPoly poly,
  _PackedBasis basis,
  Assumptions assumptions,
) {
  final keys = poly.keys;
  final coeffs = poly.coeffs;
  final hasReal = poly.hasReal;
  if (keys.isEmpty) {
    return hasReal ? RealNumber.zero : IntegerNumber.zero;
  }

  final vars = basis.vars;
  final strides = basis.strides;
  final varCount = vars.length;
  final isUnassumed =
      identical(assumptions, Assumptions.none) || assumptions.isEmpty;

  Number constant = IntegerNumber.zero;
  final nonConst = <({Expr base, Number coeff})>[];
  final powCache = List<Map<int, Expr>?>.filled(varCount, null);

  Expr varPowerNode(int v, int e) {
    if (e == 1) return vars[v];
    final cache = powCache[v] ??= <int, Expr>{};
    return cache.putIfAbsent(
      e,
      () => Pow.canonical(vars[v], IntegerNumber.of(e), simplified: true),
    );
  }

  for (var i = 0; i < keys.length; i++) {
    final k = keys[i];
    final c = coeffs[i];
    if (k == 0) {
      constant = constant.add(c);
      continue;
    }
    var rem = k;
    final varsPart = <Expr>[];
    final powsPart = <Expr>[];
    for (var v = 0; v < varCount; v++) {
      final stride = strides[v];
      final e = rem ~/ stride;
      if (e > 0) {
        rem -= e * stride;
        if (e == 1) {
          varsPart.add(vars[v]);
        } else {
          powsPart.add(varPowerNode(v, e));
        }
      }
    }
    final merged = varsPart.isEmpty
        ? powsPart
        : (powsPart.isEmpty ? varsPart : <Expr>[...varsPart, ...powsPart]);
    final base = merged.length == 1
        ? merged.first
        : Mul.canonical(merged, simplified: true);
    nonConst.add((base: base, coeff: c));
  }

  final resultTerms = <Expr>[];
  if (!constant.isZero) {
    resultTerms.add(
      hasReal && constant is RationalNumber
          ? RealNumber(constant.toDouble())
          : constant,
    );
  }

  if (nonConst.length > 1) {
    nonConst.sort((a, b) => compareStructural(a.base, b.base));
  }
  for (var i = 0; i < nonConst.length; i++) {
    final (:base, :coeff) = nonConst[i];
    if (coeff.isOne) {
      resultTerms.add(base);
    } else if (base is Mul) {
      resultTerms.add(
        Mul.canonical([coeff, ...base.factors], simplified: isUnassumed),
      );
    } else {
      resultTerms.add(Mul.canonical([coeff, base], simplified: isUnassumed));
    }
  }

  return switch (resultTerms) {
    [] => hasReal ? RealNumber.zero : IntegerNumber.zero,
    [final single] => single,
    _ => Add.canonical(resultTerms, simplified: isUnassumed),
  };
}
