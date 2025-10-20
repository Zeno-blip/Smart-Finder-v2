// TENANT/CHAT.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smart_finder/services/chat_service.dart';

class ChatScreenTenant extends StatefulWidget {
  final String conversationId;
  final String peerName;
  final String peerImageAsset;
  final String? landlordPhone; // optional, passed from startChatFromRoom

  const ChatScreenTenant({
    super.key,
    required this.conversationId,
    required this.peerName,
    required this.peerImageAsset,
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
  bool _fetchingPhone = false;

  // Helper: parse Supabase timestamp -> local (PH) time
  DateTime _parseToLocal(dynamic createdAt) {
    if (createdAt == null) return DateTime.now();
    try {
      // Supabase returns ISO8601 (UTC). Always convert to local.
      final dt = DateTime.parse(createdAt.toString());
      return dt.toLocal();
    } catch (_) {
      return DateTime.now();
    }
  }

  @override
  void initState() {
    super.initState();
    _sb = Supabase.instance.client;
    _chat = ChatService(_sb);

    // mark tenant read
    _chat.markRead(conversationId: widget.conversationId, isLandlord: false);

    // prefer the phone passed from the navigation, otherwise fetch
    _landlordPhone = widget.landlordPhone;
    if (_landlordPhone == null || _landlordPhone!.trim().isEmpty) {
      _fetchPhone();
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

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final me = _sb.auth.currentUser?.id;
    if (me == null) return;

    try {
      await _chat.send(
        conversationId: widget.conversationId,
        senderId: me,
        body: text,
        viaSms: false, // in-app send
      );
      _controller.clear();
      // Give realtime a moment, then jump to bottom
      await Future.delayed(const Duration(milliseconds: 120));
      if (_listController.hasClients) {
        _listController.jumpTo(_listController.position.maxScrollExtent);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Send failed: $e')));
    }
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

    // Primary: sms: scheme (Android supports 'body' as query)
    final smsUri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {if (draft.isNotEmpty) 'body': draft},
    );

    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri, mode: LaunchMode.externalApplication);
      return;
    }

    // Fallback: smsto: scheme (widely supported)
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
            CircleAvatar(backgroundImage: AssetImage(widget.peerImageAsset)),
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
                final data = snap.data ?? const [];

                // keep scrolled to bottom whenever new data lands
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

                    // >>> PH TIME FIX: always convert to local before formatting
                    final time = _parseToLocal(m['created_at']);

                    final isDeleted = (m['is_deleted'] ?? false) == true;
                    final editedAt = m['edited_at'] as String?;
                    final wasEdited = editedAt != null;

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
                                DateFormat('hh:mm a').format(time),
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
                                  final ctrl = TextEditingController(
                                    text: (m['body'] ?? '') as String,
                                  );
                                  final newText = await showDialog<String>(
                                    context: context,
                                    builder: (_) {
                                      return AlertDialog(
                                        title: const Text('Edit message'),
                                        content: TextField(
                                          controller: ctrl,
                                          autofocus: true,
                                          maxLines: null,
                                          decoration: const InputDecoration(
                                            hintText: 'Update message',
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(
                                              context,
                                              ctrl.text.trim(),
                                            ),
                                            child: const Text('Save'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                  if (newText != null && newText.isNotEmpty) {
                                    try {
                                      await _chat.updateMessage(
                                        messageId: (m['id'] as num).toInt(),
                                        newBody: newText,
                                      );
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('Edit failed: $e'),
                                        ),
                                      );
                                    }
                                  }
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
                          child: bubble(),
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
                  // SMS launcher
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
                        hintText: 'Type a message…',
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
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF04395E),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _send,
                      tooltip: 'Send',
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
