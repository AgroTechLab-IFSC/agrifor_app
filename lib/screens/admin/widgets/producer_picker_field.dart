import 'package:flutter/material.dart';
import 'package:agrifor_app/models/app_user_model.dart';

/// Campo de vínculo de produtor(es): busca por nome/email entre os
/// produtores ainda não selecionados, com resultados exibidos INLINE
/// (na própria árvore de widgets, não em Overlay) logo abaixo do campo.
/// Os já selecionados aparecem como Chips, removíveis pelo "x".
///
/// IMPORTANTE: propositalmente não usa RawAutocomplete/Autocomplete
/// (que renderizam a lista de opções via OverlayEntry +
/// CompositedTransformFollower). Dentro de um DraggableScrollableSheet
/// dentro de um ListView, abrir o teclado muda MediaQuery.viewInsets e
/// redimensiona/rola o sheet — o que move o campo na tela e faz esse
/// Overlay perder a referência de posição e fechar sozinho (o bug de
/// "abre, mostra e reseta"). Uma lista inline não depende de posição
/// global, então não sofre com isso.
class ProducerPickerField extends StatefulWidget {
  const ProducerPickerField({
    super.key,
    required this.allProducers,
    required this.selectedIds,
    required this.onChanged,
  });

  /// União de availableProducers (stream, sem propertyId) +
  /// currentProducers (já vinculados a esta propriedade) — resolvida por
  /// quem usa o widget, igual já era feito antes na tela.
  final List<AppUserModel> allProducers;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<ProducerPickerField> createState() => _ProducerPickerFieldState();
}

class _ProducerPickerFieldState extends State<ProducerPickerField> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  // Controla se a lista inline de resultados deve aparecer — some ao
  // perder foco e volta ao focar o campo.
  bool _showResults = false;

  List<AppUserModel> get _selected => widget.allProducers
      .where((p) => widget.selectedIds.contains(p.uid))
      .toList();

  List<AppUserModel> get _unselected => widget.allProducers
      .where((p) => !widget.selectedIds.contains(p.uid))
      .toList();

  List<AppUserModel> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _unselected;
    return _unselected
        .where((p) =>
            p.name.toLowerCase().contains(query) ||
            p.email.toLowerCase().contains(query))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      // addListener roda fora da fase de build, setState é seguro aqui.
      setState(() => _showResults = _focusNode.hasFocus);
    });
  }

  void _add(AppUserModel producer) {
    widget.onChanged({...widget.selectedIds, producer.uid});
    _searchController.clear();
    setState(() {}); // atualiza a lista filtrada imediatamente
    // Mantém o foco no campo pra permitir adicionar vários em sequência.
    _focusNode.requestFocus();
  }

  void _remove(String uid) {
    widget.onChanged({...widget.selectedIds}..remove(uid));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          focusNode: _focusNode,
          enabled: _unselected.isNotEmpty,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Adicionar produtor',
            hintText: _unselected.isEmpty
                ? 'Nenhum produtor disponível'
                : 'Buscar por nome ou email',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => setState(() => _searchController.clear()),
                  )
                : null,
            border: const OutlineInputBorder(),
          ),
        ),

        // Lista inline (não Overlay) — só aparece com o campo focado e
        // enquanto houver algo pra mostrar.
        if (_showResults && _unselected.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Nenhum produtor encontrado.'),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final p = _filtered[index];
                      return ListTile(
                        dense: true,
                        title: Text(p.name),
                        subtitle: Text(p.email),
                        onTap: () => _add(p),
                      );
                    },
                  ),
          ),
        ],

        const SizedBox(height: 12),
        if (_selected.isEmpty)
          Text(
            'Nenhum produtor vinculado ainda.',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selected.map((p) {
              return Chip(
                label: Text(p.name),
                onDeleted: () => _remove(p.uid),
              );
            }).toList(),
          ),
      ],
    );
  }
}