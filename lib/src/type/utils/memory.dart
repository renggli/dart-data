import 'dart:typed_data';

/// Returns `true` if [a] and [b] share the same underlying memory buffer.
bool sharesMemory(List<dynamic> a, List<dynamic> b) {
  if (identical(a, b)) return true;
  if ((a, b) case (final TypedData aTyped, final TypedData bTyped)) {
    return aTyped.buffer == bTyped.buffer;
  }
  return false;
}

/// Returns `true` if the ranges of [a] and [b] overlap in memory.
bool hasOverlap(
  List<dynamic> a,
  int aOffset,
  List<dynamic> b,
  int bOffset,
  int count,
) {
  if (count <= 0) return false;
  if (identical(a, b)) {
    final aEnd = aOffset + count;
    final bEnd = bOffset + count;
    return aOffset < bEnd && bOffset < aEnd;
  }
  if ((a, b) case (final TypedData aTyped, final TypedData bTyped)) {
    if (aTyped.buffer == bTyped.buffer) {
      final aStartByte =
          aTyped.offsetInBytes + aOffset * aTyped.elementSizeInBytes;
      final aEndByte = aStartByte + count * aTyped.elementSizeInBytes;
      final bStartByte =
          bTyped.offsetInBytes + bOffset * bTyped.elementSizeInBytes;
      final bEndByte = bStartByte + count * bTyped.elementSizeInBytes;
      return aStartByte < bEndByte && bStartByte < aEndByte;
    }
  }
  return false;
}
