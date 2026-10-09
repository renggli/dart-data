import '../data_type.dart';

class ObjectDataType<T> extends DataType<T> {
  const new(this.defaultValue);

  @override
  final T defaultValue;

  @override
  String get name => T == dynamic || T == Object || defaultValue == null
      ? 'object'
      : 'object<$T>';

  @override
  bool get isNullable => null is T;

  @override
  ObjectDataType<T?> get nullable => ObjectDataType<T?>(null);

  @override
  T cast(dynamic value) => value as T;

  @override
  int get hashCode => Object.hash(T, defaultValue);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ObjectDataType<T> && defaultValue == other.defaultValue);
}
