import 'package:more/math.dart' show BinomialIntegerExtension;

import '../../algebra/expand.dart';
import '../../algebra/helpers.dart';
import '../../algebra/rational.dart';
import '../../algebra/simplify.dart';
import '../../assumptions.dart';
import '../../ast.dart';
import '../../functions/fn.dart';
import '../linear_form.dart';
import 'definite.dart';
import 'integration.dart';
import 'integration_elementary.dart';
import 'trigonometric_helpers.dart';

Expr? tryMonomialDenominator(
  Expr left,
  Expr right,
  String variable, {
  required Assumptions assumptions,
}) {
  ({Expr scale, int n})? extractMonomial(Expr e) {
    if (e case Variable(:final name) when name == variable) {
      return (scale: IntegerNumber.one, n: 1);
    }
    if (e
        case Pow(
          base: Variable(:final name),
          exponent: IntegerNumber(asInt: final k?),
        )
        when name == variable && k >= 1) {
      return (scale: IntegerNumber.one, n: k);
    }
    if (e case Mul(:final factors)) {
      final (:constFactors, :varFactors) = partitionFactors(factors, variable);
      if (varFactors.length == 1) {
        final inner = extractMonomial(varFactors.first);
        if (inner != null) {
          final scale = constFactors.isEmpty
              ? IntegerNumber.one
              : Mul.of(constFactors).simplify(assumptions: assumptions);
          return (scale: scale, n: inner.n);
        }
      }
    }
    return null;
  }

  final mono = extractMonomial(right);
  if (mono == null) return null;
  final (:scale, :n) = mono;

  final rawDeg = polynomialDegree(left, variable);
  if (rawDeg == null || rawDeg > 40) return null;

  final coeffs = extractPolynomialCoefficients(left, variable);
  if (coeffs == null) return null;

  final xVar = Variable(variable);
  final terms = <Expr>[];
  for (final MapEntry(:key, :value) in coeffs.entries) {
    if (value is Number && value.isZero) continue;
    final exp = key - n;
    if (exp == -1) {
      terms.add((value * logAntiderivative(xVar, assumptions)) / scale);
    } else {
      final newExp = IntegerNumber.of(exp + 1);
      terms.add((value * Pow.of(xVar, newExp)) / (scale * newExp));
    }
  }
  return terms.isEmpty
      ? IntegerNumber.zero
      : Add.of(terms).simplify(assumptions: assumptions);
}

Expr? tryLinearPowerDenominator(
  Expr left,
  Expr right,
  String variable, {
  required Assumptions assumptions,
}) {
  ({Expr scale, Expr linBase, int q})? extractLinPow(Expr e) {
    if (e
        case Pow(base: final linBase, exponent: IntegerNumber(asInt: final q?))
        when q >= 2 && linBase.dependsOn(variable)) {
      return (scale: IntegerNumber.one, linBase: linBase, q: q);
    }
    if (e case Mul(:final factors)) {
      final (:constFactors, :varFactors) = partitionFactors(factors, variable);
      if (varFactors.length == 1) {
        final inner = extractLinPow(varFactors.first);
        if (inner != null) {
          final scale = constFactors.isEmpty
              ? IntegerNumber.one
              : Mul.of(constFactors).simplify(assumptions: assumptions);
          return (scale: scale, linBase: inner.linBase, q: inner.q);
        }
      }
    }
    return null;
  }

  final lp = extractLinPow(right);
  if (lp == null) return null;
  final (:scale, :linBase, :q) = lp;

  final lin = linBase.matchLinear(variable);
  if (lin == null) return null;
  final (:a, :b) = lin;
  if (b is Number && b.isZero) return null;

  final rawDeg = polynomialDegree(left, variable);
  if (rawDeg == null || rawDeg == 0 || rawDeg > 20) return null;

  const uName = '_lin_u';
  const uVar = Variable(uName);
  final xOfU = ((uVar - b) / a).simplify(assumptions: assumptions);
  final numU = left
      .substitute(variable, xOfU)
      .simplify(assumptions: assumptions);
  final denU = (a * scale * Pow.of(uVar, IntegerNumber.of(q))).simplify(
    assumptions: assumptions,
  );
  final resU = tryMonomialDenominator(
    numU,
    denU,
    uName,
    assumptions: assumptions,
  );
  if (resU == null) return null;
  return resU.substitute(uName, linBase).simplify(assumptions: assumptions);
}

Expr? tryPowerOverLogPower(
  Expr left,
  Expr right,
  String variable, {
  required Assumptions assumptions,
}) {
  final numFactors = left is Mul ? left.factors : [left];
  final denFactors = right is Mul ? right.factors : [right];

  var scale = IntegerNumber.one as Expr;
  var nExp = IntegerNumber.zero as Expr;
  Expr? logInner;
  Expr? logScale;
  int? kInt;

  bool processFactor(Expr f, {required bool isNum}) {
    if (!f.dependsOn(variable)) {
      scale = (isNum ? scale * f : scale / f).simplify(
        assumptions: assumptions,
      );
      return true;
    }
    if (f is Variable && f.name == variable) {
      nExp = (nExp + (isNum ? IntegerNumber.one : IntegerNumber.negativeOne))
          .simplify(assumptions: assumptions);
      return true;
    }
    if (f case Pow(base: Variable(:final name), :final exponent)
        when name == variable && !exponent.dependsOn(variable)) {
      nExp = (nExp + (isNum ? exponent : -exponent)).simplify(
        assumptions: assumptions,
      );
      return true;
    }
    if (f case Call(id: FunctionId.ln, args: [final expr]) when !isNum) {
      if (kInt != null) return false;
      if (expr.matchLinear(variable) case (:final a, :final b)
          when b is Number && b.isZero) {
        logInner = expr;
        logScale = a;
        kInt = 1;
        return true;
      }
      return false;
    }
    if (f case Pow(
      base: Call(id: FunctionId.ln, args: [final expr]),
      exponent: IntegerNumber(asInt: final p?),
    )) {
      final k = isNum ? -p : p;
      if (k < 1 || k > 6 || kInt != null) return false;
      if (expr.matchLinear(variable) case (:final a, :final b)
          when b is Number && b.isZero) {
        logInner = expr;
        logScale = a;
        kInt = k;
        return true;
      }
      return false;
    }
    return false;
  }

  for (final f in numFactors) {
    if (!processFactor(f, isNum: true)) return null;
  }
  for (final f in denFactors) {
    if (!processFactor(f, isNum: false)) return null;
  }
  if (logInner == null || logScale == null || kInt == null) return null;

  final inner = logInner!;
  final c = logScale!;
  final k = kInt!;
  final lnExpr = Fn.ln(inner);
  final xVar = Variable(variable);

  if (nExp == IntegerNumber.negativeOne ||
      (nExp is RealNumber && (nExp as RealNumber).value == -1.0)) {
    final res = k == 1
        ? logAntiderivative(lnExpr, assumptions)
        : (-Pow.of(lnExpr, IntegerNumber.of(1 - k)) / IntegerNumber.of(k - 1));
    return (scale * res).simplify(assumptions: assumptions);
  }

  final np1 = (nExp + IntegerNumber.one).simplify(assumptions: assumptions);
  final isZeroN = nExp is Number && (nExp as Number).isZero;
  Expr integrateK(int m) {
    if (m == 1) {
      if (isZeroN) {
        return (Fn.li(inner) / c).simplify(assumptions: assumptions);
      }
      return (Fn.ei((np1 * lnExpr).simplify(assumptions: assumptions)) /
              Pow.of(c, np1))
          .simplify(assumptions: assumptions);
    }
    final m1 = IntegerNumber.of(m - 1);
    final term1 = -Pow.of(xVar, np1) / (m1 * Pow.of(lnExpr, m1));
    final term2 = (np1 / m1) * integrateK(m - 1);
    return (term1 + term2).simplify(assumptions: assumptions);
  }

  return (scale * integrateK(k)).simplify(assumptions: assumptions);
}

Expr? tryTrigOrHypOverLinearPower(
  Expr left,
  Expr right,
  String variable, {
  required Assumptions assumptions,
}) {
  final Expr linBase;
  final int k;
  if (right
      case Pow(base: final rBase, exponent: IntegerNumber(asInt: final p?))
      when p >= 1 && p <= 6) {
    linBase = rBase;
    k = p;
  } else {
    linBase = right;
    k = 1;
  }

  final linDen = linBase.matchLinear(variable);
  if (linDen == null) return null;
  final (a: d, b: c) = linDen;

  // Handle powered trig/hyperbolic numerator: (sin|cos|sinh|cosh)(u)^n / (c + d*x)^k
  if (left
      case Pow(
        base: Call(id: final fnId),
        exponent: IntegerNumber(asInt: final n?),
      )
      when (fnId == FunctionId.sin ||
              fnId == FunctionId.cos ||
              fnId == FunctionId.sinh ||
              fnId == FunctionId.cosh) &&
          n >= 2 &&
          n <= 4) {
    final reduced = reduceTrigPower(left, variable);
    if (reduced != null) {
      final expanded = reduced
          .expand(assumptions: assumptions)
          .simplify(assumptions: assumptions);
      final terms = expanded is Add ? expanded.terms : [expanded];
      final results = <Expr>[];
      for (final t in terms) {
        final res = antiDerivative(
          (t / right).simplify(assumptions: assumptions),
          variable,
          depth: 2,
          assumptions: assumptions,
        );
        if (hasUnevaluatedIntegral(res, variable)) return null;
        results.add(res);
      }
      return Add.of(results).simplify(assumptions: assumptions);
    }
  }

  if (left is! Call || left.args.length != 1) return null;
  final Expr inner;
  switch (left.id) {
    case FunctionId.sin || FunctionId.cos || FunctionId.sinh || FunctionId.cosh:
      inner = left.args[0];
    default:
      return null;
  }

  final linNum = inner.matchLinear(variable);
  if (linNum == null) return null;
  final (a: b, b: a) = linNum;

  Expr integrateBase(Call fn) {
    final beta = (b / d).simplify(assumptions: assumptions);
    final alpha = (a - b * c / d).simplify(assumptions: assumptions);
    final arg = (beta * linBase).simplify(assumptions: assumptions);
    return switch (fn.id) {
      FunctionId.sin =>
        ((Fn.cos(alpha) * Fn.si(arg) + Fn.sin(alpha) * Fn.ci(arg)) / d)
            .simplify(assumptions: assumptions),
      FunctionId.cos =>
        ((Fn.cos(alpha) * Fn.ci(arg) - Fn.sin(alpha) * Fn.si(arg)) / d)
            .simplify(assumptions: assumptions),
      FunctionId.sinh =>
        ((Fn.cosh(alpha) * Fn.shi(arg) + Fn.sinh(alpha) * Fn.chi(arg)) / d)
            .simplify(assumptions: assumptions),
      FunctionId.cosh =>
        ((Fn.cosh(alpha) * Fn.chi(arg) + Fn.sinh(alpha) * Fn.shi(arg)) / d)
            .simplify(assumptions: assumptions),
      _ => throw StateError('Unreachable'),
    };
  }

  Expr integrateK(Call fn, int m) {
    if (m == 1) return integrateBase(fn);
    final m1 = IntegerNumber.of(m - 1);
    final denomPow = m - 1 == 1 ? linBase : Pow.of(linBase, m1);
    final term1 = (-fn / (d * m1 * denomPow)).simplify(
      assumptions: assumptions,
    );
    final (Expr derivScale, Call nextFn) = switch (fn.id) {
      FunctionId.sin => (b, Fn.cos(inner)),
      FunctionId.cos => (-b, Fn.sin(inner)),
      FunctionId.sinh => (b, Fn.cosh(inner)),
      FunctionId.cosh => (b, Fn.sinh(inner)),
      _ => throw StateError('Unreachable'),
    };
    final rem = integrateK(nextFn, m - 1);
    return (term1 + (derivScale / (d * m1)) * rem).simplify(
      assumptions: assumptions,
    );
  }

  return integrateK(left, k);
}

Expr? tryExpOverRational(
  Expr left,
  Expr right,
  String variable, {
  required int depth,
  required Assumptions assumptions,
}) {
  var scale = IntegerNumber.one as Expr;
  Pow? expNode;
  if (left is Pow && left.base == Constant.e) {
    expNode = left;
  } else if (left is Mul) {
    final consts = <Expr>[];
    final vars = <Expr>[];
    for (final f in left.factors) {
      if (f.dependsOn(variable)) {
        vars.add(f);
      } else {
        consts.add(f);
      }
    }
    if (vars.length == 1 && vars.first is Pow) {
      final p = vars.first as Pow;
      if (p.base == Constant.e) {
        expNode = p;
        if (consts.isNotEmpty) {
          scale = Mul.of(consts).simplify(assumptions: assumptions);
        }
      }
    }
  }
  if (expNode == null) return null;

  final linExp = expNode.exponent.matchLinear(variable);
  if (linExp == null) return null;
  final (a: b, b: a) = linExp;

  // Case 1: right is (c + d*x)^k with 1 <= k <= 6
  final Expr linBase;
  final int k;
  if (right
      case Pow(base: final rBase, exponent: IntegerNumber(asInt: final p?))
      when p >= 1 && p <= 6) {
    linBase = rBase;
    k = p;
  } else {
    linBase = right;
    k = 1;
  }
  final linDen = linBase.matchLinear(variable);
  if (linDen != null) {
    final (a: d, b: c) = linDen;
    Expr integrateK(int m) {
      if (m == 1) {
        final shift = Pow.of(
          Constant.e,
          (a - b * c / d).simplify(assumptions: assumptions),
        );
        final arg = ((b / d) * linBase).simplify(assumptions: assumptions);
        return (scale * shift * Fn.ei(arg) / d).simplify(
          assumptions: assumptions,
        );
      }
      final m1 = IntegerNumber.of(m - 1);
      final denomPow = m - 1 == 1 ? linBase : Pow.of(linBase, m1);
      final term1 = (-left / (d * m1 * denomPow)).simplify(
        assumptions: assumptions,
      );
      final rem = integrateK(m - 1);
      return (term1 + (b / (d * m1)) * rem).simplify(assumptions: assumptions);
    }

    return integrateK(k);
  }

  // Case 2: right is a polynomial of degree 2..4 -> partial fractions
  if (depth < 2) {
    final deg = polynomialDegree(right, variable);
    if (deg != null && deg >= 2 && deg <= 4) {
      final pf = (IntegerNumber.one / right).apart(variable);
      if (pf is Add) {
        final results = <Expr>[];
        for (final term in pf.terms) {
          final res = antiDerivative(
            (left * term).simplify(assumptions: assumptions),
            variable,
            depth: depth + 1,
            assumptions: assumptions,
          );
          if (hasUnevaluatedIntegral(res, variable)) return null;
          results.add(res);
        }
        return Add.of(results).simplify(assumptions: assumptions);
      }
    }
  }
  return null;
}

Expr? trySumToProductTrigQuotient(
  Expr left,
  Add right,
  String variable, {
  required int depth,
  required Assumptions assumptions,
}) {
  if (left is! Add || left.terms.length != 2 || right.terms.length != 2) {
    return null;
  }

  ({int sign, Expr arg})? matchSignedSin(Expr e) => switch (e) {
    Call(id: FunctionId.sin, args: [final expr]) => (sign: 1, arg: expr),
    Mul(
      factors: [
        IntegerNumber(isNegativeOne: true),
        Call(id: FunctionId.sin, args: [final expr]),
      ],
    ) =>
      (sign: -1, arg: expr),
    _ => null,
  };

  ({int sign, Expr arg})? matchSignedCos(Expr e) => switch (e) {
    Call(id: FunctionId.cos, args: [final expr]) => (sign: 1, arg: expr),
    Mul(
      factors: [
        IntegerNumber(isNegativeOne: true),
        Call(id: FunctionId.cos, args: [final expr]),
      ],
    ) =>
      (sign: -1, arg: expr),
    _ => null,
  };

  final s0 = matchSignedSin(left.terms[0]);
  final s1 = matchSignedSin(left.terms[1]);
  final c0 = matchSignedCos(right.terms[0]);
  final c1 = matchSignedCos(right.terms[1]);
  if (s0 == null || s1 == null || c0 == null || c1 == null) return null;

  final ({int sign, Expr arg}) cosA;
  final ({int sign, Expr arg}) cosB;
  if (s0.arg == c0.arg && s1.arg == c1.arg) {
    cosA = c0;
    cosB = c1;
  } else if (s0.arg == c1.arg && s1.arg == c0.arg) {
    cosA = c1;
    cosB = c0;
  } else {
    return null;
  }

  final a = s0.arg;
  final b = s1.arg;
  if (a == b ||
      a.matchLinear(variable) == null ||
      b.matchLinear(variable) == null) {
    return null;
  }

  var numSignA = s0.sign;
  var numSignB = s1.sign;
  var denSignA = cosA.sign;
  var denSignB = cosB.sign;
  var overallSign = 1;
  if (denSignA == -1) {
    denSignA = 1;
    denSignB = -denSignB;
    overallSign = -overallSign;
  }
  if (numSignA == -1) {
    numSignA = 1;
    numSignB = -numSignB;
    overallSign = -overallSign;
  }

  final Expr rewritten;
  if (denSignB == 1) {
    final angle = ((numSignB == 1 ? a + b : a - b) / IntegerNumber.two)
        .simplify(assumptions: assumptions);
    rewritten = (IntegerNumber.of(overallSign) * Fn.tan(angle)).simplify(
      assumptions: assumptions,
    );
  } else {
    final angle = ((numSignB == 1 ? a - b : a + b) / IntegerNumber.two)
        .simplify(assumptions: assumptions);
    rewritten = (IntegerNumber.of(-overallSign) / Fn.tan(angle)).simplify(
      assumptions: assumptions,
    );
  }

  final res = antiDerivative(
    rewritten,
    variable,
    assumptions: assumptions,
    depth: depth + 1,
  );
  return hasUnevaluatedIntegral(res, variable) ? null : res;
}

({Expr a, Expr b, Expr inner})? matchLinearLog(Expr expr, String variable) {
  final terms = expr is Add ? expr.terms : [expr];
  var a = IntegerNumber.zero as Expr;
  Expr? b;
  Expr? inner;
  for (final t in terms) {
    if (!t.dependsOn(variable)) {
      a = (a + t).simplify();
      continue;
    }
    if (t case Call(id: FunctionId.ln, args: [final arg])
        when inner == null || inner == arg) {
      inner = arg;
      b = ((b ?? IntegerNumber.zero) + IntegerNumber.one).simplify();
      continue;
    }
    if (t case Mul(:final factors)) {
      var coeff = IntegerNumber.one as Expr;
      Expr? lnArg;
      var valid = true;
      for (final f in factors) {
        if (!f.dependsOn(variable)) {
          coeff = (coeff * f).simplify();
        } else if (f case Call(id: FunctionId.ln, args: [final arg])
            when lnArg == null) {
          lnArg = arg;
        } else {
          valid = false;
          break;
        }
      }
      if (valid && lnArg != null && (inner == null || inner == lnArg)) {
        inner = lnArg;
        b = ((b ?? IntegerNumber.zero) + coeff).simplify();
        continue;
      }
    }
    return null;
  }
  if (b == null || inner == null || (b is Number && b.isZero)) return null;
  return (a: a, b: b, inner: inner);
}

bool isScaledVarLn(Expr node, String variable) {
  if (node case Call(id: FunctionId.ln, args: [final inner])) {
    if (inner.matchLinear(variable) case (a: final a, b: final b)
        when b is Number &&
            b.isZero &&
            a != IntegerNumber.one &&
            isPositiveConstant(a)) {
      return true;
    }
  }
  return false;
}

Expr splitScaledVarLn(Expr node, String variable) {
  if (node case Call(id: FunctionId.ln, args: [final inner])) {
    if (inner.matchLinear(variable) case (a: final a, b: final b)
        when b is Number &&
            b.isZero &&
            a != IntegerNumber.one &&
            isPositiveConstant(a)) {
      return Fn.ln(a) + Fn.ln(Variable(variable));
    }
  }
  return node.mapChildren((c) => splitScaledVarLn(c, variable));
}

Expr? tryTwoLinearPowersDenominator(
  Expr left,
  Expr right,
  String variable, {
  required Assumptions assumptions,
}) {
  final factors = right is Mul ? right.factors : [right];
  var scale = IntegerNumber.one as Expr;
  final linFactors = <Expr, int>{};

  for (final f in factors) {
    if (!f.dependsOn(variable)) {
      scale = (scale * f).simplify(assumptions: assumptions);
      continue;
    }
    if (f.matchLinear(variable) != null) {
      linFactors[f] = (linFactors[f] ?? 0) + 1;
      continue;
    }
    if (f case Pow(:final base, exponent: IntegerNumber(asInt: final exp?))
        when exp >= 1 && exp <= 20 && base.matchLinear(variable) != null) {
      linFactors[base] = (linFactors[base] ?? 0) + exp;
      continue;
    }
    return null;
  }

  if (linFactors.isEmpty || linFactors.length > 3) return null;

  final entries = linFactors.entries.toList();
  final sumMult = linFactors.values.fold<int>(0, (acc, v) => acc + v);
  if (sumMult > (linFactors.length == 3 ? 16 : 20)) return null;

  if (linFactors.length == 1) {
    // Covered by tryLinearPowerDenominator; only handle via shared decomposer.
    return null;
  }

  if (linFactors.length == 2) {
    final u = entries[0].key;
    final v = entries[1].key;
    final uLin = u.matchLinear(variable)!;
    final vLin = v.matchLinear(variable)!;
    final det = (uLin.a * vLin.b - uLin.b * vLin.a).expand().simplify(
      assumptions: assumptions,
    );
    if (det is Number && det.isZero) return null;
  } else {
    final l0 = entries[0].key.matchLinear(variable)!;
    final l1 = entries[1].key.matchLinear(variable)!;
    final l2 = entries[2].key.matchLinear(variable)!;
    for (final det in [
      (l0.a * l1.b - l0.b * l1.a).expand().simplify(assumptions: assumptions),
      (l0.a * l2.b - l0.b * l2.a).expand().simplify(assumptions: assumptions),
      (l1.a * l2.b - l1.b * l2.a).expand().simplify(assumptions: assumptions),
    ]) {
      if (det is Number && det.isZero) return null;
    }
  }

  final maxDeg = linFactors.length == 3 ? 12 : 16;
  final degLeft = polynomialDegree(left, variable);
  if (degLeft == null || degLeft > maxDeg) return null;

  final decomp = _decomposeFactoredLinearPowers(
    (left / scale).simplify(assumptions: assumptions),
    linFactors,
    variable,
    assumptions,
  );
  if (decomp == null) return null;

  final terms = <Expr>[];
  if (decomp.polyPart != IntegerNumber.zero) {
    final polyInt = antiDerivative(
      decomp.polyPart,
      variable,
      assumptions: assumptions,
      depth: 2,
    );
    if (hasUnevaluatedIntegral(polyInt, variable)) return null;
    terms.add(polyInt);
  }
  for (final (:coeff, :factor, :power) in decomp.pfTerms) {
    if (coeff is Number && coeff.isZero) continue;
    final slope = factor.matchLinear(variable)!.a;
    if (power == 1) {
      terms.add(
        ((coeff / slope) * logAntiderivative(factor, assumptions)).simplify(
          assumptions: assumptions,
        ),
      );
    } else {
      final oneMinusPow = IntegerNumber.of(1 - power);
      terms.add(
        ((coeff / (slope * oneMinusPow)) * Pow.of(factor, oneMinusPow))
            .simplify(assumptions: assumptions),
      );
    }
  }
  return terms.isEmpty
      ? IntegerNumber.zero
      : Add.of(terms).simplify(assumptions: assumptions);
}

/// Integrates `P(x) / (scale * x^r * prod_{i=1..m} (a_i + b_i * x^k)^{p_i})`
/// by partitioning terms of `P(x)` into residue classes mod `k` and reducing
/// each class in `t = x^k` via partial fractions and Ostrogradsky reduction.
Expr? tryFactoredBinomialPowersDenominator(
  Expr left,
  Expr right,
  String variable, {
  required int depth,
  required Assumptions assumptions,
}) {
  if (depth >= 2) return null;
  final factors = right is Mul ? right.factors : [right];
  var scale = IntegerNumber.one as Expr;
  var r = 0;
  int? commonK;
  final binomPowers = <Expr, int>{};

  for (final f in factors) {
    if (!f.dependsOn(variable)) {
      scale = (scale * f).simplify(assumptions: assumptions);
      continue;
    }
    if (f is Variable && f.name == variable) {
      r += 1;
      continue;
    }
    if (f
        case Pow(
          base: Variable(:final name),
          exponent: IntegerNumber(:final asInt?),
        )
        when name == variable && asInt >= 1 && asInt <= 24) {
      r += asInt;
      continue;
    }
    final Expr bBase;
    final int bExp;
    if (f case Pow(:final base, exponent: IntegerNumber(asInt: final exp?))
        when exp >= 1 && exp <= 16) {
      bBase = base;
      bExp = exp;
    } else {
      bBase = f;
      bExp = 1;
    }
    final coeffs = extractPolynomialCoefficients(bBase, variable);
    if (coeffs == null || coeffs.length != 2) return null;
    final aCoeff = coeffs[0];
    final degK = coeffs.keys.reduce((a, b) => a > b ? a : b);
    if (degK < 2 || degK > 6 || aCoeff == null) return null;
    if (aCoeff is Number && aCoeff.isZero) return null;
    final bCoeff = coeffs[degK];
    if (bCoeff == null || (bCoeff is Number && bCoeff.isZero)) return null;
    if (commonK != null && commonK != degK) return null;
    commonK = degK;
    binomPowers[bBase] = (binomPowers[bBase] ?? 0) + bExp;
  }

  if (commonK == null || binomPowers.isEmpty) return null;
  final k = commonK;
  final totalMult = binomPowers.values.fold<int>(0, (acc, v) => acc + v);
  if (totalMult > 16 || binomPowers.length + (r > 0 ? 1 : 0) > 3) {
    return null;
  }

  final rawDegLeft = polynomialDegree(left, variable);
  if (rawDegLeft == null || rawDegLeft > 16) return null;
  if (binomPowers.length == 1 &&
      r == 0 &&
      (k == 2 || (binomPowers.values.first == 1 && rawDegLeft < k))) {
    return null;
  }

  const tName = '_t_fb';
  const tVar = Variable(tName);
  final binomFactorsInT = <Expr, int>{};
  for (final MapEntry(:key, :value) in binomPowers.entries) {
    final c = extractPolynomialCoefficients(key, variable)!;
    final linT = (c[0]! + c[k]! * tVar).simplify(assumptions: assumptions);
    if (linT.matchLinear(tName) == null) return null;
    binomFactorsInT[linT] = (binomFactorsInT[linT] ?? 0) + value;
  }

  final tEntries = binomFactorsInT.entries.toList();
  for (var i = 0; i < tEntries.length; i++) {
    final li = tEntries[i].key.matchLinear(tName)!;
    for (var j = i + 1; j < tEntries.length; j++) {
      final lj = tEntries[j].key.matchLinear(tName)!;
      final det = (li.a * lj.b - li.b * lj.a).expand().simplify(
        assumptions: assumptions,
      );
      if (det is Number && det.isZero) return null;
    }
  }

  final leftExp = left.expand().simplify(assumptions: assumptions);
  final leftCoeffs = extractPolynomialCoefficients(leftExp, variable);
  if (leftCoeffs == null) return null;

  final byRem = <int, List<({int deg, Expr coeff})>>{};
  for (final MapEntry(:key, :value) in leftCoeffs.entries) {
    if (value is Number && value.isZero) continue;
    byRem.putIfAbsent(key % k, () => []).add((deg: key, coeff: value));
  }

  final xVar = Variable(variable);
  final xPowK = Pow.of(xVar, IntegerNumber.of(k));
  final results = <Expr>[];

  Expr integrateMonomialPower(Expr coeff, int expX) {
    if (expX == -1) {
      return (coeff * logAntiderivative(xVar, assumptions)).simplify(
        assumptions: assumptions,
      );
    }
    final np1 = IntegerNumber.of(expX + 1);
    return (coeff * Pow.of(xVar, np1) / np1).simplify(assumptions: assumptions);
  }

  for (final group in byRem.values) {
    var minQ = 1 << 20;
    var s = 0;
    final items = <({int q, Expr coeff})>[];
    for (final item in group) {
      final netExp = item.deg - r;
      var q = netExp ~/ k;
      var rem = netExp - q * k;
      if (rem < 0) {
        q -= 1;
        rem += k;
      }
      s = rem;
      if (q < minQ) minQ = q;
      items.add((q: q, coeff: item.coeff));
    }

    final p0 = minQ < 0 ? -minQ : 0;
    if (p0 > 16 || binomFactorsInT.length + (p0 > 0 ? 1 : 0) > 3) {
      return null;
    }

    final numT = Add.of([
      for (final item in items)
        (item.q + p0 == 0
                ? item.coeff
                : item.coeff * Pow.of(tVar, IntegerNumber.of(item.q + p0)))
            .simplify(assumptions: assumptions),
    ]).simplify(assumptions: assumptions);

    final linMapT = <Expr, int>{if (p0 > 0) tVar: p0, ...binomFactorsInT};
    final decomp = _decomposeFactoredLinearPowers(
      (numT / scale).simplify(assumptions: assumptions),
      linMapT,
      tName,
      assumptions,
    );
    if (decomp == null) return null;

    if (decomp.polyPart != IntegerNumber.zero) {
      final pCoeffs = extractPolynomialCoefficients(decomp.polyPart, tName);
      if (pCoeffs == null) return null;
      for (final MapEntry(key: j, value: cJ) in pCoeffs.entries) {
        if (cJ is Number && cJ.isZero) continue;
        results.add(integrateMonomialPower(cJ, s + j * k));
      }
    }

    final xPowS = s == 0
        ? IntegerNumber.one
        : (s == 1 ? xVar : Pow.of(xVar, IntegerNumber.of(s)));

    for (final (:coeff, :factor, :power) in decomp.pfTerms) {
      if (coeff is Number && coeff.isZero) continue;
      if (factor == tVar) {
        results.add(integrateMonomialPower(coeff, s - power * k));
        continue;
      }
      final linT = factor.matchLinear(tName)!;
      final bi = linT.a;
      final ai = linT.b;
      final ux = factor
          .substitute(tName, xPowK)
          .simplify(assumptions: assumptions);

      if (s == k - 1) {
        if (power == 1) {
          results.add(
            ((coeff * logAntiderivative(ux, assumptions)) /
                    (IntegerNumber.of(k) * bi))
                .simplify(assumptions: assumptions),
          );
        } else {
          final oneMinusPow = IntegerNumber.of(1 - power);
          results.add(
            ((coeff * Pow.of(ux, oneMinusPow)) /
                    (IntegerNumber.of(k) * bi * oneMinusPow))
                .simplify(assumptions: assumptions),
          );
        }
        continue;
      }

      var curCoeff = coeff;
      for (var j = power; j >= 2; j--) {
        final jm1 = j - 1;
        final denomScale = (ai * IntegerNumber.of(k * jm1)).simplify(
          assumptions: assumptions,
        );
        final xPowSp1 = s == 0 ? xVar : Pow.of(xVar, IntegerNumber.of(s + 1));
        results.add(
          (curCoeff *
                  xPowSp1 /
                  (denomScale * Pow.of(ux, IntegerNumber.of(jm1))))
              .simplify(assumptions: assumptions),
        );
        final remFactor = (IntegerNumber.of(k * jm1 - s - 1) / denomScale)
            .simplify(assumptions: assumptions);
        curCoeff = (curCoeff * remFactor).simplify(assumptions: assumptions);
        if (curCoeff is Number && curCoeff.isZero) break;
      }
      if (!(curCoeff is Number && curCoeff.isZero)) {
        final baseIntegrand = (xPowS / ux).simplify(assumptions: assumptions);
        final baseInt = antiDerivative(
          baseIntegrand,
          variable,
          depth: depth + 1,
          assumptions: assumptions,
        );
        if (hasUnevaluatedIntegral(baseInt, variable)) return null;
        results.add((curCoeff * baseInt).simplify(assumptions: assumptions));
      }
    }
  }

  return results.isEmpty
      ? IntegerNumber.zero
      : Add.of(results).simplify(assumptions: assumptions);
}

/// Integrates `P(x) / (c * x^r * Q(x))` with `Q(0) != 0` by synthetic
/// stripping of `x^r` into monomial terms plus a reduced `R(x) / Q(x)` quotient.
Expr? tryMonomialTimesPolyDenominator(
  Expr left,
  Expr right,
  String variable, {
  required int depth,
  required Assumptions assumptions,
}) {
  if (depth >= 4) return null;
  final factors = right is Mul ? right.factors : [right];
  var scale = IntegerNumber.one as Expr;
  var r = 0;
  Expr? qExpr;

  for (final f in factors) {
    if (!f.dependsOn(variable)) {
      scale = (scale * f).simplify(assumptions: assumptions);
      continue;
    }
    if (f is Variable && f.name == variable) {
      r += 1;
      continue;
    }
    if (f
        case Pow(
          base: Variable(:final name),
          exponent: IntegerNumber(:final asInt?),
        )
        when name == variable && asInt >= 1 && asInt <= 24) {
      r += asInt;
      continue;
    }
    if (qExpr != null) return null;
    qExpr = f;
  }

  if (r < 1 || qExpr == null) return null;
  final qCoeffs = extractPolynomialCoefficients(
    qExpr.expand().simplify(assumptions: assumptions),
    variable,
  );
  if (qCoeffs == null) return null;
  final degQ = maxPolynomialDegree(qCoeffs);
  if (degQ < 2 || degQ > 10) return null;
  final q0 = qCoeffs[0] ?? IntegerNumber.zero;
  if (q0 is Number && q0.isZero) return null;

  final pCoeffsRaw = extractPolynomialCoefficients(
    left.expand().simplify(assumptions: assumptions),
    variable,
  );
  if (pCoeffsRaw == null) return null;
  final degP = maxPolynomialDegree(pCoeffsRaw);
  if (degP > 16) return null;

  final xVar = Variable(variable);
  var curCoeffs = Map<int, Expr>.from(pCoeffsRaw);
  final monoTerms = <Expr>[];

  for (var m = r; m >= 1; m--) {
    final p0 = curCoeffs[0] ?? IntegerNumber.zero;
    final ratio = (p0 / q0).simplify(assumptions: assumptions);
    if (!(ratio is Number && ratio.isZero)) {
      final c = (ratio / scale).simplify(assumptions: assumptions);
      if (m == 1) {
        monoTerms.add(
          (c * logAntiderivative(xVar, assumptions)).simplify(
            assumptions: assumptions,
          ),
        );
      } else {
        final oneMinusM = IntegerNumber.of(1 - m);
        monoTerms.add(
          ((c / oneMinusM) * Pow.of(xVar, oneMinusM)).simplify(
            assumptions: assumptions,
          ),
        );
      }
    }
    final nextCoeffs = <int, Expr>{};
    final maxDeg = curCoeffs.isEmpty ? 0 : maxPolynomialDegree(curCoeffs);
    final limit = maxDeg > degQ ? maxDeg : degQ;
    for (var i = 1; i <= limit; i++) {
      final pi = curCoeffs[i] ?? IntegerNumber.zero;
      final qi = qCoeffs[i] ?? IntegerNumber.zero;
      final diff = (pi - ratio * qi).simplify(assumptions: assumptions);
      if (!(diff is Number && diff.isZero)) {
        nextCoeffs[i - 1] = diff;
      }
    }
    curCoeffs = nextCoeffs;
  }

  final remTerms = <Expr>[
    for (final MapEntry(:key, :value) in curCoeffs.entries)
      (key == 0 ? value : value * Pow.of(xVar, IntegerNumber.of(key))).simplify(
        assumptions: assumptions,
      ),
  ];
  final remNum = remTerms.isEmpty
      ? IntegerNumber.zero
      : Add.of(remTerms).simplify(assumptions: assumptions);
  if (!(remNum is Number && remNum.isZero)) {
    final remIntegrand = (remNum / (scale * qExpr)).simplify(
      assumptions: assumptions,
    );
    final remInt = antiDerivative(
      remIntegrand,
      variable,
      depth: depth + 1,
      assumptions: assumptions,
    );
    if (hasUnevaluatedIntegral(remInt, variable)) return null;
    monoTerms.add(remInt);
  }

  return monoTerms.isEmpty
      ? IntegerNumber.zero
      : Add.of(monoTerms).simplify(assumptions: assumptions);
}

({Expr polyPart, List<({Expr coeff, Expr factor, int power})> pfTerms})?
_decomposeFactoredLinearPowers(
  Expr numExpr,
  Map<Expr, int> linFactors,
  String variable,
  Assumptions assumptions,
) {
  final cur = numExpr.expand().simplify(assumptions: assumptions);
  if (cur is Number && cur.isZero) {
    return (polyPart: IntegerNumber.zero, pfTerms: const []);
  }
  final deg = polynomialDegree(cur, variable);
  if (deg == null) return null;

  final entries = linFactors.entries.toList();
  final u = entries[0].key;
  final p = entries[0].value;

  final coeffsInU = <Expr>[];
  var remCur = cur;
  for (var m = 0; m <= deg; m++) {
    final (:quotient, :remainder) = remCur.polynomialDivide(
      u,
      variable,
      assumptions: assumptions,
    );
    coeffsInU.add(remainder);
    remCur = quotient;
  }

  if (entries.length == 1) {
    final polyTerms = <Expr>[];
    final pfTerms = <({Expr coeff, Expr factor, int power})>[];
    for (var m = 0; m < coeffsInU.length; m++) {
      final cm = coeffsInU[m];
      if (cm is Number && cm.isZero) continue;
      if (m < p) {
        pfTerms.add((coeff: cm, factor: u, power: p - m));
      } else {
        polyTerms.add(
          m == p ? cm : (cm * Pow.of(u, IntegerNumber.of(m - p))).simplify(),
        );
      }
    }
    return (
      polyPart: polyTerms.isEmpty
          ? IntegerNumber.zero
          : Add.of(polyTerms).simplify(assumptions: assumptions),
      pfTerms: pfTerms,
    );
  }

  final uLin = u.matchLinear(variable)!;
  if (entries.length == 2) {
    final v = entries[1].key;
    final q = entries[1].value;
    final vLin = v.matchLinear(variable)!;
    final det = (uLin.a * vLin.b - uLin.b * vLin.a).expand().simplify(
      assumptions: assumptions,
    );
    if (det is Number && det.isZero) return null;

    final polyParts = <Expr>[];
    final pfTerms = <({Expr coeff, Expr factor, int power})>[];
    for (var m = 0; m < coeffsInU.length; m++) {
      final cm = coeffsInU[m];
      if (cm is Number && cm.isZero) continue;
      if (m < p) {
        pfTerms.addAll(
          _decomposeTwoLinearPowers(
            cm,
            u,
            p - m,
            v,
            q,
            uLin.a,
            vLin.a,
            det,
            assumptions,
          ),
        );
      } else {
        final sub = _decomposeFactoredLinearPowers(
          (cm *
                  (m == p
                      ? IntegerNumber.one
                      : Pow.of(u, IntegerNumber.of(m - p))))
              .simplify(assumptions: assumptions),
          {v: q},
          variable,
          assumptions,
        );
        if (sub == null) return null;
        if (sub.polyPart != IntegerNumber.zero) polyParts.add(sub.polyPart);
        pfTerms.addAll(sub.pfTerms);
      }
    }
    return (
      polyPart: polyParts.isEmpty
          ? IntegerNumber.zero
          : Add.of(polyParts).simplify(assumptions: assumptions),
      pfTerms: pfTerms,
    );
  }

  // entries.length == 3
  final u2 = entries[1].key;
  final p2 = entries[1].value;
  final u3 = entries[2].key;
  final p3 = entries[2].value;
  final l2 = u2.matchLinear(variable)!;
  final l3 = u3.matchLinear(variable)!;
  final det12 = (uLin.a * l2.b - uLin.b * l2.a).expand().simplify(
    assumptions: assumptions,
  );
  final det13 = (uLin.a * l3.b - uLin.b * l3.a).expand().simplify(
    assumptions: assumptions,
  );
  final det23 = (l2.a * l3.b - l2.b * l3.a).expand().simplify(
    assumptions: assumptions,
  );

  final polyParts = <Expr>[];
  final pfTerms = <({Expr coeff, Expr factor, int power})>[];
  for (var m = 0; m < coeffsInU.length; m++) {
    final cm = coeffsInU[m];
    if (cm is Number && cm.isZero) continue;
    if (m < p) {
      final decomp23 = _decomposeTwoLinearPowers(
        cm,
        u2,
        p2,
        u3,
        p3,
        l2.a,
        l3.a,
        det23,
        assumptions,
      );
      for (final item in decomp23) {
        if (item.factor == u2) {
          pfTerms.addAll(
            _decomposeTwoLinearPowers(
              item.coeff,
              u,
              p - m,
              u2,
              item.power,
              uLin.a,
              l2.a,
              det12,
              assumptions,
            ),
          );
        } else {
          pfTerms.addAll(
            _decomposeTwoLinearPowers(
              item.coeff,
              u,
              p - m,
              u3,
              item.power,
              uLin.a,
              l3.a,
              det13,
              assumptions,
            ),
          );
        }
      }
    } else {
      final sub = _decomposeFactoredLinearPowers(
        (cm * (m == p ? IntegerNumber.one : Pow.of(u, IntegerNumber.of(m - p))))
            .simplify(assumptions: assumptions),
        {u2: p2, u3: p3},
        variable,
        assumptions,
      );
      if (sub == null) return null;
      if (sub.polyPart != IntegerNumber.zero) polyParts.add(sub.polyPart);
      pfTerms.addAll(sub.pfTerms);
    }
  }
  return (
    polyPart: polyParts.isEmpty
        ? IntegerNumber.zero
        : Add.of(polyParts).simplify(assumptions: assumptions),
    pfTerms: pfTerms,
  );
}

List<({Expr coeff, Expr factor, int power})> _decomposeTwoLinearPowers(
  Expr coeff,
  Expr u,
  int p,
  Expr v,
  int q,
  Expr b,
  Expr d,
  Expr det,
  Assumptions assumptions,
) {
  final result = <({Expr coeff, Expr factor, int power})>[];
  final negD = (-d).simplify(assumptions: assumptions);

  // Terms A_i / u^i for 1 <= i <= p:
  // A_i = C(p - i + q - 1, q - 1) * (-d)^(p - i) * b^q / det^(p - i + q)
  final bPowQ = Pow.of(b, IntegerNumber.of(q));
  for (var i = 1; i <= p; i++) {
    final binom = (p - i + q - 1).binomial(q - 1);
    final ai =
        (coeff *
                IntegerNumber.of(binom) *
                Pow.of(negD, IntegerNumber.of(p - i)) *
                bPowQ /
                Pow.of(det, IntegerNumber.of(p - i + q)))
            .simplify(assumptions: assumptions);
    result.add((coeff: ai, factor: u, power: i));
  }

  // Terms B_j / v^j for 1 <= j <= q:
  // B_j = C(p - 1 + q - j, p - 1) * (-d)^p * b^(q - j) / det^(p + q - j)
  final negDPowP = Pow.of(negD, IntegerNumber.of(p));
  for (var j = 1; j <= q; j++) {
    final binom = (p - 1 + q - j).binomial(p - 1);
    final bj =
        (coeff *
                IntegerNumber.of(binom) *
                negDPowP *
                Pow.of(b, IntegerNumber.of(q - j)) /
                Pow.of(det, IntegerNumber.of(p + q - j)))
            .simplify(assumptions: assumptions);
    result.add((coeff: bj, factor: v, power: j));
  }

  return result;
}

Expr? tryBinomialPowerOstrogradsky(
  Expr left,
  Expr right,
  String variable, {
  required int depth,
  required Assumptions assumptions,
}) {
  if (depth > 8) return null;
  if (right is! Pow) return null;
  final base = right.base;
  final mExpr = right.exponent;
  if (mExpr.dependsOn(variable) || mExpr == IntegerNumber.one) return null;
  if (base is! Add || base.terms.length != 2) return null;
  final t0 = base.terms[0];
  final t1 = base.terms[1];

  final Expr a;
  final Expr bXn;
  if (!t0.dependsOn(variable) && t1.dependsOn(variable)) {
    a = t0;
    bXn = t1;
  } else if (!t1.dependsOn(variable) && t0.dependsOn(variable)) {
    a = t1;
    bXn = t0;
  } else {
    return null;
  }
  if (a == IntegerNumber.zero) return null;

  ({Expr coeff, Expr exp})? extractMonomial(Expr e) {
    if (!e.dependsOn(variable)) return (coeff: e, exp: IntegerNumber.zero);
    if (e is Variable && e.name == variable) {
      return (coeff: IntegerNumber.one, exp: IntegerNumber.one);
    }
    if (e case Pow(base: Variable(:final name), exponent: final exp)
        when name == variable && !exp.dependsOn(variable)) {
      return (coeff: IntegerNumber.one, exp: exp);
    }
    if (e case Mul(:final factors)) {
      final consts = <Expr>[];
      Expr? xPow;
      for (final f in factors) {
        if (!f.dependsOn(variable)) {
          consts.add(f);
        } else if (xPow == null) {
          xPow = f;
        } else {
          return null;
        }
      }
      if (xPow == null) return null;
      final inner = extractMonomial(xPow);
      if (inner == null) return null;
      final c = consts.isEmpty
          ? IntegerNumber.one
          : Mul.of(consts).simplify(assumptions: assumptions);
      return (
        coeff: (c * inner.coeff).simplify(assumptions: assumptions),
        exp: inner.exp,
      );
    }
    return null;
  }

  final bxnInfo = extractMonomial(bXn);
  if (bxnInfo == null || bxnInfo.exp == IntegerNumber.zero) return null;
  final leftInfo = extractMonomial(left);
  if (leftInfo == null) return null;

  final n = bxnInfo.exp;
  final k = leftInfo.exp;
  final c = leftInfo.coeff;
  final mMinus1 = (mExpr - IntegerNumber.one).simplify(
    assumptions: assumptions,
  );
  if (mMinus1 == IntegerNumber.zero) return null;

  final remNum = (n * mMinus1 - k - IntegerNumber.one).simplify(
    assumptions: assumptions,
  );
  final isIntM =
      mExpr is IntegerNumber &&
      mExpr.value >= BigInt.two &&
      mExpr.value <= BigInt.from(10);
  if (!isIntM && remNum != IntegerNumber.zero) return null;

  final xVar = Variable(variable);
  final denomFactor = (a * n * mMinus1).simplify(assumptions: assumptions);
  if (denomFactor == IntegerNumber.zero) return null;

  final term1 =
      (Pow.of(
                xVar,
                (k + IntegerNumber.one).simplify(assumptions: assumptions),
              ) /
              (denomFactor * Pow.of(base, mMinus1)))
          .simplify(assumptions: assumptions);

  if (remNum == IntegerNumber.zero) {
    return (c * term1).simplify(assumptions: assumptions);
  }

  final reducedIntegrand = (Pow.of(xVar, k) / Pow.of(base, mMinus1)).simplify(
    assumptions: assumptions,
  );
  final reducedIntegral = antiDerivative(
    reducedIntegrand,
    variable,
    depth: depth + 1,
    assumptions: assumptions,
  );
  if (k is IntegerNumber &&
      n is IntegerNumber &&
      hasUnevaluatedIntegral(reducedIntegral, variable)) {
    return null;
  }
  final term2 = ((remNum / denomFactor) * reducedIntegral).simplify(
    assumptions: assumptions,
  );
  return (c * (term1 + term2)).simplify(assumptions: assumptions);
}
