import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../engine/commands.dart';
import '../model/environment.dart';
import '../model/notebook.dart';
import '../model/value.dart';
import 'chips.dart';
import 'code_editor.dart';
import 'highlighter.dart';
import 'icons.dart';
import 'plot_view.dart';

/// Document-first view for a [MathCell]: clean syntax-highlighted input +
/// rendered MathML/Plot output at rest; inline [CodeEditor], floating top-right
/// toolbar, and contextual follow-up chips strictly when focused.
///
/// Supports in-place [setFocused] toggling without destroying mounted WebGL
/// plots or causing layout jumps.
final class MathCellView {
  new({
    required this.cell,
    required this.env,
    required this.registry,
    required this.isFocused,
    required this.onFocus,
    required this.onRun,
    required this.onInsertFollowUp,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onConvertToText,
    required this.onDelete,
    required this.onBlurExit,
  }) {
    _buildDom();
  }

  MathCell cell;
  Environment env;
  final CommandRegistry registry;
  bool isFocused;

  final void Function() onFocus;
  final void Function(
    String source, {
    required bool advance,
    required bool approx,
  })
  onRun;
  final void Function(String call) onInsertFollowUp;
  final void Function() onMoveUp;
  final void Function() onMoveDown;
  final void Function() onConvertToText;
  final void Function() onDelete;
  final void Function() onBlurExit;

  late final web.HTMLDivElement root;
  late final web.HTMLSpanElement _badge;
  late final web.HTMLDivElement _toolbar;
  late final web.HTMLDivElement _inputSlot;
  late final web.HTMLDivElement _outputSlot;
  late final web.HTMLDivElement _chipsSlot;

  CodeEditor? _editor;
  PlotView? _plotView;
  CalcValue? _renderedValue;

  /// Latest edited source text (falling back to persisted `cell.source`).
  String get currentSource => _editor?.value ?? cell.source;

  void focusEditor({bool moveToEnd = true}) {
    _editor?.focus(moveToEnd: moveToEnd);
  }

  /// Toggles focused/editing state in-place without destroying the output or
  /// any mounted WebGL [PlotView].
  void setFocused(
    bool focused, {
    bool focusInput = false,
    bool moveToEnd = true,
  }) {
    if (isFocused == focused) {
      if (focused && focusInput) focusEditor(moveToEnd: moveToEnd);
      return;
    }
    if (!focused && _editor != null) {
      cell.source = _editor!.value;
    }
    isFocused = focused;
    root.classList.toggle('focused', focused);
    _toolbar.style.display = focused ? 'flex' : 'none';
    _rebuildInputSlot();
    _rebuildChipsSlot();
    if (focused && focusInput) {
      focusEditor(moveToEnd: moveToEnd);
    }
  }

  /// Updates the cell data in-place, preserving mounted [PlotView] instances
  /// whenever `nextCell.value` is unchanged.
  void update(MathCell nextCell, Environment nextEnv) {
    final prevSource = currentSource;
    final valueChanged = _renderedValue != nextCell.value;
    cell = nextCell;
    env = nextEnv;

    root.classList.toggle('stale', cell.stale);
    _badge
      ..textContent = 'r[${cell.id}]'
      ..title = 'Reference this result as r[${cell.id}]';

    if (!isFocused) {
      _rebuildInputSlot();
    } else if (_editor != null && prevSource != cell.source) {
      _editor!.value = cell.source;
    }

    if (valueChanged) {
      _rebuildOutputSlot();
      _plotView?.render();
    }
    _rebuildChipsSlot();
  }

  void mountRenderables() {
    _plotView?.render();
  }

  void dispose() {
    _plotView?.dispose();
    _plotView = null;
  }

  void _buildDom() {
    final classes = <String>[
      'nb-cell',
      'nb-cell-math',
      if (isFocused) 'focused',
      if (cell.stale) 'stale',
    ];
    root = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = classes.join(' ')
      ..setAttribute('data-uid', cell.uid);

    _badge = (web.document.createElement('span') as web.HTMLSpanElement)
      ..className = 'nb-margin-id'
      ..textContent = 'r[${cell.id}]'
      ..title = 'Reference this result as r[${cell.id}]';

    _toolbar = _buildToolbar()..style.display = isFocused ? 'flex' : 'none';
    _inputSlot = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-math-input-slot';
    _outputSlot = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-math-output';
    _chipsSlot = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-chips-slot';

    root
      ..append(_badge)
      ..append(_toolbar)
      ..append(_inputSlot)
      ..append(_outputSlot)
      ..append(_chipsSlot);

    _rebuildInputSlot();
    _rebuildOutputSlot();
    _rebuildChipsSlot();
  }

  void _rebuildInputSlot() {
    _inputSlot.innerHTML = ''.toJS;
    _editor = null;

    if (isFocused) {
      final editor = CodeEditor(
        mode: CodeEditorMode.math,
        registry: registry,
        env: env,
        initialText: cell.source,
        placeholder: 'Enter expression, assignment (a := ...), or command...',
        onRunAndAdvance: (val) => onRun(val, advance: true, approx: false),
        onRunInPlace: (val) => onRun(val, advance: false, approx: false),
        onApprox: (val) => onRun(val, advance: false, approx: true),
        onEscape: onBlurExit,
      );
      if (cell.value is ErrorValue) {
        editor.root.classList.add('has-error');
      }
      _editor = editor;
      _inputSlot.append(editor.root);
    } else {
      final inputPreview =
          (web.document.createElement('div') as web.HTMLDivElement)
            ..className = 'nb-math-input-rest';
      final pre = (web.document.createElement('pre') as web.HTMLPreElement)
        ..className = 'nb-math-code-rest'
        ..innerHTML =
            (cell.source.trim().isEmpty
                    ? '<span class="tok-comment">Empty math cell — click to edit</span>'
                    : SyntaxHighlighter.highlightMathHtml(
                        cell.source,
                        registry: registry,
                        env: env,
                      ))
                .toJS;
      inputPreview
        ..append(pre)
        ..onclick = ((web.MouseEvent _) => onFocus()).toJS;
      _inputSlot.append(inputPreview);
    }
  }

  void _rebuildOutputSlot() {
    _plotView?.dispose();
    _plotView = null;
    _outputSlot.innerHTML = ''.toJS;
    final val = cell.value;
    _renderedValue = val;

    if (val == null || (val is InfoValue && val.message.isEmpty)) {
      _outputSlot.style.display = 'none';
      return;
    }
    _outputSlot.style.display = 'block';

    switch (val) {
      case PlotValue():
        final pv = PlotView(val);
        _plotView = pv;
        _outputSlot.append(pv.root);

      case ErrorValue(:final message, :final suggestion):
        final err = (web.document.createElement('div') as web.HTMLDivElement)
          ..className = 'nb-output-error'
          ..textContent = suggestion != null
              ? '$message ($suggestion)'
              : message;
        _outputSlot.append(err);

      case InfoValue(:final message, :final title):
        final info = (web.document.createElement('div') as web.HTMLDivElement)
          ..className = 'nb-output-info';
        if (title != null && title.isNotEmpty) {
          final t = (web.document.createElement('div') as web.HTMLDivElement)
            ..className = 'nb-output-info-title'
            ..textContent = title;
          info.append(t);
        }
        final body = (web.document.createElement('pre') as web.HTMLPreElement)
          ..className = 'nb-output-info-body'
          ..textContent = message;
        info.append(body);
        _outputSlot.append(info);

      default:
        final mathEl = (web.document.createElement('div') as web.HTMLDivElement)
          ..className = 'nb-output-math'
          ..innerHTML = val.toMathMl(display: true).toJS;
        _outputSlot.append(mathEl);

        final approx = val.approxSummary(digits: env.settings.digits);
        if (approx != null) {
          final sub = (web.document.createElement('div') as web.HTMLDivElement)
            ..className = 'nb-output-approx'
            ..textContent = '≈ $approx';
          _outputSlot.append(sub);
        }
    }
  }

  void _rebuildChipsSlot() {
    _chipsSlot.innerHTML = ''.toJS;
    if (!isFocused) {
      _chipsSlot.style.display = 'none';
      return;
    }
    final chips = ActionChips.build(
      'r[${cell.id}]',
      cell.value,
      registry,
      onInsertFollowUp,
    );
    if (chips.children.length > 0) {
      _chipsSlot.style.display = 'block';
      _chipsSlot.append(chips);
    } else {
      _chipsSlot.style.display = 'none';
    }
  }

  web.HTMLDivElement _buildToolbar() {
    final bar = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-contextual-bar';

    bar
      ..append(
        _btn(
          'Run (Shift+Enter)',
          NbIcons.play,
          () => onRun(currentSource, advance: true, approx: false),
        ),
      )
      ..append(
        _btn(
          'Approximate (Alt+Enter)',
          NbIcons.approx,
          () => onRun(currentSource, advance: false, approx: true),
        ),
      )
      ..append(_btn('Move up', NbIcons.arrowUp, onMoveUp))
      ..append(_btn('Move down', NbIcons.arrowDown, onMoveDown))
      ..append(_textBtn('Text', 'Convert to Markdown cell', onConvertToText))
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
