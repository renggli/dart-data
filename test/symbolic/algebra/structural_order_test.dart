import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Total structural ordering of AST nodes', () {
    test('reflexivity, antisymmetry, and transitivity across node types', () {
      final nodes = <Expr>[
        IntegerNumber.of(-2),
        FractionNumber.half,
        const RealNumber(1.5),
        ComplexNumber.i,
        Constant.e,
        Constant.pi,
        const Variable('x'),
        const Variable('y'),
        Cos(const Variable('x')),
        Ln(const Variable('x')),
        Sin(const Variable('x')),
        Pow(const Variable('x'), IntegerNumber.two),
        Mul([IntegerNumber.two, const Variable('x')]),
        Add([IntegerNumber.one, const Variable('x')]),
        const OrderTerm('x', 3),
      ];

      for (var i = 0; i < nodes.length; i++) {
        check(compareStructural(nodes[i], nodes[i])).equals(0);
        for (var j = i + 1; j < nodes.length; j++) {
          final cmpIJ = compareStructural(nodes[i], nodes[j]);
          final cmpJI = compareStructural(nodes[j], nodes[i]);
          check(cmpIJ).isLessThan(0);
          check(cmpJI).isGreaterThan(0);
        }
      }
    });
  });
}
