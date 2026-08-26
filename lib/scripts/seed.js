/**
 * Script de seed — grava categorias, produtos, sistemas de produção,
 * propriedades e o usuário ADMIN inicial no Firebase (Auth + Firestore).
 *
 * COMO USAR:
 * 1. No Console do Firebase: Configurações do Projeto > Contas de Serviço >
 *    "Gerar nova chave privada". Salve o JSON baixado como
 *    `serviceAccountKey.json` NESTA MESMA PASTA (scripts/).
 *    -> NÃO COMITAR esse arquivo no git (adicione no .gitignore).
 * 2. Instale as dependências:  npm install firebase-admin
 * 3. Defina as credenciais do admin como variáveis de ambiente
 *    (evita senha hardcoded no código/git):
 *      export SEED_ADMIN_EMAIL="seu-email-admin@exemplo.com"
 *      export SEED_ADMIN_PASSWORD="senha-provisoria-forte"
 * 4. Rode:  node seed.js
 *
 * Ordem de execução importa: categorias, produtos e sistemas de
 * produção são gravados primeiro (as propriedades referenciam os IDs
 * deles). Os IDs usados aqui são slugs fixos — ok para dados de
 * seed/catálogo inicial curado por você, mas NÃO reutilize esse padrão
 * de "ID = slug do nome" pra documentos criados depois pelo admin no
 * app (lá, use doc() sem argumento pra gerar ID automático e evitar
 * colisão entre nomes parecidos).
 *
 * SISTEMAS DE PRODUÇÃO (productionSystems):
 * Assim como categories/products, é uma tabela fixa cadastrada só por
 * este seed (ou console) — não tem CRUD no app, decisão consciente
 * porque não é algo que sofre alteração. Antes, `productionSystem` em
 * `properties` guardava texto livre (ex: "Convencional"), o que
 * permitia inconsistência de digitação e furava a contagem por tipo no
 * Painel do admin. Agora guarda IDs (ex: 'convencional'), resolvidos
 * pra nome de exibição via ProductionSystemRepository no app — mesmo
 * padrão de categoryIds/productIds.
 *
 * MODELO DE DONOS:
 * Uma propriedade pode ter MAIS DE UM produtor com conta própria
 * (ex: casal, sócios) -> `ownerIds` é um ARRAY de UIDs em
 * `properties/{id}`. Não existe mais um campo de nome de dono solto na
 * propriedade (ownerName foi removido: com múltiplos donos possíveis,
 * um nome singular não fazia sentido) — o nome de exibição é sempre
 * resolvido a partir da conta em /users/{uid} via ownerIds.
 * Já uma pessoa só administra UMA propriedade -> `propertyId` em
 * `users/{uid}` é uma STRING singular (não array). A relação é
 * N pessoas -> 1 propriedade, nunca o contrário.
 *
 * LIMPEZA DE CAMPOS ANTIGOS:
 * Versões anteriores deste seed gravaram `ownerId` (singular) em
 * properties e chegaram a gravar `propertyIds` (array, tentativa
 * descartada) em users. Também gravavam `city`, `association`,
 * `ownerName` e `email` em properties — campos removidos do modelo
 * atual. Como `merge: true` nunca apaga campos que não estão no
 * payload, esses campos órfãos ficariam presos nos documentos pra
 * sempre se não forem removidos explicitamente -- por isso usamos
 * FieldValue.delete() abaixo. Depois que isso rodar uma vez em cima dos
 * documentos existentes, essas linhas de limpeza podem ser removidas
 * (mas não fazem mal nenhum se ficarem).
 *
 * FLUXO ATUAL DE PRODUTORES (auto-cadastro):
 * Este script NÃO cria contas de produtor -- e nunca vai criar. O
 * produtor cria o próprio login (email/senha ou Google) direto pelo
 * app Flutter, e o próprio app grava o doc inicial em /users/{uid}
 * (role: 'producer', propertyId: null). O admin entra depois e associa
 * esse produtor a uma propriedade através de ProducerService
 * (lib/services/producer_service.dart no app Flutter, método
 * linkProducerToProperty — roda como transação direta no Firestore,
 * chamada pelo client autenticado como admin; NÃO é uma Cloud
 * Function). Por isso todas as propriedades abaixo nascem com
 * `ownerIds: []` -- é o estado esperado até o admin fazer esse vínculo.
 *
 * O único login criado por ESTE script é o do admin (via
 * seedAdminUser abaixo), porque não existe fluxo de auto-cadastro de
 * admin -- alguém precisa "nascer" admin pra poder promover o sistema.
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const auth = admin.auth();

function slugify(text) {
  return text
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '') // remove acentos
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '');
}

// --- categorias -----------------------------------------------------------
const CATEGORY_NAMES = [
  'Hortaliças',
  'Frutas',
  'Grãos',
  'Pecuária de Corte',
  'Pecuária Leiteira',
  'Agroindústria',
];

const categories = CATEGORY_NAMES.map((name, index) => ({
  id: slugify(name),
  name,
  order: index,
  active: true,
}));

function categoryId(name) {
  return slugify(name);
}

// --- produtos ---------------------------------------------------------
const products = [
  { id: 'uva', name: 'Uva', categoryId: categoryId('Frutas') },
  { id: 'maca', name: 'Maçã', categoryId: categoryId('Frutas') },
  { id: 'goiaba', name: 'Goiaba', categoryId: categoryId('Frutas') },
  { id: 'banana', name: 'Banana', categoryId: categoryId('Frutas') },
  { id: 'alface', name: 'Alface', categoryId: categoryId('Hortaliças') },
  { id: 'cebola', name: 'Cebola', categoryId: categoryId('Hortaliças') },
  { id: 'batata', name: 'Batata', categoryId: categoryId('Hortaliças') },
  { id: 'abobora', name: 'Abóbora', categoryId: categoryId('Hortaliças') },
  { id: 'tomate', name: 'Tomate', categoryId: categoryId('Hortaliças') },
  { id: 'milho-verde', name: 'Milho Verde', categoryId: categoryId('Grãos') },
  { id: 'graos-variados', name: 'Grãos (variados)', categoryId: categoryId('Grãos') },
  { id: 'geleias', name: 'Geleias', categoryId: categoryId('Agroindústria') },
  { id: 'doces', name: 'Doces', categoryId: categoryId('Agroindústria') },
  { id: 'compotas', name: 'Compotas', categoryId: categoryId('Agroindústria') },
  { id: 'gado-de-corte', name: 'Gado de Corte', categoryId: categoryId('Pecuária de Corte') },
].map((p) => ({ ...p, active: true }));

// --- sistemas de produção ---------------------------------------------
// Tabela fixa, sem CRUD no app (decisão do usuário: não sofre
// alteração, só precisa existir pra popular o select no cadastro de
// propriedade e resolver id -> nome nas telas de exibição).
const PRODUCTION_SYSTEM_NAMES = ['Convencional', 'Orgânico Certificado', 'Agroecológico'];

const productionSystems = PRODUCTION_SYSTEM_NAMES.map((name, index) => ({
  id: slugify(name),
  name,
  order: index,
}));

function productionSystemId(name) {
  return slugify(name);
}

// --- propriedades -------------------------------------------------------
// Usadas apenas pra gerar um id de slug estável (propertyName é o único
// texto identificador que sobrou); não é mais gravado nome de dono nem
// cidade/associação aqui.
const properties = [
  {
    propertyName: 'Propriedade Alisson Correa',
    categoryIds: [categoryId('Frutas'), categoryId('Pecuária de Corte'), categoryId('Agroindústria')],
    productIds: ['uva', 'maca', 'goiaba', 'banana', 'geleias', 'doces', 'compotas', 'gado-de-corte'],
    summary:
      'Produtor integrante da Agrilages, atuando na fruticultura, ' +
      'pecuária de corte e agroindústria artesanal. Comercializa sua ' +
      'produção por diversos canais, incluindo venda direta ao consumidor ' +
      'e programas governamentais.',
    productionSystem: [productionSystemId('Convencional')],
    salesChannels: [
      'Atravessadores',
      'Programas Governamentais',
      'Venda Direta ao Consumidor',
      'Venda para Agroindústria',
      'Colha e Pague',
      'CEASA',
    ],
    salesNotes: 'CEASA: R$ 80 o espaço, paga o pessoal dos carrinhos, certificado de origem.',
    whatsapp: '',
    lat: -27.75675,
    lng: -50.120222,
    images: [
      'https://picsum.photos/seed/alisson-1/800/600',
      'https://picsum.photos/seed/alisson-2/800/600',
      'https://picsum.photos/seed/alisson-3/800/600',
    ],
  },
  {
    propertyName: 'Propriedade Fabiano Sanguanini',
    categoryIds: [categoryId('Hortaliças'), categoryId('Grãos')],
    productIds: ['alface', 'cebola', 'batata', 'abobora', 'tomate', 'milho-verde'],
    summary:
      'Produtor certificado orgânico com foco em horticultura e produção ' +
      'de milho verde. Participa de associação, cooperativa ou feira e ' +
      'comercializa por meio de atravessadores e programas governamentais.',
    productionSystem: [productionSystemId('Orgânico Certificado')],
    salesChannels: ['Atravessadores', 'Programas Governamentais'],
    salesNotes: '',
    whatsapp: '',
    lat: -27.797028,
    lng: -50.267306,
    images: [
      'https://picsum.photos/seed/fabiano-1/800/600',
      'https://picsum.photos/seed/fabiano-2/800/600',
    ],
  },
  {
    propertyName: 'Propriedade Lucimara Xavier',
    categoryIds: [
      categoryId('Hortaliças'),
      categoryId('Frutas'),
      categoryId('Grãos'),
      categoryId('Pecuária de Corte'),
    ],
    productIds: [
      'alface', 'cebola', 'batata', 'abobora', 'tomate',
      'uva', 'maca', 'goiaba', 'banana',
      'graos-variados',
      'gado-de-corte',
    ],
    summary:
      'Propriedade diversificada com horticultura, fruticultura, grãos e ' +
      'pecuária de corte, combinando sistema convencional e orgânico ' +
      'certificado. Comercializa em feiras, mercados, programas ' +
      'governamentais e diretamente ao consumidor.',
    productionSystem: [
      productionSystemId('Convencional'),
      productionSystemId('Orgânico Certificado'),
    ],
    salesChannels: [
      'Mercados, Supermercados e Restaurantes',
      'Feiras',
      'Programas Governamentais',
      'Venda Direta ao Consumidor',
      'Colha e Pague',
    ],
    salesNotes: '',
    whatsapp: '',
    lat: -27.741361,
    lng: -50.098194,
    images: [
      'https://picsum.photos/seed/lucimara-1/800/600',
      'https://picsum.photos/seed/lucimara-2/800/600',
      'https://picsum.photos/seed/lucimara-3/800/600',
    ],
  },
].map((p) => ({ ...p, id: slugify(p.propertyName) }));

// --- admin inicial --------------------------------------------------------
async function seedAdminUser() {
  const email = process.env.SEED_ADMIN_EMAIL;
  const password = process.env.SEED_ADMIN_PASSWORD;

  if (!email || !password) {
    console.warn(
      '\n[aviso] SEED_ADMIN_EMAIL / SEED_ADMIN_PASSWORD não definidas — ' +
      'pulando criação do admin. Defina as variáveis de ambiente e rode ' +
      'o seed novamente se ainda não existe nenhum admin.'
    );
    return;
  }

  let userRecord;
  try {
    userRecord = await auth.getUserByEmail(email);
    console.log(`-> admin já existe (${email}), atualizando doc...`);
  } catch (err) {
    if (err.code !== 'auth/user-not-found') throw err;
    userRecord = await auth.createUser({ email, password });
    console.log(`-> admin criado: ${email}`);
  }

  // NOTA: não usamos setCustomUserClaims aqui -- as rules atuais leem o
  // doc /users/{uid} via get(), não o token. Setar claim junto criaria
  // duas fontes de verdade que podem dessincronizar.
  await db.collection('users').doc(userRecord.uid).set(
    {
      email,
      role: 'admin',
      propertyId: null, // admin não administra propriedade nenhuma
      propertyIds: admin.firestore.FieldValue.delete(), // limpa tentativa anterior (array)
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  console.log(`-> doc /users/${userRecord.uid} confirmado (role: admin).`);
}

async function seed() {
  const batch = db.batch();

  for (const c of categories) {
    const ref = db.collection('categories').doc(c.id);
    batch.set(ref, { name: c.name, order: c.order, active: c.active }, { merge: true });
    console.log(`-> categoria preparada: ${c.id}`);
  }

  for (const p of products) {
    const ref = db.collection('products').doc(p.id);
    batch.set(ref, { name: p.name, categoryId: p.categoryId, active: p.active }, { merge: true });
    console.log(`-> produto preparado: ${p.id}`);
  }

  for (const ps of productionSystems) {
    const ref = db.collection('productionSystems').doc(ps.id);
    batch.set(ref, { name: ps.name, order: ps.order }, { merge: true });
    console.log(`-> sistema de produção preparado: ${ps.id}`);
  }

  for (const prop of properties) {
    const ref = db.collection('properties').doc(prop.id);
    batch.set(
      ref,
      {
        propertyName: prop.propertyName,
        ownerIds: [], // vínculo feito depois via ProducerService (admin, no app)
        ownerId: admin.firestore.FieldValue.delete(), // limpa campo antigo (singular)
        ownerName: admin.firestore.FieldValue.delete(), // removido: nome vem sempre de users/{uid} via ownerIds
        city: admin.firestore.FieldValue.delete(), // removido: substituído por location (GeoPoint)
        association: admin.firestore.FieldValue.delete(), // removido do modelo
        email: admin.firestore.FieldValue.delete(), // removido: mantém só whatsapp
        categoryIds: prop.categoryIds,
        productIds: prop.productIds,
        summary: prop.summary,
        productionSystem: prop.productionSystem, // agora array de IDs, não texto livre
        salesChannels: prop.salesChannels,
        salesNotes: prop.salesNotes,
        whatsapp: prop.whatsapp,
        location: new admin.firestore.GeoPoint(prop.lat, prop.lng),
        images: prop.images,
        active: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    console.log(`-> propriedade preparada: ${prop.id}`);
  }

  await batch.commit();
  console.log(
    `\nCatálogo gravado: ${categories.length} categorias, ${products.length} produtos, ` +
    `${productionSystems.length} sistemas de produção, ${properties.length} propriedades.`
  );

  await seedAdminUser();
}

seed()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Erro no seed:', err);
    process.exit(1);
  });