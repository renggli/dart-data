library data.core.series;

import 'package:data/type.dart';

/// One-dimensional list with axis labels.
///
/// Labels need not be unique but must be a hashable type. The object
/// supports both integer- and label-based indexing and provides a host of
/// methods for performing operations involving the index. Statistical
/// methods automatically exclude missing data.
class Series<T> {
  /// Creates an empty series.
  factory Series.empty({String name, DataType<T> type}) {
    final _name = name ?? '';
    final _type = type ?? DataType.object as DataType<T>;
    final _values = _type.newList(0);
    return Series._(name: _name, type: _type, values: _values);
  }

  /// Creates a series from an `Iterable`.
  factory Series.fromIterable(Iterable<T> source,
      {String name, DataType<T> type}) {
    final _name = name ?? '';
    final _type = type ?? DataType.fromIterable(source);
    final _values = _type.convertList(source);
    return Series._(name: _name, type: _type, values: _values);
  }

  /// Creates a series from a `Map`.
  factory Series.fromMap(Map<Object, T> source,
      {String name, DataType<T> type}) {
    final _name = name ?? '';
    final _type = type ?? DataType.fromIterable(source.values);
    final _values = _type.convertList(source.values);
    return Series._(name: _name, type: _type, values: _values);
  }

  /// Creates a series from a `Series`.
  factory Series.fromSeries(Series<T> source, {String name, DataType<T> type}) {
    final _name = name ?? source.name;
    final _type = type ?? source.type;
    final _values = _type.convertList(source.values);
    return Series._(name: _name, type: _type, values: _values);
  }

  Series._({this.name, this.type, this.values});

  final String name;

  final DataType<T> type;

  final List<T> values;

  T operator [](int key) => values[key];

  void operator []=(int key, T value) => values[key] = value;

  int get length => values.length;

  bool get isEmpty => values.isEmpty;

  bool get isNotEmpty => values.isNotEmpty;

  /// Returns true, if the series contains the element;
  bool containsKey(int key) => 0 <= key && key < values.length;

  /// Returns true, if the this [Series] contains the [value].
  bool containsValue(Object value) => values.contains(value);

  /// Returns a renamed [Series].
  Series<T> rename(String name) => Series.fromSeries(this, name: name);
}
