import 'dart:collection' show ListBase;

import 'package:collection/collection.dart' show NonGrowableListMixin;
import 'package:more/collection.dart' show BitList;
import 'package:more/printer.dart' show Printer;

import '../type.dart';

/// Some [DataType] instances do not support `null` values in the way they
/// represent their data. This wrapper turns those types into nullable ones.
class NullableDataType<T> extends DataType<T?> {
  NullableDataType(this.delegate)
      : assert(!delegate.isNullable, '$delegate is already nullable');

  final DataType<T> delegate;

  @override
  String get name => '${delegate.name}.nullable';

  @override
  bool get isNullable => true;

  @override
  T? get defaultValue => null;

  @override
  T? cast(dynamic value) => value == null ? null : delegate.cast(value);

  @override
  List<T?> newList(int length, [T? fillValue]) => NullableList(
      delegate.newList(length, fillValue ?? delegate.defaultValue),
      delegate.defaultValue,
      fillValue != null);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NullableDataType<T> && other.delegate == delegate);

  @override
  int get hashCode => ~delegate.hashCode;

  @override
  Printer get printer => delegate.printer.undefined('n/a');
}

/// A list with null values, where the null values are tracked in a separate
/// [BitList]. For certain types of typed lists, this is the only way to track
/// `null` values.
class NullableList<T> extends ListBase<T?> with NonGrowableListMixin<T?> {
  NullableList(this.delegate, this.defaultValue, bool isDefined)
      : defined = BitList.filled(delegate.length, isDefined);

  final List<T> delegate;

  final BitList defined;

  final T defaultValue;

  @override
  int get length => defined.length;

  @override
  T? operator [](int index) => defined[index] ? delegate[index] : null;

  @override
  void operator []=(int index, T? value) {
    if (value == null) {
      delegate[index] = defaultValue;
      defined[index] = false;
    } else {
      delegate[index] = value;
      defined[index] = true;
    }
  }
}
