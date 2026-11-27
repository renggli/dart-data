part of '../ast.dart';

/// Direction for computing directional limits of symbolic expressions.
enum LimitDirection {
  /// Two-sided limit `lim_{x -> a} f(x)`. Requires left and right limits to agree.
  both,

  /// Right-hand limit `lim_{x -> a^+} f(x)`.
  fromAbove,

  /// Left-hand limit `lim_{x -> a^-} f(x)`.
  fromBelow,
}

/// Base class for symbolic expressions that introduce a bound variable
/// ([Derivative], [Integral], [Limit], [Sum], [Product], [RootSum]).
///
/// Centralizes bound-variable [freeVariables] computation and capture-avoiding
/// alpha-renaming during [substitute].
sealed class BinderExpr extends Expr {
  /// Creates a binder AST node on bound [variable].
  new(this.variable);

  /// The bound variable name.
  final String variable;

  /// Whether [variable] is strictly bound in the body (false for indefinite
  /// integrals and unpointed derivatives).
  bool get bindsVariable;

  Iterable<Expr> get _bodyExprs;

  Iterable<Expr> get _outerExprs;

  BinderExpr _rebuildWith(
    String variable,
    List<Expr> nextBodies,
    List<Expr> nextOuters,
  );

  @override
  late final Set<String> freeVariables = () {
    final vars = <String>{};
    for (final e in _bodyExprs) {
      vars.addAll(e.freeVariables);
    }
    if (bindsVariable) {
      vars.remove(variable);
    } else {
      vars.add(variable);
    }
    for (final e in _outerExprs) {
      vars.addAll(e.freeVariables);
    }
    return Set<String>.unmodifiable(vars);
  }();

  @override
  late final int flags = _computeBinderFlags();

  @override
  late final int nodeCount = _computeBinderNodeCount();

  int _computeBinderFlags() {
    var f = kFlagHasBinder | (bindsVariable ? 0 : kFlagHasVariable);
    for (final e in _bodyExprs) {
      f |= e.flags & kStructuralFlagsMask;
    }
    for (final e in _outerExprs) {
      f |= e.flags & kStructuralFlagsMask;
    }
    return f;
  }

  int _computeBinderNodeCount() {
    var c = 1;
    for (final e in _bodyExprs) {
      c += e.nodeCount;
    }
    for (final e in _outerExprs) {
      c += e.nodeCount;
    }
    return c;
  }

  @override
  Expr substitute(String variable, Expr replacement) {
    final bodies = _bodyExprs.toList(growable: false);
    final outers = _outerExprs.toList(growable: false);

    if (variable == this.variable) {
      if (!bindsVariable) {
        return _substituteFreeBinder(replacement);
      }
      final nextOuters = [
        for (final o in outers) o.substitute(variable, replacement),
      ];
      return _rebuildWith(this.variable, bodies, nextOuters);
    }

    var boundVar = this.variable;
    var activeBodies = bodies;
    if (replacement.freeVariables.contains(boundVar)) {
      final used = <String>{
        for (final b in activeBodies) ...b.freeVariables,
        for (final o in outers) ...o.freeVariables,
        ...replacement.freeVariables,
      };
      final fresh = _freshBoundVariable(boundVar, used);
      final freshVar = Variable(fresh);
      activeBodies = [
        for (final b in activeBodies) b.substitute(boundVar, freshVar),
      ];
      boundVar = fresh;
    }

    final nextBodies = [
      for (final b in activeBodies) b.substitute(variable, replacement),
    ];
    final nextOuters = [
      for (final o in outers) o.substitute(variable, replacement),
    ];
    return _rebuildWith(boundVar, nextBodies, nextOuters);
  }

  Expr _substituteFreeBinder(Expr replacement);

  @override
  bool anyNode(bool Function(Expr) predicate) {
    if (predicate(this)) return true;
    for (final b in _bodyExprs) {
      if (b.anyNode(predicate)) return true;
    }
    for (final o in _outerExprs) {
      if (o.anyNode(predicate)) return true;
    }
    return false;
  }

  @override
  Expr mapChildren(Expr Function(Expr) transform) {
    final bodies = _bodyExprs.toList(growable: false);
    final outers = _outerExprs.toList(growable: false);
    final nextBodies = _mapExprList(bodies, transform);
    final nextOuters = _mapExprList(outers, transform);
    if (identical(nextBodies, bodies) && identical(nextOuters, outers)) {
      return this;
    }
    return _rebuildWith(variable, nextBodies, nextOuters);
  }
}

/// Symbolic derivative node representing an unevaluated derivative
/// `d^n/dx^n f(x)` or evaluated at a point `d^n/dx^n f(x)|_{x=a}`.
final class Derivative extends BinderExpr {
  /// Creates a symbolic derivative of [expr] with respect to [variable] of
  /// order [order], optionally evaluated at [point].
  new(this.expr, String variable, {this.order = 1, this.point})
    : assert(order >= 1, 'Derivative order must be at least 1.'),
      super(variable);

  /// The differentiated operand expression `f(x)`.
  final Expr expr;

  /// The order of differentiation `n >= 1`.
  final int order;

  /// Optional evaluation point `a`.
  final Expr? point;

  @override
  bool get bindsVariable => point != null;

  @override
  Iterable<Expr> get _bodyExprs => [expr];

  @override
  Iterable<Expr> get _outerExprs => [?point];

  @override
  int get structuralTag => 90;

  @override
  late final int hashCode = Object.hash(
    Derivative,
    expr,
    variable,
    order,
    point,
  );

  @override
  BinderExpr _rebuildWith(
    String variable,
    List<Expr> nextBodies,
    List<Expr> nextOuters,
  ) => Derivative(
    nextBodies[0],
    variable,
    order: order,
    point: nextOuters.isEmpty ? null : nextOuters[0],
  );

  @override
  Expr _substituteFreeBinder(Expr replacement) {
    if (replacement is Variable) {
      final targetName = replacement.name;
      var body = expr;
      if (targetName != variable && body.freeVariables.contains(targetName)) {
        final used = <String>{
          ...body.freeVariables,
          ...replacement.freeVariables,
        };
        final fresh = _freshBoundVariable(targetName, used);
        body = body.substitute(targetName, Variable(fresh));
      }
      return Derivative(
        body.substitute(variable, replacement),
        targetName,
        order: order,
      );
    }
    final derived = expr.derivative(variable, order: order);
    if (!derived.anyNode(
      (node) =>
          node is Derivative && node.variable == variable && node.point == null,
    )) {
      return derived.substitute(variable, replacement);
    }
    return Derivative(expr, variable, order: order, point: replacement);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Derivative &&
          hashCode == other.hashCode &&
          order == other.order &&
          variable == other.variable &&
          expr == other.expr &&
          point == other.point);
}

/// Symbolic integral node representing an unevaluated indefinite or definite
/// integral.
final class Integral extends BinderExpr {
  /// Creates a symbolic integral of [integrand] with respect to [variable],
  /// optionally bounded from [lower] to [upper].
  new(this.integrand, String variable, {this.lower, this.upper})
    : assert(
        (lower == null) == (upper == null),
        'Both lower and upper bounds must be provided for definite integrals, '
        'or neither for indefinite integrals.',
      ),
      super(variable);

  /// The integrand expression `f(x)`.
  final Expr integrand;

  /// Optional lower bound `a` for a definite integral.
  final Expr? lower;

  /// Optional upper bound `b` for a definite integral.
  final Expr? upper;

  /// Whether this represents a definite integral with [lower] and [upper].
  bool get isDefinite => lower != null && upper != null;

  @override
  bool get bindsVariable => isDefinite;

  @override
  Iterable<Expr> get _bodyExprs => [integrand];

  @override
  Iterable<Expr> get _outerExprs => isDefinite ? [lower!, upper!] : const [];

  @override
  int get structuralTag => 91;

  @override
  late final int hashCode = Object.hash(
    Integral,
    integrand,
    variable,
    lower,
    upper,
  );

  @override
  BinderExpr _rebuildWith(
    String variable,
    List<Expr> nextBodies,
    List<Expr> nextOuters,
  ) => Integral(
    nextBodies[0],
    variable,
    lower: nextOuters.isEmpty ? null : nextOuters[0],
    upper: nextOuters.length < 2 ? null : nextOuters[1],
  );

  @override
  Expr _substituteFreeBinder(Expr replacement) {
    if (replacement is Variable) {
      final targetName = replacement.name;
      if (targetName == variable) return this;
      if (!integrand.freeVariables.contains(targetName)) {
        return Integral(
          integrand.substitute(variable, replacement),
          targetName,
        );
      }
    }
    return this;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Integral &&
          hashCode == other.hashCode &&
          variable == other.variable &&
          integrand == other.integrand &&
          lower == other.lower &&
          upper == other.upper);
}

/// Symbolic limit node representing an unevaluated limit `lim_{x -> a} f(x)`.
final class Limit extends BinderExpr {
  /// Creates a symbolic limit of [expr] as [variable] approaches [point].
  new(
    this.expr,
    String variable,
    this.point, {
    this.direction = LimitDirection.both,
  }) : super(variable);

  /// The operand expression `f(x)`.
  final Expr expr;

  /// The target limit point `a`.
  final Expr point;

  /// The limit direction.
  final LimitDirection direction;

  @override
  bool get bindsVariable => true;

  @override
  Iterable<Expr> get _bodyExprs => [expr];

  @override
  Iterable<Expr> get _outerExprs => [point];

  @override
  int get structuralTag => 92;

  @override
  late final int hashCode = Object.hash(
    Limit,
    expr,
    variable,
    point,
    direction,
  );

  @override
  BinderExpr _rebuildWith(
    String variable,
    List<Expr> nextBodies,
    List<Expr> nextOuters,
  ) => Limit(nextBodies[0], variable, nextOuters[0], direction: direction);

  @override
  Expr _substituteFreeBinder(Expr replacement) => this;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Limit &&
          hashCode == other.hashCode &&
          direction == other.direction &&
          variable == other.variable &&
          point == other.point &&
          expr == other.expr);
}

/// Symbolic summation node representing an unevaluated definite sum
/// `sum_{k=a}^b f(k)`.
final class Sum extends BinderExpr {
  /// Creates a symbolic sum of [expr] over [variable] from [lower] to [upper].
  new(this.expr, String variable, this.lower, this.upper) : super(variable);

  /// The summand expression `f(k)`.
  final Expr expr;

  /// The lower bound `a`.
  final Expr lower;

  /// The upper bound `b`.
  final Expr upper;

  @override
  bool get bindsVariable => true;

  @override
  Iterable<Expr> get _bodyExprs => [expr];

  @override
  Iterable<Expr> get _outerExprs => [lower, upper];

  @override
  int get structuralTag => 93;

  @override
  late final int hashCode = Object.hash(Sum, expr, variable, lower, upper);

  @override
  BinderExpr _rebuildWith(
    String variable,
    List<Expr> nextBodies,
    List<Expr> nextOuters,
  ) => Sum(nextBodies[0], variable, nextOuters[0], nextOuters[1]);

  @override
  Expr _substituteFreeBinder(Expr replacement) => this;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Sum &&
          hashCode == other.hashCode &&
          variable == other.variable &&
          expr == other.expr &&
          lower == other.lower &&
          upper == other.upper);
}

/// Symbolic product node representing an unevaluated definite product
/// `prod_{k=a}^b f(k)`.
final class Product extends BinderExpr {
  /// Creates a symbolic product of [expr] over [variable] from [lower] to [upper].
  new(this.expr, String variable, this.lower, this.upper) : super(variable);

  /// The factor expression `f(k)`.
  final Expr expr;

  /// The lower bound `a`.
  final Expr lower;

  /// The upper bound `b`.
  final Expr upper;

  @override
  bool get bindsVariable => true;

  @override
  Iterable<Expr> get _bodyExprs => [expr];

  @override
  Iterable<Expr> get _outerExprs => [lower, upper];

  @override
  int get structuralTag => 94;

  @override
  late final int hashCode = Object.hash(Product, expr, variable, lower, upper);

  @override
  BinderExpr _rebuildWith(
    String variable,
    List<Expr> nextBodies,
    List<Expr> nextOuters,
  ) => Product(nextBodies[0], variable, nextOuters[0], nextOuters[1]);

  @override
  Expr _substituteFreeBinder(Expr replacement) => this;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Product &&
          hashCode == other.hashCode &&
          variable == other.variable &&
          expr == other.expr &&
          lower == other.lower &&
          upper == other.upper);
}

/// Symbolic sum of [body] over all complex roots of `polynomial(variable) = 0`.
final class RootSum extends BinderExpr {
  /// Creates a symbolic root-sum of [body] over roots `t` of [polynomial].
  new(this.polynomial, String variable, this.body) : super(variable);

  /// The defining polynomial `P(t)`.
  final Expr polynomial;

  /// The summand expression `f(t)`.
  final Expr body;

  @override
  bool get bindsVariable => true;

  @override
  Iterable<Expr> get _bodyExprs => [polynomial, body];

  @override
  Iterable<Expr> get _outerExprs => const [];

  @override
  int get structuralTag => 95;

  @override
  late final int hashCode = Object.hash(RootSum, polynomial, variable, body);

  @override
  BinderExpr _rebuildWith(
    String variable,
    List<Expr> nextBodies,
    List<Expr> nextOuters,
  ) => RootSum(nextBodies[0], variable, nextBodies[1]);

  @override
  Expr _substituteFreeBinder(Expr replacement) => this;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RootSum &&
          hashCode == other.hashCode &&
          variable == other.variable &&
          polynomial == other.polynomial &&
          body == other.body);
}
