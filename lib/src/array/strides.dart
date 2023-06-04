import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:more/printer.dart';

import '../../data.dart';

/// The strides of an N-dimensional array.
@immutable
class Strides with ToStringPrinter {
  /// Constructs the strides from an [Iterable].
  factory Strides.fromIterable(Iterable<int> strides) {
    final length = strides.length;
    final values = DataType.index.newList(length);
    values.replaceRange(0, length, strides);
    return Strides._(values);
  }

  /// Constructs the default strides of the given [Shape].
  factory Strides.fromShape(Shape shape) {
    final values = DataType.index.newList(shape.dimensions);
    values[values.length - 1] = 1;
    for (var i = values.length - 1; i > 0; i--) {
      values[i - 1] = values[i] * shape[i];
    }
    return Strides._(values);
  }

  const Strides._(this._strides);

  final List<int> _strides;

  int operator [](int index) => _strides[index];

  int get dimensions => _strides.length;

  @override
  bool operator ==(Object other) =>
      other is Strides &&
      const ListEquality<int>().equals(_strides, other._strides);

  @override
  int get hashCode => const ListEquality<int>().hash(_strides);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(_strides)
    ..addValue(dimensions, name: 'dimensions');
}
