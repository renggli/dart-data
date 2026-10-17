import 'dart:math' as math;
import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/data.dart';
import 'package:test/test.dart';

void main() {
  group('Symbolic Doc Examples', () {
    test('Expr evaluation and operations', () {
      const x = Variable('x');
      final expr = x * 2 + 1;
      final result = expr.evaluate({'x': 3});
      check(result).equals(7.0);
    });

    test('solve and solveSystem', () {
      const x = Variable('x');
      final roots = (x * x - 4).solve('x');
      final rootValues = roots.map((e) => (e as Number).toDouble()).toList();
      check(rootValues).contains(-2.0);
      check(rootValues).contains(2.0);

      const y = Variable('y');
      final systemSol = [x + y - 5, x - y - 1].solveSystem(['x', 'y']);
      check(systemSol).isNotNull();
      check((systemSol!['x'] as Number).toDouble()).equals(3.0);
      check((systemSol['y'] as Number).toDouble()).equals(2.0);
    });

    test('derivative', () {
      const x = Variable('x');
      final d = (x * x * x).derivative('x');
      check(d.evaluate({'x': 2.0})).equals(12.0);
    });

    test('integrate', () {
      const x = Variable('x');
      final area = (x * x).integrate('x', from: 0.0, to: 3.0);
      check(area.evaluate({})).isCloseTo(9.0, 1e-4);
    });

    test('gradient, hessian, jacobian', () {
      const x = Variable('x');
      const y = Variable('y');
      final grad = (x * x + y * y).gradient(['x', 'y']);
      check(grad.length).equals(2);

      final hess = (x * x + y * y).hessian(['x', 'y']);
      check(hess.rowCount).equals(2);
      check(hess.colCount).equals(2);
      check(hess[0].length).equals(2);

      final jac = [x * y, x + y].jacobian(['x', 'y']);
      check(jac.rowCount).equals(2);
      check(jac.colCount).equals(2);
      check(jac[0].length).equals(2);
    });

    test('taylorSeries and matchLinear', () {
      const x = Variable('x');
      final poly = Pow(Constant.e, x).taylorSeries('x', order: 2);
      check(poly.evaluate({'x': 0.0})).isCloseTo(1.0, 1e-6);

      final match = (x * 3 + 4).matchLinear('x');
      check(match).isNotNull();
      check((match!.a as Number).toDouble()).equals(3.0);
      check((match.b as Number).toDouble()).equals(4.0);
    });

    test('simplify, compile, toLatex', () {
      const x = Variable('x');
      final simplified = (x + 0).simplify();
      check(simplified).equals(x);

      final fn = (x * x + 1).toFunction1D('x');
      check(fn(3.0)).equals(10.0);

      final latex = (x * 2 + 1).toLatex();
      check(latex.isNotEmpty).isTrue();
    });
  });

  group('Polynomial Doc Examples', () {
    test('Polynomial constructors and methods', () {
      final p = Polynomial<double>.fromCoefficients([3.0, 2.0, 5.0]);
      check(p.evaluate(1.0)).equals(10.0); // 3 + 2(1) + 5(1) = 10

      final pRoots = Polynomial<double>.fromRoots([2.0, 3.0]);
      check(pRoots.evaluate(2.0)).isCloseTo(0.0, 1e-6);

      final d = p.differentiate();
      check(d.degree).equals(1);

      final integrated = p.integrate();
      check(integrated.degree).equals(3);

      final comp = p.compose(Polynomial.fromCoefficients([1.0, 1.0]));
      check(comp.degree).equals(2);
    });

    test('clenshawEvaluate and laguerreL', () {
      final val = clenshawEvaluate(
        [1.0, 2.0],
        0.5,
        family: OrthogonalFamily.chebyshevT,
      );
      check(val).isCloseTo(2.0, 1e-6);

      final l1 = Polynomial.laguerreL(1);
      check(l1.degree).equals(1);
    });

    test('RationalFunction', () {
      final num = Polynomial.fromCoefficients([1.0, 1.0]);
      final den = Polynomial.fromCoefficients([2.0, 1.0]);
      final rf = RationalFunction(num, den);
      check(rf.evaluateDouble(0.0)).equals(0.5);
    });
  });

  group('Tensor Doc Examples', () {
    test('Tensor constructors and getters', () {
      final tFilled = Tensor<int>.filled(7, shape: [2, 3]);
      check(tFilled.rank).equals(2);
      check(tFilled.length).equals(6);
      check(tFilled.shape).deepEquals([2, 3]);
      check(tFilled.toFlatList()).deepEquals([7, 7, 7, 7, 7, 7]);

      final tGen = Tensor<int>.generate(
        (key) => key[0] * 10 + key[1],
        shape: [2, 3],
      );
      check(tGen.getValue([1, 2])).equals(12);

      final tIter = Tensor<int>.fromIterable([1, 2, 3, 4, 5, 6], shape: [2, 3]);
      check(tIter.getValue([0, 2])).equals(3);

      final tObj = Tensor<int>.fromObject([
        [1, 2, 3],
        [4, 5, 6],
      ]);
      check(tObj.rank).equals(2);
      check(tObj.shape).deepEquals([2, 3]);
    });

    test('Layout and Slice', () {
      final layout = Layout(shape: [2, 3]);
      check(layout.rank).equals(2);
      check(layout.length).equals(6);
      check(layout.strides).deepEquals([3, 1]);
      check(layout.toIndex([1, 2])).equals(5);
      check(layout.toKey(5)).deepEquals([1, 2]);

      const slice = Slice(1, 5, 2);
      check(slice.start).equals(1);
      check(slice.end).equals(5);
      check(slice.step).equals(2);
    });

    test('Tensor operations and reduction', () {
      final t = Tensor<double>.fromIterable([
        2.0,
        4.0,
        4.0,
        4.0,
        5.0,
        5.0,
        7.0,
        9.0,
      ]);
      check(t.var_().toFlatList().first).isCloseTo(4.0, 1e-6);

      final a = Tensor<int>.fromObject([
        [1, 2],
        [3, 4],
      ]);
      final b = Tensor<int>.fromObject([
        [5, 6],
        [7, 8],
      ]);
      final c = a.tensordot(b, axes: 1);
      check(c.shape).deepEquals([2, 2]);
      check(c.toFlatList()).deepEquals([19, 22, 43, 50]);

      final v1 = Tensor<int>.fromObject([1, 2, 3]);
      final v2 = Tensor<int>.fromObject([4, 5, 6]);
      check(v1.innerProduct(v2).toFlatList().first).equals(32);

      final opA = Tensor<int>.fromObject([1, 2]);
      final opB = Tensor<int>.fromObject([3, 4]);
      final op = opA.outerProduct(opB);
      check(op.shape).deepEquals([2, 2]);
      check(op.toFlatList()).deepEquals([3, 4, 6, 8]);

      final matA = Tensor<int>.fromObject([
        [1, 2],
        [3, 4],
      ]);
      final matB = Tensor<int>.fromObject([
        [2, 0],
        [1, 2],
      ]);
      final matC = matA.matmul(matB);
      check(matC.toFlatList()).deepEquals([4, 4, 10, 8]);

      final einC = einsum('ij,jk->ik', [matA, matB]);
      check(einC.toFlatList()).deepEquals([4, 4, 10, 8]);
    });

    test('Tensor manipulation: concatenate, stack, tile, pad, split', () {
      final a = Tensor<int>.fromObject([
        [1, 2],
      ]);
      final b = Tensor<int>.fromObject([
        [3, 4],
      ]);
      final cat = a.concatenate(b, axis: 0);
      check(cat.shape).deepEquals([2, 2]);
      check(cat.toFlatList()).deepEquals([1, 2, 3, 4]);

      final sA = Tensor<int>.fromObject([1, 2]);
      final sB = Tensor<int>.fromObject([3, 4]);
      final st = sA.stack(sB, axis: 0);
      check(st.shape).deepEquals([2, 2]);

      final tiled = sA.tile([2]);
      check(tiled.shape).deepEquals([4]);
      check(tiled.toFlatList()).deepEquals([1, 2, 1, 2]);

      final padded = sA.pad([
        [1, 1],
      ], fillValue: 0);
      check(padded.shape).deepEquals([4]);
      check(padded.toFlatList()).deepEquals([0, 1, 2, 0]);

      final toSplit = Tensor<int>.fromObject([1, 2, 3, 4]);
      final parts = toSplit.split(2);
      check(parts.length).equals(2);
      check(parts[0].toFlatList()).deepEquals([1, 2]);
      check(parts[1].toFlatList()).deepEquals([3, 4]);

      final toSplitSizes = Tensor<int>.fromObject([1, 2, 3, 4, 5]);
      final sizedParts = toSplitSizes.splitWithSizes([2, 3]);
      check(sizedParts.length).equals(2);
      check(sizedParts[0].toFlatList()).deepEquals([1, 2]);
      check(sizedParts[1].toFlatList()).deepEquals([3, 4, 5]);
    });
  });

  group('Linear Algebra Doc Examples', () {
    test('Vector constructors and methods', () {
      final t = Tensor<int>.fromIterable([1, 2, 3]);
      final v = Vector<int>(t);
      check(v.length).equals(3);

      final vDouble = Vector<double>.fromList([1.0, 2.0, 3.0]);
      check(vDouble.length).equals(3);

      final a = Vector<double>.fromList([1.0, 2.0, 3.0]);
      final b = Vector<double>.fromList([4.0, 5.0, 6.0]);
      check(a.dot(b)).equals(32.0);

      final v2d = Vector<double>.fromList([3.0, 4.0]);
      check(v2d.norm()).equals(5.0);

      final va = Vector<int>.fromList([1, 2]);
      final vb = Vector<int>.fromList([3, 4, 5]);
      final outer = va.outer(vb);
      check(outer.rowCount).equals(2);
      check(outer.colCount).equals(3);
    });

    test('Matrix constructors and solve', () {
      final t = Tensor<int>.filled(0, shape: [2, 3]);
      final m = Matrix<int>(t);
      check(m.rowCount).equals(2);
      check(m.colCount).equals(3);

      final a = Matrix<double>.fromRows([
        [2.0, 1.0],
        [1.0, 3.0],
      ]);
      final b = Vector<double>.fromList([4.0, 7.0]);
      final x = a.solve(b);
      check(x[0]).isCloseTo(1.0, 1e-6);
      check(x[1]).isCloseTo(2.0, 1e-6);
    });

    test('Sparse matrices: COO, CSR, CSC', () {
      final coo = CooMatrix<double>(
        rowCount: 3,
        colCount: 3,
        rowIndices: [0, 1, 2],
        colIndices: [0, 1, 2],
        values: [1.0, 2.0, 3.0],
        type: DataType.float64,
      );
      check(coo.rowCount).equals(3);
      check(coo.colCount).equals(3);

      final csr = CsrMatrix<double>(
        rowCount: 2,
        colCount: 2,
        rowPointers: [0, 1, 2],
        colIndices: [0, 1],
        values: [1.0, 2.0],
        type: DataType.float64,
      );
      check(csr.rowCount).equals(2);
      check(csr.colCount).equals(2);

      final csc = CscMatrix<double>(
        rowCount: 2,
        colCount: 2,
        colPointers: [0, 1, 2],
        rowIndices: [0, 1],
        values: [1.0, 2.0],
        type: DataType.float64,
      );
      check(csc.rowCount).equals(2);
      check(csc.colCount).equals(2);
    });
  });

  group('DataFrame Doc Examples', () {
    test('DataFrame constructors, GroupBy, Join', () {
      final s1 = Series<int>.fromList('a', [1, 2]);
      final s2 = Series<String>.fromList('b', ['x', 'y']);
      final df = DataFrame([s1, s2]);
      check(df.rowCount).equals(2);

      final dfCols = DataFrame.fromColumns({
        'name': ['Alice', 'Bob'],
        'score': [95.0, 88.5],
      });
      check(dfCols.rowCount).equals(2);

      final empDf = DataFrame.fromColumns({
        'dept': ['Sales', 'Sales', 'Eng'],
        'salary': [50000.0, 60000.0, 80000.0],
      });
      final grouped = empDf.groupBy(['dept']);
      final summary = grouped.mean();
      check(summary.rowCount).equals(2);

      final left = DataFrame.fromColumns({
        'id': [1, 2],
        'name': ['Alice', 'Bob'],
      });
      final right = DataFrame.fromColumns({
        'id': [1, 2],
        'age': [20, 25],
      });
      final merged = left.join(right, on: ['id']);
      check(merged.rowCount).equals(2);
      check(merged.columnNames).contains('name');
      check(merged.columnNames).contains('age');
    });
  });

  group('Special Functions Doc Examples', () {
    test('gamma and gammaLn', () {
      check(gamma(5)).isCloseTo(24.0, 1e-9);
      check(gammaLn(5)).isCloseTo(3.17805383, 1e-6);
    });

    test('beta, betaLn, ibeta', () {
      check(beta(2, 3)).isCloseTo(1.0 / 12.0, 1e-9);
      check(betaLn(2, 3)).isCloseTo(-2.484906649788, 1e-6);
      check(ibeta(0.5, 2, 3)).isCloseTo(0.6875, 1e-6);
    });

    test('erf and erfInv', () {
      check(erf(1.0)).isCloseTo(0.84270079, 1e-6);
      check(erfInv(0.8427007929497149)).isCloseTo(1.0, 1e-6);
    });

    test('digamma and trigamma', () {
      check(digamma(1.0)).isCloseTo(-0.5772156649, 1e-6);
      check(trigamma(1.0)).isCloseTo(1.6449340668, 1e-6);
    });

    test('lambertW0 and lambertW1', () {
      check(lambertW0(0.0)).equals(0.0);
      check(lambertW1(-0.1)).isCloseTo(-3.577152063957297, 1e-6);
    });

    test('bessel functions', () {
      check(besselI0(0.0)).equals(1.0);
      check(besselJ0(0.0)).equals(1.0);
    });
  });

  group('Statistics Doc Examples', () {
    test('t-tests', () {
      final res1 = tTestOneSample([10.0, 11.0, 9.5, 10.5, 10.2], mu0: 10.0);
      check(res1.statistic).isA<double>();
      check(res1.pValue).isA<double>();

      final res2 = tTestTwoSample([1.0, 2.0, 3.0], [4.0, 5.0, 6.0]);
      check(res2.isSignificant).isTrue();
    });

    test('bootstrap', () {
      final data = [1.0, 2.0, 3.0, 4.0, 5.0];
      final result = bootstrap(
        data,
        (sample) => sample.reduce((a, b) => a + b) / sample.length,
        resamples: 200,
      );
      check(result.estimate).equals(3.0);
      check(result.confidenceLevel).equals(0.95);
    });
  });

  group('Numerical Analysis Doc Examples', () {
    test('quadrature integration', () {
      final areaSimp = integrate(
        (double x) => x * x,
        0.0,
        3.0,
        method: IntegrationMethod.simpson,
      );
      check(areaSimp).isCloseTo(9.0, 1e-6);

      final areaGk = integrate((double x) => x * x, 0.0, 3.0);
      check(areaGk).isCloseTo(9.0, 1e-6);
    });

    test('root finding', () {
      final rootBrent = solve((double x) => x * x - 4.0, 0.0, b: 5.0);
      check(rootBrent).isCloseTo(2.0, 1e-6);

      final rootNewton = solve(
        (double x) => x * x - 9.0,
        2.0,
        method: RootMethod.newtonRaphson,
      );
      check(rootNewton).isCloseTo(3.0, 1e-6);

      final rootBisect = solve(
        (double x) => x * x - 2.0,
        1.0,
        b: 2.0,
        method: RootMethod.bisection,
      );
      check(rootBisect).isCloseTo(1.41421356, 1e-5);
    });

    test('optimization', () {
      final optBrent = minimize(
        (Vector<double> v) => (v[0] - 2.0) * (v[0] - 2.0) + 3.0,
        a: 0.0,
        b: 5.0,
      );
      check(optBrent.point1D).isCloseTo(2.0, 1e-5);

      final start = Vector<double>.fromList([2.0, 2.0]);
      final optNelder = minimize(
        (Vector<double> v) => v[0] * v[0] + v[1] * v[1],
        initialPoint: start,
        method: OptimizationMethod.nelderMead,
      );
      check(optNelder.point[0]).isCloseTo(0.0, 1e-4);
      check(optNelder.point[1]).isCloseTo(0.0, 1e-4);

      final startBfgs = Vector<double>.fromList([3.0, 4.0]);
      final optBfgs = minimize(
        (Vector<double> v) => v[0] * v[0] + v[1] * v[1],
        initialPoint: startBfgs,
        method: OptimizationMethod.bfgs,
      );
      check(optBfgs.point[0]).isCloseTo(0.0, 1e-5);
      check(optBfgs.point[1]).isCloseTo(0.0, 1e-5);
    });

    test('ODEs', () {
      final solRk4 = solveOde(
        f: (t, y) => Vector<double>.fromList([-y[0]]),
        t0: 0.0,
        tEnd: 1.0,
        y0: Vector<double>.fromList([1.0]),
        method: OdeMethod.rk4,
      );
      check(solRk4.last[0]).isCloseTo(0.367879, 1e-4);

      final solRk45 = solveOde(
        f: (t, y) => Vector<double>.fromList([-y[0]]),
        t0: 0.0,
        tEnd: 1.0,
        y0: Vector<double>.fromList([1.0]),
      );
      check(solRk45.last[0]).isCloseTo(0.367879, 1e-4);
    });

    test('FFT and IFFT', () {
      final signal = [
        const Complex(1.0, 0.0),
        const Complex(1.0, 0.0),
        const Complex(0.0, 0.0),
        const Complex(0.0, 0.0),
      ];
      final spectrum = fft(signal);
      final reconstructed = ifft(spectrum);
      for (var i = 0; i < 4; i++) {
        check(reconstructed[i].a).isCloseTo(signal[i].a, 1e-6);
        check(reconstructed[i].b).isCloseTo(signal[i].b, 1e-6);
      }
    });

    test('calculus derivatives, gradient, Jacobian, Hessian', () {
      final slope = derivative((double x) => x * x, 3.0);
      check(slope).isCloseTo(6.0, 1e-4);

      final curv = derivative((double x) => x * x * x, 2.0, order: 2);
      check(curv).isCloseTo(12.0, 1e-3);

      final p = Vector<double>.fromList([1.0, 2.0]);
      final grad = gradient((Vector<double> v) => v[0] * v[0] + v[1] * v[1], p);
      check(grad[0]).isCloseTo(2.0, 1e-4);
      check(grad[1]).isCloseTo(4.0, 1e-4);

      final jac = jacobian(
        (Vector<double> v) =>
            Vector<double>.fromList([v[0] + v[1], v[0] * v[1]]),
        p,
      );
      check(jac.getUnchecked(0, 0)).isCloseTo(1.0, 1e-4);
      check(jac.getUnchecked(1, 0)).isCloseTo(2.0, 1e-4);

      final hess = hessian((Vector<double> v) => v[0] * v[0] + v[1] * v[1], p);
      check(hess.getUnchecked(0, 0)).isCloseTo(2.0, 1e-3);
      check(hess.getUnchecked(1, 1)).isCloseTo(2.0, 1e-3);
    });
  });

  group('Matrix Norms Doc Examples', () {
    test('normFrobenius, norm1, norm2, normInfinity, cond, rank', () {
      final m = Matrix<double>.fromRows([
        [3.0, 0.0],
        [0.0, 4.0],
      ]);
      check(m.normFrobenius).isCloseTo(5.0, 1e-10);
      check(m.norm1).equals(4.0);
      check(m.norm2).isCloseTo(4.0, 1e-10);
      check(m.normInfinity).equals(4.0);
      check(m.cond).isCloseTo(4.0 / 3.0, 1e-10);
      check(m.rank).equals(2);
    });
  });

  group('Top-level Library Quick Start Examples', () {
    test('lib/data.dart quick start', () {
      final a = Matrix<double>.fromRows([
        [2.0, 1.0],
        [1.0, 3.0],
      ]);
      final b = Vector<double>.fromList([4.0, 7.0]);
      final x = a.solve(b);
      check(x[0]).isCloseTo(1.0, 1e-6);
      check(x[1]).isCloseTo(2.0, 1e-6);

      final df = DataFrame.fromColumns({
        'name': ['Alice', 'Bob', 'Charlie'],
        'score': [95.0, 82.5, 91.0],
      });
      check(df['score'].mean).isNotNull();
    });

    test('lib/dataframe.dart quick start', () {
      final df = DataFrame.fromColumns({
        'department': ['Engineering', 'Engineering', 'Sales', 'Sales'],
        'salary': [120000.0, 135000.0, 95000.0, 105000.0],
      });
      final summary = df.groupBy(['department']).aggregate({
        'salary': [Agg.mean, Agg.count],
      });
      check(summary.rowCount).equals(2);
      check(summary.columnNames).contains('salary_mean');
      check(summary.columnNames).contains('salary_count');
    });

    test('lib/acceleration.dart quick start', () {
      check(AccelerationManager.isAccelerated).isA<bool>();

      final a = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final b = Float64List.fromList([5.0, 6.0, 7.0, 8.0]);
      final c = Float64List(4);

      AccelerationManager.dgemm(
        m: 2,
        n: 2,
        k: 2,
        alpha: 1.0,
        a: a,
        lda: 2,
        b: b,
        ldb: 2,
        beta: 0.0,
        c: c,
        ldc: 2,
      );
      check(c.length).equals(4);
    });

    test('lib/linear.dart quick start', () {
      final a = Matrix<double>.fromRows([
        [4.0, 1.0],
        [1.0, 3.0],
      ]);
      final b = Vector<double>.fromList([1.0, 2.0]);
      final x = a.cholesky.solveVector(b);
      check(x.length).equals(2);
      final ax = a * x.toMatrix();
      check(ax[0][0]).isCloseTo(b[0], 1e-6);
      check(ax[1][0]).isCloseTo(b[1], 1e-6);
    });

    test('lib/numeric.dart quick start', () {
      final result = integrate(math.sin, 0.0, math.pi);
      check(result).isCloseTo(2.0, 1e-4);

      final root = solve((double x) => math.cos(x) - x, 0.0, b: 1.0);
      check(root).isCloseTo(0.739085, 1e-4);
    });

    test('lib/polynomial.dart quick start', () {
      final p = Polynomial<double>.fromCoefficients([-4.0, 0.0, 1.0]);
      final dp = p.differentiate();
      check(dp.degree).equals(1);
      check(p.evaluate(3.0)).equals(5.0);
      final rootValues = p.roots.map((c) => c.a).toList();
      check(rootValues).contains(-2.0);
      check(rootValues).contains(2.0);
    });

    test('lib/special.dart quick start', () {
      check(gamma(0.5)).isCloseTo(math.sqrt(math.pi), 1e-5);
      check(erf(1.0)).isCloseTo(0.84270, 1e-4);
      check(besselJ0(0.0)).equals(1.0);
    });

    test('lib/stats.dart quick start', () {
      final scores = [88.0, 92.5, 79.0, 95.0, 85.5, 91.0];
      check(scores.mean()).isA<double>();
      check(scores.standardDeviation()).isA<double>();

      const normal = NormalDistribution.standard();
      check(normal.cumulativeProbability(1.96)).isCloseTo(0.975, 1e-2);

      final treatment = [12.1, 14.3, 13.8, 15.2, 14.9];
      final control = [10.2, 11.5, 10.8, 12.0, 11.1];
      final testResult = tTestTwoSample(treatment, control);
      check(testResult.pValue).isA<double>();
      check(testResult.isSignificant).isA<bool>();
    });

    test('lib/symbolic.dart quick start', () {
      const x = Variable('x');
      final f = x.pow(3) + x * 2;
      final df = f.derivative('x').simplify();
      check(df.toLatex().isNotEmpty).isTrue();
      final fn = df.toFunction1D('x');
      check(fn(2.0)).isCloseTo(14.0, 1e-6);
    });

    test('lib/tensor.dart quick start', () {
      final t = Tensor<double>.filled(1.0, shape: [2, 3]);
      check(t.shape).deepEquals([2, 3]);
      check(t.rank).equals(2);

      final a = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0, 4.0],
        shape: [2, 2],
      );
      final b = Tensor<double>.fromIterable(
        [5.0, 6.0, 7.0, 8.0],
        shape: [2, 2],
      );
      final c = einsum('ij,jk->ik', [a, b]);
      check(c.toFlatList()).deepEquals([19.0, 22.0, 43.0, 50.0]);
    });

    test('lib/type.dart quick start', () {
      const floatType = DataType.float64;
      check(floatType.bits).equals(64);
      check(floatType.field.additiveIdentity).equals(0.0);
      check(floatType.field.multiplicativeIdentity).equals(1.0);
      final list = floatType.newList(5, fillValue: 1.5);
      check(list.length).equals(5);
      check(list[0]).equals(1.5);
    });
  });

  group('Additional Subsystem Doc Examples', () {
    test('QR, SVD, and Eigenvalue doc examples', () {
      final aQr = Matrix<double>.fromRows([
        [1.0, 2.0],
        [3.0, 4.0],
        [5.0, 6.0],
      ]);
      final qr = aQr.qr;
      check(qr.q.rowCount).equals(3);
      check(qr.r.rowCount).equals(2);

      final aSvd = Matrix<double>.fromRows([
        [3.0, 0.0],
        [0.0, 4.0],
      ]);
      final svd = aSvd.svd;
      check(svd.s[0]).isCloseTo(4.0, 1e-6);
      check(svd.s[1]).isCloseTo(3.0, 1e-6);

      final aEig = Matrix<double>.fromRows([
        [2.0, 0.0],
        [0.0, 3.0],
      ]);
      final eig = aEig.eigenvalue;
      check(eig.realEigenvalues).contains(2.0);
      check(eig.realEigenvalues).contains(3.0);
    });

    test('solveTridiagonal doc example', () {
      final sub = Vector<double>.fromList([1.0, 2.0]);
      final diag = Vector<double>.fromList([2.0, 4.0, 3.0]);
      final sup = Vector<double>.fromList([1.0, 1.0]);
      final rhs = Vector<double>.fromList([4.0, 11.0, 11.0]);
      final x = solveTridiagonal(sub, diag, sup, rhs);
      check(x.length).equals(3);
      check(x[0]).isCloseTo(1.0588, 1e-3);
    });

    test('Float64 extension types doc examples', () {
      final m = Float64Matrix.filled(2, 2, 1.5);
      check(m.rowCount).equals(2);
      check(m.colCount).equals(2);

      final v = Float64Vector.filled(3, 2.5);
      check(v.length).equals(3);

      final t = Float64Tensor.filled(0.0, shape: [2, 3]);
      check(t.rank).equals(2);
    });

    test('leastSquares and linearRegression doc examples', () {
      final a = Matrix<double>.fromRows([
        [1.0, 1.0],
        [1.0, 2.0],
        [1.0, 3.0],
      ]);
      final b = Vector<double>.fromList([2.0, 2.8, 4.1]);
      final x = leastSquares(a, b);
      check(x.length).equals(2);

      final xs = Vector<double>.fromList([1.0, 2.0, 3.0, 4.0]);
      final ys = Vector<double>.fromList([2.0, 4.0, 6.0, 8.0]);
      final model = linearRegression(xs, ys);
      check(model.slope).isCloseTo(2.0, 1e-4);
      check(model.rSquared).isCloseTo(1.0, 1e-4);
    });

    test('LinearInterpolation and CubicSpline doc examples', () {
      final interp = LinearInterpolation([0.0, 1.0, 2.0], [0.0, 10.0, 20.0]);
      check(interp(0.5)).isCloseTo(5.0, 1e-6);

      final spline = CubicSpline([0.0, 1.0, 2.0], [0.0, 1.0, 8.0]);
      check(spline(1.0)).isCloseTo(1.0, 1e-6);
    });
  });
}
