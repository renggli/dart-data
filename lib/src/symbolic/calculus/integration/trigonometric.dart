import '../../algebra/expand.dart';
import '../../algebra/helpers.dart';
import '../../algebra/rational.dart';
import '../../algebra/simplify.dart';
import '../../algebra/trig.dart';
import '../../assumptions.dart';
import '../../ast.dart';
import '../../functions/fn.dart';
import '../../oracle/zero_equivalence.dart';
import '../linear_form.dart';
import 'definite.dart';
import 'integration.dart';
import 'trigonometric_helpers.dart';

/// Expands powered trigonometric or hyperbolic binomials `(a + b*sin(u))^m`
/// multiplied by other trig/hyperbolic powers and integrates term-by-term.
Expr? tryExpandTrigBinomialProduct(
  List<Expr> varFactors,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  if (depth >= 2 || varFactors.length < 2) return null;

  bool isLinearTrigOrHyp(Expr node) => switch (node) {
    Call(
      id: FunctionId.sin ||
          FunctionId.cos ||
          FunctionId.tan ||
          FunctionId.sinh ||
          FunctionId.cosh ||
          FunctionId.tanh,
      args: [final expr],
    ) =>
      expr.matchLinear(variable) != null,
    _ => false,
  };

  bool isTrigOrHypPower(Expr node) => switch (node) {
    Pow(:final base, exponent: IntegerNumber()) => isLinearTrigOrHyp(base),
    _ => isLinearTrigOrHyp(node),
  };

  var binomIdx = -1;
  for (var i = 0; i < varFactors.length; i++) {
    if (varFactors[i]
        case Pow(
          base: final Add addBase,
          exponent: IntegerNumber(asInt: final m?),
        )
        when m >= 2 && m <= 8 && addBase.terms.length <= 3) {
      if (addBase.anyNode(isLinearTrigOrHyp)) {
        binomIdx = i;
        break;
      }
    }
  }
  if (binomIdx < 0) return null;

  for (var i = 0; i < varFactors.length; i++) {
    if (i != binomIdx && !isTrigOrHypPower(varFactors[i])) return null;
  }

  final expandedBinom = varFactors[binomIdx]
      .expand(assumptions: assumptions)
      .simplify(assumptions: assumptions);
  var scaleFactor = IntegerNumber.one as Expr;
  Add? expandedAdd;
  if (expandedBinom is Add) {
    expandedAdd = expandedBinom;
  } else if (expandedBinom is Mul) {
    final rest = <Expr>[];
    for (final f in expandedBinom.factors) {
      if (f is Add && expandedAdd == null) {
        expandedAdd = f;
      } else {
        rest.add(f);
      }
    }
    if (rest.isNotEmpty) {
      scaleFactor = Mul.of(rest).simplify(assumptions: assumptions);
    }
  }
  if (expandedAdd == null) return null;

  final otherFactors = <Expr>[
    for (var i = 0; i < varFactors.length; i++)
      if (i != binomIdx) varFactors[i],
  ];
  final otherExpr = otherFactors.length == 1
      ? otherFactors.first
      : Mul.of(otherFactors).simplify(assumptions: assumptions);

  final results = <Expr>[];
  for (final term in expandedAdd.terms) {
    final prod = (scaleFactor * term * otherExpr).simplify(
      assumptions: assumptions,
    );
    final res = antiDerivative(
      prod,
      variable,
      depth: depth + 1,
      assumptions: assumptions,
    );
    if (hasUnevaluatedIntegral(res, variable)) return null;
    results.add(res);
  }
  return Add.of(results).simplify(assumptions: assumptions);
}

/// Rewrites trig sum/difference pairs such as `sin(A + B) - sin(A - B)` in an
/// `Add` node into product-to-sum form and integrates the result.
Expr? tryRewriteTrigSumToProductAdd(
  List<Expr> terms,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  if (depth >= 2 || terms.length < 2 || terms.length > 6) return null;
  for (var i = 0; i < terms.length; i++) {
    for (var j = i + 1; j < terms.length; j++) {
      final rewritten = _pairTrigSumToProduct(terms[i], terms[j], variable);
      if (rewritten == null) continue;
      final rest = <Expr>[
        for (var k = 0; k < terms.length; k++)
          if (k != i && k != j) terms[k],
      ];
      final combined = (rest.isEmpty ? rewritten : Add.of([rewritten, ...rest]))
          .simplify(assumptions: assumptions);
      final res = antiDerivative(
        combined,
        variable,
        assumptions: assumptions,
        depth: depth + 1,
      );
      if (!hasUnevaluatedIntegral(res, variable)) return res;
    }
  }
  return null;
}

Expr? _pairTrigSumToProduct(Expr t1, Expr t2, String variable) {
  ({Expr coeff, FunctionId id, Expr arg})? unpack(Expr e) {
    if (e case Call(id: final id, args: [final arg])
        when (id == FunctionId.sin || id == FunctionId.cos) &&
            arg.dependsOn(variable)) {
      return (coeff: IntegerNumber.one, id: id, arg: arg);
    }
    if (e case Mul(:final factors)) {
      final (:constFactors, :varFactors) = partitionFactors(factors, variable);
      if (varFactors.length == 1 && varFactors.first is Call) {
        final call = varFactors.first as Call;
        if ((call.id == FunctionId.sin || call.id == FunctionId.cos) &&
            call.args[0].dependsOn(variable)) {
          final coeff = constFactors.isEmpty
              ? IntegerNumber.one
              : Mul.of(constFactors).simplify();
          return (coeff: coeff, id: call.id, arg: call.args[0]);
        }
      }
    }
    return null;
  }

  final u = unpack(t1);
  final v = unpack(t2);
  if (u == null || v == null || u.id != v.id) return null;
  final halfSum = ((u.arg + v.arg) / IntegerNumber.two).simplify();
  final halfDiff = ((u.arg - v.arg) / IntegerNumber.two).simplify();
  if (halfSum == u.arg || halfDiff == u.arg) return null;
  final same = (u.coeff - v.coeff).simplify();
  final opp = (u.coeff + v.coeff).simplify();
  if (opp is Number && opp.isZero) {
    if (u.id == FunctionId.sin) {
      return (IntegerNumber.two * u.coeff * Fn.cos(halfSum) * Fn.sin(halfDiff))
          .simplify();
    }
    return (-IntegerNumber.two * u.coeff * Fn.sin(halfSum) * Fn.sin(halfDiff))
        .simplify();
  }
  if (same is Number && same.isZero) {
    if (u.id == FunctionId.sin) {
      return (IntegerNumber.two * u.coeff * Fn.sin(halfSum) * Fn.cos(halfDiff))
          .simplify();
    }
    return (IntegerNumber.two * u.coeff * Fn.cos(halfSum) * Fn.cos(halfDiff))
        .simplify();
  }
  return null;
}

Expr? _trySumDiffSinCos2xSubstitution(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  if (depth >= 2 || isIntegrationBudgetExhausted()) return null;
  final factors = expr is Mul ? expr.factors : [expr];
  for (var i = 0; i < factors.length; i++) {
    final f = factors[i];
    if (f is! Add || f.terms.length != 2) continue;
    final sinCosMatch = _matchSinCosDiffOrSum(f, variable);
    if (sinCosMatch == null) continue;
    final (:u, :k, :isCosMinusSin, :scale) = sinCosMatch;
    final rest = <Expr>[
      for (var j = 0; j < factors.length; j++)
        if (j != i) factors[j],
    ];
    final restExpr = rest.isEmpty ? IntegerNumber.one : Mul.of(rest);
    final twoU = (IntegerNumber.two * u).simplify();
    final tName = freshIntegrationVar('_sc', expr, variable, depth);
    final tVar = Variable(tName);
    final sin2uExpr = isCosMinusSin
        ? tVar * tVar - IntegerNumber.one
        : IntegerNumber.one - tVar * tVar;
    final rewrittenRest = _replaceSin2u(
      restExpr,
      twoU,
      sin2uExpr,
    ).simplify(assumptions: assumptions);
    if (rewrittenRest.dependsOn(variable)) continue;
    final integrand = (scale * rewrittenRest / k).simplify(
      assumptions: assumptions,
    );
    final tInt = antiDerivative(
      integrand,
      tName,
      assumptions: assumptions,
      depth: depth + 1,
    );
    if (!hasUnevaluatedIntegral(tInt, tName)) {
      final back = isCosMinusSin
          ? Fn.sin(u) + Fn.cos(u)
          : Fn.sin(u) - Fn.cos(u);
      return tInt.substitute(tName, back).simplify(assumptions: assumptions);
    }
  }
  return null;
}

({Expr u, Expr k, bool isCosMinusSin, Expr scale})? _matchSinCosDiffOrSum(
  Add add,
  String variable,
) {
  Expr? u;
  Expr cosCoeff = IntegerNumber.zero;
  Expr sinCoeff = IntegerNumber.zero;
  for (final term in add.terms) {
    final parts = term is Mul ? term.factors : [term];
    final (:constFactors, :varFactors) = partitionFactors(parts, variable);
    if (varFactors.length != 1 || varFactors.first is! Call) return null;
    final call = varFactors.first as Call;
    if (call.id != FunctionId.cos && call.id != FunctionId.sin) return null;
    final arg = call.args[0];
    if (arg.matchLinear(variable) == null) return null;
    if (u == null) {
      u = arg;
    } else if (u != arg) {
      return null;
    }
    final c = constFactors.isEmpty
        ? IntegerNumber.one
        : Mul.of(constFactors).simplify();
    if (call.id == FunctionId.cos) {
      cosCoeff = (cosCoeff + c).simplify();
    } else {
      sinCoeff = (sinCoeff + c).simplify();
    }
  }
  if (u == null) return null;
  final k = u.matchLinear(variable)!.a;
  if (isZeroExpr((cosCoeff + sinCoeff).simplify())) {
    return (u: u, k: k, isCosMinusSin: true, scale: cosCoeff);
  }
  if (isZeroExpr((cosCoeff - sinCoeff).simplify())) {
    return (u: u, k: k, isCosMinusSin: false, scale: cosCoeff);
  }
  return null;
}

Expr _replaceSin2u(Expr expr, Expr twoU, Expr replacement) {
  if (expr is Call &&
      expr.id == FunctionId.sin &&
      expr.args.length == 1 &&
      isZeroExpr((expr.args[0] - twoU).simplify())) {
    return replacement;
  }
  return expr.mapChildren((child) => _replaceSin2u(child, twoU, replacement));
}

/// Integrates Chebyshev-like products `sin/cos((n+2)*u) * sin/cos(u)^n`.
Expr? tryShiftAngleTrigPowerDerivative(
  List<Expr> varFactors,
  String variable, {
  Assumptions assumptions = Assumptions.none,
}) {
  if (varFactors.length != 2) return null;
  Expr? res;
  res =
      _matchShiftAnglePair(
        varFactors[0],
        varFactors[1],
        variable,
        assumptions,
      ) ??
      _matchShiftAnglePair(varFactors[1], varFactors[0], variable, assumptions);
  return res;
}

Expr? _matchShiftAnglePair(
  Expr singleTrig,
  Expr powTrig,
  String variable,
  Assumptions assumptions,
) {
  if (singleTrig is! Call ||
      (singleTrig.id != FunctionId.sin && singleTrig.id != FunctionId.cos)) {
    return null;
  }
  if (powTrig is! Pow || powTrig.base is! Call) return null;
  final baseCall = powTrig.base as Call;
  if (baseCall.id != FunctionId.sin && baseCall.id != FunctionId.cos) {
    return null;
  }
  final n = powTrig.exponent;
  if (n.dependsOn(variable)) return null;
  final u = baseCall.args[0];
  final uLin = u.matchLinear(variable);
  if (uLin == null) return null;
  final nPlus1 = (n + IntegerNumber.one).simplify(assumptions: assumptions);
  if (nPlus1 is Number && nPlus1.isZero) return null;
  final nPlus2 = (n + IntegerNumber.two).simplify(assumptions: assumptions);
  final expectedAngle = (nPlus2 * u).simplify(assumptions: assumptions);
  if ((singleTrig.args[0] - expectedAngle).simplify(assumptions: assumptions)
          is! Number ||
      !((singleTrig.args[0] - expectedAngle).simplify(
        assumptions: assumptions,
      ) as Number).isZero) {
    return null;
  }
  final shiftAngle = (nPlus1 * u).simplify(assumptions: assumptions);
  final nextPow = Pow.of(baseCall, nPlus1);
  final denom = (nPlus1 * uLin.a).simplify(assumptions: assumptions);
  final numer = switch ((singleTrig.id, baseCall.id)) {
    (FunctionId.sin, FunctionId.sin) => Fn.sin(shiftAngle) * nextPow,
    (FunctionId.cos, FunctionId.sin) => Fn.cos(shiftAngle) * nextPow,
    (FunctionId.cos, FunctionId.cos) => Fn.sin(shiftAngle) * nextPow,
    (FunctionId.sin, FunctionId.cos) => -Fn.cos(shiftAngle) * nextPow,
    _ => null,
  };
  return numer == null
      ? null
      : (numer / denom).simplify(assumptions: assumptions);
}

/// Integrates products of two sines or cosines via product-to-sum identities.
Expr? tryTrigProduct(Expr left, Expr right, String variable) {
  if (left case Call(id: FunctionId.sin, args: [final a])
      when a.matchLinear(variable) != null) {
    if (right case Call(id: FunctionId.cos, args: [final b])
        when b.matchLinear(variable) != null) {
      final sum = (a + b).simplify();
      final diff = (a - b).simplify();
      final expanded = ((Fn.sin(sum) + Fn.sin(diff)) / IntegerNumber.two)
          .simplify();
      return antiDerivative(expanded, variable, assumptions: Assumptions.none);
    }
    if (right case Call(id: FunctionId.sin, args: [final b])
        when b.matchLinear(variable) != null) {
      final diff = (a - b).simplify();
      final sum = (a + b).simplify();
      final expanded = ((Fn.cos(diff) - Fn.cos(sum)) / IntegerNumber.two)
          .simplify();
      return antiDerivative(expanded, variable, assumptions: Assumptions.none);
    }
  }
  if (left case Call(id: FunctionId.cos, args: [final a])
      when a.matchLinear(variable) != null) {
    if (right case Call(id: FunctionId.sin)) {
      return tryTrigProduct(right, left, variable);
    }
    if (right case Call(id: FunctionId.cos, args: [final b])
        when b.matchLinear(variable) != null) {
      final diff = (a - b).simplify();
      final sum = (a + b).simplify();
      final expanded = ((Fn.cos(diff) + Fn.cos(sum)) / IntegerNumber.two)
          .simplify();
      return antiDerivative(expanded, variable, assumptions: Assumptions.none);
    }
  }
  return null;
}

/// Integrates `c / (a + b*sin(u) + c*cos(u))` via Weierstrass half-angle substitution.
Expr? tryWeierstrassSubstitution(Expr left, Expr right, String variable) {
  final m = extractLinearTrigCombo(right, variable);
  if (m == null) return null;
  final inner = m.inner!;
  final k = inner.matchLinear(variable)!.a;

  const tName = '_wt';
  const tVar = Variable(tName);
  final denom =
      ((m.cConst - m.bCos) * tVar * tVar +
              IntegerNumber.two * m.aSin * tVar +
              (m.cConst + m.bCos))
          .simplify();
  if (denom is Number && denom.isZero) return null;

  final integrandT = ((IntegerNumber.two * left) / (k * denom)).simplify();
  final tAntideriv = antiDerivative(
    integrandT,
    tName,
    depth: 2,
    assumptions: Assumptions.none,
  );
  if (hasUnevaluatedIntegral(tAntideriv, tName)) return null;

  return tAntideriv
      .substitute(tName, Fn.tan((inner / IntegerNumber.two).simplify()))
      .simplify();
}

/// Integrates products and quotients of integer powers `sin(u)^p * cos(u)^q`.
Expr? tryTrigPowerProduct(Expr num, Expr den, String variable) {
  final numInfo = _extractTrigPowers(num, variable);
  final denInfo = _extractTrigPowers(den, variable);
  if (numInfo == null || denInfo == null) return null;

  final inner = numInfo.inner ?? denInfo.inner;
  if (inner == null) return null;
  if (numInfo.inner != null &&
      denInfo.inner != null &&
      numInfo.inner != denInfo.inner) {
    return null;
  }
  final linear = inner.matchLinear(variable);
  if (linear == null) return null;
  final a = linear.a;

  final p = numInfo.sinExp - denInfo.sinExp;
  final q = numInfo.cosExp - denInfo.cosExp;
  if (p == 0 && q == 0) return null;
  if (p.abs() > 10 || q.abs() > 10) return null;
  final scale = (numInfo.scale / denInfo.scale).simplify();

  if (q < 0 && p == -q && p >= 2) {
    final res = antiDerivative(
      Pow.of(Fn.tan(inner), IntegerNumber.of(p)),
      variable,
      assumptions: Assumptions.none,
    );
    return hasUnevaluatedIntegral(res, variable) ? null : res.scale(scale);
  }
  if (p < 0 && q == -p && q >= 2) {
    return integrateCotPower(q, inner, a, variable).scale(scale);
  }

  final tName = freshIntegrationVar('_wt', num / den, variable, 0);
  final tVar = Variable(tName);

  if (p.isOdd && p >= -9 && p <= 9) {
    final k = (p - 1) ~/ 2;
    final cosPow = k == 0
        ? IntegerNumber.one
        : Pow.of(IntegerNumber.one - tVar * tVar, IntegerNumber.of(k));
    final rawIntegrand =
        (-scale / a) * cosPow * Pow.of(tVar, IntegerNumber.of(q));
    final integrand = k >= 0
        ? rawIntegrand.expand().simplify()
        : rawIntegrand.simplify();
    final tInt = antiDerivative(
      integrand,
      tName,
      depth: 1,
      assumptions: Assumptions.none,
    );
    if (!hasUnevaluatedIntegral(tInt, tName)) {
      return tInt.substitute(tName, Fn.cos(inner)).simplify();
    }
  }

  if (q.isOdd && q >= -9 && q <= 9) {
    final k = (q - 1) ~/ 2;
    final sinPow = k == 0
        ? IntegerNumber.one
        : Pow.of(IntegerNumber.one - tVar * tVar, IntegerNumber.of(k));
    final rawIntegrand =
        (scale / a) * Pow.of(tVar, IntegerNumber.of(p)) * sinPow;
    final integrand = k >= 0
        ? rawIntegrand.expand().simplify()
        : rawIntegrand.simplify();
    final tInt = antiDerivative(
      integrand,
      tName,
      depth: 1,
      assumptions: Assumptions.none,
    );
    if (!hasUnevaluatedIntegral(tInt, tName)) {
      return tInt.substitute(tName, Fn.sin(inner)).simplify();
    }
  }

  if ((p + q).isEven && p + q <= -2) {
    final m = -(p + q) ~/ 2 - 1;
    final integrand =
        ((scale / a) *
                Pow.of(tVar, IntegerNumber.of(p)) *
                Pow.of(IntegerNumber.one + tVar * tVar, IntegerNumber.of(m)))
            .expand()
            .simplify();
    final tInt = antiDerivative(
      integrand,
      tName,
      depth: 1,
      assumptions: Assumptions.none,
    );
    if (!hasUnevaluatedIntegral(tInt, tName)) {
      return tInt.substitute(tName, Fn.tan(inner)).simplify();
    }
  }

  if (p >= 0 && q >= 0 && p.isEven && q.isEven) {
    final twoInner = (IntegerNumber.two * inner).simplify();
    final sin2 = (IntegerNumber.one - Fn.cos(twoInner)) / IntegerNumber.two;
    final cos2 = (IntegerNumber.one + Fn.cos(twoInner)) / IntegerNumber.two;
    final expanded =
        (scale *
                Pow.of(sin2, IntegerNumber.of(p ~/ 2)) *
                Pow.of(cos2, IntegerNumber.of(q ~/ 2)))
            .expand()
            .simplify();
    if (expanded is Add || expanded != (num / den).simplify()) {
      final res = antiDerivative(
        expanded,
        variable,
        depth: 2,
        assumptions: Assumptions.none,
      );
      if (!hasUnevaluatedIntegral(res, variable)) return res;
    }
  }

  // Even positive numerator power times odd negative denominator power:
  // sin(u)^(2k) / cos(u)^m = sum_{j=0}^k C(k,j) * (-1)^j * cos(u)^(2j - m)
  if (p >= 2 && p.isEven && q < 0 && q.isOdd) {
    final k = p ~/ 2;
    final terms = <Expr>[];
    var binom = 1;
    for (var j = 0; j <= k; j++) {
      if (j > 0) binom = (binom * (k - j + 1)) ~/ j;
      final coeff = j.isOdd ? -binom : binom;
      final termInt = antiDerivative(
        (scale *
                IntegerNumber.of(coeff) *
                Pow.of(Fn.cos(inner), IntegerNumber.of(q + 2 * j)))
            .simplify(),
        variable,
        depth: 2,
        assumptions: Assumptions.none,
      );
      if (hasUnevaluatedIntegral(termInt, variable)) {
        terms.clear();
        break;
      }
      terms.add(termInt);
    }
    if (terms.isNotEmpty) return Add.of(terms).simplify();
  }
  if (q >= 2 && q.isEven && p < 0 && p.isOdd) {
    final k = q ~/ 2;
    final terms = <Expr>[];
    var binom = 1;
    for (var j = 0; j <= k; j++) {
      if (j > 0) binom = (binom * (k - j + 1)) ~/ j;
      final coeff = j.isOdd ? -binom : binom;
      final termInt = antiDerivative(
        (scale *
                IntegerNumber.of(coeff) *
                Pow.of(Fn.sin(inner), IntegerNumber.of(p + 2 * j)))
            .simplify(),
        variable,
        depth: 2,
        assumptions: Assumptions.none,
      );
      if (hasUnevaluatedIntegral(termInt, variable)) {
        terms.clear();
        break;
      }
      terms.add(termInt);
    }
    if (terms.isNotEmpty) return Add.of(terms).simplify();
  }

  return null;
}

/// Integrates products of a polynomial with trigonometric powers or products
/// via multiple-angle power reduction.
Expr? tryPolyTrigPowerReduction(List<Expr> varFactors, String variable) {
  for (var i = 0; i < varFactors.length; i++) {
    if (reduceTrigPower(varFactors[i], variable) case final reduced?) {
      final others = <Expr>[
        for (var j = 0; j < varFactors.length; j++)
          if (i != j) varFactors[j],
      ];
      final isReducible = others.every(
        (o) =>
            polynomialDegree(o, variable) != null ||
            (o is Call &&
                (o.id == FunctionId.sin || o.id == FunctionId.cos) &&
                o.args[0].matchLinear(variable) != null) ||
            (o is Pow &&
                !o.base.dependsOn(variable) &&
                o.exponent.matchLinear(variable) != null),
      );
      if (isReducible) {
        final otherExpr = others.length == 1
            ? others.first
            : Mul.of(others).simplify();
        final expanded = (otherExpr * reduced).expand().simplify();
        final res = antiDerivative(
          expanded,
          variable,
          assumptions: Assumptions.none,
        );
        if (!hasUnevaluatedIntegral(res, variable)) return res;
      }
    }
  }

  for (var i = 0; i < varFactors.length; i++) {
    for (var j = i + 1; j < varFactors.length; j++) {
      final f1 = varFactors[i];
      final f2 = varFactors[j];
      Expr? pairReduced;
      if (f1 case Call(id: FunctionId.sin, args: [final a])
          when a.matchLinear(variable) != null) {
        if (f2 case Call(id: FunctionId.cos, args: [final b])
            when b.matchLinear(variable) != null) {
          pairReduced =
              (Fn.sin((a + b).simplify()) + Fn.sin((a - b).simplify())) /
              IntegerNumber.two;
        } else if (f2 case Call(id: FunctionId.sin, args: [final b])
            when b.matchLinear(variable) != null) {
          pairReduced =
              (Fn.cos((a - b).simplify()) - Fn.cos((a + b).simplify())) /
              IntegerNumber.two;
        }
      } else if (f1 case Call(id: FunctionId.cos, args: [final a])
          when a.matchLinear(variable) != null) {
        if (f2 case Call(id: FunctionId.sin, args: [final b])
            when b.matchLinear(variable) != null) {
          pairReduced =
              (Fn.sin((a + b).simplify()) - Fn.sin((a - b).simplify())) /
              IntegerNumber.two;
        } else if (f2 case Call(id: FunctionId.cos, args: [final b])
            when b.matchLinear(variable) != null) {
          pairReduced =
              (Fn.cos((a + b).simplify()) + Fn.cos((a - b).simplify())) /
              IntegerNumber.two;
        }
      }
      if (pairReduced != null) {
        final others = <Expr>[
          for (var k = 0; k < varFactors.length; k++)
            if (k != i && k != j) varFactors[k],
        ];
        final isReducibleProduct = others.every(
          (o) =>
              polynomialDegree(o, variable) != null ||
              (o is Call &&
                  (o.id == FunctionId.sin || o.id == FunctionId.cos) &&
                  o.args[0].matchLinear(variable) != null) ||
              (o is Pow &&
                  !o.base.dependsOn(variable) &&
                  o.exponent.matchLinear(variable) != null),
        );
        if (isReducibleProduct) {
          final otherExpr = others.length == 1
              ? others.first
              : Mul.of(others).simplify();
          final expanded = (otherExpr * pairReduced).expand().simplify();
          final res = antiDerivative(
            expanded,
            variable,
            assumptions: Assumptions.none,
          );
          if (!hasUnevaluatedIntegral(res, variable)) return res;
        }
      }
    }
  }

  return null;
}

/// Integrates `(a1*sin(u) + b1*cos(u) + c1) / (a*sin(u) + b*cos(u) + c)`.
Expr? tryLinearTrigQuotient(Expr left, Expr right, String variable) {
  if (!left.dependsOn(variable)) return null;
  final numCombo = extractLinearTrigCombo(left, variable);
  final denCombo = extractLinearTrigCombo(right, variable);
  if (numCombo == null || denCombo == null) return null;
  final inner = denCombo.inner;
  if (inner == null || numCombo.inner != inner) return null;
  final k = inner.matchLinear(variable)!.a;

  final a = denCombo.aSin;
  final b = denCombo.bCos;
  final c = denCombo.cConst;
  final a1 = numCombo.aSin;
  final b1 = numCombo.bCos;
  final c1 = numCombo.cConst;

  final denom = (a * a + b * b).simplify();
  if (denom is Number && denom.isZero) return null;

  final alpha = ((a1 * a + b1 * b) / denom).simplify();
  final beta = ((b1 * a - a1 * b) / denom).simplify();
  final gamma = (c1 - alpha * c).simplify();

  var res = (alpha * Variable(variable)).simplify();
  if (beta != IntegerNumber.zero) {
    res = (res + (beta / k) * Fn.ln(Fn.abs(right))).simplify();
  }
  if (gamma != IntegerNumber.zero) {
    final remInt = tryWeierstrassSubstitution(gamma, right, variable);
    if (remInt == null) return null;
    res = (res + remInt).simplify();
  }
  return res;
}

/// Integrates rational trigonometric functions `R(sin(u), cos(u), tan(u))` via
/// tangent or Weierstrass substitution.
Expr? tryRationalTrigSubstitution(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  if (tryDirichletKernel(expr, variable, assumptions: assumptions)
      case final dirRes?) {
    return dirRes;
  }
  if (_trySumDiffSinCos2xSubstitution(
        expr,
        variable,
        assumptions: assumptions,
        depth: depth,
      )
      case final sin2xRes?) {
    return sin2xRes;
  }

  final inner = collectAffineTrigInner(expr, variable);
  if (inner == null) {
    if (depth == 0 && hasMultipleAngleTrig(expr, variable)) {
      final expanded = expr.expandTrig(assumptions: assumptions);
      if (expanded != expr) {
        return tryRationalTrigSubstitution(
          expanded,
          variable,
          assumptions: assumptions,
          depth: depth + 1,
        );
      }
    }
    if (!isIntegrationBudgetExhausted()) {
      final tanInner = _findSingleLinearTanInner(expr, variable);
      if (tanInner != null) {
        final kTan = tanInner.matchLinear(variable)!.a;
        final tName = freshIntegrationVar('_rt', expr, variable, depth);
        final tVar = Variable(tName);
        final tanReplaced = replaceTrigWithTan(expr, tanInner, tVar);
        if (!tanReplaced.dependsOn(variable)) {
          final rawIntegrand =
              (tanReplaced / (kTan * (IntegerNumber.one + tVar * tVar)))
                  .simplify(assumptions: assumptions);
          if (!exceedsNodeBudget(rawIntegrand, 250)) {
            final integrand = rawIntegrand.together(assumptions: assumptions);
            final tInt = antiDerivative(
              integrand,
              tName,
              assumptions: assumptions,
              depth: depth + 1,
            );
            if (!hasUnevaluatedIntegral(tInt, tName)) {
              return tInt
                  .substitute(tName, Fn.tan(tanInner))
                  .simplify(assumptions: assumptions);
            }
          }
        }
      }
    }
    return null;
  }
  final k = inner.matchLinear(variable)!.a;

  if (tryTrigPolyDivision(
        expr,
        inner,
        variable,
        assumptions: assumptions,
        depth: depth,
      )
      case final polyDivRes?) {
    return polyDivRes;
  }

  // 1. Try t = tan(u) if expression is even in (sin, cos)
  final tName = freshIntegrationVar('_rt', expr, variable, depth);
  final tVar = Variable(tName);
  if (!isIntegrationBudgetExhausted()) {
    final tanReplaced = replaceTrigWithTan(expr, inner, tVar);
    if (!tanReplaced.dependsOn(variable)) {
      final rawIntegrand =
          (tanReplaced / (k * (IntegerNumber.one + tVar * tVar))).simplify();
      if (!exceedsNodeBudget(rawIntegrand, 300)) {
        final integrand = rawIntegrand.together();
        final tInt = antiDerivative(
          integrand,
          tName,
          assumptions: assumptions,
          depth: depth + 1,
        );
        if (!hasUnevaluatedIntegral(tInt, tName)) {
          return tInt
              .substitute(tName, Fn.tan(inner))
              .simplify(assumptions: assumptions);
        }
      }
    }
  }

  // 2. General Weierstrass substitution t = tan(u / 2)
  if (!isIntegrationBudgetExhausted()) {
    final wReplaced = replaceTrigWithWeierstrass(expr, inner, tVar);
    if (!wReplaced.dependsOn(variable)) {
      final rawIntegrand =
          ((wReplaced * IntegerNumber.two) /
                  (k * (IntegerNumber.one + tVar * tVar)))
              .simplify();
      if (!exceedsNodeBudget(rawIntegrand, 300)) {
        final integrand = rawIntegrand.together();
        final (_, intDen) = splitNumeratorDenominator(integrand);
        final rawDeg = polynomialDegree(intDen, tName);
        if (rawDeg != null && rawDeg <= 8) {
          final deg = polynomialDegree(intDen.expand().simplify(), tName);
          if (deg != null && deg <= 8) {
            final tInt = antiDerivative(
              integrand,
              tName,
              assumptions: assumptions,
              depth: depth + 1,
            );
            if (!hasUnevaluatedIntegral(tInt, tName)) {
              return tInt
                  .substitute(
                    tName,
                    Fn.tan((inner / IntegerNumber.two).simplify()),
                  )
                  .simplify(assumptions: assumptions);
            }
          }
        }
      }
    }
  }

  return null;
}

/// Integrates products containing an odd positive power of `cos`, `sin`, `cosh`,
/// or `sinh` paired with functions of the dual trig/hyperbolic function.
Expr? tryOddTrigHypSubstitution(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  if (depth >= 2 || expr is! Mul) return null;
  final factors = expr.factors;
  for (var i = 0; i < factors.length; i++) {
    final f = factors[i];
    final Expr fnBase;
    final int exp;
    if (f case Pow(:final base, exponent: IntegerNumber(asInt: final k?))
        when k.abs() <= 11 && k.isOdd) {
      fnBase = base;
      exp = k;
    } else if (f is Call &&
        const {
          FunctionId.cos,
          FunctionId.sin,
          FunctionId.cosh,
          FunctionId.sinh,
        }.contains(f.id)) {
      fnBase = f;
      exp = 1;
    } else {
      continue;
    }

    final Expr inner;
    final int kind; // 0: cos, 1: sin, 2: cosh, 3: sinh
    if (fnBase case Call(:final id, args: [final u])) {
      inner = u;
      switch (id) {
        case FunctionId.cos:
          kind = 0;
        case FunctionId.sin:
          kind = 1;
        case FunctionId.cosh:
          kind = 2;
        case FunctionId.sinh:
          kind = 3;
        default:
          continue;
      }
    } else {
      continue;
    }

    final lin = inner.matchLinear(variable);
    if (lin == null) continue;
    final kSlope = lin.a;

    final otherFactors = <Expr>[
      for (var j = 0; j < factors.length; j++)
        if (j != i) factors[j],
    ];
    final otherExpr = otherFactors.length == 1
        ? otherFactors.first
        : Mul.of(otherFactors).simplify(assumptions: assumptions);

    final sName = freshIntegrationVar('_ts', expr, variable, depth);
    final sVar = Variable(sName);
    final sqExpr = switch (kind) {
      0 || 1 => (IntegerNumber.one - sVar * sVar).simplify(),
      2 => (IntegerNumber.one + sVar * sVar).simplify(),
      _ => (sVar * sVar - IntegerNumber.one).simplify(),
    };
    final subTarget = switch (kind) {
      0 => Fn.sin(inner),
      1 => Fn.cos(inner),
      2 => Fn.sinh(inner),
      _ => Fn.cosh(inner),
    };
    final derivSign = kind == 1 ? IntegerNumber.negativeOne : IntegerNumber.one;

    Expr? replaceOther(Expr node) {
      if (!node.dependsOn(variable)) return node;
      if (node == subTarget) return sVar;
      if (node
          case Pow(base: final pBase, exponent: IntegerNumber(asInt: final m?))
          when pBase == fnBase && m.isEven && m.abs() <= 12) {
        return Pow.of(sqExpr, IntegerNumber.of(m ~/ 2));
      }
      if (node is Add) {
        final mapped = <Expr>[];
        for (final t in node.terms) {
          final rt = replaceOther(t);
          if (rt == null) return null;
          mapped.add(rt);
        }
        return Add.of(mapped);
      }
      if (node is Mul) {
        final mapped = <Expr>[];
        for (final mf in node.factors) {
          final rm = replaceOther(mf);
          if (rm == null) return null;
          mapped.add(rm);
        }
        return Mul.of(mapped);
      }
      if (node is Pow && !node.exponent.dependsOn(variable)) {
        final rb = replaceOther(node.base);
        if (rb == null) return null;
        return Pow.of(rb, node.exponent);
      }
      return null;
    }

    final replacedOther = replaceOther(otherExpr);
    if (replacedOther == null || replacedOther.dependsOn(variable)) continue;

    final r = (exp - 1) ~/ 2;
    final remCos = r == 0
        ? IntegerNumber.one
        : Pow.of(sqExpr, IntegerNumber.of(r));
    final transformed = (derivSign * replacedOther * remCos / kSlope).simplify(
      assumptions: assumptions,
    );
    if (exceedsNodeBudget(transformed, 250)) continue;

    final sRes = antiDerivative(
      transformed,
      sName,
      assumptions: assumptions,
      depth: depth + 1,
    );
    if (!hasUnevaluatedIntegral(sRes, sName)) {
      return sRes
          .substitute(sName, subTarget)
          .simplify(assumptions: assumptions);
    }
  }
  return null;
}

/// Integrates products and quotients of integer powers `sinh(u)^p * cosh(u)^q`.
Expr? tryHypPowerProduct(
  Expr num,
  Expr den,
  String variable, {
  Assumptions assumptions = Assumptions.none,
}) {
  final numInfo = _extractHypPowers(num, variable);
  final denInfo = _extractHypPowers(den, variable);
  if (numInfo == null || denInfo == null) return null;

  final inner = numInfo.inner ?? denInfo.inner;
  if (inner == null) return null;
  if (numInfo.inner != null &&
      denInfo.inner != null &&
      numInfo.inner != denInfo.inner) {
    return null;
  }
  final linear = inner.matchLinear(variable);
  if (linear == null) return null;
  final a = linear.a;

  final p = numInfo.sinhExp - denInfo.sinhExp;
  final q = numInfo.coshExp - denInfo.coshExp;
  if (p == 0 && q == 0) return null;
  if (p.abs() > 10 || q.abs() > 10) return null;
  final scale = (numInfo.scale / denInfo.scale).simplify(
    assumptions: assumptions,
  );

  final tName = freshIntegrationVar('_ht', num / den, variable, 0);
  final tVar = Variable(tName);

  if ((p + q).isEven && p + q <= -2) {
    final m = -(p + q) ~/ 2 - 1;
    final oneMT2 = (IntegerNumber.one - tVar * tVar).simplify();
    final integrand =
        ((scale / a) *
                Pow.of(tVar, IntegerNumber.of(p)) *
                Pow.of(oneMT2, IntegerNumber.of(m)))
            .expand()
            .simplify(assumptions: assumptions);
    final tInt = antiDerivative(
      integrand,
      tName,
      depth: 1,
      assumptions: assumptions,
    );
    if (!hasUnevaluatedIntegral(tInt, tName)) {
      return tInt
          .substitute(tName, Fn.tanh(inner))
          .simplify(assumptions: assumptions);
    }
  }

  if (p.isOdd && p >= -9 && p <= 9) {
    final k = (p - 1) ~/ 2;
    final coshPow = k == 0
        ? IntegerNumber.one
        : Pow.of(
            (tVar * tVar - IntegerNumber.one).simplify(),
            IntegerNumber.of(k),
          );
    final rawIntegrand =
        (scale / a) * coshPow * Pow.of(tVar, IntegerNumber.of(q));
    final integrand = k >= 0
        ? rawIntegrand.expand().simplify(assumptions: assumptions)
        : rawIntegrand.simplify(assumptions: assumptions);
    final tInt = antiDerivative(
      integrand,
      tName,
      depth: 1,
      assumptions: assumptions,
    );
    if (!hasUnevaluatedIntegral(tInt, tName)) {
      return tInt
          .substitute(tName, Fn.cosh(inner))
          .simplify(assumptions: assumptions);
    }
  }

  if (q.isOdd && q >= -9 && q <= 9) {
    final k = (q - 1) ~/ 2;
    final sinhPow = k == 0
        ? IntegerNumber.one
        : Pow.of(
            (IntegerNumber.one + tVar * tVar).simplify(),
            IntegerNumber.of(k),
          );
    final rawIntegrand =
        (scale / a) * Pow.of(tVar, IntegerNumber.of(p)) * sinhPow;
    final integrand = k >= 0
        ? rawIntegrand.expand().simplify(assumptions: assumptions)
        : rawIntegrand.simplify(assumptions: assumptions);
    final tInt = antiDerivative(
      integrand,
      tName,
      depth: 1,
      assumptions: assumptions,
    );
    if (!hasUnevaluatedIntegral(tInt, tName)) {
      return tInt
          .substitute(tName, Fn.sinh(inner))
          .simplify(assumptions: assumptions);
    }
  }

  if (p >= 0 && q >= 0 && p.isEven && q.isEven) {
    final twoInner = (IntegerNumber.two * inner).simplify();
    final sinh2 = (Fn.cosh(twoInner) - IntegerNumber.one) / IntegerNumber.two;
    final cosh2 = (Fn.cosh(twoInner) + IntegerNumber.one) / IntegerNumber.two;
    final expanded =
        (scale *
                Pow.of(sinh2, IntegerNumber.of(p ~/ 2)) *
                Pow.of(cosh2, IntegerNumber.of(q ~/ 2)))
            .expand()
            .simplify(assumptions: assumptions);
    if (expanded is Add || expanded != (num / den).simplify()) {
      final res = antiDerivative(
        expanded,
        variable,
        depth: 2,
        assumptions: assumptions,
      );
      if (!hasUnevaluatedIntegral(res, variable)) return res;
    }
  }

  return null;
}

/// Integrates rational hyperbolic functions `R(sinh(u), cosh(u), tanh(u))` via
/// `t = tanh(u)` or exponential substitution `w = exp(u)`.
Expr? tryHyperbolicRationalSubstitution(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  if (isIntegrationBudgetExhausted()) return null;
  final inner = collectAffineHypInner(expr, variable);
  if (inner == null) return null;
  final k = inner.matchLinear(variable)!.a;

  // 1. Try t = tanh(u) for even hyperbolic functions
  final tName = freshIntegrationVar('_ht', expr, variable, depth);
  final tVar = Variable(tName);
  final tanhReplaced = replaceHypWithTanh(expr, inner, tVar);
  if (!tanhReplaced.dependsOn(variable)) {
    final rawIntegrand =
        (tanhReplaced / (k * (IntegerNumber.one - tVar * tVar))).simplify(
          assumptions: assumptions,
        );
    if (!exceedsNodeBudget(rawIntegrand, 300)) {
      final integrand = rawIntegrand.together(assumptions: assumptions);
      final tInt = antiDerivative(
        integrand,
        tName,
        assumptions: assumptions,
        depth: depth + 1,
      );
      if (!hasUnevaluatedIntegral(tInt, tName)) {
        return tInt
            .substitute(tName, Fn.tanh(inner))
            .simplify(assumptions: assumptions);
      }
    }
  }

  // 2. General exponential substitution w = exp(u)
  final wName = freshIntegrationVar('_hw', expr, variable, depth);
  final wVar = Variable(wName);
  final replaced = replaceHypWithExp(expr, inner, wVar);
  if (replaced.dependsOn(variable) || exceedsNodeBudget(replaced, 300)) {
    return null;
  }

  final integrand = (replaced / (k * wVar)).simplify().together();
  final (_, intDen) = splitNumeratorDenominator(integrand);
  if (intDen.anyNode((n) => n is Add)) {
    final rawDeg = polynomialDegree(intDen, wName);
    final paramCount = ({...expr.freeVariables}..remove(variable)).length;
    if (rawDeg != null && (rawDeg > 16 || (paramCount >= 5 && rawDeg > 8))) {
      return null;
    }
  }
  final wInt = antiDerivative(
    integrand,
    wName,
    assumptions: assumptions,
    depth: depth + 1,
  );
  if (hasUnevaluatedIntegral(wInt, wName)) return null;

  return wInt
      .substitute(wName, Pow.of(Constant.e, inner))
      .simplify(assumptions: assumptions);
}

Expr? _findSingleLinearTanInner(Expr expr, String variable) {
  Expr? found;
  var hasTan = false;
  var valid = true;
  void scan(Expr n) {
    if (!valid || !n.dependsOn(variable)) return;
    switch (n) {
      case Call(id: FunctionId.tan, args: [final expr]):
        if (expr.matchLinear(variable) == null) {
          valid = false;
          return;
        }
        hasTan = true;
        if (found == null) {
          found = expr;
        } else if (found != expr) {
          valid = false;
        }
      case Call(id: FunctionId.sin || FunctionId.cos, args: [final expr]):
        if (expr.matchLinear(variable) == null) {
          valid = false;
          return;
        }
        if (found == null) {
          found = expr;
        } else if (found != expr) {
          valid = false;
        }
      case Add(:final terms):
        for (final t in terms) {
          scan(t);
        }
      case Mul(:final factors):
        for (final f in factors) {
          scan(f);
        }
      case Pow(:final base, :final exponent) when !exponent.dependsOn(variable):
        scan(base);
      default:
        valid = false;
    }
  }

  scan(expr);
  return (valid && hasTan) ? found : null;
}

({Expr scale, int sinhExp, int coshExp, Expr? inner})? _extractHypPowers(
  Expr expr,
  String variable,
) {
  final res = _extractCircularOrHypPowers(expr, variable, hyperbolic: true);
  if (res == null) return null;
  return (
    scale: res.scale,
    sinhExp: res.primaryExp,
    coshExp: res.secondaryExp,
    inner: res.inner,
  );
}

({Expr scale, int sinExp, int cosExp, Expr? inner})? _extractTrigPowers(
  Expr expr,
  String variable,
) {
  final res = _extractCircularOrHypPowers(expr, variable, hyperbolic: false);
  if (res == null) return null;
  return (
    scale: res.scale,
    sinExp: res.primaryExp,
    cosExp: res.secondaryExp,
    inner: res.inner,
  );
}

({Expr scale, int primaryExp, int secondaryExp, Expr? inner})?
_extractCircularOrHypPowers(
  Expr expr,
  String variable, {
  required bool hyperbolic,
}) {
  final factors = expr is Mul ? expr.factors : [expr];
  var scale = IntegerNumber.one as Expr;
  var primaryExp = 0;
  var secondaryExp = 0;
  Expr? inner;
  final primaryId = hyperbolic ? FunctionId.sinh : FunctionId.sin;
  final secondaryId = hyperbolic ? FunctionId.cosh : FunctionId.cos;
  final ratioId = hyperbolic ? FunctionId.tanh : FunctionId.tan;

  for (final f in factors) {
    if (!f.dependsOn(variable)) {
      scale = (scale * f).simplify();
      continue;
    }
    var base = f;
    var exp = 1;
    if (f case Pow(base: final pBase, exponent: IntegerNumber(:final asInt))
        when asInt != null && asInt.abs() <= 10) {
      base = pBase;
      exp = asInt;
    }
    if (base is! Call || base.args.length != 1) return null;
    final arg = base.args.first;
    if (inner == null) {
      inner = arg;
    } else if (inner != arg) {
      return null;
    }
    if (base.id == primaryId) {
      primaryExp += exp;
    } else if (base.id == secondaryId) {
      secondaryExp += exp;
    } else if (base.id == ratioId) {
      primaryExp += exp;
      secondaryExp -= exp;
    } else {
      return null;
    }
  }
  return (
    scale: scale,
    primaryExp: primaryExp,
    secondaryExp: secondaryExp,
    inner: inner,
  );
}
