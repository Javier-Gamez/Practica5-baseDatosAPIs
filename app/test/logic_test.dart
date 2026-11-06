import 'package:flutter_test/flutter_test.dart';
import 'package:practica5_app/core/models.dart';
import 'package:practica5_app/core/recommender.dart';

Show s(int id, List<String> g, [double? r]) => Show(id: id, title: 'S$id', genres: g, rating: r);

void main() {
  group('Show.fromTvmaze', () {
    test('parsea JSON valido', () {
      final x = Show.fromTvmaze({'id': 1, 'name': 'A', 'genres': ['Drama'], 'rating': {'average': 8.1}, 'image': {'medium': 'u'}});
      expect(x.title, 'A');
      expect(x.rating, 8.1);
      expect(x.genres, ['Drama']);
    });
    test('rechaza datos malformados', () {
      expect(() => Show.fromTvmaze({'id': 'x'}), throwsFormatException);
      expect(() => Show.fromTvmaze(null), throwsFormatException);
    });
    test('tolera campos nulos', () {
      final x = Show.fromTvmaze({'id': 2, 'name': 'B', 'genres': null, 'rating': {'average': null}, 'image': null});
      expect(x.genres, isEmpty);
      expect(x.rating, isNull);
    });
  });

  group('recommend', () {
    final candidates = [s(1, ['Drama'], 8), s(2, ['Comedy'], 9), s(3, ['Drama', 'Crime'], 7), s(4, ['Crime'], 6)];
    test('sin historial ni favoritos devuelve las mejor valoradas', () {
      final r = recommend(favorites: [], historyShows: [], candidates: candidates);
      expect(r.items.first.show.id, 2);
      expect(r.criteria, contains('Sin historial'));
    });
    test('prioriza generos de favoritos y excluye favoritos', () {
      final r = recommend(favorites: [s(1, ['Drama'])], historyShows: [], candidates: candidates);
      expect(r.items.map((e) => e.show.id), isNot(contains(1)));
      expect(r.items.first.show.id, 3);
      expect(r.items.map((e) => e.show.id), isNot(contains(2)));
    });
    test('es reproducible (determinista)', () {
      final a = recommend(favorites: [s(9, ['Crime'])], historyShows: [s(8, ['Drama'])], candidates: candidates);
      final b = recommend(favorites: [s(9, ['Crime'])], historyShows: [s(8, ['Drama'])], candidates: candidates);
      expect(a.items.map((e) => e.show.id), b.items.map((e) => e.show.id));
    });
  });
}
