import '../algebra/factor.dart';
import '../algebra/simplify.dart';
import '../assumptions.dart';
import '../ast.dart';
import '../calculus/integration.dart';
import '../calculus/linear_form.dart';
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
  /// Optionally accepts an initial value condition: $y(\text{at}) = \text{initialValue}$,
  /// determining the integration constant [constant] (defaults to `'C1'`).
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
    Object? initialValue,
    Assumptions assumptions = Assumptions.none,
  }) => solveOdeEquation(
    this,
    dependent: dependent,
    independent: independent,
    constant: constant,
    at: at,
    initialValue: initialValue,
    assumptions: assumptions,
  );
}

/// Solves symbolic ordinary differential equation [equation] for [dependent]
/// with respect to [independent].
Expr solveOde(
  Expr equation, {
  required String dependent,
  required String independent,
  String constant = 'C1',
  Object? at,
  Object? initialValue,
  Assumptions assumptions = Assumptions.none,
}) => solveOdeEquation(
  equation,
  dependent: dependent,
  independent: independent,
  constant: constant,
  at: at,
  initialValue: initialValue,
  assumptions: assumptions,
);

/// Solves first-order ordinary differential equation [equation] analytically.
Expr solveOdeEquation(
  Expr equation, {
  required String dependent,
  required String independent,
  String constant = 'C1',
  Object? at,
  Object? initialValue,
  Assumptions assumptions = Assumptions.none,
}) {
  var eq = equation;
  if (eq is RelationalExpr) {
    eq = eq.left - eq.right;
  }

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
  Expr ySol;

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

  if (at != null && initialValue != null) {
    final atExpr = _toExpr(at);
    final initExpr = _toExpr(initialValue);
    final evaluated = ySol
        .substitute(independent, atExpr)
        .simplify(assumptions: assumptions);
    final cEq = (evaluated - initExpr).simplify(assumptions: assumptions);
    final cRoots = cEq.solve(constant, assumptions: assumptions);
    if (cRoots.isNotEmpty) {
      ySol = ySol
          .substitute(constant, cRoots.first)
          .simplify(assumptions: assumptions);
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
