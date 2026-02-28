import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../providers/query_provider.dart';
import '../services/auth_service.dart';
import '../services/denodo_service.dart';
import '../services/download_helper.dart';

const _kSidebarWidth = 220.0;
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
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send(QueryProvider provider, [String? override]) async {
    final text = override ?? _inputController.text;
    if (override == null) _inputController.clear();
    await provider.sendMessage(text);
    _scrollToBottom();
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

  @override
  Widget build(BuildContext context) {
    return Consumer<QueryProvider>(
      builder: (context, provider, _) => Scaffold(
        backgroundColor: _kBgColor,
        body: Row(
          children: [
            _Sidebar(provider: provider),
            Expanded(child: _MainContent(
              provider: provider,
              inputController: _inputController,
              scrollController: _scrollController,
              onSend: (text) => _send(provider, text),
            )),
          ],
        ),
      ),
    );
  }
}

// ── Sidebar ───────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.provider});
  final QueryProvider provider;

  @override
  Widget build(BuildContext context) {
    final sessions = provider.sessions;
    return Container(
      width: _kSidebarWidth,
      color: _kSidebarColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DatabaseSelector(provider: provider),
          const Divider(color: _kSidebarDividerColor, height: 1, thickness: 1),
          InkWell(
            onTap: provider.newChat,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.add, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Nuevo chat',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const Divider(color: _kSidebarDividerColor, height: 1, thickness: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 4),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                final isSelected = session == provider.currentSession;
                return InkWell(
                  onTap: () => provider.loadSession(session),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    color: isSelected
                        ? Colors.black.withValues(alpha: 0.12)
                        : Colors.transparent,
                    child: Text(
                      session.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(color: _kSidebarDividerColor, height: 1, thickness: 1),
          _UserTile(),
        ],
      ),
    );
  }
}

class _DatabaseSelector extends StatelessWidget {
  const _DatabaseSelector({required this.provider});
  final QueryProvider provider;

  @override
  Widget build(BuildContext context) {
    if (provider.loadingDatabases) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Cargando bases de datos...',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (provider.databasesError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                provider.databasesError!,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
              tooltip: 'Reintentar',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: provider.loadDatabases,
            ),
          ],
        ),
      );
    }

    if (provider.databases.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Text(
          'Sin bases de datos',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
      );
    }

    return PopupMenuButton<String>(
      initialValue: provider.selectedDatabase,
      onSelected: provider.selectDatabase,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 4,
      color: const Color(0xFF333333),
      itemBuilder: (context) => provider.databases.map((db) {
        final isSelected = db == provider.selectedDatabase;
        return PopupMenuItem<String>(
          value: db,
          child: Row(
            children: [
              Icon(Icons.check,
                  size: 16,
                  color: isSelected ? Colors.white : Colors.transparent),
              const SizedBox(width: 8),
              Text(
                db,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.storage, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                provider.selectedDatabase,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down,
                color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}

class _UserInitial extends StatelessWidget {
  const _UserInitial(this.initial);
  final String initial;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final photoUrl = user?.photoURL;
    final name = user?.displayName ?? user?.email ?? 'Usuario';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white30,
            child: ClipOval(
              child: photoUrl != null
                  ? Image.network(
                      photoUrl,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _UserInitial(initial),
                    )
                  : _UserInitial(initial),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white, size: 18),
            tooltip: 'Cerrar sesión',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: AuthService.signOut,
          ),
        ],
      ),
    );
  }
}

// ── Main content ──────────────────────────────────────────────────────────────

class _MainContent extends StatelessWidget {
  const _MainContent({
    required this.provider,
    required this.inputController,
    required this.scrollController,
    required this.onSend,
  });

  final QueryProvider provider;
  final TextEditingController inputController;
  final ScrollController scrollController;
  final void Function(String?) onSend;

  @override
  Widget build(BuildContext context) {
    if (provider.messages.isEmpty) {
      return Column(
        children: [
          const _Header(),
          Expanded(
            child: Column(
              children: [
                const Spacer(flex: 2),
                const _WelcomeText(),
                const SizedBox(height: 128),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _InputBar(
                    provider: provider,
                    controller: inputController,
                    onSend: onSend,
                  ),
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
        const _Header(),
        Expanded(
          child: _ChatArea(
            provider: provider,
            scrollController: scrollController,
            onSend: onSend,
          ),
        ),
        _InputBar(
          provider: provider,
          controller: inputController,
          onSend: onSend,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
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
}

class _WelcomeText extends StatelessWidget {
  const _WelcomeText();

  @override
  Widget build(BuildContext context) {
    return const Text(
      '¿En qué te ayudamos hoy?',
      style: TextStyle(
        fontSize: 42,
        fontWeight: FontWeight.w400,
        color: _kAccentColor,
      ),
      textAlign: TextAlign.center,
    );
  }
}

// ── Chat area ─────────────────────────────────────────────────────────────────

class _ChatArea extends StatelessWidget {
  const _ChatArea({
    required this.provider,
    required this.scrollController,
    required this.onSend,
  });

  final QueryProvider provider;
  final ScrollController scrollController;
  final void Function(String?) onSend;

  @override
  Widget build(BuildContext context) {
    final itemCount =
        provider.messages.length + (provider.isLoading ? 1 : 0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              if (index == provider.messages.length) {
                return _LoadingIndicator(phase: provider.loadingPhase);
              }
              final msg = provider.messages[index];
              final isLastAssistant = !msg.isUser &&
                  index == provider.messages.length - 1 &&
                  !provider.isLoading;
              return _MessageBubble(
                message: msg,
                showExtras: isLastAssistant,
                provider: provider,
                onSend: onSend,
              );
            },
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: provider.showOptions ? 160.0 : 0.0,
          child: provider.showOptions
              ? _OptionsPanel(provider: provider)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator({required this.phase});
  final String phase;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          const CircularProgressIndicator(color: _kAccentColor),
          if (phase.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              phase,
              style: const TextStyle(fontSize: 13, color: Color(0xFF999999)),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.showExtras,
    required this.provider,
    required this.onSend,
  });

  final ChatMessage message;
  final bool showExtras;
  final QueryProvider provider;
  final void Function(String?) onSend;

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16, left: 80),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFE0E0E0),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            message.content,
            style: const TextStyle(fontSize: 18, color: Color(0xFF333333)),
          ),
        ),
      );
    }

    final api = message.apiResponse;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            message.content,
            style: const TextStyle(
              fontSize: 18,
              color: Color(0xFF333333),
              height: 1.6,
            ),
          ),
          if (api?.sqlQuery != null || api?.queryExplanation != null) ...[
            const SizedBox(height: 12),
            _ReasoningTile(api: api!),
          ],
          if (api?.rawGraph != null) ...[
            const SizedBox(height: 12),
            _GraphCard(dataUri: api!.rawGraph!),
          ],
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
            ...api.relatedQuestions.map((q) => _RelatedQuestion(
                  question: q,
                  onTap: () => onSend(q),
                )),
          ],
          if (showExtras)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Más opciones',
                icon: const Icon(Icons.more_horiz, size: 22),
                color: const Color(0xFF777777),
                onPressed: provider.toggleOptions,
              ),
            ),
        ],
      ),
    );
  }
}

class _RelatedQuestion extends StatelessWidget {
  const _RelatedQuestion({required this.question, required this.onTap});
  final String question;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFDDDDDD)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            question,
            style: const TextStyle(fontSize: 13, color: _kAccentColor),
          ),
        ),
      ),
    );
  }
}

// ── Reasoning tile ────────────────────────────────────────────────────────────

class _ReasoningTile extends StatelessWidget {
  const _ReasoningTile({required this.api});
  final ApiResponse api;

  @override
  Widget build(BuildContext context) {
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
      leading: const Icon(Icons.psychology, size: 20, color: Color(0xFF555555)),
      title: const Text(
        'Ver razonamiento',
        style: TextStyle(fontSize: 13, color: Color(0xFF555555)),
      ),
      children: [
        if (api.queryExplanation != null) ...[
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Explicación:',
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
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF666666), height: 1.5),
          ),
        ],
        if (api.sqlQuery != null) ...[
          const SizedBox(height: 10),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Consulta VQL:',
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
              'Vistas usadas: ${api.tablesUsed.join(", ")}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF888888)),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Graph card ────────────────────────────────────────────────────────────────

class _GraphCard extends StatelessWidget {
  const _GraphCard({required this.dataUri});
  final String dataUri;

  @override
  Widget build(BuildContext context) {
    try {
      final svgString = utf8.decode(base64Decode(dataUri.split(',').last));
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
            SvgPicture.string(svgString, fit: BoxFit.contain),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                tooltip: 'Descargar gráfica',
                icon: const Icon(Icons.download, size: 20),
                color: const Color(0xFF555555),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.85),
                ),
                onPressed: () => _saveGraph(context, svgString),
              ),
            ),
          ],
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  Future<void> _saveGraph(BuildContext context, String svgContent) async {
    try {
      final path = await saveSvgFile(svgContent);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gráfica guardada: $path'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// ── Options panel ─────────────────────────────────────────────────────────────

class _OptionsPanel extends StatelessWidget {
  const _OptionsPanel({required this.provider});
  final QueryProvider provider;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Color(0xFFE0E0E0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OptionItem(
            icon: Icons.download_outlined,
            label: 'Exportar',
            onTap: () {},
          ),
          const Divider(height: 1),
          _OptionItem(
            icon: Icons.share_outlined,
            label: 'Compartir',
            onTap: () {},
          ),
          const Spacer(),
          const Divider(height: 1),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up),
            color: const Color(0xFF555555),
            tooltip: 'Cerrar',
            onPressed: provider.hideOptions,
          ),
        ],
      ),
    );
  }
}

class _OptionItem extends StatelessWidget {
  const _OptionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
}

// ── Input bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.provider,
    required this.controller,
    required this.onSend,
    this.padding,
  });

  final QueryProvider provider;
  final TextEditingController controller;
  final void Function(String?) onSend;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFCCCCCC)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          _ModelDropdown(provider: provider),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Escriba la consulta',
                hintStyle:
                    TextStyle(color: Color(0xFFAAAAAA), fontSize: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 20),
              ),
              style: const TextStyle(fontSize: 18),
              onSubmitted: (_) => onSend(null),
              textInputAction: TextInputAction.send,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, size: 26),
              color: _kAccentColor,
              tooltip: 'Enviar',
              onPressed: provider.isLoading ? null : () => onSend(null),
            ),
          ),
        ],
      ),
    );

    if (padding != null) {
      content = Container(
        padding: padding,
        color: _kBgColor,
        child: content,
      );
    }

    return content;
  }
}

class _ModelDropdown extends StatelessWidget {
  const _ModelDropdown({required this.provider});
  final QueryProvider provider;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      initialValue: provider.selectedModel,
      onSelected: provider.selectModel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      color: const Color(0xFF333333),
      itemBuilder: (context) => provider.models.map((m) {
        final isSelected = m == provider.selectedModel;
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
              provider.selectedModel,
              style: const TextStyle(fontSize: 16, color: _kBgColor),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, size: 18, color: _kBgColor),
          ],
        ),
      ),
    );
  }
}
