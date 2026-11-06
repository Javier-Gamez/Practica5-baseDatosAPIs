/// Configuración sin secretos. Se sobreescribe con --dart-define:
///   flutter run --dart-define=API_URL=https://mi-servidor --dart-define=GOOGLE_SERVER_CLIENT_ID=xxx.apps.googleusercontent.com
class Config {
  /// 10.0.2.2 es el host de la PC visto desde el emulador de Android.
  /// En el simulador de iOS usar http://localhost:5000. En producción: HTTPS obligatorio.
  static const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:5000');
  static const tvmazeUrl = 'https://api.tvmaze.com';

  /// Client ID de tipo "Web" (sirve como audiencia del idToken). No es un secreto.
  static const googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
  static const googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  static const requestTimeout = Duration(seconds: 12);
  static const maxRetries = 3;
}
