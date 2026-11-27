part of '../ast.dart';

/// Unified function application AST node `spec(args...)`.
///
/// Covers all built-in trigonometric, hyperbolic, logarithmic, special, and
/// discrete functions via [FunctionSpec] as well as arbitrary uninterpreted
/// symbolic functions via [FunctionSpec.symbolic].
final class Call extends Expr {
  /// Creates a function call node applying [spec] to [args].
  new(this.spec, Iterable<Expr> args)
    : args = List<Expr>.unmodifiable(args),
      flags = _computeCallFlags(spec, args),
      nodeCount = _computeCallNodeCount(args);

  /// Creates an uninterpreted symbolic function call `name(args...)`.
  factory symbolic(String name, Iterable<Expr> args) =>
      Call(FunctionSpec.symbolic(name), args);

  /// Function descriptor identifying semantics, arity, evaluation, and formatting.
  final FunctionSpec spec;

  /// Ordered positional argument expressions.
  final List<Expr> args;

  @override
  final int flags;

  @override
  final int nodeCount;

  /// Dense [FunctionId] of [spec].
  FunctionId get id => spec.id;

  /// Canonical function name.
  String get name => spec.name;

  @override
  int get structuralTag => 3 + spec.id.index;

  @override
  late final Set<String> freeVariables = _unionAllFreeVariables(args);

  @override
  late final int hashCode = Object.hash(Call, spec, Object.hashAll(args));

  @override
  Expr mapChildren(Expr Function(Expr) transform) {
    final mapped = _mapExprList(args, transform);
    return identical(mapped, args) ? this : Call(spec, mapped);
  }

  @override
  bool anyNode(bool Function(Expr) predicate) {
    if (predicate(this)) return true;
    for (var i = 0; i < args.length; i++) {
      if (args[i].anyNode(predicate)) return true;
    }
    return false;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Call &&
          hashCode == other.hashCode &&
          args.length == other.args.length &&
          spec == other.spec &&
          const ListEquality<Expr>().equals(args, other.args));

  static int _computeCallFlags(FunctionSpec spec, Iterable<Expr> args) {
    var f = spec.isSpecial ? kFlagHasSpecial : 0;
    for (final a in args) {
      f |= a.flags;
    }
    return f;
  }

  static int _computeCallNodeCount(Iterable<Expr> args) {
    var c = 1;
    for (final a in args) {
      c += a.nodeCount;
    }
    return c;
  }
}
