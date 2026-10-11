import 'dart:convert';

import '../dataframe.dart';
import 'json_orient.dart';

/// Encodes [DataFrame] instances into JSON strings and records.
abstract final class DataFrameJsonEncoder {
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
}
