library data.test.type;

import 'package:test/test.dart';

import 'package:data/type.dart';
import 'package:data/matrix.dart';

void main() {
  final rmm = RowMajorMatrix<int>(DataType.UINT_16, 5, 6);
  final cmm = ColumnMajorMatrix<int>(DataType.UINT_16, 5, 6);
  final coo = COOSparseMatrix<int>(DataType.UINT_16, 5, 6);
  final ms = [rmm, cmm, coo];

  for (var m in ms) {
    m.set(3, 5, 999);
    m.set(4, 3, 666);
    print(m);
  }

  return;
}
