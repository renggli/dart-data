# Implementation Roadmap & Task Specifications

This document defines the prioritized, actionable engineering roadmap for `package:data`. Tasks are ordered by execution dependency and priority:

- **P0**: Critical functional bug fixes and micro-architectural performance bottlenecks.
- **P1**: High-impact robustness improvements, core API completions, and memory optimizations.
- **P2**: Subsystem extensions, advanced numerical methods, and symbolic calculus.
- **P3**: External interoperability, Arrow streaming/IPC interfaces, and graph data structures.

---

## Priority 0: Critical Functional Bugs & Micro-Architectural Bottlenecks

### Task 0.1: Direct Fast-Path Indexing on `Matrix` and `Vector` (Fix Scalar Read/Write Heap Allocations)

- **Problem / Goal**:
  In `lib/src/linear/matrix.dart` and `lib/src/linear/vector.dart`:
  - `Matrix.get(row, col)` calls `tensor.getValue([row, col])`.
  - `Matrix.set(row, col, value)` calls `tensor.setValue([row, col], value)`.
  - `Vector[index]` calls `tensor.data[tensor.layout.toIndex([index])]`.
  Every single scalar read/write allocates a heap `List<int>` literal (`[row, col]` or `[index]`). In a $1000 \times 1000$ matrix loop or inside iterative matrix decomposition routines (LU, QR, Cholesky, SVD, Eigenvalue), this creates millions of ephemeral heap objects, inducing severe GC thrashing and degrading execution speeds by $40\times - 100\times$ compared to raw typed arrays.
- **The Win**:
  - Eliminates 100% of heap allocations during scalar element indexing.
  - Accelerates pure-Dart matrix factorizations and scalar traversal to near raw `Float64List` speeds.
- **Target Files**:
  - `lib/src/linear/matrix.dart`
  - `lib/src/linear/vector.dart`
  - `lib/src/tensor/tensor.dart`
  - `lib/src/linear/decomposition/lu.dart`
  - `lib/src/linear/decomposition/qr.dart`
  - `lib/src/linear/decomposition/cholesky.dart`
  - `lib/src/linear/decomposition/svd.dart`
  - `lib/src/linear/decomposition/eigenvalue.dart`
  - `test/linear/matrix_test.dart`
  - `test/linear/vector_test.dart`
- **Step-by-Step Implementation Details**:
  1. In `lib/src/tensor/tensor.dart`, add unchecked direct indexers for rank-1 and rank-2 layouts:

     ```dart
     @pragma('vm:prefer-inline')
     T get2D(int r, int c) => data[layout.offset + r * layout.strides[0] + c * layout.strides[1]];

     @pragma('vm:prefer-inline')
     void set2D(int r, int c, T value) =>
         data[layout.offset + r * layout.strides[0] + c * layout.strides[1]] = value;

     @pragma('vm:prefer-inline')
     T get1D(int index) => data[layout.offset + index * layout.strides[0]];

     @pragma('vm:prefer-inline')
     void set1D(int index, T value) =>
         data[layout.offset + index * layout.strides[0]] = value;
     ```

  2. In `lib/src/linear/matrix.dart`:
     - Expose `getUnchecked(int row, int col)` and `setUnchecked(int row, int col, T value)` calling `tensor.get2D` and `tensor.set2D`.
     - Update `get(row, col)` and `set(row, col, value)` to validate bounds directly (`0 <= row < rowCount` and `0 <= col < colCount`) and call `getUnchecked` / `setUnchecked` without allocating `[row, col]`.
     - Add Dart 3 Record indexing `T operator []((int row, int col) pos) => get(pos.$1, pos.$2);` and `void operator []=((int row, int col) pos, T value) => set(pos.$1, pos.$2, value);` to provide clean `matrix[(r, c)]` syntax without heap allocations.
  3. In `lib/src/linear/vector.dart`:
     - Expose `getUnchecked(int index)` and `setUnchecked(int index, T value)` calling `tensor.get1D` and `tensor.set1D`.
     - Update `operator [](int index)` and `operator []=(int index, T value)` to validate bounds directly and call `getUnchecked` / `setUnchecked`.
  4. In `lib/src/linear/decomposition/*.dart`:
     - Refactor inner computational loops in `LU`, `QR`, `Cholesky`, `SVD`, and `Eigenvalue` to utilize `getUnchecked` and `setUnchecked`.
  5. Run `dart test test/linear/` to verify zero regression and measure performance gains.

---

### Task 0.2: Target Shape Validation in `Tensor.binaryOperation` and `Tensor.unaryOperation`

- **Problem / Goal**:
  In `lib/src/tensor/operations/operation.dart`:
  - Contiguous fast path (`lines 92-132`) and broadcasting branch (`lines 156-196`) verify only rank equality (`target.layout.shape.length == layout.shape.length`), never validating that each dimension matches.
  - If a target has shape `[2, 6]` and operands have shape `[3, 4]`, it erroneously takes the contiguous fast path and overwrites memory out-of-bounds or produces index corruption.
  - In the broadcast path, when `target != null` has mismatched dimensions, `targetIter.moveNext()` terminates prematurely without throwing, leaving trailing elements uninitialized or truncating output.
  - In `Tensor.unaryOperation`, only rank length is checked, permitting corrupted index calculations for mismatched dimensions.
- **The Win**:
  - Complete protection against silent memory corruption and truncated tensor outputs.
  - Explicit, informative `LayoutError` or `ArgumentError` exceptions thrown on dimension mismatches.
- **Target Files**:
  - `lib/src/tensor/operations/operation.dart`
  - `test/tensor/operation_test.dart`
- **Step-by-Step Implementation Details**:
  1. In `Tensor.unaryOperation`:
     - Replace `if (target.layout.shape.length != layout.shape.length)` with:

       ```dart
       LayoutError.checkEqualShape(layout, target.layout, 'target');
       ```

  2. In `Tensor.binaryOperation`:
     - In the contiguous check, verify exact shape equality:

       ```dart
       final isTargetMatching = target == null ||
           (target.layout.isContiguous &&
            target.layout.offset == 0 &&
            target.layout.shape.length == layout.shape.length &&
            _areShapesEqual(target.layout.shape, layout.shape));
       ```

     - In the general broadcasting path when `target != null`:

       ```dart
       final expectedShape = thisLayout.shape; // broadcasted shape
       if (!_areShapesEqual(target.layout.shape, expectedShape)) {
         throw ArgumentError(
           'Target shape ${target.layout.shape} does not match broadcasted shape $expectedShape',
         );
       }
       ```

  3. Add unit tests in `test/tensor/operation_test.dart` asserting that passing targets with matching rank but mismatched dimension sizes (e.g. `[2, 6]` vs `[3, 4]`) throws `ArgumentError` in both unary and binary operations.

---

### Task 0.3: Multi-RHS Column-Major Layout Correction in Fortran `dgesv`

- **Problem / Goal**:
  In `lib/src/hardware/cblas_ffi.dart` (`lines 1167-1195`):
  When falling back to Fortran `_dgesv`, matrix `a` is correctly transposed to column-major format (`aTrans[j * n + i] = a[...]`). However, right-hand side matrix `b` of shape $[N \times \text{nrhs}]$ is copied directly as row-major data into `bPtr`, while `ldb` is passed as $N$.
  For $\text{nrhs} > 1$, row-major element $(i, j)$ is at index $i \cdot \text{nrhs} + j$, whereas Fortran column-major expects index $j \cdot N + i$. This transposes the RHS problem and yields corrupted solutions.
- **The Win**:
  - Correct, mathematically sound multi-RHS linear solves when dispatching to Fortran LAPACK routines.
- **Target Files**:
  - `lib/src/hardware/cblas_ffi.dart`
  - `test/hardware/cblas_test.dart`
  - `test/linear/decomposition/lu_test.dart`
- **Step-by-Step Implementation Details**:
  1. In `cblas_ffi.dart` around `_dgesv` invocation:
     - Check if `nrhs > 1`.
     - When `nrhs > 1`, transpose `b` from row-major $[N \times \text{nrhs}]$ into column-major scratch buffer before copying to `bPtr`:

       ```dart
       for (var j = 0; j < nrhs; j++) {
         for (var i = 0; i < n; i++) {
           bColMajor[j * n + i] = b[i * nrhs + j];
         }
       }
       ```

     - After `_dgesv` successfully returns, transpose the solution back from `bPtr` into row-major result buffer:

       ```dart
       for (var i = 0; i < n; i++) {
         for (var j = 0; j < nrhs; j++) {
           result[i * nrhs + j] = bPtr[j * n + i];
         }
       }
       ```

  2. For `nrhs == 1`, keep the existing zero-copy flat copy fast-path.
  3. Add a test in `test/hardware/cblas_test.dart` solving a system with $N = 4$ and $\text{nrhs} = 3$, comparing Fortran LAPACK output against pure-Dart LU solve.

---

### Task 0.4: Safe Composite Keys in `DataFrame.join` and `GroupBy`

- **Problem / Goal**:
  In `lib/src/dataframe/join.dart` and `lib/src/dataframe/groupby.dart`:
  Multi-column keys are serialized as:

  ```dart
  final keyStr = keyVals.map((v) => '$v').join('__#_#__');
  ```

  - **Null collision**: A `null` value serializes to `'null'`, identical to the string `'null'`.
  - **Type erasure**: Numeric `1`, float `1.0`, and string `'1'` collide depending on formatting.
  - **Separator injection**: If any string contains `__#_#__`, distinct row keys falsely match.
- **The Win**:
  - Eliminates all key collisions and delimiter injection vulnerabilities in joins and group-by aggregations.
  - Improves grouping performance by eliminating string allocations and string interpolations per row.
- **Target Files**:
  - `lib/src/dataframe/join.dart`
  - `lib/src/dataframe/groupby.dart`
  - `lib/src/dataframe/tuple_key.dart` (new)
  - `test/dataframe/join_test.dart`
  - `test/dataframe/groupby_test.dart`
- **Step-by-Step Implementation Details**:
  1. Create `lib/src/dataframe/tuple_key.dart`:

     ```dart
     import 'package:collection/collection.dart';

     final class TupleKey {
       final List<Object?> values;
       final int _hashCode;

       TupleKey(this.values) : _hashCode = const DeepCollectionEquality().hash(values);

       @override
       bool operator ==(Object other) =>
           identical(this, other) ||
           (other is TupleKey &&
            const DeepCollectionEquality().equals(values, other.values));

       @override
       int get hashCode => _hashCode;
     }
     ```

     For common cases ($1$, $2$, or $3$ keys), provide specialized zero-allocation record-based key extraction:
     - 1 key: direct value `keyVals[0]`.
     - 2 keys: `(keyVals[0], keyVals[1])`.
     - 3 keys: `(keyVals[0], keyVals[1], keyVals[2])`.
     - $> 3$ keys: fallback to `TupleKey(keyVals)`.
  2. Refactor `lib/src/dataframe/join.dart` to use `Map<Object?, List<int>>` instead of `Map<String, List<int>>`.
  3. Refactor `lib/src/dataframe/groupby.dart` to index groups with `Object?` keys.
  4. Add tests asserting proper handling of `null` vs `'null'`, integer `1` vs string `'1'`, and strings containing delimiter sequences.

---

### Task 0.5: Proper Separator Escaping in `CsvWriter`

- **Problem / Goal**:
  In `lib/src/dataframe/csv.dart` (`_escape`):
  The code hardcodes:

  ```dart
  if (field.contains(',') || field.contains('"') || field.contains('\n') || field.contains('\r'))
  ```

  regardless of the `separator` parameter passed to `write(df, separator: ...)`.
  When writing TSV (separator: `\t`) or semicolon-delimited CSV (separator: `;`), fields containing tabs or semicolons are not escaped with quotes, corrupting the exported file structure.
- **The Win**:
  - Guarantees RFC 4180-compliant export for all custom delimiters (TSV, semicolons, pipes).
- **Target Files**:
  - `lib/src/dataframe/csv.dart`
  - `test/dataframe/csv_test.dart`
- **Step-by-Step Implementation Details**:
  1. Update `_escape` in `CsvWriter`:

     ```dart
     String _escape(String field, String separator) {
       if (field.contains(separator) ||
           field.contains('"') ||
           field.contains('\n') ||
           field.contains('\r')) {
         return '"${field.replaceAll('"', '""')}"';
       }
       return field;
     }
     ```

  2. Pass `separator` to `_escape` for all header names and row string cells.
  3. Add unit tests in `test/dataframe/csv_test.dart` verifying TSV export of fields containing tabs and semicolon-separated export of fields containing semicolons.

---

## Priority 1: High-Impact Robustness, Performance & Core API Completions

### Task 1.1: Zero-Allocation Slicing & Filtering in `TypedSeries` & Bulk Column Copies in `DataFrame.toTensor` / `toMatrix`

- **Problem / Goal**:
  - `TypedSeries.filter` and `TypedSeries.slice` currently accumulate elements into growable `List<T?>` lists before calling `TypedSeries.fromList`. This boxes primitive doubles/ints and traverses lists twice.
  - `DataFrame.toTensor` and `toMatrix` use cell-by-cell loops calling `tensor.setValue([i, j], numVal)` with `is num` checks.
- **The Win**:
  - Apache Arrow-grade unboxed memory filtering and zero-allocation slicing for numeric series.
  - $15\times - 30\times$ faster conversion from DataFrame columns to Tensors and Matrices via direct buffer block copies (`setRange`).
  - Eliminates repetitive `!` null assertion friction for callers querying known non-null series (`nullCount == 0`).
- **Target Files**:
  - `lib/src/dataframe/series.dart`
  - `lib/src/dataframe/dataframe.dart`
  - `test/dataframe/series_test.dart`
  - `test/dataframe/dataframe_test.dart`
- **Step-by-Step Implementation Details**:
  1. In `TypedSeries<T>`:
     - Implement `filter` by counting valid `true` entries in `filterMask`, pre-allocating target `TypedData` of exact length via `dataType.newList(count)`, copying unboxed elements directly, and constructing the new `ValidityMask`.
     - Implement `slice(start, end)` by slicing the underlying typed list directly (`data.sublist(start, end)`) and slicing `validityMask.slice(start, end)`.
     - Expose `T getNonNull(int index)` and `T getUnchecked(int index)` for zero-overhead scalar access without nullable `T?` checks when `hasNulls == false`.
  2. In `DataFrame.toTensor`:
     - If all requested columns are `TypedSeries<double>` and target tensor is float64 row-major:
       - Transpose target layout or perform column-stride buffer copies using `Float64List.setRange` or flat indexed loops without `List<int>` coordinates.
  3. Add unit and performance tests verifying unboxed retention and bitmask alignment.

---

### Task 1.2: Zone-Scoped Precision & Native Frames (`withDefault`)

- **Problem / Goal**:
  Default data types are currently static constants on `DefaultDataType`. Concurrency isolates, ML pipelines, and graphics tasks need to configure floating-point precision (`float32` vs `float64`), integer precision (`int32` vs `int64`), and native off-heap storage frames without mutating global state.
- **The Win**:
  - Thread-safe, isolate-safe execution context configuration via a single unified API:
    `R withDefault<R>({IntegerDataType? integer, FloatDataType? float, bool? native}, R Function() computation)`
  - Seamless switching between standard managed typed buffers and native off-heap frames for GPU/FFI workloads.
- **Target Files**:
  - `lib/src/type/default_data_type.dart`
  - `lib/src/type/data_type.dart`
  - `lib/src/tensor/tensor.dart`
  - `lib/src/linear/matrix.dart`
  - `test/type/default_data_type_test.dart`
- **Step-by-Step Implementation Details**:
  1. In `lib/src/type/default_data_type.dart`, define zone keys:

     ```dart
     const Symbol _defaultFloatZoneKey = #data_default_float;
     const Symbol _defaultIntegerZoneKey = #data_default_integer;
     const Symbol _defaultNativeZoneKey = #data_default_native;
     ```

  2. Implement `withDefault<R>`. In Dart, named parameters cannot precede positional arguments in a formal parameter list. Provide the standard positional closure pattern (matching `runZoned(body, ...)`) allowing trailing closures, or the named closure pattern:

     ```dart
     /// Standard Dart pattern with trailing closure:
     R withDefault<R>(
       R Function() computation, {
       IntegerDataType? integer,
       FloatDataType? float,
       bool? native,
     }) {
       final zoneValues = <Symbol, Object?>{};
       if (integer != null) zoneValues[_defaultIntegerZoneKey] = integer;
       if (float != null) zoneValues[_defaultFloatZoneKey] = float;
       if (native != null) zoneValues[_defaultNativeZoneKey] = native;
       return runZoned(computation, zoneValues: zoneValues);
     }
     ```

     Also support named parameter invocation where `computation` is passed as a named argument.
  3. Update getters on `DefaultDataType`:
     - `static FloatDataType get float => Zone.current[_defaultFloatZoneKey] as FloatDataType? ?? DataType.float64;`
     - `static IntegerDataType get integer => Zone.current[_defaultIntegerZoneKey] as IntegerDataType? ?? DataType.int32;`
     - `static bool get isNative => Zone.current[_defaultNativeZoneKey] as bool? ?? false;`
  4. Wire default constructors of `Tensor` and `Matrix` to respect `DefaultDataType.isNative` when allocating buffers if no explicit storage type is passed.
  5. Add unit tests verifying zone scoping, nested zone restoration, and default container allocations.

---

### Task 1.3: Dart 3 Class Modifiers on Core Type & Field Classes

- **Problem / Goal**:
  `DataType<T>`, `Field<T>`, `ExtendedField<T>`, and `Equality<T>` are currently plain abstract classes. Per user architectural constraints, `sealed` must be avoided to allow modular declarations across different library files. However, `base`, `interface`, and `final` modifiers should be applied to prevent arbitrary third-party extension while preserving modularity.
- **The Win**:
  - Robust API boundaries enforcing explicit `implements` for fields and strict extension rules for data types across files without `sealed` file-confinement limits.
- **Target Files**:
  - `lib/src/type/data_type.dart`
  - `lib/src/type/models/field.dart`
  - `lib/src/type/models/equality.dart`
  - `lib/src/type/types/*.dart`
- **Step-by-Step Implementation Details**:
  1. In `lib/src/type/data_type.dart`:
     - Change `abstract class DataType<T>` to `abstract base class DataType<T>`.
     - Change numeric categories to `abstract base class NumericDataType<T extends num> extends DataType<T>`.
  2. In `lib/src/type/types/*.dart`:
     - Mark built-in concrete data type classes (`Float64DataType`, `Int32DataType`, `ComplexDataType`, etc.) as `final class`.
  3. In `lib/src/type/models/field.dart`:
     - Mark `abstract interface class Field<T>`.
     - Mark `abstract interface class ExtendedField<T> implements Field<T>`.
  4. In `lib/src/type/models/equality.dart`:
     - Mark `abstract interface class Equality<T>`.
  5. Run `dart analyze` to verify clean compilation across the entire codebase.

---

### Task 1.4: Multi-Axis Strided Tensor Slicing (`Tensor.slice`, `Slice`) & Axis Splitting (`split`, `splitWithSizes`)

- **Problem / Goal**:
  Tensors only provide 1D sub-range views along single axes (`getRange`). Multi-axis slicing with step strides and axis partitioning are missing.
- **The Win**:
  - Zero-copy NumPy-grade multidimensional strided slicing: `tensor.slice([Slice(0, 10, step: 2), Slice.all, Slice(5, 15)])`.
  - Zero-copy axis splitting for mini-batches and multi-head attention projection.
- **Target Files**:
  - `lib/src/tensor/layout.dart`
  - `lib/src/tensor/tensor.dart`
  - `lib/src/tensor/operations/manipulation.dart`
  - `test/tensor/tensor_test.dart`
  - `test/tensor/manipulation_test.dart`
- **Step-by-Step Implementation Details**:
  1. In `lib/src/tensor/layout.dart`:
     - Define `Slice` class with `start`, `end`, `step` (default 1) and `static const all = Slice()`.
     - Implement `Layout.slice(List<Slice> slices)` recalculating `offset`, `shape`, and `strides`.
  2. In `lib/src/tensor/tensor.dart`:
     - Expose `Tensor<T> slice(List<Slice> slices) => Tensor<T>(layout: layout.slice(slices), data: data, type: type);`.
  3. In `lib/src/tensor/operations/manipulation.dart`:
     - Implement `split(int parts, {int axis = 0})` using existing zero-copy `getRange`.
     - Implement `splitWithSizes(List<int> splitSizes, {int axis = 0})`.
  4. Add unit tests verifying non-contiguous stride indexing, negative steps, and shape preservation.

---

### Task 1.5: Vector Cumulative Operations (`cumsum`, `cumprod`) & Projection / Rejection (`project`, `reject`)

- **Problem / Goal**:
  `Vector` lacks prefix scans (`cumsum`, `cumprod`) and orthogonal geometric decomposition routines (`project`, `reject`).
- **The Win**:
  - $\mathcal{O}(N)$ single-pass prefix scans without intermediate lists.
  - Numerically stable orthogonal projection and rejection with zero-division error handling.
- **Target Files**:
  - `lib/src/linear/vector.dart`
  - `test/linear/vector_test.dart`
- **Step-by-Step Implementation Details**:
  1. In `lib/src/linear/vector.dart`:
     - Implement `Vector<T> cumsum({Vector<T>? target})`:
       Traverses contiguous `data` or strided elements, maintaining accumulator `acc = field.add(acc, current)`.
     - Implement `Vector<T> cumprod({Vector<T>? target})`:
       Initializes accumulator with `field.multiplicativeIdentity`, updating with `field.mul`.
  2. Implement projection methods on `Vector<T extends num>`:
     - `Vector<double> project(Vector<T> onto)`: computes $\frac{\langle u, v \rangle}{\|v\|_2^2} v$. Throws `ArgumentError` if $\|v\|_2^2 < 1\text{e-}15$.
     - `Vector<double> reject(Vector<T> from)`: computes `this - project(from)`.
  3. Add unit tests testing integer/float cumulative scans and orthogonal geometric projections.

---

### Task 1.6: Tridiagonal / Banded Linear Solvers (Thomas Algorithm)

- **Problem / Goal**:
  Tridiagonal linear systems $A x = d$ currently fall back to dense $\mathcal{O}(N^3)$ LU decomposition or iterative solvers. `CubicSpline` in `lib/src/numeric/interpolation.dart` creates and solves an $N \times N$ dense system.
- **The Win**:
  - Solves tridiagonal systems of size $N = 100,000$ in $<10\text{ ms}$ with $\mathcal{O}(N)$ time and $\mathcal{O}(1)$ auxiliary space.
  - Accelerates `CubicSpline` setup by orders of magnitude.
- **Target Files**:
  - `lib/src/linear/solvers/tridiagonal.dart` (new)
  - `lib/src/numeric/interpolation.dart`
  - `lib/linear.dart`
  - `test/linear/solvers/tridiagonal_test.dart` (new)
  - `test/numeric/interpolation_test.dart`
- **Step-by-Step Implementation Details**:
  1. Create `lib/src/linear/solvers/tridiagonal.dart`:

     ```dart
     Vector<double> solveTridiagonal(
       Vector<double> sub,  // a_i: length N - 1
       Vector<double> diag, // b_i: length N
       Vector<double> sup,  // c_i: length N - 1
       Vector<double> rhs,  // d_i: length N
     ) { ... }
     ```

  2. Implement forward sweep computing modified coefficients $c'_i$ and $d'_i$, followed by back-substitution sweep computing $x_i$.
  3. Refactor `CubicSpline` in `lib/src/numeric/interpolation.dart` to formulate spline second derivatives as a tridiagonal system and solve via `solveTridiagonal`.
  4. Add unit tests for diagonally dominant, symmetric, and ill-conditioned tridiagonal systems.

---

### Task 1.7: Bit-Parallel Population Count & Incremental `nullCount` in `ValidityMask`

- **Problem / Goal**:
  `ValidityMask.nullCount` iterates from $0$ to $length - 1$ calling `isNull(i)` on every index, taking $\mathcal{O}(N)$ bit-by-bit calls.
- **The Win**:
  - $\mathcal{O}(1)$ null count query using an incremental counter or 64-bit Hamming weight (`popcount`) bitwise parallelism.
- **Target Files**:
  - `lib/src/dataframe/bitmask.dart`
  - `test/dataframe/bitmask_test.dart`
- **Step-by-Step Implementation Details**:
  1. Add an internal `int _nullCount` field to `ValidityMask`.
  2. Update `_nullCount` in `setNull(i)` and `setValid(i)` when the bit state changes.
  3. For bulk constructors (`fromList`), compute population count across 64-bit/32-bit words using bitwise popcount:

     ```dart
     int _popCount32(int x) {
       x = x - ((x >> 1) & 0x55555555);
       x = (x & 0x33333333) + ((x >> 2) & 0x33333333);
       return (((x + (x >> 4)) & 0x0F0F0F0F) * 0x01010101) >> 24;
     }
     ```

  4. Return `_nullCount` in $\mathcal{O}(1)$ time.

---

### Task 1.8: Unify Matrix Trace & Type-Safe Linear Decompositions (Eliminate Casting Friction)

- **Problem / Goal**:
  1. Instance member `Matrix<T>.trace` (returns `T`, enforces square matrix) shadows extension member `MatrixNormExtension<T>.trace` (returns `double`, allows rectangular).
  2. In `lib/src/linear/matrix.dart`, decomposition getters (`lu`, `qr`, `cholesky`, `svd`, `eigenvalue`) execute unsafe runtime downcasts `this as Matrix<num>`. When called on a generic or dynamically typed matrix (e.g. `Matrix<dynamic>`), Dart throws an unhandled `TypeError`.
- **The Win**:
  - Eliminates compiler ambiguity and provides a single definitive `trace` property.
  - Compile-time type safety for decomposition methods via typed extensions, preventing runtime downcast exceptions on non-numeric matrices.
- **Target Files**:
  - `lib/src/linear/matrix.dart`
  - `lib/src/linear/decomposition/norm.dart`
  - `test/linear/matrix_test.dart`
- **Step-by-Step Implementation Details**:
  1. Remove `double get trace` from `MatrixNormExtension` in `lib/src/linear/decomposition/norm.dart`.
  2. Retain `T get trace` on `Matrix<T>` in `lib/src/linear/matrix.dart`.
  3. Ensure documentation on `Matrix.trace` clarifies that it sums diagonal elements $A_{ii}$ for square matrices.
  4. Refactor decomposition getters (`lu`, `qr`, `cholesky`, `svd`, `eigenvalue`) on `Matrix<T>` to either:
     - Relocate to a typed extension `extension MatrixNumDecompositionExtension<T extends num> on Matrix<T>`, providing compile-time type-safety.
     - Add explicit runtime guards with clear exception messages (`throw StateError('Decompositions are only supported on numeric matrices.')`) instead of failing with raw `TypeError`.
  5. Add tests in `test/linear/matrix_test.dart` verifying proper behavior and clear error reporting.

---

## Priority 2: Subsystem Extensions & Advanced Algorithms

### Task 2.1: Symbolic Calculus Integration (`integrate`)

- **Problem / Goal**:
  The symbolic computation engine provides automated differentiation (`diff`), but lacks symbolic anti-differentiation (`integrate`). Users need exact integration for polynomial, power, exponential, trigonometric, and logarithmic expressions.
- **The Win**:
  - Closed-form symbolic anti-derivatives: `expr.integrate('x')`.
  - Analytical definite integrals `expr.integrate('x', a: 0, b: 1)` with automatic fallback to high-precision Gauss-Legendre quadrature when no closed-form anti-derivative exists.
- **Target Files**:
  - `lib/src/symbolic/calculus.dart`
  - `lib/src/symbolic/ast.dart`
  - `lib/symbolic.dart`
  - `test/symbolic/calculus_test.dart`
- **Step-by-Step Implementation Details**:
  1. In `lib/src/symbolic/calculus.dart`, define integration rules on `Expr`:
     - Constants: $\int c\,dx = c x$.
     - Variable: $\int x\,dx = \frac{1}{2} x^2$; $\int y\,dx = y x$ (for independent variable $y \ne x$).
     - Linear combinations: $\int (a f(x) + b g(x))\,dx = a \int f\,dx + b \int g\,dx$.
     - Power rule: $\int x^n\,dx = \frac{x^{n+1}}{n+1}$ for $n \ne -1$; $\int x^{-1}\,dx = \ln|x|$.
     - Exponentials: $\int e^{k x}\,dx = \frac{1}{k} e^{k x}$; $\int a^x\,dx = \frac{a^x}{\ln a}$.
     - Trigonometrics: $\int \sin(k x)\,dx = -\frac{\cos(k x)}{k}$; $\int \cos(k x)\,dx = \frac{\sin(k x)}{k}$.
  2. Implement substitution recognition for basic linear transforms $f(a x + b)$.
  3. Expose definite integral `integrate(variable, {num? from, num? to})`. If analytical integration fails or produces unevaluated forms, bridge to `gaussLegendreQuadrature` from `lib/src/numeric/calculus.dart`.
  4. Add unit tests for polynomials, powers, trig, exponentials, and definite integration.

---

### Task 2.2: Symbolic Taylor Series, LaTeX Formatting & Linearized Kernel JIT (`toLatex`, `taylorSeries`, `Polynomial.fromExpr`)

- **Problem / Goal**:
  Expressions cannot be exported to LaTeX math markup for display, nor can they be converted into local Taylor polynomial expansions. Furthermore, as noted in architectural evaluations, `compileTensorKernel` builds recursive closure trees (`fL(args) + fR(args)`) that execute multiple indirect calls per element ($3\times - 5\times$ slower than flat loops).
- **The Win**:
  - Publication-grade LaTeX serialization for Flutter equation widgets and documentation.
  - Bridge from symbolic expressions to high-speed numeric polynomials via Taylor series.
  - $3\times - 5\times$ faster tensor kernel evaluation by eliminating recursive closure tree dispatch.
- **Target Files**:
  - `lib/src/symbolic/latex.dart` (new)
  - `lib/src/symbolic/calculus.dart`
  - `lib/src/symbolic/compiler.dart`
  - `lib/src/polynomial/polynomial.dart`
  - `lib/symbolic.dart`
  - `test/symbolic/latex_test.dart` (new)
  - `test/symbolic/calculus_test.dart`
  - `test/symbolic/compiler_test.dart`
- **Step-by-Step Implementation Details**:
  1. Create `lib/src/symbolic/latex.dart`:
     Implement `String toLatex()` pattern-matching on `Expr` types with natural parenthesis rules and math formatting (`\frac{a}{b}`, `\sin(x)`, `x^{2}`, `\cdot`).
  2. In `lib/src/symbolic/calculus.dart`:
     Implement `Expr taylorSeries(String variable, {double around = 0.0, int order = 4})` computing coefficients $c_k = \frac{f^{(k)}(x_0)}{k!}$.
  3. In `lib/src/polynomial/polynomial.dart`:
     Implement `Polynomial.fromExpr(Expr expr, String variable, {double around = 0.0, int order = 4})`.
  4. In `lib/src/symbolic/compiler.dart`:
     Refactor `compileTensorKernel` to compile the AST into a linear instruction sequence (flattened bytecode / RPN stack evaluator) rather than recursive closure trees, avoiding per-element closure call overhead.
  5. Add unit tests for LaTeX formatting, Taylor approximations of $\sin(x)$, $\cos(x)$, and $e^x$, and linearized kernel execution.

---

### Task 2.3: Zero-Cost Extension Types (`Float64Tensor`, `Float64Matrix`, `Float64Vector`)

- **Problem / Goal**:
  Generic `Tensor<double>` and `Matrix<double>` incur polymorphic type dispatch and cannot expose direct `Float64List` indexing without downcasting.
- **The Win**:
  - Compile-time zero-cost abstractions in Dart 3.3+ wrapping typed arrays with zero heap indirection.
- **Target Files**:
  - `lib/src/type/extension_types.dart` (new)
  - `lib/tensor.dart`
  - `lib/linear.dart`
  - `lib/data.dart`
  - `test/type/extension_types_test.dart` (new)
- **Step-by-Step Implementation Details**:
  1. Create `lib/src/type/extension_types.dart`:
     - `extension type Float64Tensor(Tensor<double> _tensor) implements Tensor<double>`
     - `extension type Float64Matrix(Matrix<double> _matrix) implements Matrix<double>`
     - `extension type Float64Vector(Vector<double> _vector) implements Vector<double>`
  2. Expose `asTypedList` property providing direct access to underlying `Float64List`.
  3. Implement inlined operators routing directly to hardware BLAS/SIMD when contiguous.
  4. Add unit tests verifying compile-time zero-cost behavior and arithmetic correctness.

---

### Task 2.4: Complex Matrix Decompositions (`Matrix<Complex>`)

- **Problem / Goal**:
  Decompositions (LU, QR, Cholesky, SVD) currently require `Matrix<num>` or real scalars. Complex matrix factorizations are essential for quantum mechanics, AC circuits, and Fourier optics.
- **The Win**:
  - Exact $\mathbb{C}^{M \times N}$ arithmetic supporting Hermitian conjugate transpose $A^* = (A^T)^*$, unitary transformations, and complex Cholesky / QR / LU factorizations.
- **Target Files**:
  - `lib/src/linear/matrix.dart`
  - `lib/src/linear/decomposition/lu.dart`
  - `lib/src/linear/decomposition/cholesky.dart`
  - `lib/src/linear/decomposition/qr.dart`
  - `test/linear/decomposition/complex_decomposition_test.dart` (new)
- **Step-by-Step Implementation Details**:
  1. On `Matrix<T>`, add `Matrix<T> get conjugateTranspose` (and alias `H`) mapping elements through `type.field.conjugate`.
  2. Generalize `CholeskyDecomposition` to support Hermitian positive-definite matrices ($A = L L^*$).
  3. Generalize `QRDecomposition` using complex Householder reflectors: $v = x + \text{phase}(x_1) \|x\|_2 e_1$.
  4. Generalize `LUDecomposition` for complex field division.
  5. Add unit tests comparing results against known analytical complex matrix inverses and solves.

---

### Task 2.5: Pure-Dart Cache-Blocked Fallback GEMM

- **Problem / Goal**:
  For small matrices ($N < 64$), FFI leaf-call overhead exceeds execution time. On non-FFI platforms (Web/Wasm), naive 3-loop GEMM suffers severe CPU cache thrashing on larger matrices.
- **The Win**:
  - Cache-tiled matrix multiplication executing $2\times - 3\times$ faster on small dimensions and $4\times - 8\times$ faster on Flutter Web and Wasm.
- **Target Files**:
  - `lib/src/hardware/pure_dart_gemm.dart` (new)
  - `lib/src/linear/matrix.dart`
  - `test/hardware/gemm_test.dart` (new)
- **Step-by-Step Implementation Details**:
  1. Create `lib/src/hardware/pure_dart_gemm.dart`:
     Implement cache-blocked GEMM with $32 \times 32$ block tiles ($32 \times 32 \times 8\text{ bytes} = 8\text{ KB}$, fitting inside modern L1 data caches) with $4\times$ loop unrolling.
  2. In `Matrix.operator *`:
     If $N < 64$ or hardware FFI is unavailable, route float64/float32 multiplication to `cacheBlockedGemmFloat64`.
  3. Add performance and correctness tests comparing blocked GEMM output against CBLAS GEMM.

---

### Task 2.6: Extended BLAS Level 2/3 & LAPACK Symmetric Eigenvalue Bindings (`dtrmv`, `dsymm`, `dtrmm`, `dsyev`)

- **Problem / Goal**:
  Current FFI bindings omit triangular matrix solvers and symmetric eigenvalue routines.
- **The Win**:
  - Halved flop counts for symmetric and triangular operations.
  - $5\times - 10\times$ faster eigenvalue and eigenvector computation for real symmetric matrices (PCA, covariance matrices).
- **Target Files**:
  - `lib/src/hardware/cblas_ffi.dart`
  - `lib/src/hardware/cblas.dart`
  - `lib/src/linear/decomposition/eigenvalue.dart`
  - `test/hardware/cblas_test.dart`
- **Step-by-Step Implementation Details**:
  1. In `cblas_ffi.dart`, bind:
     - `cblas_dtrmv` / `cblas_strmv` (triangular matrix-vector multiplication).
     - `cblas_dsymm` / `cblas_ssymm` (symmetric matrix multiplication).
     - `cblas_dtrmm` / `cblas_strmm` (triangular matrix multiplication).
     - `dsyev_` / `ssyev_` (LAPACK symmetric eigenvalue solver).
  2. In `lib/src/linear/decomposition/eigenvalue.dart`:
     If matrix is symmetric and hardware acceleration is available, route to LAPACK `dsyev` divide-and-conquer algorithm.
  3. Add tests verifying orthonormal eigenvector extraction ($V^T V = I$) and eigenvalue ordering.

---

### Task 2.7: Missing GroupBy Aggregations (`Agg.median`, `Agg.var_`) with Running Accumulators

- **Problem / Goal**:
  `GroupBy.aggregate` lacks median and sample variance aggregations, and computes aggregates by allocating temporary lists.
- **The Win**:
  - Complete descriptive statistics suite within grouped data workflows.
  - Single-pass Welford algorithm for variance and in-place Quickselect for median without extra heap allocations.
- **Target Files**:
  - `lib/src/dataframe/groupby.dart`
  - `test/dataframe/groupby_test.dart`
- **Step-by-Step Implementation Details**:
  1. Add `Agg.median` and `Agg.var_` to `enum Agg`.
  2. Implement single-pass Welford variance tracking running mean and sum of squared differences over valid entries in each group bucket.
  3. Implement Quickselect for `Agg.median` operating on a reused group scratch buffer.
  4. Add unit tests testing grouped median and variance calculations against known statistical baselines.

---

### Task 2.8: JSON Import & Export Serialization for DataFrame

- **Problem / Goal**:
  `DataFrame` only supports CSV import and export. Web services and REST endpoints require standard JSON formats.
- **The Win**:
  - Support for industry standard DataFrame JSON orientations (`records`, `split`, `columns`, `values`).
- **Target Files**:
  - `lib/src/dataframe/json.dart` (new)
  - `lib/dataframe.dart`
  - `test/dataframe/json_test.dart` (new)
- **Step-by-Step Implementation Details**:
  1. Create `lib/src/dataframe/json.dart`:
     - Define `enum JsonOrient { records, split, columns, values }`.
     - Implement `String toJson({JsonOrient orient = JsonOrient.records})`.
     - Implement `List<Map<String, dynamic>> toRecords()`.
     - Implement `static DataFrame fromJson(String source, {JsonOrient orient, Map<String, DataType>? columnTypes})`.
     - Implement `static DataFrame fromRecords(Iterable<Map<String, dynamic>> records)`.
  2. Export from `lib/dataframe.dart`.
  3. Add unit tests verifying round-trip serialization across all four orientations.

---

### Task 2.9: Constrained Optimization with Box Bounds & Penalty Methods (`minimizeConstrained`)

- **Problem / Goal**:
  Current optimizers (`bfgs`, `nelderMead`) are unconstrained. Model parameters can drift into non-physical or mathematically invalid regions (e.g. negative variance, probabilities outside $[0, 1]$).
- **The Win**:
  - Bounded optimization guaranteeing solutions stay within lower/upper bounds $[l_i, u_i]$ and satisfy inequality constraints $g_i(x) \le 0$.
- **Target Files**:
  - `lib/src/numeric/optimization.dart`
  - `test/numeric/optimization_test.dart`
- **Step-by-Step Implementation Details**:
  1. In `lib/src/numeric/optimization.dart`, implement `minimizeConstrained`:
     - For box bounds: Implement smooth variable transformation $x_i = l_i + \frac{u_i - l_i}{1 + e^{-y_i}}$ with chain rule gradient adjustments.
     - For general inequality constraints: Apply the Augmented Lagrangian Method or logarithmic barrier decay.
  2. Support both scalar functions and symbolic `Expr` targets.
  3. Add unit tests verifying constrained minima convergence on Rosenbrock function with box constraints.

---

### Task 2.10: 2D Surface Grid Interpolation (Bilinear & Bicubic)

- **Problem / Goal**:
  Interpolation routines are currently restricted to 1D curves (`CubicSpline`, `PchipInterpolation`). 2D spatial models, elevation grids, and image resampling require surface interpolation.
- **The Win**:
  - Continuous 2D surface evaluation and continuous $C^1$ gradient extraction over regular grids.
- **Target Files**:
  - `lib/src/numeric/interpolation_2d.dart` (new)
  - `lib/numeric.dart`
  - `test/numeric/interpolation_2d_test.dart` (new)
- **Step-by-Step Implementation Details**:
  1. Create `lib/src/numeric/interpolation_2d.dart`:
     - Define `abstract class Interpolator2D { double evaluate(double x, double y); }`.
     - Implement `BilinearInterpolation(List<double> xs, List<double> ys, Matrix<double> values)`.
     - Implement `BicubicInterpolation(List<double> xs, List<double> ys, Matrix<double> values)` with 16-coefficient bicubic patches and `Vector<double> gradient(double x, double y)`.
  2. Export from `lib/numeric.dart`.
  3. Add unit tests evaluating interpolated values and gradients against analytical 2D test functions ($f(x, y) = \sin(x) \cos(y)$).

---

### Task 2.11: Regularized Polynomial Regression (Tikhonov / Ridge L2)

- **Problem / Goal**:
  Fitting high-degree polynomials ($\text{degree} \ge 5$) on noisy data causes catastrophic edge oscillations (Runge's phenomenon) and numerical singularity in the Vandermonde matrix.
- **The Win**:
  - Well-conditioned polynomial fitting with L2 regularization suppressing high-frequency oscillations.
- **Target Files**:
  - `lib/src/numeric/curve_fit.dart`
  - `test/numeric/curve_fit_test.dart`
- **Step-by-Step Implementation Details**:
  1. In `lib/src/numeric/curve_fit.dart`, add `double lambda = 0.0` parameter to `polynomialRegression`.
  2. Augment the Vandermonde system with regularized block rows:
     $$\begin{pmatrix} V \\ \sqrt{\lambda} \tilde{I} \end{pmatrix} c \approx \begin{pmatrix} y \\ 0 \end{pmatrix}$$
     (leaving the intercept row $\tilde{I}_{0,0} = 0$ unpenalized).
  3. Solve using Householder QR or LAPACK `dgels`.
  4. Add unit tests asserting coefficient shrinkage and oscillation damping for noisy high-degree polynomial datasets.

---

### Task 2.12: Weighted Descriptive Statistics & Rolling / Moving Window Aggregations

- **Problem / Goal**:
  Descriptive statistics do not support observation weights (survey data, importance sampling) or online moving window calculations.
- **The Win**:
  - Unbiased weighted mean and variance (with Bessel reliability weight corrections).
  - $\mathcal{O}(N)$ linear time simple moving average (SMA) and exponential moving average (EMA) with $\mathcal{O}(1)$ updates per step.
- **Target Files**:
  - `lib/src/stats/descriptive.dart`
  - `test/stats/descriptive_test.dart`
- **Step-by-Step Implementation Details**:
  1. In `lib/src/stats/descriptive.dart`:
     - Implement `weightedMean(Iterable<num> weights)` and `weightedVariance(Iterable<num> weights, {bool unbiased = true})`.
     - Implement `movingAverage(int windowSize)` with running window sum.
     - Implement `exponentialMovingAverage(double alpha)`.
  2. Add unit tests for weighted survey data, boundary window sizes, and exponential decay validation.

---

### Task 2.13: Multivariate Probability Distributions (`MultivariateNormal`, `Dirichlet`, `Multinomial`)

- **Problem / Goal**:
  The distribution suite is purely univariate. Multi-sensor modeling, financial portfolios, and Bayesian priors require multivariate distributions.
- **The Win**:
  - Correlated multivariate probability density modeling and random sampling.
- **Target Files**:
  - `lib/src/stats/distributions/multivariate/multivariate_normal.dart` (new)
  - `lib/src/stats/distributions/multivariate/dirichlet.dart` (new)
  - `lib/src/stats/distributions/multivariate/multinomial.dart` (new)
  - `lib/stats.dart`
  - `test/stats/multivariate_distribution_test.dart` (new)
- **Step-by-Step Implementation Details**:
  1. Implement `MultivariateNormalDistribution(Vector<double> mean, Matrix<double> covariance)`:
     - Compute Cholesky factorization $\Sigma = L L^T$.
     - Evaluate PDF via triangular forward solve: $y = L^{-1} (x - \mu)$, $(x - \mu)^T \Sigma^{-1} (x - \mu) = \|y\|_2^2$.
     - Sample via $x = \mu + L z$ where $z \sim \mathcal{N}(0, I)$.
  2. Implement `DirichletDistribution(Vector<double> alpha)`.
  3. Implement `MultinomialDistribution(int trials, Vector<double> probabilities)`.
  4. Add unit tests checking covariance reconstruction and empirical sampling moments.

---

### Task 2.14: Goodness-of-Fit & Normality Hypothesis Tests

- **Problem / Goal**:
  Hypothesis testing lacks formal distribution fit tests (Kolmogorov-Smirnov, Jarque-Bera) and non-parametric paired tests (Wilcoxon signed-rank).
- **The Win**:
  - Formal validation of distributional assumptions and non-parametric paired comparisons.
- **Target Files**:
  - `lib/src/stats/hypothesis.dart`
  - `test/stats/hypothesis_test.dart`
- **Step-by-Step Implementation Details**:
  1. In `lib/src/stats/hypothesis.dart`:
     - Implement `kolmogorovSmirnovTest(sample, distribution)` and `kolmogorovSmirnov2Sample(sampleA, sampleB)`.
     - Implement `jarqueBeraTest(sample)` evaluating test statistic $JB = \frac{n}{6}(S^2 + \frac{(K-3)^2}{4})$ against $\chi^2(2)$.
     - Implement `wilcoxonSignedRankTest(x, [y])` for paired non-parametric differences.
  2. Add unit tests verifying known standard normal acceptance and rejection of uniform/exponential distributions.

---

### Task 2.15: Polynomial Composition ($P(Q(x))$), Rational Functions (`RationalFunction<T>`), and Laguerre Polynomials ($L_n^{(\alpha)}(x)$)

- **Problem / Goal**:
  Advanced algebraic operations on polynomials and rational quotients are missing.
- **The Win**:
  - Exact polynomial coordinate shifts and substitutions via Horner's recurrence.
  - Exact rational quotients with automatic Euclidean GCD simplification.
  - Generalized Laguerre polynomials for quantum mechanics and semi-infinite Gauss-Laguerre quadrature.
- **Target Files**:
  - `lib/src/polynomial/polynomial.dart`
  - `lib/src/polynomial/rational.dart` (new)
  - `lib/src/polynomial/orthogonal.dart`
  - `lib/polynomial.dart`
  - `test/polynomial/polynomial_test.dart`
  - `test/polynomial/rational_test.dart` (new)
- **Step-by-Step Implementation Details**:
  1. In `lib/src/polynomial/polynomial.dart`:
     Implement `Polynomial<T> compose(Polynomial<T> other)` using Horner's recurrence.
  2. Create `lib/src/polynomial/rational.dart`:
     Implement `RationalFunction<T>` with `simplify()` dividing out `numerator.gcd(denominator)`, arithmetic overloads, evaluation, and derivative via quotient rule.
  3. In `lib/src/polynomial/orthogonal.dart`:
     Implement `laguerreL(int n, {double alpha = 0.0})` via 3-term recurrence and `laguerreEvaluate(n, x, {alpha})`.
  4. Add unit tests for polynomial composition, rational function simplification, and Laguerre orthogonality.

---

### Task 2.16: Generalized Tensor Contraction (`tensordot`) and Einstein Summation (`einsum`)

- **Problem / Goal**:
  Multi-axis tensor contractions currently require manual permutation, reshaping, and reduction loops.
- **The Win**:
  - High-performance N-D contractions mapped automatically to 2D BLAS GEMM calls.
  - Concise declarative index notation (`'bij,bjk->bik'`).
- **Target Files**:
  - `lib/src/tensor/operations/contraction.dart` (new)
  - `lib/src/tensor/operations/einsum.dart` (new)
  - `lib/tensor.dart`
  - `test/tensor/contraction_test.dart` (new)
  - `test/tensor/einsum_test.dart` (new)
- **Step-by-Step Implementation Details**:
  1. Create `lib/src/tensor/operations/contraction.dart`:
     Implement `tensordot(a, b, axes: (axesA, axesB))` by permuting free and contracted axes, reshaping to 2D matrices, executing `matmul`, and reshaping to output dimensions.
  2. Implement `innerProduct(a, b)` and `outerProduct(a, b)`.
  3. Create `lib/src/tensor/operations/einsum.dart`:
     Parse Einstein subscript strings, plan pairwise contraction order, and dispatch to `transpose`, `diagonal`, and `tensordot`.
  4. Add unit tests validating batched matrix multiplication, traces, and multi-tensor contractions.

---

## Priority 3: Longer-Term Roadmap & External Interoperability

### Task 3.1: Apache Arrow C Data Interface & IPC Stream Export

- **Problem / Goal**:
  Sharing DataFrames with Python (Polars, pandas, PyArrow) or DuckDB requires slow serialization to disk CSV files.
- **The Win**:
  - Zero-copy in-memory exchange via standard ABI `ArrowSchema` and `ArrowArray` FFI structs.
- **Target Files**:
  - `lib/src/dataframe/arrow_c_data.dart` (new)
  - `lib/src/dataframe/arrow_ipc.dart` (new)
  - `lib/dataframe.dart`
  - `test/dataframe/arrow_c_data_test.dart` (new)
- **Step-by-Step Implementation Details**:
  1. In `lib/src/dataframe/arrow_c_data.dart`, define `dart:ffi` Struct representations for `ArrowSchema` and `ArrowArray`.
  2. Implement `exportToArrowC(Pointer<ArrowArray> outArray, Pointer<ArrowSchema> outSchema)`:
     - Map `TypedSeries` memory buffers directly to pointers in `buffers` array.
     - Pass `validityMask.buffer` as buffer 0 and data memory as buffer 1.
     - Wire `release` callback to maintain Dart object references until freed by native consumer.
  3. Add tests verifying C struct layout compliance and pointer exports.

---

### Task 3.2: Apache Arrow UTF-8 String Offset Buffer (`ArrowStringSeries`)

- **Problem / Goal**:
  `StringSeries` stores individual Dart `String` instances on the garbage-collected heap, consuming large amounts of memory and preventing zero-copy Arrow serialization.
- **The Win**:
  - Apache Arrow-compliant flat `Uint8List` byte buffer with `Uint32List` offsets, eliminating individual heap string objects.
- **Target Files**:
  - `lib/src/dataframe/arrow_string_series.dart` (new)
  - `lib/src/dataframe/series.dart`
  - `test/dataframe/series_test.dart`
- **Step-by-Step Implementation Details**:
  1. Create `lib/src/dataframe/arrow_string_series.dart`:
     Implement `ArrowStringSeries` backed by `Uint8List _bytes`, `Uint32List _offsets`, and `ValidityMask _validityMask`.
  2. Provide `getBytes(int index)` returning `Uint8List.sublistView` for zero-copy string inspection.
  3. Update `CsvReader` and `DataFrame` string column construction to build `ArrowStringSeries`.
  4. Add unit tests checking null handling, UTF-8 decoding, and string slicing.

---

### Task 3.3: Sort-Merge Relational Join

- **Problem / Goal**:
  DataFrame joins strictly use hash tables, requiring $\mathcal{O}(M)$ auxiliary memory and dynamic hashing.
- **The Win**:
  - $\mathcal{O}(M + N)$ execution time and $\mathcal{O}(1)$ auxiliary memory join for pre-sorted key columns.
- **Target Files**:
  - `lib/src/dataframe/join.dart`
  - `test/dataframe/join_test.dart`
- **Step-by-Step Implementation Details**:
  1. In `lib/src/dataframe/join.dart`, implement `sortMergeJoin`:
     - Validate or sort key columns.
     - Traverse both DataFrames with dual cursor pointers, emitting matching pairs and handling duplicate key runs.
  2. Add unit tests for inner, left, right, and outer sort-merge joins with duplicate keys.

---

### Task 3.4: Streaming CSV & JSON Parsers

- **Problem / Goal**:
  `CsvReader` and JSON parsers buffer entire multi-gigabyte files into memory strings before parsing.
- **The Win**:
  - Constant memory streaming DataFrame ingestion from `Stream<List<int>>` and `Stream<String>`.
- **Target Files**:
  - `lib/src/dataframe/csv.dart`
  - `lib/src/dataframe/json.dart`
  - `test/dataframe/csv_stream_test.dart` (new)
- **Step-by-Step Implementation Details**:
  1. Implement chunked state-machine RFC 4180 streaming transformer for `Stream<List<int>>`.
  2. Stream parsed rows into chunked Series buffers, concatenating into `DataFrame` blocks.
  3. Add tests verifying parsing of large streamed chunks without buffering the full dataset in RAM.

---

### Task 3.5: Graph Data Structures & Discrete Graph Algorithms

- **Problem / Goal**:
  The long-standing roadmap commitment from `README.md` ("data structures and algorithms for vectors and matrices, but at some point might also include graphs and other mathematical structures") is unfulfilled.
- **The Win**:
  - Canonical `Graph<V, E>` interface with `AdjacencyListGraph` and `AdjacencyMatrixGraph` implementations.
  - Shortest path algorithms (Dijkstra, A*, Bellman-Ford, Floyd-Warshall), topological sorting, and Minimum Spanning Trees (Kruskal, Prim).
  - Algebraic graph theory bridge: export graph Laplacian to `Matrix<double>` for spectral graph analysis.
- **Target Files**:
  - `lib/src/graph/graph.dart` (new)
  - `lib/src/graph/adjacency_list.dart` (new)
  - `lib/src/graph/adjacency_matrix.dart` (new)
  - `lib/src/graph/pathfinding.dart` (new)
  - `lib/src/graph/algorithms.dart` (new)
  - `lib/graph.dart` (new)
  - `lib/data.dart`
  - `test/graph/graph_test.dart` (new)
  - `test/graph/pathfinding_test.dart` (new)
  - `test/graph/algorithms_test.dart` (new)
- **Step-by-Step Implementation Details**:
  1. Create `lib/src/graph/graph.dart`:
     Define `abstract class Graph<V, E>` with vertices, edges, successor/predecessor iteration, and `toAdjacencyMatrix()`, `toDegreeMatrix()`, `toLaplacianMatrix()`.
  2. Implement `AdjacencyListGraph<V, E>` in `lib/src/graph/adjacency_list.dart`.
  3. Implement `AdjacencyMatrixGraph<V, E>` in `lib/src/graph/adjacency_matrix.dart`.
  4. Create `lib/src/graph/pathfinding.dart`:
     - Implement `dijkstra` with binary min-heap priority queue.
     - Implement `aStar` with heuristic function.
     - Implement `bellmanFord` with negative cycle detection.
     - Implement `floydWarshall` returning all-pairs distance `Matrix<double>`.
  5. Create `lib/src/graph/algorithms.dart`:
     - Implement `topologicalSort` via Kahn's in-degree algorithm.
     - Implement `minimumSpanningTreeKruskal` with Disjoint-Set Union (path compression + union-by-rank).
     - Implement `minimumSpanningTreePrim`.
  6. Export via `lib/graph.dart` and `lib/data.dart`.
  7. Add exhaustive test suite across directed/undirected graphs, weighted paths, negative cycles, DAGs, and spectral Laplacian decompositions.
