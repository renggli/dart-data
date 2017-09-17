library pandas.type.string;

import 'package:pandas/src/type/object.dart';

class StringDataType extends ObjectDataType<String> {
  const StringDataType();

  @override
  String get name => 'STRING';

  @override
  String convert(Object value) => value?.toString();
}
