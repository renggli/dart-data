import 'dart:typed_data';

import '../data_type.dart';
import 'memory.dart';

/// Stub implementation of [NativeBuffer] for platforms without `dart:ffi` (e.g. Web).
class NativeBuffer<T> {
  /// Allocates a standard heap buffer when FFI is unavailable.
  factory(int length, {DataType<T>? type}) {
    RangeError.checkNotNegative(length, 'length');
    final effectiveType = type ?? DataType.fromType<T>();
    if (!effectiveType.isNative) {
      throw ArgumentError.value(
        effectiveType,
        'type',
        'NativeBuffer only supports native types, got: $effectiveType',
      );
    }
    final data = effectiveType.newList(length, native: false);
    return NativeBuffer<T>._(data, effectiveType);
  }

  new _(this.data, this.type) : _isDisposed = false;

  /// The underlying list or typed data.
  final List<T> data;

  /// The data type of elements stored in the buffer.
  final DataType<T> type;

  /// The number of elements in the buffer.
  int get length => data.length;

  /// The byte length of the underlying data.
  int get byteLength =>
      data is TypedData ? (data as TypedData).lengthInBytes : data.length * 8;

  /// Checks whether this buffer shares memory with [other].
  bool sharesMemoryWith(dynamic other) {
    if (other is NativeBuffer<dynamic>) return sharesMemory(data, other.data);
    if (other is List<dynamic>) return sharesMemory(data, other);
    return false;
  }

  bool _isDisposed;

  /// Whether native buffers are supported on this platform.
  static const bool isSupported = false;

  /// Whether native buffer allocation is globally enabled.
  static bool isEnabled = false;

  /// Whether native buffers are currently active.
  static bool get isActive => false;

  /// Registers an additional list/view [alias] to point to [buffer].
  static void register(dynamic alias, NativeBuffer<dynamic> buffer) {}

  /// Finds the [NativeBuffer] associated with [target], if any. Always null on non-FFI platforms.
  static NativeBuffer<dynamic>? find(dynamic target) => null;

  /// Whether this native buffer has been disposed.
  bool get isDisposed => _isDisposed;

  /// Manually frees the buffer.
  void dispose() {
    _isDisposed = true;
  }

  /// Returns null on non-FFI platforms.
  dynamic get asDoublePointer => null;

  /// Returns null on non-FFI platforms.
  dynamic get asFloatPointer => null;

  /// Returns null on non-FFI platforms.
  dynamic get asInt32Pointer => null;

  /// Returns null on non-FFI platforms.
  dynamic get asInt64Pointer => null;

  /// Returns null on non-FFI platforms.
  dynamic get asUint8Pointer => null;

  /// Returns null on non-FFI platforms.
  dynamic get pointer => null;
}
