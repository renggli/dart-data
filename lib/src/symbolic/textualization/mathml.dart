import '../ast.dart';
import '../calculus/series.dart';
import 'formatting.dart';

/// MathML serialization extension on [Expr].
extension MathMlExtension on Expr {
  /// Formats this expression into W3C MathML markup.
  String toMathMl({
    bool display = false,
    bool root = true,
    int decimalPlaces = 4,
  }) {
    final inner = _toMathMl(this, decimalPlaces);
    if (!root) return inner;
    final attr = display ? ' display="block"' : '';
    return '<math$attr>$inner</math>';
  }
}

/// MathML serialization extension on [PowerSeries].
extension PowerSeriesMathMlExtension on PowerSeries {
  /// Formats this power series into W3C MathML markup.
  String toMathMl({
    bool display = false,
    bool root = true,
    int decimalPlaces = 4,
    bool includeOrder = true,
  }) =>
      toExpr(includeOrder: includeOrder)
          .toMathMl(display: display, root: root, decimalPlaces: decimalPlaces);
}

String _toMathMl(Expr expr, int decimalPlaces) => switch (expr) {
  Variable(:final name) => _formatVariableMathMl(name),
  Constant(:final name, :final mathMl) =>
    mathMl == '<mi>$name</mi>' ? '<mi>${_escapeXml(name)}</mi>' : mathMl,
  IntegerNumber(:final value) =>
    value.isNegative
        ? '<mrow><mo form="prefix">&#x2212;</mo><mn>${-value}</mn></mrow>'
        : '<mn>$value</mn>',
  FractionNumber(:final numerator, :final denominator) =>
    numerator.isNegative
        ? '<mrow><mo form="prefix">&#x2212;</mo><mfrac><mn>${-numerator}</mn><mn>$denominator</mn></mfrac></mrow>'
        : '<mfrac><mn>$numerator</mn><mn>$denominator</mn></mfrac>',
  RealNumber(:final value) => () {
    final formatted = formatDouble(value, decimalPlaces);
    return formatted.startsWith('-')
        ? '<mrow><mo form="prefix">&#x2212;</mo><mn>${formatted.substring(1)}</mn></mrow>'
        : '<mn>$formatted</mn>';
  }(),
  ComplexNumber() => _formatComplexMathMl(expr, decimalPlaces),
  Add(:final terms) => _formatAddMathMl(terms, decimalPlaces),
  Mul(:final factors) => _formatMulMathMl(factors, decimalPlaces),
  Pow(:final base, :final exponent) => _formatPow(
    base,
    exponent,
    decimalPlaces,
  ),
  Call(:final spec, :final args) =>
    spec is SymbolicFunctionSpec
        ? '<mrow><mi>${_escapeXml(spec.name)}</mi><mo>(</mo>${args.map((a) => _toMathMl(a, decimalPlaces)).join('<mo>,</mo>')}<mo>)</mo></mrow>'
        : spec.formatMathMl(args, decimalPlaces, _toMathMl, _formatPowBase),
  OrderTerm(:final variable, :final order, :final point) =>
    _formatOrderTermMathMl(variable, order, point, decimalPlaces),
  Relational(:final op, :final left, :final right) =>
    '<mrow>${_toMathMl(left, decimalPlaces)}<mo>${op.mathMlSymbol}</mo>${_toMathMl(right, decimalPlaces)}</mrow>',
  Piecewise(:final branches, :final otherwise) =>
    '<mrow><mo>{</mo><mtable>'
        '${branches.map((b) => '<mtr><mtd>${_toMathMl(b.expr, decimalPlaces)}</mtd><mtd><mtext>if&#x00a0;</mtext>${_toMathMl(b.relation, decimalPlaces)}</mtd></mtr>').join()}'
        '${otherwise != null ? '<mtr><mtd>${_toMathMl(otherwise, decimalPlaces)}</mtd><mtd><mtext>otherwise</mtext></mtd></mtr>' : ''}'
        '</mtable></mrow>',
  Integral(:final integrand, :final variable, :final lower, :final upper) => () {
    final vMathMl = _formatVariableMathMl(variable);
    final body = _formatMulRight(integrand, decimalPlaces);
    return lower != null && upper != null
        ? '<mrow><msubsup><mo>&#x222B;</mo>${_toMathMl(lower, decimalPlaces)}${_toMathMl(upper, decimalPlaces)}</msubsup>$body<mspace width="thinmathspace"/><mi>d</mi>$vMathMl</mrow>'
        : '<mrow><mo>&#x222B;</mo>$body<mspace width="thinmathspace"/><mi>d</mi>$vMathMl</mrow>';
  }(),
  Derivative(:final expr, :final variable, :final order, :final point) => () {
    final vMathMl = _formatVariableMathMl(variable);
    final diffOp = order == 1
        ? '<mfrac><mi>d</mi><mrow><mi>d</mi>$vMathMl</mrow></mfrac>'
        : '<mfrac><msup><mi>d</mi><mn>$order</mn></msup><mrow><mi>d</mi><msup>$vMathMl<mn>$order</mn></msup></mrow></mfrac>';
    final base = '<mrow>$diffOp${_formatMulRight(expr, decimalPlaces)}</mrow>';
    if (point != null) {
      return '<mrow><msub><mrow>$base<mo>|</mo></mrow><mrow>$vMathMl<mo>=</mo>${_toMathMl(point, decimalPlaces)}</mrow></msub></mrow>';
    }
    return base;
  }(),
  Limit(:final expr, :final variable, :final point, :final direction) => () {
    final vMathMl = _formatVariableMathMl(variable);
    final ptMathMl = switch (direction) {
      LimitDirection.both => _toMathMl(point, decimalPlaces),
      LimitDirection.fromAbove =>
        '<msup>${_toMathMl(point, decimalPlaces)}<mo>+</mo></msup>',
      LimitDirection.fromBelow =>
        '<msup>${_toMathMl(point, decimalPlaces)}<mo>&#x2212;</mo></msup>',
    };
    return '<mrow><munder><mo movablelimits="false">lim</mo><mrow>$vMathMl<mo>&#x2192;</mo>$ptMathMl</mrow></munder>${_formatMulRight(expr, decimalPlaces)}</mrow>';
  }(),
  Sum(:final expr, :final variable, :final lower, :final upper) =>
    '<mrow><munderover><mo movablelimits="false">&#x2211;</mo><mrow>${_formatVariableMathMl(variable)}<mo>=</mo>${_toMathMl(lower, decimalPlaces)}</mrow>${_toMathMl(upper, decimalPlaces)}</munderover>${_formatMulRight(expr, decimalPlaces)}</mrow>',
  Product(:final expr, :final variable, :final lower, :final upper) =>
    '<mrow><munderover><mo movablelimits="false">&#x220F;</mo><mrow>${_formatVariableMathMl(variable)}<mo>=</mo>${_toMathMl(lower, decimalPlaces)}</mrow>${_toMathMl(upper, decimalPlaces)}</munderover>${_formatMulRight(expr, decimalPlaces)}</mrow>',
  RootSum(:final polynomial, :final variable, :final body) =>
    '<mrow><munder><mo movablelimits="false">&#x2211;</mo><mrow>${_formatVariableMathMl(variable)}<mo>:</mo>${_toMathMl(polynomial, decimalPlaces)}<mo>=</mo><mn>0</mn></mrow></munder>${_formatMulRight(body, decimalPlaces)}</mrow>',
};

String _formatComplexMathMl(ComplexNumber c, int decimalPlaces) {
  final real = c.real;
  final imag = c.imaginary;
  if (real.isZero) {
    if (imag.isOne) return '<mi>i</mi>';
    if (imag.isNegativeOne) {
      return '<mrow><mo form="prefix">&#x2212;</mo><mi>i</mi></mrow>';
    }
    if (imag.isNegative) {
      return '<mrow><mo form="prefix">&#x2212;</mo>${_toMathMl(imag.neg(), decimalPlaces)}<mi>i</mi></mrow>';
    }
    return '<mrow>${_toMathMl(imag, decimalPlaces)}<mi>i</mi></mrow>';
  }
  final realStr = _toMathMl(real, decimalPlaces);
  if (imag.isOne) return '<mrow>$realStr<mo>+</mo><mi>i</mi></mrow>';
  if (imag.isNegativeOne) {
    return '<mrow>$realStr<mo>&#x2212;</mo><mi>i</mi></mrow>';
  }
  if (imag.isNegative) {
    final posImag = imag.neg();
    return '<mrow>$realStr<mo>&#x2212;</mo><mrow>${_toMathMl(posImag, decimalPlaces)}<mi>i</mi></mrow></mrow>';
  }
  return '<mrow>$realStr<mo>+</mo><mrow>${_toMathMl(imag, decimalPlaces)}<mi>i</mi></mrow></mrow>';
}

String _formatAddMathMl(List<Expr> terms, int decimalPlaces) {
  switch (terms) {
    case []:
      return '<mn>0</mn>';
    case [final single]:
      return _toMathMl(single, decimalPlaces);
    default:
      final buffer = StringBuffer('<mrow>')
        ..write(_formatAddTermMathMl(terms.first, decimalPlaces));
      for (var i = 1; i < terms.length; i++) {
        final term = terms[i];
        if (stripLeadingNegative(term) case final stripped?) {
          buffer
            ..write('<mo>&#x2212;</mo>')
            ..write(_formatSubRight(stripped, decimalPlaces));
        } else {
          buffer
            ..write('<mo>+</mo>')
            ..write(_formatAddTermMathMl(term, decimalPlaces));
        }
      }
      buffer.write('</mrow>');
      return buffer.toString();
  }
}

String _formatAddTermMathMl(Expr term, int decimalPlaces) =>
    isModCall(term) || term is Relational
    ? '<mrow><mo>(</mo>${_toMathMl(term, decimalPlaces)}<mo>)</mo></mrow>'
    : _toMathMl(term, decimalPlaces);

String _formatMulMathMl(List<Expr> factors, int decimalPlaces) {
  switch (factors) {
    case []:
      return '<mn>1</mn>';
    case [final single]:
      return _toMathMl(single, decimalPlaces);
    default:
      final (:isNegative, :numerator, :denominator) = partitionMulFraction(
        factors,
      );
      if (denominator.isNotEmpty) {
        final numMathMl = numerator.isEmpty
            ? '<mn>1</mn>'
            : _formatMulProductMathMl(numerator, decimalPlaces);
        final denMathMl = _formatMulProductMathMl(denominator, decimalPlaces);
        final frac = '<mfrac>$numMathMl$denMathMl</mfrac>';
        return isNegative
            ? '<mrow><mo form="prefix">&#x2212;</mo>$frac</mrow>'
            : frac;
      }
      return _formatMulProductMathMl(factors, decimalPlaces);
  }
}

String _formatMulProductMathMl(List<Expr> factors, int decimalPlaces) {
  switch (factors) {
    case []:
      return '<mn>1</mn>';
    case [final single]:
      return _toMathMl(single, decimalPlaces);
    case [IntegerNumber(isNegativeOne: true), ...final rest]:
      final operand = switch (rest) {
        [final single] => single,
        _ => Mul.of(rest),
      };
      return '<mrow><mo form="prefix">&#x2212;</mo>${_formatNegOperand(operand, decimalPlaces)}</mrow>';
    default:
      final buffer = StringBuffer('<mrow>');
      var firstFactor = factors.first;
      if (firstFactor case final RealNumeric n when n.isNegative) {
        buffer.write('<mo form="prefix">&#x2212;</mo>');
        firstFactor = n.neg();
      }
      buffer.write(_formatMulLeft(firstFactor, decimalPlaces));

      for (var i = 1; i < factors.length; i++) {
        final prev = i == 1 ? firstFactor : factors[i - 1];
        final curr = factors[i];
        final sep = canOmitMulDot(prev, curr) ? '' : '<mo>&#x22c5;</mo>';
        buffer
          ..write(sep)
          ..write(_formatMulRight(curr, decimalPlaces));
      }
      buffer.write('</mrow>');
      return buffer.toString();
  }
}

String _formatOrderTermMathMl(
  String variable,
  int order,
  Expr point,
  int decimalPlaces,
) {
  if (order == 0) {
    return '<mrow><mi>O</mi><mo>(</mo><mn>1</mn><mo>)</mo></mrow>';
  }
  final isZero = point is Number && point.isZero;
  final varMl = _formatVariableMathMl(variable);
  if (isZero) {
    if (order == 1) {
      return '<mrow><mi>O</mi><mo>(</mo>$varMl<mo>)</mo></mrow>';
    }
    return '<mrow><mi>O</mi><mo>(</mo><msup>$varMl${_toMathMl(IntegerNumber.of(order), decimalPlaces)}</msup><mo>)</mo></mrow>';
  }
  final stripped = stripLeadingNegative(point);
  final diff = stripped != null
      ? '<mrow>$varMl<mo>+</mo>${_toMathMl(stripped, decimalPlaces)}</mrow>'
      : '<mrow>$varMl<mo>&#x2212;</mo>${_formatSubRight(point, decimalPlaces)}</mrow>';
  if (order == 1) {
    return '<mrow><mi>O</mi><mo>(</mo>$diff<mo>)</mo></mrow>';
  }
  return '<mrow><mi>O</mi><mo>(</mo><msup><mrow><mo>(</mo>$diff<mo>)</mo></mrow>${_toMathMl(IntegerNumber.of(order), decimalPlaces)}</msup><mo>)</mo></mrow>';
}

String _formatPow(Expr base, Expr exponent, int decimalPlaces) {
  if (base == Constant.e) {
    return '<msup><mi>e</mi>${_toMathMl(exponent, decimalPlaces)}</msup>';
  }
  if (exponent == IntegerNumber.negativeOne) {
    return '<mfrac><mn>1</mn>${_toMathMl(base, decimalPlaces)}</mfrac>';
  }
  if (exponent case RationalNumber(:final numerator, :final denominator)
      when numerator == BigInt.one) {
    if (denominator == BigInt.two) {
      return '<msqrt><mrow>${_toMathMl(base, decimalPlaces)}</mrow></msqrt>';
    } else if (denominator > BigInt.two) {
      return '<mroot><mrow>${_toMathMl(base, decimalPlaces)}</mrow><mn>$denominator</mn></mroot>';
    }
  }
  if (matchFunctionPower(base, exponent) case (
    :final name,
    :final argument,
    latexCmd: _,
  )) {
    return '<mrow><msup><mi>$name</mi>${_toMathMl(exponent, decimalPlaces)}</msup><mo>(</mo>${_toMathMl(argument, decimalPlaces)}<mo>)</mo></mrow>';
  }
  return '<msup>${_formatPowBase(base, decimalPlaces)}${_toMathMl(exponent, decimalPlaces)}</msup>';
}

String _formatSubRight(Expr right, int decimalPlaces) =>
    needsSubRightParens(right)
    ? '<mrow><mo>(</mo>${_toMathMl(right, decimalPlaces)}<mo>)</mo></mrow>'
    : _toMathMl(right, decimalPlaces);

String _formatMulLeft(Expr left, int decimalPlaces) => needsMulLeftParens(left)
    ? '<mrow><mo>(</mo>${_toMathMl(left, decimalPlaces)}<mo>)</mo></mrow>'
    : _toMathMl(left, decimalPlaces);

String _formatMulRight(Expr right, int decimalPlaces) =>
    needsMulRightParens(right)
    ? '<mrow><mo>(</mo>${_toMathMl(right, decimalPlaces)}<mo>)</mo></mrow>'
    : _toMathMl(right, decimalPlaces);

String _formatPowBase(Expr base, int decimalPlaces) => needsPowBaseParens(base)
    ? '<mrow><mo>(</mo>${_toMathMl(base, decimalPlaces)}<mo>)</mo></mrow>'
    : _toMathMl(base, decimalPlaces);

String _formatNegOperand(Expr expr, int decimalPlaces) =>
    needsNegOperandParens(expr)
    ? '<mrow><mo>(</mo>${_toMathMl(expr, decimalPlaces)}<mo>)</mo></mrow>'
    : _toMathMl(expr, decimalPlaces);

String _escapeXml(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

const _greekLetters = <String, String>{
  'alpha': 'α',
  'beta': 'β',
  'gamma': 'γ',
  'delta': 'δ',
  'epsilon': 'ε',
  'zeta': 'ζ',
  'eta': 'η',
  'theta': 'θ',
  'iota': 'ι',
  'kappa': 'κ',
  'lambda': 'λ',
  'mu': 'μ',
  'nu': 'ν',
  'xi': 'ξ',
  'rho': 'ρ',
  'sigma': 'σ',
  'tau': 'τ',
  'upsilon': 'υ',
  'phi': 'φ',
  'chi': 'χ',
  'psi': 'ψ',
  'omega': 'ω',
  'Gamma': 'Γ',
  'Delta': 'Δ',
  'Theta': 'Θ',
  'Lambda': 'Λ',
  'Xi': 'Ξ',
  'Sigma': 'Σ',
  'Upsilon': 'Υ',
  'Phi': 'Φ',
  'Psi': 'Ψ',
  'Omega': 'Ω',
};

String _formatVariableMathMl(String name) {
  final idx = name.indexOf('_');
  if (idx > 0 && idx < name.length - 1) {
    final base = name.substring(0, idx);
    final sub = name.substring(idx + 1);
    final baseGlyph = _greekLetters[base] ?? _escapeXml(base);
    final subNode = _isAllAsciiDigits(sub)
        ? '<mn>$sub</mn>'
        : '<mi>${_escapeXml(sub)}</mi>';
    return '<msub><mi>$baseGlyph</mi>$subNode</msub>';
  }
  final glyph = _greekLetters[name] ?? _escapeXml(name);
  return '<mi>$glyph</mi>';
}

bool _isAllAsciiDigits(String text) {
  if (text.isEmpty) return false;
  for (var i = 0; i < text.length; i++) {
    final code = text.codeUnitAt(i);
    if (code < 48 || code > 57) return false;
  }
  return true;
}
