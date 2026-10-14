part of '../ast.dart';

/// Sealed base class representing a relational binary comparison node.
sealed class RelationalExpr extends BinaryExpr {
  /// Abstract const constructor for relational expressions.
  const new(super.left, super.right);
}

/// Less-than relational operator: $left < right$.
final class LessThan extends RelationalExpr {
  /// Creates a less-than comparison node.
  const new(super.left, super.right);

  @override
  LessThan copyWith(Expr newLeft, Expr newRight) => LessThan(newLeft, newRight);

  @override
  double evaluate(Map<String, double> context) =>
      left.evaluate(context) < right.evaluate(context) ? 1.0 : 0.0;
}

/// Less-than-or-equal relational operator: $left \le right$.
final class LessEqual extends RelationalExpr {
  /// Creates a less-equal comparison node.
  const new(super.left, super.right);

  @override
  LessEqual copyWith(Expr newLeft, Expr newRight) =>
      LessEqual(newLeft, newRight);

  @override
  double evaluate(Map<String, double> context) =>
      left.evaluate(context) <= right.evaluate(context) ? 1.0 : 0.0;
}

/// Greater-than relational operator: $left > right$.
final class GreaterThan extends RelationalExpr {
  /// Creates a greater-than comparison node.
  const new(super.left, super.right);

  @override
  GreaterThan copyWith(Expr newLeft, Expr newRight) =>
      GreaterThan(newLeft, newRight);

  @override
  double evaluate(Map<String, double> context) =>
      left.evaluate(context) > right.evaluate(context) ? 1.0 : 0.0;
}

/// Greater-than-or-equal relational operator: $left \ge right$.
final class GreaterEqual extends RelationalExpr {
  /// Creates a greater-equal comparison node.
  const new(super.left, super.right);

  @override
  GreaterEqual copyWith(Expr newLeft, Expr newRight) =>
      GreaterEqual(newLeft, newRight);

  @override
  double evaluate(Map<String, double> context) =>
      left.evaluate(context) >= right.evaluate(context) ? 1.0 : 0.0;
}

/// Equal relational operator: $left = right$.
final class Equal extends RelationalExpr {
  /// Creates an equality comparison node.
  const new(super.left, super.right);

  @override
  Equal copyWith(Expr newLeft, Expr newRight) => Equal(newLeft, newRight);

  @override
  double evaluate(Map<String, double> context) =>
      left.evaluate(context) == right.evaluate(context) ? 1.0 : 0.0;
}

/// Conditional piecewise expression: selection by boolean condition.
///
/// Encapsulates ordered conditional pairs `(condition, expression)` and an
/// optional [otherwise] default branch.
final class Piecewise extends Expr {
  /// Creates a piecewise defined expression.
  const new(this.branches, {this.otherwise});

  /// The conditional branches in order of evaluation.
  final List<(Expr condition, Expr expr)> branches;

  /// The fallback expression evaluated when no branch condition matches.
  final Expr? otherwise;

  @override
  bool dependsOn(String name) =>
      branches.any((b) => b.$1.dependsOn(name) || b.$2.dependsOn(name)) ||
      (otherwise?.dependsOn(name) ?? false);

  @override
  void collectFreeVariables(Set<String> target) {
    for (final (cond, e) in branches) {
      cond.collectFreeVariables(target);
      e.collectFreeVariables(target);
    }
    otherwise?.collectFreeVariables(target);
  }

  @override
  Expr mapChildren(Expr Function(Expr child) transform) {
    var changed = false;
    final newBranches = <(Expr, Expr)>[];
    for (final (cond, e) in branches) {
      final nextCond = transform(cond);
      final nextExpr = transform(e);
      if (!identical(nextCond, cond) || !identical(nextExpr, e)) {
        changed = true;
      }
      newBranches.add((nextCond, nextExpr));
    }
    final nextOtherwise = otherwise != null ? transform(otherwise!) : null;
    if (!identical(nextOtherwise, otherwise)) {
      changed = true;
    }
    return changed ? Piecewise(newBranches, otherwise: nextOtherwise) : this;
  }

  @override
  bool anyNode(bool Function(Expr node) predicate) =>
      predicate(this) ||
      branches.any((b) => b.$1.anyNode(predicate) || b.$2.anyNode(predicate)) ||
      (otherwise?.anyNode(predicate) ?? false);

  @override
  Expr substitute(String variable, Expr replacement) =>
      mapChildren((child) => child.substitute(variable, replacement));

  @override
  double evaluate(Map<String, double> context) {
    for (final (cond, e) in branches) {
      final cVal = cond.evaluate(context);
      if (cVal != 0.0 && !cVal.isNaN) return e.evaluate(context);
    }
    if (otherwise != null) return otherwise!.evaluate(context);
    throw StateError('No Piecewise branch matched context $context');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Piecewise &&
          branches.length == other.branches.length &&
          otherwise == other.otherwise &&
          _branchesEqual(branches, other.branches));

  static bool _branchesEqual(List<(Expr, Expr)> a, List<(Expr, Expr)> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i].$1 != b[i].$1 || a[i].$2 != b[i].$2) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    Piecewise,
    Object.hashAll(branches.map((b) => Object.hash(b.$1, b.$2))),
    otherwise,
  );
}
