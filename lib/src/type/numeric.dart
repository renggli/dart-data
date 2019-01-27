library data.type.numeric;

import 'package:data/src/type/type.dart';

class NumericDataType extends DataType<num> {
  const NumericDataType();

  @override
  String get name => 'numeric';

  @override
  bool get isNullable => true;

  @override
  num get nullValue => null;

  @override
  num convert(Object value) {
    if (value == null || value is num) {
      return value;
    } else if (value is String) {
      final intValue = int.tryParse(value);
      if (intValue != null) {
        return intValue;
      }
      final doubleValue = double.tryParse(value);
      if (doubleValue != null) {
        return doubleValue;
      }
    }
    return super.convert(value);
  }
}
