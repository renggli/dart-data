import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../acceleration/blas/blas.dart';
import '../tensor/layout.dart';
import '../tensor/tensor.dart';
import '../type/data_type.dart';
import 'decomposition/lu.dart';
import 'float64_vector.dart';
import 'matrix.dart';
import 'vector.dart';

/// Zero-cost extension type wrapping [Matrix] with direct [Float64List] buffer
/// access.
///
/// This provides a 2D matrix optimized to store 64-bit floating-point numbers
/// in contiguous memory for high-performance linear algebra. Formally, it
/// provides an unboxed matrix representation over the real field $\mathbb{R}$
/// backed by flat IEEE 754 double-precision arrays compatible with BLAS level 3
/// operations.
///
/// ```dart
/// final m = Float64Matrix.filled(2, 2, 1.5);
/// print(m.rowCount); // 2
/// ```
extension type Float64Matrix._(Matrix<double> _matrix)
    implements Matrix<double> {
  /// Constructs a [Float64Matrix] wrapping [matrix].
  ///
  /// Throws an [ArgumentError] if `matrix.tensor.data` is not a [Float64List].
  factory(Matrix<double> matrix) {
    if (matrix.tensor.data is! Float64List) {
      throw ArgumentError.value(
        matrix,
        'matrix',
        'Float64Matrix requires underlying data to be Float64List, got ${matrix.tensor.data.runtimeType}',
      );
    }
    return Float64Matrix._(matrix);
  }

  /// Constructs a [Float64Matrix] from any [Matrix<double>], copying elements
  /// to a [Float64List] if not already backed by one.
  factory fromDoubleMatrix(Matrix<double> matrix) {
    if (matrix.tensor.data is Float64List) {
      return Float64Matrix._(matrix);
    }
    return Float64Matrix._(
      Matrix<double>.generate(
        matrix.rowCount,
        matrix.colCount,
        (r, c) => matrix.get(r, c),
        type: DataType.float64,
      ),
    );
  }

  /// Constructs a [rowCount] by [colCount] [Float64Matrix] filled with [value].
  factory filled(int rowCount, int colCount, double value) => Float64Matrix._(
    Matrix<double>.filled(rowCount, colCount, value, type: DataType.float64),
  );

  /// Constructs a [rowCount] by [colCount] [Float64Matrix] using [generator].
  factory generate(
    int rowCount,
    int colCount,
    double Function(int row, int col) generator,
  ) => Float64Matrix._(
    Matrix<double>.generate(
      rowCount,
      colCount,
      generator,
      type: DataType.float64,
    ),
  );

  /// Constructs a [Float64Matrix] from row vectors or row iterables.
  factory fromRows(Iterable<Iterable<double>> rows) =>
      Float64Matrix._(Matrix<double>.fromRows(rows, type: DataType.float64));

  /// Constructs a [Float64Matrix] from column vectors or column iterables.
  factory fromColumns(Iterable<Iterable<double>> cols) =>
      Float64Matrix._(Matrix<double>.fromColumns(cols, type: DataType.float64));

  /// Constructs a matrix from a flat list in row-major order.
  factory fromList(int rowCount, int colCount, List<double> values) =>
      Float64Matrix._(
        Matrix<double>(
          Tensor<double>.fromIterable(
            values,
            shape: [rowCount, colCount],
            type: DataType.float64,
          ),
        ),
      );

  /// Constructs an identity matrix of dimension [size] by [size].
  factory identity(int size) =>
      Float64Matrix._(Matrix<double>.identity(size, type: DataType.float64));

  /// Constructs a diagonal matrix from [diagonal] vector.
  factory diagonal(Vector<double> diagonal) => Float64Matrix._(
    Matrix<double>.generate(
      diagonal.length,
      diagonal.length,
      (row, col) => row == col ? diagonal[row] : 0.0,
      type: DataType.float64,
    ),
  );

  /// Direct zero-copy access to the underlying [Float64List] buffer.
  Float64List get asTypedList => _matrix.tensor.data as Float64List;

  /// Fast element access at [row] and [col] without bounds checking.
  @pragma('vm:prefer-inline')
  @redeclare
  double getUnchecked(int row, int col) {
    final t = _matrix.tensor;
    return asTypedList[t.offset + row * t.strides[0] + col * t.strides[1]];
  }

  /// Fast element mutation at [row] and [col] without bounds checking.
  @pragma('vm:prefer-inline')
  @redeclare
  void setUnchecked(int row, int col, double value) {
    final t = _matrix.tensor;
    asTypedList[t.offset + row * t.strides[0] + col * t.strides[1]] = value;
  }

  /// Fast element access at [row] and [col].
  @pragma('vm:prefer-inline')
  @redeclare
  double get(int row, int col) {
    RangeError.checkValidIndex(row, this, 'row', rowCount);
    RangeError.checkValidIndex(col, this, 'col', colCount);
    return getUnchecked(row, col);
  }

  /// Fast element mutation at [row] and [col].
  @pragma('vm:prefer-inline')
  @redeclare
  void set(int row, int col, double value) {
    RangeError.checkValidIndex(row, this, 'row', rowCount);
    RangeError.checkValidIndex(col, this, 'col', colCount);
    setUnchecked(row, col, value);
  }

  /// Returns a mutable [Float64Vector] view of the given [row].
  ///
  /// This enables natural 2D indexing syntax `matrix[r][c]`:
  /// ```dart
  /// final val = matrix[row][col];
  /// matrix[row][col] = 42.0;
  /// ```
  @pragma('vm:prefer-inline')
  @redeclare
  Float64Vector operator [](int row) {
    RangeError.checkValidIndex(row, this, 'row', rowCount);
    return this.row(row);
  }

  /// Sets the element at [pos] `(row, col)` to [value].
  @pragma('vm:prefer-inline')
  @redeclare
  void operator []=((int row, int col) pos, double value) {
    final (row, col) = pos;
    set(row, col, value);
  }

  /// Slices [row] index into a 1D [Float64Vector].
  @redeclare
  Float64Vector row(int row) {
    RangeError.checkValidIndex(row, this, 'row', rowCount);
    return Float64Vector(_matrix.row(row));
  }

  /// Slices [col] index into a 1D [Float64Vector].
  @redeclare
  Float64Vector col(int col) {
    RangeError.checkValidIndex(col, this, 'col', colCount);
    return Float64Vector(_matrix.col(col));
  }

  /// Returns a zero-copy submatrix view as [Float64Matrix].
  @redeclare
  Float64Matrix subMatrix({
    int rowStart = 0,
    int? rowEnd,
    int colStart = 0,
    int? colEnd,
  }) => Float64Matrix._(
    _matrix.subMatrix(
      rowStart: rowStart,
      rowEnd: rowEnd,
      colStart: colStart,
      colEnd: colEnd,
    ),
  );

  /// Returns a zero-copy transposed view as [Float64Matrix].
  @redeclare
  Float64Matrix get transposed => Float64Matrix._(_matrix.transposed);

  /// Returns a zero-copy 1D view of the main diagonal.
  @redeclare
  Float64Vector diagonal() => Float64Vector(_matrix.diagonal());

  /// Computes the determinant of this matrix.
  double get det => _matrix.det;

  /// Computes the multiplicative inverse of this square, non-singular matrix.
  Float64Matrix get inverse => Float64Matrix._(_matrix.inverse);

  /// High-performance matrix multiplication routing directly to BLAS `dgemm`.
  @redeclare
  Float64Matrix operator *(Matrix<double> other) {
    if (colCount != other.rowCount) {
      throw ArgumentError(
        'Matrix dimension mismatch for multiplication: ($rowCount x $colCount) * (${other.rowCount} x ${other.colCount})',
      );
    }
    final m = rowCount;
    final n = other.colCount;
    final k = colCount;
    final tA = _matrix.tensor;
    final tB = other.tensor;

    if (tA.isContiguous &&
        tB.isContiguous &&
        tA.offset == 0 &&
        tB.offset == 0) {
      final out = Float64List(m * n);
      final bData = tB.data is Float64List
          ? tB.data as Float64List
          : Float64List.fromList(tB.data);
      final success = Blas.dgemm(
        m: m,
        n: n,
        k: k,
        alpha: 1.0,
        a: asTypedList,
        lda: k,
        b: bData,
        ldb: n,
        beta: 0.0,
        c: out,
        ldc: n,
      );
      if (success) {
        return Float64Matrix._(
          Matrix(
            Tensor.internal(
              type: DataType.float64,
              layout: Layout(shape: [m, n]),
              data: out,
            ),
          ),
        );
      }
    }
    return Float64Matrix._(_matrix * other);
  }

  /// High-performance matrix-vector multiplication routing directly to BLAS
  /// `dgemv`.
  @redeclare
  Float64Vector apply(Vector<double> x) {
    if (colCount != x.length) {
      throw ArgumentError(
        'Dimension mismatch for matrix-vector multiplication: ($rowCount x $colCount) * (${x.length})',
      );
    }
    final m = rowCount;
    final n = colCount;
    final tA = _matrix.tensor;
    final tX = x.tensor;

    if (tA.isContiguous &&
        tX.isContiguous &&
        tA.offset == 0 &&
        tX.offset == 0) {
      final out = Float64List(m);
      final xData = tX.data is Float64List
          ? tX.data as Float64List
          : Float64List.fromList(tX.data);
      final success = Blas.dgemv(
        m: m,
        n: n,
        alpha: 1.0,
        a: asTypedList,
        lda: n,
        x: xData,
        incX: 1,
        beta: 0.0,
        y: out,
        incY: 1,
      );
      if (success) {
        return Float64Vector(
          Vector(
            Tensor.internal(
              type: DataType.float64,
              layout: Layout(shape: [m]),
              data: out,
            ),
          ),
        );
      }
    }
    return Float64Vector(_matrix.apply(x));
  }

  /// Inlined matrix scaling.
  @redeclare
  Float64Matrix scale(double scalar) {
    final t = _matrix.tensor;
    final len = rowCount * colCount;
    if (t.isContiguous && t.offset == 0) {
      final out = Float64List(len);
      final data = asTypedList;
      for (var i = 0; i < len; i++) {
        out[i] = data[i] * scalar;
      }
      return Float64Matrix._(
        Matrix(
          Tensor.internal(
            type: DataType.float64,
            layout: Layout(shape: [rowCount, colCount]),
            data: out,
          ),
        ),
      );
    }
    return Float64Matrix._(_matrix.scale(scalar));
  }

  /// Inlined matrix addition.
  @redeclare
  Float64Matrix operator +(Matrix<double> other) {
    if (rowCount != other.rowCount || colCount != other.colCount) {
      throw ArgumentError(
        'Matrix shape mismatch: ($rowCount x $colCount) vs (${other.rowCount} x ${other.colCount})',
      );
    }
    final tA = _matrix.tensor;
    final tB = other.tensor;
    final len = rowCount * colCount;
    if (tA.isContiguous &&
        tB.isContiguous &&
        tA.offset == 0 &&
        tB.offset == 0) {
      final out = Float64List(len);
      final a = asTypedList;
      final b = tB.data is Float64List
          ? tB.data as Float64List
          : Float64List.fromList(tB.data);
      for (var i = 0; i < len; i++) {
        out[i] = a[i] + b[i];
      }
      return Float64Matrix._(
        Matrix(
          Tensor.internal(
            type: DataType.float64,
            layout: Layout(shape: [rowCount, colCount]),
            data: out,
          ),
        ),
      );
    }
    return Float64Matrix._(_matrix + other);
  }

  /// Inlined matrix subtraction.
  @redeclare
  Float64Matrix operator -(Matrix<double> other) {
    if (rowCount != other.rowCount || colCount != other.colCount) {
      throw ArgumentError(
        'Matrix shape mismatch: ($rowCount x $colCount) vs (${other.rowCount} x ${other.colCount})',
      );
    }
    final tA = _matrix.tensor;
    final tB = other.tensor;
    final len = rowCount * colCount;
    if (tA.isContiguous &&
        tB.isContiguous &&
        tA.offset == 0 &&
        tB.offset == 0) {
      final out = Float64List(len);
      final a = asTypedList;
      final b = tB.data is Float64List
          ? tB.data as Float64List
          : Float64List.fromList(tB.data);
      for (var i = 0; i < len; i++) {
        out[i] = a[i] - b[i];
      }
      return Float64Matrix._(
        Matrix(
          Tensor.internal(
            type: DataType.float64,
            layout: Layout(shape: [rowCount, colCount]),
            data: out,
          ),
        ),
      );
    }
    return Float64Matrix._(_matrix - other);
  }

  /// Inlined matrix negation.
  @redeclare
  Float64Matrix operator -() {
    final t = _matrix.tensor;
    final len = rowCount * colCount;
    if (t.isContiguous && t.offset == 0) {
      final out = Float64List(len);
      final a = asTypedList;
      for (var i = 0; i < len; i++) {
        out[i] = -a[i];
      }
      return Float64Matrix._(
        Matrix(
          Tensor.internal(
            type: DataType.float64,
            layout: Layout(shape: [rowCount, colCount]),
            data: out,
          ),
        ),
      );
    }
    return Float64Matrix._(-_matrix);
  }
}
