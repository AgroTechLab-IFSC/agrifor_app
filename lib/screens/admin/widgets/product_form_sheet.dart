import 'package:flutter/material.dart';
import 'package:agrifor_app/models/product_model.dart';

/// Bottom sheet de cadastro (product == null) ou edição de produto,
/// sempre aberto a partir do ExpansionTile de uma categoria — não tem
/// seletor de categoria aqui. Trocar a categoria de um produto já
/// existente não é suportado por esta tela (teria que excluir e
/// recriar dentro da categoria certa).
class ProductFormSheet extends StatefulWidget {
  const ProductFormSheet({
    super.key,
    this.product,
    required this.categoryName,
    required this.onSave,
  });

  final ProductModel? product;

  /// Nome da categoria (só exibição, contexto pro admin).
  final String categoryName;

  final Future<void> Function(String name) onSave;

  @override
  State<ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.product?.name ?? '',
  );
  bool _saving = false;

  bool get _isEditing => widget.product != null;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await widget.onSave(_nameController.text);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? 'Editar produto' : 'Novo produto',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Categoria: ${widget.categoryName}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nome do produto'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe um nome' : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_isEditing ? 'Salvar alterações' : 'Criar produto'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}