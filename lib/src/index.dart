library pandas.index;

import 'dart:collection' show UnmodifiableMapView;

/// Immutable index of labels of type `T` to indexes in a list.
class Index<T> extends UnmodifiableMapView<T, int> {

  /// Constructs an empty index.
  factory Index.empty() => new Index._(new Map());

  /// Constructs an index from an iterable.
  factory Index.fromIterable(Iterable source, {T label(label)}) {
    var index = 0;
    var mapping = new Map.fromIterable(source, key: label, value: (object) => index++);
    return new Index._(mapping);
  }

  Index._(Map<T, int> map) : super(map);

  /// The labels of this index.
  Iterable<T> get labels => keys;

  /// The indexes of this index.
  Iterable<int> get indexes => values;

  /// Returns the index of the provided label.
  int getIndex(T label) => this[label];

  /// Returns a list of indexes at the provided labels.
  List<int> getIndexes(List<T> labels) {
    return labels
        .map((label) => getIndex(label))
        .toList(growable: false);
  }
}