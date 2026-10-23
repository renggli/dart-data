import '../data_type.dart';

/// Data type descriptor for untyped values ([dynamic]).
final class DynamicDataType extends DataType<dynamic> {
  /// Creates a new [DynamicDataType] instance.
  const new();

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
