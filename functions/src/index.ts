import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

/**
 * Cloud Function para um motorista convidar um aluno.
 */
export const enviarConvite = functions.https.onCall(async (data, context) => {
    // 1. Autenticação e validação de entrada
    if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "A função só pode ser chamada por um usuário autenticado."
        );
    }
    const motoristaId = context.auth.uid;
    const emailAluno = data.email;

    if (!emailAluno || typeof emailAluno !== "string") {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "O email do aluno é obrigatório."
        );
    }

    try {
        // 2. Encontrar o aluno pelo email
        const userQuery = await db
            .collection("users")
            .where("email", "==", emailAluno)
            .where("role", "==", "aluno")
            .limit(1)
            .get();

        if (userQuery.empty) {
            throw new functions.https.HttpsError(
                "not-found",
                "Nenhum aluno encontrado com este email."
            );
        }
        const alunoId = userQuery.docs[0].id;

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
 * Cloud Function para um motorista desvincular um aluno.
 */
export const desvincularAluno = functions.https.onCall(async (data, context) => {
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


export const notificarAlunosRotaIniciada = functions.firestore
    .document("rotas/{rotaId}")
    .onUpdate(async (change, context) => {
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