class ApiConfig {
  static const String baseUrl = 'http://192.168.1.12:3001/api';

  
  static const Duration timeout = Duration(seconds: 30);
  
  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}
