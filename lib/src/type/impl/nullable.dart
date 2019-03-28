library data.type.impl.nullable;

import 'dart:collection' show ListBase;

import 'package:collection/collection.dart' show NonGrowableListMixin;
import 'package:data/src/type/type.dart';
import 'package:more/collection.dart' show BitList;
import 'package:more/printer.dart' show Printer;

/// Some [DataType] instances do not support `null` values in the way they
/// represent their data. This wrapper turns those types into nullable ones.
class NullableDataType<T> extends DataType<T> {
  NullableDataType(this.delegate);

  final DataType<T> delegate;

  @override
  String get name => '${delegate.name}.nullable';

  @override
  bool get isNullable => true;

  @override
  T get nullValue => null;

  @override
  T cast(Object value) => value == null ? null : delegate.cast(value);

  @override
  List<T> newList(int length) => NullableList(delegate.newList(length));

  @override
  bool operator ==(Object other) =>
      other is NullableDataType && other.delegate == delegate;

  @override
  int get hashCode => ~delegate.hashCode;

  @override
  Printer get printer => delegate.printer.undefined('n/a');
}

/// A list with null values, where the null values are tracked in a separate
/// [BitList]. For certain types of typed lists, this is the only way to track
/// `null` values.
class NullableList<T> extends ListBase<T> with NonGrowableListMixin<T> {
  NullableList(this.delegate) : defined = BitList(delegate.length);

  final List<T> delegate;

  final BitList defined;

  @override
  int get length => defined.length;

  @override
  T operator [](int index) => defined[index] ? delegate[index] : null;

  @override
  void operator []=(int index, T value) {
    if (value == null) {
      defined[index] = false;
    } else {
      delegate[index] = value;
      defined[index] = true;
    }
  }
}
