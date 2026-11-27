import 'package:more/math.dart';

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

import 'trigonometric.dart';

Expr integrateCotPower(int n, Expr inner, Expr a, String variable) {
  if (n == 0) return Variable(variable);
  if (n == 1) return (Fn.ln(Fn.abs(Fn.sin(inner))) / a).simplify();
  final nMinus1 = IntegerNumber.of(n - 1);
  final cotTerm = Pow.of(Fn.cos(inner) / Fn.sin(inner), nMinus1);
  final term1 = (-cotTerm / (nMinus1 * a)).simplify();
  final rem = integrateCotPower(n - 2, inner, a, variable);
  return (term1 - rem).simplify();
}

/// Reduces integer powers `2 <= n <= 6` of `sin`, `cos`, `sinh`, or `cosh`
/// with linear arguments into multiple-angle sums.
Expr? reduceTrigPower(Expr factor, String variable) {
  if (factor case Pow(:final base, exponent: IntegerNumber(asInt: final n?))
      when n >= 2 && n <= 6) {
    Expr u2(Expr inner) => (IntegerNumber.two * inner).simplify();
    Expr u3(Expr inner) => (IntegerNumber.of(3) * inner).simplify();
    Expr u4(Expr inner) => (IntegerNumber.of(4) * inner).simplify();
    Expr u5(Expr inner) => (IntegerNumber.of(5) * inner).simplify();
    Expr u6(Expr inner) => (IntegerNumber.of(6) * inner).simplify();

    if (base case Call(id: FunctionId.sinh, args: [final expr])
        when expr.matchLinear(variable) != null) {
      return switch (n) {
        2 => (Fn.cosh(u2(expr)) - IntegerNumber.one) / IntegerNumber.two,
        3 =>
          (Fn.sinh(u3(expr)) - IntegerNumber.of(3) * Fn.sinh(expr)) /
              IntegerNumber.of(4),
        4 =>
          (Fn.cosh(u4(expr)) -
                  IntegerNumber.of(4) * Fn.cosh(u2(expr)) +
                  IntegerNumber.of(3)) /
              IntegerNumber.of(8),
        _ => null,
      };
    }
    if (base case Call(id: FunctionId.cosh, args: [final expr])
        when expr.matchLinear(variable) != null) {
      return switch (n) {
        2 => (Fn.cosh(u2(expr)) + IntegerNumber.one) / IntegerNumber.two,
        3 =>
          (Fn.cosh(u3(expr)) + IntegerNumber.of(3) * Fn.cosh(expr)) /
              IntegerNumber.of(4),
        4 =>
          (Fn.cosh(u4(expr)) +
                  IntegerNumber.of(4) * Fn.cosh(u2(expr)) +
                  IntegerNumber.of(3)) /
              IntegerNumber.of(8),
        _ => null,
      };
    }

    final Expr inner;
    final bool isSin;
    if (base case Call(id: FunctionId.sin, args: [final expr])
        when expr.matchLinear(variable) != null) {
      inner = expr;
      isSin = true;
    } else if (base case Call(id: FunctionId.cos, args: [final expr])
        when expr.matchLinear(variable) != null) {
      inner = expr;
      isSin = false;
    } else {
      return null;
    }
    return switch ((isSin, n)) {
      (true, 2) => (IntegerNumber.one - Fn.cos(u2(inner))) / IntegerNumber.two,
      (false, 2) => (IntegerNumber.one + Fn.cos(u2(inner))) / IntegerNumber.two,
      (true, 3) =>
        (IntegerNumber.of(3) * Fn.sin(inner) - Fn.sin(u3(inner))) /
            IntegerNumber.of(4),
      (false, 3) =>
        (IntegerNumber.of(3) * Fn.cos(inner) + Fn.cos(u3(inner))) /
            IntegerNumber.of(4),
      (true, 4) =>
        (IntegerNumber.of(3) -
                IntegerNumber.of(4) * Fn.cos(u2(inner)) +
                Fn.cos(u4(inner))) /
            IntegerNumber.of(8),
      (false, 4) =>
        (IntegerNumber.of(3) +
                IntegerNumber.of(4) * Fn.cos(u2(inner)) +
                Fn.cos(u4(inner))) /
            IntegerNumber.of(8),
      (true, 5) =>
        (IntegerNumber.of(10) * Fn.sin(inner) -
                IntegerNumber.of(5) * Fn.sin(u3(inner)) +
                Fn.sin(u5(inner))) /
            IntegerNumber.of(16),
      (false, 5) =>
        (IntegerNumber.of(10) * Fn.cos(inner) +
                IntegerNumber.of(5) * Fn.cos(u3(inner)) +
                Fn.cos(u5(inner))) /
            IntegerNumber.of(16),
      (true, 6) =>
        (IntegerNumber.of(10) -
                IntegerNumber.of(15) * Fn.cos(u2(inner)) +
                IntegerNumber.of(6) * Fn.cos(u4(inner)) -
                Fn.cos(u6(inner))) /
            IntegerNumber.of(32),
      (false, 6) =>
        (IntegerNumber.of(10) +
                IntegerNumber.of(15) * Fn.cos(u2(inner)) +
                IntegerNumber.of(6) * Fn.cos(u4(inner)) +
                Fn.cos(u6(inner))) /
            IntegerNumber.of(32),
      _ => null,
    };
  }
  return null;
}

({Expr aSin, Expr bCos, Expr cConst, Expr? inner})? extractLinearTrigCombo(
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
        _ => Mul.of(constFactors).simplify(),
      };
    }
    switch (varPart) {
      case Call(id: FunctionId.sin, args: [final arg]):
        if (inner == null) {
          inner = arg;
        } else if (inner != arg) {
          return null;
        }
        aSin = (aSin + coeff).simplify();
      case Call(id: FunctionId.cos, args: [final arg]):
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

Expr? collectAffineTrigInner(Expr node, String variable) {
  Expr? found;
  var valid = true;
  void scan(Expr n) {
    if (!valid || !n.dependsOn(variable)) return;
    switch (n) {
      case Call(
        id: FunctionId.sin || FunctionId.cos || FunctionId.tan,
        args: [final expr],
      ):
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

Expr replaceTrigWithWeierstrass(Expr node, Expr inner, Variable tVar) {
  if (node is Call && node.args[0] == inner) {
    if (node.id == FunctionId.sin) {
      return (IntegerNumber.two * tVar) / (IntegerNumber.one + tVar * tVar);
    }
    if (node.id == FunctionId.cos) {
      return (IntegerNumber.one - tVar * tVar) /
          (IntegerNumber.one + tVar * tVar);
    }
    if (node.id == FunctionId.tan) {
      return (IntegerNumber.two * tVar) / (IntegerNumber.one - tVar * tVar);
    }
  }
  return node.mapChildren((c) => replaceTrigWithWeierstrass(c, inner, tVar));
}

Expr replaceTrigWithTan(Expr node, Expr inner, Variable tVar) {
  if (node is Call && node.id == FunctionId.tan && node.args[0] == inner) {
    return tVar;
  }
  if (node
      case Pow(
        base: Call(id: FunctionId.sin, args: [final arg]),
        exponent: IntegerNumber(asInt: final n?),
      )
      when arg == inner && n.isEven) {
    return Pow.of(
      (tVar * tVar) / (IntegerNumber.one + tVar * tVar),
      IntegerNumber.of(n ~/ 2),
    );
  }
  if (node
      case Pow(
        base: Call(id: FunctionId.cos, args: [final arg]),
        exponent: IntegerNumber(asInt: final n?),
      )
      when arg == inner && n.isEven) {
    return Pow.of(
      IntegerNumber.one / (IntegerNumber.one + tVar * tVar),
      IntegerNumber.of(n ~/ 2),
    );
  }
  if (node is Mul) {
    var p = 0;
    var q = 0;
    final otherFactors = <Expr>[];
    final sinCosFactors = <Expr>[];
    for (final f in node.factors) {
      if (f is Call && f.id == FunctionId.sin && f.args[0] == inner) {
        p += 1;
        sinCosFactors.add(f);
      } else if (f is Call && f.id == FunctionId.cos && f.args[0] == inner) {
        q += 1;
        sinCosFactors.add(f);
      } else if (f
          case Pow(
            base: Call(id: FunctionId.sin, args: [final arg]),
            exponent: IntegerNumber(asInt: final n?),
          )
          when arg == inner) {
        p += n;
        sinCosFactors.add(f);
      } else if (f
          case Pow(
            base: Call(id: FunctionId.cos, args: [final arg]),
            exponent: IntegerNumber(asInt: final n?),
          )
          when arg == inner) {
        q += n;
        sinCosFactors.add(f);
      } else {
        otherFactors.add(replaceTrigWithTan(f, inner, tVar));
      }
    }
    if ((p != 0 || q != 0) && (p + q).isEven) {
      final tPart = p == 0
          ? IntegerNumber.one
          : Pow.of(tVar, IntegerNumber.of(p));
      final secPart = -(p + q) ~/ 2 == 0
          ? IntegerNumber.one
          : Pow.of(
              IntegerNumber.one + tVar * tVar,
              IntegerNumber.of(-(p + q) ~/ 2),
            );
      return Mul.of([tPart, secPart, ...otherFactors]).simplify();
    }
    return Mul.of([
      for (final f in sinCosFactors) replaceTrigWithTan(f, inner, tVar),
      ...otherFactors,
    ]).simplify();
  }
  return node.mapChildren((c) => replaceTrigWithTan(c, inner, tVar));
}

/// Rewrites even-degree hyperbolic expressions in [inner] as rational
/// functions of `tVar = tanh(inner)`.
Expr replaceHypWithTanh(Expr node, Expr inner, Variable tVar) {
  if (node is Call && node.id == FunctionId.tanh && node.args[0] == inner) {
    return tVar;
  }
  final oneMT2 = (IntegerNumber.one - tVar * tVar).simplify();
  if (node
      case Pow(
        base: Call(id: FunctionId.sinh, args: [final arg]),
        exponent: IntegerNumber(asInt: final n?),
      )
      when arg == inner && n.isEven) {
    return Pow.of((tVar * tVar) / oneMT2, IntegerNumber.of(n ~/ 2));
  }
  if (node
      case Pow(
        base: Call(id: FunctionId.cosh, args: [final arg]),
        exponent: IntegerNumber(asInt: final n?),
      )
      when arg == inner && n.isEven) {
    return Pow.of(IntegerNumber.one / oneMT2, IntegerNumber.of(n ~/ 2));
  }
  if (node is Mul) {
    var p = 0;
    var q = 0;
    final otherFactors = <Expr>[];
    final hypFactors = <Expr>[];
    for (final f in node.factors) {
      if (f is Call && f.id == FunctionId.sinh && f.args[0] == inner) {
        p += 1;
        hypFactors.add(f);
      } else if (f is Call && f.id == FunctionId.cosh && f.args[0] == inner) {
        q += 1;
        hypFactors.add(f);
      } else if (f
          case Pow(
            base: Call(id: FunctionId.sinh, args: [final arg]),
            exponent: IntegerNumber(asInt: final n?),
          )
          when arg == inner) {
        p += n;
        hypFactors.add(f);
      } else if (f
          case Pow(
            base: Call(id: FunctionId.cosh, args: [final arg]),
            exponent: IntegerNumber(asInt: final n?),
          )
          when arg == inner) {
        q += n;
        hypFactors.add(f);
      } else {
        otherFactors.add(replaceHypWithTanh(f, inner, tVar));
      }
    }
    if ((p != 0 || q != 0) && (p + q).isEven) {
      final tPart = p == 0
          ? IntegerNumber.one
          : Pow.of(tVar, IntegerNumber.of(p));
      final coshPart = -(p + q) ~/ 2 == 0
          ? IntegerNumber.one
          : Pow.of(oneMT2, IntegerNumber.of(-(p + q) ~/ 2));
      return Mul.of([tPart, coshPart, ...otherFactors]).simplify();
    }
    return Mul.of([
      for (final f in hypFactors) replaceHypWithTanh(f, inner, tVar),
      ...otherFactors,
    ]).simplify();
  }
  return node.mapChildren((c) => replaceHypWithTanh(c, inner, tVar));
}

Expr? collectAffineHypInner(Expr node, String variable) {
  Expr? found;
  final expExponents = <Expr>[];
  var valid = true;
  void scan(Expr n) {
    if (!valid || !n.dependsOn(variable)) return;
    switch (n) {
      case Call(
        id: FunctionId.sinh || FunctionId.cosh || FunctionId.tanh,
        args: [final expr],
      ):
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

Expr replaceHypWithExp(Expr node, Expr inner, Variable wVar) {
  if (node is Call && node.args[0] == inner) {
    if (node.id == FunctionId.sinh) {
      return (wVar - IntegerNumber.one / wVar) / IntegerNumber.two;
    }
    if (node.id == FunctionId.cosh) {
      return (wVar + IntegerNumber.one / wVar) / IntegerNumber.two;
    }
    if (node.id == FunctionId.tanh) {
      return (wVar * wVar - IntegerNumber.one) /
          (wVar * wVar + IntegerNumber.one);
    }
  }
  if (node case Pow(base: Constant.e, :final exponent)) {
    final vName = inner.freeVariables.length == 1
        ? inner.freeVariables.first
        : null;
    if (vName != null && exponent.dependsOn(vName)) {
      if ((inner.matchLinear(vName), exponent.matchLinear(vName)) case (
        final linInner?,
        final linExp?,
      )) {
        final kExpr = (linExp.a / linInner.a).simplify();
        if (kExpr is IntegerNumber) {
          final shift = (linExp.b - kExpr * linInner.b).simplify();
          final wPow = Pow.of(wVar, kExpr);
          return (shift is Number && shift.isZero)
              ? wPow
              : (Pow.of(Constant.e, shift) * wPow);
        }
      }
    }
  }
  return node.mapChildren((c) => replaceHypWithExp(c, inner, wVar));
}

Expr? tryDirichletKernel(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
}) {
  if (expr is! Mul) return null;
  var scale = IntegerNumber.one as Expr;
  Call? numSin;
  Call? denSin;
  for (final f in expr.factors) {
    if (!f.dependsOn(variable)) {
      scale = (scale * f).simplify(assumptions: assumptions);
    } else if (f is Call && f.id == FunctionId.sin && numSin == null) {
      numSin = f;
    } else if (f
        case Pow(
          base: final Call s && Call(id: FunctionId.sin),
          exponent: IntegerNumber(isNegativeOne: true),
        )
        when denSin == null) {
      denSin = s;
    } else {
      return null;
    }
  }
  if (numSin == null || denSin == null) return null;
  final linDen = denSin.args[0].matchLinear(variable);
  final linNum = numSin.args[0].matchLinear(variable);
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

  final u = denSin.args[0];
  final a = linDen.a;
  final terms = <Expr>[];
  if (n.isOdd) {
    terms.add(u);
    final m = (n - 1) ~/ 2;
    for (var j = 1; j <= m; j++) {
      terms.add(
        Fn.sin((IntegerNumber.of(2 * j) * u).simplify()) / IntegerNumber.of(j),
      );
    }
  } else {
    final m = n ~/ 2;
    for (var j = 1; j <= m; j++) {
      final coeff = IntegerNumber.of(2 * j - 1);
      terms.add((IntegerNumber.two * Fn.sin((coeff * u).simplify())) / coeff);
    }
  }
  return (scale * Add.of(terms) / a).simplify(assumptions: assumptions);
}

bool hasMultipleAngleTrig(Expr node, String variable) {
  final args = <Expr>{};
  var valid = true;
  void scan(Expr n) {
    if (!valid || !n.dependsOn(variable)) return;
    switch (n) {
      case Call(
        id: FunctionId.sin || FunctionId.cos || FunctionId.tan,
        args: [final expr],
      ):
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

Expr? tryTrigPolyDivision(
  Expr expr,
  Expr inner,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  if (depth >= 2) return null;
  const sName = '_s';
  const sVar = Variable(sName);

  Expr replaceRecipAtom(Expr node, Expr trigAtom) {
    if (node == trigAtom) return IntegerNumber.one / sVar;
    if (node case Pow(base: final b, exponent: IntegerNumber(asInt: final k?))
        when b == trigAtom) {
      return Pow.of(sVar, IntegerNumber.of(-k));
    }
    return node.mapChildren((c) => replaceRecipAtom(c, trigAtom));
  }

  Expr replaceWithPythagorean(Expr node, Expr mainAtom, Expr pythAtom) {
    if (node == mainAtom) return sVar;
    if (node case Pow(base: final b, exponent: IntegerNumber(asInt: final k?))
        when b == pythAtom && k.isEven) {
      final halfK = k ~/ 2;
      final oneMinusS2 = IntegerNumber.one - sVar * sVar;
      return halfK == 1
          ? oneMinusS2
          : Pow.of(oneMinusS2, IntegerNumber.of(halfK));
    }
    return node.mapChildren(
      (c) => replaceWithPythagorean(c, mainAtom, pythAtom),
    );
  }

  final sinInner = Fn.sin(inner);
  final cosInner = Fn.cos(inner);
  final candidates = <(Expr atom, Expr Function(Expr) replacer)>[
    (sinInner, (e) => replaceWithPythagorean(e, sinInner, cosInner)),
    (cosInner, (e) => replaceWithPythagorean(e, cosInner, sinInner)),
    (
      Pow.of(cosInner, IntegerNumber.negativeOne),
      (e) => replaceRecipAtom(e, cosInner),
    ),
    (
      Pow.of(sinInner, IntegerNumber.negativeOne),
      (e) => replaceRecipAtom(e, sinInner),
    ),
  ];

  for (final (atom, replacer) in candidates) {
    final replaced = replacer(expr);
    if (replaced.dependsOn(variable)) continue;
    final combined = replaced.together(assumptions: assumptions);
    final (numS, denS) = splitNumeratorDenominator(combined);
    final degNum = polynomialDegree(numS, sName);
    final degDen = polynomialDegree(denS, sName);
    if (degNum != null &&
        degDen != null &&
        degDen >= 1 &&
        degDen <= 4 &&
        degNum >= degDen) {
      final numExp = numS.expand().simplify(assumptions: assumptions);
      final denExp = denS.expand().simplify(assumptions: assumptions);
      final (:quotient, :remainder) = numExp.polynomialDivide(
        denExp,
        sName,
        assumptions: assumptions,
      );
      final qExpr = quotient
          .substitute(sName, atom)
          .simplify(assumptions: assumptions);
      final qRes = antiDerivative(
        qExpr,
        variable,
        depth: depth + 1,
        assumptions: assumptions,
      );
      if (hasUnevaluatedIntegral(qRes, variable)) continue;
      if (remainder is Number && remainder.isZero) return qRes;
      final rExpr = (remainder / denExp)
          .substitute(sName, atom)
          .simplify(assumptions: assumptions);
      var rRes = antiDerivative(
        rExpr,
        variable,
        depth: depth + 1,
        assumptions: assumptions,
      );
      if (hasUnevaluatedIntegral(rRes, variable)) {
        rRes =
            tryRationalTrigSubstitution(
              rExpr,
              variable,
              assumptions: assumptions,
              depth: depth + 1,
            ) ??
            rRes;
      }
      if (!hasUnevaluatedIntegral(rRes, variable)) {
        return (qRes + rRes).simplify(assumptions: assumptions);
      }
    }
  }
  return null;
}

/// Integrates products `scale * f(u)^n * g(u)^(2*k + 1)` where `n` is symbolic
/// (or numeric), `0 <= k <= 6`, `u` is linear in [variable], and `(f, g)` is
/// `(sin, cos)`, `(cos, sin)`, `(sinh, cosh)`, or `(cosh, sinh)`.
Expr? trySymbolicTrigPowerProduct(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
}) {
  final factors = expr is Mul ? expr.factors : [expr];
  var scale = IntegerNumber.one as Expr;
  final varFactors = <({Expr base, Expr exp})>[];

  for (final f in factors) {
    if (!f.dependsOn(variable)) {
      scale = (scale * f).simplify(assumptions: assumptions);
      continue;
    }
    if (f case Pow(:final base, :final exponent)) {
      if (exponent.dependsOn(variable)) return null;
      varFactors.add((base: base, exp: exponent));
    } else {
      varFactors.add((base: f, exp: IntegerNumber.one));
    }
  }

  if (varFactors.length != 2) return null;

  bool isTrigOrHyp(Expr e) =>
      e is Call &&
      const {
        FunctionId.sin,
        FunctionId.cos,
        FunctionId.sinh,
        FunctionId.cosh,
      }.contains(e.id);
  Expr? innerOf(Expr e) => switch (e) {
    Call(
      id: FunctionId.sin ||
          FunctionId.cos ||
          FunctionId.sinh ||
          FunctionId.cosh,
      args: [final expr],
    ) =>
      expr,
    _ => null,
  };

  final f0 = varFactors[0];
  final f1 = varFactors[1];
  if (!isTrigOrHyp(f0.base) || !isTrigOrHyp(f1.base)) return null;

  final u0 = innerOf(f0.base);
  final u1 = innerOf(f1.base);
  if (u0 == null || u0 != u1) return null;
  final lin = u0.matchLinear(variable);
  if (lin == null) return null;
  final slope = lin.a;

  // Pick which factor is g^(2k+1) and which is f^n
  final ({Expr base, Expr exp}) fPair;
  final ({Expr base, Expr exp}) gPair;
  if (f1.exp case IntegerNumber(asInt: final m?)
      when m >= 1 && m <= 13 && m.isOdd) {
    fPair = f0;
    gPair = f1;
  } else if (f0.exp case IntegerNumber(asInt: final m?)
      when m >= 1 && m <= 13 && m.isOdd) {
    fPair = f1;
    gPair = f0;
  } else {
    return null;
  }

  final fBase = fPair.base as Call;
  final gBase = gPair.base as Call;
  final n = fPair.exp;
  final k = ((gPair.exp as IntegerNumber).asInt! - 1) ~/ 2;

  // Determine (prefactor, signPattern):
  // signMode: 0 -> all +1 (Sinh/Cosh), 1 -> (-1)^j (Sin/Cos, Cos/Sin), 2 -> (-1)^(k-j) (Cosh/Sinh)
  final Expr prefactor;
  final int signMode;
  if (fBase.id == FunctionId.sin && gBase.id == FunctionId.cos) {
    prefactor = (scale / slope).simplify(assumptions: assumptions);
    signMode = 1;
  } else if (fBase.id == FunctionId.cos && gBase.id == FunctionId.sin) {
    prefactor = (-scale / slope).simplify(assumptions: assumptions);
    signMode = 1;
  } else if (fBase.id == FunctionId.sinh && gBase.id == FunctionId.cosh) {
    prefactor = (scale / slope).simplify(assumptions: assumptions);
    signMode = 0;
  } else if (fBase.id == FunctionId.cosh && gBase.id == FunctionId.sinh) {
    prefactor = (scale / slope).simplify(assumptions: assumptions);
    signMode = 2;
  } else {
    return null;
  }

  final terms = <Expr>[];
  for (var j = 0; j <= k; j++) {
    final binom = IntegerNumber.of(k.binomial(j));
    final isNeg = switch (signMode) {
      1 => j.isOdd,
      2 => (k - j).isOdd,
      _ => false,
    };
    final coeff = isNeg ? -binom : binom;
    final exp = (n + IntegerNumber.of(2 * j + 1)).simplify(
      assumptions: assumptions,
    );
    if (exp is Number && exp.isZero) {
      terms.add(coeff * logAntiderivative(fBase, assumptions));
    } else {
      terms.add(coeff * Pow.of(fBase, exp) / exp);
    }
  }

  return (prefactor * Add.of(terms)).simplify(assumptions: assumptions);
}
