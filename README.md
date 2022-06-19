Dart Data
=========

[![Pub Package](https://img.shields.io/pub/v/data.svg)](https://pub.dev/packages/data)
[![Build Status](https://github.com/renggli/dart-data/actions/workflows/dart.yml/badge.svg?branch=main)](https://github.com/renggli/dart-data/actions/workflows/dart.yml)
[![Code Coverage](https://codecov.io/gh/renggli/dart-data/branch/main/graph/badge.svg?token=G8EBSJSR17)](https://codecov.io/gh/renggli/dart-data)
[![GitHub Issues](https://img.shields.io/github/issues/renggli/dart-data.svg)](https://github.com/renggli/dart-data/issues)
[![GitHub Forks](https://img.shields.io/github/forks/renggli/dart-data.svg)](https://github.com/renggli/dart-data/network)
[![GitHub Stars](https://img.shields.io/github/stars/renggli/dart-data.svg)](https://github.com/renggli/dart-data/stargazers)
[![GitHub License](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/renggli/dart-data/main/LICENSE)

Dart Data is a fast and space efficient library to deal with data in Dart, Flutter and the web. As of today this mostly includes data structures and algorithms for vectors and matrices, but at some point might also include graphs and other mathematical structures.

This library is open source, stable and well tested. Development happens on [GitHub](https://github.com/renggli/dart-data). Feel free to report issues or create a pull-request there. General questions are best asked on [StackOverflow](https://stackoverflow.com/questions/tagged/data+dart).

The package is hosted on [dart packages](https://pub.dev/packages/data). Up-to-date [class documentation](https://pub.dev/documentation/data/latest/) is created with every release.


Tutorial
--------

Below are step-by-step instructions of how to use this library. More elaborate examples are included with the [examples](https://github.com/renggli/dart-data/tree/main/example).

### Installation

Follow the installation instructions on [dart packages](https://pub.dev/packages/data/install).

Import the core-package into your Dart code using:

```dart
import 'package:data/data.dart';
```

### How to solve a linear equation?

Solve 'A * x = b', where 'A' is a matrix and 'b' a vector:

```dart
final a = Matrix<double>.fromRows(DataType.float64, [
  [2, 1, 1],
  [1, 3, 2],
  [1, 0, 0],
]);
final b = Vector<double>.fromList(DataType.float64, [4, 5, 6]);
final x = a.solve(b.columnMatrix).column(0);
print(x.format(valuePrinter: Printer.fixed()); // prints '6 15 -23'
```

### How to find the eigenvalues of a matrix?

Find the eigenvalues of a matrix 'A':

```dart
final a = Matrix<double>.fromRows(DataType.float64, [
  [1, 0, 0, -1],
  [0, -1, 0, 0],
  [0, 0, 1, -1],
  [-1, 0, -1, 0],
]);
final decomposition = a.eigenvalue;
final eigenvalues = Vector<double>.fromList(
    DataType.float64, decomposition.realEigenvalues);
print(eigenvalues.format(valuePrinter: Printer.fixed(precision: 1))); // prints '-1.0 -1.0 1.0 2.0'
```

### How to find all the roots of a polynomial?

To find the roots of `x^5 + -8x^4 + -72x^3 + 242x^2 + 1847x + 2310`:

```dart
final polynomial = Polynomial.fromCoefficients(DataType.int32, [1, -8, -72, 242, 1847, 2310]);
final roots = polynomial.roots;
print(roots.map((root) => root.real)); // [-5, -3, -2, 7, 11]
print(roots.map((root) => root.imaginary)); // [0, 0, 0, 0, 0]
```

### How to do a polynomial regression?

To find the best fitting third degree polynomial through a list of points:

```dart
final height = [1.47, 1.50, 1.52, 1.55, 1.57, 1.60, 1.63, 1.65, 1.68, 1.70, 1.73, 1.75, 1.78, 1.80, 1.83].toVector();
final mass = [52.21, 53.12, 54.48, 55.84, 57.20, 58.57, 59.93, 61.29, 63.11, 64.47, 66.28, 68.10, 69.92, 72.19, 74.46].toVector();
final fitter = PolynomialRegression(degree: 2);
final result = fitter.fit(xs: height, ys: mass);
print(result.polynomial.format(valuePrinter: FixedNumberPrinter(precision: 3))); // 61.960x^2 + -143.162x + 128.813
```

### How to numerically integrate a function?

In both examples we specify a custom depth, since these integrals are tricky at the upper bound (very steep for the first one, very flat for the second one).

```dart
// Compute the area of a circle by iterating over a quarter circle:
final pi = 4 * integrate((x) => sqrt(1 - x * x), 0, 1, depth: 30);
print(pi); // 3.1415925673846368 ~ pi

// Compute an improper integral:
final one = integrate((x) => exp(-x), 0, double.infinity, depth: 30);
print(one); // 1.0000000904304227 ~ 1
```


Misc
----

### License

The MIT License, see [LICENSE](https://github.com/renggli/dart-data/raw/main/LICENSE).

Some of the matrix decomposition algorithms are a port of the [JAMA: A Java Matrix Package](https://math.nist.gov/javanumerics/jama/) released under public domain.

Some of the distributions and special functions are a port of the [JavaScript Statistical Library](https://github.com/jstat/jstat) released under MIT.

The Levenberg-Marquardt least squares curve fitting is a port of [levenberg-marquardt](https://github.com/mljs/levenberg-marquardt) released under MIT.