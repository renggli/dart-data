library pandas.type.object;

import 'package:pandas/src/type.dart';

class ObjectDataType<T> extends DataType<T> {
  const ObjectDataType();

  @override
  String get name => 'OBJECT';

  @override
  bool get isNullable => true;

  @override
  T convert(Object value) => value;

  @override
  List<T> newList(int length) => new List(length);
}
