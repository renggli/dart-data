/// Defines equality and closeness for elements.
abstract class Equality<T> {
  const new();

  bool isEqual(T a, T b);

  bool isClose(T a, T b, double epsilon) => isEqual(a, b);

  int hash(T a);
}

class NaturalEquality<T> extends Equality<T> {
  const new();

  @override
  bool isEqual(T a, T b) => a == b;

  @override
  int hash(T a) => a.hashCode;
}

class FloatEquality extends Equality<double> {
  const new();

  @override
  bool isEqual(double a, double b) => a == b;

  @override
  bool isClose(double a, double b, double epsilon) => (a - b).abs() <= epsilon;

  @override
  int hash(double a) => a.hashCode;
}
