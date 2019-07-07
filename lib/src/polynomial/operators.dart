library data.polynomial.operators;

import 'dart:math' as math;

import 'package:data/src/polynomial/builder.dart';
import 'package:data/src/polynomial/polynomial.dart';
import 'package:data/type.dart';

Polynomial<T> _resultPolynomial<T>(int degree, Polynomial<T> target,
    Builder<T> builder, DataType<T> dataType) {
  if (target != null) {
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
  for (var i = 0; i <= degree; i++) {
    result.setUnchecked(i, operator(source.getUnchecked(i)));
  }
}

void _binaryOperator<T>(Polynomial<T> result, Polynomial<T> sourceA,
    Polynomial<T> sourceB, T Function(T a, T b) operator) {
  final degree = math.max(sourceA.degree, sourceB.degree);
  for (var i = 0; i <= degree; i++) {
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

/// Compares two polynomials [sourceA] and [sourceB] with each other.
bool compare<T>(Polynomial<T> sourceA, Polynomial<T> sourceB,
    {bool Function(T a, T b) equals}) {
  if (equals == null && identical(sourceA, sourceB)) {
    return true;
  }
  final degree = math.max(sourceA.degree, sourceB.degree);
  equals ??= sourceA.dataType.equality.isEqual;
  for (var i = 0; i <= degree; i++) {
    if (!equals(sourceA.getUnchecked(i), sourceB.getUnchecked(i))) {
      return false;
    }
  }
  return true;
}
