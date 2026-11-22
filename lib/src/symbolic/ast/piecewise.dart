part of '../ast.dart';

/// Base class for relational comparison conditions used in [Piecewise] branches.
sealed class RelationalExpr extends BinaryExpr {
  /// Creates a relational comparison between [left] and [right].
  new(super.left, super.right, {super.isSimplified = false});
}

/// Strict less-than relation: $\text{left} < \text{right}$.
final class LessThan extends RelationalExpr {
  /// Creates a `<` relation.
  new(super.left, super.right, {super.isSimplified = false});

  @override
  Expr _withOperands(Expr left, Expr right) => LessThan(left, right);
}

/// Less-than-or-equal relation: $\text{left} \le \text{right}$.
final class LessEqual extends RelationalExpr {
  /// Creates a `<=` relation.
  new(super.left, super.right, {super.isSimplified = false});

  @override
  Expr _withOperands(Expr left, Expr right) => LessEqual(left, right);
}

/// Strict greater-than relation: $\text{left} > \text{right}$.
final class GreaterThan extends RelationalExpr {
  /// Creates a `>` relation.
  new(super.left, super.right, {super.isSimplified = false});

  @override
  Expr _withOperands(Expr left, Expr right) => GreaterThan(left, right);
}

/// Greater-than-or-equal relation: $\text{left} \ge \text{right}$.
final class GreaterEqual extends RelationalExpr {
  /// Creates a `>=` relation.
  new(super.left, super.right, {super.isSimplified = false});

  @override
  Expr _withOperands(Expr left, Expr right) => GreaterEqual(left, right);
}

/// Equality relation: $\text{left} = \text{right}$.
final class Equal extends RelationalExpr {
  /// Creates an `=` relation.
  new(super.left, super.right, {super.isSimplified = false});

  @override
  Expr _withOperands(Expr left, Expr right) => Equal(left, right);
}

/// Inequality relation: $\text{left} \ne \text{right}$.
final class NotEqual extends RelationalExpr {
  /// Creates a `!=` relation.
  new(super.left, super.right, {super.isSimplified = false});

  @override
  Expr _withOperands(Expr left, Expr right) => NotEqual(left, right);
}

/// A guarded branch in a [Piecewise] expression.
typedef PiecewiseBranch = ({RelationalExpr relation, Expr expr});

/// Piecewise conditional expression node:
/// $$f(x) = \begin{cases} e_1 & \text{if } c_1 \\ e_2 & \text{if } c_2 \\ \text{otherwise} & \text{otherwise} \end{cases}$$
final class Piecewise extends Expr {
  /// Creates a piecewise expression from guarded [branches] and an optional
  /// fallback [otherwise] expression.
  new(
    List<PiecewiseBranch> branches, {
    this.otherwise,
    this.isSimplified = false,
  }) : branches = List.unmodifiable(branches);

  /// Ordered list of [PiecewiseBranch] entries evaluated top-to-bottom.
  final List<PiecewiseBranch> branches;

  /// Optional fallback expression evaluated when no branch condition holds.
  final Expr? otherwise;

  @override
  final bool isSimplified;

  @override
  late final int hashCode = Object.hash(
    Piecewise,
    Object.hashAll(branches.map((b) => Object.hash(b.relation, b.expr))),
    otherwise,
  );

  @override
  late final Set<String> freeVariables = Set.unmodifiable({
    for (final (:relation, :expr) in branches) ...[
      ...relation.freeVariables,
      ...expr.freeVariables,
    ],
    if (otherwise case final o?) ...o.freeVariables,
  });

  @override
  Expr mapChildren(Expr Function(Expr) transform) {
    List<PiecewiseBranch>? updated;
    for (var i = 0; i < branches.length; i++) {
      final branch = branches[i];
      final nextRel = transform(branch.relation) as RelationalExpr;
      final nextExpr = transform(branch.expr);
      if (updated != null) {
        updated[i] = (relation: nextRel, expr: nextExpr);
      } else if (!identical(nextRel, branch.relation) ||
          !identical(nextExpr, branch.expr)) {
        updated = List<PiecewiseBranch>.of(branches);
        updated[i] = (relation: nextRel, expr: nextExpr);
      }
    }
    final nextOtherwise = otherwise != null ? transform(otherwise!) : null;
    if (updated == null && identical(nextOtherwise, otherwise)) {
      return this;
    }
    return Piecewise(updated ?? branches, otherwise: nextOtherwise);
  }

  @override
  bool anyNode(bool Function(Expr) predicate) {
    if (predicate(this)) return true;
    for (final (:relation, :expr) in branches) {
      if (relation.anyNode(predicate) || expr.anyNode(predicate)) return true;
    }
    return otherwise?.anyNode(predicate) ?? false;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Piecewise &&
          branches.length == other.branches.length &&
          hashCode == other.hashCode &&
          otherwise == other.otherwise &&
          const ListEquality<PiecewiseBranch>().equals(
            branches,
            other.branches,
          ));
}
