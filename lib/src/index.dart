library pandas.index;

import 'dart:collection' show UnmodifiableMapView;

/// Immutable index of labels of type `T` to indexes in a list.
class Index<T> extends UnmodifiableMapView<T, int> {
  /// Constructs an empty index.
  factory Index.empty() => Index._({});

  /// Constructs an index from an iterable.
  factory Index.fromIterable(Iterable source, {T label(label)}) {
    var index = 0;
    final mapping =
        Map.fromIterable(source, key: label, value: (object) => index++);
    return Index._(mapping);
  }

  Index._(Map<T, int> map) : super(map);

  /// The labels of this index.
  Iterable<T> get labels => keys;

  /// The indexes of this index.
  Iterable<int> get indexes => values;

  /// Returns the index of the provided label.
  int getIndex(T label) => this[label];

  /// Returns a list of indexes at the provided labels.
  List<int> getIndexes(List<T> labels) =>
      labels.map(getIndex).toList(growable: false);
}
