library pandas.index;

import 'dart:collection' show UnmodifiableMapView;

/// Immutable index of labels of type `T` to indexes in a list.
class Index<T> extends UnmodifiableMapView<T, int> {

  /// Constructs an empty index.
  factory Index.empty() => new Index._(new Map());

  /// Constructs an index from an iterable.
  factory Index.fromIterable(Iterable source, {T label(label)}) {
    var index = 0;
    var mapping = new LinkedHashMap.fromIterable(source, key: label, value: (object) => index++);
    return new Index._(mapping);
  }

  Index._(this.mapping_);

  /// The name of this index.
  final Map<T, int> mapping_;

  /// The length of the index.
  int get length => mapping_.length;

  /// The labels of this index.
  Iterable<T> get labels => mapping_.keys;

  /// The indexes of this index.
  Iterable<int> get indexes => mapping_.values;

  /// Returns the index of the provided label.
  int getIndex(T label) => mapping_[label];

  /// Returns a list of indexes at the provided labels.
  List<int> getIndexes(List<T> labels) {
    return labels
        .map((label) => getIndex(label))
        .toList(growable: false);
  }
}