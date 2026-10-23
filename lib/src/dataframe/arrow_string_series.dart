import 'dart:convert' show utf8;
import 'dart:math' as math;
import 'dart:typed_data';

import '../../type.dart';
import 'bitmask.dart';
import 'series.dart';

/// Apache Arrow-compliant string [Series] backed by a flat UTF-8 byte buffer
/// and offset table.
///
/// Conceptually, this stores text columns without allocating individual heap
/// `String` objects for each cell, minimizing garbage collection overhead on
/// millions of rows. Formally, it adheres to the Apache Arrow `utf8` layout
/// specification:
/// - A flat contiguous `Uint8List` buffer containing all concatenated UTF-8
///   string bytes.
/// - A contiguous `Uint32List` of $N + 1$ byte offsets where row $i$ spans
///   `[offsets[i], offsets[i + 1])`.
/// - An optional [ValidityMask] bitmask for tracking null values.
///
/// ```dart
/// final series = ArrowStringSeries.fromList('names', ['Alice', null, 'Bob']);
/// print(series[0]); // 'Alice'
/// print(series.isNull(1)); // true
/// final bytes = series.getBytes(2); // UTF-8 view of 'Bob'
/// ```
class ArrowStringSeries extends Series<String> {
  /// Constructs an [ArrowStringSeries] from raw buffers.
  new({
    required this.name,
    required this.bytes,
    required this.offsets,
    this.mask,
  }) : length = offsets.length - 1 {
    if (offsets.isEmpty) {
      throw ArgumentError('Offsets buffer must contain at least 1 element.');
    }
    if (offsets[0] != 0) {
      throw ArgumentError('Offsets buffer must start at 0.');
    }
  }

  /// Constructs an [ArrowStringSeries] from an iterable of nullable strings.
  factory fromList(String name, Iterable<String?> list) {
    final strList = list.toList(growable: false);
    final count = strList.length;

    // First pass: compute byte lengths and null mask
    final encodedList = List<Uint8List?>.filled(count, null);
    var totalBytes = 0;
    ValidityMask? validity;

    for (var i = 0; i < count; i++) {
      final s = strList[i];
      if (s == null) {
        validity ??= ValidityMask(count);
        validity.setNull(i);
      } else {
        final encoded = utf8.encode(s);
        encodedList[i] = encoded;
        totalBytes += encoded.length;
      }
    }

    final outBytes = Uint8List(totalBytes);
    final outOffsets = Uint32List(count + 1);
    var currentOffset = 0;
    outOffsets[0] = 0;

    for (var i = 0; i < count; i++) {
      final encoded = encodedList[i];
      if (encoded != null) {
        outBytes.setRange(
          currentOffset,
          currentOffset + encoded.length,
          encoded,
        );
        currentOffset += encoded.length;
      }
      outOffsets[i + 1] = currentOffset;
    }

    return ArrowStringSeries(
      name: name,
      bytes: outBytes,
      offsets: outOffsets,
      mask: validity,
    );
  }

  @override
  final String name;

  /// Flat UTF-8 bytes for all string values.
  final Uint8List bytes;

  /// Byte offsets into [bytes] for each row index.
  final Uint32List offsets;

  /// Optional validity mask for null values.
  @override
  final ValidityMask? mask;

  @override
  final int length;

  @override
  DataType<String> get dataType => DataType.string;

  @override
  int get nullCount => mask?.nullCount ?? 0;

  @override
  bool isNull(int index) => mask?.isNull(index) ?? false;

  /// Returns the raw UTF-8 byte view of the string at [index] without
  /// allocating a `String` instance.
  ///
  /// Returns an empty view if the entry is null or empty.
  Uint8List getBytes(int index) {
    if (index < 0 || index >= length || isNull(index)) {
      return Uint8List(0);
    }
    final start = offsets[index];
    final end = offsets[index + 1];
    if (start >= end) return Uint8List(0);
    return Uint8List.sublistView(bytes, start, end);
  }

  @override
  String? operator [](int index) {
    RangeError.checkValidIndex(index, this, 'index', length);
    if (isNull(index)) return null;
    final start = offsets[index];
    final end = offsets[index + 1];
    if (start >= end) return '';
    return utf8.decode(Uint8List.sublistView(bytes, start, end));
  }

  @override
  Series<String> filter(List<bool> filterMask) {
    if (filterMask.length != length) {
      throw ArgumentError(
        'Filter mask length (${filterMask.length}) does not match series length ($length).',
      );
    }
    var matchCount = 0;
    var filteredBytesTotal = 0;
    for (var i = 0; i < length; i++) {
      if (filterMask[i]) {
        matchCount++;
        if (!isNull(i)) {
          filteredBytesTotal += offsets[i + 1] - offsets[i];
        }
      }
    }

    final newBytes = Uint8List(filteredBytesTotal);
    final newOffsets = Uint32List(matchCount + 1);
    ValidityMask? newMask;
    var currentByte = 0;
    var currentIdx = 0;
    newOffsets[0] = 0;

    for (var i = 0; i < length; i++) {
      if (filterMask[i]) {
        if (isNull(i)) {
          newMask ??= ValidityMask(matchCount);
          newMask.setNull(currentIdx);
        } else {
          final s = offsets[i];
          final e = offsets[i + 1];
          final len = e - s;
          if (len > 0) {
            newBytes.setRange(
              currentByte,
              currentByte + len,
              Uint8List.sublistView(bytes, s, e),
            );
            currentByte += len;
          }
        }
        currentIdx++;
        newOffsets[currentIdx] = currentByte;
      }
    }

    return ArrowStringSeries(
      name: name,
      bytes: newBytes,
      offsets: newOffsets,
      mask: newMask,
    );
  }

  @override
  Series<String> slice(int start, int end) {
    final s = math.max(0, start);
    final e = math.min(length, end);
    if (s >= e) {
      return ArrowStringSeries(
        name: name,
        bytes: Uint8List(0),
        offsets: Uint32List.fromList([0]),
      );
    }
    final count = e - s;
    final byteStart = offsets[s];
    final byteEnd = offsets[e];
    final newBytes = bytes.sublist(byteStart, byteEnd);
    final newOffsets = Uint32List(count + 1);
    for (var i = 0; i <= count; i++) {
      newOffsets[i] = offsets[s + i] - byteStart;
    }
    final newMask = mask?.slice(s, e);
    return ArrowStringSeries(
      name: name,
      bytes: newBytes,
      offsets: newOffsets,
      mask: newMask,
    );
  }

  @override
  Series<String> sort({bool ascending = true, bool nullsLast = true}) {
    final indices = List<int>.generate(length, (i) => i);
    indices.sort((a, b) {
      final aNull = isNull(a);
      final bNull = isNull(b);
      if (aNull && bNull) return 0;
      if (aNull) return nullsLast ? 1 : -1;
      if (bNull) return nullsLast ? -1 : 1;

      final startA = offsets[a];
      final endA = offsets[a + 1];
      final startB = offsets[b];
      final endB = offsets[b + 1];
      final lenA = endA - startA;
      final lenB = endB - startB;
      final minLen = lenA < lenB ? lenA : lenB;
      var cmp = 0;
      for (var k = 0; k < minLen; k++) {
        final byteA = bytes[startA + k];
        final byteB = bytes[startB + k];
        if (byteA != byteB) {
          cmp = byteA.compareTo(byteB);
          break;
        }
      }
      if (cmp == 0) {
        cmp = lenA.compareTo(lenB);
      }
      return ascending ? cmp : -cmp;
    });

    final count = length;
    var totalBytes = 0;
    ValidityMask? newMask;
    for (var i = 0; i < count; i++) {
      final oldIdx = indices[i];
      if (isNull(oldIdx)) {
        newMask ??= ValidityMask(count);
        newMask.setNull(i);
      } else {
        totalBytes += offsets[oldIdx + 1] - offsets[oldIdx];
      }
    }

    final newBytes = Uint8List(totalBytes);
    final newOffsets = Uint32List(count + 1);
    var curOffset = 0;
    for (var i = 0; i < count; i++) {
      newOffsets[i] = curOffset;
      final oldIdx = indices[i];
      if (!isNull(oldIdx)) {
        final start = offsets[oldIdx];
        final end = offsets[oldIdx + 1];
        final len = end - start;
        newBytes.setRange(curOffset, curOffset + len, bytes, start);
        curOffset += len;
      }
    }
    newOffsets[count] = curOffset;

    return ArrowStringSeries(
      name: name,
      bytes: newBytes,
      offsets: newOffsets,
      mask: newMask,
    );
  }

  @override
  Series<String> rename(String newName) => ArrowStringSeries(
    name: newName,
    bytes: bytes,
    offsets: offsets,
    mask: mask,
  );

  @override
  String? get min {
    String? res;
    for (var i = 0; i < length; i++) {
      if (!isNull(i)) {
        final val = this[i]!;
        if (res == null || val.compareTo(res) < 0) res = val;
      }
    }
    return res;
  }

  @override
  String? get max {
    String? res;
    for (var i = 0; i < length; i++) {
      if (!isNull(i)) {
        final val = this[i]!;
        if (res == null || val.compareTo(res) > 0) res = val;
      }
    }
    return res;
  }

  @override
  num? get sum => null;

  @override
  double? get mean => null;
}
