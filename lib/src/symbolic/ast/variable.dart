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
  int get flags => kFlagHasVariable | kFlagSimplified;

  @override
  int get nodeCount => 1;

  @override
  int get structuralTag => 2;

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
