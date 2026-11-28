import 'dart:js_interop';
import 'dart:math' as math;

import 'package:data/linear.dart';
import 'package:data/numeric.dart';
import 'package:data/symbolic.dart';
import 'package:data/type.dart';
import 'package:web/web.dart' as web;

import '../../../shared/graph/model/axis.dart';
import '../../../shared/graph/model/dataset_2d.dart';
import '../../../shared/graph/model/dataset_3d.dart';
import '../../../shared/graph/model/style.dart';
import '../../../shared/graph/sampling/oklch.dart';
import '../../../shared/graph/sampling/sampler_2d.dart';
import '../../../shared/graph/sampling/sampler_3d.dart';
import '../../../shared/graph/ui/graph_widget.dart';
import '../../../shared/utils.dart';
import '../model/value.dart';

/// Interactive plot view inside a notebook cell powered by [GraphWidget].
final class PlotView {
  /// Creates a vertically resizable plot view for [plot].
  new(this.plot, {double? initialHeight, this.onHeightChanged}) {
    root = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-plot';

    if (plot.title != null && plot.title!.isNotEmpty) {
      final titleEl = (web.document.createElement('div') as web.HTMLDivElement)
        ..className = 'nb-plot-title'
        ..textContent = plot.title;
      root.append(titleEl);
    }

    final defaultH = plot.is3d ? 340.0 : 300.0;
    final startH = (initialHeight ?? defaultH).clamp(minHeight, maxHeight);
    final scene3d = _reconstructScene3D(plot);
    if (scene3d != null) {
      _widget = GraphWidget.view3d(scene3d, height: startH);
    } else {
      final scene2d = _reconstructScene2D(plot);
      _widget = GraphWidget.view2d(scene2d, height: startH);
    }
    root
      ..append(_widget.element)
      ..append(_buildResizeHandle(defaultH));
  }

  static const double minHeight = 160.0;
  static const double maxHeight = 900.0;

  /// Backing plot specification.
  PlotValue plot;

  /// Invoked when the user finishes resizing the plot vertically.
  final void Function(double height)? onHeightChanged;

  /// Root DOM element mounted inside the cell output.
  late final web.HTMLDivElement root;

  late final GraphWidget _widget;

  double get height => _widget.height;

  /// Updates the mounted graph widget in-place when [nextPlot] shares the same
  /// dimensionality and title, returning `false` if a full rebuild is needed.
  bool update(PlotValue nextPlot) {
    if (nextPlot.plotKind != plot.plotKind || nextPlot.title != plot.title) {
      return false;
    }
    if (nextPlot == plot) return true;
    plot = nextPlot;
    final scene3d = _reconstructScene3D(nextPlot);
    if (scene3d != null) {
      _widget.setScene3D(scene3d, preserveView: true);
    } else {
      final scene2d = _reconstructScene2D(nextPlot);
      _widget.setScene2D(scene2d, preserveView: false);
    }
    return true;
  }

  /// Triggers a layout-aware re-render.
  void render() => _widget.resize();

  /// Notifies the underlying graph widget of a container resize.
  void resize() => _widget.resize();

  /// Disposes the underlying graph widget.
  void dispose() => _widget.dispose();

  web.HTMLDivElement _buildResizeHandle(double defaultHeight) {
    final handle = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-plot-resize-handle'
      ..title = 'Drag to resize plot height (double-click to reset)';
    final pill = (web.document.createElement('span') as web.HTMLSpanElement)
      ..className = 'nb-plot-resize-pill';
    handle.append(pill);

    var dragging = false;
    var startY = 0.0;
    var startH = _widget.height;

    handle.onpointerdown = ((web.PointerEvent e) {
      e.preventDefault();
      dragging = true;
      startY = e.clientYDouble;
      startH = _widget.height;
      handle.setPointerCapture(e.pointerId);
      handle.classList.add('dragging');
      web.document.body?.classList.add('nb-resizing-plot');
    }).toJS;

    handle.onpointermove = ((web.PointerEvent e) {
      if (!dragging) return;
      final dy = e.clientYDouble - startY;
      final nextH = (startH + dy).clamp(minHeight, maxHeight);
      _widget.setHeight(nextH);
    }).toJS;

    void endDrag(web.PointerEvent e) {
      if (!dragging) return;
      dragging = false;
      handle.classList.remove('dragging');
      web.document.body?.classList.remove('nb-resizing-plot');
      try {
        handle.releasePointerCapture(e.pointerId);
      } on Object {
        // Ignore if pointer capture already released
      }
      onHeightChanged?.call(_widget.height);
    }

    handle.onpointerup = endDrag.toJS;
    handle.onpointercancel = endDrag.toJS;
    handle.ondblclick = ((web.MouseEvent _) {
      _widget.setHeight(defaultHeight);
      onHeightChanged?.call(defaultHeight);
    }).toJS;

    return handle;
  }
}

Scene3D? _reconstructScene3D(PlotValue plot) {
  switch (plot.plotKind) {
    case PlotKind.surface3d:
      if (plot.expressions.isEmpty) return null;
      final expr = plot.expressions.first;
      final xVar = plot.variable;
      final yVar =
          plot.yVariable ??
          expr.freeVariables.firstWhere((v) => v != xVar, orElse: () => 'y');
      final fn = expr.toVectorFunction([xVar, yVar]);
      final grid = plot.gridSize.clamp(12, 128);
      return Scene3D(
        datasets: [
          sampleSurface3D(
            id: 's0',
            label: expr.toString(),
            fn: (x, y) => fn(Vector.fromList([x, y])),
            xMin: plot.minX,
            xMax: plot.maxX,
            yMin: plot.minY,
            yMax: plot.maxY,
            nx: grid,
            ny: grid,
          ),
        ],
        xAxis: AxisConfig(label: xVar),
        yAxis: AxisConfig(label: yVar),
        zAxis: const AxisConfig(label: 'z'),
      );
    case PlotKind.complex3d:
      if (plot.expressions.isEmpty) return null;
      final expr = plot.expressions.first;
      final fn = expr.toComplexFunction1D(plot.variable);
      final grid = plot.gridSize.clamp(12, 128);
      return Scene3D(
        datasets: [
          sampleSurface3D(
            id: 'c3d',
            label: '|$expr|',
            fn: (x, y) {
              final w = fn(Complex(x, y));
              final mag = math.sqrt(w.a * w.a + w.b * w.b);
              return mag.isFinite ? math.min(mag, 25.0) : double.nan;
            },
            xMin: plot.minX,
            xMax: plot.maxX,
            yMin: plot.minY,
            yMax: plot.maxY,
            nx: grid,
            ny: grid,
            colormap: Colormap.plasma,
          ),
        ],
        xAxis: const AxisConfig(label: 'Re(z)'),
        yAxis: const AxisConfig(label: 'Im(z)'),
        zAxis: const AxisConfig(label: '|f(z)|'),
      );
    case PlotKind.vectorField3d:
      if (plot.expressions.length < 3) return null;
      final xVar = plot.variable;
      final yVar = plot.yVariable ?? 'y';
      const zVar = 'z';
      final vxFn = plot.expressions[0].toVectorFunction([xVar, yVar, zVar]);
      final vyFn = plot.expressions[1].toVectorFunction([xVar, yVar, zVar]);
      final vzFn = plot.expressions[2].toVectorFunction([xVar, yVar, zVar]);
      final grid = plot.gridSize.clamp(3, 10);
      return Scene3D(
        datasets: [
          sampleVectorField3D(
            id: 'vf3d',
            label:
                '(${plot.expressions[0]}, ${plot.expressions[1]}, ${plot.expressions[2]})',
            fn: (x, y, z) => (
              vx: vxFn(Vector.fromList([x, y, z])),
              vy: vyFn(Vector.fromList([x, y, z])),
              vz: vzFn(Vector.fromList([x, y, z])),
            ),
            xMin: plot.minX,
            xMax: plot.maxX,
            yMin: plot.minY,
            yMax: plot.maxY,
            zMin: plot.minX,
            zMax: plot.maxX,
            nx: grid,
            ny: grid,
            nz: grid,
          ),
        ],
        xAxis: AxisConfig(label: xVar),
        yAxis: AxisConfig(label: yVar),
        zAxis: const AxisConfig(label: zVar),
      );
    default:
      return null;
  }
}

Scene2D _reconstructScene2D(PlotValue plot) {
  if ((plot.plotKind == PlotKind.complex2d || plot.isComplex) &&
      plot.expressions.isNotEmpty) {
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
      lazy: true,
    );
    return Scene2D(
      datasets: [ds],
      xAxis: const AxisConfig(label: 'Re(z)'),
      yAxis: const AxisConfig(label: 'Im(z)'),
      equalAspect: true,
    );
  }

  if (plot.plotKind == PlotKind.parametric2d && plot.expressions.length >= 2) {
    final xFn = plot.expressions[0].toFunction1D(plot.variable);
    final yFn = plot.expressions[1].toFunction1D(plot.variable);
    final ds = sampleParametric2D(
      id: 'p0',
      label: '(${plot.expressions[0]}, ${plot.expressions[1]})',
      fn: (t) => (x: xFn(t), y: yFn(t)),
      tMin: plot.minT ?? plot.minX,
      tMax: plot.maxT ?? plot.maxX,
      color: defaultGraphPalette[0],
      samples: 720,
    );
    return Scene2D(datasets: [ds], equalAspect: true);
  }

  if (plot.plotKind == PlotKind.vectorField2d && plot.expressions.length >= 2) {
    final xVar = plot.variable;
    final yVar = plot.yVariable ?? 'y';
    final uFn = plot.expressions[0].toVectorFunction([xVar, yVar]);
    final vFn = plot.expressions[1].toVectorFunction([xVar, yVar]);
    final grid = plot.gridSize.clamp(4, 32);
    final ds = sampleVectorField2D(
      id: 'vf2d',
      label: '(${plot.expressions[0]}, ${plot.expressions[1]})',
      fn: (x, y) =>
          (u: uFn(Vector.fromList([x, y])), v: vFn(Vector.fromList([x, y]))),
      domain: Bounds2D(
        xMin: plot.minX,
        xMax: plot.maxX,
        yMin: plot.minY,
        yMax: plot.maxY,
      ),
      cols: grid,
      rows: grid,
    );
    return Scene2D(
      datasets: [ds],
      xAxis: AxisConfig(label: xVar),
      yAxis: AxisConfig(label: yVar),
      equalAspect: true,
    );
  }

  if (plot.plotKind == PlotKind.heatmap2d && plot.expressions.isNotEmpty) {
    final xVar = plot.variable;
    final yVar = plot.yVariable ?? 'y';
    final fn = plot.expressions.first.toVectorFunction([xVar, yVar]);
    final grid = plot.gridSize.clamp(16, 200);
    final ds = sampleScalarField2D(
      id: 'hm2d',
      label: plot.expressions.first.toString(),
      fn: (x, y) => fn(Vector.fromList([x, y])),
      domain: Bounds2D(
        xMin: plot.minX,
        xMax: plot.maxX,
        yMin: plot.minY,
        yMax: plot.maxY,
      ),
      cols: grid,
      rows: grid,
      lazy: true,
    );
    return Scene2D(
      datasets: [ds],
      xAxis: AxisConfig(label: xVar),
      yAxis: AxisConfig(label: yVar),
    );
  }

  if (plot.plotKind == PlotKind.ode2d && plot.expressions.isNotEmpty) {
    final rhs = plot.expressions.first;
    final tVar = plot.variable;
    final yVar = plot.yVariable ?? 'y';
    final f = rhs.toVectorFunction([tVar, yVar]);
    final method = switch (plot.odeMethod) {
      'rk4' => OdeMethod.rk4,
      'bdf2' => OdeMethod.bdf2,
      _ => OdeMethod.dormandPrince45,
    };
    const sampleCount = 400;
    final span = plot.maxX - plot.minX;
    final tEval = span == 0.0
        ? null
        : [
            for (var i = 0; i < sampleCount; i++)
              plot.minX + span * (i / (sampleCount - 1)),
          ];
    final sol = solveOde(
      f: (double t, Vector<double> y) => Vector.fromList([
        f(Vector.fromList([t, y[0]])),
      ]),
      t0: plot.minX,
      tEnd: plot.maxX,
      y0: Vector.fromList([plot.odeY0 ?? 1.0]),
      method: method,
      maxStep: math.max(1e-6, span.abs() / 100),
      tEval: tEval,
    );
    return Scene2D(
      datasets: [
        Function2DDataset(
          id: 'ode0',
          label: '$yVar($tVar)',
          xs: sol.t,
          ys: [for (final row in sol.y) row[0]],
          color: defaultGraphPalette[0],
        ),
      ],
      xAxis: AxisConfig(label: tVar),
      yAxis: AxisConfig(label: yVar),
    );
  }

  final datasets = <Dataset2D>[];
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

  return Scene2D(
    datasets: datasets,
    xAxis: AxisConfig(label: plot.variable),
    equalAspect: plot.isParametric,
  );
}
