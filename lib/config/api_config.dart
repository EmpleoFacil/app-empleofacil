class ApiConfig {
  static const String baseUrl = 'http://10.0.2.2:3000/api';
  
  static const Duration timeout = Duration(seconds: 30);
  
  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}
