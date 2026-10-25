import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Registers global keyboard shortcuts for the Calculator PWA (`Ctrl/Cmd+K`
/// Command Palette, `Ctrl/Cmd+M` Mode Toggle, `Ctrl/Cmd+Z` / `Ctrl/Cmd+Shift+Z`
/// Undo/Redo, `Ctrl/Cmd+/` Help Drawer, `Ctrl/Cmd+L` Clear View, `F1`–`F6`
/// RPN Soft Keys).
abstract final class GlobalShortcuts {
  static void register({
    required void Function() onOpenPalette,
    required void Function() onToggleMode,
    required void Function() onUndo,
    required void Function() onRedo,
    required void Function() onOpenHelp,
    required void Function() onClearView,
    required bool Function(String fKey) onFunctionKey,
  }) {
    web.window.addEventListener(
      'keydown',
      ((web.KeyboardEvent e) {
        final mod = e.ctrlKey || e.metaKey;
        final key = e.key.toLowerCase();
        if (mod && key == 'k') {
          e.preventDefault();
          onOpenPalette();
          return;
        }
        if (mod && key == 'm') {
          e.preventDefault();
          onToggleMode();
          return;
        }
        if (mod && key == 'z') {
          if (_isNonEmptyTextInput(web.document.activeElement)) return;
          e.preventDefault();
          if (e.shiftKey) {
            onRedo();
          } else {
            onUndo();
          }
          return;
        }
        if (e.ctrlKey && !e.metaKey && !e.shiftKey && key == 'y') {
          if (_isNonEmptyTextInput(web.document.activeElement)) return;
          e.preventDefault();
          onRedo();
          return;
        }
        if (mod && e.key == '/') {
          e.preventDefault();
          onOpenHelp();
          return;
        }
        if (mod && key == 'l') {
          e.preventDefault();
          onClearView();
          return;
        }
        if (!mod &&
            !e.altKey &&
            const {'F1', 'F2', 'F3', 'F4', 'F5', 'F6'}.contains(e.key)) {
          if (onFunctionKey(e.key)) {
            e.preventDefault();
          }
        }
      }).toJS,
    );
  }

  static bool _isNonEmptyTextInput(web.Element? el) {
    if (el == null) return false;
    if (el.isA<web.HTMLTextAreaElement>()) {
      return (el as web.HTMLTextAreaElement).value.isNotEmpty;
    }
    if (el.isA<web.HTMLInputElement>()) {
      return (el as web.HTMLInputElement).value.isNotEmpty;
    }
    return false;
  }
}
