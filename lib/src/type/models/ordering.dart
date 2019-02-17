library data.type.models.ordering;

/// Encapsulates a total order of objects.
abstract class Ordering<T> {
  const Ordering();

  int compare(T a, T b);
}
