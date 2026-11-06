import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:uuid/uuid.dart';

import 'api.dart';
import 'config.dart';
import 'local_db.dart';
import 'models.dart';
import 'recommender.dart';

enum SyncStatus { idle, syncing, ok, error }

/// Resultado de una búsqueda: datos + origen (red o caché local).
class SearchOutcome {
  final List<Show> shows;
  final bool fromCache;
  final DateTime? cachedAt;
  final Duration elapsed;
  final String? warning;
  const SearchOutcome(this.shows, this.fromCache, this.cachedAt, this.elapsed, {this.warning});
}

/// Estado global y lógica de negocio (repositorio + sincronización).
class AppState extends ChangeNotifier {
  AppState({required this.db, BackendApi? backend, TvmazeApi? tvmaze, FlutterSecureStorage? storage})
      : backend = backend ?? BackendApi(),
        tvmaze = tvmaze ?? TvmazeApi(),
        _storage = storage ?? const FlutterSecureStorage();

  final LocalDb db;
  final BackendApi backend;
  final TvmazeApi tvmaze;
  final FlutterSecureStorage _storage;
  static const _uuid = Uuid();
  static const _kSession = 'session_v1';

  Session? session;
  bool online = true;
  SyncStatus syncStatus = SyncStatus.idle;
  String? syncError;
  DateTime? lastSync;
  int pendingCount = 0;
  bool _syncing = false;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  Timer? _retryTimer;
  int _retryAttempt = 0;

  // ---------------------------------------------------------------- arranque
  Future<void> init() async {
    final res = await Connectivity().checkConnectivity();
    online = _isOnline(res);
    _connSub = Connectivity().onConnectivityChanged.listen((r) {
      final was = online;
      online = _isOnline(r);
      notifyListeners();
      if (!was && online) syncNow(); // reconexión → sincronizar
    });
    await _restoreSession();
    notifyListeners();
    if (session != null) syncNow();
  }

  bool _isOnline(List<ConnectivityResult> r) => r.any((e) => e != ConnectivityResult.none);

  @override
  void dispose() {
    _connSub?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }

  // ----------------------------------------------------------------- sesión
  /// Restaura la sesión guardada de forma segura. Sin red se confía en la sesión ya
  /// validada; con red se verifica que el token siga vigente (si expiró, se cierra).
  Future<void> _restoreSession() async {
    try {
      final raw = await _storage.read(key: _kSession);
      if (raw == null) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final s = Session(m['t'] as String, m['id'] as int, m['u'] as String, m['r'] as String);
      backend.token = s.token;
      session = s;
      if (online) {
        try {
          session = await backend.me();
          await _persistSession(session!);
        } on ApiException catch (e) {
          if (e.kind == ApiErrorKind.unauthorized) {
            await _clearSession();
          } // otros errores (red): se mantiene la sesión offline
        }
      }
    } catch (_) {
      await _clearSession();
    }
  }

  Future<void> _persistSession(Session s) => _storage.write(
      key: _kSession, value: jsonEncode({'t': s.token, 'id': s.userId, 'u': s.username, 'r': s.role}));

  Future<void> _clearSession() async {
    session = null;
    backend.token = null;
    await _storage.delete(key: _kSession);
  }

  Future<void> _setSession(Session s) async {
    session = s;
    backend.token = s.token;
    await _persistSession(s);
    notifyListeners();
    syncNow();
  }

  Future<void> login(String u, String p) async => _setSession(await backend.login(u.trim(), p));

  Future<void> register(String u, String p) async {
    await backend.register(u.trim(), p);
    await login(u, p);
  }

  bool _googleInit = false;

  Future<void> loginWithGoogle() async {
    final g = GoogleSignIn.instance;
    if (!_googleInit) {
      await g.initialize(
        serverClientId: Config.googleServerClientId.isEmpty ? null : Config.googleServerClientId,
        clientId: Config.googleIosClientId.isEmpty ? null : Config.googleIosClientId,
      );
      _googleInit = true;
    }
    try {
      final account = await g.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw const ApiException(ApiErrorKind.malformed, 'Google no devolvió idToken');
      // La identidad se valida en el backend (audiencia + emisor con Google).
      await _setSession(await backend.google(idToken));
    } on GoogleSignInException catch (e) {
      throw ApiException(ApiErrorKind.http, 'Google: ${e.description ?? e.code.name}');
    }
  }

  Future<void> logout() async {
    try {
      if (_googleInit) await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await _clearSession();
    syncStatus = SyncStatus.idle;
    pendingCount = 0;
    notifyListeners();
  }

  // ---------------------------------------------------------------- búsqueda
  Future<SearchOutcome> search(String q) async {
    final query = q.trim();
    final sw = Stopwatch()..start();
    final uid = session!.userId;
    try {
      final shows = await tvmaze.search(query);
      sw.stop();
      await db.saveSearch(query, Show.encodeList(shows));
      for (final s in shows) {
        await db.saveShow(s);
      }
      await _recordHistory(uid, query);
      return SearchOutcome(shows, false, null, sw.elapsed);
    } on ApiException catch (e) {
      sw.stop();
      final cached = await db.getSearch(query);
      if (cached != null && e.kind != ApiErrorKind.malformed) {
        await _recordHistory(uid, query);
        return SearchOutcome(Show.decodeList(cached.json), true, cached.at, sw.elapsed, warning: e.message);
      }
      rethrow;
    }
  }

  Future<void> _recordHistory(int uid, String query) async {
    final id = _uuid.v4();
    await db.addHistory(uid, HistoryEntry(id, query, DateTime.now()));
    await db.enqueue(uid, PendingOp(_uuid.v4(), 'add_history', {'query': query, 'client_id': id}));
    _queueChanged();
  }

  Future<Show> showDetail(Show base) async {
    try {
      final s = await tvmaze.detail(base.id);
      await db.saveShow(s);
      return s;
    } on ApiException {
      return await db.getShow(base.id) ?? base;
    }
  }

  // ---------------------------------------------------------------- favoritos
  Future<bool> isFavorite(int showId) => db.isFavorite(session!.userId, showId);

  Future<void> toggleFavorite(Show s) async {
    final uid = session!.userId;
    if (await db.isFavorite(uid, s.id)) {
      await db.removeFavorite(uid, s.id);
      await db.enqueue(uid, PendingOp(_uuid.v4(), 'remove_favorite', {'show_id': s.id}));
    } else {
      await db.addFavorite(uid, s);
      await db.enqueue(uid, PendingOp(_uuid.v4(), 'add_favorite', s.toBackend()));
    }
    _queueChanged();
  }

  Future<List<Show>> favorites() => db.favorites(session!.userId);
  Future<List<HistoryEntry>> history() => db.history(session!.userId);

  Future<void> clearHistory() async {
    await db.clearHistory(session!.userId);
    if (online) {
      try {
        await backend.clearHistory();
      } on ApiException {/* se reconciliará en el próximo sync */}
    }
    notifyListeners();
  }

  void _queueChanged() {
    notifyListeners();
    syncNow();
  }

  // ----------------------------------------------------------- sincronización
  /// 1) Sube la cola pendiente (idempotente por op_id). 2) Descarga el estado del servidor.
  /// Conflictos: el servidor es la fuente de verdad, salvo operaciones locales aún pendientes
  /// (se conservan hasta confirmarse). Reintentos con retroceso exponencial (2,4,8 s…).
  Future<void> syncNow() async {
    if (session == null || _syncing) return;
    final uid = session!.userId;
    pendingCount = (await db.pendingOps(uid)).length;
    if (!online) {
      notifyListeners();
      return;
    }
    _syncing = true;
    syncStatus = SyncStatus.syncing;
    syncError = null;
    notifyListeners();
    try {
      final ops = await db.pendingOps(uid);
      if (ops.isNotEmpty) {
        final done = await backend.sync(ops);
        await db.removeOps(done);
        final failed = ops.where((o) => !done.contains(o.opId)).map((o) => o.opId);
        await db.bumpAttempts(failed);
        // Operaciones rechazadas muchas veces se descartan para no bloquear la cola.
        await db.removeOps(ops.where((o) => !done.contains(o.opId) && o.attempts + 1 >= 5).map((o) => o.opId));
      }
      final remaining = await db.pendingOps(uid);
      final server = await backend.favorites();
      await db.replaceFavorites(
        uid,
        server,
        remaining.where((o) => o.type == 'add_favorite').map((o) => o.payload['show_id'] as int).toSet(),
        remaining.where((o) => o.type == 'remove_favorite').map((o) => o.payload['show_id'] as int).toSet(),
      );
      for (final h in await backend.history()) {
        await db.addHistory(uid, h);
      }
      lastSync = DateTime.now();
      await db.setMeta('last_sync_$uid', lastSync!.toIso8601String());
      pendingCount = remaining.length;
      syncStatus = SyncStatus.ok;
      _retryAttempt = 0;
    } on ApiException catch (e) {
      syncStatus = SyncStatus.error;
      syncError = e.message;
      if (e.kind == ApiErrorKind.unauthorized) {
        await _clearSession();
      } else {
        _scheduleRetry();
      }
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  void _scheduleRetry() {
    if (_retryAttempt >= Config.maxRetries) return;
    _retryAttempt++;
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: 1 << _retryAttempt), syncNow);
  }

  Future<DateTime?> loadLastSync() async {
    final v = await db.getMeta('last_sync_${session!.userId}');
    lastSync ??= v == null ? null : DateTime.tryParse(v);
    return lastSync;
  }

  // ---------------------------------------------------------- recomendaciones
  Future<({RecResult result, bool fromCache, DateTime at})> recommendations({bool refresh = false}) async {
    final uid = session!.userId;
    if (!refresh || !online) {
      final prev = await db.getRecommendations(uid);
      if (prev != null && !refresh) return (result: _decodeRec(prev.json, prev.criteria), fromCache: true, at: prev.at);
    }
    final favs = await db.favorites(uid);
    final hist = await db.history(uid);
    final historyShows = <Show>[];
    for (final h in hist.take(20)) {
      final c = await db.getSearch(h.query);
      if (c != null) {
        final l = Show.decodeList(c.json);
        if (l.isNotEmpty) historyShows.add(l.first);
      }
    }
    final candidates = <Show>[...await db.allCachedShows()];
    if (online) {
      try {
        candidates.addAll(await tvmaze.index());
      } on ApiException {/* se usa lo local */}
    }
    final result = recommend(favorites: favs, historyShows: historyShows, candidates: candidates);
    await db.saveRecommendations(uid, _encodeRec(result), result.criteria);
    return (result: result, fromCache: false, at: DateTime.now());
  }

  String _encodeRec(RecResult r) => jsonEncode(r.items
      .map((e) => {'show': e.show.toJson(), 'score': e.score, 'reason': e.reason})
      .toList());

  RecResult _decodeRec(String json, String criteria) => RecResult(
      (jsonDecode(json) as List)
          .map((e) => Recommendation(Show.fromJson(e['show'] as Map<String, dynamic>),
              (e['score'] as num).toDouble(), e['reason'] as String))
          .toList(),
      criteria);
}
