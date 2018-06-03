library pandas.type.numeric;

import 'package:pandas/src/type.dart';

class NumericDataType extends DataType<num> {
  const NumericDataType();

  @override
  String get name => 'NUMERIC';

  @override
  bool get isNullable => true;

  @override
  num convert(Object value) {
    if (value == null || value is num) {
      return value;
    } else if (value is String) {
      var intValue = int.tryParse(value);
      if (intValue != null) {
        return intValue;
      }
      var doubleValue = double.tryParse(value);
      if (doubleValue != null) {
        return doubleValue;
      }
    }
    return super.convert(value);
  }
}
