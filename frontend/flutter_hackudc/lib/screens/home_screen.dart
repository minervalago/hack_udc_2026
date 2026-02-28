import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/chat_message.dart';
import '../services/denodo_service.dart';
import '../services/download_helper.dart';

const _kSidebarWidth = 180.0;
const _kSidebarColor = Color(0xFFD96E6E);
const _kSidebarDividerColor = Color(0xFFC45555);
const _kAccentColor = Color(0xFFD96E6E);
const _kBgColor = Color(0xFFF2F2F2);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _databases = ['BD Mec', 'BD ENUE', 'BD XXXX', 'BD XXX'];
  var _selectedDatabase = 'BD Mec';
  final _messages = <ChatMessage>[];
  var _isLoading = false;
  var _loadingPhase = '';
  var _showOptions = false;
  var _selectedModel = 'Turbo';
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _models = ['Turbo', 'Pro'];

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? overrideText]) async {
    final text = overrideText ?? _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(ChatMessage(content: text, isUser: true));
      _isLoading = true;
      _loadingPhase = 'Analizando consulta...';
      _showOptions = false;
      if (overrideText == null) _inputController.clear();
    });

    _scrollToBottom();

    final wantsPlot = RegExp(r'gr[aá]fic|plot|chart|diagrama', caseSensitive: false)
        .hasMatch(text);

    setState(() => _loadingPhase = 'Consultando base de datos...');

    final response = await DenodoService.query(
      question: text,
      databaseNames: _selectedDatabase,
      plot: wantsPlot,
    );

    if (mounted) {
      setState(() {
        _messages.add(ChatMessage.fromApiResponse(response));
        _isLoading = false;
        _loadingPhase = '';
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _selectDatabase(String db) {
    setState(() {
      _selectedDatabase = db;
      _messages.clear();
      _showOptions = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgColor,
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(child: _buildMainContent()),
        ],
      ),
    );
  }

  // ── Sidebar ──────────────────────────────────────────────────────────────

  Widget _buildSidebar() {
    return Container(
      width: _kSidebarWidth,
      color: _kSidebarColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(top: 20),
              itemCount: _databases.length,
              separatorBuilder: (_, i) => Divider(
                color: _kSidebarDividerColor,
                height: 1,
                thickness: 1,
                indent: 16,
                endIndent: 16,
              ),
              itemBuilder: (context, index) {
                final db = _databases[index];
                final isSelected = db == _selectedDatabase;
                return InkWell(
                  onTap: () => _selectDatabase(db),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    color: isSelected
                        ? Colors.black.withValues(alpha: 0.12)
                        : Colors.transparent,
                    child: Text(
                      db,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Divider(color: _kSidebarDividerColor, height: 1, thickness: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.account_circle,
                    color: Colors.white, size: 30),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () {},
                  child: const Text('CUENTA'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Main content ─────────────────────────────────────────────────────────

  Widget _buildMainContent() {
    if (_messages.isEmpty) {
      return Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Column(
              children: [
                const Spacer(flex: 2),
                _buildWelcome(),
                const SizedBox(height: 128),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildInputBarContent(),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        _buildHeader(),
        Expanded(child: _buildChat()),
        _buildInputBar(),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
      ),
      child: const Text(
        'Administrador de becas',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Color(0xFF333333),
        ),
      ),
    );
  }

  // ── Welcome view ─────────────────────────────────────────────────────────

  Widget _buildWelcome() {
    return Center(
      child: Text(
        'En que te ayudamos hoy?',
        style: const TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.w400,
          color: _kAccentColor,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ── Chat view ─────────────────────────────────────────────────────────────

  Widget _buildChat() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(20),
            itemCount: _messages.length + (_isLoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _messages.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(color: _kAccentColor),
                      if (_loadingPhase.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          _loadingPhase,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF999999),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }
              final msg = _messages[index];
              final isLastAssistant =
                  !msg.isUser && index == _messages.length - 1 && !_isLoading;
              return _buildMessage(msg, isLastAssistant);
            },
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: _showOptions ? 160.0 : 0.0,
          child: _showOptions ? _buildOptionsPanel() : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildMessage(ChatMessage msg, bool showExtras) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16, left: 80),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFE0E0E0),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            msg.content,
            style: const TextStyle(
                fontSize: 18, color: Color(0xFF333333)),
          ),
        ),
      );
    }

    final api = msg.apiResponse;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Respuesta de texto
          SelectableText(
            msg.content,
            style: const TextStyle(
              fontSize: 18,
              color: Color(0xFF333333),
              height: 1.6,
            ),
          ),

          // Razonamiento (SQL + explicacion)
          if (api?.sqlQuery != null || api?.queryExplanation != null) ...[
            const SizedBox(height: 12),
            _buildReasoning(api!),
          ],

          // Grafica SVG
          if (api?.rawGraph != null) ...[
            const SizedBox(height: 12),
            _buildGraph(api!.rawGraph!),
          ],

          // Preguntas relacionadas
          if (showExtras && api != null && api.relatedQuestions.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Preguntas relacionadas:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF555555),
              ),
            ),
            const SizedBox(height: 8),
            ...api.relatedQuestions.map((q) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    onTap: () => _sendMessage(q),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFDDDDDD)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        q,
                        style: const TextStyle(
                          fontSize: 13,
                          color: _kAccentColor,
                        ),
                      ),
                    ),
                  ),
                )),
          ],

          // Boton de opciones
          if (showExtras)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Mas opciones',
                icon: const Icon(Icons.more_horiz, size: 22),
                color: const Color(0xFF777777),
                onPressed: () =>
                    setState(() => _showOptions = !_showOptions),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReasoning(ApiResponse api) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      backgroundColor: Colors.white,
      collapsedBackgroundColor: Colors.white,
      title: const Text(
        'Ver razonamiento',
        style: TextStyle(fontSize: 13, color: Color(0xFF555555)),
      ),
      leading: const Icon(Icons.psychology, size: 20, color: Color(0xFF555555)),
      children: [
        if (api.queryExplanation != null) ...[
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Explicacion:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF555555),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            api.queryExplanation!,
            style: const TextStyle(fontSize: 12, color: Color(0xFF666666), height: 1.5),
          ),
        ],
        if (api.sqlQuery != null) ...[
          const SizedBox(height: 10),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Consulta SQL:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF555555),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D),
              borderRadius: BorderRadius.circular(6),
            ),
            child: SelectableText(
              api.sqlQuery!,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: Color(0xFF66FF66),
                height: 1.5,
              ),
            ),
          ),
        ],
        if (api.tablesUsed.isNotEmpty) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Tablas usadas: ${api.tablesUsed.join(", ")}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF888888)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGraph(String dataUri) {
    // El raw_graph viene como "data:image/svg+xml;base64,..."
    try {
      final base64Str = dataUri.split(',').last;
      final svgString = utf8.decode(base64Decode(base64Str));
      return Container(
        constraints: const BoxConstraints(maxHeight: 350),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        padding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            SvgPicture.string(
              svgString,
              fit: BoxFit.contain,
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                tooltip: 'Descargar grafica',
                icon: const Icon(Icons.download, size: 20),
                color: const Color(0xFF555555),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.85),
                ),
                onPressed: () => _saveGraph(svgString),
              ),
            ),
          ],
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  Future<void> _saveGraph(String svgContent) async {
    try {
      final path = await saveSvgFile(svgContent);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Grafica guardada: $path'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Options panel ─────────────────────────────────────────────────────────

  Widget _buildOptionsPanel() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Color(0xFFE0E0E0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildOptionItem(Icons.download_outlined, 'Exportar', () {}),
          const Divider(height: 1),
          _buildOptionItem(Icons.share_outlined, 'Compartir', () {}),
          const Spacer(),
          const Divider(height: 1),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up),
            color: const Color(0xFF555555),
            tooltip: 'Cerrar',
            onPressed: () => setState(() => _showOptions = false),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionItem(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF555555)),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF333333))),
          ],
        ),
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      color: _kBgColor,
      child: _buildInputBarContent(),
    );
  }

  Widget _buildInputBarContent() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFCCCCCC)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          _buildModelDropdown(),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: _inputController,
              decoration: const InputDecoration(
                hintText: 'Escriba la consulta',
                hintStyle:
                    TextStyle(color: Color(0xFFAAAAAA), fontSize: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 20),
              ),
              style: const TextStyle(fontSize: 18),
              onSubmitted: (_) => _sendMessage(),
              textInputAction: TextInputAction.send,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, size: 26),
              color: _kAccentColor,
              tooltip: 'Enviar',
              onPressed: _isLoading ? null : () => _sendMessage(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelDropdown() {
    return PopupMenuButton<String>(
      initialValue: _selectedModel,
      onSelected: (v) => setState(() => _selectedModel = v),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      color: const Color(0xFF333333),
      itemBuilder: (context) => _models.map((m) {
        final isSelected = m == _selectedModel;
        return PopupMenuItem<String>(
          value: m,
          child: Row(
            children: [
              Icon(
                Icons.check,
                size: 16,
                color: isSelected ? _kBgColor : Colors.transparent,
              ),
              const SizedBox(width: 8),
              Text(
                m,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: _kBgColor,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF333333),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selectedModel,
              style: const TextStyle(fontSize: 16, color: _kBgColor),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down,
                size: 18, color: _kBgColor),
          ],
        ),
      ),
    );
  }
}
