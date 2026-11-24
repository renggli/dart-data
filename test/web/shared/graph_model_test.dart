import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

import '../../../web/shared/graph/model/axis.dart';
import '../../../web/shared/graph/model/dataset.dart';
import '../../../web/shared/graph/model/dataset_2d.dart';
import '../../../web/shared/graph/model/dataset_3d.dart';
import '../../../web/shared/graph/model/style.dart';

void main() {
  group('AxisConfig and Bounds', () {
    test('Bounds2D computes spans, validity, and union', () {
      const a = Bounds2D(xMin: -2, xMax: 2, yMin: -1, yMax: 3);
      const b = Bounds2D(
        xMin: 0,
        xMax: 5,
        yMin: -4,
        yMax: 1,
        y2Min: 0,
        y2Max: 10,
      );
      check(a.isValid).isTrue;
      check(a.xSpan).equals(4);
      check(a.ySpan).equals(4);
      check(a.y2Span).isNull;

      final combined = Bounds2D.union([a, b, null]);
      check(combined).isNotNull();
      check(combined!.xMin).equals(-2);
      check(combined.xMax).equals(5);
      check(combined.yMin).equals(-4);
      check(combined.yMax).equals(3);
      check(combined.y2Min).equals(0);
      check(combined.y2Max).equals(10);
      check(combined.y2Span).equals(10);
    });

    test('Bounds2D rejects degenerate or non-finite bounds', () {
      const zeroSpan = Bounds2D(xMin: 1, xMax: 1, yMin: 0, yMax: 2);
      const nanBounds = Bounds2D(xMin: double.nan, xMax: 1, yMin: 0, yMax: 2);
      check(zeroSpan.isValid).isFalse;
      check(nanBounds.isValid).isFalse;
      check(Bounds2D.union([zeroSpan, nanBounds])).isNull;
    });

    test('Bounds3D computes spans and union', () {
      const a = Bounds3D(
        xMin: -1,
        xMax: 1,
        yMin: -2,
        yMax: 2,
        zMin: 0,
        zMax: 4,
      );
      const b = Bounds3D(
        xMin: 0,
        xMax: 3,
        yMin: -1,
        yMax: 5,
        zMin: -2,
        zMax: 1,
      );
      final combined = Bounds3D.union([a, b]);
      check(combined).isNotNull();
      check(combined!.xMin).equals(-1);
      check(combined.xMax).equals(3);
      check(combined.yMin).equals(-2);
      check(combined.yMax).equals(5);
      check(combined.zMin).equals(-2);
      check(combined.zMax).equals(4);
      check(combined.zSpan).equals(6);
    });
  });

  group('Colormap and Style', () {
    test('all colormaps clamp inputs and return valid RGBA bytes', () {
      for (final map in Colormap.values) {
        for (final t in [-0.5, 0.0, 0.25, 0.5, 1.0, 1.5, double.nan]) {
          final c = map.sampleRgba(t);
          check(c.r).isGreaterOrEqual(0);
          check(c.r).isLessOrEqual(255);
          check(c.g).isGreaterOrEqual(0);
          check(c.g).isLessOrEqual(255);
          check(c.b).isGreaterOrEqual(0);
          check(c.b).isLessOrEqual(255);
          check(c.a).equals(255);
        }
        check(map.gradientStops(5).length).equals(5);
      }
    });

    test('default palette has distinct hex colors', () {
      check(defaultGraphPalette.length).isGreaterOrEqual(6);
      check(defaultGraphPalette.toSet().length)
          .equals(defaultGraphPalette.length);
    });
  });

  group('2D Datasets', () {
    test('Function2DDataset computes bounds and interpolates readout', () {
      const ds = Function2DDataset(
        id: 'f1',
        label: 'y = 2x',
        xs: [0.0, 1.0, 2.0],
        ys: [0.0, 2.0, 4.0],
        color: '#60a5fa',
      );
      check(ds.swatch).isA<LineSwatch>();
      final b = ds.bounds;
      check(b).isNotNull();
      check(b!.xMin).equals(0.0);
      check(b.yMax).equals(4.0);

      final r = ds.readout(const Probe2D(x: 0.5, y: 1.0));
      check(r).isNotNull();
      check(r!.valueText).equals('1.0000');
      check(ds.readout(const Probe2D(x: -1.0, y: 0.0))).isNull;
      check(ds.readout(const Probe3D(x: 0.5, y: 1.0, z: 0.0))).isNull;
    });

    test('Parametric2DDataset finds nearest point readout', () {
      const ds = Parametric2DDataset(
        id: 'p1',
        label: 'circle',
        ts: [0.0, 1.0, 2.0],
        xs: [1.0, 0.0, -1.0],
        ys: [0.0, 1.0, 0.0],
        color: '#f472b6',
      );
      final r = ds.readout(const Probe2D(x: 0.1, y: 0.9));
      check(r).isNotNull();
      check(r!.detailText).equals('t = 1.0000');
    });

    test('Field2DDataset computes scalar and vector readouts', () {
      final ds = Field2DDataset(
        id: 'fld',
        label: 'field',
        cols: 2,
        rows: 2,
        domain: const Bounds2D(xMin: 0, xMax: 1, yMin: 0, yMax: 1),
        samples: const [
          Field2DSample(x: 0, y: 0, u: 1, v: 0, scalar: 1),
          Field2DSample(x: 1, y: 0, u: 0, v: 2, scalar: 2),
          Field2DSample(x: 0, y: 1, u: -1, v: 0, scalar: 1),
          Field2DSample(x: 1, y: 1, u: 0, v: -2, scalar: 2),
        ],
        showVectors: true,
        rgbaPixels: Uint8List(16),
      );
      final r = ds.readout(const Probe2D(x: 0.95, y: 0.05));
      check(r).isNotNull();
      check(r!.valueText).equals('(0.0000, 2.0000)');
      check(r.detailText).equals('|v| = 2.0000');
      check(ds.readout(const Probe2D(x: 2.0, y: 0.5))).isNull;
    });

    test('Scene2D computes union bounds of visible datasets', () {
      const scene = Scene2D(
        datasets: [
          Function2DDataset(
            id: 'a',
            label: 'a',
            xs: [0, 2],
            ys: [0, 4],
            color: '#60a5fa',
          ),
          Function2DDataset(
            id: 'b',
            label: 'b',
            xs: [-10, 10],
            ys: [-10, 10],
            color: '#f472b6',
            visible: false,
          ),
        ],
      );
      final b = scene.computeBounds();
      check(b).isNotNull();
      check(b!.xMin).equals(0);
      check(b.xMax).equals(2);
    });
  });

  group('3D Datasets', () {
    test('Surface3DDataset computes bounds and Z readout', () {
      const ds = Surface3DDataset(
        id: 's1',
        label: 'plane',
        nx: 2,
        ny: 2,
        xs: [0.0, 1.0],
        ys: [0.0, 1.0],
        zs: [0.0, 1.0, 2.0, 3.0],
      );
      final b = ds.bounds;
      check(b).isNotNull();
      check(b!.zMin).equals(0.0);
      check(b.zMax).equals(3.0);
      final r = ds.readout(const Probe3D(x: 1.0, y: 1.0, z: 3.0));
      check(r).isNotNull();
      check(r!.valueText).equals('z = 3.0000');
    });

    test('Parametric3DDataset and VectorField3DDataset compute bounds and readouts', () {
      const p3 = Parametric3DDataset(
        id: 'p3',
        label: 'helix',
        ts: [0.0, 1.0],
        xs: [1.0, 0.0],
        ys: [0.0, 1.0],
        zs: [0.0, 2.0],
        color: '#34d399',
      );
      check(p3.bounds).isNotNull();
      check(p3.readout(const Probe3D(x: 0.0, y: 1.0, z: 2.0))!.detailText)
          .equals('t = 1.0000');

      const vf = VectorField3DDataset(
        id: 'vf3',
        label: 'vf',
        samples: [Field3DSample(x: 0, y: 0, z: 0, vx: 3, vy: 4, vz: 0)],
      );
      final r = vf.readout(const Probe3D(x: 0, y: 0, z: 0));
      check(r).isNotNull();
      check(r!.detailText).equals('|v| = 5.0000');

      const scene = Scene3D(datasets: [p3, vf]);
      check(scene.computeBounds()).isNotNull();
    });
  });
}
