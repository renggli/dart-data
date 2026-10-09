import 'dart:typed_data';

import '../hardware/cblas.dart';
import '../hardware/hardware.dart';
import '../tensor/layout.dart';
import '../tensor/operations/matmul.dart';
import '../tensor/operations/operation.dart';
import '../tensor/tensor.dart';
import '../type/data_type.dart';
import 'decomposition/cholesky.dart';
import 'decomposition/eigenvalue.dart';
import 'decomposition/lu.dart';
import 'decomposition/qr.dart';
import 'decomposition/svd.dart';
import 'operator.dart';
import 'solvers/gmres.dart';
import 'vector.dart';

/// 2-dimensional mathematical matrix backed by a rank-2 [Tensor].
class Matrix<T> implements LinearOperator<T> {
  new(this.tensor)
    : assert(tensor.rank == 2, 'Tensor must have rank 2, got ${tensor.rank}');

  /// Constructs an [rowCount x colCount] matrix backed by off-heap native memory.
  factory native(int rowCount, int colCount, {DataType<T>? type}) =>
      Matrix(Tensor<T>.native(shape: [rowCount, colCount], type: type));

  /// Constructs an [rowCount x colCount] matrix filled with [value].
  factory filled(int rowCount, int colCount, T value, {DataType<T>? type}) {
    final effectiveType = type ?? DataType.fromInstance(value);
    final tensor = Tensor<T>.filled(
      value,
      shape: [rowCount, colCount],
      type: effectiveType,
    );
    return Matrix(tensor);
  }

  /// Constructs an [rowCount x colCount] matrix using [generator].
  factory generate(
    int rowCount,
    int colCount,
    T Function(int r, int c) generator, {
    DataType<T>? type,
  }) {
    final effectiveType = type ?? DataType.fromType<T>();
    final tensor = Tensor<T>.generate(
      (key) => generator(key[0], key[1]),
      shape: [rowCount, colCount],
      type: effectiveType,
    );
    return Matrix(tensor);
  }

  /// Constructs an identity matrix of dimension [size x size].
  factory identity(int size, {DataType<T>? type}) {
    final effectiveType = type ?? DataType.fromType<T>();
    final f = effectiveType.field;
    final one = f.multiplicativeIdentity;
    final zero = f.additiveIdentity;
    return Matrix.generate(
      size,
      size,
      (r, c) => r == c ? one : zero,
      type: effectiveType,
    );
  }

  /// Constructs a matrix from row vectors or row iterables.
  factory fromRows(Iterable<Iterable<T>> rows, {DataType<T>? type}) {
    final rowList = rows
        .map((r) => r.toList(growable: false))
        .toList(growable: false);
    if (rowList.isEmpty) {
      final t = type ?? DataType.fromType<T>();
      return Matrix(Tensor.filled(t.defaultValue, shape: [0, 0], type: t));
    }
    final rCount = rowList.length;
    final cCount = rowList.first.length;
    final t = type ?? DataType.fromIterable(rowList.first);
    final flat = <T>[];
    for (final row in rowList) {
      if (row.length != cCount) {
        throw ArgumentError(
          'All rows must have identical length ($cCount), got ${row.length}',
        );
      }
      flat.addAll(row);
    }
    return Matrix(Tensor.fromIterable(flat, shape: [rCount, cCount], type: t));
  }

  /// Constructs a matrix from column vectors or column iterables.
  factory fromColumns(Iterable<Iterable<T>> cols, {DataType<T>? type}) {
    final colList = cols
        .map((c) => c.toList(growable: false))
        .toList(growable: false);
    if (colList.isEmpty) {
      final t = type ?? DataType.fromType<T>();
      return Matrix(Tensor.filled(t.defaultValue, shape: [0, 0], type: t));
    }
    final cCount = colList.length;
    final rCount = colList.first.length;
    final t = type ?? DataType.fromIterable(colList.first);
    final flat = <T>[];
    for (var r = 0; r < rCount; r++) {
      for (var c = 0; c < cCount; c++) {
        if (colList[c].length != rCount) {
          throw ArgumentError(
            'All columns must have identical length ($rCount)',
          );
        }
        flat.add(colList[c][r]);
      }
    }
    return Matrix(Tensor.fromIterable(flat, shape: [rCount, cCount], type: t));
  }

  /// Constructs a diagonal matrix from [diagonal] vector.
  factory diagonal(Vector<T> diagonal) {
    final n = diagonal.length;
    final t = diagonal.type;
    final zero = t.field.additiveIdentity;
    return Matrix.generate(
      n,
      n,
      (r, c) => r == c ? diagonal[r] : zero,
      type: t,
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

  /// Gets the element at [row, col].
  T get(int row, int col) => tensor.getValue([row, col]);

  /// Sets the element at [row, col] to [value].
  void set(int row, int col, T value) => tensor.setValue([row, col], value);

  /// Slices the [row] index into a 1D [Vector].
  Vector<T> row(int row) => Vector(tensor[row]);

  /// Slices the [col] index into a 1D [Vector].
  Vector<T> col(int col) => Vector(tensor.transpose([1, 0])[col]);

  /// Returns a zero-copy transposed view of this matrix.
  Matrix<T> transpose() => Matrix(tensor.transpose([1, 0]));

  /// Returns a zero-copy transposed view of this matrix.
  Matrix<T> get transposed => transpose();

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

  /// Trace (sum of main diagonal elements) of this square matrix.
  T get trace {
    if (rowCount != colCount) {
      throw StateError(
        'Trace is only defined for square matrices, got $rowCount x $colCount',
      );
    }
    return diagonal().sum;
  }

  /// Computes the Cholesky decomposition of this symmetric positive-definite matrix.
  CholeskyDecomposition get cholesky =>
      CholeskyDecomposition(this as Matrix<num>);

  /// Computes the LU decomposition of this matrix.
  LUDecomposition get lu => LUDecomposition(this as Matrix<num>);

  /// Computes the QR decomposition of this matrix.
  QRDecomposition get qr => QRDecomposition(this as Matrix<num>);

  /// Computes the Singular Value Decomposition (SVD) of this matrix.
  SingularValueDecomposition get svd =>
      SingularValueDecomposition(this as Matrix<num>);

  /// Computes the Eigenvalue decomposition of this square matrix.
  EigenvalueDecomposition get eigenvalue =>
      EigenvalueDecomposition(this as Matrix<num>);

  /// Tests if this matrix is square ($M = N$).
  bool get isSquare => rowCount == colCount;

  /// Tests if this matrix is symmetric ($A = A^T$).
  bool get isSymmetric {
    if (!isSquare) return false;
    final eq = type.equality;
    for (var r = 1; r < rowCount; r++) {
      for (var c = 0; c < r; c++) {
        if (!eq.isEqual(get(r, c), get(c, r))) {
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
    for (var r = 0; r < rowCount; r++) {
      for (var c = 0; c < colCount; c++) {
        if (r != c && !eq.isEqual(get(r, c), zero)) {
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
    for (var r = 0; r < rowCount; r++) {
      for (var c = r + 1; c < colCount; c++) {
        if (!eq.isEqual(get(r, c), zero)) {
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
    for (var r = 1; r < rowCount; r++) {
      for (var c = 0; c < colCount && c < r; c++) {
        if (!eq.isEqual(get(r, c), zero)) {
          return false;
        }
      }
    }
    return true;
  }

  /// Returns column [col] as a 1D [Vector] (alias for [col]).
  Vector<T> column(int col) => this.col(col);

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
      (r, c) => c < colCount ? get(r, c) : other.get(r, c - colCount),
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
      (r, c) => r < rowCount ? get(r, c) : other.get(r - rowCount, c),
      type: type,
    );
  }

  /// Solves the linear system A * x = b.
  Vector<T> solve(Vector<T> b) {
    if (rowCount != colCount) {
      throw StateError(
        'Matrix must be square to solve, got $rowCount x $colCount',
      );
    }
    if (rowCount != b.length) {
      throw ArgumentError(
        'Dimension mismatch: Matrix $rowCount x $colCount, Vector ${b.length}',
      );
    }
    if (T == double) {
      final aData = Float64List.fromList(tensor.copy().data as List<double>);
      final bData = Float64List.fromList(b.copy().tensor.data as List<double>);
      final success = HardwareManager.dgesv(
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
            layout: Layout(shape: [rowCount]),
            data: bData as List<T>,
          ),
        );
      }
    }
    return gmres(this, b);
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
    final f = type.field;
    return Matrix(tensor.unaryOperation((v) => f.mul(v, scalar)));
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
    final f = type.field;
    final result = Matrix<T>.filled(
      rowCount,
      other.colCount,
      f.additiveIdentity,
      type: type,
    );
    final eJ = Vector<T>.filled(other.colCount, f.additiveIdentity, type: type);
    for (var j = 0; j < other.colCount; j++) {
      if (j > 0) eJ[j - 1] = f.additiveIdentity;
      eJ[j] = f.multiplicativeIdentity;
      final colJ = other.apply(eJ);
      final outColJ = apply(colJ);
      for (var i = 0; i < rowCount; i++) {
        result.set(i, j, outColJ[i]);
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
    final f = type.field;
    final res = Vector<T>.filled(rowCount, f.additiveIdentity, type: type);

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
        if (tensor.data is Float64List &&
            x.tensor.data is Float64List &&
            res.tensor.data is Float64List) {
          final success = HardwareManager.dgemv(
            transA: transA,
            m: mVal!,
            n: nVal!,
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
          if (success) return res;
        } else if (tensor.data is Float32List &&
            x.tensor.data is Float32List &&
            res.tensor.data is Float32List) {
          final success = HardwareManager.sgemv(
            transA: transA,
            m: mVal!,
            n: nVal!,
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
          if (success) return res;
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
        var sum = f.additiveIdentity;
        for (var j = 0; j < colCount; j++) {
          sum = f.add(sum, f.mul(mData[mOffset + j], xData[xOffset + j]));
        }
        res[i] = sum;
        mOffset += colCount;
      }
    } else {
      for (var i = 0; i < rowCount; i++) {
        var sum = f.additiveIdentity;
        for (var j = 0; j < colCount; j++) {
          sum = f.add(sum, f.mul(get(i, j), x[j]));
        }
        res[i] = sum;
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
    final f = type.field;
    final res = Vector<T>.filled(colCount, f.additiveIdentity, type: type);

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
        if (tensor.data is Float64List &&
            x.tensor.data is Float64List &&
            res.tensor.data is Float64List) {
          final success = HardwareManager.dgemv(
            transA: transA,
            m: mVal!,
            n: nVal!,
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
          if (success) return res;
        } else if (tensor.data is Float32List &&
            x.tensor.data is Float32List &&
            res.tensor.data is Float32List) {
          final success = HardwareManager.sgemv(
            transA: transA,
            m: mVal!,
            n: nVal!,
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
          if (success) return res;
        }
      }
    }

    for (var i = 0; i < rowCount; i++) {
      final xi = x[i];
      for (var j = 0; j < colCount; j++) {
        res[j] = f.add(res[j], f.mul(f.conjugate(get(i, j)), xi));
      }
    }
    return res;
  }

  /// Computes symmetric rank-k update $C = \alpha A A^T + \beta C$ (or $A^T A$).
  Matrix<T> syrk({
    double alpha = 1.0,
    double beta = 0.0,
    bool transpose = false,
  }) {
    final n = transpose ? colCount : rowCount;
    final k = transpose ? rowCount : colCount;
    final f = type.field;
    final result = Matrix<T>.filled(n, n, f.additiveIdentity, type: type);
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
          final success = HardwareManager.dsyrk(
            uplo: cblasUpper,
            trans: effectiveTrans,
            n: n,
            k: k,
            alpha: alpha,
            a: tensor.data as Float64List,
            aOffset: tensor.offset,
            lda: lda,
            beta: beta,
            c: result.tensor.data as Float64List,
            cOffset: result.tensor.offset,
            ldc: n,
          );
          if (success) return result;
        } else if (tensor.data is Float32List &&
            result.tensor.data is Float32List) {
          final success = HardwareManager.ssyrk(
            uplo: cblasUpper,
            trans: effectiveTrans,
            n: n,
            k: k,
            alpha: alpha,
            a: tensor.data as Float32List,
            aOffset: tensor.offset,
            lda: lda,
            beta: beta,
            c: result.tensor.data as Float32List,
            cOffset: result.tensor.offset,
            ldc: n,
          );
          if (success) return result;
        }
      }
    }
    final aOp = transpose ? this.transpose() : this;
    final aOther = transpose ? this : this.transpose();
    return (aOp * aOther).scale(f.scale(f.multiplicativeIdentity, alpha));
  }

  /// Creates a deep contiguous copy of this matrix.
  Matrix<T> copy() => Matrix(tensor.copy());

  /// Converts this matrix into nested rows.
  List<List<T>> toNestedList() => List<List<T>>.generate(
    rowCount,
    (r) => List<T>.generate(colCount, (c) => get(r, c)),
  );

  @override
  String toString() => 'Matrix($rowCount x $colCount, ${toNestedList()})';
}
