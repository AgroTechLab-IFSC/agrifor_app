// functions/index.js
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

/**
 * MODELO: uma propriedade pode ter MAIS DE UM dono (`ownerIds` é array),
 * mas cada PRODUTOR só administra UMA propriedade (`propertyId` é
 * string singular em /users/{uid}). A relação é N pessoas -> 1
 * propriedade, nunca o contrário.
 *
 * FLUXO DE CADASTRO: o produtor cria a própria conta (email/senha ou
 * Google) direto no app Flutter e o próprio app grava o doc inicial em
 * /users/{uid} (role: 'producer', propertyId: null) -- ver rules do
 * Firestore. Este arquivo só cuida do VÍNCULO entre um produtor já
 * existente e uma propriedade, que é responsabilidade exclusiva do
 * admin.
 */

/**
 * Callable: vincula um PRODUTOR JÁ EXISTENTE a uma propriedade,
 * TROCANDO a propriedade anterior dele (já que cada produtor só
 * administra uma). Se ele já tinha um vínculo, esse vínculo antigo é
 * desfeito (removido do `ownerIds` da propriedade anterior) antes de
 * criar o novo.
 *
 * Só pode ser chamada por admin.
 */
exports.linkProducerToProperty = onCall(async (request) => {
  const { auth, data } = request;

  if (!auth) {
    throw new HttpsError('unauthenticated', 'É preciso estar logado.');
  }

  const callerDoc = await db.collection('users').doc(auth.uid).get();
  if (!callerDoc.exists || callerDoc.data().role !== 'admin') {
    throw new HttpsError('permission-denied', 'Apenas administradores podem vincular produtores.');
  }

  const { uid, propertyId } = data;
  if (!uid || !propertyId) {
    throw new HttpsError('invalid-argument', 'uid e propertyId são obrigatórios.');
  }

  const userRef = db.collection('users').doc(uid);
  const userSnap = await userRef.get();
  if (!userSnap.exists) {
    throw new HttpsError('not-found', `Usuário ${uid} não encontrado.`);
  }
  if (userSnap.data().role !== 'producer') {
    throw new HttpsError('failed-precondition', 'Esse usuário não é um produtor.');
  }

  const propertyRef = db.collection('properties').doc(propertyId);
  const propertySnap = await propertyRef.get();
  if (!propertySnap.exists) {
    throw new HttpsError('not-found', `Propriedade ${propertyId} não encontrada.`);
  }

  const previousPropertyId = userSnap.data().propertyId;

  const batch = db.batch();

  // desfaz vínculo anterior, se havia um e é diferente do novo
  if (previousPropertyId && previousPropertyId !== propertyId) {
    batch.update(db.collection('properties').doc(previousPropertyId), {
      ownerIds: admin.firestore.FieldValue.arrayRemove(uid),
    });
  }

  batch.update(userRef, { propertyId });
  batch.update(propertyRef, {
    ownerIds: admin.firestore.FieldValue.arrayUnion(uid),
  });
  await batch.commit();

  return { uid, propertyId };
});

/**
 * Callable: desvincula um produtor da propriedade atual (não apaga a
 * conta, só remove o vínculo — ele fica sem propriedade até o admin
 * linká-lo em outra).
 *
 * Só pode ser chamada por admin.
 */
exports.unlinkProducerFromProperty = onCall(async (request) => {
  const { auth, data } = request;

  if (!auth) {
    throw new HttpsError('unauthenticated', 'É preciso estar logado.');
  }

  const callerDoc = await db.collection('users').doc(auth.uid).get();
  if (!callerDoc.exists || callerDoc.data().role !== 'admin') {
    throw new HttpsError('permission-denied', 'Apenas administradores podem desvincular produtores.');
  }

  const { uid } = data;
  if (!uid) {
    throw new HttpsError('invalid-argument', 'uid é obrigatório.');
  }

  const userRef = db.collection('users').doc(uid);
  const userSnap = await userRef.get();
  if (!userSnap.exists) {
    throw new HttpsError('not-found', `Usuário ${uid} não encontrado.`);
  }

  const currentPropertyId = userSnap.data().propertyId;
  if (!currentPropertyId) {
    throw new HttpsError('failed-precondition', 'Esse produtor não está vinculado a nenhuma propriedade.');
  }

  const batch = db.batch();
  batch.update(userRef, { propertyId: admin.firestore.FieldValue.delete() });
  batch.update(db.collection('properties').doc(currentPropertyId), {
    ownerIds: admin.firestore.FieldValue.arrayRemove(uid),
  });
  await batch.commit();

  return { uid, propertyId: currentPropertyId };
});