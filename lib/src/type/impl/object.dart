import 'package:more/hash.dart';

import '../type.dart';

class ObjectDataType<T> extends DataType<T> {
  const ObjectDataType(this.defaultValue);

  @override
  String get name => 'object<$T>';

  @override
  final T defaultValue;

  @override
  bool get isNullable => null is T;

  @override
  ObjectDataType<T?> get nullable => ObjectDataType<T?>(null);

  @override
  T cast(dynamic value) => value is T ? value : super.cast(value);

  @override
  int get hashCode => hash2(T, defaultValue);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ObjectDataType<T> && defaultValue == other.defaultValue);
}
