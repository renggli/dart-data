import '../ast.dart';

/// Formats the symbolic [expr] into a clean mathematical string representation
/// with minimal parentheses based on operator precedence and associativity.
///
/// ```dart
/// final x = Variable('x');
/// final str = formatExpr(x * x + 1); // 'x * x + 1'
/// ```
String formatExpr(Expr expr, [int parentPrec = 0]) {
  final prec = precedence(expr);
  final formatted = switch (expr) {
    Variable(:final name) => name,
    ComplexNumber() => expr.toString(),
    ConstantNumber(:final name) => name,
    RationalNumber(:final numerator, :final denominator) =>
      denominator == 1 ? '$numerator' : '$numerator/$denominator',
    RealNumber(:final value) => '$value',
    Sin(:final expr) => 'sin(${formatExpr(expr)})',
    Cos(:final expr) => 'cos(${formatExpr(expr)})',
    Tan(:final expr) => 'tan(${formatExpr(expr)})',
    Asin(:final expr) => 'asin(${formatExpr(expr)})',
    Acos(:final expr) => 'acos(${formatExpr(expr)})',
    Atan(:final expr) => 'atan(${formatExpr(expr)})',
    Sinh(:final expr) => 'sinh(${formatExpr(expr)})',
    Cosh(:final expr) => 'cosh(${formatExpr(expr)})',
    Tanh(:final expr) => 'tanh(${formatExpr(expr)})',
    Abs(:final expr) => 'abs(${formatExpr(expr)})',
    Exp(:final expr) => 'exp(${formatExpr(expr)})',
    Ln(:final expr) => 'ln(${formatExpr(expr)})',
    Neg(:final expr) => '-${formatExpr(expr, 4)}',
    Pow(:final base, :final exponent) =>
      exponent is RationalNumber &&
              exponent.numerator == 1 &&
              exponent.denominator == 2
          ? 'sqrt(${formatExpr(base)})'
          : '${formatExpr(base, 5)} ^ ${formatExpr(exponent, 4)}',
    Mul(:final left, :final right) =>
      '${formatExpr(left, 2)} * ${formatExpr(right, 2)}',
    Div(:final left, :final right) =>
      '${formatExpr(left, 2)} / ${formatExpr(right, 3)}',
    Add(:final left, :final right) =>
      '${formatExpr(left, 1)} + ${formatExpr(right, 1)}',
    Sub(:final left, :final right) =>
      '${formatExpr(left, 1)} - ${formatExpr(right, 2)}',
    OrderTerm(:final variable, :final order, :final point) => _formatOrderTerm(
      variable,
      order,
      point,
    ),
    LambertW(:final expr, :final branch) =>
      branch == 0
          ? 'LambertW(${formatExpr(expr)})'
          : 'LambertW(${formatExpr(expr)}, $branch)',
    Erf(:final expr) => 'erf(${formatExpr(expr)})',
    Erfc(:final expr) => 'erfc(${formatExpr(expr)})',
    Gamma(:final expr) => 'gamma(${formatExpr(expr)})',
    Beta(:final left, :final right) =>
      'beta(${formatExpr(left)}, ${formatExpr(right)})',
    Asinh(:final expr) => 'asinh(${formatExpr(expr)})',
    Acosh(:final expr) => 'acosh(${formatExpr(expr)})',
    Atanh(:final expr) => 'atanh(${formatExpr(expr)})',
    LessThan(:final left, :final right) =>
      '${formatExpr(left)} < ${formatExpr(right)}',
    LessEqual(:final left, :final right) =>
      '${formatExpr(left)} <= ${formatExpr(right)}',
    GreaterThan(:final left, :final right) =>
      '${formatExpr(left)} > ${formatExpr(right)}',
    GreaterEqual(:final left, :final right) =>
      '${formatExpr(left)} >= ${formatExpr(right)}',
    Equal(:final left, :final right) =>
      '${formatExpr(left)} == ${formatExpr(right)}',
    Piecewise(:final branches, :final otherwise) =>
      'Piecewise([${branches.map((b) => '(${formatExpr(b.$1)}, ${formatExpr(b.$2)})').join(', ')}]'
          '${otherwise != null ? ', otherwise: ${formatExpr(otherwise)}' : ''})',
  };
  return prec < parentPrec ? '($formatted)' : formatted;
}

String _formatOrderTerm(String variable, int order, Expr point) {
  final isZero = point is RationalNumber && point.isZero;
  if (isZero) {
    if (order == 0) return 'O(1)';
    if (order == 1) return 'O($variable)';
    return 'O($variable^$order)';
  }
  final delta = formatExpr(Sub(Variable(variable), point));
  if (order == 1) return 'O($delta)';
  return 'O(($delta)^$order)';
}

/// Returns the operator precedence level for the given [expr].
///
/// Higher values indicate tighter binding.
int precedence(Expr expr) => switch (expr) {
  RelationalExpr() => 0,
  Piecewise() => 0,
  ComplexNumber(:final real, :final imaginary)
      when real != 0.0 && imaginary != 0.0 =>
    1,
  Add() || Sub() => 1,
  Div() => 2,
  Mul() => 2,
  RationalNumber(isInteger: false) => 2,
  Neg() ||
  RationalNumber(isNegative: true) ||
  RealNumber(value: < 0) ||
  ComplexNumber(real: < 0, imaginary: 0) ||
  ComplexNumber(real: 0, imaginary: < 0) => 3,
  ComplexNumber(real: 0, :final imaginary) when imaginary != 1.0 => 2,
  Pow(:final exponent) =>
    exponent is RationalNumber &&
            exponent.numerator == 1 &&
            exponent.denominator == 2
        ? 5
        : 4,
  _ => 5,
};
