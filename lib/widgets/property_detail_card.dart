import 'package:flutter/material.dart';
import '../../models/property_model.dart';

class PropertyDetailCard extends StatelessWidget {
  final PropertyModel property;

  /// Nomes de exibição das categorias da propriedade (resolvidos pelo
  /// chamador a partir de property.categoryIds — o card não busca no
  /// Firestore).
  final List<String> categoryNames;

  final VoidCallback onClose;
  final VoidCallback onSeeMore;

  const PropertyDetailCard({
    super.key,
    required this.property,
    required this.categoryNames,
    required this.onClose,
    required this.onSeeMore,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.eco_rounded, color: Color(0xFF2E7D32), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // TODO: quando existir resolução de nome do
                        // produtor via users/{uid} (property.ownerIds),
                        // trocar por esse nome — por ora usa propertyName.
                        Text(
                          property.propertyName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B2E1B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded, color: Colors.black45),
                    splashRadius: 20,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (categoryNames.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categoryNames
                      .map((t) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F5EE),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFCFE4CC)),
                            ),
                            child: Text(
                              t,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              if (property.summary.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  property.summary,
                  style: const TextStyle(fontSize: 13.5, height: 1.4, color: Color(0xFF454545)),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: onSeeMore,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Ver mais',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}