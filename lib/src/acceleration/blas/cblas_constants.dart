// ignore_for_file: constant_identifier_names

/// CBLAS Row-Major matrix layout order.
const int cblasRowMajor = 101;

/// CBLAS Column-Major matrix layout order.
const int cblasColMajor = 102;

/// CBLAS Transposition option: No transposition.
const int cblasNoTrans = 111;

/// CBLAS Transposition option: Transpose.
const int cblasTrans = 112;

/// CBLAS Transposition option: Conjugate transpose.
const int cblasConjTrans = 113;

/// CBLAS Matrix triangular part: Upper triangle.
const int cblasUpper = 121;

/// CBLAS Matrix triangular part: Lower triangle.
const int cblasLower = 122;

/// CBLAS Diagonal option: Non-unit diagonal.
const int cblasNonUnit = 131;

/// CBLAS Diagonal option: Unit diagonal.
const int cblasUnit = 132;

/// CBLAS Operation side: Multiply on the left ($A \cdot X$).
const int cblasLeft = 141;

/// CBLAS Operation side: Multiply on the right ($X \cdot A$).
const int cblasRight = 142;
