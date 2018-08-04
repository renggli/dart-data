library data.test.type;

import 'package:data/matrix.dart';
import 'package:data/type.dart';

void main() {
  final rmm = RowMajorMatrix<int>(DataType.uint16, 5, 6);
  final cmm = ColumnMajorMatrix<int>(DataType.uint16, 5, 6);
  final coo = COOSparseMatrix<int>(DataType.uint16, 5, 6);
  final ms = [rmm, cmm, coo];

  for (var m in ms) {
    m.set(3, 5, 999);
    m.set(4, 3, 666);
    print(m);
  }

  coo.set(3, 5, 0);
  print(coo);
  coo.set(4, 3, 0);
  print(coo);

  return;
}
