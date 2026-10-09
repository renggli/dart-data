# Subsystem Architecture: Core Architecture & Type System

## 1. Overview & Problem Analysis

`package:data` is designed to be a high-performance foundation for scientific computing, linear algebra, tensors, statistics, and tabular data analysis in Dart. However, the existing architecture and type hierarchy suffer from fundamental friction points that make the library awkward, error-prone, and difficult to integrate with external systems (such as ML frameworks, Apache Arrow, WebAssembly, and native BLAS/LAPACK).

### 1.1 Deficiencies in the Current Type Hierarchy

1. **Dual System Tension (`DataType<T>` vs. Native Dart Types)**:
   - Dart does not support generic specialization or user-defined value types (structs). To achieve unboxed performance with primitive arrays, the library introduces [`DataType<T>`](../lib/src/type/type.dart), which carries runtime functions for allocation (`newList`), equality, and field operations.
   - However, users must constantly pass `DataType<T>` explicitly across constructors (e.g. `Vector.type(DataType.float64, 10)`), or rely on dynamic dispatch and implicit inference that frequently collapses to `dynamic` or `Object`.
   - The type system requires verbose generic declarations like `Matrix<double>` where the inner data representation might be `Float64List`, `List<double>`, or `Float32List`, but the static type hides the actual memory layout.

2. **Incomplete Algebraic Abstraction (`Field<T>`)**:
   - [`Field<T>`](../lib/src/type/models/field.dart) models a mathematical field ($+$, $-$, $\times$, $/$, $0$, $1$, negation, inversion).
   - It is missing essential operations:
     - Absolute value / norm: `abs(T a) -> T`, `norm(T a) -> double`
     - Square root: `sqrt(T a) -> T`
     - Power & transcendental operations: `pow`, `exp`, `log`, `sin`, `cos`
     - Conjugate: `conjugate(T a) -> T` (vital for `Complex`)
   - Because `Field<T>` omits square roots and norms, algorithms like SVD, QR decomposition, Cholesky decomposition, and vector norms cannot be written generically over `Field<T>`. Instead, they are hardcoded specifically to `Matrix<num>` or `DataType.float` (`double`), preventing their use on `Complex`, `Fraction`, or custom high-precision numeric types.

3. **Flawed `BigIntField.scale` Rounding**:
   - In [`lib/src/type/impl/bigint.dart:69`](../lib/src/type/impl/bigint.dart#L69):

     ```dart
     @override
     BigInt scale(BigInt a, num f) => a * BigInt.from(f.round());
     ```

     `f` is prematurely truncated/rounded to an integer *before* multiplying by `a`. For example, `scale(BigInt.from(10), 0.4)` evaluates to `10 * 0 = 0`, whereas scaling by $0.4$ should yield $\approx 4$. In contrast, `IntegerField.scale` correctly computes `(a * f).round()`.

4. **Mutable Global Static State**:
   - In [`lib/src/type/type.dart:62-104`](../lib/src/type/type.dart#L62-L104):

     ```dart
     static IntegerDataType index = uint32;
     static IntegerDataType integer = int32;
     static FloatDataType float = float64;
     ```

   - These global mutable variables create race conditions across asynchronous execution contexts, isolate issues, and non-deterministic unit tests.

5. **Lack of Type Promotion**:
   - Binary operations between containers (e.g., adding `Tensor<int>` to `Tensor<double>`) are forbidden because operators enforce identical `T` types (`operator +(Tensor<T> other)`), forcing tedious manual conversions.

6. **Defunct `Storage` Abstraction & Memory Aliasing Bug**:
   - [`Storage`](../lib/src/shared/storage.dart) defines `Set<Storage> get storage;` across hundreds of matrix and vector views, but it is never checked during assignments or copies.
   - As a result, operations like `matrix.transposed.copyInto(matrix)` silently corrupt data due to unbuffered overlapping memory mutations. Meanwhile, `Tensor` does not even implement `Storage`.

---

## 2. Architectural Blueprint & Target Design

```text
+------------------------------------------------------------------------+
|                            User API Layer                              |
|   Extension Types: Float64Tensor, Int32Matrix, Float32Vector, Series   |
+------------------------------------------------------------------------+
                                    |
+------------------------------------------------------------------------+
|                     Unified Memory & Buffer Layer                      |
|  - StorageBuffer<T> (Dense flat buffer: TypedData or Native Pointer)   |
|  - StrideLayout (offset, shape, strides: ND, 2D, 1D)                  |
|  - Zero-copy aliasing tracking & view hierarchy                        |
+------------------------------------------------------------------------+
                                    |
        +---------------------------+---------------------------+
        |                                                       |
+------------------------------+        +------------------------------+
|     DataType<T> Registry     |        |   Hardware Acceleration      |
|  - Sealed DataType Hierarchy |        |   - Native FFI (BLAS/LAPACK) |
|  - AlgebraicField<T>         |        |   - SIMD (Float32x4)         |
|  - Type Promotion Matrix     |        |   - Pure Dart Fallback       |
+------------------------------+        +------------------------------+
```

### 2.1 Modernizing `DataType` with Class Modifiers & Sealed Hierarchies

Leveraging Dart 3.0+ `sealed` and `final` class modifiers ensures exhaustive type switching and eliminates invalid subtypes:

```dart
sealed class DataType<T> {
  const DataType();
  
  String get name;
  T get defaultValue;
  bool get isNullable => false;
  
  List<T> newList(int length, [T? fillValue]);
  
  Equality<T> get equality;
  Field<T>? get field => null;
  
  // Safe type promotion resolution
  DataType<Object?> promoteWith(DataType<Object?> other);
}

sealed class NumericDataType<T extends num> extends DataType<T> {
  const NumericDataType();
  @override
  NumericField<T> get field;
}

final class Float64DataType extends NumericDataType<double> {
  const Float64DataType();
  @override
  String get name => 'float64';
  @override
  Float64List newList(int length, [double? fillValue]) => ...;
}
```

### 2.2 Extended Algebraic Interface: `AlgebraicField<T>`

We upgrade `Field<T>` to provide standard numerical requirements:

```dart
abstract interface class Field<T> {
  T get zero;
  T get one;
  T add(T a, T b);
  T sub(T a, T b);
  T mul(T a, T b);
  T div(T a, T b);
  T neg(T a);
  T inv(T a);
  T scale(T a, num factor);
}

abstract interface class ExtendedField<T> implements Field<T> {
  T abs(T a);
  double norm(T a);
  T sqrt(T a);
  T pow(T base, T exponent);
  T exp(T a);
  T log(T a);
  T conjugate(T a); // Identity for real numbers, (r, -i) for complex
}
```

`IntegerField.scale` is corrected:

```dart
@override
int scale(int a, num f) => (a * f).round();
```

### 2.3 Elimination of Mutable Static State

Replace mutable global defaults with immutable constants:

```dart
abstract final class DataTypeDefaults {
  static const IntegerDataType index = DataType.uint32;
  static const IntegerDataType integer = DataType.int32;
  static const FloatDataType float = DataType.float64;
}
```

For applications requiring custom precision defaults (e.g. running neural networks on `float32`), use scoped zones:

```dart
T withDefaultFloat<T>(FloatDataType type, T Function() computation) {
  return runZoned(computation, zoneValues: {#data_default_float: type});
}
```

### 2.4 Ergonomic Zero-Cost Views via Extension Types

Dart 3.3+ extension types allow developers to write natural, statically-typed code without heap allocation overhead:

```dart
extension type Float64Tensor(Tensor<double> _tensor) implements Tensor<double> {
  Float64List get asTypedList => _tensor.buffer as Float64List;
  
  Float64Tensor operator +(Float64Tensor other) {
    // Direct dispatch to SIMD or BLAS-accelerated vector addition
    return Float64Tensor(_acceleratedAdd(_tensor, other._tensor));
  }
}

extension type Float64Matrix(Matrix<double> _matrix) implements Matrix<double> {
  Float64Matrix operator *(Float64Matrix other) {
    return Float64Matrix(_blasGemm(_matrix, other._matrix));
  }
}
```

### 2.5 Robust Aliasing Detection & Memory Safety

Every container holds a reference to an underlying memory block:

```dart
abstract interface class MemoryBuffer {
  int get byteLength;
  int get id; // Unique buffer instance ID
  bool overlaps(MemoryBuffer other, int offset, int otherOffset, int length);
}

abstract class Storage {
  List<int> get shape;
  MemoryBuffer get memoryBuffer;
  bool sharesMemoryWith(Storage other);
}
```

In `copyInto(target)`:

```dart
if (sharesMemoryWith(target)) {
  // Overlapping aliased region detected: copy through a temporary buffer
  final temp = copy();
  temp._copyDirect(target);
} else {
  _copyDirect(target);
}
```

---

## 3. Prioritized Implementation Task List

| Task ID | Phase | Priority | Description | Verification / Success Criteria |
| :--- | :--- | :--- | :--- | :--- |
| **SYS-01** | Fixes | **P0** | Correct `BigIntField.scale` rounding order in `bigint.dart:69` to avoid premature integer truncation of scaling factor `f`. | Add unit test verifying `scale(BigInt.from(10), 0.4) == BigInt.from(4)`. |
| **SYS-02** | Refactor | **P0** | Replace mutable statics in `DataType` (`index`, `integer`, `float`) with `static const` fields or zone-scoped lookups. | Audit entire repo; ensure no mutable global state exists. |
| **SYS-03** | Interface | **P1** | Extend `Field<T>` with `ExtendedField<T>` containing `abs`, `norm`, `sqrt`, `pow`, `exp`, `log`, `conjugate`. | Implement on `FloatDataType`, `ComplexDataType`, `FractionDataType`, `BigIntDataType`. |
| **SYS-04** | Aliasing | **P1** | Connect `Storage` to aliasing detection; implement buffer identity check in `Matrix.copyInto` and `Tensor.copyInto`. | Test `matrix.transposed.copyInto(matrix)` to ensure no corrupted cells. |
| **SYS-05** | Type System | **P1** | Implement `promoteWith(other)` across all numeric data types to support mixed-type container arithmetic. | Unit tests: `int32 + float64 -> float64`, `int32 + int64 -> int64`. |
| **SYS-06** | Dart 3 Modifiers | **P2** | Apply `sealed`, `base`, `final`, `interface` modifiers to `DataType`, `Field`, `Storage`, and `Equality`. | Verify analyzer passes with strict type checking and exhaustive switch support. |
| **SYS-07** | Ergonomics | **P2** | Introduce zero-cost extension types (`Float64Tensor`, `Float32Tensor`, `Float64Matrix`, `Float64Vector`) for typed performance. | Benchmarks demonstrate zero heap allocation compared to primitive types. |
