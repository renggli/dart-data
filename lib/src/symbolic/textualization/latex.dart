import '../ast.dart';
import 'formatting.dart';

/// LaTeX serialization extension on [Expr].
extension LatexExtension on Expr {
  /// Formats this expression into publication-grade LaTeX math syntax.
  String toLatex({int decimalPlaces = 4}) => _toLatex(this, decimalPlaces);
}

String _toLatex(Expr expr, int decimalPlaces) => switch (expr) {
  Variable(:final name) => _formatVariableLatex(name),
  Constant(:final latex) => latex,
  IntegerNumber(:final value) => '$value',
  FractionNumber(:final numerator, :final denominator) =>
    numerator.isNegative
        ? '-\\frac{${-numerator}}{$denominator}'
        : '\\frac{$numerator}{$denominator}',
  RealNumber(:final value) => formatDouble(value, decimalPlaces),
  ComplexNumber() => _formatComplexLatex(expr, decimalPlaces),
  Add(:final terms) => _formatAddLatex(terms, decimalPlaces),
  Mul(:final factors) => _formatMulLatex(factors, decimalPlaces),
  Pow(:final base, :final exponent) => _formatPow(
    base,
    exponent,
    decimalPlaces,
  ),
  Call(:final spec, :final args) => spec.formatLatex(
    args,
    decimalPlaces,
    _toLatex,
    _formatPowBase,
  ),
  OrderTerm(:final variable, :final order, :final point) =>
    _formatOrderTermLatex(variable, order, point, decimalPlaces),
  Relational(:final op, :final left, :final right) =>
    '${_toLatex(left, decimalPlaces)} ${op.latexSymbol} ${_toLatex(right, decimalPlaces)}',
  Piecewise(:final branches, :final otherwise) =>
    '\\begin{cases} '
        '${[for (final b in branches) '${_toLatex(b.expr, decimalPlaces)}, & \\text{if } ${_toLatex(b.relation, decimalPlaces)}', if (otherwise != null) '${_toLatex(otherwise, decimalPlaces)}, & \\text{otherwise}'].join(' \\\\ ')}'
        ' \\end{cases}',
  Integral(:final integrand, :final variable, :final lower, :final upper) => () {
    final varLatex = _formatVariableLatex(variable);
    final body = _formatMulRight(integrand, decimalPlaces);
    return lower != null && upper != null
        ? '\\int_{${_toLatex(lower, decimalPlaces)}}^{${_toLatex(upper, decimalPlaces)}} $body \\, \\mathrm{d}$varLatex'
        : '\\int $body \\, \\mathrm{d}$varLatex';
  }(),
  Derivative(:final expr, :final variable, :final order, :final point) => () {
    final varLatex = _formatVariableLatex(variable);
    final body = _formatMulRight(expr, decimalPlaces);
    return point != null
        ? (order == 1
              ? '\\left. \\frac{d}{d$varLatex} $body \\right|_{$varLatex = ${_toLatex(point, decimalPlaces)}}'
              : '\\left. \\frac{d^{$order}}{d$varLatex^{$order}} $body \\right|_{$varLatex = ${_toLatex(point, decimalPlaces)}}')
        : (order == 1
              ? '\\frac{d}{d$varLatex} $body'
              : '\\frac{d^{$order}}{d$varLatex^{$order}} $body');
  }(),
  Limit(:final expr, :final variable, :final point, :final direction) => () {
    final varLatex = _formatVariableLatex(variable);
    final dirSuffix = switch (direction) {
      LimitDirection.both => '',
      LimitDirection.fromAbove => '^+',
      LimitDirection.fromBelow => '^-',
    };
    return '\\lim_{$varLatex \\to ${_toLatex(point, decimalPlaces)}$dirSuffix} ${_formatMulRight(expr, decimalPlaces)}';
  }(),
  Sum(:final expr, :final variable, :final lower, :final upper) =>
    '\\sum_{${_formatVariableLatex(variable)}=${_toLatex(lower, decimalPlaces)}}^{${_toLatex(upper, decimalPlaces)}} ${_formatMulRight(expr, decimalPlaces)}',
  Product(:final expr, :final variable, :final lower, :final upper) =>
    '\\prod_{${_formatVariableLatex(variable)}=${_toLatex(lower, decimalPlaces)}}^{${_toLatex(upper, decimalPlaces)}} ${_formatMulRight(expr, decimalPlaces)}',
  RootSum(:final polynomial, :final variable, :final body) =>
    '\\sum_{${_formatVariableLatex(variable)} : ${_toLatex(polynomial, decimalPlaces)} = 0} ${_formatMulRight(body, decimalPlaces)}',
};

String _formatComplexLatex(ComplexNumber c, int decimalPlaces) {
  final real = c.real;
  final imag = c.imaginary;
  if (real.isZero) {
    if (imag.isOne) return 'i';
    if (imag.isNegativeOne) return '-i';
    return '${_toLatex(imag, decimalPlaces)} i';
  }
  final realStr = _toLatex(real, decimalPlaces);
  if (imag.isOne) return '$realStr + i';
  if (imag.isNegativeOne) return '$realStr - i';
  if (imag.isNegative) {
    return '$realStr - ${_toLatex(imag.neg(), decimalPlaces)} i';
  }
  return '$realStr + ${_toLatex(imag, decimalPlaces)} i';
}

String _formatAddLatex(List<Expr> terms, int decimalPlaces) {
  switch (terms) {
    case []:
      return '0';
    case [final single]:
      return _toLatex(single, decimalPlaces);
    default:
      final buffer = StringBuffer(_formatAddTerm(terms.first, decimalPlaces));
      for (var i = 1; i < terms.length; i++) {
        final term = terms[i];
        if (stripLeadingNegative(term) case final stripped?) {
          buffer.write(' - ${_formatSubRight(stripped, decimalPlaces)}');
        } else {
          buffer.write(' + ${_formatAddTerm(term, decimalPlaces)}');
        }
      }
      return buffer.toString();
  }
}

String _formatAddTerm(Expr term, int decimalPlaces) =>
    isModCall(term) || term is Relational
    ? '\\left(${_toLatex(term, decimalPlaces)}\\right)'
    : _toLatex(term, decimalPlaces);

String _formatMulLatex(List<Expr> factors, int decimalPlaces) {
  switch (factors) {
    case []:
      return '1';
    case [final single]:
      return _toLatex(single, decimalPlaces);
    default:
      final (:isNegative, :numerator, :denominator) = partitionMulFraction(
        factors,
      );
      if (denominator.isNotEmpty) {
        final numLatex = numerator.isEmpty
            ? '1'
            : _formatMulProductLatex(numerator, decimalPlaces);
        final denLatex = _formatMulProductLatex(denominator, decimalPlaces);
        final frac = '\\frac{$numLatex}{$denLatex}';
        return isNegative ? '-$frac' : frac;
      }
      return _formatMulProductLatex(factors, decimalPlaces);
  }
}

String _formatMulProductLatex(List<Expr> factors, int decimalPlaces) {
  switch (factors) {
    case []:
      return '1';
    case [final single]:
      return _toLatex(single, decimalPlaces);
    case [IntegerNumber(isNegativeOne: true), ...final rest]:
      final operand = switch (rest) {
        [final single] => single,
        _ => Mul.of(rest),
      };
      return '-${_formatNegOperand(operand, decimalPlaces)}';
    default:
      final buffer = StringBuffer(_formatMulLeft(factors.first, decimalPlaces));
      for (var i = 1; i < factors.length; i++) {
        final prev = factors[i - 1];
        final curr = factors[i];
        final sep = canOmitMulDot(prev, curr) ? ' ' : r' \cdot ';
        buffer.write('$sep${_formatMulRight(curr, decimalPlaces)}');
      }
      return buffer.toString();
  }
}

String _formatOrderTermLatex(
  String variable,
  int order,
  Expr point,
  int decimalPlaces,
) {
  if (order == 0) return 'O(1)';
  final varStr = _formatVariableLatex(variable);
  final isZero = point is Number && point.isZero;
  if (isZero) {
    if (order == 1) return 'O($varStr)';
    return 'O($varStr^{$order})';
  }
  final stripped = stripLeadingNegative(point);
  final diff = stripped != null
      ? '$varStr + ${_toLatex(stripped, decimalPlaces)}'
      : '$varStr - ${_formatSubRight(point, decimalPlaces)}';
  if (order == 1) return 'O($diff)';
  return 'O(($diff)^{$order})';
}

String _formatPow(Expr base, Expr exponent, int decimalPlaces) {
  if (base == Constant.e) {
    return 'e^{${_toLatex(exponent, decimalPlaces)}}';
  }
  if (exponent == IntegerNumber.negativeOne) {
    return '\\frac{1}{${_toLatex(base, decimalPlaces)}}';
  }
  if (exponent case RationalNumber(:final numerator, :final denominator)
      when numerator == BigInt.one) {
    if (denominator == BigInt.two) {
      return '\\sqrt{${_toLatex(base, decimalPlaces)}}';
    } else if (denominator > BigInt.two) {
      return '\\sqrt[$denominator]{${_toLatex(base, decimalPlaces)}}';
    }
  }
  if (matchFunctionPower(base, exponent) case (
    :final latexCmd,
    :final argument,
    name: _,
  )) {
    return '$latexCmd^{${_toLatex(exponent, decimalPlaces)}}(${_toLatex(argument, decimalPlaces)})';
  }
  return '{${_formatPowBase(base, decimalPlaces)}}^{${_toLatex(exponent, decimalPlaces)}}';
}

String _formatSubRight(Expr right, int decimalPlaces) =>
    needsSubRightParens(right)
    ? '(${_toLatex(right, decimalPlaces)})'
    : _toLatex(right, decimalPlaces);

String _formatMulLeft(Expr left, int decimalPlaces) => needsMulLeftParens(left)
    ? '(${_toLatex(left, decimalPlaces)})'
    : _toLatex(left, decimalPlaces);

String _formatMulRight(Expr right, int decimalPlaces) =>
    needsMulRightParens(right)
    ? '(${_toLatex(right, decimalPlaces)})'
    : _toLatex(right, decimalPlaces);

const _greekLetters = <String>{
  'alpha',
  'beta',
  'gamma',
  'delta',
  'epsilon',
  'zeta',
  'eta',
  'theta',
  'iota',
  'kappa',
  'lambda',
  'mu',
  'nu',
  'xi',
  'rho',
  'sigma',
  'tau',
  'upsilon',
  'phi',
  'chi',
  'psi',
  'omega',
  'Gamma',
  'Delta',
  'Theta',
  'Lambda',
  'Xi',
  'Sigma',
  'Upsilon',
  'Phi',
  'Psi',
  'Omega',
};

String _escapeLatexIdent(String name) => name
    .replaceAll(r'\', r'\textbackslash{}')
    .replaceAll('_', r'\_')
    .replaceAll('%', r'\%')
    .replaceAll('&', r'\&')
    .replaceAll('#', r'\#')
    .replaceAll(r'$', r'\$')
    .replaceAll('{', r'\{')
    .replaceAll('}', r'\}');

String _formatVariableLatex(String name) {
  final idx = name.indexOf('_');
  if (idx > 0 && idx < name.length - 1) {
    final base = name.substring(0, idx);
    final sub = name.substring(idx + 1);
    final baseTex = _greekLetters.contains(base)
        ? '\\$base'
        : _escapeLatexIdent(base);
    final subTex = _greekLetters.contains(sub)
        ? '\\$sub'
        : _escapeLatexIdent(sub);
    return '${baseTex}_{$subTex}';
  }
  return _greekLetters.contains(name) ? '\\$name' : _escapeLatexIdent(name);
}

String _formatPowBase(Expr base, int decimalPlaces) => needsPowBaseParens(base)
    ? '(${_toLatex(base, decimalPlaces)})'
    : _toLatex(base, decimalPlaces);

String _formatNegOperand(Expr expr, int decimalPlaces) =>
    needsNegOperandParens(expr)
    ? '(${_toLatex(expr, decimalPlaces)})'
    : _toLatex(expr, decimalPlaces);
