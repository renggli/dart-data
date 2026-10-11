import 'ast.dart';

/// LaTeX serialization extension on [Expr].
extension LatexExtension on Expr {
  /// Formats this expression into publication-grade LaTeX math syntax.
  ///
  /// Conceptually, this formats symbolic expressions for mathematical typesetting in
  /// papers, documentation, MathJax, or Markdown (such as `\frac{x}{2}`).
  /// Formally, it parses tree precedence to format fractions, exponents,
  /// negatives, and functions according to standard LaTeX formatting conventions.
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
  Constant(:final value) =>
    value % 1 == 0 ? value.toInt().toString() : value.toString(),
  Add(:final left, :final right) => '${_toLatex(left)} + ${_toLatex(right)}',
  Sub(:final left, :final right) =>
    '${_toLatex(left)} - ${_formatSubRight(right)}',
  Mul(:final left, :final right) =>
    '${_formatMulOperand(left)} \\cdot ${_formatMulOperand(right)}',
  Div(:final left, :final right) =>
    '\\frac{${_toLatex(left)}}{${_toLatex(right)}}',
  Pow(:final base, :final exponent) =>
    '{${_formatPowBase(base)}}^{${_toLatex(exponent)}}',
  Neg(:final expr) => '-${_formatNegOperand(expr)}',
  Sin(:final expr) => '\\sin(${_toLatex(expr)})',
  Cos(:final expr) => '\\cos(${_toLatex(expr)})',
  Exp(:final expr) => 'e^{${_toLatex(expr)}}',
  Ln(:final expr) => '\\ln(${_toLatex(expr)})',
};

String _formatSubRight(Expr right) => switch (right) {
  Add() || Sub() => '(${_toLatex(right)})',
  _ => _toLatex(right),
};

String _formatMulOperand(Expr operand) => switch (operand) {
  Add() || Sub() => '(${_toLatex(operand)})',
  _ => _toLatex(operand),
};

String _formatPowBase(Expr base) => switch (base) {
  Add() || Sub() || Mul() || Div() || Neg() => '(${_toLatex(base)})',
  _ => _toLatex(base),
};

String _formatNegOperand(Expr expr) => switch (expr) {
  Add() || Sub() => '(${_toLatex(expr)})',
  _ => _toLatex(expr),
};
