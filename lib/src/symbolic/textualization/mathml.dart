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
  Constant(:final mathMl) => mathMl,
  IntegerNumber(:final value) =>
    value.isNegative
        ? '<mrow><mo>−</mo><mn>${-value}</mn></mrow>'
        : '<mn>$value</mn>',
  FractionNumber(:final numerator, :final denominator) =>
    numerator.isNegative
        ? '<mrow><mo>−</mo><mfrac><mn>${-numerator}</mn><mn>$denominator</mn></mfrac></mrow>'
        : '<mfrac><mn>$numerator</mn><mn>$denominator</mn></mfrac>',
  RealNumber(:final value) =>
    value < 0 ? '<mrow><mo>−</mo><mn>${-value}</mn></mrow>' : '<mn>$value</mn>',
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
  Piecewise(:final branches, :final otherwise) =>
    '<mrow><mo>{</mo><mtable>'
        '${branches.map((b) => '<mtr><mtd>${_toMathMl(b.$2)}</mtd><mtd><mtext>if&#x00a0;</mtext>${_toMathMl(b.$1)}</mtd></mtr>').join()}'
        '${otherwise != null ? '<mtr><mtd>${_toMathMl(otherwise)}</mtd><mtd><mtext>otherwise</mtext></mtd></mtr>' : ''}'
        '</mtable></mrow>',
};

String _formatComplexMathMl(ComplexNumber c) {
  final real = c.real;
  final imag = c.imaginary;
  if (real.isZero) {
    if (imag.isOne) return '<mi>i</mi>';
    if (imag.isNegativeOne) return '<mrow><mo>−</mo><mi>i</mi></mrow>';
    if (imag.isNegative) {
      return '<mrow><mo>−</mo>${_toMathMl(imag.neg())}<mi>i</mi></mrow>';
    }
    return '<mrow>${_toMathMl(imag)}<mi>i</mi></mrow>';
  }
  final realStr = _toMathMl(real);
  if (imag.isOne) return '<mrow>$realStr<mo>+</mo><mi>i</mi></mrow>';
  if (imag.isNegativeOne) return '<mrow>$realStr<mo>−</mo><mi>i</mi></mrow>';
  if (imag.isNegative) {
    final posImag = imag.neg();
    return '<mrow>$realStr<mo>−</mo><mrow>${_toMathMl(posImag)}<mi>i</mi></mrow></mrow>';
  }
  return '<mrow>$realStr<mo>+</mo><mrow>${_toMathMl(imag)}<mi>i</mi></mrow></mrow>';
}

String _formatAddMathMl(List<Expr> terms) {
  if (terms.isEmpty) return '<mn>0</mn>';
  if (terms.length == 1) return _toMathMl(terms.first);
  final buffer = StringBuffer('<mrow>')..write(_toMathMl(terms.first));
  for (var i = 1; i < terms.length; i++) {
    final term = terms[i];
    final stripped = _stripLeadingNegative(term);
    if (stripped != null) {
      buffer
        ..write('<mo>−</mo>')
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

Expr? _stripLeadingNegative(Expr term) {
  if (term is RealNumeric && term.isNegative) {
    return term.neg();
  }
  if (term is ComplexNumber && term.real.isZero && term.imaginary.isNegative) {
    return ComplexNumber.of(IntegerNumber.zero, term.imaginary.neg());
  }
  if (term is Mul && term.factors.isNotEmpty) {
    final first = term.factors.first;
    if (first is RealNumeric && first.isNegative) {
      final posFirst = first.neg();
      if (posFirst.isOne) {
        return term.factors.length == 2
            ? term.factors[1]
            : Mul(term.factors.sublist(1));
      }
      return Mul([posFirst, ...term.factors.skip(1)]);
    }
    if (first is ComplexNumber &&
        first.real.isZero &&
        first.imaginary.isNegative) {
      final posFirst = ComplexNumber.of(
        IntegerNumber.zero,
        first.imaginary.neg(),
      );
      return Mul([posFirst, ...term.factors.skip(1)]);
    }
  }
  return null;
}

String _formatMulMathMl(List<Expr> factors) {
  if (factors.isEmpty) return '<mn>1</mn>';
  if (factors.length == 1) return _toMathMl(factors.first);

  var isNegative = false;
  final numFactors = <Expr>[];
  final denFactors = <Expr>[];

  for (final f in factors) {
    if (f is FractionNumber) {
      if (f.isNegative) {
        isNegative = !isNegative;
      }
      final absNum = f.numerator.abs();
      if (!absNum.isOne) {
        numFactors.add(IntegerNumber(absNum));
      }
      denFactors.add(IntegerNumber(f.denominator));
      continue;
    }
    if (f is Pow && f.exponent is IntegerNumber) {
      final exp = f.exponent as IntegerNumber;
      if (exp.isNegative) {
        denFactors.add(exp.isNegativeOne ? f.base : Pow(f.base, exp.neg()));
        continue;
      }
    }
    numFactors.add(f);
  }

  if (denFactors.isNotEmpty) {
    if (numFactors.isNotEmpty &&
        numFactors.first is RealNumeric &&
        (numFactors.first as RealNumeric).isNegative) {
      isNegative = !isNegative;
      final posFirst = (numFactors.first as RealNumeric).neg();
      if (posFirst.isOne) {
        numFactors.removeAt(0);
      } else {
        numFactors[0] = posFirst;
      }
    }
    final numMathMl = numFactors.isEmpty
        ? '<mn>1</mn>'
        : _formatMulProductMathMl(numFactors);
    final denMathMl = _formatMulProductMathMl(denFactors);
    final frac = '<mfrac>$numMathMl$denMathMl</mfrac>';
    return isNegative ? '<mrow><mo>−</mo>$frac</mrow>' : frac;
  }

  return _formatMulProductMathMl(factors);
}

String _formatMulProductMathMl(List<Expr> factors) {
  if (factors.isEmpty) return '<mn>1</mn>';
  if (factors.length == 1) return _toMathMl(factors.first);

  if (factors.first == IntegerNumber.negativeOne) {
    final rest = factors.length == 2 ? factors[1] : Mul(factors.sublist(1));
    return '<mrow><mo>−</mo>${_formatNegOperand(rest)}</mrow>';
  }

  final buffer = StringBuffer('<mrow>');
  var firstFactor = factors.first;
  if (firstFactor is RealNumeric && firstFactor.isNegative) {
    buffer.write('<mo>−</mo>');
    firstFactor = firstFactor.neg();
  }
  buffer.write(_formatMulLeft(firstFactor));

  for (var i = 1; i < factors.length; i++) {
    final prev = i == 1 ? firstFactor : factors[i - 1];
    final curr = factors[i];
    final sep = _canOmitMulDot(prev, curr) ? '' : '<mo>&#x22c5;</mo>';
    buffer
      ..write(sep)
      ..write(_formatMulRight(curr));
  }
  buffer.write('</mrow>');
  return buffer.toString();
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
    return '<mrow><mi>O</mi><mo>(</mo><mrow><mi>${_escapeXml(variable)}</mi><mo>−</mo>${_formatSubRight(point)}</mrow><mo>)</mo></mrow>';
  }
  return '<mrow><mi>O</mi><mo>(</mo><msup><mrow><mo>(</mo><mrow><mi>${_escapeXml(variable)}</mi><mo>−</mo>${_formatSubRight(point)}</mrow><mo>)</mo></mrow><mn>$order</mn></msup><mo>)</mo></mrow>';
}

String _formatPow(Expr base, Expr exponent) {
  if (base == Constant.e) {
    return '<msup><mi>e</mi>${_toMathMl(exponent)}</msup>';
  }
  if (exponent == IntegerNumber.negativeOne) {
    return '<mfrac><mn>1</mn>${_toMathMl(base)}</mfrac>';
  }
  if (exponent is RationalNumber && exponent.numerator == Integer.one) {
    if (exponent.denominator == Integer.two) {
      return '<msqrt>${_toMathMl(base)}</msqrt>';
    } else if (exponent.denominator > Integer.two) {
      return '<mroot>${_toMathMl(base)}<mn>${exponent.denominator}</mn></mroot>';
    }
  }
  return '<msup>${_formatPowBase(base)}${_toMathMl(exponent)}</msup>';
}

String _formatSubRight(Expr right) => switch (right) {
  Add() => '<mrow><mo>(</mo>${_toMathMl(right)}<mo>)</mo></mrow>',
  ComplexNumber(:final real) when !real.isZero =>
    '<mrow><mo>(</mo>${_toMathMl(right)}<mo>)</mo></mrow>',
  _ when _startsWithNegative(right) =>
    '<mrow><mo>(</mo>${_toMathMl(right)}<mo>)</mo></mrow>',
  _ => _toMathMl(right),
};

String _formatMulLeft(Expr left) => switch (left) {
  Add() => '<mrow><mo>(</mo>${_toMathMl(left)}<mo>)</mo></mrow>',
  ComplexNumber(:final real) when !real.isZero =>
    '<mrow><mo>(</mo>${_toMathMl(left)}<mo>)</mo></mrow>',
  _ => _toMathMl(left),
};

String _formatMulRight(Expr right) => switch (right) {
  Add() => '<mrow><mo>(</mo>${_toMathMl(right)}<mo>)</mo></mrow>',
  ComplexNumber(:final real) when !real.isZero =>
    '<mrow><mo>(</mo>${_toMathMl(right)}<mo>)</mo></mrow>',
  _ when _startsWithNegative(right) =>
    '<mrow><mo>(</mo>${_toMathMl(right)}<mo>)</mo></mrow>',
  _ => _toMathMl(right),
};

bool _canOmitMulDot(Expr left, Expr right) {
  final l = _rightmostMulFactor(left);
  if (!_isNumericFactor(l)) return false;
  final r = _leftmostMulFactor(right);
  return switch (r) {
    RealNumeric() => false,
    ComplexNumber(:final real, :final imaginary) =>
      real.isZero && imaginary.isOne,
    _ when _startsWithNegative(r) => false,
    Pow(:final base, :final exponent) =>
      base == Constant.e ||
          (exponent != IntegerNumber.negativeOne && !_startsWithNumber(r)),
    _ => true,
  };
}

bool _isNumericFactor(Expr expr) => switch (expr) {
  RealNumeric() => true,
  _ => false,
};

bool _startsWithNegative(Expr expr) => switch (expr) {
  RealNumeric(:final isNegative) => isNegative,
  ComplexNumber(:final real, :final imaginary) =>
    real.isZero ? imaginary.isNegative : real.isNegative,
  Mul(:final factors) when factors.isNotEmpty => _startsWithNegative(
    factors.first,
  ),
  _ => false,
};

Expr _rightmostMulFactor(Expr expr) => expr is Mul && expr.factors.isNotEmpty
    ? _rightmostMulFactor(expr.factors.last)
    : expr;

Expr _leftmostMulFactor(Expr expr) => expr is Mul && expr.factors.isNotEmpty
    ? _leftmostMulFactor(expr.factors.first)
    : expr;

bool _startsWithNumber(Expr expr) => switch (expr) {
  RealNumeric() => true,
  ComplexNumber(:final real, :final imaginary) =>
    !real.isZero || !imaginary.isOne,
  Pow(:final base, :final exponent) =>
    base != Constant.e &&
        !(exponent is RationalNumber &&
            exponent.numerator == Integer.one &&
            exponent.denominator >= Integer.two) &&
        _startsWithNumber(base),
  _ => false,
};

String _formatPowBase(Expr base) => switch (base) {
  Add() || Mul() || FractionNumber() || RealNumeric(isNegative: true) =>
    '<mrow><mo>(</mo>${_toMathMl(base)}<mo>)</mo></mrow>',
  ComplexNumber(:final real, :final imaginary)
      when !real.isZero || !imaginary.isOne =>
    '<mrow><mo>(</mo>${_toMathMl(base)}<mo>)</mo></mrow>',
  Pow(:final exponent) when exponent == IntegerNumber.negativeOne =>
    '<mrow><mo>(</mo>${_toMathMl(base)}<mo>)</mo></mrow>',
  _ => _toMathMl(base),
};

String _formatNegOperand(Expr expr) => switch (expr) {
  Add() => '<mrow><mo>(</mo>${_toMathMl(expr)}<mo>)</mo></mrow>',
  ComplexNumber(:final real) when !real.isZero =>
    '<mrow><mo>(</mo>${_toMathMl(expr)}<mo>)</mo></mrow>',
  _ when _startsWithNegative(expr) =>
    '<mrow><mo>(</mo>${_toMathMl(expr)}<mo>)</mo></mrow>',
  _ => _toMathMl(expr),
};

String _escapeXml(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
