library data.type.string;

import 'object.dart';

class StringDataType extends ObjectDataType<String> {
  const StringDataType();

  @override
  String get name => 'string';

  @override
  String convert(Object value) => value?.toString();
}
