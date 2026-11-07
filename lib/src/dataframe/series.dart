import 'dart:math' as math;

import '../type/data_type.dart';
import '../type/types/nullable.dart';
import 'arrow/arrow_c_data.dart';
import 'arrow_string_series.dart';
import 'bitmask.dart';
import 'dataframe.dart';
import 'tuple_key.dart';

/// 1-dimensional columnar series with optional Apache Arrow validity bitmask.
///
/// Conceptually, a [Series] is a single named column in a table (such as a
/// "Score" or "Age" column in a spreadsheet) holding values for each row.
/// Mathematically, it represents an ordered 1-tuple sequence
/// $(x_0, \dots, x_{n-1})$ over a domain $T \cup \{\bot\}$, backed by
/// contiguous typed buffers and a separate null bitmap for $\mathcal{O}(1)$
/// random access without boxing primitive types.
///
/// ```dart
/// final series = Series<double>.fromList('scores', [95.0, 88.0, 92.5]);
/// print(series.name); // 'scores'
/// print(series.mean); // ~91.83
/// ```
abstract class Series<T> {
  /// Initializes a [Series] instance.
  const new();

  /// Factory constructor creating appropriate typed series from an iterable or
  /// list.
  factory fromList(
    String name,
    Iterable<Object?> iterable, {
    DataType<T>? type,
  }) {
    final list = iterable.toList(growable: false);
    if (type != null) {
      final effectiveType = type is NullableDataType
          ? (type as NullableDataType).delegate
          : type;
      if (effectiveType is DataType<int>) {
        final intList = list
            .map(
              (element) => element == null ? null : effectiveType.cast(element),
            )
            .toList(growable: false);
        return TypedSeries<int>.fromList(name, intList, type: effectiveType)
            as Series<T>;
      } else if (effectiveType is DataType<double>) {
        final dblList = list
            .map(
              (element) => element == null ? null : effectiveType.cast(element),
            )
            .toList(growable: false);
        return TypedSeries<double>.fromList(name, dblList, type: effectiveType)
            as Series<T>;
      } else if (effectiveType is DataType<num>) {
        final numList = list
            .map(
              (element) => element == null ? null : effectiveType.cast(element),
            )
            .toList(growable: false);
        return TypedSeries<num>.fromList(name, numList, type: effectiveType)
            as Series<T>;
      } else if (effectiveType is DataType<String>) {
        final strList = list
            .map(
              (element) => element == null ? null : effectiveType.cast(element),
            )
            .toList(growable: false);
        return StringSeries.fromList(name, strList) as Series<T>;
      } else if (effectiveType is DataType<bool>) {
        final boolList = list
            .map(
              (element) => element == null ? null : effectiveType.cast(element),
            )
            .toList(growable: false);
        return BoolSeries.fromList(name, boolList) as Series<T>;
      } else {
        final objList = list
            .map(
              (element) =>
                  element == null ? null : effectiveType.cast(element) as T,
            )
            .toList(growable: false);
        return ObjectSeries<T>.fromList(name, objList, type: type);
      }
    }
    Object? firstNonNull;
    for (final element in list) {
      if (element != null) {
        firstNonNull = element;
        break;
      }
    }
    if (T == int ||
        T == _typeOf<int?>() ||
        list is List<int> ||
        list is List<int?>) {
      final intList = list
          .map(
            (element) => element == null
                ? null
                : (element is num
                      ? element.toInt()
                      : DataType.int64.cast(element)),
          )
          .toList(growable: false);
      return TypedSeries<int>.fromList(name, intList) as Series<T>;
    } else if (T == double ||
        T == _typeOf<double?>() ||
        list is List<double> ||
        list is List<double?>) {
      final dblList = list
          .map(
            (element) => element == null
                ? null
                : (element is num
                      ? element.toDouble()
                      : DataType.float64.cast(element)),
          )
          .toList(growable: false);
      return TypedSeries<double>.fromList(name, dblList) as Series<T>;
    } else if (list is List<String> ||
        list is List<String?> ||
        (firstNonNull is String &&
            list.every((e) => e == null || e is String))) {
      final strList = list
          .map((element) => element as String?)
          .toList(growable: false);
      return StringSeries.fromList(name, strList) as Series<T>;
    } else if (list is List<bool> ||
        list is List<bool?> ||
        (firstNonNull is bool && list.every((e) => e == null || e is bool))) {
      final boolList = list
          .map((element) => element as bool?)
          .toList(growable: false);
      return BoolSeries.fromList(name, boolList) as Series<T>;
    } else if (firstNonNull is num &&
        list.every((e) => e == null || e is num)) {
      if (list.every((e) => e == null || e is int)) {
        final intList = list
            .map((element) => element as int?)
            .toList(growable: false);
        return TypedSeries<int>.fromList(name, intList) as Series<T>;
      }
      if (list.every((e) => e == null || e is double)) {
        final dblList = list
            .map((element) => element as double?)
            .toList(growable: false);
        return TypedSeries<double>.fromList(name, dblList) as Series<T>;
      }
      final numList = list
          .map((element) => element as num?)
          .toList(growable: false);
      return TypedSeries<num>.fromList(
        name,
        numList,
        type: type as DataType<num>?,
      ) as Series<T>;
    }
    final objList = list
        .map((element) => element as T?)
        .toList(growable: false);
    return ObjectSeries<T>.fromList(name, objList, type: type);
  }

  /// Imports a [Series] from Apache Arrow C Data structures.
  ///
  /// Consumes [schema] (`Pointer<ArrowSchema>`) and [array]
  /// (`Pointer<ArrowArray>`). If [release] is true (default), the producer's
  /// release callbacks are invoked upon import completion.
  static Series<Object?> importFrom({
    required Object schema,
    required Object array,
    bool release = true,
  }) => importSeriesFromArrowC(schema: schema, array: array, release: release);

  /// The name of this column.
  String get name;

  /// The data type of elements in this series.
  DataType<T> get dataType;

  /// The number of rows.
  int get length;

  /// The number of missing (null) values.
  int get nullCount;

  /// Optional validity bitmask tracking null values.
  ValidityMask? get mask => null;

  /// Returns true if this series contains one or more missing (null) values.
  bool get hasNulls => nullCount > 0;

  /// Returns true if the element at [index] is null.
  bool isNull(int index);

  /// Gets the element at [index], or null if missing.
  T? operator [](int index);

  /// Returns the non-null value at [index].
  ///
  /// Throws a [StateError] if the entry at [index] is null.
  T getNonNull(int index) {
    final value = this[index];
    if (value == null) {
      throw StateError('Value at index $index is null in series "$name"');
    }
    return value;
  }

  /// Returns an iterable over the values (including nulls).
  Iterable<T?> get values sync* {
    for (var i = 0; i < length; i++) {
      yield this[i];
    }
  }

  /// Converts values to a list.
  List<T?> toList() => values.toList(growable: false);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Series) return false;
    if (name != other.name ||
        length != other.length ||
        dataType != other.dataType) {
      return false;
    }
    for (var i = 0; i < length; i++) {
      final a = this[i];
      final b = other[i];
      if (a == null && b == null) continue;
      if (a == null || b == null) return false;
      if (a is num && b is num && a.isNaN && b.isNaN) continue;
      if (!dataType.equality.isEqual(a as T, b as T)) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    var hash = Object.hash(name, length, dataType);
    for (var i = 0; i < length; i++) {
      final val = this[i];
      final Object? elem;
      if (val is num) {
        if (val.isNaN) {
          elem = 0x7fc00000;
        } else if (val is double && val == 0.0) {
          elem = 0.0;
        } else {
          elem = dataType.equality.hash(val as T);
        }
      } else if (val != null) {
        elem = dataType.equality.hash(val);
      } else {
        elem = null;
      }
      hash = Object.hash(hash, elem);
    }
    return hash;
  }

  @override
  String toString() => 'Series<$T>($name, length: $length, nulls: $nullCount)';

  /// Filters this series using a boolean [mask].
  Series<T> filter(List<bool> mask);

  /// Slices rows in range [[start], [end]).
  Series<T> slice(int start, int end);

  /// Permutes elements of this series according to [indices].
  Series<T> permute(List<int> indices);

  /// Returns a new series with [other] concatenated to the end.
  Series<Object?> concat(Series<Object?> other) {
    final combinedType = dataType.promoteWith(other.dataType);
    final combinedVals = <Object?>[
      for (var i = 0; i < length; i++)
        if (isNull(i)) null else combinedType.cast(this[i]),
      for (var i = 0; i < other.length; i++)
        if (other.isNull(i)) null else combinedType.cast(other[i]),
    ];
    return Series.fromList(name, combinedVals, type: combinedType);
  }

  /// Sorts this series.
  Series<T> sort({bool ascending = true, bool nullsLast = true});

  /// Returns a copy of this series with a new [name].
  Series<T> rename(String newName);

  /// Returns a copy of this series with null values removed.
  Series<T> dropNulls() {
    if (!hasNulls) return this;
    final mask = [for (var i = 0; i < length; i++) !isNull(i)];
    return filter(mask);
  }

  /// Returns a copy of this series with null values replaced by [value].
  Series<T> fillNull(T value) {
    if (!hasNulls) return this;
    final list = [
      for (var i = 0; i < length; i++)
        if (isNull(i)) value else this[i],
    ];
    return Series.fromList(name, list, type: dataType);
  }

  /// Transforms elements of this series using [fn], ignoring null entries.
  Series<R> map<R>(R Function(T value) fn, {String? name, DataType<R>? type}) {
    final newName = name ?? this.name;
    final list = <R?>[];
    for (var i = 0; i < length; i++) {
      if (isNull(i)) {
        list.add(null);
      } else {
        list.add(fn(this[i] as T));
      }
    }
    return Series.fromList(newName, list, type: type);
  }

  /// Returns a series containing only unique values in order of appearance.
  Series<T> unique() {
    final seen = <Object?>{};
    final mask = <bool>[];
    for (var i = 0; i < length; i++) {
      mask.add(seen.add(canonicalizeKey(this[i])));
    }
    return filter(mask);
  }

  /// Returns a [DataFrame] containing unique values and their occurrence counts.
  DataFrame valueCounts({bool ascending = false, bool dropNulls = false}) {
    final counts = <Object?, int>{};
    final keyToValue = <Object?, T?>{};
    for (var i = 0; i < length; i++) {
      final val = this[i];
      if (dropNulls && val == null) continue;
      final key = canonicalizeKey(val);
      counts[key] = (counts[key] ?? 0) + 1;
      keyToValue.putIfAbsent(key, () => val);
    }
    final entries = counts.entries.toList();
    entries.sort(
      (a, b) =>
          ascending ? a.value.compareTo(b.value) : b.value.compareTo(a.value),
    );
    final valueList = [for (final e in entries) keyToValue[e.key]];
    final countList = [for (final e in entries) e.value];
    return DataFrame([
      Series.fromList(name, valueList, type: dataType),
      Series<int>.fromList('count', countList, type: DataType.int32),
    ]);
  }

  /// Exports this [Series] to Apache Arrow C Data structures.
  ///
  /// Populates [outSchema] (`Pointer<ArrowSchema>`) and [outArray]
  /// (`Pointer<ArrowArray>`). Requires `dart:ffi`.
  void exportTo({required Object outSchema, required Object outArray}) =>
      exportSeriesToArrowC(
        series: this,
        outSchema: outSchema,
        outArray: outArray,
      );

  /// Number of non-null elements in this series.
  int get count => length - nullCount;

  /// Minimum value in the series, ignoring nulls.
  T? get min;

  /// Maximum value in the series, ignoring nulls.
  T? get max;

  /// Sum of all values, ignoring nulls.
  num? get sum;

  /// Mean of all values, ignoring nulls.
  double? get mean;

  /// Sample or population variance of values, ignoring nulls.
  ///
  /// Returns `null` if the series has fewer than 2 elements (or fewer than 1
  /// for [population] variance), or if the series is non-numeric.
  double? variance({bool population = false});

  /// Sample or population standard deviation of values, ignoring nulls.
  ///
  /// Returns `null` if the series has fewer than 2 elements (or fewer than 1
  /// for [population] variance), or if the series is non-numeric.
  double? std({bool population = false});

  /// Median value in the series, ignoring nulls.
  ///
  /// Returns `null` if the series has no non-null elements or is non-numeric.
  double? median();

  /// Empirical quantile of values for fraction [p] in `[0.0, 1.0]`, ignoring
  /// nulls, using linear interpolation.
  ///
  /// Returns `null` if the series has no non-null elements or is non-numeric.
  double? quantile(double p);
}

/// [Series] backed by typed contiguous buffers for numerical values.
class TypedSeries<T extends num> extends Series<T> {
  /// Creates a typed series with [name], underlying typed [data], [dataType],
  /// and optional null [mask].
  new({
    required this.name,
    required this.data,
    required this.dataType,
    this.mask,
  }) : length = data.length {
    final m = mask;
    if (m != null && m.length != data.length) {
      throw ArgumentError(
        'ValidityMask length (${m.length}) must match data length (${data.length}).',
      );
    }
  }

  /// Creates a [TypedSeries] from a nullable [list] of numbers.
  factory fromList(String name, List<T?> list, {DataType<T>? type}) {
    DataType<T> inferIntType() =>
        list.any((v) => v is int && (v < -0x80000000 || v > 0x7FFFFFFF))
        ? DataType.int64 as DataType<T>
        : DataType.int32 as DataType<T>;

    final effectiveType =
        type ??
        (T == double
            ? DataType.float64 as DataType<T>
            : (T == int
                  ? inferIntType()
                  : (list.any((element) => element is double)
                        ? DataType.float64 as DataType<T>
                        : inferIntType())));
    final len = list.length;
    final data = effectiveType.newList(len);
    ValidityMask? mask;

    for (var i = 0; i < len; i++) {
      final val = list[i];
      if (val == null) {
        mask ??= ValidityMask(len);
        mask.setNull(i);
        data[i] = effectiveType.defaultValue;
      } else {
        data[i] = effectiveType.cast(val);
      }
    }

    return TypedSeries(
      name: name,
      data: data,
      dataType: effectiveType,
      mask: mask,
    );
  }

  @override
  final String name;

  /// Underlying typed data buffer.
  final List<T> data;

  /// Optional validity bitmask tracking null values.
  @override
  final ValidityMask? mask;

  @override
  final DataType<T> dataType;

  @override
  final int length;

  @override
  int get nullCount => mask?.nullCount ?? 0;

  @override
  bool isNull(int index) {
    RangeError.checkValidIndex(index, this, 'index', length);
    return mask?.isNull(index) ?? false;
  }

  @override
  T? operator [](int index) {
    if (isNull(index)) return null;
    return data[index];
  }

  @override
  T getNonNull(int index) {
    if (isNull(index)) {
      throw StateError('Value at index $index is null in series "$name"');
    }
    return data[index];
  }

  /// Returns the value at [index] without null checking.
  @pragma('vm:prefer-inline')
  T getUnchecked(int index) => data[index];

  @override
  Series<T> filter(List<bool> filterMask) {
    if (filterMask.length != length) {
      throw ArgumentError(
        'Filter mask length (${filterMask.length}) must match series length ($length)',
      );
    }
    var count = 0;
    for (var i = 0; i < length; i++) {
      if (filterMask[i]) count++;
    }
    final targetData = dataType.newList(count);
    ValidityMask? targetMask;
    var targetIndex = 0;
    for (var i = 0; i < length; i++) {
      if (filterMask[i]) {
        targetData[targetIndex] = data[i];
        if (isNull(i)) {
          targetMask ??= ValidityMask(count);
          targetMask.setNull(targetIndex);
        }
        targetIndex++;
      }
    }
    return TypedSeries<T>(
      name: name,
      data: targetData,
      dataType: dataType,
      mask: targetMask,
    );
  }

  @override
  Series<T> slice(int start, int end) {
    final startIndex = start.clamp(0, length);
    final endIndex = math.min(length, math.max(startIndex, end));
    final slicedData = data.sublist(startIndex, endIndex);
    final slicedMask = mask?.slice(startIndex, endIndex);
    return TypedSeries<T>(
      name: name,
      data: slicedData,
      dataType: dataType,
      mask: (slicedMask != null && slicedMask.nullCount > 0)
          ? slicedMask
          : null,
    );
  }

  @override
  Series<T> permute(List<int> indices) {
    final count = indices.length;
    final permutedData = dataType.newList(count);
    ValidityMask? permutedMask;
    for (var i = 0; i < count; i++) {
      final idx = indices[i];
      if (isNull(idx)) {
        permutedMask ??= ValidityMask(count);
        permutedMask.setNull(i);
        permutedData[i] = dataType.defaultValue;
      } else {
        permutedData[i] = data[idx];
      }
    }
    return TypedSeries<T>(
      name: name,
      data: permutedData,
      dataType: dataType,
      mask: permutedMask,
    );
  }

  @override
  TypedSeries<T> fillNull(T value) {
    if (!hasNulls) return this;
    final castValue = dataType.cast(value);
    final newData = dataType.newList(length);
    newData.setRange(0, length, data);
    final m = mask;
    if (m != null) {
      for (var i = 0; i < length; i++) {
        if (m.isNull(i)) {
          newData[i] = castValue;
        }
      }
    }
    return TypedSeries<T>(
      name: name,
      data: newData,
      dataType: dataType,
      mask: null,
    );
  }

  @override
  Series<Object?> concat(Series<Object?> other) {
    if (other is TypedSeries<T> && other.dataType == dataType) {
      final newLen = length + other.length;
      final newData = dataType.newList(newLen);
      newData.setRange(0, length, data);
      newData.setRange(length, newLen, other.data);
      final newMask = ValidityMask.concatMasks(
        mask,
        length,
        other.mask,
        other.length,
      );
      return TypedSeries<T>(
        name: name,
        data: newData,
        dataType: dataType,
        mask: newMask,
      );
    }
    return super.concat(other);
  }

  @override
  Series<T> sort({bool ascending = true, bool nullsLast = true}) {
    final indices = List<int>.generate(length, (i) => i);
    indices.sort((a, b) {
      final aNull = isNull(a);
      final bNull = isNull(b);
      if (aNull && bNull) return 0;
      if (aNull) return nullsLast ? 1 : -1;
      if (bNull) return nullsLast ? -1 : 1;
      final valA = data[a];
      final valB = data[b];
      final isNanA = valA.isNaN;
      final isNanB = valB.isNaN;
      final int cmp;
      if (isNanA && isNanB) {
        cmp = 0;
      } else if (isNanA) {
        cmp = 1;
      } else if (isNanB) {
        cmp = -1;
      } else {
        cmp = valA.compareTo(valB);
      }
      return ascending ? cmp : -cmp;
    });

    return permute(indices);
  }

  @override
  Series<T> rename(String newName) =>
      TypedSeries(name: newName, data: data, dataType: dataType, mask: mask);

  @override
  T? get min {
    T? result;
    for (var i = 0; i < length; i++) {
      if (!isNull(i)) {
        final val = data[i];
        if (val.isNaN) return val;
        if (result == null || val.compareTo(result) < 0) {
          result = val;
        }
      }
    }
    return result;
  }

  @override
  T? get max {
    T? result;
    for (var i = 0; i < length; i++) {
      if (!isNull(i)) {
        final val = data[i];
        if (val.isNaN) return val;
        if (result == null || val.compareTo(result) > 0) {
          result = val;
        }
      }
    }
    return result;
  }

  @override
  num? get sum {
    num total = 0;
    var count = 0;
    for (var i = 0; i < length; i++) {
      if (!isNull(i)) {
        total += data[i];
        count++;
      }
    }
    return count > 0 ? total : null;
  }

  @override
  double? get mean {
    final currentSum = sum;
    final validCount = length - nullCount;
    return (currentSum != null && validCount > 0)
        ? currentSum.toDouble() / validCount
        : null;
  }

  @override
  double? variance({bool population = false}) {
    var validCount = 0;
    var mean = 0.0;
    var m2 = 0.0;
    for (var i = 0; i < length; i++) {
      if (!isNull(i)) {
        final val = data[i].toDouble();
        if (val.isNaN) return double.nan;
        validCount++;
        final delta = val - mean;
        mean += delta / validCount;
        final delta2 = val - mean;
        m2 += delta * delta2;
      }
    }
    final divisor = population ? validCount : validCount - 1;
    if (divisor <= 0) return null;
    final v = m2 / divisor;
    return v < 0.0 ? 0.0 : v;
  }

  @override
  double? std({bool population = false}) {
    final v = variance(population: population);
    return v != null ? math.sqrt(v) : null;
  }

  @override
  double? median() => quantile(0.5);

  @override
  double? quantile(double p) {
    if (p < 0.0 || p > 1.0 || p.isNaN) {
      throw RangeError.value(p, 'p', 'Must be between 0.0 and 1.0');
    }
    final nonNulls = <double>[];
    for (var i = 0; i < length; i++) {
      if (!isNull(i)) {
        final val = data[i].toDouble();
        if (val.isNaN) return double.nan;
        nonNulls.add(val);
      }
    }
    final n = nonNulls.length;
    if (n == 0) return null;
    nonNulls.sort();
    final idx = p * (n - 1);
    final low = idx.floor();
    final frac = idx - low;
    if (low >= n - 1) return nonNulls.last;
    return nonNulls[low] + frac * (nonNulls[low + 1] - nonNulls[low]);
  }
}

/// String [Series] column representation backed by Apache Arrow-compliant
/// [ArrowStringSeries].
typedef StringSeries = ArrowStringSeries;

/// Boolean [Series] column representation.
class BoolSeries extends Series<bool> {
  /// Creates a boolean series with [name], underlying boolean [data], and
  /// optional null [mask].
  new({required this.name, required this.data, this.mask})
    : length = data.length {
    final m = mask;
    if (m != null && m.length != data.length) {
      throw ArgumentError(
        'ValidityMask length (${m.length}) must match data length (${data.length}).',
      );
    }
  }

  /// Creates a [BoolSeries] from a nullable [list] of booleans.
  factory fromList(String name, List<bool?> list) {
    final len = list.length;
    final data = List<bool>.filled(len, false);
    ValidityMask? mask;

    for (var i = 0; i < len; i++) {
      final val = list[i];
      if (val == null) {
        mask ??= ValidityMask(len);
        mask.setNull(i);
      } else {
        data[i] = val;
      }
    }

    return BoolSeries(name: name, data: data, mask: mask);
  }

  @override
  final String name;

  /// Underlying boolean data buffer.
  final List<bool> data;

  /// Optional validity bitmask tracking null values.
  @override
  final ValidityMask? mask;

  @override
  final int length;

  @override
  DataType<bool> get dataType => DataType.boolean;

  @override
  int get nullCount => mask?.nullCount ?? 0;

  @override
  bool isNull(int index) {
    RangeError.checkValidIndex(index, this, 'index', length);
    return mask?.isNull(index) ?? false;
  }

  @override
  bool? operator [](int index) => isNull(index) ? null : data[index];

  @override
  Series<bool> filter(List<bool> filterMask) {
    if (filterMask.length != length) {
      throw ArgumentError(
        'Filter mask length (${filterMask.length}) must match series length ($length)',
      );
    }
    var count = 0;
    for (var i = 0; i < length; i++) {
      if (filterMask[i]) count++;
    }
    final targetData = List<bool>.filled(count, false);
    ValidityMask? targetMask;
    var targetIndex = 0;
    for (var i = 0; i < length; i++) {
      if (filterMask[i]) {
        targetData[targetIndex] = data[i];
        if (isNull(i)) {
          targetMask ??= ValidityMask(count);
          targetMask.setNull(targetIndex);
        }
        targetIndex++;
      }
    }
    return BoolSeries(name: name, data: targetData, mask: targetMask);
  }

  @override
  Series<bool> slice(int start, int end) {
    final startIndex = start.clamp(0, length);
    final endIndex = math.min(length, math.max(startIndex, end));
    final slicedData = data.sublist(startIndex, endIndex);
    final slicedMask = mask?.slice(startIndex, endIndex);
    return BoolSeries(
      name: name,
      data: slicedData,
      mask: (slicedMask != null && slicedMask.nullCount > 0)
          ? slicedMask
          : null,
    );
  }

  @override
  Series<bool> permute(List<int> indices) {
    final count = indices.length;
    final permutedData = List<bool>.filled(count, false);
    ValidityMask? permutedMask;
    for (var i = 0; i < count; i++) {
      final idx = indices[i];
      if (isNull(idx)) {
        permutedMask ??= ValidityMask(count);
        permutedMask.setNull(i);
      } else {
        permutedData[i] = data[idx];
      }
    }
    return BoolSeries(name: name, data: permutedData, mask: permutedMask);
  }

  @override
  BoolSeries fillNull(bool value) {
    if (!hasNulls) return this;
    final newData = List<bool>.of(data);
    final m = mask;
    if (m != null) {
      for (var i = 0; i < length; i++) {
        if (m.isNull(i)) {
          newData[i] = value;
        }
      }
    }
    return BoolSeries(name: name, data: newData, mask: null);
  }

  @override
  Series<Object?> concat(Series<Object?> other) {
    if (other is BoolSeries) {
      final newLen = length + other.length;
      final newData = List<bool>.filled(newLen, false);
      newData.setRange(0, length, data);
      newData.setRange(length, newLen, other.data);
      final newMask = ValidityMask.concatMasks(
        mask,
        length,
        other.mask,
        other.length,
      );
      return BoolSeries(name: name, data: newData, mask: newMask);
    }
    return super.concat(other);
  }

  @override
  Series<bool> sort({bool ascending = true, bool nullsLast = true}) {
    final indices = List<int>.generate(length, (i) => i);
    indices.sort((a, b) {
      final aNull = isNull(a);
      final bNull = isNull(b);
      if (aNull && bNull) return 0;
      if (aNull) return nullsLast ? 1 : -1;
      if (bNull) return nullsLast ? -1 : 1;
      final cmp = (data[a] ? 1 : 0).compareTo(data[b] ? 1 : 0);
      return ascending ? cmp : -cmp;
    });
    return permute(indices);
  }

  @override
  Series<bool> rename(String newName) =>
      BoolSeries(name: newName, data: data, mask: mask);

  @override
  bool? get min {
    var hasTrue = false;
    for (var i = 0; i < length; i++) {
      if (!isNull(i)) {
        if (!data[i]) return false;
        hasTrue = true;
      }
    }
    return hasTrue ? true : null;
  }

  @override
  bool? get max {
    var hasFalse = false;
    for (var i = 0; i < length; i++) {
      if (!isNull(i)) {
        if (data[i]) return true;
        hasFalse = true;
      }
    }
    return hasFalse ? false : null;
  }

  @override
  double? variance({bool population = false}) => null;

  @override
  double? std({bool population = false}) => null;

  @override
  double? median() => null;

  @override
  double? quantile(double p) => null;

  @override
  num? get sum {
    final valid = length - nullCount;
    if (valid == 0) return null;
    var count = 0;
    for (var i = 0; i < length; i++) {
      if (!isNull(i) && data[i]) count++;
    }
    return count;
  }

  @override
  double? get mean {
    final currentSum = sum;
    final valid = length - nullCount;
    return (currentSum != null && valid > 0)
        ? currentSum.toDouble() / valid
        : null;
  }
}

/// Generic [Series] fallback for arbitrary Dart objects.
class ObjectSeries<T> extends Series<T> {
  /// Creates an object series with [name], underlying object [data],
  /// [dataType], and optional null [mask].
  new({
    required this.name,
    required this.data,
    required this.dataType,
    this.mask,
  }) : length = data.length {
    final m = mask;
    if (m != null && m.length != data.length) {
      throw ArgumentError(
        'ValidityMask length (${m.length}) must match data length (${data.length}).',
      );
    }
  }

  /// Creates an [ObjectSeries] from a nullable [list] of objects.
  factory fromList(String name, List<T?> list, {DataType<T>? type}) {
    final effectiveType =
        type ??
        (Object() is T
            ? DataType.object as DataType<T>
            : DataType.fromType<T>());
    final len = list.length;
    final data = List<T>.filled(len, effectiveType.defaultValue);
    ValidityMask? mask;

    for (var i = 0; i < len; i++) {
      final val = list[i];
      if (val == null) {
        mask ??= ValidityMask(len);
        mask.setNull(i);
      } else {
        data[i] = val;
      }
    }

    return ObjectSeries(
      name: name,
      data: data,
      dataType: effectiveType,
      mask: mask,
    );
  }

  @override
  final String name;

  /// Underlying object data buffer.
  final List<T> data;

  /// Optional validity bitmask tracking null values.
  @override
  final ValidityMask? mask;

  @override
  final DataType<T> dataType;

  @override
  final int length;

  @override
  int get nullCount => mask?.nullCount ?? 0;

  @override
  bool isNull(int index) {
    RangeError.checkValidIndex(index, this, 'index', length);
    return mask?.isNull(index) ?? false;
  }

  @override
  T? operator [](int index) => isNull(index) ? null : data[index];

  @override
  Series<T> filter(List<bool> filterMask) {
    if (filterMask.length != length) {
      throw ArgumentError(
        'Filter mask length (${filterMask.length}) must match series length ($length)',
      );
    }
    var count = 0;
    for (var i = 0; i < length; i++) {
      if (filterMask[i]) count++;
    }
    final targetData = List<T>.filled(count, dataType.defaultValue);
    ValidityMask? targetMask;
    var targetIndex = 0;
    for (var i = 0; i < length; i++) {
      if (filterMask[i]) {
        targetData[targetIndex] = data[i];
        if (isNull(i)) {
          targetMask ??= ValidityMask(count);
          targetMask.setNull(targetIndex);
        }
        targetIndex++;
      }
    }
    return ObjectSeries<T>(
      name: name,
      data: targetData,
      dataType: dataType,
      mask: targetMask,
    );
  }

  @override
  Series<T> slice(int start, int end) {
    final startIndex = start.clamp(0, length);
    final endIndex = math.min(length, math.max(startIndex, end));
    final slicedData = data.sublist(startIndex, endIndex);
    final slicedMask = mask?.slice(startIndex, endIndex);
    return ObjectSeries<T>(
      name: name,
      data: slicedData,
      dataType: dataType,
      mask: (slicedMask != null && slicedMask.nullCount > 0)
          ? slicedMask
          : null,
    );
  }

  @override
  Series<T> permute(List<int> indices) {
    final count = indices.length;
    final permutedData = List<T>.filled(count, dataType.defaultValue);
    ValidityMask? permutedMask;
    for (var i = 0; i < count; i++) {
      final idx = indices[i];
      if (isNull(idx)) {
        permutedMask ??= ValidityMask(count);
        permutedMask.setNull(i);
      } else {
        permutedData[i] = data[idx];
      }
    }
    return ObjectSeries<T>(
      name: name,
      data: permutedData,
      dataType: dataType,
      mask: permutedMask,
    );
  }

  @override
  ObjectSeries<T> fillNull(T value) {
    if (!hasNulls) return this;
    final newData = List<T>.of(data);
    final m = mask;
    if (m != null) {
      for (var i = 0; i < length; i++) {
        if (m.isNull(i)) {
          newData[i] = value;
        }
      }
    }
    return ObjectSeries<T>(
      name: name,
      data: newData,
      dataType: dataType,
      mask: null,
    );
  }

  @override
  Series<Object?> concat(Series<Object?> other) {
    if (other is ObjectSeries<T> && other.dataType == dataType) {
      final newLen = length + other.length;
      final newData = List<T>.filled(newLen, dataType.defaultValue);
      newData.setRange(0, length, data);
      newData.setRange(length, newLen, other.data);
      final newMask = ValidityMask.concatMasks(
        mask,
        length,
        other.mask,
        other.length,
      );
      return ObjectSeries<T>(
        name: name,
        data: newData,
        dataType: dataType,
        mask: newMask,
      );
    }
    return super.concat(other);
  }

  @override
  Series<T> sort({bool ascending = true, bool nullsLast = true}) {
    final indices = List<int>.generate(length, (i) => i);
    var supportsDataTypeCmp = true;
    for (var i = 0; i < length; i++) {
      if (!isNull(i)) {
        try {
          dataType.comparator(data[i], data[i]);
        } on UnsupportedError {
          supportsDataTypeCmp = false;
        }
        break;
      }
    }
    final cmp = supportsDataTypeCmp
        ? dataType.comparator
        : (T a, T b) {
            if (a is Comparable) {
              return (a as Comparable).compareTo(b);
            }
            return '$a'.compareTo('$b');
          };
    indices.sort((a, b) {
      final aNull = isNull(a);
      final bNull = isNull(b);
      if (aNull && bNull) return 0;
      if (aNull) return nullsLast ? 1 : -1;
      if (bNull) return nullsLast ? -1 : 1;
      final valA = data[a];
      final valB = data[b];
      final int comparison;
      if (valA is num && valB is num) {
        final isNanA = valA.isNaN;
        final isNanB = valB.isNaN;
        if (isNanA && isNanB) {
          comparison = 0;
        } else if (isNanA) {
          comparison = 1;
        } else if (isNanB) {
          comparison = -1;
        } else {
          comparison = cmp(valA, valB);
        }
      } else {
        comparison = cmp(valA, valB);
      }
      return ascending ? comparison : -comparison;
    });
    return permute(indices);
  }

  @override
  Series<T> rename(String newName) =>
      ObjectSeries(name: newName, data: data, dataType: dataType, mask: mask);

  @override
  T? get min {
    T? result;
    for (var i = 0; i < length; i++) {
      if (!isNull(i)) {
        final val = data[i];
        if (val == null) continue;
        if (result == null) {
          result = val;
        } else if (val is Comparable) {
          if (val.compareTo(result) < 0) result = val;
        } else {
          return null;
        }
      }
    }
    return result;
  }

  @override
  T? get max {
    T? result;
    for (var i = 0; i < length; i++) {
      if (!isNull(i)) {
        final val = data[i];
        if (val == null) continue;
        if (result == null) {
          result = val;
        } else if (val is Comparable) {
          if (val.compareTo(result) > 0) result = val;
        } else {
          return null;
        }
      }
    }
    return result;
  }

  @override
  num? get sum {
    num total = 0;
    var count = 0;
    for (var i = 0; i < length; i++) {
      if (!isNull(i)) {
        final val = data[i];
        if (val is! num) return null;
        total += val;
        count++;
      }
    }
    return count > 0 ? total : null;
  }

  @override
  double? get mean {
    final s = sum;
    final valid = length - nullCount;
    return (s != null && valid > 0) ? s.toDouble() / valid : null;
  }

  @override
  double? variance({bool population = false}) {
    var validCount = 0;
    var mean = 0.0;
    var m2 = 0.0;
    for (var i = 0; i < length; i++) {
      if (!isNull(i)) {
        final raw = data[i];
        if (raw is! num) return null;
        final val = raw.toDouble();
        if (val.isNaN) return double.nan;
        validCount++;
        final delta = val - mean;
        mean += delta / validCount;
        final delta2 = val - mean;
        m2 += delta * delta2;
      }
    }
    final divisor = population ? validCount : validCount - 1;
    if (divisor <= 0) return null;
    final v = m2 / divisor;
    return v < 0.0 ? 0.0 : v;
  }

  @override
  double? std({bool population = false}) {
    final v = variance(population: population);
    return v != null ? math.sqrt(v) : null;
  }

  @override
  double? median() => quantile(0.5);

  @override
  double? quantile(double p) {
    if (p < 0.0 || p > 1.0 || p.isNaN) {
      throw RangeError.value(p, 'p', 'Must be between 0.0 and 1.0');
    }
    final nonNulls = <double>[];
    for (var i = 0; i < length; i++) {
      if (!isNull(i)) {
        final raw = data[i];
        if (raw is! num) return null;
        final val = raw.toDouble();
        if (val.isNaN) return double.nan;
        nonNulls.add(val);
      }
    }
    final n = nonNulls.length;
    if (n == 0) return null;
    nonNulls.sort();
    final idx = p * (n - 1);
    final low = idx.floor();
    final frac = idx - low;
    if (low >= n - 1) return nonNulls.last;
    return nonNulls[low] + frac * (nonNulls[low + 1] - nonNulls[low]);
  }
}

Type _typeOf<X>() => X;
