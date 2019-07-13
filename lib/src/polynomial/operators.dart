library data.polynomial.operators;

import 'dart:math' as math;

import 'package:data/matrix.dart' as matrix;
import 'package:data/src/polynomial/builder.dart';
import 'package:data/src/polynomial/polynomial.dart';
import 'package:data/type.dart';
import 'package:more/tuple.dart' show Tuple2;

Polynomial<T> _resultPolynomial<T>(int degree, Polynomial<T> target,
    Builder<T> builder, DataType<T> dataType) {
  if (target != null) {
    target.clear();
    return target;
  } else if (builder != null) {
    return builder(degree);
  } else if (dataType != null) {
    return Polynomial.builder.withType(dataType)(degree);
  }
  throw ArgumentError(
      'Expected either a "target", a "builder", or a "dataType".');
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
    {Polynomial<T> target, Builder<T> builder, DataType<T> dataType}) {
  final result = _resultPolynomial(
      source.count, target, builder, dataType ?? source.dataType);
  _unaryOperator(result, source, operator);
  return result;
}

/// Generic binary operator on two equal sized polynomials.
Polynomial<T> binaryOperator<T>(
    Polynomial<T> sourceA, Polynomial<T> sourceB, T Function(T a, T b) operator,
    {Polynomial<T> target, Builder<T> builder, DataType<T> dataType}) {
  final result = _resultPolynomial(
      sourceA.count, target, builder, dataType ?? sourceA.dataType);
  _binaryOperator(result, sourceA, sourceB, operator);
  return result;
}

/// Adds two polynomials [sourceA] and [sourceB].
Polynomial<T> add<T>(Polynomial<T> sourceA, Polynomial<T> sourceB,
    {Polynomial<T> target, Builder<T> builder, DataType<T> dataType}) {
  final result = _resultPolynomial(
      sourceA.count, target, builder, dataType ?? sourceA.dataType);
  _binaryOperator(result, sourceA, sourceB, result.dataType.field.add);
  return result;
}

/// Subtracts two numeric polynomials [sourceB] from [sourceA].
Polynomial<T> sub<T>(Polynomial<T> sourceA, Polynomial<T> sourceB,
    {Polynomial<T> target, Builder<T> builder, DataType<T> dataType}) {
  final result = _resultPolynomial(
      sourceA.count, target, builder, dataType ?? sourceA.dataType);
  _binaryOperator(result, sourceA, sourceB, result.dataType.field.sub);
  return result;
}

/// Negates a numeric polynomial [source].
Polynomial<T> neg<T>(Polynomial<T> source,
    {Polynomial<T> target, Builder<T> builder, DataType<T> dataType}) {
  final result = _resultPolynomial(
      source.count, target, builder, dataType ?? source.dataType);
  _unaryOperator(result, source, result.dataType.field.neg);
  return result;
}

/// Scales a numeric polynomial [source] with a [factor].
Polynomial<T> scale<T>(Polynomial<T> source, num factor,
    {Polynomial<T> target, Builder<T> builder, DataType<T> dataType}) {
  final result = _resultPolynomial(
      source.count, target, builder, dataType ?? source.dataType);
  final scale = result.dataType.field.scale;
  _unaryOperator(result, source, (a) => scale(a, factor));
  return result;
}

/// Interpolates linearly between [sourceA] and [sourceA] with a factor [t].
Polynomial<T> lerp<T>(Polynomial<T> sourceA, Polynomial<T> sourceB, num t,
    {Polynomial<T> target, Builder<T> builder, DataType<T> dataType}) {
  final result = _resultPolynomial(
      sourceA.count, target, builder, dataType ?? sourceA.dataType);
  final field = result.dataType.field;
  _binaryOperator(result, sourceA, sourceB,
      (a, b) => field.add(field.scale(a, 1.0 - t), field.scale(b, t)));
  return result;
}

/// Multiplies two polynomials [sourceA] and [sourceB].
Polynomial<T> mul<T>(Polynomial<T> sourceA, Polynomial<T> sourceB,
    {Polynomial<T> target, Builder<T> builder, DataType<T> dataType}) {
  final degreeA = sourceA.degree, degreeB = sourceB.degree;
  final result =
      _resultPolynomial(degreeA + degreeB + 1, target, builder, dataType);
  if (identical(result, target)) {
    final sourcesStorage = Set.identity()
      ..addAll(sourceA.storage)
      ..addAll(sourceB.storage);
    if (result.storage.any(sourcesStorage.contains)) {
      throw ArgumentError('Polynomial multiplication cannot be done in-place.');
    }
  }
  final field = result.dataType.field;
  for (var a = degreeA; a >= 0; a--) {
    for (var b = degreeB; b >= 0; b--) {
      result.setUnchecked(
          a + b,
          field.add(result.getUnchecked(a + b),
              field.mul(sourceA.getUnchecked(a), sourceB.getUnchecked(b))));
    }
  }
  return result;
}

/// Divides one polynomial [sourceA] by another one [sourceB], returns a tuple
/// of the quotient and remainder such that `sourceA = quotient * sourceB +
/// remainder`.
Tuple2<Polynomial<T>, Polynomial<T>> div<T>(
  Polynomial<T> sourceA,
  Polynomial<T> sourceB, {
  Polynomial<T> targetQuotient,
  Polynomial<T> targetRemainder,
  Builder<T> builder,
  DataType<T> dataType,
}) {
  final degreeB = sourceB.degree;
  if (degreeB < 0) {
    // Division by zero: throw an exception.
    throw const IntegerDivisionByZeroException();
  }
  final quotient = _resultPolynomial(0, targetQuotient, builder, dataType);
  final remainder = _resultPolynomial(0, targetRemainder, builder, dataType);
  if (identical(quotient, remainder)) {
    throw ArgumentError('Polynomial remainder and quotient cannot be shared.');
  }
  if (identical(quotient, targetQuotient) ||
      identical(remainder, targetRemainder)) {
    final sourcesStorage = Set.identity()
      ..addAll(sourceA.storage)
      ..addAll(sourceB.storage);
    if (quotient.storage.any(sourcesStorage.contains) ||
        remainder.storage.any(sourcesStorage.contains)) {
      throw ArgumentError('Polynomial division cannot be done in-place.');
    }
  }
  final degreeA = sourceA.degree;
  if (degreeA < 0) {
    // Zero divided by something: return zero.
    return Tuple2(quotient, remainder);
  }
  final field = quotient.dataType.field;
  if (degreeB == 0) {
    // Something divided by a scalar: divide the sourceA by scalar.
    final divisor = sourceB.getUnchecked(0);
    for (var i = degreeA; i >= 0; i--) {
      quotient.setUnchecked(i, field.div(sourceA.getUnchecked(i), divisor));
    }
    return Tuple2(quotient, remainder);
  }
  if (degreeA < degreeB) {
    // Something small divided by something larger: return the small thing.
    for (var i = degreeA; i >= 0; i--) {
      remainder.setUnchecked(i, sourceA.getUnchecked(i));
    }
    return Tuple2(quotient, remainder);
  }

  final c1 = sourceA.dataType.copyList(sourceA.iterable);
  final scl = sourceB.getUnchecked(degreeB);
  final c22 = sourceB.dataType.newList(degreeB);
  for (var ii = 0; ii < c22.length; ii++) {
    c22[ii] = field.div(sourceB.getUnchecked(ii), scl);
  }

  var i = degreeA - degreeB;
  var j = degreeA;
  while (i >= 0) {
    final v = c1[j];
    for (var k = i; k < j; k++) {
      c1[k] = field.sub(c1[k], field.mul(c22[k - i], v));
    }
    i--;
    j--;
  }

  final j1 = j + 1;
  final l1 = degreeA - j;
  for (var k = 0; k < l1; k++) {
    quotient.setUnchecked(k, field.div(c1[k + j1], scl));
  }

  for (var k = 0; k < j1; k++) {
    remainder.setUnchecked(k, c1[k]);
  }

  return Tuple2(quotient, remainder);
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
