import 'package:more/collection.dart' show BitList;

import '../type.dart';

const _trueStrings = ['true', 't', 'yes', 'y', '1'];
const _falseStrings = ['false', 'f', 'no', 'n', '0'];

class BooleanDataType extends DataType<bool> {
  const BooleanDataType();

  @override
  String get name => 'boolean';

  @override
  bool get defaultValue => false;

  @override
  List<bool> newList(int length, [bool? fillValue]) =>
      BitList.filled(length, fillValue ?? defaultValue);

  @override
  bool cast(dynamic value) {
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
    return super.cast(value);
  }
}
