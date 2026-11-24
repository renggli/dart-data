import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../model/dataset.dart';
import '../model/dataset_2d.dart';
import '../model/dataset_3d.dart';
import '../model/style.dart';
import '../render/renderer_2d.dart';
import '../render/renderer_3d.dart';

/// Unified interactive graph widget wrapping [Renderer2D] or [Renderer3D],
/// a compact wrapping top legend with live readouts, and a hover toolbar.
class GraphWidget {
  /// Creates a 2D graph widget for [scene].
  factory view2d(
    Scene2D scene, {
    GraphTheme? theme,
    double height = 360,
    bool showLegend = true,
    bool showToolbar = true,
  }) {
    final widget = GraphWidget._(
      theme: theme ?? _detectDocumentTheme(),
      height: height,
      showLegend: showLegend,
      showToolbar: showToolbar,
    );
    widget._mount2D(scene);
    return widget;
  }

  /// Creates a 3D graph widget for [scene].
  factory view3d(
    Scene3D scene, {
    GraphTheme? theme,
    double height = 400,
    bool showLegend = true,
    bool showToolbar = true,
  }) {
    final widget = GraphWidget._(
      theme: theme ?? _detectDocumentTheme(),
      height: height,
      showLegend: showLegend,
      showToolbar: showToolbar,
    );
    widget._mount3D(scene);
    return widget;
  }

  new _({
    required this._theme,
    required double height,
    required bool showLegend,
    required bool showToolbar,
  }) : _showLegend = showLegend {
    element = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'graph-root';

    _legendBar = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'graph-legend';
    if (!showLegend) {
      _legendBar.style.display = 'none';
    }
    element.appendChild(_legendBar);

    _viewport = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'graph-viewport'
      ..style.height = '${height.round()}px';
    element.appendChild(_viewport);

    if (showToolbar) {
      _viewport.appendChild(_buildToolbar());
    }

    _resizeObserver = web.ResizeObserver(
      ((JSArray<web.ResizeObserverEntry> _, web.ResizeObserver _) {
        resize();
      }).toJS,
    );
    _resizeObserver.observe(_viewport);

    _themeObserver = web.MutationObserver(
      ((JSArray<web.MutationRecord> _, web.MutationObserver _) {
        setTheme(_detectDocumentTheme());
      }).toJS,
    );
    final rootEl = web.document.documentElement;
    if (rootEl != null) {
      _themeObserver.observe(
        rootEl,
        web.MutationObserverInit(
          attributes: true,
          attributeFilter: <JSString>['data-theme'.toJS].toJS,
        ),
      );
    }
  }

  /// Root DOM element to mount into any container.
  late final web.HTMLDivElement element;

  late final web.HTMLDivElement _legendBar;
  late final web.HTMLDivElement _viewport;
  late final web.ResizeObserver _resizeObserver;
  late final web.MutationObserver _themeObserver;

  GraphTheme _theme;
  final bool _showLegend;
  Renderer2D? _renderer2d;
  Renderer3D? _renderer3d;
  Scene2D? _scene2d;
  Scene3D? _scene3d;

  final Map<String, bool> _visibility = <String, bool>{};
  final Map<String, web.HTMLSpanElement> _readoutEls =
      <String, web.HTMLSpanElement>{};
  web.HTMLSpanElement? _probePill;

  /// Updates the widget with a new 2D [scene].
  void setScene2D(Scene2D scene, {bool preserveView = false}) {
    _scene2d = scene;
    _scene3d = null;
    if (_renderer2d == null) {
      _renderer3d?.dispose();
      _renderer3d = null;
      _mount2D(scene);
      return;
    }
    _renderer2d!.setScene(scene, preserveView: preserveView);
    _rebuildLegend(scene.datasets);
  }

  /// Updates the widget with a new 3D [scene].
  void setScene3D(Scene3D scene, {bool preserveView = false}) {
    _scene3d = scene;
    _scene2d = null;
    if (_renderer3d == null) {
      _renderer2d?.dispose();
      _renderer2d = null;
      _mount3D(scene);
      return;
    }
    _renderer3d!.setScene(scene, preserveView: preserveView);
    _rebuildLegend(scene.datasets);
  }

  /// Updates the active theme on the underlying renderer.
  void setTheme(GraphTheme theme) {
    _theme = theme;
    _renderer2d?.setTheme(theme);
    _renderer3d?.setTheme(theme);
  }

  /// Triggers a layout-aware canvas resize.
  void resize() {
    _renderer2d?.resize();
    _renderer3d?.resize();
  }

  /// Disposes observers and renderer resources.
  void dispose() {
    _resizeObserver.disconnect();
    _themeObserver.disconnect();
    _renderer2d?.dispose();
    _renderer3d?.dispose();
    _renderer2d = null;
    _renderer3d = null;
  }

  void _mount2D(Scene2D scene) {
    _scene2d = scene;
    _renderer2d = Renderer2D(
      _viewport,
      theme: _theme,
      onProbeChanged: _onProbeChanged,
    )..setScene(scene);
    _rebuildLegend(scene.datasets);
  }

  void _mount3D(Scene3D scene) {
    _scene3d = scene;
    _renderer3d = Renderer3D(
      _viewport,
      theme: _theme,
      onProbeChanged: _onProbeChanged,
    )..setScene(scene);
    _rebuildLegend(scene.datasets);
  }

  void _onProbeChanged(GraphProbe? probe) {
    final pill = _probePill;
    if (pill != null) {
      if (probe == null) {
        pill.textContent = '';
        pill.style.display = 'none';
      } else {
        pill.style.display = 'inline-flex';
        pill.textContent = switch (probe) {
          Probe2D() =>
            probe.y2 != null
                ? 'x: ${formatGraphNumber(probe.x)}, y: ${formatGraphNumber(probe.y)}, y₂: ${formatGraphNumber(probe.y2!)}'
                : '(${formatGraphNumber(probe.x)}, ${formatGraphNumber(probe.y)})',
          Probe3D() =>
            '(${formatGraphNumber(probe.x)}, ${formatGraphNumber(probe.y)}, ${formatGraphNumber(probe.z)})',
        };
      }
    }

    final datasets =
        _scene2d?.datasets ?? _scene3d?.datasets ?? const <GraphDataset>[];
    for (final ds in datasets) {
      final readoutEl = _readoutEls[ds.id];
      if (readoutEl == null) continue;
      final r = ds.readout(probe);
      if (r == null || r.valueText == null) {
        readoutEl.textContent = '';
      } else if (r.detailText != null) {
        readoutEl.textContent = '${r.valueText} (${r.detailText})';
      } else {
        readoutEl.textContent = r.valueText;
      }
    }
  }

  void _rebuildLegend(List<GraphDataset> datasets) {
    _legendBar.replaceChildren(<JSAny>[].toJS);
    _readoutEls.clear();
    _probePill = null;

    if (!_showLegend || datasets.isEmpty) {
      _legendBar.style.display = 'none';
      return;
    }
    _legendBar.style.display = 'flex';

    for (final ds in datasets) {
      final visible = _visibility[ds.id] ?? ds.visible;
      _visibility[ds.id] = visible;

      final item = web.document.createElement('button') as web.HTMLButtonElement
        ..type = 'button'
        ..className = visible
            ? 'graph-legend-item'
            : 'graph-legend-item is-hidden';

      item.appendChild(_buildSwatch(ds.swatch));

      final labelEl = web.document.createElement('span') as web.HTMLSpanElement
        ..className = 'graph-legend-label'
        ..textContent = ds.label;
      item.appendChild(labelEl);

      final readoutEl =
          web.document.createElement('span') as web.HTMLSpanElement
            ..className = 'graph-legend-readout';
      _readoutEls[ds.id] = readoutEl;
      item.appendChild(readoutEl);

      item.addEventListener(
        'click',
        ((web.Event _) {
          final next = !(_visibility[ds.id] ?? true);
          _visibility[ds.id] = next;
          item.classList.toggle('is-hidden', !next);
          _renderer2d?.setVisibility(ds.id, next);
          _renderer3d?.setVisibility(ds.id, next);
        }).toJS,
      );

      _legendBar.appendChild(item);
    }

    final pill = web.document.createElement('span') as web.HTMLSpanElement
      ..className = 'graph-probe-pill'
      ..style.display = 'none';
    _probePill = pill;
    _legendBar.appendChild(pill);
  }

  web.HTMLElement _buildSwatch(LegendSwatch swatch) {
    final el = web.document.createElement('span') as web.HTMLSpanElement;
    switch (swatch) {
      case LineSwatch():
        el.className = swatch.dashed
            ? 'graph-swatch-line is-dashed'
            : 'graph-swatch-line';
        el.style.borderColor = swatch.color;
      case MarkerSwatch():
        el.className = 'graph-swatch-marker';
        el.style.backgroundColor = swatch.filled ? swatch.color : 'transparent';
        el.style.borderColor = swatch.color;
      case GradientSwatch():
        el.className = 'graph-swatch-gradient';
        final stops = swatch.colormap.gradientStops(6).join(', ');
        el.style.background = 'linear-gradient(90deg, $stops)';
      case PhaseSwatch():
        el.className = 'graph-swatch-phase';
    }
    return el;
  }

  web.HTMLDivElement _buildToolbar() {
    final bar = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'graph-toolbar';

    bar.appendChild(
      _toolbarBtn('+', 'Zoom in', () {
        _renderer2d?.zoomBy(0.8);
        _renderer3d?.zoomBy(0.85);
      }),
    );
    bar.appendChild(
      _toolbarBtn('−', 'Zoom out', () {
        _renderer2d?.zoomBy(1.25);
        _renderer3d?.zoomBy(1.18);
      }),
    );
    bar.appendChild(
      _toolbarBtn('↺', 'Reset view', () {
        _renderer2d?.resetView();
        _renderer3d?.resetView();
      }),
    );
    bar.appendChild(
      _toolbarBtn('⤓', 'Export PNG', () {
        final url =
            _renderer2d?.exportPngDataUrl() ?? _renderer3d?.exportPngDataUrl();
        if (url == null) return;
        final link = web.document.createElement('a') as web.HTMLAnchorElement
          ..href = url
          ..download = 'graph.png';
        link.click();
      }),
    );
    return bar;
  }

  web.HTMLButtonElement _toolbarBtn(
    String text,
    String title,
    void Function() onClick,
  ) {
    final btn = web.document.createElement('button') as web.HTMLButtonElement
      ..type = 'button'
      ..className = 'graph-tool-btn'
      ..title = title
      ..textContent = text;
    btn.addEventListener('click', ((web.Event _) => onClick()).toJS);
    return btn;
  }
}

GraphTheme _detectDocumentTheme() {
  final attr = web.document.documentElement?.getAttribute('data-theme');
  return attr == 'light' ? GraphTheme.light : GraphTheme.dark;
}
