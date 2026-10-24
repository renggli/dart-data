import 'dart:convert';

import '../../type/data_type.dart';
import '../dataframe.dart';
import 'json_decoder.dart';

/// Streaming JSON Lines (NDJSON) and chunked JSON reader for [DataFrame].
///
/// Ingests records line-by-line from [Stream<String>] or [Stream<List<int>>] in
/// constant memory without loading the complete JSON document into RAM.
abstract final class DataFrameJsonStream {
  /// Reads a text [stream] of newline-delimited JSON (NDJSON/JSONL) records
  /// into chunked [DataFrame] instances.
  static Stream<DataFrame> readNdjsonChunks(
    Stream<String> stream, {
    int chunkSize = 1000,
    Map<String, DataType<dynamic>>? columnTypes,
  }) async* {
    final lineStream = stream.transform(const LineSplitter());
    final buffer = <Map<String, dynamic>>[];

    await for (final line in lineStream) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final dynamic decoded = jsonDecode(trimmed);
      if (decoded is! Map) {
        throw FormatException(
          'Expected JSON Map for NDJSON record, got ${decoded.runtimeType}',
          trimmed,
        );
      }
      buffer.add(decoded.map((k, v) => MapEntry(k.toString(), v)));

      if (buffer.length >= chunkSize) {
        yield DataFrameJsonDecoder.fromRecords(
          buffer,
          columnTypes: columnTypes,
        );
        buffer.clear();
      }
    }

    if (buffer.isNotEmpty) {
      yield DataFrameJsonDecoder.fromRecords(buffer, columnTypes: columnTypes);
      buffer.clear();
    }
  }

  /// Ingests a text [stream] of NDJSON records into a single [DataFrame].
  static Future<DataFrame> readNdjson(
    Stream<String> stream, {
    Map<String, DataType<dynamic>>? columnTypes,
  }) async {
    final lineStream = stream.transform(const LineSplitter());
    final allRecords = <Map<String, dynamic>>[];

    await for (final line in lineStream) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final dynamic decoded = jsonDecode(trimmed);
      if (decoded is! Map) {
        throw FormatException(
          'Expected JSON Map for NDJSON record, got ${decoded.runtimeType}',
          trimmed,
        );
      }
      allRecords.add(decoded.map((k, v) => MapEntry(k.toString(), v)));
    }

    return DataFrameJsonDecoder.fromRecords(
      allRecords,
      columnTypes: columnTypes,
    );
  }

  /// Reads a byte [stream] of NDJSON records into chunked [DataFrame]
  /// instances.
  static Stream<DataFrame> readByteChunks(
    Stream<List<int>> stream, {
    int chunkSize = 1000,
    Map<String, DataType<dynamic>>? columnTypes,
  }) => readNdjsonChunks(
    stream.cast<List<int>>().transform(utf8.decoder),
    chunkSize: chunkSize,
    columnTypes: columnTypes,
  );

  /// Reads a byte [stream] of NDJSON records into a single [DataFrame].
  static Future<DataFrame> readByteStream(
    Stream<List<int>> stream, {
    Map<String, DataType<dynamic>>? columnTypes,
  }) => readNdjson(
    stream.cast<List<int>>().transform(utf8.decoder),
    columnTypes: columnTypes,
  );
}
