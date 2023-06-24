import '../../../data.dart';

/// Constructs the shape from an `iterable`.
List<int> fromIterable(Iterable<int> iterable) =>
    DataType.index.copyList(iterable, readonly: true);

/// Creates a shape from an `object` of iterables.
List<int> fromObject(Iterable<dynamic> object) {
  final values = <int>[];
  for (Object? current = object; current is Iterable; current = current.first) {
    values.add(current.length);
  }
  return fromIterable(values);
}
