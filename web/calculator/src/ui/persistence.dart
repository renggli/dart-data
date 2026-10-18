import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../model/environment.dart';

/// Manages `localStorage` persistence, JSON file import/export, and shareable
/// `#calc=` URL hash links for the Calculator PWA.
abstract final class CalcPersistence {
  static const String _storageKey = 'data_calculator_session_v1';
  static const String _modeKey = 'data_calculator_mode_v1';

  /// Loads the saved calculator mode (`scroll` or `rpn`).
  static CalcMode loadMode() {
    try {
      final raw = web.window.localStorage.getItem(_modeKey);
      if (raw == 'rpn') return CalcMode.rpn;
    } catch (_) {}
    return CalcMode.scroll;
  }

  /// Saves the active calculator mode.
  static void saveMode(CalcMode mode) {
    try {
      web.window.localStorage.setItem(_modeKey, mode.name);
    } catch (_) {}
  }

  /// Saves a full state snapshot to `localStorage`.
  static void saveState(Map<String, Object?> snapshot) {
    try {
      web.window.localStorage.setItem(_storageKey, jsonEncode(snapshot));
    } catch (_) {}
  }

  /// Loads the saved state snapshot from `localStorage`, if present.
  static Map<String, Object?>? loadState() {
    try {
      final raw = web.window.localStorage.getItem(_storageKey);
      if (raw == null || raw.isEmpty) return null;
      return (jsonDecode(raw) as Map).cast<String, Object?>();
    } catch (_) {
      return null;
    }
  }

  /// Clears the saved session from `localStorage`.
  static void clearSavedState() {
    try {
      web.window.localStorage.removeItem(_storageKey);
    } catch (_) {}
  }

  /// Encodes the current session snapshot into a shareable `#calc=<base64url>`
  /// URL and updates `window.history.replaceState`.
  static String buildShareUrl(Map<String, Object?> snapshot) {
    final jsonBytes = utf8.encode(jsonEncode(snapshot));
    final b64 = base64Url.encode(jsonBytes);
    final loc = web.window.location;
    final baseUrl = '${loc.origin}${loc.pathname}${loc.search}';
    final fullUrl = '$baseUrl#calc=$b64';
    try {
      web.window.history.replaceState(null, '', '#calc=$b64');
    } catch (_) {}
    return fullUrl;
  }

  /// Attempts to decode a `#calc=<base64url>` hash from `window.location.hash`.
  static Map<String, Object?>? tryLoadFromUrlHash() {
    try {
      final hash = web.window.location.hash;
      if (!hash.startsWith('#calc=')) return null;
      final b64 = hash.substring('#calc='.length).trim();
      if (b64.isEmpty) return null;
      final normalized = base64Url.normalize(b64);
      final bytes = base64Url.decode(normalized);
      final jsonStr = utf8.decode(bytes);
      return (jsonDecode(jsonStr) as Map).cast<String, Object?>();
    } catch (_) {
      return null;
    }
  }

  /// Triggers a browser file download of [snapshot] as `.calc.json`.
  static void downloadSessionJson(Map<String, Object?> snapshot) {
    final pretty = const JsonEncoder.withIndent('  ').convert(snapshot);
    final parts = <JSAny>[pretty.toJS].toJS;
    final blob = web.Blob(parts, web.BlobPropertyBag(type: 'application/json'));
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = 'session.calc.json';
    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);
  }

  /// Copies [text] to the system clipboard and invokes [onCopied] on success.
  static void copyToClipboard(String text, {void Function()? onCopied}) {
    try {
      web.window.navigator.clipboard.writeText(text);
      onCopied?.call();
    } catch (_) {}
  }

  /// Triggers a subtle 10 ms mobile haptic vibration if enabled and supported.
  static void triggerHaptic({required bool enabled}) {
    if (!enabled) return;
    try {
      web.window.navigator.vibrate(10.toJS);
    } catch (_) {}
  }
}
