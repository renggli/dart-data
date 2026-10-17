import 'dart:math' as math;

import 'package:more/number.dart' show Complex;

import '../../special/beta.dart' as special_beta;
import '../../special/erf.dart' as special_erf;
import '../../special/gamma.dart' as special_gamma;
import '../ast.dart';

/// Compiles [expression] into a fast native Dart closure for a single real variable.
double Function(double x) compileFast1D(
  Expr expression,
  String variableName,
) => compileEvaluator<double>(
  expression,
  (name) => name == variableName
      ? (x) => x
      : throw ArgumentError(
          'Unbound variable "$name" in 1D compiled function for "$variableName"',
        ),
);

/// Compiles [expression] into a fast native Dart closure for a single complex variable.
Complex Function(Complex x) compileFastComplex1D(
  Expr expression,
  String variableName,
) => compileComplexEvaluator<Complex>(
  expression,
  (name) => name == variableName
      ? (x) => x
      : throw ArgumentError(
          'Unbound variable "$name" in 1D compiled function for "$variableName"',
        ),
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
    case Constant(isReal: false, :final name):
      throw UnsupportedError(
        'Expression contains imaginary constant "$name"; use toComplexFunction1D instead.',
      );
    case Constant(:final value):
      final real = value.a.toDouble();
      return (_) => real;
    case ComplexNumber():
      throw UnsupportedError(
        'Expression contains complex number $expression; use toComplexFunction1D instead.',
      );
    case RealNumeric():
      final value = expression.toDouble();
      return (_) => value;
    case Variable(:final name):
      return compileVar(name);
    case Add(:final terms):
      if (terms.isEmpty) return (_) => 0.0;
      if (terms.length == 1) return compileEvaluator<T>(terms[0], compileVar);
      if (terms.length == 2) {
        final f0 = compileEvaluator<T>(terms[0], compileVar);
        final f1 = compileEvaluator<T>(terms[1], compileVar);
        return (t) => f0(t) + f1(t);
      }
      final fns = [
        for (final term in terms) compileEvaluator<T>(term, compileVar),
      ];
      return (t) {
        var sum = 0.0;
        for (var i = 0; i < fns.length; i++) {
          sum += fns[i](t);
        }
        return sum;
      };
    case Mul(:final factors):
      if (factors.isEmpty) return (_) => 1.0;
      if (factors.length == 1) {
        return compileEvaluator<T>(factors[0], compileVar);
      }
      if (factors.length == 2) {
        if (factors[0] == IntegerNumber.negativeOne) {
          final fn = compileEvaluator<T>(factors[1], compileVar);
          return (t) => -fn(t);
        }
        final f0 = compileEvaluator<T>(factors[0], compileVar);
        final f1 = compileEvaluator<T>(factors[1], compileVar);
        return (t) => f0(t) * f1(t);
      }
      final fns = [
        for (final factor in factors) compileEvaluator<T>(factor, compileVar),
      ];
      return (t) {
        var prod = 1.0;
        for (var i = 0; i < fns.length; i++) {
          prod *= fns[i](t);
        }
        return prod;
      };
    case Pow(base: Constant.e, :final exponent):
      final fn = compileEvaluator<T>(exponent, compileVar);
      return (t) => math.exp(fn(t));
    case Pow(:final base, :final exponent)
        when exponent == FractionNumber.half ||
            exponent == const RealNumber(0.5):
      final fB = compileEvaluator<T>(base, compileVar);
      return (t) => math.sqrt(fB(t));
    case Pow(:final base, exponent: IntegerNumber(isNegativeOne: true)):
      final fB = compileEvaluator<T>(base, compileVar);
      return (t) => 1.0 / fB(t);
    case Pow(
      :final base,
      exponent: FractionNumber(:final numerator, :final denominator),
    ):
      final fB = compileEvaluator<T>(base, compileVar);
      final expVal = numerator.toDouble() / denominator.toDouble();
      final isOddDen = denominator.isOdd;
      final isOddNum = numerator.isOdd;
      return (t) {
        final b = fB(t);
        if (b < 0 && isOddDen) {
          final mag = math.pow(-b, expVal).toDouble();
          return isOddNum ? -mag : mag;
        }
        return math.pow(b, expVal).toDouble();
      };
    case Pow(:final base, :final exponent):
      final fB = compileEvaluator<T>(base, compileVar);
      final fE = compileEvaluator<T>(exponent, compileVar);
      return (t) => math.pow(fB(t), fE(t)).toDouble();
    case Sin(:final expr):
      final fn = compileEvaluator<T>(expr, compileVar);
      return (t) => math.sin(fn(t));
    case Cos(:final expr):
      final fn = compileEvaluator<T>(expr, compileVar);
      return (t) => math.cos(fn(t));
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
        if (v.abs() < 1e-5) {
          return v + (v * v * v) / 6.0;
        }
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
      return (t) => evaluateLambertWReal(fn(t), branch: branch);
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
        if (v < 1.0) return double.nan;
        return math.log(v + math.sqrt(v - 1.0) * math.sqrt(v + 1.0));
      };
    case Atanh(:final expr):
      final fn = compileEvaluator<T>(expr, compileVar);
      return (t) {
        final v = fn(t);
        if (v < -1.0 || v > 1.0) return double.nan;
        if (v == 1.0) return double.infinity;
        if (v == -1.0) return double.negativeInfinity;
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
      final c = expression.toComplex();
      return (_) => c;
    case Constant(:final value):
      return (_) => value;
    case Add(:final terms):
      if (terms.isEmpty) return (_) => Complex.zero;
      if (terms.length == 1) {
        return compileComplexEvaluator<T>(terms[0], compileVar);
      }
      if (terms.length == 2) {
        final f0 = compileComplexEvaluator<T>(terms[0], compileVar);
        final f1 = compileComplexEvaluator<T>(terms[1], compileVar);
        return (t) => f0(t) + f1(t);
      }
      final fns = [
        for (final term in terms) compileComplexEvaluator<T>(term, compileVar),
      ];
      return (t) {
        var sum = Complex.zero;
        for (var i = 0; i < fns.length; i++) {
          sum += fns[i](t);
        }
        return sum;
      };
    case Mul(:final factors):
      if (factors.isEmpty) return (_) => Complex.one;
      if (factors.length == 1) {
        return compileComplexEvaluator<T>(factors[0], compileVar);
      }
      if (factors.length == 2) {
        if (factors[0] == IntegerNumber.negativeOne) {
          final fn = compileComplexEvaluator<T>(factors[1], compileVar);
          return (t) => -fn(t);
        }
        final f0 = compileComplexEvaluator<T>(factors[0], compileVar);
        final f1 = compileComplexEvaluator<T>(factors[1], compileVar);
        return (t) => f0(t) * f1(t);
      }
      final fns = [
        for (final factor in factors)
          compileComplexEvaluator<T>(factor, compileVar),
      ];
      return (t) {
        var prod = Complex.one;
        for (var i = 0; i < fns.length; i++) {
          prod *= fns[i](t);
        }
        return prod;
      };
    case Pow(base: Constant.e, :final exponent):
      final fn = compileComplexEvaluator<T>(exponent, compileVar);
      return (t) => fn(t).exp();
    case Pow(:final base, :final exponent):
      final fB = compileComplexEvaluator<T>(base, compileVar);
      final fE = compileComplexEvaluator<T>(exponent, compileVar);
      return (t) => _complexPow(fB(t), fE(t));
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
      return (t) {
        final z = fn(t);
        if (z.b == 0.0) {
          return Complex(evaluateLambertWReal(z.a.toDouble(), branch: branch));
        }
        throw UnsupportedError(
          'Complex LambertW evaluation is only supported on R',
        );
      };
    case Erf(:final expr):
      final fn = compileComplexEvaluator<T>(expr, compileVar);
      return (t) {
        final z = fn(t);
        if (z.b == 0.0) return Complex(special_erf.erf(z.a.toDouble()));
        throw UnsupportedError('Complex Erf evaluation is only supported on R');
      };
    case Erfc(:final expr):
      final fn = compileComplexEvaluator<T>(expr, compileVar);
      return (t) {
        final z = fn(t);
        if (z.b == 0.0) return Complex(special_erf.erfc(z.a.toDouble()));
        throw UnsupportedError(
          'Complex Erfc evaluation is only supported on R',
        );
      };
    case Gamma(:final expr):
      final fn = compileComplexEvaluator<T>(expr, compileVar);
      return (t) {
        final z = fn(t);
        if (z.b == 0.0) return Complex(special_gamma.gamma(z.a.toDouble()));
        throw UnsupportedError(
          'Complex Gamma evaluation is only supported on R',
        );
      };
    case Beta(:final left, :final right):
      final fL = compileComplexEvaluator<T>(left, compileVar);
      final fR = compileComplexEvaluator<T>(right, compileVar);
      return (t) {
        final zA = fL(t);
        final zB = fR(t);
        if (zA.b == 0.0 && zB.b == 0.0) {
          return Complex(special_beta.beta(zA.a.toDouble(), zB.a.toDouble()));
        }
        throw UnsupportedError(
          'Complex Beta evaluation is only supported on R',
        );
      };
    case Asinh(:final expr):
      final fn = compileComplexEvaluator<T>(expr, compileVar);
      return (t) {
        final z = fn(t);
        return (z + (z * z + Complex.one).sqrt()).log();
      };
    case Acosh(:final expr):
      final fn = compileComplexEvaluator<T>(expr, compileVar);
      return (t) {
        final z = fn(t);
        return (z + (z + Complex.one).sqrt() * (z - Complex.one).sqrt()).log();
      };
    case Atanh(:final expr):
      final fn = compileComplexEvaluator<T>(expr, compileVar);
      return (t) {
        final z = fn(t);
        return ((Complex.one + z) / (Complex.one - z)).log() *
            const Complex(0.5);
      };
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

Complex _complexPow(Complex base, Complex exponent) {
  if (exponent == Complex.zero) return Complex.one;
  if (base == Complex.zero) {
    if (exponent.a > 0) return Complex.zero;
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
