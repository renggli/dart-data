part of '../ast.dart';

/// Sealed base class representing a unary operation AST node with a single operand.
///
/// Encapsulates common structural traversal, variable dependency collection,
/// and value hashing across unary expressions such as negation ([Neg]) and
/// transcendental functions ([Sin], [Cos], [Exp], [Ln]).
sealed class UnaryExpr extends Expr {
  /// Abstract const constructor for unary expression nodes.
  const new(this.expr);

  /// The sub-expression argument of this unary operation.
  final Expr expr;

  @override
  bool dependsOn(String name) => expr.dependsOn(name);

  @override
  void collectFreeVariables(Set<String> target) =>
      expr.collectFreeVariables(target);

  /// Reconstructs this unary node with [newExpr].
  UnaryExpr copyWith(Expr newExpr);

  @override
  Expr mapChildren(Expr Function(Expr child) transform) {
    final next = transform(expr);
    return identical(next, expr) ? this : copyWith(next);
  }

  @override
  bool anyNode(bool Function(Expr node) predicate) =>
      predicate(this) || expr.anyNode(predicate);

  @override
  Expr substitute(String variable, Expr replacement) =>
      mapChildren((child) => child.substitute(variable, replacement));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UnaryExpr &&
          other.runtimeType == runtimeType &&
          other.expr == expr);

  @override
  int get hashCode => Object.hash(runtimeType, expr);
}

/// Sealed base class representing a binary operation AST node with two operands.
///
/// Encapsulates common structural traversal, variable dependency collection,
/// and value hashing across binary expressions such as arithmetic operations
/// ([Add], [Sub], [Mul], [Div]) and exponentiation ([Pow]).
sealed class BinaryExpr extends Expr {
  /// Abstract const constructor for binary expression nodes.
  const new(this.left, this.right);

  /// The left operand.
  final Expr left;

  /// The right operand.
  final Expr right;

  @override
  bool dependsOn(String name) => left.dependsOn(name) || right.dependsOn(name);

  @override
  void collectFreeVariables(Set<String> target) {
    left.collectFreeVariables(target);
    right.collectFreeVariables(target);
  }

  /// Reconstructs this binary node with [newLeft] and [newRight].
  BinaryExpr copyWith(Expr newLeft, Expr newRight);

  @override
  Expr mapChildren(Expr Function(Expr child) transform) {
    final nextLeft = transform(left);
    final nextRight = transform(right);
    return identical(nextLeft, left) && identical(nextRight, right)
        ? this
        : copyWith(nextLeft, nextRight);
  }

  @override
  bool anyNode(bool Function(Expr node) predicate) =>
      predicate(this) || left.anyNode(predicate) || right.anyNode(predicate);

  @override
  Expr substitute(String variable, Expr replacement) =>
      mapChildren((child) => child.substitute(variable, replacement));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BinaryExpr &&
          other.runtimeType == runtimeType &&
          other.left == left &&
          other.right == right);

  @override
  int get hashCode => Object.hash(runtimeType, left, right);
}

/// An addition binary expression node representing $left + right$.
///
/// ```dart
/// final sum = Add(Variable('x'), RationalNumber(1));
/// ```
final class Add extends BinaryExpr {
  /// Creates an addition node representing `[left] + [right]`.
  const new(super.left, super.right);

  @override
  Add copyWith(Expr newLeft, Expr newRight) => Add(newLeft, newRight);

  @override
  double evaluate(Map<String, double> context) =>
      left.evaluate(context) + right.evaluate(context);
}

/// A subtraction binary expression node representing $left - right$.
///
/// ```dart
/// final diff = Sub(Variable('x'), RationalNumber(1));
/// ```
final class Sub extends BinaryExpr {
  /// Creates a subtraction node representing `[left] - [right]`.
  const new(super.left, super.right);

  @override
  Sub copyWith(Expr newLeft, Expr newRight) => Sub(newLeft, newRight);

  @override
  double evaluate(Map<String, double> context) =>
      left.evaluate(context) - right.evaluate(context);
}

/// A multiplication binary expression node representing $left \times right$.
///
/// ```dart
/// final product = Mul(RationalNumber(2), Variable('x'));
/// ```
final class Mul extends BinaryExpr {
  /// Creates a multiplication node representing `[left] * [right]`.
  const new(super.left, super.right);

  @override
  Mul copyWith(Expr newLeft, Expr newRight) => Mul(newLeft, newRight);

  @override
  double evaluate(Map<String, double> context) =>
      left.evaluate(context) * right.evaluate(context);
}

/// A division binary expression node representing $left / right$.
///
/// ```dart
/// final quotient = Div(Variable('x'), RationalNumber(2));
/// ```
final class Div extends BinaryExpr {
  /// Creates a division node representing `[left] / [right]`.
  const new(super.left, super.right);

  @override
  Div copyWith(Expr newLeft, Expr newRight) => Div(newLeft, newRight);

  @override
  double evaluate(Map<String, double> context) =>
      left.evaluate(context) / right.evaluate(context);
}

/// An exponentiation binary expression node representing $base^{exponent}$.
///
/// ```dart
/// final power = Pow(Variable('x'), RationalNumber(2));
/// ```
final class Pow extends BinaryExpr {
  /// Creates an exponentiation node representing `[base] ^ [exponent]`.
  const new(super.left, super.right);

  /// The base expression.
  Expr get base => left;

  /// The exponent expression.
  Expr get exponent => right;

  @override
  Pow copyWith(Expr newLeft, Expr newRight) => Pow(newLeft, newRight);

  @override
  double evaluate(Map<String, double> context) {
    final bVal = left.evaluate(context);
    if (right case RationalNumber(:final numerator, :final denominator)) {
      if (numerator == 1 && denominator == 2) {
        return math.sqrt(bVal);
      }
      if (bVal < 0 && denominator > 1 && denominator.isOdd) {
        final mag = math.pow(-bVal, numerator / denominator).toDouble();
        return numerator.isOdd ? -mag : mag;
      }
    }
    final eVal = right.evaluate(context);
    if (eVal == 0.5) return math.sqrt(bVal);
    return math.pow(bVal, eVal).toDouble();
  }
}

/// A unary negation expression node representing $-expr$.
///
/// ```dart
/// final neg = Neg(Variable('x'));
/// ```
final class Neg extends UnaryExpr {
  /// Creates a unary negation node representing `-[expr]`.
  const new(super.expr);

  @override
  Neg copyWith(Expr newExpr) => Neg(newExpr);

  @override
  double evaluate(Map<String, double> context) => -expr.evaluate(context);
}
