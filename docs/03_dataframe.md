# Subsystem Architecture: Tabular Data & DataFrame

## 1. Overview & Motivation

Modern data science, analytics, and machine learning workflows depend heavily on tabular data structures (such as pandas, Polars, or R `data.frame`). While `package:data` excels at homogeneous numerical matrices and tensors, it currently lacks a tabular data abstraction capable of handling:

1. Heterogeneous column types (e.g. `String`, `int`, `double`, `DateTime`, `bool`).
2. Missing / null values with memory-efficient validity bitmasks.
3. Labeled rows and columns.
4. Relational operations: grouping, aggregation, joining, and filtering.
5. High-throughput zero-copy interoperability with Apache Arrow and columnar file formats (Parquet, CSV).

This document outlines the architecture for a unified, fast, and easy-to-use `DataFrame` subsystem designed for Dart.

---

## 2. Core Architectural Design

```text
+-------------------------------------------------------------------------+
|                               DataFrame                                 |
|  - Index (Row labels or RangeIndex)                                     |
|  - ColumnIndex (Ordered map of column names -> Series)                  |
|  - Schema (Column names and DataType<T> descriptors)                    |
+-------------------------------------------------------------------------+
                                    |
          +-------------------------+-------------------------+
          |                         |                         |
+-------------------+     +-------------------+     +-------------------+
|  Series<int64>    |     |  Series<double>   |     |  Series<String>   |
| - Int64List buffer|     | - Float64List     |     | - Offset buffer   |
| - Validity Bitmask|     | - Validity Bitmask|     | - Byte buffer     |
+-------------------+     +-------------------+     +-------------------+
```

### 2.1 Columnar Memory Representation (`Series<T>`)

Each column is represented as a typed `Series<T>`. To achieve maximum memory efficiency and speed:

- **Contiguous Typed Buffers**: Numeric series use Dart typed lists (`Int32List`, `Float64List`, etc.) directly.
- **Validity Bitmask (Null Handling)**: Instead of allocating boxed `T?` references in generic object lists, missing values are tracked using an optional `Uint8List` bitmask (1 bit per row, where 1 indicates valid/non-null and 0 indicates null). This matches the **Apache Arrow specification** and avoids pointer chasing.
- **String Column Representation**: Large string columns are represented as UTF-8 byte buffers with an offset index (`Uint32List`), enabling rapid slicing and aggregation without thousands of Dart `String` allocations.

```dart
abstract class Series<T> {
  String get name;
  DataType<T> get dataType;
  int get length;
  int get nullCount;
  
  bool isNull(int index);
  T? operator [](int index);
  
  // High-performance vectorized operations
  Series<T> filter(List<bool> mask);
  Series<T> sort({bool ascending = true});
  Series<R> cast<R>(DataType<R> targetType);
  
  // Reductions
  T? get min;
  T? get max;
  num? get sum;
  double? get mean;
}
```

### 2.2 `DataFrame` Interface

The `DataFrame` holds an ordered mapping of column names to `Series` instances, all sharing the same row count:

```dart
class DataFrame {
  final List<Series> _columns;
  final Map<String, int> _columnIndex;
  final int rowCount;
  
  // Column access
  Series<T> column<T>(String name);
  Series<T> operator [](String name) => column<T>(name);
  
  // Row access
  Row getRow(int index);
  
  // Structural manipulation
  DataFrame select(List<String> columnNames);
  DataFrame drop(List<String> columnNames);
  DataFrame withColumn(String name, Series series);
  
  // Filtering & Slicing
  DataFrame filter(Series<bool> condition);
  DataFrame slice(int start, int end);
  DataFrame head([int n = 5]);
  DataFrame tail([int n = 5]);
  
  // Conversions
  Matrix<num> toMatrix({List<String>? columns, DataType<num>? type});
  Tensor<num> toTensor({List<String>? columns, DataType<num>? type});
}
```

### 2.3 GroupBy & Aggregations

Fast group-by operations use a single-pass hash partitioning pass over key columns, returning grouped slices for aggregation:

```dart
final df = DataFrame.fromCsv(csvString);

// GroupBy example
final summary = df
    .groupBy(['department', 'region'])
    .aggregate({
      'salary': [Agg.mean, Agg.median, Agg.std],
      'employee_id': [Agg.count],
    });
```

Supported Aggregations:

- `Agg.count`, `Agg.sum`, `Agg.mean`, `Agg.median`, `Agg.min`, `Agg.max`, `Agg.std`, `Agg.var`, `Agg.first`, `Agg.last`.

### 2.4 Relational Joins

Support standard database relational joins:

```dart
DataFrame join(
  DataFrame other, {
  required List<String> on,
  JoinType type = JoinType.inner, // inner, left, right, full, cross
  String suffix = '_other',
});
```

Algorithms:

- **Hash Join**: For unsorted columns (default).
- **Sort-Merge Join**: Optimized for already-sorted index columns.

### 2.5 Zero-Copy Interoperability with Apache Arrow & Files

Because `Series<T>` uses contiguous typed buffers and validity bitmasks matching Arrow's layout:

1. **Arrow IPC / Flight**: Data can be transferred across isolates, native processes (Python, C++), and network sockets via Arrow IPC streams without serializing or copying individual rows.
2. **Matrix / Tensor Conversion**: Extracting numeric columns into a 2D `Matrix<double>` or `Tensor<double>` is zero-copy if the columns are stored contiguously, or a fast SIMD block-copy if reshaping is needed.
3. **CSV & JSON Streaming**:
   - `DataFrame.fromCsv(String or Stream<List<int>>)` with automated type inference.
   - `df.toCsv()`, `df.toJson()`.

---

## 3. Prioritized Implementation Task List

| Task ID | Phase | Priority | Description | Verification / Success Criteria |
| :--- | :--- | :--- | :--- | :--- |
| **DF-01** | Core Series | **P0** | Implement `Series<T>` and `TypedSeries<T>` backed by Dart typed arrays and Apache Arrow-compatible validity bitmasks. | Test null handling, bitmask setting/clearing, and element access. |
| **DF-02** | Core DataFrame | **P0** | Implement `DataFrame` with column management, shape validation, row count, column selection, and projection. | Unit tests for creating, adding, dropping, and renaming columns. |
| **DF-03** | Filtering | **P1** | Implement boolean mask filtering (`df.filter(mask)`), row slicing (`head`, `tail`, `slice`), and sorting (`sortBy`). | Correctly filters a 100,000-row DataFrame in <20ms. |
| **DF-04** | GroupBy & Agg | **P1** | Implement `GroupBy` with hash-partitioned aggregation engine for single and multi-column keys (`sum`, `mean`, `count`, etc.). | Benchmark: Aggregating 500,000 rows across 3 groups completes in <100ms. |
| **DF-05** | Relational Joins | **P1** | Implement Hash Join supporting `inner`, `left`, `right`, and `outer` joins on shared keys. | Test complex joins with missing keys and mismatched columns. |
| **DF-06** | IO (CSV/JSON) | **P2** | Implement fast streaming CSV reader with type inference and CSV writer. | Read and write standard benchmarks (e.g. Iris, Boston Housing, NYC Taxi samples). |
| **DF-07** | Matrix Interop | **P2** | Add seamless conversions between numeric columns and `Matrix<num>` / `Tensor<num>`. | Verify `df.select(['a', 'b']).toMatrix()` round-trip fidelity. |
| **DF-08** | Arrow Interop | **P3** | Implement zero-copy export/import to Apache Arrow RecordBatch format. | Zero-copy validation via Dart FFI and Arrow C Data Interface. |
