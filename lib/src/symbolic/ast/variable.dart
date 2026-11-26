part of '../ast.dart';

/// Mathematical domain assumption for a symbolic [Variable].
enum VariableDomain {
  /// Unspecified domain (no branch-cut or sign assumptions applied).
  unknown,

  /// Complex numbers `C`.
  complex,

  /// Real numbers `R`.
  real,

  /// Strictly positive real numbers `R_{> 0}`.
  positive,

  /// Integers `Z`.
  integer,
}

/// Symbolic variable leaf node (e.g. `x`, `y`, `theta`).
final class Variable extends Expr {
  /// Creates a symbolic variable with [name].
  const new(this.name);

  /// Identifier name of the variable.
  final String name;

  @override
  bool get isSimplified => true;

  @override
  Set<String> get freeVariables => Set.unmodifiable({name});

  @override
  bool dependsOn(String variable) => name == variable;

  @override
  Expr substitute(String variable, Expr replacement) =>
      name == variable ? replacement : this;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Variable && name == other.name);

  @override
  int get hashCode => Object.hash(Variable, name);
}

/// Symbolic uninterpreted function application node (e.g. `f(x)`, `g(x, y)`).
final class VariableFunction extends Expr {
  /// Creates a symbolic function application `name(arguments)`.
  new(this.name, Iterable<Expr> arguments, {this.isSimplified = false})
    : arguments = List<Expr>.unmodifiable(arguments);

  /// Identifier name of the function.
  final String name;

  /// Positional arguments passed to the function.
  final List<Expr> arguments;

  @override
  final bool isSimplified;

  @override
  late final Set<String> freeVariables = _unionAllFreeVariables(arguments);

  @override
  bool dependsOn(String variable) => freeVariables.contains(variable);

  @override
  Expr mapChildren(Expr Function(Expr) transform) {
    final mapped = _mapExprList(arguments, transform);
    return identical(mapped, arguments) ? this : VariableFunction(name, mapped);
  }

  @override
  bool anyNode(bool Function(Expr) predicate) =>
      predicate(this) || arguments.any((arg) => arg.anyNode(predicate));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VariableFunction &&
          name == other.name &&
          arguments.length == other.arguments.length &&
          hashCode == other.hashCode &&
          const ListEquality<Expr>().equals(arguments, other.arguments));

  @override
  late final int hashCode = Object.hash(
    VariableFunction,
    name,
    Object.hashAll(arguments),
  );
}
