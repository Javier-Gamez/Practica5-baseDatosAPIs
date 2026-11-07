# Informe técnico — Práctica 5

## 1. Introducción
Aplicación multiplataforma (Flutter, Android 7.0+ / iOS 15+) que consulta una API REST propia y la API pública TVMaze, con persistencia local, sincronización, favoritos, historial y recomendaciones. Continúa la Práctica 2 (Flask + PostgreSQL + JWT).

## 2. Arquitectura
- **Compartido (Dart):** `lib/core` (modelos, clientes HTTP, SQLite, sincronización, recomendador) y `lib/ui` (Material 3).
- **Específico de plataforma:** Keystore/Keychain (`flutter_secure_storage`), SDK de Google Sign-In (OAuth distinto por plataforma), estado de red (`connectivity_plus`), `sqflite` (SQLite nativo), manifiestos (Android) e `Info.plist` (iOS).
- **Backend:** Flask + SQLAlchemy + PostgreSQL 17 en Docker Compose.
- Estado: `AppState` (ChangeNotifier + Provider) actúa de repositorio y orquestador de sincronización.

## 3. Endpoints usados
Ver README (tabla). TVMaze: `GET /search/shows?q=`, `GET /shows/{id}`, `GET /shows?page=`.

## 4. Modelo de datos
Servidor: `User(id, username, password, role, google_sub)`, `Note`, `SearchHistory(user_id, query, client_id)` único `(user_id, client_id)`, `Favorite(user_id, show_id, …)` único `(user_id, show_id)`, `SyncOp(user_id, op_id)` único.
Local: ver `docs/sincronizacion.md`.

## 5. Persistencia
SQLite local para lectura offline; PostgreSQL como fuente de verdad. Estrategia de conflictos en `docs/sincronizacion.md`.

## 6. Autenticación
Registro/login con bcrypt + JWT (HS256, con expiración). Google: la app obtiene un `idToken`; el backend lo valida contra `oauth2.googleapis.com/tokeninfo` (emisor, audiencia ∈ `GOOGLE_CLIENT_IDS`, correo verificado) y emite su propio JWT. La sesión se guarda en almacenamiento seguro. Offline se mantiene la sesión ya validada; al reconectar `GET /me` la revalida. El rol se lee de la BD en cada petición de administrador (`admin_required`), por lo que la autorización no depende de la interfaz.

## 7. Recomendaciones
Regla reproducible por géneros: peso(género) = 3·favoritos + 1·series del historial; puntaje = Σ pesos coincidentes + rating/10; se excluyen favoritos; desempate por id. Sin datos: las mejor valoradas. Se persisten con su criterio y fecha para verlas offline. Cubierta por pruebas unitarias.

## 8. Resultados
Pruebas automatizadas: 4 de backend y 6 de cliente aprobadas (ver `docs/matriz-pruebas.md`). Pruebas funcionales en Android (Samsung Galaxy S21 Ultra, Android 14, dispositivo físico) con el backend en Docker Compose: consulta REST, búsqueda pública (10 resultados en 355 ms), estado vacío, favoritos, recomendaciones, reinicio, consulta offline, reconexión con sincronización, cambios de conectividad en vivo y autorización de administrador (403 para usuario normal, 200 para admin) aprobadas; evidencias en `docs/evidencias/android/` y detalle en `docs/matriz-pruebas.md`. Se hallaron y corrigieron defectos (DEF-1) y quedan abiertos DEF-2 y DEF-3. En iOS se ejecutó la misma prueba de integración en el **simulador de iPhone** de Codemagic (macOS/Xcode, build en verde, 15 capturas en `docs/evidencias/ios/`) con servicios simulados. Además la prueba halló otro defecto (`setState` tras `dispose` en Favoritos), ya corregido. El inicio de sesión con Google se verificó en Android físico (ingreso, restauración y cierre de sesión; el backend validó el token contra el ID Web). **Pendiente de validar:** inicio de sesión con Google en iOS y pruebas en iPhone físico (requieren Mac/Apple Developer).

## 9. Conclusiones
Un único cliente Flutter cubre ambas plataformas; la cola idempotente evita pérdidas y duplicados durante los reintentos. Limitación: iOS se validó solo en simulador (Codemagic) y con servicios simulados.

## 10. Autoría y contribuciones
Práctica realizada de forma **individual** por Javier Gámez (sin otros integrantes): diseño, backend, cliente Flutter, pruebas, configuración de Google OAuth, CI en Codemagic y documentación.

## 10.1 Herramientas de IA declaradas
Se utilizó Claude (Anthropic) como asistente de programación para generar y revisar código y documentación; el autor revisó y probó el resultado.

## 11. Bibliografía (APA)
- Google. (2025). *google_sign_in*. https://pub.dev/packages/google_sign_in
- TVMaze. (s. f.). *TVMaze API*. https://www.tvmaze.com/api
- Flutter. (2025). *Flutter documentation*. https://docs.flutter.dev
- Pallets. (2025). *Flask documentation*. https://flask.palletsprojects.com
