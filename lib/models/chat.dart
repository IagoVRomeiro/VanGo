import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatStatus {
  active,
  inquiry,
  archived;

  static ChatStatus fromString(String? status) {
    return ChatStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => ChatStatus.inquiry,
    );
  }
}

class Chat {
  final String id;
  final List<String> participants;
  final String alunoId;
  final String motoristaId;
  final String pairKey;
  final ChatStatus status;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final Map<String, dynamic> lastMessage;
  final Map<String, int> unreadCount;
  final Map<String, Timestamp> lastRead;

  Chat({
    required this.id,
    required this.participants,
    required this.alunoId,
    required this.motoristaId,
    required this.pairKey,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.lastMessage,
    required this.unreadCount,
    required this.lastRead,
  });

  factory Chat.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data()!;
    final unreadCountData = data['unreadCount'] as Map<String, dynamic>? ?? {};
    final lastReadData = data['lastRead'] as Map<String, dynamic>? ?? {};

    return Chat(
      id: snapshot.id,
      participants: List<String>.from(data['participants'] ?? []),
      alunoId: data['alunoId'] ?? '',
      motoristaId: data['motoristaId'] ?? '',
      pairKey: data['pairKey'] ?? '',
      status: ChatStatus.fromString(data['status']),
      createdAt: data['createdAt'],
      updatedAt: data['updatedAt'],
      lastMessage: Map<String, dynamic>.from(data['lastMessage'] ?? {}),
      unreadCount: unreadCountData.map((key, value) => MapEntry(key, value as int)),
      lastRead: lastReadData.map((key, value) => MapEntry(key, value as Timestamp)),
    );
  }
}
