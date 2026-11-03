import 'package:flutter/material.dart';

import '../models/assistant.dart';
import '../services/areas_store.dart';
import '../services/community_store.dart';
import '../theme.dart';
import 'ghars_logo.dart';

class ChatMessage {
  ChatMessage.user(this.text)
      : isUser = true,
        reply = null;
  ChatMessage.assistant(AssistantReply this.reply)
      : text = reply.text,
        isUser = false;

  final String text;
  final bool isUser;
  final AssistantReply? reply;
}

/// نافذة غَرْس، المساعد البيئي؛ الرسائل محفوظة عند الأب حتى تبقى بعد إغلاق النافذة
class AssistantSheet extends StatefulWidget {
  const AssistantSheet({
    super.key,
    required this.messages,
    required this.onShowArea,
    required this.onShowSite,
  });

  final List<ChatMessage> messages;
  final void Function(int areaId) onShowArea;
  final void Function(int siteId) onShowSite;

  @override
  State<AssistantSheet> createState() => _AssistantSheetState();
}

class _AssistantSheetState extends State<AssistantSheet> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _ask(String question) {
    final q = question.trim();
    if (q.isEmpty) return;
    final assistant = Assistant(AreasScope.of(context), CommunityScope.of(context).campaigns);
    setState(() {
      widget.messages
        ..add(ChatMessage.user(q))
        ..add(ChatMessage.assistant(assistant.answer(q)));
      _input.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.messages;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Row(children: [
              GharsLogo(size: 52),
              SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('غَرْس',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ZillColors.greenDark)),
                  Text('مساعد ظِلّ البيئي. يجيب من بيانات المنصة فقط.',
                      style: TextStyle(fontSize: 13, color: ZillColors.muted)),
                ]),
              ),
            ]),
          ),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              children: [
                if (messages.isEmpty) ...[
                  const Text('أهلاً، أنا غَرْس. اسألني عن حرارة مناطق بغداد وأماكن التشجير فيها.',
                      style: TextStyle(height: 1.6)),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final e in assistantExamples)
                      ActionChip(label: Text(e), onPressed: () => _ask(e)),
                  ]),
                ],
                for (final m in messages) _bubble(m),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _ask,
                  decoration: InputDecoration(
                    hintText: 'اكتب سؤالك…',
                    filled: true,
                    fillColor: ZillColors.grayLight,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () => _ask(_input.text),
                icon: const Icon(Icons.send),
                tooltip: 'إرسال',
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _bubble(ChatMessage m) {
    final reply = m.reply;
    final bubble = Flexible(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: m.isUser ? ZillColors.greenLight : ZillColors.grayLight,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SelectableText(m.text, style: const TextStyle(height: 1.6)),
          if (reply?.areaId != null || reply?.siteId != null)
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                if (reply!.siteId != null) {
                  widget.onShowSite(reply.siteId!);
                } else {
                  widget.onShowArea(reply.areaId!);
                }
              },
              icon: const Icon(Icons.place_outlined, size: 18),
              label: const Text('عرض على الخريطة'),
              style: TextButton.styleFrom(foregroundColor: ZillColors.green),
            ),
        ]),
      ),
    );
    return Row(
      mainAxisAlignment: m.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!m.isUser) ...[const GharsLogo(size: 32), const SizedBox(width: 8)],
        bubble,
      ],
    );
  }
}
