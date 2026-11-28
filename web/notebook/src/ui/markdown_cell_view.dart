import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../engine/commands.dart';
import '../model/notebook.dart';
import 'cell_menu.dart';
import 'code_editor.dart';
import 'icons.dart';
import 'markdown_render.dart';

/// Document-first view for a [MarkdownCell]: pure prose + MathML at rest,
/// revealing an inline [CodeEditor] while editing and a compact Mathematica-
/// inspired cell bracket + overflow menu (`⋯`).
///
/// Supports in-place [setEditing] toggling without rebuilding sibling cells.
final class MarkdownCellView {
  new({
    required this.cell,
    required this.document,
    required this.registry,
    required this.isEditing,
    required this.onStartEdit,
    required this.onCommit,
    required this.onInsertMathBelow,
    required this.onInsertTextBelow,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onConvertToMath,
    required this.onDelete,
  }) {
    _buildDom();
  }

  MarkdownCell cell;
  NotebookDocument document;
  final CommandRegistry registry;
  bool isEditing;

  final void Function() onStartEdit;
  final void Function(String source, {required bool advance}) onCommit;
  final void Function() onInsertMathBelow;
  final void Function() onInsertTextBelow;
  final void Function() onMoveUp;
  final void Function() onMoveDown;
  final void Function() onConvertToMath;
  final void Function() onDelete;

  late final web.HTMLDivElement root;
  late final CellActionMenu _menu;
  late final web.HTMLDivElement _contentSlot;
  CodeEditor? _editor;

  /// Latest edited source text (falling back to persisted `cell.source`).
  String get currentSource => _editor?.value ?? cell.source;

  void focusEditor({bool moveToEnd = true}) {
    _editor?.focus(moveToEnd: moveToEnd);
  }

  /// Toggles editing mode in-place.
  void setEditing(
    bool editing, {
    bool focusInput = false,
    bool moveToEnd = true,
  }) {
    if (isEditing == editing) {
      if (editing && focusInput) focusEditor(moveToEnd: moveToEnd);
      return;
    }
    if (!editing) _menu.close();
    isEditing = editing;
    root.classList.toggle('focused', editing);
    _rebuildContentSlot();
    if (editing && focusInput) {
      focusEditor(moveToEnd: moveToEnd);
    }
  }

  /// Updates cell data and re-renders prose when not actively editing.
  void update(MarkdownCell nextCell, NotebookDocument nextDoc) {
    cell = nextCell;
    document = nextDoc;
    root.classList.toggle('stale', cell.stale);
    if (!isEditing) {
      _rebuildContentSlot();
    }
  }

  void dispose() => _menu.dispose();

  void _buildDom() {
    root = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = isEditing
          ? 'nb-cell nb-cell-md focused'
          : (cell.stale ? 'nb-cell nb-cell-md stale' : 'nb-cell nb-cell-md')
      ..setAttribute('data-uid', cell.uid);

    final row = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-cell-row';

    _contentSlot = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-md-slot';

    final controls = _buildControls();

    row
      ..append(_contentSlot)
      ..append(controls);

    final bracket = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-cell-bracket'
      ..setAttribute('aria-hidden', 'true');

    root
      ..append(row)
      ..append(bracket);

    _rebuildContentSlot();
  }

  void _rebuildContentSlot() {
    _contentSlot.innerHTML = ''.toJS;
    _editor = null;

    if (isEditing) {
      final editor = CodeEditor(
        mode: CodeEditorMode.markdown,
        registry: registry,
        env: document.env,
        initialText: cell.source,
        placeholder: 'Write Markdown prose, \$inline math\$, or {{r[1]}}...',
        onRunAndAdvance: (val) => onCommit(val, advance: true),
        onRunInPlace: (val) => onCommit(val, advance: false),
        onEscape: () => onCommit(currentSource, advance: false),
      );
      _editor = editor;
      _contentSlot.append(editor.root);
    } else {
      final prose = (web.document.createElement('div') as web.HTMLDivElement)
        ..className = 'nb-md-prose'
        ..innerHTML = MarkdownRenderer.renderToHtml(
          cell.source,
          document,
          registry: registry,
        ).toJS;
      prose.onclick = ((web.MouseEvent e) {
        final target = e.target;
        if (target.isA<web.Element>() &&
            (target as web.Element).closest('a') != null) {
          return;
        }
        onStartEdit();
      }).toJS;
      _contentSlot.append(prose);
    }
  }

  web.HTMLDivElement _buildControls() {
    final wrap = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-cell-controls';

    _menu = CellActionMenu(
      cellRoot: root,
      buildItems: () => [
        CellMenuAction(
          isEditing ? 'Render preview' : 'Edit text',
          isEditing ? NbIcons.check : NbIcons.pencil,
          () {
            if (isEditing) {
              onCommit(currentSource, advance: false);
            } else {
              onStartEdit();
            }
          },
          shortcut: isEditing ? '⇧↵' : null,
        ),
        const CellMenuDivider(),
        CellMenuAction('Insert math below', NbIcons.plus, onInsertMathBelow),
        CellMenuAction(
          'Insert text below',
          NbIcons.fileText,
          onInsertTextBelow,
        ),
        const CellMenuDivider(),
        CellMenuAction('Move up', NbIcons.arrowUp, onMoveUp),
        CellMenuAction('Move down', NbIcons.arrowDown, onMoveDown),
        CellMenuAction('Convert to Math', NbIcons.play, onConvertToMath),
        const CellMenuDivider(),
        CellMenuAction('Delete cell', NbIcons.trash, onDelete, danger: true),
      ],
    );

    wrap
      ..append(_menu.button)
      ..append(_menu.popup);
    return wrap;
  }
}
