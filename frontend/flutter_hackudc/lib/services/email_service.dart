import 'dart:convert';
import 'package:http/http.dart' as http;

class EmailService {
  static const _apiKey = 'API_AQUI';
  static const _from = 'onboarding@resend.dev';

  static Future<void> sendReport({
    required String toEmail,
    required String htmlContent,
  }) async {
    final response = await http
        .post(
          Uri.parse('https://api.resend.com/emails'),
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'from': _from,
            'to': [toEmail],
            'subject': 'Informe — Administrador de Becas',
            'html': htmlContent,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }
  }
}
