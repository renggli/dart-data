import 'dart:collection';

import 'package:collection/collection.dart';

import '../vector.dart';

/// Fixed-size [List] of a vector.
class VectorList<T> extends ListBase<T> with NonGrowableListMixin<T> {
  final Vector<T> vector;

  VectorList(this.vector);

  @override
  int get length => vector.count;

  @override
  T operator [](int index) => vector[index];

  @override
  void operator []=(int index, T value) => vector[index] = value;
}

extension VectorListExtension<T> on Vector<T> {
  /// Returns a view [List] of the underlying vector.
  ///
  /// By default this is a fixed-size view: modifications to either the source
  /// vector or the resulting list are reflected in both. If [growable] is set
  /// to `true`, a copy is made and the resulting list can be modified
  /// independently.
  List<T> toList({bool growable = false}) => growable
      ? VectorList<T>(this).toList(growable: true)
      : VectorList<T>(this);
}
