# Tensor Architecture

`Tensor` is a powerful N-dimensional array library for Dart, inspired by Python's NumPy. It provides memory-efficient, multi-dimensional data structures and operations designed for high-performance scientific computing, machine learning, and data analysis.

---

## Core Architecture & Design Concepts

The library's architecture is based on the separation of data storage, data type representation, and multi-dimensional layout mapping.

```
       +---------------------------------------------+
       |                  Tensor<T>                  |
       +-------------------+-------------------------+
                           |
         +-----------------+-----------------+
         |                                   |
         v                                   v
+-----------------+                 +-----------------+
|   Layout        |                 |   DataType<T>   |
+-----------------+                 +-----------------+
| - shape         |                 | - newList()     |
| - strides       |                 | - copyList()    |
| - offset        |                 | - printer       |
| - isContiguous  |                 +-----------------+
+--------+--------+
         |
         | (computes index)
         v
+-----------------------------+
|   Flat List (data)          |
|   [v0, v1, v2, ..., vn]     |
+-----------------------------+
```

### 1. Data Storage & Layout

A `Tensor<T>` does not store data in a nested, multi-dimensional structure. Instead, it maintains three properties:

* **`data`**: A flat `List<T>` containing all elements.
* **`type`**: A `DataType<T>` instance describing the element type and providing type-specific list allocation, copying, and printing.
* **`layout`**: A `Layout` object describing how the flat list is mapped to N-dimensional space.

The `Layout` defines:

* **`rank`**: The number of dimensions (axes).
* **`shape`**: A list of size `rank` representing the length of each dimension.
* **`strides`**: A list of size `rank` representing the step size (number of indices in the flat list) needed to advance by one element along each dimension.
* **`offset`**: The starting index of the tensor's data within the flat list.
* **`isContiguous`**: A boolean indicating if elements are stored sequentially without gaps.

This design permits **zero-copy layout views**. Operations such as transposing, flipping, slicing, and reshaping often do not duplicate the underlying data; they merely return a new `Tensor` sharing the same `data` list with an updated `Layout`.

### 2. Layout View Operations (O(1) Complexity)

Many transformations are implemented by manipulating the `shape`, `strides`, and `offset` of the `Layout`:

* **Slicing (`getRange`)**: Returns a view of a sub-region along an axis.
  $$\text{new\_strides}[i] = \text{step} \times \text{strides}[i]$$
  $$\text{new\_offset} = \text{offset} + \text{start} \times \text{strides}[\text{axis}]$$
* **Transposing (`transpose`, `swapAxes`, `moveAxes`)**: Reorders the dimensions. It permutes the elements of `shape` and `strides` accordingly without moving any data.
* **Flipping (`flip`)**: Reverses elements along an axis by negating the stride for that axis and adjusting the offset:
  $$\text{new\_strides}[\text{axis}] = -\text{strides}[\text{axis}]$$
  $$\text{new\_offset} = \text{offset} + \text{strides}[\text{axis}] \times (\text{shape}[\text{axis}] - 1)$$
* **Collapsing (`collapse`)**: Removes a single-element dimension (equivalent to `np.squeeze`).
* **Expanding (`expand`)**: Inserts a new single-element dimension (equivalent to `np.expand_dims`).

### 3. Indexing & Coordinate Mapping

Converting an N-dimensional key (index coordinate list) to a flat index is done via:
$$\text{flat\_index} = \text{offset} + \sum_{i=0}^{\text{rank}-1} \text{key}[i] \times \text{strides}[i]$$

To iterate over non-contiguous layouts, the library uses custom iterators:

* **`IndexIterator`**: Performs a multi-dimensional mixed-radix counter traversal to yield the exact flat indices corresponding to the N-dimensional space.
* **`KeyIterator`**: Traverses the N-dimensional coordinate space to yield coordinate keys.

### 4. Broadcasting

Broadcasting allows operations on tensors of different shapes. The implementation matches NumPy's broadcasting rules, evaluating dimensions starting from the trailing (rightmost) dimension:

1. Two dimensions are compatible if they are equal, or if one of them is `1`.
2. If a dimension is missing in one tensor (due to lower rank), it is prepended with `1`.
3. The resulting dimension size is the maximum of the two.
4. **Implementation Detail**: If a dimension of size `1` is broadcasted to size `N`, its stride is set to `0`. This means advancing along that dimension adds `0` to the flat index, effectively repeating the single element across the axis without duplicating data in memory.

---

## Comparison with NumPy: Missing Concepts

While the current implementation covers the fundamental layout-based structure of N-dimensional arrays, several key concepts from NumPy are not yet present:

### 1. Axis-Based Reductions and Aggregations

NumPy provides extensive aggregation functions that can operate over the entire tensor or along specific axes (e.g., `sum`, `mean`, `min`, `max`, `std`, `var`, `prod`, `any`, `all`, `argmin`, `argmax`).

* *Current State*: There are no axis-based reduction methods implemented.
* *Required Change*: Add reduction operations that contract layout dimensions and project the remaining dimensions into a new tensor shape.

### 2. Advanced / Fancy Indexing

NumPy allows indexing using:

* Integer arrays (indexing along an axis using arbitrary coordinate lists).
* Boolean masks (filtering elements matching a condition, e.g., `tensor[tensor > 0]`).
* *Current State*: Indexing is limited to standard index coordinates via `getValue`/`setValue`, simple axis-subscripting (`operator []`), or range slicing (`getRange`).

### 3. Universal Functions (ufuncs)

In NumPy, functions like `sin`, `cos`, `exp`, `log`, and `sqrt` are universal functions (`ufunc`) that support broadcasting, output destination overriding, buffering, and type casting.

* *Current State*: Element-wise operations are limited to standard arithmetic/comparison operators and basic unary/binary mapping functions.

### 4. Linear Algebra Operations

Fundamental linear algebra operations are missing:

* Matrix multiplication (`matmul` or `@` operator).
* Dot product, inner/outer products, tensor products.
* Advanced decompositions (SVD, QR, Eigenvalues) and matrix solvers (inverses, determinants).

### 5. Tensor Concatenation, Stacking, and Splitting

Operations to combine or split tensors along axes are missing:

* `concatenate`, `stack`, `hstack`, `vstack`, `dstack`.
* `split`, `hsplit`, `vsplit`.

### 6. Dynamic Upcasting & Data Type Promotion

NumPy automatically promotes data types during operations (e.g., adding an integer tensor to a float tensor produces a float tensor).

* *Current State*: Binary operations are heavily bound to the first tensor's data type, potentially leading to precision truncation or dynamic type errors when types differ.

---

## Optimization & Improvement Opportunities

To achieve peak performance, several areas of the tensor implementation can be optimized:

### 1. Fast Paths for Contiguous Tensors

Currently, all element-wise unary and binary operations use generalized iterators (`IndexIterator`) that perform multi-dimensional coordinate and stride calculations on every single element.

* **Optimization**: When `isContiguous` is `true` for all involved layouts, the operation can completely bypass the iterator and execute a flat, single-dimensional loop over the underlying data list.
* **Expected Impact**: Bypassing iterator logic and mixed-radix counter calculations for contiguous data yields substantial execution speedups (potentially 10x to 50x) due to Dart VM loop optimizations, devirtualization, and elimination of call overhead.

```dart
// Conceptual contiguous binary operation optimization
if (layout.isContiguous && other.layout.isContiguous && target == null) {
  final length = layout.length;
  final resultData = resultType.newList(length);
  for (var i = 0; i < length; i++) {
    resultData[i] = function(data[layout.offset + i], other.data[other.layout.offset + i]);
  }
  return Tensor.internal(...);
}
```

### 2. SIMD Vectorization

Dart provides SIMD (Single Instruction, Multiple Data) support through `Float32x4List` and `Int32x4List` in `dart:typed_data`.

* **Optimization**: For numeric tensors (e.g., float or double type) with contiguous layouts, binary and unary mathematical operations can be rewritten using SIMD vector lists.
* **Expected Impact**: Parallel processing of 4 numeric values per instruction cycle on compatible hardware architectures.

### 3. Reduction of Memory Allocations

* `IndexIterator` allocates a coordinate list (`indices`) and modifies it on each step. Frequent creation of iterators in tight computation loops introduces garbage collection pressure.
* **Optimization**: Iterators can be pooled, or specialized flat iterators can be implemented for low-rank tensors (e.g., 1D, 2D, and 3D) to avoid general-purpose list allocations.

### 4. Specialized Broadcast Operations

When broadcasting, one or more dimensions have a stride of `0`.

* **Optimization**: Rather than calculating indices through the general `IndexIterator`, specialized loops can recognize dimensions with a stride of `0` and reuse values directly, avoiding redundant arithmetic and array lookups.
