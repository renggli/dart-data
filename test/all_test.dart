library data.test.all_test;

import 'package:test/test.dart';

import 'matrix_test.dart' as matrix_test;
import 'shared_test.dart' as shared_test;
import 'type_test.dart' as type_test;
import 'vector_test.dart' as vector_test;

void main() {
  group('matrix', matrix_test.main);
  group('shared', shared_test.main);
  group('type', type_test.main);
  group('vector', vector_test.main);
}
