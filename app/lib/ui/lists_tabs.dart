import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import 'widgets.dart';

class FavoritesTab extends StatefulWidget {
  const FavoritesTab({super.key});
  @override
  State<FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends State<FavoritesTab> {
  late Future<List<Show>> _f = context.read<AppState>().favorites();
  void _reload() => setState(() {
        _f = context.read<AppState>().favorites();
      });

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Show>>(
        future: _f,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (snap.data!.isEmpty) {
            return const EmptyView('Aún no tienes favoritos.\nAbre una serie y toca el corazón.', icon: Icons.favorite_border);
          }
          return ListView(children: [for (final s in snap.data!) ShowTile(s, onChanged: _reload)]);
        },
      );
}

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key, required this.onSelect});
  final void Function(String query) onSelect;
  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  late Future<List<HistoryEntry>> _f = context.read<AppState>().history();

  @override
  Widget build(BuildContext context) => FutureBuilder<List<HistoryEntry>>(
        future: _f,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final items = snap.data!;
          if (items.isEmpty) return const EmptyView('Sin historial de búsquedas', icon: Icons.history);
          return Column(children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: const Text('Borrar historial'),
                onPressed: () async {
                  await context.read<AppState>().clearHistory();
                  setState(() {
                    _f = context.read<AppState>().history();
                  });
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (_, i) => ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(items[i].query),
                  subtitle: Text(fmt(items[i].at)),
                  onTap: () => widget.onSelect(items[i].query),
                ),
              ),
            ),
          ]);
        },
      );
}

class RecommendationsTab extends StatefulWidget {
  const RecommendationsTab({super.key});
  @override
  State<RecommendationsTab> createState() => _RecommendationsTabState();
}

class _RecommendationsTabState extends State<RecommendationsTab> {
  Future<({dynamic result, bool fromCache, DateTime at})>? _f;

  @override
  void initState() {
    super.initState();
    _load(refresh: true);
  }

  void _load({required bool refresh}) {
    final app = context.read<AppState>();
    // Con red se recalculan; sin red se muestran las últimas guardadas.
    _f = app.recommendations(refresh: refresh && app.online);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return ErrorView(snap.error!, onRetry: () => setState(() => _load(refresh: true)));
          final d = snap.data!;
          final items = (d.result.items as List<Recommendation>);
          return Column(children: [
            Card(
              margin: const EdgeInsets.all(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${d.result.criteria}\n'
                      '${d.fromCache ? 'Guardadas el' : 'Calculadas el'} ${fmt(d.at)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Recalcular',
                    icon: const Icon(Icons.refresh),
                    onPressed: () => setState(() => _load(refresh: true)),
                  ),
                ]),
              ),
            ),
            if (items.isEmpty)
              const Expanded(child: EmptyView('No hay candidatas suficientes. Realiza búsquedas con conexión.'))
            else
              Expanded(
                child: ListView(children: [
                  for (final r in items) ShowTile(r.show, subtitle: r.reason),
                ]),
              ),
          ]);
        },
      );
}
