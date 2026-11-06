# Matriz de pruebas

Leyenda: ✅ ejecutada y aprobada · ⏳ por ejecutar en el dispositivo (completar con captura) · ❌ falla (abrir issue y enlazar).

## Pruebas automatizadas (ejecutadas)
| ID | Prueba | Resultado |
|---|---|---|
| A1 | `backend/tests`: favoritos idempotentes y aislados por usuario | ✅ |
| A2 | `backend/tests`: `/sync` idempotente (reintento → `skipped`, sin duplicar historial) | ✅ |
| A3 | `backend/tests`: admin permitido (200) y usuario normal denegado (403) | ✅ |
| A4 | `backend/tests`: `/auth/google` sin token → 400 | ✅ |
| A5 | `app/test`: parseo TVMaze válido, malformado y con nulos | ✅ |
| A6 | `app/test`: recomendador determinista, excluye favoritos, caso sin datos | ✅ |

## Pruebas funcionales (Android y iOS)
Ejecutar los mismos pasos en ambas plataformas. Completar dispositivo/SO y adjuntar captura en `docs/evidencias/`.

| ID | Escenario | Pasos | Esperado | Android (dispositivo / SO / resultado) | iOS (simulador / SO / resultado) |
|---|---|---|---|---|---|
| F1 | Consulta REST (CRUD notas) | Login → Notas → crear, editar, borrar | Cambios reflejados; errores visibles | ✅ Samsung SM-G998U (Galaxy S21 Ultra), Android 14, físico por USB. CRUD de notas verificado contra la API (POST/PUT/DELETE → 200/201); en la app se vio el estado vacío. Captura: `evidencias/android/` (pantalla de notas no capturada con datos) | ⏳ |
| F2 | Búsqueda API pública | Buscar "breaking" | Lista con imagen, géneros, tiempo en ms; detalle | ✅ Samsung SM-G998U (Galaxy S21 Ultra), Android 14, físico por USB. 'breaking' → 10 resultados en 355 ms, detalle con sinopsis. `03-busqueda.png`, `04-detalle.png` | ⏳ |
| F3 | Estado vacío / error | Buscar "zzzqqq"; apagar red y buscar texto nuevo | "Sin resultados"; error de red sin cierre | ⏳ parcial: error de red sin cierre visto en modo offline (`11-…png`); falta 'zzzqqq' (sin resultados) | ⏳ |
| F4 | Google: ingreso, restauración y cierre | Continuar con Google → cerrar y abrir app → Cerrar sesión | Entra, conserva sesión, sale | ⏳ requiere Client IDs de Google | ⏳ |
| F5 | Favoritos | Marcar/desmarcar desde detalle | Aparece/desaparece en Favoritos | ✅ Samsung SM-G998U (Galaxy S21 Ultra), Android 14, físico por USB. 3 favoritos marcados y persistidos en servidor. `05-favorito-marcado.png`, `06-favoritos.png` | ⏳ |
| F6 | Recomendaciones | Con 2+ favoritos abrir "Para ti"; sin datos con cuenta nueva | ≥3 con razón; caso vacío explicado | ✅ Samsung SM-G998U (Galaxy S21 Ultra), Android 14, físico por USB. Con 3 favoritos: lista de recomendaciones con criterio y razón por serie. `08-recomendaciones.png`. Caso sin datos: cubierto por prueba unitaria | ⏳ |
| F7 | Reinicio de la app | Cerrar totalmente y abrir | Sesión, favoritos, historial y recomendaciones persisten | ✅ Samsung SM-G998U (Galaxy S21 Ultra), Android 14, físico por USB. Tras `force-stop` y reabrir: sesión restaurada sin login. `11-reinicio-offline-busqueda.png` | ⏳ |
| F8 | Consulta offline | Modo avión; abrir búsquedas previas | Resultados guardados con fecha | ✅ Samsung SM-G998U (Galaxy S21 Ultra), Android 14, físico por USB. Wi-Fi y datos apagados: 'breaking' muestra resultados guardados con fecha (imágenes no disponibles offline). `11-reinicio-offline-busqueda.png` | ⏳ |
| F9 | Reconexión y sync | Marcar favoritos offline → reactivar red | Banner "N pendientes" → 0, sin duplicados | ✅ Samsung SM-G998U (Galaxy S21 Ultra), Android 14, físico por USB. Favorito quitado offline → banner '1 pendiente(s)'; al reconectar sincroniza y el servidor coincide (2 favoritos). `09-offline-pendiente.png`, `10-reconexion-sync.png` | ⏳ |
| F10 | Admin y acceso denegado | Cuenta `admin` abre panel; cuenta normal pulsa "Probar acceso" | Admin ve usuarios; normal recibe 403 | ✅ backend: `usuario1` → 403 y `admin` → 200 en `/admin/users`; admin ve favoritos de usuario1. ⏳ falta captura del panel en la app | ⏳ |
| F11 | Cambio de conectividad en vivo | Alternar red con la app abierta | Banner cambia en tiempo real | ✅ Samsung SM-G998U (Galaxy S21 Ultra), Android 14, físico por USB. Banner cambia a 'Sin conexión' y de vuelta a 'En línea' al alternar Wi-Fi/datos. `09-…png`, `10-…png` | ⏳ |

Defectos reproducibles: registrar como issues de GitHub y enlazarlos aquí.
