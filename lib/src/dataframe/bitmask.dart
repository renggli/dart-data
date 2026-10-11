import 'dart:typed_data';

import 'package:more/math.dart' show BitUint32Extension;

/// Apache Arrow-compliant validity bitmask for tracking null values.
///
/// Each bit represents the validity of a corresponding entry:
/// - 1: Valid (non-null)
/// - 0: Null (missing)
///
/// Example:
/// ```dart
/// final mask = ValidityMask(10);
/// mask.setNull(3);
/// print(mask.nullCount); // 1
/// print(mask.isNull(3)); // true
/// ```
class ValidityMask {
  /// Creates a validity mask of [length] with all entries marked valid
  /// (non-null).
  new(this.length)
    : _bytes = Uint8List(
        (RangeError.checkNotNegative(length, 'length') + 7) ~/ 8,
      ),
      _nullCount = 0 {
    _bytes.fillRange(0, _bytes.length, 0xFF);
    final tail = length % 8;
    if (tail > 0 && _bytes.isNotEmpty) {
      _bytes[_bytes.length - 1] = (1 << tail) - 1;
    }
  }

  /// Creates a validity mask of [length] with all entries marked null.
  new allNull(this.length)
    : _bytes = Uint8List(
        (RangeError.checkNotNegative(length, 'length') + 7) ~/ 8,
      ),
      _nullCount = length;

  /// Creates a validity mask from raw byte buffer [bytes] and [length].
  ///
  /// If [nullCount] is not specified, it is computed using bit-parallel
  /// population count from [BitUint32Extension.bitCount].
  factory fromBytes(int length, Uint8List bytes, [int? nullCount]) {
    RangeError.checkNotNegative(length, 'length');
    if (nullCount != null) {
      RangeError.checkValueInInterval(nullCount, 0, length, 'nullCount');
    }
    final mask = ValidityMask.allNull(length);
    final copyLen = bytes.length < mask._bytes.length
        ? bytes.length
        : mask._bytes.length;
    mask._bytes.setRange(0, copyLen, bytes);
    final tail = length % 8;
    if (tail > 0 && mask._bytes.isNotEmpty) {
      mask._bytes[mask._bytes.length - 1] &= (1 << tail) - 1;
    }
    mask._nullCount = nullCount ?? (length - _popCountBytes(mask._bytes));
    return mask;
  }

  /// Creates a validity mask from a list of boolean validity flags, where
  /// `true` indicates valid (non-null) and `false` indicates null.
  factory fromList(List<bool> list) {
    final length = list.length;
    final mask = ValidityMask.allNull(length);
    var nulls = 0;
    for (var i = 0; i < length; i++) {
      if (list[i]) {
        mask._bytes[i >> 3] |= 1 << (i & 7);
      } else {
        nulls++;
      }
    }
    mask._nullCount = nulls;
    return mask;
  }

  new _(this.length, this._bytes, this._nullCount);

  /// The number of entries tracked by this mask.
  final int length;

  final Uint8List _bytes;
  int _nullCount;

  /// The underlying raw byte buffer.
  Uint8List get bytes => _bytes;

  /// Returns the total count of null entries in $\mathcal{O}(1)$ time.
  int get nullCount => _nullCount;

  /// Returns true if this mask contains at least one null entry.
  bool get hasNulls => _nullCount > 0;

  /// Returns true if the entry at [index] is null.
  bool isNull(int index) {
    if (index < 0 || index >= length) {
      throw RangeError.index(index, this, 'index', null, length);
    }
    return (_bytes[index >> 3] & (1 << (index & 7))) == 0;
  }

  /// Returns true if the entry at [index] is valid (non-null).
  bool isValid(int index) => !isNull(index);

  /// Sets the entry at [index] as null.
  void setNull(int index) {
    if (index < 0 || index >= length) {
      throw RangeError.index(index, this, 'index', null, length);
    }
    final byteIndex = index >> 3;
    final bitMask = 1 << (index & 7);
    if ((_bytes[byteIndex] & bitMask) != 0) {
      _bytes[byteIndex] &= ~bitMask;
      _nullCount++;
    }
  }

  /// Sets the entry at [index] as valid (non-null).
  void setValid(int index) {
    if (index < 0 || index >= length) {
      throw RangeError.index(index, this, 'index', null, length);
    }
    final byteIndex = index >> 3;
    final bitMask = 1 << (index & 7);
    if ((_bytes[byteIndex] & bitMask) == 0) {
      _bytes[byteIndex] |= bitMask;
      _nullCount--;
    }
  }

  /// Creates a slice of this validity mask from [start] (inclusive) to [end]
  /// (exclusive).
  ValidityMask slice(int start, int end) {
    RangeError.checkValidRange(start, end, length);
    final sliceLen = end - start;
    if (sliceLen == 0) {
      return ValidityMask(0);
    }
    if (_nullCount == 0) {
      return ValidityMask(sliceLen);
    }
    if (_nullCount == length) {
      return ValidityMask.allNull(sliceLen);
    }
    if (start % 8 == 0) {
      final startByte = start >> 3;
      final numBytes = (sliceLen + 7) >> 3;
      final sliceBytes = _bytes.sublist(startByte, startByte + numBytes);
      return ValidityMask.fromBytes(sliceLen, sliceBytes);
    }
    final result = ValidityMask(sliceLen);
    var nulls = 0;
    for (var i = 0; i < sliceLen; i++) {
      final srcIndex = start + i;
      if ((_bytes[srcIndex >> 3] & (1 << (srcIndex & 7))) == 0) {
        result._bytes[i >> 3] &= ~(1 << (i & 7));
        nulls++;
      }
    }
    result._nullCount = nulls;
    return result;
  }

  /// Creates a deep copy of this validity mask.
  ValidityMask copy() =>
      ValidityMask._(length, Uint8List.fromList(_bytes), _nullCount);

  /// Computes the population count (number of set 1-bits) across [bytes].
  static int _popCountBytes(Uint8List bytes) {
    var count = 0;
    var offset = 0;
    final wordBytes = bytes.length & ~3;
    if (wordBytes > 0) {
      final byteData = ByteData.sublistView(bytes);
      while (offset < wordBytes) {
        count += byteData.getUint32(offset, Endian.little).bitCount;
        offset += 4;
      }
    }
    while (offset < bytes.length) {
      count += bytes[offset].bitCount;
      offset++;
    }
    return count;
  }
}
