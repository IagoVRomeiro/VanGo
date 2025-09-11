// screens/lista_motoristas_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart'; // Importe seu serviço

class ListaMotoristasScreen extends StatelessWidget {
  const ListaMotoristasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Motoristas Cadastrados'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestoreService().getMotoristasStream(), // Use o stream do seu serviço
        builder: (context, snapshot) {
          // Lida com erros
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }

          // Exibe um indicador de carregamento enquanto os dados são buscados
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Se não houver dados
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Nenhum motorista cadastrado ainda.'));
          }

          // Se houver dados, construa a lista
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              // Converte o documento para um mapa de dados
              Map<String, dynamic> data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              // O ID do documento pode ser útil para operações futuras (update/delete)
              String motoristaId = snapshot.data!.docs[index].id;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: ListTile(
                  title: Text(data['nome'] ?? 'Nome Desconhecido'),
                  subtitle: Text('Placa: ${data['placaVan'] ?? 'N/A'}\nUniversidade: ${data['universidade'] ?? 'N/A'}'),
                  trailing: Text('ID: $motoristaId'), // Exibe o ID do documento
                  onTap: () {
                    // Implemente a navegação para uma tela de detalhes ou edição
                    print('Clicou no motorista: ${data['nome']}');
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navegue para uma tela de cadastro de motorista
          // Navigator.push(context, MaterialPageRoute(builder: (context) => const CadastroMotoristaScreen()));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
