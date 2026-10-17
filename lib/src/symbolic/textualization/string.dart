import '../ast.dart';
import 'formatting.dart';

/// Formats the symbolic [expr] into a clean mathematical string representation
/// with minimal parentheses based on operator precedence and associativity.
///
/// ```dart
/// final x = Variable('x');
/// final str = formatExpr(x * x + 1); // 'x * x + 1'
/// ```
String formatExpr(Expr expr, [int parentPrec = 0]) {
  final prec = precedence(expr);
  final formatted = switch (expr) {
    Variable(:final name) => name,
    Constant(:final name) => name,
    IntegerNumber(:final value) => '$value',
    FractionNumber(:final numerator, :final denominator) =>
      '$numerator/$denominator',
    RealNumber(:final value) => '$value',
    ComplexNumber() => _formatComplex(expr),
    Sin(:final expr) => 'sin(${formatExpr(expr)})',
    Cos(:final expr) => 'cos(${formatExpr(expr)})',
    Tan(:final expr) => 'tan(${formatExpr(expr)})',
    Asin(:final expr) => 'asin(${formatExpr(expr)})',
    Acos(:final expr) => 'acos(${formatExpr(expr)})',
    Atan(:final expr) => 'atan(${formatExpr(expr)})',
    Sinh(:final expr) => 'sinh(${formatExpr(expr)})',
    Cosh(:final expr) => 'cosh(${formatExpr(expr)})',
    Tanh(:final expr) => 'tanh(${formatExpr(expr)})',
    Abs(:final expr) => 'abs(${formatExpr(expr)})',
    Ln(:final expr) => 'ln(${formatExpr(expr)})',
    Pow(:final base, :final exponent) => _formatPow(base, exponent),
    Mul(:final factors) => _formatMul(factors),
    Add(:final terms) => _formatAdd(terms),
    OrderTerm(:final variable, :final order, :final point) => _formatOrderTerm(
      variable,
      order,
      point,
    ),
    LambertW(:final expr, :final branch) =>
      branch == 0
          ? 'LambertW(${formatExpr(expr)})'
          : 'LambertW(${formatExpr(expr)}, $branch)',
    Erf(:final expr) => 'erf(${formatExpr(expr)})',
    Erfc(:final expr) => 'erfc(${formatExpr(expr)})',
    Gamma(:final expr) => 'gamma(${formatExpr(expr)})',
    Beta(:final left, :final right) =>
      'beta(${formatExpr(left)}, ${formatExpr(right)})',
    Asinh(:final expr) => 'asinh(${formatExpr(expr)})',
    Acosh(:final expr) => 'acosh(${formatExpr(expr)})',
    Atanh(:final expr) => 'atanh(${formatExpr(expr)})',
    LessThan(:final left, :final right) =>
      '${formatExpr(left, 1)} < ${formatExpr(right, 1)}',
    LessEqual(:final left, :final right) =>
      '${formatExpr(left, 1)} <= ${formatExpr(right, 1)}',
    GreaterThan(:final left, :final right) =>
      '${formatExpr(left, 1)} > ${formatExpr(right, 1)}',
    GreaterEqual(:final left, :final right) =>
      '${formatExpr(left, 1)} >= ${formatExpr(right, 1)}',
    Equal(:final left, :final right) =>
      '${formatExpr(left, 1)} == ${formatExpr(right, 1)}',
    Piecewise(:final branches, :final otherwise) =>
      'Piecewise([${branches.map((b) => '(${formatExpr(b.$1)}, ${formatExpr(b.$2)})').join(', ')}]'
          '${otherwise != null ? ', otherwise: ${formatExpr(otherwise)}' : ''})',
    Integral(:final integrand, :final variable, :final lower, :final upper) =>
      lower != null && upper != null
          ? 'integrate(${formatExpr(integrand)}, $variable, ${formatExpr(lower)}, ${formatExpr(upper)})'
          : 'integrate(${formatExpr(integrand)}, $variable)',
  };
  return prec < parentPrec ? '($formatted)' : formatted;
}

String _formatComplex(ComplexNumber c) {
  final real = c.real;
  final imag = c.imaginary;
  if (real.isZero) {
    if (imag.isOne) return 'i';
    if (imag.isNegativeOne) return '-i';
    return '${formatExpr(imag, 2)} * i';
  }
  final realStr = formatExpr(real, 1);
  if (imag.isOne) return '$realStr + i';
  if (imag.isNegativeOne) return '$realStr - i';
  if (imag.isNegative) {
    return '$realStr - ${formatExpr(imag.neg(), 2)} * i';
  }
  return '$realStr + ${formatExpr(imag, 2)} * i';
}

String _formatPow(Expr base, Expr exponent) {
  if (base == Constant.e) {
    return 'exp(${formatExpr(exponent)})';
  }
  if (exponent == IntegerNumber.negativeOne) {
    return '1 / ${formatExpr(base, 3)}';
  }
  if (exponent is FractionNumber &&
      exponent.numerator == Integer.one &&
      exponent.denominator == Integer.two) {
    return 'sqrt(${formatExpr(base)})';
  }
  return '${formatExpr(base, 5)} ^ ${formatExpr(exponent, 4)}';
}

String _formatAdd(List<Expr> terms) {
  if (terms.isEmpty) return '0';
  if (terms.length == 1) return formatExpr(terms.first);
  final buffer = StringBuffer(formatExpr(terms.first, 1));
  for (var i = 1; i < terms.length; i++) {
    final term = terms[i];
    final stripped = stripLeadingNegative(term);
    if (stripped != null) {
      buffer.write(' - ${formatExpr(stripped, 2)}');
    } else {
      final prec = term is Add ? 2 : 1;
      buffer.write(' + ${formatExpr(term, prec)}');
    }
  }
  return buffer.toString();
}

String _formatMul(List<Expr> factors) {
  if (factors.isEmpty) return '1';
  if (factors.length == 1) return formatExpr(factors.first);

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
    final numStr = numFactors.isEmpty
        ? '1'
        : _formatMulNumerator(numFactors, 2);
    if (denFactors.length == 1) {
      return '$numStr / ${formatExpr(denFactors.first, 3)}';
    }
    return '$numStr / (${_formatMulNumerator(denFactors, 0)})';
  }

  return _formatMulNumerator(numFactors, 0);
}

String _formatMulNumerator(List<Expr> factors, int parentPrec) {
  if (factors.isEmpty) return '1';
  if (factors.length == 1) return formatExpr(factors.first, parentPrec);

  if (factors.first == IntegerNumber.negativeOne) {
    final rest = factors.length == 2 ? factors[1] : Mul(factors.sublist(1));
    final formatted = '-${formatExpr(rest, 4)}';
    return 3 < parentPrec ? '($formatted)' : formatted;
  }

  final parts = <String>[];
  for (var i = 0; i < factors.length; i++) {
    final f = factors[i];
    if (i > 0 && f == IntegerNumber.negativeOne && i + 1 < factors.length) {
      final next = factors[i + 1];
      parts.add(formatExpr(Mul([IntegerNumber.negativeOne, next]), 2));
      i++;
    } else {
      final reqPrec = (i > 0 && f is Mul && !_isUnaryNegMul(f)) ? 3 : 2;
      parts.add(formatExpr(f, reqPrec));
    }
  }
  final formatted = parts.join(' * ');
  return 2 < parentPrec ? '($formatted)' : formatted;
}

bool _isUnaryNegMul(Mul expr) =>
    expr.factors.isNotEmpty && expr.factors.first == IntegerNumber.negativeOne;

String _formatOrderTerm(String variable, int order, Expr point) {
  final isZero = point is Number && point.isZero;
  if (isZero) {
    if (order == 0) return 'O(1)';
    if (order == 1) return 'O($variable)';
    return 'O($variable^$order)';
  }
  final delta = formatExpr(Variable(variable) - point);
  if (order == 1) return 'O($delta)';
  return 'O(($delta)^$order)';
}

/// Returns the operator precedence level for the given [expr].
///
/// Higher values indicate tighter binding.
int precedence(Expr expr) => switch (expr) {
  RelationalExpr() => 0,
  Piecewise() => 0,
  Add() => 1,
  ComplexNumber(:final real, :final imaginary) =>
    !real.isZero
        ? 1
        : imaginary.isOne
        ? 5
        : imaginary.isNegativeOne
        ? 3
        : 2,
  Mul(:final factors) => _mulPrecedence(factors),
  FractionNumber() => 2,
  IntegerNumber(isNegative: true) || RealNumber(isNegative: true) => 3,
  Pow(:final base, :final exponent) =>
    base == Constant.e
        ? 5
        : exponent == IntegerNumber.negativeOne
        ? 2
        : exponent is FractionNumber &&
              exponent.numerator == Integer.one &&
              exponent.denominator == Integer.two
        ? 5
        : 4,
  _ => 5,
};

int _mulPrecedence(List<Expr> factors) {
  if (factors.isEmpty) return 5;
  for (final f in factors) {
    if (f is Pow &&
        f.exponent is IntegerNumber &&
        (f.exponent as IntegerNumber).isNegative) {
      return 2;
    }
  }
  if (factors.first == IntegerNumber.negativeOne) {
    return 3;
  }
  return 2;
}
