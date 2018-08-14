library matrix.decomposition.eigen;

import 'dart:math' as math;

import 'package:data/type.dart';

import '../matrix.dart';
import '../operators.dart';
import '../utils.dart';

/// Eigenvalues and eigenvectors of a real matrix.
///
/// If A is symmetric, then A = V*D*V' where the eigenvalue matrix D is
/// diagonal and the eigenvector matrix V is orthogonal.
/// I.e. A = V.times(D.times(V.transpose())) and
/// V.times(V.transpose()) equals the identity matrix.
///
/// If A is not symmetric, then the eigenvalue matrix D is block diagonal
/// with the real eigenvalues in 1-by-1 blocks and any complex eigenvalues,
/// lambda + i*mu, in 2-by-2 blocks, [lambda, mu; -mu, lambda].  The
/// columns of V represent the eigenvectors in the sense that A*V = V*D,
/// i.e. A.times(V) equals V.times(D).  The matrix V may be badly
/// conditioned, or even singular, so the validity of the equation
/// A = V*D*inverse(V) depends upon V.cond().
class EigenvalueDecomposition  {

/* ------------------------
   Class variables
 * ------------------------ */

   /** Row and column dimension (square matrix).
   @serial matrix dimension.
   */
   private int n;

   /** Symmetry flag.
   @serial internal symmetry flag.
   */
   private boolean issymmetric;

   /** Arrays for internal storage of eigenvalues.
   @serial internal storage of eigenvalues.
   */
   private double[] d, e;

   /** Array for internal storage of eigenvectors.
   @serial internal storage of eigenvectors.
   */
   private double[][] V;

   /** Array for internal storage of nonsymmetric Hessenberg form.
   @serial internal storage of nonsymmetric Hessenberg form.
   */
   private double[][] H;

   /** Working storage for nonsymmetric algorithm.
   @serial working storage for nonsymmetric algorithm.
   */
   private double[] ort;

/* ------------------------
   Private Methods
 * ------------------------ */

   // Symmetric Householder reduction to tridiagonal form.

   private void tred2 () {

   //  This is derived from the Algol procedures tred2 by
   //  Bowdler, Martin, Reinsch, and Wilkinson, Handbook for
   //  Auto. Comp., Vol.ii-Linear Algebra, and the corresponding
   //  Fortran subroutine in EISPACK.

      for (var j = 0; j < _n; j++) {
         d[j] = V.getUnchecked(_n-1, j);
      }

      // Householder reduction to tridiagonal form.
   
      for (var i = _n-1; i > 0; i--) {
   
         // Scale to avoid under/overflow.
   
         double scale = 0.0;
         double h = 0.0;
         for (var k = 0; k < i; k++) {
            scale = scale + math.abs(d[k]);
         }
         if (scale == 0.0) {
            e[i] = d[i-1];
            for (var j = 0; j < i; j++) {
               d[j] = V.getUnchecked(i-1, j);
               V.setUnchecked(i, j, 0.0);
               V.setUnchecked(j, i, 0.0);
            }
         } else {
   
            // Generate Householder vector.
   
            for (var k = 0; k < i; k++) {
               d[k] /= scale;
               h += d[k] * d[k];
            }
            double f = d[i-1];
            double g = math.sqrt(h);
            if (f > 0) {
               g = -g;
            }
            e[i] = scale * g;
            h = h - f * g;
            d[i-1] = f - g;
            for (var j = 0; j < i; j++) {
               e[j] = 0.0;
            }
   
            // Apply similarity transformation to remaining columns.
   
            for (var j = 0; j < i; j++) {
               f = d[j];
               V.setUnchecked(j, i, f);
               g = e[j] + V.getUnchecked(j, j) * f;
               for (var k = j+1; k <= i-1; k++) {
                  g += V.getUnchecked(k, j) * d[k];
                  e[k] += V.getUnchecked(k, j) * f;
               }
               e[j] = g;
            }
            f = 0.0;
            for (var j = 0; j < i; j++) {
               e[j] /= h;
               f += e[j] * d[j];
            }
            double hh = f / (h + h);
            for (var j = 0; j < i; j++) {
               e[j] -= hh * d[j];
            }
            for (var j = 0; j < i; j++) {
               f = d[j];
               g = e[j];
               for (var k = j; k <= i-1; k++) {
                  V.getUnchecked(k, j) -= (f * e[k] + g * d[k]);
               }
               d[j] = V.getUnchecked(i-1, j);
               V.setUnchecked(i, j, 0.0);
            }
         }
         d[i] = h;
      }
   
      // Accumulate transformations.
   
      for (var i = 0; i < _n-1; i++) {
         V.setUnchecked(_n-1, i, V.getUnchecked(i, i));
         V.setUnchecked(i, i, 1.0);
         double h = d[i+1];
         if (h != 0.0) {
            for (var k = 0; k <= i; k++) {
               d[k] = V.getUnchecked(k, i+1) / h;
            }
            for (var j = 0; j <= i; j++) {
               double g = 0.0;
               for (var k = 0; k <= i; k++) {
                  g += V.getUnchecked(k, i+1) * V.getUnchecked(k, j);
               }
               for (var k = 0; k <= i; k++) {
                  V.getUnchecked(k, j) -= g * d[k];
               }
            }
         }
         for (var k = 0; k <= i; k++) {
            V.setUnchecked(k, i+1, 0.0);
         }
      }
      for (var j = 0; j < _n; j++) {
         d[j] = V.getUnchecked(_n-1, j);
         V.setUnchecked(_n-1, j, 0.0);
      }
      V.setUnchecked(_n-1, _n-1, 1.0);
      e[0] = 0.0;
   } 

   // Symmetric tridiagonal QL algorithm.
   
   private void tql2 () {

   //  This is derived from the Algol procedures tql2, by
   //  Bowdler, Martin, Reinsch, and Wilkinson, Handbook for
   //  Auto. Comp., Vol.ii-Linear Algebra, and the corresponding
   //  Fortran subroutine in EISPACK.
   
      for (var i = 1; i < _n; i++) {
         e[i-1] = e[i];
      }
      e[_n-1] = 0.0;
   
      double f = 0.0;
      double tst1 = 0.0;
      double eps = math.pow(2.0,-52.0);
      for (var l = 0; l < _n; l++) {

         // Find small subdiagonal element
   
         tst1 = math.max(tst1,math.abs(d[l]) + math.abs(e[l]));
         var m = l;
         while (m < _n) {
            if (math.abs(e[m]) <= eps*tst1) {
               break;
            }
            m++;
         }
   
         // If m == l, d[l] is an eigenvalue,
         // otherwise, iterate.
   
         if (m > l) {
            var iter = 0;
            do {
               iter = iter + 1;  // (Could check iteration count here.)
   
               // Compute implicit shift
   
               double g = d[l];
               double p = (d[l+1] - g) / (2.0 * e[l]);
               double r = hypot(p,1.0);
               if (p < 0) {
                  r = -r;
               }
               d[l] = e[l] / (p + r);
               d[l+1] = e[l] * (p + r);
               double dl1 = d[l+1];
               double h = g - d[l];
               for (var i = l+2; i < _n; i++) {
                  d[i] -= h;
               }
               f = f + h;
   
               // Implicit QL transformation.
   
               p = d[m];
               double c = 1.0;
               double c2 = c;
               double c3 = c;
               double el1 = e[l+1];
               double s = 0.0;
               double s2 = 0.0;
               for (var i = m-1; i >= l; i--) {
                  c3 = c2;
                  c2 = c;
                  s2 = s;
                  g = c * e[i];
                  h = c * p;
                  r = hypot(p,e[i]);
                  e[i+1] = s * r;
                  s = e[i] / r;
                  c = p / r;
                  p = c * d[i] - s * g;
                  d[i+1] = h + s * (c * g + s * d[i]);
   
                  // Accumulate transformation.
   
                  for (var k = 0; k < _n; k++) {
                     h = V.getUnchecked(k, i+1);
                     V.setUnchecked(k, i+1, s * V.getUnchecked(k, i) + c * h);
                     V.setUnchecked(k, i, c * V.getUnchecked(k, i) - s * h);
                  }
               }
               p = -s * s2 * c3 * el1 * e[l] / dl1;
               e[l] = s * p;
               d[l] = c * p;
   
               // Check for convergence.
   
            } while (math.abs(e[l]) > eps*tst1);
         }
         d[l] = d[l] + f;
         e[l] = 0.0;
      }
     
      // Sort eigenvalues and corresponding vectors.
   
      for (var i = 0; i < _n-1; i++) {
         var k = i;
         double p = d[i];
         for (var j = i+1; j < _n; j++) {
            if (d[j] < p) {
               k = j;
               p = d[j];
            }
         }
         if (k != i) {
            d[k] = d[i];
            d[i] = p;
            for (var j = 0; j < _n; j++) {
               p = V.getUnchecked(j, i);
               V.setUnchecked(j, i, V.getUnchecked(j, k));
               V.setUnchecked(j, k, p);
            }
         }
      }
   }

   // Nonsymmetric reduction to Hessenberg form.

   private void orthes () {
   
      //  This is derived from the Algol procedures orthes and ortran,
      //  by Martin and Wilkinson, Handbook for Auto. Comp.,
      //  Vol.ii-Linear Algebra, and the corresponding
      //  Fortran subroutines in EISPACK.
   
      var low = 0;
      var high = _n-1;
   
      for (var m = low+1; m <= high-1; m++) {
   
         // Scale column.
   
         double scale = 0.0;
         for (var i = m; i <= high; i++) {
            scale = scale + math.abs(H.getUnchecked(i, m-1));
         }
         if (scale != 0.0) {
   
            // Compute Householder transformation.
   
            double h = 0.0;
            for (var i = high; i >= m; i--) {
               ort[i] = H.getUnchecked(i, m-1)/scale;
               h += ort[i] * ort[i];
            }
            double g = math.sqrt(h);
            if (ort[m] > 0) {
               g = -g;
            }
            h = h - ort[m] * g;
            ort[m] = ort[m] - g;
   
            // Apply Householder similarity transformation
            // H = (I-u*u'/h)*H*(I-u*u')/h)
   
            for (var j = m; j < _n; j++) {
               double f = 0.0;
               for (var i = high; i >= m; i--) {
                  f += ort[i]*H.getUnchecked(i, j);
               }
               f = f/h;
               for (var i = m; i <= high; i++) {
                  H.getUnchecked(i, j) -= f*ort[i];
               }
           }
   
           for (var i = 0; i <= high; i++) {
               double f = 0.0;
               for (var j = high; j >= m; j--) {
                  f += ort[j]*H.getUnchecked(i, j);
               }
               f = f/h;
               for (var j = m; j <= high; j++) {
                  H.getUnchecked(i, j) -= f*ort[j];
               }
            }
            ort[m] = scale*ort[m];
            H.setUnchecked(m, m-1, scale*g);
         }
      }
   
      // Accumulate transformations (Algol's ortran).

      for (var i = 0; i < _n; i++) {
         for (var j = 0; j < _n; j++) {
            V.setUnchecked(i, j, (i == j ? 1.0 : 0.0));
         }
      }

      for (var m = high-1; m >= low+1; m--) {
         if (H.getUnchecked(m, m-1) != 0.0) {
            for (var i = m+1; i <= high; i++) {
               ort[i] = H.getUnchecked(i, m-1);
            }
            for (var j = m; j <= high; j++) {
               double g = 0.0;
               for (var i = m; i <= high; i++) {
                  g += ort[i] * V.getUnchecked(i, j);
               }
               // Double division avoids possible underflow
               g = (g / ort[m]) / H.getUnchecked(m, m-1);
               for (var i = m; i <= high; i++) {
                  V.getUnchecked(i, j) += g * ort[i];
               }
            }
         }
      }
   }


   // Complex scalar division.

   private transient double cdivr, cdivi;
   private void cdiv(double xr, double xi, double yr, double yi) {
      double r,d;
      if (math.abs(yr) > math.abs(yi)) {
         r = yi/yr;
         d = yr + r*yi;
         cdivr = (xr + r*xi)/d;
         cdivi = (xi - r*xr)/d;
      } else {
         r = yr/yi;
         d = yi + r*yr;
         cdivr = (r*xr + xi)/d;
         cdivi = (r*xi - xr)/d;
      }
   }


   // Nonsymmetric reduction from Hessenberg to real Schur form.

   private void hqr2 () {
   
      //  This is derived from the Algol procedure hqr2,
      //  by Martin and Wilkinson, Handbook for Auto. Comp.,
      //  Vol.ii-Linear Algebra, and the corresponding
      //  Fortran subroutine in EISPACK.
   
      // Initialize
   
      var nn = this._n;
      var n = nn-1;
      var low = 0;
      var high = nn-1;
      double eps = math.pow(2.0,-52.0);
      double exshift = 0.0;
      double p=0,q=0,r=0,s=0,z=0,t,w,x,y;
   
      // Store roots isolated by balanc and compute matrix norm
   
      double norm = 0.0;
      for (var i = 0; i < nn; i++) {
         if (i < low | i > high) {
            d[i] = H.getUnchecked(i, i);
            e[i] = 0.0;
         }
         for (var j = math.max(i-1,0); j < nn; j++) {
            norm = norm + math.abs(H.getUnchecked(i, j));
         }
      }
   
      // Outer loop over eigenvalue index
   
      var iter = 0;
      while (n >= low) {
   
         // Look for single small sub-diagonal element
   
         var l = n;
         while (l > low) {
            s = math.abs(H.getUnchecked(l-1, l-1)) + math.abs(H.getUnchecked(l, l));
            if (s == 0.0) {
               s = norm;
            }
            if (math.abs(H.getUnchecked(l, l-1)) < eps * s) {
               break;
            }
            l--;
         }
       
         // Check for convergence
         // One root found
   
         if (l == n) {
            H.setUnchecked(n, n, H.getUnchecked(n, n) + exshift);
            d[n] = H.getUnchecked(n, n);
            e[n] = 0.0;
            n--;
            iter = 0;
   
         // Two roots found
   
         } else if (l == n-1) {
            w = H.getUnchecked(n, n-1) * H.getUnchecked(n-1, n);
            p = (H.getUnchecked(n-1, n-1) - H.getUnchecked(n, n)) / 2.0;
            q = p * p + w;
            z = math.sqrt(math.abs(q));
            H.setUnchecked(n, n, H.getUnchecked(n, n) + exshift);
            H.setUnchecked(n-1, n-1, H.getUnchecked(n-1, n-1) + exshift);
            x = H.getUnchecked(n, n);
   
            // Real pair
   
            if (q >= 0) {
               if (p >= 0) {
                  z = p + z;
               } else {
                  z = p - z;
               }
               d[n-1] = x + z;
               d[n] = d[n-1];
               if (z != 0.0) {
                  d[n] = x - w / z;
               }
               e[n-1] = 0.0;
               e[n] = 0.0;
               x = H.getUnchecked(n, n-1);
               s = math.abs(x) + math.abs(z);
               p = x / s;
               q = z / s;
               r = math.sqrt(p * p+q * q);
               p = p / r;
               q = q / r;
   
               // Row modification
   
               for (var j = n-1; j < nn; j++) {
                  z = H.getUnchecked(n-1, j);
                  H.setUnchecked(n-1, j, q * z + p * H.getUnchecked(n, j));
                  H.setUnchecked(n, j, q * H.getUnchecked(n, j) - p * z);
               }
   
               // Column modification
   
               for (var i = 0; i <= n; i++) {
                  z = H.getUnchecked(i, n-1);
                  H.setUnchecked(i, n-1, q * z + p * H.getUnchecked(i, n));
                  H.setUnchecked(i, n, q * H.getUnchecked(i, n) - p * z);
               }
   
               // Accumulate transformations
   
               for (var i = low; i <= high; i++) {
                  z = V.getUnchecked(i, n-1);
                  V.setUnchecked(i, n-1, q * z + p * V.getUnchecked(i, n));
                  V.setUnchecked(i, n, q * V.getUnchecked(i, n) - p * z);
               }
   
            // Complex pair
   
            } else {
               d[n-1] = x + p;
               d[n] = x + p;
               e[n-1] = z;
               e[n] = -z;
            }
            n = n - 2;
            iter = 0;
   
         // No convergence yet
   
         } else {
   
            // Form shift
   
            x = H.getUnchecked(n, n);
            y = 0.0;
            w = 0.0;
            if (l < n) {
               y = H.getUnchecked(n-1, n-1);
               w = H.getUnchecked(n, n-1) * H.getUnchecked(n-1, n);
            }
   
            // Wilkinson's original ad hoc shift
   
            if (iter == 10) {
               exshift += x;
               for (var i = low; i <= n; i++) {
                  H.getUnchecked(i, i) -= x;
               }
               s = math.abs(H.getUnchecked(n, n-1)) + math.abs(H.getUnchecked(n-1, n-2));
               x = y = 0.75 * s;
               w = -0.4375 * s * s;
            }

            // MATLAB's new ad hoc shift

            if (iter == 30) {
                s = (y - x) / 2.0;
                s = s * s + w;
                if (s > 0) {
                    s = math.sqrt(s);
                    if (y < x) {
                       s = -s;
                    }
                    s = x - w / ((y - x) / 2.0 + s);
                    for (var i = low; i <= n; i++) {
                       H.getUnchecked(i, i) -= s;
                    }
                    exshift += s;
                    x = y = w = 0.964;
                }
            }
   
            iter = iter + 1;   // (Could check iteration count here.)
   
            // Look for two consecutive small sub-diagonal elements
   
            var m = n-2;
            while (m >= l) {
               z = H.getUnchecked(m, m);
               r = x - z;
               s = y - z;
               p = (r * s - w) / H.getUnchecked(m+1, m) + H.getUnchecked(m, m+1);
               q = H.getUnchecked(m+1, m+1) - z - r - s;
               r = H.getUnchecked(m+2, m+1);
               s = math.abs(p) + math.abs(q) + math.abs(r);
               p = p / s;
               q = q / s;
               r = r / s;
               if (m == l) {
                  break;
               }
               if (math.abs(H.getUnchecked(m, m-1)) * (math.abs(q) + math.abs(r)) <
                  eps * (math.abs(p) * (math.abs(H.getUnchecked(m-1, m-1)) + math.abs(z) +
                  math.abs(H.getUnchecked(m+1, m+1))))) {
                     break;
               }
               m--;
            }
   
            for (var i = m+2; i <= n; i++) {
               H.setUnchecked(i, i-2, 0.0);
               if (i > m+2) {
                  H.setUnchecked(i, i-3, 0.0);
               }
            }
   
            // Double QR step involving rows l:n and columns m:n
   

            for (var k = m; k <= n-1; k++) {
               boolean notlast = (k != n-1);
               if (k != m) {
                  p = H.getUnchecked(k, k-1);
                  q = H.getUnchecked(k+1, k-1);
                  r = (notlast ? H.getUnchecked(k+2, k-1) : 0.0);
                  x = math.abs(p) + math.abs(q) + math.abs(r);
                  if (x == 0.0) {
                      continue;
                  }
                  p = p / x;
                  q = q / x;
                  r = r / x;
               }

               s = math.sqrt(p * p + q * q + r * r);
               if (p < 0) {
                  s = -s;
               }
               if (s != 0) {
                  if (k != m) {
                     H.setUnchecked(k, k-1, -s * x);
                  } else if (l != m) {
                     H.setUnchecked(k, k-1, -H.getUnchecked(k, k-1));
                  }
                  p = p + s;
                  x = p / s;
                  y = q / s;
                  z = r / s;
                  q = q / p;
                  r = r / p;
   
                  // Row modification
   
                  for (var j = k; j < nn; j++) {
                     p = H.getUnchecked(k, j) + q * H.getUnchecked(k+1, j);
                     if (notlast) {
                        p = p + r * H.getUnchecked(k+2, j);
                        H.setUnchecked(k+2, j, H.getUnchecked(k+2, j) - p * z);
                     }
                     H.setUnchecked(k, j, H.getUnchecked(k, j) - p * x);
                     H.setUnchecked(k+1, j, H.getUnchecked(k+1, j) - p * y);
                  }
   
                  // Column modification
   
                  for (var i = 0; i <= math.min(n,k+3); i++) {
                     p = x * H.getUnchecked(i, k) + y * H.getUnchecked(i, k+1);
                     if (notlast) {
                        p = p + z * H.getUnchecked(i, k+2);
                        H.setUnchecked(i, k+2, H.getUnchecked(i, k+2) - p * r);
                     }
                     H.setUnchecked(i, k, H.getUnchecked(i, k) - p);
                     H.setUnchecked(i, k+1, H.getUnchecked(i, k+1) - p * q);
                  }
   
                  // Accumulate transformations
   
                  for (var i = low; i <= high; i++) {
                     p = x * V.getUnchecked(i, k) + y * V.getUnchecked(i, k+1);
                     if (notlast) {
                        p = p + z * V.getUnchecked(i, k+2);
                        V.setUnchecked(i, k+2, V.getUnchecked(i, k+2) - p * r);
                     }
                     V.setUnchecked(i, k, V.getUnchecked(i, k) - p);
                     V.setUnchecked(i, k+1, V.getUnchecked(i, k+1) - p * q);
                  }
               }  // (s != 0)
            }  // k loop
         }  // check convergence
      }  // while (n >= low)
      
      // Backsubstitute to find vectors of upper triangular form

      if (norm == 0.0) {
         return;
      }
   
      for (n = nn-1; n >= 0; n--) {
         p = d[n];
         q = e[n];
   
         // Real vector
   
         if (q == 0) {
            var l = n;
            H.setUnchecked(n, n, 1.0);
            for (var i = n-1; i >= 0; i--) {
               w = H.getUnchecked(i, i) - p;
               r = 0.0;
               for (var j = l; j <= n; j++) {
                  r = r + H.getUnchecked(i, j) * H.getUnchecked(j, n);
               }
               if (e[i] < 0.0) {
                  z = w;
                  s = r;
               } else {
                  l = i;
                  if (e[i] == 0.0) {
                     if (w != 0.0) {
                        H.setUnchecked(i, n, -r / w);
                     } else {
                        H.setUnchecked(i, n, -r / (eps * norm));
                     }
   
                  // Solve real equations
   
                  } else {
                     x = H.getUnchecked(i, i+1);
                     y = H.getUnchecked(i+1, i);
                     q = (d[i] - p) * (d[i] - p) + e[i] * e[i];
                     t = (x * s - z * r) / q;
                     H.setUnchecked(i, n, t);
                     if (math.abs(x) > math.abs(z)) {
                        H.setUnchecked(i+1, n, (-r - w * t) / x);
                     } else {
                        H.setUnchecked(i+1, n, (-s - y * t) / z);
                     }
                  }
   
                  // Overflow control
   
                  t = math.abs(H.getUnchecked(i, n));
                  if ((eps * t) * t > 1) {
                     for (var j = i; j <= n; j++) {
                        H.setUnchecked(j, n, H.getUnchecked(j, n) / t);
                     }
                  }
               }
            }
   
         // Complex vector
   
         } else if (q < 0) {
            var l = n-1;

            // Last vector component imaginary so matrix is triangular
   
            if (math.abs(H.getUnchecked(n, n-1)) > math.abs(H.getUnchecked(n-1, n))) {
               H.setUnchecked(n-1, n-1, q / H.getUnchecked(n, n-1));
               H.setUnchecked(n-1, n, -(H.getUnchecked(n, n) - p) / H.getUnchecked(n, n-1));
            } else {
               cdiv(0.0,-H.getUnchecked(n-1, n),H.getUnchecked(n-1, n-1)-p,q);
               H.setUnchecked(n-1, n-1, cdivr);
               H.setUnchecked(n-1, n, cdivi);
            }
            H.setUnchecked(n, n-1, 0.0);
            H.setUnchecked(n, n, 1.0);
            for (var i = n-2; i >= 0; i--) {
               double ra,sa,vr,vi;
               ra = 0.0;
               sa = 0.0;
               for (var j = l; j <= n; j++) {
                  ra = ra + H.getUnchecked(i, j) * H.getUnchecked(j, n-1);
                  sa = sa + H.getUnchecked(i, j) * H.getUnchecked(j, n);
               }
               w = H.getUnchecked(i, i) - p;
   
               if (e[i] < 0.0) {
                  z = w;
                  r = ra;
                  s = sa;
               } else {
                  l = i;
                  if (e[i] == 0) {
                     cdiv(-ra,-sa,w,q);
                     H.setUnchecked(i, n-1, cdivr);
                     H.setUnchecked(i, n, cdivi);
                  } else {
   
                     // Solve complex equations
   
                     x = H.getUnchecked(i, i+1);
                     y = H.getUnchecked(i+1, i);
                     vr = (d[i] - p) * (d[i] - p) + e[i] * e[i] - q * q;
                     vi = (d[i] - p) * 2.0 * q;
                     if (vr == 0.0 & vi == 0.0) {
                        vr = eps * norm * (math.abs(w) + math.abs(q) +
                        math.abs(x) + math.abs(y) + math.abs(z));
                     }
                     cdiv(x*r-z*ra+q*sa,x*s-z*sa-q*ra,vr,vi);
                     H.setUnchecked(i, n-1, cdivr);
                     H.setUnchecked(i, n, cdivi);
                     if (math.abs(x) > (math.abs(z) + math.abs(q))) {
                        H.setUnchecked(i+1, n-1, (-ra - w * H.getUnchecked(i, n-1) + q * H.getUnchecked(i, n)) / x);
                        H.setUnchecked(i+1, n, (-sa - w * H.getUnchecked(i, n) - q * H.getUnchecked(i, n-1)) / x);
                     } else {
                        cdiv(-r-y*H.getUnchecked(i, n-1),-s-y*H.getUnchecked(i, n),z,q);
                        H.setUnchecked(i+1, n-1, cdivr);
                        H.setUnchecked(i+1, n, cdivi);
                     }
                  }
   
                  // Overflow control

                  t = math.max(math.abs(H.getUnchecked(i, n-1)),math.abs(H.getUnchecked(i, n)));
                  if ((eps * t) * t > 1) {
                     for (var j = i; j <= n; j++) {
                        H.setUnchecked(j, n-1, H.getUnchecked(j, n-1) / t);
                        H.setUnchecked(j, n, H.getUnchecked(j, n) / t);
                     }
                  }
               }
            }
         }
      }
   
      // Vectors of isolated roots
   
      for (var i = 0; i < nn; i++) {
         if (i < low | i > high) {
            for (var j = i; j < nn; j++) {
               V.setUnchecked(i, j, H.getUnchecked(i, j));
            }
         }
      }
   
      // Back transformation to get eigenvectors of original matrix
   
      for (var j = nn-1; j >= low; j--) {
         for (var i = low; i <= high; i++) {
            z = 0.0;
            for (var k = low; k <= math.min(j,high); k++) {
               z = z + V.getUnchecked(i, k) * H.getUnchecked(k, j);
            }
            V.setUnchecked(i, j, z);
         }
      }
   }


/* ------------------------
   Constructor
 * ------------------------ */

   /** Check for symmetry, then construct the eigenvalue decomposition
       Structure to access D and V.
   @param Arg    Square matrix
   */

   EigenvalueDecomposition (Matrix Arg) {
      double[][] A = Arg.getArray();
      _n = Arg.colCount;
      V = new double.getUnchecked(_n, _n);
      d = new double[_n];
      e = new double[_n];

      issymmetric = true;
      for (var j = 0; (j < _n) & issymmetric; j++) {
         for (var i = 0; (i < _n) & issymmetric; i++) {
            issymmetric = (A.getUnchecked(i, j) == A.getUnchecked(j, i));
         }
      }

      if (issymmetric) {
         for (var i = 0; i < _n; i++) {
            for (var j = 0; j < _n; j++) {
               V.setUnchecked(i, j, A.getUnchecked(i, j));
            }
         }
   
         // Tridiagonalize.
         tred2();
   
         // Diagonalize.
         tql2();

      } else {
         H = new double.getUnchecked(_n, _n);
         ort = new double[_n];
         
         for (var j = 0; j < _n; j++) {
            for (var i = 0; i < _n; i++) {
               H.setUnchecked(i, j, A.getUnchecked(i, j));
            }
         }
   
         // Reduce to Hessenberg form.
         orthes();
   
         // Reduce Hessenberg to real Schur form.
         hqr2();
      }
   }

/* ------------------------
   Public Methods
 * ------------------------ */

   /** Return the eigenvector matrix
   @return     V
   */

   Matrix getV () {
      return new Matrix(V,_n,_n);
   }

   /** Return the real parts of the eigenvalues
   @return     real(diag(D))
   */

   double[] getRealEigenvalues () {
      return d;
   }

   /** Return the imaginary parts of the eigenvalues
   @return     imag(diag(D))
   */

   double[] getImagEigenvalues () {
      return e;
   }

   /** Return the block diagonal eigenvalue matrix
   @return     D
   */

   Matrix getD () {
      Matrix X = new Matrix(_n,_n);
      double[][] D = X.getArray();
      for (var i = 0; i < _n; i++) {
         for (var j = 0; j < _n; j++) {
            D.setUnchecked(i, j, 0.0);
         }
         D.setUnchecked(i, i, d[i]);
         if (e[i] > 0) {
            D.setUnchecked(i, i+1, e[i]);
         } else if (e[i] < 0) {
            D.setUnchecked(i, i-1, e[i]);
         }
      }
      return X;
   }

}
