import 'dart:convert';
import 'package:http/http.dart' as http;

class DenodoService {
  static const String baseUrl = 'http://localhost:9090/denodo-restfulws';
  static const String _username = 'admin';
  static const String _password = 'admin';

  static String get _authHeader {
    final credentials = base64Encode(utf8.encode('$_username:$_password'));
    return 'Basic $credentials';
  }

  static Future<String> query({
    required String question,
    required String database,
    String model = 'turbo',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/ai/query');
      final response = await http
          .post(
            uri,
            headers: {
              'Authorization': _authHeader,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'question': question,
              'database': database,
              'model': model,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['answer'] ?? data['response'] ?? data.toString();
      }
      return 'Error ${response.statusCode}: ${response.reasonPhrase}';
    } on Exception catch (e) {
      return 'Error de conexión con Denodo: $e';
    }
  }
}
