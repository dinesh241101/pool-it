import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../core/storage/local_storage_service.dart';
import '../core/constants/app_constants.dart';

class ChatProvider extends ChangeNotifier {
  List<ChatMessage> _messages = [];
  final _uuid = const Uuid();

  List<ChatMessage> get messages => _messages;

  List<ChatMessage> getMessagesForRide(String rideId) {
    final msgs = _messages.where((m) => m.rideId == rideId).toList();
    msgs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return msgs;
  }

  Future<void> init() async {
    final storage = await LocalStorageService.getInstance();
    final messagesList = storage.getList(AppConstants.storageKeyChatMessages);
    _messages = messagesList
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
    notifyListeners();
  }

  Future<void> sendMessage({
    required String rideId,
    required String senderId,
    required String senderName,
    required String message,
  }) async {
    if (message.trim().isEmpty) return;
    final msg = ChatMessage(
      id: _uuid.v4(),
      rideId: rideId,
      senderId: senderId,
      senderName: senderName,
      message: message.trim(),
    );
    _messages.add(msg);
    await _saveToStorage();
    notifyListeners();
  }

  Future<void> _saveToStorage() async {
    final storage = await LocalStorageService.getInstance();
    await storage.saveList(
      AppConstants.storageKeyChatMessages,
      _messages.map((m) => m.toJson()).toList(),
    );
  }
}
