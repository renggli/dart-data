import 'dart:math' as math;

import '../../../type.dart';
import '../polynomial.dart';
import '../polynomial_format.dart';

Polynomial<T> createPolynomial<T>(Polynomial<T> source, int desiredDegree,
        DataType<T>? dataType, PolynomialFormat? format) =>
    Polynomial<T>(dataType ?? source.dataType,
        desiredDegree: desiredDegree, format: format);

void unaryOperator<T>(
    Polynomial<T> result, Polynomial<T> source, T Function(T value) operator) {
  for (var i = source.degree; i >= 0; i--) {
    result.setUnchecked(i, operator(source.getUnchecked(i)));
  }
}

void binaryOperator<T>(Polynomial<T> result, Polynomial<T> first,
    Polynomial<T> second, T Function(T a, T b) operator) {
  for (var i = math.max(first.degree, second.degree); i >= 0; i--) {
    result.setUnchecked(
        i, operator(first.getUnchecked(i), second.getUnchecked(i)));
  }
}
