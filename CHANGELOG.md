# Changelog

## 0.15.1

- Dart and Flutter 3.9 compatibility.

## 0.15.0

- Dart 3.8 requirement.
- Bugfixes and resolved compatibility issues.

## 0.14.0

- Add `Vector.fromString` and `Matrix.fromString`.
- Make matrix iterators return row, column, and value tuples.

## 0.13.0

- Cleanup API of distributions.
- Add cross product support to vectors.
- Add `Vector.fromTensor` and `Matrix.fromTensor`.

## 0.12.0

- Dart 3.0 support and requirement.
- Experimental `Tensor` library.

## 0.11.0

- Dart 2.18 requirement.
- Add fast FFT polynomial multiplication operator.
- Add more distributions (rademacher, inverse weibull, negative binomial) and more properties (kurtosis, bounds).
- Add support for curve fitting (Levenberg Marquardt, Polynomial Regression).
- More and better accessors for numeric limits, including also floating point numbers.
- Operators are lazy now and create views. Use `toVector()` or `copyInto(target)` to evaluate the data. This uniformly applies to `Matrix`, `Vector` and `Polynomial` now.
- Various improvements to singular value decomposition, thanks to Jong Hyun Kim.

## 0.10.0

- Dart 2.16 requirement.
- More distributions: exponential, gamma, inverse gamma, student-t.
- Add a Jackknife estimator to compute confidence intervals of samples.
- Countless fixes, improved tests, and other improvements.

## 0.9.0

- Dart 2.14 requirement.
- Strong typing support across all code.

## 0.7.0

- Dart 2.12 requirement and null-safety.
- Added numeric derivative, integration, and solver.

## 0.6.0

- Support for vectors, matrices, and polynomials.
