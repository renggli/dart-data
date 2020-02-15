library data.frame.index.categorical;

import '../../type/type.dart';
import '../index.dart';

class CategoricalIndex<T> extends Index<T> {
  final Map<T, int> mapping;

  CategoricalIndex(this.dataType, this.mapping);

  @override
  final DataType<T> dataType;

  @override
  int operator [](Object key) => mapping[key];

  @override
  Iterable<T> get keys => mapping.keys;

  @override
  Iterable<int> get values => mapping.values;
}
