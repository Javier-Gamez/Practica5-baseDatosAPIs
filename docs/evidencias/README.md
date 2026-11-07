# Evidencias

Capturas de la Práctica 5. Los escenarios y resultados están en [`../matriz-pruebas.md`](../matriz-pruebas.md).

## Android: dispositivo físico (Samsung Galaxy S21 Ultra, Android 14)

Prueba manual con el backend real en Docker Compose (conexión por `adb reverse`). Incluye login con Google (`18`–`20`), búsqueda, favoritos, recomendaciones, offline, 403 y panel de administrador.

### 01-login
![01-login](android/01-login.png)

### 02-home-login-ok
![02-home-login-ok](android/02-home-login-ok.png)

### 03-busqueda
![03-busqueda](android/03-busqueda.png)

### 04-detalle
![04-detalle](android/04-detalle.png)

### 05-favorito-marcado
![05-favorito-marcado](android/05-favorito-marcado.png)

### 06-favoritos
![06-favoritos](android/06-favoritos.png)

### 07-historial
![07-historial](android/07-historial.png)

### 08-recomendaciones
![08-recomendaciones](android/08-recomendaciones.png)

### 09-offline-pendiente
![09-offline-pendiente](android/09-offline-pendiente.png)

### 10-reconexion-sync
![10-reconexion-sync](android/10-reconexion-sync.png)

### 11-reinicio-offline-busqueda
![11-reinicio-offline-busqueda](android/11-reinicio-offline-busqueda.png)

### 12-sin-resultados
![12-sin-resultados](android/12-sin-resultados.png)

### 13-nota-nueva
![13-nota-nueva](android/13-nota-nueva.png)

### 14-acceso-denegado-403
![14-acceso-denegado-403](android/14-acceso-denegado-403.png)

### 14-perfil-usuario
![14-perfil-usuario](android/14-perfil-usuario.png)

### 15-perfil-admin
![15-perfil-admin](android/15-perfil-admin.png)

### 16-admin-usuarios
![16-admin-usuarios](android/16-admin-usuarios.png)

### 17-admin-detalle-usuario
![17-admin-detalle-usuario](android/17-admin-detalle-usuario.png)

### 18-google-login-resultado
![18-google-login-resultado](android/18-google-login-resultado.png)

### 19-google-sesion-restaurada
![19-google-sesion-restaurada](android/19-google-sesion-restaurada.png)

### 20-google-cierre-sesion
![20-google-cierre-sesion](android/20-google-cierre-sesion.png)

## Android: prueba de integración automatizada (mismo código que iOS)

Servicios simulados; UI y SQLite reales.

### p5_android_01_login
![p5_android_01_login](android-integracion/p5_android_01_login.png)

### p5_android_02_inicio
![p5_android_02_inicio](android-integracion/p5_android_02_inicio.png)

### p5_android_03_busqueda
![p5_android_03_busqueda](android-integracion/p5_android_03_busqueda.png)

### p5_android_04_detalle
![p5_android_04_detalle](android-integracion/p5_android_04_detalle.png)

### p5_android_05_sin_resultados
![p5_android_05_sin_resultados](android-integracion/p5_android_05_sin_resultados.png)

### p5_android_06_favoritos
![p5_android_06_favoritos](android-integracion/p5_android_06_favoritos.png)

### p5_android_07_historial
![p5_android_07_historial](android-integracion/p5_android_07_historial.png)

### p5_android_08_recomendaciones
![p5_android_08_recomendaciones](android-integracion/p5_android_08_recomendaciones.png)

### p5_android_09_offline_pendiente
![p5_android_09_offline_pendiente](android-integracion/p5_android_09_offline_pendiente.png)

### p5_android_10_offline_busqueda_guardada
![p5_android_10_offline_busqueda_guardada](android-integracion/p5_android_10_offline_busqueda_guardada.png)

### p5_android_11_reconexion_sync
![p5_android_11_reconexion_sync](android-integracion/p5_android_11_reconexion_sync.png)

### p5_android_12_notas
![p5_android_12_notas](android-integracion/p5_android_12_notas.png)

### p5_android_13_acceso_denegado_403
![p5_android_13_acceso_denegado_403](android-integracion/p5_android_13_acceso_denegado_403.png)

### p5_android_14_admin_usuarios
![p5_android_14_admin_usuarios](android-integracion/p5_android_14_admin_usuarios.png)

### p5_android_15_admin_detalle_usuario
![p5_android_15_admin_detalle_usuario](android-integracion/p5_android_15_admin_detalle_usuario.png)

## iOS: simulador de iPhone en Codemagic (build verde)

Prueba de integración automatizada con servicios simulados. Login con Google no probado en iOS.

### p5_ios_01_login
![p5_ios_01_login](ios/p5_ios_01_login.png)

### p5_ios_02_inicio
![p5_ios_02_inicio](ios/p5_ios_02_inicio.png)

### p5_ios_03_busqueda
![p5_ios_03_busqueda](ios/p5_ios_03_busqueda.png)

### p5_ios_04_detalle
![p5_ios_04_detalle](ios/p5_ios_04_detalle.png)

### p5_ios_05_sin_resultados
![p5_ios_05_sin_resultados](ios/p5_ios_05_sin_resultados.png)

### p5_ios_06_favoritos
![p5_ios_06_favoritos](ios/p5_ios_06_favoritos.png)

### p5_ios_07_historial
![p5_ios_07_historial](ios/p5_ios_07_historial.png)

### p5_ios_08_recomendaciones
![p5_ios_08_recomendaciones](ios/p5_ios_08_recomendaciones.png)

### p5_ios_09_offline_pendiente
![p5_ios_09_offline_pendiente](ios/p5_ios_09_offline_pendiente.png)

### p5_ios_10_offline_busqueda_guardada
![p5_ios_10_offline_busqueda_guardada](ios/p5_ios_10_offline_busqueda_guardada.png)

### p5_ios_11_reconexion_sync
![p5_ios_11_reconexion_sync](ios/p5_ios_11_reconexion_sync.png)

### p5_ios_12_notas
![p5_ios_12_notas](ios/p5_ios_12_notas.png)

### p5_ios_13_acceso_denegado_403
![p5_ios_13_acceso_denegado_403](ios/p5_ios_13_acceso_denegado_403.png)

### p5_ios_14_admin_usuarios
![p5_ios_14_admin_usuarios](ios/p5_ios_14_admin_usuarios.png)

### p5_ios_15_admin_detalle_usuario
![p5_ios_15_admin_detalle_usuario](ios/p5_ios_15_admin_detalle_usuario.png)
