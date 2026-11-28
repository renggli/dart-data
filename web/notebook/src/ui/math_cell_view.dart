import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../../shared/utils.dart';
import '../engine/commands.dart';
import '../model/environment.dart';
import '../model/notebook.dart';
import '../model/value.dart';
import 'cell_menu.dart';
import 'chips.dart';
import 'code_editor.dart';
import 'control_view.dart';
import 'highlighter.dart';
import 'icons.dart';
import 'plot_view.dart';

/// Document-first view for a [MathCell]: clean syntax-highlighted input +
/// rendered MathML/Plot output at rest; inline [CodeEditor], minimal top-right
/// Mathematica-inspired controls & overflow menu, and contextual follow-up
/// chips strictly when focused.
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
    required this.onControlChanged,
    required this.onInsertFollowUp,
    required this.onInsertMathBelow,
    required this.onInsertTextBelow,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onConvertToText,
    required this.onDelete,
    required this.onBlurExit,
    this.initialPlotHeight,
    this.onPlotHeightChanged,
  }) {
    _buildDom();
  }

  MathCell cell;
  Environment env;
  final CommandRegistry registry;
  bool isFocused;
  double? initialPlotHeight;
  final void Function(double height)? onPlotHeightChanged;

  final void Function() onFocus;
  final void Function(
    String source, {
    required bool advance,
    required bool approx,
  })
  onRun;
  final void Function(String key, Object? value, {required bool recordUndo})
  onControlChanged;
  final void Function(String call) onInsertFollowUp;
  final void Function() onInsertMathBelow;
  final void Function() onInsertTextBelow;
  final void Function() onMoveUp;
  final void Function() onMoveDown;
  final void Function() onConvertToText;
  final void Function() onDelete;
  final void Function() onBlurExit;

  late final web.HTMLDivElement root;
  late final web.HTMLSpanElement _badge;
  late final web.HTMLButtonElement _staleBtn;
  late final CellActionMenu _menu;
  late final web.HTMLDivElement _inputSlot;
  late final web.HTMLDivElement _outputSlot;
  late final web.HTMLDivElement _chipsSlot;

  CodeEditor? _editor;
  PlotView? _plotView;
  ControlView? _controlView;
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
    if (!focused) {
      _menu.close();
      if (_editor != null) {
        cell.source = _editor!.value;
      }
    }
    isFocused = focused;
    root.classList.toggle('focused', focused);
    _rebuildInputSlot();
    _rebuildChipsSlot();
    if (focused && focusInput) {
      focusEditor(moveToEnd: moveToEnd);
    }
  }

  /// Updates the cell data in-place, preserving mounted [PlotView] instances
  /// whenever `nextCell.value` is unchanged.
  void update(MathCell nextCell, Environment nextEnv, {double? plotHeight}) {
    final prevSource = currentSource;
    final valueChanged = _renderedValue != nextCell.value;
    cell = nextCell;
    env = nextEnv;
    if (plotHeight != null) initialPlotHeight = plotHeight;

    root.classList.toggle('stale', cell.stale);
    _staleBtn.style.display = cell.stale ? 'inline-flex' : 'none';
    _badge
      ..textContent = 'r[${cell.id}]'
      ..title = 'Reference this result as r[${cell.id}]';

    if (!isFocused) {
      _rebuildInputSlot();
    } else if (_editor != null && prevSource != cell.source) {
      _editor!.value = cell.source;
    }

    if (valueChanged) {
      final nextVal = nextCell.value;
      var updatedInPlace = false;
      if (nextVal is PlotValue && _plotView != null) {
        try {
          updatedInPlace = _plotView!.update(nextVal);
        } on Object {
          updatedInPlace = false;
        }
      } else if (nextVal != null && _controlView != null) {
        updatedInPlace = _controlView!.tryUpdateInPlace(
          nextVal,
          digits: env.settings.digits,
        );
      }

      if (updatedInPlace) {
        _renderedValue = nextVal;
      } else {
        _rebuildOutputSlot();
        _plotView?.render();
      }
    }
    _rebuildChipsSlot();
  }

  void mountRenderables() {
    _plotView?.render();
  }

  void dispose() {
    _menu.dispose();
    _controlView?.dispose();
    _controlView = null;
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

    final row = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-cell-row';

    _inputSlot = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-math-input-slot';

    final controls = _buildControls();

    row
      ..append(_inputSlot)
      ..append(controls);

    _outputSlot = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-math-output';
    _chipsSlot = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-chips-slot';

    final bracket = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-cell-bracket'
      ..setAttribute('aria-hidden', 'true');

    root
      ..append(_badge)
      ..append(row)
      ..append(_outputSlot)
      ..append(_chipsSlot)
      ..append(bracket);

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
    _controlView?.dispose();
    _controlView = null;
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
        try {
          final pv = PlotView(
            val,
            initialHeight: initialPlotHeight,
            onHeightChanged: (h) {
              initialPlotHeight = h;
              onPlotHeightChanged?.call(h);
            },
          );
          _plotView = pv;
          _outputSlot.append(pv.root);
        } on Object catch (e) {
          final err = (web.document.createElement('div') as web.HTMLDivElement)
            ..className = 'nb-output-error'
            ..textContent = '$e';
          _outputSlot.append(err);
        }

      case SliderValue() || InputValue() || ControlGroupValue():
        final cv = ControlView(
          val,
          digits: env.settings.digits,
          onChanged: onControlChanged,
        );
        _controlView = cv;
        _outputSlot.append(cv.root);

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
            ..title = 'Click to copy approximation'
            ..textContent = '≈ $approx';
          sub.onclick = ((web.MouseEvent _) {
            copyToClipboard(approx);
            showCopyToast(approx);
          }).toJS;
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

  web.HTMLDivElement _buildControls() {
    final wrap = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-cell-controls';

    _staleBtn = (web.document.createElement('button') as web.HTMLButtonElement)
      ..type = 'button'
      ..className = 'nb-stale-pill'
      ..textContent = 'Stale'
      ..title = 'Cell output is out of date — click to recompute'
      ..style.display = cell.stale ? 'inline-flex' : 'none';
    _staleBtn.onmousedown = ((web.MouseEvent e) {
      e.preventDefault();
      e.stopPropagation();
      onRun(currentSource, advance: false, approx: false);
    }).toJS;

    final runBtn =
        (web.document.createElement('button') as web.HTMLButtonElement)
          ..type = 'button'
          ..className = 'icon-btn nb-cell-run-btn'
          ..title = 'Evaluate (Shift+Enter)'
          ..innerHTML = NbIcons.play.toJS;
    runBtn.onmousedown = ((web.MouseEvent e) {
      e.preventDefault();
      e.stopPropagation();
      onRun(currentSource, advance: true, approx: false);
    }).toJS;

    _menu = CellActionMenu(
      cellRoot: root,
      buildItems: () {
        final v = cell.value;
        final canCopy =
            v != null &&
            v is! PlotValue &&
            v is! ErrorValue &&
            !(v is InfoValue && v.message.isEmpty);
        return [
          CellMenuAction(
            'Evaluate',
            NbIcons.play,
            () => onRun(currentSource, advance: true, approx: false),
            shortcut: '⇧↵',
          ),
          CellMenuAction(
            'Approximate',
            NbIcons.approx,
            () => onRun(currentSource, advance: false, approx: true),
            shortcut: '⌥↵',
          ),
          if (canCopy) ...[
            const CellMenuDivider(),
            CellMenuAction('Copy result', NbIcons.copy, () {
              final text = v.toCanonicalText();
              copyToClipboard(text);
              showCopyToast(text);
            }),
            CellMenuAction('Copy LaTeX', NbIcons.copy, () {
              final latex = v.toLatex();
              copyToClipboard(latex);
              showCopyToast(latex);
            }),
          ],
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
          CellMenuAction('Convert to Text', NbIcons.fileText, onConvertToText),
          const CellMenuDivider(),
          CellMenuAction('Delete cell', NbIcons.trash, onDelete, danger: true),
        ];
      },
    );

    wrap
      ..append(_staleBtn)
      ..append(runBtn)
      ..append(_menu.button)
      ..append(_menu.popup);

    return wrap;
  }
}
