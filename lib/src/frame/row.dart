import 'package:data/src/type/type.dart';

import 'frame.dart';

class Row {
  Row(this._frame, this._index);

  final Frame _frame;
  final int _index;
  late final int _row = _frame.indexes.lookup(_index);

  T getValue<T>(String name, {DataType<T>? dataType}) {
    final value = _frame.columns[name][_row];
    return dataType == null ? value as T : dataType.cast(value);
  }
}
