import 'dart:typed_data';

final Map<Object, int> _bufferIds = <Object, int>{};
int _nextBufferId = 1;

int _getBufferId(Object target) {
  var id = _bufferIds[target];
  if (id == null) {
    id = _nextBufferId++;
    _bufferIds[target] = id;
  }
  return id;
}

/// Represents a contiguous memory buffer with identity tracking and safe aliasing detection.
class MemoryBuffer<T> {
  const new empty() : id = 0, data = const [];

  new(this.data)
    : id = _getBufferId(data is TypedData ? (data as TypedData).buffer : data);

  /// Unique identifier of the underlying physical buffer.
  final int id;

  /// The underlying list or typed data.
  final List<T> data;

  /// The number of elements in the buffer.
  int get length => data.length;

  /// The byte length of the underlying data.
  int get byteLength =>
      data is TypedData ? (data as TypedData).lengthInBytes : data.length * 8;

  /// Checks whether two lists share the same underlying memory buffer.
  static bool sharesMemory(List<dynamic> a, List<dynamic> b) {
    if (identical(a, b)) return true;
    if (a is TypedData && b is TypedData) {
      final aTyped = a as TypedData;
      final bTyped = b as TypedData;
      return aTyped.buffer == bTyped.buffer;
    }
    return false;
  }

  /// Checks whether this buffer shares memory with [other].
  bool sharesMemoryWith(MemoryBuffer<Object?> other) => id == other.id;

  /// Checks if this buffer overlaps with [other] over the specified element ranges.
  bool overlaps(
    MemoryBuffer<Object?> other,
    int offset,
    int otherOffset,
    int count,
  ) {
    if (id != other.id) return false;
    if (identical(data, other.data)) {
      final end = offset + count;
      final otherEnd = otherOffset + count;
      return offset < otherEnd && otherOffset < end;
    }
    if (data is TypedData && other.data is TypedData) {
      final a = data as TypedData;
      final b = other.data as TypedData;
      final aElementSize = a.elementSizeInBytes;
      final bElementSize = b.elementSizeInBytes;
      final aStartByte = a.offsetInBytes + offset * aElementSize;
      final aEndByte = aStartByte + count * aElementSize;
      final bStartByte = b.offsetInBytes + otherOffset * bElementSize;
      final bEndByte = bStartByte + count * bElementSize;
      return aStartByte < bEndByte && bStartByte < aEndByte;
    }
    return false;
  }
}
