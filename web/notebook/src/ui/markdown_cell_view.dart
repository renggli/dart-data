import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../engine/commands.dart';
import '../model/notebook.dart';
import 'code_editor.dart';
import 'icons.dart';
import 'markdown_render.dart';

/// Document-first view for a [MarkdownCell]: pure prose + MathML at rest,
/// revealing an inline [CodeEditor] and compact toolbar only while editing.
final class MarkdownCellView {
  new({
    required this.cell,
    required this.document,
    required this.registry,
    required this.isEditing,
    required this.onStartEdit,
    required this.onCommit,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onConvertToMath,
    required this.onDelete,
  }) {
    _buildDom();
  }

  final MarkdownCell cell;
  final NotebookDocument document;
  final CommandRegistry registry;
  final bool isEditing;

  final void Function() onStartEdit;
  final void Function(String source, {required bool advance}) onCommit;
  final void Function() onMoveUp;
  final void Function() onMoveDown;
  final void Function() onConvertToMath;
  final void Function() onDelete;

  late final web.HTMLDivElement root;
  CodeEditor? _editor;

  void focusEditor({bool moveToEnd = true}) {
    _editor?.focus(moveToEnd: moveToEnd);
  }

  void _buildDom() {
    root = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = isEditing
          ? 'nb-cell nb-cell-md focused'
          : (cell.stale ? 'nb-cell nb-cell-md stale' : 'nb-cell nb-cell-md')
      ..setAttribute('data-uid', cell.uid);

    if (isEditing) {
      final toolbar = _buildToolbar();
      final editor = CodeEditor(
        mode: CodeEditorMode.markdown,
        registry: registry,
        env: document.env,
        initialText: cell.source,
        placeholder: 'Write Markdown prose, \$inline math\$, or {{r[1]}}...',
        onRunAndAdvance: (val) => onCommit(val, advance: true),
        onRunInPlace: (val) => onCommit(val, advance: false),
        onEscape: () => onCommit(_editor?.value ?? cell.source, advance: false),
      );
      _editor = editor;
      root
        ..append(toolbar)
        ..append(editor.root);
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
      root.append(prose);
    }
  }

  web.HTMLDivElement _buildToolbar() {
    final bar = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-contextual-bar';

    bar
      ..append(
        _btn(
          'Done (Shift+Enter)',
          NbIcons.check,
          () => onCommit(_editor?.value ?? cell.source, advance: false),
        ),
      )
      ..append(_btn('Move up', NbIcons.arrowUp, onMoveUp))
      ..append(_btn('Move down', NbIcons.arrowDown, onMoveDown))
      ..append(_textBtn('Math', 'Convert to Math cell', onConvertToMath))
      ..append(_btn('Delete cell', NbIcons.trash, onDelete));

    return bar;
  }

  web.HTMLButtonElement _btn(String title, String svg, void Function() onTap) {
    final b = (web.document.createElement('button') as web.HTMLButtonElement)
      ..type = 'button'
      ..className = 'icon-btn'
      ..title = title
      ..innerHTML = svg.toJS;
    b.onmousedown = ((web.MouseEvent e) {
      e.preventDefault();
      onTap();
    }).toJS;
    return b;
  }

  web.HTMLButtonElement _textBtn(
    String label,
    String title,
    void Function() onTap,
  ) {
    final b = (web.document.createElement('button') as web.HTMLButtonElement)
      ..type = 'button'
      ..className = 'nb-bar-text-btn'
      ..title = title
      ..textContent = label;
    b.onmousedown = ((web.MouseEvent e) {
      e.preventDefault();
      onTap();
    }).toJS;
    return b;
  }
}
