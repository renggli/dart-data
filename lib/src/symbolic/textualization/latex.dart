import '../ast.dart';
import 'formatting.dart';

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
  VariableFunction(:final name, :final arguments) =>
    '$name(${arguments.map(_toLatex).join(', ')})',
  Constant(:final latex) => latex,
  IntegerNumber(:final value) => '$value',
  FractionNumber(:final numerator, :final denominator) =>
    numerator.isNegative
        ? '-\\frac{${-numerator}}{$denominator}'
        : '\\frac{$numerator}{$denominator}',
  RealNumber(:final value) => '$value',
  ComplexNumber() => _formatComplexLatex(expr),
  Add(:final terms) => _formatAddLatex(terms),
  Mul(:final factors) => _formatMulLatex(factors),
  Pow(:final base, :final exponent) => _formatPow(base, exponent),
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
  Factorial(:final expr) => '${_formatPowBase(expr)}!',
  Binomial(:final left, :final right) =>
    '\\binom{${_toLatex(left)}}{${_toLatex(right)}}',
  Floor(:final expr) => '\\lfloor ${_toLatex(expr)} \\rfloor',
  Ceil(:final expr) => '\\lceil ${_toLatex(expr)} \\rceil',
  Round(:final expr) => '\\operatorname{round}(${_toLatex(expr)})',
  Sign(:final expr) => '\\operatorname{sgn}(${_toLatex(expr)})',
  Mod(:final left, :final right) =>
    '${_formatMulLeft(left)} \\bmod ${_formatMulRight(right)}',
  Re(:final expr) => '\\operatorname{Re}(${_toLatex(expr)})',
  Im(:final expr) => '\\operatorname{Im}(${_toLatex(expr)})',
  Arg(:final expr) => '\\arg(${_toLatex(expr)})',
  Conjugate(:final expr) => '\\overline{${_toLatex(expr)}}',
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
  NotEqual(:final left, :final right) =>
    '${_toLatex(left)} \\ne ${_toLatex(right)}',
  Piecewise(:final branches, :final otherwise) =>
    '\\begin{cases} '
        '${branches.map((b) => '${_toLatex(b.expr)}, & \\text{if } ${_toLatex(b.relation)}').join(' \\\\ ')}'
        '${otherwise != null ? ' \\\\ ${_toLatex(otherwise)}, & \\text{otherwise}' : ''}'
        ' \\end{cases}',
  Integral(:final integrand, :final variable, :final lower, :final upper) =>
    lower != null && upper != null
        ? '\\int_{${_toLatex(lower)}}^{${_toLatex(upper)}} ${_toLatex(integrand)} \\, d$variable'
        : '\\int ${_toLatex(integrand)} \\, d$variable',
  Derivative(:final expr, :final variable, :final order) =>
    order == 1
        ? '\\frac{d}{d$variable} ${_formatMulRight(expr)}'
        : '\\frac{d^{$order}}{d$variable^{$order}} ${_formatMulRight(expr)}',
  Limit(:final expr, :final variable, :final point, :final direction) => () {
    final dirSuffix = switch (direction) {
      LimitDirection.both => '',
      LimitDirection.fromAbove => '^+',
      LimitDirection.fromBelow => '^-',
    };
    return '\\lim_{$variable \\to ${_toLatex(point)}$dirSuffix} ${_formatMulRight(expr)}';
  }(),
};

String _formatComplexLatex(ComplexNumber c) {
  final real = c.real;
  final imag = c.imaginary;
  if (real.isZero) {
    if (imag.isOne) return 'i';
    if (imag.isNegativeOne) return '-i';
    return '${_toLatex(imag)} i';
  }
  final realStr = _toLatex(real);
  if (imag.isOne) return '$realStr + i';
  if (imag.isNegativeOne) return '$realStr - i';
  if (imag.isNegative) {
    return '$realStr - ${_toLatex(imag.neg())} i';
  }
  return '$realStr + ${_toLatex(imag)} i';
}

String _formatAddLatex(List<Expr> terms) {
  switch (terms) {
    case []:
      return '0';
    case [final single]:
      return _toLatex(single);
    default:
      final buffer = StringBuffer(_toLatex(terms.first));
      for (var i = 1; i < terms.length; i++) {
        final term = terms[i];
        if (stripLeadingNegative(term) case final stripped?) {
          buffer.write(' - ${_formatSubRight(stripped)}');
        } else {
          buffer.write(' + ${_toLatex(term)}');
        }
      }
      return buffer.toString();
  }
}

String _formatMulLatex(List<Expr> factors) {
  switch (factors) {
    case []:
      return '1';
    case [final single]:
      return _toLatex(single);
    default:
      final (:isNegative, :numerator, :denominator) = partitionMulFraction(
        factors,
      );
      if (denominator.isNotEmpty) {
        final numLatex = numerator.isEmpty
            ? '1'
            : _formatMulProductLatex(numerator);
        final denLatex = _formatMulProductLatex(denominator);
        final frac = '\\frac{$numLatex}{$denLatex}';
        return isNegative ? '-$frac' : frac;
      }
      return _formatMulProductLatex(factors);
  }
}

String _formatMulProductLatex(List<Expr> factors) {
  switch (factors) {
    case []:
      return '1';
    case [final single]:
      return _toLatex(single);
    case [IntegerNumber(isNegativeOne: true), ...final rest]:
      final operand = switch (rest) {
        [final single] => single,
        _ => Mul(rest),
      };
      return '-${_formatNegOperand(operand)}';
    default:
      final buffer = StringBuffer(_formatMulLeft(factors.first));
      for (var i = 1; i < factors.length; i++) {
        final prev = factors[i - 1];
        final curr = factors[i];
        final sep = canOmitMulDot(prev, curr) ? r' \, ' : r' \cdot ';
        buffer.write('$sep${_formatMulRight(curr)}');
      }
      return buffer.toString();
  }
}

String _formatOrderTermLatex(String variable, int order, Expr point) {
  final isZero = point is Number && point.isZero;
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
  if (base == Constant.e) {
    return 'e^{${_toLatex(exponent)}}';
  }
  if (exponent == IntegerNumber.negativeOne) {
    return '\\frac{1}{${_toLatex(base)}}';
  }
  if (exponent case RationalNumber(:final numerator, :final denominator)
      when numerator == Integer.one) {
    if (denominator == Integer.two) {
      return '\\sqrt{${_toLatex(base)}}';
    } else if (denominator > Integer.two) {
      return '\\sqrt[$denominator]{${_toLatex(base)}}';
    }
  }
  if (matchFunctionPower(base, exponent) case (
    :final latexCmd,
    :final argument,
    name: _,
  )) {
    return '$latexCmd^{${_toLatex(exponent)}}(${_toLatex(argument)})';
  }
  return '{${_formatPowBase(base)}}^{${_toLatex(exponent)}}';
}

String _formatSubRight(Expr right) =>
    needsSubRightParens(right) ? '(${_toLatex(right)})' : _toLatex(right);

String _formatMulLeft(Expr left) =>
    needsMulLeftParens(left) ? '(${_toLatex(left)})' : _toLatex(left);

String _formatMulRight(Expr right) =>
    needsMulRightParens(right) ? '(${_toLatex(right)})' : _toLatex(right);

String _formatPowBase(Expr base) =>
    needsPowBaseParens(base) ? '(${_toLatex(base)})' : _toLatex(base);

String _formatNegOperand(Expr expr) =>
    needsNegOperandParens(expr) ? '(${_toLatex(expr)})' : _toLatex(expr);
