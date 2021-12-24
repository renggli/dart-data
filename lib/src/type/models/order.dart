import 'package:meta/meta.dart';

/// Encapsulates a total order of objects.
@immutable
abstract class Order<T> {
  const Order();

  /// Compares [a] with [b] and returns
  ///
  /// * a negative integer if [a] is smaller than [b],
  /// * zero if [a] is equal to [b], and
  /// * a positive integer if [a] is greater than [b].
  ///
  int compare(T a, T b);
}

/// The natural and canonical order of objects.
class NaturalOrder<T extends Comparable> extends Order<T> {
  const NaturalOrder();

  @override
  int compare(T a, T b) => a.compareTo(b);
}
