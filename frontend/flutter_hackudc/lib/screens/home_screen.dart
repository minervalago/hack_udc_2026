import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/denodo_service.dart';

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

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(ChatMessage(content: text, isUser: true));
      _isLoading = true;
      _showOptions = false;
      _inputController.clear();
    });

    _scrollToBottom();

    final response = await DenodoService.query(
      question: text,
      database: _selectedDatabase,
      model: _selectedModel.toLowerCase(),
    );

    if (mounted) {
      setState(() {
        _messages.add(ChatMessage(content: response, isUser: false));
        _isLoading = false;
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
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: _messages.isEmpty ? _buildWelcome() : _buildChat(),
        ),
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
          fontSize: 32,
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
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: CircularProgressIndicator(color: _kAccentColor),
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

  Widget _buildMessage(ChatMessage msg, bool showDots) {
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
                fontSize: 14, color: Color(0xFF333333)),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            msg.content,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF333333),
              height: 1.6,
            ),
          ),
          if (showDots)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Más opciones',
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: _kBgColor,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFCCCCCC)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 6),
            _buildModelDropdown(),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _inputController,
                decoration: const InputDecoration(
                  hintText: 'Escriba la consulta',
                  hintStyle:
                      TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
                style: const TextStyle(fontSize: 14),
                onSubmitted: (_) => _sendMessage(),
                textInputAction: TextInputAction.send,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send_rounded),
              color: _kAccentColor,
              tooltip: 'Enviar',
              onPressed: _isLoading ? null : _sendMessage,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCCCCCC)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedModel,
          isDense: true,
          items: _models
              .map(
                (m) => DropdownMenuItem(
                  value: m,
                  child: Text(m,
                      style: const TextStyle(fontSize: 13)),
                ),
              )
              .toList(),
          onChanged: (v) =>
              v != null ? setState(() => _selectedModel = v) : null,
        ),
      ),
    );
  }
}
