import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../../shared/utils.dart';
import '../model/examples.dart';
import '../worker/engine_client.dart';
import 'help.dart';
import 'icons.dart';
import 'left_sidebar.dart';
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

  static const String _rightOpenKey = 'data_notebook_right_open';

  late final EngineClient _client;
  late final NotebookView _notebookView;
  late final CommandPalette _palette;
  late final LeftSidebar _leftSidebar;
  late final RightSidebar _rightSidebar;

  late final web.HTMLSpanElement _busyBadge;
  late final web.HTMLButtonElement _undoBtn;
  late final web.HTMLButtonElement _redoBtn;
  late final web.HTMLButtonElement _helpBtn;

  String? _activeFileId;
  bool _suppressAutoSave = false;

  bool get _isRightOpen =>
      web.document.body?.classList.contains('nb-right-open') ?? false;

  Future<void> _init() async {
    _notebookView = NotebookView(
      _client,
      onFocusChanged: () => _leftSidebar.render(),
      onLoadExample: _loadExampleIntoCurrentOrNew,
    );

    _palette = CommandPalette(
      registry: _client.registry,
      env: _client.env,
      actions: _buildPaletteActions(),
      onInsert: (snippet) async {
        final uid = await _client.evalCell(snippet);
        _notebookView.focusCell(uid);
      },
    );

    _leftSidebar = LeftSidebar(
      client: _client,
      getActiveFileId: () => _activeFileId,
      getFocusedUid: () => _notebookView.focusedUid,
      onNewFile: _createNewNotebook,
      onOpenFile: (fileId) async {
        final entry = NotebookPersistence.findFile(fileId);
        if (entry == null) return;
        _activeFileId = entry.id;
        NotebookPersistence.setActiveFileId(entry.id);
        _notebookView.focusCell(null);
        await _loadSnapshot(entry.snapshot);
      },
      onRenameFile: (fileId, name) {
        NotebookPersistence.renameFile(fileId, name);
        _leftSidebar.render();
      },
      onDeleteFile: (fileId) async {
        final next = NotebookPersistence.deleteFile(fileId);
        if (fileId == _activeFileId) {
          _activeFileId = next.id;
          _notebookView.focusCell(null);
          await _loadSnapshot(next.snapshot);
        } else {
          _leftSidebar.render();
        }
      },
      onImportFile: (filename, content) async {
        final baseName = filename.replaceFirst(RegExp(r'\.[^.]+$'), '');
        final entry = NotebookPersistence.createFile(
          name: baseName.isEmpty ? 'Imported Notebook' : baseName,
        );
        _activeFileId = entry.id;
        _notebookView.focusCell(null);
        if (filename.toLowerCase().endsWith('.json')) {
          try {
            final snap = (jsonDecode(content) as Map).cast<String, Object?>();
            await _client.loadSnapshot(snap);
            return;
          } on Object {
            // Fall through to markdown import
          }
        }
        await _client.importMarkdown(content);
      },
      onExportMarkdown: _exportMarkdown,
      onCopyShareUrl: _copyShareUrl,
      onSelectCell: (uid) => _notebookView.scrollToAndFocusCell(uid),
      onDeleteCell: (uid) => _client.deleteCell(uid),
      onInsertMathCell: () async {
        final uid = await _client.evalCell('');
        _notebookView.focusCell(uid);
      },
      onInsertTextCell: () async {
        final uid = await _client.insertMarkdown('');
        _notebookView.focusCell(uid);
      },
      onTerminalAction: () {
        if (isMobileViewport()) setSidebarCollapsed(true);
      },
    );

    _rightSidebar = RightSidebar(
      registry: _client.registry,
      env: _client.env,
      onInsertMathExample: (code) async {
        final uid = await _client.evalCell(code);
        _notebookView.focusCell(uid);
      },
      onInsertTextExample: (md) async {
        final uid = await _client.insertMarkdown(md);
        _notebookView.focusCell(uid);
      },
      onMobileExampleInserted: () {
        if (isMobileViewport()) _setRightOpen(false);
      },
    );

    _wireHeader();
    _initSidebars();

    web.document.getElementById('nb-left-sidebar')?.append(_leftSidebar.root);
    web.document.getElementById('nb-right-sidebar')?.append(_rightSidebar.root);
    web.document.getElementById('notebook-mount')?.append(_notebookView.root);
    web.document.body?.append(_palette.backdrop);

    final examples = await _loadExamples();
    _notebookView.setExamples(examples);

    // Load persisted notebook or bootstrap initial file
    final initial = NotebookPersistence.loadInitial();
    if (initial.entry != null) {
      _activeFileId = initial.entry!.id;
      await _loadSnapshot(initial.entry!.snapshot);
    } else if (examples.isNotEmpty) {
      final entry = NotebookPersistence.createFile(name: examples.first.title);
      _activeFileId = entry.id;
      await _client.importMarkdown(examples.first.markdown);
    } else {
      final entry = NotebookPersistence.createFile(name: 'Untitled Notebook');
      _activeFileId = entry.id;
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
    _leftSidebar.render();
  }

  Future<List<NotebookExample>> _loadExamples() async {
    try {
      final response = await web.window.fetch('examples.json'.toJS).toDart;
      if (!response.ok) return const [];
      final raw = (await response.text().toDart).toDart;
      return NotebookExample.parseJson(raw);
    } on Object {
      return const [];
    }
  }

  Future<void> _createNewNotebook() async {
    final entry = NotebookPersistence.createFile(name: 'Untitled Notebook');
    _activeFileId = entry.id;
    _notebookView.focusCell(null);
    await _loadSnapshot(entry.snapshot);
  }

  Future<void> _loadExampleIntoCurrentOrNew(NotebookExample ex) async {
    if (_activeFileId != null) {
      NotebookPersistence.renameFile(_activeFileId!, ex.title);
    } else {
      final entry = NotebookPersistence.createFile(name: ex.title);
      _activeFileId = entry.id;
    }
    _notebookView.focusCell(null);
    await _client.importMarkdown(ex.markdown);
  }

  Future<void> _exportMarkdown() async {
    final md = await _client.exportMarkdown();
    final name = _downloadBaseName();
    downloadFile('$name.md', md, 'text/markdown');
  }

  void _copyShareUrl() {
    final url = NotebookPersistence.buildShareUrl(_client.document);
    copyToClipboard(url);
    showCopyToast('Share link');
  }

  List<PaletteAction> _buildPaletteActions() => [
    PaletteAction(
      id: 'new-math',
      label: 'New Math Cell',
      description: 'Append an interactive symbolic computation cell.',
      category: 'Cells',
      shortcut: '⇧⌘M',
      onRun: () async {
        final uid = await _client.evalCell('');
        _notebookView.focusCell(uid);
      },
    ),
    PaletteAction(
      id: 'new-text',
      label: 'New Text Cell',
      description: 'Append a Markdown & MathML prose cell.',
      category: 'Cells',
      onRun: () async {
        final uid = await _client.insertMarkdown('');
        _notebookView.focusCell(uid);
      },
    ),
    PaletteAction(
      id: 'new-notebook',
      label: 'New Empty Notebook',
      description: 'Create a blank notebook with example gallery.',
      category: 'Files',
      onRun: _createNewNotebook,
    ),
    PaletteAction(
      id: 'undo',
      label: 'Undo',
      description: 'Undo the previous notebook edit or evaluation.',
      category: 'Edit',
      shortcut: '⌘Z',
      onRun: () => _client.undo(),
    ),
    PaletteAction(
      id: 'redo',
      label: 'Redo',
      description: 'Redo a previously undone notebook edit.',
      category: 'Edit',
      shortcut: '⇧⌘Z',
      onRun: () => _client.redo(),
    ),
    PaletteAction(
      id: 'recompute-all',
      label: 'Recompute All Cells',
      description:
          'Re-evaluate every math and interpolated text cell from top.',
      category: 'Execution',
      onRun: () => _client.recomputeAll(),
    ),
    PaletteAction(
      id: 'recompute-stale',
      label: 'Recompute Stale Cells',
      description: 'Update dependent cells marked out of date.',
      category: 'Execution',
      onRun: () => _client.recomputeStale(),
    ),
    PaletteAction(
      id: 'clear-session',
      label: 'Clear Session Variables',
      description: 'Reset bound variables, functions, and assumptions.',
      category: 'Session',
      onRun: () => _client.clearSession(),
    ),
    PaletteAction(
      id: 'export-md',
      label: 'Export Notebook (.md)',
      description: 'Download the active notebook as portable Markdown.',
      category: 'Files',
      onRun: _exportMarkdown,
    ),
    PaletteAction(
      id: 'copy-share-link',
      label: 'Copy Shareable Link',
      description: 'Copy a URL encoding the current notebook.',
      category: 'Files',
      onRun: _copyShareUrl,
    ),
    PaletteAction(
      id: 'left-files',
      label: 'Show Files Tab',
      description: 'Open local notebook files in the left sidebar.',
      category: 'View',
      onRun: () {
        setSidebarCollapsed(false);
        _leftSidebar.setTab(LeftSidebarTab.files);
      },
    ),
    PaletteAction(
      id: 'left-structure',
      label: 'Show Structure Tab',
      description: 'Inspect document cells and jump to entries.',
      category: 'View',
      onRun: () {
        setSidebarCollapsed(false);
        _leftSidebar.setTab(LeftSidebarTab.structure);
      },
    ),
    PaletteAction(
      id: 'left-settings',
      label: 'Show Settings Tab',
      description: 'Adjust domain, precision, and display preferences.',
      category: 'View',
      onRun: () {
        setSidebarCollapsed(false);
        _leftSidebar.setTab(LeftSidebarTab.settings);
      },
    ),
    PaletteAction(
      id: 'right-math',
      label: 'Open Math Reference',
      description: 'Browse symbolic syntax, commands, and functions.',
      category: 'Reference',
      onRun: () {
        _setRightOpen(true);
        _rightSidebar.setTab(RightSidebarTab.math);
      },
    ),
    PaletteAction(
      id: 'right-text',
      label: 'Open Text & Markdown Guide',
      description: 'Browse Markdown syntax and live {{...}} interpolation.',
      category: 'Reference',
      onRun: () {
        _setRightOpen(true);
        _rightSidebar.setTab(RightSidebarTab.text);
      },
    ),
    PaletteAction(
      id: 'toggle-help',
      label: 'Toggle Reference Sidebar',
      description: 'Show or hide the right Text & Math sidebar.',
      category: 'View',
      onRun: () => _setRightOpen(!_isRightOpen),
    ),
    PaletteAction(
      id: 'toggle-theme',
      label: 'Toggle Light / Dark Theme',
      description: 'Switch the color theme across the workspace.',
      category: 'View',
      onRun: () {
        (web.document.querySelector('[data-theme-toggle]') as web.HTMLElement?)
            ?.click();
      },
    ),
  ];

  Future<void> _loadSnapshot(Map<String, Object?> snapshot) async {
    _suppressAutoSave = true;
    try {
      await _client.loadSnapshot(snapshot);
    } finally {
      _suppressAutoSave = false;
    }
    if (_activeFileId != null) {
      NotebookPersistence.saveFile(_activeFileId!, _client.document);
    }
    _leftSidebar.render();
  }

  String _downloadBaseName() {
    if (_activeFileId != null) {
      final entry = NotebookPersistence.findFile(_activeFileId!);
      if (entry != null) {
        final safe = entry.name
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
            .replaceAll(RegExp(r'^-+|-+$'), '');
        if (safe.isNotEmpty) return safe;
      }
    }
    return 'notebook';
  }

  void _wireHeader() {
    _busyBadge = web.document.getElementById('nb-busy')! as web.HTMLSpanElement;
    web.document.getElementById('nb-palette-btn')
      ?..innerHTML = NbIcons.commandPalette.toJS
      ..addEventListener('click', ((web.Event _) => _palette.open()).toJS);
    _undoBtn = web.document.getElementById('nb-undo')! as web.HTMLButtonElement
      ..innerHTML = NbIcons.undo.toJS
      ..onclick = ((web.MouseEvent _) => _client.undo()).toJS;
    _redoBtn = web.document.getElementById('nb-redo')! as web.HTMLButtonElement
      ..innerHTML = NbIcons.redo.toJS
      ..onclick = ((web.MouseEvent _) => _client.redo()).toJS;
    _helpBtn =
        web.document.getElementById('nb-help-btn')! as web.HTMLButtonElement
          ..innerHTML = NbIcons.help.toJS
          ..onclick = ((web.MouseEvent _) => _setRightOpen(!_isRightOpen)).toJS;

    setupSidebarToggle(
      onToggled: (collapsed) {
        if (!collapsed && isMobileViewport() && _isRightOpen) {
          _setRightOpen(false, persist: false);
        }
        web.window.dispatchEvent(web.Event('resize'));
      },
    );
  }

  void _initSidebars() {
    if (isMobileViewport()) {
      setSidebarCollapsed(true, persist: false);
      _setRightOpen(false, persist: false);
      return;
    }
    final rightPref = web.window.localStorage.getItem(_rightOpenKey);
    _setRightOpen(rightPref == 'true', persist: false);
  }

  void _setRightOpen(bool open, {bool persist = true}) {
    final body = web.document.body;
    if (body == null) return;
    if (open && isMobileViewport() && !isSidebarCollapsed()) {
      setSidebarCollapsed(true, persist: false);
    }
    body.classList.toggle('nb-right-open', open);
    _helpBtn
      ..classList.toggle('active', open)
      ..setAttribute('aria-expanded', open ? 'true' : 'false');
    if (persist && !isMobileViewport()) {
      web.window.localStorage.setItem(_rightOpenKey, open ? 'true' : 'false');
    }
    Timer(const Duration(milliseconds: 280), () {
      web.window.dispatchEvent(web.Event('resize'));
    });
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
    if (!_suppressAutoSave && _activeFileId != null) {
      NotebookPersistence.saveFile(_activeFileId!, _client.document);
    }
    _notebookView.render(focusEditorUid: _notebookView.focusedUid);
    _leftSidebar.render();
  }
}
