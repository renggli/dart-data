# Dart Data

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

## Tutorial

Below are step-by-step instructions of how to use this library. More elaborate examples are included with the [examples](https://github.com/renggli/dart-data/tree/main/example).

### Installation

Follow the installation instructions on [dart packages](https://pub.dev/packages/data/install).

Import the core-package into your Dart code using:

```dart
import 'dart:math';

import 'package:data/data.dart';
import 'package:more/printer.dart';
```

### How to solve a linear equation?

Solve $A \cdot x = b$, where $A$ is a matrix and $b$ a vector:

```dart
final a = Matrix<double>.fromRows([
  [2.0, 1.0],
  [1.0, 3.0],
]);
final b = Vector<double>.fromList([4.0, 7.0]);
final x = a.solve(b);
print(x); // Vector([1.0, 2.0])
```

### How to work with multi-dimensional tensors?

Dense multi-dimensional arrays backed by strided layouts and eager operations:

```dart
final t = Tensor<double>.fromObject([
  [1.0, 2.0],
  [3.0, 4.0],
]);
final product = t.matmul(t);
print(product.toNestedList()); // [[7.0, 10.0], [15.0, 22.0]]
```

### How to process columnar tabular data (DataFrame)?

Arrow-aligned `DataFrame` with streaming CSV parsing and relational joins:

```dart
final df = DataFrame.fromCsv('''
name,age,salary
Alice,30,75000.5
Bob,25,50000.0
Charlie,35,90000.0
''');

final filtered = df.filterBy((row) => (row['age'] as int) >= 30);
print(filtered);
```

### How to perform exact symbolic differentiation & JIT compilation?

Symbolic expression graphs, exact analytical differentiation, and zero-allocation JIT loops:

```dart
final x = Variable('x');
final expr = x * x + Sin(x);
final deriv = expr.diff('x').simplify();
print(deriv.toLatex()); // (2 * x) + \cos(x)

final fastFn = expr.compile1D('x');
print(fastFn(0.0)); // 0.0
```

### License

The MIT License, see [LICENSE](https://github.com/renggli/dart-data/raw/main/LICENSE).

Some of the matrix decomposition algorithms are a port of the [JAMA: A Java Matrix Package](https://math.nist.gov/javanumerics/jama/) released under public domain.

- In particular, the singular value decomposition algorithm comes from the [Math.Net Numerics](https://github.com/mathnet/mathnet-numerics) released under MIT.

Some of the distributions and special functions are a port of the [JavaScript Statistical Library](https://github.com/jstat/jstat) released under MIT.

The Levenberg-Marquardt least squares curve fitting is a port of [levenberg-marquardt](https://github.com/mljs/levenberg-marquardt) released under MIT.
