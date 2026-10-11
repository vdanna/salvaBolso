import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../data/chat_api.dart';
import '../data/chat_models.dart';

class ChatConversationPage extends StatefulWidget {
  const ChatConversationPage({
    super.key,
    required this.chatApi,
    required this.session,
  });

  final ChatApi chatApi;
  final ChatSession session;

  @override
  State<ChatConversationPage> createState() => _ChatConversationPageState();
}

class _ChatConversationPageState extends State<ChatConversationPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  bool _isLoading = false;
  bool _isSending = false;
  String? _errorMessage;

  List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final messages = await widget.chatApi.getMessages(
        sessionId: widget.session.id,
      );

      if (!mounted) return;

      setState(() {
        _messages = messages;
      });

      _scrollToBottom();
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

  Future<void> _sendMessage([String? quickMessage]) async {
    final text = (quickMessage ?? _messageController.text).trim();

    if (text.length < 2) {
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    _messageController.clear();

    try {
      final response = await widget.chatApi.sendMessage(
        sessionId: widget.session.id,
        message: text,
      );

      if (!mounted) return;

      setState(() {
        _messages = [
          ..._messages,
          response.userMessage,
          response.assistantMessage,
        ];
      });

      _scrollToBottom();
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
        _isSending = false;
      });
    }
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

    return 'Erro ao enviar mensagem.';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasMessages = _messages.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Salva Bolso'),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppColors.pageGradient,
        ),
        child: Column(
          children: [
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 10),
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
              ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                      children: [
                        if (!hasMessages) ...[
                          const _AssistantIntroCard(),
                          const SizedBox(height: 16),
                          _QuickQuestions(
                            onQuestionTap: _sendMessage,
                          ),
                        ],
                        for (final message in _messages) ...[
                          _ChatBubble(message: message),
                          const SizedBox(height: 12),
                        ],
                        if (_isSending) ...[
                          const _TypingBubble(),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
            ),
            _MessageComposer(
              controller: _messageController,
              isSending: _isSending,
              onSend: () => _sendMessage(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.selectedMonth,
    required this.onChanged,
  });

  final String? selectedMonth;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.indigo.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: selectedMonth,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down),
          items: const [
            DropdownMenuItem<String?>(
              value: null,
              child: Text('Mês automático'),
            ),
            DropdownMenuItem<String?>(
              value: '2026-04',
              child: Text('Mês: 2026-04'),
            ),
            DropdownMenuItem<String?>(
              value: '2026-05',
              child: Text('Mês: 2026-05'),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _AssistantIntroCard extends StatelessWidget {
  const _AssistantIntroCard();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Text(
          'Olá, sou o Salva Bolso, seu assistente financeiro. '
          'Posso analisar seus gastos, caixa, faturas e compras parceladas.',
        ),
      ),
    );
  }
}

class _QuickQuestions extends StatelessWidget {
  const _QuickQuestions({
    required this.onQuestionTap,
  });

  final ValueChanged<String> onQuestionTap;

  @override
  Widget build(BuildContext context) {
    const questions = [
      'Como foi meu mês financeiro?',
      'Onde eu mais gastei?',
      'Tenho muitas compras parceladas?',
      'Meu pagamento de fatura foi contado duas vezes?',
      'Qual próximo passo devo tomar?',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: questions
          .map(
            (question) => ActionChip(
              label: Text(question),
              onPressed: () => onQuestionTap(question),
            ),
          )
          .toList(),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
  });

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppColors.seaGreen : AppColors.card,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(isUser ? 22 : 6),
            bottomRight: Radius.circular(isUser ? 6 : 22),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.indigo.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: isUser ? Colors.white : AppColors.textPrimary,
            fontWeight: isUser ? FontWeight.w600 : FontWeight.w500,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Analisando seus dados...'),
          ],
        ),
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        decoration: BoxDecoration(
          color: AppColors.card.withOpacity(0.96),
          border: Border(
            top: BorderSide(
              color: AppColors.border.withOpacity(0.65),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  if (!isSending) {
                    onSend();
                  }
                },
                decoration: const InputDecoration(
                  hintText: 'Envie sua dúvida...',
                  prefixIcon: Icon(Icons.chat_bubble_outline),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Material(
              color: AppColors.seaGreen,
              shape: const CircleBorder(),
              child: IconButton(
                onPressed: isSending ? null : onSend,
                icon: const Icon(
                  Icons.send,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}