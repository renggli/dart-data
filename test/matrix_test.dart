library data.test.type;

import 'package:test/test.dart';

import 'package:data/type.dart';
import 'package:data/matrix.dart';

void main() {
  final rmm = RowMajorMatrix<int>(DataType.UINT_16, 5, 6);
  final cmm = ColumnMajorMatrix<int>(DataType.UINT_16, 5, 6);

  print(rmm);

  print(cmm);
}
