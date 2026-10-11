import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/salva_card.dart';
import '../data/chat_api.dart';
import '../data/chat_models.dart';
import 'chat_conversation_page.dart';

class ChatHomePage extends StatefulWidget {
  const ChatHomePage({
    super.key,
    required this.chatApi,
  });

  final ChatApi chatApi;

  @override
  State<ChatHomePage> createState() => _ChatHomePageState();
}

class _ChatHomePageState extends State<ChatHomePage> {
  bool _isLoading = false;
  bool _isCreating = false;
  String? _errorMessage;
  List<ChatSession> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sessions = await widget.chatApi.getSessions();

      if (!mounted) return;

      setState(() {
        _sessions = sessions;
      });
    } on DioException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = _extractDioError(error);
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Erro inesperado: $error';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createSession() async {
    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      final session = await widget.chatApi.createSession(
        title: 'Conversa financeira',
      );

      if (!mounted) return;

      await _openConversation(session);
      await _loadSessions();
    } on DioException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = _extractDioError(error);
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Erro inesperado: $error';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isCreating = false;
      });
    }
  }

  Future<void> _openConversation(ChatSession session) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatConversationPage(
          chatApi: widget.chatApi,
          session: session,
        ),
      ),
    );
  }

  String _extractDioError(DioException error) {
    final data = error.response?.data;

    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }

    if (error.type == DioExceptionType.connectionError) {
      return 'Não foi possível conectar à API.';
    }

    if (error.response?.statusCode == 401) {
      return 'Sua sessão expirou. Faça login novamente.';
    }

    if (error.response?.statusCode == 503) {
      return 'O Gemini não está configurado no backend. Confira a GEMINI_API_KEY.';
    }

    return 'Erro ao carregar conversas.';
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: AppColors.pageGradient,
      ),
      child: RefreshIndicator(
        onRefresh: _loadSessions,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Chat',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Converse com o Salva Bolso sobre seus dados financeiros.',
            ),
            const SizedBox(height: 20),
            GradientButton(
              label: 'Nova conversa',
              icon: Icons.add_comment_outlined,
              isLoading: _isCreating,
              onPressed: _isCreating ? null : _createSession,
            ),
            const SizedBox(height: 20),
            if (_isLoading && _sessions.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            if (_errorMessage != null)
              SalvaCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (!_isLoading && _sessions.isEmpty && _errorMessage == null)
              SalvaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nenhuma conversa ainda',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Crie uma conversa e pergunte sobre seus gastos, caixa, fatura ou compras parceladas.',
                    ),
                  ],
                ),
              ),
            for (final session in _sessions) ...[
              _ChatSessionCard(
                session: session,
                onTap: () => _openConversation(session),
                onDelete: () => _deleteSession(session),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSession(ChatSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir conversa?'),
          content: Text(
            'Tem certeza que deseja excluir "${session.title}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.chatApi.deleteSession(
        sessionId: session.id,
      );

      await _loadSessions();
    } on DioException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = _extractDioError(error);
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Erro inesperado: $error';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }
}

class _ChatSessionCard extends StatelessWidget {
  const _ChatSessionCard({
    required this.session,
    required this.onTap,
    required this.onDelete,
  });

  final ChatSession session;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SalvaCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Row(
          children: [
            const CircleAvatar(
              radius: 25,
              backgroundColor: AppColors.mint,
              child: Icon(
                Icons.chat_bubble_outline,
                color: AppColors.indigo,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    session.updatedAt ?? session.createdAt ?? 'Sem data',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'open') {
                  onTap();
                }
            
                if (value == 'delete') {
                  onDelete();
                }
              },
              itemBuilder: (context) {
                return const [
                  PopupMenuItem(
                    value: 'open',
                    child: Text('Abrir'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Excluir'),
                  ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}