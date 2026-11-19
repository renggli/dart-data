import 'dart:math' as math;

import '../algebra/expand.dart';
import '../algebra/factor.dart';
import '../algebra/simplify.dart';
import '../algebra/simplify/domain.dart';
import '../algebra/term_accumulator.dart';
import '../algebra/trig.dart';
import '../assumptions.dart';
import '../ast.dart';
import '../calculus/linear_form.dart';
import '../compiler.dart';
import '../number/integer.dart';
import '../type/expr_data_type.dart';
import 'polynomial.dart';
import 'trigonometric.dart';
import 'univariate.dart';

/// Isolates variable in additive expression or equates to 0, then inverts.
List<Expr>? isolateAndInvert(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
}) {
  // Case 1: expr is Add(terms)
  if (expr case Add(:final terms)) {
    // Log combination: sum a_i * ln(u_i) + C -> ln(prod u_i^a_i) + C
    final logCombined = _tryCombineLogsAndSolve(
      terms,
      variable,
      assumptions: assumptions,
    );
    if (logCombined != null) return logCombined;

    // Radical isolation: c * base^(p/q) + R = 0 -> c^q * base^p - (-R)^q = 0
    final radicalSolved = _tryIsolateRadicalAndSolve(
      terms,
      variable,
      assumptions: assumptions,
    );
    if (radicalSolved != null) return radicalSolved;

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

  // Case 3: Polynomial in an exponential substitution P(b^(a*x + c)) = 0
  final expPolyRoots = _tryPolynomialInExponential(
    expr,
    variable,
    assumptions: assumptions,
  );
  if (expPolyRoots != null) return expPolyRoots;

  // Case 3b: Polynomial in a single elementary function P(u(x)) = 0
  final fnPolyRoots = _tryPolynomialInFunction(
    expr,
    variable,
    assumptions: assumptions,
  );
  if (fnPolyRoots != null) return fnPolyRoots;

  // Case 3c: Harmonic addition a*sin(u) + b*cos(u) + k = 0
  final harmonicRoots = _tryHarmonicAddition(
    expr,
    variable,
    assumptions: assumptions,
  );
  if (harmonicRoots != null) return harmonicRoots;

  // Case 3d: Multiple-angle trigonometric reduction
  final multiTrigRoots = _tryMultipleAngleTrig(
    expr,
    variable,
    assumptions: assumptions,
  );
  if (multiTrigRoots != null) return multiTrigRoots;

  // Case 4: expr is alone (equated to 0)
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
  required Assumptions assumptions,
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
  required Assumptions assumptions,
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
  required Assumptions assumptions,
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
        if (b
            case Pow(
              base: final powBase,
              exponent: IntegerNumber(isNegativeOne: true),
            )
            when powBase == expr && expr.dependsOn(variable)) {
          return _solveLambertWEquation(
            (-Ln(expr)).simplify(assumptions: assumptions),
            (-c).simplify(assumptions: assumptions),
            variable,
            assumptions: assumptions,
          );
        }
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
  required Assumptions assumptions,
}) {
  if (u.terms case [final t0, final t1]) {
    for (final (a, b) in [(t0, t1), (t1, t0)]) {
      final (Expr? lnArg, Expr k) = switch (a) {
        Ln(:final expr) => (expr, IntegerNumber.one),
        Mul(:final factors) => () {
          Expr? arg;
          final constFactors = <Expr>[];
          for (final f in factors) {
            if (arg == null && f is Ln) {
              arg = f.expr;
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
            _ => Mul(constFactors).simplify(assumptions: assumptions),
          };
          return (arg, coeff);
        }(),
        _ => (null, IntegerNumber.one),
      };
      if (lnArg != null && b is! Ln) {
        final ratio = (b / (k * lnArg)).simplify(assumptions: assumptions);
        if (!ratio.dependsOn(variable) && !(ratio is Number && ratio.isZero)) {
          final cOverK = (c / k).simplify(assumptions: assumptions);
          final cPrime = (ratio * Pow(Constant.e, cOverK)).simplify(
            assumptions: assumptions,
          );
          return _solveLambertWEquation(
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
  required Assumptions assumptions,
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

List<Expr>? _tryCombineLogsAndSolve(
  List<Expr> terms,
  String variable, {
  required Assumptions assumptions,
}) {
  final lnTerms = <({Expr u, RationalNumber coeff})>[];
  final rest = <Expr>[];
  for (final t in terms) {
    switch (t) {
      case Ln(:final expr):
        lnTerms.add((u: expr, coeff: IntegerNumber.one));
      case Mul(factors: [final RationalNumber a, Ln(:final expr)]):
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
        : Pow(u, coeff).simplify(assumptions: assumptions);
    prod = (prod * term).simplify(assumptions: assumptions);
  }
  final combined = Add([Ln(prod).simplify(assumptions: assumptions), ...rest])
      .simplify(assumptions: assumptions);
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
      if (uVal.freeVariables.isNotEmpty) continue;
      if (isPositiveExpr(uVal, assumptions: assumptions)) continue;
      final numVal = _tryEvalReal(uVal);
      if (numVal == null || numVal <= 0.0) return false;
    }
    return true;
  }).toList();
}

bool _hasVariableRadical(Expr expr, String variable) => expr.anyNode(
  (n) => n is Pow && n.exponent is FractionNumber && n.base.dependsOn(variable),
);

List<Expr>? _tryIsolateRadicalAndSolve(
  List<Expr> terms,
  String variable, {
  required Assumptions assumptions,
}) {
  ({Expr c, Expr base, Integer p, int q})? radical;
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
      final q = denominator.asInt;
      if (q == null || q < 2 || q > 4) return null;
      radical = (c: IntegerNumber.one, base: base, p: numerator, q: q);
    } else if (t case Mul(:final factors)) {
      Expr? radBase;
      Integer? radP;
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
          final q = denominator.asInt;
          if (q == null || q < 2 || q > 4) return null;
          radBase = base;
          radP = numerator;
          radQ = q;
        } else if (_hasVariableRadical(f, variable)) {
          return null;
        } else {
          otherFactors.add(f);
        }
      }
      if (radBase == null) return null;
      final c = switch (otherFactors) {
        [] => IntegerNumber.one,
        [final single] => single,
        _ => Mul(otherFactors).simplify(assumptions: assumptions),
      };
      radical = (c: c, base: radBase, p: radP!, q: radQ!);
    } else {
      return null;
    }
  }

  if (radical == null || rest.isEmpty) return null;
  final (:c, :base, :p, :q) = radical;
  final r = rest.length == 1
      ? rest.single
      : Add(rest).simplify(assumptions: assumptions);
  final negR = (-r).simplify(assumptions: assumptions);
  final poly =
      (Pow(c, IntegerNumber.of(q)) * Pow(base, IntegerNumber(p)) -
              Pow(negR, IntegerNumber.of(q)))
          .expand(assumptions: assumptions)
          .simplify(assumptions: assumptions);
  return solveEquation(poly, variable, assumptions: assumptions);
}

List<Expr>? _tryPolynomialInExponential(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
}) {
  final expNodes = <({Pow node, Expr base, RationalNumber alpha, Expr beta})>[];

  void collect(Expr e) {
    if (e case Pow(:final base, :final exponent)) {
      if (!base.dependsOn(variable) && exponent.dependsOn(variable)) {
        final lin = exponent.matchLinear(variable);
        if (lin?.a case final RationalNumber alpha when !alpha.isZero) {
          expNodes.add((node: e, base: base, alpha: alpha, beta: lin!.b));
          return;
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
  final firstSign = expNodes.first.alpha.sign;
  for (final entry in expNodes) {
    if (entry.base != commonBase || entry.alpha.sign != firstSign) return null;
  }

  // Fundamental rational slope alpha0 = sign * gcd(numerators) / lcm(denominators)
  var gcdNum = expNodes.first.alpha.numerator.abs();
  var lcmDen = expNodes.first.alpha.denominator;
  for (var i = 1; i < expNodes.length; i++) {
    final r = expNodes[i].alpha;
    final numAbs = r.numerator.abs();
    gcdNum = gcdNum.gcd(numAbs);
    lcmDen = (lcmDen ~/ lcmDen.gcd(r.denominator)) * r.denominator;
  }
  final alpha0 = RationalNumber.of(firstSign < 0 ? -gcdNum : gcdNum, lcmDen);

  const uName = '_u_exp';
  const uVar = Variable(uName);
  final replacements = <Pow, Expr>{};
  for (final (:node, :base, :alpha, :beta) in expNodes) {
    final ratio = alpha.divRational(alpha0);
    if (ratio is! IntegerNumber) return null;
    final m = ratio.asInt;
    if (m == null || m < 1 || m > 6) return null;
    final uPow = m == 1 ? uVar : Pow(uVar, IntegerNumber.of(m));
    final bScale = (beta is Number && beta.isZero)
        ? IntegerNumber.one
        : Pow(base, beta);
    replacements[node] = (bScale * uPow).simplify(
      assumptions: Assumptions.none,
    );
  }

  Expr substituteExp(Expr e) {
    if (e is Pow && replacements.containsKey(e)) {
      return replacements[e]!;
    }
    return e.mapChildren(substituteExp);
  }

  final polyU = substituteExp(expr).simplify(assumptions: Assumptions.none);
  if (polyU.dependsOn(variable) || !polyU.dependsOn(uName)) return null;

  final uRoots = solveEquation(polyU, uName, assumptions: Assumptions.none);
  if (uRoots.isEmpty) return const [];

  final targetPow = Pow(
    commonBase,
    (alpha0 * Variable(variable)).simplify(assumptions: assumptions),
  );
  final results = <Expr>[];
  final seen = <Expr>{};
  for (final uRoot in uRoots) {
    final roots = invertEquation(
      targetPow,
      uRoot,
      variable,
      assumptions: assumptions,
    );
    if (roots == null) return null;
    for (final r in roots) {
      if (seen.add(r)) results.add(r);
    }
  }
  return results;
}

bool _isElementaryFunctionNode(Expr e, String variable) => switch (e) {
  Ln(:final expr) ||
  Sin(:final expr) ||
  Cos(:final expr) ||
  Tan(:final expr) ||
  Sinh(:final expr) ||
  Cosh(:final expr) ||
  Tanh(:final expr) ||
  Asin(:final expr) ||
  Acos(:final expr) ||
  Atan(:final expr) ||
  LambertW(:final expr) => expr.dependsOn(variable),
  _ => false,
};

List<Expr>? _tryPolynomialInFunction(
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
    final simplified = polyU.simplify(assumptions: Assumptions.none);
    if (simplified.dependsOn(variable) || !simplified.dependsOn(uName)) {
      return null;
    }
    final uRoots = solveEquation(
      simplified,
      uName,
      assumptions: Assumptions.none,
    );
    if (uRoots.isEmpty) return const [];
    final results = <Expr>[];
    for (final uRoot in uRoots) {
      final roots = invertEquation(
        uNode,
        uRoot,
        variable,
        assumptions: assumptions,
      );
      if (roots == null) return null;
      results.addAll(roots);
    }
    return deduplicateRoots(results);
  }

  if (fnNodes.length == 1) {
    final uNode = fnNodes.first;
    Expr subst(Expr e) => e == uNode ? uVar : e.mapChildren(subst);
    return solveSubstituted(uNode, subst(expr));
  }

  if (fnNodes.length == 2) {
    final list = fnNodes.toList();
    final (Sin? sinNode, Cos? cosNode) = switch ((list[0], list[1])) {
      (final Sin s, final Cos c) when s.expr == c.expr => (s, c),
      (final Cos c, final Sin s) when s.expr == c.expr => (s, c),
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
            final oneMinusU2 = IntegerNumber.one - Pow(uVar, IntegerNumber.two);
            return k == 2
                ? oneMinusU2
                : Pow(oneMinusU2, IntegerNumber.of(k ~/ 2));
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

List<Expr>? _tryMultipleAngleTrig(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
}) {
  final trigAtoms = <Expr>{};
  void collectTrig(Expr e) {
    switch (e) {
      case Sin(expr: final arg) || Cos(expr: final arg) || Tan(expr: final arg)
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
      case Sin(expr: final arg) || Cos(expr: final arg) || Tan(expr: final arg)
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

List<Expr>? _tryHarmonicAddition(
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
    Expr? trigNode;
    final coeffFactors = <Expr>[];
    for (final f in factors) {
      if (!f.dependsOn(variable)) {
        coeffFactors.add(f);
      } else if ((f is Sin || f is Cos) && trigNode == null) {
        trigNode = f;
      } else {
        return null;
      }
    }
    if (trigNode == null) return null;
    final arg = trigNode is Sin ? trigNode.expr : (trigNode as Cos).expr;
    if (arg.matchLinear(variable) == null) return null;
    if (commonArg == null) {
      commonArg = arg;
    } else if (commonArg != arg) {
      return null;
    }
    final coeff = coeffFactors.isEmpty
        ? IntegerNumber.one
        : Mul(coeffFactors).simplify(assumptions: assumptions);
    if (trigNode is Sin) {
      sinCoeffs.add(coeff);
    } else {
      cosCoeffs.add(coeff);
    }
  }

  if (commonArg == null || sinCoeffs.isEmpty || cosCoeffs.isEmpty) {
    return null;
  }
  final a = Add(sinCoeffs).simplify(assumptions: assumptions);
  final b = Add(cosCoeffs).simplify(assumptions: assumptions);
  if ((a is Number && a.isZero) || (b is Number && b.isZero)) return null;

  final r = Pow(
    a * a + b * b,
    FractionNumber.half,
  ).simplify(assumptions: assumptions);
  final k = constTerms.isEmpty
      ? IntegerNumber.zero
      : Add(constTerms).simplify(assumptions: assumptions);

  if (k.freeVariables.isEmpty && r.freeVariables.isEmpty) {
    final kAbs = k.evaluate().abs();
    final rVal = r.evaluate();
    if (kAbs.isFinite && rVal.isFinite && kAbs > rVal + 1e-12) {
      return const [];
    }
  }

  final Expr phi;
  if ((a is RealNumber || b is RealNumber) &&
      a.freeVariables.isEmpty &&
      b.freeVariables.isEmpty) {
    phi = RealNumber(math.atan2(b.evaluate(), a.evaluate()));
  } else {
    final ratio = (b / a).simplify(assumptions: assumptions);
    final baseAtan = Atan(ratio).simplify(assumptions: assumptions);
    final aPos =
        isPositiveExpr(a, assumptions: assumptions) ||
        (a.freeVariables.isEmpty && a.evaluate() > 0);
    final aNeg =
        isNegativeExpr(a, assumptions: assumptions) ||
        (a.freeVariables.isEmpty && a.evaluate() < 0);
    if (aPos) {
      phi = baseAtan;
    } else if (aNeg) {
      final bNonNeg = b.freeVariables.isEmpty
          ? b.evaluate() >= 0
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
