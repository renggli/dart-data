import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('SymbolicMatrixExtension', () {
    test(
      'computes determinant, characteristicPolynomial, inverse, and derivative',
      () {
        const x = Variable('x');
        final m = Matrix<Expr>.fromRows([
          [x * x, Sin(x)],
          [IntegerNumber.of(3) * x, Pow(Constant.e, x)],
        ], type: exprDataType);
        final dm = m.derivative('x');
        check(dm.get(0, 0).toString()).equals('2 * x');
        check(dm.get(0, 1)).equals(Cos(x));
        check(dm.get(1, 0)).equals(IntegerNumber.of(3));
        check(dm.get(1, 1)).equals(Pow(Constant.e, x, isSimplified: true));

        final a = Matrix<Expr>.fromRows([
          [IntegerNumber.two, IntegerNumber.zero],
          [IntegerNumber.zero, IntegerNumber.of(4)],
        ], type: exprDataType);
        check(a.determinant()).equals(IntegerNumber.of(8));
        check(a.characteristicPolynomial('t').toString())
            .equals('8 - 6 * t + t ^ 2');
        check(a.inverse()!.get(0, 0)).equals(FractionNumber.half);
      },
    );

    test('supports element-wise algebra, calculus, textualization, and parsing round-trip', () {
      final syntax = ExprSyntax.standard;
      final parsed = syntax.parseMatrix(
        '[[(x + 1) * (x - 1), x + x], [x^2 - 4, pi]]',
      );
      check(parsed.rowCount).equals(2);
      check(parsed.colCount).equals(2);
      check(syntax.parseMatrix(parsed.format()).toNestedList())
          .deepEquals(parsed.toNestedList());

      final expanded = parsed.expand();
      check(expanded.get(0, 0).toString()).equals('-1 + x ^ 2');

      final simplified = parsed.simplify();
      check(simplified.get(0, 1).toString()).equals('2 * x');

      final factored = expanded.factor();
      check(factored.get(1, 0).expand().simplify())
          .equals(expanded.get(1, 0).simplify());

      final subbed = simplified.substitute('x', IntegerNumber.of(3)).simplify();
      check(subbed.get(0, 1)).equals(IntegerNumber.of(6));

      final approx = subbed.approximate();
      check(approx.get(1, 1)).isA<RealNumber>();

      final rat = Matrix<Expr>.fromRows([
        const [RealNumber(0.5), RealNumber(0.25)],
      ], type: exprDataType).rationalize();
      check(rat.get(0, 0)).equals(FractionNumber.half);
      check(rat.get(0, 1)).equals(FractionNumber.quarter);

      final integrated = Matrix<Expr>.fromRows([
        [const Variable('x'), Sin(const Variable('x'))],
      ], type: exprDataType).integrate('x', from: 0, to: Constant.pi);
      check(integrated.get(0, 0)).equals(
        (Pow(Constant.pi, IntegerNumber.two) / IntegerNumber.two).simplify(),
      );
      check(integrated.get(0, 1)).equals(IntegerNumber.two);

      check(rat.format()).equals('[[1/2, 1/4]]');
      check(rat.toLatex())
          .equals(r'\begin{bmatrix} \frac{1}{2} & \frac{1}{4} \end{bmatrix}');
      check(rat.toMathMl()).equals(
        '<math><mrow><mo>[</mo><mtable><mtr><mtd><mfrac><mn>1</mn><mn>2</mn></mfrac></mtd><mtd><mfrac><mn>1</mn><mn>4</mn></mfrac></mtd></mtr></mtable><mo>]</mo></mrow></math>',
      );
      check(rat.toMathMl(root: false)).equals(
        '<mrow><mo>[</mo><mtable><mtr><mtd><mfrac><mn>1</mn><mn>2</mn></mfrac></mtd><mtd><mfrac><mn>1</mn><mn>4</mn></mfrac></mtd></mtr></mtable><mo>]</mo></mrow>',
      );

      check(syntax.tryParseMatrix('[[1, 2], [3]]')).isNull();
      check(() => syntax.parseMatrix('[[1, 2], [3]]'))
          .throws<FormatException>();
      check(syntax.tryParseMatrix('not a matrix')).isNull();
      check(() => syntax.parseMatrix('not a matrix')).throws<FormatException>();
    });
  });

  group('SymbolicVectorExtension', () {
    test('computes element-wise derivative of Vector<Expr>', () {
      const x = Variable('x');
      final v = Vector<Expr>.fromList([x * x, Sin(x)], type: exprDataType);
      final dv = v.derivative('x');
      check(dv[0].toString()).equals('2 * x');
      check(dv[1]).equals(Cos(x));
    });

    test('supports element-wise algebra, calculus, textualization, and parsing round-trip', () {
      final syntax = ExprSyntax.standard;
      final v = syntax.parseVector('[(x + 1)^2, x^2 - 1, 0.5 * pi]');
      check(v.length).equals(3);
      check(syntax.parseVector(v.format()).toList()).deepEquals(v.toList());

      check(v.expand()[0].toString()).equals('1 + 2 * x + x ^ 2');
      check(v.factor()[1].expand().simplify()).equals(v[1].simplify());
      check(v.substitute('x', IntegerNumber.two).simplify()[1])
          .equals(IntegerNumber.of(3));
      check(v.approximate()[2]).isA<RealNumber>();

      final rat = Vector<Expr>.fromList(const [
        RealNumber(0.5),
        RealNumber(0.75),
      ], type: exprDataType).rationalize();
      check(rat[0]).equals(FractionNumber.half);
      check(rat.format()).equals('[1/2, 3/4]');
      check(rat.toLatex())
          .equals(r'\begin{bmatrix} \frac{1}{2} \\ \frac{3}{4} \end{bmatrix}');
      check(rat.toMathMl()).equals(
        '<math><mrow><mo>[</mo><mtable><mtr><mtd><mfrac><mn>1</mn><mn>2</mn></mfrac></mtd></mtr><mtr><mtd><mfrac><mn>3</mn><mn>4</mn></mfrac></mtd></mtr></mtable><mo>]</mo></mrow></math>',
      );
      check(rat.toMathMl(root: false)).equals(
        '<mrow><mo>[</mo><mtable><mtr><mtd><mfrac><mn>1</mn><mn>2</mn></mfrac></mtd></mtr><mtr><mtd><mfrac><mn>3</mn><mn>4</mn></mfrac></mtd></mtr></mtable><mo>]</mo></mrow>',
      );

      final intVec = Vector<Expr>.fromList([
        const Variable('x'),
        IntegerNumber.one,
      ], type: exprDataType).integrate('x', from: 0, to: 2);
      check(intVec[0]).equals(IntegerNumber.two);
      check(intVec[1]).equals(IntegerNumber.two);

      check(syntax.tryParseVector('[1, 2')).isNull();
      check(() => syntax.parseVector('[1, 2')).throws<FormatException>();
    });
  });
}
