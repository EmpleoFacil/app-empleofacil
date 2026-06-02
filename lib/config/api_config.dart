class ApiConfig {
  // Selecciona la URL según el dispositivo donde ejecutes la app:
  // - Emulador Android: 'http://10.0.2.2:3001/api'
  // - Celular físico: 'http://192.168.1.6:3001/api' (Tu IP de red actual)
  // - Emulador iOS / Windows Desktop: 'http://localhost:3001/api'
  static const String baseUrl = 'http://10.0.2.2:3001/api';

  static String get socketUrl => baseUrl.replaceFirst(RegExp(r'/api/?$'), '');

  static const Duration timeout = Duration(seconds: 30);

  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}
