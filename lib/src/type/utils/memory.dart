import 'dart:typed_data';

import '../types/complex.dart';

/// Returns `true` if [a] and [b] share the same underlying memory buffer.
bool sharesMemory(List<dynamic> a, List<dynamic> b) {
  if (identical(a, b)) return true;
  final aInfo = _viewInfo(a);
  final bInfo = _viewInfo(b);
  if (aInfo != null && bInfo != null) {
    return aInfo.buffer == bInfo.buffer;
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
  final aInfo = _viewInfo(a);
  final bInfo = _viewInfo(b);
  if (aInfo != null && bInfo != null && aInfo.buffer == bInfo.buffer) {
    final aStartByte = aInfo.offset + aOffset * aInfo.elemSize;
    final aEndByte = aStartByte + count * aInfo.elemSize;
    final bStartByte = bInfo.offset + bOffset * bInfo.elemSize;
    final bEndByte = bStartByte + count * bInfo.elemSize;
    return aStartByte < bEndByte && bStartByte < aEndByte;
  }
  return false;
}

typedef _ViewInfo = ({int offset, int elemSize, ByteBuffer buffer});

_ViewInfo? _viewInfo(List<dynamic> list) => switch (list) {
  final TypedData t => (
    offset: t.offsetInBytes,
    elemSize: t.elementSizeInBytes,
    buffer: t.buffer,
  ),
  final Float64ComplexList t => (
    offset: t.offsetInBytes,
    elemSize: t.elementSizeInBytes,
    buffer: t.buffer,
  ),
  _ => null,
};
