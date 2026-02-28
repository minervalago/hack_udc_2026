import 'dart:convert';
import 'package:http/http.dart' as http;

const _baseUrl = 'localhost:8008';
const _username = 'admin';
const _password = 'admin';

const _turboTimeout = Duration(seconds: 60);
const _deepTimeout = Duration(seconds: 300);

class ApiResponse {
  final String answer;
  final String? sqlQuery;
  final String? queryExplanation;
  final List<String> relatedQuestions;
  final String? rawGraph;
  final List<String> tablesUsed;
  final String? htmlReport; // only present in Deep mode

  const ApiResponse({
    required this.answer,
    this.sqlQuery,
    this.queryExplanation,
    this.relatedQuestions = const [],
    this.rawGraph,
    this.tablesUsed = const [],
    this.htmlReport,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      answer: json['answer'] as String? ?? '',
      sqlQuery: json['sql_query'] as String?,
      queryExplanation: json['query_explanation'] as String?,
      relatedQuestions: (json['related_questions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      rawGraph: json['raw_graph'] as String?,
      tablesUsed: (json['tables_used'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  factory ApiResponse.error(String message) => ApiResponse(answer: message);
}

class DenodoService {
  static String get _authHeader {
    final credentials = base64Encode(utf8.encode('$_username:$_password'));
    return 'Basic $credentials';
  }

  static Map<String, String> get _headers => {
        'accept': 'application/json',
        'Authorization': _authHeader,
      };

  static Map<String, String> get _jsonHeaders => {
        'accept': 'application/json',
        'Authorization': _authHeader,
        'Content-Type': 'application/json',
      };

  // Turbo Phase 1: discover which tables/columns are available for the question.
  static Future<String> _discoverMetadata({
    required String question,
  }) async {
    final uri = Uri.http(_baseUrl, '/answerMetadataQuestion', {
      'question': question,
      'llm_provider': 'openai',
      'llm_model': 'gpt-4o-mini',
      'llm_temperature': '0',
      'embeddings_provider': 'openai',
      'embeddings_model': 'text-embedding-3-small',
      'vector_store_provider': 'chroma',
      'vector_search_k': '5',
      'markdown_response': 'false',
    });

    final response = await http
        .get(uri, headers: _headers)
        .timeout(_turboTimeout);

    if (response.statusCode != 200) {
      throw Exception('Metadata error ${response.statusCode}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return data['answer'] as String? ?? '';
  }

  // Turbo Phase 2: run the actual VQL query and return ranked candidates.
  static Future<ApiResponse> _queryData({
    required String question,
    required String metadataContext,
    required bool plot,
  }) async {
    final enrichedQuestion =
        '$question\n\n[Contexto de esquema disponible]:\n$metadataContext';

    final uri = Uri.http(_baseUrl, '/answerDataQuestion', {
      'question': enrichedQuestion,
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
      'check_ambiguity': 'false',
      'vql_execute_rows_limit': '100',
      'llm_response_rows_limit': '25',
    });

    final response = await http
        .get(uri, headers: _headers)
        .timeout(_turboTimeout);

    if (response.statusCode != 200) {
      throw Exception('Query error ${response.statusCode}: ${response.reasonPhrase}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return ApiResponse.fromJson(data);
  }

  // Deep Phase 1: /deepQuery with o1 as thinking model.
  static Future<Map<String, dynamic>> _runDeepQuery({
    required String question,
    required String database,
  }) async {
    final uri = Uri.http(_baseUrl, '/deepQuery');
    final body = jsonEncode({
      'question': question,
      'execution_model': 'thinking',
      'default_rows': 10,
      'max_analysis_loops': 50,
      'max_concurrent_tool_calls': 5,
      'thinking_llm_provider': 'openai',
      'thinking_llm_model': 'o1',
      'thinking_llm_temperature': 1,
      'thinking_llm_max_tokens': 10240,
      'llm_provider': 'openai',
      'llm_model': 'gpt-4o-mini',
      'llm_temperature': 0,
      'llm_max_tokens': 4096,
      'embeddings_provider': 'openai',
      'embeddings_model': 'text-embedding-3-small',
      'vector_store_provider': 'chroma',
      'vdp_database_names': database,
      'vdp_tag_names': '',
      'allow_external_associations': false,
      'use_views': '',
      'expand_set_views': true,
      'vector_search_k': 5,
      'vector_search_sample_data_k': 3,
    });

    final response = await http
        .post(uri, headers: _jsonHeaders, body: body)
        .timeout(_deepTimeout);

    if (response.statusCode != 200) {
      final detail = utf8.decode(response.bodyBytes);
      throw Exception('DeepQuery error ${response.statusCode}: $detail');
    }

    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  // Deep Phase 2: /generateDeepQueryReport — builds HTML report from metadata.
  static Future<String> _generateDeepReport({
    required Map<String, dynamic> metadata,
  }) async {
    final uri = Uri.http(_baseUrl, '/generateDeepQueryReport');
    final body = jsonEncode({
      'deepquery_metadata': metadata,
      'color_palette': 'red',
      'max_reporting_loops': 25,
      'include_failed_tool_calls_appendix': false,
      'thinking_llm_provider': 'openai',
      'thinking_llm_model': 'o1',
      'thinking_llm_temperature': 1,
      'thinking_llm_max_tokens': 10240,
      'llm_provider': 'openai',
      'llm_model': 'gpt-4o-mini',
      'llm_temperature': 0,
      'llm_max_tokens': 4096,
    });

    final response = await http
        .post(uri, headers: _jsonHeaders, body: body)
        .timeout(_deepTimeout);

    if (response.statusCode != 200) {
      final detail = utf8.decode(response.bodyBytes);
      throw Exception('Report error ${response.statusCode}: $detail');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return data['html_report'] as String? ?? '';
  }

  /// Fetches the list of available VDP databases from /getVectorDBInfo.
  static Future<List<String>> fetchDatabases() async {
    final uri = Uri.http(_baseUrl, '/getVectorDBInfo');
    final response = await http
        .get(uri, headers: _headers)
        .timeout(_turboTimeout);

    if (response.statusCode != 200) {
      final body = utf8.decode(response.bodyBytes);
      final preview = body.length > 300 ? '${body.substring(0, 300)}…' : body;
      throw Exception('HTTP ${response.statusCode}: $preview');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final synced = data['syncedResources'] as Map<String, dynamic>? ?? {};
    final dbs = synced['DATABASE'] as Map<String, dynamic>? ?? {};
    return dbs.keys.toList();
  }

  /// Public entry point. Branches by model:
  ///   Turbo → 2-phase flow (/answerMetadataQuestion + /answerDataQuestion) with gpt-4o-mini
  ///   Deep  → /deepQuery (o1) + /generateDeepQueryReport → ApiResponse with htmlReport
  static Future<ApiResponse> query({
    required String question,
    required String model,
    required String database,
    bool plot = false,
    void Function(String phase)? onPhaseChange,
  }) async {
    try {
      if (model == 'Deep') {
        onPhaseChange?.call('Iniciando análisis profundo con o1...');
        final deepResult = await _runDeepQuery(
          question: question,
          database: database,
        );
        final answer = deepResult['answer'] as String? ?? '';
        final metadata =
            deepResult['deepquery_metadata'] as Map<String, dynamic>? ?? {};

        onPhaseChange?.call('Generando informe detallado...');
        final htmlReport = await _generateDeepReport(metadata: metadata);

        return ApiResponse(answer: answer, htmlReport: htmlReport);
      } else {
        onPhaseChange?.call('Descubriendo esquema de datos...');
        final metadata = await _discoverMetadata(question: question);

        onPhaseChange?.call('Consultando base de datos...');
        return await _queryData(
          question: question,
          metadataContext: metadata,
          plot: plot,
        );
      }
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('TimeoutException')) {
        return ApiResponse.error(
          model == 'Deep'
              ? 'El análisis profundo tardó demasiado. Simplifica la pregunta o prueba con Turbo.'
              : 'La consulta tardó demasiado. Prueba con el modo Turbo o simplifica la pregunta.',
        );
      }
      if (msg.contains('SocketException') || msg.contains('Connection refused')) {
        return ApiResponse.error(
          'No se puede conectar con Denodo (localhost:8008). Comprueba que el servicio está activo.',
        );
      }
      return ApiResponse.error('Error inesperado: $msg');
    }
  }
}
