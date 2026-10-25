import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();
const functionsUs = functions.region("us-central1");
type CallableCtx = functions.https.CallableContext;

const TOKENS_INVALIDOS = new Set([
    "messaging/registration-token-not-registered",
    "messaging/invalid-registration-token",
]);

/**
 * Envia uma notificação push para os usuários informados (API HTTP v1 do FCM)
 * e remove dos documentos os tokens que não são mais válidos.
 */
async function enviarPush(
    userIds: string[],
    notification: { title: string; body: string },
    data: Record<string, string>,
): Promise<number> {
    const usersDocs = await Promise.all(
        userIds.map((id) => db.collection("users").doc(id).get())
    );
    const destinos = usersDocs
        .map((doc) => ({ ref: doc.ref, token: doc.data()?.fcmToken as string | undefined }))
        .filter((d): d is { ref: FirebaseFirestore.DocumentReference; token: string } => !!d.token);

    if (destinos.length === 0) {
        console.log("Nenhum token FCM encontrado para os destinatários.");
        return 0;
    }

    const response = await admin.messaging().sendEachForMulticast({
        tokens: destinos.map((d) => d.token),
        notification,
        data,
        android: { priority: "high", notification: { sound: "default" } },
        apns: { payload: { aps: { sound: "default" } } },
    });

    const limpezas: Promise<unknown>[] = [];
    response.responses.forEach((result, index) => {
        if (result.success) return;
        console.error("Falha ao enviar notificação:", result.error?.code, result.error?.message);
        if (result.error && TOKENS_INVALIDOS.has(result.error.code)) {
            limpezas.push(destinos[index].ref.update({
                fcmToken: admin.firestore.FieldValue.delete(),
            }));
        }
    });
    await Promise.all(limpezas);

    return response.successCount;
}

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
                {
                    motoristasIds: admin.firestore.FieldValue.arrayUnion(motoristaId),
                    motoristaId: admin.firestore.FieldValue.delete(),
                },
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
    const motoristaIdInput = typeof data?.motoristaId === "string" ? data.motoristaId : null;

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
        const motoristasIdsRaw = alunoData?.motoristasIds;
        const motoristasIds = Array.isArray(motoristasIdsRaw)
            ? motoristasIdsRaw.filter((id: unknown) => typeof id === "string") as string[]
            : [];
        const motoristaIdLegacy = alunoData?.motoristaId as string | undefined;
        const motoristaId =
            motoristaIdInput ??
            (motoristasIds.length === 1 ? motoristasIds[0] : motoristaIdLegacy);
        if (motoristasIds.length > 1 && !motoristaIdInput) {
            throw new functions.https.HttpsError(
                "failed-precondition",
                "Informe o motoristaId para desvincular quando houver múltiplos motoristas."
            );
        }
        if (!motoristaId) {
            return { success: true, message: "Aluno já está desvinculado." };
        }

        const motoristaRef = db.collection("motoristas").doc(motoristaId);

        await db.runTransaction(async (transaction) => {
          transaction.update(alunoRef, {
            motoristasIds: admin.firestore.FieldValue.arrayRemove(motoristaId),
            motoristaId: admin.firestore.FieldValue.delete(),
          });
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

            // b. Remover o motorista atual do documento do aluno
            transaction.update(alunoRef, {
                motoristasIds: admin.firestore.FieldValue.arrayRemove(motoristaId),
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

            // 2. Envia as notificações
            try {
                const enviadas = await enviarPush(
                    alunosIds,
                    {
                        title: "Sua van está a caminho!",
                        body: `O motorista iniciou a rota "${nomeRota}". Acompanhe a viagem no mapa.`,
                    },
                    { screen: "tela_viagem", rotaId: context.params.rotaId },
                );
                console.log("Notificações enviadas com sucesso:", enviadas);
            } catch (error) {
                console.error("Erro ao enviar notificações:", error);
            }
            return null;
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
        
        // 2. Busca o nome do aluno
        const alunoUserDoc = await db.collection("users").doc(alunoId).get();
        const nomeAluno = alunoUserDoc.data()?.nome || "Um aluno";

        // 3. Envia a notificação para o motorista
        try {
            console.log(`Enviando notificação para o motorista ${motoristaId}...`);
            const enviadas = await enviarPush(
                [motoristaId],
                {
                    title: "Nova solicitação de conversa",
                    body: `${nomeAluno} quer iniciar uma conversa com você.`,
                },
                { screen: "tela_lista_chats", chatId: context.params.chatId },
            );
            console.log("Notificações enviadas:", enviadas);
        } catch (error) {
            console.error("Erro ao enviar notificação para o motorista:", error);
        }
    });

export const sendWelcomeEmail = functionsUs.https.onCall(async (data: any, context: CallableCtx) => {
  // TODO: Implement actual email sending logic
  console.log("sendWelcomeEmail called with data:", data);
  return { success: true, message: "Welcome email sent (not really)!" };
});

const FUSO_ROTAS = "America/Sao_Paulo";
const DIAS_SEMANA = ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sab"];

/** Dia da semana ("Seg"...) e horário "HH:mm" de [data] no fuso das rotas. */
function diaEHorario(data: Date): { dia: string; horario: string } {
    const partes = new Intl.DateTimeFormat("en-US", {
        timeZone: FUSO_ROTAS,
        weekday: "short",
        hour: "2-digit",
        minute: "2-digit",
        hourCycle: "h23",
    }).formatToParts(data);
    const valor = (tipo: string) => partes.find((p) => p.type === tipo)?.value ?? "";
    const indiceDia = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"].indexOf(valor("weekday"));
    return { dia: DIAS_SEMANA[indiceDia], horario: `${valor("hour")}:${valor("minute")}` };
}

/**
 * A cada 5 minutos, avisa os alunos das rotas que começam daqui a 10–14 minutos.
 * Usa os dias da semana e o horário previsto da rota, então vale toda semana.
 */
export const notificarAlunosProximidadeInicioRota = functionsUs.pubsub
    .schedule("every 5 minutes")
    .timeZone(FUSO_ROTAS)
    .onRun(async () => {
    console.log("Executando verificação de rotas prestes a iniciar...");

    const agora = Date.now();
    const janelas = [10, 11, 12, 13, 14].map((min) => diaEHorario(new Date(agora + min * 60 * 1000)));
    const horarios = janelas.map((j) => j.horario);

    try {
        const snapshot = await db.collection("rotas")
            .where("horarioInicioPrevisto", "in", horarios)
            .get();

        const docs = snapshot.docs.filter((doc) => {
            const rota = doc.data();
            if (rota.status === "emAndamento" || rota.status === "cancelada") return false;
            const janela = janelas.find((j) => j.horario === rota.horarioInicioPrevisto);
            return !!janela && rota.diasSemana?.[janela.dia] === true;
        });
        const querySnapshot = { docs, size: docs.length, empty: docs.length === 0 };

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

            const enviadas = await enviarPush(
                alunosIds,
                {
                    title: "Sua van está quase saindo!",
                    body: `Faltam 10 minutos para o motorista começar a buscar os alunos da rota "${rota.nome}".`,
                },
                { screen: "tela_viagem", rotaId: doc.id },
            );
            console.log(`Notificações enviadas para ${enviadas} alunos da rota ${doc.id}`);
        });

        await Promise.all(promises);
        return null;

    } catch (error) {
        console.error("Erro ao executar a função de notificação de rotas:", error);
        return null;
    }
});
