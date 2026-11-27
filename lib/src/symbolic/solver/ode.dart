import 'dart:math' as math;

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
import '../functions/fn.dart';
import '../type/expr_data_type.dart';
import 'system.dart';
import 'univariate.dart';

/// Extension providing symbolic ordinary differential equation solving on [Expr].
extension OdeExtension on Expr {
  /// Solves this ordinary differential equation for [dependent] with respect to
  /// [independent].
  ///
  /// Conceptually, an ordinary differential equation (ODE) expresses the rate
  /// of change of an unknown function `y(x)` in terms of `x` and `y`. Solving it
  /// analytically recovers the original family of curves satisfying this rate.
  /// Formally, this solves first-order linear ODEs:
  /// `dy/dx + P(x) * y = Q(x)`
  /// using the integrating factor `mu(x) = exp(integrate(P(x), x))`, as
  /// well as separable ODEs `dy/dx = f(x) * g(y)` and constant-coefficient
  /// linear ODEs up to order 6.
  ///
  /// Optionally accepts initial value conditions at [at]:
  /// `[y(at)]` for first-order ODEs, or `[y(at), y'(at), ...]` for higher-order
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
  if (dependent == independent) {
    throw ArgumentError(
      'Dependent variable "$dependent" and independent variable "$independent" must be distinct.',
    );
  }
  final Expr eq;
  if (equation case Relational(op: RelOp.equal, :final left, :final right)) {
    eq = left - right;
  } else if (equation is Relational) {
    throw ArgumentError.value(
      equation,
      'equation',
      'Expected an equality Relational equation or algebraic expression, got $equation.',
    );
  } else {
    eq = equation;
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

  final usedVars = eq.freeVariables;
  Expr ySol;
  if (maxOrder >= 2) {
    ySol = _tryNthOrderLinearOde(
      eq,
      order: maxOrder,
      dependent: dependent,
      independent: independent,
      constant: constant,
      usedVars: usedVars,
      assumptions: assumptions,
    );
  } else {
    final sentinel = _freshOdeVar(usedVars, '_yPrime');
    final normalized = _replaceFirstDerivative(
      eq,
      dependent,
      independent,
      Variable(sentinel),
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
        final mu = Pow.of(Constant.e, pInt).simplify(assumptions: assumptions);
        final muQ = (mu * q).simplify(assumptions: assumptions);
        final muQInt = muQ.integrate(independent, assumptions: assumptions);
        ySol = ((muQInt + Variable(constant)) / mu).simplify(
          assumptions: assumptions,
        );
      } else {
        // Case 3: Separable ODE: y' = F(x) * G(y)
        final factored = yPrime.factor(assumptions: assumptions);
        final separated = _separateVariables(factored, independent, dependent);
        if (separated case (:final fx, :final gy)) {
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
    final atExpr = Expr.wrap(at);
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
        (evaluated - Expr.wrap(initialValues[k])).simplify(
          assumptions: assumptions,
        ),
      );
    }

    ySol = _applyInitialConditions(
      ySol,
      equations,
      constNames,
      assumptions: assumptions,
    );
  }

  return ySol;
}

Expr _applyInitialConditions(
  Expr ySol,
  List<Expr> equations,
  List<String> constNames, {
  required Assumptions assumptions,
}) {
  var result = ySol;
  var pending = equations
      .map((e) => e.simplify(assumptions: assumptions))
      .toList();
  final remainingConsts = List<String>.of(constNames);

  // First resolve any equations containing a single integration constant.
  var progress = true;
  while (progress && pending.isNotEmpty && remainingConsts.isNotEmpty) {
    progress = false;
    final nextPending = <Expr>[];
    for (final icEq in pending) {
      final deps = remainingConsts.where(icEq.dependsOn).toList();
      if (deps.isEmpty) {
        if (!isZeroExpr(
          icEq
              .expand(assumptions: assumptions)
              .simplify(assumptions: assumptions),
        )) {
          throw StateError(
            'Inconsistent initial conditions for ODE: $icEq = 0.',
          );
        }
        continue;
      }
      if (deps.length == 1) {
        final cName = deps.first;
        final cRoots = icEq.solve(cName, assumptions: assumptions);
        if (cRoots.isEmpty) {
          throw StateError(
            'Inconsistent or unsolvable initial condition for $cName.',
          );
        }
        final cVal = cRoots.first.simplify(assumptions: assumptions);
        result = result
            .substitute(cName, cVal)
            .simplify(assumptions: assumptions);
        remainingConsts.remove(cName);
        nextPending.addAll(
          pending
              .where((p) => !identical(p, icEq))
              .map(
                (p) => p
                    .substitute(cName, cVal)
                    .simplify(assumptions: assumptions),
              ),
        );
        progress = true;
        break;
      }
      nextPending.add(icEq);
    }
    if (!progress) {
      pending = nextPending;
    } else {
      pending = nextPending;
    }
  }

  if (pending.isEmpty) return result;

  final activeConsts = remainingConsts
      .where((c) => pending.any((eq) => eq.dependsOn(c)))
      .toList();
  if (activeConsts.isEmpty) {
    for (final icEq in pending) {
      if (!isZeroExpr(
        icEq
            .expand(assumptions: assumptions)
            .simplify(assumptions: assumptions),
      )) {
        throw StateError('Inconsistent initial conditions for ODE: $icEq = 0.');
      }
    }
    return result;
  }

  final solveConsts = activeConsts.length > pending.length
      ? activeConsts.take(pending.length).toList()
      : activeConsts;
  final solutions = pending.solve(solveConsts, assumptions: assumptions);
  if (solutions.isEmpty) {
    throw StateError(
      'Inconsistent or unsolvable initial conditions for $solveConsts.',
    );
  }
  for (final MapEntry(:key, :value) in solutions.first.entries) {
    result = result.substitute(key, value);
  }
  return result.simplify(assumptions: assumptions);
}

Expr _replaceFirstDerivative(
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
  return expr.mapChildren(
    (child) =>
        _replaceFirstDerivative(child, dependent, independent, replacement),
  );
}

({Expr fx, Expr gy})? _separateVariables(
  Expr expr,
  String independent,
  String dependent,
) {
  final factors = <Expr>[];
  void collectFactor(Expr f) {
    if (f is Mul) {
      for (final sub in f.factors) {
        collectFactor(sub);
      }
      return;
    }
    if (f case Pow(:final base, exponent: Add(:final terms))
        when !base.dependsOn(independent) && !base.dependsOn(dependent)) {
      if (base == Constant.e ||
          isPositiveExpr(base, assumptions: Assumptions.none)) {
        for (final t in terms) {
          collectFactor(Pow.of(base, t));
        }
        return;
      }
    }
    factors.add(f);
  }

  collectFactor(expr);

  final xFactors = <Expr>[];
  final yFactors = <Expr>[];

  for (final factor in factors) {
    final dependsX = factor.dependsOn(independent);
    final dependsY = factor.dependsOn(dependent);
    if (dependsX && dependsY) {
      return null;
    } else if (dependsY) {
      yFactors.add(factor);
    } else {
      xFactors.add(factor);
    }
  }

  final fx = switch (xFactors) {
    [] => IntegerNumber.one,
    [final single] => single,
    _ => Mul.of(xFactors),
  };
  final gy = switch (yFactors) {
    [] => IntegerNumber.one,
    [final single] => single,
    _ => Mul.of(yFactors),
  };

  return (fx: fx, gy: gy);
}

String _freshOdeVar(Set<String> used, String base) {
  var name = base;
  var idx = 1;
  while (used.contains(name)) {
    name = '${base}_$idx';
    idx++;
  }
  return name;
}

Expr _tryNthOrderLinearOde(
  Expr eq, {
  required int order,
  required String dependent,
  required String independent,
  required String constant,
  required Set<String> usedVars,
  required Assumptions assumptions,
}) {
  final derivPrefix = _freshOdeVar(usedVars, '_yDeriv');
  String derivSentinel(int k) => '${derivPrefix}_$k';

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
    usedVars: usedVars,
    assumptions: assumptions,
  );

  final rhs = (-d)
      .expand(assumptions: assumptions)
      .simplify(assumptions: assumptions);
  if (isZeroExpr(rhs)) {
    return yh;
  }

  final yp = _particularSolutionNthOrder(
    coeffs,
    rhs,
    independent,
    usedVars: usedVars,
    assumptions: assumptions,
  );
  return (yh + yp).simplify(assumptions: assumptions);
}

Expr _buildHomogeneousSolution(
  List<Expr> coeffs, {
  required int order,
  required String independent,
  required String constant,
  required Set<String> usedVars,
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
    final delta = (b * b - IntegerNumber.of(4) * a * c)
        .expand(assumptions: assumptions)
        .simplify(assumptions: assumptions);

    if (isZeroExpr(delta)) {
      final r = (-b / (IntegerNumber.two * a)).simplify(
        assumptions: assumptions,
      );
      return ((c1 + c2 * xVar) * Pow.of(Constant.e, r * xVar)).simplify(
        assumptions: assumptions,
      );
    }
    if (isNegativeExpr(delta, assumptions: assumptions)) {
      final alpha = (-b / (IntegerNumber.two * a)).simplify(
        assumptions: assumptions,
      );
      final beta =
          (Pow.of(-delta, FractionNumber.half) / (IntegerNumber.two * a))
              .simplify(assumptions: assumptions);
      return (Pow.of(Constant.e, alpha * xVar) *
              (c1 * Fn.cos(beta * xVar) + c2 * Fn.sin(beta * xVar)))
          .simplify(assumptions: assumptions);
    }
    final sqrtDelta = Pow.of(delta, FractionNumber.half);
    final r1 = ((-b - sqrtDelta) / (IntegerNumber.two * a)).simplify(
      assumptions: assumptions,
    );
    final r2 = ((-b + sqrtDelta) / (IntegerNumber.two * a)).simplify(
      assumptions: assumptions,
    );
    return (c1 * Pow.of(Constant.e, r1 * xVar) +
            c2 * Pow.of(Constant.e, r2 * xVar))
        .simplify(assumptions: assumptions);
  }

  final rName = _freshOdeVar(usedVars, '_r');
  final rVar = Variable(rName);
  var charPoly = IntegerNumber.zero as Expr;
  for (var j = 0; j <= order; j++) {
    final aj = coeffs[j];
    if (isZeroExpr(aj)) continue;
    final rPow = j == 0
        ? IntegerNumber.one
        : (j == 1 ? rVar : Pow.of(rVar, IntegerNumber.of(j)));
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
  var handledMult = 0;
  var yh = IntegerNumber.zero as Expr;
  final rootData = <({Expr alpha, Expr beta, int mult})>[];
  for (final root in roots) {
    final mult = _rootMultiplicity(
      charPoly,
      rName,
      root,
      maxOrder: order,
      assumptions: assumptions,
    );
    final (:re, :im) = decomposeComplex(root, assumptions);
    final alpha = re.simplify(assumptions: assumptions);
    final beta = im.simplify(assumptions: assumptions);
    rootData.add((alpha: alpha, beta: beta, mult: mult));
  }

  final consumedIndices = <int>{};
  for (var i = 0; i < rootData.length; i++) {
    if (consumedIndices.contains(i)) continue;
    final (:alpha, :beta, :mult) = rootData[i];
    if (isZeroExpr(beta)) {
      handledMult += mult;
      final expTerm = isZeroExpr(alpha)
          ? IntegerNumber.one
          : Pow.of(Constant.e, alpha * xVar);
      for (var k = 0; k < mult; k++) {
        final ck = Variable(constName(constIdx++));
        final xPow = k == 0
            ? IntegerNumber.one
            : (k == 1 ? xVar : Pow.of(xVar, IntegerNumber.of(k)));
        yh = yh + ck * xPow * expTerm;
      }
      continue;
    }

    final negBeta = (-beta).simplify(assumptions: assumptions);
    var conjIndex = -1;
    for (var j = i + 1; j < rootData.length; j++) {
      if (consumedIndices.contains(j)) continue;
      if (rootData[j].alpha == alpha &&
          isZeroExpr(
            (rootData[j].beta + beta)
                .expand(assumptions: assumptions)
                .simplify(assumptions: assumptions),
          )) {
        conjIndex = j;
        break;
      }
    }

    if (conjIndex != -1) {
      consumedIndices.add(conjIndex);
      final pairMult = math.min(mult, rootData[conjIndex].mult);
      handledMult += 2 * pairMult;
      final betaVal = _tryEvalFiniteReal(beta);
      final chosenBeta =
          (betaVal != null && betaVal < 0) ||
              isNegativeExpr(beta, assumptions: assumptions)
          ? negBeta
          : beta;
      final expTerm = isZeroExpr(alpha)
          ? IntegerNumber.one
          : Pow.of(Constant.e, alpha * xVar);
      for (var k = 0; k < pairMult; k++) {
        final cA = Variable(constName(constIdx++));
        final cB = Variable(constName(constIdx++));
        final xPow = k == 0
            ? IntegerNumber.one
            : (k == 1 ? xVar : Pow.of(xVar, IntegerNumber.of(k)));
        yh =
            yh +
            xPow *
                expTerm *
                (cA * Fn.cos(chosenBeta * xVar) +
                    cB * Fn.sin(chosenBeta * xVar));
      }
    } else {
      handledMult += mult;
      final expTerm = Pow.of(
        Constant.e,
        (alpha + ComplexNumber.i * beta) * xVar,
      );
      for (var k = 0; k < mult; k++) {
        final ck = Variable(constName(constIdx++));
        final xPow = k == 0
            ? IntegerNumber.one
            : (k == 1 ? xVar : Pow.of(xVar, IntegerNumber.of(k)));
        yh = yh + ck * xPow * expTerm;
      }
    }
  }

  if (handledMult != order) {
    throw UnsupportedError(
      'Could not account for all $order characteristic roots (resolved $handledMult).',
    );
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
    final val = current
        .substitute(rName, z)
        .expand(assumptions: assumptions)
        .simplify(assumptions: assumptions);
    final isZero =
        isZeroExpr(val) ||
        (val is ComplexNumber && val.isZero) ||
        ((val.anyNode((n) => n is RealNumber) ||
                z.anyNode((n) => n is RealNumber)) &&
            val.freeVariables.isEmpty &&
            () {
              try {
                final c = val.evaluateComplex();
                return !c.isNaN && c.a.abs() < 1e-10 && c.b.abs() < 1e-10;
              } on ArgumentError {
                return false;
              } on UnsupportedError {
                return false;
              } on StateError {
                return false;
              }
            }());
    if (!isZero) break;
    mult++;
    current = current.derivative(rName, assumptions: assumptions);
  }
  return mult;
}

double? _tryEvalFiniteReal(Expr expr) {
  if (!expr.isReal || expr.freeVariables.isNotEmpty) return null;
  try {
    final v = expr.evaluate(const {});
    return v.isFinite ? v : null;
  } on ArgumentError {
    return null;
  } on UnsupportedError {
    return null;
  } on StateError {
    return null;
  }
}

Expr _particularSolutionNthOrder(
  List<Expr> coeffs,
  Expr rhs,
  String independent, {
  required Set<String> usedVars,
  required Assumptions assumptions,
}) {
  final order = coeffs.length - 1;
  final xVar = Variable(independent);
  final rName = _freshOdeVar(usedVars, '_r');
  final rVar = Variable(rName);
  var charPoly = IntegerNumber.zero as Expr;
  for (var j = 0; j <= order; j++) {
    final aj = coeffs[j];
    if (aj is Number && aj.isZero) continue;
    final rPow = j == 0
        ? IntegerNumber.one
        : (j == 1 ? rVar : Pow.of(rVar, IntegerNumber.of(j)));
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
        : Add.of(group.cosTerms).simplify(assumptions: assumptions);
    final qSin = group.sinTerms.isEmpty
        ? IntegerNumber.zero
        : Add.of(group.sinTerms).simplify(assumptions: assumptions);

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
      final aName = _freshOdeVar(usedVars, '_ua_$k');
      unknowns.add(aName);
      final xPow = k == 0
          ? IntegerNumber.one
          : (k == 1 ? xVar : Pow.of(xVar, IntegerNumber.of(k)));
      polyA = polyA + Variable(aName) * xPow;
      if (isTrig) {
        final bName = _freshOdeVar(usedVars, '_ub_$k');
        unknowns.add(bName);
        polyB = polyB + Variable(bName) * xPow;
      }
    }

    final xShift = s == 0
        ? IntegerNumber.one
        : (s == 1 ? xVar : Pow.of(xVar, IntegerNumber.of(s)));
    final expFactor = (alpha is Number && alpha.isZero)
        ? IntegerNumber.one
        : Pow.of(Constant.e, alpha * xVar);

    final Expr ypAnsatz;
    final Expr forcing;
    if (!isTrig) {
      ypAnsatz = (xShift * expFactor * polyA).simplify(
        assumptions: assumptions,
      );
      forcing = (qCos * expFactor).simplify(assumptions: assumptions);
    } else {
      final cosBx = Fn.cos(beta * xVar);
      final sinBx = Fn.sin(beta * xVar);
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
      residual = residual * Pow.of(Constant.e, -alpha * xVar);
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
      final ocName = _freshOdeVar(usedVars, '_oc');
      final osName = _freshOdeVar(usedVars, '_os');
      final cosBx = Fn.cos(beta * xVar).simplify(assumptions: assumptions);
      final sinBx = Fn.sin(beta * xVar).simplify(assumptions: assumptions);
      Expr replaceTrig(Expr e) {
        if (e == cosBx) return Variable(ocName);
        if (e == sinBx) return Variable(osName);
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
  Call? trigFactor;

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
        polyFactors.add(Pow.of(Constant.e, lin.b));
      }
      continue;
    }
    if (f is Call &&
        (f.id == FunctionId.sin || f.id == FunctionId.cos) &&
        trigFactor == null) {
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
      : Mul.of(polyFactors).simplify(assumptions: assumptions);

  if (trigFactor == null) {
    return [(poly: poly, alpha: alpha, beta: IntegerNumber.zero, isSin: false)];
  }

  final arg = trigFactor.args[0];
  final lin = arg.matchLinear(independent);
  if (lin == null || (lin.a is Number && (lin.a as Number).isZero)) {
    return null;
  }
  final beta = lin.a;
  final phi = lin.b;
  final isSinFactor = trigFactor.id == FunctionId.sin;
  if (phi is Number && phi.isZero) {
    return [(poly: poly, alpha: alpha, beta: beta, isSin: isSinFactor)];
  }
  if (!isSinFactor) {
    return [
      (
        poly: (poly * Fn.cos(phi)).simplify(assumptions: assumptions),
        alpha: alpha,
        beta: beta,
        isSin: false,
      ),
      (
        poly: (-poly * Fn.sin(phi)).simplify(assumptions: assumptions),
        alpha: alpha,
        beta: beta,
        isSin: true,
      ),
    ];
  } else {
    return [
      (
        poly: (poly * Fn.cos(phi)).simplify(assumptions: assumptions),
        alpha: alpha,
        beta: beta,
        isSin: true,
      ),
      (
        poly: (poly * Fn.sin(phi)).simplify(assumptions: assumptions),
        alpha: alpha,
        beta: beta,
        isSin: false,
      ),
    ];
  }
}
