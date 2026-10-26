import 'dart:typed_data';

import 'cblas_constants.dart';

/// Validates CBLAS transpose constant.
void checkBlasTrans(int trans, [String name = 'trans']) {
  if (trans != cblasNoTrans && trans != cblasTrans && trans != cblasConjTrans) {
    throw ArgumentError.value(trans, name, 'Invalid CBLAS transpose constant');
  }
}

/// Validates CBLAS uplo constant.
void checkBlasUplo(int uplo, [String name = 'uplo']) {
  if (uplo != cblasUpper && uplo != cblasLower) {
    throw ArgumentError.value(uplo, name, 'Invalid CBLAS uplo constant');
  }
}

/// Validates CBLAS diag constant.
void checkBlasDiag(int diag, [String name = 'diag']) {
  if (diag != cblasNonUnit && diag != cblasUnit) {
    throw ArgumentError.value(diag, name, 'Invalid CBLAS diag constant');
  }
}

/// Validates CBLAS side constant.
void checkBlasSide(int side, [String name = 'side']) {
  if (side != cblasLeft && side != cblasRight) {
    throw ArgumentError.value(side, name, 'Invalid CBLAS side constant');
  }
}

/// Validates vector stride.
void checkBlasInc(int inc, String name) {
  if (inc == 0) {
    throw ArgumentError.value(inc, name, 'Stride must not be 0');
  }
}

/// Validates buffer offset.
void checkBlasOffset(int offset, int bufferLength, String name) {
  if (offset < 0 || offset > bufferLength) {
    throw RangeError.range(
      offset,
      0,
      bufferLength,
      name,
      'Offset is out of bounds',
    );
  }
}

/// Validates that vector elements fit within the buffer length.
void checkBlasVectorBounds(
  int bufferLength,
  int n,
  int offset,
  int inc,
  String name,
) {
  checkBlasOffset(offset, bufferLength, name);
  if (n <= 0) return;
  final maxIdx = offset + (n - 1) * inc.abs();
  if (maxIdx >= bufferLength) {
    throw RangeError(
      'Vector $name bounds check failed: indices [$offset, $maxIdx] exceed buffer length $bufferLength',
    );
  }
}

/// Validates leading dimension for row-major layout.
void checkBlasMatrixLeadingDim(int ld, String name, int minCols) {
  final minAllowed = minCols > 1 ? minCols : 1;
  if (ld < minAllowed) {
    throw ArgumentError.value(
      ld,
      name,
      'Leading dimension must be >= max(1, $minCols) ($minAllowed)',
    );
  }
}

/// Validates that 2D matrix elements fit within the buffer length for row-major layout.
void checkBlasMatrixBounds(
  int bufferLength,
  int rows,
  int cols,
  int offset,
  int ld,
  String name,
) {
  checkBlasOffset(offset, bufferLength, name);
  if (rows <= 0 || cols <= 0) return;
  final requiredLength = offset + (rows - 1) * ld + cols;
  if (requiredLength > bufferLength) {
    throw RangeError(
      'Matrix $name bounds check failed: required length $requiredLength exceeds buffer length $bufferLength',
    );
  }
}

/// Mirrors the stored triangle of a symmetric matrix across the diagonal.
void mirrorSymmetricDouble(
  Float64List c,
  int cOffset,
  int n,
  int ldc,
  int uplo,
) {
  if (uplo == cblasUpper) {
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        c[cOffset + j * ldc + i] = c[cOffset + i * ldc + j];
      }
    }
  } else {
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < i; j++) {
        c[cOffset + j * ldc + i] = c[cOffset + i * ldc + j];
      }
    }
  }
}

/// Mirrors the stored triangle of a symmetric matrix across the diagonal.
void mirrorSymmetricFloat(
  Float32List c,
  int cOffset,
  int n,
  int ldc,
  int uplo,
) {
  if (uplo == cblasUpper) {
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        c[cOffset + j * ldc + i] = c[cOffset + i * ldc + j];
      }
    }
  } else {
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < i; j++) {
        c[cOffset + j * ldc + i] = c[cOffset + i * ldc + j];
      }
    }
  }
}
