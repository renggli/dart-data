library data.type.boolean;

import 'package:more/collection.dart' show BitList;

import 'type.dart';

const _trueStrings = ['true', 't', 'yes', 'y', '1'];
const _falseStrings = ['false', 'f', 'no', 'n', '0'];

class BooleanDataType extends DataType<bool> {
  const BooleanDataType();

  @override
  String get name => 'boolean';

  @override
  bool get isNullable => false;

  @override
  bool get nullValue => false;

  @override
  List<bool> newList(int length) => BitList(length);

  @override
  bool convert(Object value) {
    if (value is bool) {
      return value;
    } else if (value is num) {
      return value != 0 && !value.isNaN;
    } else if (value is String) {
      if (_trueStrings.contains(value)) {
        return true;
      }
      if (_falseStrings.contains(value)) {
        return false;
      }
    }
    return super.convert(value);
  }
}
