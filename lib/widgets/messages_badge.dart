import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MessagesBadge extends StatelessWidget {
  final String? userId;
  final IconData icon;
  final double? size;

  const MessagesBadge({
    super.key,
    required this.userId,
    required this.icon,
    this.size,
  });

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream(String userId) {
    return FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final id = userId;
    if (id == null || id.isEmpty) {
      return Icon(icon, size: size);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream(id),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        var count = 0;

        for (final doc in docs) {
          final data = doc.data();
          final lastMessage = data['lastMessage'] as Map<String, dynamic>?;
          if (lastMessage == null) continue;
          final senderId = lastMessage['senderId'] as String?;
          final lastTimestamp = lastMessage['timestamp'] as Timestamp?;
          if (senderId == null || lastTimestamp == null) continue;
          if (senderId == id) continue;

          final lastReadMap =
              data['lastRead'] as Map<String, dynamic>? ?? const {};
          final lastReadTimestamp = lastReadMap[id] as Timestamp?;
          if (lastReadTimestamp == null ||
              lastReadTimestamp
                  .toDate()
                  .isBefore(lastTimestamp.toDate())) {
            count++;
          }
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, size: size),
            if (count > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count > 9 ? '9+' : count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
