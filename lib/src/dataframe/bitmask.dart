import 'dart:typed_data';

/// Apache Arrow-compliant validity bitmask for tracking null values.
///
/// Each bit represents the validity of a corresponding entry:
/// - 1: Valid (non-null)
/// - 0: Null (missing)
class ValidityMask {
  new(this.length) : _bytes = Uint8List((length + 7) ~/ 8) {
    // Initialize all entries as valid (all 1s)
    _bytes.fillRange(0, _bytes.length, 0xFF);
    // Clear unused tail bits
    final tail = length % 8;
    if (tail > 0) {
      _bytes[_bytes.length - 1] = (1 << tail) - 1;
    }
  }

  new fromBytes(this.length, Uint8List bytes)
    : _bytes = Uint8List.fromList(bytes);

  final int length;
  final Uint8List _bytes;

  /// The underlying raw byte buffer.
  Uint8List get bytes => _bytes;

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
    _bytes[index >> 3] &= ~(1 << (index & 7));
  }

  /// Sets the entry at [index] as valid (non-null).
  void setValid(int index) {
    if (index < 0 || index >= length) {
      throw RangeError.index(index, this, 'index', null, length);
    }
    _bytes[index >> 3] |= 1 << (index & 7);
  }

  /// Returns the total count of null entries.
  int get nullCount {
    var count = 0;
    for (var i = 0; i < length; i++) {
      if (isNull(i)) count++;
    }
    return count;
  }

  /// Creates a deep copy of this validity mask.
  ValidityMask copy() => ValidityMask.fromBytes(length, _bytes);
}
