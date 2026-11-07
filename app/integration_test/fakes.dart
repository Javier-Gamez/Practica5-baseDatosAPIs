import 'package:practica5_app/core/api.dart';
import 'package:practica5_app/core/models.dart';

/// Catálogo fijo para pruebas deterministas (sin depender de TVMaze).
const catalog = <Show>[
  Show(id: 1, title: 'Breaking Bad', genres: ['Drama', 'Crime', 'Thriller'], rating: 9.2, summary: '<p>Un profesor de química...</p>'),
  Show(id: 2, title: 'Better Call Saul', genres: ['Drama', 'Crime', 'Legal'], rating: 8.9, summary: '<p>El abogado Saul Goodman.</p>'),
  Show(id: 3, title: 'Ozark', genres: ['Drama', 'Crime', 'Thriller'], rating: 8.4, summary: '<p>Lavado de dinero.</p>'),
  Show(id: 4, title: 'Mindhunter', genres: ['Crime', 'Drama', 'Thriller'], rating: 8.6),
  Show(id: 5, title: 'True Detective', genres: ['Crime', 'Drama', 'Mystery'], rating: 8.3),
  Show(id: 6, title: 'The Office', genres: ['Comedy'], rating: 8.5),
  Show(id: 7, title: 'Breaking Point', genres: ['Drama'], rating: 6.0),
];

class FakeTvmaze extends TvmazeApi {
  bool offline = false;

  void _check() {
    if (offline) throw const ApiException(ApiErrorKind.network, 'Sin conexión a Internet');
  }

  @override
  Future<List<Show>> search(String q) async {
    _check();
    return catalog.where((s) => s.title.toLowerCase().contains(q.toLowerCase())).toList();
  }

  @override
  Future<Show> detail(int id) async {
    _check();
    return catalog.firstWhere((s) => s.id == id);
  }

  @override
  Future<List<Show>> index({int page = 0}) async {
    _check();
    return catalog;
  }
}

/// Backend en memoria con las mismas reglas que Flask: aislamiento por usuario,
/// sync idempotente por op_id y 403 para quien no es administrador.
class FakeBackend extends BackendApi {
  final _users = {'usuario1': ('user123', 2, 'user'), 'admin': ('admin123', 1, 'admin')};
  final _favs = <int, Map<int, Show>>{};
  final _hist = <int, List<HistoryEntry>>{};
  final _applied = <String>{};
  final _notes = <Note>[];
  int _noteId = 1;
  int syncCalls = 0;

  (String, int, String)? get _me {
    for (final u in _users.values) {
      if ('tok_${u.$2}' == token) return u;
    }
    return null;
  }

  String get _name => _users.entries.firstWhere((e) => 'tok_${e.value.$2}' == token).key;

  @override
  Future<Session> login(String u, String p) async {
    final r = _users[u];
    if (r == null || r.$1 != p) throw const ApiException(ApiErrorKind.unauthorized, 'Credenciales invalidas', 401);
    return Session('tok_${r.$2}', r.$2, u, r.$3);
  }

  @override
  Future<void> register(String u, String p) async {}

  @override
  Future<Session> me() async {
    final m = _me;
    if (m == null) throw const ApiException(ApiErrorKind.unauthorized, 'Token invalido', 401);
    return Session(token!, m.$2, _name, m.$3);
  }

  @override
  Future<List<Note>> notes() async => List.of(_notes);

  @override
  Future<Note> createNote(String title, String content) async {
    final n = Note(_noteId++, title, content);
    _notes.add(n);
    return n;
  }

  @override
  Future<void> deleteNote(int id) async => _notes.removeWhere((n) => n.id == id);

  @override
  Future<List<HistoryEntry>> history() async => List.of(_hist[_me!.$2] ?? []);

  @override
  Future<void> clearHistory() async => _hist[_me!.$2] = [];

  @override
  Future<List<Show>> favorites() async => (_favs[_me!.$2] ?? {}).values.toList();

  @override
  Future<Set<String>> sync(List<PendingOp> ops) async {
    syncCalls++;
    final uid = _me!.$2;
    final done = <String>{};
    for (final o in ops) {
      if (_applied.add('$uid:${o.opId}')) {
        final f = _favs.putIfAbsent(uid, () => {});
        if (o.type == 'add_favorite') {
          f[o.payload['show_id'] as int] = Show.fromBackend(o.payload);
        } else if (o.type == 'remove_favorite') {
          f.remove(o.payload['show_id']);
        } else if (o.type == 'add_history') {
          final l = _hist.putIfAbsent(uid, () => []);
          final cid = o.payload['client_id'] as String;
          if (!l.any((h) => h.clientId == cid)) {
            l.add(HistoryEntry(cid, o.payload['query'] as String, DateTime.now()));
          }
        }
      }
      done.add(o.opId);
    }
    return done;
  }

  void _admin() {
    if (_me?.$3 != 'admin') {
      throw const ApiException(ApiErrorKind.forbidden, 'Acceso denegado: se requiere rol administrador', 403);
    }
  }

  @override
  Future<List<AppUser>> adminUsers() async {
    _admin();
    return _users.entries.map((e) => AppUser(e.value.$2, e.key, e.value.$3)).toList();
  }

  @override
  Future<List<String>> adminHistory(int uid) async {
    _admin();
    return (_hist[uid] ?? []).map((h) => h.query).toList();
  }

  @override
  Future<List<Show>> adminFavorites(int uid) async {
    _admin();
    return (_favs[uid] ?? {}).values.toList();
  }
}
