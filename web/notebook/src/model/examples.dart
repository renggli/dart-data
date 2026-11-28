import 'dart:convert';

/// Curated runnable example notebook definition loaded from `examples.json`.
final class NotebookExample {
  const new({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.markdown,
  });

  factory fromJson(Map<String, Object?> json) => NotebookExample(
    id: json['id'] as String? ?? '',
    category: json['category'] as String? ?? 'Notebook',
    title: json['title'] as String? ?? 'Untitled Example',
    description: json['description'] as String? ?? '',
    markdown: json['markdown'] as String? ?? '',
  );

  final String id;
  final String category;
  final String title;
  final String description;
  final String markdown;

  /// Decodes a JSON array string into a list of [NotebookExample] entries.
  static List<NotebookExample> parseJson(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return [
      for (final item in decoded)
        if (item is Map<String, Object?>)
          NotebookExample.fromJson(item)
        else if (item is Map)
          NotebookExample.fromJson(item.cast<String, Object?>()),
    ];
  }
}
