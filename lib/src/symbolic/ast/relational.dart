part of '../ast.dart';

/// Comparison operator for a [Relational] expression.
enum RelOp {
  /// Strict less-than `left < right`.
  lessThan('<', '<', '&lt;'),

  /// Less-than-or-equal `left <= right`.
  lessEqual('<=', r'\le', '&#x2264;'),

  /// Strict greater-than `left > right`.
  greaterThan('>', '>', '&gt;'),

  /// Greater-than-or-equal `left >= right`.
  greaterEqual('>=', r'\ge', '&#x2265;'),

  /// Equality `left == right` (formatted `=` in LaTeX/MathML).
  equal('==', '=', '='),

  /// Inequality `left != right`.
  notEqual('!=', r'\ne', '&#x2260;');

  new(this.symbol, this.latexSymbol, this.mathMlSymbol);

  /// Plain-text operator symbol.
  final String symbol;

  /// LaTeX operator token.
  final String latexSymbol;

  /// MathML `<mo>` token.
  final String mathMlSymbol;
}

/// Relational comparison expression `left <op> right` used in [Piecewise]
/// branches, equations, and `Assumptions` constraints.
final class Relational extends Expr {
  /// Creates a relational comparison between [left] and [right].
  new(this.op, this.left, this.right);

  /// Creates `left < right`.
  factory lessThan(Expr left, Expr right) =>
      Relational(RelOp.lessThan, left, right);

  /// Creates `left <= right`.
  factory lessEqual(Expr left, Expr right) =>
      Relational(RelOp.lessEqual, left, right);

  /// Creates `left > right`.
  factory greaterThan(Expr left, Expr right) =>
      Relational(RelOp.greaterThan, left, right);

  /// Creates `left >= right`.
  factory greaterEqual(Expr left, Expr right) =>
      Relational(RelOp.greaterEqual, left, right);

  /// Creates `left == right`.
  factory equal(Expr left, Expr right) => Relational(RelOp.equal, left, right);

  /// Creates `left != right`.
  factory notEqual(Expr left, Expr right) =>
      Relational(RelOp.notEqual, left, right);

  /// Comparison operator.
  final RelOp op;

  /// Left-hand expression.
  final Expr left;

  /// Right-hand expression.
  final Expr right;

  @override
  int get flags =>
      ((left.flags | right.flags) & kStructuralFlagsMask) | kFlagHasRelational;

  @override
  int get nodeCount => 1 + left.nodeCount + right.nodeCount;

  @override
  int get structuralTag => 80 + op.index;

  @override
  late final int hashCode = Object.hash(Relational, op, left, right);

  @override
  late final Set<String> freeVariables = _unionFreeVariables(
    left.freeVariables,
    right.freeVariables,
  );

  @override
  Expr mapChildren(Expr Function(Expr) transform) {
    final nextLeft = transform(left);
    final nextRight = transform(right);
    return identical(nextLeft, left) && identical(nextRight, right)
        ? this
        : Relational(op, nextLeft, nextRight);
  }

  @override
  bool anyNode(bool Function(Expr) predicate) =>
      predicate(this) || left.anyNode(predicate) || right.anyNode(predicate);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Relational &&
          hashCode == other.hashCode &&
          op == other.op &&
          left == other.left &&
          right == other.right);
}

/// A guarded branch in a [Piecewise] expression.
typedef PiecewiseBranch = ({Relational relation, Expr expr});

/// Piecewise conditional expression node:
/// `cases(e_1 if c_1; e_2 if c_2; otherwise)`.
final class Piecewise extends Expr {
  /// Creates a piecewise expression from guarded [branches] and an optional
  /// fallback [otherwise] expression.
  new(List<PiecewiseBranch> branches, {this.otherwise})
    : branches = List<PiecewiseBranch>.unmodifiable(branches),
      flags = _computeFlags(branches, otherwise),
      nodeCount = _computeNodeCount(branches, otherwise);

  /// Ordered list of [PiecewiseBranch] entries evaluated top-to-bottom.
  final List<PiecewiseBranch> branches;

  /// Optional fallback expression evaluated when no branch condition holds.
  final Expr? otherwise;

  @override
  final int flags;

  @override
  final int nodeCount;

  @override
  int get structuralTag => 86;

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
      final nextRel = transform(branch.relation);
      if (nextRel is! Relational) {
        throw StateError(
          'Piecewise relation must transform to a Relational, got $nextRel',
        );
      }
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

  static int _computeFlags(List<PiecewiseBranch> branches, Expr? otherwise) {
    var f =
        kFlagHasRelational | ((otherwise?.flags ?? 0) & kStructuralFlagsMask);
    for (final (:relation, :expr) in branches) {
      f |= (relation.flags | expr.flags) & kStructuralFlagsMask;
    }
    return f;
  }

  static int _computeNodeCount(
    List<PiecewiseBranch> branches,
    Expr? otherwise,
  ) {
    var c = 1 + (otherwise?.nodeCount ?? 0);
    for (final (:relation, :expr) in branches) {
      c += relation.nodeCount + expr.nodeCount;
    }
    return c;
  }
}
