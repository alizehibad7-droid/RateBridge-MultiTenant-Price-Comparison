import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/field_theme.dart';
import '../services/ai_context_service.dart';
import '../services/gemini_service.dart';

class _ChatMsg {
  final String text;
  final bool isUser;
  _ChatMsg(this.text, this.isUser);
}

class AiAssistantSheet extends StatefulWidget {
  const AiAssistantSheet({super.key});

  @override
  State<AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _AiAssistantSheetState extends State<AiAssistantSheet> {
  final List<_ChatMsg> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  ScrollController? _listScrollController;
  bool _isResponding = false;

  String _screenLabel(String key) {
    switch (key) {
      case 'compare':
        return 'Price Comparison';
      case 'price_trend':
        return 'Price Trends';
      case 'orders':
        return 'My Orders';
      case 'marketplace':
        return 'Marketplace';
      default:
        return 'Home Dashboard';
    }
  }

  List<String> _suggestedQuestions(String screen) {
    switch (screen) {
      case 'compare':
        return ['Why is this the best price?', 'Compare quality'];
      case 'price_trend':
        return ['Explain this trend', 'Should I buy now?'];
      case 'orders':
        return ['How do I track my order?'];
      default:
        return ['How does RateBridge work?', 'How do I place an order?'];
    }
  }

  Future<void> _send(String question) async {
    if (question.trim().isEmpty || _isResponding) return;
    final ctx = context.read<AiContextService>();

    setState(() {
      _messages.add(_ChatMsg(question.trim(), true));
      _isResponding = true;
      _inputController.clear();
    });
    _scrollToBottom();

    try {
      final response = await context
          .read<GeminiService>()
          .askAssistant(
            question.trim(),
            ctx.currentScreenName,
            ctx.currentScreenData,
          )
          .timeout(const Duration(seconds: 45));

      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMsg(
          response.trim().isEmpty
              ? "Sorry, I couldn't process that. Please try again."
              : response.trim(),
          false,
        ));
        _isResponding = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMsg(
          "Sorry, I couldn't process that. Please try again.",
          false,
        ));
        _isResponding = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = _listScrollController;
      if (controller != null && controller.hasClients) {
        controller.animateTo(
          controller.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = context.watch<AiContextService>();
    final screenLabel = _screenLabel(ctx.currentScreenName);
    final suggestions = _suggestedQuestions(ctx.currentScreenName);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        _listScrollController = scrollController;
        return Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: FieldColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: FieldColors.primaryNavy,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'RateBridge Assistant',
                            style: FieldTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: FieldColors.primaryNavy,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'Helping with: $screenLabel',
                            style: FieldTypography.bodyMedium.copyWith(
                              fontSize: 11,
                              color: FieldColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: FieldColors.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              if (_messages.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: suggestions
                          .map((q) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ActionChip(
                                  label: Text(q,
                                      style: const TextStyle(fontSize: 12)),
                                  backgroundColor: FieldColors.accentAmber
                                      .withValues(alpha: 0.12),
                                  onPressed: () => _send(q),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length + (_isResponding ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length && _isResponding) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: FieldColors.borderSubtle,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const SizedBox(
                            width: 30,
                            child: Text('...'),
                          ),
                        ),
                      );
                    }
                    final msg = _messages[index];
                    return Align(
                      alignment: msg.isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: msg.isUser
                              ? FieldColors.accentAmber
                              : FieldColors.borderSubtle,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          msg.text,
                          style: TextStyle(
                            color: msg.isUser
                                ? Colors.white
                                : FieldColors.primaryNavy,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          decoration: InputDecoration(
                            hintText: 'Ask anything about RateBridge...',
                            filled: true,
                            fillColor: FieldColors.screenBackground,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: _send,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _isResponding
                            ? null
                            : () => _send(_inputController.text),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _isResponding
                                ? FieldColors.borderSubtle
                                : FieldColors.accentAmber,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_upward,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
