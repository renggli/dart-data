import 'dart:math' as math;

import 'package:data/symbolic.dart';
import 'package:data/type.dart';
import 'package:web/web.dart' as web;

import '../../../shared/graph/model/axis.dart';
import '../../../shared/graph/model/dataset_2d.dart';
import '../../../shared/graph/model/dataset_3d.dart';
import '../../../shared/graph/model/style.dart';
import '../../../shared/graph/sampling/oklch.dart';
import '../../../shared/graph/sampling/sampler_2d.dart';
import '../../../shared/graph/ui/graph_widget.dart';
import '../model/value.dart';

/// Interactive plot view inside a notebook cell powered by [GraphWidget].
final class PlotView {
  /// Creates a plot view for [plot].
  new(this.plot) {
    root = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-plot';

    if (plot.title != null && plot.title!.isNotEmpty) {
      final titleEl = (web.document.createElement('div') as web.HTMLDivElement)
        ..className = 'nb-plot-title'
        ..textContent = plot.title;
      root.append(titleEl);
    }

    final scene3d = plot.scene3d ?? _reconstructScene3D(plot);
    if (scene3d != null) {
      _widget = GraphWidget.view3d(scene3d, height: 340);
    } else {
      final scene2d = plot.scene2d ?? _reconstructScene2D(plot);
      _widget = GraphWidget.view2d(scene2d, height: 300);
    }
    root.append(_widget.element);
  }

  /// Backing plot specification.
  final PlotValue plot;

  /// Root DOM element mounted inside the cell output.
  late final web.HTMLDivElement root;

  late final GraphWidget _widget;

  /// Triggers a layout-aware re-render.
  void render() => _widget.resize();

  /// Notifies the underlying graph widget of a container resize.
  void resize() => _widget.resize();

  /// Disposes the underlying graph widget.
  void dispose() => _widget.dispose();
}

Scene3D? _reconstructScene3D(PlotValue plot) {
  final s3d = plot.surface3d;
  if (s3d != null) {
    final n = s3d.gridSize;
    final xs = List<double>.generate(
      n,
      (i) => s3d.minX + (i / math.max(1, n - 1)) * (s3d.maxX - s3d.minX),
      growable: false,
    );
    final ys = List<double>.generate(
      n,
      (j) => s3d.minY + (j / math.max(1, n - 1)) * (s3d.maxY - s3d.minY),
      growable: false,
    );
    return Scene3D(
      datasets: [
        Surface3DDataset(
          id: 's0',
          label: plot.expressions.isNotEmpty
              ? plot.expressions.first.toString()
              : 'z',
          nx: n,
          ny: n,
          xs: xs,
          ys: ys,
          zs: s3d.zValues,
          colormap: plot.isComplex ? Colormap.plasma : Colormap.viridis,
        ),
      ],
      xAxis: AxisConfig(label: s3d.xVar),
      yAxis: AxisConfig(label: s3d.yVar),
      zAxis: const AxisConfig(label: 'z'),
    );
  }

  final p3d = plot.parametric3d;
  if (p3d != null) {
    return Scene3D(
      datasets: [
        Parametric3DDataset(
          id: 'p3d',
          label: plot.expressions.join(', '),
          ts: p3d.tValues,
          xs: p3d.xValues,
          ys: p3d.yValues,
          zs: p3d.zValues,
          color: defaultGraphPalette[0],
        ),
      ],
    );
  }

  return null;
}

Scene2D _reconstructScene2D(PlotValue plot) {
  if (plot.isComplex && plot.expressions.isNotEmpty) {
    final expr = plot.expressions.first;
    final fn = expr.toComplexFunction1D(plot.variable);
    final ds = sampleComplexDomainGrid(
      id: 'c0',
      label: expr.toString(),
      fn: (x, y) {
        final w = fn(Complex(x, y));
        return (re: w.a.toDouble(), im: w.b.toDouble());
      },
      domain: Bounds2D(
        xMin: plot.minX,
        xMax: plot.maxX,
        yMin: plot.minY,
        yMax: plot.maxY,
      ),
    );
    return Scene2D(
      datasets: [ds],
      xAxis: const AxisConfig(label: 'Re(z)'),
      yAxis: const AxisConfig(label: 'Im(z)'),
      equalAspect: true,
    );
  }

  final datasets = <Dataset2D>[];
  for (var i = 0; i < plot.curves.length; i++) {
    final curve = plot.curves[i];
    final xs = <double>[];
    final ys = <double>[];
    for (final seg in curve.segments) {
      if (xs.isNotEmpty) {
        xs.add(double.nan);
        ys.add(double.nan);
      }
      xs.addAll(seg.x);
      ys.addAll(seg.y);
    }
    datasets.add(
      Function2DDataset(
        id: 'c$i',
        label: curve.label,
        xs: xs,
        ys: ys,
        color: defaultGraphPalette[i % defaultGraphPalette.length],
        markers: [
          for (final m in curve.markers)
            PointMarker(x: m.x, y: m.y, label: m.label),
        ],
      ),
    );
  }

  if (datasets.isEmpty && plot.expressions.isNotEmpty) {
    for (var i = 0; i < plot.expressions.length; i++) {
      final expr = plot.expressions[i];
      final fn = expr.toFunction1D(plot.variable);
      datasets.add(
        sampleFunction2D(
          id: 'f$i',
          label: expr.toString(),
          fn: fn,
          xMin: plot.minX,
          xMax: plot.maxX,
          color: defaultGraphPalette[i % defaultGraphPalette.length],
        ),
      );
    }
  }

  return Scene2D(
    datasets: datasets,
    xAxis: AxisConfig(label: plot.variable),
    equalAspect: plot.isParametric,
  );
}
