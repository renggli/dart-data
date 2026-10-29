import '../data_type.dart';

/// Data type descriptor for generic Dart objects ([Object]).
final class ObjectDataType<T> extends DataType<T> {
  /// Creates a new [ObjectDataType] instance with a specified [defaultValue].
  const new([T? defaultValue]) : _defaultValue = defaultValue;

  final T? _defaultValue;

  @override
  T get defaultValue {
    final val = _defaultValue;
    if (val is T) return val;
    throw StateError('No defaultValue configured for $this');
  }

  @override
  String get name => _isGeneralType<T>() ? 'object' : 'object<$T>';

  @override
  bool get isNullable => null is T;

  @override
  ObjectDataType<T?> get nullable => isNullable
      ? this as ObjectDataType<T?>
      : ObjectDataType<T?>(_defaultValue);

  @override
  T cast(Object? value) => value as T;

  @override
  int get hashCode => Object.hash(T, _defaultValue);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ObjectDataType<T> && _defaultValue == other._defaultValue);
}

Type _typeOf<T>() => T;

bool _isGeneralType<T>() =>
    T == dynamic || T == Object || _typeOf<T>() == _typeOf<Object?>();
