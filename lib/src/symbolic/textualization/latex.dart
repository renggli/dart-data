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
  ComplexNumber() => expr.toString(),
  ConstantNumber(:final name) => switch (name) {
    'pi' => r'\pi',
    'i' => 'i',
    'oo' || 'infinity' => r'\infty',
    _ => name,
  },
  RationalNumber(:final numerator, :final denominator) =>
    denominator == 1
        ? '$numerator'
        : numerator < 0
        ? '-\\frac{${-numerator}}{$denominator}'
        : '\\frac{$numerator}{$denominator}',
  RealNumber(:final value) => '$value',
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
  OrderTerm(:final variable, :final order, :final point) =>
    _formatOrderTermLatex(variable, order, point),
  LambertW(:final expr, :final branch) =>
    branch == 0 ? 'W(${_toLatex(expr)})' : 'W_{$branch}(${_toLatex(expr)})',
  Erf(:final expr) => '\\operatorname{erf}(${_toLatex(expr)})',
  Erfc(:final expr) => '\\operatorname{erfc}(${_toLatex(expr)})',
  Gamma(:final expr) => '\\Gamma(${_toLatex(expr)})',
  Beta(:final left, :final right) =>
    '\\operatorname{B}(${_toLatex(left)}, ${_toLatex(right)})',
  Asinh(:final expr) => '\\operatorname{arsinh}(${_toLatex(expr)})',
  Acosh(:final expr) => '\\operatorname{arcosh}(${_toLatex(expr)})',
  Atanh(:final expr) => '\\operatorname{artanh}(${_toLatex(expr)})',
  LessThan(:final left, :final right) =>
    '${_toLatex(left)} < ${_toLatex(right)}',
  LessEqual(:final left, :final right) =>
    '${_toLatex(left)} \\le ${_toLatex(right)}',
  GreaterThan(:final left, :final right) =>
    '${_toLatex(left)} > ${_toLatex(right)}',
  GreaterEqual(:final left, :final right) =>
    '${_toLatex(left)} \\ge ${_toLatex(right)}',
  Equal(:final left, :final right) => '${_toLatex(left)} = ${_toLatex(right)}',
  Piecewise(:final branches, :final otherwise) =>
    '\\begin{cases} '
        '${branches.map((b) => '${_toLatex(b.$2)}, & \\text{if } ${_toLatex(b.$1)}').join(' \\\\ ')}'
        '${otherwise != null ? ' \\\\ ${_toLatex(otherwise)}, & \\text{otherwise}' : ''}'
        ' \\end{cases}',
};

String _formatOrderTermLatex(String variable, int order, Expr point) {
  final isZero = point is RationalNumber && point.isZero;
  if (isZero) {
    if (order == 0) return 'O(1)';
    if (order == 1) return 'O($variable)';
    return 'O($variable^{$order})';
  }
  final formattedPoint = _formatSubRight(point);
  if (order == 1) return 'O($variable - $formattedPoint)';
  return 'O(($variable - $formattedPoint)^{$order})';
}

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

bool _isCompoundOrNegativeComplex(ComplexNumber c) =>
    (c.real != 0.0 && c.imaginary != 0.0) || c.real < 0.0 || c.imaginary < 0.0;

String _formatSubRight(Expr right) => switch (right) {
  Add() ||
  Sub() ||
  Neg() ||
  RationalNumber(numerator: < 0) ||
  RealNumber(value: < 0) => '(${_toLatex(right)})',
  final ComplexNumber c when _isCompoundOrNegativeComplex(c) =>
    '(${_toLatex(right)})',
  _ => _toLatex(right),
};

String _formatMulOperand(Expr operand) => switch (operand) {
  Add() ||
  Sub() ||
  Neg() ||
  RationalNumber(numerator: < 0) ||
  RealNumber(value: < 0) => '(${_toLatex(operand)})',
  final ComplexNumber c when _isCompoundOrNegativeComplex(c) =>
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
  final ComplexNumber c
      when _isCompoundOrNegativeComplex(c) ||
          (c.real == 0.0 && c.imaginary != 1.0) =>
    '(${_toLatex(base)})',
  _ => _toLatex(base),
};

String _formatNegOperand(Expr expr) => switch (expr) {
  Add() ||
  Sub() ||
  Neg() ||
  RationalNumber(numerator: < 0) ||
  RealNumber(value: < 0) => '(${_toLatex(expr)})',
  final ComplexNumber c when _isCompoundOrNegativeComplex(c) =>
    '(${_toLatex(expr)})',
  _ => _toLatex(expr),
};
