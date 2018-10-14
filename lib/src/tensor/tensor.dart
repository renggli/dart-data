library data.tensor.tensor;

import 'package:data/type.dart' show DataType;
import 'package:more/printer.dart' show Printer;

/// Abstract tensor type.
abstract class Tensor<T> {
  /// Returns the data type of this tensor.
  DataType<T> get dataType;

  /// Returns the dimensions of this tensor.
  List<int> get shape;

  /// Returns the underlying storage base of this tensor.
  Tensor get base;

  /// Returns a copy of this tensor.
  Tensor<T> copy();

  /// Returns a tensor or a scalar at the provided [index].
  Object operator [](int index);

  /// Returns the human readable representation of this tensor.
  String format([Printer printer]);

  /// Returns the string representation of this tensor.
  @override
  String toString() => '$runtimeType[${shape.join(', ')}, ${dataType.name}]:\n'
      '${format()}';
}
