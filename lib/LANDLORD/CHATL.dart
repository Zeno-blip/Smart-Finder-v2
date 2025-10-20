import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_finder/services/chat_service.dart';

class LandlordChatScreen extends StatefulWidget {
  final String conversationId;
  final String peerName;
  final String peerImageAsset;

  const LandlordChatScreen({
    super.key,
    required this.conversationId,
    required this.peerName,
    required this.peerImageAsset,
  });

  @override
  State<LandlordChatScreen> createState() => _LandlordChatScreenState();
}

class _LandlordChatScreenState extends State<LandlordChatScreen> {
  final _controller = TextEditingController();
  final _listController = ScrollController();
  late final SupabaseClient _sb;
  late final ChatService _chat;

  int? _editingMessageId; // ID of message being edited

  @override
  void initState() {
    super.initState();
    _sb = Supabase.instance.client;
    _chat = ChatService(_sb);
    _chat.markRead(conversationId: widget.conversationId, isLandlord: true);
  }

  String _fmtLocal(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  Future<void> _sendOrUpdate() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final me = _sb.auth.currentUser?.id;
    if (me == null) return;

    try {
      if (_editingMessageId != null) {
        // update existing
        await _chat.updateMessage(messageId: _editingMessageId!, newBody: text);
        setState(() => _editingMessageId = null);
        _controller.clear();
      } else {
        // send new
        await _chat.send(
          conversationId: widget.conversationId,
          senderId: me,
          body: text,
        );
        _controller.clear();
        await Future.delayed(const Duration(milliseconds: 120));
        if (_listController.hasClients) {
          _listController.jumpTo(_listController.position.maxScrollExtent);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Action failed: $e')));
    }
  }

  void _startEditing(int messageId, String currentText) {
    setState(() {
      _editingMessageId = messageId;
      _controller.text = currentText;
    });
  }

  void _cancelEditing() {
    setState(() => _editingMessageId = null);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final me = _sb.auth.currentUser?.id ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF04395E),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            CircleAvatar(backgroundImage: AssetImage(widget.peerImageAsset)),
            const SizedBox(width: 10),
            Text(
              widget.peerName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _chat.streamMessages(widget.conversationId),
              builder: (context, snap) {
                final data = List<Map<String, dynamic>>.from(
                  snap.data ?? const [],
                );
                data.sort((a, b) {
                  final aT =
                      DateTime.tryParse(a['created_at'] ?? '') ??
                      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
                  final bT =
                      DateTime.tryParse(b['created_at'] ?? '') ??
                      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
                  return aT.compareTo(bT);
                });

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_listController.hasClients) {
                    _listController.jumpTo(
                      _listController.position.maxScrollExtent,
                    );
                  }
                });

                return ListView.builder(
                  controller: _listController,
                  padding: const EdgeInsets.all(10),
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final m = data[index];
                    final isMe = m['sender_user_id'] == me;
                    final time = _fmtLocal(m['created_at']);
                    final isDeleted = (m['is_deleted'] ?? false) == true;
                    final wasEdited = (m['edited_at'] as String?) != null;

                    Widget bubbleContent() {
                      if (isDeleted) {
                        return Text(
                          'Message deleted',
                          style: TextStyle(
                            color: isMe ? Colors.white70 : Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        );
                      }
                      return Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Text(
                            (m['body'] ?? '') as String,
                            style: TextStyle(
                              color: isMe ? Colors.white : Colors.black87,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                time,
                                style: TextStyle(
                                  color: isMe
                                      ? Colors.white70
                                      : Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                              if (wasEdited) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '(edited)',
                                  style: TextStyle(
                                    color: isMe ? Colors.white70 : Colors.grey,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      );
                    }

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: GestureDetector(
                        onLongPress: isMe && !isDeleted
                            ? () async {
                                final action = await showMenu<String>(
                                  context: context,
                                  position: const RelativeRect.fromLTRB(
                                    200,
                                    300,
                                    20,
                                    0,
                                  ),
                                  items: const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit inline'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete'),
                                    ),
                                  ],
                                );

                                if (action == 'edit') {
                                  _startEditing(
                                    (m['id'] as num).toInt(),
                                    (m['body'] ?? '') as String,
                                  );
                                } else if (action == 'delete') {
                                  final sure = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Delete message?'),
                                      content: const Text(
                                        'This will delete the message for everyone.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (sure == true) {
                                    try {
                                      await _chat.softDeleteMessage(
                                        messageId: (m['id'] as num).toInt(),
                                      );
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('Delete failed: $e'),
                                        ),
                                      );
                                    }
                                  }
                                }
                              }
                            : null,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            color: isMe
                                ? const Color(0xFF04395E)
                                : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(isMe ? 16 : 0),
                              bottomRight: Radius.circular(isMe ? 0 : 16),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: bubbleContent(),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: _editingMessageId != null
                            ? 'Editing message...'
                            : 'Type a message...',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendOrUpdate(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_editingMessageId != null)
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: _cancelEditing,
                          tooltip: 'Cancel edit',
                        ),
                        CircleAvatar(
                          backgroundColor: const Color(0xFF04395E),
                          child: IconButton(
                            icon: const Icon(Icons.check, color: Colors.white),
                            onPressed: _sendOrUpdate,
                            tooltip: 'Save edit',
                          ),
                        ),
                      ],
                    )
                  else
                    CircleAvatar(
                      backgroundColor: const Color(0xFF04395E),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: _sendOrUpdate,
                        tooltip: 'Send message',
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
