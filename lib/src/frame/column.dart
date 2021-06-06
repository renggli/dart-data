import '../../vector.dart';

class Column<T> {
  final String name;

  final Vector<T> vector;

  Column(this.name, this.vector);

  T operator [](int index) => vector[index];
}
