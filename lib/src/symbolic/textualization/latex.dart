import '../ast.dart';
import '../number/integer.dart';
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
  /// Floating-point numbers are formatted with [decimalPlaces] (default 4).
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final tex = (x / (x + 1)).toLatex();
  /// // tex: '\frac{x}{x + 1}'
  /// ```
  String toLatex({int decimalPlaces = 4}) => _toLatex(this, decimalPlaces);
}

String _toLatex(Expr expr, int decimalPlaces) => switch (expr) {
  Variable(:final name) => _formatVariableLatex(name),
  VariableFunction(:final name, :final arguments) =>
    '$name(${arguments.map((a) => _toLatex(a, decimalPlaces)).join(', ')})',
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
  Sin(:final expr) => '\\sin(${_toLatex(expr, decimalPlaces)})',
  Cos(:final expr) => '\\cos(${_toLatex(expr, decimalPlaces)})',
  Tan(:final expr) => '\\tan(${_toLatex(expr, decimalPlaces)})',
  Asin(:final expr) => '\\arcsin(${_toLatex(expr, decimalPlaces)})',
  Acos(:final expr) => '\\arccos(${_toLatex(expr, decimalPlaces)})',
  Atan(:final expr) => '\\arctan(${_toLatex(expr, decimalPlaces)})',
  Atan2(:final left, :final right) =>
    '\\operatorname{atan2}(${_toLatex(left, decimalPlaces)}, ${_toLatex(right, decimalPlaces)})',
  Sinh(:final expr) => '\\sinh(${_toLatex(expr, decimalPlaces)})',
  Cosh(:final expr) => '\\cosh(${_toLatex(expr, decimalPlaces)})',
  Tanh(:final expr) => '\\tanh(${_toLatex(expr, decimalPlaces)})',
  Abs(:final expr) => '\\left|${_toLatex(expr, decimalPlaces)}\\right|',
  Ln(:final expr) => '\\ln(${_toLatex(expr, decimalPlaces)})',
  OrderTerm(:final variable, :final order, :final point) =>
    _formatOrderTermLatex(variable, order, point, decimalPlaces),
  LambertW(:final expr, :final branch) =>
    branch == 0
        ? 'W(${_toLatex(expr, decimalPlaces)})'
        : 'W_{$branch}(${_toLatex(expr, decimalPlaces)})',
  Erf(:final expr) => '\\operatorname{erf}(${_toLatex(expr, decimalPlaces)})',
  Erfc(:final expr) => '\\operatorname{erfc}(${_toLatex(expr, decimalPlaces)})',
  Gamma(:final expr) => '\\Gamma(${_toLatex(expr, decimalPlaces)})',
  Zeta(:final expr, :final shift) =>
    shift == null
        ? '\\zeta(${_toLatex(expr, decimalPlaces)})'
        : '\\zeta(${_toLatex(expr, decimalPlaces)}, ${_toLatex(shift, decimalPlaces)})',
  Digamma(:final expr) => '\\psi(${_toLatex(expr, decimalPlaces)})',
  Polygamma(:final left, :final right) =>
    '\\psi^{(${_toLatex(left, decimalPlaces)})}(${_toLatex(right, decimalPlaces)})',
  BesselJ(:final left, :final right) =>
    'J_{${_toLatex(left, decimalPlaces)}}(${_toLatex(right, decimalPlaces)})',
  BesselY(:final left, :final right) =>
    'Y_{${_toLatex(left, decimalPlaces)}}(${_toLatex(right, decimalPlaces)})',
  BesselI(:final left, :final right) =>
    'I_{${_toLatex(left, decimalPlaces)}}(${_toLatex(right, decimalPlaces)})',
  BesselK(:final left, :final right) =>
    'K_{${_toLatex(left, decimalPlaces)}}(${_toLatex(right, decimalPlaces)})',
  EllipticK(:final expr) => 'K(${_toLatex(expr, decimalPlaces)})',
  EllipticE(:final expr, :final amplitude) =>
    amplitude == null
        ? 'E(${_toLatex(expr, decimalPlaces)})'
        : 'E(${_toLatex(amplitude, decimalPlaces)}, ${_toLatex(expr, decimalPlaces)})',
  Erfi(:final expr) => '\\operatorname{erfi}(${_toLatex(expr, decimalPlaces)})',
  FresnelS(:final expr) => 'S(${_toLatex(expr, decimalPlaces)})',
  FresnelC(:final expr) => 'C(${_toLatex(expr, decimalPlaces)})',
  ExpIntegral(:final expr) =>
    '\\operatorname{Ei}(${_toLatex(expr, decimalPlaces)})',
  ExpIntegralE(:final left, :final right) =>
    'E_{${_toLatex(left, decimalPlaces)}}(${_toLatex(right, decimalPlaces)})',
  LogIntegral(:final expr) =>
    '\\operatorname{li}(${_toLatex(expr, decimalPlaces)})',
  SinIntegral(:final expr) =>
    '\\operatorname{Si}(${_toLatex(expr, decimalPlaces)})',
  CosIntegral(:final expr) =>
    '\\operatorname{Ci}(${_toLatex(expr, decimalPlaces)})',
  SinhIntegral(:final expr) =>
    '\\operatorname{Shi}(${_toLatex(expr, decimalPlaces)})',
  CoshIntegral(:final expr) =>
    '\\operatorname{Chi}(${_toLatex(expr, decimalPlaces)})',
  UpperGamma(:final left, :final right) =>
    '\\Gamma(${_toLatex(left, decimalPlaces)}, ${_toLatex(right, decimalPlaces)})',
  LowerGamma(:final left, :final right) =>
    '\\gamma(${_toLatex(left, decimalPlaces)}, ${_toLatex(right, decimalPlaces)})',
  Polylog(:final left, :final right) =>
    '\\operatorname{Li}_{${_toLatex(left, decimalPlaces)}}(${_toLatex(right, decimalPlaces)})',
  EllipticF(:final left, :final right) =>
    'F(${_toLatex(left, decimalPlaces)}, ${_toLatex(right, decimalPlaces)})',
  EllipticPi(:final characteristic, :final amplitude, :final modulus) =>
    '\\Pi(${_toLatex(characteristic, decimalPlaces)}; ${_toLatex(amplitude, decimalPlaces)} \\mid ${_toLatex(modulus, decimalPlaces)})',
  Hypergeometric(:final upper, :final lower, :final argument) =>
    '{}_{${upper.length}}F_{${lower.length}}\\left(${upper.map((e) => _toLatex(e, decimalPlaces)).join(', ')}; ${lower.map((e) => _toLatex(e, decimalPlaces)).join(', ')}; ${_toLatex(argument, decimalPlaces)}\\right)',
  Min(:final args) =>
    '\\min\\left(${args.map((e) => _toLatex(e, decimalPlaces)).join(', ')}\\right)',
  Max(:final args) =>
    '\\max\\left(${args.map((e) => _toLatex(e, decimalPlaces)).join(', ')}\\right)',
  Beta(:final left, :final right) =>
    '\\operatorname{B}(${_toLatex(left, decimalPlaces)}, ${_toLatex(right, decimalPlaces)})',
  Factorial(:final expr) => '${_formatPowBase(expr, decimalPlaces)}!',
  Binomial(:final left, :final right) =>
    '\\binom{${_toLatex(left, decimalPlaces)}}{${_toLatex(right, decimalPlaces)}}',
  Floor(:final expr) => '\\lfloor ${_toLatex(expr, decimalPlaces)} \\rfloor',
  Ceil(:final expr) => '\\lceil ${_toLatex(expr, decimalPlaces)} \\rceil',
  Round(:final expr) =>
    '\\operatorname{round}(${_toLatex(expr, decimalPlaces)})',
  Sign(:final expr) => '\\operatorname{sgn}(${_toLatex(expr, decimalPlaces)})',
  Mod(:final left, :final right) =>
    '${_formatMulLeft(left, decimalPlaces)} \\bmod ${_formatMulRight(right, decimalPlaces)}',
  Re(:final expr) => '\\operatorname{Re}(${_toLatex(expr, decimalPlaces)})',
  Im(:final expr) => '\\operatorname{Im}(${_toLatex(expr, decimalPlaces)})',
  Arg(:final expr) => '\\arg(${_toLatex(expr, decimalPlaces)})',
  Conjugate(:final expr) => '\\overline{${_toLatex(expr, decimalPlaces)}}',
  Asinh(:final expr) =>
    '\\operatorname{arsinh}(${_toLatex(expr, decimalPlaces)})',
  Acosh(:final expr) =>
    '\\operatorname{arcosh}(${_toLatex(expr, decimalPlaces)})',
  Atanh(:final expr) =>
    '\\operatorname{artanh}(${_toLatex(expr, decimalPlaces)})',
  LessThan(:final left, :final right) =>
    '${_toLatex(left, decimalPlaces)} < ${_toLatex(right, decimalPlaces)}',
  LessEqual(:final left, :final right) =>
    '${_toLatex(left, decimalPlaces)} \\le ${_toLatex(right, decimalPlaces)}',
  GreaterThan(:final left, :final right) =>
    '${_toLatex(left, decimalPlaces)} > ${_toLatex(right, decimalPlaces)}',
  GreaterEqual(:final left, :final right) =>
    '${_toLatex(left, decimalPlaces)} \\ge ${_toLatex(right, decimalPlaces)}',
  Equal(:final left, :final right) =>
    '${_toLatex(left, decimalPlaces)} = ${_toLatex(right, decimalPlaces)}',
  NotEqual(:final left, :final right) =>
    '${_toLatex(left, decimalPlaces)} \\ne ${_toLatex(right, decimalPlaces)}',
  Piecewise(:final branches, :final otherwise) =>
    '\\begin{cases} '
        '${branches.map((b) => '${_toLatex(b.expr, decimalPlaces)}, & \\text{if } ${_toLatex(b.relation, decimalPlaces)}').join(' \\\\ ')}'
        '${otherwise != null ? ' \\\\ ${_toLatex(otherwise, decimalPlaces)}, & \\text{otherwise}' : ''}'
        ' \\end{cases}',
  Integral(:final integrand, :final variable, :final lower, :final upper) => () {
    final varLatex = _toLatex(Variable(variable), decimalPlaces);
    final body = _formatMulRight(integrand, decimalPlaces);
    return lower != null && upper != null
        ? '\\int_{${_toLatex(lower, decimalPlaces)}}^{${_toLatex(upper, decimalPlaces)}} $body \\, \\mathrm{d}$varLatex'
        : '\\int $body \\, \\mathrm{d}$varLatex';
  }(),
  Derivative(:final expr, :final variable, :final order, :final point) => () {
    final varLatex = _toLatex(Variable(variable), decimalPlaces);
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
    final varLatex = _toLatex(Variable(variable), decimalPlaces);
    final dirSuffix = switch (direction) {
      LimitDirection.both => '',
      LimitDirection.fromAbove => '^+',
      LimitDirection.fromBelow => '^-',
    };
    return '\\lim_{$varLatex \\to ${_toLatex(point, decimalPlaces)}$dirSuffix} ${_formatMulRight(expr, decimalPlaces)}';
  }(),
  Sum(:final expr, :final variable, :final lower, :final upper) =>
    '\\sum_{${_toLatex(Variable(variable), decimalPlaces)}=${_toLatex(lower, decimalPlaces)}}^{${_toLatex(upper, decimalPlaces)}} ${_formatMulRight(expr, decimalPlaces)}',
  Product(:final expr, :final variable, :final lower, :final upper) =>
    '\\prod_{${_toLatex(Variable(variable), decimalPlaces)}=${_toLatex(lower, decimalPlaces)}}^{${_toLatex(upper, decimalPlaces)}} ${_formatMulRight(expr, decimalPlaces)}',
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
    term is Mod || term is RelationalExpr
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
        _ => Mul(rest),
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
      when numerator == Integer.one) {
    if (denominator == Integer.two) {
      return '\\sqrt{${_toLatex(base, decimalPlaces)}}';
    } else if (denominator > Integer.two) {
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

String _formatVariableLatex(String name) {
  final idx = name.indexOf('_');
  if (idx > 0 && idx < name.length - 1) {
    final base = name.substring(0, idx);
    final sub = name.substring(idx + 1);
    final baseTex = _greekLetters.contains(base) ? '\\$base' : base;
    return '${baseTex}_{$sub}';
  }
  return _greekLetters.contains(name) ? '\\$name' : name;
}

String _formatPowBase(Expr base, int decimalPlaces) => needsPowBaseParens(base)
    ? '(${_toLatex(base, decimalPlaces)})'
    : _toLatex(base, decimalPlaces);

String _formatNegOperand(Expr expr, int decimalPlaces) =>
    needsNegOperandParens(expr)
    ? '(${_toLatex(expr, decimalPlaces)})'
    : _toLatex(expr, decimalPlaces);
