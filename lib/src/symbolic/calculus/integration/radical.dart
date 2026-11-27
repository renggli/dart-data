import 'package:more/math.dart' show LcmIntegerExtension;

import '../../algebra/expand.dart';
import '../../algebra/helpers.dart';
import '../../algebra/rational.dart';
import '../../algebra/simplify.dart';
import '../../assumptions.dart';
import '../../ast.dart';
import '../../functions/fn.dart';
import '../../oracle/sign.dart';
import '../linear_form.dart';
import 'definite.dart';
import 'integration.dart';
import 'radical_binomial.dart';

/// Factors common monomials `x^m` or perfect-square trinomials out of
/// fractional-power radicands and delegates to [antiDerivative].
Expr? tryFactorRadicandPower(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  if (depth >= 2) return null;
  final factors = expr is Mul ? expr.factors : [expr];
  final xVar = Variable(variable);

  Expr rebuild(int idx, Expr replacement) => Mul.of([
    for (var j = 0; j < factors.length; j++)
      if (j == idx) replacement else factors[j],
  ]).simplify(assumptions: assumptions);

  for (var i = 0; i < factors.length; i++) {
    final factor = factors[i];
    if (factor case Pow(:final base, :final exponent)
        when base.dependsOn(variable) &&
            !exponent.dependsOn(variable) &&
            exponent is! IntegerNumber) {
      if (exponent is FractionNumber) {
        final k = halfIntExponent(exponent);
        if (k != null && k.isOdd && k.abs() <= 9 && base is Mul) {
          final varPart = [
            for (final f in base.factors)
              if (f.dependsOn(variable)) f,
          ];
          if (varPart.length == 1) {
            if (varPart.first case Pow(
              base: final f,
              exponent: IntegerNumber(asInt: 2),
            )) {
              final isLinearTrigOrHyp = switch (f) {
                Call(:final id, args: [final expr])
                    when id == FunctionId.sin ||
                        id == FunctionId.cos ||
                        id == FunctionId.tan ||
                        id == FunctionId.sinh ||
                        id == FunctionId.cosh ||
                        id == FunctionId.tanh =>
                  expr.matchLinear(variable) != null,
                _ => false,
              };
              if (isLinearTrigOrHyp) {
                final fPowK = Pow.of(
                  f,
                  IntegerNumber.of(k),
                ).simplify(assumptions: assumptions);
                final scaleFactor = (factor / fPowK).simplify(
                  assumptions: assumptions,
                );
                final rewritten = rebuild(i, fPowK);
                final res = antiDerivative(
                  rewritten,
                  variable,
                  depth: depth + 1,
                  assumptions: assumptions,
                );
                if (!hasUnevaluatedIntegral(res, variable)) {
                  return (scaleFactor * res).simplify(assumptions: assumptions);
                }
              }
            }
          }
        }
      }

      final coeffs = extractPolynomialCoefficients(base, variable);
      if (coeffs == null) {
        final negPoly = _extractNegLaurentShift(base, variable, assumptions);
        if (negPoly != null) {
          final (:k, :shiftedPoly) = negPoly;
          final pulledExp = (IntegerNumber.of(-k) * exponent).simplify(
            assumptions: assumptions,
          );
          final replacement =
              (Pow.of(xVar, pulledExp) * Pow.of(shiftedPoly, exponent))
                  .simplify(assumptions: assumptions);
          final rewritten = rebuild(i, replacement);
          final res = antiDerivative(
            rewritten,
            variable,
            depth: depth + 1,
            assumptions: assumptions,
          );
          if (!hasUnevaluatedIntegral(res, variable)) {
            if (exponent is IntegerNumber ||
                isPositiveExpr(xVar, assumptions: assumptions)) {
              return res;
            }
            final unit = (factor / replacement).simplify(
              assumptions: assumptions,
            );
            return (unit * res).simplify(assumptions: assumptions);
          }
        }
        continue;
      }
      final nonZero = [
        for (final entry in coeffs.entries)
          if (entry.value is! Number || !(entry.value as Number).isZero) entry,
      ];
      if (nonZero.length < 2) continue;

      final minDeg = nonZero.map((e) => e.key).reduce((a, b) => a < b ? a : b);
      if (minDeg >= 1) {
        final pulledExp = (IntegerNumber.of(minDeg) * exponent).simplify(
          assumptions: assumptions,
        );
        final quotientPoly = Add.of([
          for (final entry in nonZero)
            entry.value * Pow.of(xVar, IntegerNumber.of(entry.key - minDeg)),
        ]).simplify(assumptions: assumptions);
        final replacement =
            (Pow.of(xVar, pulledExp) * Pow.of(quotientPoly, exponent)).simplify(
              assumptions: assumptions,
            );
        final rewritten = rebuild(i, replacement);
        final res = antiDerivative(
          rewritten,
          variable,
          depth: depth + 1,
          assumptions: assumptions,
        );
        if (!hasUnevaluatedIntegral(res, variable)) {
          final isBranchExact =
              minDeg.isOdd ||
              isPositiveExpr(xVar, assumptions: assumptions) ||
              (minDeg.isEven &&
                  !(pulledExp is IntegerNumber && pulledExp.value.isOdd));
          if (isBranchExact) return res;
          final unit = (factor / replacement).simplify(
            assumptions: assumptions,
          );
          return (unit * res).simplify(assumptions: assumptions);
        }
      }

      if (exponent is FractionNumber) {
        final exp = exponent;
        for (final k in const [1, 2, 3]) {
          if (nonZero.length == 3 &&
              nonZero.every(
                (e) => e.key == 0 || e.key == k || e.key == 2 * k,
              )) {
            final a = coeffs[2 * k]!;
            final b = coeffs[k]!;
            final c = coeffs[0]!;
            final disc = (b * b - IntegerNumber.of(4) * a * c)
                .expand()
                .simplify(assumptions: assumptions);
            if (disc is Number && disc.isZero) {
              final isNegQuad =
                  isSyntacticallyNegative(a) || isNegativeConstant(a);
              if (isNegQuad) {
                final negA = (-a).simplify(assumptions: assumptions);
                final negC = (-c).simplify(assumptions: assumptions);
                final sqrtNegA = _factorEvenPowerSqrt(negA, assumptions);
                final sqrtNegC = _factorEvenPowerSqrt(negC, assumptions);
                final negSignRatio =
                    (-b / (IntegerNumber.two * sqrtNegA * sqrtNegC))
                        .expand()
                        .simplify(assumptions: assumptions);
                final s = negSignRatio == IntegerNumber.negativeOne
                    ? IntegerNumber.negativeOne
                    : IntegerNumber.one;
                final innerReal =
                    (sqrtNegA * Pow.of(xVar, IntegerNumber.of(k)) +
                            s * sqrtNegC)
                        .simplify(assumptions: assumptions);
                final halfExp = halfIntExponent(exp);
                if (halfExp != null &&
                    !sqrtNegA.anyNode((n) => n is ComplexNumber) &&
                    !sqrtNegC.anyNode((n) => n is ComplexNumber)) {
                  final paritySign = ((halfExp - 1) ~/ 2).isOdd
                      ? IntegerNumber.negativeOne
                      : IntegerNumber.one;
                  final rewritten = rebuild(
                    i,
                    (paritySign * Pow.of(innerReal, IntegerNumber.of(halfExp)))
                        .simplify(assumptions: assumptions),
                  );
                  final res = antiDerivative(
                    rewritten,
                    variable,
                    depth: depth + 1,
                    assumptions: assumptions,
                  );
                  if (!hasUnevaluatedIntegral(res, variable)) {
                    final unit = (Pow.of(base, FractionNumber.half) / innerReal)
                        .simplify(assumptions: assumptions);
                    return (unit * res).simplify(assumptions: assumptions);
                  }
                }
              } else {
                final sqrtA = _factorEvenPowerSqrt(a, assumptions);
                final sqrtC = _factorEvenPowerSqrt(c, assumptions);
                final signRatio = (b / (IntegerNumber.two * sqrtA * sqrtC))
                    .expand()
                    .simplify(assumptions: assumptions);
                final s = signRatio == IntegerNumber.negativeOne
                    ? IntegerNumber.negativeOne
                    : IntegerNumber.one;
                final inner =
                    (sqrtA * Pow.of(xVar, IntegerNumber.of(k)) + s * sqrtC)
                        .simplify(assumptions: assumptions);
                final newExp = (IntegerNumber.two * exp).simplify(
                  assumptions: assumptions,
                );
                final needsAbsInner =
                    exp.denominator.isEven &&
                    newExp is FractionNumber &&
                    newExp.denominator.isEven &&
                    !isNonNegativeExpr(inner, assumptions: assumptions) &&
                    (k.isOdd ||
                        s == IntegerNumber.negativeOne ||
                        isSyntacticallyNegative(a) ||
                        isSyntacticallyNegative(c));
                if (!needsAbsInner) {
                  final rewritten = rebuild(i, Pow.of(inner, newExp));
                  final res = antiDerivative(
                    rewritten,
                    variable,
                    depth: depth + 1,
                    assumptions: assumptions,
                  );
                  if (!hasUnevaluatedIntegral(res, variable)) {
                    final halfExp = halfIntExponent(exp);
                    if (halfExp != null &&
                        !isPositiveExpr(inner, assumptions: assumptions) &&
                        !inner.anyNode((n) => n is ComplexNumber)) {
                      var anchored = res;
                      if (inner.matchLinear(variable) case (
                        a: final linA,
                        b: final linB,
                      )) {
                        final zeroPt = (-linB / linA).simplify(
                          assumptions: assumptions,
                        );
                        final atZero = res
                            .substitute(variable, zeroPt)
                            .simplify(assumptions: assumptions);
                        if (atZero != Constant.undefined &&
                            !atZero.anyNode(
                              (n) =>
                                  n == Constant.undefined ||
                                  n == Constant.infinity,
                            )) {
                          anchored = (res - atZero).simplify(
                            assumptions: assumptions,
                          );
                        }
                      }
                      final unit =
                          assumptions.domainOf(variable) == VariableDomain.real
                          ? Fn.sign(inner)
                          : (Pow.of(base, FractionNumber.half) / inner)
                                .simplify(assumptions: assumptions);
                      return (unit * anchored).simplify(
                        assumptions: assumptions,
                      );
                    }
                    return res;
                  }
                }
              }
            }
          }
        }
      }
    }
  }
  return null;
}

({int k, Expr shiftedPoly})? _extractNegLaurentShift(
  Expr base,
  String variable,
  Assumptions assumptions,
) {
  if (base is! Add || base.terms.length < 2) return null;
  final xVar = Variable(variable);
  var minExp = 0;
  final parsedTerms = <({Expr coeff, int power})>[];

  for (final t in base.terms) {
    if (!t.dependsOn(variable)) {
      parsedTerms.add((coeff: t, power: 0));
      continue;
    }
    final factors = t is Mul ? t.factors : [t];
    final consts = <Expr>[];
    var deg = 0;
    var ok = true;
    for (final f in factors) {
      if (!f.dependsOn(variable)) {
        consts.add(f);
      } else if (f is Variable && f.name == variable) {
        deg += 1;
      } else if (f
          case Pow(
            base: Variable(:final name),
            exponent: IntegerNumber(asInt: final e?),
          )
          when name == variable) {
        deg += e;
      } else {
        ok = false;
        break;
      }
    }
    if (!ok || deg > 0) return null;
    if (deg < minExp) minExp = deg;
    final c = consts.isEmpty
        ? IntegerNumber.one
        : Mul.of(consts).simplify(assumptions: assumptions);
    parsedTerms.add((coeff: c, power: deg));
  }

  final k = -minExp;
  if (k < 1 || k > 6) return null;
  final shifted = Add.of([
    for (final item in parsedTerms)
      (item.power + k == 0
              ? item.coeff
              : item.coeff * Pow.of(xVar, IntegerNumber.of(item.power + k)))
          .simplify(assumptions: assumptions),
  ]).simplify(assumptions: assumptions);
  return (k: k, shiftedPoly: shifted);
}

/// Integrates half-integer powers `(a +/- a*sin(u))^(k/2)` and
/// `(a +/- a*cos(u))^(k/2)` via half-angle identities.
Expr? tryHalfAngleTrigRadical(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  if (depth >= 2) return null;

  ({Expr a, int sign, bool isSin, bool isRecip, Expr u, int k})?
  matchHalfAnglePow(Pow node) {
    final k = halfIntExponent(node.exponent);
    if (k == null || k.isEven || k.abs() > 9) return null;
    if (node.base case Add(terms: [final t0, final t1])) {
      final Expr a;
      final Expr trigTerm;
      if (!t0.dependsOn(variable) && t1.dependsOn(variable)) {
        a = t0;
        trigTerm = t1;
      } else if (!t1.dependsOn(variable) && t0.dependsOn(variable)) {
        a = t1;
        trigTerm = t0;
      } else {
        return null;
      }
      final trigFactors = trigTerm is Mul ? trigTerm.factors : [trigTerm];
      final trigConst = <Expr>[];
      final trigVar = <Expr>[];
      for (final f in trigFactors) {
        if (f.dependsOn(variable)) {
          trigVar.add(f);
        } else {
          trigConst.add(f);
        }
      }
      if (trigVar.length != 1) return null;
      var tv = trigVar.first;
      var isRecip = false;
      if (tv case Pow(
        base: final b,
        exponent: IntegerNumber(isNegativeOne: true),
      )) {
        isRecip = true;
        tv = b;
      }
      final bool isSin;
      final Expr u;
      if (tv case Call(id: FunctionId.sin, args: [final expr])) {
        isSin = true;
        u = expr;
      } else if (tv case Call(id: FunctionId.cos, args: [final expr])) {
        isSin = false;
        u = expr;
      } else {
        return null;
      }
      if (u.matchLinear(variable) == null) return null;
      final coeff = trigConst.isEmpty
          ? IntegerNumber.one
          : Mul.of(trigConst).simplify(assumptions: assumptions);
      final ratio = (coeff / a).simplify(assumptions: assumptions);
      final int sign;
      if (ratio == IntegerNumber.one) {
        sign = 1;
      } else if (ratio == IntegerNumber.negativeOne) {
        sign = -1;
      } else {
        return null;
      }
      return (a: a, sign: sign, isSin: isSin, isRecip: isRecip, u: u, k: k);
    }
    return null;
  }

  var constScale = IntegerNumber.one as Expr;
  Pow? targetPow;
  ({Expr a, int sign, bool isSin, bool isRecip, Expr u, int k})? matched;

  if (expr is Pow) {
    final m = matchHalfAnglePow(expr);
    if (m != null && !m.isRecip) {
      targetPow = expr;
      matched = m;
    } else if (m != null && m.isRecip) {
      targetPow = expr;
      matched = m;
    }
  } else if (expr is Mul) {
    final consts = <Expr>[];
    final varOthers = <Expr>[];
    for (final f in expr.factors) {
      if (!f.dependsOn(variable)) {
        consts.add(f);
      } else if (f is Pow && targetPow == null) {
        final m = matchHalfAnglePow(f);
        if (m != null) {
          targetPow = f;
          matched = m;
        } else {
          varOthers.add(f);
        }
      } else {
        varOthers.add(f);
      }
    }
    if (targetPow != null && matched != null) {
      if (consts.isNotEmpty) {
        constScale = Mul.of(consts).simplify(assumptions: assumptions);
      }
      if (varOthers.isNotEmpty) {
        final uTarget = matched.u;
        bool onlySinCosOfU(Expr n) {
          if (!n.dependsOn(variable)) return true;
          if (n is Call &&
              (n.id == FunctionId.sin ||
                  n.id == FunctionId.cos ||
                  n.id == FunctionId.tan) &&
              n.args[0] == uTarget) {
            return true;
          }
          if (n is Add) return n.terms.every(onlySinCosOfU);
          if (n is Mul) return n.factors.every(onlySinCosOfU);
          if (n is Pow &&
              !n.exponent.dependsOn(variable) &&
              n.exponent is IntegerNumber) {
            return onlySinCosOfU(n.base);
          }
          return false;
        }

        if (!varOthers.every(onlySinCosOfU)) return null;

        final sign = matched.sign;
        final isSin = matched.isSin;
        final isRecip = matched.isRecip;
        final k = matched.k;
        final duFactor = uTarget
            .matchLinear(variable)!
            .a
            .simplify(assumptions: assumptions);
        final v = isSin
            ? (uTarget / IntegerNumber.two - Constant.pi / IntegerNumber.of(4))
                  .simplify(assumptions: assumptions)
            : (uTarget / IntegerNumber.two).simplify(assumptions: assumptions);

        if (!isRecip) {
          final trigHalf = sign > 0 ? Fn.cos(v) : Fn.sin(v);
          final unit = (Pow.of(targetPow.base, FractionNumber.half) / trigHalf)
              .simplify(assumptions: assumptions);
          final twoCos2M1 =
              (IntegerNumber.two * Fn.cos(v) * Fn.cos(v) - IntegerNumber.one)
                  .simplify(assumptions: assumptions);
          final oneMTwoSin2 =
              (IntegerNumber.one - IntegerNumber.two * Fn.sin(v) * Fn.sin(v))
                  .simplify(assumptions: assumptions);
          final twoSinCos = (IntegerNumber.two * Fn.sin(v) * Fn.cos(v))
              .simplify(assumptions: assumptions);
          final cosURepl = !isSin
              ? (sign > 0 ? twoCos2M1 : oneMTwoSin2)
              : (-twoSinCos).simplify(assumptions: assumptions);
          final sinURepl = !isSin
              ? twoSinCos
              : (sign > 0 ? twoCos2M1 : oneMTwoSin2);

          Expr replaceTrigHalf(Expr n) {
            if (n is Call && n.args[0] == uTarget) {
              if (n.id == FunctionId.sin) return sinURepl;
              if (n.id == FunctionId.cos) return cosURepl;
              if (n.id == FunctionId.tan) return sinURepl / cosURepl;
            }
            return n.mapChildren(replaceTrigHalf);
          }

          final otherProd = varOthers.length == 1
              ? varOthers.first
              : Mul.of(varOthers).simplify(assumptions: assumptions);
          final rawRewritten =
              (constScale *
                      Pow.of(trigHalf, IntegerNumber.of(k)) *
                      replaceTrigHalf(otherProd))
                  .simplify(assumptions: assumptions);
          if (!exceedsNodeBudget(rawRewritten, 220)) {
            final rewritten = rawRewritten
                .expand(assumptions: assumptions)
                .simplify(assumptions: assumptions);
            final res = antiDerivative(
              rewritten,
              variable,
              depth: depth + 1,
              assumptions: assumptions,
            );
            if (!hasUnevaluatedIntegral(res, variable)) {
              return (Pow.of(unit, IntegerNumber.of(k)) * res).simplify(
                assumptions: assumptions,
              );
            }
          }
          return null;
        }

        // Case B: a +- a / cos(u) or a +- a / sin(u)
        final tVar = Variable(
          freshIntegrationVar('_ha', expr, variable, depth),
        );
        final primaryExpr =
            (IntegerNumber.one - tVar * tVar).simplify() /
            (IntegerNumber.one + tVar * tVar).simplify();
        final secondaryExpr =
            (IntegerNumber.two * tVar) /
            (IntegerNumber.one + tVar * tVar).simplify() *
            (isSin ? -IntegerNumber.one : IntegerNumber.one);
        final cosExprT = isSin ? secondaryExpr : primaryExpr;
        final sinExprT = isSin ? primaryExpr : secondaryExpr;

        Expr replaceTrigT(Expr n) {
          if (n is Call && n.args[0] == uTarget) {
            if (n.id == FunctionId.cos) return cosExprT;
            if (n.id == FunctionId.sin) return sinExprT;
            if (n.id == FunctionId.tan) return sinExprT / cosExprT;
          }
          return n.mapChildren(replaceTrigT);
        }

        final otherProd = varOthers.length == 1
            ? varOthers.first
            : Mul.of(varOthers).simplify(assumptions: assumptions);
        return _tryHalfAngleTangentSub(
          tVar: tVar,
          radBase: targetPow.base,
          v: v,
          duFactor: duFactor,
          sign: sign,
          k: k,
          extraScale: (constScale * replaceTrigT(otherProd)).simplify(
            assumptions: assumptions,
          ),
          variable: variable,
          depth: depth,
          assumptions: assumptions,
          checkVarFree: true,
        );
      }
    }
  }

  if (targetPow != null && matched != null) {
    final aExpr = matched.a;
    final sign = matched.sign;
    final isSin = matched.isSin;
    final isRecip = matched.isRecip;
    final u = matched.u;
    final k = matched.k;
    if (isRecip) {
      final v = isSin
          ? (u / IntegerNumber.two - Constant.pi / IntegerNumber.of(4))
                .simplify(assumptions: assumptions)
          : (u / IntegerNumber.two).simplify(assumptions: assumptions);
      final duFactor = u
          .matchLinear(variable)!
          .a
          .simplify(assumptions: assumptions);
      final tVar = Variable(freshIntegrationVar('_ha', expr, variable, depth));
      return _tryHalfAngleTangentSub(
        tVar: tVar,
        radBase: targetPow.base,
        v: v,
        duFactor: duFactor,
        sign: sign,
        k: k,
        extraScale: constScale,
        variable: variable,
        depth: depth,
        assumptions: assumptions,
      );
    }

    final duFactor = u
        .matchLinear(variable)!
        .a
        .simplify(assumptions: assumptions);
    final trigDeriv = isSin ? Fn.cos(u) : (-Fn.sin(u)).simplify();
    final sqrt2 = Pow.of(IntegerNumber.two, FractionNumber.half);
    final sqrtA = Pow.of(aExpr, FractionNumber.half);

    Expr integrateHalfInt(int m) {
      final sExpr = targetPow!.base;
      if (m == 1) {
        return (-IntegerNumber.of(2 * sign) *
                aExpr *
                trigDeriv *
                Pow.of(sExpr, FractionNumber.negativeHalf))
            .simplify(assumptions: assumptions);
      }
      if (m == -1) {
        final arg =
            (sqrt2 *
                    sqrtA *
                    trigDeriv /
                    (IntegerNumber.two * Pow.of(sExpr, FractionNumber.half)))
                .simplify(assumptions: assumptions);
        return (-IntegerNumber.of(sign) * sqrt2 * Fn.atanh(arg) / sqrtA)
            .simplify(assumptions: assumptions);
      }
      if (m > 1) {
        final q = RationalNumber(m, 2);
        final prev = integrateHalfInt(m - 2);
        final term1 =
            (-IntegerNumber.of(2 * sign) *
                aExpr *
                trigDeriv *
                Pow.of(sExpr, (q - IntegerNumber.one).simplify())) /
            IntegerNumber.of(m);
        final term2 =
            (IntegerNumber.of(2 * (m - 1)) * aExpr / IntegerNumber.of(m)) *
            prev;
        return (term1 + term2).simplify(assumptions: assumptions);
      }
      // m <= -3
      final q = RationalNumber(m, 2);
      final next = integrateHalfInt(m + 2);
      final term1 =
          (IntegerNumber.of(sign) * trigDeriv * Pow.of(sExpr, q)) /
          IntegerNumber.of(m + 1);
      final term2 =
          (IntegerNumber.of(m + 2) / (IntegerNumber.of(2 * (m + 1)) * aExpr)) *
          next;
      return (term1 + term2).simplify(assumptions: assumptions);
    }

    return (constScale * integrateHalfInt(k) / duFactor).simplify(
      assumptions: assumptions,
    );
  }
  return null;
}

/// Rewrites products of linear square roots and perfect-square trig factors
/// inside `sqrt(...)` for real antiderivative computation.
Expr? tryRealRadicalRewrite(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  if (depth >= 3) return null;

  // 1. Product of two linear square roots: sqrt(a1*x + b1) * sqrt(a2*x + b2)
  //    or 1 / (sqrt(a1*x + b1) * sqrt(a2*x + b2))
  if (expr case Mul(:final factors)) {
    final posIndices = <int>[];
    final negIndices = <int>[];
    for (var i = 0; i < factors.length; i++) {
      if (factors[i] case Pow(:final base, :final exponent)
          when base.matchLinear(variable) != null) {
        final h = halfIntExponent(exponent);
        if (h == 1) {
          posIndices.add(i);
        } else if (h == -1) {
          negIndices.add(i);
        }
      }
    }
    final pair = posIndices.length >= 2
        ? (i0: posIndices[0], i1: posIndices[1], exp: FractionNumber.half)
        : (negIndices.length >= 2
              ? (
                  i0: negIndices[0],
                  i1: negIndices[1],
                  exp: FractionNumber.negativeHalf,
                )
              : null);
    if (pair != null) {
      final b0 = (factors[pair.i0] as Pow).base;
      final b1 = (factors[pair.i1] as Pow).base;
      final isOpposite =
          (b0 + b1).simplify(assumptions: assumptions) == IntegerNumber.zero;
      final ratio = isOpposite
          ? IntegerNumber.negativeOne
          : (b0 / b1)
                .cancel(assumptions: assumptions)
                .simplify(assumptions: assumptions);
      if (ratio is RealNumeric && ratio.sign < 0) {
        if (factors.length == 2 && pair.exp == FractionNumber.negativeHalf) {
          final posBase = isSyntacticallyNegative(b0) ? b1 : b0;
          final negBase = isSyntacticallyNegative(b0) ? b0 : b1;
          if (posBase.matchLinear(variable) case (:final a, b: _)) {
            return (Pow.of(posBase, FractionNumber.half) *
                    Fn.ln(posBase) /
                    (a * Pow.of(negBase, FractionNumber.half)))
                .simplify(assumptions: assumptions);
          }
        }
      } else {
        if (factors.length == 2 && pair.exp == FractionNumber.negativeHalf) {
          if ((b0.matchLinear(variable), b1.matchLinear(variable))
              case ((a: final a0, b: _), (a: final a1, b: _)) when a0 == a1) {
            return (IntegerNumber.two *
                    Fn.ln(
                      (Pow.of(b0, FractionNumber.half) +
                              Pow.of(b1, FractionNumber.half))
                          .simplify(assumptions: assumptions),
                    ) /
                    a0)
                .simplify(assumptions: assumptions);
          }
        }
        final merged = Pow.of(
          (b0 * b1).expand().simplify(assumptions: assumptions),
          pair.exp,
        );
        final rebuilt = Mul.of([
          merged,
          for (var j = 0; j < factors.length; j++)
            if (j != pair.i0 && j != pair.i1) factors[j],
        ]).simplify(assumptions: assumptions);
        final res = antiDerivative(
          rebuilt,
          variable,
          depth: depth + 1,
          assumptions: assumptions,
        );
        if (!hasUnevaluatedIntegral(res, variable)) return res;
      }
    }
  }

  // 2. Trig Pythagorean identity & even-power extraction inside sqrt(...)
  final signFactors = <Expr>[];
  Expr rewriteSqrt(Expr node) {
    final mapped = node.mapChildren(rewriteSqrt);
    if (mapped
        case Pow(
          :final base,
          exponent: FractionNumber(
            numerator: final fnNum,
            denominator: final fnDen,
          ),
        )
        when fnNum == BigInt.one && fnDen == BigInt.two) {
      if (base case Add(terms: [final t0, final t1])) {
        Expr? tanSq;
        if (t0 == IntegerNumber.one) {
          tanSq = t1;
        } else if (t1 == IntegerNumber.one) {
          tanSq = t0;
        }
        if (tanSq case Pow(
          base: Call(id: FunctionId.tan, args: [final u]),
          exponent: IntegerNumber(asInt: 2),
        )) {
          final cosU = Fn.cos(u);
          if (!isPositiveExpr(cosU, assumptions: assumptions)) {
            signFactors.add(Fn.sign(cosU));
          }
          return Pow.of(cosU, IntegerNumber.negativeOne);
        }
      }
      if (base case Mul(:final factors)) {
        final pulled = <Expr>[];
        final remaining = <Expr>[];
        for (final f in factors) {
          if (f
              case Pow(
                base: final inner,
                exponent: IntegerNumber(asInt: final p?),
              )
              when p.isEven &&
                  inner is Call &&
                  (inner.id == FunctionId.sin || inner.id == FunctionId.cos)) {
            final k = p ~/ 2;
            if (k.isOdd && !isPositiveExpr(inner, assumptions: assumptions)) {
              signFactors.add(Fn.sign(inner));
            }
            pulled.add(Pow.of(inner, IntegerNumber.of(k)));
          } else {
            remaining.add(f);
          }
        }
        if (pulled.isNotEmpty) {
          final remSqrt = switch (remaining) {
            [] => IntegerNumber.one,
            [Pow(:final base, exponent: Number(isNegativeOne: true))] => Pow.of(
              base,
              FractionNumber.negativeHalf,
            ),
            _ => Pow.of(
              Mul.of(remaining).simplify(assumptions: assumptions),
              FractionNumber.half,
            ),
          };
          return (Mul.of(pulled) * remSqrt).simplify(assumptions: assumptions);
        }
      }
    }
    return mapped;
  }

  final rewritten = rewriteSqrt(expr).simplify(assumptions: assumptions);
  if (rewritten != expr) {
    final res = antiDerivative(
      rewritten,
      variable,
      depth: depth + 1,
      assumptions: assumptions,
    );
    if (!hasUnevaluatedIntegral(res, variable)) {
      return signFactors.isEmpty
          ? res
          : (Mul.of(signFactors) * res).simplify(assumptions: assumptions);
    }
  }
  return null;
}

/// Integrates expressions containing fractional powers `x^(p/q)` via `x = t^d`.
Expr? tryVariableRootSubstitution(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  if (depth >= 2) return null;

  final denoms = <int>{};
  var hasNonVarFracPow = false;
  var hasTranscendental = false;

  void collect(Expr node) {
    if (node
        case Pow(
          base: Variable(:final name),
          exponent: FractionNumber(:final denominator),
        )
        when name == variable) {
      final dInt = denominator.isValidInt ? denominator.toInt() : null;
      if (dInt != null && dInt >= 2) {
        denoms.add(dInt);
        return;
      }
    }
    if (node is Pow &&
        node.exponent is FractionNumber &&
        node.dependsOn(variable)) {
      hasNonVarFracPow = true;
    } else if (node is Call && node.dependsOn(variable)) {
      hasTranscendental = true;
    }
    node.mapChildren((c) {
      collect(c);
      return c;
    });
  }

  collect(expr);
  if (denoms.isEmpty) return null;

  var d = 1;
  for (final q in denoms) {
    d = d.lcm(q);
    if (d > 25) return null;
  }
  if (d < 2) return null;
  if (d > 6 && (hasNonVarFracPow || hasTranscendental)) return null;

  final tName = freshIntegrationVar('_rt', expr, variable, depth);
  final tVar = Variable(tName);

  Expr? replaceX(Expr node) {
    if (node
        case Pow(
          base: Variable(:final name),
          exponent: FractionNumber(:final numerator, :final denominator),
        )
        when name == variable) {
      final numInt = numerator.isValidInt ? numerator.toInt() : null;
      final denInt = denominator.isValidInt ? denominator.toInt() : null;
      if (numInt == null || denInt == null) return null;
      final exp = numInt * (d ~/ denInt);
      return Pow.of(tVar, IntegerNumber.of(exp));
    }
    if (node is Variable && node.name == variable) {
      return Pow.of(tVar, IntegerNumber.of(d));
    }
    var ok = true;
    final mapped = node.mapChildren((c) {
      final r = replaceX(c);
      if (r == null) {
        ok = false;
        return c;
      }
      return r;
    });
    return ok ? mapped : null;
  }

  final replacedExpr = replaceX(expr);
  if (replacedExpr == null) return null;
  final substituted = replacedExpr.simplify(assumptions: assumptions);
  if (substituted.dependsOn(variable)) return null;

  final dxFactor = (IntegerNumber.of(d) * Pow.of(tVar, IntegerNumber.of(d - 1)))
      .simplify(assumptions: assumptions);
  final transformed = (substituted * dxFactor).simplify(
    assumptions: assumptions,
  );
  final res = antiDerivative(
    transformed,
    tName,
    depth: depth + 1,
    assumptions: assumptions,
  );
  if (hasUnevaluatedIntegral(res, tName)) return null;

  final xRoot = Pow.of(Variable(variable), RationalNumber(1, d));
  return res.substitute(tName, xRoot).simplify(assumptions: assumptions);
}

/// Integrates square-root binomial quadratics `sqrt(a +/- u^2)` or `sqrt(u^2 - a)`.
Expr? tryRadicalQuadratic(Expr base, String variable) {
  if (base case Add(terms: [final t0, final t1])) {
    final aConst = !t0.dependsOn(variable)
        ? t0
        : (!t1.dependsOn(variable) ? t1 : null);
    final varTerm = !t0.dependsOn(variable) ? t1 : t0;
    if (aConst == null) return null;

    final rad = Pow.of(base, FractionNumber.half).simplify();
    if (isPositiveConstant(aConst)) {
      final sqrtA = Pow.of(aConst, FractionNumber.half).simplify();
      // 1. sqrt(a - u^2) where u = m*x + b
      final negVar = (-varTerm).simplify();
      if (extractScaledSquareBase(negVar, variable) case final u?) {
        if (u.matchLinear(variable) case (a: final slope, b: _)) {
          return ((u * rad / IntegerNumber.two +
                      (aConst / IntegerNumber.two) * Fn.asin(u / sqrtA)) /
                  slope)
              .simplify();
        }
      }
      // 2. sqrt(a + u^2) where u = m*x + b
      if (extractScaledSquareBase(varTerm, variable) case final u?) {
        if (u.matchLinear(variable) case (a: final slope, b: _)) {
          return ((u * rad / IntegerNumber.two +
                      (aConst / IntegerNumber.two) * Fn.asinh(u / sqrtA)) /
                  slope)
              .simplify();
        }
      }
    } else if (isSymbolicPositive((-aConst).simplify())) {
      // 3. sqrt(u^2 - a) where a = -aConst > 0 and u = m*x + b
      final posA = (-aConst).simplify();
      if (extractScaledSquareBase(varTerm, variable) case final u?) {
        if (u.matchLinear(variable) case (a: final slope, b: _)) {
          return ((u * rad / IntegerNumber.two -
                      (posA / IntegerNumber.two) *
                          Fn.ln(Fn.abs((u + rad).simplify()))) /
                  slope)
              .simplify();
        }
      }
    }
  }
  return null;
}

/// Integrates `P(x) * (A*x^2 + B*x + C)^(k/2)` with respect to [variable].
Expr? tryQuadraticRadical(
  Expr numerator,
  Expr quad,
  int halfExp,
  String variable, {
  bool preferLog = false,
}) {
  final numExpanded = numerator.expand().simplify();
  if (numExpanded is Number && numExpanded.isZero) return IntegerNumber.zero;

  final numCoeffs = extractPolynomialCoefficients(numExpanded, variable);
  if (numCoeffs == null) return null;
  final degP = maxPolynomialDegree(numCoeffs);
  if (degP > 12) return null;

  final quadCoeffs = extractPolynomialCoefficients(quad, variable);
  if (quadCoeffs == null || maxPolynomialDegree(quadCoeffs) != 2) return null;
  final a = quadCoeffs[2] ?? IntegerNumber.zero;
  final b = quadCoeffs[1] ?? IntegerNumber.zero;
  final c = quadCoeffs[0] ?? IntegerNumber.zero;

  if (degP >= 2) {
    if (halfExp <= -3) {
      final (:quotient, :remainder) = numExpanded.polynomialDivide(
        quad,
        variable,
      );
      final qInt = tryQuadraticRadical(quotient, quad, halfExp + 2, variable);
      if (qInt == null) return null;
      final rInt = tryQuadraticRadical(remainder, quad, halfExp, variable);
      if (rInt == null) return null;
      return (qInt + rInt).simplify();
    }
    if (halfExp == -1) {
      return integratePolyOverSqrtQ(
        numExpanded,
        quad,
        a,
        b,
        c,
        variable,
        preferLog: preferLog,
      );
    }
    if (halfExp >= 1 && halfExp.isOdd) {
      final m = degP;
      final lead = numCoeffs[m]!;
      final xVar = Variable(variable);
      final denom = (IntegerNumber.of(m + halfExp + 1) * a).simplify();
      final term1 =
          (lead *
              Pow.of(xVar, IntegerNumber.of(m - 1)) *
              Pow.of(quad, RationalNumber(halfExp + 2, 2))) /
          denom;
      final bTerm =
          (lead *
              IntegerNumber.of(2 * m + halfExp) *
              b /
              (IntegerNumber.two * denom)) *
          Pow.of(xVar, IntegerNumber.of(m - 1));
      final cTerm =
          (lead * IntegerNumber.of(m - 1) * c / denom) *
          (m == 2 ? IntegerNumber.one : Pow.of(xVar, IntegerNumber.of(m - 2)));
      final lowerPoly =
          (numExpanded -
                  lead * Pow.of(xVar, IntegerNumber.of(m)) -
                  bTerm -
                  cTerm)
              .expand()
              .simplify();
      final rem = tryQuadraticRadical(lowerPoly, quad, halfExp, variable);
      if (rem == null) return null;
      return (term1 + rem).simplify();
    }
    return null;
  }

  final p = numCoeffs[1] ?? IntegerNumber.zero;
  final q = numCoeffs[0] ?? IntegerNumber.zero;

  if (p == IntegerNumber.zero) {
    final rem = _tryQuadraticRadicalConst(
      quad,
      a,
      b,
      c,
      halfExp,
      variable,
      preferLog: preferLog,
    );
    return rem == null ? null : (q * rem).simplify();
  }

  final twoA = (IntegerNumber.two * a).simplify();
  final leadTerm =
      (p / (a * IntegerNumber.of(halfExp + 2))) *
      Pow.of(quad, RationalNumber(halfExp + 2, 2));
  final qRem = (q - (p * b) / twoA).simplify();
  if (qRem == IntegerNumber.zero) return leadTerm.simplify();

  final rem = _tryQuadraticRadicalConst(
    quad,
    a,
    b,
    c,
    halfExp,
    variable,
    preferLog: preferLog,
  );
  if (rem == null) return null;
  return (leadTerm + qRem * rem).simplify();
}

/// Attempts affine radical substitution `u = (a*x + b)^(1/n)` on [expr].
Expr? tryAffineRadicalSubstitution(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  final radicals = <({Expr base, int p, int q})>[];
  _collectAffineRadicals(expr, variable, radicals);
  if (radicals.isEmpty) return null;

  final firstBase = radicals.first.base;
  final linear = firstBase.matchLinear(variable);
  if (linear == null) return null;
  final (:a, :b) = linear;
  final baseScales = <Expr, Expr>{firstBase: IntegerNumber.one};
  for (final r in radicals) {
    if (baseScales.containsKey(r.base)) continue;
    final rLin = r.base.matchLinear(variable);
    if (rLin == null) return null;
    final det = (a * rLin.b - b * rLin.a).expand().simplify(
      assumptions: assumptions,
    );
    if (det is! Number || !det.isZero) return null;
    final ratio = (rLin.a / a).simplify(assumptions: assumptions);
    if (!isPositiveConstant(ratio)) return null;
    baseScales[r.base] = ratio;
  }

  var n = 1;
  for (final r in radicals) {
    n = n.lcm(r.q);
    if (n > 6) return null;
  }
  if (n < 2) return null;

  final uName = freshIntegrationVar('_u', expr, variable, depth);
  final uVar = Variable(uName);
  final replaced = _replaceAffineRadical(
    expr,
    baseScales,
    variable,
    uVar,
    n,
    a,
    b,
  );
  final dx = (IntegerNumber.of(n) * Pow.of(uVar, IntegerNumber.of(n - 1))) / a;
  final transformed = (replaced * dx)
      .together(assumptions: assumptions)
      .cancel(assumptions: assumptions);
  if (transformed.dependsOn(variable)) return null;

  final uAntideriv = antiDerivative(
    transformed,
    uName,
    assumptions: assumptions,
    depth: depth + 1,
  );
  if (hasUnevaluatedIntegral(uAntideriv, uName)) return null;

  final backSub = Pow.of(firstBase, RationalNumber(1, n));
  return uAntideriv
      .substitute(uName, backSub)
      .simplify(assumptions: assumptions);
}

/// Attempts Chebyshev differential binomial substitution on `x^m * (a + b*x^n)^(p/q)`.

Expr? _tryQuadraticRadicalConst(
  Expr quad,
  Expr a,
  Expr b,
  Expr c,
  int halfExp,
  String variable, {
  bool preferLog = false,
}) {
  final twoA = (IntegerNumber.two * a).simplify();
  final twoAxPlusB = (twoA * Variable(variable) + b).simplify();
  final disc = (IntegerNumber.of(4) * a * c - b * b).expand().simplify();

  if (halfExp == -1) {
    if (disc == IntegerNumber.zero) return null;
    if (preferLog) {
      final sqrtA = Pow.of(a, FractionNumber.half).simplify();
      final rad = Pow.of(quad, FractionNumber.half).simplify();
      final logArg = (twoAxPlusB + IntegerNumber.two * sqrtA * rad).simplify();
      return (Fn.ln(logArg) / sqrtA).simplify();
    }
    if (isSyntacticallyNegative(a) || isNegativeConstant(a)) {
      final negA = (-a).simplify();
      final b2Minus4ac = (-disc).simplify();
      final ratio = (negA / b2Minus4ac).simplify();
      if (isNegativeConstant(disc) ||
          (isPositiveConstant(ratio) &&
              _isPositiveConstantOrEvenSquare(b2Minus4ac) &&
              _isPositiveConstantOrEvenSquare(negA))) {
        final sqrtNegA = _factorEvenPowerSqrt(negA, Assumptions.none);
        final sqrtDisc = _factorEvenPowerSqrt(b2Minus4ac, Assumptions.none);
        final arg = ((-twoAxPlusB) / sqrtDisc).simplify();
        return (Fn.asin(arg) / sqrtNegA).simplify();
      }
    }
    final sqrtA = Pow.of(a, FractionNumber.half).simplify();
    if (!isPositiveExpr(disc, assumptions: Assumptions.none) ||
        isSyntacticallyNegative(a) ||
        isNegativeConstant(a)) {
      final rad = Pow.of(quad, FractionNumber.half).simplify();
      final logArg = (twoAxPlusB + IntegerNumber.two * sqrtA * rad).simplify();
      return (Fn.ln(logArg) / sqrtA).simplify();
    }
    final sqrtDisc = Pow.of(disc, FractionNumber.half).simplify();
    final arg = (twoAxPlusB / sqrtDisc).simplify();
    return (Fn.asinh(arg) / sqrtA).simplify();
  }

  if (halfExp == -3) {
    if (disc == IntegerNumber.zero) return null;
    final rad = Pow.of(quad, FractionNumber.half).simplify();
    return ((IntegerNumber.two * twoAxPlusB) / (disc * rad)).simplify();
  }

  if (halfExp <= -5) {
    if (disc == IntegerNumber.zero) return null;
    final m = -halfExp;
    final prev = _tryQuadraticRadicalConst(
      quad,
      a,
      b,
      c,
      halfExp + 2,
      variable,
    );
    if (prev == null) return null;
    final mMinus2 = IntegerNumber.of(m - 2);
    final mMinus3 = IntegerNumber.of(m - 3);
    final denom = (mMinus2 * disc).simplify();
    final term1 =
        (IntegerNumber.two * twoAxPlusB) /
        (denom * Pow.of(quad, RationalNumber(m - 2, 2)));
    final term2 = (IntegerNumber.of(4) * a * mMinus3 / denom) * prev;
    return (term1 + term2).simplify();
  }

  if (halfExp >= 1) {
    final prev = _tryQuadraticRadicalConst(
      quad,
      a,
      b,
      c,
      halfExp - 2,
      variable,
    );
    if (prev == null) return null;
    final nPlus1 = IntegerNumber.of(halfExp + 1);
    final term1 =
        (twoAxPlusB * Pow.of(quad, RationalNumber(halfExp, 2))) /
        (twoA * nPlus1);
    final term2 =
        (IntegerNumber.of(halfExp) *
            disc /
            (IntegerNumber.of(4) * a * nPlus1)) *
        prev;
    return (term1 + term2).simplify();
  }

  return null;
}

({int p, int q})? fractionalExponent(Expr exponent) {
  if (exponent case FractionNumber(:final numerator, :final denominator)) {
    final p = numerator.isValidInt ? numerator.toInt() : null;
    final q = denominator.isValidInt ? denominator.toInt() : null;
    if (p != null && q != null && p.abs() <= 12 && q >= 2 && q <= 6) {
      return (p: p, q: q);
    }
  }
  if (exponent is RealNumber && exponent.value.abs() == 0.5) {
    return (p: exponent.value > 0 ? 1 : -1, q: 2);
  }
  return null;
}

void _collectAffineRadicals(
  Expr node,
  String variable,
  List<({Expr base, int p, int q})> out,
) {
  if (node case Pow(:final base, :final exponent)) {
    if (base.dependsOn(variable) && base.matchLinear(variable) != null) {
      if (fractionalExponent(exponent) case (:final p, :final q)) {
        out.add((base: base, p: p, q: q));
        return;
      }
    }
  }
  node.mapChildren((child) {
    _collectAffineRadicals(child, variable, out);
    return child;
  });
}

Expr _replaceAffineRadical(
  Expr node,
  Map<Expr, Expr> baseScales,
  String variable,
  Variable uVar,
  int n,
  Expr a,
  Expr b,
) {
  if (node case Pow(:final base, :final exponent)) {
    if (baseScales[base] case final scale?) {
      if (fractionalExponent(exponent) case (:final p, :final q)) {
        final uPow = Pow.of(uVar, IntegerNumber.of((p * n) ~/ q));
        if (scale == IntegerNumber.one) return uPow;
        return (Pow.of(scale, RationalNumber(p, q)) * uPow).simplify();
      }
    }
    if (exponent case IntegerNumber(:final asInt?)
        when asInt != 0 && base.dependsOn(variable)) {
      if (extractPolynomialCoefficients(base, variable) case final coeffs?) {
        final nonZero = [
          for (final entry in coeffs.entries)
            if (entry.value is! Number || !(entry.value as Number).isZero)
              entry,
        ];
        if (nonZero.length >= 2) {
          final minDeg = nonZero
              .map((e) => e.key)
              .reduce((x, y) => x < y ? x : y);
          if (minDeg >= 1) {
            final xVar = Variable(variable);
            final xOfU = ((Pow.of(uVar, IntegerNumber.of(n)) - b) / a)
                .simplify();
            final qPoly = Add.of([
              for (final entry in nonZero)
                entry.value *
                    Pow.of(xVar, IntegerNumber.of(entry.key - minDeg)),
            ]).simplify();
            final qSub = _replaceAffineRadical(
              qPoly,
              baseScales,
              variable,
              uVar,
              n,
              a,
              b,
            );
            return (Pow.of(xOfU, IntegerNumber.of(asInt * minDeg)) *
                    Pow.of(qSub, exponent))
                .simplify();
          }
        }
      }
    }
  }
  if (node is Variable && node.name == variable) {
    return ((Pow.of(uVar, IntegerNumber.of(n)) - b) / a).simplify();
  }
  return node.mapChildren(
    (child) =>
        _replaceAffineRadical(child, baseScales, variable, uVar, n, a, b),
  );
}

Expr _factorEvenPowerSqrt(Expr expr, Assumptions assumptions) => switch (expr) {
  Pow(:final base, exponent: IntegerNumber(asInt: final p?)) when p.isEven =>
    Pow.of(base, IntegerNumber.of(p ~/ 2)).simplify(assumptions: assumptions),
  Mul(:final factors) => Mul.of([
    for (final f in factors) _factorEvenPowerSqrt(f, assumptions),
  ]).simplify(assumptions: assumptions),
  _ => Pow.of(expr, FractionNumber.half).simplify(assumptions: assumptions),
};

bool _isPositiveConstantOrEvenSquare(Expr expr) {
  if (isPositiveConstant(expr)) return true;
  if (expr case Pow(exponent: IntegerNumber(:final value))) {
    return value > BigInt.zero && value.isEven;
  }
  if (expr case Mul(:final factors)) {
    return factors.every(_isPositiveConstantOrEvenSquare);
  }
  return false;
}

Expr? _tryHalfAngleTangentSub({
  required Variable tVar,
  required Expr radBase,
  required Expr v,
  required Expr duFactor,
  required int sign,
  required int k,
  required Expr extraScale,
  required String variable,
  required int depth,
  required Assumptions assumptions,
  bool checkVarFree = false,
}) {
  final tanV = Fn.tan(v);
  final oneMT2 = (IntegerNumber.one - tVar * tVar).simplify();
  final onePT2 = (IntegerNumber.one + tVar * tVar).simplify();
  final oneMTanV2 = (IntegerNumber.one - tanV * tanV).simplify();
  final baseHalf =
      Pow.of(radBase, FractionNumber.half) *
      Pow.of(oneMTanV2, FractionNumber.half);
  final unit = (sign > 0 ? baseHalf : baseHalf / tanV).simplify(
    assumptions: assumptions,
  );
  final oneMT2Pow = Pow.of(oneMT2, RationalNumber(-k, 2));
  final radInT = sign > 0
      ? oneMT2Pow
      : (Pow.of(tVar, IntegerNumber.of(k)) * oneMT2Pow).simplify();
  final dx = IntegerNumber.two / (duFactor * onePT2);
  final transformed = (extraScale * radInT * dx)
      .together(assumptions: assumptions)
      .simplify(assumptions: assumptions);
  if ((!checkVarFree || !transformed.dependsOn(variable)) &&
      !exceedsNodeBudget(transformed, 250)) {
    final tRes = antiDerivative(
      transformed,
      tVar.name,
      depth: depth + 1,
      assumptions: assumptions,
    );
    if (!hasUnevaluatedIntegral(tRes, tVar.name)) {
      return (Pow.of(unit, IntegerNumber.of(k)) *
              tRes.substitute(tVar.name, tanV))
          .simplify(assumptions: assumptions);
    }
  }
  return null;
}
