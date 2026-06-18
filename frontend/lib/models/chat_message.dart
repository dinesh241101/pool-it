class ChatMessage {
  final String id;
  final String rideId;
  final String senderId;
  final String senderName;
  final String message;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.rideId,
    required this.senderId,
    required this.senderName,
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'rideId': rideId,
        'senderId': senderId,
        'senderName': senderName,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'],
        rideId: json['rideId'],
        senderId: json['senderId'],
        senderName: json['senderName'],
        message: json['message'],
        timestamp: DateTime.parse(json['timestamp']),
      );
}
