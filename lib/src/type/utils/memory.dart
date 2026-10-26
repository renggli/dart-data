import 'dart:typed_data';

import '../types/complex.dart';
import '../types/nullable.dart';

/// Returns `true` if [a] and [b] share the same underlying memory buffer.
bool sharesMemory(List<Object?> a, List<Object?> b) {
  final ua = _unwrapList(a);
  final ub = _unwrapList(b);
  if (identical(ua, ub)) return true;
  final aInfo = _viewInfo(ua);
  final bInfo = _viewInfo(ub);
  if (aInfo != null && bInfo != null) {
    return aInfo.buffer == bInfo.buffer;
  }
  return false;
}

/// Returns `true` if [a] at [aOffset] and [b] at [bOffset] point to the exact
/// same starting memory address.
bool sameStartAddress(
  List<Object?> a,
  int aOffset,
  List<Object?> b,
  int bOffset,
) {
  final ua = _unwrapList(a);
  final ub = _unwrapList(b);
  if (identical(ua, ub)) return aOffset == bOffset;
  final aInfo = _viewInfo(ua);
  final bInfo = _viewInfo(ub);
  if (aInfo != null &&
      bInfo != null &&
      aInfo.buffer == bInfo.buffer &&
      aInfo.elemSize == bInfo.elemSize) {
    return aInfo.offset + aOffset * aInfo.elemSize ==
        bInfo.offset + bOffset * bInfo.elemSize;
  }
  return false;
}

/// Returns `true` if the ranges of [a] and [b] overlap in memory.
bool hasOverlap(
  List<Object?> a,
  int aOffset,
  List<Object?> b,
  int bOffset,
  int count,
) {
  if (count <= 0) return false;
  final ua = _unwrapList(a);
  final ub = _unwrapList(b);
  if (identical(ua, ub)) {
    final aEnd = aOffset + count;
    final bEnd = bOffset + count;
    return aOffset < bEnd && bOffset < aEnd;
  }
  final aInfo = _viewInfo(ua);
  final bInfo = _viewInfo(ub);
  if (aInfo != null && bInfo != null && aInfo.buffer == bInfo.buffer) {
    final aStartByte = aInfo.offset + aOffset * aInfo.elemSize;
    final aEndByte = aStartByte + count * aInfo.elemSize;
    final bStartByte = bInfo.offset + bOffset * bInfo.elemSize;
    final bEndByte = bStartByte + count * bInfo.elemSize;
    return aStartByte < bEndByte && bStartByte < aEndByte;
  }
  return false;
}

List<Object?> _unwrapList(List<Object?> list) {
  var current = list;
  while (true) {
    if (current is NullableList) {
      current = current.delegate;
    } else if (current is UnmodifiableFloat64ComplexList) {
      current = current.source;
    } else {
      return current;
    }
  }
}

typedef _ViewInfo = ({int offset, int elemSize, ByteBuffer buffer});

_ViewInfo? _viewInfo(List<Object?> list) => switch (list) {
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
