import 'dart:convert';
import 'dart:js_interop';

import 'package:data/symbolic.dart';
import 'package:web/web.dart' as web;

import '../model/notebook.dart';
import '../worker/engine_client.dart';
import 'help.dart';
import 'icons.dart';
import 'matrix_editor.dart';
import 'notebook_view.dart';
import 'palette.dart';
import 'persistence.dart';
import 'shortcuts.dart';

/// Top-level coordinator for the Symbolic Notebook web application.
final class NotebookApp {
  new() {
    _client = EngineClient(
      onBusyStateChanged: _onBusyChanged,
      onStateUpdated: _onStateUpdated,
    );
    _init();
  }

  late final EngineClient _client;
  late final NotebookView _notebookView;
  late final CommandPalette _palette;
  late final HelpDrawer _helpDrawer;
  late final MatrixEditorModal _matrixModal;

  late final web.HTMLDivElement _settingsBackdrop;
  late final web.HTMLSpanElement _busyBadge;
  late final web.HTMLButtonElement _undoBtn;
  late final web.HTMLButtonElement _redoBtn;
  late final web.HTMLElement _outlineList;

  Future<void> _init() async {
    _notebookView = NotebookView(_client, onFocusChanged: _renderOutline);
    _palette = CommandPalette(
      registry: _client.registry,
      env: _client.env,
      onInsert: (snippet) async {
        final uid = await _client.evalCell(snippet);
        _notebookView.focusCell(uid);
      },
    );
    _helpDrawer = HelpDrawer(
      registry: _client.registry,
      env: _client.env,
      onInsertExample: (ex) async {
        final uid = await _client.evalCell(ex);
        _notebookView.focusCell(uid);
      },
    );
    _matrixModal = MatrixEditorModal(
      onInsert: (literal) async {
        final uid = await _client.evalCell(literal);
        _notebookView.focusCell(uid);
      },
    );

    _buildSettingsDrawer();
    _wireHeader();

    final mount = web.document.getElementById('notebook-mount');
    mount?.append(_notebookView.root);

    web.document.body?.append(_palette.backdrop);
    web.document.body?.append(_helpDrawer.backdrop);
    web.document.body?.append(_matrixModal.backdrop);
    web.document.body?.append(_settingsBackdrop);

    final saved = NotebookPersistence.loadInitialSnapshot();
    if (saved != null) {
      await _client.loadSnapshot(saved);
    }

    NotebookShortcuts.attach(
      onOpenPalette: _palette.open,
      onUndo: () => _client.undo(),
      onRedo: () => _client.redo(),
      onNewMathCell: () async {
        final uid = await _client.evalCell('');
        _notebookView.focusCell(uid);
      },
    );

    _notebookView.render();
    _renderOutline();
  }

  void _wireHeader() {
    _busyBadge = web.document.getElementById('nb-busy')! as web.HTMLSpanElement;
    _outlineList =
        web.document.getElementById('nb-outline-list')! as web.HTMLElement;

    _undoBtn = web.document.getElementById('nb-undo')! as web.HTMLButtonElement
      ..innerHTML = NbIcons.undo.toJS
      ..onclick = ((web.MouseEvent _) => _client.undo()).toJS;
    _redoBtn = web.document.getElementById('nb-redo')! as web.HTMLButtonElement
      ..innerHTML = NbIcons.redo.toJS
      ..onclick = ((web.MouseEvent _) => _client.redo()).toJS;

    final loadInput =
        (web.document.createElement('input') as web.HTMLInputElement)
          ..type = 'file'
          ..accept = '.md,.markdown,.json,.txt'
          ..style.display = 'none';
    loadInput.onchange = ((web.Event _) {
      final files = loadInput.files;
      if (files == null || files.length == 0) return;
      final file = files.item(0);
      if (file == null) return;
      final reader = web.FileReader();
      reader.onload = ((web.Event _) async {
        final text = (reader.result as JSString?)?.toDart ?? '';
        if (file.name.toLowerCase().endsWith('.json')) {
          try {
            final snap = (jsonDecode(text) as Map).cast<String, Object?>();
            await _client.loadSnapshot(snap);
            return;
          } on Object {
            // Fall through to markdown import
          }
        }
        await _client.importMarkdown(text);
      }).toJS;
      reader.readAsText(file);
    }).toJS;
    web.document.body?.append(loadInput);

    (web.document.getElementById('nb-load-btn')! as web.HTMLButtonElement)
      ..innerHTML = NbIcons.upload.toJS
      ..onclick = ((web.MouseEvent _) {
        loadInput.value = '';
        loadInput.click();
      }).toJS;

    (web.document.getElementById('nb-save-btn')! as web.HTMLButtonElement)
      ..innerHTML = NbIcons.download.toJS
      ..onclick = ((web.MouseEvent _) async {
        final md = await _client.exportMarkdown();
        NotebookPersistence.downloadFile('notebook.md', md, 'text/markdown');
      }).toJS;

    (web.document.getElementById('nb-clear-btn')! as web.HTMLButtonElement)
      ..innerHTML = NbIcons.clearDoc.toJS
      ..onclick = ((web.MouseEvent _) async {
        _notebookView.focusCell(null);
        await _client.importMarkdown('');
      }).toJS;

    (web.document.getElementById('nb-palette-btn')! as web.HTMLButtonElement)
      ..innerHTML = NbIcons.search.toJS
      ..onclick = ((web.MouseEvent _) => _palette.open()).toJS;

    (web.document.getElementById('nb-matrix-btn')! as web.HTMLButtonElement)
      ..innerHTML = NbIcons.matrix.toJS
      ..onclick = ((web.MouseEvent _) => _matrixModal.open()).toJS;

    (web.document.getElementById('nb-help-btn')! as web.HTMLButtonElement)
      ..innerHTML = NbIcons.help.toJS
      ..onclick = ((web.MouseEvent _) => _helpDrawer.open()).toJS;

    (web.document.getElementById('nb-settings-btn')! as web.HTMLButtonElement)
      ..innerHTML = NbIcons.settings.toJS
      ..onclick = ((web.MouseEvent _) {
        _settingsBackdrop.style.display = 'flex';
      }).toJS;
  }

  void _buildSettingsDrawer() {
    _settingsBackdrop =
        (web.document.createElement('div') as web.HTMLDivElement)
          ..className = 'nb-drawer-backdrop'
          ..style.display = 'none';

    final drawer = (web.document.createElement('aside') as web.HTMLElement)
      ..className = 'nb-drawer';

    final header = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-drawer-header';
    final title = (web.document.createElement('h3') as web.HTMLHeadingElement)
      ..textContent = 'Notebook Settings';
    final closeBtn =
        (web.document.createElement('button') as web.HTMLButtonElement)
          ..type = 'button'
          ..className = 'nb-bar-text-btn'
          ..textContent = 'Close';
    closeBtn.onclick = ((web.MouseEvent _) {
      _settingsBackdrop.style.display = 'none';
    }).toJS;
    header
      ..append(title)
      ..append(closeBtn);

    final body = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-drawer-body nb-settings-body';

    // Domain assumption select
    final domSelect =
        web.document.createElement('select') as web.HTMLSelectElement;
    for (final d in VariableDomain.values) {
      final opt =
          (web.document.createElement('option') as web.HTMLOptionElement)
            ..value = d.name
            ..textContent = d.name
            ..selected = d == _client.env.settings.domain;
      domSelect.append(opt);
    }
    domSelect.onchange = ((web.Event _) {
      final chosen = VariableDomain.values.firstWhere(
        (d) => d.name == domSelect.value,
        orElse: () => VariableDomain.complex,
      );
      _client.updateSettings(_client.env.settings.copyWith(domain: chosen));
    }).toJS;

    // Precision digits
    final digitsInput =
        (web.document.createElement('input') as web.HTMLInputElement)
          ..type = 'number'
          ..min = '2'
          ..max = '16'
          ..value = '${_client.env.settings.digits}';
    digitsInput.onchange = ((web.Event _) {
      final d = (int.tryParse(digitsInput.value) ?? 10).clamp(2, 16);
      _client.updateSettings(_client.env.settings.copyWith(digits: d));
    }).toJS;

    // Export / Share / Session actions
    final exportJson = _actionBtn('Export JSON (.json)', () {
      NotebookPersistence.downloadFile(
        'notebook.json',
        const JsonEncoder.withIndent('  ').convert(_client.document.toJson()),
        'application/json',
      );
    });

    final shareBtn = _actionBtn('Copy Share URL', () {
      final url = NotebookPersistence.buildShareUrl(_client.document);
      web.window.navigator.clipboard.writeText(url);
    });

    final recomputeBtn = _actionBtn('Recompute All Cells', () {
      _client.recomputeAll();
      _settingsBackdrop.style.display = 'none';
    });

    final clearBtn = _actionBtn('Clear Session Variables', () {
      _client.clearSession();
    });

    body
      ..append(_settingRow('Default Domain', domSelect))
      ..append(_settingRow('Approx Digits', digitsInput))
      ..append(exportJson)
      ..append(shareBtn)
      ..append(recomputeBtn)
      ..append(clearBtn);

    drawer
      ..append(header)
      ..append(body);
    _settingsBackdrop.append(drawer);
    _settingsBackdrop.onclick = ((web.MouseEvent e) {
      if (e.target == _settingsBackdrop) {
        _settingsBackdrop.style.display = 'none';
      }
    }).toJS;
  }

  web.HTMLDivElement _settingRow(String label, web.HTMLElement control) {
    final row = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-setting-row';
    final lbl = (web.document.createElement('label') as web.HTMLLabelElement)
      ..textContent = label;
    row
      ..append(lbl)
      ..append(control);
    return row;
  }

  web.HTMLButtonElement _actionBtn(String label, void Function() onTap) {
    final b = (web.document.createElement('button') as web.HTMLButtonElement)
      ..type = 'button'
      ..className = 'nb-secondary-btn'
      ..textContent = label;
    b.onclick = ((web.MouseEvent _) => onTap()).toJS;
    return b;
  }

  void _onBusyChanged(bool isBusy, int elapsedMs) {
    if (!isBusy) {
      _busyBadge.style.display = 'none';
      return;
    }
    _busyBadge.style.display = 'inline-flex';
    _busyBadge.textContent =
        'Computing (${(elapsedMs / 1000).toStringAsFixed(1)}s)...';
  }

  void _onStateUpdated() {
    _undoBtn.disabled = !_client.canUndo;
    _redoBtn.disabled = !_client.canRedo;
    NotebookPersistence.saveSnapshot(_client.document);
    _notebookView.render(focusEditorUid: _notebookView.focusedUid);
    _renderOutline();
  }

  void _renderOutline() {
    _outlineList.innerHTML = ''.toJS;
    final cells = _client.document.cells;
    if (cells.isEmpty) {
      final empty = (web.document.createElement('div') as web.HTMLDivElement)
        ..className = 'nb-outline-empty'
        ..textContent = 'No cells yet.';
      _outlineList.append(empty);
      return;
    }

    for (final cell in cells) {
      final item = (web.document.createElement('div') as web.HTMLDivElement)
        ..className = cell.uid == _notebookView.focusedUid
            ? 'sidebar-item active'
            : 'sidebar-item';
      final label = (web.document.createElement('span') as web.HTMLSpanElement)
        ..className = 'nb-outline-label';
      final tag = (web.document.createElement('span') as web.HTMLSpanElement)
        ..className = 'badge';

      switch (cell) {
        case MarkdownCell(:final source):
          final firstLine = source.trim().split('\n').first;
          label.textContent = firstLine.isEmpty
              ? 'Text cell'
              : firstLine.replaceFirst(RegExp(r'^#+\s*'), '');
          tag.textContent = 'Text';
        case MathCell(:final id, :final source):
          final firstLine = source.trim().split('\n').first;
          label.textContent = firstLine.isEmpty ? 'Math cell' : firstLine;
          tag.textContent = 'r[$id]';
      }

      item
        ..append(label)
        ..append(tag)
        ..onclick = ((web.MouseEvent _) {
          _notebookView.focusCell(cell.uid);
        }).toJS;
      _outlineList.append(item);
    }
  }
}
