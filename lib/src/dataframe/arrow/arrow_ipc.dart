import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../../type.dart';
import '../arrow_string_series.dart';
import '../bitmask.dart';
import '../dataframe.dart';
import '../series.dart';

int _readInt64(ByteData data, int offset) {
  final low = data.getUint32(offset, Endian.little);
  final high = data.getInt32(offset + 4, Endian.little);
  return high * 0x100000000 + low;
}

void _writeInt64(ByteData data, int offset, int val) {
  final high = val < 0
      ? (val - 0x100000000 + 1) ~/ 0x100000000
      : val ~/ 0x100000000;
  final low = val - high * 0x100000000;
  data.setUint32(offset, low, Endian.little);
  data.setInt32(offset + 4, high, Endian.little);
}

int _readUint64(ByteData data, int offset) {
  final low = data.getUint32(offset, Endian.little);
  final high = data.getUint32(offset + 4, Endian.little);
  return high * 0x100000000 + low;
}

void _writeUint64(ByteData data, int offset, int val) {
  final high = val ~/ 0x100000000;
  final low = val - high * 0x100000000;
  data.setUint32(offset, low, Endian.little);
  data.setUint32(offset + 4, high, Endian.little);
}

/// Apache Arrow IPC stream serializer and deserializer.
///
/// Encodes and decodes DataFrames to and from the official Apache Arrow IPC
/// Streaming format (encapsulated schema and record batches).
abstract final class ArrowIpc {
  /// Encodes a [DataFrame] into an Apache Arrow IPC stream byte buffer.
  static Uint8List encode(DataFrame df) {
    final builder = _ArrowIpcStreamWriter([df]);
    return builder.build();
  }

  /// Encodes multiple [DataFrame] batches sharing the same schema into an
  /// Apache Arrow IPC stream byte buffer.
  static Uint8List encodeBatches(List<DataFrame> batches) {
    if (batches.isEmpty) return encode(DataFrame([]));
    final builder = _ArrowIpcStreamWriter(batches);
    return builder.build();
  }

  /// Decodes an Apache Arrow IPC stream byte buffer into a [DataFrame].
  static DataFrame decode(Uint8List bytes) {
    final reader = _ArrowIpcStreamReader(bytes);
    return reader.read();
  }

  /// For testing: encodes an Apache Arrow IPC stream with mock dictionary
  /// encoding or batch compression.
  @visibleForTesting
  static Uint8List encodeForTesting(
    DataFrame df, {
    bool dictionaryEncoding = false,
    bool recordBatchCompression = false,
  }) {
    final builder = _ArrowIpcStreamWriter(
      [df],
      dictionaryEncoding: dictionaryEncoding,
      recordBatchCompression: recordBatchCompression,
    );
    return builder.build();
  }
}

class _ArrowIpcStreamWriter {
  new(
    this.batches, {
    this.dictionaryEncoding = false,
    this.recordBatchCompression = false,
  });

  final List<DataFrame> batches;
  final bool dictionaryEncoding;
  final bool recordBatchCompression;
  final BytesBuilder _builder = BytesBuilder(copy: false);

  Uint8List build() {
    final schemaDf = batches.isNotEmpty ? batches.first : DataFrame([]);
    // 1. Write Schema Message
    final schemaFb = _buildSchemaFlatBuffer(schemaDf);
    _writeMessage(schemaFb, null);

    // 2. Write RecordBatch Messages
    for (final df in batches) {
      final (batchFb, bodyBytes) = _buildRecordBatchFlatBufferAndBody(df);
      _writeMessage(batchFb, bodyBytes);
    }

    // 3. Write End-of-Stream Message (4 bytes 0xFFFFFFFF, 4 bytes 0x00000000)
    final eos = Uint8List(8);
    final eosView = ByteData.sublistView(eos);
    eosView.setUint32(0, 0xFFFFFFFF, Endian.little);
    eosView.setUint32(4, 0x00000000, Endian.little);
    _builder.add(eos);

    return _builder.toBytes();
  }

  void _writeMessage(Uint8List metadataFb, Uint8List? body) {
    // Continuation indicator
    final header = Uint8List(8);
    final headerView = ByteData.sublistView(header);
    headerView.setUint32(0, 0xFFFFFFFF, Endian.little);

    // Padded metadata length (multiple of 8)
    final metaPadding = (8 - (metadataFb.length % 8)) % 8;
    final metadataLength = metadataFb.length + metaPadding;
    headerView.setUint32(4, metadataLength, Endian.little);

    _builder.add(header);
    _builder.add(metadataFb);
    if (metaPadding > 0) {
      _builder.add(Uint8List(metaPadding));
    }

    if (body != null && body.isNotEmpty) {
      _builder.add(body);
      final bodyPadding = (8 - (body.length % 8)) % 8;
      if (bodyPadding > 0) {
        _builder.add(Uint8List(bodyPadding));
      }
    }
  }

  Uint8List _buildSchemaFlatBuffer(DataFrame schemaDf) {
    final fb = _FlatBufferWriter();

    final emptyChildrenOffset = fb.addOffsetVector(const <int>[]);

    // 1. Serialize each field
    final fieldOffsets = <int>[];
    for (final col in schemaDf.columns) {
      final nameOffset = fb.addString(col.name);
      final (typeType, typeOffset) = _serializeType(fb, col);

      // Field table: name, nullable, type_type, type, dictionary, children
      // vtable: [name: 0, nullable: 1, type_type: 2, type: 3, dictionary: 4, children: 5]
      final dummyDictOffset = dictionaryEncoding
          ? fb.addTable([0, 0], [_FbFieldType.int64, _FbFieldType.offset])
          : null;
      fieldOffsets.add(
        fb.addTable(
          [
            nameOffset,
            if (col.hasNulls) 1 else 0,
            typeType,
            typeOffset,
            dummyDictOffset,
            emptyChildrenOffset,
          ],
          [
            _FbFieldType.offset,
            _FbFieldType.boolean,
            _FbFieldType.uint8,
            _FbFieldType.offset,
            _FbFieldType.offset,
            _FbFieldType.offset,
          ],
        ),
      );
    }

    final fieldsVector = fb.addOffsetVector(fieldOffsets);

    // Schema table: endianness (0 = Little), fields
    final schemaOffset = fb.addTable(
      [0, fieldsVector],
      [_FbFieldType.int16, _FbFieldType.offset],
    );

    // Message table: version = 4 (V5), header_type = 1 (Schema), header =
    // schemaOffset, bodyLength = 0
    final messageOffset = fb.addTable(
      [4, 1, schemaOffset, 0],
      [
        _FbFieldType.int16,
        _FbFieldType.uint8,
        _FbFieldType.offset,
        _FbFieldType.int64,
      ],
    );

    fb.finish(messageOffset);
    return fb.toBytes();
  }

  (int, int) _serializeType(_FlatBufferWriter fb, Series<dynamic> col) {
    final dt = col.dataType;
    if (col is ArrowStringSeries || dt == DataType.string) {
      final typeOffset = fb.addTable([], []);
      return (5, typeOffset); // 5 = Utf8
    } else if (col is BoolSeries || dt == DataType.boolean) {
      final typeOffset = fb.addTable([], []);
      return (6, typeOffset); // 6 = Bool
    } else {
      if (dt == DataType.float64) {
        final typeOffset = fb.addTable([2], [_FbFieldType.int16]); // 2 = Double
        return (3, typeOffset); // 3 = FloatingPoint
      } else if (dt == DataType.float32) {
        final typeOffset = fb.addTable([1], [_FbFieldType.int16]); // 1 = Single
        return (3, typeOffset);
      } else if (dt == DataType.int64) {
        final typeOffset = fb.addTable(
          [64, 1],
          [_FbFieldType.int32, _FbFieldType.boolean],
        );
        return (2, typeOffset); // 2 = Int
      } else if (dt == DataType.int32) {
        final typeOffset = fb.addTable(
          [32, 1],
          [_FbFieldType.int32, _FbFieldType.boolean],
        );
        return (2, typeOffset);
      } else if (dt == DataType.int16) {
        final typeOffset = fb.addTable(
          [16, 1],
          [_FbFieldType.int32, _FbFieldType.boolean],
        );
        return (2, typeOffset);
      } else if (dt == DataType.int8) {
        final typeOffset = fb.addTable(
          [8, 1],
          [_FbFieldType.int32, _FbFieldType.boolean],
        );
        return (2, typeOffset);
      } else if (dt == DataType.uint64) {
        final typeOffset = fb.addTable(
          [64, 0],
          [_FbFieldType.int32, _FbFieldType.boolean],
        );
        return (2, typeOffset);
      } else if (dt == DataType.uint32) {
        final typeOffset = fb.addTable(
          [32, 0],
          [_FbFieldType.int32, _FbFieldType.boolean],
        );
        return (2, typeOffset);
      } else if (dt == DataType.uint16) {
        final typeOffset = fb.addTable(
          [16, 0],
          [_FbFieldType.int32, _FbFieldType.boolean],
        );
        return (2, typeOffset);
      } else if (dt == DataType.uint8) {
        final typeOffset = fb.addTable(
          [8, 0],
          [_FbFieldType.int32, _FbFieldType.boolean],
        );
        return (2, typeOffset);
      }
    }
    throw UnsupportedError('Unsupported Arrow type for column ${col.name}');
  }

  (Uint8List, Uint8List) _buildRecordBatchFlatBufferAndBody(DataFrame batchDf) {
    final bodyBuilder = BytesBuilder(copy: false);
    var currentBodyOffset = 0;

    // We collect FieldNodes: (length: int64, null_count: int64) = 16 bytes each
    final nodes = <(int, int)>[];
    // We collect Buffers: (offset: int64, length: int64) = 16 bytes each
    final buffers = <(int, int)>[];

    void addBuffer(Uint8List buf) {
      final len = buf.length;
      buffers.add((currentBodyOffset, len));
      if (len > 0) {
        bodyBuilder.add(buf);
        final pad = (8 - (len % 8)) % 8;
        if (pad > 0) {
          bodyBuilder.add(Uint8List(pad));
        }
        currentBodyOffset += len + pad;
      }
    }

    for (final col in batchDf.columns) {
      nodes.add((col.length, col.nullCount));

      // 1. Validity buffer (Buffer 0)
      if (col.nullCount > 0 && col.mask != null) {
        final maskBytes = (col.length + 7) ~/ 8;
        addBuffer(Uint8List.sublistView(col.mask!.bytes, 0, maskBytes));
      } else {
        addBuffer(Uint8List(0));
      }

      // 2. Data buffers
      if (col is ArrowStringSeries) {
        // Buffer 1: offsets
        final offsetsBytes = Uint8List.sublistView(col.offsets);
        addBuffer(offsetsBytes);
        // Buffer 2: UTF-8 data
        addBuffer(col.bytes);
      } else if (col.dataType == DataType.string) {
        final strSeries = ArrowStringSeries.fromList(col.name, [
          for (var i = 0; i < col.length; i++) col[i] as String?,
        ]);
        addBuffer(Uint8List.sublistView(strSeries.offsets));
        addBuffer(strSeries.bytes);
      } else if (col is BoolSeries) {
        final byteCount = (col.length + 7) ~/ 8;
        final boolBuf = Uint8List(byteCount);
        for (var i = 0; i < col.length; i++) {
          if (col.data[i]) {
            boolBuf[i >> 3] |= 1 << (i & 7);
          }
        }
        addBuffer(boolBuf);
      } else if (col.dataType == DataType.boolean) {
        final byteCount = (col.length + 7) ~/ 8;
        final boolBuf = Uint8List(byteCount);
        for (var i = 0; i < col.length; i++) {
          if (col[i] == true) {
            boolBuf[i >> 3] |= 1 << (i & 7);
          }
        }
        addBuffer(boolBuf);
      } else if (col is TypedSeries && col.data is TypedData) {
        final td = col.data as TypedData;
        addBuffer(Uint8List.sublistView(td));
      } else if (col.dataType == DataType.int64) {
        final buf = Uint8List(col.length * 8);
        final bd = ByteData.sublistView(buf);
        for (var i = 0; i < col.length; i++) {
          final v = col[i] as int? ?? 0;
          _writeInt64(bd, i * 8, v);
        }
        addBuffer(buf);
      } else if (col.dataType == DataType.uint64) {
        final buf = Uint8List(col.length * 8);
        final bd = ByteData.sublistView(buf);
        for (var i = 0; i < col.length; i++) {
          final v = col[i] as int? ?? 0;
          _writeUint64(bd, i * 8, v);
        }
        addBuffer(buf);
      } else {
        final td = col.dataType.newList(col.length);
        for (var i = 0; i < col.length; i++) {
          final v = col[i];
          if (v != null) td[i] = v;
        }
        addBuffer(Uint8List.sublistView(td as TypedData));
      }
    }

    final bodyBytes = bodyBuilder.toBytes();

    // Now construct RecordBatch FlatBuffer
    final fb = _FlatBufferWriter();

    // Struct vectors for FieldNodes and Buffers
    final nodesVecOffset = fb.addStructVector(nodes, (node, writer) {
      final (nullCount, length) = node;
      writer.putInt64(length);
      writer.putInt64(nullCount);
    }, 16);

    final buffersVecOffset = fb.addStructVector(buffers, (b, writer) {
      final (offset, length) = b;
      writer.putInt64(length);
      writer.putInt64(offset);
    }, 16);

    // RecordBatch table: length (int64), nodes (vector), buffers (vector), compression (table)
    final dummyCompOffset = recordBatchCompression
        ? fb.addTable([0, 0], [_FbFieldType.int16, _FbFieldType.int16])
        : null;
    final batchOffset = fb.addTable(
      [batchDf.rowCount, nodesVecOffset, buffersVecOffset, ?dummyCompOffset],
      [
        _FbFieldType.int64,
        _FbFieldType.offset,
        _FbFieldType.offset,
        if (dummyCompOffset != null) _FbFieldType.offset,
      ],
    );

    // Message table: version = 4, header_type = 2 (RecordBatch), header =
    // batchOffset, bodyLength = bodyBytes.length
    final messageOffset = fb.addTable(
      [4, 2, batchOffset, bodyBytes.length],
      [
        _FbFieldType.int16,
        _FbFieldType.uint8,
        _FbFieldType.offset,
        _FbFieldType.int64,
      ],
    );

    fb.finish(messageOffset);
    return (fb.toBytes(), bodyBytes);
  }
}

class _ArrowIpcStreamReader {
  new(this.bytes);

  final Uint8List bytes;
  int _cursor = 0;

  DataFrame read() {
    List<_ArrowFieldDesc>? schemaFields;
    final batches = <DataFrame>[];

    while (_cursor + 8 <= bytes.length) {
      final headerView = ByteData.sublistView(bytes, _cursor, _cursor + 8);
      final cont = headerView.getUint32(0, Endian.little);
      final metaLength = headerView.getInt32(4, Endian.little);

      if (cont != 0xFFFFFFFF) {
        throw const FormatException(
          'Invalid Arrow IPC stream: missing continuation',
        );
      }

      if (metaLength == 0) {
        // End-of-Stream
        break;
      }

      _cursor += 8;
      if (_cursor + metaLength > bytes.length) {
        throw const FormatException('Arrow IPC stream message truncated');
      }

      final fbBytes = Uint8List.sublistView(
        bytes,
        _cursor,
        _cursor + metaLength,
      );
      _cursor += metaLength;

      final reader = _FlatBufferReader(fbBytes);
      final rootTable = reader.rootTableOffset;

      final headerType = reader.readUint8(rootTable, 1);
      final headerOffset = reader.readTableOffset(rootTable, 2);

      if (headerType == 1) {
        // Schema Message
        if (headerOffset != null) {
          schemaFields = _readSchema(reader, headerOffset);
        }
      } else if (headerType == 2) {
        // RecordBatch Message
        if (schemaFields == null) {
          throw const FormatException(
            'RecordBatch found before Schema in Arrow IPC stream',
          );
        }

        final bodyLength = reader.readInt64(rootTable, 3) ?? 0;
        final bodyBytes = bodyLength > 0
            ? Uint8List.sublistView(bytes, _cursor, _cursor + bodyLength)
            : Uint8List(0);
        _cursor += bodyLength;
        final bodyPadding = (8 - (bodyLength % 8)) % 8;
        _cursor += bodyPadding;

        if (headerOffset != null) {
          final batchDf = _readRecordBatch(
            fbBytes,
            headerOffset,
            schemaFields,
            bodyBytes,
          );
          batches.add(batchDf);
        }
      }
    }

    if (batches.length == 1) {
      return batches.first;
    } else if (batches.length > 1) {
      final fields = schemaFields!;
      final columns = <Series<dynamic>>[];
      for (var i = 0; i < fields.length; i++) {
        final field = fields[i];
        final colBatches = [for (final b in batches) b.columns[i]];
        columns.add(_concatSeries(field.name, field.typeCode, colBatches));
      }
      return DataFrame(columns);
    }

    // If no RecordBatch was emitted (e.g. empty DataFrame with schema)
    if (schemaFields != null) {
      final columns = <Series<dynamic>>[];
      for (final f in schemaFields) {
        columns.add(_createEmptySeries(f.name, f.typeCode));
      }
      return DataFrame(columns);
    }

    return DataFrame([]);
  }

  Series<dynamic> _createEmptySeries(String name, int typeCode) {
    switch (typeCode) {
      case 5:
        return ArrowStringSeries(
          name: name,
          bytes: Uint8List(0),
          offsets: Uint32List(1),
        );
      case 6:
        return BoolSeries(name: name, data: const []);
      case 302:
        return TypedSeries<double>(
          name: name,
          data: Float64List(0),
          dataType: DataType.float64,
        );
      case 301:
        return TypedSeries<double>(
          name: name,
          data: Float32List(0),
          dataType: DataType.float32,
        );
      case 264:
        return TypedSeries<int>(
          name: name,
          data: DataType.int64.emptyList(0),
          dataType: DataType.int64,
        );
      case 232:
        return TypedSeries<int>(
          name: name,
          data: Int32List(0),
          dataType: DataType.int32,
        );
      case 216:
        return TypedSeries<int>(
          name: name,
          data: Int16List(0),
          dataType: DataType.int16,
        );
      case 208:
        return TypedSeries<int>(
          name: name,
          data: Int8List(0),
          dataType: DataType.int8,
        );
      case 164:
        return TypedSeries<int>(
          name: name,
          data: DataType.uint64.emptyList(0),
          dataType: DataType.uint64,
        );
      case 132:
        return TypedSeries<int>(
          name: name,
          data: Uint32List(0),
          dataType: DataType.uint32,
        );
      case 116:
        return TypedSeries<int>(
          name: name,
          data: Uint16List(0),
          dataType: DataType.uint16,
        );
      case 108:
        return TypedSeries<int>(
          name: name,
          data: Uint8List(0),
          dataType: DataType.uint8,
        );
      default:
        throw UnsupportedError('Unsupported type code: $typeCode');
    }
  }

  List<_ArrowFieldDesc> _readSchema(_FlatBufferReader reader, int schemaPos) {
    final fieldsVec = reader.readVectorOffset(schemaPos, 1);
    if (fieldsVec == null) return [];

    final count = reader.vectorLength(fieldsVec);
    final fields = <_ArrowFieldDesc>[];

    for (var i = 0; i < count; i++) {
      final fieldPos = reader.vectorTableAt(fieldsVec, i);
      final name = reader.readString(fieldPos, 0) ?? '';
      final nullable = (reader.readUint8(fieldPos, 1) ?? 1) == 1;
      final typeType = reader.readUint8(fieldPos, 2) ?? 0;
      final typePos = reader.readTableOffset(fieldPos, 3);
      final dictPos = reader.readTableOffset(fieldPos, 4);
      if (dictPos != null) {
        throw UnsupportedError(
          'Dictionary-encoded Arrow fields are currently not supported (field: "$name").',
        );
      }
      final childrenVec = reader.readVectorOffset(fieldPos, 5);
      if (childrenVec != null && reader.vectorLength(childrenVec) > 0) {
        throw UnsupportedError(
          'Nested Arrow fields (with children) are currently not supported (field: "$name").',
        );
      }

      var typeCode = 0;
      if (typeType == 5) {
        typeCode = 5; // Utf8
      } else if (typeType == 6) {
        typeCode = 6; // Bool
      } else if (typeType == 3 && typePos != null) {
        // FloatingPoint: precision (0=Half, 1=Single, 2=Double)
        final prec = reader.readInt16(typePos, 0) ?? 2;
        typeCode = prec == 1 ? 301 : 302;
      } else if (typeType == 2 && typePos != null) {
        // Int: bitWidth, is_signed
        final bitWidth = reader.readInt32(typePos, 0) ?? 32;
        final isSigned = (reader.readUint8(typePos, 1) ?? 1) == 1;
        typeCode = (isSigned ? 200 : 100) + bitWidth;
      }

      fields.add(
        _ArrowFieldDesc(name: name, nullable: nullable, typeCode: typeCode),
      );
    }

    return fields;
  }

  DataFrame _readRecordBatch(
    Uint8List fbBytes,
    int batchPos,
    List<_ArrowFieldDesc> fields,
    Uint8List body,
  ) {
    final reader = _FlatBufferReader(fbBytes);
    final compressionPos = reader.readTableOffset(batchPos, 3);
    if (compressionPos != null) {
      throw UnsupportedError(
        'Compressed Arrow IPC RecordBatches are currently not supported.',
      );
    }
    final nodesVec = reader.readVectorOffset(batchPos, 1);
    final buffersVec = reader.readVectorOffset(batchPos, 2);

    if (nodesVec == null || buffersVec == null) {
      return DataFrame([]);
    }

    final columns = <Series<dynamic>>[];
    var bufferIdx = 0;

    for (var i = 0; i < fields.length; i++) {
      final field = fields[i];

      // Read FieldNode: length (int64), null_count (int64) = 16 bytes
      final nodeOffset = nodesVec + 4 + i * 16;
      final nodeData = ByteData.sublistView(
        fbBytes,
        nodeOffset,
        nodeOffset + 16,
      );
      final colLength = _readInt64(nodeData, 0);
      final nullCount = _readInt64(nodeData, 8);

      // Read Buffer 0 (Validity)
      final buf0Offset = buffersVec + 4 + bufferIdx * 16;
      final buf0Data = ByteData.sublistView(
        fbBytes,
        buf0Offset,
        buf0Offset + 16,
      );
      final vOffset = _readInt64(buf0Data, 0);
      final vLength = _readInt64(buf0Data, 8);
      bufferIdx++;

      ValidityMask? mask;
      if (nullCount > 0 && vLength > 0) {
        final maskBytes = Uint8List.sublistView(
          body,
          vOffset,
          vOffset + vLength,
        );
        mask = ValidityMask.fromBytes(colLength, maskBytes, nullCount);
      }

      // Read data buffers based on type
      if (field.typeCode == 5) {
        // String: Buffer 1 = offsets, Buffer 2 = bytes
        final buf1Offset = buffersVec + 4 + bufferIdx * 16;
        final buf1Data = ByteData.sublistView(
          fbBytes,
          buf1Offset,
          buf1Offset + 16,
        );
        final offOffset = _readInt64(buf1Data, 0);
        final offLen = _readInt64(buf1Data, 8);
        bufferIdx++;

        final buf2Offset = buffersVec + 4 + bufferIdx * 16;
        final buf2Data = ByteData.sublistView(
          fbBytes,
          buf2Offset,
          buf2Offset + 16,
        );
        final bytesOffset = _readInt64(buf2Data, 0);
        final bytesLen = _readInt64(buf2Data, 8);
        bufferIdx++;

        final offCount = offLen ~/ 4;
        final offView = ByteData.sublistView(
          body,
          offOffset,
          offOffset + offLen,
        );
        final offsets = Uint32List(offCount);
        for (var j = 0; j < offCount; j++) {
          offsets[j] = offView.getUint32(j * 4, Endian.little);
        }
        final strBytes = bytesLen == 0
            ? Uint8List(0)
            : Uint8List.fromList(
                Uint8List.sublistView(
                  body,
                  bytesOffset,
                  bytesOffset + bytesLen,
                ),
              );

        columns.add(
          ArrowStringSeries(
            name: field.name,
            bytes: strBytes,
            offsets: offsets,
            mask: mask,
          ),
        );
      } else if (field.typeCode == 6) {
        // Bool: Buffer 1 = bitmask
        final buf1Offset = buffersVec + 4 + bufferIdx * 16;
        final buf1Data = ByteData.sublistView(
          fbBytes,
          buf1Offset,
          buf1Offset + 16,
        );
        final bOffset = _readInt64(buf1Data, 0);
        bufferIdx++;

        final boolData = List<bool>.generate(colLength, (idx) {
          final byte = body[bOffset + (idx >> 3)];
          return ((byte >> (idx & 7)) & 1) == 1;
        });

        columns.add(BoolSeries(name: field.name, data: boolData, mask: mask));
      } else {
        // Primitive TypedSeries
        final buf1Offset = buffersVec + 4 + bufferIdx * 16;
        final buf1Data = ByteData.sublistView(
          fbBytes,
          buf1Offset,
          buf1Offset + 16,
        );
        final dOffset = _readInt64(buf1Data, 0);
        bufferIdx++;

        columns.add(
          _createTypedSeries(
            field.name,
            field.typeCode,
            colLength,
            body,
            dOffset,
            mask,
          ),
        );
      }
    }

    return DataFrame(columns);
  }

  Series<dynamic> _createTypedSeries(
    String name,
    int typeCode,
    int length,
    Uint8List body,
    int offset,
    ValidityMask? mask,
  ) {
    switch (typeCode) {
      case 302:
        return TypedSeries<double>(
          name: name,
          data: _readFloat64Buffer(body, offset, length),
          mask: mask,
          dataType: DataType.float64,
        );
      case 301:
        return TypedSeries<double>(
          name: name,
          data: _readFloat32Buffer(body, offset, length),
          mask: mask,
          dataType: DataType.float32,
        );
      case 264:
        final list = DataType.int64.emptyList(length);
        final bd = ByteData.sublistView(body, offset, offset + length * 8);
        for (var i = 0; i < length; i++) {
          list[i] = _readInt64(bd, i * 8);
        }
        return TypedSeries<int>(
          name: name,
          data: list,
          mask: mask,
          dataType: DataType.int64,
        );
      case 232:
        return TypedSeries<int>(
          name: name,
          data: _readInt32Buffer(body, offset, length),
          mask: mask,
          dataType: DataType.int32,
        );
      case 216:
        return TypedSeries<int>(
          name: name,
          data: _readInt16Buffer(body, offset, length),
          mask: mask,
          dataType: DataType.int16,
        );
      case 208:
        final data = Int8List.fromList(
          Int8List.sublistView(body, offset, offset + length),
        );
        return TypedSeries<int>(
          name: name,
          data: data,
          mask: mask,
          dataType: DataType.int8,
        );
      case 164:
        final list = DataType.uint64.emptyList(length);
        final bd = ByteData.sublistView(body, offset, offset + length * 8);
        for (var i = 0; i < length; i++) {
          list[i] = _readUint64(bd, i * 8);
        }
        return TypedSeries<int>(
          name: name,
          data: list,
          mask: mask,
          dataType: DataType.uint64,
        );
      case 132:
        return TypedSeries<int>(
          name: name,
          data: _readUint32Buffer(body, offset, length),
          mask: mask,
          dataType: DataType.uint32,
        );
      case 116:
        return TypedSeries<int>(
          name: name,
          data: _readUint16Buffer(body, offset, length),
          mask: mask,
          dataType: DataType.uint16,
        );
      case 108:
        final data = Uint8List.fromList(
          Uint8List.sublistView(body, offset, offset + length),
        );
        return TypedSeries<int>(
          name: name,
          data: data,
          mask: mask,
          dataType: DataType.uint8,
        );
      default:
        throw UnsupportedError('Unsupported type code: $typeCode');
    }
  }

  static Float64List _readFloat64Buffer(
    Uint8List body,
    int offset,
    int length,
  ) {
    if (length == 0) return Float64List(0);
    final byteLength = length * 8;
    if ((body.offsetInBytes + offset) % 8 == 0) {
      return Float64List.fromList(
        Float64List.sublistView(body, offset, offset + byteLength),
      );
    }
    final aligned = Uint8List(byteLength);
    aligned.setRange(0, byteLength, body, offset);
    return Float64List.sublistView(aligned);
  }

  static Float32List _readFloat32Buffer(
    Uint8List body,
    int offset,
    int length,
  ) {
    if (length == 0) return Float32List(0);
    final byteLength = length * 4;
    if ((body.offsetInBytes + offset) % 4 == 0) {
      return Float32List.fromList(
        Float32List.sublistView(body, offset, offset + byteLength),
      );
    }
    final aligned = Uint8List(byteLength);
    aligned.setRange(0, byteLength, body, offset);
    return Float32List.sublistView(aligned);
  }

  static Int32List _readInt32Buffer(Uint8List body, int offset, int length) {
    if (length == 0) return Int32List(0);
    final byteLength = length * 4;
    if ((body.offsetInBytes + offset) % 4 == 0) {
      return Int32List.fromList(
        Int32List.sublistView(body, offset, offset + byteLength),
      );
    }
    final aligned = Uint8List(byteLength);
    aligned.setRange(0, byteLength, body, offset);
    return Int32List.sublistView(aligned);
  }

  static Int16List _readInt16Buffer(Uint8List body, int offset, int length) {
    if (length == 0) return Int16List(0);
    final byteLength = length * 2;
    if ((body.offsetInBytes + offset) % 2 == 0) {
      return Int16List.fromList(
        Int16List.sublistView(body, offset, offset + byteLength),
      );
    }
    final aligned = Uint8List(byteLength);
    aligned.setRange(0, byteLength, body, offset);
    return Int16List.sublistView(aligned);
  }

  static Uint32List _readUint32Buffer(Uint8List body, int offset, int length) {
    if (length == 0) return Uint32List(0);
    final byteLength = length * 4;
    if ((body.offsetInBytes + offset) % 4 == 0) {
      return Uint32List.fromList(
        Uint32List.sublistView(body, offset, offset + byteLength),
      );
    }
    final aligned = Uint8List(byteLength);
    aligned.setRange(0, byteLength, body, offset);
    return Uint32List.sublistView(aligned);
  }

  static Uint16List _readUint16Buffer(Uint8List body, int offset, int length) {
    if (length == 0) return Uint16List(0);
    final byteLength = length * 2;
    if ((body.offsetInBytes + offset) % 2 == 0) {
      return Uint16List.fromList(
        Uint16List.sublistView(body, offset, offset + byteLength),
      );
    }
    final aligned = Uint8List(byteLength);
    aligned.setRange(0, byteLength, body, offset);
    return Uint16List.sublistView(aligned);
  }

  Series<dynamic> _concatSeries(
    String name,
    int typeCode,
    List<Series<dynamic>> seriesList,
  ) {
    final totalLength = seriesList.fold<int>(0, (sum, s) => sum + s.length);
    final anyHasNulls = seriesList.any((s) => s.hasNulls);
    ValidityMask? combinedMask;
    if (anyHasNulls) {
      combinedMask = ValidityMask(totalLength);
      var offset = 0;
      for (final s in seriesList) {
        if (s.hasNulls) {
          final mask = s.mask;
          for (var i = 0; i < s.length; i++) {
            if (mask != null ? mask.isNull(i) : s.isNull(i)) {
              combinedMask.setNull(offset + i);
            }
          }
        }
        offset += s.length;
      }
    }

    if (typeCode == 5) {
      var totalBytes = 0;
      for (final s in seriesList) {
        if (s is ArrowStringSeries) {
          totalBytes += s.bytes.length;
        } else {
          for (var i = 0; i < s.length; i++) {
            final val = s[i] as String?;
            if (val != null) totalBytes += utf8.encode(val).length;
          }
        }
      }
      final combinedBytes = Uint8List(totalBytes);
      final combinedOffsets = Uint32List(totalLength + 1);
      var byteOffset = 0;
      var rowOffset = 0;
      combinedOffsets[0] = 0;

      for (final s in seriesList) {
        if (s is ArrowStringSeries) {
          final sBytes = s.bytes;
          final sOffsets = s.offsets;
          combinedBytes.setRange(
            byteOffset,
            byteOffset + sBytes.length,
            sBytes,
          );
          for (var i = 0; i < s.length; i++) {
            combinedOffsets[rowOffset + i + 1] = byteOffset + sOffsets[i + 1];
          }
          byteOffset += sBytes.length;
        } else {
          for (var i = 0; i < s.length; i++) {
            final val = s[i] as String?;
            if (val != null) {
              final encoded = utf8.encode(val);
              combinedBytes.setRange(
                byteOffset,
                byteOffset + encoded.length,
                encoded,
              );
              byteOffset += encoded.length;
            }
            combinedOffsets[rowOffset + i + 1] = byteOffset;
          }
        }
        rowOffset += s.length;
      }

      return ArrowStringSeries(
        name: name,
        bytes: combinedBytes,
        offsets: combinedOffsets,
        mask: combinedMask,
      );
    } else if (typeCode == 6) {
      final combinedData = List<bool>.filled(totalLength, false);
      var offset = 0;
      for (final s in seriesList) {
        final sBool = s as BoolSeries;
        combinedData.setRange(offset, offset + s.length, sBool.data);
        offset += s.length;
      }
      return BoolSeries(name: name, data: combinedData, mask: combinedMask);
    } else {
      switch (typeCode) {
        case 302:
          final combinedData = Float64List(totalLength);
          var offset = 0;
          for (final s in seriesList) {
            final data = (s as TypedSeries<double>).data as Float64List;
            combinedData.setRange(offset, offset + s.length, data);
            offset += s.length;
          }
          return TypedSeries<double>(
            name: name,
            data: combinedData,
            mask: combinedMask,
            dataType: DataType.float64,
          );
        case 301:
          final combinedData = Float32List(totalLength);
          var offset = 0;
          for (final s in seriesList) {
            final data = (s as TypedSeries<double>).data as Float32List;
            combinedData.setRange(offset, offset + s.length, data);
            offset += s.length;
          }
          return TypedSeries<double>(
            name: name,
            data: combinedData,
            mask: combinedMask,
            dataType: DataType.float32,
          );
        case 264:
          final combinedData = DataType.int64.emptyList(totalLength);
          var offset = 0;
          for (final s in seriesList) {
            final data = (s as TypedSeries<int>).data;
            combinedData.setRange(offset, offset + s.length, data);
            offset += s.length;
          }
          return TypedSeries<int>(
            name: name,
            data: combinedData,
            mask: combinedMask,
            dataType: DataType.int64,
          );
        case 232:
          final combinedData = Int32List(totalLength);
          var offset = 0;
          for (final s in seriesList) {
            final data = (s as TypedSeries<int>).data as Int32List;
            combinedData.setRange(offset, offset + s.length, data);
            offset += s.length;
          }
          return TypedSeries<int>(
            name: name,
            data: combinedData,
            mask: combinedMask,
            dataType: DataType.int32,
          );
        case 216:
          final combinedData = Int16List(totalLength);
          var offset = 0;
          for (final s in seriesList) {
            final data = (s as TypedSeries<int>).data as Int16List;
            combinedData.setRange(offset, offset + s.length, data);
            offset += s.length;
          }
          return TypedSeries<int>(
            name: name,
            data: combinedData,
            mask: combinedMask,
            dataType: DataType.int16,
          );
        case 208:
          final combinedData = Int8List(totalLength);
          var offset = 0;
          for (final s in seriesList) {
            final data = (s as TypedSeries<int>).data as Int8List;
            combinedData.setRange(offset, offset + s.length, data);
            offset += s.length;
          }
          return TypedSeries<int>(
            name: name,
            data: combinedData,
            mask: combinedMask,
            dataType: DataType.int8,
          );
        case 164:
          final combinedData = DataType.uint64.emptyList(totalLength);
          var offset = 0;
          for (final s in seriesList) {
            final data = (s as TypedSeries<int>).data;
            combinedData.setRange(offset, offset + s.length, data);
            offset += s.length;
          }
          return TypedSeries<int>(
            name: name,
            data: combinedData,
            mask: combinedMask,
            dataType: DataType.uint64,
          );
        case 132:
          final combinedData = Uint32List(totalLength);
          var offset = 0;
          for (final s in seriesList) {
            final data = (s as TypedSeries<int>).data as Uint32List;
            combinedData.setRange(offset, offset + s.length, data);
            offset += s.length;
          }
          return TypedSeries<int>(
            name: name,
            data: combinedData,
            mask: combinedMask,
            dataType: DataType.uint32,
          );
        case 116:
          final combinedData = Uint16List(totalLength);
          var offset = 0;
          for (final s in seriesList) {
            final data = (s as TypedSeries<int>).data as Uint16List;
            combinedData.setRange(offset, offset + s.length, data);
            offset += s.length;
          }
          return TypedSeries<int>(
            name: name,
            data: combinedData,
            mask: combinedMask,
            dataType: DataType.uint16,
          );
        case 108:
          final combinedData = Uint8List(totalLength);
          var offset = 0;
          for (final s in seriesList) {
            final data = (s as TypedSeries<int>).data as Uint8List;
            combinedData.setRange(offset, offset + s.length, data);
            offset += s.length;
          }
          return TypedSeries<int>(
            name: name,
            data: combinedData,
            mask: combinedMask,
            dataType: DataType.uint8,
          );
        default:
          throw UnsupportedError('Unsupported type code: $typeCode');
      }
    }
  }
}

class _ArrowFieldDesc {
  new({required this.name, required this.nullable, required this.typeCode});

  final String name;
  final bool nullable;
  final int typeCode;
}

enum _FbFieldType { boolean, uint8, int16, int32, int64, offset }

/// Minimal FlatBuffer builder creating Arrow-compliant IPC messages.
class _FlatBufferWriter {
  Uint8List _buf = Uint8List(1024);
  int _head = 1024;

  int get offset => _buf.length - _head;

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
    _writeInt64(ByteData.sublistView(_buf, _head, _head + 8), 0, val);
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
    void Function(T item, _FlatBufferWriter writer) writeStruct,
    int structSize,
  ) {
    pad(8); // Struct vectors in Arrow are 8-byte aligned (FieldNode, Buffer)
    for (var i = structs.length - 1; i >= 0; i--) {
      writeStruct(structs[i], this);
    }
    putUint32(structs.length);
    return offset;
  }

  int addTable(List<dynamic> fieldValues, List<_FbFieldType> fieldTypes) {
    final fieldLocs = List<int>.filled(fieldValues.length, 0);

    // Write table fields in forward order (so higher offset fields are written
    // first in reverse)
    for (var i = fieldValues.length - 1; i >= 0; i--) {
      final val = fieldValues[i];
      if (val == null) continue;
      final type = fieldTypes[i];
      switch (type) {
        case _FbFieldType.boolean:
        case _FbFieldType.uint8:
          putUint8(val as int);
        case _FbFieldType.int16:
          putInt16(val as int);
        case _FbFieldType.int32:
          putInt32(val as int);
        case _FbFieldType.int64:
          putInt64(val as int);
        case _FbFieldType.offset:
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
}

/// Minimal FlatBuffer reader for extracting fields from Arrow messages.
class _FlatBufferReader {
  new(this.bytes);

  final Uint8List bytes;

  int get rootTableOffset {
    final view = ByteData.sublistView(bytes, 0, 4);
    return view.getUint32(0, Endian.little);
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
    return _readInt64(ByteData.sublistView(bytes, pos, pos + 8), 0);
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
}
