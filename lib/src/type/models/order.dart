library data.type.models.order;

/// Encapsulates a total order of objects.
abstract class Order<T> {
  const Order();

  int compare(T a, T b);
}
