import '../../../type.dart';
import '../dataframe.dart';
import 'json_decoder.dart';
import 'json_encoder.dart';
import 'json_orient.dart';
import 'json_stream.dart';

export 'json_decoder.dart';
export 'json_encoder.dart';
export 'json_orient.dart';
export 'json_stream.dart';

/// JSON encoder and decoder for [DataFrame].
abstract final class DataFrameJson {
  /// Encodes [df] into a JSON string according to [orient].
  static String encode(
    DataFrame df, {
    JsonOrient orient = JsonOrient.records,
  }) => DataFrameJsonEncoder.encode(df, orient: orient);

  /// Converts [df] into a list of row maps.
  static List<Map<String, dynamic>> toRecords(DataFrame df) =>
      DataFrameJsonEncoder.toRecords(df);

  /// Parses a JSON [source] string into a [DataFrame].
  static DataFrame decode(
    String source, {
    JsonOrient? orient,
    Map<String, DataType<dynamic>>? columnTypes,
  }) => DataFrameJsonDecoder.decode(
    source,
    orient: orient,
    columnTypes: columnTypes,
  );

  /// Constructs a [DataFrame] from an iterable of [records].
  static DataFrame fromRecords(
    Iterable<Map<String, dynamic>> records, {
    Map<String, DataType<dynamic>>? columnTypes,
  }) => DataFrameJsonDecoder.fromRecords(records, columnTypes: columnTypes);

  /// Reads a text [stream] of newline-delimited JSON (NDJSON) into chunked [DataFrame] instances.
  static Stream<DataFrame> readNdjsonChunks(
    Stream<String> stream, {
    int chunkSize = 1000,
    Map<String, DataType<dynamic>>? columnTypes,
  }) => DataFrameJsonStream.readNdjsonChunks(
    stream,
    chunkSize: chunkSize,
    columnTypes: columnTypes,
  );

  /// Ingests a text [stream] of NDJSON records into a single [DataFrame].
  static Future<DataFrame> readNdjson(
    Stream<String> stream, {
    Map<String, DataType<dynamic>>? columnTypes,
  }) => DataFrameJsonStream.readNdjson(stream, columnTypes: columnTypes);
}
