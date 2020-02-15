library data.frame.io.csv_importer;

import 'dart:async';

import 'package:csv/csv.dart';
import 'package:more/iterable.dart';

import '../../../vector.dart';
import '../../type/type.dart';
import '../frame.dart';
import '../index/categorical.dart';
import '../index/range.dart';

const defaultCvsToListDetector = CsvToListConverter(eol: '\n');

abstract class CsvImporter {
  static Future<Frame<int, String>> fromString(String data,
          {StreamTransformer<String, List> csvConverter =
              defaultCvsToListDetector}) async =>
      fromStream(Stream.value(data), csvConverter: csvConverter);

  static Future<Frame<int, String>> fromStream(Stream<String> data,
          {StreamTransformer<String, List> csvConverter =
              defaultCvsToListDetector}) async =>
      fromList(await data.transform(csvConverter).toList());

  static Future<Frame<int, String>> fromList(List<List> data) async {
    final rowIndex = RangeIndex(stop: data.length - 1);
    final columnIndex = CategoricalIndex<String>(DataType.string, {
      for (final each in data.first.indexed()) each.value.toString(): each.index
    });
    final columns = columnIndex.values.map((col) {
      final list = List.generate(rowIndex.length, (row) => data[row + 1][col]);
      final dataType = DataType.fromIterable(list);
      return Vector.fromList(dataType, dataType.castList(list));
    }).toList();
    return Frame<int, String>(rowIndex, columnIndex, columns);
  }
}
