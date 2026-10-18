import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

/// Visual $m \times n$ matrix & vector grid editor modal that serializes cleanly
/// to `[[a, b], [c, d]]` or `[a, b, c]` in the formula input bar.
final class MatrixEditorModal {
  static void open({
    required void Function(String literalText) onInsert,
    int initialRows = 2,
    int initialCols = 2,
  }) {
    var rows = initialRows.clamp(1, 8);
    var cols = initialCols.clamp(1, 8);
    final gridValues = <String, String>{};

    final backdrop = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-modal-backdrop';
    final dialog = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-modal-dialog calc-matrix-dialog';

    final header = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-modal-header';
    final title = web.document.createElement('h3') as web.HTMLHeadingElement
      ..textContent = 'Matrix / Vector Builder';
    final closeBtn =
        web.document.createElement('button') as web.HTMLButtonElement
          ..type = 'button'
          ..className = 'calc-icon-btn'
          ..textContent = '✕';
    header
      ..append(title)
      ..append(closeBtn);

    final controls = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-matrix-controls';
    final dimLabel = web.document.createElement('span') as web.HTMLSpanElement
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

    controls
      ..append(dimLabel)
      ..append(addRowBtn)
      ..append(remRowBtn)
      ..append(addColBtn)
      ..append(remColBtn)
      ..append(idPresetBtn)
      ..append(zeroPresetBtn);

    final gridContainer =
        web.document.createElement('div') as web.HTMLDivElement
          ..className = 'calc-matrix-grid';

    final footer = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-modal-footer';
    final insertVecBtn =
        web.document.createElement('button') as web.HTMLButtonElement
          ..type = 'button'
          ..className = 'calc-btn-secondary'
          ..textContent = 'Insert as Vector [...]';
    final insertMatBtn =
        web.document.createElement('button') as web.HTMLButtonElement
          ..type = 'button'
          ..className = 'calc-btn-primary'
          ..textContent = 'Insert Matrix [[...]]';
    footer
      ..append(insertVecBtn)
      ..append(insertMatBtn);

    dialog
      ..append(header)
      ..append(controls)
      ..append(gridContainer)
      ..append(footer);
    backdrop.append(dialog);

    void renderGrid() {
      dimLabel.textContent = '$rows × $cols';
      gridContainer.innerHTML = ''.toJS;
      gridContainer.style.gridTemplateColumns =
          'repeat($cols, minmax(64px, 1fr))';

      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          final key = '$r,$c';
          final val = gridValues[key] ?? (r == c ? '1' : '0');
          gridValues[key] = val;
          final input =
              web.document.createElement('input') as web.HTMLInputElement
                ..type = 'text'
                ..className = 'calc-matrix-cell-input'
                ..value = val
                ..placeholder = 'a_${r + 1}${c + 1}';
          input.addEventListener(
            'input',
            ((web.Event _) {
              gridValues[key] = input.value.trim().isEmpty
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
          gridContainer.append(input);
        }
      }
    }

    addRowBtn.addEventListener(
      'click',
      ((web.Event _) {
        rows = math.min(8, rows + 1);
        renderGrid();
      }).toJS,
    );
    remRowBtn.addEventListener(
      'click',
      ((web.Event _) {
        rows = math.max(1, rows - 1);
        renderGrid();
      }).toJS,
    );
    addColBtn.addEventListener(
      'click',
      ((web.Event _) {
        cols = math.min(8, cols + 1);
        renderGrid();
      }).toJS,
    );
    remColBtn.addEventListener(
      'click',
      ((web.Event _) {
        cols = math.max(1, cols - 1);
        renderGrid();
      }).toJS,
    );
    idPresetBtn.addEventListener(
      'click',
      ((web.Event _) {
        for (var r = 0; r < rows; r++) {
          for (var c = 0; c < cols; c++) {
            gridValues['$r,$c'] = r == c ? '1' : '0';
          }
        }
        renderGrid();
      }).toJS,
    );
    zeroPresetBtn.addEventListener(
      'click',
      ((web.Event _) {
        for (var r = 0; r < rows; r++) {
          for (var c = 0; c < cols; c++) {
            gridValues['$r,$c'] = '0';
          }
        }
        renderGrid();
      }).toJS,
    );

    insertMatBtn.addEventListener(
      'click',
      ((web.Event _) {
        final rowStrings = <String>[];
        for (var r = 0; r < rows; r++) {
          final entries = <String>[];
          for (var c = 0; c < cols; c++) {
            final v = gridValues['$r,$c']?.trim() ?? '0';
            entries.add(v.isEmpty ? '0' : v);
          }
          rowStrings.add('[${entries.join(', ')}]');
        }
        backdrop.remove();
        onInsert('[${rowStrings.join(', ')}]');
      }).toJS,
    );

    insertVecBtn.addEventListener(
      'click',
      ((web.Event _) {
        final entries = <String>[];
        for (var c = 0; c < cols; c++) {
          final v = gridValues['0,$c']?.trim() ?? '0';
          entries.add(v.isEmpty ? '0' : v);
        }
        backdrop.remove();
        onInsert('[${entries.join(', ')}]');
      }).toJS,
    );

    closeBtn.addEventListener(
      'click',
      ((web.Event _) => backdrop.remove()).toJS,
    );
    backdrop.addEventListener(
      'click',
      ((web.MouseEvent e) {
        if (e.target == backdrop) backdrop.remove();
      }).toJS,
    );

    renderGrid();
    web.document.body?.append(backdrop);
  }
}
