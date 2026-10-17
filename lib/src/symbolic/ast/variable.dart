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
  /// Creates a symbolic variable with [name] and optional [domain] assumption.
  const new(this.name, {this.domain = VariableDomain.unknown});

  /// Identifier name of the variable.
  final String name;

  /// Assumed mathematical domain of the variable.
  final VariableDomain domain;

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
      identical(this, other) ||
      (other is Variable && name == other.name && domain == other.domain);

  @override
  int get hashCode => Object.hash(Variable, name, domain);
}
