/// Type descriptors, algebraic structures, memory storage models, and equality relations.
///
/// Underpins tensors, matrices, vectors, and columnar data structures with explicit
/// type specifications, algebraic field axioms (identities, addition, multiplication, inversion),
/// and unboxed typed memory storage.
///
/// ## Core Concepts
///
/// - **Type Descriptors ([DataType])**: Singletons representing primitive numbers ([DataType.int32],
///   [DataType.float64], [DataType.uint8]), complex types ([DataType.complex], [DataType.quaternion]),
///   arbitrary precision numbers ([DataType.bigInt], [DataType.fraction]), [DataType.string],
///   [DataType.boolean], and generic objects ([DataType.object]).
/// - **Algebraic Fields ([Field])**: Axiomatic algebraic structures specifying additive
///   identity ($0$), multiplicative identity ($1$), operations ($+$, $-$, $\times$, $\div$),
///   and inversion over a type.
/// - **Memory Storage ([NativeBuffer])**: Flat typed byte buffers that enable zero-copy
///   passing to native FFI algorithms and hardware accelerators.
/// - **Equivalence & Ordering**: [Equality] and comparator utilities for deterministic hashing and sorting.
///
/// ## Example
///
/// ```dart
/// import 'package:data/type.dart';
///
/// void main() {
///   final floatType = DataType.float64;
///   print('Bits: ${floatType.bits}, isNative: ${floatType.isNative}');
///
///   // Access algebraic field
///   final field = floatType.field;
///   print('Additive identity: ${field.additiveIdentity}');
///   print('Multiplicative identity: ${field.multiplicativeIdentity}');
///
///   // Create an efficient typed list
///   final list = floatType.newList(5, fillValue: 1.5);
///   print(list);
/// }
/// ```
library;

import 'src/type/buffers/native_buffer.dart';
import 'src/type/data_type.dart';
import 'src/type/models/equality.dart';
import 'src/type/models/field.dart';

export 'package:more/comparator.dart';
export 'package:more/number.dart' show Complex, Fraction, Quaternion;

export 'src/type/buffers/memory.dart';
export 'src/type/buffers/native_buffer.dart';
export 'src/type/data_type.dart';
export 'src/type/default_data_type.dart';
export 'src/type/models/equality.dart';
export 'src/type/models/field.dart';
export 'src/type/types/bigint.dart';
export 'src/type/types/boolean.dart';
export 'src/type/types/complex.dart';
export 'src/type/types/float.dart';
export 'src/type/types/fraction.dart';
export 'src/type/types/integer.dart';
export 'src/type/types/nullable.dart';
export 'src/type/types/numeric.dart';
export 'src/type/types/object.dart';
export 'src/type/types/quaternion.dart';
export 'src/type/types/string.dart';
