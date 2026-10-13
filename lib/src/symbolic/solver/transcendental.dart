import '../algebra/simplify.dart';
import '../ast.dart';
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
      return invertEquation(u, c, variable);
    }
  }

  // Case 2: expr is alone (equated to 0)
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
    // exp(arg) = c -> arg = ln(c) (requires c > 0)
    if (c is RationalNumber && (c.isNegative || c.isZero)) return const [];
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
    final sinC = Sin(c).simplify();
    return solveEquation((u.expr - sinC).simplify(), variable);
  }

  if (u is Acos) {
    final cosC = Cos(c).simplify();
    return solveEquation((u.expr - cosC).simplify(), variable);
  }

  if (u is Atan) {
    final tanC = Tan(c).simplify();
    return solveEquation((u.expr - tanC).simplify(), variable);
  }

  if (u is Pow) {
    if (!u.exponent.dependsOn(variable)) {
      if (u.exponent is RationalNumber) {
        final expConst = u.exponent as RationalNumber;
        if (!expConst.isZero) {
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
    }
  }

  if (u is Div) {
    if (!u.right.dependsOn(variable)) {
      return invertEquation(u.left, (c * u.right).simplify(), variable);
    } else if (!u.left.dependsOn(variable)) {
      if (c == RationalNumber.zero ||
          (c is RationalNumber && c.isZero) ||
          (c is RealNumber && c.value == 0.0)) {
        return const [];
      }
      return invertEquation(u.right, (u.left / c).simplify(), variable);
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
