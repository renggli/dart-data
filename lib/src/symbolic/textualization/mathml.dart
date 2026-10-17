import '../ast.dart';
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
  /// ```dart
  /// final x = Variable('x');
  /// final mathml = (x / (x + 1)).toMathMl();
  /// // '<math><mfrac><mi>x</mi><mrow><mi>x</mi><mo>+</mo><mn>1</mn></mrow></mfrac></math>'
  /// ```
  String toMathMl({bool display = false, bool root = true}) {
    final inner = _toMathMl(this);
    if (!root) return inner;
    final attr = display ? ' display="block"' : '';
    return '<math$attr>$inner</math>';
  }
}

String _toMathMl(Expr expr) => switch (expr) {
  Variable(:final name) => '<mi>${_escapeXml(name)}</mi>',
  VariableFunction(:final name, :final arguments) =>
    '<mrow><mi>${_escapeXml(name)}</mi><mo>(</mo>${arguments.map(_toMathMl).join('<mo>,</mo>')}<mo>)</mo></mrow>',
  Constant(:final mathMl) => mathMl,
  IntegerNumber(:final value) =>
    value.isNegative
        ? '<mrow><mo form="prefix">&minus;</mo><mn>${-value}</mn></mrow>'
        : '<mn>$value</mn>',
  FractionNumber(:final numerator, :final denominator) =>
    numerator.isNegative
        ? '<mrow><mo form="prefix">&minus;</mo><mfrac><mn>${-numerator}</mn><mn>$denominator</mn></mfrac></mrow>'
        : '<mfrac><mn>$numerator</mn><mn>$denominator</mn></mfrac>',
  RealNumber(:final value) =>
    value < 0
        ? '<mrow><mo form="prefix">&minus;</mo><mn>${-value}</mn></mrow>'
        : '<mn>$value</mn>',
  ComplexNumber() => _formatComplexMathMl(expr),
  Add(:final terms) => _formatAddMathMl(terms),
  Mul(:final factors) => _formatMulMathMl(factors),
  Pow(:final base, :final exponent) => _formatPow(base, exponent),
  Sin(:final expr) =>
    '<mrow><mi>sin</mi><mo>(</mo>${_toMathMl(expr)}<mo>)</mo></mrow>',
  Cos(:final expr) =>
    '<mrow><mi>cos</mi><mo>(</mo>${_toMathMl(expr)}<mo>)</mo></mrow>',
  Tan(:final expr) =>
    '<mrow><mi>tan</mi><mo>(</mo>${_toMathMl(expr)}<mo>)</mo></mrow>',
  Asin(:final expr) =>
    '<mrow><mi>arcsin</mi><mo>(</mo>${_toMathMl(expr)}<mo>)</mo></mrow>',
  Acos(:final expr) =>
    '<mrow><mi>arccos</mi><mo>(</mo>${_toMathMl(expr)}<mo>)</mo></mrow>',
  Atan(:final expr) =>
    '<mrow><mi>arctan</mi><mo>(</mo>${_toMathMl(expr)}<mo>)</mo></mrow>',
  Sinh(:final expr) =>
    '<mrow><mi>sinh</mi><mo>(</mo>${_toMathMl(expr)}<mo>)</mo></mrow>',
  Cosh(:final expr) =>
    '<mrow><mi>cosh</mi><mo>(</mo>${_toMathMl(expr)}<mo>)</mo></mrow>',
  Tanh(:final expr) =>
    '<mrow><mi>tanh</mi><mo>(</mo>${_toMathMl(expr)}<mo>)</mo></mrow>',
  Abs(:final expr) => '<mrow><mo>|</mo>${_toMathMl(expr)}<mo>|</mo></mrow>',
  Ln(:final expr) =>
    '<mrow><mi>ln</mi><mo>(</mo>${_toMathMl(expr)}<mo>)</mo></mrow>',
  OrderTerm(:final variable, :final order, :final point) =>
    _formatOrderTermMathMl(variable, order, point),
  LambertW(:final expr, :final branch) =>
    branch == 0
        ? '<mrow><mi>W</mi><mo>(</mo>${_toMathMl(expr)}<mo>)</mo></mrow>'
        : '<mrow><msub><mi>W</mi>${_toMathMl(IntegerNumber.of(branch))}</msub><mo>(</mo>${_toMathMl(expr)}<mo>)</mo></mrow>',
  Erf(:final expr) =>
    '<mrow><mi>erf</mi><mo>(</mo>${_toMathMl(expr)}<mo>)</mo></mrow>',
  Erfc(:final expr) =>
    '<mrow><mi>erfc</mi><mo>(</mo>${_toMathMl(expr)}<mo>)</mo></mrow>',
  Gamma(:final expr) =>
    '<mrow><mi>Γ</mi><mo>(</mo>${_toMathMl(expr)}<mo>)</mo></mrow>',
  Beta(:final left, :final right) =>
    '<mrow><mi>B</mi><mo>(</mo>${_toMathMl(left)}<mo>,</mo>${_toMathMl(right)}<mo>)</mo></mrow>',
  Asinh(:final expr) =>
    '<mrow><mi>asinh</mi><mo>(</mo>${_toMathMl(expr)}<mo>)</mo></mrow>',
  Acosh(:final expr) =>
    '<mrow><mi>acosh</mi><mo>(</mo>${_toMathMl(expr)}<mo>)</mo></mrow>',
  Atanh(:final expr) =>
    '<mrow><mi>atanh</mi><mo>(</mo>${_toMathMl(expr)}<mo>)</mo></mrow>',
  LessThan(:final left, :final right) =>
    '<mrow>${_toMathMl(left)}<mo>&lt;</mo>${_toMathMl(right)}</mrow>',
  LessEqual(:final left, :final right) =>
    '<mrow>${_toMathMl(left)}<mo>&#x2264;</mo>${_toMathMl(right)}</mrow>',
  GreaterThan(:final left, :final right) =>
    '<mrow>${_toMathMl(left)}<mo>&gt;</mo>${_toMathMl(right)}</mrow>',
  GreaterEqual(:final left, :final right) =>
    '<mrow>${_toMathMl(left)}<mo>&#x2265;</mo>${_toMathMl(right)}</mrow>',
  Equal(:final left, :final right) =>
    '<mrow>${_toMathMl(left)}<mo>=</mo>${_toMathMl(right)}</mrow>',
  NotEqual(:final left, :final right) =>
    '<mrow>${_toMathMl(left)}<mo>&#x2260;</mo>${_toMathMl(right)}</mrow>',
  Piecewise(:final branches, :final otherwise) =>
    '<mrow><mo>{</mo><mtable>'
        '${branches.map((b) => '<mtr><mtd>${_toMathMl(b.expr)}</mtd><mtd><mtext>if&#x00a0;</mtext>${_toMathMl(b.relation)}</mtd></mtr>').join()}'
        '${otherwise != null ? '<mtr><mtd>${_toMathMl(otherwise)}</mtd><mtd><mtext>otherwise</mtext></mtd></mtr>' : ''}'
        '</mtable></mrow>',
  Integral(:final integrand, :final variable, :final lower, :final upper) =>
    lower != null && upper != null
        ? '<mrow><msubsup><mo>&#x222B;</mo>${_toMathMl(lower)}${_toMathMl(upper)}</msubsup>${_toMathMl(integrand)}<mspace width="thinmathspace"/><mi>d</mi><mi>${_escapeXml(variable)}</mi></mrow>'
        : '<mrow><mo>&#x222B;</mo>${_toMathMl(integrand)}<mspace width="thinmathspace"/><mi>d</mi><mi>${_escapeXml(variable)}</mi></mrow>',
};

String _formatComplexMathMl(ComplexNumber c) {
  final real = c.real;
  final imag = c.imaginary;
  if (real.isZero) {
    if (imag.isOne) return '<mi>i</mi>';
    if (imag.isNegativeOne) {
      return '<mrow><mo form="prefix">&minus;</mo><mi>i</mi></mrow>';
    }
    if (imag.isNegative) {
      return '<mrow><mo form="prefix">&minus;</mo>${_toMathMl(imag.neg())}<mi>i</mi></mrow>';
    }
    return '<mrow>${_toMathMl(imag)}<mi>i</mi></mrow>';
  }
  final realStr = _toMathMl(real);
  if (imag.isOne) return '<mrow>$realStr<mo>+</mo><mi>i</mi></mrow>';
  if (imag.isNegativeOne) {
    return '<mrow>$realStr<mo>&minus;</mo><mi>i</mi></mrow>';
  }
  if (imag.isNegative) {
    final posImag = imag.neg();
    return '<mrow>$realStr<mo>&minus;</mo><mrow>${_toMathMl(posImag)}<mi>i</mi></mrow></mrow>';
  }
  return '<mrow>$realStr<mo>+</mo><mrow>${_toMathMl(imag)}<mi>i</mi></mrow></mrow>';
}

String _formatAddMathMl(List<Expr> terms) {
  switch (terms) {
    case []:
      return '<mn>0</mn>';
    case [final single]:
      return _toMathMl(single);
    default:
      final buffer = StringBuffer('<mrow>')..write(_toMathMl(terms.first));
      for (var i = 1; i < terms.length; i++) {
        final term = terms[i];
        if (stripLeadingNegative(term) case final stripped?) {
          buffer
            ..write('<mo>&minus;</mo>')
            ..write(_formatSubRight(stripped));
        } else {
          buffer
            ..write('<mo>+</mo>')
            ..write(_toMathMl(term));
        }
      }
      buffer.write('</mrow>');
      return buffer.toString();
  }
}

String _formatMulMathMl(List<Expr> factors) {
  switch (factors) {
    case []:
      return '<mn>1</mn>';
    case [final single]:
      return _toMathMl(single);
    default:
      final (:isNegative, :numerator, :denominator) = partitionMulFraction(
        factors,
      );
      if (denominator.isNotEmpty) {
        final numMathMl = numerator.isEmpty
            ? '<mn>1</mn>'
            : _formatMulProductMathMl(numerator);
        final denMathMl = _formatMulProductMathMl(denominator);
        final frac = '<mfrac>$numMathMl$denMathMl</mfrac>';
        return isNegative
            ? '<mrow><mo form="prefix">&minus;</mo>$frac</mrow>'
            : frac;
      }
      return _formatMulProductMathMl(factors);
  }
}

String _formatMulProductMathMl(List<Expr> factors) {
  switch (factors) {
    case []:
      return '<mn>1</mn>';
    case [final single]:
      return _toMathMl(single);
    case [IntegerNumber(isNegativeOne: true), ...final rest]:
      final operand = switch (rest) {
        [final single] => single,
        _ => Mul(rest),
      };
      return '<mrow><mo form="prefix">&minus;</mo>${_formatNegOperand(operand)}</mrow>';
    default:
      final buffer = StringBuffer('<mrow>');
      var firstFactor = factors.first;
      if (firstFactor case final RealNumeric n when n.isNegative) {
        buffer.write('<mo form="prefix">&minus;</mo>');
        firstFactor = n.neg();
      }
      buffer.write(_formatMulLeft(firstFactor));

      for (var i = 1; i < factors.length; i++) {
        final prev = i == 1 ? firstFactor : factors[i - 1];
        final curr = factors[i];
        final sep = canOmitMulDot(prev, curr)
            ? '<mspace width="0.167em"/>'
            : '<mo>&#x22c5;</mo>';
        buffer
          ..write(sep)
          ..write(_formatMulRight(curr));
      }
      buffer.write('</mrow>');
      return buffer.toString();
  }
}

String _formatOrderTermMathMl(String variable, int order, Expr point) {
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
    return '<mrow><mi>O</mi><mo>(</mo><mrow><mi>${_escapeXml(variable)}</mi><mo>&minus;</mo>${_formatSubRight(point)}</mrow><mo>)</mo></mrow>';
  }
  return '<mrow><mi>O</mi><mo>(</mo><msup><mrow><mo>(</mo><mrow><mi>${_escapeXml(variable)}</mi><mo>&minus;</mo>${_formatSubRight(point)}</mrow><mo>)</mo></mrow><mn>$order</mn></msup><mo>)</mo></mrow>';
}

String _formatPow(Expr base, Expr exponent) {
  if (base == Constant.e) {
    return '<msup><mi>e</mi>${_toMathMl(exponent)}</msup>';
  }
  if (exponent == IntegerNumber.negativeOne) {
    return '<mfrac><mn>1</mn>${_toMathMl(base)}</mfrac>';
  }
  if (exponent case RationalNumber(:final numerator, :final denominator)
      when numerator == Integer.one) {
    if (denominator == Integer.two) {
      return '<mroot><mrow>${_toMathMl(base)}</mrow></mroot>';
    } else if (denominator > Integer.two) {
      return '<mroot><mrow>${_toMathMl(base)}</mrow><mn>$denominator</mn></mroot>';
    }
  }
  if (matchFunctionPower(base, exponent) case (
    :final name,
    :final argument,
    latexCmd: _,
  )) {
    return '<mrow><msup><mi>$name</mi>${_toMathMl(exponent)}</msup><mo>(</mo>${_toMathMl(argument)}<mo>)</mo></mrow>';
  }
  return '<msup>${_formatPowBase(base)}${_toMathMl(exponent)}</msup>';
}

String _formatSubRight(Expr right) => needsSubRightParens(right)
    ? '<mrow><mo>(</mo>${_toMathMl(right)}<mo>)</mo></mrow>'
    : _toMathMl(right);

String _formatMulLeft(Expr left) => needsMulLeftParens(left)
    ? '<mrow><mo>(</mo>${_toMathMl(left)}<mo>)</mo></mrow>'
    : _toMathMl(left);

String _formatMulRight(Expr right) => needsMulRightParens(right)
    ? '<mrow><mo>(</mo>${_toMathMl(right)}<mo>)</mo></mrow>'
    : _toMathMl(right);

String _formatPowBase(Expr base) => needsPowBaseParens(base)
    ? '<mrow><mo>(</mo>${_toMathMl(base)}<mo>)</mo></mrow>'
    : _toMathMl(base);

String _formatNegOperand(Expr expr) => needsNegOperandParens(expr)
    ? '<mrow><mo>(</mo>${_toMathMl(expr)}<mo>)</mo></mrow>'
    : _toMathMl(expr);

String _escapeXml(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
