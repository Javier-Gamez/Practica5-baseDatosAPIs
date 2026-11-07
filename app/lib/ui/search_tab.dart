import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import 'widgets.dart';

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});
  @override
  State<SearchTab> createState() => SearchTabState();
}

class SearchTabState extends State<SearchTab> {
  final _ctrl = TextEditingController();
  Future<SearchOutcome>? _future;

  void run(String q) {
    if (q.trim().isEmpty) return;
    _ctrl.text = q;
    final f = context.read<AppState>().search(q);
    setState(() {
      _future = f;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: SearchBar(
          controller: _ctrl,
          hintText: 'Buscar series (TVMaze)…',
          leading: const Icon(Icons.search),
          onSubmitted: run,
          trailing: [IconButton(icon: const Icon(Icons.arrow_forward), onPressed: () => run(_ctrl.text))],
        ),
      ),
      Expanded(
        child: _future == null
            ? const EmptyView('Escribe el nombre de una serie para buscar', icon: Icons.search)
            : FutureBuilder<SearchOutcome>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) return ErrorView(snap.error!, onRetry: () => run(_ctrl.text));
                  final o = snap.data!;
                  if (o.shows.isEmpty) return EmptyView('Sin resultados para "${_ctrl.text}"');
                  return Column(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          o.fromCache
                              ? 'Resultados guardados (${fmt(o.cachedAt!)}) · ${o.warning ?? ''}'
                              : '${o.shows.length} resultados en ${o.elapsed.inMilliseconds} ms',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: o.shows.length,
                        itemBuilder: (_, i) => ShowTile(o.shows[i]),
                      ),
                    ),
                  ]);
                },
              ),
      ),
    ]);
  }
}
