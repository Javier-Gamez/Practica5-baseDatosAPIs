# Estrategia de sincronización y conflictos

## Qué se guarda localmente (SQLite, `app/lib/core/local_db.dart`)
| Tabla | Contenido | Disponible offline tras reiniciar |
|---|---|---|
| `searches` | JSON de resultados por consulta + fecha | Sí |
| `shows` | Detalle de series consultadas | Sí |
| `history` | Historial por `user_id` | Sí |
| `favorites` | Favoritos por `user_id` | Sí |
| `pending_ops` | Cola de operaciones por enviar (`op_id`) | Sí |
| `recommendations` | Última lista de recomendaciones + criterio | Sí |
| `meta` | Fecha de última sincronización | Sí |

La sesión (JWT) vive en `flutter_secure_storage`, por lo que también se restaura sin red.

## Flujo
1. La acción se aplica en SQLite y se encola con `op_id` (UUID v4); la UI nunca espera a la red.
2. `syncNow()` se dispara: al iniciar con sesión, tras cada cambio, al pasar de offline a online y manualmente.
3. La cola se envía en un solo `POST /sync`. El servidor registra cada `op_id` aplicado (`SyncOp`, restricción única `(user_id, op_id)`); un reintento tras un corte devuelve la operación como `skipped`, **sin duplicar**.
4. Se borran de la cola las operaciones `applied` o `skipped`. Las no resueltas incrementan `attempts`; tras 5 intentos se descartan para no bloquear la cola.
5. Se descargan favoritos e historial del servidor.
6. Errores de red/HTTP: estado `error` visible y reintento con retroceso exponencial (2 s, 4 s, 8 s; máx. 3).

## Conflictos y prioridad
- **Favoritos:** el servidor es la fuente de verdad. Al reemplazar el estado local se conservan las altas pendientes y se ignoran las bajas pendientes, de modo que un cambio hecho offline no se pierde ni "revive".
- **Historial:** unión de entradas por `client_id` (clave única); nunca se pisan entradas.
- **Mismo favorito en dos dispositivos:** `PUT /favorites/<id>` es upsert (restricción única `(user_id, show_id)`); el último en llegar gana.
- **Notas (CRUD de la Práctica 2):** requieren servidor; muestran estado de espera/error y no se encolan.
- **Aislamiento:** todo dato personal lleva `user_id` localmente y se filtra por el JWT en el servidor.
