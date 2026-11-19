import '../algebra/factor.dart';
import '../algebra/simplify.dart';
import '../algebra/simplify/domain.dart';
import '../algebra/simplify/multiplicative.dart';
import '../algebra/term_accumulator.dart';
import '../assumptions.dart';
import '../ast.dart';
import '../calculus/differentiation.dart';
import '../calculus/integration/integration.dart';
import '../calculus/linear_form.dart';
import 'system.dart';
import 'univariate.dart';

/// Extension providing symbolic ordinary differential equation solving on [Expr].
extension OdeExtension on Expr {
  /// Solves this ordinary differential equation for [dependent] with respect to
  /// [independent].
  ///
  /// Conceptually, an ordinary differential equation (ODE) expresses the rate
  /// of change of an unknown function $y(x)$ in terms of $x$ and $y$. Solving it
  /// analytically recovers the original family of curves satisfying this rate.
  /// Formally, this solves first-order linear ODEs:
  /// $$\frac{dy}{dx} + P(x) y = Q(x)$$
  /// using the integrating factor $\mu(x) = \exp\left(\int P(x) dx\right)$, as
  /// well as separable ODEs $\frac{dy}{dx} = f(x) g(y)$.
  ///
  /// Optionally accepts initial value conditions at [at]:
  /// `[y(at)]` for first-order ODEs, or `[y(at), y'(at)]` for second-order
  /// ODEs, determining the integration constants (`C1`, `C2`, ...).
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final y = Variable('y');
  /// final dy = Derivative(y, 'x');
  /// // Solve y' = 2 * y
  /// final sol = (dy - y * 2).solveOde(dependent: 'y', independent: 'x');
  /// // sol: C1 * exp(2 * x)
  /// ```
  Expr solveOde({
    required String dependent,
    required String independent,
    String constant = 'C1',
    Object? at,
    List<Object> initialValues = const [],
    Assumptions assumptions = Assumptions.none,
  }) => _solveOde(
    this,
    dependent: dependent,
    independent: independent,
    constant: constant,
    at: at,
    initialValues: initialValues,
    assumptions: assumptions,
  );
}

Expr _solveOde(
  Expr equation, {
  required String dependent,
  required String independent,
  String constant = 'C1',
  Object? at,
  List<Object> initialValues = const [],
  required Assumptions assumptions,
}) {
  var eq = equation;
  if (eq is RelationalExpr) {
    eq = eq.left - eq.right;
  }

  var maxOrder = 0;
  void scanOrder(Expr e) {
    if (e
        case Derivative(
          expr: Variable(name: final depName),
          variable: final indName,
          order: final ord,
        )
        when depName == dependent && indName == independent) {
      if (ord > maxOrder) maxOrder = ord;
    }
    e.mapChildren((c) {
      scanOrder(c);
      return c;
    });
  }

  scanOrder(eq);
  if (maxOrder > 2) {
    throw UnsupportedError('ODEs of order $maxOrder > 2 are not supported');
  }
  if (initialValues.length > maxOrder) {
    throw ArgumentError(
      'Too many initial values (${initialValues.length}) for ODE of order $maxOrder.',
    );
  }
  if (initialValues.isNotEmpty && at == null) {
    throw ArgumentError('at must be provided when initialValues is non-empty.');
  }

  Expr ySol;
  if (maxOrder == 2) {
    ySol = _trySecondOrderLinearOde(
      eq,
      dependent: dependent,
      independent: independent,
      constant: constant,
      assumptions: assumptions,
    );
  } else {
    const sentinel = '_yPrime';
    final normalized = _replaceDerivative(
      eq,
      dependent,
      independent,
      const Variable(sentinel),
    );
    if (!normalized.dependsOn(sentinel)) {
      throw ArgumentError(
        'Equation does not contain any derivative of $dependent with respect to $independent.',
      );
    }

    final isolated = normalized.solve(sentinel, assumptions: assumptions);
    if (isolated.isEmpty) {
      throw UnsupportedError(
        'Could not isolate derivative of $dependent in ODE.',
      );
    }

    final yPrime = isolated.first.simplify(assumptions: assumptions);

    // Case 1: y' does not depend on y -> direct integration
    if (!yPrime.dependsOn(dependent)) {
      final anti = yPrime.integrate(independent, assumptions: assumptions);
      ySol = (anti + Variable(constant)).simplify(assumptions: assumptions);
    } else {
      // Case 2: First-order linear ODE: y' = a(x) * y + b(x) <=> y' - a(x)*y = b(x)
      final lin = yPrime.matchLinear(dependent);
      if (lin != null &&
          !lin.a.dependsOn(dependent) &&
          !lin.b.dependsOn(dependent)) {
        final p = (-lin.a).simplify(assumptions: assumptions);
        final q = lin.b.simplify(assumptions: assumptions);
        final pInt = p.integrate(independent, assumptions: assumptions);
        final mu = Pow(Constant.e, pInt).simplify(assumptions: assumptions);
        final muQ = (mu * q).simplify(assumptions: assumptions);
        final muQInt = muQ.integrate(independent, assumptions: assumptions);
        ySol = ((muQInt + Variable(constant)) / mu).simplify(
          assumptions: assumptions,
        );
      } else {
        // Case 3: Separable ODE: y' = F(x) * G(y)
        final factored = yPrime.factor(assumptions: assumptions);
        final (fx, gy) = _separateVariables(factored, independent, dependent);
        if (fx != null && gy != null) {
          final invG = (IntegerNumber.one / gy).simplify(
            assumptions: assumptions,
          );
          final iY = invG.integrate(dependent, assumptions: assumptions);
          final iX = fx.integrate(independent, assumptions: assumptions);
          final sepEq = (iY - iX - Variable(constant)).simplify(
            assumptions: assumptions,
          );
          final roots = sepEq.solve(dependent, assumptions: assumptions);
          if (roots.isNotEmpty) {
            ySol = roots.first.simplify(assumptions: assumptions);
          } else {
            throw UnsupportedError(
              'Could not algebraically invert separable ODE integral for $dependent.',
            );
          }
        } else {
          throw UnsupportedError(
            'Unsupported ODE form. Only first-order linear and separable ODEs are currently supported.',
          );
        }
      }
    }
  }

  if (at != null && initialValues.isNotEmpty) {
    final atExpr = _toExpr(at);
    final constNames = <String>[
      constant,
      if (maxOrder == 2)
        if (constant == 'C1') 'C2' else '${constant}_2',
    ];
    final equations = <Expr>[];
    var currentDeriv = ySol;
    for (var k = 0; k < initialValues.length; k++) {
      if (k > 0) {
        currentDeriv = currentDeriv.derivative(
          independent,
          assumptions: assumptions,
        );
      }
      final evaluated = currentDeriv
          .substitute(independent, atExpr)
          .simplify(assumptions: assumptions);
      equations.add(
        (evaluated - _toExpr(initialValues[k])).simplify(
          assumptions: assumptions,
        ),
      );
    }
    if (equations.length == 1) {
      final cRoots = equations.first.solve(
        constNames.first,
        assumptions: assumptions,
      );
      if (cRoots.isNotEmpty) {
        ySol = ySol
            .substitute(constNames.first, cRoots.first)
            .simplify(assumptions: assumptions);
      }
    } else {
      final solutions = equations.solve(constNames, assumptions: assumptions);
      if (solutions.isNotEmpty) {
        var substituted = ySol;
        for (final entry in solutions.first.entries) {
          substituted = substituted.substitute(entry.key, entry.value);
        }
        ySol = substituted.simplify(assumptions: assumptions);
      }
    }
  }

  return ySol;
}

Expr _toExpr(Object value) {
  if (value is Expr) return value;
  if (value is int) return IntegerNumber.of(value);
  if (value is num) return RealNumber(value.toDouble());
  return Variable(value.toString());
}

Expr _replaceDerivative(
  Expr expr,
  String dependent,
  String independent,
  Expr replacement,
) {
  if (expr
      case Derivative(
        order: 1,
        :final variable,
        expr: Variable(name: final depName),
      )
      when variable == independent && depName == dependent) {
    return replacement;
  }
  if (expr case Variable(:final name)) {
    if (name == "$dependent'" ||
        name == 'd$dependent' ||
        name == '${dependent}_prime' ||
        name == 'D$dependent') {
      return replacement;
    }
  }
  return expr.mapChildren(
    (child) => _replaceDerivative(child, dependent, independent, replacement),
  );
}

(Expr?, Expr?) _separateVariables(
  Expr expr,
  String independent,
  String dependent,
) {
  final factors = <Expr>[];
  if (expr case Mul(factors: final f)) {
    factors.addAll(f);
  } else {
    factors.add(expr);
  }

  final xFactors = <Expr>[];
  final yFactors = <Expr>[];

  for (final factor in factors) {
    final dependsX = factor.dependsOn(independent);
    final dependsY = factor.dependsOn(dependent);
    if (dependsX && dependsY) {
      return (null, null);
    } else if (dependsY) {
      yFactors.add(factor);
    } else {
      xFactors.add(factor);
    }
  }

  final fx = switch (xFactors) {
    [] => IntegerNumber.one,
    [final single] => single,
    _ => Mul(xFactors),
  };
  final gy = switch (yFactors) {
    [] => IntegerNumber.one,
    [final single] => single,
    _ => Mul(yFactors),
  };

  return (fx, gy);
}

Expr _trySecondOrderLinearOde(
  Expr eq, {
  required String dependent,
  required String independent,
  required String constant,
  required Assumptions assumptions,
}) {
  const yDoublePrime = '_yDoublePrime';
  const yPrime = '_yPrime';

  Expr replaceHigher(Expr e) {
    if (e
        case Derivative(
          expr: Variable(name: final depName),
          variable: final indName,
          order: final ord,
        )
        when depName == dependent && indName == independent) {
      if (ord == 2) return const Variable(yDoublePrime);
      if (ord == 1) return const Variable(yPrime);
    }
    return e.mapChildren(replaceHigher);
  }

  final normalized = replaceHigher(eq).simplify(assumptions: assumptions);
  final lin2 = normalized.matchLinear(yDoublePrime);
  if (lin2 == null) {
    throw UnsupportedError(
      'Only linear second-order ODEs with constant coefficients are supported.',
    );
  }
  final a = lin2.a.simplify(assumptions: assumptions);
  final lin1 = lin2.b.dependsOn(yPrime)
      ? lin2.b.matchLinear(yPrime)
      : (a: IntegerNumber.zero as Expr, b: lin2.b);
  if (lin1 == null) {
    throw UnsupportedError(
      'Only linear second-order ODEs with constant coefficients are supported.',
    );
  }
  final b = lin1.a.simplify(assumptions: assumptions);
  final lin0 = lin1.b.dependsOn(dependent)
      ? lin1.b.matchLinear(dependent)
      : (a: IntegerNumber.zero as Expr, b: lin1.b);
  if (lin0 == null) {
    throw UnsupportedError(
      'Only linear second-order ODEs with constant coefficients are supported.',
    );
  }
  final c = lin0.a.simplify(assumptions: assumptions);
  final d = lin0.b.simplify(assumptions: assumptions);

  bool hasDepVar(Expr e) =>
      e.dependsOn(dependent) ||
      e.dependsOn(yPrime) ||
      e.dependsOn(yDoublePrime);

  bool hasForbiddenVar(Expr e) => e.dependsOn(independent) || hasDepVar(e);

  if ((a is Number && a.isZero) ||
      hasForbiddenVar(a) ||
      hasForbiddenVar(b) ||
      hasForbiddenVar(c) ||
      hasDepVar(d)) {
    throw UnsupportedError(
      'Only linear second-order ODEs with constant coefficients are supported.',
    );
  }

  final xVar = Variable(independent);
  final c1 = Variable(constant);
  final c2 = Variable(constant == 'C1' ? 'C2' : '${constant}_2');
  final delta = (b * b - IntegerNumber.of(4) * a * c).simplify(
    assumptions: assumptions,
  );

  final Expr yh;
  if (delta is Number && delta.isZero) {
    final r = (-b / (IntegerNumber.two * a)).simplify(assumptions: assumptions);
    yh = ((c1 + c2 * xVar) * Pow(Constant.e, r * xVar)).simplify(
      assumptions: assumptions,
    );
  } else if (isNegativeExpr(delta, assumptions: assumptions)) {
    final alpha = (-b / (IntegerNumber.two * a)).simplify(
      assumptions: assumptions,
    );
    final beta = (Pow(-delta, FractionNumber.half) / (IntegerNumber.two * a))
        .simplify(assumptions: assumptions);
    yh =
        (Pow(Constant.e, alpha * xVar) *
                (c1 * Cos(beta * xVar) + c2 * Sin(beta * xVar)))
            .simplify(assumptions: assumptions);
  } else {
    final sqrtDelta = Pow(delta, FractionNumber.half);
    final r1 = ((-b - sqrtDelta) / (IntegerNumber.two * a)).simplify(
      assumptions: assumptions,
    );
    final r2 = ((-b + sqrtDelta) / (IntegerNumber.two * a)).simplify(
      assumptions: assumptions,
    );
    yh = (c1 * Pow(Constant.e, r1 * xVar) + c2 * Pow(Constant.e, r2 * xVar))
        .simplify(assumptions: assumptions);
  }

  final rhs = (-d).simplify(assumptions: assumptions);
  if (rhs is Number && rhs.isZero) {
    return yh;
  }

  final yp = _particularSolutionUndeterminedCoeffs(
    a,
    b,
    c,
    rhs,
    independent,
    assumptions: assumptions,
  );
  return (yh + yp).simplify(assumptions: assumptions);
}

Expr _particularSolutionUndeterminedCoeffs(
  Expr a,
  Expr b,
  Expr c,
  Expr rhs,
  String independent, {
  required Assumptions assumptions,
}) {
  final xVar = Variable(independent);
  final terms = rhs is Add ? rhs.terms : [rhs];
  final polyTerms = <Expr>[];
  final otherTerms = <Expr>[];

  for (final term in terms) {
    if (extractPolynomialCoefficients(term, independent) != null) {
      polyTerms.add(term);
    } else {
      otherTerms.add(term);
    }
  }

  var totalYp = IntegerNumber.zero as Expr;

  if (polyTerms.isNotEmpty) {
    final polyRhs = polyTerms.length == 1
        ? polyTerms.first
        : Add(polyTerms).simplify(assumptions: assumptions);
    final coeffs = extractPolynomialCoefficients(polyRhs, independent)!;
    var maxDeg = 0;
    for (final k in coeffs.keys) {
      if (k > maxDeg) maxDeg = k;
    }
    if (maxDeg > 4) {
      throw UnsupportedError(
        'Polynomial forcing of degree > 4 in second-order ODE is not supported.',
      );
    }
    final isCZero = c is Number && c.isZero;
    final isBZero = b is Number && b.isZero;
    final s = isCZero ? (isBZero ? 2 : 1) : 0;
    final aCoeffs = List<Expr>.filled(maxDeg + 1, IntegerNumber.zero);

    for (var k = maxDeg; k >= 0; k--) {
      final pk = coeffs[k] ?? IntegerNumber.zero;
      if (s == 0) {
        var rem = pk;
        if (k + 1 <= maxDeg) {
          rem = rem - b * IntegerNumber.of(k + 1) * aCoeffs[k + 1];
        }
        if (k + 2 <= maxDeg) {
          rem = rem - a * IntegerNumber.of((k + 2) * (k + 1)) * aCoeffs[k + 2];
        }
        aCoeffs[k] = (rem / c).simplify(assumptions: assumptions);
      } else if (s == 1) {
        var rem = pk;
        if (k + 1 <= maxDeg) {
          rem = rem - a * IntegerNumber.of((k + 2) * (k + 1)) * aCoeffs[k + 1];
        }
        aCoeffs[k] = (rem / (b * IntegerNumber.of(k + 1))).simplify(
          assumptions: assumptions,
        );
      } else {
        aCoeffs[k] = (pk / (a * IntegerNumber.of((k + 2) * (k + 1)))).simplify(
          assumptions: assumptions,
        );
      }
    }

    var ypPoly = IntegerNumber.zero as Expr;
    for (var k = 0; k <= maxDeg; k++) {
      if (aCoeffs[k] is Number && (aCoeffs[k] as Number).isZero) continue;
      final powExp = k + s;
      final xPow = powExp == 0
          ? IntegerNumber.one
          : (powExp == 1 ? xVar : Pow(xVar, IntegerNumber.of(powExp)));
      ypPoly = ypPoly + aCoeffs[k] * xPow;
    }
    totalYp = totalYp + ypPoly;
  }

  for (final term in otherTerms) {
    final ypTerm = _particularSingleNonPolyTerm(
      a,
      b,
      c,
      term,
      independent,
      assumptions: assumptions,
    );
    if (ypTerm == null) {
      throw UnsupportedError(
        'Unsupported inhomogeneous term in second-order linear ODE: $term',
      );
    }
    totalYp = totalYp + ypTerm;
  }

  return totalYp.simplify(assumptions: assumptions);
}

Expr? _particularSingleNonPolyTerm(
  Expr a,
  Expr b,
  Expr c,
  Expr term,
  String independent, {
  required Assumptions assumptions,
}) {
  final xVar = Variable(independent);
  final factors = term is Mul ? term.factors : [term];
  final (:constFactors, :varFactors) = partitionFactors(factors, independent);
  if (varFactors.length != 1) return null;

  final kConst = constFactors.isEmpty
      ? IntegerNumber.one
      : simplifyMul(constFactors, assumptions: assumptions);
  final vf = varFactors.first;

  // Exponential: K * e^(alpha * x + beta)
  if (vf case Pow(base: Constant.e, :final exponent)) {
    final lin = exponent.matchLinear(independent);
    if (lin == null || (lin.a is Number && (lin.a as Number).isZero)) {
      return null;
    }
    final alpha = lin.a;
    final pChar = (a * alpha * alpha + b * alpha + c).simplify(
      assumptions: assumptions,
    );
    if (!(pChar is Number && pChar.isZero)) {
      return (term / pChar).simplify(assumptions: assumptions);
    }
    final derivChar = (IntegerNumber.two * a * alpha + b).simplify(
      assumptions: assumptions,
    );
    if (!(derivChar is Number && derivChar.isZero)) {
      return (xVar * term / derivChar).simplify(assumptions: assumptions);
    }
    return (xVar * xVar * term / (IntegerNumber.two * a)).simplify(
      assumptions: assumptions,
    );
  }

  // Sinusoidal: K * cos(omega * x + phi) or K * sin(omega * x + phi)
  if (vf is Cos || vf is Sin) {
    final arg = vf is Cos ? vf.expr : (vf as Sin).expr;
    final lin = arg.matchLinear(independent);
    if (lin == null || (lin.a is Number && (lin.a as Number).isZero)) {
      return null;
    }
    final omega = lin.a;
    final d1 = (c - a * omega * omega).simplify(assumptions: assumptions);
    final d2 = (b * omega).simplify(assumptions: assumptions);
    final deltaOmega = (d1 * d1 + d2 * d2).simplify(assumptions: assumptions);

    if (!(deltaOmega is Number && deltaOmega.isZero)) {
      if (vf is Cos) {
        return (kConst * (d1 * Cos(arg) + d2 * Sin(arg)) / deltaOmega).simplify(
          assumptions: assumptions,
        );
      } else {
        return (kConst * (d1 * Sin(arg) - d2 * Cos(arg)) / deltaOmega).simplify(
          assumptions: assumptions,
        );
      }
    }

    // Pure harmonic resonance: b = 0 and c = a * omega^2
    if (vf is Cos) {
      return (kConst * xVar * Sin(arg) / (IntegerNumber.two * a * omega))
          .simplify(assumptions: assumptions);
    } else {
      return (-kConst * xVar * Cos(arg) / (IntegerNumber.two * a * omega))
          .simplify(assumptions: assumptions);
    }
  }

  return null;
}
