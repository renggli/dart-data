import 'dart:math' as math;

import '../../type.dart';
import 'arrow_string_series.dart';
import 'bitmask.dart';

export 'arrow_string_series.dart';

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
  const new();

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

  /// Filters this series using a boolean [mask].
  Series<T> filter(List<bool> mask);

  /// Slices rows in range [[start], [end]).
  Series<T> slice(int start, int end);

  /// Sorts this series.
  Series<T> sort({bool ascending = true, bool nullsLast = true});

  /// Returns a copy of this series with a new [name].
  Series<T> rename(String newName);

  /// Minimum value in the series, ignoring nulls.
  T? get min;

  /// Maximum value in the series, ignoring nulls.
  T? get max;

  /// Sum of all values, ignoring nulls.
  num? get sum;

  /// Mean of all values, ignoring nulls.
  double? get mean;

  /// Factory constructor creating appropriate typed series from an iterable or
  /// list.
  factory fromList(
    String name,
    Iterable<dynamic> iterable, {
    DataType<T>? type,
  }) {
    final list = iterable.toList(growable: false);
    if (type != null) {
      if (T == int ||
          (type is DataType<int> && T != num && T != dynamic && T != Object)) {
        final intList = list
            .map((element) => element as int?)
            .toList(growable: false);
        return TypedSeries<int>.fromList(
          name,
          intList,
          type: type as DataType<int>,
        ) as Series<T>;
      } else if (T == double ||
          (type is DataType<double> &&
              T != num &&
              T != dynamic &&
              T != Object)) {
        final dblList = list
            .map((element) => element as double?)
            .toList(growable: false);
        return TypedSeries<double>.fromList(
          name,
          dblList,
          type: type as DataType<double>,
        ) as Series<T>;
      } else if (type is DataType<num>) {
        final numList = list
            .map((element) => element as num?)
            .toList(growable: false);
        return TypedSeries<num>.fromList(
          name,
          numList,
          type: type as DataType<num>,
        ) as Series<T>;
      } else if (type is DataType<String>) {
        final strList = list
            .map((element) => element as String?)
            .toList(growable: false);
        return StringSeries.fromList(name, strList) as Series<T>;
      } else if (type is DataType<bool>) {
        final boolList = list
            .map((element) => element as bool?)
            .toList(growable: false);
        return BoolSeries.fromList(name, boolList) as Series<T>;
      } else {
        final objList = list
            .map((element) => element as T?)
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
    if (T == int || list is List<int> || list is List<int?>) {
      final intList = list
          .map((element) => element as int?)
          .toList(growable: false);
      return TypedSeries<int>.fromList(name, intList) as Series<T>;
    } else if (T == double || list is List<double> || list is List<double?>) {
      final dblList = list
          .map((element) => element as double?)
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
  }) : length = data.length;

  factory fromList(String name, List<T?> list, {DataType<T>? type}) {
    final effectiveType =
        type ??
        (T == double
            ? DataType.float64 as DataType<T>
            : (T == int
                  ? DataType.int32 as DataType<T>
                  : (list.any((element) => element is double)
                        ? DataType.float64 as DataType<T>
                        : DataType.int32 as DataType<T>)));
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
  bool isNull(int index) => mask?.isNull(index) ?? false;

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
    final startIndex = math.max(0, start);
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
  Series<T> sort({bool ascending = true, bool nullsLast = true}) {
    final indices = List<int>.generate(length, (i) => i);
    indices.sort((a, b) {
      final aNull = isNull(a);
      final bNull = isNull(b);
      if (aNull && bNull) return 0;
      if (aNull) return nullsLast ? 1 : -1;
      if (bNull) return nullsLast ? -1 : 1;
      final cmp = data[a].compareTo(data[b]);
      return ascending ? cmp : -cmp;
    });

    final sortedList = <T?>[];
    for (final idx in indices) {
      sortedList.add(this[idx]);
    }
    return TypedSeries<T>.fromList(name, sortedList, type: dataType);
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
  String toString() => 'Series<$T>($name, length: $length, nulls: $nullCount)';
}

/// String [Series] column representation backed by Apache Arrow-compliant
/// [ArrowStringSeries].
typedef StringSeries = ArrowStringSeries;

/// Boolean [Series] column representation.
class BoolSeries extends Series<bool> {
  /// Creates a boolean series with [name], underlying boolean [data], and
  /// optional null [mask].
  new({required this.name, required this.data, this.mask})
    : length = data.length;

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
  bool isNull(int index) => mask?.isNull(index) ?? false;

  @override
  bool? operator [](int index) => isNull(index) ? null : data[index];

  @override
  Series<bool> filter(List<bool> filterMask) {
    final filtered = <bool?>[];
    for (var i = 0; i < length; i++) {
      if (filterMask[i]) filtered.add(this[i]);
    }
    return BoolSeries.fromList(name, filtered);
  }

  @override
  Series<bool> slice(int start, int end) {
    final startIndex = math.max(0, start);
    final endIndex = math.min(length, end);
    final sliced = <bool?>[];
    for (var i = startIndex; i < endIndex; i++) {
      sliced.add(this[i]);
    }
    return BoolSeries.fromList(name, sliced);
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
    return BoolSeries.fromList(name, [for (final idx in indices) this[idx]]);
  }

  @override
  Series<bool> rename(String newName) =>
      BoolSeries(name: newName, data: data, mask: mask);

  @override
  bool? get min => null;

  @override
  bool? get max => null;

  @override
  num? get sum {
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
  }) : length = data.length;

  factory fromList(String name, List<T?> list, {DataType<T>? type}) {
    final effectiveType =
        type ??
        (T == dynamic || T == Object
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
  bool isNull(int index) => mask?.isNull(index) ?? false;

  @override
  T? operator [](int index) => isNull(index) ? null : data[index];

  @override
  Series<T> filter(List<bool> filterMask) {
    final filtered = <T?>[];
    for (var i = 0; i < length; i++) {
      if (filterMask[i]) filtered.add(this[i]);
    }
    return ObjectSeries<T>.fromList(name, filtered, type: dataType);
  }

  @override
  Series<T> slice(int start, int end) {
    final startIndex = math.max(0, start);
    final endIndex = math.min(length, end);
    final sliced = <T?>[];
    for (var i = startIndex; i < endIndex; i++) {
      sliced.add(this[i]);
    }
    return ObjectSeries<T>.fromList(name, sliced, type: dataType);
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
      final comparison = cmp(data[a], data[b]);
      return ascending ? comparison : -comparison;
    });
    return ObjectSeries<T>.fromList(name, [
      for (final idx in indices) this[idx],
    ], type: dataType);
  }

  @override
  Series<T> rename(String newName) =>
      ObjectSeries(name: newName, data: data, dataType: dataType, mask: mask);

  @override
  T? get min => null;

  @override
  T? get max => null;

  @override
  num? get sum => null;

  @override
  double? get mean => null;
}
