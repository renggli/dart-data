import 'dart:collection';

import 'package:more/collection.dart';

import 'frame.dart';
import 'row.dart';

class Rows extends IterableBase<Row> {
  Rows(this._frame);

  final Frame _frame;

  int _length = 0;

  @override
  Iterator<Row> get iterator =>
      IntegerRange(_length).map((index) => Row(_frame, index)).iterator;

  @override
  int get length => _length;

  Row operator [](int index) {
    RangeError.checkValidIndex(index, this, 'index', _length);
    return Row(_frame, index);
  }
}
