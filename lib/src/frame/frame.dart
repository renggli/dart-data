import '../vector/vector.dart';
import 'columns.dart';
import 'indexes.dart';
import 'rows.dart';

class Frame {
  /// Constructs a new data frame from a map of column lists.
  factory Frame.fromColumnLists(Map<String, List> columns) {
    final result = Frame();
    for (final entry in columns.entries) {
      result.columns.addList(entry.value, name: entry.key);
    }
    return result;
  }

  /// Constructs a new data frame from a map of column vectors.
  factory Frame.fromColumnVectors(Map<String, Vector> columns) {
    final result = Frame();
    for (final entry in columns.entries) {
      result.columns.addVector(entry.value, name: entry.key);
    }
    return result;
  }

  /// Constructs an empty data frame.
  Frame();

  /// The columns of this data frame.
  late final Columns columns = Columns(this);

  /// The rows of this data frame.
  late final Rows rows = Rows(this);

  /// The indexes of this data frame.
  late final Indexes indexes = Indexes(this);
}
