library data.frame.index.range;

import 'package:more/collection.dart';

import '../../shared/config.dart';
import '../../type/type.dart';
import '../index.dart';

class RangeIndex extends Index<int> {
  final IntegerRange range;

  factory RangeIndex({int start = 0, int stop = 0, int step = 1}) =>
      RangeIndex.fromRange(start.to(stop, step: step));

  RangeIndex.fromRange(this.range);

  @override
  DataType<int> get dataType => indexDataType;

  @override
  int operator [](Object key) => range[key];

  @override
  int get length => range.length;

  @override
  Iterable<int> get keys => 0.to(range.length);

  @override
  Iterable<int> get values => range;
}
