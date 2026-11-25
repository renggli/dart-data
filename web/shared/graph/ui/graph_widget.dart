import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../model/dataset.dart';
import '../model/dataset_2d.dart';
import '../model/dataset_3d.dart';
import '../model/style.dart';
import '../render/renderer_2d.dart';
import '../render/renderer_3d.dart';
import '../render/renderer_base.dart';

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
      _attachContextMenu();
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
  GraphRenderer? _renderer;
  Scene2D? _scene2d;
  Scene3D? _scene3d;

  final Map<String, bool> _visibility = <String, bool>{};
  final Map<String, web.HTMLSpanElement> _readoutEls =
      <String, web.HTMLSpanElement>{};
  web.HTMLSpanElement? _probePill;
  web.HTMLDivElement? _contextMenu;
  bool _menuOpen = false;
  Timer? _longPressTimer;
  double _touchStartX = 0.0;
  double _touchStartY = 0.0;
  JSFunction? _onContextMenuJs;
  JSFunction? _onTouchDownJs;
  JSFunction? _onTouchMoveJs;
  JSFunction? _onTouchEndJs;
  JSFunction? _onDocPointerDownJs;
  JSFunction? _onDocKeyDownJs;

  /// Updates the widget with a new 2D [scene].
  void setScene2D(Scene2D scene, {bool preserveView = false}) {
    _scene2d = scene;
    _scene3d = null;
    if (_renderer case final Renderer2D r2d) {
      r2d.setScene(scene, preserveView: preserveView);
      _rebuildLegend(scene.datasets);
      return;
    }
    _renderer?.dispose();
    _renderer = null;
    _mount2D(scene);
  }

  /// Updates the widget with a new 3D [scene].
  void setScene3D(Scene3D scene, {bool preserveView = false}) {
    _scene3d = scene;
    _scene2d = null;
    if (_renderer case final Renderer3D r3d) {
      r3d.setScene(scene, preserveView: preserveView);
      _rebuildLegend(scene.datasets);
      return;
    }
    _renderer?.dispose();
    _renderer = null;
    _mount3D(scene);
  }

  /// Updates the active theme on the underlying renderer.
  void setTheme(GraphTheme theme) {
    _theme = theme;
    _renderer?.setTheme(theme);
  }

  /// Triggers a layout-aware canvas resize.
  void resize() => _renderer?.resize();

  /// Disposes observers and renderer resources.
  void dispose() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    if (_onContextMenuJs != null) {
      _viewport.removeEventListener('contextmenu', _onContextMenuJs);
    }
    if (_onTouchDownJs != null) {
      _viewport.removeEventListener('pointerdown', _onTouchDownJs);
    }
    if (_onTouchMoveJs != null) {
      _viewport.removeEventListener('pointermove', _onTouchMoveJs);
    }
    if (_onTouchEndJs != null) {
      _viewport.removeEventListener('pointerup', _onTouchEndJs);
      _viewport.removeEventListener('pointercancel', _onTouchEndJs);
    }
    if (_onDocPointerDownJs != null) {
      web.document.removeEventListener('pointerdown', _onDocPointerDownJs);
    }
    if (_onDocKeyDownJs != null) {
      web.document.removeEventListener('keydown', _onDocKeyDownJs);
    }
    _contextMenu?.remove();
    _resizeObserver.disconnect();
    _themeObserver.disconnect();
    _renderer?.dispose();
    _renderer = null;
  }

  void _mount2D(Scene2D scene) {
    _scene2d = scene;
    _renderer = Renderer2D(
      _viewport,
      theme: _theme,
      onProbeChanged: _onProbeChanged,
    )..setScene(scene);
    _rebuildLegend(scene.datasets);
  }

  void _mount3D(Scene3D scene) {
    _scene3d = scene;
    _renderer = Renderer3D(
      _viewport,
      theme: _theme,
      onProbeChanged: _onProbeChanged,
    )..setScene(scene);
    _rebuildLegend(scene.datasets);
  }

  void _onProbeChanged(GraphProbe? probe) {
    final r = _renderer;
    final datasets =
        (r is Renderer2D ? r.scene.datasets : null) ??
        _scene2d?.datasets ??
        _scene3d?.datasets ??
        const <GraphDataset>[];
    var hasCurveReadout = false;
    var hasSurfaceReadout = false;

    for (final ds in datasets) {
      final readoutEl = _readoutEls[ds.id];
      if (readoutEl == null) continue;
      final r = ds.readout(probe);
      if (r == null || r.valueText == null) {
        readoutEl.textContent = '';
      } else {
        if (ds is Function2DDataset || ds is Parametric2DDataset) {
          hasCurveReadout = true;
        } else if (ds is Surface3DDataset) {
          hasSurfaceReadout = true;
        }
        if (r.detailText != null) {
          readoutEl.textContent = '${r.valueText} (${r.detailText})';
        } else {
          readoutEl.textContent = r.valueText;
        }
      }
    }

    final pill = _probePill;
    if (pill != null) {
      if (probe == null) {
        pill.textContent = '';
        pill.style.visibility = 'hidden';
      } else {
        pill.style.visibility = 'visible';
        pill.textContent = switch (probe) {
          Probe2D() =>
            hasCurveReadout
                ? 'x = ${formatGraphNumber(probe.x)}'
                : '(${formatGraphNumber(probe.x)}, ${formatGraphNumber(probe.y)})',
          Probe3D() =>
            hasSurfaceReadout
                ? '(${formatGraphNumber(probe.x)}, ${formatGraphNumber(probe.y)})'
                : '(${formatGraphNumber(probe.x)}, ${formatGraphNumber(probe.y)}, ${formatGraphNumber(probe.z)})',
        };
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
          _renderer?.setVisibility(ds.id, next);
        }).toJS,
      );

      _legendBar.appendChild(item);
    }

    final pill = web.document.createElement('span') as web.HTMLSpanElement
      ..className = 'graph-probe-pill'
      ..style.visibility = 'hidden';
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

  void _attachContextMenu() {
    final menu = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'graph-context-menu'
      ..setAttribute('role', 'menu')
      ..setAttribute('hidden', '');

    menu.appendChild(
      _menuItem('<svg width="14" height="14" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"><path d="M8 3.5v9M3.5 8h9"/></svg>', 'Zoom in', () {
        _renderer?.zoomBy(_renderer is Renderer3D ? 0.85 : 0.8);
      }),
    );
    menu.appendChild(
      _menuItem('<svg width="14" height="14" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"><path d="M3.5 8h9"/></svg>', 'Zoom out', () {
        _renderer?.zoomBy(_renderer is Renderer3D ? 1.18 : 1.25);
      }),
    );
    menu.appendChild(
      _menuItem('<svg width="14" height="14" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M3 8a5 5 0 1 0 1.4-3.5L3 6"/><path d="M3 3v3h3"/></svg>', 'Reset view', () {
        _renderer?.resetView();
      }),
    );

    final divider = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'graph-menu-divider'
      ..setAttribute('role', 'separator');
    menu.appendChild(divider);

    menu.appendChild(
      _menuItem('<svg width="14" height="14" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M8 2.5v7.5M5 7l3 3 3-3M3 12.5h10"/></svg>', 'Download PNG', () {
        final url = _renderer?.exportPngDataUrl();
        if (url == null) return;
        final link = web.document.createElement('a') as web.HTMLAnchorElement
          ..href = url
          ..download = 'graph.png';
        link.click();
      }),
    );

    _contextMenu = menu;
    _viewport.appendChild(menu);

    _onContextMenuJs = ((web.MouseEvent e) {
      e.preventDefault();
      _openContextMenu(e.clientX.toDouble(), e.clientY.toDouble());
    }).toJS;
    _viewport.addEventListener('contextmenu', _onContextMenuJs);

    _onTouchDownJs = ((web.PointerEvent e) {
      if (e.pointerType != 'touch') return;
      _touchStartX = e.clientX.toDouble();
      _touchStartY = e.clientY.toDouble();
      _longPressTimer?.cancel();
      _longPressTimer = Timer(const Duration(milliseconds: 480), () {
        _openContextMenu(_touchStartX, _touchStartY);
      });
    }).toJS;
    _onTouchMoveJs = ((web.PointerEvent e) {
      if (_longPressTimer == null) return;
      final dx = e.clientX.toDouble() - _touchStartX;
      final dy = e.clientY.toDouble() - _touchStartY;
      if (dx * dx + dy * dy > 64.0) {
        _longPressTimer?.cancel();
        _longPressTimer = null;
      }
    }).toJS;
    _onTouchEndJs = ((web.PointerEvent _) {
      _longPressTimer?.cancel();
      _longPressTimer = null;
    }).toJS;

    _viewport.addEventListener('pointerdown', _onTouchDownJs);
    _viewport.addEventListener('pointermove', _onTouchMoveJs);
    _viewport.addEventListener('pointerup', _onTouchEndJs);
    _viewport.addEventListener('pointercancel', _onTouchEndJs);

    _onDocPointerDownJs = ((web.PointerEvent e) {
      if (!_menuOpen) return;
      final target = e.target;
      if (target != null &&
          target.isA<web.Node>() &&
          menu.contains(target as web.Node)) {
        return;
      }
      _closeContextMenu();
    }).toJS;
    _onDocKeyDownJs = ((web.KeyboardEvent e) {
      if (_menuOpen && e.key == 'Escape') {
        _closeContextMenu();
      }
    }).toJS;

    web.document.addEventListener('pointerdown', _onDocPointerDownJs);
    web.document.addEventListener('keydown', _onDocKeyDownJs);
  }

  void _openContextMenu(double clientX, double clientY) {
    final menu = _contextMenu;
    if (menu == null) return;
    _menuOpen = true;
    menu.removeAttribute('hidden');
    final rect = menu.getBoundingClientRect();
    final maxX = math.max(8.0, web.window.innerWidth - rect.width - 8.0);
    final maxY = math.max(8.0, web.window.innerHeight - rect.height - 8.0);
    menu.style.left = '${clientX.clamp(8.0, maxX)}px';
    menu.style.top = '${clientY.clamp(8.0, maxY)}px';
  }

  void _closeContextMenu() {
    _menuOpen = false;
    _contextMenu?.setAttribute('hidden', '');
  }

  web.HTMLButtonElement _menuItem(
    String svgIcon,
    String label,
    void Function() onClick,
  ) {
    final btn = web.document.createElement('button') as web.HTMLButtonElement
      ..type = 'button'
      ..className = 'graph-menu-item'
      ..setAttribute('role', 'menuitem');

    final iconSpan = web.document.createElement('span') as web.HTMLSpanElement
      ..className = 'graph-menu-icon'
      ..innerHTML = svgIcon.toJS;
    final labelSpan = web.document.createElement('span') as web.HTMLSpanElement
      ..textContent = label;
    btn.appendChild(iconSpan);
    btn.appendChild(labelSpan);

    btn.addEventListener(
      'click',
      ((web.Event _) {
        _closeContextMenu();
        onClick();
      }).toJS,
    );
    return btn;
  }
}

GraphTheme _detectDocumentTheme() {
  final attr = web.document.documentElement?.getAttribute('data-theme');
  return attr == 'light' ? GraphTheme.light : GraphTheme.dark;
}
