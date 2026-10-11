import 'package:checks/checks.dart';
import 'package:data/dataframe.dart';
import 'package:test/test.dart';

void main() {
  group('Arrow IPC Streaming', () {
    test('round-trips DataFrame with numbers, strings, and booleans', () {
      final df = DataFrame.fromColumns({
        'name': ['Alice', null, 'Bob', 'Charlie 🚀'],
        'age': [25, 30, null, 42],
        'score': [95.5, 88.0, 72.3, null],
        'verified': [true, false, true, false],
      });

      final ipcBytes = df.toArrowIpc();
      check(ipcBytes.isNotEmpty).isTrue();

      // Check header continuation token (0xFFFFFFFF)
      check(ipcBytes[0]).equals(0xFF);
      check(ipcBytes[1]).equals(0xFF);
      check(ipcBytes[2]).equals(0xFF);
      check(ipcBytes[3]).equals(0xFF);

      final imported = DataFrame.fromArrowIpc(ipcBytes);
      check(imported.rowCount).equals(4);
      check(imported.columnCount).equals(4);
      check(imported.columnNames)
          .deepEquals(['name', 'age', 'score', 'verified']);

      check(imported['name'].toList())
          .deepEquals(['Alice', null, 'Bob', 'Charlie 🚀']);
      check(imported['age'].toList()).deepEquals([25, 30, null, 42]);
      check(imported['score'].toList()).deepEquals([95.5, 88.0, 72.3, null]);
      check(imported['verified'].toList())
          .deepEquals([true, false, true, false]);
    });

    test('round-trips empty DataFrame with schema', () {
      final df = DataFrame.fromColumns({
        'str': <String>[],
        'int': <int>[],
        'float': <double>[],
        'bool': <bool>[],
      });

      final ipcBytes = df.toArrowIpc();
      final imported = DataFrame.fromArrowIpc(ipcBytes);

      check(imported.rowCount).equals(0);
      check(imported.columnCount).equals(4);
      check(imported.columnNames).deepEquals(['str', 'int', 'float', 'bool']);
    });
  });
}
