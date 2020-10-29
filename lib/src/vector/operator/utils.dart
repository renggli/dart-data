import '../../../type.dart';
import '../vector.dart';
import '../vector_format.dart';

void checkDimensions<T>(Vector<T> first, Vector<T> second) {
  if (first.count != second.count) {
    throw ArgumentError('Vector operand dimensions do not match: '
        '${first.count} and ${second.count}.');
  }
}

Vector<T> createVector<T>(Vector<T> source, Vector<T>? result,
    DataType<T>? dataType, VectorFormat? format) {
  if (result == null) {
    return Vector<T>(dataType ?? source.dataType, source.count, format: format);
  } else if (result.count == source.count) {
    return result;
  }
  throw ArgumentError('Vector result and operand dimensions do not match: '
      '${result.count} and ${source.count}.');
}

void unaryOperator<T>(
    Vector<T> result, Vector<T> source, T Function(T value) operator) {
  for (var i = 0; i < result.count; i++) {
    result.setUnchecked(i, operator(source.getUnchecked(i)));
  }
}

void binaryOperator<T>(Vector<T> result, Vector<T> first, Vector<T> second,
    T Function(T a, T b) operator) {
  checkDimensions<T>(first, second);
  for (var i = 0; i < result.count; i++) {
    result.setUnchecked(
        i, operator(first.getUnchecked(i), second.getUnchecked(i)));
  }
}
