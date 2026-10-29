import 'dart:collection' show ListBase, UnmodifiableListView;

import 'package:collection/collection.dart' show NonGrowableListMixin;
import 'package:more/collection.dart' show BitList;
import 'package:more/comparator.dart';
import 'package:more/functional.dart';
import 'package:more/printer.dart' show NullPrinterExtension, Printer;

import '../data_type.dart';
import '../models/equality.dart';

/// Some [DataType] instances do not support `null` values in the way they
/// represent their data. This wrapper turns those types into nullable ones.
final class NullableDataType<T> extends DataType<T?> {
  /// Creates a new [NullableDataType] wrapping [delegate].
  new(this.delegate, {this.nullsFirst = false})
    : assert(!delegate.isNullable, '$delegate is already nullable');

  /// The wrapped non-nullable [DataType].
  final DataType<T> delegate;

  /// Whether null values sort first or last.
  final bool nullsFirst;

  @override
  String get name => '${delegate.name}.nullable';

  @override
  bool get isNullable => true;

  @override
  int get bits => delegate.bits;

  @override
  bool get isFloat => delegate.isFloat;

  @override
  bool get isInteger => delegate.isInteger;

  @override
  bool get isNumeric => delegate.isNumeric;

  @override
  bool get isSigned => delegate.isSigned;

  @override
  T? get defaultValue => null;

  @override
  int comparator(T? a, T? b) => _comparator(a, b);

  @override
  Equality<T?> get equality => _equality;

  @override
  T? cast(Object? value) => value == null ? null : delegate.cast(value);

  @override
  List<T?> newList(
    int length, {
    Map1<int, T?>? generate,
    T? fillValue,
    bool readonly = false,
  }) {
    final result = NullableList<T>(
      delegate.newList(length, fillValue: fillValue ?? delegate.defaultValue),
      delegate.defaultValue,
      fillValue != null,
    );
    if (generate != null) {
      for (var i = 0; i < length; i++) {
        result[i] = generate(i);
      }
    }
    return readonly ? UnmodifiableListView<T?>(result) : result;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NullableDataType<T> &&
          other.delegate == delegate &&
          other.nullsFirst == nullsFirst);

  @override
  int get hashCode => Object.hash(delegate, nullsFirst);

  @override
  Printer<T?> get printer => delegate.printer.ifNull('n/a');

  late final Comparator<T?> _comparator = nullsFirst
      ? delegate.comparator.nullsFirst
      : delegate.comparator.nullsLast;

  late final Equality<T?> _equality = NullableEquality<T>(delegate.equality);
}

/// Equality relation for nullable data types delegating to an underlying [Equality].
final class NullableEquality<T> implements Equality<T?> {
  /// Creates a new [NullableEquality] wrapping [delegate].
  const new(this.delegate);

  /// The delegate equality for non-null elements.
  final Equality<T> delegate;

  @override
  bool isEqual(T? a, T? b) =>
      identical(a, b) || (a != null && b != null && delegate.isEqual(a, b));

  @override
  bool isClose(T? a, T? b, double epsilon) =>
      identical(a, b) ||
      (a != null && b != null && delegate.isClose(a, b, epsilon));

  @override
  int hash(T? a) => a == null ? 0 : delegate.hash(a);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NullableEquality<T> && delegate == other.delegate);

  @override
  int get hashCode => delegate.hashCode;
}

/// A list with null values, where the null values are tracked in a separate
/// [BitList]. For certain types of typed lists, this is the only way to track
/// `null` values.
final class NullableList<T> extends ListBase<T?> with NonGrowableListMixin<T?> {
  /// Constructs a new [NullableList] wrapping [delegate] with a bitmask.
  new(this.delegate, this.defaultValue, bool isDefined)
    : defined = BitList.filled(delegate.length, isDefined);

  /// The underlying non-nullable data list.
  final List<T> delegate;

  /// The bitmask indicating whether an index is non-null.
  final BitList defined;

  /// The default fill value placed in [delegate] when an entry is set to null.
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
