part of '../ast.dart';

/// Symbolic variable leaf node (e.g. $x$, $y$, $\theta$).
final class Variable extends Expr {
  /// Creates a symbolic variable with [name].
  const new(this.name);

  /// Identifier name of the variable.
  final String name;

  @override
  bool get isSimplified => true;

  @override
  double evaluate([Map<String, double> context = const {}]) {
    final val = context[name];
    if (val == null) {
      throw ArgumentError('Unbound variable "$name" in evaluation context');
    }
    return val;
  }

  @override
  Set<String> get freeVariables => {name};

  @override
  void collectFreeVariables(Set<String> target) {
    target.add(name);
  }

  @override
  bool dependsOn(String variable) => name == variable;

  @override
  Expr substitute(String variable, Expr replacement) =>
      name == variable ? replacement : this;

  @override
  Expr mapChildren(Expr Function(Expr) transform) => this;

  @override
  bool anyNode(bool Function(Expr) predicate) => predicate(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Variable && name == other.name);

  @override
  int get hashCode => Object.hash(Variable, name);
}
