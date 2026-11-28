import 'dart:convert';

import 'package:web/web.dart' as web;

import '../model/notebook.dart';

/// Metadata and serialized snapshot of a locally stored notebook.
final class StoredNotebookEntry {
  new({
    required this.id,
    required this.name,
    required this.updatedAtMs,
    required this.snapshot,
  });

  factory fromJson(Map<String, Object?> json) => StoredNotebookEntry(
    id: json['id']! as String,
    name: json['name']! as String,
    updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
    snapshot: (json['snapshot']! as Map).cast<String, Object?>(),
  );

  final String id;
  String name;
  int updatedAtMs;
  Map<String, Object?> snapshot;

  int get cellCount => (snapshot['cells'] as List<Object?>?)?.length ?? 0;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'updatedAtMs': updatedAtMs,
    'snapshot': snapshot,
  };
}

/// Multi-document `localStorage` store and URL-hash sharing helpers.
final class NotebookPersistence {
  const new _();

  static const String _filesKey = 'data_notebook_files_v2';
  static const String _activeKey = 'data_notebook_active_v2';
  static const String _hashPrefix = '#nb=';

  static List<StoredNotebookEntry> listFiles() {
    try {
      final raw = web.window.localStorage.getItem(_filesKey);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<Object?>;
      return [
        for (final item in list)
          if (item is Map)
            StoredNotebookEntry.fromJson(item.cast<String, Object?>()),
      ];
    } on Object {
      return [];
    }
  }

  static void _writeFiles(List<StoredNotebookEntry> entries) {
    try {
      web.window.localStorage.setItem(
        _filesKey,
        jsonEncode([for (final e in entries) e.toJson()]),
      );
    } on Object {
      // Ignore storage quota errors
    }
  }

  static String? activeFileId() {
    try {
      return web.window.localStorage.getItem(_activeKey);
    } on Object {
      return null;
    }
  }

  static void setActiveFileId(String id) {
    try {
      web.window.localStorage.setItem(_activeKey, id);
    } on Object {
      // Ignore storage errors
    }
  }

  static StoredNotebookEntry createFile({
    required String name,
    Map<String, Object?>? snapshot,
  }) {
    final files = listFiles();
    final id = 'nb-${DateTime.now().microsecondsSinceEpoch}';
    final entry = StoredNotebookEntry(
      id: id,
      name: _dedupeName(name, files),
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      snapshot: snapshot ?? NotebookDocument().toJson(),
    );
    files.insert(0, entry);
    _writeFiles(files);
    setActiveFileId(id);
    return entry;
  }

  static void saveFile(String id, NotebookDocument doc) {
    final files = listFiles();
    final idx = files.indexWhere((f) => f.id == id);
    final snap = doc.toJson();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (idx >= 0) {
      files[idx]
        ..updatedAtMs = now
        ..snapshot = snap;
      _writeFiles(files);
    } else {
      final entry = StoredNotebookEntry(
        id: id,
        name: _dedupeName('Untitled Notebook', files),
        updatedAtMs: now,
        snapshot: snap,
      );
      files.insert(0, entry);
      _writeFiles(files);
    }
    setActiveFileId(id);
  }

  static StoredNotebookEntry? findFile(String id) {
    for (final f in listFiles()) {
      if (f.id == id) return f;
    }
    return null;
  }

  static void renameFile(String id, String newName) {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    final files = listFiles();
    final idx = files.indexWhere((f) => f.id == id);
    if (idx < 0) return;
    files[idx].name = trimmed;
    _writeFiles(files);
  }

  static StoredNotebookEntry deleteFile(String id) {
    final files = listFiles()..removeWhere((f) => f.id == id);
    if (files.isEmpty) {
      final fallback = StoredNotebookEntry(
        id: 'nb-${DateTime.now().microsecondsSinceEpoch}',
        name: 'Untitled Notebook',
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        snapshot: NotebookDocument().toJson(),
      );
      files.add(fallback);
      _writeFiles(files);
      setActiveFileId(fallback.id);
      return fallback;
    }
    _writeFiles(files);
    final active = activeFileId();
    final next = files.firstWhere(
      (f) => f.id == active,
      orElse: () => files.first,
    );
    setActiveFileId(next.id);
    return next;
  }

  /// Resolves a share URL (`#nb=...`) if present, or restores the active file
  /// from local storage. Returns `null` when starting completely fresh.
  static ({StoredNotebookEntry? entry, bool fromShareUrl}) loadInitial() {
    final hash = web.window.location.hash;
    if (hash.startsWith(_hashPrefix)) {
      try {
        final encoded = hash.substring(_hashPrefix.length);
        final jsonStr = Uri.decodeComponent(encoded);
        final snap = (jsonDecode(jsonStr) as Map).cast<String, Object?>();
        final entry = createFile(name: 'Shared Notebook', snapshot: snap);
        return (entry: entry, fromShareUrl: true);
      } on Object {
        // Fall through to local files
      }
    }
    final files = listFiles();
    if (files.isEmpty) {
      return (entry: null, fromShareUrl: false);
    }
    final activeId = activeFileId();
    final active = files.firstWhere(
      (f) => f.id == activeId,
      orElse: () => files.first,
    );
    setActiveFileId(active.id);
    return (entry: active, fromShareUrl: false);
  }

  static String buildShareUrl(NotebookDocument doc) {
    final encoded = Uri.encodeComponent(jsonEncode(doc.toJson()));
    final base = web.window.location.href.split('#').first;
    return '$base$_hashPrefix$encoded';
  }

  static String _dedupeName(String base, List<StoredNotebookEntry> existing) {
    final names = {for (final e in existing) e.name};
    if (!names.contains(base)) return base;
    var n = 2;
    while (names.contains('$base ($n)')) {
      n++;
    }
    return '$base ($n)';
  }
}
