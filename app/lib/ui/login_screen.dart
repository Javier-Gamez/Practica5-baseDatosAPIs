import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    if (!context.read<AppState>().online) {
      setState(() => _error = 'Sin conexión: el primer inicio de sesión requiere Internet');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final valid = _user.text.trim().isNotEmpty && _pass.text.isNotEmpty;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.live_tv, size: 64),
                const SizedBox(height: 8),
                Text('Práctica 5 · Series', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 24),
                TextField(
                  key: const Key('user'),
                  controller: _user,
                  decoration: const InputDecoration(labelText: 'Usuario', border: OutlineInputBorder()),
                  onChanged: (_) => setState(() {}),
                  autocorrect: false,
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('pass'),
                  controller: _pass,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
                  onChanged: (_) => setState(() {}),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                const SizedBox(height: 16),
                if (_busy) const CircularProgressIndicator(),
                if (!_busy) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: valid ? () => _run(() => app.login(_user.text, _pass.text)) : null,
                      child: const Text('Iniciar sesión'),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: valid ? () => _run(() => app.register(_user.text, _pass.text)) : null,
                      child: const Text('Registrarse'),
                    ),
                  ),
                  const Divider(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.account_circle),
                      onPressed: () => _run(app.loginWithGoogle),
                      label: const Text('Continuar con Google'),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
