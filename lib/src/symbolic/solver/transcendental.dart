import 'dart:math' as math;

import '../algebra/helpers.dart';
import '../algebra/simplify.dart';
import '../assumptions.dart';
import '../ast.dart';
import '../compiler.dart';
import '../type/expr_data_type.dart';
import 'polynomial.dart';
import 'transcendental_helpers.dart';
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
    final logCombined = tryCombineLogsAndSolve(
      terms,
      variable,
      assumptions: assumptions,
    );
    if (logCombined != null) return logCombined;

    // Radical isolation: c * base^(p/q) + R = 0 -> c^q * base^p - (-R)^q = 0
    final radicalSolved = tryIsolateRadicalAndSolve(
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
  final affineExp = matchAffineExponential(
    expr,
    variable,
    assumptions: assumptions,
  );
  if (affineExp != null) return affineExp;

  // Case 3: Polynomial in an exponential substitution P(b^(a*x + c)) = 0
  final expPolyRoots = tryPolynomialInExponential(
    expr,
    variable,
    assumptions: assumptions,
  );
  if (expPolyRoots != null) return expPolyRoots;

  // Case 3b: Polynomial in a single elementary function P(u(x)) = 0
  final fnPolyRoots = tryPolynomialInFunction(
    expr,
    variable,
    assumptions: assumptions,
  );
  if (fnPolyRoots != null) return fnPolyRoots;

  // Case 3c: Harmonic addition a*sin(u) + b*cos(u) + k = 0
  final harmonicRoots = tryHarmonicAddition(
    expr,
    variable,
    assumptions: assumptions,
  );
  if (harmonicRoots != null) return harmonicRoots;

  // Case 3d: Multiple-angle trigonometric reduction
  final multiTrigRoots = tryMultipleAngleTrig(
    expr,
    variable,
    assumptions: assumptions,
  );
  if (multiTrigRoots != null) return multiTrigRoots;

  // Case 3e: Quadratic trigonometric equations a*sin^2 + b*sin*cos + c*cos^2 + d = 0
  final quadTrigRoots = solveQuadraticTrig(
    expr,
    variable,
    assumptions: assumptions,
  );
  if (quadTrigRoots != null) return quadTrigRoots;

  // Case 4: expr is alone (equated to 0)
  return invertEquation(
    expr,
    IntegerNumber.zero,
    variable,
    assumptions: assumptions,
  );
}

/// Inverts elementary and transcendental operations for equation `u = c`.
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
      final cNum = tryEvalReal(c);
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
      final cNum = tryEvalReal(c);
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
      final cNum = tryEvalReal(c);
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
      ], assumptions: assumptions);
    case Tanh(:final expr):
      final cNum = tryEvalReal(c);
      if (cNum != null && cNum.abs() >= 1.0 - 1e-12) return const [];
      final rhs = Atanh(c).simplify(assumptions: assumptions);
      return solveEquation(
        (expr - rhs).simplify(assumptions: assumptions),
        variable,
        assumptions: assumptions,
      );
    case Abs(:final expr):
      final cNum = tryEvalReal(c);
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
      ], assumptions: assumptions);
    case LambertW(:final expr, :final branch):
      final cNum = tryEvalReal(c);
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
      final cNum = tryEvalReal(c);
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
      final cNum = tryEvalReal(c);
      if (cNum != null && cNum.abs() > 1.0 + 1e-12) return const [];
    case Add():
      final res = solveAddTranscendental(
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
          final cNum = tryEvalReal(c);
          if (cNum != null && cNum <= 0.0) return const [];
          final lnC = Ln(c).simplify(assumptions: assumptions);
          return solveEquation(
            (exponent - lnC).simplify(assumptions: assumptions),
            variable,
            assumptions: assumptions,
          );
        }
        final bNum = tryEvalReal(base);
        if (bNum == null || (bNum > 0.0 && bNum != 1.0)) {
          final cNum = tryEvalReal(c);
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
          final cNum = tryEvalReal(c);
          if (cNum != null && cNum <= 0.0) return const [];
          return solveLambertWEquation(
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
          final cVal = tryEvalReal(c);
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
              return deduplicateRoots([...s1, ...s2], assumptions: assumptions);
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
          final Expr posRoot;
          if (expConst.numerator.isOdd &&
              expConst.denominator.isOdd &&
              assumptions.domainOf(variable) != VariableDomain.complex &&
              ((cVal != null && cVal < 0.0) ||
                  (c is RationalNumber && c.isNegative))) {
            final absRoot = c is RealNumber
                ? RealNumber(math.pow(-c.value, invP.toDouble()).toDouble())
                : Pow(
                    (-c).simplify(assumptions: assumptions),
                    invP,
                  ).simplify(assumptions: assumptions);
            posRoot = (-absRoot).simplify(assumptions: assumptions);
          } else {
            posRoot = Pow(c, invP).simplify(assumptions: assumptions);
          }
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
            return deduplicateRoots([...s1, ...s2], assumptions: assumptions);
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
      final res = solveProductTranscendental(
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

/// Checks whether a real constant [c] is strictly outside `[-maxAbs, maxAbs]`.
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
