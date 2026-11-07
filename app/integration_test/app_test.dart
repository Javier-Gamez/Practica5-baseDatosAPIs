import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:practica5_app/core/app_state.dart';
import 'package:practica5_app/core/local_db.dart';
import 'package:practica5_app/main.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

import 'fakes.dart';

/// Prueba de integración idéntica para Android e iOS (mismo código compartido).
/// Usa servicios simulados (fakes.dart) para ser determinista; ejercita la UI real,
/// SQLite real, la cola offline y la sincronización.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final plat = Platform.isIOS ? 'ios' : 'android';
  var converted = false;

  Future<void> settle(WidgetTester t, [int n = 12]) async {
    for (var i = 0; i < n; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> shot(WidgetTester t, String name) async {
    await settle(t);
    if (Platform.isAndroid && !converted) {
      await binding.convertFlutterSurfaceToImage();
      converted = true;
    }
    await t.pump();
    await binding.takeScreenshot('p5_${plat}_$name');
  }

  Future<void> tapText(WidgetTester t, String text) async {
    await t.tap(find.text(text).first);
    await settle(t);
  }

  Future<void> search(WidgetTester t, String q) async {
    final field = find.descendant(of: find.byType(SearchBar), matching: find.byType(EditableText));
    await t.ensureVisible(field);
    await t.tap(field);
    await t.pump(const Duration(milliseconds: 300));
    await t.enterText(field, q);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.byIcon(Icons.arrow_forward));
    await settle(t, 15);
  }

  Future<void> login(WidgetTester t, String u, String pw) async {
    await t.enterText(find.byKey(const Key('user')), u);
    await t.enterText(find.byKey(const Key('pass')), pw);
    await t.pump();
    await t.tap(find.text('Iniciar sesión'));
    await settle(t, 20);
  }

  testWidgets('Flujo completo Práctica 5', (t) async {
    final dbPath = p.join(await getDatabasesPath(), 'it_${DateTime.now().millisecondsSinceEpoch}.db');
    final db = await LocalDb.open(path: dbPath);
    final backend = FakeBackend();
    final tv = FakeTvmaze();
    final state = AppState(db: db, backend: backend, tvmaze: tv);
    await state.init();
    runApp(ChangeNotifierProvider<AppState>.value(value: state, child: const App()));
    await settle(t);
    await shot(t, '01_login');

    // --- Sesión de usuario normal ---
    await login(t, 'usuario1', 'user123');
    expect(find.text('Rol: user'), findsNothing); // aún en pestaña Buscar
    expect(find.byType(NavigationBar), findsOneWidget);
    await shot(t, '02_inicio');

    // --- Búsqueda en la API pública y favoritos ---
    await search(t, 'breaking');
    expect(find.text('Breaking Bad'), findsOneWidget);
    await shot(t, '03_busqueda');
    await tapText(t, 'Breaking Bad');
    await shot(t, '04_detalle');
    await t.tap(find.byIcon(Icons.favorite_border));
    await settle(t);
    await t.pageBack();
    await settle(t);

    await search(t, 'ozark');
    await tapText(t, 'Ozark');
    await t.tap(find.byIcon(Icons.favorite_border));
    await settle(t);
    await t.pageBack();
    await settle(t);

    await search(t, 'zzzqqq');
    expect(find.textContaining('Sin resultados'), findsOneWidget);
    await shot(t, '05_sin_resultados');

    await tapText(t, 'Favoritos');
    expect(find.text('Breaking Bad'), findsOneWidget);
    expect(find.text('Ozark'), findsOneWidget);
    await shot(t, '06_favoritos');

    await tapText(t, 'Historial');
    expect(find.text('breaking'), findsOneWidget);
    await shot(t, '07_historial');

    await tapText(t, 'Para ti');
    await settle(t, 20);
    expect(find.textContaining('Coincide en géneros'), findsWidgets);
    await shot(t, '08_recomendaciones');

    // --- Modo offline: cambio local y cola pendiente ---
    tv.offline = true;
    state.setOnlineForTest(false);
    await settle(t);
    await tapText(t, 'Favoritos');
    await tapText(t, 'Ozark');
    await t.tap(find.byIcon(Icons.favorite));
    await settle(t);
    await t.pageBack();
    await settle(t);
    expect(find.textContaining('Sin conexión'), findsOneWidget);
    expect(find.textContaining('pendiente'), findsOneWidget);
    await shot(t, '09_offline_pendiente');

    // búsqueda previa disponible sin red (resultados guardados)
    await tapText(t, 'Buscar');
    await search(t, 'breaking');
    expect(find.textContaining('Resultados guardados'), findsOneWidget);
    await shot(t, '10_offline_busqueda_guardada');

    // --- Reconexión: la cola se resuelve sin duplicados ---
    final before = backend.syncCalls;
    tv.offline = false;
    state.setOnlineForTest(true);
    await settle(t, 25);
    expect(backend.syncCalls, greaterThan(before));
    expect(find.textContaining('pendiente'), findsNothing);
    expect((await backend.favorites()).map((s) => s.title), ['Breaking Bad']);
    await tapText(t, 'Favoritos');
    await shot(t, '11_reconexion_sync');

    // --- CRUD de notas ---
    await tapText(t, 'Notas');
    await t.tap(find.byIcon(Icons.add));
    await settle(t);
    await t.enterText(find.byType(TextField).at(0), 'Nota desde $plat');
    await t.enterText(find.byType(TextField).at(1), 'Contenido de prueba');
    await t.tap(find.text('Guardar'));
    await settle(t, 15);
    expect(find.text('Nota desde $plat'), findsOneWidget);
    await shot(t, '12_notas');

    // --- Acceso denegado para usuario sin permisos ---
    await tapText(t, 'Perfil');
    await t.tap(find.text('Probar acceso a panel admin'));
    await settle(t, 6);
    expect(find.textContaining('Acceso denegado'), findsOneWidget);
    await shot(t, '13_acceso_denegado_403');

    // --- Administrador ---
    await t.tap(find.text('Cerrar sesión'));
    await settle(t);
    await login(t, 'admin', 'admin123');
    await tapText(t, 'Perfil');
    expect(find.text('Rol: admin'), findsOneWidget);
    await tapText(t, 'Panel de administrador');
    expect(find.text('usuario1'), findsOneWidget);
    await shot(t, '14_admin_usuarios');
    await tapText(t, 'usuario1');
    expect(find.text('Breaking Bad'), findsOneWidget);
    await shot(t, '15_admin_detalle_usuario');
  });
}
