import 'dart:convert';
import 'dart:math' as math;

import '../../type.dart';
import 'dataframe.dart';
import 'series.dart';

/// Layout orientation for DataFrame JSON serialization.
enum JsonOrient {
  /// List of row objects: `[{"col1": v1, "col2": v2}, ...]`.
  records,

  /// Object with columns and data arrays: `{"columns": ["col1", "col2"], "data": [[v1, v2], ...]}`.
  split,

  /// Object mapping column names to arrays: `{"col1": [v1, v2], ...}` or row-indexed maps.
  columns,

  /// 2D array of row values: `[[v1, v2], ...]`.
  values_,
}

/// JSON encoder and decoder for [DataFrame].
abstract final class DataFrameJson {
  new _();

  /// Encodes [df] into a JSON string according to [orient].
  static String encode(DataFrame df, {JsonOrient orient = JsonOrient.records}) {
    final names = df.columnNames;
    final cols = [for (final name in names) df.column(name)];
    final rowCount = df.rowCount;
    final dynamic jsonObject = switch (orient) {
      JsonOrient.records => toRecords(df),
      JsonOrient.split => {
        'columns': names,
        'data': [
          for (var r = 0; r < rowCount; r++)
            [for (var c = 0; c < names.length; c++) cols[c][r]],
        ],
      },
      JsonOrient.columns => {
        for (var c = 0; c < names.length; c++) names[c]: cols[c].toList(),
      },
      JsonOrient.values_ => [
        for (var r = 0; r < rowCount; r++)
          [for (var c = 0; c < names.length; c++) cols[c][r]],
      ],
    };
    return jsonEncode(jsonObject);
  }

  /// Converts [df] into a list of row maps.
  static List<Map<String, dynamic>> toRecords(DataFrame df) {
    final names = df.columnNames;
    final cols = [for (final name in names) df.column(name)];
    final rowCount = df.rowCount;
    final records = <Map<String, dynamic>>[];
    for (var r = 0; r < rowCount; r++) {
      final record = <String, dynamic>{};
      for (var c = 0; c < names.length; c++) {
        record[names[c]] = cols[c][r];
      }
      records.add(record);
    }
    return records;
  }

  /// Parses a JSON [source] string into a [DataFrame].
  ///
  /// If [orient] is omitted, the layout is automatically detected:
  /// - Root `List` with `Map` items -> [JsonOrient.records].
  /// - Root `List` with `List` items -> [JsonOrient.values].
  /// - Root `Map` with `'columns'` and `'data'` keys -> [JsonOrient.split].
  /// - Root `Map` -> [JsonOrient.columns].
  static DataFrame decode(
    String source, {
    JsonOrient? orient,
    Map<String, DataType<dynamic>>? columnTypes,
  }) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('Failed to parse JSON: ${e.message}', source);
    }

    final effectiveOrient = orient ?? _detectOrient(decoded);
    return switch (effectiveOrient) {
      JsonOrient.records => _decodeRecords(decoded, columnTypes: columnTypes),
      JsonOrient.split => _decodeSplit(decoded, columnTypes: columnTypes),
      JsonOrient.columns => _decodeColumns(decoded, columnTypes: columnTypes),
      JsonOrient.values_ => _decodeValues(decoded, columnTypes: columnTypes),
    };
  }

  /// Constructs a [DataFrame] from an iterable of [records].
  static DataFrame fromRecords(
    Iterable<Map<String, dynamic>> records, {
    Map<String, DataType<dynamic>>? columnTypes,
  }) {
    final recordsList = records.toList(growable: false);
    if (recordsList.isEmpty) {
      if (columnTypes != null && columnTypes.isNotEmpty) {
        final cols = columnTypes.entries
            .map((e) => Series.fromList(e.key, const [], type: e.value))
            .toList(growable: false);
        return DataFrame(cols);
      }
      return DataFrame([]);
    }

    final colNames = <String>{};
    for (final record in recordsList) {
      colNames.addAll(record.keys);
    }
    if (columnTypes != null) {
      colNames.addAll(columnTypes.keys);
    }

    final columns = <Series<dynamic>>[];
    for (final name in colNames) {
      final type = columnTypes?[name];
      final values = <dynamic>[];
      for (final record in recordsList) {
        final val = record[name];
        values.add(val != null && type != null ? type.cast(val) : val);
      }
      columns.add(Series.fromList(name, values, type: type));
    }
    return DataFrame(columns);
  }

  static JsonOrient _detectOrient(dynamic decoded) {
    if (decoded is List) {
      if (decoded.isEmpty) {
        return JsonOrient.records;
      }
      final first = decoded.first;
      if (first is Map) {
        return JsonOrient.records;
      }
      if (first is List) {
        return JsonOrient.values_;
      }
      throw FormatException(
        'Cannot auto-detect JsonOrient: List elements must be Map or List, got ${first.runtimeType}',
      );
    }
    if (decoded is Map) {
      if (decoded.containsKey('columns') && decoded.containsKey('data')) {
        return JsonOrient.split;
      }
      return JsonOrient.columns;
    }
    throw FormatException(
      'Cannot auto-detect JsonOrient: root JSON must be List or Map, got ${decoded.runtimeType}',
    );
  }

  static DataFrame _decodeRecords(
    dynamic decoded, {
    Map<String, DataType<dynamic>>? columnTypes,
  }) {
    if (decoded is! List) {
      throw FormatException(
        'Expected JSON List for records orientation, got ${decoded.runtimeType}',
      );
    }
    final rawList = decoded;
    if (rawList.isEmpty) {
      if (columnTypes != null && columnTypes.isNotEmpty) {
        final cols = columnTypes.entries
            .map((e) => Series.fromList(e.key, const [], type: e.value))
            .toList(growable: false);
        return DataFrame(cols);
      }
      return DataFrame([]);
    }

    final records = <Map<String, dynamic>>[];
    for (var i = 0; i < rawList.length; i++) {
      final item = rawList[i];
      if (item is! Map) {
        throw FormatException(
          'Row at index $i in records orientation must be a Map, got ${item.runtimeType}',
        );
      }
      records.add(item.map((k, v) => MapEntry(k.toString(), v)));
    }

    return fromRecords(records, columnTypes: columnTypes);
  }

  static DataFrame _decodeSplit(
    dynamic decoded, {
    Map<String, DataType<dynamic>>? columnTypes,
  }) {
    if (decoded is! Map) {
      throw FormatException(
        'Expected JSON Map for split orientation, got ${decoded.runtimeType}',
      );
    }
    if (!decoded.containsKey('columns') || !decoded.containsKey('data')) {
      throw const FormatException(
        'Split format requires "columns" and "data" keys',
      );
    }
    final rawCols = decoded['columns'];
    if (rawCols is! List) {
      throw FormatException(
        'Split format "columns" must be a List, got ${rawCols.runtimeType}',
      );
    }
    final rawData = decoded['data'];
    if (rawData is! List) {
      throw FormatException(
        'Split format "data" must be a List, got ${rawData.runtimeType}',
      );
    }

    final colNames = rawCols.map((c) => c.toString()).toList(growable: false);
    final rowCount = rawData.length;
    final columns = <Series<dynamic>>[];

    for (var colIdx = 0; colIdx < colNames.length; colIdx++) {
      final name = colNames[colIdx];
      final type = columnTypes?[name];
      final values = <dynamic>[];
      for (var rowIdx = 0; rowIdx < rowCount; rowIdx++) {
        final row = rawData[rowIdx];
        if (row is! List) {
          throw FormatException(
            'Row at index $rowIdx in split "data" must be a List, got ${row.runtimeType}',
          );
        }
        final val = colIdx < row.length ? row[colIdx] : null;
        values.add(val != null && type != null ? type.cast(val) : val);
      }
      columns.add(Series.fromList(name, values, type: type));
    }

    return DataFrame(columns);
  }

  static DataFrame _decodeColumns(
    dynamic decoded, {
    Map<String, DataType<dynamic>>? columnTypes,
  }) {
    if (decoded is! Map) {
      throw FormatException(
        'Expected JSON Map for columns orientation, got ${decoded.runtimeType}',
      );
    }
    if (decoded.isEmpty) {
      if (columnTypes != null && columnTypes.isNotEmpty) {
        final cols = columnTypes.entries
            .map((e) => Series.fromList(e.key, const [], type: e.value))
            .toList(growable: false);
        return DataFrame(cols);
      }
      return DataFrame([]);
    }

    var anyMap = false;
    var allMapsHaveIntegerKeys = true;
    final allIntKeys = <int>{};
    var maxIntKey = -1;
    var maxListLen = 0;
    final orderedStringRowKeys = <String>{};

    for (final entry in decoded.entries) {
      final val = entry.value;
      if (val is List) {
        if (val.length > maxListLen) {
          maxListLen = val.length;
        }
      } else if (val is Map) {
        anyMap = true;
        for (final k in val.keys) {
          final strK = k.toString();
          orderedStringRowKeys.add(strK);
          final parsed = int.tryParse(strK);
          if (parsed == null || parsed < 0) {
            allMapsHaveIntegerKeys = false;
          } else {
            allIntKeys.add(parsed);
            if (parsed > maxIntKey) {
              maxIntKey = parsed;
            }
          }
        }
      } else {
        throw FormatException(
          'Column "${entry.key}" must be a List or Map, got ${val.runtimeType}',
        );
      }
    }

    final int rowCount;
    final bool useIntegerIndexing;
    final List<String> rowKeysList;
    if (!anyMap) {
      rowCount = maxListLen;
      useIntegerIndexing = false;
      rowKeysList = const [];
    } else if (allMapsHaveIntegerKeys &&
        (allIntKeys.contains(0) || maxListLen > 0) &&
        (maxIntKey + 1 <= (allIntKeys.length + maxListLen) * 5)) {
      useIntegerIndexing = true;
      rowCount = math.max(maxListLen, maxIntKey + 1);
      rowKeysList = const [];
    } else if (allMapsHaveIntegerKeys) {
      useIntegerIndexing = false;
      final sortedIntKeys = allIntKeys.toList()..sort();
      rowKeysList = sortedIntKeys
          .map((k) => k.toString())
          .toList(growable: false);
      rowCount = math.max(maxListLen, rowKeysList.length);
    } else {
      useIntegerIndexing = false;
      rowKeysList = orderedStringRowKeys.toList(growable: false);
      rowCount = math.max(maxListLen, rowKeysList.length);
    }

    final columns = <Series<dynamic>>[];
    for (final entry in decoded.entries) {
      final colName = entry.key.toString();
      final colVal = entry.value;
      final type = columnTypes?[colName];
      final values = <dynamic>[];

      if (colVal is List) {
        for (var r = 0; r < rowCount; r++) {
          final raw = r < colVal.length ? colVal[r] : null;
          values.add(raw != null && type != null ? type.cast(raw) : raw);
        }
      } else if (colVal is Map) {
        if (useIntegerIndexing) {
          for (var r = 0; r < rowCount; r++) {
            final raw = colVal[r] ?? colVal['$r'];
            values.add(raw != null && type != null ? type.cast(raw) : raw);
          }
        } else {
          for (var r = 0; r < rowCount; r++) {
            final k = r < rowKeysList.length ? rowKeysList[r] : null;
            final raw = k != null
                ? (colVal[k] ??
                      (int.tryParse(k) != null
                          ? colVal[int.tryParse(k)!]
                          : null))
                : null;
            values.add(raw != null && type != null ? type.cast(raw) : raw);
          }
        }
      }
      columns.add(Series.fromList(colName, values, type: type));
    }

    return DataFrame(columns);
  }

  static DataFrame _decodeValues(
    dynamic decoded, {
    Map<String, DataType<dynamic>>? columnTypes,
  }) {
    if (decoded is! List) {
      throw FormatException(
        'Expected JSON List for values orientation, got ${decoded.runtimeType}',
      );
    }
    if (decoded.isEmpty) {
      if (columnTypes != null && columnTypes.isNotEmpty) {
        final cols = columnTypes.entries
            .map((e) => Series.fromList(e.key, const [], type: e.value))
            .toList(growable: false);
        return DataFrame(cols);
      }
      return DataFrame([]);
    }

    var numCols = 0;
    for (var i = 0; i < decoded.length; i++) {
      final row = decoded[i];
      if (row is! List) {
        throw FormatException(
          'Row at index $i in values orientation must be a List, got ${row.runtimeType}',
        );
      }
      if (row.length > numCols) {
        numCols = row.length;
      }
    }

    if (columnTypes != null && columnTypes.length > numCols) {
      numCols = columnTypes.length;
    }

    final typeKeys = columnTypes?.keys.toList();
    final colNames = <String>[];
    for (var j = 0; j < numCols; j++) {
      if (typeKeys != null && j < typeKeys.length) {
        colNames.add(typeKeys[j]);
      } else {
        var defaultName = 'col_$j';
        var k = j;
        while (colNames.contains(defaultName)) {
          k++;
          defaultName = 'col_$k';
        }
        colNames.add(defaultName);
      }
    }

    final columns = <Series<dynamic>>[];
    for (var colIdx = 0; colIdx < numCols; colIdx++) {
      final name = colNames[colIdx];
      final type = columnTypes?[name];
      final values = <dynamic>[];
      for (var rowIdx = 0; rowIdx < decoded.length; rowIdx++) {
        final row = decoded[rowIdx] as List;
        final val = colIdx < row.length ? row[colIdx] : null;
        values.add(val != null && type != null ? type.cast(val) : val);
      }
      columns.add(Series.fromList(name, values, type: type));
    }

    return DataFrame(columns);
  }
}
