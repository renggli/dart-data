import 'dart:typed_data';

import '../../type.dart';
import '../acceleration/acceleration_manager.dart';
import '../acceleration/blas/cblas.dart';
import '../tensor/layout.dart';
import '../tensor/operations/matmul.dart';
import '../tensor/operations/operation.dart';
import '../tensor/tensor.dart';
import 'decomposition/lu.dart';
import 'decomposition/qr.dart';
import 'operator.dart';
import 'vector.dart';

/// 2-dimensional mathematical matrix backed by a rank-2 [Tensor].
///
/// Conceptually, a matrix is a rectangular grid or table of numbers organized
/// into rows and columns. Mathematically, a matrix represents a linear
/// transformation between finite-dimensional vector spaces $T^n \to T^m$ with
/// components in $T$.
///
/// ```dart
/// final m = Matrix<double>.filled(2, 3, 0.0);
/// final rows = m.rowCount; // 2
/// final cols = m.colCount; // 3
/// ```
class Matrix<T> implements LinearOperator<T> {
  /// Creates a [Matrix] wrapping a 2-dimensional [tensor].
  ///
  /// ```dart
  /// final t = Tensor<int>.filled(0, shape: [2, 3]);
  /// final m = Matrix<int>(t);
  /// ```
  new(this.tensor)
    : assert(tensor.rank == 2, 'Tensor must have rank 2, got ${tensor.rank}');

  /// Constructs a [rowCount] by [colCount] [Matrix] filled with [value].
  factory filled(int rowCount, int colCount, T value, {DataType<T>? type}) {
    final effectiveType = type ?? DataType.fromInstance(value);
    final tensor = Tensor<T>.filled(
      value,
      shape: [rowCount, colCount],
      type: effectiveType,
    );
    return Matrix(tensor);
  }

  /// Constructs a [rowCount] by [colCount] [Matrix] using [generator].
  factory generate(
    int rowCount,
    int colCount,
    T Function(int row, int col) generator, {
    DataType<T>? type,
  }) {
    final effectiveType = type ?? DataType.fromType<T>();
    final data = effectiveType.newList(rowCount * colCount);
    var index = 0;
    for (var r = 0; r < rowCount; r++) {
      for (var c = 0; c < colCount; c++) {
        data[index++] = generator(r, c);
      }
    }
    return Matrix(
      Tensor.internal(
        type: effectiveType,
        layout: Layout(shape: [rowCount, colCount]),
        data: data,
      ),
    );
  }

  /// Constructs an identity [Matrix] of dimension [size] by [size].
  factory identity(int size, {DataType<T>? type}) {
    final effectiveType = type ?? DataType.fromType<T>();
    final field = effectiveType.field;
    final one = field.multiplicativeIdentity;
    final zero = field.additiveIdentity;
    return Matrix.generate(
      size,
      size,
      (row, col) => row == col ? one : zero,
      type: effectiveType,
    );
  }

  /// Constructs a [Matrix] from row vectors or row iterables.
  factory fromRows(Iterable<Iterable<T>> rows, {DataType<T>? type}) {
    final rowList = rows
        .map((row) => row.toList(growable: false))
        .toList(growable: false);
    if (rowList.isEmpty) {
      final dataType = type ?? DataType.fromType<T>();
      return Matrix(
        Tensor.filled(dataType.defaultValue, shape: [0, 0], type: dataType),
      );
    }
    final rCount = rowList.length;
    final cCount = rowList.first.length;
    final dataType =
        type ??
        (rowList.first.isEmpty
            ? DataType.fromType<T>()
            : DataType.fromIterable(rowList.first));
    final data = dataType.newList(rCount * cCount);
    var index = 0;
    for (final row in rowList) {
      if (row.length != cCount) {
        throw ArgumentError(
          'All rows must have identical length ($cCount), got ${row.length}',
        );
      }
      for (var col = 0; col < cCount; col++) {
        data[index++] = row[col];
      }
    }
    return Matrix(
      Tensor.internal(
        type: dataType,
        layout: Layout(shape: [rCount, cCount]),
        data: data,
      ),
    );
  }

  /// Constructs a [Matrix] from column vectors or column iterables.
  factory fromColumns(Iterable<Iterable<T>> cols, {DataType<T>? type}) {
    final colList = cols
        .map((col) => col.toList(growable: false))
        .toList(growable: false);
    if (colList.isEmpty) {
      final dataType = type ?? DataType.fromType<T>();
      return Matrix(
        Tensor.filled(dataType.defaultValue, shape: [0, 0], type: dataType),
      );
    }
    final cCount = colList.length;
    final rCount = colList.first.length;
    for (final col in colList) {
      if (col.length != rCount) {
        throw ArgumentError('All columns must have identical length ($rCount)');
      }
    }
    final dataType =
        type ??
        (colList.first.isEmpty
            ? DataType.fromType<T>()
            : DataType.fromIterable(colList.first));
    final data = dataType.newList(rCount * cCount);
    var index = 0;
    for (var row = 0; row < rCount; row++) {
      for (var col = 0; col < cCount; col++) {
        data[index++] = colList[col][row];
      }
    }
    return Matrix(
      Tensor.internal(
        type: dataType,
        layout: Layout(shape: [rCount, cCount]),
        data: data,
      ),
    );
  }

  /// Constructs a diagonal [Matrix] from [diagonal] vector.
  factory diagonal(Vector<T> diagonal) {
    final dim = diagonal.length;
    final dataType = diagonal.type;
    final zero = dataType.field.additiveIdentity;
    return Matrix.generate(
      dim,
      dim,
      (row, col) => row == col ? diagonal[row] : zero,
      type: dataType,
    );
  }

  /// The underlying 2D tensor.
  final Tensor<T> tensor;

  @override
  int get rowCount => tensor.shape[0];

  @override
  int get colCount => tensor.shape[1];

  @override
  DataType<T> get type => tensor.type;

  /// Returns an iterable over the elements in row-major traversal order.
  Iterable<T> get values => tensor.values;

  /// Gets the element at [row] and [col] without bounds checks.
  @pragma('vm:prefer-inline')
  T getUnchecked(int row, int col) => tensor.get2D(row, col);

  /// Sets the element at [row] and [col] to [value] without bounds checks.
  @pragma('vm:prefer-inline')
  void setUnchecked(int row, int col, T value) => tensor.set2D(row, col, value);

  /// Gets the element at [row] and [col].
  T get(int row, int col) {
    RangeError.checkValidIndex(row, this, 'row', rowCount);
    RangeError.checkValidIndex(col, this, 'col', colCount);
    return getUnchecked(row, col);
  }

  /// Sets the element at [row] and [col] to [value].
  void set(int row, int col, T value) {
    RangeError.checkValidIndex(row, this, 'row', rowCount);
    RangeError.checkValidIndex(col, this, 'col', colCount);
    setUnchecked(row, col, value);
  }

  /// Returns a mutable [Vector] view of the given [row].
  ///
  /// This enables natural 2D indexing syntax `matrix[r][c]`:
  /// ```dart
  /// final val = matrix[row][col];
  /// matrix[row][col] = 42.0;
  /// ```
  @pragma('vm:prefer-inline')
  Vector<T> operator [](int row) {
    RangeError.checkValidIndex(row, this, 'row', rowCount);
    return this.row(row);
  }

  /// Sets the element at [pos] `(row, col)` to [value].
  @pragma('vm:prefer-inline')
  void operator []=((int row, int col) pos, T value) {
    final (row, col) = pos;
    set(row, col, value);
  }

  /// Slices the [row] index into a 1D [Vector].
  Vector<T> row(int row) => Vector(tensor[row]);

  /// Slices the [col] index into a 1D [Vector].
  Vector<T> col(int col) => Vector(tensor.transpose([1, 0])[col]);

  /// Returns a zero-copy transposed view of this matrix.
  Matrix<T> transpose() => Matrix(tensor.transpose([1, 0]));

  /// Returns a zero-copy transposed view of this matrix.
  Matrix<T> get transposed => transpose();

  /// Returns the conjugate transpose (Hermitian adjoint $A^* = (\bar{A})^T$) of
  /// this matrix.
  Matrix<T> get conjugateTranspose {
    final field = type.field;
    return Matrix<T>.generate(
      colCount,
      rowCount,
      (r, c) => field.conjugate(getUnchecked(c, r)),
      type: type,
    );
  }

  /// Returns a zero-copy 1D view of the main diagonal.
  Vector<T> diagonal() {
    final minDim = rowCount < colCount ? rowCount : colCount;
    final diagStride = tensor.strides[0] + tensor.strides[1];
    final diagLayout = Layout(
      shape: [minDim],
      strides: [diagStride],
      offset: tensor.offset,
    );
    return Vector(
      Tensor.internal(type: type, layout: diagLayout, data: tensor.data),
    );
  }

  /// Returns the trace of this square matrix.
  ///
  /// The trace is defined as the sum of the main diagonal elements:
  ///
  /// $$\operatorname{tr}(A) = \sum_{i=1}^n A_{ii}$$
  ///
  /// Throws an [ArgumentError] if the matrix is not square.
  T get trace {
    if (rowCount != colCount) {
      throw ArgumentError(
        'Trace is only defined for square matrices, got $rowCount x $colCount.',
      );
    }
    final field = type.field;
    var sum = field.additiveIdentity;
    for (var i = 0; i < rowCount; i++) {
      sum = field.add(sum, getUnchecked(i, i));
    }
    return sum;
  }

  /// Tests if this matrix is square ($M = N$).
  bool get isSquare => rowCount == colCount;

  /// Tests if this matrix is symmetric ($A = A^T$).
  bool get isSymmetric {
    if (!isSquare) return false;
    final eq = type.equality;
    for (var row = 1; row < rowCount; row++) {
      for (var col = 0; col < row; col++) {
        if (!eq.isEqual(getUnchecked(row, col), getUnchecked(col, row))) {
          return false;
        }
      }
    }
    return true;
  }

  /// Tests if this matrix is a diagonal matrix ($a_{ij} = 0$ for $i \ne j$).
  bool get isDiagonal {
    final eq = type.equality;
    final zero = type.defaultValue;
    for (var row = 0; row < rowCount; row++) {
      for (var col = 0; col < colCount; col++) {
        if (row != col && !eq.isEqual(getUnchecked(row, col), zero)) {
          return false;
        }
      }
    }
    return true;
  }

  /// Tests if this matrix is lower triangular ($a_{ij} = 0$ for $j > i$).
  bool get isLowerTriangular {
    final eq = type.equality;
    final zero = type.defaultValue;
    for (var row = 0; row < rowCount; row++) {
      for (var col = row + 1; col < colCount; col++) {
        if (!eq.isEqual(getUnchecked(row, col), zero)) {
          return false;
        }
      }
    }
    return true;
  }

  /// Tests if this matrix is upper triangular ($a_{ij} = 0$ for $i > j$).
  bool get isUpperTriangular {
    final eq = type.equality;
    final zero = type.defaultValue;
    for (var row = 1; row < rowCount; row++) {
      for (var col = 0; col < colCount && col < row; col++) {
        if (!eq.isEqual(getUnchecked(row, col), zero)) {
          return false;
        }
      }
    }
    return true;
  }

  /// Horizontally flipped view of this matrix.
  Matrix<T> flippedHorizontal() => Matrix(tensor.flip(axis: 1));

  /// Vertically flipped view of this matrix.
  Matrix<T> flippedVertical() => Matrix(tensor.flip(axis: 0));

  /// Rotates this matrix clockwise by 90 degrees times [count].
  Matrix<T> rotated([int count = 1]) {
    final normalized = count % 4;
    return switch (normalized) {
      0 => this,
      1 => transpose().flippedHorizontal(),
      2 => flippedHorizontal().flippedVertical(),
      3 => transpose().flippedVertical(),
      _ => this,
    };
  }

  /// Concatenates [other] horizontally to the right of this matrix.
  Matrix<T> concatHorizontal(Matrix<T> other) {
    if (rowCount != other.rowCount) {
      throw ArgumentError(
        'Row counts must match to concatenate horizontally: $rowCount vs ${other.rowCount}.',
      );
    }
    return Matrix.generate(
      rowCount,
      colCount + other.colCount,
      (row, col) => col < colCount
          ? getUnchecked(row, col)
          : other.getUnchecked(row, col - colCount),
      type: type,
    );
  }

  /// Concatenates [other] vertically to the bottom of this matrix.
  Matrix<T> concatVertical(Matrix<T> other) {
    if (colCount != other.colCount) {
      throw ArgumentError(
        'Column counts must match to concatenate vertically: $colCount vs ${other.colCount}.',
      );
    }
    return Matrix.generate(
      rowCount + other.rowCount,
      colCount,
      (row, col) => row < rowCount
          ? getUnchecked(row, col)
          : other.getUnchecked(row - rowCount, col),
      type: type,
    );
  }

  /// Solves the linear system $A x = b$ or linear least-squares problem
  /// $A x \approx b$.
  ///
  /// Conceptually, this solves for the unknown vector or matrix that satisfies
  /// the system $A x = b$. If the system is overdetermined or underdetermined
  /// ($m \ne n$), it automatically finds the least-squares solution minimizing
  /// $\|A x - b\|_2$.
  ///
  /// Accepts either a [Vector] or a multi-column [Matrix] right-hand side:
  /// - When [b] is a [Vector], returns the solution [Vector] of length
  ///   [colCount].
  /// - When [b] is a [Matrix], returns the solution [Matrix] of shape
  ///   `[colCount, b.colCount]`.
  ///
  /// For square matrices ($m = n$), the system is solved via LU decomposition
  /// with partial pivoting (`dgesv` or pure-Dart LU). For rectangular matrices
  /// ($m \ne n$), the least-squares solution is computed via QR decomposition
  /// (`dgels` or pure-Dart QR).
  ///
  /// ```dart
  /// final a = Matrix<double>.fromRows([
  ///   [2.0, 1.0],
  ///   [1.0, 3.0],
  /// ]);
  /// final b = Vector<double>.fromList([4.0, 7.0]);
  /// final x = a.solve(b); // [1.0, 2.0]
  /// ```
  S solve<S extends Object>(S b) {
    if (b is Vector) {
      if (b.length != rowCount) {
        throw ArgumentError(
          'Dimension mismatch: Matrix $rowCount x $colCount, Vector ${b.length}',
        );
      }
      final bVec = b is Vector<T>
          ? b
          : Vector<T>.generate(b.length, (i) => type.cast(b[i]), type: type);
      if (rowCount == colCount) {
        if (T == double) {
          final aData = Float64List.fromList(
            tensor.copy().data as List<double>,
          );
          final bData = Float64List.fromList(
            bVec.copy().tensor.data as List<double>,
          );
          final success = AccelerationManager.dgesv(
            n: rowCount,
            nrhs: 1,
            a: aData,
            lda: colCount,
            b: bData,
            ldb: 1,
          );
          if (success) {
            return Vector<T>(
              Tensor.internal(
                type: type,
                layout: Layout(shape: [colCount]),
                data: bData as List<T>,
              ),
            ) as S;
          }
        }
        return LUDecomposition<T>(this).solveVector(bVec) as S;
      } else if (T == double || T == num || T == Complex) {
        if (rowCount > colCount) {
          return QRDecomposition<T>(this).solveVector(bVec) as S;
        }
        return _solveUnderdetermined(bVec) as S;
      } else {
        return _solveRref(bVec.toMatrix()).col(0).copy() as S;
      }
    } else if (b is Matrix) {
      if (b.rowCount != rowCount) {
        throw ArgumentError(
          'Dimension mismatch: Matrix $rowCount x $colCount, Matrix RHS ${b.rowCount} x ${b.colCount}',
        );
      }
      final bMat = b is Matrix<T>
          ? b
          : Matrix<T>.generate(
              b.rowCount,
              b.colCount,
              (r, c) => type.cast(b.get(r, c)),
              type: type,
            );
      if (rowCount == colCount) {
        if (T == double) {
          final aData = Float64List.fromList(
            tensor.copy().data as List<double>,
          );
          final bData = Float64List.fromList(
            bMat.copy().tensor.data as List<double>,
          );
          final success = AccelerationManager.dgesv(
            n: rowCount,
            nrhs: bMat.colCount,
            a: aData,
            lda: colCount,
            b: bData,
            ldb: bMat.colCount,
          );
          if (success) {
            return Matrix<T>(
              Tensor.internal(
                type: type,
                layout: Layout(shape: [colCount, bMat.colCount]),
                data: bData as List<T>,
              ),
            ) as S;
          }
        }
        return LUDecomposition<T>(this).solve(bMat) as S;
      } else if (T == double || T == num || T == Complex) {
        if (rowCount > colCount) {
          return QRDecomposition<T>(this).solve(bMat) as S;
        }
        return _solveUnderdetermined(bMat) as S;
      } else {
        return _solveRref(bMat) as S;
      }
    }
    throw ArgumentError.value(b, 'b', 'Expected Vector or Matrix');
  }

  Matrix<T> _solveRref(Matrix<T> b) {
    final field = type.field;
    final zero = field.additiveIdentity;
    final one = field.multiplicativeIdentity;
    final m = rowCount;
    final n = colCount;
    final k = b.colCount;
    final totalCols = n + k;
    final grid = [
      for (var r = 0; r < m; r++)
        [
          for (var c = 0; c < n; c++) getUnchecked(r, c),
          for (var c = 0; c < k; c++) b.getUnchecked(r, c),
        ],
    ];
    final pivotColumns = <int>[];
    var pivotRow = 0;

    for (var col = 0; col < totalCols && pivotRow < m; col++) {
      var found = -1;
      for (var r = pivotRow; r < m; r++) {
        if (field.add(grid[r][col], zero) != zero) {
          found = r;
          break;
        }
      }
      if (found == -1) continue;
      if (found != pivotRow) {
        final temp = grid[pivotRow];
        grid[pivotRow] = grid[found];
        grid[found] = temp;
      }
      pivotColumns.add(col);
      final pivot = grid[pivotRow][col];
      grid[pivotRow][col] = one;
      for (var c = col + 1; c < totalCols; c++) {
        grid[pivotRow][c] = field.div(grid[pivotRow][c], pivot);
      }
      for (var r = 0; r < m; r++) {
        if (r == pivotRow) continue;
        final factor = grid[r][col];
        if (field.add(factor, zero) == zero) {
          grid[r][col] = zero;
          continue;
        }
        grid[r][col] = zero;
        for (var c = col + 1; c < totalCols; c++) {
          grid[r][c] = field.sub(
            grid[r][c],
            field.mul(factor, grid[pivotRow][c]),
          );
        }
      }
      pivotRow++;
    }

    if (pivotColumns.any((p) => p >= n)) {
      throw StateError('Linear system is inconsistent.');
    }
    if (m >= n && pivotColumns.length < n) {
      throw StateError('Matrix is rank deficient.');
    }

    final result = Matrix<T>.filled(n, k, zero, type: type);
    for (var pIdx = 0; pIdx < pivotColumns.length; pIdx++) {
      final pCol = pivotColumns[pIdx];
      for (var c = 0; c < k; c++) {
        result.setUnchecked(pCol, c, grid[pIdx][n + c]);
      }
    }
    return result;
  }

  S _solveUnderdetermined<S extends Object>(S b) {
    final at = transposed;
    final qr = QRDecomposition<T>(at);
    if (!qr.isFullRank) {
      throw StateError('Matrix is rank deficient.');
    }
    final field = type.field;
    final rMat = qr.r;
    if (b is Vector<T>) {
      final y = Vector<T>.filled(rowCount, field.additiveIdentity, type: type);
      for (var i = 0; i < rowCount; i++) {
        var sum = b.getUnchecked(i);
        for (var k = 0; k < i; k++) {
          sum = field.sub(
            sum,
            field.mul(rMat.getUnchecked(k, i), y.getUnchecked(k)),
          );
        }
        y.setUnchecked(i, field.div(sum, rMat.getUnchecked(i, i)));
      }
      final qMat = qr.q;
      final x = Vector<T>.generate(colCount, (i) {
        var sum = field.additiveIdentity;
        for (var k = 0; k < rowCount; k++) {
          sum = field.add(
            sum,
            field.mul(qMat.getUnchecked(i, k), y.getUnchecked(k)),
          );
        }
        return sum;
      }, type: type);
      return x as S;
    } else if (b is Matrix<T>) {
      final nx = b.colCount;
      final y = Matrix<T>.generate(
        rowCount,
        nx,
        (r, c) => field.additiveIdentity,
        type: type,
      );
      for (var j = 0; j < nx; j++) {
        for (var i = 0; i < rowCount; i++) {
          var sum = b.getUnchecked(i, j);
          for (var k = 0; k < i; k++) {
            sum = field.sub(
              sum,
              field.mul(rMat.getUnchecked(k, i), y.getUnchecked(k, j)),
            );
          }
          y.setUnchecked(i, j, field.div(sum, rMat.getUnchecked(i, i)));
        }
      }
      final qMat = qr.q;
      final x = Matrix<T>.generate(colCount, nx, (i, j) {
        var sum = field.additiveIdentity;
        for (var k = 0; k < rowCount; k++) {
          sum = field.add(
            sum,
            field.mul(qMat.getUnchecked(i, k), y.getUnchecked(k, j)),
          );
        }
        return sum;
      }, type: type);
      return x as S;
    }
    throw ArgumentError.value(b, 'b', 'Expected Vector or Matrix');
  }

  /// Slices a submatrix over the given row and column ranges.
  Matrix<T> subMatrix({
    required int rowStart,
    int? rowEnd,
    required int colStart,
    int? colEnd,
  }) {
    final rEnd = rowEnd ?? rowCount;
    final cEnd = colEnd ?? colCount;
    final rowSlice = tensor.layout.getRange(
      axis: 0,
      start: rowStart,
      end: rEnd,
    );
    final subLayout = rowSlice.getRange(axis: 1, start: colStart, end: cEnd);
    return Matrix(
      Tensor.internal(type: type, layout: subLayout, data: tensor.data),
    );
  }

  /// Element-wise matrix addition.
  Matrix<T> operator +(Matrix<T> other) => Matrix(tensor + other.tensor);

  /// Element-wise matrix subtraction.
  Matrix<T> operator -(Matrix<T> other) => Matrix(tensor - other.tensor);

  /// Unary matrix negation.
  Matrix<T> operator -() => Matrix(-tensor);

  /// Scales every element by [scalar].
  Matrix<T> scale(T scalar) {
    final field = type.field;
    return Matrix(
      tensor.unaryOperation((val) => field.mul(val, scalar), type: type),
    );
  }

  /// Element-wise Hadamard product.
  Matrix<T> hadamard(Matrix<T> other) => Matrix(tensor * other.tensor);

  /// Computes matrix multiplication (or operator composition) A * B.
  Matrix<T> operator *(Matrix<T> other) => matmul(other) as Matrix<T>;

  @override
  LinearOperator<T> matmul(LinearOperator<T> other) {
    if (colCount != other.rowCount) {
      throw ArgumentError(
        'Dimension mismatch: Matrix ($rowCount x $colCount) * Operator (${other.rowCount} x ${other.colCount})',
      );
    }
    if (other is Matrix<T>) {
      return Matrix(tensor.matmul(other.tensor));
    }
    // Generic column-by-column composition
    final field = type.field;
    final result = Matrix<T>.filled(
      rowCount,
      other.colCount,
      field.additiveIdentity,
      type: type,
    );
    final eJ = Vector<T>.filled(
      other.colCount,
      field.additiveIdentity,
      type: type,
    );
    for (var j = 0; j < other.colCount; j++) {
      if (j > 0) eJ[j - 1] = field.additiveIdentity;
      eJ[j] = field.multiplicativeIdentity;
      final colJ = other.apply(eJ);
      final outColJ = apply(colJ);
      for (var i = 0; i < rowCount; i++) {
        result.setUnchecked(i, j, outColJ.getUnchecked(i));
      }
    }
    return result;
  }

  @override
  Vector<T> apply(Vector<T> x) {
    if (colCount != x.length) {
      throw ArgumentError(
        'Vector length (${x.length}) must match colCount ($colCount)',
      );
    }
    final field = type.field;
    final res = Vector<T>.filled(rowCount, field.additiveIdentity, type: type);

    // Fast-path: hardware-accelerated DGEMV / SGEMV
    if (T == double && x.tensor.strides[0] > 0 && res.tensor.strides[0] > 0) {
      final s0 = tensor.strides[0];
      final s1 = tensor.strides[1];
      int? transA;
      int? mVal;
      int? nVal;
      int? lda;
      if (s1 == 1 && (s0 >= colCount || rowCount == 1)) {
        transA = cblasNoTrans;
        mVal = rowCount;
        nVal = colCount;
        lda = rowCount == 1 ? (colCount > 0 ? colCount : 1) : s0;
      } else if (s0 == 1 && (s1 >= rowCount || colCount == 1)) {
        transA = cblasTrans;
        mVal = colCount;
        nVal = rowCount;
        lda = colCount == 1 ? (rowCount > 0 ? rowCount : 1) : s1;
      }

      if (transA != null && lda != null) {
        if (_tryAcceleratedGemv(
          transA: transA,
          m: mVal!,
          n: nVal!,
          lda: lda,
          x: x,
          res: res,
        )) {
          return res;
        }
      }
    }

    final xContig = x.tensor.isContiguous;
    final xData = x.tensor.data;
    final xOffset = x.tensor.offset;

    if (tensor.isContiguous && xContig) {
      final mData = tensor.data;
      var mOffset = tensor.offset;
      for (var i = 0; i < rowCount; i++) {
        var sum = field.additiveIdentity;
        for (var j = 0; j < colCount; j++) {
          sum = field.add(
            sum,
            field.mul(mData[mOffset + j], xData[xOffset + j]),
          );
        }
        res[i] = sum;
        mOffset += colCount;
      }
    } else {
      for (var i = 0; i < rowCount; i++) {
        var sum = field.additiveIdentity;
        for (var j = 0; j < colCount; j++) {
          sum = field.add(
            sum,
            field.mul(getUnchecked(i, j), x.getUnchecked(j)),
          );
        }
        res.setUnchecked(i, sum);
      }
    }
    return res;
  }

  @override
  Vector<T> applyTranspose(Vector<T> x) {
    if (rowCount != x.length) {
      throw ArgumentError(
        'Vector length (${x.length}) must match rowCount ($rowCount)',
      );
    }
    final field = type.field;
    final res = Vector<T>.filled(colCount, field.additiveIdentity, type: type);

    // Fast-path: hardware-accelerated DGEMV / SGEMV
    if (T == double && x.tensor.strides[0] > 0 && res.tensor.strides[0] > 0) {
      final s0 = tensor.strides[0];
      final s1 = tensor.strides[1];
      int? transA;
      int? mVal;
      int? nVal;
      int? lda;
      if (s1 == 1 && (s0 >= colCount || rowCount == 1)) {
        transA = cblasTrans;
        mVal = rowCount;
        nVal = colCount;
        lda = rowCount == 1 ? (colCount > 0 ? colCount : 1) : s0;
      } else if (s0 == 1 && (s1 >= rowCount || colCount == 1)) {
        transA = cblasNoTrans;
        mVal = colCount;
        nVal = rowCount;
        lda = colCount == 1 ? (rowCount > 0 ? rowCount : 1) : s1;
      }

      if (transA != null && lda != null) {
        if (_tryAcceleratedGemv(
          transA: transA,
          m: mVal!,
          n: nVal!,
          lda: lda,
          x: x,
          res: res,
        )) {
          return res;
        }
      }
    }

    for (var i = 0; i < rowCount; i++) {
      final xi = x.getUnchecked(i);
      for (var j = 0; j < colCount; j++) {
        res.setUnchecked(
          j,
          field.add(
            res.getUnchecked(j),
            field.mul(field.conjugate(getUnchecked(i, j)), xi),
          ),
        );
      }
    }
    return res;
  }

  /// Computes symmetric rank-k update $C = \alpha A A^T + \beta C$ (or
  /// $A^T A$).
  Matrix<T> syrk({
    double alpha = 1.0,
    double beta = 0.0,
    bool transpose = false,
  }) {
    final dim = transpose ? colCount : rowCount;
    final kDim = transpose ? rowCount : colCount;
    final field = type.field;
    final result = Matrix<T>.filled(
      dim,
      dim,
      field.additiveIdentity,
      type: type,
    );
    if (T == double) {
      final s0 = tensor.strides[0];
      final s1 = tensor.strides[1];
      int? effectiveTrans;
      int? lda;
      if (s1 == 1 && (s0 >= colCount || rowCount == 1)) {
        effectiveTrans = transpose ? cblasTrans : cblasNoTrans;
        lda = rowCount == 1 ? (colCount > 0 ? colCount : 1) : s0;
      } else if (s0 == 1 && (s1 >= rowCount || colCount == 1)) {
        effectiveTrans = transpose ? cblasNoTrans : cblasTrans;
        lda = colCount == 1 ? (rowCount > 0 ? rowCount : 1) : s1;
      }

      if (effectiveTrans != null && lda != null) {
        if (tensor.data is Float64List && result.tensor.data is Float64List) {
          final success = AccelerationManager.dsyrk(
            uplo: cblasUpper,
            trans: effectiveTrans,
            n: dim,
            k: kDim,
            alpha: alpha,
            a: tensor.data as Float64List,
            aOffset: tensor.offset,
            lda: lda,
            beta: beta,
            c: result.tensor.data as Float64List,
            cOffset: result.tensor.offset,
            ldc: dim,
          );
          if (success) return result;
        } else if (tensor.data is Float32List &&
            result.tensor.data is Float32List) {
          final success = AccelerationManager.ssyrk(
            uplo: cblasUpper,
            trans: effectiveTrans,
            n: dim,
            k: kDim,
            alpha: alpha,
            a: tensor.data as Float32List,
            aOffset: tensor.offset,
            lda: lda,
            beta: beta,
            c: result.tensor.data as Float32List,
            cOffset: result.tensor.offset,
            ldc: dim,
          );
          if (success) return result;
        }
      }
    }
    final aOp = transpose ? this.transpose() : this;
    final aOther = transpose ? this : this.transpose();
    return (aOp * aOther).scale(
      field.scale(field.multiplicativeIdentity, alpha),
    );
  }

  /// Creates a deep contiguous copy of this matrix.
  Matrix<T> copy() => Matrix(tensor.copy());

  /// Converts this matrix into nested rows.
  List<List<T>> toNestedList() => List<List<T>>.generate(
    rowCount,
    (row) => List<T>.generate(colCount, (col) => getUnchecked(row, col)),
  );

  @override
  String toString() => 'Matrix($rowCount x $colCount, ${toNestedList()})';

  bool _tryAcceleratedGemv({
    required int transA,
    required int m,
    required int n,
    required int lda,
    required Vector<T> x,
    required Vector<T> res,
  }) {
    if (tensor.data is Float64List &&
        x.tensor.data is Float64List &&
        res.tensor.data is Float64List) {
      return AccelerationManager.dgemv(
        transA: transA,
        m: m,
        n: n,
        alpha: 1.0,
        a: tensor.data as Float64List,
        aOffset: tensor.offset,
        lda: lda,
        x: x.tensor.data as Float64List,
        xOffset: x.tensor.offset,
        incX: x.tensor.strides[0],
        beta: 0.0,
        y: res.tensor.data as Float64List,
        yOffset: res.tensor.offset,
        incY: res.tensor.strides[0],
      );
    } else if (tensor.data is Float32List &&
        x.tensor.data is Float32List &&
        res.tensor.data is Float32List) {
      return AccelerationManager.sgemv(
        transA: transA,
        m: m,
        n: n,
        alpha: 1.0,
        a: tensor.data as Float32List,
        aOffset: tensor.offset,
        lda: lda,
        x: x.tensor.data as Float32List,
        xOffset: x.tensor.offset,
        incX: x.tensor.strides[0],
        beta: 0.0,
        y: res.tensor.data as Float32List,
        yOffset: res.tensor.offset,
        incY: res.tensor.strides[0],
      );
    }
    return false;
  }
}
