part of '../ast.dart';

/// Mathematical domain assumption for a symbolic [Variable].
enum VariableDomain {
  /// Unspecified domain (no branch-cut or sign assumptions applied).
  unknown,

  /// Complex numbers $\mathbb{C}$.
  complex,

  /// Real numbers $\mathbb{R}$.
  real,

  /// Strictly positive real numbers $\mathbb{R}_{> 0}$.
  positive,

  /// Integers $\mathbb{Z}$.
  integer,
}

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
  void _collectFreeVariables(Set<String> target) {
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

/// Symbolic uninterpreted function application node (e.g. $f(x)$, $g(x, y)$).
final class VariableFunction extends Expr {
  /// Creates a symbolic function application $name(\text{arguments})$.
  new(this.name, Iterable<Expr> arguments, {this.isSimplified = false})
    : arguments = List<Expr>.unmodifiable(arguments);

  /// Identifier name of the function.
  final String name;

  /// Positional arguments passed to the function.
  final List<Expr> arguments;

  @override
  final bool isSimplified;

  @override
  double evaluate([
    Map<String, double> context = const {},
  ]) => throw UnsupportedError(
    'Cannot numerically evaluate symbolic function "$name(${arguments.join(', ')})"',
  );

  @override
  void _collectFreeVariables(Set<String> target) {
    for (final arg in arguments) {
      arg._collectFreeVariables(target);
    }
  }

  @override
  bool dependsOn(String variable) =>
      arguments.any((arg) => arg.dependsOn(variable));

  @override
  Expr substitute(String variable, Expr replacement) => VariableFunction(name, [
    for (final arg in arguments) arg.substitute(variable, replacement),
  ]);

  @override
  Expr mapChildren(Expr Function(Expr) transform) =>
      VariableFunction(name, [for (final arg in arguments) transform(arg)]);

  @override
  bool anyNode(bool Function(Expr) predicate) =>
      predicate(this) || arguments.any((arg) => arg.anyNode(predicate));

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! VariableFunction ||
        hashCode != other.hashCode ||
        name != other.name ||
        arguments.length != other.arguments.length) {
      return false;
    }
    for (var i = 0; i < arguments.length; i++) {
      if (arguments[i] != other.arguments[i]) return false;
    }
    return true;
  }

  @override
  late final int hashCode = Object.hash(
    VariableFunction,
    name,
    Object.hashAll(arguments),
  );
}
