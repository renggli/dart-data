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
  dynamic cast(dynamic value) => value;
}
