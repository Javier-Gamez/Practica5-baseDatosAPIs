import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import 'widgets.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.session!;
    return ListView(children: [
      ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(s.username),
        subtitle: Text('Rol: ${s.role}'),
      ),
      ListTile(
        leading: const Icon(Icons.sync),
        title: const Text('Sincronizar ahora'),
        subtitle: Text(app.lastSync == null ? 'Nunca' : 'Última: ${fmt(app.lastSync!)}'),
        onTap: app.online ? app.syncNow : null,
      ),
      if (s.isAdmin)
        ListTile(
          leading: const Icon(Icons.admin_panel_settings),
          title: const Text('Panel de administrador'),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen())),
        )
      else
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: const Text('Probar acceso a panel admin'),
          subtitle: const Text('El backend responde 403 si no eres administrador'),
          onTap: () async {
            try {
              await app.backend.adminUsers();
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
              }
            }
          },
        ),
      const Divider(),
      ListTile(
        leading: const Icon(Icons.logout),
        title: const Text('Cerrar sesión'),
        onTap: () => app.logout(),
      ),
    ]);
  }
}

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late final Future<List<AppUser>> _f = context.read<AppState>().backend.adminUsers();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Usuarios')),
        body: FutureBuilder<List<AppUser>>(
          future: _f,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) return ErrorView(snap.error!);
            return ListView(children: [
              for (final u in snap.data!)
                ListTile(
                  leading: Icon(u.role == 'admin' ? Icons.shield : Icons.person_outline),
                  title: Text(u.username),
                  subtitle: Text('id ${u.id} · ${u.role}'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminUserScreen(u))),
                ),
            ]);
          },
        ),
      );
}

class AdminUserScreen extends StatelessWidget {
  const AdminUserScreen(this.user, {super.key});
  final AppUser user;

  Future<(List<String>, List<Show>)> _load(BackendApi api) async =>
      (await api.adminHistory(user.id), await api.adminFavorites(user.id));

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().backend;
    return Scaffold(
      appBar: AppBar(title: Text(user.username)),
      body: FutureBuilder<(List<String>, List<Show>)>(
        future: _load(api),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return ErrorView(snap.error!);
          final (hist, favs) = snap.data!;
          return ListView(children: [
            const ListTile(title: Text('Favoritos', style: TextStyle(fontWeight: FontWeight.bold))),
            if (favs.isEmpty) const ListTile(title: Text('—')),
            for (final f in favs) ListTile(leading: const Icon(Icons.favorite), title: Text(f.title)),
            const ListTile(title: Text('Historial', style: TextStyle(fontWeight: FontWeight.bold))),
            if (hist.isEmpty) const ListTile(title: Text('—')),
            for (final h in hist) ListTile(leading: const Icon(Icons.history), title: Text(h)),
          ]);
        },
      ),
    );
  }
}
