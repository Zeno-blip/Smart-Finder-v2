import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_finder/services/chat_service.dart';

class LandlordChatScreen extends StatefulWidget {
  final String conversationId;
  final String peerName;

  /// Preferred: full network URL for the peer’s avatar.
  final String? peerAvatarUrl;

  /// Legacy: asset path (kept for backward compatibility).
  final String? peerImageAsset;

  const LandlordChatScreen({
    super.key,
    required this.conversationId,
    required this.peerName,
    this.peerAvatarUrl,
    this.peerImageAsset,
  });

  @override
  State<LandlordChatScreen> createState() => _LandlordChatScreenState();
}

class _LandlordChatScreenState extends State<LandlordChatScreen> {
  final _controller = TextEditingController();
  final _listController = ScrollController();

  late final SupabaseClient _sb;
  late final ChatService _chat;

  /// Debounce guard to prevent double-sends.
  bool _sending = false;

  /// When editing a message, holds its id (uuid/int).
  Object? _editingMessageId;

  /// Cache of userId -> avatar URL (network).
  final Map<String, String> _avatarCache = {};

  /// Current user info
  String _meId = '';
  String _meName = 'You';
  String? _myAvatarUrl;

  /// Peer avatar (header). For bubbles we resolve by sender id.
  ImageProvider get _peerHeaderAvatar {
    if ((widget.peerAvatarUrl ?? '').startsWith('http')) {
      return NetworkImage(widget.peerAvatarUrl!);
    }
    if ((widget.peerImageAsset ?? '').isNotEmpty) {
      return AssetImage(widget.peerImageAsset!);
    }
    // fallback asset
    return const AssetImage('assets/images/mykel.png');
  }

  @override
  void initState() {
    super.initState();
    _sb = Supabase.instance.client;
    _chat = ChatService(_sb);

    _meId = _sb.auth.currentUser?.id ?? '';
    _chat.markRead(conversationId: widget.conversationId, isLandlord: true);

    _loadMyName();
    _primeMyAvatar();
  }

  Future<void> _loadMyName() async {
    if (_meId.isEmpty) return;
    try {
      final row = await _sb
          .from('users')
          .select('full_name, first_name, last_name')
          .eq('id', _meId)
          .maybeSingle();
      if (!mounted || row == null) return;
      final full =
          (row['full_name'] ??
                  '${row['first_name'] ?? ''} ${row['last_name'] ?? ''}')
              .toString()
              .trim();
      if (full.isNotEmpty) setState(() => _meName = full);
    } catch (_) {
      /* no-op */
    }
  }

  Future<void> _primeMyAvatar() async {
    if (_meId.isEmpty) return;
    _myAvatarUrl = _avatarUrlFor(_meId);
    _avatarCache[_meId] = _myAvatarUrl!;
    setState(() {});
  }

  /// Build a public URL for a user avatar stored in the `avatars` bucket.
  /// We return `<id>.jpg` (preferred) and if you’d rather PNG, swap order.
  String _avatarUrlFor(String userId) {
    final storage = _sb.storage.from('avatars');
    final jpg = storage.getPublicUrl('$userId.jpg');
    final png = storage.getPublicUrl('$userId.png');
    // We can’t probe existence cheaply here, so prefer jpg and the Image widget
    // will show an errorBuilder icon if it 404s.
    return jpg.isNotEmpty ? jpg : png;
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

    // Debounce: ignore while an in-flight send/update exists.
    if (_sending) return;
    _sending = true;

    try {
      if (_editingMessageId != null) {
        await _chat.updateMessage(messageId: _editingMessageId!, newBody: text);
        if (!mounted) return;
        setState(() => _editingMessageId = null);
        _controller.clear();
      } else {
        await _chat.send(
          conversationId: widget.conversationId,
          senderId: _meId,
          body: text,
        );
        _controller.clear();

        // Scroll to bottom after slight delay so new item is laid out
        await Future.delayed(const Duration(milliseconds: 140));
        if (_listController.hasClients) {
          _listController.jumpTo(_listController.position.maxScrollExtent);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Action failed: $e')));
    } finally {
      _sending = false;
      if (mounted) setState(() {});
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

  /// Avatar widget for a given user id (uses cache).
  Widget _bubbleAvatar(String userId, {double size = 28}) {
    final url = _avatarCache[userId] ?? _avatarUrlFor(userId);
    _avatarCache[userId] = url;

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Colors.white,
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.person, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF04395E),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            CircleAvatar(backgroundImage: _peerHeaderAvatar),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.peerName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                overflow: TextOverflow.ellipsis,
              ),
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
                    final senderId =
                        (m['sender_user_id'] ?? m['sender_id'])?.toString() ??
                        '';
                    final isMe = senderId == _meId;
                    final time = _fmtLocal(m['created_at']);
                    final isDeleted = (m['is_deleted'] ?? false) == true;
                    final wasEdited = (m['edited_at'] as String?) != null;

                    // Capture long-press position so the popup anchors
                    Offset? pressPosition;

                    Widget messageBubble() {
                      final content = isDeleted
                          ? Text(
                              'Message deleted',
                              style: TextStyle(
                                color: isMe ? Colors.white70 : Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            )
                          : Column(
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
                                          color: isMe
                                              ? Colors.white70
                                              : Colors.grey,
                                          fontStyle: FontStyle.italic,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            );

                      return GestureDetector(
                        onLongPressStart: isMe && !isDeleted
                            ? (details) async {
                                pressPosition = details.globalPosition;

                                // Compute menu position next to the bubble
                                final overlay =
                                    Overlay.of(
                                          context,
                                        ).context.findRenderObject()
                                        as RenderBox;
                                final offset = pressPosition!;
                                final rr = RelativeRect.fromLTRB(
                                  offset.dx,
                                  offset.dy,
                                  overlay.size.width - offset.dx,
                                  overlay.size.height - offset.dy,
                                );

                                final action = await showMenu<String>(
                                  context: context,
                                  position: rr,
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
                            maxWidth: MediaQuery.of(context).size.width * 0.72,
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
                          child: content,
                        ),
                      );
                    }

                    // Row with avatar + bubble
                    final row = Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: isMe
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      children: isMe
                          ? [
                              // my bubble, then my avatar on the right
                              Flexible(child: messageBubble()),
                              const SizedBox(width: 8),
                              _bubbleAvatar(_meId),
                            ]
                          : [
                              // peer avatar, then their bubble
                              _bubbleAvatar(senderId),
                              const SizedBox(width: 8),
                              Flexible(child: messageBubble()),
                            ],
                    );

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: row,
                    );
                  },
                );
              },
            ),
          ),

          // White edit bar
          if (_editingMessageId != null)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.edit, color: Colors.black54),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Edit message',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _cancelEditing,
                    borderRadius: BorderRadius.circular(20),
                    child: const CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(0xFFECECEC),
                      child: Icon(Icons.close, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _sendOrUpdate,
                    borderRadius: BorderRadius.circular(20),
                    child: const CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(0xFFECECEC),
                      child: Icon(Icons.check, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),

          // Composer
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
                      onPressed: _sending ? null : _sendOrUpdate,
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
