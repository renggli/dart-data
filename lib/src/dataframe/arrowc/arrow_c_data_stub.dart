// ignore_for_file: unreachable_from_main

import '../dataframe.dart';
import '../series.dart';

/// Flag indicating that dictionary values are ordered.
const int arrowFlagDictionaryOrdered = 1;

/// Flag indicating that null values are permitted.
const int arrowFlagNullable = 2;

/// Flag indicating that map keys are sorted.
const int arrowFlagMapKeysSorted = 4;

/// Stub representation of Apache Arrow Schema structure on non-FFI platforms.
class ArrowSchema {
  /// Throws [UnsupportedError] as Arrow C Data interface requires `dart:ffi`.
  new() {
    throw UnsupportedError('Arrow C Data interface requires dart:ffi.');
  }
}

/// Stub representation of Apache Arrow Array structure on non-FFI platforms.
class ArrowArray {
  /// Throws [UnsupportedError] as Arrow C Data interface requires `dart:ffi`.
  new() {
    throw UnsupportedError('Arrow C Data interface requires dart:ffi.');
  }
}

/// Exports a [DataFrame] to Apache Arrow C Data structures (stub).
void exportDataFrameToArrowC(
  DataFrame df,
  dynamic outArray,
  dynamic outSchema,
) {
  throw UnsupportedError('Arrow C Data interface requires dart:ffi.');
}

/// Imports a [DataFrame] from Apache Arrow C Data structures (stub).
DataFrame importDataFrameFromArrowC(dynamic array, dynamic schema) {
  throw UnsupportedError('Arrow C Data interface requires dart:ffi.');
}

/// Exports a single [Series] to Apache Arrow C Data structures (stub).
void exportSeriesToArrowC(
  Series<Object?> series,
  dynamic outArray,
  dynamic outSchema,
) {
  throw UnsupportedError('Arrow C Data interface requires dart:ffi.');
}

/// Imports a single [Series] from Apache Arrow C Data structures (stub).
Series<Object?> importSeriesFromArrowC(dynamic array, dynamic schema) {
  throw UnsupportedError('Arrow C Data interface requires dart:ffi.');
}

/// Extension methods for exporting a [DataFrame] to Arrow C Data (stub).
extension ArrowCDataFrameExtension on DataFrame {
  /// Exports this DataFrame into provided structs (stub).
  void exportToArrowC(dynamic outArray, dynamic outSchema) =>
      throw UnsupportedError('Arrow C Data interface requires dart:ffi.');
}

/// Extension methods for exporting a [Series] to Arrow C Data (stub).
extension ArrowCSeriesExtension on Series<Object?> {
  /// Exports this Series into provided structs (stub).
  void exportToArrowC(dynamic outArray, dynamic outSchema) =>
      throw UnsupportedError('Arrow C Data interface requires dart:ffi.');
}
