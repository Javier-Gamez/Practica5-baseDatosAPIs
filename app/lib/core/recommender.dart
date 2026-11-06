import 'models.dart';

/// Resultado del recomendador: lista + explicación del criterio.
class RecResult {
  final List<Recommendation> items;
  final String criteria;
  const RecResult(this.items, this.criteria);
}

/// Regla reproducible (sin IA) basada en coincidencia de géneros.
///
/// Peso de cada género = 3 * (nº de favoritos que lo tienen) + 1 * (nº de series
/// vistas en búsquedas del historial que lo tienen). Puntaje de un candidato =
/// suma de pesos de sus géneros + rating/10 (desempate). Se excluyen los favoritos.
/// Sin datos del usuario se devuelven las series mejor valoradas.
RecResult recommend({
  required List<Show> favorites,
  required List<Show> historyShows,
  required List<Show> candidates,
  int limit = 10,
}) {
  final favIds = favorites.map((s) => s.id).toSet();
  final pool = <int, Show>{for (final s in candidates) s.id: s}..removeWhere((k, _) => favIds.contains(k));

  if (favorites.isEmpty && historyShows.isEmpty) {
    final top = pool.values.toList()..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    return RecResult(
      top.take(limit).map((s) => Recommendation(s, (s.rating ?? 0) / 10, 'Mejor valorada (aún no tienes historial ni favoritos)')).toList(),
      'Sin historial ni favoritos: se muestran las series mejor valoradas. '
      'Busca series o márcalas como favoritas para personalizar.',
    );
  }

  final weights = <String, double>{};
  for (final s in favorites) {
    for (final g in s.genres) {
      weights[g] = (weights[g] ?? 0) + 3;
    }
  }
  for (final s in historyShows) {
    for (final g in s.genres) {
      weights[g] = (weights[g] ?? 0) + 1;
    }
  }

  final scored = <Recommendation>[];
  for (final s in pool.values) {
    final matched = s.genres.where(weights.containsKey).toList();
    if (matched.isEmpty) continue;
    final score = matched.fold<double>(0, (a, g) => a + weights[g]!) + (s.rating ?? 0) / 10;
    scored.add(Recommendation(s, score, 'Coincide en géneros: ${matched.join(', ')}'));
  }
  scored.sort((a, b) {
    final c = b.score.compareTo(a.score);
    return c != 0 ? c : a.show.id.compareTo(b.show.id); // determinista
  });

  final top = (weights.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
      .take(3).map((e) => e.key).join(', ');
  return RecResult(
    scored.take(limit).toList(),
    'Basado en tus ${favorites.length} favoritos y ${historyShows.length} series del historial. '
    'Géneros con más peso: $top. Puntaje = peso de géneros coincidentes + rating/10.',
  );
}
