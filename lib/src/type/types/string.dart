import 'dart:math' as math;

import '../data_type.dart';
import '../models/equality.dart';

/// Data type descriptor for string values ([String]).
final class StringDataType extends DataType<String> {
  /// Creates a new [StringDataType] instance.
  const new();

  @override
  String get name => 'string';

  @override
  String get defaultValue => '';

  @override
  int comparator(String a, String b) => a.compareTo(b);

  @override
  Equality<String> get equality => const StringEquality();

  @override
  String cast(Object? value) => value.toString();
}

/// Equality relation for [String] values with edit-distance proximity testing.
final class StringEquality extends NaturalEquality<String> {
  /// Creates a new [StringEquality] instance.
  const new();

  @override
  bool isClose(String a, String b, double epsilon) {
    if (a == b) return epsilon >= 0;
    if (epsilon < 1) return false;
    return _editDistance(a, b) <= epsilon;
  }
}

int _editDistance(String a, String b) {
  if (a.length < b.length) {
    return _editDistance(b, a);
  }
  var v0 = DataType.index.newList(b.length + 1);
  var v1 = DataType.index.newList(b.length + 1);
  for (var i = 0; i <= b.length; i++) {
    v0[i] = i;
  }
  for (var i = 0; i < a.length; i++) {
    v1[0] = i + 1;
    for (var j = 0; j < b.length; j++) {
      v1[j + 1] = math.min(
        v0[j + 1] + 1,
        math.min(v1[j] + 1, a[i] == b[j] ? v0[j] : v0[j] + 1),
      );
    }
    final temp = v0;
    v0 = v1;
    v1 = temp;
  }
  return v0[b.length];
}
