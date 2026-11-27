import '../../algebra/expand.dart';
import '../../algebra/helpers.dart';
import '../../algebra/rational.dart';
import '../../algebra/simplify.dart';
import '../../assumptions.dart';
import '../../ast.dart';
import '../../functions/fn.dart';
import '../../poly/bridge.dart';
import '../../poly/univariate.dart';
import '../differentiation.dart';
import 'definite.dart';
import 'integration.dart';
import 'integration_elementary.dart';

typedef _Poly = Map<int, Expr>;

/// Attempts symbolic integration of transcendental rational expressions in a
/// maximal `exp(...)` or `ln(...)` tower generator using Hermite reduction,
/// Rothstein-Trager logarithmic reduction, and a Risch exponential ODE solver.
Expr? tryTranscendentalTower(
  Expr node,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  if (depth >= 2 ||
      isIntegrationBudgetExhausted() ||
      exceedsNodeBudget(node, 600)) {
    return null;
  }
  if (!markTranscendentalTowerAttempt(node, variable)) return null;

  // Convert u(x)^v(x) with both base and exponent depending on variable to
  // coeff * exp(g(x)) for the Risch exponential ODE / tower solver without
  // collapsing exp(v * ln(u)) back to u^v.
  if (_hasVariableBaseAndExponent(node, variable)) {
    if (_tryIntegrateSelfPower(
          node,
          variable,
          assumptions: assumptions,
          depth: depth,
        )
        case final selfRes?) {
      return selfRes;
    }
  }

  final hasExpOrLn = node.anyNode(
    (n) =>
        (n is Call && n.id == FunctionId.ln && n.args[0].dependsOn(variable)) ||
        (n is Pow && n.base == Constant.e && n.exponent.dependsOn(variable)),
  );
  if (!hasExpOrLn) return null;

  return _integrateInTower(
    node,
    variable,
    assumptions: assumptions,
    depth: depth,
  );
}

/// Solves Risch's differential equation `h' + g' * h = coeff` for
/// `∫ coeff(x) * exp(exponent) dx = h(x) * exp(exponent)` when a closed-form
/// solution in the coefficient field exists.
Expr? tryExpRischOde(
  Expr coeff,
  Expr exponent,
  String variable, {
  required Assumptions assumptions,
}) {
  if (isIntegrationBudgetExhausted() ||
      exceedsNodeBudget(coeff, 350) ||
      exceedsNodeBudget(exponent, 250)) {
    return null;
  }
  final gPrime = exponent
      .derivative(variable, assumptions: assumptions)
      .simplify(assumptions: assumptions);
  if (gPrime is Number && gPrime.isZero) return null;

  // Fast track 1: when g'(x) itself contains transcendental kernels (exp/ln),
  // match the top kernel ratio h = lc(coeff, T) / lc(g', T) and verify
  // h' + g' * h - coeff == 0 directly.
  if (_hasExpOrLn(gPrime, variable)) {
    final candidate = _tryNonRationalOdeCandidate(
      coeff,
      gPrime,
      variable,
      assumptions,
    );
    if (candidate != null) {
      return (candidate * Pow.of(Constant.e, exponent)).simplify(
        assumptions: assumptions,
      );
    }
  }

  // Fast track 2: rational R(x) and rational g'(x) in K(x).
  return _tryRationalExpOde(coeff, exponent, gPrime, variable, assumptions);
}

// ---------------------------------------------------------------------------
// Tower decomposition (Hermite + Rothstein-Trager + polynomial recursion)
// ---------------------------------------------------------------------------

final class _TowerKernel {
  const new(this.expr, this.isExp);

  final Expr expr;
  final bool isExp;
}

Expr? _integrateInTower(
  Expr node,
  String variable, {
  required Assumptions assumptions,
  required int depth,
}) {
  final kernels = _selectMaximalKernels(node, variable);
  for (final kernel in kernels) {
    if (isIntegrationBudgetExhausted()) return null;
    final res = _integrateWithKernel(
      node,
      kernel,
      variable,
      assumptions: assumptions,
      depth: depth,
    );
    if (res != null) return res;
  }
  return null;
}

List<_TowerKernel> _selectMaximalKernels(Expr expr, String variable) {
  final expBases = <Expr, int>{};
  final lnNodes = <Call>{};

  void visit(Expr e) {
    if (e is Pow && e.base == Constant.e && e.exponent.dependsOn(variable)) {
      final (:primBase, scale: _) = _splitExpExponent(e.exponent, variable);
      if (primBase != null) {
        expBases[primBase] = (expBases[primBase] ?? 0) + 1;
      }
    } else if (e is Call &&
        e.id == FunctionId.ln &&
        e.args[0].dependsOn(variable)) {
      lnNodes.add(e);
    }
    e.mapChildren((c) {
      visit(c);
      return c;
    });
  }

  visit(expr);

  // Collect exact kernel nodes and filter to maximal ones (not appearing strictly
  // inside another transcendental argument).
  final rawCandidates = <_TowerKernel>[];
  for (final prim in expBases.keys) {
    // Refine primitive base by integer GCD of exponents sharing `prim` if > 1.
    final exps = <int>[];
    var validGcd = true;
    void collectExps(Expr e) {
      if (!validGcd) return;
      if (e is Pow && e.base == Constant.e && e.exponent.dependsOn(variable)) {
        final s = _splitExpExponent(e.exponent, variable);
        if (s.primBase == prim) {
          exps.add(s.scale.abs());
        } else if (_dependsModuloConstantShift(e.exponent, prim, variable)) {
          validGcd = false;
        }
      }
      e.mapChildren((c) {
        collectExps(c);
        return c;
      });
    }

    collectExps(expr);
    var gen = prim;
    if (validGcd && exps.isNotEmpty) {
      var g = exps.first;
      for (var i = 1; i < exps.length; i++) {
        g = _intGcd(g, exps[i]);
      }
      if (g > 1) {
        gen = (IntegerNumber.of(g) * prim).simplify();
      }
    }
    rawCandidates.add(_TowerKernel(Pow.of(Constant.e, gen), true));
  }
  for (final ln in lnNodes) {
    rawCandidates.add(_TowerKernel(ln, false));
  }

  bool isInsideArg(_TowerKernel inner, _TowerKernel outer) {
    if (inner.expr == outer.expr) return false;
    final outerArg = outer.isExp
        ? (outer.expr as Pow).exponent
        : (outer.expr as Call).args[0];
    return outerArg.anyNode((n) => n == inner.expr);
  }

  final maximal = <_TowerKernel>[
    for (final c in rawCandidates)
      if (!rawCandidates.any((other) => isInsideArg(c, other))) c,
  ];
  // Prefer exp kernels first when multiple independent maximal kernels exist
  // (or higher-nesting ones first).
  maximal.sort((a, b) {
    final aHasSub = _hasExpOrLn(
      a.isExp ? (a.expr as Pow).exponent : (a.expr as Call).args[0],
      variable,
    );
    final bHasSub = _hasExpOrLn(
      b.isExp ? (b.expr as Pow).exponent : (b.expr as Call).args[0],
      variable,
    );
    if (aHasSub != bHasSub) return aHasSub ? -1 : 1;
    if (a.isExp != b.isExp) return a.isExp ? -1 : 1;
    return 0;
  });
  return maximal.length <= 3 ? maximal : maximal.sublist(0, 3);
}

Expr? _integrateWithKernel(
  Expr node,
  _TowerKernel kernel,
  String variable, {
  required Assumptions assumptions,
  required int depth,
}) {
  final tv = freshIntegrationVar('_tr', node, variable, depth);
  final tVar = Variable(tv);

  final Expr? rewritten;
  final Expr uExpr;
  if (kernel.isExp) {
    uExpr = (kernel.expr as Pow).exponent;
    rewritten = _substituteExpKernel(node, uExpr, tVar, variable, assumptions);
  } else {
    uExpr = (kernel.expr as Call).args[0];
    rewritten = _substituteLnKernel(node, uExpr, tVar, assumptions);
  }
  if (rewritten == null ||
      isIntegrationBudgetExhausted() ||
      exceedsNodeBudget(rewritten, 700)) {
    return null;
  }

  var exprInT = rewritten.simplify(assumptions: assumptions);
  if (isIntegrationBudgetExhausted()) return null;
  if ((exprInT is Add ||
          exprInT.anyNode(
            (n) =>
                n is Add &&
                n.anyNode(
                  (m) =>
                      m is Pow &&
                      m.exponent is RealNumeric &&
                      (m.exponent as RealNumeric).isNegative,
                ),
          )) &&
      !exceedsNodeBudget(exprInT, 400)) {
    exprInT = exprInT.together(assumptions: assumptions);
  }
  if (isIntegrationBudgetExhausted() || exceedsNodeBudget(exprInT, 800)) {
    return null;
  }

  final (numExpr, denExpr) = splitNumeratorDenominator(exprInT);
  final numExp = numExpr.expand().simplify(assumptions: assumptions);
  final denExp = denExpr.expand().simplify(assumptions: assumptions);
  if (isIntegrationBudgetExhausted() ||
      exceedsNodeBudget(numExp, 500) ||
      exceedsNodeBudget(denExp, 500)) {
    return null;
  }

  final rawP = extractPolynomialCoefficients(numExp, tv);
  final rawD = extractPolynomialCoefficients(denExp, tv);
  if (rawP == null || rawD == null) return null;

  final pPoly = _polyTrim(rawP, assumptions);
  final dPoly = _polyTrim(rawD, assumptions);
  final pDeg = _polyDeg(pPoly);
  final dDeg = _polyDeg(dPoly);
  if (dDeg < 0 ||
      pDeg > 12 ||
      dDeg > 12 ||
      _hasHighVariableExponent(numExp, variable, 18) ||
      _hasHighVariableExponent(denExp, variable, 18)) {
    return null;
  }

  // Ensure coefficients have no hidden occurrence of the generator `tv`
  // or nested kernels referencing `tv`.
  for (final c in pPoly.values) {
    if (c.dependsOn(tv)) return null;
  }
  for (final c in dPoly.values) {
    if (c.dependsOn(tv)) return null;
  }

  // Derivation D_x in K[tv] and (when exp) u' / (when ln) u'/u.
  final uPrime = uExpr
      .derivative(variable, assumptions: assumptions)
      .simplify(assumptions: assumptions);
  final lnDeriv = kernel.isExp
      ? uPrime
      : _safeCancel(uPrime / uExpr, assumptions);
  if (lnDeriv == null) return null;

  _Poly? totalDeriv(_Poly f) {
    final res = <int, Expr>{};
    for (final MapEntry(key: k, value: ck) in f.entries) {
      if (isIntegrationBudgetExhausted()) return null;
      final dck = ck.derivative(variable, assumptions: assumptions);
      final old0 = res[k] ?? IntegerNumber.zero;
      res[k] = (old0 + dck).simplify(assumptions: assumptions);
      if (k > 0) {
        if (kernel.isExp) {
          final term = (IntegerNumber.of(k) * lnDeriv * ck).simplify(
            assumptions: assumptions,
          );
          res[k] = (res[k]! + term).simplify(assumptions: assumptions);
        } else {
          final term = (IntegerNumber.of(k) * lnDeriv * ck).simplify(
            assumptions: assumptions,
          );
          final oldKm1 = res[k - 1] ?? IntegerNumber.zero;
          res[k - 1] = (oldKm1 + term).simplify(assumptions: assumptions);
        }
      }
    }
    return _polyCancelTrim(res, assumptions);
  }

  // For t = exp(u), separate factor tv^m from denPoly into Laurent terms
  // so Hermite/Rothstein-Trager only run on D(tv) with D(0) != 0.
  var laurentShift = 0;
  final initNum = _polyCancelTrim(pPoly, assumptions);
  final initDen = _polyCancelTrim(dPoly, assumptions);
  if (initNum == null || initDen == null) return null;
  var curNum = initNum;
  var curDen = initDen;
  if (kernel.isExp) {
    while (laurentShift < 12 &&
        (curDen[0] ?? IntegerNumber.zero) == IntegerNumber.zero) {
      if (_polyDeg(curDen) <= 0) return null;
      curDen = <int, Expr>{
        for (final MapEntry(key: k, value: v) in curDen.entries)
          if (k > 0) k - 1: v,
      };
      laurentShift++;
    }
  }

  // Split Laurent / improper part Q(tv) and proper fraction R(tv) / curDen(tv).
  final laurentTerms = <int, Expr>{};
  if (laurentShift > 0) {
    if (_polyDeg(curDen) == 0) {
      final lc = curDen[0]!;
      for (final MapEntry(key: k, value: c) in curNum.entries) {
        final scaled = _safeCancel(c / lc, assumptions);
        if (scaled == null) return null;
        laurentTerms[k - laurentShift] = scaled;
      }
      curNum = const {};
    } else {
      // Split curNum / (tv^laurentShift * curDen) via Bezout identity:
      // 1 = s * tv^laurentShift + t * curDen => curNum/(tv^m * D) = curNum*t/tv^m + curNum*s/D
      final tPower = <int, Expr>{laurentShift: IntegerNumber.one};
      final ext = _polyExtGcd(tPower, curDen, assumptions);
      if (ext == null || _polyDeg(ext.g) != 0) return null;
      final invG0 = _safeCancel(IntegerNumber.one / ext.g[0]!, assumptions);
      if (invG0 == null) return null;
      final sScaled = _polyScale(ext.s, invG0, assumptions);
      final tScaled = _polyScale(ext.t, invG0, assumptions);
      if (sScaled == null || tScaled == null) return null;
      final numNeg = _polyMul(curNum, tScaled, assumptions);
      if (numNeg == null) return null;
      final divNeg = _polyDivRem(numNeg, tPower, assumptions);
      if (divNeg == null) return null;
      for (final MapEntry(key: k, value: c) in divNeg.r.entries) {
        laurentTerms[k - laurentShift] = c;
      }
      final cs = _polyMul(curNum, sScaled, assumptions);
      final qd = _polyMul(divNeg.q, curDen, assumptions);
      if (cs == null || qd == null) return null;
      final numProp = _polyAdd(cs, qd, assumptions);
      if (numProp == null) return null;
      final divProp = _polyDivRem(numProp, curDen, assumptions);
      if (divProp == null) return null;
      for (final MapEntry(key: k, value: c) in divProp.q.entries) {
        final updated = _safeCancel(
          (laurentTerms[k] ?? IntegerNumber.zero) + c,
          assumptions,
        );
        if (updated == null) return null;
        laurentTerms[k] = updated;
      }
      curNum = divProp.r;
    }
  } else {
    final divInit = _polyDivRem(curNum, curDen, assumptions);
    if (divInit == null) return null;
    for (final MapEntry(key: k, value: c) in divInit.q.entries) {
      laurentTerms[k] = c;
    }
    curNum = divInit.r;
  }

  // Step 1: Mack's Hermite reduction in K(tv).
  final rationalTerms = <Expr>[];
  if (_polyDeg(curNum) >= 0 && _polyDeg(curDen) >= 1) {
    if (isIntegrationBudgetExhausted()) return null;
    final dDerivT = _polyPartialDeriv(curDen, assumptions);
    if (dDerivT == null) return null;
    final sqFreeG = _polyGcd(curDen, dDerivT, assumptions);
    if (sqFreeG == null) return null;
    if (_polyDeg(sqFreeG) >= 1) {
      // Exact square-free factorization D = prod_{i >= 1} D_i^i via Yun/gcd.
      final exactSqFactors = _squareFreeFactors(curDen, assumptions);
      if (exactSqFactors == null) return null;

      for (final (:factor, :mult) in exactSqFactors) {
        if (isIntegrationBudgetExhausted()) return null;
        if (mult < 2 || _polyDeg(factor) < 1) continue;
        final vPoly = factor;
        final dV = totalDeriv(vPoly);
        if (dV == null) return null;
        for (var k = mult; k >= 2; k--) {
          if (isIntegrationBudgetExhausted()) return null;
          final vPowK = _polyPow(vPoly, k, assumptions);
          if (vPowK == null) return null;
          final uDiv = _polyDivRem(curDen, vPowK, assumptions);
          if (uDiv == null || _polyDeg(uDiv.r) >= 0) return null;
          final uPoly = uDiv.q;
          final uDv = _polyMul(uPoly, dV, assumptions);
          if (uDv == null) return null;
          final ext = _polyExtGcd(uDv, vPoly, assumptions);
          if (ext == null || _polyDeg(ext.g) != 0) return null;
          final g0 = ext.g[0]!;
          final kMinus1 = IntegerNumber.of(k - 1);
          final negR = _polyScale(
            curNum,
            IntegerNumber.negativeOne,
            assumptions,
          );
          if (negR == null) return null;
          final rs = _polyMul(negR, ext.s, assumptions);
          if (rs == null) return null;
          final cScale = _safeCancel(
            IntegerNumber.one / (kMinus1 * g0),
            assumptions,
          );
          if (cScale == null) return null;
          final cFull = _polyScale(rs, cScale, assumptions);
          if (cFull == null) return null;
          final cDiv = _polyDivRem(cFull, vPoly, assumptions);
          if (cDiv == null) return null;
          final cPoly = cDiv.r;

          if (_polyDeg(cPoly) >= 0) {
            final cExpr = _polyEval(cPoly, kernel.expr, assumptions);
            final vExpr = _polyEval(vPoly, kernel.expr, assumptions);
            rationalTerms.add(
              (cExpr / Pow.of(vExpr, kMinus1)).simplify(
                assumptions: assumptions,
              ),
            );

            final dc = totalDeriv(cPoly);
            final uv = _polyMul(uPoly, vPoly, assumptions);
            if (dc == null || uv == null) return null;
            final termA = _polyMul(uv, dc, assumptions);
            final uDvC = _polyMul(uDv, cPoly, assumptions);
            if (termA == null || uDvC == null) return null;
            final termB = _polyScale(uDvC, kMinus1, assumptions);
            if (termB == null) return null;
            final subNum = _polySub(curNum, termA, assumptions);
            if (subNum == null) return null;
            final nextNumFull = _polyAdd(subNum, termB, assumptions);
            if (nextNumFull == null) return null;
            final divV = _polyDivRem(nextNumFull, vPoly, assumptions);
            if (divV == null || _polyDeg(divV.r) >= 0) return null;
            curNum = divV.q;
          }
          final vPowKm1 = _polyPow(vPoly, k - 1, assumptions);
          if (vPowKm1 == null) return null;
          final nextDen = _polyMul(uPoly, vPowKm1, assumptions);
          if (nextDen == null) return null;
          curDen = nextDen;
        }
      }

      // Re-split curNum / curDen after Hermite reduction.
      final afterH = _polyDivRem(curNum, curDen, assumptions);
      if (afterH == null) return null;
      for (final MapEntry(key: k, value: c) in afterH.q.entries) {
        final updated = _safeCancel(
          (laurentTerms[k] ?? IntegerNumber.zero) + c,
          assumptions,
        );
        if (updated == null) return null;
        laurentTerms[k] = updated;
      }
      curNum = afterH.r;
    }
  }

  // Step 2: Logarithmic part for proper square-free fraction curNum / curDen.
  final logTerms = <Expr>[];
  if (_polyDeg(curNum) >= 0 && _polyDeg(curDen) >= 1) {
    if (isIntegrationBudgetExhausted()) return null;
    final degD = _polyDeg(curDen);
    final lcD = curDen[degD]!;
    final invLcD = _safeCancel(IntegerNumber.one / lcD, assumptions);
    if (invLcD == null) return null;
    final dMonic = _polyScale(curDen, invLcD, assumptions);
    final rScaled = _polyScale(curNum, invLcD, assumptions);
    if (dMonic == null || rScaled == null) return null;

    final dMonicDeriv = totalDeriv(dMonic);
    if (dMonicDeriv == null) return null;
    final _Poly? dRem;
    if (kernel.isExp) {
      final degLnDeriv = _safeCancel(
        IntegerNumber.of(degD) * lnDeriv,
        assumptions,
      );
      if (degLnDeriv == null) return null;
      final scaledD = _polyScale(dMonic, degLnDeriv, assumptions);
      if (scaledD == null) return null;
      dRem = _polySub(dMonicDeriv, scaledD, assumptions);
    } else {
      dRem = dMonicDeriv;
    }
    if (dRem == null) return null;

    // 2a. Constant scalar multiple: rScaled == c * dRem.
    if (_polyDeg(dRem) == _polyDeg(rScaled) && _polyDeg(dRem) >= 0) {
      final lcR = rScaled[_polyDeg(rScaled)]!;
      final lcDR = dRem[_polyDeg(dRem)]!;
      final c = _safeCancel(lcR / lcDR, assumptions);
      if (c != null && !c.dependsOn(variable) && !c.dependsOn(tv)) {
        final cDrem = _polyScale(dRem, c, assumptions);
        if (cDrem == null) return null;
        final diff = _polySub(rScaled, cDrem, assumptions);
        if (diff == null) return null;
        if (_polyDeg(diff) < 0) {
          final dExpr = _polyEval(dMonic, kernel.expr, assumptions);
          logTerms.add(
            (c * logAntiderivative(dExpr, assumptions)).simplify(
              assumptions: assumptions,
            ),
          );
          if (kernel.isExp) {
            final shift = _safeCancel(
              c * IntegerNumber.of(degD) * lnDeriv,
              assumptions,
            );
            if (shift == null) return null;
            final updated0 = _safeCancel(
              (laurentTerms[0] ?? IntegerNumber.zero) - shift,
              assumptions,
            );
            if (updated0 == null) return null;
            laurentTerms[0] = updated0;
          }
          curNum = const {};
        }
      }
    }

    // 2b. Degree-2 Rothstein-Trager resultant resolution.
    if (_polyDeg(curNum) >= 0 && degD == 2) {
      final rtRes = _tryQuadraticRothsteinTrager(
        rScaled,
        dMonic,
        dRem,
        kernel,
        lnDeriv,
        totalDeriv,
        variable,
        assumptions,
      );
      if (rtRes == null) return null;
      logTerms.addAll(rtRes.logTerms);
      if (kernel.isExp) {
        final updated0 = _safeCancel(
          (laurentTerms[0] ?? IntegerNumber.zero) - rtRes.polyShift,
          assumptions,
        );
        if (updated0 == null) return null;
        laurentTerms[0] = updated0;
      }
      curNum = const {};
    }

    if (_polyDeg(curNum) >= 0) return null;
  }

  // Step 3: Integrate the Laurent / polynomial part in `kernel`.
  final polyPart = <Expr>[];
  if (kernel.isExp) {
    final sortedKeys = laurentTerms.keys.toList()..sort();
    for (final k in sortedKeys) {
      if (isIntegrationBudgetExhausted()) return null;
      final coeff = laurentTerms[k]!;
      if (_isPolyCoeffZero(coeff, assumptions)) continue;
      if (k == 0) {
        final q0Int = antiDerivative(
          coeff,
          variable,
          assumptions: assumptions,
          depth: depth + 1,
        );
        if (hasUnevaluatedIntegral(q0Int, variable)) return null;
        polyPart.add(q0Int);
      } else {
        final expArg = (IntegerNumber.of(k) * uExpr).simplify(
          assumptions: assumptions,
        );
        final odeRes = tryExpRischOde(
          coeff,
          expArg,
          variable,
          assumptions: assumptions,
        );
        if (odeRes != null) {
          polyPart.add(odeRes);
        } else {
          final recRes = antiDerivative(
            (coeff * Pow.of(Constant.e, expArg)).simplify(
              assumptions: assumptions,
            ),
            variable,
            assumptions: assumptions,
            depth: depth + 1,
          );
          if (hasUnevaluatedIntegral(recRes, variable)) return null;
          polyPart.add(recRes);
        }
      }
    }
  } else {
    final qWork = <int, Expr>{
      for (final MapEntry(key: k, value: c) in laurentTerms.entries)
        if (!_isPolyCoeffZero(c, assumptions)) k: c,
    };
    final maxQ = _polyDeg(qWork);
    for (var k = maxQ; k >= 1; k--) {
      if (isIntegrationBudgetExhausted()) return null;
      final qk = qWork[k];
      if (qk == null || _isPolyCoeffZero(qk, assumptions)) continue;
      // Direct u-sub check: qk / (u'/u) == const.
      final ratio = _safeCancel(qk / lnDeriv, assumptions);
      if (ratio != null && !ratio.dependsOn(variable) && !ratio.dependsOn(tv)) {
        polyPart.add(
          (ratio *
                  Pow.of(kernel.expr, IntegerNumber.of(k + 1)) /
                  IntegerNumber.of(k + 1))
              .simplify(assumptions: assumptions),
        );
        continue;
      }
      final pK = antiDerivative(
        qk,
        variable,
        assumptions: assumptions,
        depth: depth + 1,
      );
      if (hasUnevaluatedIntegral(pK, variable)) return null;
      polyPart.add(
        (pK * Pow.of(kernel.expr, IntegerNumber.of(k))).simplify(
          assumptions: assumptions,
        ),
      );
      final delta = _safeCancel(
        IntegerNumber.of(k) * pK * lnDeriv,
        assumptions,
      );
      if (delta == null) return null;
      final updatedKm1 = _safeCancel(
        (qWork[k - 1] ?? IntegerNumber.zero) - delta,
        assumptions,
      );
      if (updatedKm1 == null) return null;
      qWork[k - 1] = updatedKm1;
    }
    final q0 = qWork[0];
    if (q0 != null && !_isPolyCoeffZero(q0, assumptions)) {
      final q0Int = antiDerivative(
        q0,
        variable,
        assumptions: assumptions,
        depth: depth + 1,
      );
      if (hasUnevaluatedIntegral(q0Int, variable)) return null;
      polyPart.add(q0Int);
    }
  }

  final allTerms = <Expr>[...rationalTerms, ...logTerms, ...polyPart];
  if (allTerms.isEmpty) return IntegerNumber.zero;
  return Add.of(allTerms).simplify(assumptions: assumptions);
}

({List<Expr> logTerms, Expr polyShift})? _tryQuadraticRothsteinTrager(
  _Poly rScaled,
  _Poly dMonic,
  _Poly dRem,
  _TowerKernel kernel,
  Expr lnDeriv,
  _Poly? Function(_Poly) totalDeriv,
  String variable,
  Assumptions assumptions,
) {
  if (isIntegrationBudgetExhausted()) return null;
  final d0 = dMonic[0] ?? IntegerNumber.zero;
  final d1 = dMonic[1] ?? IntegerNumber.zero;
  final r0 = rScaled[0] ?? IntegerNumber.zero;
  final r1 = rScaled[1] ?? IntegerNumber.zero;
  final b0 = dRem[0] ?? IntegerNumber.zero;
  final b1 = dRem[1] ?? IntegerNumber.zero;

  // Resultant in c of D(t) = t^2 + d1*t + d0 and (r1 - c*b1)*t + (r0 - c*b0).
  final c2 = _safeCancel(b0 * b0 - d1 * b0 * b1 + d0 * b1 * b1, assumptions);
  final c1 = _safeCancel(
    d1 * (r0 * b1 + r1 * b0) -
        IntegerNumber.two * r0 * b0 -
        IntegerNumber.two * d0 * r1 * b1,
    assumptions,
  );
  final c0 = _safeCancel(r0 * r0 - d1 * r0 * r1 + d0 * r1 * r1, assumptions);
  if (c2 == null || c1 == null || c0 == null) return null;
  if (c2.dependsOn(variable) ||
      c1.dependsOn(variable) ||
      c0.dependsOn(variable)) {
    return null;
  }

  final roots = <Expr>[];
  if (_isPolyCoeffZero(c2, assumptions)) {
    if (_isPolyCoeffZero(c1, assumptions)) return null;
    final singleRoot = _safeCancel(-c0 / c1, assumptions);
    if (singleRoot == null) return null;
    roots.add(singleRoot);
  } else {
    final disc = _safeCancel(
      c1 * c1 - IntegerNumber.of(4) * c2 * c0,
      assumptions,
    );
    if (disc == null) return null;
    final twoC2 = (IntegerNumber.two * c2).simplify(assumptions: assumptions);
    if (_isPolyCoeffZero(disc, assumptions)) {
      roots.add((-c1 / twoC2).simplify(assumptions: assumptions));
    } else {
      final sqrtDisc = Pow.of(
        disc,
        FractionNumber.half,
      ).simplify(assumptions: assumptions);
      roots.add(((-c1 + sqrtDisc) / twoC2).simplify(assumptions: assumptions));
      roots.add(((-c1 - sqrtDisc) / twoC2).simplify(assumptions: assumptions));
    }
  }

  final logTerms = <Expr>[];
  Expr polyShift = IntegerNumber.zero;
  var reconstructedNum = const <int, Expr>{};

  for (final root in roots) {
    if (isIntegrationBudgetExhausted()) return null;
    final scaledDrem = _polyScale(dRem, root, assumptions);
    if (scaledDrem == null) return null;
    final testPoly = _polySub(rScaled, scaledDrem, assumptions);
    if (testPoly == null) return null;
    final g = _polyGcd(dMonic, testPoly, assumptions);
    if (g == null || _polyDeg(g) != 1) continue;
    final invG1 = _safeCancel(IntegerNumber.one / g[1]!, assumptions);
    if (invG1 == null) return null;
    final gMonic = _polyScale(g, invG1, assumptions);
    if (gMonic == null) return null;
    final gExpr = _polyEval(gMonic, kernel.expr, assumptions);
    logTerms.add(
      (root * logAntiderivative(gExpr, assumptions)).simplify(
        assumptions: assumptions,
      ),
    );
    final cofactor = _polyDivRem(dMonic, gMonic, assumptions);
    if (cofactor == null || _polyDeg(cofactor.r) >= 0) return null;
    final dg = totalDeriv(gMonic);
    if (dg == null) return null;
    final _Poly? dgAdj;
    if (kernel.isExp) {
      final gScaled = _polyScale(gMonic, lnDeriv, assumptions);
      if (gScaled == null) return null;
      dgAdj = _polySub(dg, gScaled, assumptions);
    } else {
      dgAdj = dg;
    }
    if (dgAdj == null) return null;
    final prod = _polyMul(dgAdj, cofactor.q, assumptions);
    if (prod == null) return null;
    final scaledProd = _polyScale(prod, root, assumptions);
    if (scaledProd == null) return null;
    final nextRec = _polyAdd(reconstructedNum, scaledProd, assumptions);
    if (nextRec == null) return null;
    reconstructedNum = nextRec;
    if (kernel.isExp) {
      final nextShift = _safeCancel(polyShift + root * lnDeriv, assumptions);
      if (nextShift == null) return null;
      polyShift = nextShift;
    }
  }

  if (logTerms.isEmpty) return null;
  final residual = _polySub(rScaled, reconstructedNum, assumptions);
  if (residual == null || _polyDeg(residual) >= 0) {
    return null;
  }
  return (logTerms: logTerms, polyShift: polyShift);
}

// ---------------------------------------------------------------------------
// Risch Exponential ODE solvers
// ---------------------------------------------------------------------------

Expr? _tryNonRationalOdeCandidate(
  Expr coeff,
  Expr gPrime,
  String variable,
  Assumptions assumptions,
) {
  final kernels = _selectMaximalKernels(gPrime, variable);
  for (final kernel in kernels) {
    if (isIntegrationBudgetExhausted()) return null;
    final tv = freshIntegrationVar('_ro', coeff, variable, 0);
    final tVar = Variable(tv);
    final rInT = kernel.isExp
        ? _substituteExpKernel(
            coeff,
            (kernel.expr as Pow).exponent,
            tVar,
            variable,
            assumptions,
          )
        : _substituteLnKernel(
            coeff,
            (kernel.expr as Call).args[0],
            tVar,
            assumptions,
          );
    final gpInT = kernel.isExp
        ? _substituteExpKernel(
            gPrime,
            (kernel.expr as Pow).exponent,
            tVar,
            variable,
            assumptions,
          )
        : _substituteLnKernel(
            gPrime,
            (kernel.expr as Call).args[0],
            tVar,
            assumptions,
          );
    if (rInT == null || gpInT == null || isIntegrationBudgetExhausted()) {
      continue;
    }

    final rCoeffs = extractPolynomialCoefficients(
      rInT.expand().simplify(assumptions: assumptions),
      tv,
    );
    final gpCoeffs = extractPolynomialCoefficients(
      gpInT.expand().simplify(assumptions: assumptions),
      tv,
    );
    if (rCoeffs == null || gpCoeffs == null) continue;
    final degR = maxPolynomialDegree(rCoeffs);
    final degGp = maxPolynomialDegree(gpCoeffs);
    if (degGp < 1 || degR < degGp) continue;

    final degH = degR - degGp;
    final lcGp = gpCoeffs[degGp]!;
    if (lcGp is Number && lcGp.isZero) continue;

    // Solve triangularly top-down for polynomial h in T.
    final hCoeffs = <int, Expr>{};
    final workR = Map<int, Expr>.from(rCoeffs);
    var ok = true;
    for (var k = degH; k >= 0; k--) {
      if (isIntegrationBudgetExhausted()) {
        ok = false;
        break;
      }
      final remCoeff = workR[k + degGp] ?? IntegerNumber.zero;
      final hk = _safeCancel(remCoeff / lcGp, assumptions);
      if (hk == null || hk.dependsOn(tv)) {
        ok = false;
        break;
      }
      hCoeffs[k] = hk;
      for (final MapEntry(key: j, value: gj) in gpCoeffs.entries) {
        final cur = workR[k + j] ?? IntegerNumber.zero;
        final updated = _safeCancel(cur - hk * gj, assumptions);
        if (updated == null) {
          ok = false;
          break;
        }
        workR[k + j] = updated;
      }
      if (!ok) break;
      // Also account for k-term derivative in K[T] if k > 0 or k == 0.
      final hkExpr = hk;
      final dHk = hkExpr.derivative(variable, assumptions: assumptions);
      final updated0 = _safeCancel(
        (workR[k] ?? IntegerNumber.zero) - dHk,
        assumptions,
      );
      if (updated0 == null) {
        ok = false;
        break;
      }
      workR[k] = updated0;
      if (k > 0) {
        if (kernel.isExp) {
          final uP = (kernel.expr as Pow).exponent
              .derivative(variable, assumptions: assumptions)
              .simplify(assumptions: assumptions);
          final updatedK = _safeCancel(
            (workR[k] ?? IntegerNumber.zero) -
                IntegerNumber.of(k) * uP * hkExpr,
            assumptions,
          );
          if (updatedK == null) {
            ok = false;
            break;
          }
          workR[k] = updatedK;
        } else {
          final inner = (kernel.expr as Call).args[0];
          final uP = _safeCancel(
            inner.derivative(variable, assumptions: assumptions) / inner,
            assumptions,
          );
          if (uP == null) {
            ok = false;
            break;
          }
          final updatedKm1 = _safeCancel(
            (workR[k - 1] ?? IntegerNumber.zero) -
                IntegerNumber.of(k) * uP * hkExpr,
            assumptions,
          );
          if (updatedKm1 == null) {
            ok = false;
            break;
          }
          workR[k - 1] = updatedKm1;
        }
      }
    }
    if (!ok || isIntegrationBudgetExhausted()) continue;

    final hCandidate = _polyEval(hCoeffs, kernel.expr, assumptions);
    final checkExpr = _safeCancel(
      hCandidate.derivative(variable, assumptions: assumptions) +
          gPrime * hCandidate -
          coeff,
      assumptions,
    );
    if (checkExpr != null && _isPolyCoeffZero(checkExpr, assumptions)) {
      return hCandidate;
    }
  }
  return null;
}

Expr? _tryRationalExpOde(
  Expr coeff,
  Expr exponent,
  Expr gPrime,
  String variable,
  Assumptions assumptions,
) {
  if (isIntegrationBudgetExhausted() ||
      _hasHighVariableExponent(coeff, variable, 18) ||
      _hasHighVariableExponent(gPrime, variable, 18)) {
    return null;
  }
  final combinedR = coeff.together(assumptions: assumptions);
  final combinedGp = gPrime.together(assumptions: assumptions);
  if (isIntegrationBudgetExhausted() ||
      exceedsNodeBudget(combinedR, 600) ||
      exceedsNodeBudget(combinedGp, 600)) {
    return null;
  }
  final (rNumRaw, rDenRaw) = splitNumeratorDenominator(combinedR);
  final (gNumRaw, gDenRaw) = splitNumeratorDenominator(combinedGp);

  final rNumP = extractPolynomialCoefficients(
    rNumRaw.expand().simplify(assumptions: assumptions),
    variable,
  );
  final rDenP = extractPolynomialCoefficients(
    rDenRaw.expand().simplify(assumptions: assumptions),
    variable,
  );
  final gNumP = extractPolynomialCoefficients(
    gNumRaw.expand().simplify(assumptions: assumptions),
    variable,
  );
  final gDenP = extractPolynomialCoefficients(
    gDenRaw.expand().simplify(assumptions: assumptions),
    variable,
  );
  if (rNumP == null || rDenP == null || gNumP == null || gDenP == null) {
    return null;
  }

  final aPoly = _polyCancelTrim(rNumP, assumptions);
  final bPoly = _polyCancelTrim(rDenP, assumptions);
  final ngPoly = _polyCancelTrim(gNumP, assumptions);
  final dgPoly = _polyCancelTrim(gDenP, assumptions);
  if (aPoly == null || bPoly == null || ngPoly == null || dgPoly == null) {
    return null;
  }

  final degA = _polyDeg(aPoly);
  final degB = _polyDeg(bPoly);
  final degNg = _polyDeg(ngPoly);
  final degDg = _polyDeg(dgPoly);
  if (degB < 0 ||
      degDg < 0 ||
      degA > 12 ||
      degB > 12 ||
      degNg > 12 ||
      degDg > 12) {
    return null;
  }

  // Compute candidate denominator D(x) of h = P(x) / D(x).
  var dPoly = <int, Expr>{0: IntegerNumber.one};
  if (degB > 0) {
    final sqB = _squareFreeFactors(bPoly, assumptions);
    if (sqB == null) return null;
    for (final (:factor, mult: e) in sqB) {
      if (isIntegrationBudgetExhausted()) return null;
      if (_polyDeg(factor) < 1) continue;
      // Compute multiplicity m of `factor` in dgPoly.
      var m = 0;
      var workDg = dgPoly;
      while (_polyDeg(workDg) >= _polyDeg(factor)) {
        if (isIntegrationBudgetExhausted()) return null;
        final g = _polyGcd(workDg, factor, assumptions);
        if (g == null || _polyDeg(g) != _polyDeg(factor)) break;
        final div = _polyDivRem(workDg, factor, assumptions);
        if (div == null || _polyDeg(div.r) >= 0) break;
        workDg = div.q;
        m++;
      }
      final int dMult;
      if (m == 0) {
        if (e == 1) return null;
        dMult = e - 1;
      } else if (m >= 2) {
        dMult = e > m ? e - m : 0;
      } else {
        dMult = e;
      }
      if (dMult > 0) {
        final factorPow = _polyPow(factor, dMult, assumptions);
        if (factorPow == null) return null;
        final nextD = _polyMul(dPoly, factorPow, assumptions);
        if (nextD == null) return null;
        dPoly = nextD;
      }
    }
  }

  final degD = _polyDeg(dPoly);
  if (degD > 12) return null;

  // Compute degree bound M for numerator polynomial P(x) in h = P(x) / D(x).
  final delta = degA - degB;
  final deltaG = degNg - degDg;
  var boundM = degD;
  if (deltaG >= 0) {
    final diff = delta - deltaG;
    boundM = (diff > 0 ? diff : 0) + degD + (deltaG == 0 ? 1 : 0);
  } else if (deltaG <= -2) {
    final diff = delta + 1;
    boundM = (diff > 0 ? diff : 0) + degD;
  } else {
    final diff = delta + 1;
    boundM = (diff > 0 ? diff : 0) + degD + 1;
  }
  if (boundM > 12) return null;

  // Equation: (D_g * B) * (P' * D - P * D') + (N_g * B) * P * D = A * D_g * D^2
  final dgB = _polyMul(dgPoly, bPoly, assumptions);
  final ngB = _polyMul(ngPoly, bPoly, assumptions);
  final dDeriv = _polyPartialDeriv(dPoly, assumptions);
  final dSq = _polyMul(dPoly, dPoly, assumptions);
  if (dgB == null || ngB == null || dDeriv == null || dSq == null) {
    return null;
  }
  final aDg = _polyMul(aPoly, dgPoly, assumptions);
  if (aDg == null) return null;
  final rhsPoly = _polyMul(aDg, dSq, assumptions);
  if (rhsPoly == null) return null;

  // Build linear columns for P(x) = sum_{j=0}^boundM c_j x^j.
  final columns = <_Poly>[];
  var maxRowDeg = _polyDeg(rhsPoly);
  for (var j = 0; j <= boundM; j++) {
    if (isIntegrationBudgetExhausted()) return null;
    final xJ = <int, Expr>{j: IntegerNumber.one};
    final xJp = j == 0
        ? const <int, Expr>{}
        : <int, Expr>{j - 1: IntegerNumber.of(j)};
    final pDerivD = _polyMul(xJp, dPoly, assumptions);
    final pDd = _polyMul(xJ, dDeriv, assumptions);
    if (pDerivD == null || pDd == null) return null;
    final diffP = _polySub(pDerivD, pDd, assumptions);
    if (diffP == null) return null;
    final term1 = _polyMul(dgB, diffP, assumptions);
    final xJd = _polyMul(xJ, dPoly, assumptions);
    if (term1 == null || xJd == null) return null;
    final term2 = _polyMul(ngB, xJd, assumptions);
    if (term2 == null) return null;
    final col = _polyAdd(term1, term2, assumptions);
    if (col == null) return null;
    columns.add(col);
    final colDeg = _polyDeg(col);
    if (colDeg > maxRowDeg) maxRowDeg = colDeg;
  }
  if (maxRowDeg < 0) return null;

  final nRows = maxRowDeg + 1;
  final nCols = boundM + 1;
  final mat = List<List<Expr>>.generate(
    nRows,
    (r) => List<Expr>.generate(
      nCols + 1,
      (c) => c < nCols
          ? (columns[c][r] ?? IntegerNumber.zero)
          : (rhsPoly[r] ?? IntegerNumber.zero),
    ),
  );

  final sol = _solveLinearSystemExpr(mat, nRows, nCols, assumptions);
  if (sol == null) return null;

  final pCoeffs = <int, Expr>{};
  for (var j = 0; j <= boundM; j++) {
    if (!_isPolyCoeffZero(sol[j], assumptions)) {
      pCoeffs[j] = sol[j];
    }
  }
  final pExpr = _polyEval(pCoeffs, Variable(variable), assumptions);
  final dExpr = _polyEval(dPoly, Variable(variable), assumptions);
  final hExpr = _safeCancel(pExpr / dExpr, assumptions);
  if (hExpr == null) return null;
  return (hExpr * Pow.of(Constant.e, exponent)).simplify(
    assumptions: assumptions,
  );
}

List<Expr>? _solveLinearSystemExpr(
  List<List<Expr>> mat,
  int nRows,
  int nCols,
  Assumptions assumptions,
) {
  final pivotCols = List<int>.filled(nRows, -1);
  var row = 0;
  for (var col = 0; col < nCols && row < nRows; col++) {
    if (isIntegrationBudgetExhausted()) return null;
    var pivotRow = -1;
    for (var r = row; r < nRows; r++) {
      if (!_isPolyCoeffZero(mat[r][col], assumptions)) {
        pivotRow = r;
        break;
      }
    }
    if (pivotRow < 0) continue;
    if (pivotRow != row) {
      final tmp = mat[row];
      mat[row] = mat[pivotRow];
      mat[pivotRow] = tmp;
    }
    final piv = mat[row][col];
    for (var j = col; j <= nCols; j++) {
      final normalized = _safeCancel(mat[row][j] / piv, assumptions);
      if (normalized == null || exceedsNodeBudget(normalized, 300)) {
        return null;
      }
      mat[row][j] = normalized;
    }
    for (var r = 0; r < nRows; r++) {
      if (r == row) continue;
      if (isIntegrationBudgetExhausted()) return null;
      final factor = mat[r][col];
      if (_isPolyCoeffZero(factor, assumptions)) continue;
      for (var j = col; j <= nCols; j++) {
        final updated = _safeCancel(
          mat[r][j] - factor * mat[row][j],
          assumptions,
        );
        if (updated == null || exceedsNodeBudget(updated, 300)) return null;
        mat[r][j] = updated;
      }
    }
    pivotCols[row] = col;
    row++;
  }

  for (var r = row; r < nRows; r++) {
    if (!_isPolyCoeffZero(mat[r][nCols], assumptions)) return null;
  }

  final sol = List<Expr>.filled(nCols, IntegerNumber.zero);
  for (var r = 0; r < row; r++) {
    final c = pivotCols[r];
    if (c >= 0) {
      sol[c] = mat[r][nCols];
    }
  }
  return sol;
}

// ---------------------------------------------------------------------------
// Kernel substitution & normalization helpers
// ---------------------------------------------------------------------------

bool _hasExpOrLn(Expr expr, String variable) => expr.anyNode(
  (n) =>
      (n is Call && n.id == FunctionId.ln && n.args[0].dependsOn(variable)) ||
      (n is Pow && n.base == Constant.e && n.exponent.dependsOn(variable)),
);

bool _hasVariableBaseAndExponent(Expr expr, String variable) => expr.anyNode(
  (n) =>
      n is Pow &&
      n.base != Constant.e &&
      n.base.dependsOn(variable) &&
      n.exponent.dependsOn(variable),
);

Expr? _tryIntegrateSelfPower(
  Expr node,
  String variable, {
  required Assumptions assumptions,
  required int depth,
}) {
  final factors = node is Mul ? node.factors : [node];
  final extraCoeff = <Expr>[];
  var gTotal = IntegerNumber.zero as Expr;
  var found = false;
  for (final f in factors) {
    if (f case Pow(:final base, :final exponent)
        when base != Constant.e &&
            base.dependsOn(variable) &&
            exponent.dependsOn(variable)) {
      found = true;
      final prod = (exponent * Fn.ln(base)).expand().simplify(
        assumptions: assumptions,
      );
      final terms = prod is Add ? prod.terms : [prod];
      for (final t in terms) {
        final expT = Pow.of(Constant.e, t).simplify(assumptions: assumptions);
        final keepsVarExp =
            (expT is Pow &&
                expT.base == Constant.e &&
                expT.exponent.dependsOn(variable)) ||
            expT.anyNode(
              (n) =>
                  n is Pow &&
                  n.base.dependsOn(variable) &&
                  n.exponent.dependsOn(variable),
            );
        if (!keepsVarExp) {
          extraCoeff.add(expT);
        } else {
          gTotal = (gTotal + t).simplify(assumptions: assumptions);
        }
      }
    } else {
      extraCoeff.add(f);
    }
  }
  if (!found || gTotal is Number && gTotal.isZero) return null;
  final coeff = extraCoeff.isEmpty
      ? IntegerNumber.one
      : (extraCoeff.length == 1
            ? extraCoeff.first
            : Mul.of(extraCoeff).simplify(assumptions: assumptions));
  if (tryExpRischOde(coeff, gTotal, variable, assumptions: assumptions)
      case final odeRes?) {
    return odeRes;
  }
  // Fallback when gTotal's derivative yields direct u-sub: e.g. u^v * (v' ln u + v u'/u).
  final gPrime = gTotal
      .derivative(variable, assumptions: assumptions)
      .simplify(assumptions: assumptions);
  if (_tryNonRationalOdeCandidate(coeff, gPrime, variable, assumptions)
      case final h?) {
    return (h * Pow.of(Constant.e, gTotal)).simplify(assumptions: assumptions);
  }
  return null;
}

({Expr? primBase, int scale}) _splitExpExponent(
  Expr exponent,
  String variable,
) {
  final varTerms = <Expr>[];
  final terms = exponent is Add ? exponent.terms : [exponent];
  for (final t in terms) {
    if (t.dependsOn(variable)) {
      varTerms.add(t);
    }
  }
  if (varTerms.isEmpty) return (primBase: null, scale: 1);
  final varPart = varTerms.length == 1
      ? varTerms.first
      : Add.of(varTerms).simplify();
  if (varPart case Mul(:final factors)) {
    final intCoeff = factors.whereType<IntegerNumber>().fold<int>(
      1,
      (acc, n) => acc * (n.asInt ?? 1),
    );
    if (intCoeff != 1 && intCoeff != 0 && intCoeff.abs() <= 64) {
      final rest = [
        for (final f in factors)
          if (f is! IntegerNumber) f,
      ];
      final prim = (rest.length == 1 ? rest.first : Mul.of(rest)).simplify();
      return (primBase: prim, scale: intCoeff);
    }
  }
  return (primBase: varPart, scale: 1);
}

bool _dependsModuloConstantShift(
  Expr exponent,
  Expr primBase,
  String variable,
) {
  final s = _splitExpExponent(exponent, variable);
  return s.primBase == primBase;
}

Expr? _substituteExpKernel(
  Expr node,
  Expr genArg,
  Variable tVar,
  String variable,
  Assumptions assumptions,
) {
  if (isIntegrationBudgetExhausted()) return null;
  final genSplit = _splitExpExponent(genArg, variable);
  var aborted = false;

  Expr replace(Expr e) {
    if (aborted || isIntegrationBudgetExhausted()) {
      aborted = true;
      return e;
    }
    if (e case Pow(:final base, :final exponent)
        when base == Constant.e && exponent.dependsOn(variable)) {
      if (exponent == genArg) return tVar;
      // Fast structural check before resorting to algebraic cancellation.
      final eSplit = _splitExpExponent(exponent, variable);
      if (eSplit.primBase == genSplit.primBase && genSplit.scale != 0) {
        if (eSplit.scale % genSplit.scale == 0) {
          final k = eSplit.scale ~/ genSplit.scale;
          if (k.abs() > 12) {
            aborted = true;
            return e;
          }
          final diff = (exponent - IntegerNumber.of(k) * genArg).simplify(
            assumptions: assumptions,
          );
          if (!diff.dependsOn(variable)) {
            final tPow = k == 1 ? tVar : Pow.of(tVar, IntegerNumber.of(k));
            return (diff is Number && diff.isZero)
                ? tPow
                : Pow.of(Constant.e, diff) * tPow;
          }
        }
      }
      if (exponent.freeVariables.length <= genArg.freeVariables.length + 2) {
        final diff = (exponent - genArg).simplify(assumptions: assumptions);
        if (!diff.dependsOn(variable)) {
          return Pow.of(Constant.e, diff) * tVar;
        }
      }
      return Pow.of(base, replace(exponent));
    }
    return e.mapChildren(replace);
  }

  final out = replace(node);
  if (aborted || isIntegrationBudgetExhausted()) return null;
  return out.simplify(assumptions: assumptions);
}

Expr? _substituteLnKernel(
  Expr node,
  Expr uExpr,
  Variable tVar,
  Assumptions assumptions,
) {
  Expr replace(Expr e) {
    if (e case Call(id: FunctionId.ln, args: [final expr]) when expr == uExpr) {
      return tVar;
    }
    return e.mapChildren(replace);
  }

  return replace(node).simplify(assumptions: assumptions);
}

int _intGcd(int a, int b) {
  var x = a.abs();
  var y = b.abs();
  while (y != 0) {
    final t = x % y;
    x = y;
    y = t;
  }
  return x == 0 ? 1 : x;
}

// ---------------------------------------------------------------------------
// Univariate polynomial arithmetic over K(x)[t]
// ---------------------------------------------------------------------------

Expr? _safeCancel(Expr e, Assumptions assumptions) {
  if (e is Number) {
    return _exceedsBitBudget(e, 128) ? null : e;
  }
  if (consumeIntegrationWork() ||
      exceedsNodeBudget(e, 500) ||
      _exceedsBitBudget(e, 128)) {
    return null;
  }
  final vars = e.freeVariables;
  var target = e;
  if (vars.length <= 1) {
    final combined = e.together(assumptions: assumptions);
    if (exceedsNodeBudget(combined, 600) || _exceedsBitBudget(combined, 128)) {
      return null;
    }
    final (rawNum, rawDen) = splitNumeratorDenominator(combined);
    if (rawDen == IntegerNumber.one) {
      return (exceedsNodeBudget(rawNum, 350) || _exceedsBitBudget(rawNum, 128))
          ? null
          : rawNum.simplify(assumptions: assumptions);
    }
    if (vars.length == 1) {
      final v = vars.first;
      final pNum = exprToPolyQ(rawNum, v);
      final pDen = exprToPolyQ(rawDen, v);
      if (pNum != null && pDen != null && !pDen.isZero) {
        if (pNum.degree > 16 || pDen.degree > 16) return null;
        final (scale: nScale, primitive: nPrim) = pNum.clearDenominators();
        final (scale: dScale, primitive: dPrim) = pDen.clearDenominators();
        if (_polyZExceedsBitBudget(nPrim, 128) ||
            _polyZExceedsBitBudget(dPrim, 128)) {
          return null;
        }
        final g = nPrim.gcd(dPrim);
        final remNum = nPrim.exactDivide(g) ?? nPrim;
        final remDen = dPrim.exactDivide(g) ?? dPrim;
        final totalScale = nScale.divRational(dScale);
        final numExpr = totalScale.numerator == BigInt.one
            ? polyZToExpr(remNum, v)
            : IntegerNumber(totalScale.numerator) * polyZToExpr(remNum, v);
        final denExpr = totalScale.denominator == BigInt.one
            ? polyZToExpr(remDen, v)
            : IntegerNumber(totalScale.denominator) * polyZToExpr(remDen, v);
        final res = (numExpr / denExpr).simplify(assumptions: assumptions);
        return (exceedsNodeBudget(res, 350) || _exceedsBitBudget(res, 128))
            ? null
            : res;
      }
    }
    target = combined;
  }
  if (consumeIntegrationWork(4) || exceedsNodeBudget(target, 350)) {
    return null;
  }
  final c = target.cancel(assumptions: assumptions);
  if (isIntegrationBudgetExhausted() ||
      exceedsNodeBudget(c, 350) ||
      _exceedsBitBudget(c, 128)) {
    return null;
  }
  return c;
}

bool _exceedsBitBudget(Expr expr, int maxBits) => expr.anyNode(
  (n) => switch (n) {
    RationalNumber(:final numerator, :final denominator) =>
      numerator.bitLength > maxBits || denominator.bitLength > maxBits,
    ComplexNumber(real: RationalNumber(:final numerator, :final denominator))
        when numerator.bitLength > maxBits || denominator.bitLength > maxBits =>
      true,
    ComplexNumber(
      imaginary: RationalNumber(:final numerator, :final denominator),
    )
        when numerator.bitLength > maxBits || denominator.bitLength > maxBits =>
      true,
    _ => false,
  },
);

bool _polyZExceedsBitBudget(PolyZ poly, int maxBits) {
  for (final c in poly.coeffs) {
    if (c.bitLength > maxBits) return true;
  }
  return false;
}

bool _hasHighVariableExponent(Expr expr, String variable, int limit) =>
    expr.anyNode(
      (n) =>
          n is Pow &&
          n.base.dependsOn(variable) &&
          n.exponent is IntegerNumber &&
          (n.exponent as IntegerNumber).value.abs() > BigInt.from(limit),
    );

bool _isPolyCoeffZero(Expr expr, Assumptions assumptions) {
  if (expr is Number) return expr.isZero;
  final s = expr.simplify(assumptions: assumptions);
  if (s is Number && s.isZero) return true;
  if (!s.anyNode((n) => n is Add || n is Pow || n is Mul)) return false;
  return s.expand().simplify(assumptions: assumptions) == IntegerNumber.zero;
}

int _polyDeg(_Poly p) {
  var maxDeg = -1;
  for (final k in p.keys) {
    if (k > maxDeg) maxDeg = k;
  }
  return maxDeg;
}

_Poly _polyTrim(_Poly p, Assumptions assumptions) => <int, Expr>{
  for (final MapEntry(key: k, value: v) in p.entries)
    if (!_isPolyCoeffZero(v, assumptions)) k: v,
};

_Poly? _polyCancelTrim(_Poly p, Assumptions assumptions) {
  final res = <int, Expr>{};
  for (final MapEntry(key: k, value: v) in p.entries) {
    final c = _safeCancel(v, assumptions);
    if (c == null) return null;
    if (!_isPolyCoeffZero(c, assumptions)) {
      res[k] = c;
    }
  }
  return res;
}

_Poly? _polyAdd(_Poly a, _Poly b, Assumptions assumptions) {
  final res = Map<int, Expr>.from(a);
  for (final MapEntry(key: k, value: v) in b.entries) {
    final sum = _safeCancel((res[k] ?? IntegerNumber.zero) + v, assumptions);
    if (sum == null) return null;
    if (_isPolyCoeffZero(sum, assumptions)) {
      res.remove(k);
    } else {
      res[k] = sum;
    }
  }
  return res;
}

_Poly? _polySub(_Poly a, _Poly b, Assumptions assumptions) {
  final res = Map<int, Expr>.from(a);
  for (final MapEntry(key: k, value: v) in b.entries) {
    final diff = _safeCancel((res[k] ?? IntegerNumber.zero) - v, assumptions);
    if (diff == null) return null;
    if (_isPolyCoeffZero(diff, assumptions)) {
      res.remove(k);
    } else {
      res[k] = diff;
    }
  }
  return res;
}

_Poly? _polyScale(_Poly a, Expr s, Assumptions assumptions) {
  if (_isPolyCoeffZero(s, assumptions)) return const {};
  final res = <int, Expr>{};
  for (final MapEntry(key: k, value: v) in a.entries) {
    final prod = _safeCancel(v * s, assumptions);
    if (prod == null) return null;
    if (!_isPolyCoeffZero(prod, assumptions)) {
      res[k] = prod;
    }
  }
  return res;
}

_Poly? _polyMul(_Poly a, _Poly b, Assumptions assumptions) {
  if (a.isEmpty || b.isEmpty) return const {};
  if (isIntegrationBudgetExhausted()) return null;
  final raw = <int, Expr>{};
  for (final MapEntry(key: da, value: va) in a.entries) {
    for (final MapEntry(key: db, value: vb) in b.entries) {
      final k = da + db;
      raw[k] = (raw[k] ?? IntegerNumber.zero) + va * vb;
    }
  }
  return _polyCancelTrim(raw, assumptions);
}

_Poly? _polyPow(_Poly a, int exp, Assumptions assumptions) {
  if (exp == 0) return {0: IntegerNumber.one};
  var res = <int, Expr>{0: IntegerNumber.one};
  var cur = a;
  var e = exp;
  while (e > 0) {
    if (isIntegrationBudgetExhausted()) return null;
    if (e.isOdd) {
      final nextRes = _polyMul(res, cur, assumptions);
      if (nextRes == null) return null;
      res = nextRes;
    }
    e >>= 1;
    if (e > 0) {
      final nextCur = _polyMul(cur, cur, assumptions);
      if (nextCur == null) return null;
      cur = nextCur;
    }
  }
  return res;
}

_Poly? _polyPartialDeriv(_Poly a, Assumptions assumptions) {
  final res = <int, Expr>{};
  for (final MapEntry(key: k, value: v) in a.entries) {
    if (k > 0) {
      final coeff = _safeCancel(IntegerNumber.of(k) * v, assumptions);
      if (coeff == null) return null;
      if (!_isPolyCoeffZero(coeff, assumptions)) {
        res[k - 1] = coeff;
      }
    }
  }
  return res;
}

({_Poly q, _Poly r})? _polyDivRem(_Poly a, _Poly b, Assumptions assumptions) {
  final db = _polyDeg(b);
  if (db < 0) {
    throw ArgumentError('Polynomial division by zero.');
  }
  final lcB = b[db]!;
  final rem = Map<int, Expr>.from(a);
  final quot = <int, Expr>{};
  var dr = _polyDeg(rem);
  while (dr >= db) {
    if (isIntegrationBudgetExhausted()) return null;
    final shift = dr - db;
    final coeff = _safeCancel(rem[dr]! / lcB, assumptions);
    if (coeff == null) return null;
    if (!_isPolyCoeffZero(coeff, assumptions)) {
      quot[shift] = coeff;
      for (final MapEntry(key: k, value: bv) in b.entries) {
        if (isIntegrationBudgetExhausted()) return null;
        final target = k + shift;
        final updated = _safeCancel(
          (rem[target] ?? IntegerNumber.zero) - coeff * bv,
          assumptions,
        );
        if (updated == null) return null;
        if (_isPolyCoeffZero(updated, assumptions)) {
          rem.remove(target);
        } else {
          rem[target] = updated;
        }
      }
    }
    rem.remove(dr);
    dr = _polyDeg(rem);
  }
  return (q: _polyTrim(quot, assumptions), r: _polyTrim(rem, assumptions));
}

_Poly? _polyGcd(_Poly a, _Poly b, Assumptions assumptions) {
  var x = a;
  var y = b;
  var steps = 0;
  while (_polyDeg(y) >= 0) {
    if (isIntegrationBudgetExhausted() || steps++ > 30) return null;
    final div = _polyDivRem(x, y, assumptions);
    if (div == null) return null;
    final r = div.r;
    for (final v in r.values) {
      if (exceedsNodeBudget(v, 300)) return null;
    }
    x = y;
    y = r;
  }
  final dx = _polyDeg(x);
  if (dx < 0) return const {};
  return _polyScale(x, IntegerNumber.one / x[dx]!, assumptions);
}

({_Poly s, _Poly t, _Poly g})? _polyExtGcd(
  _Poly a,
  _Poly b,
  Assumptions assumptions,
) {
  var oldR = a;
  var r = b;
  var oldS = <int, Expr>{0: IntegerNumber.one};
  var s = const <int, Expr>{};
  var oldT = const <int, Expr>{};
  var t = <int, Expr>{0: IntegerNumber.one};
  var steps = 0;
  while (_polyDeg(r) >= 0) {
    if (isIntegrationBudgetExhausted() || steps++ > 30) return null;
    final div = _polyDivRem(oldR, r, assumptions);
    if (div == null) return null;
    final nextR = div.r;
    final qs = _polyMul(div.q, s, assumptions);
    final qt = _polyMul(div.q, t, assumptions);
    if (qs == null || qt == null) return null;
    final nextS = _polySub(oldS, qs, assumptions);
    final nextT = _polySub(oldT, qt, assumptions);
    if (nextS == null || nextT == null) return null;
    for (final v in nextR.values) {
      if (exceedsNodeBudget(v, 300)) return null;
    }
    oldR = r;
    r = nextR;
    oldS = s;
    s = nextS;
    oldT = t;
    t = nextT;
  }
  final d = _polyDeg(oldR);
  if (d < 0) return null;
  final invLc = _safeCancel(IntegerNumber.one / oldR[d]!, assumptions);
  if (invLc == null) return null;
  final resS = _polyScale(oldS, invLc, assumptions);
  final resT = _polyScale(oldT, invLc, assumptions);
  final resG = _polyScale(oldR, invLc, assumptions);
  if (resS == null || resT == null || resG == null) return null;
  return (s: resS, t: resT, g: resG);
}

List<({int mult, _Poly factor})>? _squareFreeFactors(
  _Poly poly,
  Assumptions assumptions,
) {
  final deg = _polyDeg(poly);
  if (deg <= 0) return const [];
  final deriv = _polyPartialDeriv(poly, assumptions);
  if (deriv == null) return null;
  final g = _polyGcd(poly, deriv, assumptions);
  if (g == null) return null;
  if (_polyDeg(g) <= 0) {
    return [(mult: 1, factor: poly)];
  }
  final result = <({int mult, _Poly factor})>[];
  final wDiv = _polyDivRem(poly, g, assumptions);
  if (wDiv == null) return null;
  var w = wDiv.q;
  var y = g;
  var i = 1;
  while (_polyDeg(w) > 0 || _polyDeg(y) > 0) {
    if (isIntegrationBudgetExhausted()) return null;
    final z = _polyGcd(w, y, assumptions);
    if (z == null) return null;
    final _Poly ai;
    if (_polyDeg(z) >= 1) {
      final aiDiv = _polyDivRem(w, z, assumptions);
      if (aiDiv == null) return null;
      ai = aiDiv.q;
    } else {
      ai = w;
    }
    if (_polyDeg(ai) >= 1) {
      result.add((mult: i, factor: ai));
    }
    w = z;
    if (_polyDeg(z) >= 1) {
      final yDiv = _polyDivRem(y, z, assumptions);
      if (yDiv == null) return null;
      y = yDiv.q;
    } else {
      y = const {};
    }
    i++;
    if (i > 12) return null;
  }
  return result;
}

Expr _polyEval(_Poly poly, Expr kernelExpr, Assumptions assumptions) {
  if (poly.isEmpty) return IntegerNumber.zero;
  final terms = <Expr>[
    for (final MapEntry(key: k, value: c) in poly.entries)
      if (k == 0)
        c
      else if (k == 1)
        c * kernelExpr
      else
        c * Pow.of(kernelExpr, IntegerNumber.of(k)),
  ];
  return Add.of(terms).simplify(assumptions: assumptions);
}
