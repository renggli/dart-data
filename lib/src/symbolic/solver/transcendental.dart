import 'dart:math' as math;

import '../algebra/simplify.dart';
import '../algebra/term_accumulator.dart';
import '../ast.dart';
import '../calculus/linear_form.dart';
import 'polynomial.dart';
import 'trigonometric.dart';
import 'univariate.dart';

/// Isolates variable in additive expression or equates to 0, then inverts.
List<Expr>? isolateAndInvert(Expr expr, String variable) {
  // Case 1: expr is Add(terms)
  if (expr is Add) {
    final varTerms = <Expr>[];
    final constTerms = <Expr>[];
    for (final t in expr.terms) {
      if (t.dependsOn(variable)) {
        varTerms.add(t);
      } else {
        constTerms.add(t);
      }
    }
    if (varTerms.isNotEmpty && constTerms.isNotEmpty) {
      final u = varTerms.length == 1
          ? varTerms.first
          : Add(varTerms).simplify();
      final c = (-(constTerms.length == 1 ? constTerms.first : Add(constTerms)))
          .simplify();
      final res = invertEquation(u, c, variable);
      if (res != null) return res;
    }
  }

  // Case 2: Affine exponential matching (e.g. a^x = bx + c)
  final affineExp = _matchAffineExponential(expr, variable);
  if (affineExp != null) return affineExp;

  // Case 3: expr is alone (equated to 0)
  return invertEquation(expr, IntegerNumber.zero, variable);
}

/// Inverts elementary and transcendental operations for equation $u = c$.
List<Expr>? invertEquation(Expr u, Expr c, String variable) {
  u = u.simplify();
  c = c.simplify();

  if (u is Variable && u.name == variable) {
    return [c];
  }

  if (u is Ln) {
    // ln(arg) = c -> arg = exp(c)
    final expC = Pow(Constant.e, c).simplify();
    return solveEquation((u.expr - expC).simplify(), variable);
  }

  if (u is Sin) {
    return invertSin(u.expr, c, variable);
  }

  if (u is Cos) {
    return invertCos(u.expr, c, variable);
  }

  if (u is Tan) {
    return invertTan(u.expr, c, variable);
  }

  if (u is Asin) {
    if (isRealConstantOutOfRange(c, math.pi / 2)) return const [];
    final sinC = Sin(c).simplify();
    return solveEquation((u.expr - sinC).simplify(), variable);
  }

  if (u is Acos) {
    final cNum = _tryEvalReal(c);
    if (cNum != null && (cNum < -1e-12 || cNum > math.pi + 1e-12)) {
      return const [];
    }
    final cosC = Cos(c).simplify();
    return solveEquation((u.expr - cosC).simplify(), variable);
  }

  if (u is Atan) {
    final cNum = _tryEvalReal(c);
    if (cNum != null && cNum.abs() >= math.pi / 2 - 1e-12) {
      return const [];
    }
    final tanC = Tan(c).simplify();
    return solveEquation((u.expr - tanC).simplify(), variable);
  }

  if (u is Sinh) {
    final rhs = Asinh(c).simplify();
    return solveEquation((u.expr - rhs).simplify(), variable);
  }

  if (u is Cosh) {
    final cNum = _tryEvalReal(c);
    if (cNum != null && cNum < 1.0 - 1e-12) return const [];
    if ((c is Number && c.isOne) || (c is RealNumber && c.value == 1.0)) {
      return solveEquation(u.expr, variable);
    }
    final pos = Acosh(c).simplify();
    final neg = (-pos).simplify();
    return deduplicateRoots([
      ...solveEquation((u.expr - pos).simplify(), variable),
      ...solveEquation((u.expr - neg).simplify(), variable),
    ]);
  }

  if (u is Tanh) {
    final cNum = _tryEvalReal(c);
    if (cNum != null && cNum.abs() >= 1.0 - 1e-12) return const [];
    final rhs = Atanh(c).simplify();
    return solveEquation((u.expr - rhs).simplify(), variable);
  }

  if (u is Abs) {
    final cNum = _tryEvalReal(c);
    if (cNum != null && cNum < -1e-12) return const [];
    if ((c is Number && c.isZero) || (c is RealNumber && c.value == 0.0)) {
      return solveEquation(u.expr, variable);
    }
    return deduplicateRoots([
      ...solveEquation((u.expr - c).simplify(), variable),
      ...solveEquation((u.expr + c).simplify(), variable),
    ]);
  }

  if (u is LambertW) {
    final cNum = _tryEvalReal(c);
    if (cNum != null) {
      if (u.branch == 0 && cNum < -1.0 - 1e-12) return const [];
      if (u.branch == -1 && cNum > -1.0 + 1e-12) return const [];
    }
    final rhs = (c * Pow(Constant.e, c)).simplify();
    return solveEquation((u.expr - rhs).simplify(), variable);
  }

  if (u is Asinh) {
    final rhs = Sinh(c).simplify();
    return solveEquation((u.expr - rhs).simplify(), variable);
  }

  if (u is Acosh) {
    final cNum = _tryEvalReal(c);
    if (cNum != null && cNum < -1e-12) return const [];
    final rhs = Cosh(c).simplify();
    return solveEquation((u.expr - rhs).simplify(), variable);
  }

  if (u is Atanh) {
    final rhs = Tanh(c).simplify();
    return solveEquation((u.expr - rhs).simplify(), variable);
  }

  if (u is Erf) {
    if (c is Number && c.isZero) {
      return solveEquation(u.expr, variable);
    }
    final cNum = _tryEvalReal(c);
    if (cNum != null) {
      if (cNum.abs() > 1.0 + 1e-12) return const [];
      if (cNum.abs() < 1e-12) return solveEquation(u.expr, variable);
    }
  }

  if (u is Add) {
    final res = _solveAddTranscendental(u, c, variable);
    if (res != null) return res;
  }

  if (u is Pow) {
    // Exponential form: e^arg = c or b^arg = c
    if (!u.base.dependsOn(variable) && u.exponent.dependsOn(variable)) {
      if (u.base == Constant.e) {
        final cNum = _tryEvalReal(c);
        if (cNum != null && cNum <= 0.0) return const [];
        final lnC = Ln(c).simplify();
        return solveEquation((u.exponent - lnC).simplify(), variable);
      }
      final bNum = _tryEvalReal(u.base);
      if (bNum == null || (bNum > 0.0 && bNum != 1.0)) {
        final cNum = _tryEvalReal(c);
        if (cNum != null && cNum <= 0.0) return const [];
        final rhs = (Ln(c) / Ln(u.base)).simplify();
        return solveEquation((u.exponent - rhs).simplify(), variable);
      }
    }

    if (u.base.dependsOn(variable) && u.exponent.dependsOn(variable)) {
      if ((u.exponent / u.base).simplify() == IntegerNumber.one) {
        final cNum = _tryEvalReal(c);
        if (cNum != null && cNum <= 0.0) return const [];
        return _solveLambertWEquation(
          Ln(u.base).simplify(),
          Ln(c).simplify(),
          variable,
        );
      }
    }
    if (!u.exponent.dependsOn(variable)) {
      if (u.exponent is RationalNumber) {
        final expConst = u.exponent as RationalNumber;
        if (!expConst.isZero) {
          if (expConst.isNegative &&
              ((c is Number && c.isZero) ||
                  (c is RealNumber && c.value == 0.0))) {
            return const [];
          }
          if (expConst is IntegerNumber) {
            final n = expConst.asInt;
            if (n != null && n > 0) {
              if (n.isEven) {
                // Even power: u^n = c -> u = +/- c^(1/n) (requires c >= 0)
                if (c is RationalNumber && c.isNegative) return const [];
                if (c is RealNumber && c.value < 0) return const [];
                final posRoot = rootConstant(c, n);
                final negRoot = (-posRoot).simplify();
                final s1 = solveEquation(
                  (u.base - posRoot).simplify(),
                  variable,
                );
                final s2 = solveEquation(
                  (u.base - negRoot).simplify(),
                  variable,
                );
                return deduplicateRoots([...s1, ...s2]);
              } else {
                // Odd power: u^n = c -> u = c^(1/n)
                final root = rootConstant(c, n);
                return solveEquation((u.base - root).simplify(), variable);
              }
            }
          }
          final invP = expConst.reciprocal();
          if (expConst.denominator.isEven &&
              ((c is RationalNumber && c.isNegative) ||
                  (c is RealNumber && c.value < 0))) {
            return const [];
          }
          final root = Pow(c, invP).simplify();
          return solveEquation((u.base - root).simplify(), variable);
        }
      }
    }
  }

  // Check quotient decomposition: N(x) / D(x) = c
  final (num, den) = splitNumeratorDenominator(u);
  if (den != IntegerNumber.one) {
    if (!den.dependsOn(variable)) {
      return invertEquation(num, (c * den).simplify(), variable);
    } else if (!num.dependsOn(variable)) {
      if ((c is Number && c.isZero) || (c is RealNumber && c.value == 0.0)) {
        return const [];
      }
      return invertEquation(den, (num / c).simplify(), variable);
    } else if (!c.dependsOn(variable)) {
      final candidates = solveEquation((num - c * den).simplify(), variable);
      return candidates
          .where((r) => !isZeroExpr(den.substitute(variable, r).simplify()))
          .toList();
    }
  }

  if (u is Mul) {
    final constFactors = <Expr>[];
    final varFactors = <Expr>[];
    for (final f in u.factors) {
      if (f.dependsOn(variable)) {
        varFactors.add(f);
      } else {
        constFactors.add(f);
      }
    }
    if (constFactors.isNotEmpty && varFactors.isNotEmpty) {
      final constPart = constFactors.length == 1
          ? constFactors.first
          : Mul(constFactors).simplify();
      final varPart = varFactors.length == 1
          ? varFactors.first
          : Mul(varFactors).simplify();
      return invertEquation(varPart, (c / constPart).simplify(), variable);
    } else {
      final res = _solveProductTranscendental(u, c, variable);
      if (res != null) return res;
    }
  }

  return null;
}

/// Checks whether a real constant [c] is strictly outside $\[-maxAbs, maxAbs\]$.
bool isRealConstantOutOfRange(Expr c, double maxAbs) {
  if (c is RationalNumber) {
    return c.toDouble().abs() > maxAbs + 1e-12;
  }
  if (c is RealNumber) {
    return c.value.abs() > maxAbs + 1e-12;
  }
  if (c.freeVariables.isEmpty) {
    try {
      final comp = c.evaluateComplex();
      if (comp.b.abs() < 1e-12) {
        return comp.a.abs() > maxAbs + 1e-12;
      }
    } catch (_) {}
  }
  return false;
}

List<Expr>? _solveLambertWEquation(Expr E, Expr cPrime, String variable) {
  final cVal = _tryEvalReal(cPrime);
  const invE = 0.36787944117144232159587;
  final targets = <Expr>[];
  if (cVal != null) {
    if (cVal < -invE - 1e-12) {
      return const [];
    } else if ((cVal - (-invE)).abs() <= 1e-12) {
      targets.add(IntegerNumber.negativeOne);
    } else if (cVal < 0.0) {
      targets.add(LambertW(cPrime, branch: 0));
      targets.add(LambertW(cPrime, branch: -1));
    } else {
      targets.add(LambertW(cPrime, branch: 0));
    }
  } else {
    targets.add(LambertW(cPrime, branch: 0));
    targets.add(LambertW(cPrime, branch: -1));
  }

  final solutions = <Expr>[];
  for (final w in targets) {
    final subSolutions = solveEquation((E - w).simplify(), variable);
    solutions.addAll(subSolutions);
  }
  return deduplicateRoots(solutions);
}

List<Expr>? _solveProductTranscendental(Mul u, Expr c, String variable) {
  if (u.factors.length != 2) return null;
  final left = u.factors[0];
  final right = u.factors[1];

  Expr? expFactor;
  Expr? otherFactor;
  if (left is Pow && left.base == Constant.e) {
    expFactor = left.exponent;
    otherFactor = right;
  } else if (right is Pow && right.base == Constant.e) {
    expFactor = right.exponent;
    otherFactor = left;
  }

  if (expFactor != null && otherFactor != null) {
    final ratio = (expFactor / otherFactor).simplify();
    if (!ratio.dependsOn(variable) && !(ratio is Number && ratio.isZero)) {
      final cPrime = (c * ratio).simplify();
      return _solveLambertWEquation(expFactor, cPrime, variable);
    }
  }

  Expr? lnFactor;
  Expr? pFactor;
  if (left is Ln) {
    lnFactor = left.expr;
    pFactor = right;
  } else if (right is Ln) {
    lnFactor = right.expr;
    pFactor = left;
  }

  if (lnFactor != null && pFactor != null) {
    if ((lnFactor / pFactor).simplify() == IntegerNumber.one) {
      return _solveLambertWEquation(Ln(pFactor).simplify(), c, variable);
    }
  }

  return null;
}

List<Expr>? _solveAddTranscendental(Add u, Expr c, String variable) {
  if (u.terms.length != 2) return null;
  final left = u.terms[0];
  final right = u.terms[1];

  Expr? p;
  Expr? q;
  if (left is Ln && right is! Ln) {
    q = left.expr;
    p = right;
  } else if (right is Ln && left is! Ln) {
    q = right.expr;
    p = left;
  }
  if (p != null && q != null) {
    if ((q / p).simplify() == IntegerNumber.one) {
      return _solveLambertWEquation(p, Pow(Constant.e, c).simplify(), variable);
    }
  }
  return null;
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

(Expr base, Expr exponent, Expr coeff)? _extractExponentialTerm(
  Expr expr,
  String variable,
) {
  if (expr is Pow) {
    if (!expr.base.dependsOn(variable) && expr.exponent.dependsOn(variable)) {
      return (expr.base, expr.exponent, IntegerNumber.one);
    }
    return null;
  }
  if (expr is Mul) {
    final constFactors = <Expr>[];
    final varFactors = <Expr>[];
    for (final f in expr.factors) {
      if (f.dependsOn(variable)) {
        varFactors.add(f);
      } else {
        constFactors.add(f);
      }
    }
    if (constFactors.isNotEmpty && varFactors.length == 1) {
      final sub = _extractExponentialTerm(varFactors.first, variable);
      if (sub != null) {
        final constPart = constFactors.length == 1
            ? constFactors.first
            : Mul(constFactors).simplify();
        return (sub.$1, sub.$2, (constPart * sub.$3).simplify());
      }
    }
  }
  return null;
}

List<Expr>? _matchAffineExponential(Expr expr, String variable) {
  final terms = <Expr>[];
  _collectAdditiveTerms(expr, terms);
  if (terms.length < 2) return null;

  (Expr base, Expr exponent, Expr coeff)? expTerm;
  (Expr coeff, Expr constant)? linTerm;
  Expr constSum = IntegerNumber.zero;

  for (final t in terms) {
    if (!t.dependsOn(variable)) {
      constSum = (constSum + t).simplify();
      continue;
    }

    final lin = t.matchLinear(variable);
    if (lin != null && !(lin.a is Number && (lin.a as Number).isZero)) {
      if (linTerm != null) return null;
      linTerm = (lin.a, lin.b);
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

  final (base, exponent, k1) = expTerm;
  final (k2, linConst) = linTerm;
  final k3 = (constSum + linConst).simplify();

  final expLin = exponent.matchLinear(variable);
  if (expLin == null || (expLin.a is Number && (expLin.a as Number).isZero)) {
    return null;
  }
  final alpha = expLin.a;
  final beta = expLin.b;

  final B = (-k2 / (k1 * alpha)).simplify();
  final C = (-(k3 - (k2 * beta / alpha)) / k1).simplify();

  if (B is Number && B.isZero) return null;

  final lnBase = Ln(base).simplify();
  final negCdivB = (-C / B).simplify();
  final wArg = ((-lnBase / B) * Pow(Constant.e, (-C * lnBase / B).simplify()))
      .simplify();

  final wVal = _tryEvalReal(wArg);
  const invE = 0.36787944117144232159587;
  final branches = <int>[];
  if (wVal != null) {
    if (wVal < -invE - 1e-12) {
      return const [];
    } else if ((wVal - (-invE)).abs() <= 1e-12) {
      branches.add(0);
    } else if (wVal < 0.0) {
      branches.add(0);
      branches.add(-1);
    } else {
      branches.add(0);
    }
  } else {
    branches.add(0);
    branches.add(-1);
  }

  final roots = <Expr>[];
  for (final branch in branches) {
    final wTerm = branch == 0 && wVal != null && (wVal - (-invE)).abs() <= 1e-12
        ? IntegerNumber.negativeOne
        : LambertW(wArg, branch: branch);
    final y = (negCdivB - (wTerm / lnBase)).simplify();
    final x = ((y - beta) / alpha).simplify();
    roots.add(x);
  }
  return deduplicateRoots(roots);
}

double? _tryEvalReal(Expr expr) {
  if (expr is RationalNumber) return expr.toDouble();
  if (expr is RealNumber) return expr.value;
  if (expr.freeVariables.isEmpty) {
    try {
      final v = expr.evaluate(const {});
      if (v.isFinite) return v;
    } catch (_) {}
  }
  return null;
}
