/// Layout orientation for DataFrame JSON serialization.
enum JsonOrient {
  /// List of row objects: `[{"col1": v1, "col2": v2}, ...]`.
  records,

  /// Object with columns and data arrays:
  /// `{"columns": ["col1", "col2"], "data": [[v1, v2], ...]}`.
  split,

  /// Object mapping column names to arrays: `{"col1": [v1, v2], ...}` or
  /// row-indexed maps.
  columns,

  /// 2D array of row values: `[[v1, v2], ...]`.
  array,
}
