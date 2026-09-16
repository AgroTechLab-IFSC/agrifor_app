import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Ações de armazenamento das fotos de uma propriedade no Firebase
/// Storage. Isolado num service próprio (não dentro do
/// PropertyRepository) porque lida com um recurso diferente do
/// Firestore — mesma razão de separação já usada pro ProducerService
/// (ações que não pertencem a um único documento/coleção).
///
/// Cada propriedade tem sua própria "pasta" em `properties/{folderId}/`.
/// `folderId` normalmente é o id do documento da propriedade
/// (property.id), mas pro CADASTRO (propriedade ainda sem id, porque o
/// Firestore só gera um depois do create) quem chama passa um id
/// temporário local só pra ter um prefixo estável durante a sessão do
/// formulário — ver PropertyFormSheet._folderId. Não precisa bater com
/// o id final do documento: só serve pra evitar colisão de nomes entre
/// uploads de propriedades diferentes.
class PropertyImageService {
  PropertyImageService({FirebaseStorage? storage, ImagePicker? picker})
      : _storage = storage ?? FirebaseStorage.instance,
        _picker = picker ?? ImagePicker();

  final FirebaseStorage _storage;
  final ImagePicker _picker;

  /// Abre o seletor nativo permitindo escolher várias imagens de uma
  /// vez. Retorna lista vazia se o usuário cancelar — quem chama só
  /// precisa acrescentar o resultado à lista atual, sem tratar cancel
  /// como erro.
  Future<List<XFile>> pickImages() {
    return _picker.pickMultiImage(imageQuality: 85);
  }

  /// Sobe um arquivo local pra `properties/{folderId}/` com um nome
  /// único (timestamp + extensão original) e devolve a URL pública de
  /// download, já pronta pra gravar em `PropertyModel.images`.
  Future<String> upload({required String folderId, required XFile file}) async {
    final dotIndex = file.name.lastIndexOf('.');
    final extension = dotIndex != -1 ? file.name.substring(dotIndex) : '.jpg';
    final fileName = '${DateTime.now().microsecondsSinceEpoch}$extension';
    final ref = _storage.ref().child('properties/$folderId/$fileName');

    await ref.putFile(File(file.path));
    return ref.getDownloadURL();
  }

  /// Sobe vários arquivos em sequência, preservando a ordem de entrada
  /// (importante: a posição na lista resultante é o que define a
  /// ordem no carrossel — ver PropertyModel.images). Sequencial, não
  /// paralelo, pra manter essa ordem determinística sem precisar
  /// reordenar depois por índice.
  Future<List<String>> uploadAll({
    required String folderId,
    required List<XFile> files,
  }) async {
    final urls = <String>[];
    for (final file in files) {
      urls.add(await upload(folderId: folderId, file: file));
    }
    return urls;
  }

  /// Remove uma imagem já enviada, a partir da própria URL de download
  /// (guardada em PropertyModel.images). Silenciosamente ignora falha
  /// (arquivo já removido, URL de outro storage, etc.) — a exclusão de
  /// imagem nunca deve impedir o resto do fluxo de salvar/editar a
  /// propriedade.
  Future<void> delete(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {
      // já removido, ou url não pertence a este bucket — ok ignorar.
    }
  }

  Future<void> deleteAll(List<String> urls) async {
    for (final url in urls) {
      await delete(url);
    }
  }

  /// Apaga a pasta inteira de uma propriedade — usado quando a
  /// propriedade em si é excluída (ver PropertiesScreen._confirmDelete),
  /// pra não deixar arquivos órfãos no Storage. Lista e apaga um a um
  /// (Storage não tem "delete de pasta" nativo). Silencioso: se a
  /// pasta não existir ou já tiver sido limpa, não há nada a fazer.
  Future<void> deleteFolder(String folderId) async {
    try {
      final result = await _storage.ref().child('properties/$folderId').listAll();
      for (final item in result.items) {
        await item.delete();
      }
    } catch (_) {
      // pasta vazia/inexistente — ok ignorar.
    }
  }
}