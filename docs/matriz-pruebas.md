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
| F1 | Consulta REST (CRUD notas) | Login → Notas → crear, editar, borrar | Cambios reflejados; errores visibles | ⏳ | ⏳ |
| F2 | Búsqueda API pública | Buscar "breaking" | Lista con imagen, géneros, tiempo en ms; detalle | ⏳ | ⏳ |
| F3 | Estado vacío / error | Buscar "zzzqqq"; apagar red y buscar texto nuevo | "Sin resultados"; error de red sin cierre | ⏳ | ⏳ |
| F4 | Google: ingreso, restauración y cierre | Continuar con Google → cerrar y abrir app → Cerrar sesión | Entra, conserva sesión, sale | ⏳ | ⏳ |
| F5 | Favoritos | Marcar/desmarcar desde detalle | Aparece/desaparece en Favoritos | ⏳ | ⏳ |
| F6 | Recomendaciones | Con 2+ favoritos abrir "Para ti"; sin datos con cuenta nueva | ≥3 con razón; caso vacío explicado | ⏳ | ⏳ |
| F7 | Reinicio de la app | Cerrar totalmente y abrir | Sesión, favoritos, historial y recomendaciones persisten | ⏳ | ⏳ |
| F8 | Consulta offline | Modo avión; abrir búsquedas previas | Resultados guardados con fecha | ⏳ | ⏳ |
| F9 | Reconexión y sync | Marcar favoritos offline → reactivar red | Banner "N pendientes" → 0, sin duplicados | ⏳ | ⏳ |
| F10 | Admin y acceso denegado | Cuenta `admin` abre panel; cuenta normal pulsa "Probar acceso" | Admin ve usuarios; normal recibe 403 | ⏳ | ⏳ |
| F11 | Cambio de conectividad en vivo | Alternar red con la app abierta | Banner cambia en tiempo real | ⏳ | ⏳ |

Defectos reproducibles: registrar como issues de GitHub y enlazarlos aquí.
