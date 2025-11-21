# VanGo 🚐

VanGo é um aplicativo Flutter projetado para modernizar e simplificar o gerenciamento de transporte escolar e universitário. Ele conecta motoristas, alunos e pais, oferecendo funcionalidades de rastreamento em tempo real, comunicação e gerenciamento de rotas.

## 🎯 Conceito e Objetivo

O VanGo busca resolver desafios comuns no transporte educacional, fornecendo uma plataforma digital intuitiva que melhora a segurança, a eficiência e a comunicação. O foco é em oferecer uma experiência fluida tanto para quem transporta (motoristas) quanto para quem é transportado (alunos).

## ✨ Funcionalidades Implementadas

### Para Motoristas
- **Gerenciamento de Perfil:** Os motoristas podem atualizar suas informações pessoais e detalhes da CNH.
- **Cadastro de Veículos:** Funcionalidade para registrar e gerenciar dados da van, incluindo fotos.
- **Criação e Gestão de Rotas:** Ferramentas para definir novas rotas, especificar destinos (faculdades), dias da semana e horários, além de permitir a edição de rotas existentes.
- **Vínculo e Gestão de Alunos:** Capacidade de convidar alunos, aceitar solicitações de vínculo e manter uma lista organizada de passageiros por rota.
- **Modo de Viagem Interativo:** Um sistema de mapa que, ao iniciar uma rota, traça um caminho otimizado para a coleta de alunos e, após a coleta, guia o motorista até o destino final (faculdade), com rastreamento GPS em tempo real.
- **Comunicação:** Um sistema de chat integrado para interação direta com os alunos vinculados.

### Para Alunos
- **Gerenciamento de Perfil:** Alunos podem manter suas informações pessoais e endereços atualizados, com sugestões de endereço via Google Places.
- **Busca Otimizada de Motoristas:** Interface para pesquisar motoristas por nome e por destino (faculdade), facilitando a localização de um transporte adequado.
- **Detalhes de Motoristas e Rotas:** Visualização completa dos perfis dos motoristas, incluindo avaliações, detalhes do veículo e informações sobre suas rotas.
- **Solicitação de Vínculo:** Processo simplificado para solicitar vínculo a um motorista.
- **Notificações:** Alertas em tempo real, por exemplo, quando o motorista inicia a rota.
- **Acompanhamento de Viagem:** Embora o acompanhamento em tempo real no mapa esteja em desenvolvimento, a estrutura para isso está pronta.

## ⚙️ Arquitetura e Tecnologias

O VanGo é construído utilizando **Flutter**, garantindo uma experiência nativa em múltiplas plataformas (Android, iOS e Web). A persistência de dados e a lógica de backend são gerenciadas pelo **Firebase**, utilizando:
- **Firebase Authentication:** Para gerenciamento de usuários.
- **Firestore Database:** Como banco de dados NoSQL para dados de aplicativo.
- **Firebase Storage:** Para armazenamento de imagens (fotos de perfil, fotos de van).
- **Firebase Cloud Functions:** Para lógica de backend e envio de notificações push.
- **Firebase Messaging (FCM):** Para sistema de notificações.
- **Google Maps Platform:** Integrado para funcionalidades de mapa, geolocalização e cálculo de rotas (Directions API, Places API).
- **Gerenciamento de Estado:** Utiliza `setState` para gerenciamento de estado local.

## 🔑 Configuração de Chaves de API

Para que as funcionalidades de mapa e rota funcionem, você precisa fornecer sua própria chave de API do Google Maps. O projeto está configurado para carregar as chaves de locais seguros que não são enviados para o controle de versão.

1.  **Chave para o Código Dart (Directions API, Places API):**
    -   Crie um arquivo na pasta `assets/` chamado `.env`.
    -   Dentro dele, adicione a seguinte linha, substituindo `SUA_CHAVE_AQUI`:
        ```
        GOOGLE_MAPS_API_KEY=SUA_CHAVE_AQUI
        ```

2.  **Chave para o Módulo Nativo Android (Google Maps SDK):**
    -   Crie um arquivo na pasta `android/` chamado `local.properties`.
    -   Dentro dele, adicione a seguinte linha, substituindo `SUA_CHAVE_AQUI`:
        ```
        maps.apiKey=SUA_CHAVE_AQUI
        ```
