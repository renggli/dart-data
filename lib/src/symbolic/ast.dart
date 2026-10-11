import 'dart:math' as math;

/// Sealed base class representing an algebraic expression abstract syntax tree
/// (AST) node.
///
/// In algebra and calculus, an expression combines constants, variables,
/// operators, and mathematical functions (such as $2x + 1$ or $\sin(x)$).
/// Expressions can be constructed and evaluated numerically for specific
/// variable assignments, or manipulated symbolically for exact differentiation,
/// indefinite integration, equation solving, simplification, and JIT
/// compilation.
///
/// ```dart
/// final x = Variable('x');
/// final expr = x * x + 2 * x + 1;
/// final val = expr.evaluate({'x': 3.0}); // 3^2 + 2(3) + 1 = 16.0
/// ```
sealed class Expr {
  /// Abstract const constructor for expression nodes.
  const new();

  /// Whether this expression depends on [name].
  bool dependsOn(String name);

  /// All unique variable names appearing in this expression.
  Set<String> get freeVariables;

  /// Substitutes occurrences of [variable] with [replacement].
  Expr substitute(String variable, Expr replacement);

  /// Evaluates this expression using the variable values in [context].
  double evaluate(Map<String, double> context);

  /// Adds this expression to [other].
  Expr operator +(Object other) => Add(this, _wrap(other));

  /// Subtracts [other] from this expression.
  Expr operator -(Object other) => Sub(this, _wrap(other));

  /// Multiplies this expression by [other].
  Expr operator *(Object other) => Mul(this, _wrap(other));

  /// Divides this expression by [other].
  Expr operator /(Object other) => Div(this, _wrap(other));

  /// Negates this expression.
  Expr operator -() => Neg(this);

  /// Raises this expression to the power of [exponent].
  Expr pow(Object exponent) => Pow(this, _wrap(exponent));

  static Expr _wrap(Object value) =>
      value is Expr ? value : Constant((value as num).toDouble());
}

/// [Variable] node representing a named symbol.
final class Variable extends Expr {
  /// Creates a variable node with the given [name].
  const new(this.name);

  /// The symbol name of this variable (e.g. `'x'`).
  final String name;

  @override
  bool dependsOn(String name) => this.name == name;

  @override
  Set<String> get freeVariables => {name};

  @override
  Expr substitute(String variable, Expr replacement) =>
      name == variable ? replacement : this;

  @override
  double evaluate(Map<String, double> context) {
    final val = context[name];
    if (val == null) {
      throw ArgumentError('Variable "$name" not provided in context');
    }
    return val;
  }

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) => other is Variable && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

/// [Constant] numeric value node.
final class Constant extends Expr {
  /// Creates a constant numeric node with [value].
  const new(this.value);

  /// The numeric value of this constant.
  final double value;

  @override
  bool dependsOn(String name) => false;

  @override
  Set<String> get freeVariables => const {};

  @override
  Expr substitute(String variable, Expr replacement) => this;

  @override
  double evaluate(Map<String, double> context) => value;

  @override
  String toString() =>
      value % 1 == 0 ? value.toInt().toString() : value.toString();

  @override
  bool operator ==(Object other) => other is Constant && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// [Add] expression node: left + right.
final class Add extends Expr {
  /// Creates an addition node representing `[left] + [right]`.
  const new(this.left, this.right);

  /// The left operand.
  final Expr left;

  /// The right operand.
  final Expr right;

  @override
  bool dependsOn(String name) => left.dependsOn(name) || right.dependsOn(name);

  @override
  Set<String> get freeVariables => {
    ...left.freeVariables,
    ...right.freeVariables,
  };

  @override
  Expr substitute(String variable, Expr replacement) => Add(
    left.substitute(variable, replacement),
    right.substitute(variable, replacement),
  );

  @override
  double evaluate(Map<String, double> context) =>
      left.evaluate(context) + right.evaluate(context);

  @override
  String toString() => '($left + $right)';

  @override
  bool operator ==(Object other) =>
      other is Add && other.left == left && other.right == right;

  @override
  int get hashCode => Object.hash(left, right);
}

/// [Sub] expression node: left - right.
final class Sub extends Expr {
  /// Creates a subtraction node representing `[left] - [right]`.
  const new(this.left, this.right);

  /// The left operand.
  final Expr left;

  /// The right operand.
  final Expr right;

  @override
  bool dependsOn(String name) => left.dependsOn(name) || right.dependsOn(name);

  @override
  Set<String> get freeVariables => {
    ...left.freeVariables,
    ...right.freeVariables,
  };

  @override
  Expr substitute(String variable, Expr replacement) => Sub(
    left.substitute(variable, replacement),
    right.substitute(variable, replacement),
  );

  @override
  double evaluate(Map<String, double> context) =>
      left.evaluate(context) - right.evaluate(context);

  @override
  String toString() => '($left - $right)';

  @override
  bool operator ==(Object other) =>
      other is Sub && other.left == left && other.right == right;

  @override
  int get hashCode => Object.hash(left, right);
}

/// [Mul] expression node: left * right.
final class Mul extends Expr {
  /// Creates a multiplication node representing `[left] * [right]`.
  const new(this.left, this.right);

  /// The left operand.
  final Expr left;

  /// The right operand.
  final Expr right;

  @override
  bool dependsOn(String name) => left.dependsOn(name) || right.dependsOn(name);

  @override
  Set<String> get freeVariables => {
    ...left.freeVariables,
    ...right.freeVariables,
  };

  @override
  Expr substitute(String variable, Expr replacement) => Mul(
    left.substitute(variable, replacement),
    right.substitute(variable, replacement),
  );

  @override
  double evaluate(Map<String, double> context) =>
      left.evaluate(context) * right.evaluate(context);

  @override
  String toString() => '($left * $right)';

  @override
  bool operator ==(Object other) =>
      other is Mul && other.left == left && other.right == right;

  @override
  int get hashCode => Object.hash(left, right);
}

/// [Div] expression node: left / right.
final class Div extends Expr {
  /// Creates a division node representing `[left] / [right]`.
  const new(this.left, this.right);

  /// The numerator operand.
  final Expr left;

  /// The denominator operand.
  final Expr right;

  @override
  bool dependsOn(String name) => left.dependsOn(name) || right.dependsOn(name);

  @override
  Set<String> get freeVariables => {
    ...left.freeVariables,
    ...right.freeVariables,
  };

  @override
  Expr substitute(String variable, Expr replacement) => Div(
    left.substitute(variable, replacement),
    right.substitute(variable, replacement),
  );

  @override
  double evaluate(Map<String, double> context) =>
      left.evaluate(context) / right.evaluate(context);

  @override
  String toString() => '($left / $right)';

  @override
  bool operator ==(Object other) =>
      other is Div && other.left == left && other.right == right;

  @override
  int get hashCode => Object.hash(left, right);
}

/// [Pow] expression node: base ^ exponent.
final class Pow extends Expr {
  /// Creates an exponentiation node representing `[base] ^ [exponent]`.
  const new(this.base, this.exponent);

  /// The base expression.
  final Expr base;

  /// The exponent expression.
  final Expr exponent;

  @override
  bool dependsOn(String name) =>
      base.dependsOn(name) || exponent.dependsOn(name);

  @override
  Set<String> get freeVariables => {
    ...base.freeVariables,
    ...exponent.freeVariables,
  };

  @override
  Expr substitute(String variable, Expr replacement) => Pow(
    base.substitute(variable, replacement),
    exponent.substitute(variable, replacement),
  );

  @override
  double evaluate(Map<String, double> context) =>
      math.pow(base.evaluate(context), exponent.evaluate(context)).toDouble();

  @override
  String toString() => '($base ^ $exponent)';

  @override
  bool operator ==(Object other) =>
      other is Pow && other.base == base && other.exponent == exponent;

  @override
  int get hashCode => Object.hash(base, exponent);
}

/// [Neg] unary negation node: -expr.
final class Neg extends Expr {
  /// Creates a unary negation node representing `-[expr]`.
  const new(this.expr);

  /// The negated sub-expression.
  final Expr expr;

  @override
  bool dependsOn(String name) => expr.dependsOn(name);

  @override
  Set<String> get freeVariables => expr.freeVariables;

  @override
  Expr substitute(String variable, Expr replacement) =>
      Neg(expr.substitute(variable, replacement));

  @override
  double evaluate(Map<String, double> context) => -expr.evaluate(context);

  @override
  String toString() => '(-$expr)';

  @override
  bool operator ==(Object other) => other is Neg && other.expr == expr;

  @override
  int get hashCode => expr.hashCode;
}

/// [Sin] function node: sin(expr).
final class Sin extends Expr {
  /// Creates a sine function node representing `sin([expr])`.
  const new(this.expr);

  /// The argument sub-expression.
  final Expr expr;

  @override
  bool dependsOn(String name) => expr.dependsOn(name);

  @override
  Set<String> get freeVariables => expr.freeVariables;

  @override
  Expr substitute(String variable, Expr replacement) =>
      Sin(expr.substitute(variable, replacement));

  @override
  double evaluate(Map<String, double> context) =>
      math.sin(expr.evaluate(context));

  @override
  String toString() => 'sin($expr)';

  @override
  bool operator ==(Object other) => other is Sin && other.expr == expr;

  @override
  int get hashCode => expr.hashCode;
}

/// [Cos] function node: cos(expr).
final class Cos extends Expr {
  /// Creates a cosine function node representing `cos([expr])`.
  const new(this.expr);

  /// The argument sub-expression.
  final Expr expr;

  @override
  bool dependsOn(String name) => expr.dependsOn(name);

  @override
  Set<String> get freeVariables => expr.freeVariables;

  @override
  Expr substitute(String variable, Expr replacement) =>
      Cos(expr.substitute(variable, replacement));

  @override
  double evaluate(Map<String, double> context) =>
      math.cos(expr.evaluate(context));

  @override
  String toString() => 'cos($expr)';

  @override
  bool operator ==(Object other) => other is Cos && other.expr == expr;

  @override
  int get hashCode => expr.hashCode;
}

/// [Exp] function node: exp(expr).
final class Exp extends Expr {
  /// Creates an exponential function node representing `exp([expr])`.
  const new(this.expr);

  /// The exponent sub-expression.
  final Expr expr;

  @override
  bool dependsOn(String name) => expr.dependsOn(name);

  @override
  Set<String> get freeVariables => expr.freeVariables;

  @override
  Expr substitute(String variable, Expr replacement) =>
      Exp(expr.substitute(variable, replacement));

  @override
  double evaluate(Map<String, double> context) =>
      math.exp(expr.evaluate(context));

  @override
  String toString() => 'exp($expr)';

  @override
  bool operator ==(Object other) => other is Exp && other.expr == expr;

  @override
  int get hashCode => expr.hashCode;
}

/// [Ln] function node: ln(expr).
final class Ln extends Expr {
  /// Creates a natural logarithm function node representing `ln([expr])`.
  const new(this.expr);

  /// The argument sub-expression.
  final Expr expr;

  @override
  bool dependsOn(String name) => expr.dependsOn(name);

  @override
  Set<String> get freeVariables => expr.freeVariables;

  @override
  Expr substitute(String variable, Expr replacement) =>
      Ln(expr.substitute(variable, replacement));

  @override
  double evaluate(Map<String, double> context) =>
      math.log(expr.evaluate(context));

  @override
  String toString() => 'ln($expr)';

  @override
  bool operator ==(Object other) => other is Ln && other.expr == expr;

  @override
  int get hashCode => expr.hashCode;
}
