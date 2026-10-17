import '../algebra/simplify.dart';
import '../ast.dart';

/// Linear form matching, affine decomposition, and scalar scaling extension on
/// [Expr].
extension LinearFormExtension on Expr {
  /// Decomposes this expression into affine form $a \cdot [variable] + b$,
  /// where $a$ and $b$ do not depend on [variable], and $a \ne 0$.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final lin = (x * 2 + 5).matchLinear('x');
  /// // lin?.a == RationalNumber(2), lin?.b == RationalNumber(5)
  /// ```
  ({Expr a, Expr b})? matchLinear(String variable) =>
      _matchLinear(this, variable);

  /// Tests whether this expression is an exact scalar multiple of [target] with
  /// respect to [variable].
  ///
  /// Returns scalar factor $k$ such that $\text{this} = k \cdot target$, where
  /// $k$ does not depend on [variable].
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final k = (x * 6).matchScalarMultiple(x * 2, 'x'); // RationalNumber(3)
  /// ```
  Expr? matchScalarMultiple(Expr target, String variable) =>
      _matchScalarMultiple(this, target, variable);

  /// Scales this expression by [factor] with constant folding and distribution.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final scaled = (x + 2).scale(RationalNumber(3)); // 3 * x + 6
  /// ```
  Expr scale(Expr factor) => _scaleExpr(this, factor);
}

({Expr a, Expr b})? _matchLinear(Expr expr, String variable) {
  expr = expr.simplify();
  if (!expr.dependsOn(variable)) {
    return null;
  }
  return switch (expr) {
    Variable(:final name) when name == variable => (
      a: IntegerNumber.one,
      b: IntegerNumber.zero,
    ),
    Mul(:final factors) => _matchLinearMul(factors, variable),
    Add(:final terms) => _matchLinearAdd(terms, variable),
    _ => null,
  };
}

({Expr a, Expr b})? _matchLinearMul(List<Expr> factors, String variable) {
  final constFactors = <Expr>[];
  final varFactors = <Expr>[];
  for (final f in factors) {
    if (f.dependsOn(variable)) {
      varFactors.add(f);
    } else {
      constFactors.add(f);
    }
  }
  if (varFactors.length != 1) return null;
  final sub = _matchLinear(varFactors.first, variable);
  if (sub == null) return null;
  final scale = constFactors.length == 1
      ? constFactors.first
      : Mul(constFactors);
  return _validLinear(
    (scale * sub.a).simplify(),
    (scale * sub.b).simplify(),
    variable,
  );
}

({Expr a, Expr b})? _matchLinearAdd(List<Expr> terms, String variable) {
  final aTerms = <Expr>[];
  final bTerms = <Expr>[];
  for (final t in terms) {
    if (!t.dependsOn(variable)) {
      bTerms.add(t);
    } else {
      final sub = _matchLinear(t, variable);
      if (sub == null) return null;
      aTerms.add(sub.a);
      if (!(sub.b is Number && (sub.b as Number).isZero)) {
        bTerms.add(sub.b);
      }
    }
  }
  final a = (aTerms.length == 1 ? aTerms.first : Add(aTerms)).simplify();
  final b = bTerms.isEmpty
      ? IntegerNumber.zero
      : (bTerms.length == 1 ? bTerms.first : Add(bTerms)).simplify();
  return _validLinear(a, b, variable);
}

Expr? _matchScalarMultiple(Expr expr, Expr target, String variable) {
  expr = expr.simplify();
  target = target.simplify();
  if (expr == target) {
    return IntegerNumber.one;
  }

  final (cExpr, vExpr) = _splitConstAndVar(expr, variable);
  final (cTarget, vTarget) = _splitConstAndVar(target, variable);
  if (vExpr == vTarget) {
    return (cExpr / cTarget).simplify();
  }

  final lin1 = _matchLinear(expr, variable);
  final lin2 = _matchLinear(target, variable);
  if (lin1 != null && lin2 != null) {
    final cross = (lin1.a * lin2.b - lin2.a * lin1.b).simplify();
    if (cross is Number && cross.isZero) {
      return (lin1.a / lin2.a).simplify();
    }
  }

  final quot = (expr / target).simplify();
  if (!quot.dependsOn(variable)) {
    return quot;
  }
  return null;
}

(Expr, Expr) _splitConstAndVar(Expr expr, String variable) {
  if (expr is Mul) {
    final consts = <Expr>[];
    final vars = <Expr>[];
    for (final f in expr.factors) {
      if (f.dependsOn(variable)) {
        vars.add(f);
      } else {
        consts.add(f);
      }
    }
    final c = consts.isEmpty
        ? IntegerNumber.one
        : consts.length == 1
        ? consts.first
        : Mul(consts).simplify();
    final v = vars.isEmpty
        ? IntegerNumber.one
        : vars.length == 1
        ? vars.first
        : Mul(vars).simplify();
    return (c, v);
  }
  if (!expr.dependsOn(variable)) {
    return (expr, IntegerNumber.one);
  }
  return (IntegerNumber.one, expr);
}

Expr _scaleExpr(Expr expr, Expr factor) {
  factor = factor.simplify();
  if (factor is Number) {
    if (factor.isZero) return IntegerNumber.zero;
    if (factor.isOne) return expr;
    if (factor.isNegativeOne) return (-expr).simplify();
  }
  expr = expr.simplify();
  if (expr is Add) {
    return Add(expr.terms.map((t) => _scaleExpr(t, factor)).toList())
        .simplify();
  }
  return (factor * expr).simplify();
}

({Expr a, Expr b})? _validLinear(Expr a, Expr b, String variable) {
  if (a.dependsOn(variable) || b.dependsOn(variable)) return null;
  if (a is Number && a.isZero) return null;
  return (a: a, b: b);
}
