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
    '∞' || 'infinity' => r'\infty',
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
  Mul(:final left, :final right) => _formatMul(left, right),
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

String _formatSubRight(Expr right) => switch (right) {
  Add() || Sub() => '(${_toLatex(right)})',
  _ when _startsWithNegative(right) => '(${_toLatex(right)})',
  _ => _toLatex(right),
};

String _formatMul(Expr left, Expr right) {
  final leftLatex = _formatMulLeft(left);
  final rightLatex = _formatMulRight(right);
  final sep = _canOmitMulDot(left, right) ? ' ' : r' \cdot ';
  return '$leftLatex$sep$rightLatex';
}

String _formatMulLeft(Expr left) => switch (left) {
  Add() || Sub() => '(${_toLatex(left)})',
  _ => _toLatex(left),
};

String _formatMulRight(Expr right) => switch (right) {
  Add() || Sub() => '(${_toLatex(right)})',
  _ when _startsWithNegative(right) => '(${_toLatex(right)})',
  _ => _toLatex(right),
};

bool _canOmitMulDot(Expr left, Expr right) {
  final l = _rightmostMulFactor(left);
  if (!_isNumericFactor(l)) return false;
  final r = _leftmostMulFactor(right);
  return switch (r) {
    RationalNumber() || RealNumber() || Div() => false,
    _ when _startsWithNegative(r) => false,
    Pow() => !_startsWithNumber(r),
    _ => true,
  };
}

bool _isNumericFactor(Expr expr) => switch (expr) {
  RationalNumber() || RealNumber() => true,
  Neg(expr: RationalNumber() || RealNumber()) => true,
  _ => false,
};

bool _startsWithNegative(Expr expr) => switch (expr) {
  Neg() || RationalNumber(numerator: < 0) || RealNumber(value: < 0) => true,
  Mul(:final left) => _startsWithNegative(left),
  _ => false,
};

Expr _rightmostMulFactor(Expr expr) =>
    expr is Mul ? _rightmostMulFactor(expr.right) : expr;

Expr _leftmostMulFactor(Expr expr) =>
    expr is Mul ? _leftmostMulFactor(expr.left) : expr;

bool _startsWithNumber(Expr expr) => switch (expr) {
  RationalNumber() || RealNumber() => true,
  Pow(:final base, :final exponent) =>
    !(exponent is RationalNumber &&
            exponent.numerator == 1 &&
            exponent.denominator >= 2) &&
        _startsWithNumber(base),
  _ => false,
};

String _formatPowBase(Expr base) => switch (base) {
  Add() ||
  Sub() ||
  Mul() ||
  Div() ||
  Neg() ||
  RationalNumber(numerator: < 0) ||
  RealNumber(value: < 0) => '(${_toLatex(base)})',
  _ => _toLatex(base),
};

String _formatNegOperand(Expr expr) => switch (expr) {
  Add() || Sub() => '(${_toLatex(expr)})',
  _ when _startsWithNegative(expr) => '(${_toLatex(expr)})',
  _ => _toLatex(expr),
};
