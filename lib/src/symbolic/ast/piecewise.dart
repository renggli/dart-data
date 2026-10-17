part of '../ast.dart';

/// Base class for relational comparison conditions used in [Piecewise] branches.
sealed class RelationalExpr extends BinaryExpr {
  /// Creates a relational comparison between [left] and [right].
  new(super.left, super.right, {super.isSimplified = false});

  /// Evaluates this relational condition to `true` or `false` under [context].
  bool evaluateCondition([Map<String, double> context = const {}]);

  @override
  double evaluate([Map<String, double> context = const {}]) =>
      evaluateCondition(context) ? 1.0 : 0.0;
}

/// Strict less-than relation: $\text{left} < \text{right}$.
final class LessThan extends RelationalExpr {
  /// Creates a `<` relation.
  new(super.left, super.right, {super.isSimplified = false});

  @override
  bool evaluateCondition([Map<String, double> context = const {}]) =>
      left.evaluate(context) < right.evaluate(context);

  @override
  Expr substitute(String variable, Expr replacement) => LessThan(
    left.substitute(variable, replacement),
    right.substitute(variable, replacement),
  );

  @override
  Expr mapChildren(Expr Function(Expr) transform) =>
      LessThan(transform(left), transform(right));
}

/// Less-than-or-equal relation: $\text{left} \le \text{right}$.
final class LessEqual extends RelationalExpr {
  /// Creates a `<=` relation.
  new(super.left, super.right, {super.isSimplified = false});

  @override
  bool evaluateCondition([Map<String, double> context = const {}]) =>
      left.evaluate(context) <= right.evaluate(context);

  @override
  Expr substitute(String variable, Expr replacement) => LessEqual(
    left.substitute(variable, replacement),
    right.substitute(variable, replacement),
  );

  @override
  Expr mapChildren(Expr Function(Expr) transform) =>
      LessEqual(transform(left), transform(right));
}

/// Strict greater-than relation: $\text{left} > \text{right}$.
final class GreaterThan extends RelationalExpr {
  /// Creates a `>` relation.
  new(super.left, super.right, {super.isSimplified = false});

  @override
  bool evaluateCondition([Map<String, double> context = const {}]) =>
      left.evaluate(context) > right.evaluate(context);

  @override
  Expr substitute(String variable, Expr replacement) => GreaterThan(
    left.substitute(variable, replacement),
    right.substitute(variable, replacement),
  );

  @override
  Expr mapChildren(Expr Function(Expr) transform) =>
      GreaterThan(transform(left), transform(right));
}

/// Greater-than-or-equal relation: $\text{left} \ge \text{right}$.
final class GreaterEqual extends RelationalExpr {
  /// Creates a `>=` relation.
  new(super.left, super.right, {super.isSimplified = false});

  @override
  bool evaluateCondition([Map<String, double> context = const {}]) =>
      left.evaluate(context) >= right.evaluate(context);

  @override
  Expr substitute(String variable, Expr replacement) => GreaterEqual(
    left.substitute(variable, replacement),
    right.substitute(variable, replacement),
  );

  @override
  Expr mapChildren(Expr Function(Expr) transform) =>
      GreaterEqual(transform(left), transform(right));
}

/// Equality relation: $\text{left} = \text{right}$.
final class Equal extends RelationalExpr {
  /// Creates an `=` relation.
  new(super.left, super.right, {super.isSimplified = false});

  @override
  bool evaluateCondition([Map<String, double> context = const {}]) =>
      left.evaluate(context) == right.evaluate(context);

  @override
  Expr substitute(String variable, Expr replacement) => Equal(
    left.substitute(variable, replacement),
    right.substitute(variable, replacement),
  );

  @override
  Expr mapChildren(Expr Function(Expr) transform) =>
      Equal(transform(left), transform(right));
}

/// Piecewise conditional expression node:
/// $$f(x) = \begin{cases} e_1 & \text{if } c_1 \\ e_2 & \text{if } c_2 \\ \text{otherwise} & \text{otherwise} \end{cases}$$
final class Piecewise extends Expr {
  /// Creates a piecewise expression from guarded `(condition, expression)`
  /// [branches] and an optional fallback [otherwise] expression.
  new(this.branches, {this.otherwise, this.isSimplified = false});

  /// Ordered list of `(condition, expression)` pairs evaluated top-to-bottom.
  final List<(RelationalExpr, Expr)> branches;

  /// Optional fallback expression evaluated when no branch condition holds.
  final Expr? otherwise;

  @override
  final bool isSimplified;

  int? _hashCode;

  @override
  double evaluate([Map<String, double> context = const {}]) {
    for (final (cond, expr) in branches) {
      if (cond.evaluateCondition(context)) {
        return expr.evaluate(context);
      }
    }
    if (otherwise != null) {
      return otherwise!.evaluate(context);
    }
    return double.nan;
  }

  @override
  void collectFreeVariables(Set<String> target) {
    for (final (cond, expr) in branches) {
      cond.collectFreeVariables(target);
      expr.collectFreeVariables(target);
    }
    otherwise?.collectFreeVariables(target);
  }

  @override
  bool dependsOn(String variable) {
    for (final (cond, expr) in branches) {
      if (cond.dependsOn(variable) || expr.dependsOn(variable)) return true;
    }
    return otherwise?.dependsOn(variable) ?? false;
  }

  @override
  Expr substitute(String variable, Expr replacement) => Piecewise([
    for (final (cond, expr) in branches)
      (
        cond.substitute(variable, replacement) as RelationalExpr,
        expr.substitute(variable, replacement),
      ),
  ], otherwise: otherwise?.substitute(variable, replacement));

  @override
  Expr mapChildren(Expr Function(Expr) transform) => Piecewise([
    for (final (cond, expr) in branches)
      (transform(cond) as RelationalExpr, transform(expr)),
  ], otherwise: otherwise != null ? transform(otherwise!) : null);

  @override
  bool anyNode(bool Function(Expr) predicate) {
    if (predicate(this)) return true;
    for (final (cond, expr) in branches) {
      if (cond.anyNode(predicate) || expr.anyNode(predicate)) return true;
    }
    return otherwise?.anyNode(predicate) ?? false;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Piecewise) return false;
    if (otherwise != other.otherwise) return false;
    if (branches.length != other.branches.length) return false;
    for (var i = 0; i < branches.length; i++) {
      if (branches[i].$1 != other.branches[i].$1 ||
          branches[i].$2 != other.branches[i].$2) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => _hashCode ??= Object.hash(
    Piecewise,
    Object.hashAll(branches.map((b) => Object.hash(b.$1, b.$2))),
    otherwise,
  );
}
