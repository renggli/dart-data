import 'package:test/test.dart';

import 'matrix_test.dart' as matrix_test;
import 'numeric_test.dart' as numeric_test;
import 'polynomial_test.dart' as polynomial_test;
import 'shared_test.dart' as shared_test;
import 'stats_test.dart' as stats_test;
import 'tutorial_test.dart' as tutorial_test;
import 'type_test.dart' as type_test;
import 'vector_test.dart' as vector_test;

void main() {
  group('matrix', matrix_test.main);
  group('numeric', numeric_test.main);
  group('polynomial', polynomial_test.main);
  group('shared', shared_test.main);
  group('stats', stats_test.main);
  group('tutorial', tutorial_test.main);
  group('type', type_test.main);
  group('vector', vector_test.main);
}
