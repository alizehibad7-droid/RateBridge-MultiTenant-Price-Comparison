import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/voice_search_service.dart';
import '../services/gemini_service.dart';
import '../models/voice_intent_model.dart';

class VoiceSearchButtonWidget extends StatefulWidget {
  final Function(String route, Map<String, dynamic> params)? onNavigate;
  final Function(String transcript)? onTranscriptRecognized;

  const VoiceSearchButtonWidget({
    this.onNavigate,
    this.onTranscriptRecognized,
    super.key,
  });

  @override
  State<VoiceSearchButtonWidget> createState() => _VoiceSearchButtonWidgetState();
}

class _VoiceSearchButtonWidgetState extends State<VoiceSearchButtonWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isListening = false;
  String _transcript = '';
  StreamSubscription? _partialSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)
    );

    final voiceService = context.read<VoiceSearchService>();
    _partialSub = voiceService.partialResults.listen((text) {
      setState(() => _transcript = text);
    });
    _stateSub = voiceService.listeningState.listen((listening) {
      setState(() => _isListening = listening);
      if (listening) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    });
  }

  Future<void> _toggleListening() async {
    final voiceService = context.read<VoiceSearchService>();
    const locale = 'en-US';

    if (_isListening) {
      final transcript = await voiceService.stopListening();
      if (transcript.isNotEmpty) {
        if (widget.onTranscriptRecognized != null) {
          widget.onTranscriptRecognized!(transcript);
        }
        
        if (widget.onNavigate != null) {
          final intent = await context.read<GeminiService>().parseVoiceIntent(transcript);
          _handleNavigation(intent);
        }
      }
    } else {
      try {
        await voiceService.startListening(locale);
      } catch(e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Microphone unavailable: ${e.toString()}')),
        );
      }
    }
  }

  void _handleNavigation(VoiceIntentModel intent) {
    if (widget.onNavigate == null) return;

    switch(intent.action) {
      case 'compare':
        widget.onNavigate!('/field/search', {'q': intent.material ?? '', 'action': 'compare'});
        break;
      case 'order':
        widget.onNavigate!('/field/search', {'q': intent.material ?? '', 'action': 'order', 'qty': intent.quantity ?? 0});
        break;
      case 'trend':
        widget.onNavigate!('/field/search', {'q': intent.material ?? '', 'action': 'trend'});
        break;
      case 'navigate':
        widget.onNavigate!('/field/home', {});
        break;
      default:
        widget.onNavigate!('/field/search', {'q': intent.material ?? ''});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _toggleListening,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (_, child) => Transform.scale(
              scale: _isListening ? _pulseAnimation.value : 1.0,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening ? Colors.red : Theme.of(context).primaryColor,
                  boxShadow: _isListening ? [
                    BoxShadow(color: Colors.red.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 4)
                  ] : [],
                ),
                child: Icon(
                  _isListening ? Icons.stop : Icons.mic,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
        if (_transcript.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _transcript,
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic,
                color: Theme.of(context).textTheme.bodySmall?.color),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _partialSub?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }
}
