part of '../ast.dart';

/// A named symbolic variable in an algebraic expression.
///
/// Variables act as placeholders for unknown quantities or coordinates (e.g.
/// `'x'`, `'y'`). During evaluation, their values are supplied via a context map.
///
/// ```dart
/// final x = Variable('x');
/// final expr = x * x + 1;
/// print(expr.evaluate({'x': 3.0})); // 10.0
/// ```
final class Variable extends Expr {
  /// Creates a variable node with the given [name].
  const new(this.name);

  /// The symbol name of this variable (e.g. `'x'`).
  final String name;

  @override
  bool dependsOn(String name) => this.name == name;

  @override
  void collectFreeVariables(Set<String> target) => target.add(name);

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
