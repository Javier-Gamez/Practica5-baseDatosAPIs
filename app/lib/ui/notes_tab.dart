import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import 'widgets.dart';

/// CRUD de notas de la Práctica 2 (GET/POST/PUT/DELETE contra la API REST).
/// Requiere conexión; el estado de espera y error se muestran en pantalla.
class NotesTab extends StatefulWidget {
  const NotesTab({super.key});
  @override
  State<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<NotesTab> {
  late Future<List<Note>> _f = context.read<AppState>().backend.notes();
  void _reload() => setState(() {
        _f = context.read<AppState>().backend.notes();
      });

  Future<void> _edit([Note? n]) async {
    final title = TextEditingController(text: n?.title);
    final content = TextEditingController(text: n?.content);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(n == null ? 'Nueva nota' : 'Editar nota'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Título')),
          TextField(controller: content, decoration: const InputDecoration(labelText: 'Contenido'), maxLines: 3),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (ok != true || title.text.trim().isEmpty || !mounted) return;
    final api = context.read<AppState>().backend;
    await _guard(() => n == null
        ? api.createNote(title.text.trim(), content.text)
        : api.updateNote(n.id, title.text.trim(), content.text));
  }

  Future<void> _guard(Future<void> Function() f) async {
    try {
      await f();
      _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().backend;
    return Scaffold(
      floatingActionButton: FloatingActionButton(onPressed: _edit, child: const Icon(Icons.add)),
      body: FutureBuilder<List<Note>>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return ErrorView(snap.error!, onRetry: _reload);
          if (snap.data!.isEmpty) return const EmptyView('Sin notas', icon: Icons.note_add);
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(children: [
              for (final n in snap.data!)
                ListTile(
                  title: Text(n.title),
                  subtitle: Text(n.content, maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () => _edit(n),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _guard(() => api.deleteNote(n.id)),
                  ),
                ),
            ]),
          );
        },
      ),
    );
  }
}
