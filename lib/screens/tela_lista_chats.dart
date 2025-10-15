// lib/screens/tela_lista_chats.dart (VERSÃO COMPLETA E CORRIGIDA)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Imports relativos (supondo que já estejam corrigidos no seu projeto)
import '../models/aluno.dart';
import 'tela_chat.dart';

class TelaListaChats extends StatelessWidget {
  const TelaListaChats({super.key});

  @override
  Widget build(BuildContext context) {
    final motoristaId = FirebaseAuth.instance.currentUser?.uid;

    if (motoristaId == null) {
      return const Center(
        child: Text('Erro: Motorista não está logado.'),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: motoristaId)
          .orderBy('lastMessage.timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Nenhuma conversa encontrada.'));
        }

        final chats = snapshot.data!.docs;

        return ListView.builder(
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index];
            final participants = List<String>.from(chat['participants']);
            final alunoId = participants.firstWhere((id) => id != motoristaId);
            final lastMessage = chat['lastMessage'] as Map<String, dynamic>? ?? {};

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('alunos').doc(alunoId).get(),
              builder: (context, alunoSnapshot) {
                if (!alunoSnapshot.hasData) {
                  return const ListTile(title: Text('Carregando conversa...'));
                }

                if (!alunoSnapshot.data!.exists || alunoSnapshot.data!.data() == null) {
                  return const ListTile(title: Text('Aluno não encontrado'));
                }

                // ✅✅✅ A ÚNICA LINHA CORRIGIDA ESTÁ AQUI ✅✅✅
                // Passamos o ID do documento e os dados para o método fromMap.
                final aluno = Aluno.fromMap(
                  alunoSnapshot.data!.id,
                  alunoSnapshot.data!.data() as Map<String, dynamic>
                );
                
                final timestamp = lastMessage['timestamp'] as Timestamp?;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: aluno.fotoUrl != null && aluno.fotoUrl!.isNotEmpty
                          ? NetworkImage(aluno.fotoUrl!)
                          : null,
                      child: aluno.fotoUrl == null || aluno.fotoUrl!.isEmpty
                          ? Text(aluno.nome.isNotEmpty ? aluno.nome[0].toUpperCase() : '?')
                          : null,
                    ),
                    title: Text(aluno.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      lastMessage['texto'] ?? 'Nenhuma mensagem ainda.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      timestamp != null ? DateFormat('HH:mm').format(timestamp.toDate()) : '',
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TelaChat(
                            chatId: chat.id,
                            nomeReceptor: aluno.nome,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}