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
void exportDataFrameToArrowC({
  required DataFrame dataFrame,
  required Object outSchema,
  required Object outArray,
}) {
  throw UnsupportedError('Arrow C Data interface requires dart:ffi.');
}

/// Imports a [DataFrame] from Apache Arrow C Data structures (stub).
DataFrame importDataFrameFromArrowC({
  required Object schema,
  required Object array,
  bool release = true,
}) {
  throw UnsupportedError('Arrow C Data interface requires dart:ffi.');
}

/// Exports a single [Series] to Apache Arrow C Data structures (stub).
void exportSeriesToArrowC({
  required Series<Object?> series,
  required Object outSchema,
  required Object outArray,
  bool? nullable,
}) {
  throw UnsupportedError('Arrow C Data interface requires dart:ffi.');
}

/// Imports a single [Series] from Apache Arrow C Data structures (stub).
Series<Object?> importSeriesFromArrowC({
  required Object schema,
  required Object array,
  bool release = true,
}) {
  throw UnsupportedError('Arrow C Data interface requires dart:ffi.');
}
