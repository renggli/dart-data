import 'dart:math' as math;

import 'simplifier.dart';

/// Sealed base class representing an algebraic expression AST node.
sealed class Expr {
  const new();

  /// Whether this expression depends on [name].
  bool dependsOn(String name);

  /// All unique variable names appearing in this expression.
  Set<String> get freeVariables;

  /// Exact analytical symbolic derivative with respect to [variable].
  Expr diff(String variable);

  /// Canonically simplifies this expression.
  Expr simplify();

  /// Substitutes occurrences of [variable] with [replacement].
  Expr substitute(String variable, Expr replacement);

  /// Evaluates this expression using the variable values in [context].
  double evaluate(Map<String, double> context);

  /// Formats this expression into LaTeX math syntax.
  String toLatex();

  Expr operator +(Object other) => Add(this, _wrap(other));
  Expr operator -(Object other) => Sub(this, _wrap(other));
  Expr operator *(Object other) => Mul(this, _wrap(other));
  Expr operator /(Object other) => Div(this, _wrap(other));
  Expr operator -() => Neg(this);
  Expr pow(Object exponent) => Pow(this, _wrap(exponent));

  static Expr _wrap(Object value) =>
      value is Expr ? value : Constant((value as num).toDouble());
}

/// Variable node representing a named symbol.
final class Variable extends Expr {
  const new(this.name);

  final String name;

  @override
  bool dependsOn(String name) => this.name == name;

  @override
  Set<String> get freeVariables => {name};

  @override
  Expr diff(String variable) =>
      name == variable ? const Constant(1.0) : const Constant(0.0);

  @override
  Expr simplify() => this;

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
  String toLatex() => name;

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) => other is Variable && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

/// Constant numeric value node.
final class Constant extends Expr {
  const new(this.value);

  final double value;

  @override
  bool dependsOn(String name) => false;

  @override
  Set<String> get freeVariables => const {};

  @override
  Expr diff(String variable) => const Constant(0.0);

  @override
  Expr simplify() => this;

  @override
  Expr substitute(String variable, Expr replacement) => this;

  @override
  double evaluate(Map<String, double> context) => value;

  @override
  String toLatex() => toString();

  @override
  String toString() =>
      value % 1 == 0 ? value.toInt().toString() : value.toString();

  @override
  bool operator ==(Object other) => other is Constant && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// Addition node: left + right.
final class Add extends Expr {
  const new(this.left, this.right);

  final Expr left;
  final Expr right;

  @override
  bool dependsOn(String name) => left.dependsOn(name) || right.dependsOn(name);

  @override
  Set<String> get freeVariables => {
    ...left.freeVariables,
    ...right.freeVariables,
  };

  @override
  Expr diff(String variable) => Add(left.diff(variable), right.diff(variable));

  @override
  Expr simplify() => Simplifier.add(left.simplify(), right.simplify());

  @override
  Expr substitute(String variable, Expr replacement) => Add(
    left.substitute(variable, replacement),
    right.substitute(variable, replacement),
  );

  @override
  double evaluate(Map<String, double> context) =>
      left.evaluate(context) + right.evaluate(context);

  @override
  String toLatex() => '${left.toLatex()} + ${right.toLatex()}';

  @override
  String toString() => '($left + $right)';

  @override
  bool operator ==(Object other) =>
      other is Add && other.left == left && other.right == right;

  @override
  int get hashCode => Object.hash(left, right);
}

/// Subtraction node: left - right.
final class Sub extends Expr {
  const new(this.left, this.right);

  final Expr left;
  final Expr right;

  @override
  bool dependsOn(String name) => left.dependsOn(name) || right.dependsOn(name);

  @override
  Set<String> get freeVariables => {
    ...left.freeVariables,
    ...right.freeVariables,
  };

  @override
  Expr diff(String variable) => Sub(left.diff(variable), right.diff(variable));

  @override
  Expr simplify() => Simplifier.sub(left.simplify(), right.simplify());

  @override
  Expr substitute(String variable, Expr replacement) => Sub(
    left.substitute(variable, replacement),
    right.substitute(variable, replacement),
  );

  @override
  double evaluate(Map<String, double> context) =>
      left.evaluate(context) - right.evaluate(context);

  @override
  String toLatex() => '${left.toLatex()} - ${right.toLatex()}';

  @override
  String toString() => '($left - $right)';

  @override
  bool operator ==(Object other) =>
      other is Sub && other.left == left && other.right == right;

  @override
  int get hashCode => Object.hash(left, right);
}

/// Multiplication node: left * right.
final class Mul extends Expr {
  const new(this.left, this.right);

  final Expr left;
  final Expr right;

  @override
  bool dependsOn(String name) => left.dependsOn(name) || right.dependsOn(name);

  @override
  Set<String> get freeVariables => {
    ...left.freeVariables,
    ...right.freeVariables,
  };

  // Product rule: (u * v)' = u' * v + u * v'
  @override
  Expr diff(String variable) =>
      Add(Mul(left.diff(variable), right), Mul(left, right.diff(variable)));

  @override
  Expr simplify() => Simplifier.mul(left.simplify(), right.simplify());

  @override
  Expr substitute(String variable, Expr replacement) => Mul(
    left.substitute(variable, replacement),
    right.substitute(variable, replacement),
  );

  @override
  double evaluate(Map<String, double> context) =>
      left.evaluate(context) * right.evaluate(context);

  @override
  String toLatex() => '${left.toLatex()} \\cdot ${right.toLatex()}';

  @override
  String toString() => '($left * $right)';

  @override
  bool operator ==(Object other) =>
      other is Mul && other.left == left && other.right == right;

  @override
  int get hashCode => Object.hash(left, right);
}

/// Division node: left / right.
final class Div extends Expr {
  const new(this.left, this.right);

  final Expr left;
  final Expr right;

  @override
  bool dependsOn(String name) => left.dependsOn(name) || right.dependsOn(name);

  @override
  Set<String> get freeVariables => {
    ...left.freeVariables,
    ...right.freeVariables,
  };

  // Quotient rule: (u / v)' = (u' * v - u * v') / v^2
  @override
  Expr diff(String variable) => Div(
    Sub(Mul(left.diff(variable), right), Mul(left, right.diff(variable))),
    Pow(right, const Constant(2.0)),
  );

  @override
  Expr simplify() => Simplifier.div(left.simplify(), right.simplify());

  @override
  Expr substitute(String variable, Expr replacement) => Div(
    left.substitute(variable, replacement),
    right.substitute(variable, replacement),
  );

  @override
  double evaluate(Map<String, double> context) =>
      left.evaluate(context) / right.evaluate(context);

  @override
  String toLatex() => '\\frac{${left.toLatex()}}{${right.toLatex()}}';

  @override
  String toString() => '($left / $right)';

  @override
  bool operator ==(Object other) =>
      other is Div && other.left == left && other.right == right;

  @override
  int get hashCode => Object.hash(left, right);
}

/// Exponentiation node: base ^ exponent.
final class Pow extends Expr {
  const new(this.base, this.exponent);

  final Expr base;
  final Expr exponent;

  @override
  bool dependsOn(String name) =>
      base.dependsOn(name) || exponent.dependsOn(name);

  @override
  Set<String> get freeVariables => {
    ...base.freeVariables,
    ...exponent.freeVariables,
  };

  // Generalized power rule: d/dx(u^v) = u^v * (v' * ln(u) + v * u' / u)
  @override
  Expr diff(String variable) {
    final bDep = base.dependsOn(variable);
    final eDep = exponent.dependsOn(variable);
    if (!bDep && !eDep) return const Constant(0.0);
    if (bDep && !eDep) {
      return Mul(
        Mul(exponent, Pow(base, Sub(exponent, const Constant(1.0)))),
        base.diff(variable),
      );
    }
    if (!bDep && eDep) {
      return Mul(Mul(this, Ln(base)), exponent.diff(variable));
    }
    return Mul(
      this,
      Add(
        Mul(exponent.diff(variable), Ln(base)),
        Div(Mul(exponent, base.diff(variable)), base),
      ),
    );
  }

  @override
  Expr simplify() => Simplifier.pow(base.simplify(), exponent.simplify());

  @override
  Expr substitute(String variable, Expr replacement) => Pow(
    base.substitute(variable, replacement),
    exponent.substitute(variable, replacement),
  );

  @override
  double evaluate(Map<String, double> context) =>
      math.pow(base.evaluate(context), exponent.evaluate(context)).toDouble();

  @override
  String toLatex() => '{${base.toLatex()}}^{${exponent.toLatex()}}';

  @override
  String toString() => '($base ^ $exponent)';

  @override
  bool operator ==(Object other) =>
      other is Pow && other.base == base && other.exponent == exponent;

  @override
  int get hashCode => Object.hash(base, exponent);
}

/// Unary negation: -expr.
final class Neg extends Expr {
  const new(this.expr);

  final Expr expr;

  @override
  bool dependsOn(String name) => expr.dependsOn(name);

  @override
  Set<String> get freeVariables => expr.freeVariables;

  @override
  Expr diff(String variable) => Neg(expr.diff(variable));

  @override
  Expr simplify() => Simplifier.neg(expr.simplify());

  @override
  Expr substitute(String variable, Expr replacement) =>
      Neg(expr.substitute(variable, replacement));

  @override
  double evaluate(Map<String, double> context) => -expr.evaluate(context);

  @override
  String toLatex() => '-${expr.toLatex()}';

  @override
  String toString() => '(-$expr)';

  @override
  bool operator ==(Object other) => other is Neg && other.expr == expr;

  @override
  int get hashCode => expr.hashCode;
}

/// Sine function: sin(expr).
final class Sin extends Expr {
  const new(this.expr);

  final Expr expr;

  @override
  bool dependsOn(String name) => expr.dependsOn(name);

  @override
  Set<String> get freeVariables => expr.freeVariables;

  // d/dx(sin(u)) = cos(u) * u'
  @override
  Expr diff(String variable) => Mul(Cos(expr), expr.diff(variable));

  @override
  Expr simplify() => Simplifier.sin(expr.simplify());

  @override
  Expr substitute(String variable, Expr replacement) =>
      Sin(expr.substitute(variable, replacement));

  @override
  double evaluate(Map<String, double> context) =>
      math.sin(expr.evaluate(context));

  @override
  String toLatex() => '\\sin(${expr.toLatex()})';

  @override
  String toString() => 'sin($expr)';

  @override
  bool operator ==(Object other) => other is Sin && other.expr == expr;

  @override
  int get hashCode => expr.hashCode;
}

/// Cosine function: cos(expr).
final class Cos extends Expr {
  const new(this.expr);

  final Expr expr;

  @override
  bool dependsOn(String name) => expr.dependsOn(name);

  @override
  Set<String> get freeVariables => expr.freeVariables;

  // d/dx(cos(u)) = -sin(u) * u'
  @override
  Expr diff(String variable) => Mul(Neg(Sin(expr)), expr.diff(variable));

  @override
  Expr simplify() => Simplifier.cos(expr.simplify());

  @override
  Expr substitute(String variable, Expr replacement) =>
      Cos(expr.substitute(variable, replacement));

  @override
  double evaluate(Map<String, double> context) =>
      math.cos(expr.evaluate(context));

  @override
  String toLatex() => '\\cos(${expr.toLatex()})';

  @override
  String toString() => 'cos($expr)';

  @override
  bool operator ==(Object other) => other is Cos && other.expr == expr;

  @override
  int get hashCode => expr.hashCode;
}

/// Exponential function: exp(expr).
final class Exp extends Expr {
  const new(this.expr);

  final Expr expr;

  @override
  bool dependsOn(String name) => expr.dependsOn(name);

  @override
  Set<String> get freeVariables => expr.freeVariables;

  // d/dx(exp(u)) = exp(u) * u'
  @override
  Expr diff(String variable) => Mul(this, expr.diff(variable));

  @override
  Expr simplify() => Simplifier.exp(expr.simplify());

  @override
  Expr substitute(String variable, Expr replacement) =>
      Exp(expr.substitute(variable, replacement));

  @override
  double evaluate(Map<String, double> context) =>
      math.exp(expr.evaluate(context));

  @override
  String toLatex() => 'e^{${expr.toLatex()}}';

  @override
  String toString() => 'exp($expr)';

  @override
  bool operator ==(Object other) => other is Exp && other.expr == expr;

  @override
  int get hashCode => expr.hashCode;
}

/// Natural logarithm: ln(expr).
final class Ln extends Expr {
  const new(this.expr);

  final Expr expr;

  @override
  bool dependsOn(String name) => expr.dependsOn(name);

  @override
  Set<String> get freeVariables => expr.freeVariables;

  // d/dx(ln(u)) = u' / u
  @override
  Expr diff(String variable) => Div(expr.diff(variable), expr);

  @override
  Expr simplify() => Simplifier.ln(expr.simplify());

  @override
  Expr substitute(String variable, Expr replacement) =>
      Ln(expr.substitute(variable, replacement));

  @override
  double evaluate(Map<String, double> context) =>
      math.log(expr.evaluate(context));

  @override
  String toLatex() => '\\ln(${expr.toLatex()})';

  @override
  String toString() => 'ln($expr)';

  @override
  bool operator ==(Object other) => other is Ln && other.expr == expr;

  @override
  int get hashCode => expr.hashCode;
}
