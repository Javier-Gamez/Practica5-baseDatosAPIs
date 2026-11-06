import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'models.dart';

enum ApiErrorKind { network, timeout, http, malformed, rateLimit, unauthorized, forbidden }

class ApiException implements Exception {
  final ApiErrorKind kind;
  final String message;
  final int? status;
  const ApiException(this.kind, this.message, [this.status]);
  @override
  String toString() => message;
}

/// Ejecuta la petición traduciendo cualquier fallo a ApiException (nunca cierra la app).
Future<dynamic> _send(Future<http.Response> Function() call) async {
  http.Response r;
  try {
    r = await call().timeout(Config.requestTimeout);
  } on TimeoutException {
    throw const ApiException(ApiErrorKind.timeout, 'Tiempo de espera agotado');
  } on SocketException {
    throw const ApiException(ApiErrorKind.network, 'Sin conexión a Internet');
  } on http.ClientException {
    throw const ApiException(ApiErrorKind.network, 'Error de red');
  } on HandshakeException {
    throw const ApiException(ApiErrorKind.network, 'Error de seguridad (TLS)');
  }
  if (r.statusCode == 429) {
    throw const ApiException(ApiErrorKind.rateLimit, 'Límite de consultas alcanzado, intenta en unos segundos', 429);
  }
  if (r.statusCode == 401) throw ApiException(ApiErrorKind.unauthorized, _msg(r, 'No autorizado'), 401);
  if (r.statusCode == 403) throw ApiException(ApiErrorKind.forbidden, _msg(r, 'Acceso denegado'), 403);
  if (r.statusCode >= 400) {
    throw ApiException(ApiErrorKind.http, _msg(r, 'Error HTTP ${r.statusCode}'), r.statusCode);
  }
  if (r.body.isEmpty) return null;
  try {
    return jsonDecode(utf8.decode(r.bodyBytes));
  } on FormatException {
    throw const ApiException(ApiErrorKind.malformed, 'Respuesta con formato inválido');
  }
}

String _msg(http.Response r, String fallback) {
  try {
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    if (j is Map && j['message'] is String) return j['message'] as String;
  } catch (_) {}
  return fallback;
}

/// Cliente de la API pública TVMaze.
class TvmazeApi {
  TvmazeApi({http.Client? client}) : _c = client ?? http.Client();
  final http.Client _c;

  Future<List<Show>> search(String q) async {
    final data = await _send(() => _c.get(Uri.parse('${Config.tvmazeUrl}/search/shows')
        .replace(queryParameters: {'q': q})));
    if (data is! List) throw const ApiException(ApiErrorKind.malformed, 'Se esperaba una lista');
    final out = <Show>[];
    for (final e in data) {
      try {
        out.add(Show.fromTvmaze(e is Map ? e['show'] : null));
      } on FormatException {
        // Se omite el elemento malformado, el resto sigue siendo útil.
      }
    }
    if (data.isNotEmpty && out.isEmpty) {
      throw const ApiException(ApiErrorKind.malformed, 'Todos los resultados son inválidos');
    }
    return out;
  }

  Future<Show> detail(int id) async {
    final data = await _send(() => _c.get(Uri.parse('${Config.tvmazeUrl}/shows/$id')));
    try {
      return Show.fromTvmaze(data);
    } on FormatException catch (e) {
      throw ApiException(ApiErrorKind.malformed, e.message);
    }
  }

  /// Series populares (página de índice), usadas como candidatas de recomendación.
  Future<List<Show>> index({int page = 0}) async {
    final data = await _send(() => _c.get(Uri.parse('${Config.tvmazeUrl}/shows?page=$page')));
    if (data is! List) throw const ApiException(ApiErrorKind.malformed, 'Se esperaba una lista');
    final out = <Show>[];
    for (final e in data) {
      try {
        out.add(Show.fromTvmaze(e));
      } on FormatException {/* omitir */}
    }
    return out;
  }
}

/// Cliente de la API REST propia (Flask).
class BackendApi {
  BackendApi({http.Client? client}) : _c = client ?? http.Client();
  final http.Client _c;
  String? token;

  Uri _u(String path) => Uri.parse('${Config.apiUrl}$path');
  Map<String, String> get _h => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> _get(String p) => _send(() => _c.get(_u(p), headers: _h));
  Future<dynamic> _post(String p, Object body) =>
      _send(() => _c.post(_u(p), headers: _h, body: jsonEncode(body)));
  Future<dynamic> _put(String p, Object body) =>
      _send(() => _c.put(_u(p), headers: _h, body: jsonEncode(body)));
  Future<dynamic> _delete(String p) => _send(() => _c.delete(_u(p), headers: _h));

  Session _session(dynamic j) {
    if (j is! Map || j['token'] is! String || j['user_id'] is! int || j['username'] is! String) {
      throw const ApiException(ApiErrorKind.malformed, 'Respuesta de sesión inválida');
    }
    return Session(j['token'] as String, j['user_id'] as int, j['username'] as String,
        (j['role'] as String?) ?? 'user');
  }

  Future<Session> login(String u, String p) async =>
      _session(await _post('/login', {'username': u, 'password': p}));

  Future<void> register(String u, String p) async {
    await _post('/register', {'username': u, 'password': p});
  }

  Future<Session> google(String idToken) async =>
      _session(await _post('/auth/google', {'id_token': idToken}));

  Future<Session> me() async {
    final j = await _get('/me');
    return Session(token!, j['user_id'] as int, j['username'] as String, j['role'] as String);
  }

  // --- Notas (CRUD de la Práctica 2) ---
  Future<List<Note>> notes() async {
    final j = await _get('/notes');
    if (j is! List) throw const ApiException(ApiErrorKind.malformed, 'Se esperaba una lista');
    return j.map((e) => Note.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Note> createNote(String title, String content) async =>
      Note.fromJson(await _post('/notes', {'title': title, 'content': content}));
  Future<Note> updateNote(int id, String title, String content) async =>
      Note.fromJson(await _put('/notes/$id', {'title': title, 'content': content}));
  Future<void> deleteNote(int id) async => _delete('/notes/$id');

  // --- Historial y favoritos ---
  Future<List<HistoryEntry>> history() async {
    final j = await _get('/history') as List;
    return j
        .map((e) => HistoryEntry(e['client_id'] as String, e['query'] as String,
            DateTime.parse('${e['searched_at']}Z')))
        .toList();
  }

  Future<void> clearHistory() async => _delete('/history');

  Future<List<Show>> favorites() async {
    final j = await _get('/favorites') as List;
    return j.map((e) => Show.fromBackend(e as Map<String, dynamic>)).toList();
  }

  /// Envía la cola offline. Devuelve los op_id resueltos (aplicados u omitidos por duplicados).
  Future<Set<String>> sync(List<PendingOp> ops) async {
    final j = await _post('/sync', {
      'ops': ops.map((o) => {'op_id': o.opId, 'type': o.type, 'payload': o.payload}).toList()
    });
    if (j is! Map) throw const ApiException(ApiErrorKind.malformed, 'Respuesta de sync inválida');
    return {...(j['applied'] as List).cast<String>(), ...(j['skipped'] as List).cast<String>()};
  }

  // --- Administrador ---
  Future<List<AppUser>> adminUsers() async {
    final j = await _get('/admin/users') as List;
    return j.map((e) => AppUser(e['id'] as int, e['username'] as String, e['role'] as String)).toList();
  }

  Future<List<String>> adminHistory(int uid) async {
    final j = await _get('/admin/users/$uid/history') as List;
    return j.map((e) => e['query'] as String).toList();
  }

  Future<List<Show>> adminFavorites(int uid) async {
    final j = await _get('/admin/users/$uid/favorites') as List;
    return j.map((e) => Show.fromBackend(e as Map<String, dynamic>)).toList();
  }
}
