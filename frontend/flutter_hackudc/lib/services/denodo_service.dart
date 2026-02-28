import 'dart:convert';
import 'package:http/http.dart' as http;

const _baseUrl = 'localhost:8008';
const _username = 'admin';
const _password = 'admin';

// Timeout per model: o1 needs much more time for reasoning
const _turboTimeout = Duration(seconds: 60);
const _proTimeout = Duration(seconds: 180);

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

  // Phase 1: discover which tables/columns are available for the question.
  // Returns a plain-text description that phase 2 uses to build the VQL query.
  static Future<String> _discoverMetadata({
    required String question,
    required String llmModel,
  }) async {
    final uri = Uri.http(_baseUrl, '/answerMetadataQuestion', {
      'question': question,
      'llm_provider': 'openai',
      'llm_model': llmModel,
      'llm_temperature': '0',
      'embeddings_provider': 'openai',
      'embeddings_model': 'text-embedding-3-small',
      'vector_store_provider': 'chroma',
      'vector_search_k': '5',
      'markdown_response': 'false',
    });

    final response = await http
        .get(uri, headers: _headers)
        .timeout(_turboTimeout); // metadata phase always uses fast timeout

    if (response.statusCode != 200) {
      throw Exception('Metadata error ${response.statusCode}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return data['answer'] as String? ?? '';
  }

  // Phase 2: run the actual VQL query and return ranked candidates.
  static Future<ApiResponse> _queryData({
    required String question,
    required String metadataContext,
    required String llmModel,
    required bool plot,
  }) async {
    // Enrich the question with the metadata discovered in phase 1 so the LLM
    // can build precise VQL without guessing column names.
    final enrichedQuestion =
        '$question\n\n[Contexto de esquema disponible]:\n$metadataContext';

    final uri = Uri.http(_baseUrl, '/answerDataQuestion', {
      'question': enrichedQuestion,
      'plot': plot.toString(),
      'embeddings_provider': 'openai',
      'embeddings_model': 'text-embedding-3-small',
      'vector_store_provider': 'chroma',
      'llm_provider': 'openai',
      'llm_model': llmModel,
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
      'check_ambiguity': 'false', // already resolved in phase 1
      'vql_execute_rows_limit': '100',
      'llm_response_rows_limit': '25',
    });

    final timeout = llmModel == 'o1' ? _proTimeout : _turboTimeout;
    final response = await http.get(uri, headers: _headers).timeout(timeout);

    if (response.statusCode != 200) {
      throw Exception('Query error ${response.statusCode}: ${response.reasonPhrase}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return ApiResponse.fromJson(data);
  }

  /// Fetches the list of available VDP databases from /getVectorDBInfo.
  /// Returns the keys under syncedResources.DATABASE.
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

  /// Public entry point. Runs the mandatory two-phase flow:
  ///   1. /answerMetadataQuestion — schema discovery
  ///   2. /answerDataQuestion     — VQL execution + ranking
  ///
  /// [model] must be 'Turbo' or 'Pro' (matches UI selector labels).
  /// [onPhaseChange] is called with a human-readable status string so the UI
  /// can update the loading indicator between phases.
  static Future<ApiResponse> query({
    required String question,
    required String model,
    bool plot = false,
    void Function(String phase)? onPhaseChange,
  }) async {
    final llmModel = model == 'Pro' ? 'o1' : 'gpt-4o';

    try {
      // ── Phase 1 ─────────────────────────────────────────────────────────
      onPhaseChange?.call('Descubriendo esquema de datos...');
      final metadata = await _discoverMetadata(
        question: question,
        llmModel: llmModel,
      );

      // ── Phase 2 ─────────────────────────────────────────────────────────
      onPhaseChange?.call(
        model == 'Pro'
            ? 'Analizando candidatos en profundidad...'
            : 'Consultando base de datos...',
      );
      return await _queryData(
        question: question,
        metadataContext: metadata,
        llmModel: llmModel,
        plot: plot,
      );
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('TimeoutException')) {
        return ApiResponse.error(
          'La consulta tardó demasiado. Prueba con el modo Turbo o simplifica la pregunta.',
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
