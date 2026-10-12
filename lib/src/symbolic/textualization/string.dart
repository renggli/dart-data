import 'package:more/number.dart' show Complex;

import '../ast.dart';

/// Formats the symbolic [expr] into a clean mathematical string representation
/// with minimal parentheses based on operator precedence and associativity.
///
/// ```dart
/// final x = Variable('x');
/// final str = formatExpr(x * x + 1); // 'x ^ 2 + 1'
/// ```
String formatExpr(Expr expr, [int parentPrec = 0]) {
  final prec = precedence(expr);
  final formatted = switch (expr) {
    Variable(:final name) => name,
    ConstantNumber(:final name) => name,
    RationalNumber(:final numerator, :final denominator) =>
      denominator == 1 ? '$numerator' : '$numerator/$denominator',
    RealNumber(:final value) => '$value',
    ComplexNumber(:final complex) => _formatComplex(complex),
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
    Log(:final base, :final expr) =>
      'log(${formatExpr(base)}, ${formatExpr(expr)})',
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
  };
  return prec < parentPrec ? '($formatted)' : formatted;
}

String _formatComplex(Complex c) {
  if (c.b == 0) {
    return _formatNum(c.a);
  }
  if (c.a == 0) {
    if (c.b == 1) return 'i';
    if (c.b == -1) return '-i';
    return '${_formatNum(c.b)} * i';
  }
  final aStr = _formatNum(c.a);
  if (c.b == 1) {
    return '$aStr + i';
  } else if (c.b == -1) {
    return '$aStr - i';
  } else if (c.b > 0) {
    return '$aStr + ${_formatNum(c.b)} * i';
  } else {
    return '$aStr - ${_formatNum(-c.b)} * i';
  }
}

String _formatNum(num n) {
  if (n is int) return '$n';
  if (n.truncateToDouble() == n && !n.isInfinite && !n.isNaN) {
    return '${n.toInt()}';
  }
  return '$n';
}

int _complexPrecedence(Complex c) {
  if (c.b != 0) {
    if (c.a != 0) return 1;
    if (c.b == 1) return 5;
    if (c.b == -1) return 3;
    return c.b < 0 ? 3 : 2;
  }
  return c.a < 0 ? 3 : 5;
}

/// Returns the operator precedence level for the given [expr].
///
/// Higher values indicate tighter binding.
int precedence(Expr expr) => switch (expr) {
  Add() || Sub() => 1,
  Div() => 2,
  Mul() => 2,
  RationalNumber(isInteger: false) => 2,
  Neg() || RationalNumber(isNegative: true) || RealNumber(value: < 0) => 3,
  ComplexNumber(:final complex) => _complexPrecedence(complex),
  Pow(:final exponent) =>
    exponent is RationalNumber &&
            exponent.numerator == 1 &&
            exponent.denominator == 2
        ? 5
        : 4,
  _ => 5,
};
