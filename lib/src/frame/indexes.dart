import 'dart:collection';

import 'frame.dart';
import 'index.dart';

class Indexes extends IterableBase<Index> {
  final Frame _frame;
  final List<Index> _indexes = [];

  Indexes(this._frame);

  @override
  Iterator<Index> get iterator => _indexes.iterator;
}
