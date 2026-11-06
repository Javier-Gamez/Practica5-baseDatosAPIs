import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// Base SQLite local. Todo dato personal lleva user_id (aislamiento por cuenta).
class LocalDb {
  LocalDb._(this._db);
  final Database _db;

  static Future<LocalDb> open({String? path}) async {
    final dbPath = path ?? p.join(await getDatabasesPath(), 'practica5.db');
    final db = await openDatabase(dbPath, version: 1, onCreate: (db, v) async {
      // Resultados de búsqueda guardados (para verlos sin conexión).
      await db.execute('''CREATE TABLE searches(
        query TEXT PRIMARY KEY, results TEXT NOT NULL, updated_at INTEGER NOT NULL)''');
      // Detalle de series consultadas (cache de lectura, compartido).
      await db.execute('''CREATE TABLE shows(
        id INTEGER PRIMARY KEY, data TEXT NOT NULL, updated_at INTEGER NOT NULL)''');
      await db.execute('''CREATE TABLE history(
        client_id TEXT NOT NULL, user_id INTEGER NOT NULL, query TEXT NOT NULL,
        at INTEGER NOT NULL, PRIMARY KEY(user_id, client_id))''');
      await db.execute('''CREATE TABLE favorites(
        user_id INTEGER NOT NULL, show_id INTEGER NOT NULL, data TEXT NOT NULL,
        updated_at INTEGER NOT NULL, PRIMARY KEY(user_id, show_id))''');
      // Cola de operaciones pendientes; op_id es la clave de idempotencia.
      await db.execute('''CREATE TABLE pending_ops(
        op_id TEXT PRIMARY KEY, user_id INTEGER NOT NULL, type TEXT NOT NULL,
        payload TEXT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL)''');
      await db.execute('''CREATE TABLE recommendations(
        user_id INTEGER PRIMARY KEY, data TEXT NOT NULL, criteria TEXT NOT NULL,
        created_at INTEGER NOT NULL)''');
      await db.execute('CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)');
    });
    return LocalDb._(db);
  }

  Future<void> close() => _db.close();

  int get _now => DateTime.now().millisecondsSinceEpoch;

  // ---------- búsquedas y series ----------
  Future<void> saveSearch(String q, String resultsJson) => _db.insert(
      'searches', {'query': q.toLowerCase(), 'results': resultsJson, 'updated_at': _now},
      conflictAlgorithm: ConflictAlgorithm.replace);

  Future<({String json, DateTime at})?> getSearch(String q) async {
    final r = await _db.query('searches', where: 'query = ?', whereArgs: [q.toLowerCase()]);
    if (r.isEmpty) return null;
    return (
      json: r.first['results'] as String,
      at: DateTime.fromMillisecondsSinceEpoch(r.first['updated_at'] as int)
    );
  }

  Future<void> saveShow(Show s) => _db.insert(
      'shows', {'id': s.id, 'data': Show.encodeList([s]), 'updated_at': _now},
      conflictAlgorithm: ConflictAlgorithm.replace);

  Future<Show?> getShow(int id) async {
    final r = await _db.query('shows', where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : Show.decodeList(r.first['data'] as String).first;
  }

  Future<List<Show>> allCachedShows() async {
    final r = await _db.query('shows');
    return r.map((e) => Show.decodeList(e['data'] as String).first).toList();
  }

  // ---------- historial ----------
  Future<void> addHistory(int uid, HistoryEntry h) => _db.insert(
      'history',
      {'client_id': h.clientId, 'user_id': uid, 'query': h.query, 'at': h.at.millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.ignore);

  Future<List<HistoryEntry>> history(int uid) async {
    final r = await _db.query('history', where: 'user_id = ?', whereArgs: [uid], orderBy: 'at DESC');
    return r
        .map((e) => HistoryEntry(e['client_id'] as String, e['query'] as String,
            DateTime.fromMillisecondsSinceEpoch(e['at'] as int)))
        .toList();
  }

  Future<void> clearHistory(int uid) => _db.delete('history', where: 'user_id = ?', whereArgs: [uid]);

  // ---------- favoritos ----------
  Future<void> addFavorite(int uid, Show s) => _db.insert(
      'favorites',
      {'user_id': uid, 'show_id': s.id, 'data': Show.encodeList([s]), 'updated_at': _now},
      conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> removeFavorite(int uid, int showId) =>
      _db.delete('favorites', where: 'user_id = ? AND show_id = ?', whereArgs: [uid, showId]);

  Future<List<Show>> favorites(int uid) async {
    final r = await _db.query('favorites',
        where: 'user_id = ?', whereArgs: [uid], orderBy: 'updated_at DESC');
    return r.map((e) => Show.decodeList(e['data'] as String).first).toList();
  }

  Future<bool> isFavorite(int uid, int showId) async =>
      (await _db.query('favorites', where: 'user_id = ? AND show_id = ?', whereArgs: [uid, showId]))
          .isNotEmpty;

  // ---------- cola de operaciones ----------
  Future<void> enqueue(int uid, PendingOp op) => _db.insert(
      'pending_ops',
      {
        'op_id': op.opId,
        'user_id': uid,
        'type': op.type,
        'payload': _enc(op.payload),
        'created_at': _now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore);

  Future<List<PendingOp>> pendingOps(int uid) async {
    final r = await _db.query('pending_ops',
        where: 'user_id = ?', whereArgs: [uid], orderBy: 'created_at ASC');
    return r
        .map((e) => PendingOp(e['op_id'] as String, e['type'] as String,
            _dec(e['payload'] as String), attempts: e['attempts'] as int))
        .toList();
  }

  Future<void> removeOps(Iterable<String> ids) async {
    final b = _db.batch();
    for (final id in ids) {
      b.delete('pending_ops', where: 'op_id = ?', whereArgs: [id]);
    }
    await b.commit(noResult: true);
  }

  Future<void> bumpAttempts(Iterable<String> ids) async {
    final b = _db.batch();
    for (final id in ids) {
      b.rawUpdate('UPDATE pending_ops SET attempts = attempts + 1 WHERE op_id = ?', [id]);
    }
    await b.commit(noResult: true);
  }

  /// Reemplaza el estado local por el del servidor, conservando lo pendiente de enviar.
  Future<void> replaceFavorites(int uid, List<Show> server, Set<int> pendingAdds, Set<int> pendingRemoves) async {
    await _db.transaction((t) async {
      final localKeep = await t.query('favorites', where: 'user_id = ?', whereArgs: [uid]);
      await t.delete('favorites', where: 'user_id = ?', whereArgs: [uid]);
      for (final s in server) {
        if (pendingRemoves.contains(s.id)) continue;
        await t.insert('favorites',
            {'user_id': uid, 'show_id': s.id, 'data': Show.encodeList([s]), 'updated_at': _now});
      }
      for (final row in localKeep) {
        if (pendingAdds.contains(row['show_id'])) {
          await t.insert('favorites', row, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
    });
  }

  // ---------- recomendaciones ----------
  Future<void> saveRecommendations(int uid, String json, String criteria) => _db.insert(
      'recommendations',
      {'user_id': uid, 'data': json, 'criteria': criteria, 'created_at': _now},
      conflictAlgorithm: ConflictAlgorithm.replace);

  Future<({String json, String criteria, DateTime at})?> getRecommendations(int uid) async {
    final r = await _db.query('recommendations', where: 'user_id = ?', whereArgs: [uid]);
    if (r.isEmpty) return null;
    return (
      json: r.first['data'] as String,
      criteria: r.first['criteria'] as String,
      at: DateTime.fromMillisecondsSinceEpoch(r.first['created_at'] as int)
    );
  }

  // ---------- meta ----------
  Future<void> setMeta(String k, String v) =>
      _db.insert('meta', {'key': k, 'value': v}, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<String?> getMeta(String k) async {
    final r = await _db.query('meta', where: 'key = ?', whereArgs: [k]);
    return r.isEmpty ? null : r.first['value'] as String;
  }

  static String _enc(Map<String, dynamic> m) => jsonEncode(m);
  static Map<String, dynamic> _dec(String s) => jsonDecode(s) as Map<String, dynamic>;
}
