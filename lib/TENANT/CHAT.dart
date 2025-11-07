// TENANT/CHAT.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smart_finder/services/chat_service.dart';

class ChatScreenTenant extends StatefulWidget {
  final String conversationId;
  final String peerName;
  final String? peerAvatarUrl; // optional precomputed URL
  final String? landlordPhone;

  const ChatScreenTenant({
    super.key,
    required this.conversationId,
    required this.peerName,
    this.peerAvatarUrl,
    this.landlordPhone,
  });

  @override
  State<ChatScreenTenant> createState() => _ChatScreenTenantState();
}

class _ChatScreenTenantState extends State<ChatScreenTenant> {
  final _controller = TextEditingController();
  final _listController = ScrollController();

  late final SupabaseClient _sb;
  late final ChatService _chat;

  String? _landlordPhone;
  String? _avatarUrl; // resolved avatar (bucket)
  int _avatarVersion = 0; // cache-buster after edits (if any)

  bool _fetchingPhone = false;
  bool _fetchingHeader = false;

  Object? _editingMessageId;

  @override
  void initState() {
    super.initState();
    _sb = Supabase.instance.client;
    _chat = ChatService(_sb);

    _chat.markRead(conversationId: widget.conversationId, isLandlord: false);

    _landlordPhone = widget.landlordPhone;
    _avatarUrl = widget.peerAvatarUrl;

    // If either is missing, fetch from conversation parties & build avatar URL
    if (_landlordPhone == null || _landlordPhone!.trim().isEmpty) {
      _fetchPhone();
    }
    if (_avatarUrl == null || _avatarUrl!.trim().isEmpty) {
      _fetchHeaderAvatar();
    }
  }

  Future<void> _fetchHeaderAvatar() async {
    if (_fetchingHeader) return;
    setState(() => _fetchingHeader = true);
    try {
      final parties = await _chat.getConversationParties(widget.conversationId);
      final landlordId = parties['landlord_id'] as String?;
      if (landlordId != null) {
        final storage = _sb.storage.from('avatars');
        final jpg = storage.getPublicUrl('$landlordId.jpg');
        // (If you commonly store .png, change the next line to png)
        setState(() => _avatarUrl = '$jpg?v=$_avatarVersion');
      }
    } catch (_) {
      // ignore, we’ll show placeholder avatar
    } finally {
      if (mounted) setState(() => _fetchingHeader = false);
    }
  }

  Future<void> _fetchPhone() async {
    if (_fetchingPhone) return;
    setState(() => _fetchingPhone = true);
    try {
      final parties = await _chat.getConversationParties(widget.conversationId);
      final landlordId = parties['landlord_id'] as String?;
      if (landlordId != null) {
        final phone = await _chat.getLandlordPhone(landlordId);
        if (mounted) setState(() => _landlordPhone = phone);
      }
    } finally {
      if (mounted) setState(() => _fetchingPhone = false);
    }
  }

  String _fmtLocal(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      return DateFormat('hh:mm a').format(DateTime.parse(iso).toLocal());
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
        await _chat.updateMessage(messageId: _editingMessageId!, newBody: text);
        setState(() => _editingMessageId = null);
        _controller.clear();
      } else {
        await _chat.send(
          conversationId: widget.conversationId,
          senderId: me,
          body: text,
          viaSms: false,
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

  void _startEditing(Object messageId, String currentText) {
    setState(() {
      _editingMessageId = messageId;
      _controller.text = currentText;
    });
  }

  void _cancelEditing() {
    setState(() => _editingMessageId = null);
    _controller.clear();
  }

  Future<void> _openSmsWithDraft() async {
    final phone = _landlordPhone?.trim();
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Landlord phone not available.")),
      );
      return;
    }

    final draft = _controller.text.trim();

    final smsUri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {if (draft.isNotEmpty) 'body': draft},
    );
    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri, mode: LaunchMode.externalApplication);
      return;
    }

    final smsto = Uri(scheme: 'smsto', path: phone);
    if (await canLaunchUrl(smsto)) {
      await launchUrl(smsto, mode: LaunchMode.externalApplication);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Can't open SMS app for $phone")));
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
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child: ClipOval(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                      ? Image.network(
                          _avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.person, color: Colors.grey),
                        )
                      : const Icon(Icons.person, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.peerName,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              _landlordPhone ?? '',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
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
                  itemBuilder: (_, i) {
                    final m = data[i];
                    final isMe =
                        m['sender_user_id'] == me || m['sender_id'] == me;
                    final time = _fmtLocal(m['created_at']);
                    final isDeleted = (m['is_deleted'] ?? false) == true;
                    final wasEdited = (m['edited_at'] as String?) != null;

                    Widget bubble() {
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
                                      child: Text('Edit'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete'),
                                    ),
                                  ],
                                );
                                if (action == 'edit') {
                                  _startEditing(
                                    m['id'],
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
                                        messageId: m['id'],
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
                          child: bubble(),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          if (_editingMessageId != null)
            Container(
              color: const Color(0xFF4A2B20),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Edit message',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _cancelEditing,
                    borderRadius: BorderRadius.circular(20),
                    child: const CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _sendOrUpdate,
                    borderRadius: BorderRadius.circular(20),
                    child: const CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.check, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

          SafeArea(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.sms, color: Color(0xFF04395E)),
                    onPressed: _openSmsWithDraft,
                    tooltip: 'Open SMS app',
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: _editingMessageId != null
                            ? 'Update your message…'
                            : 'Type a message…',
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
                  CircleAvatar(
                    backgroundColor: const Color(0xFF04395E),
                    child: IconButton(
                      icon: Icon(
                        _editingMessageId != null ? Icons.check : Icons.send,
                        color: Colors.white,
                      ),
                      onPressed: _sendOrUpdate,
                      tooltip: _editingMessageId != null ? 'Save' : 'Send',
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
