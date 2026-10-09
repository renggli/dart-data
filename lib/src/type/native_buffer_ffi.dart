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

  /// Whether native buffers are supported on this platform.
  static const bool isSupported = true;

  /// Whether native buffer allocation is globally enabled.
  static bool isEnabled = true;

  /// Whether native buffers are currently active.
  static bool get isActive => isSupported && isEnabled;

  /// Allocates an off-heap native buffer of [length] elements of [type].
  factory(int length, {DataType<T>? type}) {
    RangeError.checkNotNegative(length, 'length');
    final effectiveType = type ?? DataType.fromType<T>();
    final allocLength = length <= 0 ? 1 : length;
    if ((effectiveType as DataType<dynamic>) == DataType.float32) {
      final ptr = calloc<ffi.Float>(allocLength);
      final typedList = ptr.asTypedList(length);
      return NativeBuffer<T>._(ptr, typedList as List<T>, effectiveType);
    } else if ((effectiveType as DataType<dynamic>) == DataType.int32) {
      final ptr = calloc<ffi.Int32>(allocLength);
      final typedList = ptr.asTypedList(length);
      return NativeBuffer<T>._(ptr, typedList as List<T>, effectiveType);
    } else if ((effectiveType as DataType<dynamic>) == DataType.int64) {
      final ptr = calloc<ffi.Int64>(allocLength);
      final typedList = ptr.asTypedList(length);
      return NativeBuffer<T>._(ptr, typedList as List<T>, effectiveType);
    } else if ((effectiveType as DataType<dynamic>) == DataType.int16) {
      final ptr = calloc<ffi.Int16>(allocLength);
      final typedList = ptr.asTypedList(length);
      return NativeBuffer<T>._(ptr, typedList as List<T>, effectiveType);
    } else if ((effectiveType as DataType<dynamic>) == DataType.int8) {
      final ptr = calloc<ffi.Int8>(allocLength);
      final typedList = ptr.asTypedList(length);
      return NativeBuffer<T>._(ptr, typedList as List<T>, effectiveType);
    } else if ((effectiveType as DataType<dynamic>) == DataType.uint8) {
      final ptr = calloc<ffi.Uint8>(allocLength);
      final typedList = ptr.asTypedList(length);
      return NativeBuffer<T>._(ptr, typedList as List<T>, effectiveType);
    } else if ((effectiveType as DataType<dynamic>) == DataType.uint16) {
      final ptr = calloc<ffi.Uint16>(allocLength);
      final typedList = ptr.asTypedList(length);
      return NativeBuffer<T>._(ptr, typedList as List<T>, effectiveType);
    } else if ((effectiveType as DataType<dynamic>) == DataType.uint32) {
      final ptr = calloc<ffi.Uint32>(allocLength);
      final typedList = ptr.asTypedList(length);
      return NativeBuffer<T>._(ptr, typedList as List<T>, effectiveType);
    } else if ((effectiveType as DataType<dynamic>) == DataType.uint64) {
      final ptr = calloc<ffi.Uint64>(allocLength);
      final typedList = ptr.asTypedList(length);
      return NativeBuffer<T>._(ptr, typedList as List<T>, effectiveType);
    } else if ((effectiveType as DataType<dynamic>) == DataType.float64) {
      final ptr = calloc<ffi.Double>(allocLength);
      final typedList = ptr.asTypedList(length);
      return NativeBuffer<T>._(ptr, typedList as List<T>, effectiveType);
    } else {
      throw ArgumentError.value(
        effectiveType,
        'type',
        'Unsupported data type for NativeBuffer: $effectiveType',
      );
    }
  }

  static final ffi.NativeFinalizer _finalizer = ffi.NativeFinalizer(
    calloc.nativeFree,
  );
  static final Expando<NativeBuffer<dynamic>> _expando =
      Expando<NativeBuffer<dynamic>>();

  /// Registers an additional list/view [alias] to point to [buffer].
  static void register(dynamic alias, NativeBuffer<dynamic> buffer) {
    if (alias is List) {
      _expando[alias] = buffer;
    }
  }

  /// Finds the [NativeBuffer] associated with [target], if any.
  static NativeBuffer<dynamic>? find(dynamic target) {
    if (target == null) return null;
    if (target is NativeBuffer<dynamic>) return target;
    if (target is MemoryBuffer<dynamic>) {
      return target is NativeBuffer<dynamic> ? target : find(target.data);
    }
    if (target is List) return _expando[target];
    try {
      final dynamic buf = (target as dynamic).buffer;
      if (buf is NativeBuffer<dynamic>) return buf;
      if (buf is MemoryBuffer<dynamic>) return find(buf);
    } catch (_) {}
    try {
      final dynamic tensor = (target as dynamic).tensor;
      if (tensor != null) return find(tensor);
    } catch (_) {}
    try {
      final dynamic data = (target as dynamic).data;
      if (data is List) return _expando[data];
    } catch (_) {}
    return null;
  }

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

  /// Returns the pointer cast to [ffi.Pointer<ffi.Int32>], or null if disposed.
  ffi.Pointer<ffi.Int32>? get asInt32Pointer =>
      _isDisposed ? null : pointer.cast<ffi.Int32>();

  /// Returns the pointer cast to [ffi.Pointer<ffi.Int64>], or null if disposed.
  ffi.Pointer<ffi.Int64>? get asInt64Pointer =>
      _isDisposed ? null : pointer.cast<ffi.Int64>();

  /// Returns the pointer cast to [ffi.Pointer<ffi.Uint8>], or null if disposed.
  ffi.Pointer<ffi.Uint8>? get asUint8Pointer =>
      _isDisposed ? null : pointer.cast<ffi.Uint8>();
}
