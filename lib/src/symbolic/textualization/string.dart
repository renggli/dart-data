import '../ast.dart';

/// Formats the symbolic [expr] into a clean mathematical string representation
/// with minimal parentheses based on operator precedence and associativity.
String formatExpr(
  Expr expr, {
  int parentPrec = 0,
  bool isRight = false,
  bool isSubRight = false,
  bool isDivRight = false,
  bool isPowExp = false,
  bool isPowBase = false,
}) {
  final prec = precedence(expr);
  final needsParens = switch (expr) {
    _ when prec < parentPrec => true,
    Add() || Sub() when isSubRight => true,
    Mul() || Div() when isDivRight => true,
    Neg() when isPowBase || isPowExp || isDivRight => true,
    Constant(:final value, :final name)
        when (isPowBase || isPowExp || isDivRight) &&
            name == null &&
            value < 0 =>
      true,
    _ => false,
  };

  final inner = switch (expr) {
    Variable(:final name) => name,
    Constant(:final value, :final name) =>
      name ?? (value % 1 == 0 ? value.toInt().toString() : value.toString()),
    Sin(:final expr) => 'sin(${formatExpr(expr)})',
    Cos(:final expr) => 'cos(${formatExpr(expr)})',
    Exp(:final expr) => 'exp(${formatExpr(expr)})',
    Ln(:final expr) => 'ln(${formatExpr(expr)})',
    Neg(:final expr) => switch (expr) {
      Add() || Sub() || Neg() => '-(${formatExpr(expr)})',
      _ => '-${formatExpr(expr, parentPrec: 40)}',
    },
    Pow(:final base, :final exponent) =>
      '${formatExpr(base, parentPrec: 30, isPowBase: true)} ^ ${formatExpr(exponent, parentPrec: 30, isRight: true, isPowExp: true)}',
    Mul(:final left, :final right) =>
      '${formatExpr(left, parentPrec: 20)} * ${formatExpr(right, parentPrec: 20, isRight: true)}',
    Div(:final left, :final right) =>
      '${formatExpr(left, parentPrec: 20)} / ${formatExpr(right, parentPrec: 20, isRight: true, isDivRight: true)}',
    Add(:final left, :final right) =>
      '${formatExpr(left, parentPrec: 10)} + ${formatExpr(right, parentPrec: 10, isRight: true)}',
    Sub(:final left, :final right) =>
      '${formatExpr(left, parentPrec: 10)} - ${formatExpr(right, parentPrec: 10, isRight: true, isSubRight: true)}',
  };

  return needsParens ? '($inner)' : inner;
}

/// Returns the operator precedence for the given [expr].
int precedence(Expr expr) => switch (expr) {
  Add() || Sub() => 10,
  Mul() || Div() => 20,
  Pow() => 30,
  Neg() => 40,
  Constant(:final value, :final name) when name == null && value < 0 => 40,
  _ => 50,
};
