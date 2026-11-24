import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Visual grid modal for constructing a symbolic matrix literal `[[...]]`.
final class MatrixEditorModal {
  new({required this.onInsert}) {
    _buildDom();
  }

  final void Function(String matrixLiteral) onInsert;

  late final web.HTMLDivElement backdrop;
  late final web.HTMLDivElement _gridContainer;
  int _rows = 2;
  int _cols = 2;
  final List<List<web.HTMLInputElement>> _cells = [];

  void open() {
    _rebuildGrid();
    backdrop.style.display = 'flex';
  }

  void close() {
    backdrop.style.display = 'none';
  }

  void _buildDom() {
    backdrop = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-modal-backdrop'
      ..style.display = 'none';

    final modal = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-modal nb-matrix-modal';

    final header = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-drawer-header';
    final title = (web.document.createElement('h3') as web.HTMLHeadingElement)
      ..textContent = 'Insert Matrix';
    final closeBtn =
        (web.document.createElement('button') as web.HTMLButtonElement)
          ..type = 'button'
          ..className = 'nb-bar-text-btn'
          ..textContent = 'Cancel';
    closeBtn.onclick = ((web.MouseEvent _) => close()).toJS;
    header
      ..append(title)
      ..append(closeBtn);

    final controls = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-matrix-dims';

    final rowsInput =
        (web.document.createElement('input') as web.HTMLInputElement)
          ..type = 'number'
          ..min = '1'
          ..max = '6'
          ..value = '$_rows';
    final colsInput =
        (web.document.createElement('input') as web.HTMLInputElement)
          ..type = 'number'
          ..min = '1'
          ..max = '6'
          ..value = '$_cols';

    void onDimChange(web.Event _) {
      _rows = (int.tryParse(rowsInput.value) ?? 2).clamp(1, 6);
      _cols = (int.tryParse(colsInput.value) ?? 2).clamp(1, 6);
      _rebuildGrid();
    }

    rowsInput.oninput = onDimChange.toJS;
    colsInput.oninput = onDimChange.toJS;

    controls
      ..append(
        (web.document.createElement('span') as web.HTMLSpanElement)
          ..textContent = 'Rows:',
      )
      ..append(rowsInput)
      ..append(
        (web.document.createElement('span') as web.HTMLSpanElement)
          ..textContent = 'Cols:',
      )
      ..append(colsInput);

    _gridContainer = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-matrix-grid';

    final insertBtn =
        (web.document.createElement('button') as web.HTMLButtonElement)
          ..type = 'button'
          ..className = 'nb-primary-btn'
          ..textContent = 'Insert Matrix';
    insertBtn.onclick = ((web.MouseEvent _) {
      final rowsStr = [
        for (final row in _cells)
          '[${[for (final c in row)
            if (c.value.trim().isEmpty) '0' else c.value.trim()].join(', ')}]',
      ].join(', ');
      close();
      onInsert('[$rowsStr]');
    }).toJS;

    modal
      ..append(header)
      ..append(controls)
      ..append(_gridContainer)
      ..append(insertBtn);
    backdrop.append(modal);

    backdrop.onclick = ((web.MouseEvent e) {
      if (e.target == backdrop) close();
    }).toJS;
  }

  void _rebuildGrid() {
    _gridContainer.innerHTML = ''.toJS;
    _gridContainer.style.gridTemplateColumns =
        'repeat($_cols, minmax(52px, 1fr))';
    _cells.clear();
    for (var r = 0; r < _rows; r++) {
      final rowInputs = <web.HTMLInputElement>[];
      for (var c = 0; c < _cols; c++) {
        final inp =
            (web.document.createElement('input') as web.HTMLInputElement)
              ..type = 'text'
              ..className = 'nb-matrix-cell'
              ..value = r == c ? '1' : '0';
        rowInputs.add(inp);
        _gridContainer.append(inp);
      }
      _cells.add(rowInputs);
    }
  }
}
