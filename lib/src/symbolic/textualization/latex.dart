import '../ast.dart';

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
  Piecewise(:final branches, :final otherwise) =>
    '\\begin{cases} '
        '${branches.map((b) => '${_toLatex(b.$2)}, & \\text{if } ${_toLatex(b.$1)}').join(' \\\\ ')}'
        '${otherwise != null ? ' \\\\ ${_toLatex(otherwise)}, & \\text{otherwise}' : ''}'
        ' \\end{cases}',
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
  if (terms.isEmpty) return '0';
  if (terms.length == 1) return _toLatex(terms.first);
  final buffer = StringBuffer(_toLatex(terms.first));
  for (var i = 1; i < terms.length; i++) {
    final term = terms[i];
    final stripped = _stripLeadingNegative(term);
    if (stripped != null) {
      buffer.write(' - ${_formatSubRight(stripped)}');
    } else {
      buffer.write(' + ${_toLatex(term)}');
    }
  }
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

String _formatMulLatex(List<Expr> factors) {
  if (factors.isEmpty) return '1';
  if (factors.length == 1) return _toLatex(factors.first);

  final numFactors = <Expr>[];
  final denFactors = <Expr>[];

  for (final f in factors) {
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
    final numLatex = numFactors.isEmpty
        ? '1'
        : _formatMulProductLatex(numFactors);
    final denLatex = _formatMulProductLatex(denFactors);
    return '\\frac{$numLatex}{$denLatex}';
  }

  return _formatMulProductLatex(numFactors);
}

String _formatMulProductLatex(List<Expr> factors) {
  if (factors.isEmpty) return '1';
  if (factors.length == 1) return _toLatex(factors.first);

  if (factors.first == IntegerNumber.negativeOne) {
    final rest = factors.length == 2 ? factors[1] : Mul(factors.sublist(1));
    return '-${_formatNegOperand(rest)}';
  }

  final buffer = StringBuffer(_formatMulLeft(factors.first));
  for (var i = 1; i < factors.length; i++) {
    final prev = factors[i - 1];
    final curr = factors[i];
    final sep = _canOmitMulDot(prev, curr) ? ' ' : r' \cdot ';
    buffer.write('$sep${_formatMulRight(curr)}');
  }
  return buffer.toString();
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
  if (exponent is RationalNumber && exponent.numerator == Integer.one) {
    if (exponent.denominator == Integer.two) {
      return '\\sqrt{${_toLatex(base)}}';
    } else if (exponent.denominator > Integer.two) {
      return '\\sqrt[${exponent.denominator}]{${_toLatex(base)}}';
    }
  }
  return '{${_formatPowBase(base)}}^{${_toLatex(exponent)}}';
}

String _formatSubRight(Expr right) => switch (right) {
  Add() => '(${_toLatex(right)})',
  ComplexNumber(:final real) when !real.isZero => '(${_toLatex(right)})',
  _ when _startsWithNegative(right) => '(${_toLatex(right)})',
  _ => _toLatex(right),
};

String _formatMulLeft(Expr left) => switch (left) {
  Add() => '(${_toLatex(left)})',
  ComplexNumber(:final real) when !real.isZero => '(${_toLatex(left)})',
  _ => _toLatex(left),
};

String _formatMulRight(Expr right) => switch (right) {
  Add() => '(${_toLatex(right)})',
  ComplexNumber(:final real) when !real.isZero => '(${_toLatex(right)})',
  _ when _startsWithNegative(right) => '(${_toLatex(right)})',
  _ => _toLatex(right),
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
  Add() ||
  Mul() ||
  FractionNumber() ||
  RealNumeric(isNegative: true) => '(${_toLatex(base)})',
  ComplexNumber(:final real, :final imaginary)
      when !real.isZero || !imaginary.isOne =>
    '(${_toLatex(base)})',
  Pow(:final exponent) when exponent == IntegerNumber.negativeOne =>
    '(${_toLatex(base)})',
  _ => _toLatex(base),
};

String _formatNegOperand(Expr expr) => switch (expr) {
  Add() => '(${_toLatex(expr)})',
  ComplexNumber(:final real) when !real.isZero => '(${_toLatex(expr)})',
  _ when _startsWithNegative(expr) => '(${_toLatex(expr)})',
  _ => _toLatex(expr),
};
