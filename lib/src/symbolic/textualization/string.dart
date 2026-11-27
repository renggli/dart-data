import '../ast.dart';
import 'formatting.dart';

/// Plain-text mathematical string serialization extension on [Expr].
extension TextExtension on Expr {
  /// Formats this expression into a clean mathematical string representation
  /// with minimal parentheses based on operator precedence and associativity.
  String format({int decimalPlaces = 4}) => _formatExpr(this, 0, decimalPlaces);
}

/// Returns the operator precedence level for [expr].
int precedence(Expr expr) => switch (expr) {
  Relational() || Piecewise() => 0,
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
              exponent.numerator == BigInt.one &&
              exponent.denominator == BigInt.two
        ? 5
        : 4,
  _ => 5,
};

String _formatExpr(Expr expr, int parentPrec, int decimalPlaces) {
  final prec = precedence(expr);
  final formatted = switch (expr) {
    Variable(:final name) => name,
    Constant(:final name) => name,
    IntegerNumber(:final value) => '$value',
    FractionNumber(:final numerator, :final denominator) =>
      '$numerator/$denominator',
    RealNumber(:final value) => formatDouble(value, decimalPlaces),
    ComplexNumber() => _formatComplex(expr, decimalPlaces),
    Call(:final spec, :final args) => spec.formatText(
      args,
      decimalPlaces,
      _formatExpr,
    ),
    Pow(:final base, :final exponent) => _formatPow(
      base,
      exponent,
      decimalPlaces,
    ),
    Mul(:final factors) => _formatMul(factors, decimalPlaces),
    Add(:final terms) => _formatAdd(terms, decimalPlaces),
    OrderTerm(:final variable, :final order, :final point) => _formatOrderTerm(
      variable,
      order,
      point,
      decimalPlaces,
    ),
    Relational(:final op, :final left, :final right) =>
      '${_formatExpr(left, 1, decimalPlaces)} ${op.symbol} ${_formatExpr(right, 1, decimalPlaces)}',
    Piecewise(:final branches, :final otherwise) =>
      'piecewise(${[
        for (final (:relation, :expr) in branches) ...[_formatExpr(relation, 0, decimalPlaces), _formatExpr(expr, 0, decimalPlaces)],
        if (otherwise != null) _formatExpr(otherwise, 0, decimalPlaces),
      ].join(', ')})',
    Integral(:final integrand, :final variable, :final lower, :final upper) =>
      lower != null && upper != null
          ? 'integrate(${_formatExpr(integrand, 0, decimalPlaces)}, $variable, ${_formatExpr(lower, 0, decimalPlaces)}, ${_formatExpr(upper, 0, decimalPlaces)})'
          : 'integrate(${_formatExpr(integrand, 0, decimalPlaces)}, $variable)',
    Derivative(:final expr, :final variable, :final order, :final point) =>
      point != null
          ? 'diff(${_formatExpr(expr, 0, decimalPlaces)}, $variable, $order, ${_formatExpr(point, 0, decimalPlaces)})'
          : (order == 1
                ? 'diff(${_formatExpr(expr, 0, decimalPlaces)}, $variable)'
                : 'diff(${_formatExpr(expr, 0, decimalPlaces)}, $variable, $order)'),
    Limit(:final expr, :final variable, :final point, :final direction) =>
      switch (direction) {
        LimitDirection.both =>
          'limit(${_formatExpr(expr, 0, decimalPlaces)}, $variable, ${_formatExpr(point, 0, decimalPlaces)})',
        LimitDirection.fromAbove =>
          'limit(${_formatExpr(expr, 0, decimalPlaces)}, $variable, ${_formatExpr(point, 0, decimalPlaces)}, 1)',
        LimitDirection.fromBelow =>
          'limit(${_formatExpr(expr, 0, decimalPlaces)}, $variable, ${_formatExpr(point, 0, decimalPlaces)}, -1)',
      },
    Sum(:final expr, :final variable, :final lower, :final upper) =>
      'sum(${_formatExpr(expr, 0, decimalPlaces)}, $variable, ${_formatExpr(lower, 0, decimalPlaces)}, ${_formatExpr(upper, 0, decimalPlaces)})',
    Product(:final expr, :final variable, :final lower, :final upper) =>
      'product(${_formatExpr(expr, 0, decimalPlaces)}, $variable, ${_formatExpr(lower, 0, decimalPlaces)}, ${_formatExpr(upper, 0, decimalPlaces)})',
    RootSum(:final polynomial, :final variable, :final body) =>
      'rootsum(${_formatExpr(polynomial, 0, decimalPlaces)}, $variable, ${_formatExpr(body, 0, decimalPlaces)})',
  };
  return prec < parentPrec ? '($formatted)' : formatted;
}

String _formatComplex(ComplexNumber c, int decimalPlaces) {
  final real = c.real;
  final imag = c.imaginary;
  if (real.isZero) {
    if (imag.isOne) return 'i';
    if (imag.isNegativeOne) return '-i';
    return '${_formatExpr(imag, 2, decimalPlaces)} * i';
  }
  final realStr = _formatExpr(real, 1, decimalPlaces);
  if (imag.isOne) return '$realStr + i';
  if (imag.isNegativeOne) return '$realStr - i';
  if (imag.isNegative) {
    return '$realStr - ${_formatExpr(imag.neg(), 2, decimalPlaces)} * i';
  }
  return '$realStr + ${_formatExpr(imag, 2, decimalPlaces)} * i';
}

String _formatPow(Expr base, Expr exponent, int decimalPlaces) => switch ((
  base,
  exponent,
)) {
  (Constant.e, _) => 'exp(${_formatExpr(exponent, 0, decimalPlaces)})',
  (_, IntegerNumber(isNegativeOne: true)) =>
    '1 / ${_formatExpr(base, 3, decimalPlaces)}',
  (_, FractionNumber(:final numerator, :final denominator))
      when numerator == BigInt.one && denominator == BigInt.two =>
    'sqrt(${_formatExpr(base, 0, decimalPlaces)})',
  _ =>
    '${_formatExpr(base, 5, decimalPlaces)} ^ ${_formatExpr(exponent, 4, decimalPlaces)}',
};

String _formatAdd(List<Expr> terms, int decimalPlaces) {
  switch (terms) {
    case []:
      return '0';
    case [final single]:
      return _formatExpr(single, 0, decimalPlaces);
    default:
      final buffer = StringBuffer(_formatExpr(terms.first, 1, decimalPlaces));
      for (var i = 1; i < terms.length; i++) {
        final term = terms[i];
        if (stripLeadingNegative(term) case final stripped?) {
          final inner = _formatExpr(
            stripped,
            startsWithNegative(stripped) ? 4 : 2,
            decimalPlaces,
          );
          buffer.write(' - $inner');
        } else {
          final prec = term is Add ? 2 : 1;
          buffer.write(' + ${_formatExpr(term, prec, decimalPlaces)}');
        }
      }
      return buffer.toString();
  }
}

String _formatMul(List<Expr> factors, int decimalPlaces) {
  switch (factors) {
    case []:
      return '1';
    case [final single]:
      return _formatExpr(single, 0, decimalPlaces);
    default:
      final numFactors = <Expr>[];
      final denFactors = <Expr>[];

      for (final f in factors) {
        if (f case Pow(:final base, exponent: final IntegerNumber exp)
            when exp.isNegative) {
          denFactors.add(exp.isNegativeOne ? base : Pow.raw(base, exp.neg()));
        } else {
          numFactors.add(f);
        }
      }

      if (denFactors.isNotEmpty) {
        final numStr = numFactors.isEmpty
            ? '1'
            : _formatMulNumerator(numFactors, 2, decimalPlaces);
        return switch (denFactors) {
          [final single] =>
            '$numStr / ${_formatExpr(single, 3, decimalPlaces)}',
          _ =>
            '$numStr / (${_formatMulNumerator(denFactors, 0, decimalPlaces)})',
        };
      }

      return _formatMulNumerator(numFactors, 0, decimalPlaces);
  }
}

String _formatMulNumerator(
  List<Expr> factors,
  int parentPrec,
  int decimalPlaces,
) {
  switch (factors) {
    case []:
      return '1';
    case [final single]:
      return _formatExpr(single, parentPrec, decimalPlaces);
    case [IntegerNumber(isNegativeOne: true), ...final rest]:
      final formatted = rest.length == 1
          ? '-${_formatExpr(rest.single, startsWithNegative(rest.single) ? 4 : 3, decimalPlaces)}'
          : '-${_formatExpr(rest.first, startsWithNegative(rest.first) ? 4 : 3, decimalPlaces)} * '
                '${_formatMulNumerator(rest.sublist(1), 2, decimalPlaces)}';
      final prec = rest.length == 1 ? 3 : 2;
      return prec < parentPrec ? '($formatted)' : formatted;
    default:
      final parts = <String>[];
      for (var i = 0; i < factors.length; i++) {
        final f = factors[i];
        if (i > 0 && f == IntegerNumber.negativeOne && i + 1 < factors.length) {
          final next = factors[i + 1];
          parts.add(_formatExpr(-next, 2, decimalPlaces));
          i++;
        } else {
          final reqPrec = (i > 0 && f is FractionNumber)
              ? 3
              : (i > 0 && f is Mul && !_isUnaryNegMul(f))
              ? 3
              : 2;
          parts.add(_formatExpr(f, reqPrec, decimalPlaces));
        }
      }
      final formatted = parts.join(' * ');
      return 2 < parentPrec ? '($formatted)' : formatted;
  }
}

bool _isUnaryNegMul(Mul expr) => switch (expr.factors) {
  [IntegerNumber(isNegativeOne: true), ...] => true,
  _ => false,
};

String _formatOrderTerm(
  String variable,
  int order,
  Expr point,
  int decimalPlaces,
) {
  final isZero = point is Number && point.isZero;
  if (isZero) {
    if (order == 0) return variable == 'x' ? 'O(1)' : 'O($variable, 0)';
    if (order == 1) return 'O($variable)';
    return 'O($variable^$order)';
  }
  if (order == 0) {
    return 'O($variable, 0, ${_formatExpr(point, 0, decimalPlaces)})';
  }
  final stripped = stripLeadingNegative(point);
  final delta = stripped != null
      ? '$variable + ${_formatExpr(stripped, 2, decimalPlaces)}'
      : '$variable - ${_formatExpr(point, 2, decimalPlaces)}';
  if (order == 1) return 'O($delta)';
  return 'O(($delta)^$order)';
}

int _mulPrecedence(List<Expr> factors) {
  if (factors.isEmpty) return 5;
  for (final f in factors) {
    if (f case Pow(exponent: IntegerNumber(isNegative: true))) {
      return 2;
    }
  }
  return switch (factors) {
    [IntegerNumber(isNegativeOne: true), _] => 3,
    _ => 2,
  };
}
