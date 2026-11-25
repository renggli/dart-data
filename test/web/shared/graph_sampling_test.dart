import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

import '../../../web/shared/graph/model/axis.dart';
import '../../../web/shared/graph/model/dataset_2d.dart';
import '../../../web/shared/graph/sampling/oklch.dart';
import '../../../web/shared/graph/sampling/sampler_2d.dart';
import '../../../web/shared/graph/sampling/sampler_3d.dart';

void main() {
  group('OKLCH and Domain Coloring', () {
    test('oklchToSrgb returns clamped byte channels', () {
      final black = oklchToSrgb(0.0, 0.0, 0.0);
      final white = oklchToSrgb(1.0, 0.0, 0.0);
      check(black.r).equals(0);
      check(white.r).equals(255);
      check(white.g).equals(255);
      check(white.b).equals(255);
    });

    test('sampleComplexDomainGrid handles poles, zeros, and finite values', () {
      final ds = sampleComplexDomainGrid(
        id: 'c1',
        label: '1/z',
        fn: (x, y) {
          final d = x * x + y * y;
          if (d == 0) return (re: double.nan, im: double.nan);
          return (re: x / d, im: -y / d);
        },
        domain: const Bounds2D(xMin: -1, xMax: 1, yMin: -1, yMax: 1),
        cols: 12,
        rows: 12,
      );
      check(ds.rgbaPixels).isNotNull();
      check(ds.rgbaPixels!.length).equals(12 * 12 * 4);
      check(ds.samples.length).equals(144);
    });
  });

  group('2D Samplers', () {
    test(
      'sampleFunction2D refines high-curvature regions and breaks poles',
      () {
        final ds = sampleFunction2D(
          id: 'tan',
          label: '1 / x',
          fn: (x) => x == 0 ? double.nan : 1.0 / x,
          xMin: -2.0,
          xMax: 2.0,
          color: '#60a5fa',
          baseSamples: 32,
        );
        check(ds.xs.length).isGreaterThan(32);
        check(ds.ys.any((y) => y.isNaN)).isTrue;
      },
    );

    test('sampleFunction2D populates markers and references via samplers', () {
      final ds = sampleFunction2D(
        id: 'sin',
        label: 'sin(x)',
        fn: math.sin,
        xMin: -4.0,
        xMax: 4.0,
        color: '#60a5fa',
        markerSampler: (a, b) => const [
          PointMarker(x: 0.0, y: 0.0, label: 'root'),
        ],
        referenceSampler: (a, b) => [
          ReferenceLine(value: a, isVertical: true),
          ReferenceLine(value: b, isVertical: true),
        ],
      );
      check(ds.evaluator).isNotNull();
      check(ds.markerSampler).isNotNull();
      check(ds.referenceSampler).isNotNull();
      check(ds.markers.length).equals(1);
      check(ds.references.length).equals(2);
      check(ds.references.first.value).equals(-4.0);
      check(ds.references.last.value).equals(4.0);
    });

    test('sampleParametric2D samples unit circle', () {
      final ds = sampleParametric2D(
        id: 'circle',
        label: 'circle',
        fn: (t) => (x: math.cos(t), y: math.sin(t)),
        tMin: 0,
        tMax: 2 * math.pi,
        color: '#f472b6',
        samples: 64,
      );
      check(ds.xs.length).equals(64);
      final b = ds.bounds;
      check(b).isNotNull();
      check(b!.xMin).isCloseTo(-1.0, 0.05);
      check(b.xMax).isCloseTo(1.0, 0.05);
    });

    test('sampleScalarField2D and sampleVectorField2D populate grids', () {
      const domain = Bounds2D(xMin: -1, xMax: 1, yMin: -1, yMax: 1);
      final scalar = sampleScalarField2D(
        id: 'heat',
        label: 'x^2 + y^2',
        fn: (x, y) => x * x + y * y,
        domain: domain,
        cols: 10,
        rows: 10,
      );
      check(scalar.rgbaPixels).isNotNull();
      check(scalar.rgbaPixels!.length).equals(400);

      final vec = sampleVectorField2D(
        id: 'vf',
        label: '(-y, x)',
        fn: (x, y) => (u: -y, v: x),
        domain: domain,
        cols: 5,
        rows: 5,
      );
      check(vec.showVectors).isTrue;
      check(vec.samples.length).equals(25);
    });
  });

  group('3D Samplers', () {
    test('sampleSurface3D, sampleParametric3D, and sampleVectorField3D', () {
      final surf = sampleSurface3D(
        id: 's',
        label: 'x*y',
        fn: (x, y) => x * y,
        xMin: -1,
        xMax: 1,
        yMin: -1,
        yMax: 1,
        nx: 8,
        ny: 8,
      );
      check(surf.zs.length).equals(64);
      check(surf.bounds).isNotNull();

      final curve = sampleParametric3D(
        id: 'c',
        label: 'helix',
        fn: (t) => (x: math.cos(t), y: math.sin(t), z: t),
        tMin: 0,
        tMax: 6.28,
        color: '#34d399',
        samples: 40,
      );
      check(curve.zs.length).equals(40);

      final vf = sampleVectorField3D(
        id: 'vf3',
        label: 'radial',
        fn: (x, y, z) => (vx: x, vy: y, vz: z),
        xMin: -1,
        xMax: 1,
        yMin: -1,
        yMax: 1,
        zMin: -1,
        zMax: 1,
        nx: 3,
        ny: 3,
        nz: 3,
      );
      check(vf.samples.length).equals(27);
    });
  });
}
