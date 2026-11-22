import '../../algebra/expand.dart';
import '../../algebra/helpers.dart';
import '../../algebra/rational.dart';
import '../../algebra/simplify.dart';
import '../../assumptions.dart';
import '../../ast.dart';
import '../../number/integer.dart';
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
      final constFactors = <Expr>[];
      final varFactors = <Expr>[];
      for (final f in factors) {
        if (f.dependsOn(variable)) {
          varFactors.add(f);
        } else {
          constFactors.add(f);
        }
      }
      if (varFactors.length == 1) {
        final inner = extractMonomial(varFactors.first);
        if (inner != null) {
          final scale = constFactors.isEmpty
              ? IntegerNumber.one
              : Mul(constFactors).simplify(assumptions: assumptions);
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
      terms.add((value * Pow(xVar, newExp)) / (scale * newExp));
    }
  }
  return terms.isEmpty
      ? IntegerNumber.zero
      : Add(terms).simplify(assumptions: assumptions);
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
      final constFactors = <Expr>[];
      final varFactors = <Expr>[];
      for (final f in factors) {
        if (f.dependsOn(variable)) {
          varFactors.add(f);
        } else {
          constFactors.add(f);
        }
      }
      if (varFactors.length == 1) {
        final inner = extractLinPow(varFactors.first);
        if (inner != null) {
          final scale = constFactors.isEmpty
              ? IntegerNumber.one
              : Mul(constFactors).simplify(assumptions: assumptions);
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
  final denU = (a * scale * Pow(uVar, IntegerNumber.of(q))).simplify(
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
    if (f case Ln(:final expr) when !isNum) {
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
      base: Ln(:final expr),
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
  final lnExpr = Ln(inner);
  final xVar = Variable(variable);

  if (nExp == IntegerNumber.negativeOne) {
    final res = k == 1
        ? logAntiderivative(lnExpr, assumptions)
        : (-Pow(lnExpr, IntegerNumber.of(1 - k)) / IntegerNumber.of(k - 1));
    return (scale * res).simplify(assumptions: assumptions);
  }

  final np1 = (nExp + IntegerNumber.one).simplify(assumptions: assumptions);
  final isZeroN = nExp is Number && (nExp as Number).isZero;
  Expr integrateK(int m) {
    if (m == 1) {
      if (isZeroN) {
        return (LogIntegral(inner) / c).simplify(assumptions: assumptions);
      }
      return (ExpIntegral((np1 * lnExpr).simplify(assumptions: assumptions)) /
              Pow(c, np1))
          .simplify(assumptions: assumptions);
    }
    final m1 = IntegerNumber.of(m - 1);
    final term1 = -Pow(xVar, np1) / (m1 * Pow(lnExpr, m1));
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
        base: Sin() || Cos() || Sinh() || Cosh(),
        exponent: IntegerNumber(asInt: final n?),
      )
      when n >= 2 && n <= 4) {
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
      return Add(results).simplify(assumptions: assumptions);
    }
  }

  final Expr inner;
  if (left case Sin(:final expr)) {
    inner = expr;
  } else if (left case Cos(:final expr)) {
    inner = expr;
  } else if (left case Sinh(:final expr)) {
    inner = expr;
  } else if (left case Cosh(:final expr)) {
    inner = expr;
  } else {
    return null;
  }

  final linNum = inner.matchLinear(variable);
  if (linNum == null) return null;
  final (a: b, b: a) = linNum;

  Expr integrateBase(Expr fn) {
    final beta = (b / d).simplify(assumptions: assumptions);
    final alpha = (a - b * c / d).simplify(assumptions: assumptions);
    final arg = (beta * linBase).simplify(assumptions: assumptions);
    return switch (fn) {
      Sin() =>
        ((Cos(alpha) * SinIntegral(arg) + Sin(alpha) * CosIntegral(arg)) / d)
            .simplify(assumptions: assumptions),
      Cos() =>
        ((Cos(alpha) * CosIntegral(arg) - Sin(alpha) * SinIntegral(arg)) / d)
            .simplify(assumptions: assumptions),
      Sinh() =>
        ((Cosh(alpha) * SinhIntegral(arg) + Sinh(alpha) * CoshIntegral(arg)) /
                d)
            .simplify(assumptions: assumptions),
      Cosh() =>
        ((Cosh(alpha) * CoshIntegral(arg) + Sinh(alpha) * SinhIntegral(arg)) /
                d)
            .simplify(assumptions: assumptions),
      _ => throw StateError('Unreachable'),
    };
  }

  Expr integrateK(Expr fn, int m) {
    if (m == 1) return integrateBase(fn);
    final m1 = IntegerNumber.of(m - 1);
    final denomPow = m - 1 == 1 ? linBase : Pow(linBase, m1);
    final term1 = (-fn / (d * m1 * denomPow)).simplify(
      assumptions: assumptions,
    );
    final (Expr derivScale, Expr nextFn) = switch (fn) {
      Sin() => (b, Cos(inner)),
      Cos() => (-b, Sin(inner)),
      Sinh() => (b, Cosh(inner)),
      Cosh() => (b, Sinh(inner)),
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
          scale = Mul(consts).simplify(assumptions: assumptions);
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
        final shift = Pow(
          Constant.e,
          (a - b * c / d).simplify(assumptions: assumptions),
        );
        final arg = ((b / d) * linBase).simplify(assumptions: assumptions);
        return (scale * shift * ExpIntegral(arg) / d).simplify(
          assumptions: assumptions,
        );
      }
      final m1 = IntegerNumber.of(m - 1);
      final denomPow = m - 1 == 1 ? linBase : Pow(linBase, m1);
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
        return Add(results).simplify(assumptions: assumptions);
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
    Sin(:final expr) => (sign: 1, arg: expr),
    Mul(factors: [IntegerNumber(isNegativeOne: true), Sin(:final expr)]) => (
      sign: -1,
      arg: expr,
    ),
    _ => null,
  };

  ({int sign, Expr arg})? matchSignedCos(Expr e) => switch (e) {
    Cos(:final expr) => (sign: 1, arg: expr),
    Mul(factors: [IntegerNumber(isNegativeOne: true), Cos(:final expr)]) => (
      sign: -1,
      arg: expr,
    ),
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
    rewritten = (IntegerNumber.of(overallSign) * Tan(angle)).simplify(
      assumptions: assumptions,
    );
  } else {
    final angle = ((numSignB == 1 ? a - b : a + b) / IntegerNumber.two)
        .simplify(assumptions: assumptions);
    rewritten = (IntegerNumber.of(-overallSign) / Tan(angle)).simplify(
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
    if (t case Ln(expr: final arg) when inner == null || inner == arg) {
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
        } else if (f case Ln(expr: final arg) when lnArg == null) {
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
  if (node case Ln(expr: final inner)) {
    if (inner.matchLinear(variable) case (a: final a, b: final b)
        when b is Number && b.isZero && a != IntegerNumber.one) {
      return true;
    }
  }
  return false;
}

Expr splitScaledVarLn(Expr node, String variable) {
  if (node case Ln(expr: final inner)) {
    if (inner.matchLinear(variable) case (a: final a, b: final b)
        when b is Number && b.isZero && a != IntegerNumber.one) {
      return Ln(a) + Ln(Variable(variable));
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

  if (linFactors.length == 3 && !left.dependsOn(variable)) {
    final entries = linFactors.entries.toList();
    final u1 = entries[0].key;
    final p1 = entries[0].value;
    final u2 = entries[1].key;
    final p2 = entries[1].value;
    final u3 = entries[2].key;
    final p3 = entries[2].value;
    if (p1 + p2 + p3 > 16) return null;
    final l1 = u1.matchLinear(variable)!;
    final l2 = u2.matchLinear(variable)!;
    final l3 = u3.matchLinear(variable)!;
    final det12 = (l1.a * l2.b - l1.b * l2.a).expand().simplify(
      assumptions: assumptions,
    );
    final det13 = (l1.a * l3.b - l1.b * l3.a).expand().simplify(
      assumptions: assumptions,
    );
    final det23 = (l2.a * l3.b - l2.b * l3.a).expand().simplify(
      assumptions: assumptions,
    );
    if ((det12 is Number && det12.isZero) ||
        (det13 is Number && det13.isZero) ||
        (det23 is Number && det23.isZero)) {
      return null;
    }
    final decomp23 = _decomposeTwoLinearPowers(
      (left / scale).simplify(assumptions: assumptions),
      u2,
      p2,
      u3,
      p3,
      l2.a,
      l3.a,
      det23,
      assumptions,
    );
    final terms = <Expr>[];
    for (final (:coeff, :factor, :power) in decomp23) {
      if (factor == u2) {
        terms.add(
          _integrateTwoLinearPowersConst(
            coeff,
            u1,
            p1,
            u2,
            power,
            l1.a,
            l2.a,
            det12,
            assumptions,
          ),
        );
      } else {
        terms.add(
          _integrateTwoLinearPowersConst(
            coeff,
            u1,
            p1,
            u3,
            power,
            l1.a,
            l3.a,
            det13,
            assumptions,
          ),
        );
      }
    }
    return Add(terms).simplify(assumptions: assumptions);
  }

  if (linFactors.length != 2) return null;
  final entries = linFactors.entries.toList();
  final u = entries[0].key;
  final p = entries[0].value;
  final v = entries[1].key;
  final q = entries[1].value;
  if (p + q > 20) return null;

  final uLin = u.matchLinear(variable)!;
  final vLin = v.matchLinear(variable)!;
  final b = uLin.a;
  final a = uLin.b;
  final d = vLin.a;
  final c = vLin.b;
  final det = (b * c - a * d).expand().simplify(assumptions: assumptions);
  if (det is Number && det.isZero) return null;

  if (!left.dependsOn(variable)) {
    return _integrateTwoLinearPowersConst(
      (left / scale).simplify(assumptions: assumptions),
      u,
      p,
      v,
      q,
      b,
      d,
      det,
      assumptions,
    );
  }

  final degLeft = polynomialDegree(left, variable);
  if (degLeft == null || degLeft > 4) return null;

  // Decompose left in powers of u: left = sum c_m * u^m
  final coeffsInU = <Expr>[];
  var cur = left.expand().simplify(assumptions: assumptions);
  for (var m = 0; m <= degLeft; m++) {
    final (:quotient, :remainder) = cur.polynomialDivide(
      u,
      variable,
      assumptions: assumptions,
    );
    coeffsInU.add(remainder);
    cur = quotient;
  }

  final terms = <Expr>[];
  for (var m = 0; m < coeffsInU.length; m++) {
    final cm = coeffsInU[m];
    if (cm is Number && cm.isZero) continue;
    final scaledCm = (cm / scale).simplify(assumptions: assumptions);
    if (m < p) {
      terms.add(
        _integrateTwoLinearPowersConst(
          scaledCm,
          u,
          p - m,
          v,
          q,
          b,
          d,
          det,
          assumptions,
        ),
      );
    } else {
      final numExpr = m == p
          ? scaledCm
          : (scaledCm * Pow(u, IntegerNumber.of(m - p))).simplify();
      final remInt = tryLinearPowerDenominator(
        numExpr,
        Pow(v, IntegerNumber.of(q)),
        variable,
        assumptions: assumptions,
      );
      if (remInt == null) return null;
      terms.add(remInt);
    }
  }
  return terms.isEmpty
      ? IntegerNumber.zero
      : Add(terms).simplify(assumptions: assumptions);
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
  final bPowQ = Pow(b, IntegerNumber.of(q));
  for (var i = 1; i <= p; i++) {
    final binom = Integer.from(p - i + q - 1).binomial(Integer.from(q - 1));
    final ai =
        (coeff *
                IntegerNumber(binom) *
                Pow(negD, IntegerNumber.of(p - i)) *
                bPowQ /
                Pow(det, IntegerNumber.of(p - i + q)))
            .simplify(assumptions: assumptions);
    result.add((coeff: ai, factor: u, power: i));
  }

  // Terms B_j / v^j for 1 <= j <= q:
  // B_j = C(p - 1 + q - j, p - 1) * (-d)^p * b^(q - j) / det^(p + q - j)
  final negDPowP = Pow(negD, IntegerNumber.of(p));
  for (var j = 1; j <= q; j++) {
    final binom = Integer.from(p - 1 + q - j).binomial(Integer.from(p - 1));
    final bj =
        (coeff *
                IntegerNumber(binom) *
                negDPowP *
                Pow(b, IntegerNumber.of(q - j)) /
                Pow(det, IntegerNumber.of(p + q - j)))
            .simplify(assumptions: assumptions);
    result.add((coeff: bj, factor: v, power: j));
  }

  return result;
}

Expr _integrateTwoLinearPowersConst(
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
  final decomp = _decomposeTwoLinearPowers(
    coeff,
    u,
    p,
    v,
    q,
    b,
    d,
    det,
    assumptions,
  );
  final terms = <Expr>[];
  for (final (:coeff, :factor, :power) in decomp) {
    final slope = factor == u ? b : d;
    if (power == 1) {
      terms.add(
        ((coeff / slope) * logAntiderivative(factor, assumptions)).simplify(
          assumptions: assumptions,
        ),
      );
    } else {
      final oneMinusPow = IntegerNumber.of(1 - power);
      terms.add(
        ((coeff / (slope * oneMinusPow)) * Pow(factor, oneMinusPow)).simplify(
          assumptions: assumptions,
        ),
      );
    }
  }
  return Add(terms).simplify(assumptions: assumptions);
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
          : Mul(consts).simplify(assumptions: assumptions);
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
      mExpr.value >= const Integer(2) &&
      mExpr.value <= const Integer(10);
  if (!isIntM && remNum != IntegerNumber.zero) return null;

  final xVar = Variable(variable);
  final denomFactor = (a * n * mMinus1).simplify(assumptions: assumptions);
  if (denomFactor == IntegerNumber.zero) return null;

  final term1 =
      (Pow(xVar, (k + IntegerNumber.one).simplify(assumptions: assumptions)) /
              (denomFactor * Pow(base, mMinus1)))
          .simplify(assumptions: assumptions);

  if (remNum == IntegerNumber.zero) {
    return (c * term1).simplify(assumptions: assumptions);
  }

  final reducedIntegrand = (Pow(xVar, k) / Pow(base, mMinus1)).simplify(
    assumptions: assumptions,
  );
  final reducedIntegral = antiDerivative(
    reducedIntegrand,
    variable,
    depth: depth + 1,
    assumptions: assumptions,
  );
  final term2 = ((remNum / denomFactor) * reducedIntegral).simplify(
    assumptions: assumptions,
  );
  return (c * (term1 + term2)).simplify(assumptions: assumptions);
}
