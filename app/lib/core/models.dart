import 'dart:convert';

/// Serie de TVMaze (API pública).
class Show {
  final int id;
  final String title;
  final String? imageUrl;
  final List<String> genres;
  final String? summary; // HTML sin limpiar
  final double? rating;
  final String? premiered;
  final String? language;

  const Show({
    required this.id,
    required this.title,
    this.imageUrl,
    this.genres = const [],
    this.summary,
    this.rating,
    this.premiered,
    this.language,
  });

  /// Parseo tolerante a datos malformados: lanza FormatException si falta lo esencial.
  factory Show.fromTvmaze(Object? raw) {
    if (raw is! Map<String, dynamic>) throw const FormatException('Elemento no es objeto');
    final id = raw['id'];
    final name = raw['name'];
    if (id is! int || name is! String) throw const FormatException('Faltan id/name');
    final img = raw['image'];
    final rating = raw['rating'];
    final genres = raw['genres'];
    return Show(
      id: id,
      title: name,
      imageUrl: img is Map ? (img['medium'] ?? img['original']) as String? : null,
      genres: genres is List ? genres.whereType<String>().toList() : const [],
      summary: raw['summary'] as String?,
      rating: rating is Map && rating['average'] is num ? (rating['average'] as num).toDouble() : null,
      premiered: raw['premiered'] as String?,
      language: raw['language'] as String?,
    );
  }

  factory Show.fromJson(Map<String, dynamic> j) => Show(
        id: j['id'] as int,
        title: j['title'] as String,
        imageUrl: j['imageUrl'] as String?,
        genres: (j['genres'] as List).cast<String>(),
        summary: j['summary'] as String?,
        rating: (j['rating'] as num?)?.toDouble(),
        premiered: j['premiered'] as String?,
        language: j['language'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'imageUrl': imageUrl,
        'genres': genres,
        'summary': summary,
        'rating': rating,
        'premiered': premiered,
        'language': language,
      };

  String get plainSummary =>
      (summary ?? '').replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('&amp;', '&').trim();

  /// Formato del backend para /favorites y /sync.
  Map<String, dynamic> toBackend() => {
        'show_id': id,
        'title': title,
        'image_url': imageUrl,
        'genres': genres.join(','),
        'summary': summary,
      };

  factory Show.fromBackend(Map<String, dynamic> j) => Show(
        id: j['show_id'] as int,
        title: j['title'] as String,
        imageUrl: j['image_url'] as String?,
        genres: ((j['genres'] as String?) ?? '').split(',').where((g) => g.isNotEmpty).toList(),
        summary: j['summary'] as String?,
      );

  static String encodeList(List<Show> l) => jsonEncode(l.map((s) => s.toJson()).toList());
  static List<Show> decodeList(String s) =>
      (jsonDecode(s) as List).map((e) => Show.fromJson(e as Map<String, dynamic>)).toList();
}

class Session {
  final String token;
  final int userId;
  final String username;
  final String role;
  const Session(this.token, this.userId, this.username, this.role);
  bool get isAdmin => role == 'admin';
}

class HistoryEntry {
  final String clientId;
  final String query;
  final DateTime at;
  final bool synced;
  const HistoryEntry(this.clientId, this.query, this.at, {this.synced = true});
}

class PendingOp {
  final String opId;
  final String type; // add_history | add_favorite | remove_favorite
  final Map<String, dynamic> payload;
  final int attempts;
  const PendingOp(this.opId, this.type, this.payload, {this.attempts = 0});
}

class Recommendation {
  final Show show;
  final double score;
  final String reason;
  const Recommendation(this.show, this.score, this.reason);
}

class Note {
  final int id;
  final String title;
  final String content;
  const Note(this.id, this.title, this.content);
  factory Note.fromJson(Map<String, dynamic> j) =>
      Note(j['id'] as int, j['title'] as String, (j['content'] as String?) ?? '');
}

class AppUser {
  final int id;
  final String username;
  final String role;
  const AppUser(this.id, this.username, this.role);
}
