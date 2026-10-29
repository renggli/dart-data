import 'dart:collection';
import 'dart:typed_data';

import 'package:more/number.dart';

import '../models/equality.dart';
import '../models/field.dart';
import 'typed.dart';

/// Data type descriptor for complex numbers ([Complex]).
final class ComplexDataType extends TypedDataType<Complex, Float64ComplexList> {
  /// Creates a new [ComplexDataType] instance.
  const new();

  @override
  String get name => 'complex';

  @override
  int get bits => 128;

  @override
  Complex get defaultValue => Complex.zero;

  @override
  Complex get min =>
      throw UnsupportedError('Complex numbers have no total ordering');

  @override
  Complex get max =>
      throw UnsupportedError('Complex numbers have no total ordering');

  @override
  Float64ComplexList emptyList(int length) => Float64ComplexList(length);

  @override
  Float64ComplexList readonlyList(Float64ComplexList list) =>
      list.asUnmodifiableView();

  @override
  Complex cast(Object? value) {
    if (value is Complex) {
      return value;
    } else if (value is num) {
      return Complex(value);
    } else if (value is BigInt) {
      return Complex(value.toDouble());
    } else if (value is Fraction) {
      return Complex(value.toDouble());
    } else if (value is String) {
      return Complex.tryParse(value) ?? super.cast(value);
    }
    return super.cast(value);
  }

  @override
  Equality<Complex> get equality => const ComplexEquality();

  @override
  Field<Complex> get field => const ComplexField();
}

/// Equality relation for [Complex] numbers with proximity testing.
final class ComplexEquality extends NaturalEquality<Complex> {
  /// Creates a new [ComplexEquality] instance.
  const new();

  @override
  bool isClose(Complex a, Complex b, double epsilon) => a.closeTo(b, epsilon);
}

/// Algebraic field operations over [Complex] numbers.
final class ComplexField implements ExtendedField<Complex> {
  /// Creates a new [ComplexField] instance.
  const new();

  @override
  Complex get additiveIdentity => Complex.zero;

  @override
  Complex neg(Complex a) => -a;

  @override
  Complex add(Complex a, Complex b) => a + b;

  @override
  Complex sub(Complex a, Complex b) => a - b;

  @override
  Complex get multiplicativeIdentity => Complex.one;

  @override
  Complex inv(Complex a) => a.reciprocal();

  @override
  Complex mul(Complex a, Complex b) => a * b;

  @override
  Complex scale(Complex a, num factor) => a * factor;

  @override
  Complex div(Complex a, Complex b) => a / b;

  @override
  Complex mod(Complex a, Complex b) => unsupportedOperation('mod');

  @override
  Complex division(Complex a, Complex b) => unsupportedOperation('division');

  @override
  Complex remainder(Complex a, Complex b) => unsupportedOperation('remainder');

  @override
  Complex pow(Complex base, Complex exponent) => base.pow(exponent);

  @override
  Complex modPow(Complex base, Complex exponent, Complex modulus) =>
      unsupportedOperation('modPow');

  @override
  Complex modInverse(Complex base, Complex modulus) =>
      unsupportedOperation('modInverse');

  @override
  Complex gcd(Complex a, Complex b) => unsupportedOperation('gcd');

  @override
  Complex abs(Complex a) => Complex(a.abs());

  @override
  double norm(Complex a) => a.abs();

  @override
  Complex sqrt(Complex a) => a.sqrt();

  @override
  Complex exp(Complex a) => a.exp();

  @override
  Complex log(Complex a) => a.log();

  @override
  Complex conjugate(Complex a) => a.conjugate();

  @override
  Complex get nan => Complex.nan;

  @override
  Complex get infinity => Complex.infinity;

  @override
  Complex get negativeInfinity => -Complex.infinity;
}

/// A fixed-length [List] of [Complex] numbers backed by a single contiguous
/// interleaved [Float64List] buffer `[re0, im0, re1, im1, ...]`.
class Float64ComplexList with ListMixin<Complex> {
  /// Constructs a [Float64ComplexList] of the given [length] backed by a
  /// contiguous interleaved [Float64List] of length `2 * length`.
  factory(int length) => Float64ComplexList.fromData(Float64List(2 * length));

  /// Constructs a [Float64ComplexList] wrapping the provided interleaved [data]
  /// buffer of length `2 * length`.
  new fromData(this.data)
    : assert(data.length.isEven, 'Data length must be even');

  /// Constructs a [Float64ComplexList] from an iterable of [Complex] numbers.
  factory fromList(Iterable<Complex> elements) {
    final list = elements.toList(growable: false);
    final result = Float64ComplexList(list.length);
    for (var i = 0; i < list.length; i++) {
      result[i] = list[i];
    }
    return result;
  }

  /// Constructs a [Float64ComplexList] from separate [real] and [imag] buffers.
  factory fromBuffers(Float64List real, Float64List imag) {
    if (real.length != imag.length) {
      throw ArgumentError('real and imag buffers must have equal length');
    }
    final result = Float64ComplexList(real.length);
    final data = result.data;
    for (var i = 0; i < real.length; i++) {
      data[2 * i] = real[i];
      data[2 * i + 1] = imag[i];
    }
    return result;
  }

  /// The underlying interleaved data buffer: `[re0, im0, re1, im1, ...]`.
  final Float64List data;

  /// The number of bytes in the representation of each element in this list.
  int get elementSizeInBytes => 16;

  /// The offset of this view into the underlying byte buffer, in bytes.
  int get offsetInBytes => data.offsetInBytes;

  /// The length of this view, in bytes.
  int get lengthInBytes => data.lengthInBytes;

  /// The byte buffer associated with this object.
  ByteBuffer get buffer => data.buffer;

  @override
  int get length => data.length >> 1;

  @override
  set length(int newLength) =>
      throw UnsupportedError('Cannot resize fixed-length Float64ComplexList');

  @override
  Complex operator [](int index) =>
      Complex(data[2 * index], data[2 * index + 1]);

  @override
  void operator []=(int index, Complex value) {
    data[2 * index] = value.a.toDouble();
    data[2 * index + 1] = value.b.toDouble();
  }

  @override
  void setRange(
    int start,
    int end,
    Iterable<Complex> iterable, [
    int skipCount = 0,
  ]) {
    RangeError.checkValidRange(start, end, length);
    final count = end - start;
    if (count == 0) return;
    if (skipCount < 0) {
      throw ArgumentError.value(skipCount, 'skipCount', 'Must be non-negative');
    }

    if (iterable is Float64ComplexList) {
      data.setRange(2 * start, 2 * end, iterable.data, 2 * skipCount);
    } else {
      super.setRange(start, end, iterable, skipCount);
    }
  }

  @override
  void fillRange(int start, int end, [Complex? fill]) {
    RangeError.checkValidRange(start, end, length);
    final value = fill ?? Complex.zero;
    final r = value.a.toDouble();
    final im = value.b.toDouble();
    for (var i = start; i < end; i++) {
      data[2 * i] = r;
      data[2 * i + 1] = im;
    }
  }

  @override
  Float64ComplexList sublist(int start, [int? end]) {
    final actualEnd = RangeError.checkValidRange(start, end, length);
    final count = actualEnd - start;
    final result = Float64ComplexList(count);
    result.data.setRange(0, 2 * count, data, 2 * start);
    return result;
  }

  /// Returns a zero-copy sublist view of this [Float64ComplexList].
  Float64ComplexList sublistView(int start, [int? end]) {
    final actualEnd = RangeError.checkValidRange(start, end, length);
    return Float64ComplexList.fromData(
      Float64List.sublistView(data, 2 * start, 2 * actualEnd),
    );
  }

  /// Returns an unmodifiable view of this [Float64ComplexList].
  Float64ComplexList asUnmodifiableView() =>
      UnmodifiableFloat64ComplexList(this);
}

/// An unmodifiable view of a [Float64ComplexList].
final class UnmodifiableFloat64ComplexList extends Float64ComplexList {
  /// Constructs an unmodifiable view wrapping the provided list.
  new(Float64ComplexList source)
    : _source = source,
      super.fromData(source.data.asUnmodifiableView());

  final Float64ComplexList _source;

  /// The wrapped mutable [Float64ComplexList].
  Float64ComplexList get source => _source;

  @override
  ByteBuffer get buffer => _source.buffer;

  @override
  void operator []=(int index, Complex value) =>
      throw UnsupportedError('Cannot modify an unmodifiable list');

  @override
  void setRange(
    int start,
    int end,
    Iterable<Complex> iterable, [
    int skipCount = 0,
  ]) => throw UnsupportedError('Cannot modify an unmodifiable list');

  @override
  void fillRange(int start, int end, [Complex? fill]) =>
      throw UnsupportedError('Cannot modify an unmodifiable list');

  @override
  void setAll(int index, Iterable<Complex> iterable) =>
      throw UnsupportedError('Cannot modify an unmodifiable list');

  @override
  Float64ComplexList sublistView(int start, [int? end]) =>
      UnmodifiableFloat64ComplexList(super.sublistView(start, end));

  @override
  Float64ComplexList asUnmodifiableView() => this;
}
