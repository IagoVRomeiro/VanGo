// lib/screens/tela_lista_chats.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vango/models/aluno.dart';
import 'package:vango/screens/tela_chat.dart';

class TelaListaChats extends StatelessWidget {
  const TelaListaChats({super.key});

  @override
  Widget build(BuildContext context) {
    final motoristaId = FirebaseAuth.instance.currentUser?.uid;

    // Caso de segurança se o motorista não estiver logado
    if (motoristaId == null) {
      return const Center(
        child: Text('Erro: Motorista não está logado.'),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      // 1. Ouve a coleção 'chats' em tempo real
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: motoristaId) // Busca só os chats do motorista
          .orderBy('lastMessage.timestamp', descending: true) // Ordena pelos mais recentes
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
            
            // 2. Usa um FutureBuilder para buscar o nome do aluno (só uma vez por item)
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('alunos').doc(alunoId).get(),
              builder: (context, alunoSnapshot) {
                if (!alunoSnapshot.hasData) {
                  return const ListTile(title: Text('Carregando conversa...'));
                }
                
                if (!alunoSnapshot.data!.exists) {
                  return const ListTile(title: Text('Aluno não encontrado'));
                }

                final aluno = Aluno.fromMap(alunoSnapshot.data!.data() as Map<String, dynamic>);
                final timestamp = lastMessage['timestamp'] as Timestamp?;
                
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(aluno.nome.isNotEmpty ? aluno.nome[0].toUpperCase() : '?'),
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
                      // 3. Navega para a tela de chat individual
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