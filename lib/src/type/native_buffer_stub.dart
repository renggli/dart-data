import 'data_type.dart';
import 'memory_buffer.dart';

/// Stub implementation of [NativeBuffer] for platforms without `dart:ffi` (e.g. Web).
class NativeBuffer<T> extends MemoryBuffer<T> {
  new _(super.data, this.type) : _isDisposed = false;

  /// Allocates a standard heap buffer when FFI is unavailable.
  factory(int length, {DataType<T>? type}) {
    final effectiveType = type ?? DataType.fromType<T>();
    final data = effectiveType.newList(length);
    return NativeBuffer<T>._(data, effectiveType);
  }

  /// Finds the [NativeBuffer] associated with [list], if any. Always null on non-FFI platforms.
  static NativeBuffer<dynamic>? find(dynamic list) => null;

  /// The data type of elements stored in the buffer.
  final DataType<T> type;

  bool _isDisposed;

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
  dynamic get pointer => null;
}
