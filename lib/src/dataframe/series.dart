import 'dart:math' as math;

import '../type/data_type.dart';
import 'bitmask.dart';

/// 1-dimensional columnar series with optional Apache Arrow validity bitmask.
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

  /// Returns true if the element at [index] is null.
  bool isNull(int index);

  /// Gets the element at [index], or null if missing.
  T? operator [](int index);

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
  Series<T> sort({bool ascending = true});

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

  /// Factory constructor creating appropriate typed series from an iterable or list.
  factory fromList(
    String name,
    Iterable<dynamic> iterable, {
    DataType<T>? type,
  }) {
    final list = iterable.toList(growable: false);
    if (type != null) {
      if (type is DataType<num>) {
        final numList = list.map((e) => e as num?).toList(growable: false);
        return TypedSeries<num>.fromList(
          name,
          numList,
          type: type as DataType<num>,
        ) as Series<T>;
      } else if (type is DataType<String>) {
        final strList = list.map((e) => e as String?).toList(growable: false);
        return StringSeries.fromList(name, strList) as Series<T>;
      } else if (type is DataType<bool>) {
        final boolList = list.map((e) => e as bool?).toList(growable: false);
        return BoolSeries.fromList(name, boolList) as Series<T>;
      }
    }
    final firstNonNull = list.firstWhere((e) => e != null, orElse: () => null);
    if (firstNonNull is num) {
      final numList = list.map((e) => e as num?).toList(growable: false);
      return TypedSeries<num>.fromList(
        name,
        numList,
        type: type as DataType<num>?,
      ) as Series<T>;
    } else if (firstNonNull is String) {
      final strList = list.map((e) => e as String?).toList(growable: false);
      return StringSeries.fromList(name, strList) as Series<T>;
    } else if (firstNonNull is bool) {
      final boolList = list.map((e) => e as bool?).toList(growable: false);
      return BoolSeries.fromList(name, boolList) as Series<T>;
    }
    final objList = list.map((e) => e as T?).toList(growable: false);
    return ObjectSeries<T>.fromList(name, objList, type: type);
  }
}

/// Series backed by typed contiguous buffers for numerical values.
class TypedSeries<T extends num> extends Series<T> {
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
                  : (list.any((e) => e is double)
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
        data[i] = val;
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

  final List<T> data;

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
  Series<T> filter(List<bool> filterMask) {
    if (filterMask.length != length) {
      throw ArgumentError(
        'Filter mask length (${filterMask.length}) must match series length ($length)',
      );
    }
    final filtered = <T?>[];
    for (var i = 0; i < length; i++) {
      if (filterMask[i]) {
        filtered.add(this[i]);
      }
    }
    return TypedSeries<T>.fromList(name, filtered, type: dataType);
  }

  @override
  Series<T> slice(int start, int end) {
    final s = math.max(0, start);
    final e = math.min(length, end);
    final sliced = <T?>[];
    for (var i = s; i < e; i++) {
      sliced.add(this[i]);
    }
    return TypedSeries<T>.fromList(name, sliced, type: dataType);
  }

  @override
  Series<T> sort({bool ascending = true}) {
    final indices = List<int>.generate(length, (i) => i);
    indices.sort((a, b) {
      final aNull = isNull(a);
      final bNull = isNull(b);
      if (aNull && bNull) return 0;
      if (aNull) return 1;
      if (bNull) return -1;
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
    final s = sum;
    final validCount = length - nullCount;
    return (s != null && validCount > 0) ? s.toDouble() / validCount : null;
  }

  @override
  String toString() => 'Series<$T>($name, length: $length, nulls: $nullCount)';
}

/// String series column representation.
class StringSeries extends Series<String> {
  new({required this.name, required this.data, this.mask})
    : length = data.length;

  factory fromList(String name, List<String?> list) {
    final len = list.length;
    final data = List<String>.filled(len, '');
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

    return StringSeries(name: name, data: data, mask: mask);
  }

  @override
  final String name;

  final List<String> data;

  final ValidityMask? mask;

  @override
  DataType<String> get dataType => DataType.string;

  @override
  final int length;

  @override
  int get nullCount => mask?.nullCount ?? 0;

  @override
  bool isNull(int index) => mask?.isNull(index) ?? false;

  @override
  String? operator [](int index) => isNull(index) ? null : data[index];

  @override
  Series<String> filter(List<bool> filterMask) {
    final filtered = <String?>[];
    for (var i = 0; i < length; i++) {
      if (filterMask[i]) filtered.add(this[i]);
    }
    return StringSeries.fromList(name, filtered);
  }

  @override
  Series<String> slice(int start, int end) {
    final s = math.max(0, start);
    final e = math.min(length, end);
    final sliced = <String?>[];
    for (var i = s; i < e; i++) {
      sliced.add(this[i]);
    }
    return StringSeries.fromList(name, sliced);
  }

  @override
  Series<String> sort({bool ascending = true}) {
    final indices = List<int>.generate(length, (i) => i);
    indices.sort((a, b) {
      final aNull = isNull(a);
      final bNull = isNull(b);
      if (aNull && bNull) return 0;
      if (aNull) return 1;
      if (bNull) return -1;
      final cmp = data[a].compareTo(data[b]);
      return ascending ? cmp : -cmp;
    });
    return StringSeries.fromList(name, [for (final idx in indices) this[idx]]);
  }

  @override
  Series<String> rename(String newName) =>
      StringSeries(name: newName, data: data, mask: mask);

  @override
  String? get min {
    String? res;
    for (var i = 0; i < length; i++) {
      if (!isNull(i)) {
        if (res == null || data[i].compareTo(res) < 0) res = data[i];
      }
    }
    return res;
  }

  @override
  String? get max {
    String? res;
    for (var i = 0; i < length; i++) {
      if (!isNull(i)) {
        if (res == null || data[i].compareTo(res) > 0) res = data[i];
      }
    }
    return res;
  }

  @override
  num? get sum => null;

  @override
  double? get mean => null;
}

/// Boolean series column representation.
class BoolSeries extends Series<bool> {
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

  final List<bool> data;

  final ValidityMask? mask;

  @override
  DataType<bool> get dataType => DataType.boolean;

  @override
  final int length;

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
    final s = math.max(0, start);
    final e = math.min(length, end);
    final sliced = <bool?>[];
    for (var i = s; i < e; i++) {
      sliced.add(this[i]);
    }
    return BoolSeries.fromList(name, sliced);
  }

  @override
  Series<bool> sort({bool ascending = true}) {
    final indices = List<int>.generate(length, (i) => i);
    indices.sort((a, b) {
      final aNull = isNull(a);
      final bNull = isNull(b);
      if (aNull && bNull) return 0;
      if (aNull) return 1;
      if (bNull) return -1;
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
    final s = sum;
    final valid = length - nullCount;
    return (s != null && valid > 0) ? s.toDouble() / valid : null;
  }
}

/// Generic series fallback for arbitrary Dart objects.
class ObjectSeries<T> extends Series<T> {
  new({
    required this.name,
    required this.data,
    required this.dataType,
    this.mask,
  }) : length = data.length;

  factory fromList(String name, List<T?> list, {DataType<T>? type}) {
    final effectiveType = type ?? DataType.object as DataType<T>;
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

  final List<T> data;

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
    final s = math.max(0, start);
    final e = math.min(length, end);
    final sliced = <T?>[];
    for (var i = s; i < e; i++) {
      sliced.add(this[i]);
    }
    return ObjectSeries<T>.fromList(name, sliced, type: dataType);
  }

  @override
  Series<T> sort({bool ascending = true}) {
    final indices = List<int>.generate(length, (i) => i);
    final cmp = dataType.comparator;
    indices.sort((a, b) {
      final aNull = isNull(a);
      final bNull = isNull(b);
      if (aNull && bNull) return 0;
      if (aNull) return 1;
      if (bNull) return -1;
      final c = cmp(data[a], data[b]);
      return ascending ? c : -c;
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
