import 'package:flutter/material.dart';
import 'package:agrifor_app/models/category_model.dart';

/// Bottom sheet de cadastro (category == null) ou edição de categoria.
/// Só tem o campo nome — `order` é definido na criação como
/// categories.length (ver AdminCategoriesController.createCategory) e
/// não é editável por aqui.
class CategoryFormSheet extends StatefulWidget {
  const CategoryFormSheet({super.key, this.category, required this.onSave});

  final CategoryModel? category;

  /// Recebe o nome digitado (sem trim — quem implementa faz o trim,
  /// ver AdminCategoriesController.createCategory/renameCategory).
  final Future<void> Function(String name) onSave;

  @override
  State<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.category?.name ?? '',
  );
  bool _saving = false;

  bool get _isEditing => widget.category != null;

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
              _isEditing ? 'Editar categoria' : 'Nova categoria',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nome da categoria'),
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
                  : Text(_isEditing ? 'Salvar alterações' : 'Criar categoria'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}