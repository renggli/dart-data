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
  void _collectFreeVariables(Set<String> target) {
    expr._collectFreeVariables(target);
  }

  @override
  bool dependsOn(String variable) => expr.dependsOn(variable);

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
  void _collectFreeVariables(Set<String> target) {
    left._collectFreeVariables(target);
    right._collectFreeVariables(target);
  }

  @override
  bool dependsOn(String variable) =>
      left.dependsOn(variable) || right.dependsOn(variable);

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
  void _collectFreeVariables(Set<String> target) {
    for (var i = 0; i < terms.length; i++) {
      terms[i]._collectFreeVariables(target);
    }
  }

  @override
  bool dependsOn(String variable) {
    for (var i = 0; i < terms.length; i++) {
      if (terms[i].dependsOn(variable)) return true;
    }
    return false;
  }

  @override
  Expr substitute(String variable, Expr replacement) =>
      Add([for (final t in terms) t.substitute(variable, replacement)]);

  @override
  Expr mapChildren(Expr Function(Expr) transform) =>
      Add([for (final t in terms) transform(t)]);

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
  void _collectFreeVariables(Set<String> target) {
    for (var i = 0; i < factors.length; i++) {
      factors[i]._collectFreeVariables(target);
    }
  }

  @override
  bool dependsOn(String variable) {
    for (var i = 0; i < factors.length; i++) {
      if (factors[i].dependsOn(variable)) return true;
    }
    return false;
  }

  @override
  Expr substitute(String variable, Expr replacement) =>
      Mul([for (final f in factors) f.substitute(variable, replacement)]);

  @override
  Expr mapChildren(Expr Function(Expr) transform) =>
      Mul([for (final f in factors) transform(f)]);

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
  Expr substitute(String variable, Expr replacement) => Pow(
    base.substitute(variable, replacement),
    exponent.substitute(variable, replacement),
  );

  @override
  Expr mapChildren(Expr Function(Expr) transform) =>
      Pow(transform(base), transform(exponent));
}
