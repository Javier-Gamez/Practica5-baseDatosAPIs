# Práctica 5 — Consulta de bases de datos vía APIs (Flutter · Android e iOS)

[Español](#español) · [English](#english)

---

## Español

Aplicación **Flutter** (una sola base de código para Android 7.0/API 24+ e iOS 15+) que continúa la
**Práctica 2** (backend Flask + PostgreSQL con CRUD y JWT). Añade API pública (TVMaze), caché local SQLite,
sincronización con cola offline, historial, favoritos, recomendaciones, login con Google y rol administrador.

> Base reutilizada de la Práctica 2: <https://github.com/Javier-Gamez/Flask-Compose-Login-API> (commit `5c8fc61`).

### Estructura

```
backend/   API REST Flask + PostgreSQL (Docker Compose)
app/       Cliente Flutter (lib/core = lógica compartida, lib/ui = pantallas)
docs/      Informe técnico, matriz de pruebas, estrategia de sincronización
```

### Endpoints

| Endpoint | Origen | Descripción |
|---|---|---|
| `GET /` , `POST /register`, `POST /login` | Práctica 2 (reutilizado; `login` ahora devuelve `role`) | Registro y sesión JWT |
| `GET/POST /notes`, `GET/PUT/DELETE /notes/<id>` | Práctica 2 (reutilizado) | CRUD de notas |
| `POST /auth/google` | **Nuevo** | Valida el `idToken` de Google (emisor, audiencia, correo verificado) y emite JWT propio |
| `GET /me` | **Nuevo** | Restaura/valida sesión |
| `GET/POST/DELETE /history` | **Nuevo** | Historial de búsquedas por usuario |
| `GET /favorites`, `PUT/DELETE /favorites/<show_id>` | **Nuevo** | Favoritos por usuario (PUT idempotente) |
| `POST /sync` | **Nuevo** | Aplica en lote la cola offline; idempotente por `op_id` |
| `GET /admin/users`, `/admin/users/<id>/history`, `/admin/users/<id>/favorites` | **Nuevo** | Solo rol `admin` (403 en caso contrario, validado en el backend) |

API pública: **TVMaze** (`/search/shows`, `/shows/<id>`, `/shows?page=`), sin llave.

### Requisitos

- Flutter ≥ 3.x, Android SDK (API 24+), Docker Desktop.
- Para iOS: macOS con Xcode (simulador iOS 15+ o dispositivo).

### Backend

```bash
cd backend
cp .env.example .env     # editar JWT_SECRET_KEY, ADMIN_USERNAMES, GOOGLE_CLIENT_IDS
docker compose up -d --build
curl http://localhost:5000/
```

Pruebas del backend: `cd backend && pip install flask flask-sqlalchemy flask-bcrypt pyjwt requests pytest && pytest tests`.

El usuario cuyo nombre aparezca en `ADMIN_USERNAMES` obtiene rol administrador al registrarse.

### Ejecutar la app

```bash
cd app
flutter pub get
# Android (emulador): el backend en la PC es http://10.0.2.2:5000 (valor por defecto)
flutter run
# iOS (simulador, en macOS):
cd ios && pod install && cd ..
flutter run --dart-define=API_URL=http://localhost:5000
```

Pruebas unitarias: `flutter test`.

**HTTPS:** TVMaze se consume por HTTPS. Para el backend, en desarrollo se permite HTTP solo hacia
`10.0.2.2`/localhost (manifiesto *debug* de Android y `NSAllowsLocalNetworking` en iOS). En un despliegue real
publicar el backend detrás de un proxy TLS y usar `--dart-define=API_URL=https://...`; las compilaciones *release* de Android no permiten HTTP.

### Configuración de Google (sin secretos en el repositorio)

1. En Google Cloud Console crear un proyecto y la pantalla de consentimiento OAuth.
2. Crear tres Client IDs: **Web** (será la audiencia), **Android** (paquete `mx.ipn.escom.practica5_app` + SHA-1 del keystore) e **iOS** (bundle id del proyecto).
3. Backend: poner el Client ID **Web** en `GOOGLE_CLIENT_IDS` del `.env`.
4. App: `flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<web>.apps.googleusercontent.com --dart-define=GOOGLE_IOS_CLIENT_ID=<ios>.apps.googleusercontent.com`.
5. iOS: reemplazar `com.googleusercontent.apps.REEMPLAZAR` en `ios/Runner/Info.plist` por el *reversed client ID* de iOS.

Los Client IDs no son secretos, pero no se versionan valores reales; `.env` y archivos `google-services.json` / `GoogleService-Info.plist` están en `.gitignore`.
El token de sesión se guarda con `flutter_secure_storage` (Keystore en Android, Keychain en iOS).

### Sincronización y conflictos (resumen)

Detalle en [`docs/sincronizacion.md`](docs/sincronizacion.md).

- Toda acción (favorito, historial) se escribe **primero en SQLite** y se encola con un `op_id` (UUID).
- Al abrir la app, al recuperar la conexión y tras cada cambio se envía la cola a `POST /sync` (idempotente); si falla se reintenta con retroceso exponencial (2, 4, 8 s).
- Después se descarga el estado del servidor. **Prioridad: servidor = fuente de verdad, salvo operaciones locales aún pendientes**, que se conservan hasta confirmarse.
- Offline siguen disponibles: sesión validada, búsquedas y series ya consultadas, historial, favoritos y recomendaciones guardadas.

### Documentación

- [`docs/informe-tecnico.md`](docs/informe-tecnico.md) — informe técnico
- [`docs/matriz-pruebas.md`](docs/matriz-pruebas.md) — matriz de pruebas Android/iOS
- [`docs/sincronizacion.md`](docs/sincronizacion.md) — estrategia de sincronización

---

## English

**Flutter** app (single codebase for Android 7.0/API 24+ and iOS 15+) that continues **Practice 2**
(Flask + PostgreSQL backend with CRUD and JWT). It adds a public API (TVMaze), SQLite cache,
offline queue synchronization, search history, favorites, recommendations, Google sign-in and an admin role.

> Reused base from Practice 2: <https://github.com/Javier-Gamez/Flask-Compose-Login-API> (commit `5c8fc61`).

### Layout

```
backend/   Flask + PostgreSQL REST API (Docker Compose)
app/       Flutter client (lib/core = shared logic, lib/ui = screens)
docs/      Technical report, test matrix, sync strategy
```

### Endpoints

Reused from Practice 2: `/`, `/register`, `/login` (now also returns `role`), `/notes` CRUD.
New: `POST /auth/google`, `GET /me`, `/history`, `/favorites`, `POST /sync` (idempotent by `op_id`),
`/admin/users[/<id>/history|favorites]` (admin only, enforced server-side → 403 otherwise).
Public API: **TVMaze** (no key required).

### Requirements

Flutter, Android SDK (API 24+), Docker Desktop. iOS builds need macOS + Xcode (simulator iOS 15+ or device).

### Run the backend

```bash
cd backend
cp .env.example .env     # set JWT_SECRET_KEY, ADMIN_USERNAMES, GOOGLE_CLIENT_IDS
docker compose up -d --build
```

### Run the app

```bash
cd app && flutter pub get
flutter run                                              # Android emulator (API_URL defaults to http://10.0.2.2:5000)
flutter run --dart-define=API_URL=http://localhost:5000  # iOS simulator (macOS, after `pod install`)
```

HTTPS: TVMaze is used over HTTPS. Plain HTTP to the backend is only allowed for local development
(Android debug manifest / iOS `NSAllowsLocalNetworking`); in production put the backend behind TLS and pass `API_URL=https://...`.

### Google OAuth setup (no secrets committed)

Create Web, Android and iOS OAuth client IDs in Google Cloud Console. Put the **Web** client ID in the backend `GOOGLE_CLIENT_IDS`
(token audience check) and pass `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` / `GOOGLE_IOS_CLIENT_ID=...` to the app.
On iOS replace the reversed client ID placeholder in `ios/Runner/Info.plist`. The session token is stored with `flutter_secure_storage`.

### Sync

Writes go to SQLite first and into a queue with a UUID `op_id`. The queue is flushed to `POST /sync` on startup, on reconnect and after each change,
with exponential backoff. The server then returns its state; the server wins except for local operations still pending. See `docs/sincronizacion.md`.
