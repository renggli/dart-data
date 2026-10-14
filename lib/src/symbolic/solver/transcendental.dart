import 'dart:math' as math;

import '../algebra/simplify.dart';
import '../ast.dart';
import '../calculus/linear_form.dart';
import 'polynomial.dart';
import 'trigonometric.dart';
import 'univariate.dart';

/// Isolates variable in additive expression or equates to 0, then inverts.
List<Expr>? isolateAndInvert(Expr expr, String variable) {
  // Case 1: expr is Add(left, right) or Sub(left, right)
  if (expr is Add || expr is Sub) {
    final (u, c) = switch (expr) {
      Add(:final left, :final right)
          when left.dependsOn(variable) && !right.dependsOn(variable) =>
        (left, (-right).simplify()),
      Add(:final left, :final right)
          when !left.dependsOn(variable) && right.dependsOn(variable) =>
        (right, (-left).simplify()),
      Sub(:final left, :final right)
          when left.dependsOn(variable) && !right.dependsOn(variable) =>
        (left, right.simplify()),
      Sub(:final left, :final right)
          when !left.dependsOn(variable) && right.dependsOn(variable) =>
        (right, left.simplify()),
      _ => (null, null),
    };

    if (u != null && c != null) {
      final res = invertEquation(u, c, variable);
      if (res != null) return res;
    }
  }

  // Case 2: Affine exponential matching (e.g. a^x = bx + c)
  final affineExp = _matchAffineExponential(expr, variable);
  if (affineExp != null) return affineExp;

  // Case 3: expr is alone (equated to 0)
  return invertEquation(expr, RationalNumber.zero, variable);
}

/// Inverts elementary and transcendental operations for equation $u = c$.
List<Expr>? invertEquation(Expr u, Expr c, String variable) {
  u = u.simplify();
  c = c.simplify();

  if (u is Variable && u.name == variable) {
    return [c];
  }

  if (u is Exp) {
    // exp(arg) = c -> arg = ln(c) (requires c > 0 for real constants)
    final cNum = _tryEvalReal(c);
    if (cNum != null && cNum <= 0.0) return const [];
    final lnC = Ln(c).simplify();
    return solveEquation((u.expr - lnC).simplify(), variable);
  }

  if (u is Ln) {
    // ln(arg) = c -> arg = exp(c)
    final expC = Exp(c).simplify();
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
    if (c == RationalNumber.one || (c is RealNumber && c.value == 1.0)) {
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
    if (c == RationalNumber.zero || (c is RealNumber && c.value == 0.0)) {
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
    final rhs = Mul(c, Exp(c)).simplify();
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
    if (c is RationalNumber && c.isZero) {
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
    if (u.base.dependsOn(variable) && u.exponent.dependsOn(variable)) {
      if ((u.exponent / u.base).simplify() == RationalNumber.one) {
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
          if (expConst.numerator < 0 &&
              (c == RationalNumber.zero ||
                  (c is RealNumber && c.value == 0.0))) {
            return const [];
          }
          if (expConst.isInteger) {
            final n = expConst.numerator;
            if (n > 0) {
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
          final invP = RationalNumber(
            expConst.numerator < 0
                ? -expConst.denominator
                : expConst.denominator,
            expConst.numerator.abs(),
          );
          if (expConst.denominator.isEven &&
              ((c is RationalNumber && c.isNegative) ||
                  (c is RealNumber && c.value < 0))) {
            return const [];
          }
          final root = c.pow(invP).simplify();
          return solveEquation((u.base - root).simplify(), variable);
        }
      }
    }
  }

  if (u is Neg) {
    return invertEquation(u.expr, (-c).simplify(), variable);
  }

  if (u is Mul) {
    if (!u.left.dependsOn(variable)) {
      return invertEquation(u.right, (c / u.left).simplify(), variable);
    } else if (!u.right.dependsOn(variable)) {
      return invertEquation(u.left, (c / u.right).simplify(), variable);
    } else {
      final res = _solveProductTranscendental(u, c, variable);
      if (res != null) return res;
    }
  }

  if (u is Div) {
    final num = u.left;
    final den = u.right;
    if (!den.dependsOn(variable)) {
      return invertEquation(num, (c * den).simplify(), variable);
    } else if (!num.dependsOn(variable)) {
      if (c == RationalNumber.zero ||
          (c is RationalNumber && c.isZero) ||
          (c is RealNumber && c.value == 0.0)) {
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

  return null;
}

/// Checks whether a real constant [c] is strictly outside $\[-maxAbs, maxAbs\]$.
bool isRealConstantOutOfRange(Expr c, double maxAbs) {
  if (c is RationalNumber) {
    return c.numerator.abs() > c.denominator * maxAbs;
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
      targets.add(RationalNumber.negativeOne);
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
  Expr? expFactor;
  Expr? otherFactor;
  if (u.left is Exp) {
    expFactor = (u.left as Exp).expr;
    otherFactor = u.right;
  } else if (u.right is Exp) {
    expFactor = (u.right as Exp).expr;
    otherFactor = u.left;
  }

  if (expFactor != null && otherFactor != null) {
    final ratio = (expFactor / otherFactor).simplify();
    if (!ratio.dependsOn(variable) && ratio != RationalNumber.zero) {
      final cPrime = (c * ratio).simplify();
      return _solveLambertWEquation(expFactor, cPrime, variable);
    }
  }

  Expr? lnFactor;
  Expr? pFactor;
  if (u.left is Ln) {
    lnFactor = (u.left as Ln).expr;
    pFactor = u.right;
  } else if (u.right is Ln) {
    lnFactor = (u.right as Ln).expr;
    pFactor = u.left;
  }

  if (lnFactor != null && pFactor != null) {
    if ((lnFactor / pFactor).simplify() == RationalNumber.one) {
      return _solveLambertWEquation(Ln(pFactor).simplify(), c, variable);
    }
  }

  return null;
}

List<Expr>? _solveAddTranscendental(Add u, Expr c, String variable) {
  Expr? p;
  Expr? q;
  if (u.left is Ln && u.right is! Ln) {
    q = (u.left as Ln).expr;
    p = u.right;
  } else if (u.right is Ln && u.left is! Ln) {
    q = (u.right as Ln).expr;
    p = u.left;
  }
  if (p != null && q != null) {
    if ((q / p).simplify() == RationalNumber.one) {
      return _solveLambertWEquation(p, Exp(c).simplify(), variable);
    }
  }
  return null;
}

void _collectAdditiveTerms(Expr expr, List<Expr> terms) {
  switch (expr) {
    case Add(:final left, :final right):
      _collectAdditiveTerms(left, terms);
      _collectAdditiveTerms(right, terms);
    case Sub(:final left, :final right):
      _collectAdditiveTerms(left, terms);
      _collectAdditiveTerms((-right).simplify(), terms);
    case _:
      terms.add(expr);
  }
}

(Expr base, Expr exponent, Expr coeff)? _extractExponentialTerm(
  Expr expr,
  String variable,
) {
  if (expr is Neg) {
    final sub = _extractExponentialTerm(expr.expr, variable);
    if (sub != null) {
      return (sub.$1, sub.$2, (-sub.$3).simplify());
    }
    return null;
  }
  if (expr is Exp) {
    if (expr.expr.dependsOn(variable)) {
      return (ConstantNumber.e, expr.expr, RationalNumber.one);
    }
    return null;
  }
  if (expr is Pow) {
    if (!expr.base.dependsOn(variable) && expr.exponent.dependsOn(variable)) {
      return (expr.base, expr.exponent, RationalNumber.one);
    }
    return null;
  }
  if (expr is Mul) {
    if (!expr.left.dependsOn(variable) && expr.right.dependsOn(variable)) {
      final sub = _extractExponentialTerm(expr.right, variable);
      if (sub != null) {
        return (sub.$1, sub.$2, (expr.left * sub.$3).simplify());
      }
    } else if (!expr.right.dependsOn(variable) &&
        expr.left.dependsOn(variable)) {
      final sub = _extractExponentialTerm(expr.left, variable);
      if (sub != null) {
        return (sub.$1, sub.$2, (expr.right * sub.$3).simplify());
      }
    }
  }
  if (expr is Div && !expr.right.dependsOn(variable)) {
    final sub = _extractExponentialTerm(expr.left, variable);
    if (sub != null) {
      return (sub.$1, sub.$2, (sub.$3 / expr.right).simplify());
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
  var constSum = RationalNumber.zero as Expr;

  for (final t in terms) {
    if (!t.dependsOn(variable)) {
      constSum = (constSum + t).simplify();
      continue;
    }

    final lin = t.matchLinear(variable);
    if (lin != null && lin.a != RationalNumber.zero) {
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
  if (expLin == null || expLin.a == RationalNumber.zero) return null;
  final alpha = expLin.a;
  final beta = expLin.b;

  final B = (-k2 / (k1 * alpha)).simplify();
  final C = (-(k3 - (k2 * beta / alpha)) / k1).simplify();

  if (B == RationalNumber.zero) return null;

  final lnBase = Ln(base).simplify();
  final negCdivB = (-C / B).simplify();
  final wArg = ((-lnBase / B) * Exp((-C * lnBase / B).simplify())).simplify();

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
        ? RationalNumber.negativeOne
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
