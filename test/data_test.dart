import 'package:data/data.dart';
import 'package:test/test.dart';

void main() {
  test('Umbrella package:data export test', () {
    expect(DataType.float64.isFloat, isTrue);
    expect(sharesMemory([1.0, 2.0], [1.0, 2.0]), isFalse);

    // Subsystem 2: Tensor & Layout
    final tensor = Tensor<double>.filled(1.0, shape: [2, 2]);
    expect(tensor.shape, [2, 2]);

    // Subsystem 3: LinearOperator & Matrix / Vector
    final mat = Matrix<double>.identity(2);
    final vec = Vector<double>.fromList([3.0, 4.0]);
    final prod = mat.apply(vec);
    expect(prod.toList(), [3.0, 4.0]);

    // Subsystem 4: Hardware
    expect(HardwareManager.isEnabled, isTrue);

    // Subsystem 5: DataFrame & Series
    final df = DataFrame.fromColumns({
      'a': [10, 20],
      'b': ['x', 'y'],
    });
    expect(df.rowCount, 2);

    // Subsystem 6: Symbolic
    const x = Variable('x');
    final expr = x * 2 + 1;
    final fn = expr.compile1D('x');
    expect(fn(5.0), 11.0);
  });
}
