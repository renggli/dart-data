import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';

import 'data_type.dart';
import 'memory_buffer.dart';

/// Off-heap native memory buffer managed via [calloc] and [ffi.NativeFinalizer].
class NativeBuffer<T> extends MemoryBuffer<T> implements ffi.Finalizable {
  new _(this.pointer, List<T> data, this.type)
    : _isDisposed = false,
      super(data) {
    _finalizer.attach(this, pointer.cast(), detach: this);
    _expando[data] = this;
  }

  /// Allocates an off-heap native buffer of [length] elements of [type].
  factory(int length, {DataType<T>? type}) {
    final effectiveType = type ?? DataType.fromType<T>();
    if ((effectiveType as DataType<dynamic>) == DataType.float32) {
      final ptr = calloc<ffi.Float>(length);
      final typedList = ptr.asTypedList(length);
      return NativeBuffer<T>._(ptr, typedList as List<T>, effectiveType);
    } else if ((effectiveType as DataType<dynamic>) == DataType.int32) {
      final ptr = calloc<ffi.Int32>(length);
      final typedList = ptr.asTypedList(length);
      return NativeBuffer<T>._(ptr, typedList as List<T>, effectiveType);
    } else if ((effectiveType as DataType<dynamic>) == DataType.int64) {
      final ptr = calloc<ffi.Int64>(length);
      final typedList = ptr.asTypedList(length);
      return NativeBuffer<T>._(ptr, typedList as List<T>, effectiveType);
    } else if ((effectiveType as DataType<dynamic>) == DataType.uint8) {
      final ptr = calloc<ffi.Uint8>(length);
      final typedList = ptr.asTypedList(length);
      return NativeBuffer<T>._(ptr, typedList as List<T>, effectiveType);
    } else {
      final ptr = calloc<ffi.Double>(length);
      final typedList = ptr.asTypedList(length);
      return NativeBuffer<T>._(ptr, typedList as List<T>, effectiveType);
    }
  }

  static final ffi.NativeFinalizer _finalizer = ffi.NativeFinalizer(
    calloc.nativeFree,
  );
  static final Expando<NativeBuffer<dynamic>> _expando =
      Expando<NativeBuffer<dynamic>>();

  /// Finds the [NativeBuffer] associated with [list], if any.
  static NativeBuffer<dynamic>? find(dynamic list) =>
      list is List ? _expando[list] : null;

  /// The raw native pointer.
  final ffi.Pointer<ffi.NativeType> pointer;

  /// The data type of elements stored in the buffer.
  final DataType<T> type;

  bool _isDisposed;

  /// Whether this native buffer has been manually freed.
  bool get isDisposed => _isDisposed;

  /// Manually frees the native memory immediately.
  void dispose() {
    if (!_isDisposed) {
      _finalizer.detach(this);
      _expando[data] = null;
      calloc.free(pointer);
      _isDisposed = true;
    }
  }

  /// Returns the pointer cast to [ffi.Pointer<ffi.Double>], or null if disposed.
  ffi.Pointer<ffi.Double>? get asDoublePointer =>
      _isDisposed ? null : pointer.cast<ffi.Double>();

  /// Returns the pointer cast to [ffi.Pointer<ffi.Float>], or null if disposed.
  ffi.Pointer<ffi.Float>? get asFloatPointer =>
      _isDisposed ? null : pointer.cast<ffi.Float>();
}
