import 'dart:math' as math;

import '../algebra/expand.dart';
import '../algebra/factor.dart';
import '../algebra/simplify.dart';
import '../algebra/simplify/domain.dart';
import '../algebra/trig.dart';
import '../assumptions.dart';
import '../ast.dart';
import '../calculus/linear_form.dart';
import '../compiler.dart';
import '../functions/fn.dart';
import '../type/expr_data_type.dart';
import 'transcendental.dart';
import 'trigonometric.dart';
import 'univariate.dart';

List<Expr>? solveLambertWEquation(
  Expr E,
  Expr cPrime,
  String variable, {
  required Assumptions assumptions,
}) {
  final cVal = tryEvalReal(cPrime);
  const invE = 1.0 / math.e;
  final negInvE = (-Pow.of(Constant.e, IntegerNumber.negativeOne)).simplify();
  final List<Expr> targets;
  if (cPrime == negInvE) {
    targets = [IntegerNumber.negativeOne];
  } else if (cVal != null) {
    if (cVal < -invE - 1e-12) {
      return const [];
    } else if (cVal >= 0.0) {
      targets = [Fn.lambertW(cPrime)];
    } else {
      targets = [
        Fn.lambertW(cPrime),
        Fn.lambertW(cPrime, IntegerNumber.negativeOne),
      ];
    }
  } else if (isNonNegativeExpr(cPrime, assumptions: assumptions) ||
      cPrime.anyNode((n) => n is ComplexNumber && !n.imaginary.isZero)) {
    targets = [Fn.lambertW(cPrime)];
  } else {
    targets = [
      Fn.lambertW(cPrime),
      Fn.lambertW(cPrime, IntegerNumber.negativeOne),
    ];
  }

  final solutions = <Expr>[];
  for (final w in targets) {
    final subSolutions = solveEquation(
      (E - w).simplify(assumptions: assumptions),
      variable,
      assumptions: assumptions,
    );
    solutions.addAll(subSolutions);
  }
  return deduplicateRoots(solutions, assumptions: assumptions);
}

List<Expr>? solveProductTranscendental(
  Mul u,
  Expr c,
  String variable, {
  required Assumptions assumptions,
}) {
  if (u.factors case [final f0, final f1]) {
    for (final (a, b) in [(f0, f1), (f1, f0)]) {
      if (a case Pow(:final base, :final exponent) when base == Constant.e) {
        final ratio = (exponent / b).simplify(assumptions: assumptions);
        if (!ratio.dependsOn(variable) && !(ratio is Number && ratio.isZero)) {
          final cPrime = (c * ratio).simplify(assumptions: assumptions);
          return solveLambertWEquation(
            exponent,
            cPrime,
            variable,
            assumptions: assumptions,
          );
        }
      }
      if (a case Call(id: FunctionId.ln, args: [final expr])) {
        if (b
            case Pow(
              base: final powBase,
              exponent: IntegerNumber(isNegativeOne: true),
            )
            when powBase == expr && expr.dependsOn(variable)) {
          return solveLambertWEquation(
            (-Fn.ln(expr)).simplify(assumptions: assumptions),
            (-c).simplify(assumptions: assumptions),
            variable,
            assumptions: assumptions,
          );
        }
        final ratio = (expr / b).simplify(assumptions: assumptions);
        if (!ratio.dependsOn(variable) && !(ratio is Number && ratio.isZero)) {
          final cPrime = (c * ratio).simplify(assumptions: assumptions);
          return solveLambertWEquation(
            Fn.ln(expr).simplify(assumptions: assumptions),
            cPrime,
            variable,
            assumptions: assumptions,
          );
        }
      }
    }
  }
  return null;
}

List<Expr>? solveAddTranscendental(
  Add u,
  Expr c,
  String variable, {
  required Assumptions assumptions,
}) {
  if (u.terms case [final t0, final t1]) {
    for (final (a, b) in [(t0, t1), (t1, t0)]) {
      final (Expr? lnArg, Expr k) = switch (a) {
        Call(id: FunctionId.ln, args: [final expr]) => (
          expr,
          IntegerNumber.one,
        ),
        Mul(:final factors) => () {
          Expr? arg;
          final constFactors = <Expr>[];
          for (final f in factors) {
            if (arg == null && f is Call && f.id == FunctionId.ln) {
              arg = f.args[0];
            } else if (!f.dependsOn(variable)) {
              constFactors.add(f);
            } else {
              return (null, IntegerNumber.one);
            }
          }
          if (arg == null) return (null, IntegerNumber.one);
          final coeff = switch (constFactors) {
            [] => IntegerNumber.one,
            [final single] => single,
            _ => Mul.of(constFactors).simplify(assumptions: assumptions),
          };
          return (arg, coeff);
        }(),
        _ => (null, IntegerNumber.one),
      };
      if (lnArg != null && !(b is Call && b.id == FunctionId.ln)) {
        final ratio = (b / (k * lnArg)).simplify(assumptions: assumptions);
        if (!ratio.dependsOn(variable) && !(ratio is Number && ratio.isZero)) {
          final cOverK = (c / k).simplify(assumptions: assumptions);
          final cPrime = (ratio * Pow.of(Constant.e, cOverK)).simplify(
            assumptions: assumptions,
          );
          return solveLambertWEquation(
            (b / k).simplify(assumptions: assumptions),
            cPrime,
            variable,
            assumptions: assumptions,
          );
        }
      }
    }
  }
  return null;
}

List<Expr>? matchAffineExponential(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
}) {
  final terms = <Expr>[];
  _collectAdditiveTerms(expr, terms);
  if (terms.length < 2) return null;

  ({Expr base, Expr exponent, Expr coeff})? expTerm;
  ({Expr coeff, Expr constant})? linTerm;
  Expr constSum = IntegerNumber.zero;

  for (final t in terms) {
    if (!t.dependsOn(variable)) {
      constSum = (constSum + t).simplify(assumptions: assumptions);
      continue;
    }

    if (t.matchLinear(variable) case (:final a, :final b)
        when !(a is Number && a.isZero)) {
      if (linTerm != null) return null;
      linTerm = (coeff: a, constant: b);
      continue;
    }

    final matchedExp = _extractExponentialTerm(t, variable);
    if (matchedExp != null) {
      if (expTerm != null) return null;
      expTerm = matchedExp;
      continue;
    }

    return null;
  }

  if (expTerm == null || linTerm == null) return null;

  final (:base, :exponent, coeff: k1) = expTerm;
  if (isZeroExpr(base) || base == IntegerNumber.one) return null;
  final bVal = tryEvalReal(base);
  if (bVal != null && (bVal <= 0.0 || bVal == 1.0)) return null;

  final (coeff: k2, constant: linConst) = linTerm;
  final k3 = (constSum + linConst).simplify(assumptions: assumptions);

  final expLin = exponent.matchLinear(variable);
  if (expLin == null) {
    return null;
  }
  final (a: alpha, b: beta) = expLin;

  final B = (-k2 / (k1 * alpha)).simplify(assumptions: assumptions);
  final C = (-(k3 - (k2 * beta / alpha)) / k1).simplify(
    assumptions: assumptions,
  );

  final lnBase = Fn.ln(base).simplify(assumptions: assumptions);
  if (isZeroExpr(lnBase)) return null;
  final negCdivB = (-C / B).simplify(assumptions: assumptions);
  final wArg =
      ((-lnBase / B) *
              Pow.of(
                Constant.e,
                (-C * lnBase / B).simplify(assumptions: assumptions),
              ))
          .simplify(assumptions: assumptions);

  final wVal = tryEvalReal(wArg);
  const invE = 1.0 / math.e;
  final negInvE = (-Pow.of(Constant.e, IntegerNumber.negativeOne)).simplify();
  final List<int> branches;
  if (wArg == negInvE) {
    branches = const [0];
  } else if (wVal != null) {
    if (wVal < -invE - 1e-12) {
      return const [];
    } else if (wVal >= 0.0) {
      branches = const [0];
    } else {
      branches = const [0, -1];
    }
  } else if (isNonNegativeExpr(wArg, assumptions: assumptions) ||
      wArg.anyNode((n) => n is ComplexNumber && !n.imaginary.isZero)) {
    branches = const [0];
  } else {
    branches = const [0, -1];
  }

  final roots = <Expr>[];
  for (final branch in branches) {
    final wTerm = wArg == negInvE
        ? IntegerNumber.negativeOne
        : (branch == 0
              ? Fn.lambertW(wArg)
              : Fn.lambertW(wArg, IntegerNumber.of(branch)));
    final y = (negCdivB - (wTerm / lnBase)).simplify(assumptions: assumptions);
    final x = ((y - beta) / alpha).simplify(assumptions: assumptions);
    roots.add(x);
  }
  return deduplicateRoots(roots, assumptions: assumptions);
}

double? tryEvalReal(Expr expr) {
  switch (expr) {
    case RationalNumber():
      return expr.toDouble();
    case RealNumber(:final value):
      return value;
    case _ when expr.freeVariables.isEmpty:
      try {
        final v = expr.evaluate(const {});
        if (v.isFinite) return v;
      } on ArgumentError {
        // Ignored.
      } on UnsupportedError {
        // Ignored.
      }
    case _:
      break;
  }
  return null;
}

List<Expr>? tryCombineLogsAndSolve(
  List<Expr> terms,
  String variable, {
  required Assumptions assumptions,
}) {
  final lnTerms = <({Expr u, RationalNumber coeff})>[];
  final rest = <Expr>[];
  for (final t in terms) {
    switch (t) {
      case Call(id: FunctionId.ln, args: [final expr]):
        lnTerms.add((u: expr, coeff: IntegerNumber.one));
      case Mul(
        factors: [
          final RationalNumber a,
          Call(id: FunctionId.ln, args: [final expr]),
        ],
      ):
        lnTerms.add((u: expr, coeff: a));
      default:
        rest.add(t);
    }
  }
  if (lnTerms.length < 2 || !lnTerms.any((e) => e.u.dependsOn(variable))) {
    return null;
  }
  if (rest.any((r) => r.dependsOn(variable))) {
    return null;
  }

  var prod = IntegerNumber.one as Expr;
  for (final (:u, :coeff) in lnTerms) {
    final term = coeff.isOne
        ? u
        : Pow.of(u, coeff).simplify(assumptions: assumptions);
    prod = (prod * term).simplify(assumptions: assumptions);
  }
  final combined = Add.of([
    Fn.ln(prod).simplify(assumptions: assumptions),
    ...rest,
  ]).simplify(assumptions: assumptions);
  final candidates = solveEquation(
    combined,
    variable,
    assumptions: assumptions,
  );
  return candidates.where((root) {
    for (final (:u, coeff: _) in lnTerms) {
      if (!u.dependsOn(variable)) continue;
      final uVal = u
          .substitute(variable, root)
          .simplify(assumptions: assumptions);
      if (isZeroExpr(uVal) || isNegativeExpr(uVal, assumptions: assumptions)) {
        return false;
      }
      if (isPositiveExpr(uVal, assumptions: assumptions)) continue;
      if (uVal.freeVariables.isNotEmpty) continue;
      final numVal = tryEvalReal(uVal);
      if (numVal == null || numVal <= 0.0) return false;
    }
    return true;
  }).toList();
}

List<Expr>? tryIsolateRadicalAndSolve(
  List<Expr> terms,
  String variable, {
  required Assumptions assumptions,
}) {
  ({Expr c, Expr base, int p, int q})? radical;
  final rest = <Expr>[];

  for (final t in terms) {
    if (!_hasVariableRadical(t, variable)) {
      rest.add(t);
      continue;
    }
    if (radical != null) return null;
    if (t
        case Pow(
          :final base,
          exponent: FractionNumber(:final numerator, :final denominator),
        )
        when base.dependsOn(variable)) {
      if (numerator == BigInt.zero ||
          numerator.abs() > BigInt.from(12) ||
          denominator < BigInt.two ||
          denominator > BigInt.from(4)) {
        return null;
      }
      radical = (
        c: IntegerNumber.one,
        base: base,
        p: numerator.toInt(),
        q: denominator.toInt(),
      );
    } else if (t case Mul(:final factors)) {
      Expr? radBase;
      int? radP;
      int? radQ;
      final otherFactors = <Expr>[];
      for (final f in factors) {
        if (f
            case Pow(
              :final base,
              exponent: FractionNumber(:final numerator, :final denominator),
            )
            when base.dependsOn(variable)) {
          if (radBase != null) return null;
          if (numerator == BigInt.zero ||
              numerator.abs() > BigInt.from(12) ||
              denominator < BigInt.two ||
              denominator > BigInt.from(4)) {
            return null;
          }
          radBase = base;
          radP = numerator.toInt();
          radQ = denominator.toInt();
        } else if (_hasVariableRadical(f, variable)) {
          return null;
        } else {
          otherFactors.add(f);
        }
      }
      if (radBase == null || radP == null || radQ == null) return null;
      final c = switch (otherFactors) {
        [] => IntegerNumber.one,
        [final single] => single,
        _ => Mul.of(otherFactors).simplify(assumptions: assumptions),
      };
      radical = (c: c, base: radBase, p: radP, q: radQ);
    } else {
      return null;
    }
  }

  if (radical == null || rest.isEmpty) return null;
  final (:c, :base, :p, :q) = radical;
  final r = rest.length == 1
      ? rest.single
      : Add.of(rest).simplify(assumptions: assumptions);
  final negR = (-r).simplify(assumptions: assumptions);
  final lhs = p > 0
      ? Pow.of(c, IntegerNumber.of(q)) * Pow.of(base, IntegerNumber.of(p))
      : Pow.of(c, IntegerNumber.of(q));
  final rhs = p > 0
      ? Pow.of(negR, IntegerNumber.of(q))
      : Pow.of(negR, IntegerNumber.of(q)) * Pow.of(base, IntegerNumber.of(-p));
  final poly = (lhs - rhs)
      .expand(assumptions: assumptions)
      .simplify(assumptions: assumptions);
  return solveEquation(poly, variable, assumptions: assumptions);
}

List<Expr>? tryPolynomialInExponential(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
}) {
  final expNodes = <({Pow node, Expr base, RationalNumber alpha, Expr beta})>[];

  void collect(Expr e) {
    if (e case Pow(:final base, :final exponent)) {
      if (!base.dependsOn(variable) && exponent.dependsOn(variable)) {
        final lin = exponent.matchLinear(variable);
        if (lin != null) {
          if (lin.a case final RationalNumber alpha when !alpha.isZero) {
            expNodes.add((node: e, base: base, alpha: alpha, beta: lin.b));
            return;
          }
        }
      }
    }
    e.mapChildren((c) {
      collect(c);
      return c;
    });
  }

  collect(expr);
  if (expNodes.isEmpty) return null;

  final commonBase = expNodes.first.base;
  if (isZeroExpr(commonBase) || commonBase == IntegerNumber.one) return null;
  final baseVal = tryEvalReal(commonBase);
  if (baseVal != null && (baseVal <= 0.0 || baseVal == 1.0)) return null;

  var hasPos = false;
  var hasNeg = false;
  for (final entry in expNodes) {
    if (entry.base != commonBase) return null;
    if (entry.alpha.sign > 0) {
      hasPos = true;
    } else if (entry.alpha.sign < 0) {
      hasNeg = true;
    }
  }
  final uniformNeg = hasNeg && !hasPos;

  // Fundamental rational slope alpha0
  var gcdNum = expNodes.first.alpha.numerator.abs();
  var lcmDen = expNodes.first.alpha.denominator;
  for (var i = 1; i < expNodes.length; i++) {
    final r = expNodes[i].alpha;
    final numAbs = r.numerator.abs();
    gcdNum = gcdNum.gcd(numAbs);
    lcmDen = (lcmDen ~/ lcmDen.gcd(r.denominator)) * r.denominator;
  }
  final alpha0 = RationalNumber.of(uniformNeg ? -gcdNum : gcdNum, lcmDen);

  const uName = '_u_exp';
  const uVar = Variable(uName);
  final replacements = <Pow, Expr>{};
  var minM = 0;
  var maxM = 0;
  for (final (:node, :base, :alpha, :beta) in expNodes) {
    final ratio = alpha.divRational(alpha0);
    if (ratio is! IntegerNumber) return null;
    final m = ratio.asInt;
    if (m == null || m == 0 || m.abs() > 6) return null;
    if (m < minM) minM = m;
    if (m > maxM) maxM = m;
    final uPow = m == 1 ? uVar : Pow.of(uVar, IntegerNumber.of(m));
    final bScale = (beta is Number && beta.isZero)
        ? IntegerNumber.one
        : Pow.of(base, beta);
    replacements[node] = (bScale * uPow).simplify(
      assumptions: Assumptions.none,
    );
  }
  if (maxM - minM > 8) return null;

  Expr substituteExp(Expr e) {
    if (replacements[e] case final repl?) {
      return repl;
    }
    return e.mapChildren(substituteExp);
  }

  var polyU = substituteExp(expr);
  if (minM < 0) {
    polyU = (polyU * Pow.of(uVar, IntegerNumber.of(-minM))).expand(
      assumptions: assumptions,
    );
  }
  polyU = polyU.simplify(assumptions: assumptions);
  if (polyU.dependsOn(variable) || !polyU.dependsOn(uName)) return null;

  final uRoots = solveEquation(
    polyU,
    uName,
    assumptions: assumptions,
  ).where((r) => !isZeroExpr(r)).toList();
  if (uRoots.isEmpty) return const [];

  final targetPow = Pow.of(
    commonBase,
    (alpha0 * Variable(variable)).simplify(assumptions: assumptions),
  );
  final results = <Expr>[];
  final seen = <Expr>{};
  var anyUnsolved = false;
  for (final uRoot in uRoots) {
    final roots = invertEquation(
      targetPow,
      uRoot,
      variable,
      assumptions: assumptions,
    );
    if (roots == null) {
      anyUnsolved = true;
      continue;
    }
    for (final r in roots) {
      if (seen.add(r)) results.add(r);
    }
  }
  if (anyUnsolved && results.isEmpty) return null;
  return deduplicateRoots(results, assumptions: assumptions);
}

List<Expr>? tryPolynomialInFunction(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
}) {
  final fnNodes = <Expr>{};

  void collect(Expr e) {
    if (_isElementaryFunctionNode(e, variable)) {
      fnNodes.add(e);
      return;
    }
    e.mapChildren((c) {
      collect(c);
      return c;
    });
  }

  collect(expr);
  if (fnNodes.isEmpty) return null;

  const uName = '_u_fn';
  const uVar = Variable(uName);

  List<Expr>? solveSubstituted(Expr uNode, Expr polyU) {
    final simplified = polyU.simplify(assumptions: assumptions);
    if (simplified.dependsOn(variable) || !simplified.dependsOn(uName)) {
      return null;
    }
    final uRoots = solveEquation(simplified, uName, assumptions: assumptions);
    if (uRoots.isEmpty) return const [];
    final results = <Expr>[];
    var anyUnsolved = false;
    for (final uRoot in uRoots) {
      final roots = invertEquation(
        uNode,
        uRoot,
        variable,
        assumptions: assumptions,
      );
      if (roots == null) {
        anyUnsolved = true;
        continue;
      }
      results.addAll(roots);
    }
    if (anyUnsolved && results.isEmpty) return null;
    return deduplicateRoots(results, assumptions: assumptions);
  }

  if (fnNodes.length == 1) {
    final uNode = fnNodes.first;
    Expr subst(Expr e) => e == uNode ? uVar : e.mapChildren(subst);
    return solveSubstituted(uNode, subst(expr));
  }

  if (fnNodes.length == 2) {
    final list = fnNodes.toList();
    final (Call? sinNode, Call? cosNode) = switch ((list[0], list[1])) {
      (
        final Call s && Call(id: FunctionId.sin, args: [final sArg]),
        final Call c && Call(id: FunctionId.cos, args: [final cArg]),
      )
          when sArg == cArg =>
        (s, c),
      (
        final Call c && Call(id: FunctionId.cos, args: [final cArg]),
        final Call s && Call(id: FunctionId.sin, args: [final sArg]),
      )
          when sArg == cArg =>
        (s, c),
      _ => (null, null),
    };
    if (sinNode != null && cosNode != null) {
      Expr? tryPythagorean(Expr uNode, Expr otherNode) {
        var valid = true;
        Expr subst(Expr e) {
          if (!valid) return e;
          if (e == uNode) return uVar;
          if (e == otherNode) {
            valid = false;
            return e;
          }
          if (e
              case Pow(base: final b, exponent: IntegerNumber(asInt: final k?))
              when b == otherNode) {
            if (k < 2 || k.isOdd) {
              valid = false;
              return e;
            }
            final oneMinusU2 =
                IntegerNumber.one - Pow.of(uVar, IntegerNumber.two);
            return k == 2
                ? oneMinusU2
                : Pow.of(oneMinusU2, IntegerNumber.of(k ~/ 2));
          }
          return e.mapChildren(subst);
        }

        final replaced = subst(expr);
        return valid ? replaced : null;
      }

      if (tryPythagorean(cosNode, sinNode) case final polyCos?) {
        final res = solveSubstituted(cosNode, polyCos);
        if (res != null) return res;
      }
      if (tryPythagorean(sinNode, cosNode) case final polySin?) {
        final res = solveSubstituted(sinNode, polySin);
        if (res != null) return res;
      }
    }
  }

  return null;
}

List<Expr>? tryMultipleAngleTrig(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
}) {
  final trigAtoms = <Expr>{};
  void collectTrig(Expr e) {
    switch (e) {
      case Call(
            id: FunctionId.sin || FunctionId.cos || FunctionId.tan,
            args: [final arg],
          )
          when arg.dependsOn(variable):
        trigAtoms.add(e);
      default:
        e.mapChildren((c) {
          collectTrig(c);
          return c;
        });
    }
  }

  collectTrig(expr);
  if (trigAtoms.length < 2) return null;

  final expanded = expr.expandTrig(assumptions: assumptions);
  if (expanded == expr) return null;

  // Factor expanded expression with respect to its trigonometric atoms.
  final expandedAtoms = <Expr>[];
  final atomSet = <Expr>{};
  void collectExpandedTrig(Expr e) {
    switch (e) {
      case Call(
            id: FunctionId.sin || FunctionId.cos || FunctionId.tan,
            args: [final arg],
          )
          when arg.dependsOn(variable):
        if (atomSet.add(e)) expandedAtoms.add(e);
      default:
        e.mapChildren((c) {
          collectExpandedTrig(c);
          return c;
        });
    }
  }

  collectExpandedTrig(expanded);
  if (expandedAtoms.isNotEmpty) {
    final toPlaceholder = <Expr, Variable>{};
    final fromPlaceholder = <Variable, Expr>{};
    for (var i = 0; i < expandedAtoms.length; i++) {
      final v = Variable('_t_trig_$i');
      toPlaceholder[expandedAtoms[i]] = v;
      fromPlaceholder[v] = expandedAtoms[i];
    }
    Expr toPoly(Expr e) => toPlaceholder[e] ?? e.mapChildren(toPoly);
    Expr fromPoly(Expr e) =>
        e is Variable ? (fromPlaceholder[e] ?? e) : e.mapChildren(fromPoly);

    final poly = toPoly(expanded);
    if (!poly.dependsOn(variable)) {
      final factored = poly.factor(assumptions: Assumptions.none);
      if (factored case Mul(:final factors)) {
        final allRoots = <Expr>[];
        for (final f in factors) {
          final restored = fromPoly(f).simplify(assumptions: assumptions);
          if (!restored.dependsOn(variable)) continue;
          allRoots.addAll(
            solveEquation(restored, variable, assumptions: assumptions),
          );
        }
        return deduplicateRoots(allRoots);
      }
    }
  }

  final roots = solveEquation(expanded, variable, assumptions: assumptions);
  return roots.isEmpty ? null : deduplicateRoots(roots);
}

List<Expr>? tryHarmonicAddition(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
}) {
  if (expr is! Add) return null;
  final constTerms = <Expr>[];
  final sinCoeffs = <Expr>[];
  final cosCoeffs = <Expr>[];
  Expr? commonArg;

  for (final term in expr.terms) {
    if (!term.dependsOn(variable)) {
      constTerms.add(term);
      continue;
    }
    final factors = term is Mul ? term.factors : [term];
    Call? trigNode;
    final coeffFactors = <Expr>[];
    for (final f in factors) {
      if (!f.dependsOn(variable)) {
        coeffFactors.add(f);
      } else if (f is Call &&
          (f.id == FunctionId.sin || f.id == FunctionId.cos) &&
          trigNode == null) {
        trigNode = f;
      } else {
        return null;
      }
    }
    if (trigNode == null) return null;
    final arg = trigNode.args[0];
    if (arg.matchLinear(variable) == null) return null;
    if (commonArg == null) {
      commonArg = arg;
    } else if (commonArg != arg) {
      return null;
    }
    final coeff = coeffFactors.isEmpty
        ? IntegerNumber.one
        : Mul.of(coeffFactors).simplify(assumptions: assumptions);
    if (trigNode.id == FunctionId.sin) {
      sinCoeffs.add(coeff);
    } else {
      cosCoeffs.add(coeff);
    }
  }

  if (commonArg == null || sinCoeffs.isEmpty || cosCoeffs.isEmpty) {
    return null;
  }
  final a = Add.of(sinCoeffs).simplify(assumptions: assumptions);
  final b = Add.of(cosCoeffs).simplify(assumptions: assumptions);
  if (isZeroExpr(a) || isZeroExpr(b)) return null;
  final k = constTerms.isEmpty
      ? IntegerNumber.zero
      : Add.of(constTerms).simplify(assumptions: assumptions);

  bool hasComplexNode(Expr e) =>
      e.anyNode((n) => n is ComplexNumber && !n.imaginary.isZero);
  if (hasComplexNode(a) || hasComplexNode(b) || hasComplexNode(k)) {
    return null;
  }

  final rSq = (a * a + b * b).simplify(assumptions: assumptions);
  if (isZeroExpr(rSq)) return null;
  final rSqVal = tryEvalReal(rSq);
  if (rSqVal != null && rSqVal <= 1e-18) return null;

  final r = Pow.of(rSq, FractionNumber.half).simplify(assumptions: assumptions);
  if (isZeroExpr(r)) return null;

  final kVal = tryEvalReal(k);
  final rVal = tryEvalReal(r);
  if (kVal != null && rVal != null) {
    if (kVal.abs().isFinite && rVal.isFinite && kVal.abs() > rVal + 1e-12) {
      return const [];
    }
  }

  final Expr phi;
  final aVal = tryEvalReal(a);
  final bVal = tryEvalReal(b);
  if ((a is RealNumber || b is RealNumber) && aVal != null && bVal != null) {
    phi = RealNumber(math.atan2(bVal, aVal));
  } else {
    final ratio = (b / a).simplify(assumptions: assumptions);
    final baseAtan = Fn.atan(ratio).simplify(assumptions: assumptions);
    final aPos =
        isPositiveExpr(a, assumptions: assumptions) ||
        (aVal != null && aVal > 0);
    final aNeg =
        isNegativeExpr(a, assumptions: assumptions) ||
        (aVal != null && aVal < 0);
    if (aPos) {
      phi = baseAtan;
    } else if (aNeg) {
      final bNonNeg = bVal != null
          ? bVal >= 0
          : !isNegativeExpr(b, assumptions: assumptions);
      phi = (baseAtan + (bNonNeg ? Constant.pi : -Constant.pi)).simplify(
        assumptions: assumptions,
      );
    } else {
      return null;
    }
  }

  return invertSin(
    (commonArg + phi).simplify(assumptions: assumptions),
    (-k / r).simplify(assumptions: assumptions),
    variable,
    assumptions: assumptions,
  );
}

void _collectAdditiveTerms(Expr expr, List<Expr> terms) {
  switch (expr) {
    case Add(terms: final addTerms):
      for (final t in addTerms) {
        _collectAdditiveTerms(t, terms);
      }
    case _:
      terms.add(expr);
  }
}

({Expr base, Expr exponent, Expr coeff})? _extractExponentialTerm(
  Expr expr,
  String variable,
) {
  switch (expr) {
    case Pow(:final base, :final exponent)
        when !base.dependsOn(variable) && exponent.dependsOn(variable):
      return (base: base, exponent: exponent, coeff: IntegerNumber.one);
    case Mul(:final factors):
      final constFactors = <Expr>[];
      final varFactors = <Expr>[];
      for (final f in factors) {
        if (f.dependsOn(variable)) {
          varFactors.add(f);
        } else {
          constFactors.add(f);
        }
      }
      if (constFactors.isNotEmpty) {
        if (varFactors case [final singleVar]) {
          if (_extractExponentialTerm(singleVar, variable) case (
            :final base,
            :final exponent,
            :final coeff,
          )) {
            final constPart = switch (constFactors) {
              [final single] => single,
              _ => Mul.of(constFactors).simplify(),
            };
            return (
              base: base,
              exponent: exponent,
              coeff: (constPart * coeff).simplify(),
            );
          }
        }
      }
    case _:
      break;
  }
  return null;
}

bool _hasVariableRadical(Expr expr, String variable) => expr.anyNode(
  (n) => n is Pow && n.exponent is FractionNumber && n.base.dependsOn(variable),
);

bool _isElementaryFunctionNode(Expr e, String variable) => switch (e) {
  Call(
    id: FunctionId.ln ||
        FunctionId.sin ||
        FunctionId.cos ||
        FunctionId.tan ||
        FunctionId.sinh ||
        FunctionId.cosh ||
        FunctionId.tanh ||
        FunctionId.asin ||
        FunctionId.acos ||
        FunctionId.atan ||
        FunctionId.lambertW,
    :final args,
  ) =>
    args[0].dependsOn(variable),
  _ => false,
};
