import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Global keyboard shortcut bindings for the notebook.
final class NotebookShortcuts {
  const new _();

  static void attach({
    required void Function() onOpenPalette,
    required void Function() onUndo,
    required void Function() onRedo,
    required void Function() onNewMathCell,
  }) {
    web.window.onkeydown = ((web.KeyboardEvent e) {
      final mod = e.ctrlKey || e.metaKey;
      if (mod && e.key.toLowerCase() == 'k') {
        e.preventDefault();
        onOpenPalette();
        return;
      }
      if (mod && e.key.toLowerCase() == 'z') {
        final active = web.document.activeElement;
        if (active.isA<web.HTMLTextAreaElement>() ||
            active.isA<web.HTMLInputElement>()) {
          return;
        }
        e.preventDefault();
        if (e.shiftKey) {
          onRedo();
        } else {
          onUndo();
        }
        return;
      }
      if (mod && e.key.toLowerCase() == 'm' && e.shiftKey) {
        e.preventDefault();
        onNewMathCell();
      }
    }).toJS;
  }
}
