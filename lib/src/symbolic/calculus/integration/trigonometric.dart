import '../../algebra/expand.dart';
import '../../algebra/rational.dart';
import '../../algebra/simplify.dart';
import '../../algebra/term_accumulator.dart';
import '../../algebra/trig.dart';
import '../../assumptions.dart';
import '../../ast.dart';
import '../linear_form.dart';
import 'definite.dart';
import 'integration.dart';

/// Integrates products of two sines or cosines via product-to-sum identities.
Expr? tryTrigProduct(Expr left, Expr right, String variable) {
  if (left case Sin(expr: final a) when a.matchLinear(variable) != null) {
    if (right case Cos(expr: final b) when b.matchLinear(variable) != null) {
      final sum = (a + b).simplify();
      final diff = (a - b).simplify();
      final expanded = ((Sin(sum) + Sin(diff)) / IntegerNumber.two).simplify();
      return antiDerivative(expanded, variable, assumptions: Assumptions.none);
    }
    if (right case Sin(expr: final b) when b.matchLinear(variable) != null) {
      final diff = (a - b).simplify();
      final sum = (a + b).simplify();
      final expanded = ((Cos(diff) - Cos(sum)) / IntegerNumber.two).simplify();
      return antiDerivative(expanded, variable, assumptions: Assumptions.none);
    }
  }
  if (left case Cos(expr: final a) when a.matchLinear(variable) != null) {
    if (right case Sin()) {
      return tryTrigProduct(right, left, variable);
    }
    if (right case Cos(expr: final b) when b.matchLinear(variable) != null) {
      final diff = (a - b).simplify();
      final sum = (a + b).simplify();
      final expanded = ((Cos(diff) + Cos(sum)) / IntegerNumber.two).simplify();
      return antiDerivative(expanded, variable, assumptions: Assumptions.none);
    }
  }
  return null;
}

/// Integrates `c / (a + b*sin(u) + c*cos(u))` via Weierstrass half-angle substitution.
Expr? tryWeierstrassSubstitution(Expr left, Expr right, String variable) {
  final terms = right is Add ? right.terms : [right];
  var aConst = IntegerNumber.zero as Expr;
  var bSin = IntegerNumber.zero as Expr;
  var cCos = IntegerNumber.zero as Expr;
  Expr? inner;

  for (final term in terms) {
    if (!term.dependsOn(variable)) {
      aConst = (aConst + term).simplify();
      continue;
    }
    var coeff = IntegerNumber.one as Expr;
    var varPart = term;
    if (term case Mul(:final factors)) {
      final (:constFactors, :varFactors) = partitionFactors(factors, variable);
      if (varFactors.length != 1) return null;
      varPart = varFactors.first;
      coeff = switch (constFactors) {
        [] => IntegerNumber.one,
        [final single] => single,
        _ => Mul(constFactors).simplify(),
      };
    }
    switch (varPart) {
      case Sin(expr: final arg):
        if (inner == null) {
          inner = arg;
        } else if (inner != arg) {
          return null;
        }
        bSin = (bSin + coeff).simplify();
      case Cos(expr: final arg):
        if (inner == null) {
          inner = arg;
        } else if (inner != arg) {
          return null;
        }
        cCos = (cCos + coeff).simplify();
      default:
        return null;
    }
  }

  if (inner == null) return null;
  final linear = inner.matchLinear(variable);
  if (linear == null) return null;
  final k = linear.a;

  const tName = '_wt';
  const tVar = Variable(tName);
  final denom =
      ((aConst - cCos) * tVar * tVar +
              IntegerNumber.two * bSin * tVar +
              (aConst + cCos))
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
      .substitute(tName, Tan((inner / IntegerNumber.two).simplify()))
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
      Pow(Tan(inner), IntegerNumber.of(p)),
      variable,
      assumptions: Assumptions.none,
    );
    return hasUnevaluatedIntegral(res, variable) ? null : res.scale(scale);
  }
  if (p < 0 && q == -p && q >= 2) {
    return _integrateCotPower(q, inner, a, variable).scale(scale);
  }

  const tName = '_wt';
  const tVar = Variable(tName);

  if (p >= 1 && p.isOdd) {
    final k = (p - 1) ~/ 2;
    final integrand =
        ((-scale / a) *
                Pow(IntegerNumber.one - tVar * tVar, IntegerNumber.of(k)) *
                Pow(tVar, IntegerNumber.of(q)))
            .expand()
            .simplify();
    final tInt = antiDerivative(
      integrand,
      tName,
      depth: 2,
      assumptions: Assumptions.none,
    );
    if (!hasUnevaluatedIntegral(tInt, tName)) {
      return tInt.substitute(tName, Cos(inner)).simplify();
    }
  }

  if (q >= 1 && q.isOdd) {
    final k = (q - 1) ~/ 2;
    final integrand =
        ((scale / a) *
                Pow(tVar, IntegerNumber.of(p)) *
                Pow(IntegerNumber.one - tVar * tVar, IntegerNumber.of(k)))
            .expand()
            .simplify();
    final tInt = antiDerivative(
      integrand,
      tName,
      depth: 2,
      assumptions: Assumptions.none,
    );
    if (!hasUnevaluatedIntegral(tInt, tName)) {
      return tInt.substitute(tName, Sin(inner)).simplify();
    }
  }

  if ((p + q).isEven && p + q <= -2) {
    final m = -(p + q) ~/ 2 - 1;
    final integrand =
        ((scale / a) *
                Pow(tVar, IntegerNumber.of(p)) *
                Pow(IntegerNumber.one + tVar * tVar, IntegerNumber.of(m)))
            .expand()
            .simplify();
    final tInt = antiDerivative(
      integrand,
      tName,
      depth: 2,
      assumptions: Assumptions.none,
    );
    if (!hasUnevaluatedIntegral(tInt, tName)) {
      return tInt.substitute(tName, Tan(inner)).simplify();
    }
  }

  if (p >= 0 && q >= 0 && p.isEven && q.isEven) {
    final twoInner = (IntegerNumber.two * inner).simplify();
    final sin2 = (IntegerNumber.one - Cos(twoInner)) / IntegerNumber.two;
    final cos2 = (IntegerNumber.one + Cos(twoInner)) / IntegerNumber.two;
    final expanded =
        (scale *
                Pow(sin2, IntegerNumber.of(p ~/ 2)) *
                Pow(cos2, IntegerNumber.of(q ~/ 2)))
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

  return null;
}

/// Integrates products of a polynomial with trigonometric powers or products
/// via multiple-angle power reduction.
Expr? tryPolyTrigPowerReduction(List<Expr> varFactors, String variable) {
  for (var i = 0; i < varFactors.length; i++) {
    if (_reduceTrigPower(varFactors[i], variable) case final reduced?) {
      final others = <Expr>[
        for (var j = 0; j < varFactors.length; j++)
          if (i != j) varFactors[j],
      ];
      final isReducible = others.every(
        (o) =>
            polynomialDegree(o, variable) != null ||
            (o is Pow &&
                !o.base.dependsOn(variable) &&
                o.exponent.matchLinear(variable) != null),
      );
      if (isReducible) {
        final otherExpr = others.length == 1
            ? others.first
            : Mul(others).simplify();
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
      if (f1 case Sin(expr: final a) when a.matchLinear(variable) != null) {
        if (f2 case Cos(expr: final b) when b.matchLinear(variable) != null) {
          pairReduced =
              (Sin((a + b).simplify()) + Sin((a - b).simplify())) /
              IntegerNumber.two;
        } else if (f2 case Sin(expr: final b)
            when b.matchLinear(variable) != null) {
          pairReduced =
              (Cos((a - b).simplify()) - Cos((a + b).simplify())) /
              IntegerNumber.two;
        }
      } else if (f1 case Cos(expr: final a)
          when a.matchLinear(variable) != null) {
        if (f2 case Sin(expr: final b) when b.matchLinear(variable) != null) {
          pairReduced =
              (Sin((a + b).simplify()) - Sin((a - b).simplify())) /
              IntegerNumber.two;
        } else if (f2 case Cos(expr: final b)
            when b.matchLinear(variable) != null) {
          pairReduced =
              (Cos((a + b).simplify()) + Cos((a - b).simplify())) /
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
              (o is Sin && o.expr.matchLinear(variable) != null) ||
              (o is Cos && o.expr.matchLinear(variable) != null) ||
              (o is Pow &&
                  !o.base.dependsOn(variable) &&
                  o.exponent.matchLinear(variable) != null),
        );
        if (isReducibleProduct) {
          final otherExpr = others.length == 1
              ? others.first
              : Mul(others).simplify();
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
  final numCombo = _extractLinearTrigCombo(left, variable);
  final denCombo = _extractLinearTrigCombo(right, variable);
  if (numCombo == null || denCombo == null) return null;
  if (numCombo.inner != denCombo.inner) return null;
  final inner = denCombo.inner!;
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
    res = (res + (beta / k) * Ln(Abs(right))).simplify();
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
  if (_tryDirichletKernel(expr, variable, assumptions: assumptions)
      case final dirRes?) {
    return dirRes;
  }

  final inner = _collectAffineTrigInner(expr, variable);
  if (inner == null) {
    if (depth == 0 && _hasMultipleAngleTrig(expr, variable)) {
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
    return null;
  }
  final k = inner.matchLinear(variable)!.a;

  // 1. Try t = tan(u) if expression is even in (sin, cos)
  const tName = '_rt';
  const tVar = Variable(tName);
  final tanReplaced = _replaceTrigWithTan(expr, inner, tVar);
  if (!tanReplaced.dependsOn(variable)) {
    final rawIntegrand = (tanReplaced / (k * (IntegerNumber.one + tVar * tVar)))
        .simplify();
    final integrand = rawIntegrand.together();
    final tInt = antiDerivative(
      integrand,
      tName,
      assumptions: assumptions,
      depth: 2,
    );
    if (!hasUnevaluatedIntegral(tInt, tName)) {
      return tInt
          .substitute(tName, Tan(inner))
          .simplify(assumptions: assumptions);
    }
  }

  // 2. General Weierstrass substitution t = tan(u / 2)
  final wReplaced = _replaceTrigWithWeierstrass(expr, inner, tVar);
  if (!wReplaced.dependsOn(variable)) {
    final rawIntegrand =
        ((wReplaced * IntegerNumber.two) /
                (k * (IntegerNumber.one + tVar * tVar)))
            .simplify();
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
          depth: 2,
        );
        if (!hasUnevaluatedIntegral(tInt, tName)) {
          return tInt
              .substitute(tName, Tan((inner / IntegerNumber.two).simplify()))
              .simplify(assumptions: assumptions);
        }
      }
    }
  }

  return null;
}

/// Integrates rational hyperbolic functions `R(sinh(u), cosh(u), tanh(u))` via
/// exponential substitution `w = exp(u)`.
Expr? tryHyperbolicRationalSubstitution(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  final inner = _collectAffineHypInner(expr, variable);
  if (inner == null) return null;
  final k = inner.matchLinear(variable)!.a;

  const wName = '_hw';
  const wVar = Variable(wName);
  final replaced = _replaceHypWithExp(expr, inner, wVar);
  if (replaced.dependsOn(variable)) return null;

  final integrand = (replaced / (k * wVar)).simplify().together();
  final wInt = antiDerivative(
    integrand,
    wName,
    assumptions: assumptions,
    depth: 2,
  );
  if (hasUnevaluatedIntegral(wInt, wName)) return null;

  return wInt
      .substitute(wName, Pow(Constant.e, inner))
      .simplify(assumptions: assumptions);
}

({Expr scale, int sinExp, int cosExp, Expr? inner})? _extractTrigPowers(
  Expr expr,
  String variable,
) {
  final factors = expr is Mul ? expr.factors : [expr];
  var scale = IntegerNumber.one as Expr;
  var sinExp = 0;
  var cosExp = 0;
  Expr? inner;

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
    switch (base) {
      case Sin(expr: final arg):
        if (inner == null) {
          inner = arg;
        } else if (inner != arg) {
          return null;
        }
        sinExp += exp;
      case Cos(expr: final arg):
        if (inner == null) {
          inner = arg;
        } else if (inner != arg) {
          return null;
        }
        cosExp += exp;
      default:
        return null;
    }
  }
  return (scale: scale, sinExp: sinExp, cosExp: cosExp, inner: inner);
}

Expr _integrateCotPower(int n, Expr inner, Expr a, String variable) {
  if (n == 0) return Variable(variable);
  if (n == 1) return (Ln(Abs(Sin(inner))) / a).simplify();
  final nMinus1 = IntegerNumber.of(n - 1);
  final cotTerm = Pow(Cos(inner) / Sin(inner), nMinus1);
  final term1 = (-cotTerm / (nMinus1 * a)).simplify();
  final rem = _integrateCotPower(n - 2, inner, a, variable);
  return (term1 - rem).simplify();
}

Expr? _reduceTrigPower(Expr factor, String variable) {
  if (factor case Pow(:final base, exponent: IntegerNumber(asInt: final n?))
      when n >= 2 && n <= 6) {
    final Expr inner;
    final bool isSin;
    if (base case Sin(:final expr) when expr.matchLinear(variable) != null) {
      inner = expr;
      isSin = true;
    } else if (base case Cos(:final expr)
        when expr.matchLinear(variable) != null) {
      inner = expr;
      isSin = false;
    } else {
      return null;
    }
    final u2 = (IntegerNumber.two * inner).simplify();
    final u3 = (IntegerNumber.of(3) * inner).simplify();
    final u4 = (IntegerNumber.of(4) * inner).simplify();
    final u5 = (IntegerNumber.of(5) * inner).simplify();
    final u6 = (IntegerNumber.of(6) * inner).simplify();
    return switch ((isSin, n)) {
      (true, 2) => (IntegerNumber.one - Cos(u2)) / IntegerNumber.two,
      (false, 2) => (IntegerNumber.one + Cos(u2)) / IntegerNumber.two,
      (true, 3) =>
        (IntegerNumber.of(3) * Sin(inner) - Sin(u3)) / IntegerNumber.of(4),
      (false, 3) =>
        (IntegerNumber.of(3) * Cos(inner) + Cos(u3)) / IntegerNumber.of(4),
      (true, 4) =>
        (IntegerNumber.of(3) - IntegerNumber.of(4) * Cos(u2) + Cos(u4)) /
            IntegerNumber.of(8),
      (false, 4) =>
        (IntegerNumber.of(3) + IntegerNumber.of(4) * Cos(u2) + Cos(u4)) /
            IntegerNumber.of(8),
      (true, 5) =>
        (IntegerNumber.of(10) * Sin(inner) -
                IntegerNumber.of(5) * Sin(u3) +
                Sin(u5)) /
            IntegerNumber.of(16),
      (false, 5) =>
        (IntegerNumber.of(10) * Cos(inner) +
                IntegerNumber.of(5) * Cos(u3) +
                Cos(u5)) /
            IntegerNumber.of(16),
      (true, 6) =>
        (IntegerNumber.of(10) -
                IntegerNumber.of(15) * Cos(u2) +
                IntegerNumber.of(6) * Cos(u4) -
                Cos(u6)) /
            IntegerNumber.of(32),
      (false, 6) =>
        (IntegerNumber.of(10) +
                IntegerNumber.of(15) * Cos(u2) +
                IntegerNumber.of(6) * Cos(u4) +
                Cos(u6)) /
            IntegerNumber.of(32),
      _ => null,
    };
  }
  return null;
}

({Expr aSin, Expr bCos, Expr cConst, Expr? inner})? _extractLinearTrigCombo(
  Expr expr,
  String variable,
) {
  final terms = expr is Add ? expr.terms : [expr];
  var aSin = IntegerNumber.zero as Expr;
  var bCos = IntegerNumber.zero as Expr;
  var cConst = IntegerNumber.zero as Expr;
  Expr? inner;

  for (final term in terms) {
    if (!term.dependsOn(variable)) {
      cConst = (cConst + term).simplify();
      continue;
    }
    var coeff = IntegerNumber.one as Expr;
    var varPart = term;
    if (term case Mul(:final factors)) {
      final (:constFactors, :varFactors) = partitionFactors(factors, variable);
      if (varFactors.length != 1) return null;
      varPart = varFactors.first;
      coeff = switch (constFactors) {
        [] => IntegerNumber.one,
        [final single] => single,
        _ => Mul(constFactors).simplify(),
      };
    }
    switch (varPart) {
      case Sin(expr: final arg):
        if (inner == null) {
          inner = arg;
        } else if (inner != arg) {
          return null;
        }
        aSin = (aSin + coeff).simplify();
      case Cos(expr: final arg):
        if (inner == null) {
          inner = arg;
        } else if (inner != arg) {
          return null;
        }
        bCos = (bCos + coeff).simplify();
      default:
        return null;
    }
  }
  if (inner == null || inner.matchLinear(variable) == null) return null;
  return (aSin: aSin, bCos: bCos, cConst: cConst, inner: inner);
}

Expr? _collectAffineTrigInner(Expr node, String variable) {
  Expr? found;
  var valid = true;
  void scan(Expr n) {
    if (!valid || !n.dependsOn(variable)) return;
    switch (n) {
      case Sin(:final expr) || Cos(:final expr) || Tan(:final expr):
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
      case Pow(:final base, :final exponent)
          when exponent is IntegerNumber && !exponent.dependsOn(variable):
        scan(base);
      default:
        valid = false;
    }
  }

  scan(node);
  return valid ? found : null;
}

Expr _replaceTrigWithWeierstrass(Expr node, Expr inner, Variable tVar) {
  if (node is Sin && node.expr == inner) {
    return (IntegerNumber.two * tVar) / (IntegerNumber.one + tVar * tVar);
  }
  if (node is Cos && node.expr == inner) {
    return (IntegerNumber.one - tVar * tVar) /
        (IntegerNumber.one + tVar * tVar);
  }
  if (node is Tan && node.expr == inner) {
    return (IntegerNumber.two * tVar) / (IntegerNumber.one - tVar * tVar);
  }
  return node.mapChildren((c) => _replaceTrigWithWeierstrass(c, inner, tVar));
}

Expr _replaceTrigWithTan(Expr node, Expr inner, Variable tVar) {
  if (node is Tan && node.expr == inner) return tVar;
  if (node
      case Pow(
        base: Sin(expr: final arg),
        exponent: IntegerNumber(asInt: final n?),
      )
      when arg == inner && n.isEven) {
    return Pow(
      (tVar * tVar) / (IntegerNumber.one + tVar * tVar),
      IntegerNumber.of(n ~/ 2),
    );
  }
  if (node
      case Pow(
        base: Cos(expr: final arg),
        exponent: IntegerNumber(asInt: final n?),
      )
      when arg == inner && n.isEven) {
    return Pow(
      IntegerNumber.one / (IntegerNumber.one + tVar * tVar),
      IntegerNumber.of(n ~/ 2),
    );
  }
  return node.mapChildren((c) => _replaceTrigWithTan(c, inner, tVar));
}

Expr? _collectAffineHypInner(Expr node, String variable) {
  Expr? found;
  final expExponents = <Expr>[];
  var valid = true;
  void scan(Expr n) {
    if (!valid || !n.dependsOn(variable)) return;
    switch (n) {
      case Sinh(:final expr) || Cosh(:final expr) || Tanh(:final expr):
        if (expr.matchLinear(variable) == null) {
          valid = false;
          return;
        }
        if (found == null) {
          found = expr;
        } else if (found != expr) {
          valid = false;
        }
      case Pow(base: Constant.e, :final exponent):
        if (exponent.matchLinear(variable) == null) {
          valid = false;
          return;
        }
        expExponents.add(exponent);
      case Add(:final terms):
        for (final t in terms) {
          scan(t);
        }
      case Mul(:final factors):
        for (final f in factors) {
          scan(f);
        }
      case Pow(:final base, :final exponent)
          when exponent is IntegerNumber && !exponent.dependsOn(variable):
        scan(base);
      default:
        valid = false;
    }
  }

  scan(node);
  if (!valid || found == null) return null;
  final linFound = found!.matchLinear(variable)!;
  for (final expArg in expExponents) {
    final linExp = expArg.matchLinear(variable)!;
    final ratio = (linExp.a / linFound.a).simplify();
    if (ratio is! IntegerNumber ||
        ratio.asInt == null ||
        ratio.asInt!.abs() > 6) {
      return null;
    }
  }
  return found;
}

Expr _replaceHypWithExp(Expr node, Expr inner, Variable wVar) {
  if (node is Sinh && node.expr == inner) {
    return (wVar - IntegerNumber.one / wVar) / IntegerNumber.two;
  }
  if (node is Cosh && node.expr == inner) {
    return (wVar + IntegerNumber.one / wVar) / IntegerNumber.two;
  }
  if (node is Tanh && node.expr == inner) {
    return (wVar * wVar - IntegerNumber.one) /
        (wVar * wVar + IntegerNumber.one);
  }
  if (node case Pow(base: Constant.e, :final exponent)) {
    final vName = inner.freeVariables.first;
    final linInner = inner.matchLinear(vName)!;
    final linExp = exponent.matchLinear(vName)!;
    final k = (linExp.a / linInner.a).simplify() as IntegerNumber;
    final shift = (linExp.b - k * linInner.b).simplify();
    final wPow = Pow(wVar, k);
    return (shift is Number && shift.isZero)
        ? wPow
        : (Pow(Constant.e, shift) * wPow);
  }
  return node.mapChildren((c) => _replaceHypWithExp(c, inner, wVar));
}

Expr? _tryDirichletKernel(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
}) {
  if (expr is! Mul) return null;
  var scale = IntegerNumber.one as Expr;
  Sin? numSin;
  Sin? denSin;
  for (final f in expr.factors) {
    if (!f.dependsOn(variable)) {
      scale = (scale * f).simplify(assumptions: assumptions);
    } else if (f is Sin && numSin == null) {
      numSin = f;
    } else if (f
        case Pow(
          base: final Sin s,
          exponent: IntegerNumber(isNegativeOne: true),
        )
        when denSin == null) {
      denSin = s;
    } else {
      return null;
    }
  }
  if (numSin == null || denSin == null) return null;
  final linDen = denSin.expr.matchLinear(variable);
  final linNum = numSin.expr.matchLinear(variable);
  if (linDen == null || linNum == null) return null;
  final nExpr = (linNum.a / linDen.a).simplify(assumptions: assumptions);
  if (nExpr is! IntegerNumber || nExpr.asInt == null) return null;
  final n = nExpr.asInt!;
  if (n < 2 || n > 50) return null;
  final expectedB = (nExpr * linDen.b).simplify(assumptions: assumptions);
  if ((linNum.b - expectedB).simplify(assumptions: assumptions) !=
      IntegerNumber.zero) {
    return null;
  }

  final u = denSin.expr;
  final a = linDen.a;
  final terms = <Expr>[];
  if (n.isOdd) {
    terms.add(u);
    final m = (n - 1) ~/ 2;
    for (var j = 1; j <= m; j++) {
      terms.add(
        Sin((IntegerNumber.of(2 * j) * u).simplify()) / IntegerNumber.of(j),
      );
    }
  } else {
    final m = n ~/ 2;
    for (var j = 1; j <= m; j++) {
      final coeff = IntegerNumber.of(2 * j - 1);
      terms.add((IntegerNumber.two * Sin((coeff * u).simplify())) / coeff);
    }
  }
  return (scale * Add(terms) / a).simplify(assumptions: assumptions);
}

bool _hasMultipleAngleTrig(Expr node, String variable) {
  final args = <Expr>{};
  var valid = true;
  void scan(Expr n) {
    if (!valid || !n.dependsOn(variable)) return;
    switch (n) {
      case Sin(:final expr) || Cos(:final expr) || Tan(:final expr):
        if (expr.matchLinear(variable) == null) {
          valid = false;
          return;
        }
        args.add(expr);
      case Add(:final terms):
        for (final t in terms) {
          scan(t);
        }
      case Mul(:final factors):
        for (final f in factors) {
          scan(f);
        }
      case Pow(:final base, :final exponent)
          when exponent is IntegerNumber && !exponent.dependsOn(variable):
        scan(base);
      default:
        valid = false;
    }
  }

  scan(node);
  if (!valid || args.length < 2) return false;
  var minSlope = double.infinity;
  Expr? minArg;
  for (final arg in args) {
    final a = arg.matchLinear(variable)!.a;
    if (a is RealNumeric) {
      final v = a.toDouble().abs();
      if (v > 0 && v < minSlope) {
        minSlope = v;
        minArg = arg;
      }
    }
  }
  if (minArg == null) return false;
  final baseSlope = minArg.matchLinear(variable)!.a;
  for (final arg in args) {
    final k = (arg.matchLinear(variable)!.a / baseSlope).simplify();
    if (k is! IntegerNumber || k.asInt == null || k.asInt!.abs() > 24) {
      return false;
    }
  }
  return true;
}
