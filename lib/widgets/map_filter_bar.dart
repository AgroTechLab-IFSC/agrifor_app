import 'package:flutter/material.dart';
import '../../models/category_model.dart';

class MapFilterBar extends StatelessWidget {
  final List<CategoryModel> categories;
  final Set<String> activeFilters; // guarda categoryId, não o nome
  final ValueChanged<String> onToggle;

  const MapFilterBar({
    super.key,
    required this.categories,
    required this.activeFilters,
    required this.onToggle,
  });

  // Sentinela pro chip "Todos" — não colide com nenhum categoryId real
  // do Firestore, que sempre vem de doc.id.
  static const String allFilterId = '__all__';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SizedBox(
        height: 32,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: categories.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _FilterChip(
                label: 'Todos',
                active: activeFilters.contains(allFilterId),
                onTap: () => onToggle(allFilterId),
              );
            }
            final category = categories[index - 1];
            final active = activeFilters.contains(category.id);
            return _FilterChip(
              label: category.name,
              active: active,
              onTap: () => onToggle(category.id),
            );
          },
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF2E7D32) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? const Color(0xFF2E7D32) : Colors.black12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.black54,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}