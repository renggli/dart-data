import '../ast.dart';
import '../simplifier.dart';

/// Linear form matching, affine decomposition, and scalar scaling extension on [Expr].
extension LinearFormExtension on Expr {
  /// Decomposes this expression into affine form $a \cdot [variable] + b$,
  /// where $a$ and $b$ do not depend on [variable], and $a \ne 0$.
  ({Expr a, Expr b})? matchLinear(String variable) =>
      _matchLinear(this, variable);

  /// Tests whether this expression is an exact scalar multiple of [target] with respect to [variable].
  ///
  /// Returns scalar factor $k$ such that $\text{this} = k \cdot target$, where $k$ does not depend on [variable].
  Expr? matchScalarMultiple(Expr target, String variable) =>
      _matchScalarMultiple(this, target, variable);

  /// Scales this expression by [factor] with constant folding and distribution.
  Expr scale(Expr factor) => _scaleExpr(this, factor);
}

({Expr a, Expr b})? _matchLinear(Expr expr, String variable) {
  expr = expr.simplify();
  if (!expr.dependsOn(variable)) {
    return null;
  }
  return switch (expr) {
    Variable(:final name) when name == variable => (
      a: const Constant(1.0),
      b: const Constant(0.0),
    ),
    Neg(:final expr) => _matchLinearNeg(expr, variable),
    Mul(:final left, :final right) => _matchLinearMul(left, right, variable),
    Div(:final left, :final right) when !right.dependsOn(variable) =>
      _matchLinearDiv(left, right, variable),
    Add(:final left, :final right) => _matchLinearAdd(left, right, variable),
    Sub(:final left, :final right) => _matchLinearSub(left, right, variable),
    _ => null,
  };
}

Expr? _matchScalarMultiple(Expr expr, Expr target, String variable) {
  expr = expr.simplify();
  target = target.simplify();
  if (expr == target) {
    return const Constant(1.0);
  }
  return switch ((expr, target)) {
    (Neg(:final expr), Neg(expr: final targetExpr)) => _matchScalarMultiple(
      expr,
      targetExpr,
      variable,
    ),
    (Neg(:final expr), _) => () {
      final k = _matchScalarMultiple(expr, target, variable);
      return k != null ? Neg(k).simplify() : null;
    }(),
    (_, Neg(expr: final targetExpr)) => () {
      final k = _matchScalarMultiple(expr, targetExpr, variable);
      return k != null ? Neg(k).simplify() : null;
    }(),
    (Div(:final left, :final right), _) when !right.dependsOn(variable) => () {
      final k = _matchScalarMultiple(left, target, variable);
      return k != null ? Div(k, right).simplify() : null;
    }(),
    (_, Div(:final left, :final right)) when !right.dependsOn(variable) => () {
      final k = _matchScalarMultiple(expr, left, variable);
      return k != null ? Mul(k, right).simplify() : null;
    }(),
    (Mul(:final left, :final right), _) when !left.dependsOn(variable) => () {
      final k = _matchScalarMultiple(right, target, variable);
      return k != null ? Mul(left, k).simplify() : null;
    }(),
    (Mul(:final left, :final right), _) when !right.dependsOn(variable) => () {
      final k = _matchScalarMultiple(left, target, variable);
      return k != null ? Mul(right, k).simplify() : null;
    }(),
    (_, Mul(:final left, :final right)) when !left.dependsOn(variable) => () {
      final k = _matchScalarMultiple(expr, right, variable);
      return k != null ? Div(k, left).simplify() : null;
    }(),
    (_, Mul(:final left, :final right)) when !right.dependsOn(variable) => () {
      final k = _matchScalarMultiple(expr, left, variable);
      return k != null ? Div(k, right).simplify() : null;
    }(),
    _ => _matchLinearOrQuotient(expr, target, variable),
  };
}

Expr _scaleExpr(Expr expr, Expr factor) {
  factor = factor.simplify();
  if (factor is Constant) {
    if (factor.value == 0.0) return const Constant(0.0);
    if (factor.value == 1.0) return expr;
    if (factor.value == -1.0) return Neg(expr).simplify();
  }
  expr = expr.simplify();
  if (expr is Constant) {
    return Mul(factor, expr).simplify();
  }
  if (factor is Constant) {
    final k = factor.value;
    return switch (expr) {
      Neg(:final expr) => _scaleExpr(expr, Constant(-k)),
      Div(:final left, right: Constant(value: final c)) => _scaleDivRight(
        left,
        k,
        c,
      ),
      Div(left: Constant(value: final c), :final right) => () {
        final newK = k * c;
        if (newK == 1.0) return Div(const Constant(1.0), right);
        return Div(Constant(newK), right).simplify();
      }(),
      Mul(left: Constant(value: final c), :final right) => _scaleMulConstant(
        right,
        k,
        c,
      ),
      Mul(:final left, right: Constant(value: final c)) => _scaleMulConstant(
        left,
        k,
        c,
      ),
      Add(:final left, :final right) => Add(
        _scaleExpr(left, factor),
        _scaleExpr(right, factor),
      ).simplify(),
      Sub(:final left, :final right) => Sub(
        _scaleExpr(left, factor),
        _scaleExpr(right, factor),
      ).simplify(),
      _ => () {
        if (k % 1 == 0) return Mul(Constant(k), expr);
        final invK = 1.0 / k;
        if (invK % 1 == 0 && invK.abs() >= 1) return Div(expr, Constant(invK));
        return Mul(factor, expr).simplify();
      }(),
    };
  }
  return Mul(factor, expr).simplify();
}

({Expr a, Expr b})? _matchLinearNeg(Expr inner, String variable) {
  final sub = _matchLinear(inner, variable);
  if (sub == null) return null;
  return _validLinear(Neg(sub.a).simplify(), Neg(sub.b).simplify(), variable);
}

({Expr a, Expr b})? _matchLinearMul(Expr left, Expr right, String variable) {
  if (!left.dependsOn(variable)) {
    final sub = _matchLinear(right, variable);
    if (sub == null) return null;
    return _validLinear(
      Mul(left, sub.a).simplify(),
      Mul(left, sub.b).simplify(),
      variable,
    );
  }
  if (!right.dependsOn(variable)) {
    final sub = _matchLinear(left, variable);
    if (sub == null) return null;
    return _validLinear(
      Mul(right, sub.a).simplify(),
      Mul(right, sub.b).simplify(),
      variable,
    );
  }
  return null;
}

({Expr a, Expr b})? _matchLinearDiv(Expr left, Expr right, String variable) {
  final sub = _matchLinear(left, variable);
  if (sub == null) return null;
  return _validLinear(
    Div(sub.a, right).simplify(),
    Div(sub.b, right).simplify(),
    variable,
  );
}

({Expr a, Expr b})? _matchLinearAdd(Expr left, Expr right, String variable) {
  final leftDep = left.dependsOn(variable);
  final rightDep = right.dependsOn(variable);
  if (leftDep && !rightDep) {
    final sub = _matchLinear(left, variable);
    if (sub == null) return null;
    return _validLinear(sub.a, Add(sub.b, right).simplify(), variable);
  }
  if (!leftDep && rightDep) {
    final sub = _matchLinear(right, variable);
    if (sub == null) return null;
    return _validLinear(sub.a, Add(left, sub.b).simplify(), variable);
  }
  if (leftDep && rightDep) {
    final subL = _matchLinear(left, variable);
    final subR = _matchLinear(right, variable);
    if (subL == null || subR == null) return null;
    return _validLinear(
      Add(subL.a, subR.a).simplify(),
      Add(subL.b, subR.b).simplify(),
      variable,
    );
  }
  return null;
}

({Expr a, Expr b})? _matchLinearSub(Expr left, Expr right, String variable) {
  final leftDep = left.dependsOn(variable);
  final rightDep = right.dependsOn(variable);
  if (leftDep && !rightDep) {
    final sub = _matchLinear(left, variable);
    if (sub == null) return null;
    return _validLinear(sub.a, Sub(sub.b, right).simplify(), variable);
  }
  if (!leftDep && rightDep) {
    final sub = _matchLinear(right, variable);
    if (sub == null) return null;
    return _validLinear(
      Neg(sub.a).simplify(),
      Sub(left, sub.b).simplify(),
      variable,
    );
  }
  if (leftDep && rightDep) {
    final subL = _matchLinear(left, variable);
    final subR = _matchLinear(right, variable);
    if (subL == null || subR == null) return null;
    return _validLinear(
      Sub(subL.a, subR.a).simplify(),
      Sub(subL.b, subR.b).simplify(),
      variable,
    );
  }
  return null;
}

Expr? _matchLinearOrQuotient(Expr expr, Expr target, String variable) {
  final lin1 = _matchLinear(expr, variable);
  final lin2 = _matchLinear(target, variable);
  if (lin1 != null && lin2 != null) {
    final cross = Sub(Mul(lin1.a, lin2.b), Mul(lin2.a, lin1.b)).simplify();
    if (cross is Constant && cross.value == 0.0) {
      return Div(lin1.a, lin2.a).simplify();
    }
  }
  final quot = Div(expr, target).simplify();
  if (!quot.dependsOn(variable)) {
    return quot;
  }
  return null;
}

Expr _scaleDivRight(Expr left, double k, double c) {
  final newK = k / c;
  if (newK == 1.0) return left;
  if (newK == -1.0) return Neg(left).simplify();
  if (newK % 1 == 0) return Mul(Constant(newK), left);
  final invK = 1.0 / newK;
  if (invK % 1 == 0 && invK.abs() >= 1) return Div(left, Constant(invK));
  return Mul(Constant(newK), left);
}

Expr _scaleMulConstant(Expr other, double k, double c) {
  final newK = k * c;
  if (newK == 1.0) return other;
  if (newK == -1.0) return Neg(other).simplify();
  if (newK % 1 == 0) return Mul(Constant(newK), other);
  final invK = 1.0 / newK;
  if (invK % 1 == 0 && invK.abs() >= 1) return Div(other, Constant(invK));
  return Mul(Constant(newK), other);
}

({Expr a, Expr b})? _validLinear(Expr a, Expr b, String variable) {
  if (a.dependsOn(variable) || b.dependsOn(variable)) return null;
  if (a is Constant && a.value == 0.0) return null;
  return (a: a, b: b);
}
