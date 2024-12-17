/// A tuple with `row` and `column` indices into a matrix.
typedef RowColumn = ({int row, int col});

/// A tuple with `row` and `column` indices into a matrix, and the
/// corresponding `value`.
typedef RowColumnValue<T> = ({int row, int col, T value});
