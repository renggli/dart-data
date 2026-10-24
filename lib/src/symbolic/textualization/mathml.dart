import '../ast.dart';
import '../number/integer.dart';
import 'formatting.dart';

/// MathML serialization extension on [Expr].
extension MathMlExtension on Expr {
  /// Formats this expression into W3C MathML markup.
  ///
  /// MathML (Mathematical Markup Language) is an XML standard for encoding
  /// mathematical notation, natively rendered by modern web browsers and
  /// document processing tools.
  ///
  /// If [display] is `true`, produces `<math display="block">` for block-level
  /// rendering; otherwise produces inline `<math>`. If [root] is `false`,
  /// returns only the inner MathML elements without the enclosing `<math>` tag.
  ///
  /// Floating-point numbers are formatted with [decimalPlaces] (default 4).
  /// If [decimalPlaces] is `null`, full standard precision is preserved.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final mathml = (x / (x + 1)).toMathMl();
  /// // '<math><mfrac><mi>x</mi><mrow><mi>x</mi><mo>+</mo><mn>1</mn></mrow></mfrac></math>'
  /// ```
  String toMathMl({
    bool display = false,
    bool root = true,
    int? decimalPlaces = 4,
  }) {
    final inner = _toMathMl(this, decimalPlaces: decimalPlaces);
    if (!root) return inner;
    final attr = display ? ' display="block"' : '';
    return '<math$attr>$inner</math>';
  }
}

String _toMathMl(Expr expr, {int? decimalPlaces = 4}) => switch (expr) {
  Variable(:final name) => '<mi>${_escapeXml(name)}</mi>',
  VariableFunction(:final name, :final arguments) =>
    '<mrow><mi>${_escapeXml(name)}</mi><mo>(</mo>${arguments.map((a) => _toMathMl(a, decimalPlaces: decimalPlaces)).join('<mo>,</mo>')}<mo>)</mo></mrow>',
  Constant(:final mathMl) => mathMl,
  IntegerNumber(:final value) =>
    value.isNegative
        ? '<mrow><mo form="prefix">&minus;</mo><mn>${-value}</mn></mrow>'
        : '<mn>$value</mn>',
  FractionNumber(:final numerator, :final denominator) =>
    numerator.isNegative
        ? '<mrow><mo form="prefix">&minus;</mo><mfrac><mn>${-numerator}</mn><mn>$denominator</mn></mfrac></mrow>'
        : '<mfrac><mn>$numerator</mn><mn>$denominator</mn></mfrac>',
  RealNumber(:final value) => () {
    final formatted = formatDouble(value.abs(), decimalPlaces: decimalPlaces);
    return value < 0
        ? '<mrow><mo form="prefix">&minus;</mo><mn>$formatted</mn></mrow>'
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
  Sin(:final expr) =>
    '<mrow><mi>sin</mi><mo>(</mo>${_toMathMl(expr, decimalPlaces: decimalPlaces)}<mo>)</mo></mrow>',
  Cos(:final expr) =>
    '<mrow><mi>cos</mi><mo>(</mo>${_toMathMl(expr, decimalPlaces: decimalPlaces)}<mo>)</mo></mrow>',
  Tan(:final expr) =>
    '<mrow><mi>tan</mi><mo>(</mo>${_toMathMl(expr, decimalPlaces: decimalPlaces)}<mo>)</mo></mrow>',
  Asin(:final expr) =>
    '<mrow><mi>arcsin</mi><mo>(</mo>${_toMathMl(expr, decimalPlaces: decimalPlaces)}<mo>)</mo></mrow>',
  Acos(:final expr) =>
    '<mrow><mi>arccos</mi><mo>(</mo>${_toMathMl(expr, decimalPlaces: decimalPlaces)}<mo>)</mo></mrow>',
  Atan(:final expr) =>
    '<mrow><mi>arctan</mi><mo>(</mo>${_toMathMl(expr, decimalPlaces: decimalPlaces)}<mo>)</mo></mrow>',
  Sinh(:final expr) =>
    '<mrow><mi>sinh</mi><mo>(</mo>${_toMathMl(expr, decimalPlaces: decimalPlaces)}<mo>)</mo></mrow>',
  Cosh(:final expr) =>
    '<mrow><mi>cosh</mi><mo>(</mo>${_toMathMl(expr, decimalPlaces: decimalPlaces)}<mo>)</mo></mrow>',
  Tanh(:final expr) =>
    '<mrow><mi>tanh</mi><mo>(</mo>${_toMathMl(expr, decimalPlaces: decimalPlaces)}<mo>)</mo></mrow>',
  Abs(:final expr) =>
    '<mrow><mo>|</mo>${_toMathMl(expr, decimalPlaces: decimalPlaces)}<mo>|</mo></mrow>',
  Ln(:final expr) =>
    '<mrow><mi>ln</mi><mo>(</mo>${_toMathMl(expr, decimalPlaces: decimalPlaces)}<mo>)</mo></mrow>',
  OrderTerm(:final variable, :final order, :final point) =>
    _formatOrderTermMathMl(variable, order, point, decimalPlaces),
  LambertW(:final expr, :final branch) =>
    branch == 0
        ? '<mrow><mi>W</mi><mo>(</mo>${_toMathMl(expr, decimalPlaces: decimalPlaces)}<mo>)</mo></mrow>'
        : '<mrow><msub><mi>W</mi>${_toMathMl(IntegerNumber.of(branch), decimalPlaces: decimalPlaces)}</msub><mo>(</mo>${_toMathMl(expr, decimalPlaces: decimalPlaces)}<mo>)</mo></mrow>',
  Erf(:final expr) =>
    '<mrow><mi>erf</mi><mo>(</mo>${_toMathMl(expr, decimalPlaces: decimalPlaces)}<mo>)</mo></mrow>',
  Erfc(:final expr) =>
    '<mrow><mi>erfc</mi><mo>(</mo>${_toMathMl(expr, decimalPlaces: decimalPlaces)}<mo>)</mo></mrow>',
  Gamma(:final expr) =>
    '<mrow><mi>Γ</mi><mo>(</mo>${_toMathMl(expr, decimalPlaces: decimalPlaces)}<mo>)</mo></mrow>',
  Beta(:final left, :final right) =>
    '<mrow><mi>B</mi><mo>(</mo>${_toMathMl(left, decimalPlaces: decimalPlaces)}<mo>,</mo>${_toMathMl(right, decimalPlaces: decimalPlaces)}<mo>)</mo></mrow>',
  Factorial(:final expr) =>
    '<mrow>${_formatPowBase(expr, decimalPlaces)}<mo>!</mo></mrow>',
  Binomial(:final left, :final right) =>
    '<mrow><mo>(</mo><mfrac linethickness="0">${_toMathMl(left, decimalPlaces: decimalPlaces)}${_toMathMl(right, decimalPlaces: decimalPlaces)}</mfrac><mo>)</mo></mrow>',
  Floor(:final expr) =>
    '<mrow><mo>&#x230A;</mo>${_toMathMl(expr, decimalPlaces: decimalPlaces)}<mo>&#x230B;</mo></mrow>',
  Ceil(:final expr) =>
    '<mrow><mo>&#x2308;</mo>${_toMathMl(expr, decimalPlaces: decimalPlaces)}<mo>&#x2309;</mo></mrow>',
  Round(:final expr) =>
    '<mrow><mi>round</mi><mo>(</mo>${_toMathMl(expr, decimalPlaces: decimalPlaces)}<mo>)</mo></mrow>',
  Sign(:final expr) =>
    '<mrow><mi>sgn</mi><mo>(</mo>${_toMathMl(expr, decimalPlaces: decimalPlaces)}<mo>)</mo></mrow>',
  Mod(:final left, :final right) =>
    '<mrow>${_formatMulLeft(left, decimalPlaces)}<mo>mod</mo>${_formatMulRight(right, decimalPlaces)}</mrow>',
  Re(:final expr) =>
    '<mrow><mi>Re</mi><mo>(</mo>${_toMathMl(expr, decimalPlaces: decimalPlaces)}<mo>)</mo></mrow>',
  Im(:final expr) =>
    '<mrow><mi>Im</mi><mo>(</mo>${_toMathMl(expr, decimalPlaces: decimalPlaces)}<mo>)</mo></mrow>',
  Arg(:final expr) =>
    '<mrow><mi>arg</mi><mo>(</mo>${_toMathMl(expr, decimalPlaces: decimalPlaces)}<mo>)</mo></mrow>',
  Conjugate(:final expr) =>
    '<mover><mrow>${_toMathMl(expr, decimalPlaces: decimalPlaces)}</mrow><mo>&macr;</mo></mover>',
  Asinh(:final expr) =>
    '<mrow><mi>asinh</mi><mo>(</mo>${_toMathMl(expr, decimalPlaces: decimalPlaces)}<mo>)</mo></mrow>',
  Acosh(:final expr) =>
    '<mrow><mi>acosh</mi><mo>(</mo>${_toMathMl(expr, decimalPlaces: decimalPlaces)}<mo>)</mo></mrow>',
  Atanh(:final expr) =>
    '<mrow><mi>atanh</mi><mo>(</mo>${_toMathMl(expr, decimalPlaces: decimalPlaces)}<mo>)</mo></mrow>',
  LessThan(:final left, :final right) =>
    '<mrow>${_toMathMl(left, decimalPlaces: decimalPlaces)}<mo>&lt;</mo>${_toMathMl(right, decimalPlaces: decimalPlaces)}</mrow>',
  LessEqual(:final left, :final right) =>
    '<mrow>${_toMathMl(left, decimalPlaces: decimalPlaces)}<mo>&#x2264;</mo>${_toMathMl(right, decimalPlaces: decimalPlaces)}</mrow>',
  GreaterThan(:final left, :final right) =>
    '<mrow>${_toMathMl(left, decimalPlaces: decimalPlaces)}<mo>&gt;</mo>${_toMathMl(right, decimalPlaces: decimalPlaces)}</mrow>',
  GreaterEqual(:final left, :final right) =>
    '<mrow>${_toMathMl(left, decimalPlaces: decimalPlaces)}<mo>&#x2265;</mo>${_toMathMl(right, decimalPlaces: decimalPlaces)}</mrow>',
  Equal(:final left, :final right) =>
    '<mrow>${_toMathMl(left, decimalPlaces: decimalPlaces)}<mo>=</mo>${_toMathMl(right, decimalPlaces: decimalPlaces)}</mrow>',
  NotEqual(:final left, :final right) =>
    '<mrow>${_toMathMl(left, decimalPlaces: decimalPlaces)}<mo>&#x2260;</mo>${_toMathMl(right, decimalPlaces: decimalPlaces)}</mrow>',
  Piecewise(:final branches, :final otherwise) =>
    '<mrow><mo>{</mo><mtable>'
        '${branches.map((b) => '<mtr><mtd>${_toMathMl(b.expr, decimalPlaces: decimalPlaces)}</mtd><mtd><mtext>if&#x00a0;</mtext>${_toMathMl(b.relation, decimalPlaces: decimalPlaces)}</mtd></mtr>').join()}'
        '${otherwise != null ? '<mtr><mtd>${_toMathMl(otherwise, decimalPlaces: decimalPlaces)}</mtd><mtd><mtext>otherwise</mtext></mtd></mtr>' : ''}'
        '</mtable></mrow>',
  Integral(:final integrand, :final variable, :final lower, :final upper) =>
    lower != null && upper != null
        ? '<mrow><msubsup><mo>&#x222B;</mo>${_toMathMl(lower, decimalPlaces: decimalPlaces)}${_toMathMl(upper, decimalPlaces: decimalPlaces)}</msubsup>${_toMathMl(integrand, decimalPlaces: decimalPlaces)}<mspace width="thinmathspace"/><mi>d</mi><mi>${_escapeXml(variable)}</mi></mrow>'
        : '<mrow><mo>&#x222B;</mo>${_toMathMl(integrand, decimalPlaces: decimalPlaces)}<mspace width="thinmathspace"/><mi>d</mi><mi>${_escapeXml(variable)}</mi></mrow>',
  Derivative(:final expr, :final variable, :final order, :final point) => () {
    final vXml = _escapeXml(variable);
    final diffOp = order == 1
        ? '<mfrac><mi>d</mi><mrow><mi>d</mi><mi>$vXml</mi></mrow></mfrac>'
        : '<mfrac><msup><mi>d</mi><mn>$order</mn></msup><mrow><mi>d</mi><msup><mi>$vXml</mi><mn>$order</mn></msup></mrow></mfrac>';
    final base = '<mrow>$diffOp${_formatMulRight(expr, decimalPlaces)}</mrow>';
    if (point != null) {
      return '<mrow><msub><mrow><mo>|</mo>$base</mrow><mrow><mi>$vXml</mi><mo>=</mo>${_toMathMl(point, decimalPlaces: decimalPlaces)}</mrow></msub></mrow>';
    }
    return base;
  }(),
  Limit(:final expr, :final variable, :final point, :final direction) => () {
    final vXml = _escapeXml(variable);
    final ptMathMl = switch (direction) {
      LimitDirection.both => _toMathMl(point, decimalPlaces: decimalPlaces),
      LimitDirection.fromAbove =>
        '<msup>${_toMathMl(point, decimalPlaces: decimalPlaces)}<mo>+</mo></msup>',
      LimitDirection.fromBelow =>
        '<msup>${_toMathMl(point, decimalPlaces: decimalPlaces)}<mo>&minus;</mo></msup>',
    };
    return '<mrow><munder><mo>lim</mo><mrow><mi>$vXml</mi><mo>&#x2192;</mo>$ptMathMl</mrow></munder>${_formatMulRight(expr, decimalPlaces)}</mrow>';
  }(),
  Sum(:final expr, :final variable, :final lower, :final upper) =>
    '<mrow><munderover><mo>&#x2211;</mo><mrow><mi>${_escapeXml(variable)}</mi><mo>=</mo>${_toMathMl(lower, decimalPlaces: decimalPlaces)}</mrow>${_toMathMl(upper, decimalPlaces: decimalPlaces)}</munderover>${_formatMulRight(expr, decimalPlaces)}</mrow>',
  Product(:final expr, :final variable, :final lower, :final upper) =>
    '<mrow><munderover><mo>&#x220F;</mo><mrow><mi>${_escapeXml(variable)}</mi><mo>=</mo>${_toMathMl(lower, decimalPlaces: decimalPlaces)}</mrow>${_toMathMl(upper, decimalPlaces: decimalPlaces)}</munderover>${_formatMulRight(expr, decimalPlaces)}</mrow>',
};

String _formatComplexMathMl(ComplexNumber c, int? decimalPlaces) {
  final real = c.real;
  final imag = c.imaginary;
  if (real.isZero) {
    if (imag.isOne) return '<mi>i</mi>';
    if (imag.isNegativeOne) {
      return '<mrow><mo form="prefix">&minus;</mo><mi>i</mi></mrow>';
    }
    if (imag.isNegative) {
      return '<mrow><mo form="prefix">&minus;</mo>${_toMathMl(imag.neg(), decimalPlaces: decimalPlaces)}<mi>i</mi></mrow>';
    }
    return '<mrow>${_toMathMl(imag, decimalPlaces: decimalPlaces)}<mi>i</mi></mrow>';
  }
  final realStr = _toMathMl(real, decimalPlaces: decimalPlaces);
  if (imag.isOne) return '<mrow>$realStr<mo>+</mo><mi>i</mi></mrow>';
  if (imag.isNegativeOne) {
    return '<mrow>$realStr<mo>&minus;</mo><mi>i</mi></mrow>';
  }
  if (imag.isNegative) {
    final posImag = imag.neg();
    return '<mrow>$realStr<mo>&minus;</mo><mrow>${_toMathMl(posImag, decimalPlaces: decimalPlaces)}<mi>i</mi></mrow></mrow>';
  }
  return '<mrow>$realStr<mo>+</mo><mrow>${_toMathMl(imag, decimalPlaces: decimalPlaces)}<mi>i</mi></mrow></mrow>';
}

String _formatAddMathMl(List<Expr> terms, int? decimalPlaces) {
  switch (terms) {
    case []:
      return '<mn>0</mn>';
    case [final single]:
      return _toMathMl(single, decimalPlaces: decimalPlaces);
    default:
      final buffer = StringBuffer('<mrow>')
        ..write(_toMathMl(terms.first, decimalPlaces: decimalPlaces));
      for (var i = 1; i < terms.length; i++) {
        final term = terms[i];
        if (stripLeadingNegative(term) case final stripped?) {
          buffer
            ..write('<mo>&minus;</mo>')
            ..write(_formatSubRight(stripped, decimalPlaces));
        } else {
          buffer
            ..write('<mo>+</mo>')
            ..write(_toMathMl(term, decimalPlaces: decimalPlaces));
        }
      }
      buffer.write('</mrow>');
      return buffer.toString();
  }
}

String _formatMulMathMl(List<Expr> factors, int? decimalPlaces) {
  switch (factors) {
    case []:
      return '<mn>1</mn>';
    case [final single]:
      return _toMathMl(single, decimalPlaces: decimalPlaces);
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
            ? '<mrow><mo form="prefix">&minus;</mo>$frac</mrow>'
            : frac;
      }
      return _formatMulProductMathMl(factors, decimalPlaces);
  }
}

String _formatMulProductMathMl(List<Expr> factors, int? decimalPlaces) {
  switch (factors) {
    case []:
      return '<mn>1</mn>';
    case [final single]:
      return _toMathMl(single, decimalPlaces: decimalPlaces);
    case [IntegerNumber(isNegativeOne: true), ...final rest]:
      final operand = switch (rest) {
        [final single] => single,
        _ => Mul(rest),
      };
      return '<mrow><mo form="prefix">&minus;</mo>${_formatNegOperand(operand, decimalPlaces)}</mrow>';
    default:
      final buffer = StringBuffer('<mrow>');
      var firstFactor = factors.first;
      if (firstFactor case final RealNumeric n when n.isNegative) {
        buffer.write('<mo form="prefix">&minus;</mo>');
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
  int? decimalPlaces,
) {
  final isZero = point is Number && point.isZero;
  if (isZero) {
    if (order == 0) {
      return '<mrow><mi>O</mi><mo>(</mo><mn>1</mn><mo>)</mo></mrow>';
    }
    if (order == 1) {
      return '<mrow><mi>O</mi><mo>(</mo><mi>${_escapeXml(variable)}</mi><mo>)</mo></mrow>';
    }
    return '<mrow><mi>O</mi><mo>(</mo><msup><mi>${_escapeXml(variable)}</mi><mn>$order</mn></msup><mo>)</mo></mrow>';
  }
  if (order == 1) {
    return '<mrow><mi>O</mi><mo>(</mo><mrow><mi>${_escapeXml(variable)}</mi><mo>&minus;</mo>${_formatSubRight(point, decimalPlaces)}</mrow><mo>)</mo></mrow>';
  }
  return '<mrow><mi>O</mi><mo>(</mo><msup><mrow><mo>(</mo><mrow><mi>${_escapeXml(variable)}</mi><mo>&minus;</mo>${_formatSubRight(point, decimalPlaces)}</mrow><mo>)</mo></mrow><mn>$order</mn></msup><mo>)</mo></mrow>';
}

String _formatPow(Expr base, Expr exponent, int? decimalPlaces) {
  if (base == Constant.e) {
    return '<msup><mi>e</mi>${_toMathMl(exponent, decimalPlaces: decimalPlaces)}</msup>';
  }
  if (exponent == IntegerNumber.negativeOne) {
    return '<mfrac><mn>1</mn>${_toMathMl(base, decimalPlaces: decimalPlaces)}</mfrac>';
  }
  if (exponent case RationalNumber(:final numerator, :final denominator)
      when numerator == Integer.one) {
    if (denominator == Integer.two) {
      return '<msqrt><mrow>${_toMathMl(base, decimalPlaces: decimalPlaces)}</mrow></msqrt>';
    } else if (denominator > Integer.two) {
      return '<mroot><mrow>${_toMathMl(base, decimalPlaces: decimalPlaces)}</mrow><mn>$denominator</mn></mroot>';
    }
  }
  if (matchFunctionPower(base, exponent) case (
    :final name,
    :final argument,
    latexCmd: _,
  )) {
    return '<mrow><msup><mi>$name</mi>${_toMathMl(exponent, decimalPlaces: decimalPlaces)}</msup><mo>(</mo>${_toMathMl(argument, decimalPlaces: decimalPlaces)}<mo>)</mo></mrow>';
  }
  return '<msup>${_formatPowBase(base, decimalPlaces)}${_toMathMl(exponent, decimalPlaces: decimalPlaces)}</msup>';
}

String _formatSubRight(Expr right, int? decimalPlaces) =>
    needsSubRightParens(right)
    ? '<mrow><mo>(</mo>${_toMathMl(right, decimalPlaces: decimalPlaces)}<mo>)</mo></mrow>'
    : _toMathMl(right, decimalPlaces: decimalPlaces);

String _formatMulLeft(Expr left, int? decimalPlaces) => needsMulLeftParens(left)
    ? '<mrow><mo>(</mo>${_toMathMl(left, decimalPlaces: decimalPlaces)}<mo>)</mo></mrow>'
    : _toMathMl(left, decimalPlaces: decimalPlaces);

String _formatMulRight(Expr right, int? decimalPlaces) =>
    needsMulRightParens(right)
    ? '<mrow><mo>(</mo>${_toMathMl(right, decimalPlaces: decimalPlaces)}<mo>)</mo></mrow>'
    : _toMathMl(right, decimalPlaces: decimalPlaces);

String _formatPowBase(Expr base, int? decimalPlaces) => needsPowBaseParens(base)
    ? '<mrow><mo>(</mo>${_toMathMl(base, decimalPlaces: decimalPlaces)}<mo>)</mo></mrow>'
    : _toMathMl(base, decimalPlaces: decimalPlaces);

String _formatNegOperand(Expr expr, int? decimalPlaces) =>
    needsNegOperandParens(expr)
    ? '<mrow><mo>(</mo>${_toMathMl(expr, decimalPlaces: decimalPlaces)}<mo>)</mo></mrow>'
    : _toMathMl(expr, decimalPlaces: decimalPlaces);

String _escapeXml(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
