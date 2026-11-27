import 'dart:math' as math;
import 'dart:typed_data';

import 'package:collection/collection.dart' show ListEquality;
import 'package:more/math.dart';
import 'package:more/number.dart' show Complex, Fraction;

import 'algebra/simplify.dart';
import 'calculus/differentiation.dart';
import 'calculus/linear_form.dart';
import 'parser.dart';
import 'textualization/string.dart';

part 'ast/arithmetic.dart';
part 'ast/binder.dart';
part 'ast/call.dart';
part 'ast/constant.dart';
part 'ast/expr.dart';
part 'ast/function_spec.dart';
part 'ast/number.dart';
part 'ast/order.dart';
part 'ast/order_term.dart';
part 'ast/relational.dart';
part 'ast/variable.dart';
