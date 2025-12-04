import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();
const functionsUs = functions.region("us-central1");
type CallableCtx = functions.https.CallableContext;

/**
 * Cloud Function para um motorista convidar um aluno.
 */
export const enviarConvite = functionsUs.https.onCall(async (data, context) => {
    // 1. Autenticação e validação de entrada
    if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "A função só pode ser chamada por um usuário autenticado."
        );
    }
    const motoristaId = context.auth.uid;
    const emailAluno = typeof data.email === "string" ? data.email.trim() : null;

    if (!emailAluno) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "O email do aluno é obrigatório."
        );
    }

    try {
        const emailLower = emailAluno.toLowerCase();
        let alunoDocId: string | null = null;

        // 2. Encontrar o aluno pelo email na coleção de usuários
        let userQuery = await db
            .collection("users")
            .where("email", "==", emailAluno)
            .where("role", "==", "aluno")
            .limit(1)
            .get();

        if (userQuery.empty && emailLower !== emailAluno) {
            userQuery = await db
                .collection("users")
                .where("email", "==", emailLower)
                .where("role", "==", "aluno")
                .limit(1)
                .get();
        }

        if (!userQuery.empty) {
            alunoDocId = userQuery.docs[0].id;
        } else {
            // Tenta localizar na coleção 'alunos' (caso ainda não exista em 'users')
            const alunoQuery = await db
                .collection("alunos")
                .where("email", "==", emailAluno)
                .limit(1)
                .get();

            if (!alunoQuery.empty) {
                alunoDocId = alunoQuery.docs[0].id;
            }
        }

        if (!alunoDocId) {
            throw new functions.https.HttpsError(
                "not-found",
                "Nenhum aluno encontrado com este email."
            );
        }
        const alunoId = alunoDocId;

        // 3. Verificar se o aluno já está vinculado ao motorista
        const motoristaDoc = await db.collection("motoristas").doc(motoristaId).get();
        const motoristaData = motoristaDoc.data();
        if (motoristaData?.alunosIds?.includes(alunoId)) {
            throw new functions.https.HttpsError(
                "already-exists",
                "Este aluno já está vinculado a você."
            );
        }

        // 4. Verificar se já existe um contrato pendente ou convite
        const contratoQuery = await db
            .collection("contratos")
            .where("motoristaId", "==", motoristaId)
            .where("alunoId", "==", alunoId)
            .where("status", "in", ["pendente", "convite_motorista"])
            .limit(1)
            .get();

        if (!contratoQuery.empty) {
            throw new functions.https.HttpsError(
                "already-exists",
                "Um convite ou solicitação para este aluno já existe."
            );
        }

        // 5. Criar o novo contrato (convite)
        await db.collection("contratos").add({
            motoristaId: motoristaId,
            alunoId: alunoId,
            status: "convite_motorista",
            dataSolicitacao: admin.firestore.FieldValue.serverTimestamp(),
        });

        return { success: true, message: "Convite enviado com sucesso!" };
    } catch (error) {
        console.error("Erro ao enviar convite:", error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError(
            "unknown",
            "Ocorreu um erro inesperado ao enviar o convite."
        );
    }
});

/**
 * Cloud Function para o aluno aceitar um convite enviado por um motorista.
 */
export const aceitarConviteAluno = functionsUs.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "A função só pode ser chamada por um usuário autenticado."
        );
    }

    const alunoId = context.auth.uid;
    const contratoId = typeof data.contratoId === "string" ? data.contratoId : null;
    const motoristaId = typeof data.motoristaId === "string" ? data.motoristaId : null;

    if (!contratoId || !motoristaId) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "Os campos contratoId e motoristaId são obrigatórios."
        );
    }

    try {
        await db.runTransaction(async (transaction) => {
            const contratoRef = db.collection("contratos").doc(contratoId);
            const contratoSnap = await transaction.get(contratoRef);
            if (!contratoSnap.exists) {
                throw new functions.https.HttpsError(
                    "not-found",
                    "Convite não encontrado."
                );
            }

            const contratoData = contratoSnap.data();
            if (!contratoData) {
                throw new functions.https.HttpsError(
                    "not-found",
                    "Dados do convite não encontrados."
                );
            }

            if (contratoData.alunoId !== alunoId || contratoData.motoristaId !== motoristaId) {
                throw new functions.https.HttpsError(
                    "permission-denied",
                    "Você não pode aceitar este convite."
                );
            }

            if (contratoData.status !== "convite_motorista") {
                throw new functions.https.HttpsError(
                    "failed-precondition",
                    "Este convite já foi processado."
                );
            }

            const motoristaRef = db.collection("motoristas").doc(motoristaId);
            const alunoRef = db.collection("alunos").doc(alunoId);

            transaction.update(contratoRef, {
                status: "aprovado",
                dataAprovacao: admin.firestore.FieldValue.serverTimestamp(),
            });

            transaction.update(motoristaRef, {
                alunosIds: admin.firestore.FieldValue.arrayUnion(alunoId),
            });

            transaction.set(
                alunoRef,
                { motoristaId: motoristaId },
                { merge: true }
            );
        });

        return { success: true, message: "Convite aceito com sucesso." };
    } catch (error) {
        console.error("Erro ao aceitar convite:", error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError(
            "unknown",
            "Ocorreu um erro inesperado ao aceitar o convite."
        );
    }
});

/**
 * Cloud Function para o aluno se desvincular de um motorista.
 */
export const desvincularMotoristaAluno = functionsUs.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "A função só pode ser chamada por um usuário autenticado."
        );
    }

    const alunoId = context.auth.uid;

    try {
        const alunoRef = db.collection("alunos").doc(alunoId);
        const alunoSnap = await alunoRef.get();
        if (!alunoSnap.exists) {
            throw new functions.https.HttpsError(
                "not-found",
                "Aluno não encontrado."
            );
        }
        const alunoData = alunoSnap.data();
        const motoristaId = alunoData?.motoristaId as string | undefined;
        if (!motoristaId) {
            return { success: true, message: "Aluno já está desvinculado." };
        }

        const motoristaRef = db.collection("motoristas").doc(motoristaId);

        await db.runTransaction(async (transaction) => {
          transaction.update(alunoRef, { motoristaId: admin.firestore.FieldValue.delete() });
          transaction.update(motoristaRef, {
            alunosIds: admin.firestore.FieldValue.arrayRemove(alunoId),
          });
        });

        return { success: true, message: "Desvinculado com sucesso." };
    } catch (error) {
        console.error("Erro ao desvincular motorista:", error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError(
            "unknown",
            "Ocorreu um erro ao desvincular."
        );
    }
});

/**
 * Cloud Function para alunos avaliarem motoristas.
 */
export const avaliarMotorista = functionsUs.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "A função só pode ser chamada por um usuário autenticado."
        );
    }

    const alunoId = context.auth.uid;
    const motoristaId = typeof data.motoristaId === "string" ? data.motoristaId : null;
    const notaValue = Number(data.nota);
    const comentario = typeof data.comentario === "string" ? data.comentario.trim() : "";

    if (!motoristaId || isNaN(notaValue)) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "Os campos motoristaId e nota são obrigatórios."
        );
    }

    if (motoristaId === alunoId) {
        throw new functions.https.HttpsError(
            "failed-precondition",
            "Você não pode avaliar a si mesmo."
        );
    }

    if (notaValue < 1 || notaValue > 5) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "A nota deve estar entre 1 e 5."
        );
    }

    const motoristaRef = db.collection("motoristas").doc(motoristaId);
    const motoristaSnap = await motoristaRef.get();
    if (!motoristaSnap.exists) {
        throw new functions.https.HttpsError(
            "not-found",
            "Motorista não encontrado."
        );
    }

    try {
        await motoristaRef
            .collection("avaliacoes")
            .doc(alunoId)
            .set({
                alunoId,
                nota: notaValue,
                comentario,
                atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });

        const avaliacoesSnapshot = await motoristaRef.collection("avaliacoes").get();
        let soma = 0;
        avaliacoesSnapshot.forEach((doc) => {
            const data = doc.data();
            soma += Number(data.nota) || 0;
        });

        const quantidade = avaliacoesSnapshot.size;
        const media = quantidade > 0 ? soma / quantidade : notaValue;

        await motoristaRef.update({
            avaliacao: media,
            avaliacaoAtualizadaEm: admin.firestore.FieldValue.serverTimestamp(),
            avaliacoesQtd: quantidade,
        });

        return { media, quantidade };
    } catch (error) {
        console.error("Erro ao registrar avaliação:", error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError(
            "unknown",
            "Ocorreu um erro inesperado ao registrar a avaliação."
        );
    }
});

/**
 * Cloud Function para um motorista desvincular um aluno.
 */
export const desvincularAluno = functionsUs.https.onCall(async (data: any, context: CallableCtx) => {
    // 1. Autenticação e validação de entrada
    if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "A função só pode ser chamada por um usuário autenticado."
        );
    }
    const motoristaId = context.auth.uid;
    const alunoId = data.alunoId;

    if (!alunoId || typeof alunoId !== "string") {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "O ID do aluno é obrigatório."
        );
    }

    try {
        // 2. Executar a desvinculação em uma transação
        await db.runTransaction(async (transaction) => {
            const motoristaRef = db.collection("motoristas").doc(motoristaId);
            const alunoRef = db.collection("alunos").doc(alunoId);

            // a. Remover o aluno do array 'alunosIds' do motorista
            transaction.update(motoristaRef, {
                alunosIds: admin.firestore.FieldValue.arrayRemove(alunoId),
            });

            // b. Remover o 'motoristaId' do documento do aluno
            transaction.update(alunoRef, {
                motoristaId: admin.firestore.FieldValue.delete(),
            });

            // c. Encontrar e deletar o contrato aprovado
            const contratoQuery = await db
                .collection("contratos")
                .where("motoristaId", "==", motoristaId)
                .where("alunoId", "==", alunoId)
                .where("status", "==", "aprovado")
                .limit(1)
                .get();

            if (!contratoQuery.empty) {
                const contratoRef = contratoQuery.docs[0].ref;
                transaction.delete(contratoRef);
            }
        });

        return { success: true, message: "Aluno desvinculado com sucesso." };
    } catch (error) {
        console.error("Erro ao desvincular aluno:", error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError(
            "unknown",
            "Ocorreu um erro inesperado ao desvincular o aluno."
        );
    }
});

export const notificarAlunosRotaIniciada = functionsUs.firestore
    .document("rotas/{rotaId}")
    .onUpdate(async (change: any, context: functions.EventContext) => {
        const dadosAntes = change.before.data();
        const dadosDepois = change.after.data();

        // 1. Checa se o status mudou para 'emAndamento'
        if (dadosDepois.status === "emAndamento" && dadosAntes.status !== "emAndamento") {
            const nomeRota = dadosDepois.nome || "Sua rota";
            const alunosIds = dadosDepois.listaAlunosIds as string[];

            if (!alunosIds || alunosIds.length === 0) {
                console.log(`Rota ${context.params.rotaId} iniciada sem alunos para notificar.`);
                return null;
            }

            console.log(`Iniciando envio de notificações para ${alunosIds.length} alunos da rota ${context.params.rotaId}.`);

            // 2. Busca os tokens dos alunos
            const tokensPromises = alunosIds.map((alunoId) => 
                db.collection("users").doc(alunoId).get()
            );

            const usersDocs = await Promise.all(tokensPromises);

            const tokens = usersDocs
                .map((doc) => doc.data()?.fcmToken as string)
                .filter((token): token is string => !!token);

            if (tokens.length === 0) {
                console.log("Nenhum token FCM encontrado para os alunos da rota.");
                return null;
            }

            // 3. Monta a mensagem da notificação
            const payload = {
                notification: {
                    title: "Sua van está a caminho!",
                    body: `O motorista iniciou a rota "${nomeRota}". Acompanhe a viagem no mapa.`,
                    sound: "default",
                },
                data: {
                  screen: "tela_viagem", 
                  rotaId: context.params.rotaId,
                }
            };

            // 4. Envia as notificações
            try {
                const response = await admin.messaging().sendToDevice(tokens, payload);
                console.log("Notificações enviadas com sucesso:", response.successCount);
                
                response.results.forEach((result, index) => {
                    const error = result.error;
                    if (error) {
                        console.error(
                            "Falha ao enviar notificação para o token:",
                            tokens[index],
                            error
                        );
                    }
                });
                return null;

            } catch (error) {
                console.error("Erro ao enviar notificações:", error);
                return null;
            }
        }

        return null;
    });

/**
 * Cloud Function para notificar um motorista sobre um novo chat de um aluno.
 */
export const notificarNovoChat = functionsUs.firestore
    .document("chats/{chatId}")
    .onCreate(async (snapshot: any, context: functions.EventContext) => {
        const chatData = snapshot.data();

        if (!chatData) {
            console.log("No data associated with the event");
            return;
        }

        // 1. Verifica se o chat é uma nova solicitação ('inquiry')
        if (chatData.status !== "inquiry") {
            console.log(`Chat ${context.params.chatId} não é uma nova solicitação. Status: ${chatData.status}`);
            return;
        }

        const participants = chatData.participants as string[];
        if (participants.length !== 2) {
            console.error(`Chat ${context.params.chatId} não tem 2 participantes.`);
            return;
        }

        const alunoId = chatData.lastMessage.senderId;
        const motoristaId = participants.find(id => id !== alunoId);

        if (!motoristaId || !alunoId) {
            console.error(`Não foi possível identificar motorista ou aluno no chat ${context.params.chatId}.`);
            return;
        }
        
        // 2. Busca os dados do aluno e do motorista
        const motoristaUserDoc = await db.collection("users").doc(motoristaId).get();
        const alunoUserDoc = await db.collection("users").doc(alunoId).get();

        const motoristaToken = motoristaUserDoc.data()?.fcmToken as string;
        const nomeAluno = alunoUserDoc.data()?.nome || "Um aluno";

        if (!motoristaToken) {
            console.log(`Motorista ${motoristaId} não possui um token FCM.`);
            return;
        }

        // 3. Monta a mensagem da notificação
        const payload = {
            notification: {
                title: "Nova solicitação de conversa",
                body: `${nomeAluno} quer iniciar uma conversa com você.`,
                sound: "default",
            },
            data: {
                screen: "tela_lista_chats", // Para abrir a tela de chats no app
                chatId: context.params.chatId,
            }
        };

        // 4. Envia a notificação
        try {
            console.log(`Enviando notificação para o motorista ${motoristaId}...`);
            await admin.messaging().sendToDevice([motoristaToken], payload);
            console.log("Notificação enviada com sucesso.");
        } catch (error) {
            console.error("Erro ao enviar notificação para o motorista:", error);
        }
    });

export const sendWelcomeEmail = functionsUs.https.onCall(async (data: any, context: CallableCtx) => {
  // TODO: Implement actual email sending logic
  console.log("sendWelcomeEmail called with data:", data);
  return { success: true, message: "Welcome email sent (not really)!" };
});

export const notificarAlunosProximidadeInicioRota = functionsUs.pubsub.schedule("every 5 minutes").onRun(async (context: any) => {
    console.log("Executando verificação de rotas prestes a iniciar...");

    const now = admin.firestore.Timestamp.now();
    const future15 = new admin.firestore.Timestamp(now.seconds + 15 * 60, now.nanoseconds); // 15 minutos no futuro
    const future10 = new admin.firestore.Timestamp(now.seconds + 10 * 60, now.nanoseconds); // 10 minutos no futuro

    try {
        const querySnapshot = await db.collection("rotas")
            .where("status", "==", "planejada")
            .where("horaInicio", ">=", future10)
            .where("horaInicio", "<", future15)
            .get();

        if (querySnapshot.empty) {
            console.log("Nenhuma rota encontrada no intervalo de 10 a 15 minutos.");
            return null;
        }

        console.log(`Encontradas ${querySnapshot.size} rotas para notificar.`);

        const promises = querySnapshot.docs.map(async (doc) => {
            const rota = doc.data();
            const alunosIds = rota.listaAlunosIds as string[];

            if (!alunosIds || alunosIds.length === 0) {
                return;
            }

            const tokensPromises = alunosIds.map((alunoId) => db.collection("users").doc(alunoId).get());
            const usersDocs = await Promise.all(tokensPromises);

            const tokens = usersDocs
                .map((userDoc) => userDoc.data()?.fcmToken as string)
                .filter((token): token is string => !!token);

            if (tokens.length === 0) {
                console.log(`Nenhum token FCM para a rota ${doc.id}`);
                return;
            }

            const payload = {
                notification: {
                    title: "Sua van está quase saindo!",
                    body: `Faltam 10 minutos para o motorista começar a buscar os alunos da rota "${rota.nome}".`,
                    sound: "default",
                },
                data: {
                    screen: "tela_viagem",
                    rotaId: doc.id,
                },
            };

            await admin.messaging().sendToDevice(tokens, payload);
            console.log(`Notificações enviadas para ${tokens.length} alunos da rota ${doc.id}`);
        });

        await Promise.all(promises);
        return null;

    } catch (error) {
        console.error("Erro ao executar a função de notificação de rotas:", error);
        return null;
    }
});
