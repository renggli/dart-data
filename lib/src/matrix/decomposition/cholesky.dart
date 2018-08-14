library matrix.decomposition.cholesky;

import 'dart:math' as math;

import 'package:data/type.dart';

import '../matrix.dart';
import '../operators.dart';
import '../utils.dart';

/// Cholesky Decomposition.
///
/// For a symmetric, positive definite matrix A, the Cholesky decomposition
/// is an lower triangular matrix L so that A = L*L'.
///
/// If the matrix is not symmetric or positive definite, the constructor
/// returns a partial decomposition and sets an internal flag that may
/// be queried by the isSPD() method.
class CholeskyDecomposition  {

/* ------------------------
   Class variables
 * ------------------------ */

   /** Array for internal storage of decomposition.
   @serial internal array storage.
   */
   private double[][] L;

   /** Row and column dimension (square matrix).
   @serial matrix dimension.
   */
   private int n;

   /** Symmetric and positive definite flag.
   @serial is symmetric and positive definite flag.
   */
   private boolean isspd;

/* ------------------------
   Constructor
 * ------------------------ */

   /** Cholesky algorithm for symmetric and positive definite matrix.
       Structure to access L and isspd flag.
   @param  Arg   Square, symmetric matrix.
   */

   CholeskyDecomposition (Matrix Arg) {


     // Initialize.
      double[][] A = Arg.getArray();
      _n = Arg.rowCount;
      L = new double.getUnchecked(_n, _n);
      isspd = (Arg.colCount == _n);
      // Main loop.
      for (var j = 0; j < _n; j++) {
         double[] Lrowj = L[j];
         double d = 0.0;
         for (var k = 0; k < j; k++) {
            double[] Lrowk = L[k];
            double s = 0.0;
            for (var i = 0; i < k; i++) {
               s += Lrowk[i]*Lrowj[i];
            }
            Lrowj[k] = s = (A.getUnchecked(j, k) - s)/L.getUnchecked(k, k);
            d = d + s*s;
            isspd = isspd & (A.getUnchecked(k, j) == A.getUnchecked(j, k)); 
         }
         d = A.getUnchecked(j, j) - d;
         isspd = isspd & (d > 0.0);
         L.setUnchecked(j, j, math.sqrt(math.max(d,0.0)));
         for (var k = j+1; k < _n; k++) {
            L.setUnchecked(j, k, 0.0);
         }
      }
   }

/* ------------------------
   Temporary, experimental code.
 * ------------------------ *\

   \** Right Triangular Cholesky Decomposition.
   <P>
   For a symmetric, positive definite matrix A, the Right Cholesky
   decomposition is an upper triangular matrix R so that A = R'*R.
   This constructor computes R with the Fortran inspired column oriented
   algorithm used in LINPACK and MATLAB.  In Java, we suspect a row oriented,
   lower triangular decomposition is faster.  We have temporarily included
   this constructor here until timing experiments confirm this suspicion.
   *\

   \** Array for internal storage of right triangular decomposition. **\
   private transient double[][] R;

   \** Cholesky algorithm for symmetric and positive definite matrix.
   @param  A           Square, symmetric matrix.
   @param  rightflag   Actual value ignored.
   @return             Structure to access R and isspd flag.
   *\

   CholeskyDecomposition (Matrix Arg, int rightflag) {
      // Initialize.
      double[][] A = Arg.getArray();
      n = Arg.colCount;
      R = new double.getUnchecked(n, n);
      isspd = (Arg.colCount == n);
      // Main loop.
      for (var j = 0; j < n; j++) {
         double d = 0.0;
         for (var k = 0; k < j; k++) {
            double s = A.getUnchecked(k, j);
            for (var i = 0; i < k; i++) {
               s = s - R.getUnchecked(i, k)*R.getUnchecked(i, j);
            }
            R.setUnchecked(k, j, s = s/R.getUnchecked(k, k));
            d = d + s*s;
            isspd = isspd & (A.getUnchecked(k, j) == A.getUnchecked(j, k)); 
         }
         d = A.getUnchecked(j, j) - d;
         isspd = isspd & (d > 0.0);
         R.setUnchecked(j, j, math.sqrt(math.max(d,0.0)));
         for (var k = j+1; k < n; k++) {
            R.setUnchecked(k, j, 0.0);
         }
      }
   }

   \** Return upper triangular factor.
   @return     R
   *\

   Matrix getR () {
      return new Matrix(R,n,n);
   }

\* ------------------------
   End of temporary code.
 * ------------------------ */

/* ------------------------
   Public Methods
 * ------------------------ */

   /** Is the matrix symmetric and positive definite?
   @return     true if A is symmetric and positive definite.
   */

   boolean isSPD () {
      return isspd;
   }

   /** Return triangular factor.
   @return     L
   */

   Matrix getL () {
      return new Matrix(L,_n,_n);
   }

   /** Solve A*X = B
   @param  B   A Matrix with as many rows as A and any number of columns.
   @return     X so that L*L'*X = B
   @exception  IllegalArgumentException  Matrix row dimensions must agree.
   @exception  RuntimeException  Matrix is not symmetric positive definite.
   */

   Matrix solve (Matrix B) {
      if (B.rowCount != _n) {
         throw new IllegalArgumentException('Matrix row dimensions must agree.');
      }
      if (!isspd) {
         throw new RuntimeException('Matrix is not symmetric positive definite.');
      }

      // Copy right hand side.
      double[][] X = B.getArrayCopy();
      var nx = B.colCount;

	      // Solve L*Y = B;
	      for (var k = 0; k < _n; k++) {
	        for (var j = 0; j < nx; j++) {
	           for (var i = 0; i < k ; i++) {
	               X.getUnchecked(k, j) -= X.getUnchecked(i, j)*L.getUnchecked(k, i);
	           }
	           X.getUnchecked(k, j) /= L.getUnchecked(k, k);
	        }
	      }
	
	      // Solve L'*X = Y;
	      for (var k = _n-1; k >= 0; k--) {
	        for (var j = 0; j < nx; j++) {
	           for (var i = k+1; i < _n ; i++) {
	               X.getUnchecked(k, j) -= X.getUnchecked(i, j)*L.getUnchecked(i, k);
	           }
	           X.getUnchecked(k, j) /= L.getUnchecked(k, k);
	        }
	      }
      
      
      return new Matrix(X,_n,nx);
   }


}

