import 'dart:convert';
import 'package:http/http.dart' as http;

class EmailService {
  // Replace with your Resend API key from https://resend.com
  static const _apiKey = 'RESEND_API_KEY_HERE';
  // Resend sandbox sender — works without domain verification
  static const _from = 'onboarding@resend.dev';

  static Future<void> sendDeepReport({
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
            'subject': 'Informe Deep Query — Administrador de Becas',
            'html': htmlContent,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
          'Error al enviar el correo (${response.statusCode}): ${response.body}');
    }
  }
}
