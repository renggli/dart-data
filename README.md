Dart Data
=========

[![Pub Package](https://img.shields.io/pub/v/data.svg)](https://pub.dev/packages/data)
[![Build Status](https://travis-ci.org/renggli/dart-data.svg)](https://travis-ci.org/renggli/dart-data)
[![Coverage Status](https://coveralls.io/repos/renggli/dart-data/badge.svg)](https://coveralls.io/r/renggli/dart-data)
[![GitHub Issues](https://img.shields.io/github/issues/renggli/dart-data.svg)](https://github.com/renggli/dart-data/issues)
[![GitHub Forks](https://img.shields.io/github/forks/renggli/dart-data.svg)](https://github.com/renggli/dart-data/network)
[![GitHub Stars](https://img.shields.io/github/stars/renggli/dart-data.svg)](https://github.com/renggli/dart-data/stargazers)
[![GitHub License](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/renggli/dart-data/master/LICENSE)

Dart Data is a fast and space efficient library to deal with data in Dart, Flutter and the web. As of today this mostly includes data structures and algorithms for vectors and matrices, but at some point might also include graphs and other mathematical structures.

This library is open source, stable and well tested. Development happens on [GitHub](https://github.com/renggli/dart-data). Feel free to report issues or create a pull-request there. General questions are best asked on [StackOverflow](https://stackoverflow.com/questions/tagged/data+dart).

The package is hosted on [dart packages](https://pub.dev/packages/data). Up-to-date [class documentation](https://pub.dev/documentation/data/latest/) is created with every release.


Tutorial
--------

Below are step-by-step instructions of how to use this library. More elaborate examples are included with the [examples](https://github.com/renggli/dart-data/tree/master/example).

### Installation

Follow the installation instructions on [dart packages](https://pub.dev/packages/data#-installing-tab-).

Import the packages into your Dart code using:

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

Misc
----

### License

The MIT License, see [LICENSE](https://github.com/renggli/dart-data/raw/master/LICENSE).

The matrix decomposition algorithms are a direct port of the [JAMA: A Java Matrix Package](https://math.nist.gov/javanumerics/jama/), that is released under public domain.
