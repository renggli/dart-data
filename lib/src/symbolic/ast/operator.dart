part of '../ast.dart';

/// Base class for unary expressions operating on a single child [expr].
sealed class UnaryExpr extends Expr {
  /// Creates a unary expression wrapping [expr].
  new(this.expr, {this.isSimplified = false});

  /// The inner operand expression.
  final Expr expr;

  @override
  final bool isSimplified;

  @override
  late final int hashCode = _computeHash();

  @override
  late final Set<String> freeVariables = expr.freeVariables;

  @override
  Expr mapChildren(Expr Function(Expr) transform) {
    final next = transform(expr);
    return identical(next, expr) ? this : _withExpr(next);
  }

  @override
  bool anyNode(bool Function(Expr) predicate) =>
      predicate(this) || expr.anyNode(predicate);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UnaryExpr &&
          runtimeType == other.runtimeType &&
          hashCode == other.hashCode &&
          _extraEquals(other) &&
          expr == other.expr);

  Expr _withExpr(Expr expr);

  bool _extraEquals(UnaryExpr other) => true;

  int _computeHash() => Object.hash(runtimeType, expr);
}

/// Base class for binary expressions operating on [left] and [right] children.
sealed class BinaryExpr extends Expr {
  /// Creates a binary expression with [left] and [right] operands.
  new(this.left, this.right, {this.isSimplified = false});

  /// The left-hand operand expression.
  final Expr left;

  /// The right-hand operand expression.
  final Expr right;

  @override
  final bool isSimplified;

  @override
  late final int hashCode = Object.hash(runtimeType, left, right);

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
        : _withOperands(nextLeft, nextRight);
  }

  @override
  bool anyNode(bool Function(Expr) predicate) =>
      predicate(this) || left.anyNode(predicate) || right.anyNode(predicate);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BinaryExpr &&
          runtimeType == other.runtimeType &&
          hashCode == other.hashCode &&
          left == other.left &&
          right == other.right);

  Expr _withOperands(Expr left, Expr right);
}

/// N-ary addition node: $\sum_{i} t_i$.
final class Add extends Expr {
  /// Creates an N-ary sum of [terms].
  new(List<Expr> terms, {this.isSimplified = false})
    : terms = List.unmodifiable(terms);

  /// The ordered list of additive terms.
  final List<Expr> terms;

  @override
  final bool isSimplified;

  @override
  late final int hashCode = Object.hash(Add, Object.hashAll(terms));

  @override
  late final Set<String> freeVariables = _unionAllFreeVariables(terms);

  @override
  Expr mapChildren(Expr Function(Expr) transform) {
    final mapped = _mapExprList(terms, transform);
    return identical(mapped, terms) ? this : Add(mapped);
  }

  @override
  bool anyNode(bool Function(Expr) predicate) {
    if (predicate(this)) return true;
    for (var i = 0; i < terms.length; i++) {
      if (terms[i].anyNode(predicate)) return true;
    }
    return false;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Add ||
        terms.length != other.terms.length ||
        hashCode != other.hashCode) {
      return false;
    }
    for (var i = 0; i < terms.length; i++) {
      if (terms[i] != other.terms[i]) return false;
    }
    return true;
  }
}

/// N-ary multiplication node: $\prod_{i} f_i$.
final class Mul extends Expr {
  /// Creates an N-ary product of [factors].
  new(List<Expr> factors, {this.isSimplified = false})
    : factors = List.unmodifiable(factors);

  /// The ordered list of multiplicative factors.
  final List<Expr> factors;

  @override
  final bool isSimplified;

  @override
  late final int hashCode = Object.hash(Mul, Object.hashAll(factors));

  @override
  late final Set<String> freeVariables = _unionAllFreeVariables(factors);

  @override
  Expr mapChildren(Expr Function(Expr) transform) {
    final mapped = _mapExprList(factors, transform);
    return identical(mapped, factors) ? this : Mul(mapped);
  }

  @override
  bool anyNode(bool Function(Expr) predicate) {
    if (predicate(this)) return true;
    for (var i = 0; i < factors.length; i++) {
      if (factors[i].anyNode(predicate)) return true;
    }
    return false;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Mul ||
        factors.length != other.factors.length ||
        hashCode != other.hashCode) {
      return false;
    }
    for (var i = 0; i < factors.length; i++) {
      if (factors[i] != other.factors[i]) return false;
    }
    return true;
  }
}

/// Exponentiation node: $\text{base}^{\text{exponent}}$.
final class Pow extends BinaryExpr {
  /// Creates an exponentiation node $\text{base}^{\text{exponent}}$.
  new(super.base, super.exponent, {super.isSimplified = false});

  /// Base of the power expression.
  Expr get base => left;

  /// Exponent of the power expression.
  Expr get exponent => right;

  @override
  Expr _withOperands(Expr left, Expr right) => Pow(left, right);
}

Set<String> _unionFreeVariables(Set<String> a, Set<String> b) {
  if (a.isEmpty) return b.isEmpty ? const <String>{} : b;
  if (b.isEmpty) return a;
  return Set.unmodifiable({...a, ...b});
}

Set<String> _unionAllFreeVariables(List<Expr> nodes) {
  Set<String>? single;
  Set<String>? merged;
  for (var i = 0; i < nodes.length; i++) {
    final vars = nodes[i].freeVariables;
    if (vars.isEmpty) continue;
    if (merged != null) {
      merged.addAll(vars);
    } else if (single == null) {
      single = vars;
    } else if (!identical(single, vars)) {
      merged = {...single, ...vars};
    }
  }
  if (merged != null) return Set.unmodifiable(merged);
  return single ?? const <String>{};
}

List<Expr> _mapExprList(List<Expr> items, Expr Function(Expr) transform) {
  List<Expr>? updated;
  for (var i = 0; i < items.length; i++) {
    final original = items[i];
    final next = transform(original);
    if (updated != null) {
      updated[i] = next;
    } else if (!identical(next, original)) {
      updated = List<Expr>.of(items);
      updated[i] = next;
    }
  }
  return updated ?? items;
}
