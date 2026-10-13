import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:data/tensor.dart';
import 'package:more/number.dart' show Complex, Fraction;
import 'package:test/scaffolding.dart';

void main() {
  const x = Variable('x');
  const y = Variable('y');

  group('ExprDataType properties & contracts', () {
    test('name, defaultValue, isNullable, toString', () {
      check(exprDataType.name).equals('expr');
      check(exprDataType.defaultValue).equals(RationalNumber.zero);
      check(exprDataType.isNullable).isFalse();
      check(exprDataType.toString()).equals('DataType.expr');
      check(exprDataType.equality).equals(const ExprEquality());
      check(exprDataType.field).equals(ExprField.instance);
    });

    test('comparator structural ordering', () {
      final cmp = exprDataType.comparator;
      check(cmp(const RationalNumber(1), x)).isLessThan(0);
      check(cmp(x, const RationalNumber(1))).isGreaterThan(0);
      check(cmp(x, x)).equals(0);
      check(cmp(x, y)).isLessThan(0);
    });

    test('cast method for various numeric types and strings', () {
      // Expr identity
      check(exprDataType.cast(x)).equals(x);

      // int
      final castInt = exprDataType.cast(42);
      check(castInt).equals(const RationalNumber(42));

      // Fraction
      final castFrac = exprDataType.cast(Fraction(3, 4));
      check(castFrac).equals(const RationalNumber(3, 4));

      // Complex
      final castComp = exprDataType.cast(const Complex(2, 5));
      check(castComp is ComplexNumber).isTrue();
      check((castComp as ComplexNumber).real).equals(2.0);
      check(castComp.imaginary).equals(5.0);

      // Purely real Complex
      final castRealComp = exprDataType.cast(const Complex(7, 0));
      check(castRealComp).equals(const RationalNumber(7));

      // num (double)
      final castDouble = exprDataType.cast(3.14);
      check(castDouble is RealNumber).isTrue();
      check((castDouble as RealNumber).value).equals(3.14);

      // BigInt
      final castBigInt = exprDataType.cast(BigInt.from(100));
      check(castBigInt).equals(const RationalNumber(100));

      // String
      final castStr = exprDataType.cast('2 * x + 1');
      check(castStr)
          .equals(const RationalNumber(2) * x + const RationalNumber(1));

      // Unsupported type throws ArgumentError
      check(() => exprDataType.cast(DateTime.now())).throws<ArgumentError>();
    });
  });

  group('ExprEquality', () {
    const eq = ExprEquality();

    test('isEqual and hash', () {
      check(eq.isEqual(x + 1, x + 1)).isTrue();
      check(eq.isEqual(x + 1, x + 2)).isFalse();
      check(eq.hash(x)).equals(x.hashCode);
    });

    test('isClose with epsilon', () {
      check(eq.isClose(x, x, 1e-6)).isTrue();
      // Symbolically simplifies to 0
      check(eq.isClose(x - x, RationalNumber.zero, 1e-6)).isTrue();

      // Numerical closeness
      const num1 = RealNumber(1.0000001);
      const num2 = RealNumber(1.0);
      check(eq.isClose(num1, num2, 1e-5)).isTrue();
      check(eq.isClose(num1, num2, 1e-8)).isFalse();

      // Unresolved variable diff is not close
      check(eq.isClose(x, y, 1e-3)).isFalse();
    });
  });

  group('ExprField axioms & operations', () {
    const field = ExprField.instance;

    test('identities and basic arithmetic', () {
      check(field.additiveIdentity).equals(RationalNumber.zero);
      check(field.multiplicativeIdentity).equals(RationalNumber.one);

      // Add & sub
      check(field.add(x, RationalNumber.zero)).equals(x);
      check(field.add(x, x)).equals(const RationalNumber(2) * x);
      check(field.sub(x, x)).equals(RationalNumber.zero);
      check(field.neg(x)).equals(-x);

      // Mul & div & inv
      check(field.mul(x, RationalNumber.one)).equals(x);
      check(field.mul(x, RationalNumber.zero)).equals(RationalNumber.zero);
      check(field.mul(x, x)).equals(x.pow(2));
      check(field.div(x.pow(2), x)).equals(x);
      check(field.inv(const RationalNumber(2)))
          .equals(const RationalNumber(1, 2));

      // Scale
      check(field.scale(x, 3)).equals(const RationalNumber(3) * x);

      // Pow & sqrt
      check(field.pow(x, const RationalNumber(2))).equals(x.pow(2));
      check(field.sqrt(const RationalNumber(4)))
          .equals(const RationalNumber(2));
      check(field.sqrt(x.pow(2))).equals(const Abs(x));

      // Abs, exp, log
      check(field.abs(const RationalNumber(-5)))
          .equals(const RationalNumber(5));
      check(field.exp(RationalNumber.zero)).equals(RationalNumber.one);
      check(field.log(RationalNumber.one)).equals(RationalNumber.zero);
    });

    test('conjugate', () {
      check(field.conjugate(ComplexNumber.i))
          .equals(const ComplexNumber(0.0, -1.0));
      check(field.conjugate(const ComplexNumber(3, 4)))
          .equals(const ComplexNumber(3, -4));
      check(field.conjugate(x)).equals(x);
      check(field.conjugate(x + ComplexNumber.i)).equals(x - ComplexNumber.i);
    });

    test('norm', () {
      check(field.norm(const RationalNumber(3, 4))).equals(0.75);
      check(field.norm(const ComplexNumber(3, 4))).equals(5.0);
      check(() => field.norm(x)).throws<UnsupportedError>();
    });

    test('special constants and unsupported operations', () {
      check(field.infinity).equals(ConstantNumber.infinity);
      check(field.negativeInfinity).equals(-ConstantNumber.infinity);
      check(field.nan is RealNumber).isTrue();

      check(() => field.mod(x, y)).throws<UnsupportedError>();
      check(() => field.division(x, y)).throws<UnsupportedError>();
      check(() => field.remainder(x, y)).throws<UnsupportedError>();
      check(() => field.modPow(x, y, x)).throws<UnsupportedError>();
      check(() => field.modInverse(x, y)).throws<UnsupportedError>();
      check(() => field.gcd(x, y)).throws<UnsupportedError>();
    });

    test('isZero predicate', () {
      check(field.isZero(RationalNumber.zero)).isTrue();
      check(field.isZero(const RealNumber(0.0))).isTrue();
      check(field.isZero((x - x).simplify())).isTrue();
      check(field.isZero(x)).isFalse();
      check(field.isZero(RationalNumber.one)).isFalse();
    });
  });

  group('Vector<Expr> and Matrix<Expr> interoperability', () {
    test('Vector dot product and linear operations', () {
      final v1 = Vector<Expr>.fromList([x, y], type: exprDataType);
      final v2 = Vector<Expr>.fromList([x, y], type: exprDataType);

      final dot = v1.dot(v2);
      check(dot.simplify()).equals(x.pow(2) + y.pow(2));

      final outer = v1.outer(v2);
      check(outer.rowCount).equals(2);
      check(outer.colCount).equals(2);
      check(outer[0][0].simplify()).equals(x.pow(2));
      check(outer[0][1].simplify()).equals(x * y);
      check(outer[1][0].simplify()).equals(x * y);
      check(outer[1][1].simplify()).equals(y.pow(2));
    });

    test('Matrix multiplication and trace', () {
      // M1 = [[x, 1], [0, y]]
      final m1 = Matrix<Expr>.fromRows([
        [x, RationalNumber.one],
        [RationalNumber.zero, y],
      ], type: exprDataType);

      // M2 = [[y, 0], [1, x]]
      final m2 = Matrix<Expr>.fromRows([
        [y, RationalNumber.zero],
        [RationalNumber.one, x],
      ], type: exprDataType);

      // M1 * M2 = [[x*y + 1, x], [y, x*y]]
      final prod = m1 * m2;
      check(prod[0][0].simplify()).equals(x * y + 1);
      check(prod[0][1].simplify()).equals(x);
      check(prod[1][0].simplify()).equals(y);
      check(prod[1][1].simplify()).equals(x * y);

      check(m1.trace.simplify()).equals(x + y);
    });

    test('Identity matrix', () {
      final id = Matrix<Expr>.identity(3, type: exprDataType);
      check(id.rowCount).equals(3);
      check(id.colCount).equals(3);
      check(id[0][0]).equals(RationalNumber.one);
      check(id[0][1]).equals(RationalNumber.zero);
      check(id[1][1]).equals(RationalNumber.one);
      check(id[2][2]).equals(RationalNumber.one);
    });

    test('Matrix and Vector +, -, unary - operators', () {
      final v1 = Vector<Expr>.fromList([x, y], type: exprDataType);
      final v2 = Vector<Expr>.fromList([y, x], type: exprDataType);
      final m1 = Matrix<Expr>.fromRows([
        [x, y],
        [y, x],
      ], type: exprDataType);
      final m2 = Matrix<Expr>.fromRows([
        [y, x],
        [x, y],
      ], type: exprDataType);

      // Vector operations
      final vSum = v1 + v2;
      check(vSum[0].simplify()).equals(x + y);
      check(vSum[1].simplify()).equals(x + y);

      final vDiff = v1 - v2;
      check(vDiff[0].simplify()).equals(x - y);

      final vNeg = -v1;
      check(vNeg[0].simplify()).equals(-x);

      // Matrix operations
      final mSum = m1 + m2;
      check(mSum[0][0].simplify()).equals(x + y);

      final mDiff = m1 - m2;
      check(mDiff[0][0].simplify()).equals(x - y);

      final mNeg = -m1;
      check(mNeg[0][0].simplify()).equals(-x);

      // Vector Hadamard and division
      final vMul = v1 * v2;
      check(vMul[0].simplify()).equals(x * y);
      final vDiv = v1 / v2;
      check(vDiv[0].simplify()).equals(x / y);

      // Matrix Hadamard and Tensor division
      final mHadamard = m1.hadamard(m2);
      check(mHadamard[0][0].simplify()).equals(x * y);
      final mTensorDiv = Matrix<Expr>(m1.tensor / m2.tensor);
      check(mTensorDiv[0][0].simplify()).equals(x / y);

      // Matrix multiplication
      final mProd = m1 * m2;
      check(mProd[0][0].simplify()).equals(const RationalNumber(2) * (x * y));
    });

    test('Vector and Matrix scale, copy, and solve without TypeError', () {
      final v = Vector<Expr>.fromList([x, y], type: exprDataType);
      final m = Matrix<Expr>.fromRows([
        [x, y],
        [y, x],
      ], type: exprDataType);

      final vScale = v.scale(x);
      check(vScale[0].simplify()).equals(x.pow(2));

      final mScale = m.scale(x);
      check(mScale[0][0].simplify()).equals(x.pow(2));

      final vCopy = v.copy();
      check(vCopy[0]).equals(x);

      final mCopy = m.copy();
      check(mCopy[0][0]).equals(x);

      final t = Tensor<Expr>.filled(x, shape: [2, 2], type: exprDataType);
      final tCopy = t.copy();
      check(tCopy.getValue([0, 0])).equals(x);
      check(tCopy.type).equals(exprDataType);

      final diagM = Matrix<Expr>.fromRows([
        [const RationalNumber(2), RationalNumber.zero],
        [RationalNumber.zero, const RationalNumber(3)],
      ], type: exprDataType);
      final rhs = Vector<Expr>.fromList([x, y], type: exprDataType);
      final sol = diagM.solve(rhs);
      check(sol[0].simplify()).equals(const RationalNumber(1, 2) * x);
      check(sol[1].simplify()).equals(const RationalNumber(1, 3) * y);

      final upperM = Matrix<Expr>.fromRows([
        [const RationalNumber(2), const RationalNumber(1)],
        [RationalNumber.zero, const RationalNumber(3)],
      ], type: exprDataType);
      final solUpper = upperM.solve(rhs);
      check(solUpper[1].simplify()).equals(const RationalNumber(1, 3) * y);
      check(
        solUpper[0].expand().simplify(),
      ).equals(const RationalNumber(1, 2) * x - const RationalNumber(1, 6) * y);

      // Matrix RHS solving: U * X = D
      final matSol = upperM.solve(diagM);
      check(matSol.rowCount).equals(2);
      check(matSol.colCount).equals(2);
      final reconstructed = upperM * matSol;
      check(reconstructed[0][0].simplify()).equals(const RationalNumber(2));
      check(reconstructed[0][1].simplify()).equals(RationalNumber.zero);
      check(reconstructed[1][0].simplify()).equals(RationalNumber.zero);
      check(reconstructed[1][1].simplify()).equals(const RationalNumber(3));

      // Systems with unresolved variables throw UnsupportedError on LUDecomposition pivoting,
      // but solve exactly via Faddeev-LeVerrier inverse
      final diagMVar = Matrix<Expr>.fromRows([
        [x, RationalNumber.zero],
        [RationalNumber.zero, y],
      ], type: exprDataType);
      final numRhs = Vector<Expr>.fromList([
        const RationalNumber(1),
        const RationalNumber(2),
      ], type: exprDataType);
      check(() => diagMVar.solve(numRhs)).throws<UnsupportedError>();

      final invDiag = diagMVar.inverse()!;
      final solDiagVar = (invDiag * numRhs.toMatrix()).col(0);
      check(solDiagVar[0].simplify()).equals(RationalNumber.one / x);
      check(solDiagVar[1].simplify()).equals(const RationalNumber(2) / y);
    });
  });

  group('Adversarial stress-testing: Field axioms & algebraic laws', () {
    const field = ExprField.instance;
    const z = Variable('z');

    test(
      'Addition axioms (associativity, commutativity, identity, inverse)',
      () {
        // Commutativity: a + b == b + a
        check(field.add(x, y)).equals(field.add(y, x));
        check(field.add(x, const RationalNumber(5)))
            .equals(field.add(const RationalNumber(5), x));

        // Associativity: (a + b) + c == a + (b + c)
        final lhsAdd = field.add(field.add(x, y), z);
        final rhsAdd = field.add(x, field.add(y, z));
        check(lhsAdd).equals(rhsAdd);

        // Additive identity: a + 0 == a
        check(field.add(x, field.additiveIdentity)).equals(x);
        check(field.add(field.additiveIdentity, x)).equals(x);

        // Additive inverse: a + (-a) == 0
        check(field.add(x, field.neg(x))).equals(field.additiveIdentity);
        check(field.add(x.pow(3), field.neg(x.pow(3))))
            .equals(field.additiveIdentity);
      },
    );

    test(
      'Multiplication axioms (associativity, commutativity, identity, inverse)',
      () {
        // Commutativity: a * b == b * a
        check(field.mul(x, y)).equals(field.mul(y, x));

        // Associativity: (a * b) * c == a * (b * c)
        final lhsMul = field.mul(field.mul(x, y), z);
        final rhsMul = field.mul(x, field.mul(y, z));
        check(lhsMul).equals(rhsMul);

        // Multiplicative identity: a * 1 == a
        check(field.mul(x, field.multiplicativeIdentity)).equals(x);
        check(field.mul(field.multiplicativeIdentity, x)).equals(x);

        // Multiplicative inverse: a * a^-1 == 1
        check(field.mul(x, field.inv(x))).equals(field.multiplicativeIdentity);
        check(
          field.mul(
            const RationalNumber(3, 7),
            field.inv(const RationalNumber(3, 7)),
          ),
        ).equals(field.multiplicativeIdentity);
      },
    );

    test('Distributivity: a * (b + c) == a * b + a * c', () {
      // a * (b + c) - (a * b + a * c) == 0
      final lhs = field.mul(x, field.add(y, z));
      final rhs = field.add(field.mul(x, y), field.mul(x, z));
      final diff = field.sub(lhs, rhs);
      check(diff.expand().simplify()).equals(RationalNumber.zero);

      // Complex number distributivity: c1 * (c2 + c3) == c1 * c2 + c1 * c3
      const c1 = ComplexNumber(2, 3);
      const c2 = ComplexNumber(4, -5);
      const c3 = ComplexNumber(-1, 7);
      final cLhs = field.mul(c1, field.add(c2, c3));
      final cRhs = field.add(field.mul(c1, c2), field.mul(c1, c3));
      check(field.sub(cLhs, cRhs)).equals(RationalNumber.zero);
    });

    test('Conjugate algebraic properties (involution, additivity, multiplicativity)', () {
      // 1. Involution: conj(conj(a)) == a
      const cNum = ComplexNumber(3, -4);
      check(field.conjugate(field.conjugate(cNum))).equals(cNum);
      check(field.conjugate(field.conjugate(ComplexNumber.i)))
          .equals(ComplexNumber.i);

      final symComp = x + field.mul(ComplexNumber.i, y);
      check(field.conjugate(field.conjugate(symComp))).equals(symComp);

      final transExpr = Sin(x + field.mul(ComplexNumber.i, y));
      check(field.conjugate(field.conjugate(transExpr))).equals(transExpr);

      final expExpr = Exp(field.mul(ComplexNumber.i, x));
      check(field.conjugate(field.conjugate(expExpr))).equals(expExpr);

      // 2. Additivity: conj(a + b) == conj(a) + conj(b)
      final conjAddLhs = field.conjugate(field.add(cNum, symComp));
      final conjAddRhs = field.add(
        field.conjugate(cNum),
        field.conjugate(symComp),
      );
      check(field.sub(conjAddLhs, conjAddRhs).expand().simplify())
          .equals(RationalNumber.zero);

      // 3. Multiplicativity: conj(a * b) == conj(a) * conj(b)
      final conjMulLhs = field.conjugate(field.mul(cNum, symComp));
      final conjMulRhs = field.mul(
        field.conjugate(cNum),
        field.conjugate(symComp),
      );
      check(field.sub(conjMulLhs, conjMulRhs).expand().simplify())
          .equals(RationalNumber.zero);

      // 4. Real preservation: conj(real) == real
      check(field.conjugate(const RationalNumber(7, 3)))
          .equals(const RationalNumber(7, 3));
      check(field.conjugate(const RealNumber(2.718)))
          .equals(const RealNumber(2.718));
      check(field.conjugate(x)).equals(x);
    });
  });
}
