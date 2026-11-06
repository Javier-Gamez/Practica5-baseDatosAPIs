import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/models.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen(this.show, {super.key});
  final Show show;
  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late Show show = widget.show;
  bool fav = false;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    app.isFavorite(show.id).then((v) {
      if (mounted) setState(() => fav = v);
    });
    app.showDetail(show).then((s) {
      if (mounted) setState(() => show = s);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(show.title), actions: [
        IconButton(
          tooltip: fav ? 'Quitar de favoritos' : 'Agregar a favoritos',
          icon: Icon(fav ? Icons.favorite : Icons.favorite_border),
          onPressed: () async {
            await app.toggleFavorite(show);
            final v = await app.isFavorite(show.id);
            if (mounted) setState(() => fav = v);
          },
        ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (show.imageUrl != null)
          Center(
            child: Image.network(show.imageUrl!,
                height: 260, errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 64)),
          ),
        const SizedBox(height: 12),
        Wrap(spacing: 6, children: show.genres.map((g) => Chip(label: Text(g))).toList()),
        const SizedBox(height: 8),
        if (show.rating != null) Text('Calificación: ★ ${show.rating}'),
        if (show.premiered != null) Text('Estreno: ${show.premiered}'),
        if (show.language != null) Text('Idioma: ${show.language}'),
        const SizedBox(height: 12),
        Text(show.plainSummary.isEmpty ? 'Sin sinopsis disponible.' : show.plainSummary),
      ]),
    );
  }
}
