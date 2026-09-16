import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Uma imagem em edição no formulário: ou já está hospedada no Storage
/// (edição de uma propriedade existente — [url] preenchido), ou foi
/// selecionada agora e ainda não foi enviada ([file] preenchido). O
/// campo trata os dois tipos de forma uniforme pra poder reordenar e
/// remover antes mesmo do upload acontecer (que só roda no submit do
/// form — ver PropertyFormSheet._submit).
class PropertyImageItem {
  PropertyImageItem.existing(String existingUrl)
      : url = existingUrl,
        file = null,
        // URL já é única por si só, serve de chave estável.
        key = existingUrl;

  PropertyImageItem.pending(XFile pickedFile)
      : url = null,
        file = pickedFile,
        key =
            'pending_${pickedFile.path}_${DateTime.now().microsecondsSinceEpoch}';

  final String? url;
  final XFile? file;

  /// Chave estável usada pelo ReorderableListView — precisa sobreviver
  /// a rebuilds sem mudar, mesmo pra itens ainda não salvos.
  final String key;

  bool get isPending => file != null;
}

/// Campo controlado (padrão do ProducerPickerField): recebe a lista
/// atual de imagens e devolve, via [onChanged], a lista nova a cada
/// alteração (adicionar, remover ou reordenar). Quem usa este widget
/// decide quando de fato subir os arquivos pendentes pro Storage — o
/// campo em si só mexe em estado local (a lista de itens).
///
/// A ORDEM da lista é a própria estrutura de persistência da ordem do
/// carrossel (ver PropertyModel.images) — arrastar um item aqui já é
/// reordenar o carrossel. O primeiro item é sempre a capa.
class PropertyImagesField extends StatelessWidget {
  const PropertyImagesField({
    super.key,
    required this.items,
    required this.onChanged,
    required this.onAddPressed,
    this.uploading = false,
  });

  final List<PropertyImageItem> items;
  final ValueChanged<List<PropertyImageItem>> onChanged;

  /// Disparado pelo botão "+" — quem usa o campo decide como abrir o
  /// seletor (PropertyFormSheet delega pro PropertyImageService).
  final VoidCallback onAddPressed;

  /// true enquanto o submit do form está subindo as imagens pendentes
  /// — desabilita adicionar/remover/reordenar pra evitar mexer na
  /// lista no meio do upload.
  final bool uploading;

  void _removeAt(int index) {
    final next = [...items]..removeAt(index);
    onChanged(next);
  }

  void _reorder(int oldIndex, int newIndex) {
    final next = [...items];
    if (newIndex > oldIndex) newIndex -= 1;
    final item = next.removeAt(oldIndex);
    next.insert(newIndex, item);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          // 96 (foto) + 8 de folga acima (pro "x" de remover e a
          // alcinha de arrastar, que ficam um pouco pra fora do
          // card) + 8 de folga abaixo, pra nada ficar cortado.
          height: 112,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Botão "+" fixo, fora da lista rolável — antes ele era
              // o último item do ReorderableListView e sumia de vista
              // assim que havia fotos suficientes pra preencher a
              // largura (só reaparecia arrastando uma foto até o
              // fim). Ficando fixo à esquerda, fora do scroll, está
              // sempre visível.
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 10),
                child: _AddImageTile(
                  onTap: uploading ? null : onAddPressed,
                ),
              ),

              // Só as fotos entram no scroll/reorder — sem o botão
              // no meio, não precisa mais do índice especial pra
              // ignorá-lo no onReorder.
              if (items.isNotEmpty)
                Expanded(
                  child: ReorderableListView.builder(
                    scrollDirection: Axis.horizontal,
                    buildDefaultDragHandles: false,
                    itemCount: items.length,
                    onReorder: uploading ? (_, __) {} : _reorder,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      // A key/listener de reorder ficam no item
                      // inteiro (exigência do ReorderableListView),
                      // mas quem de fato inicia o arrasto é só a
                      // alcinha dentro de _ImageTile — arrastar a
                      // foto em si (ou tocar no "x") não compete mais
                      // com o gesto de rolar a lista.
                      return Padding(
                        key: ValueKey(item.key),
                        padding: const EdgeInsets.only(top: 8, right: 10),
                        child: _ImageTile(
                          item: item,
                          index: index,
                          isCover: index == 0,
                          dragEnabled: !uploading,
                          onRemove:
                              uploading ? null : () => _removeAt(index),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          items.isEmpty
              ? 'Nenhuma foto adicionada ainda.'
              : 'Arraste pelo ícone para reordenar. A primeira será a capa.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    required this.item,
    required this.index,
    required this.isCover,
    required this.dragEnabled,
    required this.onRemove,
  });

  final PropertyImageItem item;

  /// Posição atual na lista — exigido pelo listener de drag da
  /// alcinha (ReorderableListView precisa saber de qual índice o
  /// arrasto está partindo).
  final int index;
  final bool isCover;
  final bool dragEnabled;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 96,
            height: 96,
            child: item.isPending
                ? Image.file(File(item.file!.path), fit: BoxFit.cover)
                : Image.network(
                    item.url!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stack) => Container(
                      color: const Color(0xFFE8F5E9),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ),
          ),
        ),
        if (isCover)
          Positioned(
            left: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Capa',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        if (onRemove != null)
          Positioned(
            top: -8,
            right: -8,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),

        // Alcinha de arrastar — centralizada por cima da própria foto
        // em vez de num canto, pra não disputar espaço/toque com o
        // "x" de remover (que fica no canto superior direito). É ela
        // quem de fato inicia o reorder; arrastar o resto da foto (ou
        // tocar no "x") não compete mais com o gesto de rolar a
        // lista.
        Positioned.fill(
          child: Center(
            child: ReorderableDragStartListener(
              index: index,
              enabled: dragEnabled,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.open_with,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddImageTile extends StatelessWidget {
  const _AddImageTile({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.4),
            style: BorderStyle.solid,
          ),
        ),
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_a_photo_outlined, color: Color(0xFF2E7D32)),
            SizedBox(height: 4),
            Text(
              'Adicionar',
              style: TextStyle(
                color: Color(0xFF2E7D32),
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}