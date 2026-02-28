import 'dart:convert';
import 'package:http/http.dart' as http;

class EmailService {
  // EmailJS credentials — get from https://emailjs.com/account
  // EmailJS supports CORS from browser (unlike Resend)
  static const _publicKey = 'rfMF8zTzoGDbNhd0E';
  static const _serviceId = 'service_qd0ms1y';
  static const _templateId = 'h7jvbxs';

  static Future<void> sendDeepReport({
    required String toEmail,
    required String htmlContent,
  }) async {
    final response = await http
        .post(
          Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'service_id': _serviceId,
            'template_id': _templateId,
            'user_id': _publicKey,
            'template_params': {
              'to_email': toEmail,
              'subject': 'Informe Deep Query — Administrador de Becas',
              'message_html': htmlContent,
            },
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
          'Error al enviar el correo (${response.statusCode}): ${response.body}');
    }
  }
}
