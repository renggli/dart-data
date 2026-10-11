import 'dart:math';
import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/dataframe.dart';
import 'package:test/test.dart';

void main() {
  group('incremental nullCount updates', () {
    test('repeated setNull on same index only increments once', () {
      final mask = ValidityMask(16);
      check(mask.nullCount).equals(0);
      check(mask.hasNulls).isFalse();

      mask.setNull(4);
      check(mask.nullCount).equals(1);
      check(mask.hasNulls).isTrue();

      // Calling setNull again on an already-null index must be a no-op for nullCount
      mask.setNull(4);
      mask.setNull(4);
      check(mask.nullCount).equals(1);
      check(mask.isNull(4)).isTrue();
    });

    test('repeated setValid on same index only decrements once', () {
      final mask = ValidityMask.allNull(16);
      check(mask.nullCount).equals(16);
      check(mask.hasNulls).isTrue();

      mask.setValid(4);
      check(mask.nullCount).equals(15);

      // Calling setValid again on an already-valid index must be a no-op for nullCount
      mask.setValid(4);
      mask.setValid(4);
      check(mask.nullCount).equals(15);
      check(mask.isValid(4)).isTrue();
    });

    test('toggling states repeatedly updates nullCount accurately', () {
      final mask = ValidityMask(10);
      check(mask.nullCount).equals(0);

      mask.setNull(2);
      check(mask.nullCount).equals(1);
      mask.setValid(2);
      check(mask.nullCount).equals(0);
      mask.setNull(2);
      check(mask.nullCount).equals(1);

      // Multiple indices
      mask.setNull(7);
      mask.setNull(8);
      check(mask.nullCount).equals(3);

      mask.setValid(2);
      mask.setValid(7);
      mask.setValid(8);
      check(mask.nullCount).equals(0);
      check(mask.hasNulls).isFalse();
    });

    test('mutations across byte boundaries', () {
      final mask = ValidityMask(24);
      // Byte 0: index 7; Byte 1: index 8; Byte 2: index 16
      mask.setNull(7);
      mask.setNull(8);
      mask.setNull(16);
      check(mask.nullCount).equals(3);

      check(mask.isNull(7)).isTrue();
      check(mask.isNull(8)).isTrue();
      check(mask.isNull(16)).isTrue();

      mask.setValid(7);
      check(mask.nullCount).equals(2);
      mask.setValid(8);
      check(mask.nullCount).equals(1);
      mask.setValid(16);
      check(mask.nullCount).equals(0);
    });
  });

  group('bulk constructors', () {
    test('default valid constructor', () {
      for (final len in [0, 1, 7, 8, 15, 16, 31, 32, 65, 128]) {
        final mask = ValidityMask(len);
        check(mask.length).equals(len);
        check(mask.nullCount).equals(0);
        check(mask.hasNulls).isFalse();
        for (var i = 0; i < len; i++) {
          check(mask.isValid(i)).isTrue();
          check(mask.isNull(i)).isFalse();
        }
      }
    });

    test('allNull constructor', () {
      for (final len in [0, 1, 7, 8, 15, 16, 31, 32, 65, 128]) {
        final mask = ValidityMask.allNull(len);
        check(mask.length).equals(len);
        check(mask.nullCount).equals(len);
        check(mask.hasNulls).equals(len > 0);
        for (var i = 0; i < len; i++) {
          check(mask.isNull(i)).isTrue();
          check(mask.isValid(i)).isFalse();
        }
      }
    });

    test('fromList constructor matches ground truth', () {
      final patterns = <List<bool>>[
        [],
        [true],
        [false],
        [true, false, true, true, false],
        [false, false, false, false, false, false, false, false],
        [true, true, true, true, true, true, true, true],
        List.generate(35, (i) => i % 3 != 0),
        List.generate(100, (i) => i % 2 == 0),
        List.generate(256, (i) => i % 5 == 0),
      ];

      for (final list in patterns) {
        final mask = ValidityMask.fromList(list);
        check(mask.length).equals(list.length);
        final expectedNulls = list.where((b) => !b).length;
        check(mask.nullCount).equals(expectedNulls);
        check(mask.hasNulls).equals(expectedNulls > 0);
        for (var i = 0; i < list.length; i++) {
          check(mask.isValid(i)).equals(list[i]);
          check(mask.isNull(i)).equals(!list[i]);
        }
      }
    });

    test('fromBytes computes bit-parallel nullCount and masks tail bits', () {
      // 10 entries packed into 2 bytes
      // Byte 0: 0b11110000 (indices 0..3 are 0/null, indices 4..7 are 1/valid) -> 4 nulls
      // Byte 1: 0b11111110 (index 8 is 0/null, index 9 is 1/valid, bits 2..7 are tail/ignored) -> 1 null
      // Total nulls: 4 + 1 = 5
      final raw = Uint8List.fromList([0xF0, 0xFE]);
      final mask = ValidityMask.fromBytes(10, raw);
      check(mask.length).equals(10);
      check(mask.nullCount).equals(5);

      // Verify each bit
      check(mask.isNull(0)).isTrue();
      check(mask.isNull(1)).isTrue();
      check(mask.isNull(2)).isTrue();
      check(mask.isNull(3)).isTrue();
      check(mask.isValid(4)).isTrue();
      check(mask.isValid(5)).isTrue();
      check(mask.isValid(6)).isTrue();
      check(mask.isValid(7)).isTrue();
      check(mask.isNull(8)).isTrue();
      check(mask.isValid(9)).isTrue();

      // Tail bits in raw bytes must not affect validity or nullCount
      // Last byte: length % 8 is 2, so bits 2..7 should be masked to 0
      check(mask.bytes[1] & ~0x03).equals(0);
    });

    test('fromBytes preserves explicit nullCount if provided', () {
      final raw = Uint8List.fromList([0xFF, 0xFF]);
      final mask = ValidityMask.fromBytes(16, raw, 0);
      check(mask.nullCount).equals(0);
    });

    test('copy produces independent clone with matching state', () {
      final original = ValidityMask(20);
      original.setNull(5);
      original.setNull(12);

      final cloned = original.copy();
      check(cloned.length).equals(original.length);
      check(cloned.nullCount).equals(original.nullCount);
      check(cloned.isNull(5)).isTrue();
      check(cloned.isNull(12)).isTrue();

      // Mutating clone does not mutate original
      cloned.setValid(5);
      check(cloned.nullCount).equals(1);
      check(original.nullCount).equals(2);
      check(original.isNull(5)).isTrue();
    });
  });

  group('slice operations and nullCount', () {
    test('slice across arbitrary ranges maintains accurate nullCount', () {
      final random = Random(42);
      for (final len in [10, 25, 64, 100, 250]) {
        final bools = List.generate(len, (_) => random.nextBool());
        final mask = ValidityMask.fromList(bools);

        // Test multiple sub-ranges
        for (var start = 0; start < len; start += 7) {
          for (var end = start; end <= len; end += 11) {
            final sliced = mask.slice(start, end);
            final expectedLength = end - start;
            final expectedNulls = bools
                .sublist(start, end)
                .where((b) => !b)
                .length;

            check(sliced.length).equals(expectedLength);
            check(sliced.nullCount).equals(expectedNulls);

            for (var i = 0; i < expectedLength; i++) {
              check(sliced.isValid(i)).equals(bools[start + i]);
            }
          }
        }
      }
    });

    test('slice fast paths for all-valid and all-null masks', () {
      final validMask = ValidityMask(50);
      final validSlice = validMask.slice(10, 30);
      check(validSlice.length).equals(20);
      check(validSlice.nullCount).equals(0);
      check(validSlice.hasNulls).isFalse();

      final nullMask = ValidityMask.allNull(50);
      final nullSlice = nullMask.slice(15, 45);
      check(nullSlice.length).equals(30);
      check(nullSlice.nullCount).equals(30);
      check(nullSlice.hasNulls).isTrue();

      final emptySlice = validMask.slice(25, 25);
      check(emptySlice.length).equals(0);
      check(emptySlice.nullCount).equals(0);
    });

    test('mutating slice does not mutate original', () {
      final original = ValidityMask(20);
      final sliced = original.slice(5, 15);
      sliced.setNull(0); // index 5 in original
      check(sliced.nullCount).equals(1);
      check(original.nullCount).equals(0);
      check(original.isValid(5)).isTrue();
    });
  });

  group('edge cases and boundaries', () {
    test('empty mask (length 0)', () {
      final mask = ValidityMask(0);
      check(mask.length).equals(0);
      check(mask.nullCount).equals(0);
      check(mask.hasNulls).isFalse();
      check(mask.bytes).isEmpty();

      final nullMask = ValidityMask.allNull(0);
      check(nullMask.length).equals(0);
      check(nullMask.nullCount).equals(0);

      final fromListMask = ValidityMask.fromList([]);
      check(fromListMask.length).equals(0);
      check(fromListMask.nullCount).equals(0);

      final sliced = mask.slice(0, 0);
      check(sliced.length).equals(0);
      check(sliced.nullCount).equals(0);

      check(() => mask.isNull(0)).throws<RangeError>();
      check(() => mask.isValid(0)).throws<RangeError>();
      check(() => mask.setNull(0)).throws<RangeError>();
      check(() => mask.setValid(0)).throws<RangeError>();
    });

    test('lengths not multiples of 8', () {
      for (final len in [1, 2, 7, 9, 15, 17, 31, 33, 63, 65, 99]) {
        final mask = ValidityMask(len);
        check(mask.length).equals(len);
        check(mask.nullCount).equals(0);

        // Set last element to null
        mask.setNull(len - 1);
        check(mask.nullCount).equals(1);
        check(mask.isNull(len - 1)).isTrue();

        // Roundtrip via fromBytes
        final copy = ValidityMask.fromBytes(len, mask.bytes);
        check(copy.nullCount).equals(1);
        check(copy.isNull(len - 1)).isTrue();
      }
    });

    test('large masks spanning multiple 32-bit words', () {
      // 1000 bits is 125 bytes = 31 words of 4 bytes + 1 byte
      final random = Random(12345);
      final bools = List.generate(1000, (_) => random.nextBool());
      final mask = ValidityMask.fromList(bools);

      final expectedNulls = bools.where((b) => !b).length;
      check(mask.nullCount).equals(expectedNulls);

      // Verify fromBytes on underlying bytes yields identical nullCount
      final fromBytes = ValidityMask.fromBytes(1000, mask.bytes);
      check(fromBytes.nullCount).equals(expectedNulls);

      for (var i = 0; i < 1000; i++) {
        check(mask.isValid(i)).equals(bools[i]);
        check(fromBytes.isValid(i)).equals(bools[i]);
      }
    });

    test('out of range indices throw RangeError', () {
      final mask = ValidityMask(10);
      check(() => mask.isNull(-1)).throws<RangeError>();
      check(() => mask.isNull(10)).throws<RangeError>();
      check(() => mask.setNull(-1)).throws<RangeError>();
      check(() => mask.setNull(10)).throws<RangeError>();
      check(() => mask.setValid(-1)).throws<RangeError>();
      check(() => mask.setValid(10)).throws<RangeError>();

      check(() => mask.slice(-1, 5)).throws<RangeError>();
      check(() => mask.slice(5, 4)).throws<RangeError>();
      check(() => mask.slice(5, 11)).throws<RangeError>();
    });

    test('negative length in constructors throws RangeError', () {
      check(() => ValidityMask(-1)).throws<RangeError>();
      check(() => ValidityMask(-8)).throws<RangeError>();
      check(() => ValidityMask.allNull(-1)).throws<RangeError>();
      check(() => ValidityMask.fromBytes(-1, Uint8List(0)))
          .throws<RangeError>();
    });

    test('invalid nullCount in fromBytes throws RangeError', () {
      check(() => ValidityMask.fromBytes(10, Uint8List(2), -1))
          .throws<RangeError>();
      check(() => ValidityMask.fromBytes(10, Uint8List(2), 11))
          .throws<RangeError>();
    });

    test('bit-parallel popcount across all 32-bit positions and patterns', () {
      final bd = ByteData(4);
      // Single 1-bit set at each bit position 0..31
      for (var bit = 0; bit < 32; bit++) {
        bd.setUint32(0, 0, Endian.little);
        final byteIndex = bit >> 3;
        final bitOffset = bit & 7;
        bd.setUint8(byteIndex, 1 << bitOffset);
        final mask = ValidityMask.fromBytes(32, bd.buffer.asUint8List());
        check(mask.nullCount).equals(31);
        check(mask.isValid(bit)).isTrue();
      }

      // Single 0-bit set at each bit position 0..31 (all other 31 bits are 1)
      for (var bit = 0; bit < 32; bit++) {
        bd.setUint32(0, 0xFFFFFFFF, Endian.little);
        final byteIndex = bit >> 3;
        final bitOffset = bit & 7;
        bd.setUint8(byteIndex, 0xFF & ~(1 << bitOffset));
        final mask = ValidityMask.fromBytes(32, bd.buffer.asUint8List());
        check(mask.nullCount).equals(1);
        check(mask.isNull(bit)).isTrue();
      }

      // Alternating bit patterns
      bd.setUint32(0, 0x55555555, Endian.little);
      final alt1 = ValidityMask.fromBytes(32, bd.buffer.asUint8List());
      check(alt1.nullCount).equals(16);

      bd.setUint32(0, 0xAAAAAAAA, Endian.little);
      final alt2 = ValidityMask.fromBytes(32, bd.buffer.asUint8List());
      check(alt2.nullCount).equals(16);

      bd.setUint32(0, 0x00000000, Endian.little);
      final allZeros = ValidityMask.fromBytes(32, bd.buffer.asUint8List());
      check(allZeros.nullCount).equals(32);

      bd.setUint32(0, 0xFFFFFFFF, Endian.little);
      final allOnes = ValidityMask.fromBytes(32, bd.buffer.asUint8List());
      check(allOnes.nullCount).equals(0);
    });

    test(
      'slice fast path with start aligned to byte boundary (start % 8 == 0)',
      () {
        final mask = ValidityMask(48);
        // Put nulls in various bytes
        mask.setNull(8);
        mask.setNull(10);
        mask.setNull(24);
        mask.setNull(25);
        mask.setNull(26);

        // Byte-aligned slice: start=8, end=32 (length 24)
        final sliced = mask.slice(8, 32);
        check(sliced.length).equals(24);
        check(sliced.nullCount).equals(5);
        check(sliced.isNull(0)).isTrue(); // orig 8
        check(sliced.isNull(2)).isTrue(); // orig 10
        check(sliced.isNull(16)).isTrue(); // orig 24
        check(sliced.isNull(17)).isTrue(); // orig 25
        check(sliced.isNull(18)).isTrue(); // orig 26
        check(sliced.isValid(1)).isTrue(); // orig 9
      },
    );
  });
}
