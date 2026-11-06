import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import 'detail_screen.dart';

String fmt(DateTime d) {
  String t(int n) => n.toString().padLeft(2, '0');
  return '${d.day}/${d.month}/${d.year} ${t(d.hour)}:${t(d.minute)}';
}

/// Franja superior: estado de red, última actualización y operaciones pendientes.
class StatusBanner extends StatelessWidget {
  const StatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final parts = <String>[
      s.online ? 'En línea' : 'Sin conexión (modo offline)',
      if (s.syncStatus == SyncStatus.syncing) 'sincronizando…',
      if (s.syncStatus == SyncStatus.error) 'error de sync: ${s.syncError}',
      if (s.lastSync != null) 'última sync ${fmt(s.lastSync!)}',
      if (s.pendingCount > 0) '${s.pendingCount} pendiente(s)',
    ];
    return Material(
      color: s.online ? cs.secondaryContainer : cs.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(children: [
          Icon(s.online ? Icons.cloud_done : Icons.cloud_off, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(parts.join(' · '), style: const TextStyle(fontSize: 12))),
          if (s.online)
            InkWell(onTap: s.syncNow, child: const Icon(Icons.sync, size: 18)),
        ]),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView(this.error, {super.key, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    var icon = Icons.error_outline;
    var title = 'Ocurrió un error';
    if (error is ApiException) {
      switch ((error as ApiException).kind) {
        case ApiErrorKind.network:
        case ApiErrorKind.timeout:
          icon = Icons.wifi_off;
          title = 'Error de red';
        case ApiErrorKind.malformed:
          icon = Icons.broken_image;
          title = 'Datos malformados';
        case ApiErrorKind.rateLimit:
          icon = Icons.speed;
          title = 'Límite de consultas';
        case ApiErrorKind.forbidden:
          icon = Icons.block;
          title = 'Acceso denegado';
        default:
          title = 'Error HTTP${(error as ApiException).status != null ? ' ${(error as ApiException).status}' : ''}';
      }
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('$error', textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ]),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView(this.message, {super.key, this.icon = Icons.inbox});
  final String message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 48, color: Theme.of(context).disabledColor),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ]),
        ),
      );
}

class ShowTile extends StatelessWidget {
  const ShowTile(this.show, {super.key, this.subtitle, this.onChanged});
  final Show show;
  final String? subtitle;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: SizedBox(
        width: 48,
        child: show.imageUrl == null
            ? const Icon(Icons.tv)
            : Image.network(show.imageUrl!, fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(Icons.broken_image)),
      ),
      title: Text(show.title),
      subtitle: Text(subtitle ?? [if (show.genres.isNotEmpty) show.genres.join(', '), if (show.rating != null) '★ ${show.rating}'].join(' · ')),
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(show)));
        onChanged?.call();
      },
    );
  }
}
