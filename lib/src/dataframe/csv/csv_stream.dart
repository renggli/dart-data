import 'dart:async';
import 'dart:convert' show utf8;

import '../../type/data_type.dart';
import '../arrow_string_series.dart';
import '../dataframe.dart';
import '../series.dart';

/// RFC 4180-compliant streaming CSV tokenizer and chunked DataFrame reader.
///
/// Enables constant-memory streaming ingestion of large CSV and TSV files from
/// [Stream<String>] or [Stream<List<int>>] without buffering the full dataset
/// in memory.
abstract final class CsvStream {
  /// Reads a text [stream] into a stream of chunked [DataFrame] instances of up
  /// to [chunkSize] rows.
  static Stream<DataFrame> readChunks(
    Stream<String> stream, {
    String separator = ',',
    bool header = true,
    int chunkSize = 1000,
    List<String>? columnNames,
    Map<String, DataType<Object?>>? columnTypes,
  }) async* {
    final rowStream = stream.transform(
      CsvStreamTransformer(separator: separator),
    );
    var headers = columnNames;
    final buffer = <List<String>>[];

    var totalRows = 0;
    await for (final row in rowStream) {
      if (headers == null) {
        if (header) {
          headers = row;
          continue;
        } else {
          headers = List.generate(row.length, (i) => 'col_$i');
        }
      }

      buffer.add(row);
      totalRows++;
      if (buffer.length >= chunkSize) {
        yield _buildDataFrame(headers, buffer, columnTypes);
        buffer.clear();
      }
    }

    if (buffer.isNotEmpty && headers != null) {
      yield _buildDataFrame(headers, buffer, columnTypes);
      buffer.clear();
    } else if (headers != null && totalRows == 0) {
      yield _buildDataFrame(headers, const [], columnTypes);
    }
  }

  /// Ingests a text [stream] into a single [DataFrame] without buffering the
  /// full raw text in RAM.
  static Future<DataFrame> readStream(
    Stream<String> stream, {
    String separator = ',',
    bool header = true,
    List<String>? columnNames,
    Map<String, DataType<Object?>>? columnTypes,
  }) async {
    final rowStream = stream.transform(
      CsvStreamTransformer(separator: separator),
    );
    var headers = columnNames;
    final allRows = <List<String>>[];

    await for (final row in rowStream) {
      if (headers == null) {
        if (header) {
          headers = row;
          continue;
        } else {
          headers = List.generate(row.length, (i) => 'col_$i');
        }
      }
      allRows.add(row);
    }

    if (headers == null) return DataFrame([]);
    return _buildDataFrame(headers, allRows, columnTypes);
  }

  /// Reads a byte [stream] into chunked [DataFrame] instances.
  static Stream<DataFrame> readByteChunks(
    Stream<List<int>> stream, {
    String separator = ',',
    bool header = true,
    int chunkSize = 1000,
    List<String>? columnNames,
    Map<String, DataType<Object?>>? columnTypes,
  }) => readChunks(
    stream.cast<List<int>>().transform(utf8.decoder),
    separator: separator,
    header: header,
    chunkSize: chunkSize,
    columnNames: columnNames,
    columnTypes: columnTypes,
  );

  /// Reads a byte [stream] into a single [DataFrame].
  static Future<DataFrame> readByteStream(
    Stream<List<int>> stream, {
    String separator = ',',
    bool header = true,
    List<String>? columnNames,
    Map<String, DataType<Object?>>? columnTypes,
  }) => readStream(
    stream.cast<List<int>>().transform(utf8.decoder),
    separator: separator,
    header: header,
    columnNames: columnNames,
    columnTypes: columnTypes,
  );

  static DataFrame _buildDataFrame(
    List<String> colNames,
    List<List<String>> dataRows,
    Map<String, DataType<Object?>>? columnTypes,
  ) {
    if (dataRows.isEmpty) {
      final cols = <Series<Object?>>[];
      for (final name in colNames) {
        final type = columnTypes?[name];
        cols.add(Series.fromList(name, const [], type: type));
      }
      return DataFrame(cols);
    }

    final rowCount = dataRows.length;
    final columns = <Series<Object?>>[];

    for (var colIdx = 0; colIdx < colNames.length; colIdx++) {
      final name = colNames[colIdx];
      final explicitType = columnTypes?[name];

      if (explicitType != null) {
        final vals = <Object?>[];
        for (var r = 0; r < rowCount; r++) {
          final row = dataRows[r];
          final raw = colIdx < row.length ? row[colIdx].trim() : '';
          if (raw.isEmpty || raw == 'null' || raw == 'NA') {
            vals.add(null);
          } else {
            vals.add(explicitType.cast(raw));
          }
        }
        columns.add(Series.fromList(name, vals, type: explicitType));
        continue;
      }

      var canBeInt = true;
      var canBeDouble = true;
      var canBeBool = true;
      final rawVals = <String?>[];

      for (var r = 0; r < rowCount; r++) {
        final row = dataRows[r];
        final val = colIdx < row.length ? row[colIdx] : '';
        final trimmed = val.trim();
        if (trimmed.isEmpty || trimmed == 'null' || trimmed == 'NA') {
          rawVals.add(null);
        } else {
          rawVals.add(val);
          if (canBeInt && int.tryParse(trimmed) == null) canBeInt = false;
          if (canBeDouble && double.tryParse(trimmed) == null) {
            canBeDouble = false;
          }
          final lower = trimmed.toLowerCase();
          if (canBeBool && lower != 'true' && lower != 'false') {
            canBeBool = false;
          }
        }
      }

      final nonNullCount = rawVals.where((v) => v != null).length;
      if (nonNullCount == 0) {
        columns.add(ArrowStringSeries.fromList(name, rawVals));
      } else if (canBeInt) {
        final intVals = rawVals
            .map((v) => v != null ? int.parse(v.trim()) : null)
            .toList(growable: false);
        columns.add(TypedSeries<int>.fromList(name, intVals));
      } else if (canBeDouble) {
        final dblVals = rawVals
            .map((v) => v != null ? double.parse(v.trim()) : null)
            .toList(growable: false);
        columns.add(TypedSeries<double>.fromList(name, dblVals));
      } else if (canBeBool) {
        final boolVals = rawVals
            .map((v) => v != null ? v.trim().toLowerCase() == 'true' : null)
            .toList(growable: false);
        columns.add(BoolSeries.fromList(name, boolVals));
      } else {
        columns.add(ArrowStringSeries.fromList(name, rawVals));
      }
    }

    return DataFrame(columns);
  }
}

/// Stream transformer that tokenizes a [Stream<String>] into CSV row lists
/// adhering to RFC 4180.
class CsvStreamTransformer extends StreamTransformerBase<String, List<String>> {
  /// Creates a [CsvStreamTransformer] with configured [separator] and
  /// [quoteChar].
  const new({this.separator = ',', this.quoteChar = '"'});

  /// Field delimiter character.
  final String separator;

  /// Quote character.
  final String quoteChar;

  @override
  Stream<List<String>> bind(Stream<String> stream) =>
      Stream<List<String>>.eventTransformed(
        stream,
        (sink) => _CsvEventSink(sink, separator, quoteChar),
      );
}

class _CsvEventSink implements EventSink<String> {
  new(this._outputSink, this.separator, this.quoteChar)
    : _sepCode = separator.codeUnitAt(0),
      _quoteCode = quoteChar.codeUnitAt(0);

  final EventSink<List<String>> _outputSink;
  final String separator;
  final String quoteChar;
  final int _sepCode;
  final int _quoteCode;

  static const int _stateStartField = 0;
  static const int _stateUnquoted = 1;
  static const int _stateInQuotes = 2;
  static const int _stateQuoteInQuotes = 3;

  int _state = _stateStartField;
  final StringBuffer _currentField = StringBuffer();
  final List<String> _currentRow = [];
  bool _sawCarriageReturn = false;

  @override
  void add(String chunk) {
    for (var i = 0; i < chunk.length; i++) {
      final code = chunk.codeUnitAt(i);

      if (_sawCarriageReturn) {
        _sawCarriageReturn = false;
        if (code == 10 /* \n */ ) {
          continue;
        }
      }

      switch (_state) {
        case _stateStartField:
          if (code == _quoteCode) {
            _state = _stateInQuotes;
          } else if (code == _sepCode) {
            _currentRow.add('');
          } else if (code == 13 /* \r */ ) {
            _sawCarriageReturn = true;
            _currentRow.add('');
            _emitRow();
          } else if (code == 10 /* \n */ ) {
            _currentRow.add('');
            _emitRow();
          } else {
            _currentField.writeCharCode(code);
            _state = _stateUnquoted;
          }

        case _stateUnquoted:
          if (code == _sepCode) {
            _currentRow.add(_currentField.toString());
            _currentField.clear();
            _state = _stateStartField;
          } else if (code == 13 /* \r */ ) {
            _sawCarriageReturn = true;
            _currentRow.add(_currentField.toString());
            _currentField.clear();
            _emitRow();
            _state = _stateStartField;
          } else if (code == 10 /* \n */ ) {
            _currentRow.add(_currentField.toString());
            _currentField.clear();
            _emitRow();
            _state = _stateStartField;
          } else {
            _currentField.writeCharCode(code);
          }

        case _stateInQuotes:
          if (code == _quoteCode) {
            _state = _stateQuoteInQuotes;
          } else {
            _currentField.writeCharCode(code);
          }

        case _stateQuoteInQuotes:
          if (code == _quoteCode) {
            // Escaped quote: "" -> "
            _currentField.writeCharCode(_quoteCode);
            _state = _stateInQuotes;
          } else if (code == _sepCode) {
            _currentRow.add(_currentField.toString());
            _currentField.clear();
            _state = _stateStartField;
          } else if (code == 13 /* \r */ ) {
            _sawCarriageReturn = true;
            _currentRow.add(_currentField.toString());
            _currentField.clear();
            _emitRow();
            _state = _stateStartField;
          } else if (code == 10 /* \n */ ) {
            _currentRow.add(_currentField.toString());
            _currentField.clear();
            _emitRow();
            _state = _stateStartField;
          } else {
            _currentField.writeCharCode(code);
            _state = _stateUnquoted;
          }
      }
    }
  }

  void _emitRow() {
    _outputSink.add(List<String>.from(_currentRow));
    _currentRow.clear();
  }

  @override
  void close() {
    if (_state == _stateInQuotes) {
      _outputSink.addError(
        const FormatException('Unterminated quoted field in CSV stream'),
      );
      _outputSink.close();
      return;
    }
    if (_state == _stateQuoteInQuotes ||
        _state == _stateUnquoted ||
        _currentField.isNotEmpty ||
        _currentRow.isNotEmpty) {
      _currentRow.add(_currentField.toString());
      _currentField.clear();
    }
    if (_currentRow.isNotEmpty) {
      _emitRow();
    }
    _outputSink.close();
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _outputSink.addError(error, stackTrace);
  }
}
