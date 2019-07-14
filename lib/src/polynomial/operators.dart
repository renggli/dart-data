library data.polynomial.operators;

import 'dart:math' as math;

import 'package:data/matrix.dart' as matrix;
import 'package:data/src/polynomial/builder.dart';
import 'package:data/src/polynomial/polynomial.dart';
import 'package:data/type.dart';

Polynomial<T> _resultPolynomial<T>(
    int degree, Builder<T> builder, DataType<T> dataType) {
  if (builder != null) {
    return builder(degree);
  } else if (dataType != null) {
    return Polynomial.builder.withType(dataType)(degree);
  }
  throw ArgumentError('Expected either a "builder", or a "dataType".');
}

void _unaryOperator<T>(
    Polynomial<T> result, Polynomial<T> source, T Function(T value) operator) {
  final degree = source.degree;
  for (var i = degree; i >= 0; i--) {
    result.setUnchecked(i, operator(source.getUnchecked(i)));
  }
}

void _binaryOperator<T>(Polynomial<T> result, Polynomial<T> sourceA,
    Polynomial<T> sourceB, T Function(T a, T b) operator) {
  for (var i = math.max(sourceA.degree, sourceB.degree); i >= 0; i--) {
    result.setUnchecked(
        i, operator(sourceA.getUnchecked(i), sourceB.getUnchecked(i)));
  }
}

/// Generic unary operator on a polynomial.
Polynomial<T> unaryOperator<T>(
    Polynomial<T> source, T Function(T value) operator,
    {Builder<T> builder, DataType<T> dataType}) {
  final result =
      _resultPolynomial(source.degree, builder, dataType ?? source.dataType);
  _unaryOperator(result, source, operator);
  return result;
}

/// Generic binary operator on two equal sized polynomials.
Polynomial<T> binaryOperator<T>(
    Polynomial<T> sourceA, Polynomial<T> sourceB, T Function(T a, T b) operator,
    {Builder<T> builder, DataType<T> dataType}) {
  final result = _resultPolynomial(math.max(sourceA.degree, sourceB.degree),
      builder, dataType ?? sourceA.dataType);
  _binaryOperator(result, sourceA, sourceB, operator);
  return result;
}

/// Adds two polynomials [sourceA] and [sourceB].
Polynomial<T> add<T>(Polynomial<T> sourceA, Polynomial<T> sourceB,
    {Builder<T> builder, DataType<T> dataType}) {
  final result = _resultPolynomial(math.max(sourceA.degree, sourceB.degree),
      builder, dataType ?? sourceA.dataType);
  _binaryOperator(result, sourceA, sourceB, result.dataType.field.add);
  return result;
}

/// Subtracts two numeric polynomials [sourceB] from [sourceA].
Polynomial<T> sub<T>(Polynomial<T> sourceA, Polynomial<T> sourceB,
    {Builder<T> builder, DataType<T> dataType}) {
  final result = _resultPolynomial(math.max(sourceA.degree, sourceB.degree),
      builder, dataType ?? sourceA.dataType);
  _binaryOperator(result, sourceA, sourceB, result.dataType.field.sub);
  return result;
}

/// Negates a numeric polynomial [source].
Polynomial<T> neg<T>(Polynomial<T> source,
    {Builder<T> builder, DataType<T> dataType}) {
  final result =
      _resultPolynomial(source.degree, builder, dataType ?? source.dataType);
  _unaryOperator(result, source, result.dataType.field.neg);
  return result;
}

/// Scales a numeric polynomial [source] with a [factor].
Polynomial<T> scale<T>(Polynomial<T> source, num factor,
    {Builder<T> builder, DataType<T> dataType}) {
  final result =
      _resultPolynomial(source.degree, builder, dataType ?? source.dataType);
  final scale = result.dataType.field.scale;
  _unaryOperator(result, source, (a) => scale(a, factor));
  return result;
}

/// Interpolates linearly between [sourceA] and [sourceA] with a factor [t].
Polynomial<T> lerp<T>(Polynomial<T> sourceA, Polynomial<T> sourceB, num t,
    {Builder<T> builder, DataType<T> dataType}) {
  final result = _resultPolynomial(math.max(sourceA.degree, sourceB.degree),
      builder, dataType ?? sourceA.dataType);
  final field = result.dataType.field;
  _binaryOperator(result, sourceA, sourceB,
      (a, b) => field.add(field.scale(a, 1.0 - t), field.scale(b, t)));
  return result;
}

/// Multiplies two polynomials [sourceA] and [sourceB].
Polynomial<T> mul<T>(Polynomial<T> sourceA, Polynomial<T> sourceB,
    {Builder<T> builder, DataType<T> dataType}) {
  final degreeA = sourceA.degree, degreeB = sourceB.degree;
  if (degreeA < 0 || degreeB < 0) {
    // One of the polynomials has zero coefficients.
    return _resultPolynomial(0, builder, dataType ?? sourceA.dataType);
  }
  final result = _resultPolynomial(
      degreeA + degreeB, builder, dataType ?? sourceA.dataType);
  final add = result.dataType.field.add, mul = result.dataType.field.mul;
  if (degreeA == 0) {
    // First polynomial is constant.
    final factor = sourceA.getUnchecked(0);
    for (var i = degreeB; i >= 0; i--) {
      result.setUnchecked(i, mul(factor, sourceB.getUnchecked(i)));
    }
  } else if (degreeB == 0) {
    // Second polynomial is constant.
    final mul = result.dataType.field.mul;
    final factor = sourceB.getUnchecked(0);
    for (var i = degreeA; i >= 0; i--) {
      result.setUnchecked(i, mul(factor, sourceA.getUnchecked(i)));
    }
    return result;
  } else {
    // Churn through full multiplication.
    for (var a = degreeA; a >= 0; a--) {
      for (var b = degreeB; b >= 0; b--) {
        result.setUnchecked(
            a + b,
            add(result.getUnchecked(a + b),
                mul(sourceA.getUnchecked(a), sourceB.getUnchecked(b))));
      }
    }
  }
  return result;
}

// Helper to return the result of an integer division.
class Division<T> {
  final T quotient;
  final T remainder;
  Division(this.quotient, this.remainder);
}

/// Divides one polynomial [dividend] by another one [divisor], returns the
/// quotient and remainder such that `dividend = quotient * divisor +
/// remainder`.
Division<Polynomial<T>> div<T>(
  Polynomial<T> dividend,
  Polynomial<T> divisor, {
  Builder<T> builder,
  DataType<T> dataType,
}) {
  builder ??= Polynomial.builder.withType(dataType ?? dividend.dataType);
  dataType ??= builder.type;
  final dividendDegree = dividend.degree;
  final divisorDegree = divisor.degree;
  final sub = dataType.field.sub;
  final mul = dataType.field.mul;
  final div = dataType.field.div;
  if (divisorDegree < 0) {
    // Divisor is zero.
    throw const IntegerDivisionByZeroException();
  } else if (dividendDegree < 0) {
    // Dividend is zero.
    return Division(builder(0), builder(0));
  } else if (divisorDegree == 0) {
    // Divisor is constant.
    final scalar = divisor.getUnchecked(0);
    return Division(
        builder.generate(
            dividendDegree, (i) => div(dividend.getUnchecked(i), scalar)),
        builder(0));
  } else if (dividendDegree < divisorDegree) {
    // Divisor degree higher than dividend.
    return Division(
      builder(0),
      builder.fromPolynomial(dividend),
    );
  }
  // Perform synthetic division:
  // https://en.wikipedia.org/wiki/Synthetic_division
  final dividendLead = dividend.lead;
  final output = dataType.copyList(dividend.iterable);
  for (var i = dividendDegree - divisorDegree; i >= 0; i--) {
    final coefficient = output[i + 1] = div(output[i + 1], dividendLead);
    if (coefficient != dataType.nullValue) {
      for (var j = divisorDegree - 1; j >= 0; j--) {
        output[i + j] =
            sub(output[i + j], mul(divisor.getUnchecked(j), coefficient));
      }
    }
  }
  return Division(
    builder.fromList(output.sublist(divisorDegree)),
    builder.fromList(output.sublist(0, divisorDegree)),
  );
}

/// Computes the roots of a polynomial.
List<Complex> roots(Polynomial<num> source) {
  final degree = source.degree;
  if (degree <= 0) {
    return [];
  } else if (degree == 1) {
    final a = source.getUnchecked(1), b = source.getUnchecked(0);
    return [Complex(-b / a)];
  } else {
    final factor = source.getUnchecked(degree);
    final eigenMatrix = matrix.Matrix.builder
        .withType(DataType.float64)
        .generate(degree, degree, (r, c) {
      if (r == degree - 1) {
        return -source.getUnchecked(c) / factor;
      } else if (r + 1 == c) {
        return 1;
      } else {
        return 0;
      }
    }, lazy: true);
    return matrix.eigenvalue(eigenMatrix).eigenvalues;
  }
}

/// Compares two polynomials [sourceA] and [sourceB] with each other.
bool compare<T>(Polynomial<T> sourceA, Polynomial<T> sourceB,
    {bool Function(T a, T b) equals}) {
  if (equals == null && identical(sourceA, sourceB)) {
    return true;
  }
  final degreeA = sourceA.degree, degreeB = sourceB.degree;
  if (degreeA != degreeB) {
    return false;
  }
  equals ??= sourceA.dataType.equality.isEqual;
  for (var i = degreeA; i >= 0; i--) {
    if (!equals(sourceA.getUnchecked(i), sourceB.getUnchecked(i))) {
      return false;
    }
  }
  return true;
}
