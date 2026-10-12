import 'package:more/number.dart' show Complex;

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
  ComplexNumber(:final complex) => _formatComplexMathMl(complex),
  Add(:final left, :final right) =>
    '<mrow>${_toMathMl(left)}<mo>+</mo>${_toMathMl(right)}</mrow>',
  Sub(:final left, :final right) =>
    '<mrow>${_toMathMl(left)}<mo>-</mo>${_formatSubRight(right)}</mrow>',
  Mul(:final left, :final right) =>
    '<mrow>${_formatMulOperand(left)}<mo>&#x22c5;</mo>${_formatMulOperand(right)}</mrow>',
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
  Log(:final base, :final expr) =>
    '<mrow><msub><mi>log</mi>${_toMathMl(base)}</msub><mo>(</mo>${_toMathMl(expr)}<mo>)</mo></mrow>',
};

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

String _formatComplexMathMl(Complex c) {
  if (c.b == 0) {
    return '<mn>${_formatNum(c.a)}</mn>';
  }
  if (c.a == 0) {
    if (c.b == 1) return '<mi>i</mi>';
    if (c.b == -1) return '<mrow><mo>-</mo><mi>i</mi></mrow>';
    return '<mrow><mn>${_formatNum(c.b)}</mn><mo>&#x22c5;</mo><mi>i</mi></mrow>';
  }
  final aNode = '<mn>${_formatNum(c.a)}</mn>';
  if (c.b == 1) {
    return '<mrow>$aNode<mo>+</mo><mi>i</mi></mrow>';
  } else if (c.b == -1) {
    return '<mrow>$aNode<mo>-</mo><mi>i</mi></mrow>';
  } else if (c.b > 0) {
    return '<mrow>$aNode<mo>+</mo><mrow><mn>${_formatNum(c.b)}</mn><mo>&#x22c5;</mo><mi>i</mi></mrow></mrow>';
  } else {
    return '<mrow>$aNode<mo>-</mo><mrow><mn>${_formatNum(-c.b)}</mn><mo>&#x22c5;</mo><mi>i</mi></mrow></mrow>';
  }
}

String _formatNum(num n) {
  if (n is int) return '$n';
  if (n.truncateToDouble() == n && !n.isInfinite && !n.isNaN) {
    return '${n.toInt()}';
  }
  return '$n';
}

String _formatSubRight(Expr right) => switch (right) {
  Add() ||
  Sub() ||
  Neg() ||
  RationalNumber(numerator: < 0) ||
  RealNumber(
    value: < 0,
  ) => '<mrow><mo>(</mo>${_toMathMl(right)}<mo>)</mo></mrow>',
  ComplexNumber(:final complex)
      when (complex.a != 0 && complex.b != 0) ||
          complex.a < 0 ||
          (complex.a == 0 && complex.b < 0) =>
    '<mrow><mo>(</mo>${_toMathMl(right)}<mo>)</mo></mrow>',
  _ => _toMathMl(right),
};

String _formatMulOperand(Expr operand) => switch (operand) {
  Add() ||
  Sub() ||
  Neg() ||
  RationalNumber(numerator: < 0) ||
  RealNumber(
    value: < 0,
  ) => '<mrow><mo>(</mo>${_toMathMl(operand)}<mo>)</mo></mrow>',
  ComplexNumber(:final complex)
      when (complex.a != 0 && complex.b != 0) ||
          complex.a < 0 ||
          (complex.a == 0 && complex.b < 0) =>
    '<mrow><mo>(</mo>${_toMathMl(operand)}<mo>)</mo></mrow>',
  _ => _toMathMl(operand),
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
  ComplexNumber(:final complex)
      when (complex.b != 0 && complex != Complex.i) || complex.a < 0 =>
    '<mrow><mo>(</mo>${_toMathMl(base)}<mo>)</mo></mrow>',
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
  ComplexNumber(:final complex)
      when (complex.a != 0 && complex.b != 0) ||
          complex.a < 0 ||
          (complex.a == 0 && complex.b < 0) =>
    '<mrow><mo>(</mo>${_toMathMl(expr)}<mo>)</mo></mrow>',
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
