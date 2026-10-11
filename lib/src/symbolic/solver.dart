import 'dart:math' as math;

import 'ast.dart';
import 'calculus/differentiation.dart';
import 'calculus/linear_form.dart';
import 'simplifier.dart';

/// Extension providing analytical equation solving on [Expr].
extension SolverExtension on Expr {
  /// Solves the algebraic equation $\text{this} = 0$ for [variable].
  ///
  /// Conceptually, this isolates the values of [variable] that satisfy the
  /// equation $\text{this} = 0$ (such as finding roots where $2x - 6 = 0$ or
  /// $x^2 - 5x + 6 = 0$). Formally, this isolates analytical roots of
  /// univariate equations:
  /// - Linear equations: $a x + b = 0 \implies x = -b / a$
  /// - Quadratic polynomials:
  ///   $a x^2 + b x + c = 0 \implies x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}$
  /// - Factored products:
  ///   $f(x) \cdot g(x) = 0 \implies \text{solve}(f) \cup \text{solve}(g)$ via
  ///   the zero-product property
  /// - Invertible transcendental compositions: $\exp(f(x)) = c$,
  ///   $\ln(f(x)) = c$, $\sin(f(x)) = c$, $\cos(f(x)) = c$, and isolated powers
  ///
  /// Returns a list of unique exact solution expressions.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final roots = (x * x - 4).solve('x');
  /// // roots: [Constant(-2.0), Constant(2.0)]
  /// ```
  List<Expr> solve(String variable) => _solveEquation(this, variable);
}

/// Extension providing linear equation system solving on [Iterable] of [Expr].
extension SystemSolverExtension on Iterable<Expr> {
  /// Solves the linear system $f_i(x_1, \dots, x_n) = 0$ for [variables].
  ///
  /// Conceptually, this finds the common solution satisfying multiple
  /// simultaneous linear equations (such as $x + y - 10 = 0$ and
  /// $x - y - 2 = 0$).
  ///
  /// Formally, this performs exact symbolic Gaussian elimination with partial
  /// pivoting over the affine coefficient matrix. Returns a mapping from each
  /// variable name to its solution expression, or `null` if the system is
  /// singular, underdetermined, or contradictory.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final y = Variable('y');
  /// final solution = [x + y - 10, x - y - 2].solveSystem(['x', 'y']);
  /// // solution?['x'] == Constant(6.0), solution?['y'] == Constant(4.0)
  /// ```
  Map<String, Expr>? solveSystem(List<String> variables) =>
      _solveSystem(toList(), variables);
}

List<Expr> _solveEquation(Expr expr, String variable) {
  expr = expr.simplify();

  if (!expr.dependsOn(variable)) {
    return const [];
  }

  // Linear form: a * x + b = 0
  final lin = expr.matchLinear(variable);
  if (lin != null) {
    final sol = ((-lin.b) / lin.a).simplify();
    return [sol];
  }

  // Quadratic form: a * x^2 + b * x + c = 0
  final quad = _matchQuadratic(expr, variable);
  if (quad != null) {
    final a = quad.a;
    final b = quad.b;
    final c = quad.c;
    final disc = ((b * b) - (const Constant(4.0) * a * c)).simplify();

    if (disc is Constant) {
      if (disc.value < 0.0) {
        return const []; // No real roots
      } else if (disc.value == 0.0) {
        final root = ((-b) / (const Constant(2.0) * a)).simplify();
        return [root];
      } else {
        final sqrtDisc = Constant(math.sqrt(disc.value));
        final twoA = (const Constant(2.0) * a).simplify();
        final r1 = (((-b) + sqrtDisc) / twoA).simplify();
        final r2 = (((-b) - sqrtDisc) / twoA).simplify();
        return _deduplicate([r1, r2]);
      }
    } else {
      final sqrtDisc = disc.pow(const Constant(0.5)).simplify();
      final twoA = (const Constant(2.0) * a).simplify();
      final r1 = (((-b) + sqrtDisc) / twoA).simplify();
      final r2 = (((-b) - sqrtDisc) / twoA).simplify();
      return _deduplicate([r1, r2]);
    }
  }

  // Factored products: f(x) * g(x) = 0
  if (expr is Mul) {
    final rootsLeft = _solveEquation(expr.left, variable);
    final rootsRight = _solveEquation(expr.right, variable);
    return _deduplicate([...rootsLeft, ...rootsRight]);
  }

  // Transcendental isolation: f(u(x)) = C
  final trans = _isolateAndInvert(expr, variable);
  if (trans != null) {
    return _deduplicate(trans);
  }

  return const [];
}

({Expr a, Expr b, Expr c})? _matchQuadratic(Expr expr, String variable) {
  // Compute second derivative f''(x)
  final d1 = expr.diff(variable).simplify();
  final d2 = d1.diff(variable).simplify();
  if (d2.dependsOn(variable)) {
    return null;
  }

  // a = f''(x) / 2
  final a = (d2 / const Constant(2.0)).simplify();
  if (a is Constant && a.value == 0.0) {
    return null;
  }

  // b = f'(0)
  final b = d1.substitute(variable, const Constant(0.0)).simplify();
  if (b.dependsOn(variable)) return null;

  // c = f(0)
  final c = expr.substitute(variable, const Constant(0.0)).simplify();
  if (c.dependsOn(variable)) return null;

  return (a: a, b: b, c: c);
}

List<Expr>? _isolateAndInvert(Expr expr, String variable) {
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
      return _invertEquation(u, c, variable);
    }
  }

  // Case 2: expr is alone (equated to 0)
  return _invertEquation(expr, const Constant(0.0), variable);
}

List<Expr>? _invertEquation(Expr u, Expr c, String variable) {
  u = u.simplify();
  c = c.simplify();

  if (u is Variable && u.name == variable) {
    return [c];
  }

  if (u is Exp) {
    // exp(arg) = c -> arg = ln(c) (requires c > 0)
    if (c is Constant && c.value <= 0.0) return const [];
    final lnC = Ln(c).simplify();
    return _solveEquation((u.expr - lnC).simplify(), variable);
  }

  if (u is Ln) {
    // ln(arg) = c -> arg = exp(c)
    final expC = Exp(c).simplify();
    return _solveEquation((u.expr - expC).simplify(), variable);
  }

  if (u is Pow) {
    if (!u.exponent.dependsOn(variable)) {
      if (u.exponent is Constant) {
        final p = (u.exponent as Constant).value;
        if (p != 0.0) {
          final invP = 1.0 / p;
          if (p.toInt() == p && p.toInt().isEven) {
            // Even power: u^n = c -> u = +/- c^(1/n) (requires c >= 0)
            if (c is Constant && c.value < 0.0) return const [];
            final posRoot = c.pow(Constant(invP)).simplify();
            final negRoot = (-posRoot).simplify();
            final s1 = _solveEquation((u.base - posRoot).simplify(), variable);
            final s2 = _solveEquation((u.base - negRoot).simplify(), variable);
            return _deduplicate([...s1, ...s2]);
          } else {
            final root = c.pow(Constant(invP)).simplify();
            return _solveEquation((u.base - root).simplify(), variable);
          }
        }
      }
    }
  }

  if (u is Neg) {
    return _invertEquation(u.expr, (-c).simplify(), variable);
  }

  if (u is Mul) {
    if (!u.left.dependsOn(variable)) {
      return _invertEquation(u.right, (c / u.left).simplify(), variable);
    } else if (!u.right.dependsOn(variable)) {
      return _invertEquation(u.left, (c / u.right).simplify(), variable);
    }
  }

  if (u is Div) {
    if (!u.right.dependsOn(variable)) {
      return _invertEquation(u.left, (c * u.right).simplify(), variable);
    }
  }

  return null;
}

Map<String, Expr>? _solveSystem(List<Expr> equations, List<String> variables) {
  final n = variables.length;
  if (equations.length != n || n == 0) {
    return null;
  }

  // Extract coefficient matrix A and right-hand side b
  // A_ij * x_j = b_i where equation is f_i = 0 => sum(A_ij * x_j) + c_i = 0 =>
  // b_i = -c_i
  final a = List<List<Expr>>.generate(
    n,
    (_) => List<Expr>.filled(n, const Constant(0.0)),
  );
  final b = List<Expr>.filled(n, const Constant(0.0));

  for (var i = 0; i < n; i++) {
    final eq = equations[i].simplify();
    for (var j = 0; j < n; j++) {
      final aij = eq.diff(variables[j]).simplify();
      // Ensure linearity: derivative must not depend on any variable
      for (final v in variables) {
        if (aij.dependsOn(v)) return null;
      }
      a[i][j] = aij;
    }

    // Constant term: evaluate with all variables set to 0.0
    var cTerm = eq;
    for (final v in variables) {
      cTerm = cTerm.substitute(v, const Constant(0.0));
    }
    b[i] = (-cTerm).simplify();
  }

  // Gaussian elimination with partial pivoting
  for (var k = 0; k < n; k++) {
    // Find pivot
    var pivotRow = -1;
    for (var i = k; i < n; i++) {
      final aik = a[i][k];
      if (aik != const Constant(0.0) &&
          !(aik is Constant && aik.value == 0.0)) {
        pivotRow = i;
        break;
      }
    }
    if (pivotRow == -1) {
      return null; // Singular matrix
    }

    // Swap rows
    if (pivotRow != k) {
      final tempRow = a[k];
      a[k] = a[pivotRow];
      a[pivotRow] = tempRow;
      final tempB = b[k];
      b[k] = b[pivotRow];
      b[pivotRow] = tempB;
    }

    final pivot = a[k][k];
    for (var i = k + 1; i < n; i++) {
      final factor = (a[i][k] / pivot).simplify();
      if (factor != const Constant(0.0) &&
          !(factor is Constant && factor.value == 0.0)) {
        for (var j = k; j < n; j++) {
          a[i][j] = (a[i][j] - factor * a[k][j]).simplify();
        }
        b[i] = (b[i] - factor * b[k]).simplify();
      }
    }
  }

  // Back-substitution
  final x = List<Expr>.filled(n, const Constant(0.0));
  for (var i = n - 1; i >= 0; i--) {
    var sum = b[i];
    for (var j = i + 1; j < n; j++) {
      sum = (sum - a[i][j] * x[j]).simplify();
    }
    x[i] = (sum / a[i][i]).simplify();
  }

  final result = <String, Expr>{};
  for (var i = 0; i < n; i++) {
    result[variables[i]] = x[i];
  }
  return result;
}

List<Expr> _deduplicate(List<Expr> list) {
  final result = <Expr>[];
  for (final item in list) {
    final simplified = item.simplify();
    final isDup = result.any(
      (existing) =>
          existing == simplified ||
          (existing is Constant &&
              simplified is Constant &&
              (existing.value - simplified.value).abs() < 1e-12),
    );
    if (!isDup) {
      result.add(simplified);
    }
  }
  return result;
}
