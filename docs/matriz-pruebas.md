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
| F1 | Consulta REST (CRUD notas) | Login → Notas → crear, editar, borrar | Cambios reflejados; errores visibles | ✅ Samsung SM-G998U (Galaxy S21 Ultra), Android 14, físico por USB. Notas: crear (2 notas creadas), listar y borrar desde la app; API PUT/DELETE → 200. `13-nota-nueva.png`. Defecto encontrado y corregido: DEF-1 | ✅ Simulador de iPhone en Codemagic (macOS, Xcode latest), build verde; prueba de integración con servicios simulados (`app/integration_test`). Notas creadas/listadas. `ios/p5_ios_12_notas.png` |
| F2 | Búsqueda API pública | Buscar "breaking" | Lista con imagen, géneros, tiempo en ms; detalle | ✅ Samsung SM-G998U (Galaxy S21 Ultra), Android 14, físico por USB. 'breaking' → 10 resultados en 355 ms, detalle con sinopsis. `03-busqueda.png`, `04-detalle.png` | ✅ Simulador de iPhone en Codemagic (macOS, Xcode latest), build verde; prueba de integración con servicios simulados (`app/integration_test`). Búsqueda y detalle. `ios/p5_ios_03_busqueda.png`, `04_detalle.png` (catálogo simulado, no TVMaze real) |
| F3 | Estado vacío / error | Buscar "zzzqqq"; apagar red y buscar texto nuevo | "Sin resultados"; error de red sin cierre | ✅ Samsung SM-G998U (Galaxy S21 Ultra), Android 14, físico por USB. 'zzzqqq' → 'Sin resultados' (`12-sin-resultados.png`); sin red → resultados guardados y sin cierre (`11-…png`) | ✅ Simulador de iPhone en Codemagic (macOS, Xcode latest), build verde; prueba de integración con servicios simulados (`app/integration_test`). `ios/p5_ios_05_sin_resultados.png`; sin red: `10_offline_busqueda_guardada.png` |
| F4 | Google: ingreso, restauración y cierre | Continuar con Google → cerrar y abrir app → Cerrar sesión | Entra, conserva sesión, sale | ⏳ requiere Client IDs de Google | ⏳ |
| F5 | Favoritos | Marcar/desmarcar desde detalle | Aparece/desaparece en Favoritos | ✅ Samsung SM-G998U (Galaxy S21 Ultra), Android 14, físico por USB. 3 favoritos marcados y persistidos en servidor. `05-favorito-marcado.png`, `06-favoritos.png` | ✅ Simulador de iPhone en Codemagic (macOS, Xcode latest), build verde; prueba de integración con servicios simulados (`app/integration_test`). `ios/p5_ios_06_favoritos.png` |
| F6 | Recomendaciones | Con 2+ favoritos abrir "Para ti"; sin datos con cuenta nueva | ≥3 con razón; caso vacío explicado | ✅ Samsung SM-G998U (Galaxy S21 Ultra), Android 14, físico por USB. Con 3 favoritos: lista de recomendaciones con criterio y razón por serie. `08-recomendaciones.png`. Caso sin datos: cubierto por prueba unitaria | ✅ Simulador de iPhone en Codemagic (macOS, Xcode latest), build verde; prueba de integración con servicios simulados (`app/integration_test`). `ios/p5_ios_08_recomendaciones.png` |
| F7 | Reinicio de la app | Cerrar totalmente y abrir | Sesión, favoritos, historial y recomendaciones persisten | ✅ Samsung SM-G998U (Galaxy S21 Ultra), Android 14, físico por USB. Tras `force-stop` y reabrir: sesión restaurada sin login. `11-reinicio-offline-busqueda.png` | ⏳ |
| F8 | Consulta offline | Modo avión; abrir búsquedas previas | Resultados guardados con fecha | ✅ Samsung SM-G998U (Galaxy S21 Ultra), Android 14, físico por USB. Wi-Fi y datos apagados: 'breaking' muestra resultados guardados con fecha (imágenes no disponibles offline). `11-reinicio-offline-busqueda.png` | ✅ Simulador de iPhone en Codemagic (macOS, Xcode latest), build verde; prueba de integración con servicios simulados (`app/integration_test`). `ios/p5_ios_10_offline_busqueda_guardada.png` |
| F9 | Reconexión y sync | Marcar favoritos offline → reactivar red | Banner "N pendientes" → 0, sin duplicados | ✅ Samsung SM-G998U (Galaxy S21 Ultra), Android 14, físico por USB. Favorito quitado offline → banner '1 pendiente(s)'; al reconectar sincroniza y el servidor coincide (2 favoritos). `09-offline-pendiente.png`, `10-reconexion-sync.png` | ✅ Simulador de iPhone en Codemagic (macOS, Xcode latest), build verde; prueba de integración con servicios simulados (`app/integration_test`). `ios/p5_ios_09_offline_pendiente.png`, `11_reconexion_sync.png` |
| F10 | Admin y acceso denegado | Cuenta `admin` abre panel; cuenta normal pulsa "Probar acceso" | Admin ve usuarios; normal recibe 403 | ✅ Samsung SM-G998U (Galaxy S21 Ultra), Android 14, físico por USB. `usuario1` (rol user): 'Acceso denegado: se requiere rol administrador' (`14-acceso-denegado-403.png`); `admin`: panel, lista de usuarios y favoritos/historial de usuario1 (`15-…`, `16-…`, `17-…png`) | ✅ Simulador de iPhone en Codemagic (macOS, Xcode latest), build verde; prueba de integración con servicios simulados (`app/integration_test`). 403: `ios/p5_ios_13_acceso_denegado_403.png`; admin: `14_admin_usuarios.png`, `15_admin_detalle_usuario.png` |
| F11 | Cambio de conectividad en vivo | Alternar red con la app abierta | Banner cambia en tiempo real | ✅ Samsung SM-G998U (Galaxy S21 Ultra), Android 14, físico por USB. Banner cambia a 'Sin conexión' y de vuelta a 'En línea' al alternar Wi-Fi/datos. `09-…png`, `10-…png` | ✅ Simulador de iPhone en Codemagic (macOS, Xcode latest), build verde; prueba de integración con servicios simulados (`app/integration_test`). Conectividad simulada (`setOnlineForTest`): `ios/p5_ios_09_…png`, `11_…png` |

> **Nota iOS:** los resultados de iOS provienen del **simulador** de Codemagic con servicios simulados (backend y TVMaze falsos, SQLite y UI reales). F4 (Google) y F7 (reinicio) no se probaron en iOS; tampoco hay prueba en iPhone físico.

## Defectos encontrados
| ID | Descripción | Estado |
|---|---|---|
| DEF-1 | Al guardar una nota, `setState` recibía un `Future` (callback con `=>` y asignación) y Flutter lanzaba error en debug; afectaba también a Favoritos, Historial y Búsqueda | Corregido — [issue](https://github.com/Javier-Gamez/Practica5-baseDatosAPIs/issues/1) |
| DEF-2 | Sin conexión no se muestran las imágenes de las series (solo datos guardados) | Abierto — [issue](https://github.com/Javier-Gamez/Practica5-baseDatosAPIs/issues/2) |
| DEF-3 | El JWT expira a los 60 min y la app vuelve al login sin mensaje explicativo | Abierto — [issue](https://github.com/Javier-Gamez/Practica5-baseDatosAPIs/issues/3) |

