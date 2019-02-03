library data.type.impl.object;

import 'package:data/src/type/type.dart';

class ObjectDataType<T> extends DataType<T> {
  const ObjectDataType();

  @override
  String get name => 'object';

  @override
  bool get isNullable => true;

  @override
  T get nullValue => null;

  @override
  T convert(Object value) => value;

  @override
  List<T> newList(int length) => List(length);
}
