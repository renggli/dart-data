import '../ast.dart';

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
  ComplexNumber(:final real, :final imaginary) =>
    real == 0.0 && imaginary == 1.0
        ? '<mi>i</mi>'
        : real == 0.0 && imaginary == -1.0
        ? '<mrow><mo>-</mo><mi>i</mi></mrow>'
        : '<mn>${_escapeXml(expr.toString())}</mn>',
  ConstantNumber(:final name) => switch (name) {
    'pi' => '<mi>π</mi>',
    'i' => '<mi>i</mi>',
    _ => '<mi>${_escapeXml(name)}</mi>',
  },
  RationalNumber(:final numerator, :final denominator) =>
    denominator == 1
        ? '<mn>$numerator</mn>'
        : numerator < 0
        ? '<mrow><mo>-</mo><mfrac><mn>${-numerator}</mn><mn>$denominator</mn></mfrac></mrow>'
        : '<mfrac><mn>$numerator</mn><mn>$denominator</mn></mfrac>',
  RealNumber(:final value) => '<mn>$value</mn>',
  Add(:final left, :final right) =>
    '<mrow>${_toMathMl(left)}<mo>+</mo>${_toMathMl(right)}</mrow>',
  Sub(:final left, :final right) =>
    '<mrow>${_toMathMl(left)}<mo>-</mo>${_formatSubRight(right)}</mrow>',
  Mul(:final left, :final right) =>
    '<mrow>${_formatMulLeft(left)}<mo>&#x22c5;</mo>${_formatMulRight(right)}</mrow>',
  Div(:final left, :final right) =>
    '<mfrac>${_toMathMl(left)}${_toMathMl(right)}</mfrac>',
  Pow(:final base, :final exponent) => _formatPow(base, exponent),
  Neg(:final expr) => '<mrow><mo>-</mo>${_formatNegOperand(expr)}</mrow>',
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
  Exp(:final expr) => '<msup><mi>e</mi>${_toMathMl(expr)}</msup>',
  Ln(:final expr) =>
    '<mrow><mi>ln</mi><mo>(</mo>${_toMathMl(expr)}<mo>)</mo></mrow>',
  OrderTerm(:final variable, :final order, :final point) =>
    _formatOrderTermMathMl(variable, order, point),
  LambertW(:final expr, :final branch) =>
    branch == 0
        ? '<mrow><mi>W</mi><mo>(</mo>${_toMathMl(expr)}<mo>)</mo></mrow>'
        : '<mrow><msub><mi>W</mi><mn>$branch</mn></msub><mo>(</mo>${_toMathMl(expr)}<mo>)</mo></mrow>',
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
  Piecewise(:final branches, :final otherwise) =>
    '<mrow><mo>{</mo><mtable>'
        '${branches.map((b) => '<mtr><mtd>${_toMathMl(b.$2)}</mtd><mtd><mtext>if </mtext>${_toMathMl(b.$1)}</mtd></mtr>').join()}'
        '${otherwise != null ? '<mtr><mtd>${_toMathMl(otherwise)}</mtd><mtd><mtext>otherwise</mtext></mtd></mtr>' : ''}'
        '</mtable></mrow>',
};

String _formatOrderTermMathMl(String variable, int order, Expr point) {
  final isZero = point is RationalNumber && point.isZero;
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
    return '<mrow><mi>O</mi><mo>(</mo><mrow><mi>${_escapeXml(variable)}</mi><mo>-</mo>${_formatSubRight(point)}</mrow><mo>)</mo></mrow>';
  }
  return '<mrow><mi>O</mi><mo>(</mo><msup><mrow><mo>(</mo><mrow><mi>${_escapeXml(variable)}</mi><mo>-</mo>${_formatSubRight(point)}</mrow><mo>)</mo></mrow><mn>$order</mn></msup><mo>)</mo></mrow>';
}

String _formatPow(Expr base, Expr exponent) {
  if (exponent is RationalNumber && exponent.numerator == 1) {
    if (exponent.denominator == 2) {
      return '<msqrt>${_wrapMrow(_toMathMl(base))}</msqrt>';
    } else if (exponent.denominator > 2) {
      return '<mroot>${_wrapMrow(_toMathMl(base))}<mrow><mn>${exponent.denominator}</mn></mrow></mroot>';
    }
  }
  return '<msup>${_formatPowBase(base)}${_toMathMl(exponent)}</msup>';
}

String _formatSubRight(Expr right) => switch (right) {
  Add() ||
  Sub() ||
  Neg() ||
  RationalNumber(numerator: < 0) ||
  RealNumber(
    value: < 0,
  ) => '<mrow><mo>(</mo>${_toMathMl(right)}<mo>)</mo></mrow>',
  _ => _toMathMl(right),
};

String _formatMulLeft(Expr left) => switch (left) {
  Add() ||
  Sub() ||
  Neg() ||
  RationalNumber(isInteger: true, numerator: < 0) ||
  RealNumber(
    value: < 0,
  ) => '<mrow><mo>(</mo>${_toMathMl(left)}<mo>)</mo></mrow>',
  _ => _toMathMl(left),
};

String _formatMulRight(Expr right) => switch (right) {
  Add() ||
  Sub() ||
  Neg() ||
  RationalNumber(numerator: < 0) ||
  RealNumber(
    value: < 0,
  ) => '<mrow><mo>(</mo>${_toMathMl(right)}<mo>)</mo></mrow>',
  _ => _toMathMl(right),
};

String _formatPowBase(Expr base) => switch (base) {
  Add() ||
  Sub() ||
  Mul() ||
  Div() ||
  Neg() ||
  RationalNumber(numerator: < 0) ||
  RealNumber(
    value: < 0,
  ) => '<mrow><mo>(</mo>${_toMathMl(base)}<mo>)</mo></mrow>',
  _ => _toMathMl(base),
};

String _formatNegOperand(Expr expr) => switch (expr) {
  Add() ||
  Sub() ||
  Neg() ||
  RationalNumber(numerator: < 0) ||
  RealNumber(
    value: < 0,
  ) => '<mrow><mo>(</mo>${_toMathMl(expr)}<mo>)</mo></mrow>',
  _ => _toMathMl(expr),
};

String _wrapMrow(String inner) =>
    inner.startsWith('<mrow>') && inner.endsWith('</mrow>')
    ? inner
    : '<mrow>$inner</mrow>';

String _escapeXml(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
