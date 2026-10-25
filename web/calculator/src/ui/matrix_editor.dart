import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

/// Docked visual $m \times n$ matrix & vector grid builder panel mounted below
/// the formula input bar, serializing to `[[a, b], [c, d]]` or `[a, b, c]`.
final class MatrixBuilderPanel {
  new({
    required this.onInsert,
    this.onVisibilityChanged,
    int initialRows = 2,
    int initialCols = 2,
  }) : _rows = initialRows.clamp(1, 8),
       _cols = initialCols.clamp(1, 8) {
    _buildDom();
  }

  final void Function(String literalText) onInsert;
  final void Function(bool visible)? onVisibilityChanged;

  late final web.HTMLDivElement element;
  late final web.HTMLSpanElement _dimLabel;
  late final web.HTMLDivElement _gridContainer;

  int _rows;
  int _cols;
  final Map<String, String> _gridValues = {};

  bool get isVisible => !element.classList.contains('hidden');

  void setVisible(bool visible) {
    if (visible) {
      element.classList.remove('hidden');
      _renderGrid();
    } else {
      element.classList.add('hidden');
    }
    onVisibilityChanged?.call(visible);
  }

  void toggle() => setVisible(!isVisible);

  void _buildDom() {
    element = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-matrix-panel hidden';

    final toolbar = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-matrix-toolbar';

    final controlsLeft = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-matrix-controls';
    _dimLabel = web.document.createElement('span') as web.HTMLSpanElement
      ..className = 'calc-matrix-dim-label';

    final addRowBtn =
        web.document.createElement('button') as web.HTMLButtonElement
          ..type = 'button'
          ..className = 'calc-chip-btn'
          ..textContent = '+ Row';
    final remRowBtn =
        web.document.createElement('button') as web.HTMLButtonElement
          ..type = 'button'
          ..className = 'calc-chip-btn'
          ..textContent = '− Row';
    final addColBtn =
        web.document.createElement('button') as web.HTMLButtonElement
          ..type = 'button'
          ..className = 'calc-chip-btn'
          ..textContent = '+ Col';
    final remColBtn =
        web.document.createElement('button') as web.HTMLButtonElement
          ..type = 'button'
          ..className = 'calc-chip-btn'
          ..textContent = '− Col';
    final idPresetBtn =
        web.document.createElement('button') as web.HTMLButtonElement
          ..type = 'button'
          ..className = 'calc-chip-btn'
          ..textContent = 'Identity';
    final zeroPresetBtn =
        web.document.createElement('button') as web.HTMLButtonElement
          ..type = 'button'
          ..className = 'calc-chip-btn'
          ..textContent = 'Zeros';

    controlsLeft
      ..append(_dimLabel)
      ..append(addRowBtn)
      ..append(remRowBtn)
      ..append(addColBtn)
      ..append(remColBtn)
      ..append(idPresetBtn)
      ..append(zeroPresetBtn);

    final actionsRight = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-matrix-actions';
    final insertVecBtn =
        web.document.createElement('button') as web.HTMLButtonElement
          ..type = 'button'
          ..className = 'calc-btn-secondary calc-btn-sm'
          ..textContent = 'Insert Vector [...]';
    final insertMatBtn =
        web.document.createElement('button') as web.HTMLButtonElement
          ..type = 'button'
          ..className = 'calc-btn-primary calc-btn-sm'
          ..textContent = 'Insert Matrix [[...]]';
    final closeBtn =
        web.document.createElement('button') as web.HTMLButtonElement
          ..type = 'button'
          ..className = 'calc-icon-btn'
          ..textContent = '✕'
          ..title = 'Close Matrix Builder';

    actionsRight
      ..append(insertVecBtn)
      ..append(insertMatBtn)
      ..append(closeBtn);

    toolbar
      ..append(controlsLeft)
      ..append(actionsRight);

    _gridContainer = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-matrix-grid';

    element
      ..append(toolbar)
      ..append(_gridContainer);

    addRowBtn.addEventListener(
      'click',
      ((web.Event _) {
        _rows = math.min(8, _rows + 1);
        _renderGrid();
      }).toJS,
    );
    remRowBtn.addEventListener(
      'click',
      ((web.Event _) {
        _rows = math.max(1, _rows - 1);
        _renderGrid();
      }).toJS,
    );
    addColBtn.addEventListener(
      'click',
      ((web.Event _) {
        _cols = math.min(8, _cols + 1);
        _renderGrid();
      }).toJS,
    );
    remColBtn.addEventListener(
      'click',
      ((web.Event _) {
        _cols = math.max(1, _cols - 1);
        _renderGrid();
      }).toJS,
    );
    idPresetBtn.addEventListener(
      'click',
      ((web.Event _) {
        for (var r = 0; r < _rows; r++) {
          for (var c = 0; c < _cols; c++) {
            _gridValues['$r,$c'] = r == c ? '1' : '0';
          }
        }
        _renderGrid();
      }).toJS,
    );
    zeroPresetBtn.addEventListener(
      'click',
      ((web.Event _) {
        for (var r = 0; r < _rows; r++) {
          for (var c = 0; c < _cols; c++) {
            _gridValues['$r,$c'] = '0';
          }
        }
        _renderGrid();
      }).toJS,
    );

    insertMatBtn.addEventListener(
      'click',
      ((web.Event _) {
        final rowStrings = <String>[];
        for (var r = 0; r < _rows; r++) {
          final entries = <String>[];
          for (var c = 0; c < _cols; c++) {
            final v = _gridValues['$r,$c']?.trim() ?? '0';
            entries.add(v.isEmpty ? '0' : v);
          }
          rowStrings.add('[${entries.join(', ')}]');
        }
        setVisible(false);
        onInsert('[${rowStrings.join(', ')}]');
      }).toJS,
    );

    insertVecBtn.addEventListener(
      'click',
      ((web.Event _) {
        final entries = <String>[];
        for (var c = 0; c < _cols; c++) {
          final v = _gridValues['0,$c']?.trim() ?? '0';
          entries.add(v.isEmpty ? '0' : v);
        }
        setVisible(false);
        onInsert('[${entries.join(', ')}]');
      }).toJS,
    );

    closeBtn.addEventListener(
      'click',
      ((web.Event _) => setVisible(false)).toJS,
    );

    _renderGrid();
  }

  void _renderGrid() {
    _dimLabel.textContent = '$_rows × $_cols';
    _gridContainer.innerHTML = ''.toJS;
    _gridContainer.style.gridTemplateColumns =
        'repeat($_cols, minmax(56px, 1fr))';

    for (var r = 0; r < _rows; r++) {
      for (var c = 0; c < _cols; c++) {
        final key = '$r,$c';
        final val = _gridValues[key] ?? (r == c ? '1' : '0');
        _gridValues[key] = val;
        final input =
            web.document.createElement('input') as web.HTMLInputElement
              ..type = 'text'
              ..name = 'mat-$r-$c'
              ..className = 'calc-matrix-cell-input'
              ..value = val
              ..placeholder = 'a_${r + 1}${c + 1}';
        input.setAttribute(
          'aria-label',
          'Matrix entry row ${r + 1} column ${c + 1}',
        );
        input.addEventListener(
          'input',
          ((web.Event _) {
            _gridValues[key] = input.value.trim().isEmpty
                ? '0'
                : input.value.trim();
          }).toJS,
        );
        input.addEventListener(
          'focus',
          ((web.Event _) {
            input.select();
          }).toJS,
        );
        _gridContainer.append(input);
      }
    }
  }
}
