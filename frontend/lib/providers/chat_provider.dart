import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../core/services/supabase_service.dart';
import '../core/storage/local_storage_service.dart';
import '../core/constants/app_constants.dart';

class ChatProvider extends ChangeNotifier {
  final Map<String, List<ChatMessage>> _messagesByRide = {};

  List<ChatMessage> getMessagesForRide(String rideId) {
    final msgs = _messagesByRide[rideId] ?? [];
    msgs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return msgs;
  }

  void subscribeToRideChat(String rideId) {
    SupabaseService.subscribeToChat(rideId, onMessage: (message) => _onIncomingMessage(rideId, message));
    _loadMessages(rideId);
  }

  void unsubscribeFromChat() {
    SupabaseService.unsubscribeChat();
  }

  void _onIncomingMessage(String rideId, ChatMessage message) {
    final list = _messagesByRide.putIfAbsent(rideId, () => []);

    final existingIdx = list.indexWhere((m) => m.id == message.id);
    if (existingIdx >= 0) {
      list[existingIdx] = message;
    } else {
      // Replace the optimistic local copy of our own sent message (same
      // sender, same text, sent within ~30s) with the confirmed server row.
      final pendingIdx = list.indexWhere(
        (m) =>
            m.senderId == message.senderId &&
            m.message == message.message &&
            message.timestamp.difference(m.timestamp).inSeconds.abs() < 30,
      );
      if (pendingIdx >= 0) {
        list[pendingIdx] = message;
      } else {
        list.add(message);
      }
    }

    _saveToStorage();
    notifyListeners();
  }

  Future<void> _loadMessages(String rideId) async {
    try {
      final messages = await SupabaseService.fetchChatMessages(rideId);
      _messagesByRide[rideId] = messages;
      _saveToStorage();
      notifyListeners();
    } catch (e) {
      debugPrint('loadMessages error: $e');
    }
  }

  Future<void> sendMessage({
    required String rideId,
    required String senderId,
    required String senderName,
    required String message,
  }) async {
    if (message.trim().isEmpty) return;

    // Optimistic local copy so the message is visible even if the network
    // is slow; the realtime echo replaces it with the confirmed row.
    final pending = ChatMessage(
      id: 'pending_${DateTime.now().microsecondsSinceEpoch}',
      rideId: rideId,
      senderId: senderId,
      senderName: senderName,
      message: message.trim(),
    );
    _messagesByRide.putIfAbsent(rideId, () => []).add(pending);
    _saveToStorage();
    notifyListeners();

    try {
      await SupabaseService.sendChatMessage(
        rideId: rideId,
        senderId: senderId,
        senderName: senderName,
        body: message.trim(),
      );
    } catch (e) {
      debugPrint('sendMessage error: $e');
    }
  }

  Future<void> init() async {
    final storage = await LocalStorageService.getInstance();
    final messagesList = storage.getList(AppConstants.storageKeyChatMessages);
    for (final msgJson in messagesList) {
      final msg = ChatMessage.fromJson(Map<String, dynamic>.from(msgJson));
      _messagesByRide.putIfAbsent(msg.rideId, () => []);
      _messagesByRide[msg.rideId]!.add(msg);
    }
    notifyListeners();
  }

  Future<void> _saveToStorage() async {
    final storage = await LocalStorageService.getInstance();
    final allMessages = _messagesByRide.values.expand((list) => list).toList();
    await storage.saveList(AppConstants.storageKeyChatMessages, allMessages.map((m) => m.toJson()).toList());
  }
}
