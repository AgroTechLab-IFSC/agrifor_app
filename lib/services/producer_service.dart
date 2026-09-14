import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrifor_app/models/property_model.dart';

/// Ações que cruzam mais de UMA coleção (users + properties) e por isso
/// não pertencem a nenhum Repository específico — ver comentário em
/// PropertyRepository explicando essa decisão.
class ProducerService {
  ProducerService(this._db);
  final FirebaseFirestore _db;

  /// Autocadastro: um produtor logado cria a PRÓPRIA propriedade pela
  /// aba "Minha Propriedade" (sem passar pelo admin). Cria o documento
  /// em properties/ e já vincula os dois lados da relação (o mesmo par
  /// de gravações de [linkProducerToProperty]) numa única transação:
  ///   - properties/{novoId} = dados do formulário + ownerIds/ownerNames
  ///     com o próprio criador + status SEMPRE 'pending'
  ///   - users/{producerUid}.propertyId = novoId
  ///
  /// `status` é forçado como 'pending' aqui dentro, ignorando qualquer
  /// valor vindo em [property] — é essa trava (mais a que as Firestore
  /// rules devem reforçar do lado do servidor) que garante que o
  /// produtor nunca consegue publicar a própria propriedade sozinho.
  /// Fica visível pra ELE imediatamente (MyPropertyScreen busca por
  /// ownerIds, sem filtrar por status), só não aparece pra mais
  /// ninguém até o admin aprovar (ver PropertyRepository.watchApproved
  /// e PropertyRepository.approve).
  ///
  /// Mesma restrição de [linkProducerToProperty]: produtor só pode
  /// estar vinculado a UMA propriedade por vez. Lança Exception com
  /// mensagem amigável se ele já tiver propertyId.
  Future<String> createPropertyForProducer({
    required String producerUid,
    required PropertyModel property,
  }) async {
    final userRef = _db.collection('users').doc(producerUid);
    // Id gerado localmente ANTES da transação — precisamos dele tanto
    // pra gravar properties/{id} quanto pra apontar users.propertyId
    // pro mesmo doc, e uma transação não permite usar o id de um
    // `add()` feito dentro dela.
    final propertyRef = _db.collection('properties').doc();

    await _db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);

      if (!userSnap.exists) {
        throw Exception('Produtor não encontrado.');
      }

      final userData = userSnap.data()!;

      if (userData['role'] != 'producer') {
        throw Exception('Apenas produtores podem cadastrar uma propriedade.');
      }

      if (userData['propertyId'] != null) {
        throw Exception('Você já está vinculado a uma propriedade.');
      }

      final producerName = userData['name'] as String? ?? 'Produtor';

      tx.set(propertyRef, {
        ...property.toMap(),
        'ownerIds': [producerUid],
        'ownerNames': [producerName],
        'status': PropertyStatus.pending.name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.update(userRef, {'propertyId': propertyRef.id});
    });

    return propertyRef.id;
  }

  /// Vincula um produtor (users/{uid}) a uma propriedade
  /// (properties/{propertyId}), gravando os dois lados da relação numa
  /// única transação:
  ///   - users/{uid}.propertyId       = propertyId
  ///   - properties/{propertyId}.ownerIds   += uid (arrayUnion)
  ///   - properties/{propertyId}.ownerNames += name (arrayUnion)
  ///
  /// ownerNames é denormalizado aqui de propósito: users é fechado pra
  /// leitura de quem não é o próprio dono ou admin (ver Firestore
  /// Rules), então telas de detalhe de propriedade (inclusive pra
  /// visitante sem login) não podem ler users/{uid} pra montar o nome
  /// de exibição do produtor — precisam vir prontos da property.
  ///
  /// Uma propriedade pode ter vários donos (ownerIds é lista); a
  /// restrição aqui é sobre o PRODUTOR: ele só pode estar vinculado a
  /// UMA propriedade por vez. Lança Exception com mensagem amigável se
  /// o produtor já tiver propertyId (evita vínculo duplo / órfão
  /// silencioso).
  Future<void> linkProducerToProperty({
    required String producerUid,
    required String propertyId,
  }) async {
    final userRef = _db.collection('users').doc(producerUid);
    final propertyRef = _db.collection('properties').doc(propertyId);

    await _db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);

      if (!userSnap.exists) {
        throw Exception('Produtor não encontrado.');
      }

      final userData = userSnap.data()!;

      if (userData['role'] != 'producer') {
        throw Exception('Usuário selecionado não é um produtor.');
      }

      if (userData['propertyId'] != null) {
        throw Exception(
          'Este produtor já está vinculado a uma propriedade.',
        );
      }

      final producerName = userData['name'] as String? ?? 'Produtor';

      // Nota: não é preciso ler o doc de properties aqui — arrayUnion é
      // idempotente e a escrita em users já garante que esse produtor
      // não será vinculado duas vezes (por causa do guard acima).
      tx.update(userRef, {'propertyId': propertyId});
      tx.update(propertyRef, {
        'ownerIds': FieldValue.arrayUnion([producerUid]),
        'ownerNames': FieldValue.arrayUnion([producerName]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Desvincula um produtor de uma propriedade — o inverso de
  /// [linkProducerToProperty]. Usado quando o admin remove um dono na
  /// edição da propriedade (o form permite 0..N donos) ou quando um
  /// vínculo foi feito por engano.
  ///
  /// Não usa arrayRemove por nome (users pode ter mudado o `name` desde
  /// o vínculo, o que faria o arrayRemove por valor falhar em achar o
  /// nome exato). Em vez disso lê ownerIds/ownerNames, remove pelo
  /// ÍNDICE correspondente ao uid, e regrava as duas listas por
  /// completo — mantendo os dois arrays sincronizados mesmo se algo já
  /// estiver bagunçado.
  ///
  /// Se o produtor já não estiver em ownerIds, é uma no-op silenciosa
  /// na property (idempotente); ainda assim limpa users.propertyId se
  /// ele apontar pra essa propriedade.
  Future<void> unlinkProducerFromProperty({
    required String producerUid,
    required String propertyId,
  }) async {
    final userRef = _db.collection('users').doc(producerUid);
    final propertyRef = _db.collection('properties').doc(propertyId);

    await _db.runTransaction((tx) async {
      // Todas as leituras antes de qualquer escrita (regra de
      // transação do Firestore).
      final propertySnap = await tx.get(propertyRef);
      final userSnap = await tx.get(userRef);

      if (!propertySnap.exists) {
        throw Exception('Propriedade não encontrada.');
      }

      final propertyData = propertySnap.data()!;
      final ownerIds = List<String>.from(propertyData['ownerIds'] ?? const []);
      final ownerNames =
          List<String>.from(propertyData['ownerNames'] ?? const []);

      final index = ownerIds.indexOf(producerUid);
      if (index != -1) {
        ownerIds.removeAt(index);
        if (ownerNames.length > index) {
          ownerNames.removeAt(index);
        }
      }

      tx.update(propertyRef, {
        'ownerIds': ownerIds,
        'ownerNames': ownerNames,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (userSnap.exists && userSnap.data()!['propertyId'] == propertyId) {
        tx.update(userRef, {'propertyId': null});
      }
    });
  }
}