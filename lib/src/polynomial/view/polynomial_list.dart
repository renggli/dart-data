import 'dart:collection';

import 'package:collection/collection.dart';

import '../polynomial.dart';

/// View of the coefficients of the polynomial as a list.
class PolynomialList<T> extends ListBase<T> with NonGrowableListMixin<T> {
  PolynomialList(this.polynomial);

  final Polynomial<T> polynomial;

  @override
  int get length => polynomial.degree + 1;

  @override
  T operator [](int index) => polynomial[index];

  @override
  void operator []=(int index, T value) => polynomial[index] = value;
}

extension PolynomialListExtension<T> on Polynomial<T> {
  /// Returns a [List] of the coefficients of the underlying polynomial.
  ///
  /// By default this is a fixed-size view: modifications to either the source
  /// polynomial or the resulting list are reflected in both. If [growable] is
  /// set to `true`, a copy is made and the resulting list can be modified
  /// independently.
  List<T> toList({bool growable = false}) => growable
      ? PolynomialList<T>(this).toList(growable: true)
      : PolynomialList<T>(this);
}
