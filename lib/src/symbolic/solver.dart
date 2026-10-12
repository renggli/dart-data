import 'dart:math' as math;

import 'algebra/expand.dart';
import 'algebra/factor.dart';
import 'algebra/simplify.dart';
import 'ast.dart';
import 'calculus/differentiation.dart';
import 'calculus/linear_form.dart';

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
  /// // roots: [RationalNumber(-2), RationalNumber(2)]
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
  /// // solution?['x'] == RationalNumber(6), solution?['y'] == RationalNumber(4)
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
    final disc = ((b * b) - (const RationalNumber(4) * a * c)).simplify();

    if (disc is RationalNumber) {
      if (disc.isNegative) {
        final posDisc = RationalNumber(-disc.numerator, disc.denominator);
        final sqrtDiscAbs = _sqrtConstant(posDisc);
        final twoA = (const RationalNumber(2) * a).simplify();
        final realPart = ((-b) / twoA).simplify();
        final imagPart = (sqrtDiscAbs / twoA).simplify();

        Expr r1;
        Expr r2;
        if ((realPart is RationalNumber && realPart.isZero) ||
            (realPart is RealNumber && realPart.value == 0.0)) {
          r1 = (imagPart * ConstantNumber.i).simplify();
          r2 = ((-imagPart) * ConstantNumber.i).simplify();
        } else {
          r1 = (realPart + imagPart * ConstantNumber.i).simplify();
          r2 = (realPart - imagPart * ConstantNumber.i).simplify();
        }
        return _deduplicate([r1, r2]);
      } else if (disc.isZero) {
        final root = ((-b) / (const RationalNumber(2) * a)).simplify();
        return [root];
      } else {
        final sqrtDisc = _sqrtConstant(disc);
        final twoA = (const RationalNumber(2) * a).simplify();
        final r1 = (((-b) + sqrtDisc) / twoA).simplify();
        final r2 = (((-b) - sqrtDisc) / twoA).simplify();
        return _deduplicate([r1, r2]);
      }
    } else if (disc is RealNumber && disc.value < 0) {
      final sqrtDiscAbs = RealNumber(math.sqrt(-disc.value));
      final twoA = (const RationalNumber(2) * a).simplify();
      final realPart = ((-b) / twoA).simplify();
      final imagPart = (sqrtDiscAbs / twoA).simplify();

      Expr r1;
      Expr r2;
      if ((realPart is RationalNumber && realPart.isZero) ||
          (realPart is RealNumber && realPart.value == 0.0)) {
        r1 = (imagPart * ConstantNumber.i).simplify();
        r2 = ((-imagPart) * ConstantNumber.i).simplify();
      } else {
        r1 = (realPart + imagPart * ConstantNumber.i).simplify();
        r2 = (realPart - imagPart * ConstantNumber.i).simplify();
      }
      return _deduplicate([r1, r2]);
    } else {
      final sqrtDisc = disc.pow(const RationalNumber(1, 2)).simplify();
      final twoA = (const RationalNumber(2) * a).simplify();
      final r1 = (((-b) + sqrtDisc) / twoA).simplify();
      final r2 = (((-b) - sqrtDisc) / twoA).simplify();
      return _deduplicate([r1, r2]);
    }
  }

  // Biquadratic form: a * x^4 + b * x^2 + c = 0
  final biquad = _matchBiquadratic(expr, variable);
  if (biquad != null) {
    return _solveBiquadratic(biquad.a, biquad.b, biquad.c, variable);
  }

  // Factored products or unrolled factor decomposition:
  final factors = <Expr>[];
  _collectFactors(expr, factors);
  final varFactors = factors.where((f) => f.dependsOn(variable)).toList();
  if (varFactors.length > 1) {
    final allRoots = <Expr>[];
    for (final factor in varFactors) {
      allRoots.addAll(_solveEquation(factor, variable));
    }
    return _deduplicate(allRoots);
  }

  // Polynomial factoring step (degree > 2 or multi-term polynomials):
  final factored = expr.factor();
  if (factored != expr) {
    final factoredList = <Expr>[];
    _collectFactors(factored, factoredList);
    final varFactored = factoredList
        .where((f) => f.dependsOn(variable))
        .toList();
    if (varFactored.length > 1 ||
        (varFactored.isNotEmpty && varFactored.first != expr)) {
      final allRoots = <Expr>[];
      for (final factor in varFactored) {
        allRoots.addAll(_solveEquation(factor, variable));
      }
      return _deduplicate(allRoots);
    }
  }

  // Transcendental isolation: f(u(x)) = C
  final trans = _isolateAndInvert(expr, variable);
  if (trans != null) {
    return _deduplicate(trans);
  }

  return const [];
}

Expr _sqrtConstant(RationalNumber c) {
  if (c.numerator >= 0) {
    final numSqrt = math.sqrt(c.numerator).round();
    final denSqrt = math.sqrt(c.denominator).round();
    if (numSqrt * numSqrt == c.numerator &&
        denSqrt * denSqrt == c.denominator) {
      return RationalNumber(numSqrt, denSqrt);
    }
  }
  return c.pow(const RationalNumber(1, 2)).simplify();
}

({Expr a, Expr b, Expr c})? _matchQuadratic(Expr expr, String variable) {
  // Compute second derivative f''(x)
  final d1 = expr.derivative(variable).simplify();
  final d2 = d1.derivative(variable).simplify();
  if (d2.dependsOn(variable)) {
    return null;
  }

  // a = f''(x) / 2
  final a = (d2 / const RationalNumber(2)).simplify();
  if (a is RationalNumber && a.isZero) {
    return null;
  }

  // b = f'(0)
  final b = d1.substitute(variable, RationalNumber.zero).simplify();
  if (b.dependsOn(variable)) return null;

  // c = f(0)
  final c = expr.substitute(variable, RationalNumber.zero).simplify();
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
  return _invertEquation(expr, RationalNumber.zero, variable);
}

List<Expr>? _invertEquation(Expr u, Expr c, String variable) {
  u = u.simplify();
  c = c.simplify();

  if (u is Variable && u.name == variable) {
    return [c];
  }

  if (u is Exp) {
    // exp(arg) = c -> arg = ln(c) (requires c > 0)
    if (c is RationalNumber && (c.isNegative || c.isZero)) return const [];
    final lnC = Ln(c).simplify();
    return _solveEquation((u.expr - lnC).simplify(), variable);
  }

  if (u is Ln) {
    // ln(arg) = c -> arg = exp(c)
    final expC = Exp(c).simplify();
    return _solveEquation((u.expr - expC).simplify(), variable);
  }

  if (u is Sin) {
    return _invertSin(u.expr, c, variable);
  }

  if (u is Cos) {
    return _invertCos(u.expr, c, variable);
  }

  if (u is Tan) {
    return _invertTan(u.expr, c, variable);
  }

  if (u is Asin) {
    final sinC = Sin(c).simplify();
    return _solveEquation((u.expr - sinC).simplify(), variable);
  }

  if (u is Acos) {
    final cosC = Cos(c).simplify();
    return _solveEquation((u.expr - cosC).simplify(), variable);
  }

  if (u is Atan) {
    final tanC = Tan(c).simplify();
    return _solveEquation((u.expr - tanC).simplify(), variable);
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
                final posRoot = _rootConstant(c, n);
                final negRoot = (-posRoot).simplify();
                final s1 = _solveEquation(
                  (u.base - posRoot).simplify(),
                  variable,
                );
                final s2 = _solveEquation(
                  (u.base - negRoot).simplify(),
                  variable,
                );
                return _deduplicate([...s1, ...s2]);
              } else {
                // Odd power: u^n = c -> u = c^(1/n)
                final root = _rootConstant(c, n);
                return _solveEquation((u.base - root).simplify(), variable);
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
          return _solveEquation((u.base - root).simplify(), variable);
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
    } else if (!u.left.dependsOn(variable)) {
      if (c == RationalNumber.zero ||
          (c is RationalNumber && c.isZero) ||
          (c is RealNumber && c.value == 0.0)) {
        return const [];
      }
      return _invertEquation(u.right, (u.left / c).simplify(), variable);
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
    (_) => List<Expr>.filled(n, RationalNumber.zero),
  );
  final b = List<Expr>.filled(n, RationalNumber.zero);

  for (var i = 0; i < n; i++) {
    final eq = equations[i].simplify();
    for (var j = 0; j < n; j++) {
      final aij = eq.derivative(variables[j]).simplify();
      // Ensure linearity: derivative must not depend on any variable
      for (final v in variables) {
        if (aij.dependsOn(v)) return null;
      }
      a[i][j] = aij;
    }

    // Constant term: evaluate with all variables set to 0
    var cTerm = eq;
    for (final v in variables) {
      cTerm = cTerm.substitute(v, RationalNumber.zero);
    }
    b[i] = (-cTerm).simplify();
  }

  // Gaussian elimination with partial pivoting
  for (var k = 0; k < n; k++) {
    // Find pivot
    var pivotRow = -1;
    for (var i = k; i < n; i++) {
      final aik = a[i][k];
      if (aik != RationalNumber.zero &&
          !(aik is RationalNumber && aik.isZero)) {
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
      if (factor != RationalNumber.zero &&
          !(factor is RationalNumber && factor.isZero)) {
        for (var j = k; j < n; j++) {
          a[i][j] = (a[i][j] - factor * a[k][j]).simplify();
        }
        b[i] = (b[i] - factor * b[k]).simplify();
      }
    }
  }

  // Back-substitution
  final x = List<Expr>.filled(n, RationalNumber.zero);
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
    final isDup = result.any((existing) {
      if (existing == simplified) return true;
      if (existing is Number && simplified is Number) {
        if (existing.isReal && simplified.isReal) {
          return (existing.value - simplified.value).abs() < 1e-12;
        } else if (!existing.isReal && !simplified.isReal) {
          final c1 = existing.complexValue;
          final c2 = simplified.complexValue;
          return (c1.a - c2.a).abs() < 1e-12 && (c1.b - c2.b).abs() < 1e-12;
        }
        return false;
      }
      if (existing.freeVariables.isEmpty && simplified.freeVariables.isEmpty) {
        try {
          final c1 = existing.evaluateComplex();
          final c2 = simplified.evaluateComplex();
          return (c1.a - c2.a).abs() < 1e-12 && (c1.b - c2.b).abs() < 1e-12;
        } catch (_) {}
      }
      return false;
    });
    if (!isDup) {
      result.add(simplified);
    }
  }
  return result;
}

void _collectFactors(Expr expr, List<Expr> target) {
  switch (expr) {
    case Mul(:final left, :final right):
      _collectFactors(left, target);
      _collectFactors(right, target);
    case Pow(:final base, exponent: RationalNumber(:final numerator))
        when numerator > 0:
      _collectFactors(base, target);
    case Neg(:final expr):
      _collectFactors(expr, target);
    default:
      if (expr is! Number) {
        target.add(expr);
      }
  }
}

({Expr a, Expr b, Expr c})? _matchBiquadratic(Expr expr, String variable) {
  final d1 = expr.derivative(variable).simplify();
  final d2 = d1.derivative(variable).simplify();
  final d3 = d2.derivative(variable).simplify();
  final d4 = d3.derivative(variable).simplify();

  if (d4.dependsOn(variable)) return null;

  final a = (d4 / const RationalNumber(24)).simplify();
  if ((a is RationalNumber && a.isZero) ||
      (a is RealNumber && a.value == 0.0) ||
      a.dependsOn(variable)) {
    return null;
  }

  final f30 = d3.substitute(variable, RationalNumber.zero).simplify();
  if (f30 != RationalNumber.zero && !(f30 is RealNumber && f30.value == 0.0)) {
    return null;
  }

  final f10 = d1.substitute(variable, RationalNumber.zero).simplify();
  if (f10 != RationalNumber.zero && !(f10 is RealNumber && f10.value == 0.0)) {
    return null;
  }

  final b =
      (d2.substitute(variable, RationalNumber.zero) / const RationalNumber(2))
          .simplify();
  if (b.dependsOn(variable)) return null;

  final c = expr.substitute(variable, RationalNumber.zero).simplify();
  if (c.dependsOn(variable)) return null;

  final x = Variable(variable);
  final expected =
      ((a * x.pow(const RationalNumber(4))) +
              (b * x.pow(const RationalNumber(2))) +
              c)
          .simplify();
  final diff = (expr.expand() - expected.expand()).simplify();
  if (diff != RationalNumber.zero &&
      !(diff is RealNumber && diff.value == 0.0)) {
    return null;
  }

  return (a: a, b: b, c: c);
}

List<Expr> _solveBiquadratic(Expr a, Expr b, Expr c, String variable) {
  const uVar = '_u';
  final uEq =
      ((a * const Variable(uVar).pow(const RationalNumber(2))) +
              (b * const Variable(uVar)) +
              c)
          .simplify();
  final uRoots = _solveEquation(uEq, uVar);
  final x = Variable(variable);
  final allRoots = <Expr>[];
  for (final u in uRoots) {
    final xEq = (x.pow(const RationalNumber(2)) - u).simplify();
    allRoots.addAll(_solveEquation(xEq, variable));
  }
  return _deduplicate(allRoots);
}

int? _integerNthRoot(int val, int n) {
  if (val < 0) return null;
  if (val == 0) return 0;
  if (val == 1) return 1;
  final r = math.pow(val, 1.0 / n).round();
  var p = 1;
  for (var i = 0; i < n; i++) {
    if (val ~/ r < p) return null;
    p *= r;
  }
  return p == val ? r : null;
}

Expr _rootConstant(Expr c, int n) {
  if (c is RationalNumber) {
    if (n.isOdd && c.isNegative) {
      final posRoot = _rootConstant(
        RationalNumber(-c.numerator, c.denominator),
        n,
      );
      return (-posRoot).simplify();
    }
    if (c.numerator >= 0) {
      final numR = _integerNthRoot(c.numerator, n);
      final denR = _integerNthRoot(c.denominator, n);
      if (numR != null && denR != null) {
        return RationalNumber(numR, denR);
      }
    }
  } else if (c is RealNumber) {
    if (n.isOdd && c.value < 0) {
      return RealNumber(-math.pow(-c.value, 1.0 / n).toDouble());
    }
  }
  return c.pow(RationalNumber(1, n)).simplify();
}

bool _isRealConstantOutOfRange(Expr c, double maxAbs) {
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

List<Expr> _invertSin(Expr arg, Expr c, String variable) {
  if (_isRealConstantOutOfRange(c, 1.0)) {
    return const [];
  }

  final angles = <Expr>[];
  if (c == RationalNumber.zero || (c is RealNumber && c.value == 0.0)) {
    angles.addAll([RationalNumber.zero, ConstantNumber.pi]);
  } else if (c == RationalNumber.one || (c is RealNumber && c.value == 1.0)) {
    angles.add(const Mul(RationalNumber(1, 2), ConstantNumber.pi));
  } else if (c == RationalNumber.negativeOne ||
      (c is RealNumber && c.value == -1.0)) {
    angles.add(const Mul(RationalNumber(3, 2), ConstantNumber.pi));
  } else if (_isHalf(c)) {
    angles.addAll([
      const Mul(RationalNumber(1, 6), ConstantNumber.pi),
      const Mul(RationalNumber(5, 6), ConstantNumber.pi),
    ]);
  } else if (_isNegativeHalf(c)) {
    angles.addAll([
      const Mul(RationalNumber(7, 6), ConstantNumber.pi),
      const Mul(RationalNumber(11, 6), ConstantNumber.pi),
    ]);
  } else if (_isSqrt2Over2(c)) {
    angles.addAll([
      const Mul(RationalNumber(1, 4), ConstantNumber.pi),
      const Mul(RationalNumber(3, 4), ConstantNumber.pi),
    ]);
  } else if (_isNegativeSqrt2Over2(c)) {
    angles.addAll([
      const Mul(RationalNumber(5, 4), ConstantNumber.pi),
      const Mul(RationalNumber(7, 4), ConstantNumber.pi),
    ]);
  } else if (_isSqrt3Over2(c)) {
    angles.addAll([
      const Mul(RationalNumber(1, 3), ConstantNumber.pi),
      const Mul(RationalNumber(2, 3), ConstantNumber.pi),
    ]);
  } else if (_isNegativeSqrt3Over2(c)) {
    angles.addAll([
      const Mul(RationalNumber(4, 3), ConstantNumber.pi),
      const Mul(RationalNumber(5, 3), ConstantNumber.pi),
    ]);
  } else {
    angles.add(Asin(c).simplify());
    angles.add((ConstantNumber.pi - Asin(c)).simplify());
  }

  final roots = <Expr>[];
  for (final angle in angles) {
    final inverted = _invertEquation(arg, angle, variable);
    if (inverted != null) {
      roots.addAll(inverted);
    } else {
      roots.addAll(_solveEquation((arg - angle).simplify(), variable));
    }
  }
  return _deduplicate(roots);
}

List<Expr> _invertCos(Expr arg, Expr c, String variable) {
  if (_isRealConstantOutOfRange(c, 1.0)) {
    return const [];
  }

  final angles = <Expr>[];
  if (c == RationalNumber.zero || (c is RealNumber && c.value == 0.0)) {
    angles.addAll([
      const Mul(RationalNumber(1, 2), ConstantNumber.pi),
      const Mul(RationalNumber(3, 2), ConstantNumber.pi),
    ]);
  } else if (c == RationalNumber.one || (c is RealNumber && c.value == 1.0)) {
    angles.add(RationalNumber.zero);
  } else if (c == RationalNumber.negativeOne ||
      (c is RealNumber && c.value == -1.0)) {
    angles.add(ConstantNumber.pi);
  } else if (_isHalf(c)) {
    angles.addAll([
      const Mul(RationalNumber(1, 3), ConstantNumber.pi),
      const Mul(RationalNumber(5, 3), ConstantNumber.pi),
    ]);
  } else if (_isNegativeHalf(c)) {
    angles.addAll([
      const Mul(RationalNumber(2, 3), ConstantNumber.pi),
      const Mul(RationalNumber(4, 3), ConstantNumber.pi),
    ]);
  } else if (_isSqrt2Over2(c)) {
    angles.addAll([
      const Mul(RationalNumber(1, 4), ConstantNumber.pi),
      const Mul(RationalNumber(7, 4), ConstantNumber.pi),
    ]);
  } else if (_isNegativeSqrt2Over2(c)) {
    angles.addAll([
      const Mul(RationalNumber(3, 4), ConstantNumber.pi),
      const Mul(RationalNumber(5, 4), ConstantNumber.pi),
    ]);
  } else if (_isSqrt3Over2(c)) {
    angles.addAll([
      const Mul(RationalNumber(1, 6), ConstantNumber.pi),
      const Mul(RationalNumber(11, 6), ConstantNumber.pi),
    ]);
  } else if (_isNegativeSqrt3Over2(c)) {
    angles.addAll([
      const Mul(RationalNumber(5, 6), ConstantNumber.pi),
      const Mul(RationalNumber(7, 6), ConstantNumber.pi),
    ]);
  } else {
    angles.add(Acos(c).simplify());
    angles.add(
      ((const RationalNumber(2) * ConstantNumber.pi) - Acos(c)).simplify(),
    );
  }

  final roots = <Expr>[];
  for (final angle in angles) {
    final inverted = _invertEquation(arg, angle, variable);
    if (inverted != null) {
      roots.addAll(inverted);
    } else {
      roots.addAll(_solveEquation((arg - angle).simplify(), variable));
    }
  }
  return _deduplicate(roots);
}

List<Expr> _invertTan(Expr arg, Expr c, String variable) {
  final angles = <Expr>[];
  if (c == RationalNumber.zero || (c is RealNumber && c.value == 0.0)) {
    angles.addAll([RationalNumber.zero, ConstantNumber.pi]);
  } else if (c == RationalNumber.one || (c is RealNumber && c.value == 1.0)) {
    angles.addAll([
      const Mul(RationalNumber(1, 4), ConstantNumber.pi),
      const Mul(RationalNumber(5, 4), ConstantNumber.pi),
    ]);
  } else if (c == RationalNumber.negativeOne ||
      (c is RealNumber && c.value == -1.0)) {
    angles.addAll([
      const Mul(RationalNumber(3, 4), ConstantNumber.pi),
      const Mul(RationalNumber(7, 4), ConstantNumber.pi),
    ]);
  } else if (_isSqrt3Over3(c)) {
    angles.addAll([
      const Mul(RationalNumber(1, 6), ConstantNumber.pi),
      const Mul(RationalNumber(7, 6), ConstantNumber.pi),
    ]);
  } else if (_isNegativeSqrt3Over3(c)) {
    angles.addAll([
      const Mul(RationalNumber(5, 6), ConstantNumber.pi),
      const Mul(RationalNumber(11, 6), ConstantNumber.pi),
    ]);
  } else if (_isSqrt3(c)) {
    angles.addAll([
      const Mul(RationalNumber(1, 3), ConstantNumber.pi),
      const Mul(RationalNumber(4, 3), ConstantNumber.pi),
    ]);
  } else if (_isNegativeSqrt3(c)) {
    angles.addAll([
      const Mul(RationalNumber(2, 3), ConstantNumber.pi),
      const Mul(RationalNumber(5, 3), ConstantNumber.pi),
    ]);
  } else {
    angles.add(Atan(c).simplify());
    angles.add((ConstantNumber.pi + Atan(c)).simplify());
  }

  final roots = <Expr>[];
  for (final angle in angles) {
    final inverted = _invertEquation(arg, angle, variable);
    if (inverted != null) {
      roots.addAll(inverted);
    } else {
      roots.addAll(_solveEquation((arg - angle).simplify(), variable));
    }
  }
  return _deduplicate(roots);
}

bool _isHalf(Expr e) {
  if (e is RationalNumber && e.numerator == 1 && e.denominator == 2) {
    return true;
  }
  if (e is RealNumber && (e.value - 0.5).abs() < 1e-12) {
    return true;
  }
  return false;
}

bool _isNegativeHalf(Expr e) {
  if (e is RationalNumber && e.numerator == -1 && e.denominator == 2) {
    return true;
  }
  if (e is RealNumber && (e.value + 0.5).abs() < 1e-12) {
    return true;
  }
  return false;
}

bool _isSqrt(Expr e, int n) =>
    e is Pow &&
    e.base == RationalNumber(n) &&
    e.exponent == const RationalNumber(1, 2);

bool _isSqrt2Over2(Expr e) {
  if (e is RealNumber && (e.value - math.sqrt(2) / 2).abs() < 1e-12) {
    return true;
  }
  if (e is Mul) {
    if ((e.left == const RationalNumber(1, 2) && _isSqrt(e.right, 2)) ||
        (e.right == const RationalNumber(1, 2) && _isSqrt(e.left, 2))) {
      return true;
    }
  }
  if (e is Div && _isSqrt(e.left, 2) && e.right == const RationalNumber(2)) {
    return true;
  }
  if (e is Pow &&
      e.base == const RationalNumber(1, 2) &&
      e.exponent == const RationalNumber(1, 2)) {
    return true;
  }
  if (e.freeVariables.isEmpty) {
    try {
      final c = e.evaluateComplex();
      if (c.b.abs() < 1e-12 && (c.a - math.sqrt(2) / 2).abs() < 1e-12) {
        return true;
      }
    } catch (_) {}
  }
  return false;
}

bool _isNegativeSqrt2Over2(Expr e) {
  if (e is RealNumber && (e.value + math.sqrt(2) / 2).abs() < 1e-12) {
    return true;
  }
  if (e is Neg && _isSqrt2Over2(e.expr)) {
    return true;
  }
  if (e is Mul) {
    if ((e.left == const RationalNumber(-1, 2) && _isSqrt(e.right, 2)) ||
        (e.right == const RationalNumber(-1, 2) && _isSqrt(e.left, 2))) {
      return true;
    }
  }
  if (e.freeVariables.isEmpty) {
    try {
      final c = e.evaluateComplex();
      if (c.b.abs() < 1e-12 && (c.a + math.sqrt(2) / 2).abs() < 1e-12) {
        return true;
      }
    } catch (_) {}
  }
  return false;
}

bool _isSqrt3Over2(Expr e) {
  if (e is RealNumber && (e.value - math.sqrt(3) / 2).abs() < 1e-12) {
    return true;
  }
  if (e is Mul) {
    if ((e.left == const RationalNumber(1, 2) && _isSqrt(e.right, 3)) ||
        (e.right == const RationalNumber(1, 2) && _isSqrt(e.left, 3))) {
      return true;
    }
  }
  if (e is Div && _isSqrt(e.left, 3) && e.right == const RationalNumber(2)) {
    return true;
  }
  if (e.freeVariables.isEmpty) {
    try {
      final c = e.evaluateComplex();
      if (c.b.abs() < 1e-12 && (c.a - math.sqrt(3) / 2).abs() < 1e-12) {
        return true;
      }
    } catch (_) {}
  }
  return false;
}

bool _isNegativeSqrt3Over2(Expr e) {
  if (e is RealNumber && (e.value + math.sqrt(3) / 2).abs() < 1e-12) {
    return true;
  }
  if (e is Neg && _isSqrt3Over2(e.expr)) {
    return true;
  }
  if (e is Mul) {
    if ((e.left == const RationalNumber(-1, 2) && _isSqrt(e.right, 3)) ||
        (e.right == const RationalNumber(-1, 2) && _isSqrt(e.left, 3))) {
      return true;
    }
  }
  if (e.freeVariables.isEmpty) {
    try {
      final c = e.evaluateComplex();
      if (c.b.abs() < 1e-12 && (c.a + math.sqrt(3) / 2).abs() < 1e-12) {
        return true;
      }
    } catch (_) {}
  }
  return false;
}

bool _isSqrt3Over3(Expr e) {
  if (e is RealNumber && (e.value - math.sqrt(3) / 3).abs() < 1e-12) {
    return true;
  }
  if (e is Mul) {
    if ((e.left == const RationalNumber(1, 3) && _isSqrt(e.right, 3)) ||
        (e.right == const RationalNumber(1, 3) && _isSqrt(e.left, 3))) {
      return true;
    }
  }
  if (e is Div && _isSqrt(e.left, 3) && e.right == const RationalNumber(3)) {
    return true;
  }
  if (e is Pow &&
      e.base == const RationalNumber(1, 3) &&
      e.exponent == const RationalNumber(1, 2)) {
    return true;
  }
  if (e.freeVariables.isEmpty) {
    try {
      final c = e.evaluateComplex();
      if (c.b.abs() < 1e-12 && (c.a - math.sqrt(3) / 3).abs() < 1e-12) {
        return true;
      }
    } catch (_) {}
  }
  return false;
}

bool _isNegativeSqrt3Over3(Expr e) {
  if (e is RealNumber && (e.value + math.sqrt(3) / 3).abs() < 1e-12) {
    return true;
  }
  if (e is Neg && _isSqrt3Over3(e.expr)) {
    return true;
  }
  if (e is Mul) {
    if ((e.left == const RationalNumber(-1, 3) && _isSqrt(e.right, 3)) ||
        (e.right == const RationalNumber(-1, 3) && _isSqrt(e.left, 3))) {
      return true;
    }
  }
  if (e.freeVariables.isEmpty) {
    try {
      final c = e.evaluateComplex();
      if (c.b.abs() < 1e-12 && (c.a + math.sqrt(3) / 3).abs() < 1e-12) {
        return true;
      }
    } catch (_) {}
  }
  return false;
}

bool _isSqrt3(Expr e) {
  if (e is RealNumber && (e.value - math.sqrt(3)).abs() < 1e-12) {
    return true;
  }
  if (_isSqrt(e, 3)) {
    return true;
  }
  if (e.freeVariables.isEmpty) {
    try {
      final c = e.evaluateComplex();
      if (c.b.abs() < 1e-12 && (c.a - math.sqrt(3)).abs() < 1e-12) {
        return true;
      }
    } catch (_) {}
  }
  return false;
}

bool _isNegativeSqrt3(Expr e) {
  if (e is RealNumber && (e.value + math.sqrt(3)).abs() < 1e-12) {
    return true;
  }
  if (e is Neg && _isSqrt3(e.expr)) {
    return true;
  }
  if (e is Mul && e.left == RationalNumber.negativeOne && _isSqrt(e.right, 3)) {
    return true;
  }
  if (e.freeVariables.isEmpty) {
    try {
      final c = e.evaluateComplex();
      if (c.b.abs() < 1e-12 && (c.a + math.sqrt(3)).abs() < 1e-12) {
        return true;
      }
    } catch (_) {}
  }
  return false;
}
