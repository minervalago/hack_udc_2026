import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiResponse {
  final String answer;
  final String? sqlQuery;
  final String? queryExplanation;
  final List<String> relatedQuestions;
  final String? rawGraph;
  final List<String> tablesUsed;

  const ApiResponse({
    required this.answer,
    this.sqlQuery,
    this.queryExplanation,
    this.relatedQuestions = const [],
    this.rawGraph,
    this.tablesUsed = const [],
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      answer: json['answer'] ?? '',
      sqlQuery: json['sql_query'],
      queryExplanation: json['query_explanation'],
      relatedQuestions: (json['related_questions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      rawGraph: json['raw_graph'],
      tablesUsed: (json['tables_used'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  factory ApiResponse.error(String message) {
    return ApiResponse(answer: message);
  }
}

class DenodoService {
  static const String _baseUrl = 'http://localhost:8008';
  static const String _username = 'admin';
  static const String _password = 'admin';

  static String get _authHeader {
    final credentials = base64Encode(utf8.encode('$_username:$_password'));
    return 'Basic $credentials';
  }

  static Future<ApiResponse> query({
    required String question,
    String? databaseNames,
    bool plot = true,
  }) async {
    try {
      final queryParams = {
        'question': question,
        'plot': plot.toString(),
        'embeddings_provider': 'openai',
        'embeddings_model': 'text-embedding-3-small',
        'vector_store_provider': 'chroma',
        'llm_provider': 'openai',
        'llm_model': 'gpt-4o-mini',
        'llm_temperature': '0',
        'llm_max_tokens': '4096',
        'allow_external_associations': 'false',
        'expand_set_views': 'true',
        'markdown_response': 'true',
        'vector_search_k': '5',
        'vector_search_sample_data_k': '3',
        'vector_search_total_limit': '20',
        'vector_search_column_description_char_limit': '200',
        'disclaimer': 'true',
        'verbose': 'true',
        'check_ambiguity': 'true',
        'vql_execute_rows_limit': '100',
        'llm_response_rows_limit': '15',
      };

      // Solo enviar si no es un nombre placeholder del sidebar
      if (databaseNames != null && databaseNames.isNotEmpty &&
          !databaseNames.startsWith('BD ')) {
        queryParams['vdp_database_names'] = databaseNames;
      }

      final uri = Uri.http('localhost:8008', '/answerDataQuestion', queryParams);
      print('REQUEST URL: $uri');

      final response = await http
          .get(
            uri,
            headers: {
              'accept': 'application/json',
              'Authorization': _authHeader,
            },
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
        return ApiResponse.fromJson(data);
      }
      return ApiResponse.error(
          'Error ${response.statusCode}: ${response.reasonPhrase}');
    } on Exception catch (e) {
      return ApiResponse.error('Error de conexion: $e');
    }
  }
}
