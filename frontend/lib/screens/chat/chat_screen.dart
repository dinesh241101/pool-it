import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../models/ride_model.dart';
import '../../models/chat_message.dart';
import '../../core/theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  final RideModel ride;
  final String chatPartnerName;
  final String chatPartnerId;

  const ChatScreen({
    super.key,
    required this.ride,
    required this.chatPartnerName,
    required this.chatPartnerId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _isCompleted = widget.ride.status == 'completed';
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;
    final auth = context.read<AuthProvider>();
    final chatProv = context.read<ChatProvider>();
    chatProv.sendMessage(
      rideId: widget.ride.id,
      senderId: auth.currentUser!.id,
      senderName: auth.currentUser!.name,
      message: _messageController.text.trim(),
    );
    _messageController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  Widget build(BuildContext context) {
    final chatProv = context.watch<ChatProvider>();
    final messages = chatProv.getMessagesForRide(widget.ride.id);
    final auth = context.watch<AuthProvider>();
    final currentUserId = auth.currentUser?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: Text(
                widget.chatPartnerName.isNotEmpty
                    ? widget.chatPartnerName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.chatPartnerName,
                    style: const TextStyle(fontSize: 16)),
                Text(
                  '${widget.ride.source} → ${widget.ride.destination}',
                  style: TextStyle(
                      fontSize: 11, color: Colors.white.withValues(alpha: 0.7)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_isCompleted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.green.shade50,
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      size: 16, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  const Text('Ride completed. Viewing chat history.',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 48, color: AppTheme.textSecondary),
                        const SizedBox(height: 12),
                        Text(
                          _isCompleted
                              ? 'No messages in this ride'
                              : 'Start chatting with ${widget.chatPartnerName}',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg.senderId == currentUserId;
                      return _MessageBubble(
                        message: msg,
                        isMe: isMe,
                        showName: !isMe,
                      );
                    },
                  ),
          ),
          if (!_isCompleted)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppTheme.primaryColor,
                      child: IconButton(
                        icon: const Icon(Icons.send, size: 18, color: Colors.white),
                        onPressed: _sendMessage,
                        padding: EdgeInsets.zero,
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

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool showName;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    this.showName = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (showName)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 12, bottom: 2),
            child: Text(
              message.senderName,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isMe ? AppTheme.primaryColor : Colors.grey.shade200,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                message.message,
                style: TextStyle(
                  fontSize: 15,
                  color: isMe ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 10,
                  color: isMe ? Colors.white.withValues(alpha: 0.7) : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
