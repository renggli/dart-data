import '../type.dart';

class DynamicDataType extends DataType<dynamic> {
  const DynamicDataType();

  @override
  String get name => 'dynamic';

  @override
  dynamic get defaultValue => null;

  @override
  bool get isNullable => true;

  @override
  int comparator(dynamic a, dynamic b) => (a as Comparable).compareTo(b);

  @override
  dynamic cast(dynamic value) => value;
}
