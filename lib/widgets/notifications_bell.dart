import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/usuario.dart';

class NotificationsBell extends StatelessWidget {
  final UserRole role;
  final String userId;
  final VoidCallback onPressed;

  const NotificationsBell({
    super.key,
    required this.role,
    required this.userId,
    required this.onPressed,
  });

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    final collection = FirebaseFirestore.instance.collection('contratos');
    if (role == UserRole.motorista) {
      return collection
          .where('motoristaId', isEqualTo: userId)
          .where('status', isEqualTo: 'pendente')
          .snapshots();
    }
    return collection
        .where('alunoId', isEqualTo: userId)
        .where('status', isEqualTo: 'convite_motorista')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: onPressed,
            ),
            if (count > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    count.toString(),
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
