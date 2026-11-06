class ChatMessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String? mediaUrl;
  final String type; // 'text', 'image', 'audio', 'gift'

  ChatMessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.mediaUrl,
    this.type = 'text',
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    final senderObj = json['sender'] ?? json['senderId'] ?? json['sender_id'] ?? json['from'] ?? json['user'];
    final sId = (senderObj is Map)
        ? (senderObj['_id']?.toString() ?? senderObj['id']?.toString() ?? senderObj['userId']?.toString() ?? '')
        : (senderObj?.toString() ?? '');

    final receiverObj = json['receiver'] ?? json['receiverId'] ?? json['receiver_id'] ?? json['to'];
    final rId = (receiverObj is Map)
        ? (receiverObj['_id']?.toString() ?? receiverObj['id']?.toString() ?? receiverObj['userId']?.toString() ?? '')
        : (receiverObj?.toString() ?? '');

    final text = json['content']?.toString() ??
        json['message']?.toString() ??
        json['text']?.toString() ??
        '';

    DateTime parseToLocal(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val.toLocal();
      final str = val.toString().trim();
      if (str.isEmpty) return DateTime.now();
      try {
        String s = str;
        if (!s.endsWith('Z') && !s.contains('+') && !RegExp(r'-\d{2}:\d{2}$').hasMatch(s)) {
          s = '${s}Z';
        }
        final parsed = DateTime.tryParse(s) ?? DateTime.tryParse(str) ?? DateTime.now();
        return parsed.toLocal();
      } catch (_) {
        return DateTime.now();
      }
    }

    DateTime time = DateTime.now();
    if (json['createdAt'] != null) {
      time = parseToLocal(json['createdAt']);
    } else if (json['timestamp'] != null) {
      time = parseToLocal(json['timestamp']);
    }

    return ChatMessageModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      senderId: sId,
      receiverId: rId,
      message: text,
      timestamp: time,
      isRead: json['isRead'] == true,
      mediaUrl: json['mediaUrl']?.toString(),
      type: json['mediaType']?.toString() ?? json['type']?.toString() ?? 'text',
    );
  }


  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'mediaUrl': mediaUrl,
      'type': type,
    };
  }
}
