library data.frame.index;

import 'dart:collection';

import '../shared/storage.dart';
import '../type/type.dart';

abstract class Index<T> extends UnmodifiableMapBase<T, int> implements Storage {
  /// Return the data type of the key.
  DataType<T> get dataType;

  @override
  List<int> get shape => [length];

  @override
  Index<T> copy() => this;

  @override
  Set<Storage> get storage => {this};
}
