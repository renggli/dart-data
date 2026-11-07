import 'dart:math' as math;

import '../algebra/simplify.dart';
import '../algebra/term_accumulator.dart';
import '../assumptions.dart';
import '../ast.dart';
import '../calculus/linear_form.dart';
import '../compiler.dart';
import '../type/expr_data_type.dart';
import 'polynomial.dart';
import 'trigonometric.dart';
import 'univariate.dart';

/// Isolates variable in additive expression or equates to 0, then inverts.
List<Expr>? isolateAndInvert(
  Expr expr,
  String variable, {
  Assumptions assumptions = Assumptions.none,
}) {
  // Case 1: expr is Add(terms)
  if (expr case Add(:final terms)) {
    final varTerms = <Expr>[];
    final constTerms = <Expr>[];
    for (final t in terms) {
      if (t.dependsOn(variable)) {
        varTerms.add(t);
      } else {
        constTerms.add(t);
      }
    }
    if (varTerms.isNotEmpty && constTerms.isNotEmpty) {
      final u = switch (varTerms) {
        [final single] => single,
        _ => Add(varTerms).simplify(assumptions: assumptions),
      };
      final c = (-(switch (constTerms) {
        [final single] => single,
        _ => Add(constTerms),
      })).simplify(assumptions: assumptions);
      final res = invertEquation(u, c, variable, assumptions: assumptions);
      if (res != null) return res;
    }
  }

  // Case 2: Affine exponential matching (e.g. a^x = bx + c)
  final affineExp = _matchAffineExponential(
    expr,
    variable,
    assumptions: assumptions,
  );
  if (affineExp != null) return affineExp;

  // Case 3: expr is alone (equated to 0)
  return invertEquation(
    expr,
    IntegerNumber.zero,
    variable,
    assumptions: assumptions,
  );
}

/// Inverts elementary and transcendental operations for equation $u = c$.
List<Expr>? invertEquation(
  Expr u,
  Expr c,
  String variable, {
  Assumptions assumptions = Assumptions.none,
}) {
  u = u.simplify(assumptions: assumptions);
  c = c.simplify(assumptions: assumptions);

  switch (u) {
    case Variable(:final name) when name == variable:
      return [c];
    case Ln(:final expr):
      final expC = Pow(Constant.e, c).simplify(assumptions: assumptions);
      return solveEquation(
        (expr - expC).simplify(assumptions: assumptions),
        variable,
        assumptions: assumptions,
      );
    case Sin(:final expr):
      return invertSin(expr, c, variable, assumptions: assumptions);
    case Cos(:final expr):
      return invertCos(expr, c, variable, assumptions: assumptions);
    case Tan(:final expr):
      return invertTan(expr, c, variable, assumptions: assumptions);
    case Asin(:final expr):
      if (isRealConstantOutOfRange(c, math.pi / 2)) return const [];
      final sinC = Sin(c).simplify(assumptions: assumptions);
      return solveEquation(
        (expr - sinC).simplify(assumptions: assumptions),
        variable,
        assumptions: assumptions,
      );
    case Acos(:final expr):
      final cNum = _tryEvalReal(c);
      if (cNum != null && (cNum < -1e-12 || cNum > math.pi + 1e-12)) {
        return const [];
      }
      final cosC = Cos(c).simplify(assumptions: assumptions);
      return solveEquation(
        (expr - cosC).simplify(assumptions: assumptions),
        variable,
        assumptions: assumptions,
      );
    case Atan(:final expr):
      final cNum = _tryEvalReal(c);
      if (cNum != null && cNum.abs() >= math.pi / 2 - 1e-12) {
        return const [];
      }
      final tanC = Tan(c).simplify(assumptions: assumptions);
      return solveEquation(
        (expr - tanC).simplify(assumptions: assumptions),
        variable,
        assumptions: assumptions,
      );
    case Sinh(:final expr):
      final rhs = Asinh(c).simplify(assumptions: assumptions);
      return solveEquation(
        (expr - rhs).simplify(assumptions: assumptions),
        variable,
        assumptions: assumptions,
      );
    case Cosh(:final expr):
      final cNum = _tryEvalReal(c);
      if (cNum != null && cNum < 1.0 - 1e-12) return const [];
      if (c is Number && c.isOne) {
        return solveEquation(expr, variable, assumptions: assumptions);
      }
      final pos = Acosh(c).simplify(assumptions: assumptions);
      final neg = (-pos).simplify(assumptions: assumptions);
      return deduplicateRoots([
        ...solveEquation(
          (expr - pos).simplify(assumptions: assumptions),
          variable,
          assumptions: assumptions,
        ),
        ...solveEquation(
          (expr - neg).simplify(assumptions: assumptions),
          variable,
          assumptions: assumptions,
        ),
      ]);
    case Tanh(:final expr):
      final cNum = _tryEvalReal(c);
      if (cNum != null && cNum.abs() >= 1.0 - 1e-12) return const [];
      final rhs = Atanh(c).simplify(assumptions: assumptions);
      return solveEquation(
        (expr - rhs).simplify(assumptions: assumptions),
        variable,
        assumptions: assumptions,
      );
    case Abs(:final expr):
      final cNum = _tryEvalReal(c);
      if (cNum != null && cNum < -1e-12) return const [];
      if (c is Number && c.isZero) {
        return solveEquation(expr, variable, assumptions: assumptions);
      }
      return deduplicateRoots([
        ...solveEquation(
          (expr - c).simplify(assumptions: assumptions),
          variable,
          assumptions: assumptions,
        ),
        ...solveEquation(
          (expr + c).simplify(assumptions: assumptions),
          variable,
          assumptions: assumptions,
        ),
      ]);
    case LambertW(:final expr, :final branch):
      final cNum = _tryEvalReal(c);
      if (cNum != null) {
        if (branch == 0 && cNum < -1.0 - 1e-12) return const [];
        if (branch == -1 && cNum > -1.0 + 1e-12) return const [];
      }
      final rhs = (c * Pow(Constant.e, c)).simplify(assumptions: assumptions);
      return solveEquation(
        (expr - rhs).simplify(assumptions: assumptions),
        variable,
        assumptions: assumptions,
      );
    case Asinh(:final expr):
      final rhs = Sinh(c).simplify(assumptions: assumptions);
      return solveEquation(
        (expr - rhs).simplify(assumptions: assumptions),
        variable,
        assumptions: assumptions,
      );
    case Acosh(:final expr):
      final cNum = _tryEvalReal(c);
      if (cNum != null && cNum < -1e-12) return const [];
      final rhs = Cosh(c).simplify(assumptions: assumptions);
      return solveEquation(
        (expr - rhs).simplify(assumptions: assumptions),
        variable,
        assumptions: assumptions,
      );
    case Atanh(:final expr):
      final rhs = Tanh(c).simplify(assumptions: assumptions);
      return solveEquation(
        (expr - rhs).simplify(assumptions: assumptions),
        variable,
        assumptions: assumptions,
      );
    case Erf(:final expr):
      if (c is Number && c.isZero) {
        return solveEquation(expr, variable, assumptions: assumptions);
      }
      final cNum = _tryEvalReal(c);
      if (cNum != null && cNum.abs() > 1.0 + 1e-12) return const [];
    case Add():
      final res = _solveAddTranscendental(
        u,
        c,
        variable,
        assumptions: assumptions,
      );
      if (res != null) return res;
    case Pow(:final base, :final exponent):
      // Exponential form: e^arg = c or b^arg = c
      if (!base.dependsOn(variable) && exponent.dependsOn(variable)) {
        if (base == Constant.e) {
          final cNum = _tryEvalReal(c);
          if (cNum != null && cNum <= 0.0) return const [];
          final lnC = Ln(c).simplify(assumptions: assumptions);
          return solveEquation(
            (exponent - lnC).simplify(assumptions: assumptions),
            variable,
            assumptions: assumptions,
          );
        }
        final bNum = _tryEvalReal(base);
        if (bNum == null || (bNum > 0.0 && bNum != 1.0)) {
          final cNum = _tryEvalReal(c);
          if (cNum != null && cNum <= 0.0) return const [];
          final rhs = (Ln(c) / Ln(base)).simplify(assumptions: assumptions);
          return solveEquation(
            (exponent - rhs).simplify(assumptions: assumptions),
            variable,
            assumptions: assumptions,
          );
        }
      }

      if (base.dependsOn(variable) && exponent.dependsOn(variable)) {
        if ((exponent / base).simplify(assumptions: assumptions) ==
            IntegerNumber.one) {
          final cNum = _tryEvalReal(c);
          if (cNum != null && cNum <= 0.0) return const [];
          return _solveLambertWEquation(
            Ln(base).simplify(assumptions: assumptions),
            Ln(c).simplify(assumptions: assumptions),
            variable,
            assumptions: assumptions,
          );
        }
      }

      if (!exponent.dependsOn(variable)) {
        if (exponent case final RationalNumber expConst when !expConst.isZero) {
          if (expConst.isNegative && isZeroExpr(c)) {
            return const [];
          }
          final cVal = _tryEvalReal(c);
          if (expConst case IntegerNumber(asInt: final int n) when n > 0) {
            if (n.isEven) {
              if (cVal != null && cVal < 0.0) {
                return const [];
              }
              final posRoot = rootConstant(c, n);
              final negRoot = (-posRoot).simplify(assumptions: assumptions);
              final s1 = solveEquation(
                (base - posRoot).simplify(assumptions: assumptions),
                variable,
                assumptions: assumptions,
              );
              final s2 = solveEquation(
                (base - negRoot).simplify(assumptions: assumptions),
                variable,
                assumptions: assumptions,
              );
              return deduplicateRoots([...s1, ...s2]);
            } else {
              final root = rootConstant(c, n);
              return solveEquation(
                (base - root).simplify(assumptions: assumptions),
                variable,
                assumptions: assumptions,
              );
            }
          }
          if (expConst.denominator.isEven || expConst.numerator.isEven) {
            if (cVal != null && cVal < 0.0) {
              return const [];
            }
          }
          final invP = expConst.reciprocal();
          final posRoot = Pow(c, invP).simplify(assumptions: assumptions);
          if (expConst.numerator.isEven && !isZeroExpr(c)) {
            final negRoot = (-posRoot).simplify(assumptions: assumptions);
            final s1 = solveEquation(
              (base - posRoot).simplify(assumptions: assumptions),
              variable,
              assumptions: assumptions,
            );
            final s2 = solveEquation(
              (base - negRoot).simplify(assumptions: assumptions),
              variable,
              assumptions: assumptions,
            );
            return deduplicateRoots([...s1, ...s2]);
          }
          return solveEquation(
            (base - posRoot).simplify(assumptions: assumptions),
            variable,
            assumptions: assumptions,
          );
        }
      }
    case _:
      break;
  }

  // Check quotient decomposition: N(x) / D(x) = c
  final (num, den) = splitNumeratorDenominator(u);
  if (den != IntegerNumber.one) {
    if (!den.dependsOn(variable)) {
      return invertEquation(
        num,
        (c * den).simplify(assumptions: assumptions),
        variable,
        assumptions: assumptions,
      );
    } else if (!num.dependsOn(variable)) {
      if (c is Number && c.isZero) {
        return const [];
      }
      return invertEquation(
        den,
        (num / c).simplify(assumptions: assumptions),
        variable,
        assumptions: assumptions,
      );
    } else if (!c.dependsOn(variable)) {
      final candidates = solveEquation(
        (num - c * den).simplify(assumptions: assumptions),
        variable,
        assumptions: assumptions,
      );
      return candidates
          .where(
            (r) => !isZeroExpr(
              den.substitute(variable, r).simplify(assumptions: assumptions),
            ),
          )
          .toList();
    }
  }

  if (u case Mul(:final factors)) {
    final constFactors = <Expr>[];
    final varFactors = <Expr>[];
    for (final f in factors) {
      if (f.dependsOn(variable)) {
        varFactors.add(f);
      } else {
        constFactors.add(f);
      }
    }
    if (constFactors.isNotEmpty && varFactors.isNotEmpty) {
      final constPart = switch (constFactors) {
        [final single] => single,
        _ => Mul(constFactors).simplify(assumptions: assumptions),
      };
      final varPart = switch (varFactors) {
        [final single] => single,
        _ => Mul(varFactors).simplify(assumptions: assumptions),
      };
      return invertEquation(
        varPart,
        (c / constPart).simplify(assumptions: assumptions),
        variable,
        assumptions: assumptions,
      );
    } else {
      final res = _solveProductTranscendental(
        u,
        c,
        variable,
        assumptions: assumptions,
      );
      if (res != null) return res;
    }
  }

  return null;
}

/// Checks whether a real constant [c] is strictly outside $\[-maxAbs, maxAbs\]$.
bool isRealConstantOutOfRange(Expr c, double maxAbs) {
  switch (c) {
    case RationalNumber():
      return c.toDouble().abs() > maxAbs + 1e-12;
    case RealNumber(:final value):
      return value.abs() > maxAbs + 1e-12;
    case _ when c.freeVariables.isEmpty:
      try {
        final comp = c.evaluateComplex();
        if (comp.b.abs() < 1e-12) {
          return comp.a.abs() > maxAbs + 1e-12;
        }
      } on ArgumentError {
        // Ignored.
      } on UnsupportedError {
        // Ignored.
      }
    case _:
      break;
  }
  return false;
}

List<Expr>? _solveLambertWEquation(
  Expr E,
  Expr cPrime,
  String variable, {
  Assumptions assumptions = Assumptions.none,
}) {
  final cVal = _tryEvalReal(cPrime);
  const invE = 1.0 / math.e;
  final List<Expr> targets;
  switch (cVal) {
    case final double v when v < -invE - 1e-12:
      return const [];
    case final double v when (v - (-invE)).abs() <= 1e-12:
      targets = [IntegerNumber.negativeOne];
    case final double v when v >= 0.0:
      targets = [LambertW(cPrime, branch: 0)];
    case _:
      targets = [LambertW(cPrime, branch: 0), LambertW(cPrime, branch: -1)];
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
  return deduplicateRoots(solutions);
}

List<Expr>? _solveProductTranscendental(
  Mul u,
  Expr c,
  String variable, {
  Assumptions assumptions = Assumptions.none,
}) {
  if (u.factors case [final f0, final f1]) {
    for (final (a, b) in [(f0, f1), (f1, f0)]) {
      if (a case Pow(:final base, :final exponent) when base == Constant.e) {
        final ratio = (exponent / b).simplify(assumptions: assumptions);
        if (!ratio.dependsOn(variable) && !(ratio is Number && ratio.isZero)) {
          final cPrime = (c * ratio).simplify(assumptions: assumptions);
          return _solveLambertWEquation(
            exponent,
            cPrime,
            variable,
            assumptions: assumptions,
          );
        }
      }
      if (a case Ln(:final expr)) {
        final ratio = (expr / b).simplify(assumptions: assumptions);
        if (!ratio.dependsOn(variable) && !(ratio is Number && ratio.isZero)) {
          final cPrime = (c * ratio).simplify(assumptions: assumptions);
          return _solveLambertWEquation(
            Ln(expr).simplify(assumptions: assumptions),
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

List<Expr>? _solveAddTranscendental(
  Add u,
  Expr c,
  String variable, {
  Assumptions assumptions = Assumptions.none,
}) {
  if (u.terms case [final t0, final t1]) {
    for (final (a, b) in [(t0, t1), (t1, t0)]) {
      if (a case Ln(:final expr) when b is! Ln) {
        final ratio = (b / expr).simplify(assumptions: assumptions);
        if (!ratio.dependsOn(variable) && !(ratio is Number && ratio.isZero)) {
          final cPrime = (ratio * Pow(Constant.e, c)).simplify(
            assumptions: assumptions,
          );
          return _solveLambertWEquation(
            b,
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
  switch (expr) {
    case Pow(:final base, :final exponent)
        when !base.dependsOn(variable) && exponent.dependsOn(variable):
      return (base, exponent, IntegerNumber.one);
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
            final base,
            final exponent,
            final coeff,
          )) {
            final constPart = switch (constFactors) {
              [final single] => single,
              _ => Mul(constFactors).simplify(),
            };
            return (base, exponent, (constPart * coeff).simplify());
          }
        }
      }
    case _:
      break;
  }
  return null;
}

List<Expr>? _matchAffineExponential(
  Expr expr,
  String variable, {
  Assumptions assumptions = Assumptions.none,
}) {
  final terms = <Expr>[];
  _collectAdditiveTerms(expr, terms);
  if (terms.length < 2) return null;

  (Expr base, Expr exponent, Expr coeff)? expTerm;
  (Expr coeff, Expr constant)? linTerm;
  Expr constSum = IntegerNumber.zero;

  for (final t in terms) {
    if (!t.dependsOn(variable)) {
      constSum = (constSum + t).simplify(assumptions: assumptions);
      continue;
    }

    if (t.matchLinear(variable) case (:final a, :final b)
        when !(a is Number && a.isZero)) {
      if (linTerm != null) return null;
      linTerm = (a, b);
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

  final lnBase = Ln(base).simplify(assumptions: assumptions);
  final negCdivB = (-C / B).simplify(assumptions: assumptions);
  final wArg =
      ((-lnBase / B) *
              Pow(
                Constant.e,
                (-C * lnBase / B).simplify(assumptions: assumptions),
              ))
          .simplify(assumptions: assumptions);

  final wVal = _tryEvalReal(wArg);
  const invE = 1.0 / math.e;
  final List<int> branches;
  switch (wVal) {
    case final double v when v < -invE - 1e-12:
      return const [];
    case final double v when (v - (-invE)).abs() <= 1e-12 || v >= 0.0:
      branches = const [0];
    case _:
      branches = const [0, -1];
  }

  final roots = <Expr>[];
  for (final branch in branches) {
    final wTerm = branch == 0 && wVal != null && (wVal - (-invE)).abs() <= 1e-12
        ? IntegerNumber.negativeOne
        : LambertW(wArg, branch: branch);
    final y = (negCdivB - (wTerm / lnBase)).simplify(assumptions: assumptions);
    final x = ((y - beta) / alpha).simplify(assumptions: assumptions);
    roots.add(x);
  }
  return deduplicateRoots(roots);
}

double? _tryEvalReal(Expr expr) {
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
