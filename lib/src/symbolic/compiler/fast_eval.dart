import 'dart:math' as math;

import 'package:more/number.dart' show Complex;

import '../../special/beta.dart' as special_beta;
import '../../special/erf.dart' as special_erf;
import '../../special/gamma.dart' as special_gamma;
import '../ast.dart';

/// Compiles [expression] into a fast native Dart closure for a single real variable.
double Function(double x) compileFast1D(Expr expression, String variableName) =>
    compileEvaluator<double>(
      expression,
      (name) => name == variableName ? (x) => x : (_) => 0.0,
    );

/// Compiles [expression] into a fast native Dart closure for a single complex variable.
Complex Function(Complex x) compileFastComplex1D(
  Expr expression,
  String variableName,
) => compileComplexEvaluator<Complex>(
  expression,
  (name) => name == variableName ? (x) => x : (_) => Complex.zero,
);

/// Compiles [expression] into a dictionary-based complex closure.
Complex Function(Map<String, Complex> context) compileComplexContext(
  Expr expression,
) => compileComplexEvaluator<Map<String, Complex>>(
  expression,
  (name) =>
      (context) =>
          context[name] ??
          (throw ArgumentError('Variable "$name" not provided in context')),
);

/// Core recursive AST real compiler synthesizing typed functional closures.
double Function(T) compileEvaluator<T>(
  Expr expression,
  double Function(T) Function(String name) compileVar,
) {
  switch (expression) {
    case ComplexNumber(:final imaginary) when imaginary != 0.0:
    case ConstantNumber(name: 'i'):
      throw UnsupportedError(
        'Expression contains imaginary constant "i"; use toComplexFunction1D instead.',
      );
    case Number(:final value):
      return (_) => value;
    case Variable(:final name):
      return compileVar(name);
    case Add(:final left, :final right):
      final fL = compileEvaluator<T>(left, compileVar);
      final fR = compileEvaluator<T>(right, compileVar);
      return (t) => fL(t) + fR(t);
    case Sub(:final left, :final right):
      final fL = compileEvaluator<T>(left, compileVar);
      final fR = compileEvaluator<T>(right, compileVar);
      return (t) => fL(t) - fR(t);
    case Mul(:final left, :final right):
      final fL = compileEvaluator<T>(left, compileVar);
      final fR = compileEvaluator<T>(right, compileVar);
      return (t) => fL(t) * fR(t);
    case Div(:final left, :final right):
      final fL = compileEvaluator<T>(left, compileVar);
      final fR = compileEvaluator<T>(right, compileVar);
      return (t) => fL(t) / fR(t);
    case Pow(
      :final base,
      exponent: RationalNumber(numerator: 1, denominator: 2) ||
          RealNumber(value: 0.5),
    ):
      final fB = compileEvaluator<T>(base, compileVar);
      return (t) => math.sqrt(fB(t));
    case Pow(:final base, :final exponent):
      final fB = compileEvaluator<T>(base, compileVar);
      final fE = compileEvaluator<T>(exponent, compileVar);
      return (t) => math.pow(fB(t), fE(t)).toDouble();
    case Neg(:final expr):
      final fn = compileEvaluator<T>(expr, compileVar);
      return (t) => -fn(t);
    case Sin(:final expr):
      final fn = compileEvaluator<T>(expr, compileVar);
      return (t) => math.sin(fn(t));
    case Cos(:final expr):
      final fn = compileEvaluator<T>(expr, compileVar);
      return (t) => math.cos(fn(t));
    case Exp(:final expr):
      final fn = compileEvaluator<T>(expr, compileVar);
      return (t) => math.exp(fn(t));
    case Ln(:final expr):
      final fn = compileEvaluator<T>(expr, compileVar);
      return (t) => math.log(fn(t));
    case Tan(:final expr):
      final fn = compileEvaluator<T>(expr, compileVar);
      return (t) => math.tan(fn(t));
    case Asin(:final expr):
      final fn = compileEvaluator<T>(expr, compileVar);
      return (t) => math.asin(fn(t));
    case Acos(:final expr):
      final fn = compileEvaluator<T>(expr, compileVar);
      return (t) => math.acos(fn(t));
    case Atan(:final expr):
      final fn = compileEvaluator<T>(expr, compileVar);
      return (t) => math.atan(fn(t));
    case Sinh(:final expr):
      final fn = compileEvaluator<T>(expr, compileVar);
      return (t) {
        final v = fn(t);
        return (math.exp(v) - math.exp(-v)) / 2.0;
      };
    case Cosh(:final expr):
      final fn = compileEvaluator<T>(expr, compileVar);
      return (t) {
        final v = fn(t);
        return (math.exp(v) + math.exp(-v)) / 2.0;
      };
    case Tanh(:final expr):
      final fn = compileEvaluator<T>(expr, compileVar);
      return (t) {
        final v = fn(t);
        if (v > 20.0) return 1.0;
        if (v < -20.0) return -1.0;
        final e2 = math.exp(2.0 * v);
        return (e2 - 1.0) / (e2 + 1.0);
      };
    case Abs(:final expr):
      final fn = compileEvaluator<T>(expr, compileVar);
      return (t) => fn(t).abs();
    case OrderTerm():
      return (_) => 0.0;
    case LambertW(:final expr, :final branch):
      final fn = compileEvaluator<T>(expr, compileVar);
      return (t) => evaluateLambertW(fn(t), branch);
    case Erf(:final expr):
      final fn = compileEvaluator<T>(expr, compileVar);
      return (t) => special_erf.erf(fn(t));
    case Erfc(:final expr):
      final fn = compileEvaluator<T>(expr, compileVar);
      return (t) => special_erf.erfc(fn(t));
    case Gamma(:final expr):
      final fn = compileEvaluator<T>(expr, compileVar);
      return (t) {
        final v = fn(t);
        if (v <= 0.0 && v == v.roundToDouble()) {
          throw ArgumentError('Gamma pole at non-positive integer $v');
        }
        return special_gamma.gamma(v);
      };
    case Beta(:final left, :final right):
      final fL = compileEvaluator<T>(left, compileVar);
      final fR = compileEvaluator<T>(right, compileVar);
      return (t) => special_beta.beta(fL(t), fR(t));
    case Asinh(:final expr):
      final fn = compileEvaluator<T>(expr, compileVar);
      return (t) {
        final v = fn(t);
        return math.log(v + math.sqrt(v * v + 1.0));
      };
    case Acosh(:final expr):
      final fn = compileEvaluator<T>(expr, compileVar);
      return (t) {
        final v = fn(t);
        if (v < 1.0) throw ArgumentError('acosh domain error: $v < 1.0');
        return math.log(v + math.sqrt(v * v - 1.0));
      };
    case Atanh(:final expr):
      final fn = compileEvaluator<T>(expr, compileVar);
      return (t) {
        final v = fn(t);
        if (v.abs() >= 1.0) {
          throw ArgumentError('atanh domain error: |$v| >= 1.0');
        }
        return 0.5 * math.log((1.0 + v) / (1.0 - v));
      };
    case LessThan(:final left, :final right):
      final fL = compileEvaluator<T>(left, compileVar);
      final fR = compileEvaluator<T>(right, compileVar);
      return (t) => fL(t) < fR(t) ? 1.0 : 0.0;
    case LessEqual(:final left, :final right):
      final fL = compileEvaluator<T>(left, compileVar);
      final fR = compileEvaluator<T>(right, compileVar);
      return (t) => fL(t) <= fR(t) ? 1.0 : 0.0;
    case GreaterThan(:final left, :final right):
      final fL = compileEvaluator<T>(left, compileVar);
      final fR = compileEvaluator<T>(right, compileVar);
      return (t) => fL(t) > fR(t) ? 1.0 : 0.0;
    case GreaterEqual(:final left, :final right):
      final fL = compileEvaluator<T>(left, compileVar);
      final fR = compileEvaluator<T>(right, compileVar);
      return (t) => fL(t) >= fR(t) ? 1.0 : 0.0;
    case Equal(:final left, :final right):
      final fL = compileEvaluator<T>(left, compileVar);
      final fR = compileEvaluator<T>(right, compileVar);
      return (t) => fL(t) == fR(t) ? 1.0 : 0.0;
    case Piecewise(:final branches, :final otherwise):
      final compiledBranches = [
        for (final (cond, e) in branches)
          (
            compileEvaluator<T>(cond, compileVar),
            compileEvaluator<T>(e, compileVar),
          ),
      ];
      final compiledOth = otherwise != null
          ? compileEvaluator<T>(otherwise, compileVar)
          : null;
      return (t) {
        for (final (c, e) in compiledBranches) {
          final cVal = c(t);
          if (cVal != 0.0 && !cVal.isNaN) return e(t);
        }
        if (compiledOth != null) return compiledOth(t);
        throw StateError('No Piecewise branch matched context');
      };
  }
}

/// Core recursive AST complex compiler synthesizing complex functional closures.
Complex Function(T) compileComplexEvaluator<T>(
  Expr expression,
  Complex Function(T) Function(String name) compileVar,
) {
  switch (expression) {
    case Variable(:final name):
      return compileVar(name);
    case Number():
      final c = expression.complexValue;
      return (_) => c;
    case Add(:final left, :final right):
      final fL = compileComplexEvaluator<T>(left, compileVar);
      final fR = compileComplexEvaluator<T>(right, compileVar);
      return (t) => fL(t) + fR(t);
    case Sub(:final left, :final right):
      final fL = compileComplexEvaluator<T>(left, compileVar);
      final fR = compileComplexEvaluator<T>(right, compileVar);
      return (t) => fL(t) - fR(t);
    case Mul(:final left, :final right):
      final fL = compileComplexEvaluator<T>(left, compileVar);
      final fR = compileComplexEvaluator<T>(right, compileVar);
      return (t) => fL(t) * fR(t);
    case Div(:final left, :final right):
      final fL = compileComplexEvaluator<T>(left, compileVar);
      final fR = compileComplexEvaluator<T>(right, compileVar);
      return (t) => fL(t) / fR(t);
    case Pow(:final base, :final exponent):
      final fB = compileComplexEvaluator<T>(base, compileVar);
      final fE = compileComplexEvaluator<T>(exponent, compileVar);
      return (t) => complexPow(fB(t), fE(t));
    case Neg(:final expr):
      final fn = compileComplexEvaluator<T>(expr, compileVar);
      return (t) => -fn(t);
    case Sin(:final expr):
      final fn = compileComplexEvaluator<T>(expr, compileVar);
      return (t) => fn(t).sin();
    case Cos(:final expr):
      final fn = compileComplexEvaluator<T>(expr, compileVar);
      return (t) => fn(t).cos();
    case Tan(:final expr):
      final fn = compileComplexEvaluator<T>(expr, compileVar);
      return (t) => fn(t).tan();
    case Asin(:final expr):
      final fn = compileComplexEvaluator<T>(expr, compileVar);
      return (t) => fn(t).asin();
    case Acos(:final expr):
      final fn = compileComplexEvaluator<T>(expr, compileVar);
      return (t) => fn(t).acos();
    case Atan(:final expr):
      final fn = compileComplexEvaluator<T>(expr, compileVar);
      return (t) => fn(t).atan();
    case Sinh(:final expr):
      final fn = compileComplexEvaluator<T>(expr, compileVar);
      return (t) => fn(t).sinh();
    case Cosh(:final expr):
      final fn = compileComplexEvaluator<T>(expr, compileVar);
      return (t) => fn(t).cosh();
    case Tanh(:final expr):
      final fn = compileComplexEvaluator<T>(expr, compileVar);
      return (t) => fn(t).tanh();
    case Exp(:final expr):
      final fn = compileComplexEvaluator<T>(expr, compileVar);
      return (t) => fn(t).exp();
    case Ln(:final expr):
      final fn = compileComplexEvaluator<T>(expr, compileVar);
      return (t) => fn(t).log();
    case Abs(:final expr):
      final fn = compileComplexEvaluator<T>(expr, compileVar);
      return (t) => Complex(fn(t).abs(), 0);
    case OrderTerm():
      return (_) => Complex.zero;
    case LambertW(:final expr, :final branch):
      final fn = compileComplexEvaluator<T>(expr, compileVar);
      return (t) => evaluateComplexLambertW(fn(t), branch);
    case Erf(:final expr):
      final fn = compileComplexEvaluator<T>(expr, compileVar);
      return (t) => evaluateComplexErf(fn(t));
    case Erfc(:final expr):
      final fn = compileComplexEvaluator<T>(expr, compileVar);
      return (t) => Complex.one - evaluateComplexErf(fn(t));
    case Gamma(:final expr):
      final fn = compileComplexEvaluator<T>(expr, compileVar);
      return (t) => evaluateComplexGamma(fn(t));
    case Beta(:final left, :final right):
      final fL = compileComplexEvaluator<T>(left, compileVar);
      final fR = compileComplexEvaluator<T>(right, compileVar);
      return (t) {
        final zA = fL(t);
        final zB = fR(t);
        return (evaluateComplexGamma(zA) * evaluateComplexGamma(zB)) /
            evaluateComplexGamma(zA + zB);
      };
    case Asinh(:final expr):
      final fn = compileComplexEvaluator<T>(expr, compileVar);
      return (t) => evaluateComplexAsinh(fn(t));
    case Acosh(:final expr):
      final fn = compileComplexEvaluator<T>(expr, compileVar);
      return (t) => evaluateComplexAcosh(fn(t));
    case Atanh(:final expr):
      final fn = compileComplexEvaluator<T>(expr, compileVar);
      return (t) => evaluateComplexAtanh(fn(t));
    case LessThan(:final left, :final right):
      final fL = compileComplexEvaluator<T>(left, compileVar);
      final fR = compileComplexEvaluator<T>(right, compileVar);
      return (t) => fL(t).a < fR(t).a ? Complex.one : Complex.zero;
    case LessEqual(:final left, :final right):
      final fL = compileComplexEvaluator<T>(left, compileVar);
      final fR = compileComplexEvaluator<T>(right, compileVar);
      return (t) => fL(t).a <= fR(t).a ? Complex.one : Complex.zero;
    case GreaterThan(:final left, :final right):
      final fL = compileComplexEvaluator<T>(left, compileVar);
      final fR = compileComplexEvaluator<T>(right, compileVar);
      return (t) => fL(t).a > fR(t).a ? Complex.one : Complex.zero;
    case GreaterEqual(:final left, :final right):
      final fL = compileComplexEvaluator<T>(left, compileVar);
      final fR = compileComplexEvaluator<T>(right, compileVar);
      return (t) => fL(t).a >= fR(t).a ? Complex.one : Complex.zero;
    case Equal(:final left, :final right):
      final fL = compileComplexEvaluator<T>(left, compileVar);
      final fR = compileComplexEvaluator<T>(right, compileVar);
      return (t) => fL(t) == fR(t) ? Complex.one : Complex.zero;
    case Piecewise(:final branches, :final otherwise):
      final compiledBranches = [
        for (final (cond, e) in branches)
          (
            compileComplexEvaluator<T>(cond, compileVar),
            compileComplexEvaluator<T>(e, compileVar),
          ),
      ];
      final compiledOth = otherwise != null
          ? compileComplexEvaluator<T>(otherwise, compileVar)
          : null;
      return (t) {
        for (final (c, e) in compiledBranches) {
          final cVal = c(t);
          if (cVal.a != 0.0 && !cVal.a.isNaN) return e(t);
        }
        if (compiledOth != null) return compiledOth(t);
        throw StateError('No Piecewise branch matched context');
      };
  }
}
