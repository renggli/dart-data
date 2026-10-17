part of '../ast.dart';

/// Complex-domain evaluation extension on [Expr].
extension ComplexEvaluationExtension on Expr {
  /// Evaluates this symbolic expression in the complex domain $\mathbb{C}$
  /// given complex variable bindings in [context].
  ///
  /// Throws an [ArgumentError] if any free variable in this expression is
  /// missing from [context].
  ///
  /// ```dart
  /// final z = const Variable('x') + 2 * i;
  /// final val = z.evaluateComplex({'x': const Complex(3, 1)}); // Complex(3, 3)
  /// ```
  Complex evaluateComplex([Map<String, Complex> context = const {}]) =>
      _evalComplex(this, context);
}

Complex _evalComplex(Expr expr, Map<String, Complex> context) => switch (expr) {
  Number() => expr.toComplex(),
  Constant(:final value) => value,
  Variable(:final name) => () {
    final val = context[name];
    if (val == null) {
      throw ArgumentError('Unbound variable "$name" in evaluation context');
    }
    return val;
  }(),
  Add(:final terms) => () {
    var sum = Complex.zero;
    for (var i = 0; i < terms.length; i++) {
      sum += _evalComplex(terms[i], context);
    }
    return sum;
  }(),
  Mul(:final factors) => () {
    var product = Complex.one;
    for (var i = 0; i < factors.length; i++) {
      product *= _evalComplex(factors[i], context);
    }
    return product;
  }(),
  Pow(base: Constant.e, :final exponent) => _evalComplex(
    exponent,
    context,
  ).exp(),
  Pow(:final base, :final exponent) => _evalComplexPow(
    _evalComplex(base, context),
    _evalComplex(exponent, context),
  ),
  Sin(:final expr) => _evalComplex(expr, context).sin(),
  Cos(:final expr) => _evalComplex(expr, context).cos(),
  Tan(:final expr) => _evalComplex(expr, context).tan(),
  Asin(:final expr) => _evalComplex(expr, context).asin(),
  Acos(:final expr) => _evalComplex(expr, context).acos(),
  Atan(:final expr) => _evalComplex(expr, context).atan(),
  Sinh(:final expr) => _evalComplex(expr, context).sinh(),
  Cosh(:final expr) => _evalComplex(expr, context).cosh(),
  Tanh(:final expr) => _evalComplex(expr, context).tanh(),
  Asinh(:final expr) => () {
    final z = _evalComplex(expr, context);
    return (z + (z * z + Complex.one).sqrt()).log();
  }(),
  Acosh(:final expr) => () {
    final z = _evalComplex(expr, context);
    return (z + (z + Complex.one).sqrt() * (z - Complex.one).sqrt()).log();
  }(),
  Atanh(:final expr) => () {
    final z = _evalComplex(expr, context);
    return ((Complex.one + z) / (Complex.one - z)).log() * const Complex(0.5);
  }(),
  Abs(:final expr) => Complex(_evalComplex(expr, context).abs()),
  Ln(:final expr) => _evalComplex(expr, context).log(),
  Erf(:final expr) => () {
    final z = _evalComplex(expr, context);
    if (z.b == 0.0) {
      return Complex(Erf(RealNumber.fromDouble(z.a.toDouble())).evaluate());
    }
    throw UnsupportedError('Complex Erf evaluation is only supported on R');
  }(),
  Erfc(:final expr) => () {
    final z = _evalComplex(expr, context);
    if (z.b == 0.0) {
      return Complex(Erfc(RealNumber.fromDouble(z.a.toDouble())).evaluate());
    }
    throw UnsupportedError('Complex Erfc evaluation is only supported on R');
  }(),
  Gamma(:final expr) => () {
    final z = _evalComplex(expr, context);
    if (z.b == 0.0) {
      return Complex(Gamma(RealNumber.fromDouble(z.a.toDouble())).evaluate());
    }
    throw UnsupportedError('Complex Gamma evaluation is only supported on R');
  }(),
  Beta(:final left, :final right) => () {
    final a = _evalComplex(left, context);
    final b = _evalComplex(right, context);
    if (a.b == 0.0 && b.b == 0.0) {
      return Complex(
        Beta(
          RealNumber.fromDouble(a.a.toDouble()),
          RealNumber.fromDouble(b.a.toDouble()),
        ).evaluate(),
      );
    }
    throw UnsupportedError('Complex Beta evaluation is only supported on R');
  }(),
  LambertW(:final expr, :final branch) => () {
    final z = _evalComplex(expr, context);
    if (z.b == 0.0) {
      return Complex(evaluateLambertWReal(z.a.toDouble(), branch: branch));
    }
    throw UnsupportedError(
      'Complex LambertW evaluation is only supported on R',
    );
  }(),
  RelationalExpr(:final left, :final right) => () {
    final a = _evalComplex(left, context);
    final b = _evalComplex(right, context);
    final cond = switch (expr) {
      LessThan() => a.a < b.a,
      LessEqual() => a.a <= b.a,
      GreaterThan() => a.a > b.a,
      GreaterEqual() => a.a >= b.a,
      Equal() => a == b,
    };
    return cond ? Complex.one : Complex.zero;
  }(),
  Piecewise(:final branches, :final otherwise) => () {
    for (final (cond, val) in branches) {
      if (_evalComplex(cond, context) == Complex.one) {
        return _evalComplex(val, context);
      }
    }
    if (otherwise != null) return _evalComplex(otherwise, context);
    return Complex.nan;
  }(),
  Integral() => () {
    if (expr.isDefinite && context.values.every((z) => z.b == 0.0)) {
      final realContext = {
        for (final entry in context.entries)
          entry.key: entry.value.a.toDouble(),
      };
      return Complex(expr.evaluate(realContext));
    }
    return Complex.nan;
  }(),
  OrderTerm() => Complex.zero,
};

Complex _evalComplexPow(Complex base, Complex exponent) {
  if (exponent == Complex.zero) {
    return Complex.one;
  }
  if (base == Complex.zero) {
    if (exponent.a > 0) {
      return Complex.zero;
    }
    if (exponent.a < 0 && exponent.b == 0.0) {
      return const Complex(double.infinity);
    }
    return Complex.nan;
  }
  if (exponent.b == 0.0 &&
      exponent.a == exponent.a.roundToDouble() &&
      exponent.a.abs() <= 64) {
    final n = exponent.a.round();
    if (n == 1) return base;
    if (n == 2) return base * base;
    if (n == -1) return Complex.one / base;
    var result = Complex.one;
    var cur = n < 0 ? Complex.one / base : base;
    var m = n.abs();
    while (m > 0) {
      if (m.isOdd) result *= cur;
      cur *= cur;
      m >>= 1;
    }
    return result;
  }
  return base.pow(exponent);
}
