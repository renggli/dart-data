import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../model/notebook.dart';

/// LocalStorage, URL-hash sharing, and `.md`/`.json` import-export helpers.
final class NotebookPersistence {
  const new _();

  static const String _storageKey = 'data_symbolic_notebook_v1';
  static const String _hashPrefix = '#nb=';

  static Map<String, Object?>? loadInitialSnapshot() {
    final hash = web.window.location.hash;
    if (hash.startsWith(_hashPrefix)) {
      try {
        final encoded = hash.substring(_hashPrefix.length);
        final jsonStr = Uri.decodeComponent(encoded);
        return (jsonDecode(jsonStr) as Map).cast<String, Object?>();
      } on Object {
        // Fall through to localStorage
      }
    }
    try {
      final raw = web.window.localStorage.getItem(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        return (jsonDecode(raw) as Map).cast<String, Object?>();
      }
    } on Object {
      // Ignore storage errors
    }
    return null;
  }

  static void saveSnapshot(NotebookDocument doc) {
    try {
      web.window.localStorage.setItem(_storageKey, jsonEncode(doc.toJson()));
    } on Object {
      // Ignore quota errors
    }
  }

  static String buildShareUrl(NotebookDocument doc) {
    final encoded = Uri.encodeComponent(jsonEncode(doc.toJson()));
    final base = web.window.location.href.split('#').first;
    return '$base$_hashPrefix$encoded';
  }

  static void downloadFile(String filename, String content, String mimeType) {
    final blob = web.Blob(
      [content.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final url = web.URL.createObjectURL(blob);
    final a = (web.document.createElement('a') as web.HTMLAnchorElement)
      ..href = url
      ..download = filename;
    a.click();
    web.URL.revokeObjectURL(url);
  }
}
