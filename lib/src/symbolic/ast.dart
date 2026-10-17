import 'dart:math' as math;

import 'package:more/number.dart' show Complex;

import '../../special.dart' as special;
import 'number/integer.dart';
import 'number/rational.dart';
import 'parser.dart';
import 'textualization/string.dart';

export 'number/integer.dart';

part 'ast/complex_eval.dart';
part 'ast/constant.dart';
part 'ast/expr.dart';
part 'ast/function.dart';
part 'ast/integral.dart';
part 'ast/lambert_w.dart';
part 'ast/number.dart';
part 'ast/operator.dart';
part 'ast/order_term.dart';
part 'ast/piecewise.dart';
part 'ast/special_function.dart';
part 'ast/variable.dart';
