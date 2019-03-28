library data.type.impl.string;

import 'package:data/src/type/impl/object.dart';

class StringDataType extends ObjectDataType<String> {
  const StringDataType();

  @override
  String get name => 'string';

  @override
  String cast(Object value) => value?.toString();
}
