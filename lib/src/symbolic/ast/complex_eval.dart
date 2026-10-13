part of '../ast.dart';

Complex _evaluateComplex(Expr expr, Map<String, Complex> context) =>
    switch (expr) {
      Variable(:final name) =>
        context[name] ??
            (throw ArgumentError('Variable "$name" not provided in context')),
      Number() => expr.complexValue,
      Add(:final left, :final right) =>
        _evaluateComplex(left, context) + _evaluateComplex(right, context),
      Sub(:final left, :final right) =>
        _evaluateComplex(left, context) - _evaluateComplex(right, context),
      Mul(:final left, :final right) =>
        _evaluateComplex(left, context) * _evaluateComplex(right, context),
      Div(:final left, :final right) =>
        _evaluateComplex(left, context) / _evaluateComplex(right, context),
      Pow(:final base, :final exponent) => complexPow(
        _evaluateComplex(base, context),
        _evaluateComplex(exponent, context),
      ),
      Neg(:final expr) => -_evaluateComplex(expr, context),
      Sin(:final expr) => _evaluateComplex(expr, context).sin(),
      Cos(:final expr) => _evaluateComplex(expr, context).cos(),
      Tan(:final expr) => _evaluateComplex(expr, context).tan(),
      Asin(:final expr) => _evaluateComplex(expr, context).asin(),
      Acos(:final expr) => _evaluateComplex(expr, context).acos(),
      Atan(:final expr) => _evaluateComplex(expr, context).atan(),
      Sinh(:final expr) => _evaluateComplex(expr, context).sinh(),
      Cosh(:final expr) => _evaluateComplex(expr, context).cosh(),
      Tanh(:final expr) => _evaluateComplex(expr, context).tanh(),
      Exp(:final expr) => _evaluateComplex(expr, context).exp(),
      Ln(:final expr) => _evaluateComplex(expr, context).log(),
      Abs(:final expr) => Complex(_evaluateComplex(expr, context).abs(), 0),
      OrderTerm() => Complex.zero,
    };

/// Computes complex power [base]^[exponent] handling zero-base edge cases.
Complex complexPow(Complex base, Complex exponent) {
  if (base.a == 0 && base.b == 0) {
    if (exponent.a == 0 && exponent.b == 0) return Complex.one;
    if (exponent.a > 0) return Complex.zero;
    if (exponent.a < 0) {
      return exponent.b == 0
          ? const Complex(double.infinity, 0.0)
          : const Complex(double.infinity, double.nan);
    }
    return Complex.nan;
  }
  return base.pow(exponent);
}
