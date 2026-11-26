part of '../ast.dart';

/// Symbolic sum of [body] evaluated over all complex roots (with multiplicity)
/// of [polynomial] with respect to [variable].
///
/// Represents `sum_{t : P(t) = 0} f(t)` as a first-class symbolic AST node,
/// commonly arising in Rothstein-Trager and algebraic logarithmic integration
/// when the denominator polynomial has degree `>= 3` or irreducible factors
/// without closed-form radical expressions.
///
/// The root variable [variable] is bound across both [polynomial] and [body]
/// and is excluded from [freeVariables]. Variable capture during substitution
/// alpha-renames [variable] automatically.
final class RootSum extends Expr {
  /// Creates a symbolic root-sum of [body] over all roots `t` of
  /// `polynomial(t) = 0`, where `t` is named [variable].
  new(this.polynomial, this.variable, this.body, {this.isSimplified = false});

  /// The defining polynomial `P(t)` whose roots index the sum.
  final Expr polynomial;

  /// The bound root variable name `t`.
  final String variable;

  /// The summand expression `f(t)` evaluated at each root of [polynomial].
  final Expr body;

  @override
  final bool isSimplified;

  @override
  late final int hashCode = Object.hash(RootSum, polynomial, variable, body);

  @override
  late final Set<String> freeVariables = Set.unmodifiable(
    {...polynomial.freeVariables, ...body.freeVariables}..remove(variable),
  );

  @override
  bool anyNode(bool Function(Expr) predicate) =>
      predicate(this) ||
      polynomial.anyNode(predicate) ||
      body.anyNode(predicate);

  @override
  Expr substitute(String variable, Expr replacement) {
    if (variable == this.variable) {
      return this;
    }
    var boundVar = this.variable;
    var nextPoly = polynomial;
    var nextBody = body;
    if (replacement.freeVariables.contains(boundVar)) {
      final used = <String>{
        ...nextPoly.freeVariables,
        ...nextBody.freeVariables,
        ...replacement.freeVariables,
      };
      final fresh = _freshBoundVariable(boundVar, used);
      final freshVar = Variable(fresh);
      nextPoly = nextPoly.substitute(boundVar, freshVar);
      nextBody = nextBody.substitute(boundVar, freshVar);
      boundVar = fresh;
    }
    return RootSum(
      nextPoly.substitute(variable, replacement),
      boundVar,
      nextBody.substitute(variable, replacement),
    );
  }

  @override
  Expr mapChildren(Expr Function(Expr) transform) {
    final nextPoly = transform(polynomial);
    final nextBody = transform(body);
    if (identical(nextPoly, polynomial) && identical(nextBody, body)) {
      return this;
    }
    return RootSum(nextPoly, variable, nextBody);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RootSum &&
          hashCode == other.hashCode &&
          variable == other.variable &&
          polynomial == other.polynomial &&
          body == other.body);
}
