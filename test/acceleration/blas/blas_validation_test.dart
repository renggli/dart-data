import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/src/acceleration/blas/blas_validation.dart';
import 'package:data/src/acceleration/blas/cblas_constants.dart';
import 'package:test/test.dart';

void main() {
  group('BLAS Validation', () {
    test('checkBlasTrans accepts valid constants and throws on invalid', () {
      checkBlasTrans(cblasNoTrans);
      checkBlasTrans(cblasTrans);
      checkBlasTrans(cblasConjTrans);
      check(() => checkBlasTrans(999)).throws<ArgumentError>();
    });

    test('checkBlasUplo accepts valid constants and throws on invalid', () {
      checkBlasUplo(cblasUpper);
      checkBlasUplo(cblasLower);
      check(() => checkBlasUplo(999)).throws<ArgumentError>();
    });

    test('checkBlasDiag accepts valid constants and throws on invalid', () {
      checkBlasDiag(cblasNonUnit);
      checkBlasDiag(cblasUnit);
      check(() => checkBlasDiag(999)).throws<ArgumentError>();
    });

    test('checkBlasSide accepts valid constants and throws on invalid', () {
      checkBlasSide(cblasLeft);
      checkBlasSide(cblasRight);
      check(() => checkBlasSide(999)).throws<ArgumentError>();
    });

    test('checkBlasInc validates non-zero stride', () {
      checkBlasInc(1, 'incX');
      checkBlasInc(-2, 'incY');
      check(() => checkBlasInc(0, 'incX')).throws<ArgumentError>();
    });

    test('checkBlasOffset validates range', () {
      checkBlasOffset(0, 10, 'offset');
      checkBlasOffset(5, 10, 'offset');
      checkBlasOffset(10, 10, 'offset');
      check(() => checkBlasOffset(-1, 10, 'offset')).throws<RangeError>();
      check(() => checkBlasOffset(11, 10, 'offset')).throws<RangeError>();
    });

    test('checkBlasVectorBounds validates vector buffer capacity', () {
      checkBlasVectorBounds(10, 5, 0, 2, 'x');
      checkBlasVectorBounds(10, 5, 5, 1, 'x');
      check(() => checkBlasVectorBounds(10, 6, 0, 2, 'x')).throws<RangeError>();
      check(() => checkBlasVectorBounds(10, 5, -1, 1, 'x'))
          .throws<RangeError>();
    });

    test('checkBlasMatrixLeadingDim validates ld', () {
      checkBlasMatrixLeadingDim(5, 'A', 3);
      checkBlasMatrixLeadingDim(3, 'A', 3);
      check(() => checkBlasMatrixLeadingDim(2, 'A', 3)).throws<ArgumentError>();
    });

    test('checkBlasMatrixBounds validates 2D buffer capacity', () {
      checkBlasMatrixBounds(12, 3, 4, 0, 4, 'A');
      check(() => checkBlasMatrixBounds(10, 3, 4, 0, 4, 'A'))
          .throws<RangeError>();
    });

    test('mirrorSymmetricDouble mirrors upper to lower', () {
      final c = Float64List.fromList([1.0, 2.0, 0.0, 3.0]);
      mirrorSymmetricDouble(c, 0, 2, 2, cblasUpper);
      check(c[2]).equals(2.0);
    });
  });
}
