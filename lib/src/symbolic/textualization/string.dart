import '../ast.dart';

/// Formats the symbolic [expr] into a clean mathematical string representation
/// with minimal parentheses based on operator precedence and associativity.
String formatExpr(Expr expr, [int parentPrec = 0]) {
  final prec = precedence(expr);
  final formatted = switch (expr) {
    Variable(:final name) => name,
    Constant(:final value, :final name) =>
      name ?? (value % 1 == 0 ? value.toInt().toString() : value.toString()),
    Sin(:final expr) => 'sin(${formatExpr(expr)})',
    Cos(:final expr) => 'cos(${formatExpr(expr)})',
    Exp(:final expr) => 'exp(${formatExpr(expr)})',
    Ln(:final expr) => 'ln(${formatExpr(expr)})',
    Neg(:final expr) => '-${formatExpr(expr, 4)}',
    Pow(:final base, :final exponent) =>
      '${formatExpr(base, 5)} ^ ${formatExpr(exponent, 4)}',
    Mul(:final left, :final right) =>
      '${formatExpr(left, 2)} * ${formatExpr(right, 2)}',
    Div(:final left, :final right) =>
      '${formatExpr(left, 2)} / ${formatExpr(right, 3)}',
    Add(:final left, :final right) =>
      '${formatExpr(left, 1)} + ${formatExpr(right, 1)}',
    Sub(:final left, :final right) =>
      '${formatExpr(left, 1)} - ${formatExpr(right, 2)}',
  };
  return prec < parentPrec ? '($formatted)' : formatted;
}

/// Returns the operator precedence for the given [expr].
int precedence(Expr expr) => switch (expr) {
  Add() || Sub() => 1,
  Mul() || Div() => 2,
  Neg() || Constant(value: < 0) => 3,
  Pow() => 4,
  _ => 5,
};
