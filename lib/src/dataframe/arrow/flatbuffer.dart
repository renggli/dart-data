import 'dart:convert' show utf8;
import 'dart:typed_data';

/// Minimal FlatBuffer data types for Arrow IPC message headers.
enum FbFieldType { boolean, uint8, int16, int32, int64, offset }

/// Minimal FlatBuffer builder creating Arrow-compliant IPC messages.
class FlatBufferWriter {
  Uint8List _buf = Uint8List(1024);
  int _head = 1024;

  int get offset => _buf.length - _head;

  void pad(int alignment) {
    final curOffset = offset;
    final rem = curOffset % alignment;
    if (rem != 0) {
      final needed = alignment - rem;
      _ensure(needed);
      for (var i = 0; i < needed; i++) {
        _head--;
        _buf[_head] = 0;
      }
    }
  }

  void putUint8(int val) {
    _ensure(1);
    _head--;
    _buf[_head] = val & 0xFF;
  }

  void putUint16(int val) {
    pad(2);
    _ensure(2);
    _head -= 2;
    ByteData.sublistView(
      _buf,
      _head,
      _head + 2,
    ).setUint16(0, val, Endian.little);
  }

  void putInt16(int val) {
    pad(2);
    _ensure(2);
    _head -= 2;
    ByteData.sublistView(
      _buf,
      _head,
      _head + 2,
    ).setInt16(0, val, Endian.little);
  }

  void putInt32(int val) {
    pad(4);
    _ensure(4);
    _head -= 4;
    ByteData.sublistView(
      _buf,
      _head,
      _head + 4,
    ).setInt32(0, val, Endian.little);
  }

  void putUint32(int val) {
    pad(4);
    _ensure(4);
    _head -= 4;
    ByteData.sublistView(
      _buf,
      _head,
      _head + 4,
    ).setUint32(0, val, Endian.little);
  }

  void putInt64(int val) {
    pad(8);
    _ensure(8);
    _head -= 8;
    writeInt64LE(ByteData.sublistView(_buf, _head, _head + 8), 0, val);
  }

  void putOffset(int targetOffset) {
    pad(4);
    final rel = offset + 4 - targetOffset;
    putUint32(rel);
  }

  int addString(String str) {
    final bytes = utf8.encode(str);
    final unpadded = bytes.length + 1;
    final padBytes = (4 - (unpadded % 4)) % 4;
    for (var i = 0; i < padBytes; i++) {
      putUint8(0);
    }
    putUint8(0); // null terminator
    _ensure(bytes.length + 4);
    _head -= bytes.length;
    _buf.setRange(_head, _head + bytes.length, bytes);
    _head -= 4;
    ByteData.sublistView(
      _buf,
      _head,
      _head + 4,
    ).setUint32(0, bytes.length, Endian.little);
    return offset;
  }

  int addOffsetVector(List<int> offsets) {
    pad(4);
    for (var i = offsets.length - 1; i >= 0; i--) {
      putOffset(offsets[i]);
    }
    putUint32(offsets.length);
    return offset;
  }

  int addStructVector<T>(
    List<T> structs,
    void Function(T item, FlatBufferWriter writer) writeStruct,
    int structSize,
  ) {
    pad(8); // Struct vectors in Arrow are 8-byte aligned (FieldNode, Buffer)
    for (var i = structs.length - 1; i >= 0; i--) {
      writeStruct(structs[i], this);
    }
    putUint32(structs.length);
    return offset;
  }

  int addTable(List<Object?> fieldValues, List<FbFieldType> fieldTypes) {
    final fieldLocs = List<int>.filled(fieldValues.length, 0);

    // Write table fields in forward order (so higher offset fields are written
    // first in reverse)
    for (var i = fieldValues.length - 1; i >= 0; i--) {
      final val = fieldValues[i];
      if (val == null) continue;
      final type = fieldTypes[i];
      switch (type) {
        case FbFieldType.boolean:
          putUint8(val is bool ? (val ? 1 : 0) : val as int);
        case FbFieldType.uint8:
          putUint8(val as int);
        case FbFieldType.int16:
          putInt16(val as int);
        case FbFieldType.int32:
          putInt32(val as int);
        case FbFieldType.int64:
          putInt64(val as int);
        case FbFieldType.offset:
          putOffset(val as int);
      }
      fieldLocs[i] = offset;
    }

    pad(4);
    putInt32(0); // Reserve 4 bytes for soffset_t
    final tableStart = offset;

    // Write vtable
    final vtableOffsets = List<int>.filled(fieldValues.length, 0);
    for (var i = 0; i < fieldValues.length; i++) {
      if (fieldValues[i] != null) {
        vtableOffsets[i] = tableStart - fieldLocs[i];
      }
    }

    var minLoc = tableStart;
    for (final loc in fieldLocs) {
      if (loc != 0 && loc < minLoc) {
        minLoc = loc;
      }
    }
    final tableSize = minLoc < tableStart ? tableStart - minLoc : 4;
    final vtableLength = 4 + 2 * fieldValues.length;

    pad(2);
    for (var i = vtableOffsets.length - 1; i >= 0; i--) {
      putUint16(vtableOffsets[i]);
    }
    putUint16(tableSize);
    putUint16(vtableLength);

    final vtablePos = offset;

    // Fill in soffset_t at tableStart
    final bufTablePos = _buf.length - tableStart;
    ByteData.sublistView(
      _buf,
      bufTablePos,
      bufTablePos + 4,
    ).setInt32(0, vtablePos - tableStart, Endian.little);

    return tableStart;
  }

  void finish(int rootTableOffset) {
    pad(4);
    putOffset(rootTableOffset);
  }

  Uint8List toBytes() => Uint8List.sublistView(_buf, _head);

  void _ensure(int additionalBytes) {
    if (_head < additionalBytes) {
      final oldLen = _buf.length;
      final newLen = oldLen * 2 + additionalBytes;
      final newBuf = Uint8List(newLen);
      final newHead = newLen - (oldLen - _head);
      newBuf.setRange(newHead, newLen, _buf.sublist(_head));
      _buf = newBuf;
      _head = newHead;
    }
  }
}

/// Minimal FlatBuffer reader for extracting fields from Arrow messages.
class FlatBufferReader {
  new(this.bytes);

  final Uint8List bytes;

  int get rootTableOffset {
    final view = ByteData.sublistView(bytes, 0, 4);
    return view.getUint32(0, Endian.little);
  }

  int? readUint8(int tablePos, int fieldIndex) {
    final pos = _getFieldPos(tablePos, fieldIndex);
    if (pos == null) return null;
    return bytes[pos];
  }

  int? readInt16(int tablePos, int fieldIndex) {
    final pos = _getFieldPos(tablePos, fieldIndex);
    if (pos == null) return null;
    return ByteData.sublistView(bytes, pos, pos + 2).getInt16(0, Endian.little);
  }

  int? readInt32(int tablePos, int fieldIndex) {
    final pos = _getFieldPos(tablePos, fieldIndex);
    if (pos == null) return null;
    return ByteData.sublistView(bytes, pos, pos + 4).getInt32(0, Endian.little);
  }

  int? readInt64(int tablePos, int fieldIndex) {
    final pos = _getFieldPos(tablePos, fieldIndex);
    if (pos == null) return null;
    return readInt64LE(ByteData.sublistView(bytes, pos, pos + 8), 0);
  }

  int? readTableOffset(int tablePos, int fieldIndex) {
    final pos = _getFieldPos(tablePos, fieldIndex);
    if (pos == null) return null;
    final rel = ByteData.sublistView(
      bytes,
      pos,
      pos + 4,
    ).getUint32(0, Endian.little);
    return pos + rel;
  }

  int? readVectorOffset(int tablePos, int fieldIndex) =>
      readTableOffset(tablePos, fieldIndex);

  int vectorLength(int vectorPos) => ByteData.sublistView(
    bytes,
    vectorPos,
    vectorPos + 4,
  ).getUint32(0, Endian.little);

  int vectorTableAt(int vectorPos, int index) {
    final elemPos = vectorPos + 4 + index * 4;
    final rel = ByteData.sublistView(
      bytes,
      elemPos,
      elemPos + 4,
    ).getUint32(0, Endian.little);
    return elemPos + rel;
  }

  String? readString(int tablePos, int fieldIndex) {
    final strPos = readTableOffset(tablePos, fieldIndex);
    if (strPos == null) return null;
    final len = ByteData.sublistView(
      bytes,
      strPos,
      strPos + 4,
    ).getUint32(0, Endian.little);
    return utf8.decode(
      Uint8List.sublistView(bytes, strPos + 4, strPos + 4 + len),
    );
  }

  int? _getFieldPos(int tablePos, int fieldIndex) {
    if (tablePos < 0 || tablePos + 4 > bytes.length) return null;
    final view = ByteData.sublistView(bytes);
    final soffset = view.getInt32(tablePos, Endian.little);
    final vtablePos = tablePos - soffset;
    if (vtablePos < 0 || vtablePos + 2 > bytes.length) return null;
    final vtableLength = view.getUint16(vtablePos, Endian.little);
    final fieldOffsetPos = vtablePos + 4 + fieldIndex * 2;
    if (fieldOffsetPos + 2 > vtablePos + vtableLength) return null;
    final offsetInTable = view.getUint16(fieldOffsetPos, Endian.little);
    if (offsetInTable == 0) return null;
    return tablePos + offsetInTable;
  }
}

/// Reads a 64-bit signed integer from little-endian byte data.
int readInt64LE(ByteData data, int offset) {
  final low = data.getUint32(offset, Endian.little);
  final high = data.getInt32(offset + 4, Endian.little);
  return high * 0x100000000 + low;
}

/// Writes a 64-bit signed integer into little-endian byte data.
void writeInt64LE(ByteData data, int offset, int val) {
  final low = val & 0xFFFFFFFF;
  final high = ((val - low) ~/ 0x100000000) & 0xFFFFFFFF;
  data.setUint32(offset, low, Endian.little);
  data.setUint32(offset + 4, high, Endian.little);
}

/// Reads a 64-bit unsigned integer from little-endian byte data.
int readUint64LE(ByteData data, int offset) {
  final low = data.getUint32(offset, Endian.little);
  final high = data.getUint32(offset + 4, Endian.little);
  return high * 0x100000000 + low;
}

/// Writes a 64-bit unsigned integer into little-endian byte data.
void writeUint64LE(ByteData data, int offset, int val) {
  final low = val & 0xFFFFFFFF;
  final high = ((val - low) ~/ 0x100000000) & 0xFFFFFFFF;
  data.setUint32(offset, low, Endian.little);
  data.setUint32(offset + 4, high, Endian.little);
}
