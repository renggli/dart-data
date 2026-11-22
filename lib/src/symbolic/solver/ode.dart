import '../algebra/expand.dart';
import '../algebra/factor.dart';
import '../algebra/helpers.dart';
import '../algebra/simplify.dart';
import '../algebra/simplify/domain.dart';
import '../assumptions.dart';
import '../ast.dart';
import '../calculus/differentiation.dart';
import '../calculus/integration/integration.dart';
import '../calculus/linear_form.dart';
import '../compiler.dart';
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
  if (maxOrder > 6) {
    throw UnsupportedError('ODEs of order $maxOrder > 6 are not supported');
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
  if (maxOrder >= 2) {
    ySol = _tryNthOrderLinearOde(
      eq,
      order: maxOrder,
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
      for (var i = 2; i <= maxOrder; i++)
        if (constant == 'C1') 'C$i' else '${constant}_$i',
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

Expr _tryNthOrderLinearOde(
  Expr eq, {
  required int order,
  required String dependent,
  required String independent,
  required String constant,
  required Assumptions assumptions,
}) {
  String derivSentinel(int k) => '_yDeriv_$k';

  Expr replaceHigher(Expr e) {
    if (e
        case Derivative(
          expr: Variable(name: final depName),
          variable: final indName,
          order: final ord,
        )
        when depName == dependent && indName == independent && ord >= 1) {
      return Variable(derivSentinel(ord));
    }
    return e.mapChildren(replaceHigher);
  }

  var rem = replaceHigher(eq).simplify(assumptions: assumptions);
  final coeffs = List<Expr>.filled(order + 1, IntegerNumber.zero);

  for (var k = order; k >= 1; k--) {
    final sName = derivSentinel(k);
    if (rem.dependsOn(sName)) {
      final lin = rem.matchLinear(sName);
      if (lin == null) {
        throw UnsupportedError(
          'Only linear ODEs with constant coefficients are supported.',
        );
      }
      coeffs[k] = lin.a.simplify(assumptions: assumptions);
      rem = lin.b.simplify(assumptions: assumptions);
    }
  }

  if (rem.dependsOn(dependent)) {
    final lin = rem.matchLinear(dependent);
    if (lin == null) {
      throw UnsupportedError(
        'Only linear ODEs with constant coefficients are supported.',
      );
    }
    coeffs[0] = lin.a.simplify(assumptions: assumptions);
    rem = lin.b.simplify(assumptions: assumptions);
  }
  final d = rem;

  bool hasDepVar(Expr e) {
    if (e.dependsOn(dependent)) return true;
    for (var k = 1; k <= order; k++) {
      if (e.dependsOn(derivSentinel(k))) return true;
    }
    return false;
  }

  bool hasForbiddenVar(Expr e) => e.dependsOn(independent) || hasDepVar(e);

  if ((coeffs[order] is Number && (coeffs[order] as Number).isZero) ||
      coeffs.any(hasForbiddenVar) ||
      hasDepVar(d)) {
    throw UnsupportedError(
      'Only linear ODEs with constant coefficients are supported.',
    );
  }

  final yh = _buildHomogeneousSolution(
    coeffs,
    order: order,
    independent: independent,
    constant: constant,
    assumptions: assumptions,
  );

  final rhs = (-d).simplify(assumptions: assumptions);
  if (rhs is Number && rhs.isZero) {
    return yh;
  }

  final yp = _particularSolutionNthOrder(
    coeffs,
    rhs,
    independent,
    assumptions: assumptions,
  );
  return (yh + yp).simplify(assumptions: assumptions);
}

Expr _buildHomogeneousSolution(
  List<Expr> coeffs, {
  required int order,
  required String independent,
  required String constant,
  required Assumptions assumptions,
}) {
  final xVar = Variable(independent);
  String constName(int index) => index == 1
      ? constant
      : (constant == 'C1' ? 'C$index' : '${constant}_$index');

  if (order == 2) {
    final c = coeffs[0];
    final b = coeffs[1];
    final a = coeffs[2];
    final c1 = Variable(constName(1));
    final c2 = Variable(constName(2));
    final delta = (b * b - IntegerNumber.of(4) * a * c).simplify(
      assumptions: assumptions,
    );

    if (delta is Number && delta.isZero) {
      final r = (-b / (IntegerNumber.two * a)).simplify(
        assumptions: assumptions,
      );
      return ((c1 + c2 * xVar) * Pow(Constant.e, r * xVar)).simplify(
        assumptions: assumptions,
      );
    }
    if (isNegativeExpr(delta, assumptions: assumptions)) {
      final alpha = (-b / (IntegerNumber.two * a)).simplify(
        assumptions: assumptions,
      );
      final beta = (Pow(-delta, FractionNumber.half) / (IntegerNumber.two * a))
          .simplify(assumptions: assumptions);
      return (Pow(Constant.e, alpha * xVar) *
              (c1 * Cos(beta * xVar) + c2 * Sin(beta * xVar)))
          .simplify(assumptions: assumptions);
    }
    final sqrtDelta = Pow(delta, FractionNumber.half);
    final r1 = ((-b - sqrtDelta) / (IntegerNumber.two * a)).simplify(
      assumptions: assumptions,
    );
    final r2 = ((-b + sqrtDelta) / (IntegerNumber.two * a)).simplify(
      assumptions: assumptions,
    );
    return (c1 * Pow(Constant.e, r1 * xVar) + c2 * Pow(Constant.e, r2 * xVar))
        .simplify(assumptions: assumptions);
  }

  const rName = '_r';
  const rVar = Variable(rName);
  var charPoly = IntegerNumber.zero as Expr;
  for (var j = 0; j <= order; j++) {
    final aj = coeffs[j];
    if (aj is Number && aj.isZero) continue;
    final rPow = j == 0
        ? IntegerNumber.one
        : (j == 1 ? rVar : Pow(rVar, IntegerNumber.of(j)));
    charPoly = charPoly + aj * rPow;
  }
  charPoly = charPoly.simplify(assumptions: assumptions);

  final roots = solveEquation(charPoly, rName, assumptions: assumptions);
  if (roots.isEmpty) {
    throw UnsupportedError(
      'Could not find characteristic roots for order-$order ODE.',
    );
  }

  var constIdx = 1;
  var yh = IntegerNumber.zero as Expr;

  for (final root in roots) {
    final mult = _rootMultiplicity(
      charPoly,
      rName,
      root,
      maxOrder: order,
      assumptions: assumptions,
    );
    final alpha = Re(root).simplify(assumptions: assumptions);
    final beta = Im(root).simplify(assumptions: assumptions);

    if (beta is Number && beta.isZero) {
      final expTerm = (alpha is Number && alpha.isZero)
          ? IntegerNumber.one
          : Pow(Constant.e, alpha * xVar);
      for (var k = 0; k < mult; k++) {
        final ck = Variable(constName(constIdx++));
        final xPow = k == 0
            ? IntegerNumber.one
            : (k == 1 ? xVar : Pow(xVar, IntegerNumber.of(k)));
        yh = yh + ck * xPow * expTerm;
      }
    } else {
      final isPosIm =
          isPositiveExpr(beta, assumptions: assumptions) ||
          (beta.freeVariables.isEmpty && beta.evaluate() > 0);
      if (!isPosIm) continue;
      final expTerm = (alpha is Number && alpha.isZero)
          ? IntegerNumber.one
          : Pow(Constant.e, alpha * xVar);
      for (var k = 0; k < mult; k++) {
        final cA = Variable(constName(constIdx++));
        final cB = Variable(constName(constIdx++));
        final xPow = k == 0
            ? IntegerNumber.one
            : (k == 1 ? xVar : Pow(xVar, IntegerNumber.of(k)));
        yh =
            yh +
            xPow * expTerm * (cA * Cos(beta * xVar) + cB * Sin(beta * xVar));
      }
    }
  }

  return yh.simplify(assumptions: assumptions);
}

int _rootMultiplicity(
  Expr poly,
  String rName,
  Expr z, {
  required int maxOrder,
  required Assumptions assumptions,
}) {
  var current = poly;
  var mult = 0;
  for (var k = 0; k < maxOrder; k++) {
    final val = current.substitute(rName, z).simplify(assumptions: assumptions);
    final isZero =
        (val is Number && val.isZero) ||
        (val is ComplexNumber && val.isZero) ||
        (val.freeVariables.isEmpty &&
            () {
              try {
                final c = val.evaluateComplex();
                return !c.isNaN && c.a.abs() < 1e-10 && c.b.abs() < 1e-10;
              } on Object {
                return false;
              }
            }());
    if (!isZero) break;
    mult++;
    current = current.derivative(rName, assumptions: assumptions);
  }
  return mult;
}

Expr _particularSolutionNthOrder(
  List<Expr> coeffs,
  Expr rhs,
  String independent, {
  required Assumptions assumptions,
}) {
  final order = coeffs.length - 1;
  final xVar = Variable(independent);
  const rName = '_r';
  const rVar = Variable(rName);
  var charPoly = IntegerNumber.zero as Expr;
  for (var j = 0; j <= order; j++) {
    final aj = coeffs[j];
    if (aj is Number && aj.isZero) continue;
    final rPow = j == 0
        ? IntegerNumber.one
        : (j == 1 ? rVar : Pow(rVar, IntegerNumber.of(j)));
    charPoly = charPoly + aj * rPow;
  }
  charPoly = charPoly.simplify(assumptions: assumptions);

  final terms = rhs is Add ? rhs.terms : [rhs];
  final groups =
      <
        (Expr, Expr),
        ({Expr alpha, Expr beta, List<Expr> cosTerms, List<Expr> sinTerms})
      >{};

  for (final term in terms) {
    final parsed = _parseForcingTerm(
      term,
      independent,
      assumptions: assumptions,
    );
    if (parsed == null) {
      throw UnsupportedError(
        'Unsupported inhomogeneous term in linear ODE: $term',
      );
    }
    for (final piece in parsed) {
      final key = (piece.alpha, piece.beta);
      final group = groups.putIfAbsent(
        key,
        () => (
          alpha: piece.alpha,
          beta: piece.beta,
          cosTerms: <Expr>[],
          sinTerms: <Expr>[],
        ),
      );
      if (piece.isSin) {
        group.sinTerms.add(piece.poly);
      } else {
        group.cosTerms.add(piece.poly);
      }
    }
  }

  var totalYp = IntegerNumber.zero as Expr;

  for (final group in groups.values) {
    final alpha = group.alpha;
    final beta = group.beta;
    final isTrig = !(beta is Number && beta.isZero);

    final qCos = group.cosTerms.isEmpty
        ? IntegerNumber.zero
        : Add(group.cosTerms).simplify(assumptions: assumptions);
    final qSin = group.sinTerms.isEmpty
        ? IntegerNumber.zero
        : Add(group.sinTerms).simplify(assumptions: assumptions);

    final degCos = qCos is Number && qCos.isZero
        ? 0
        : (polynomialDegree(qCos, independent) ?? 99);
    final degSin = qSin is Number && qSin.isZero
        ? 0
        : (polynomialDegree(qSin, independent) ?? 99);
    final m = degCos > degSin ? degCos : degSin;
    if (m > 4) {
      throw UnsupportedError(
        'Polynomial forcing of degree > 4 in linear ODE is not supported.',
      );
    }

    final z = isTrig
        ? (alpha + ComplexNumber.i * beta).simplify(assumptions: assumptions)
        : alpha;
    final s = _rootMultiplicity(
      charPoly,
      rName,
      z,
      maxOrder: order,
      assumptions: assumptions,
    );

    final unknowns = <String>[];
    var polyA = IntegerNumber.zero as Expr;
    var polyB = IntegerNumber.zero as Expr;
    for (var k = 0; k <= m; k++) {
      final aName = '_ua_$k';
      unknowns.add(aName);
      final xPow = k == 0
          ? IntegerNumber.one
          : (k == 1 ? xVar : Pow(xVar, IntegerNumber.of(k)));
      polyA = polyA + Variable(aName) * xPow;
      if (isTrig) {
        final bName = '_ub_$k';
        unknowns.add(bName);
        polyB = polyB + Variable(bName) * xPow;
      }
    }

    final xShift = s == 0
        ? IntegerNumber.one
        : (s == 1 ? xVar : Pow(xVar, IntegerNumber.of(s)));
    final expFactor = (alpha is Number && alpha.isZero)
        ? IntegerNumber.one
        : Pow(Constant.e, alpha * xVar);

    final Expr ypAnsatz;
    final Expr forcing;
    if (!isTrig) {
      ypAnsatz = (xShift * expFactor * polyA).simplify(
        assumptions: assumptions,
      );
      forcing = (qCos * expFactor).simplify(assumptions: assumptions);
    } else {
      final cosBx = Cos(beta * xVar);
      final sinBx = Sin(beta * xVar);
      ypAnsatz = (xShift * expFactor * (polyA * cosBx + polyB * sinBx))
          .simplify(assumptions: assumptions);
      forcing = (expFactor * (qCos * cosBx + qSin * sinBx)).simplify(
        assumptions: assumptions,
      );
    }

    var lhs = IntegerNumber.zero as Expr;
    var currentDeriv = ypAnsatz;
    for (var j = 0; j <= order; j++) {
      if (j > 0) {
        currentDeriv = currentDeriv.derivative(
          independent,
          assumptions: assumptions,
        );
      }
      final aj = coeffs[j];
      if (!(aj is Number && aj.isZero)) {
        lhs = lhs + aj * currentDeriv;
      }
    }

    var residual = lhs - forcing;
    if (!(alpha is Number && alpha.isZero)) {
      residual = residual * Pow(Constant.e, -alpha * xVar);
    }
    residual = residual
        .expand(assumptions: assumptions)
        .simplify(assumptions: assumptions);

    final equations = <Expr>[];
    if (!isTrig) {
      final resCoeffs = extractPolynomialCoefficients(residual, independent);
      if (resCoeffs == null) {
        throw UnsupportedError(
          'Could not extract polynomial coefficients from ODE residual.',
        );
      }
      for (final c in resCoeffs.values) {
        if (!(c is Number && c.isZero)) equations.add(c);
      }
    } else {
      const ocName = '_oc';
      const osName = '_os';
      final cosBx = Cos(beta * xVar).simplify(assumptions: assumptions);
      final sinBx = Sin(beta * xVar).simplify(assumptions: assumptions);
      Expr replaceTrig(Expr e) {
        if (e == cosBx) return const Variable(ocName);
        if (e == sinBx) return const Variable(osName);
        return e.mapChildren(replaceTrig);
      }

      final trigRes = replaceTrig(residual).simplify(assumptions: assumptions);
      final cPart = trigRes
          .substitute(ocName, IntegerNumber.one)
          .substitute(osName, IntegerNumber.zero)
          .simplify(assumptions: assumptions);
      final sPart = trigRes
          .substitute(ocName, IntegerNumber.zero)
          .substitute(osName, IntegerNumber.one)
          .simplify(assumptions: assumptions);

      for (final part in [cPart, sPart]) {
        final partCoeffs = extractPolynomialCoefficients(part, independent);
        if (partCoeffs == null) {
          throw UnsupportedError(
            'Could not extract polynomial coefficients from trig ODE residual.',
          );
        }
        for (final c in partCoeffs.values) {
          if (!(c is Number && c.isZero)) equations.add(c);
        }
      }
    }

    final solList = equations.solve(unknowns, assumptions: assumptions);
    if (solList.isEmpty) {
      throw UnsupportedError(
        'Could not solve undetermined coefficients for linear ODE.',
      );
    }
    var ypSolved = ypAnsatz;
    for (final entry in solList.first.entries) {
      ypSolved = ypSolved.substitute(entry.key, entry.value);
    }
    totalYp = totalYp + ypSolved.simplify(assumptions: assumptions);
  }

  return totalYp.simplify(assumptions: assumptions);
}

List<({Expr poly, Expr alpha, Expr beta, bool isSin})>? _parseForcingTerm(
  Expr term,
  String independent, {
  required Assumptions assumptions,
}) {
  final factors = term is Mul ? term.factors : [term];
  final polyFactors = <Expr>[];
  var alpha = IntegerNumber.zero as Expr;
  Expr? trigFactor;

  for (final f in factors) {
    if (!f.dependsOn(independent)) {
      polyFactors.add(f);
      continue;
    }
    if (f case Pow(base: Constant.e, :final exponent)) {
      final lin = exponent.matchLinear(independent);
      if (lin == null) return null;
      alpha = (alpha + lin.a).simplify(assumptions: assumptions);
      if (!(lin.b is Number && (lin.b as Number).isZero)) {
        polyFactors.add(Pow(Constant.e, lin.b));
      }
      continue;
    }
    if ((f is Sin || f is Cos) && trigFactor == null) {
      trigFactor = f;
      continue;
    }
    if (polynomialDegree(f, independent) != null) {
      polyFactors.add(f);
      continue;
    }
    return null;
  }

  final poly = polyFactors.isEmpty
      ? IntegerNumber.one
      : Mul(polyFactors).simplify(assumptions: assumptions);

  if (trigFactor == null) {
    return [(poly: poly, alpha: alpha, beta: IntegerNumber.zero, isSin: false)];
  }

  final arg = trigFactor is Cos ? trigFactor.expr : (trigFactor as Sin).expr;
  final lin = arg.matchLinear(independent);
  if (lin == null || (lin.a is Number && (lin.a as Number).isZero)) {
    return null;
  }
  final beta = lin.a;
  final phi = lin.b;
  if (phi is Number && phi.isZero) {
    return [(poly: poly, alpha: alpha, beta: beta, isSin: trigFactor is Sin)];
  }
  if (trigFactor is Cos) {
    return [
      (
        poly: (poly * Cos(phi)).simplify(assumptions: assumptions),
        alpha: alpha,
        beta: beta,
        isSin: false,
      ),
      (
        poly: (-poly * Sin(phi)).simplify(assumptions: assumptions),
        alpha: alpha,
        beta: beta,
        isSin: true,
      ),
    ];
  } else {
    return [
      (
        poly: (poly * Cos(phi)).simplify(assumptions: assumptions),
        alpha: alpha,
        beta: beta,
        isSin: true,
      ),
      (
        poly: (poly * Sin(phi)).simplify(assumptions: assumptions),
        alpha: alpha,
        beta: beta,
        isSin: false,
      ),
    ];
  }
}
