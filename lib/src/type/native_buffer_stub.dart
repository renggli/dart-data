import 'data_type.dart';
import 'memory_buffer.dart';

/// Stub implementation of [NativeBuffer] for platforms without `dart:ffi` (e.g. Web).
class NativeBuffer<T> extends MemoryBuffer<T> {
  /// Allocates a standard heap buffer when FFI is unavailable.
  factory(int length, {DataType<T>? type}) {
    RangeError.checkNotNegative(length, 'length');
    final effectiveType = type ?? DataType.fromType<T>();
    final dynamicType = effectiveType as DataType<dynamic>;
    if (dynamicType != DataType.float64 &&
        dynamicType != DataType.float32 &&
        dynamicType != DataType.int32 &&
        dynamicType != DataType.int64 &&
        dynamicType != DataType.uint8) {
      throw ArgumentError.value(
        effectiveType,
        'type',
        'NativeBuffer only supports float64, float32, int32, int64, and uint8',
      );
    }
    final data = effectiveType.newList(length);
    return NativeBuffer<T>._(data, effectiveType);
  }

  new _(super.data, this.type) : _isDisposed = false;

  /// The data type of elements stored in the buffer.
  final DataType<T> type;

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
