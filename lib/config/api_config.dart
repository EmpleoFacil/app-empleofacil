import 'package:http/http.dart' as http;

class ApiConfig {
  static const String productionUrl = 'https://apiempleofacil-production.up.railway.app/api';
  static const String localUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:3001/api',
  );

  static String baseUrl = productionUrl;

  static String get socketUrl => baseUrl.replaceFirst(RegExp(r'/api/?$'), '');

  static const Duration timeout = Duration(seconds: 30);

  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static Future<void> checkBackend() async {
    try {
      // Intentamos una petición rápida (timeout de 2 segundos) para verificar si producción responde
      final response = await http
          .get(Uri.parse(productionUrl))
          .timeout(const Duration(seconds: 2));
      // Si responde (incluso 404 o cualquier código), es que está activo
      baseUrl = productionUrl;
      print('Backend principal (producción) conectado con éxito: $baseUrl');
    } catch (e) {
      // Si falla o da timeout, usamos el local
      baseUrl = localUrl;
      print('Backend principal no disponible. Usando local: $baseUrl (Error: $e)');
    }
  }
}
