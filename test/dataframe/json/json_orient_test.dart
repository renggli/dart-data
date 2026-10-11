import 'package:checks/checks.dart';
import 'package:data/dataframe.dart';
import 'package:test/test.dart';

void main() {
  group('JsonOrient', () {
    test('values enumeration', () {
      check(JsonOrient.values).contains(JsonOrient.records);
      check(JsonOrient.values).contains(JsonOrient.split);
      check(JsonOrient.values).contains(JsonOrient.columns);
      check(JsonOrient.values).contains(JsonOrient.values_);
    });
  });
}
