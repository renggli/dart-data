import 'package:more/number.dart' show Complex;

import '../ast.dart';

/// LaTeX serialization extension on [Expr].
extension LatexExtension on Expr {
  /// Formats this expression into publication-grade LaTeX math syntax.
  ///
  /// Conceptually, this formats symbolic expressions for mathematical
  /// typesetting in papers, documentation, MathJax, or Markdown (such as
  /// `\frac{x}{2}`). Formally, it parses tree precedence to format fractions,
  /// exponents, negatives, and functions according to standard LaTeX formatting
  /// conventions.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final tex = (x / (x + 1)).toLatex();
  /// // tex: '\frac{x}{x + 1}'
  /// ```
  String toLatex() => _toLatex(this);
}

String _toLatex(Expr expr) => switch (expr) {
  Variable(:final name) => name,
  ConstantNumber(:final name) => switch (name) {
    'pi' => r'\pi',
    'i' => 'i',
    _ => name,
  },
  RationalNumber(:final numerator, :final denominator) =>
    denominator == 1
        ? '$numerator'
        : numerator < 0
        ? '-\\frac{${-numerator}}{$denominator}'
        : '\\frac{$numerator}{$denominator}',
  RealNumber(:final value) => '$value',
  ComplexNumber(:final complex) => _formatComplexLatex(complex),
  Add(:final left, :final right) => '${_toLatex(left)} + ${_toLatex(right)}',
  Sub(:final left, :final right) =>
    '${_toLatex(left)} - ${_formatSubRight(right)}',
  Mul(:final left, :final right) =>
    '${_formatMulOperand(left)} \\cdot ${_formatMulOperand(right)}',
  Div(:final left, :final right) =>
    '\\frac{${_toLatex(left)}}{${_toLatex(right)}}',
  Pow(:final base, :final exponent) => _formatPow(base, exponent),
  Neg(:final expr) => '-${_formatNegOperand(expr)}',
  Sin(:final expr) => '\\sin(${_toLatex(expr)})',
  Cos(:final expr) => '\\cos(${_toLatex(expr)})',
  Tan(:final expr) => '\\tan(${_toLatex(expr)})',
  Asin(:final expr) => '\\arcsin(${_toLatex(expr)})',
  Acos(:final expr) => '\\arccos(${_toLatex(expr)})',
  Atan(:final expr) => '\\arctan(${_toLatex(expr)})',
  Sinh(:final expr) => '\\sinh(${_toLatex(expr)})',
  Cosh(:final expr) => '\\cosh(${_toLatex(expr)})',
  Tanh(:final expr) => '\\tanh(${_toLatex(expr)})',
  Abs(:final expr) => '\\left|${_toLatex(expr)}\\right|',
  Exp(:final expr) => 'e^{${_toLatex(expr)}}',
  Ln(:final expr) => '\\ln(${_toLatex(expr)})',
  Log(:final base, :final expr) =>
    '\\log_{${_toLatex(base)}}(${_toLatex(expr)})',
};

String _formatPow(Expr base, Expr exponent) {
  if (exponent is RationalNumber && exponent.numerator == 1) {
    if (exponent.denominator == 2) {
      return '\\sqrt{${_toLatex(base)}}';
    } else if (exponent.denominator > 2) {
      return '\\sqrt[${exponent.denominator}]{${_toLatex(base)}}';
    }
  }
  return '{${_formatPowBase(base)}}^{${_toLatex(exponent)}}';
}

String _formatComplexLatex(Complex c) {
  if (c.b == 0) {
    return _formatNum(c.a);
  }
  if (c.a == 0) {
    if (c.b == 1) return 'i';
    if (c.b == -1) return '-i';
    return '${_formatNum(c.b)} i';
  }
  final aStr = _formatNum(c.a);
  if (c.b == 1) {
    return '$aStr + i';
  } else if (c.b == -1) {
    return '$aStr - i';
  } else if (c.b > 0) {
    return '$aStr + ${_formatNum(c.b)} i';
  } else {
    return '$aStr - ${_formatNum(-c.b)} i';
  }
}

String _formatNum(num n) {
  if (n is int) return '$n';
  if (n.truncateToDouble() == n && !n.isInfinite && !n.isNaN) {
    return '${n.toInt()}';
  }
  return '$n';
}

String _formatSubRight(Expr right) => switch (right) {
  Add() ||
  Sub() ||
  Neg() ||
  RationalNumber(numerator: < 0) ||
  RealNumber(value: < 0) => '(${_toLatex(right)})',
  ComplexNumber(:final complex)
      when (complex.a != 0 && complex.b != 0) ||
          complex.a < 0 ||
          (complex.a == 0 && complex.b < 0) =>
    '(${_toLatex(right)})',
  _ => _toLatex(right),
};

String _formatMulOperand(Expr operand) => switch (operand) {
  Add() ||
  Sub() ||
  Neg() ||
  RationalNumber(numerator: < 0) ||
  RealNumber(value: < 0) => '(${_toLatex(operand)})',
  ComplexNumber(:final complex)
      when (complex.a != 0 && complex.b != 0) ||
          complex.a < 0 ||
          (complex.a == 0 && complex.b < 0) =>
    '(${_toLatex(operand)})',
  _ => _toLatex(operand),
};

String _formatPowBase(Expr base) => switch (base) {
  Add() ||
  Sub() ||
  Mul() ||
  Div() ||
  Neg() ||
  RationalNumber(numerator: < 0) ||
  RealNumber(value: < 0) => '(${_toLatex(base)})',
  ComplexNumber(:final complex)
      when (complex.b != 0 && complex != Complex.i) || complex.a < 0 =>
    '(${_toLatex(base)})',
  _ => _toLatex(base),
};

String _formatNegOperand(Expr expr) => switch (expr) {
  Add() ||
  Sub() ||
  Neg() ||
  RationalNumber(numerator: < 0) ||
  RealNumber(value: < 0) => '(${_toLatex(expr)})',
  ComplexNumber(:final complex)
      when (complex.a != 0 && complex.b != 0) ||
          complex.a < 0 ||
          (complex.a == 0 && complex.b < 0) =>
    '(${_toLatex(expr)})',
  _ => _toLatex(expr),
};
