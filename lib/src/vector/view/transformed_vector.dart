library data.vector.view.transformed;

import '../../../type.dart';
import '../../shared/storage.dart';
import '../vector.dart';

/// Read-only transformed vector.
class TransformedVector<S, T> with Vector<T> {
  final Vector<S> vector;
  final T Function(int index, S value) read;
  final S Function(int index, T value) write;

  TransformedVector(this.vector, this.read, this.write, this.dataType);

  @override
  final DataType<T> dataType;

  @override
  int get count => vector.count;

  @override
  Set<Storage> get storage => vector.storage;

  @override
  Vector<T> copy() =>
      TransformedVector<S, T>(vector.copy(), read, write, dataType);

  @override
  T getUnchecked(int index) => read(index, vector.getUnchecked(index));

  @override
  void setUnchecked(int index, T value) =>
      vector.setUnchecked(index, write(index, value));
}

extension TransformedVectorExtension<T> on Vector<T> {
  /// Returns a read-only view on this [Vector] with all its elements lazily
  /// converted by calling the provided transformation [callback].
  Vector<S> map<S>(S Function(int index, T value) callback,
          [DataType<S> dataType]) =>
      transform<S>(callback, dataType: dataType);

  /// Returns a view on this [Vector] with all its elements lazily converted
  /// by calling the provided [read] transformation. An optionally provided
  /// [write] transformation enables writing to the returned vector.
  Vector<S> transform<S>(S Function(int index, T value) read,
          {T Function(int index, S value) write, DataType<S> dataType}) =>
      TransformedVector<T, S>(
        this,
        read,
        write ?? (i, v) => throw UnsupportedError('Vector is not mutable.'),
        dataType ?? DataType.fromType(S),
      );
}
