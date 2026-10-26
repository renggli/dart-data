import 'package:checks/checks.dart';
import 'package:data/dataframe.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('DataFrame.join - Safe Composite Keys', () {
    test('distinguishes integer and string representations', () {
      // 1. Homogeneous int column vs homogeneous string column
      final leftInt = DataFrame.fromColumns({
        'id': [1, 2],
        'left_val': ['num_one', 'num_two'],
      });
      final rightStr = DataFrame.fromColumns({
        'id': ['1', '2'],
        'right_val': ['str_one_r', 'str_two_r'],
      });
      // In the old string-serialization join, int 1 and string '1' collided!
      // In safe composite keys, int 1 does not match string '1'.
      final noMatches = leftInt.join(
        rightStr,
        on: ['id'],
        type: JoinType.inner,
      );
      check(noMatches.rowCount).equals(0);

      // 2. Heterogeneous columns using ObjectSeries
      final left = DataFrame([
        ObjectSeries<Object?>.fromList('id', [1, '1', 2]),
        Series.fromList('left_val', ['num_one', 'str_one', 'num_two']),
      ]);
      final right = DataFrame([
        ObjectSeries<Object?>.fromList('id', ['1', 1, '2']),
        Series.fromList('right_val', ['str_one_r', 'num_one_r', 'str_two_r']),
      ]);

      final joined = left.join(right, on: ['id'], type: JoinType.inner);
      check(joined.rowCount).equals(2);

      // Verify row 0: left had int 1, matched right int 1
      check(joined['id'][0]).equals(1);
      check(joined['left_val'][0]).equals('num_one');
      check(joined['right_val'][0]).equals('num_one_r');

      // Verify row 1: left had str '1', matched right str '1'
      check(joined['id'][1]).equals('1');
      check(joined['left_val'][1]).equals('str_one');
      check(joined['right_val'][1]).equals('str_one_r');
    });

    test('distinguishes null and string "null"', () {
      final left = DataFrame.fromColumns({
        'k1': ['null', null, 'valid'],
        'val_l': [1, 2, 3],
      });
      final right = DataFrame.fromColumns({
        'k1': ['null', null, 'valid'],
        'val_r': [10, 20, 30],
      });

      // In inner join, 'null' string matches 'null' string, but null never
      // matches null
      final inner = left.join(right, on: ['k1'], type: JoinType.inner);
      check(inner.rowCount).equals(2);
      check(inner['k1'].toList()).deepEquals(['null', 'valid']);
      check(inner['val_l'].toList()).deepEquals([1, 3]);
      check(inner['val_r'].toList()).deepEquals([10, 30]);

      // In left join, row with null key remains unmatched
      final leftJoined = left.join(right, on: ['k1'], type: JoinType.left);
      check(leftJoined.rowCount).equals(3);
      check(leftJoined['k1'].toList()).deepEquals(['null', null, 'valid']);
      check(leftJoined['val_l'].toList()).deepEquals([1, 2, 3]);
      check(leftJoined['val_r'].toList()).deepEquals([10, null, 30]);
    });

    test('prevents delimiter injection across composite keys', () {
      // With delimiter __#_#__:
      // Row 1: col1 = 'a__#_#__b', col2 = 'c' -> serialized as
      // 'a__#_#__b__#_#__c'
      // Row 2: col1 = 'a', col2 = 'b__#_#__c' -> serialized as
      // 'a__#_#__b__#_#__c'
      final left = DataFrame.fromColumns({
        'col1': ['a__#_#__b'],
        'col2': ['c'],
        'left_payload': ['payload_a'],
      });
      final right = DataFrame.fromColumns({
        'col1': ['a'],
        'col2': ['b__#_#__c'],
        'right_payload': ['payload_b'],
      });

      final inner = left.join(right, on: ['col1', 'col2']);
      check(inner.rowCount).equals(0);

      final rightMatching = DataFrame.fromColumns({
        'col1': ['a__#_#__b'],
        'col2': ['c'],
        'right_payload': ['matched_payload'],
      });
      final matched = left.join(rightMatching, on: ['col1', 'col2']);
      check(matched.rowCount).equals(1);
      check(matched['left_payload'][0]).equals('payload_a');
      check(matched['right_payload'][0]).equals('matched_payload');
    });

    test('multi-column keys with 2 columns (pair extractor)', () {
      final left = DataFrame.fromColumns({
        'c1': [1, 1, 2, null],
        'c2': ['a', 'b', 'a', 'a'],
        'v_left': [10, 20, 30, 40],
      });
      final right = DataFrame.fromColumns({
        'c1': [1, 2, 3],
        'c2': ['a', 'a', 'a'],
        'v_right': [100, 300, 400],
      });

      final inner = left.join(right, on: ['c1', 'c2']);
      check(inner.rowCount).equals(2);
      check(inner['v_left'].toList()).deepEquals([10, 30]);
      check(inner['v_right'].toList()).deepEquals([100, 300]);
    });

    test('multi-column keys with 3 columns (triple extractor)', () {
      final left = DataFrame.fromColumns({
        'c1': [1, 1, 1],
        'c2': ['x', 'x', 'y'],
        'c3': [true, false, true],
        'data_l': ['match', 'nomatch', 'nomatch'],
      });
      final right = DataFrame.fromColumns({
        'c1': [1],
        'c2': ['x'],
        'c3': [true],
        'data_r': ['found'],
      });

      final inner = left.join(right, on: ['c1', 'c2', 'c3']);
      check(inner.rowCount).equals(1);
      check(inner['data_l'][0]).equals('match');
      check(inner['data_r'][0]).equals('found');
    });

    test('multi-column keys with 4+ columns (TupleKey extractor)', () {
      final left = DataFrame.fromColumns({
        'k1': [1, 2],
        'k2': ['a', 'b'],
        'k3': [10.0, 20.0],
        'k4': [true, false],
        'tag_l': ['T1', 'T2'],
      });
      final right = DataFrame.fromColumns({
        'k1': [2, 3],
        'k2': ['b', 'c'],
        'k3': [20.0, 30.0],
        'k4': [false, true],
        'tag_r': ['R2', 'R3'],
      });

      final inner = left.join(right, on: ['k1', 'k2', 'k3', 'k4']);
      check(inner.rowCount).equals(1);
      check(inner['tag_l'][0]).equals('T2');
      check(inner['tag_r'][0]).equals('R2');

      final outer = left.join(
        right,
        on: ['k1', 'k2', 'k3', 'k4'],
        type: JoinType.outer,
      );
      check(outer.rowCount).equals(3);
    });

    test('composite keys with type differences across components', () {
      final left = DataFrame([
        ObjectSeries<Object?>.fromList('c1', [1, '1']),
        Series.fromList('c2', [2, 2]),
      ]);
      final right = DataFrame([
        ObjectSeries<Object?>.fromList('c1', ['1', 1]),
        Series.fromList('c2', [2, 2]),
        Series.fromList('extra', ['from_str', 'from_int']),
      ]);

      final joined = left.join(right, on: ['c1', 'c2']);
      check(joined.rowCount).equals(2);
      check(joined['c1'].toList()).deepEquals([1, '1']);
      check(joined['extra'].toList()).deepEquals(['from_int', 'from_str']);
    });
  });

  group('DataFrame.join - Edge Cases & Errors', () {
    test('throws ArgumentError if join column missing in either table', () {
      final df1 = DataFrame.fromColumns({
        'a': [1, 2],
      });
      final df2 = DataFrame.fromColumns({
        'b': [1, 2],
      });

      check(() => df1.join(df2, on: ['missing'])).throws<ArgumentError>();
      check(() => df1.join(df2, on: ['a'])).throws<ArgumentError>();
    });

    test('supports custom suffix for non-key column collisions', () {
      final df1 = DataFrame.fromColumns({
        'k': [1, 2],
        'val': ['left1', 'left2'],
      });
      final df2 = DataFrame.fromColumns({
        'k': [1, 2],
        'val': ['right1', 'right2'],
      });

      final joined = df1.join(df2, on: ['k'], suffix: '_rightside');
      check(joined.columnNames).deepEquals(['k', 'val', 'val_rightside']);
      check(joined['val_rightside'].toList()).deepEquals(['right1', 'right2']);
    });

    test('handles empty DataFrames gracefully', () {
      final emptyLeft = DataFrame.fromColumns({'id': [], 'name': []});
      final right = DataFrame.fromColumns({
        'id': [1, 2],
        'score': [10, 20],
      });

      final inner = emptyLeft.join(right, on: ['id'], type: JoinType.inner);
      check(inner.rowCount).equals(0);

      final rightJoined = emptyLeft.join(
        right,
        on: ['id'],
        type: JoinType.right,
      );
      check(rightJoined.rowCount).equals(2);
      check(rightJoined['score'].toList()).deepEquals([10, 20]);
      check(rightJoined['name'].toList()).deepEquals([null, null]);
    });

    test('handles many-to-many matches properly', () {
      final left = DataFrame.fromColumns({
        'id': [1, 1],
        'l_val': ['a', 'b'],
      });
      final right = DataFrame.fromColumns({
        'id': [1, 1],
        'r_val': ['x', 'y'],
      });

      final joined = left.join(right, on: ['id']);
      check(joined.rowCount).equals(4);
      check(joined['l_val'].toList()).deepEquals(['a', 'a', 'b', 'b']);
      check(joined['r_val'].toList()).deepEquals(['x', 'y', 'x', 'y']);
    });

    test('4+ columns with nulls do not match across tables', () {
      final left = DataFrame.fromColumns({
        'k1': [1, null],
        'k2': ['a', 'b'],
        'k3': [10.0, 20.0],
        'k4': [true, false],
        'val_l': ['L1', 'L2'],
      });
      final right = DataFrame.fromColumns({
        'k1': [1, null],
        'k2': ['a', 'b'],
        'k3': [10.0, 20.0],
        'k4': [true, false],
        'val_r': ['R1', 'R2'],
      });

      final inner = left.join(right, on: ['k1', 'k2', 'k3', 'k4']);
      check(inner.rowCount).equals(1);
      check(inner['val_l'][0]).equals('L1');
      check(inner['val_r'][0]).equals('R1');
    });

    test('numeric equality between int and double matches in join', () {
      final left = DataFrame.fromColumns({
        'k': [1, 2],
        'val_l': ['one', 'two'],
      });
      final right = DataFrame.fromColumns({
        'k': [1.0, 2.0],
        'val_r': ['one_r', 'two_r'],
      });

      final inner = left.join(right, on: ['k']);
      check(inner.rowCount).equals(2);
      check(inner['val_l'].toList()).deepEquals(['one', 'two']);
      check(inner['val_r'].toList()).deepEquals(['one_r', 'two_r']);
    });
  });

  group('DataFrame.sortMergeJoin', () {
    test('inner join with pre-sorted keys', () {
      final left = DataFrame.fromColumns({
        'id': [1, 2, 4],
        'name': ['Alice', 'Bob', 'Dave'],
      });
      final right = DataFrame.fromColumns({
        'id': [2, 3, 4],
        'age': [25, 30, 40],
      });

      final merged = left.join(
        right,
        on: ['id'],
        method: JoinMethod.sortMerge,
        isSorted: true,
      );
      check(merged.rowCount).equals(2);
      check(merged['id'].toList()).deepEquals([2, 4]);
      check(merged['name'].toList()).deepEquals(['Bob', 'Dave']);
      check(merged['age'].toList()).deepEquals([25, 40]);
    });

    test('left, right, and outer sort-merge joins', () {
      final left = DataFrame.fromColumns({
        'id': [1, 2, 4],
        'name': ['Alice', 'Bob', 'Dave'],
      });
      final right = DataFrame.fromColumns({
        'id': [2, 3, 4],
        'age': [25, 30, 40],
      });

      final leftJoined = left.join(
        right,
        on: ['id'],
        type: JoinType.left,
        method: JoinMethod.sortMerge,
        isSorted: true,
      );
      check(leftJoined.rowCount).equals(3);
      check(leftJoined['id'].toList()).deepEquals([1, 2, 4]);
      check(leftJoined['age'].toList()).deepEquals([null, 25, 40]);

      final rightJoined = left.join(
        right,
        on: ['id'],
        type: JoinType.right,
        method: JoinMethod.sortMerge,
        isSorted: true,
      );
      check(rightJoined.rowCount).equals(3);
      check(rightJoined['id'].toList()).deepEquals([2, 3, 4]);
      check(rightJoined['name'].toList()).deepEquals(['Bob', null, 'Dave']);
      check(rightJoined['age'].toList()).deepEquals([25, 30, 40]);

      final outerJoined = left.join(
        right,
        on: ['id'],
        type: JoinType.outer,
        method: JoinMethod.sortMerge,
        isSorted: true,
      );
      check(outerJoined.rowCount).equals(4);
      check(outerJoined['id'].toList()).deepEquals([1, 2, 3, 4]);
      check(outerJoined['name'].toList())
          .deepEquals(['Alice', 'Bob', null, 'Dave']);
      check(outerJoined['age'].toList()).deepEquals([null, 25, 30, 40]);
    });

    test('handles duplicate key runs (many-to-many)', () {
      final left = DataFrame.fromColumns({
        'id': [1, 1, 2, 3, 3],
        'val_l': ['a', 'b', 'c', 'd', 'e'],
      });
      final right = DataFrame.fromColumns({
        'id': [1, 1, 1, 3, 4],
        'val_r': ['u', 'v', 'w', 'x', 'y'],
      });

      final merged = left.join(
        right,
        on: ['id'],
        method: JoinMethod.sortMerge,
        isSorted: true,
      );
      // id 1: 2 * 3 = 6 rows
      // id 3: 2 * 1 = 2 rows
      check(merged.rowCount).equals(8);
      check(merged['id'].toList()).deepEquals([1, 1, 1, 1, 1, 1, 3, 3]);
      check(merged['val_l'].toList())
          .deepEquals(['a', 'a', 'a', 'b', 'b', 'b', 'd', 'e']);
      check(merged['val_r'].toList())
          .deepEquals(['u', 'v', 'w', 'u', 'v', 'w', 'x', 'x']);
    });

    test('sorts automatically when isSorted is false', () {
      final left = DataFrame.fromColumns({
        'id': [4, 1, 2],
        'name': ['Dave', 'Alice', 'Bob'],
      });
      final right = DataFrame.fromColumns({
        'id': [3, 2, 4],
        'age': [30, 25, 40],
      });

      final merged = left.join(right, on: ['id'], method: JoinMethod.sortMerge);
      check(merged.rowCount).equals(2);
      check(merged['id'].toList()).deepEquals([2, 4]);
      check(merged['name'].toList()).deepEquals(['Bob', 'Dave']);
      check(merged['age'].toList()).deepEquals([25, 40]);
    });

    test('validates sorted order when isSorted is true', () {
      final unsortedLeft = DataFrame.fromColumns({
        'id': [2, 1],
        'val': ['a', 'b'],
      });
      final sortedRight = DataFrame.fromColumns({
        'id': [1, 2],
        'val': ['x', 'y'],
      });

      check(
        () => unsortedLeft.join(
          sortedRight,
          on: ['id'],
          method: JoinMethod.sortMerge,
          isSorted: true,
        ),
      ).throws<ArgumentError>();
      check(
        () => sortedRight.join(
          unsortedLeft,
          on: ['id'],
          method: JoinMethod.sortMerge,
          isSorted: true,
        ),
      ).throws<ArgumentError>();
    });

    test('parity between hash join and sortMergeJoin across join types', () {
      final left = DataFrame.fromColumns({
        'k': [1, 2, 3, 5],
        'name': ['A', 'B', 'C', 'E'],
      });
      final right = DataFrame.fromColumns({
        'k': [2, 3, 4, 5],
        'val': [20, 30, 40, 50],
      });

      for (final type in JoinType.values) {
        final hashRes = left.join(
          right,
          on: ['k'],
          type: type,
          method: JoinMethod.hash,
        );
        final sortRes = left.join(
          right,
          on: ['k'],
          type: type,
          method: JoinMethod.sortMerge,
        );

        check(sortRes.rowCount).equals(hashRes.rowCount);
        check(sortRes.columnNames).deepEquals(hashRes.columnNames);
      }
    });

    test('handles empty DataFrames in sort-merge', () {
      final empty = DataFrame.fromColumns({'id': <int>[], 'val': <String>[]});
      final non = DataFrame.fromColumns({
        'id': [1, 2],
        'val': ['a', 'b'],
      });

      final inner = empty.join(
        non,
        on: ['id'],
        method: JoinMethod.sortMerge,
        isSorted: true,
      );
      check(inner.rowCount).equals(0);

      final rightOuter = empty.join(
        non,
        on: ['id'],
        type: JoinType.right,
        method: JoinMethod.sortMerge,
        isSorted: true,
      );
      check(rightOuter.rowCount).equals(2);
      check(rightOuter['id'].toList()).deepEquals([1, 2]);

      final leftOuter = non.join(
        empty,
        on: ['id'],
        type: JoinType.left,
        method: JoinMethod.sortMerge,
        isSorted: true,
      );
      check(leftOuter.rowCount).equals(2);
      check(leftOuter['id'].toList()).deepEquals([1, 2]);
    });

    test(
      'sortMergeJoin with null keys, strings, custom objects, and outer joins',
      () {
        final left = DataFrame.fromColumns({
          'key': ['alpha', null, 'gamma', 'omega'],
          'l_val': [1, 2, 3, 4],
        });
        final right = DataFrame.fromColumns({
          'key': [null, 'beta', 'gamma'],
          'r_val': [10, 20, 30],
        });

        // Left join with nulls and remaining left rows
        final leftJoin = left.join(
          right,
          on: ['key'],
          type: JoinType.left,
          method: JoinMethod.sortMerge,
        );
        check(leftJoin.rowCount).equals(4);

        // Right join with nulls and remaining right rows
        final rightJoin = left.join(
          right,
          on: ['key'],
          type: JoinType.right,
          method: JoinMethod.sortMerge,
        );
        check(rightJoin.rowCount).equals(3);

        // Full outer join
        final outerJoin = left.join(
          right,
          on: ['key'],
          type: JoinType.outer,
          method: JoinMethod.sortMerge,
        );
        check(outerJoin.rowCount).equals(6);

        // Non-Comparable objects compared by toString()
        final leftObj = DataFrame([
          ObjectSeries<Object?>.fromList('key', [
            const _Item('a'),
            const _Item('b'),
          ]),
          Series.fromList('v', [1, 2]),
        ]);
        final rightObj = DataFrame([
          ObjectSeries<Object?>.fromList('key', [
            const _Item('b'),
            const _Item('c'),
          ]),
          Series.fromList('v', [20, 30]),
        ]);
        final objJoin = leftObj.join(
          rightObj,
          on: ['key'],
          type: JoinType.inner,
          method: JoinMethod.sortMerge,
        );
        check(objJoin.rowCount).equals(1);
        check(objJoin['key'][0].toString()).equals('b');
      },
    );
  });

  group('DataFrame.join - Asymmetric Keys (leftOn and rightOn)', () {
    final left = DataFrame.fromColumns({
      'user_id': [1, 2, 3],
      'name': ['Alice', 'Bob', 'Charlie'],
    });
    final right = DataFrame.fromColumns({
      'id': [2, 3, 4],
      'score': [90, 85, 95],
    });

    test('hash join with leftOn and rightOn', () {
      final joined = left.join(
        right,
        leftOn: ['user_id'],
        rightOn: ['id'],
        type: JoinType.inner,
      );
      check(joined.rowCount).equals(2);
      check(joined.columnNames).deepEquals(['user_id', 'name', 'id', 'score']);
      check(joined['user_id'].toList()).deepEquals([2, 3]);
      check(joined['id'].toList()).deepEquals([2, 3]);
      check(joined['name'].toList()).deepEquals(['Bob', 'Charlie']);
      check(joined['score'].toList()).deepEquals([90, 85]);
    });

    test('sortMerge join with leftOn and rightOn', () {
      final joined = left.join(
        right,
        leftOn: ['user_id'],
        rightOn: ['id'],
        type: JoinType.inner,
        method: JoinMethod.sortMerge,
      );
      check(joined.rowCount).equals(2);
      check(joined['user_id'].toList()).deepEquals([2, 3]);
      check(joined['id'].toList()).deepEquals([2, 3]);
    });

    test(
      'preserves narrow DataTypes across joins and promotes mixed key types',
      () {
        final l = DataFrame([
          Series<int>.fromList('k', [1, 2], type: DataType.int8),
          Series<double>.fromList('v1', [1.5, 2.5], type: DataType.float32),
        ]);
        final r = DataFrame([
          Series<int>.fromList('k', [2, 3], type: DataType.int8),
          Series<int>.fromList('v2', [10, 20], type: DataType.uint16),
        ]);
        final j = l.join(r, on: ['k'], type: JoinType.left);
        check(j['k'].dataType).equals(DataType.int8);
        check(j['v1'].dataType).equals(DataType.float32);
        check(j['v2'].dataType).equals(DataType.uint16);

        final rWide = DataFrame([
          Series<int>.fromList('k', [2, 300], type: DataType.int32),
          Series<int>.fromList('v2', [10, 20], type: DataType.int32),
        ]);
        final rightJoined = l.join(rWide, on: ['k'], type: JoinType.right);
        check(rightJoined['k'].dataType).equals(DataType.int32);
        check(rightJoined['k'].toList()).deepEquals([2, 300]);
      },
    );

    test('validation errors for leftOn and rightOn', () {
      check(() => left.join(right)).throws<ArgumentError>();
      check(() => left.join(right, leftOn: ['user_id']))
          .throws<ArgumentError>();
      check(
        () => left.join(right, leftOn: ['user_id'], rightOn: ['id', 'score']),
      ).throws<ArgumentError>();
      check(() => left.join(right, leftOn: ['bad_col'], rightOn: ['id']))
          .throws<ArgumentError>();
      check(() => left.join(right, leftOn: ['user_id'], rightOn: ['bad_col']))
          .throws<ArgumentError>();

      // sortMerge join with null keys in left DataFrame under left/outer join
      final leftWithNull = DataFrame.fromColumns({
        'k': [1, null, 3],
        'lv': ['a', 'b', 'c'],
      });
      final rightForNull = DataFrame.fromColumns({
        'k': [1, 2],
        'rv': ['x', 'y'],
      });
      final smLeft = leftWithNull.join(
        rightForNull,
        on: ['k'],
        type: JoinType.left,
        method: JoinMethod.sortMerge,
      );
      check(smLeft.rowCount).equals(3);
    });
  });
}

final class _Item {
  const new(this.name);
  final String name;

  @override
  String toString() => name;
}
