library data.type.boolean;

import 'package:more/collection.dart' show BitList;

import 'type.dart';

class BooleanDataType extends DataType<bool> {
  const BooleanDataType();

  @override
  String get name => 'BOOLEAN';

  @override
  bool get isNullable => false;

  @override
  List<bool> newList(int length) => BitList(length);

  @override
  bool convert(Object value) {
    if (value is bool) {
      return value;
    } else if (value is num) {
      return value != 0 && !value.isNaN;
    } else if (value is String) {
      if (const ['true', 't', 'yes', 'y'].contains(value)) {
        return true;
      }
      if (const ['false', 'f', 'no', 'n'].contains(value)) {
        return false;
      }
    }
    return super.convert(value);
  }
}
