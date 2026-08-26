import 'package:flutter/material.dart';
import 'package:agrifor_app/controllers/admin_dashboard_controller.dart';
import 'package:agrifor_app/repositories/property_repository.dart';
import 'package:agrifor_app/repositories/production_system_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final AdminDashboardController _controller = AdminDashboardController(
    propertyRepository: PropertyRepository(FirebaseFirestore.instance),
    productionSystemRepository:
        ProductionSystemRepository(FirebaseFirestore.instance),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_controller.errorMessage != null) {
          return Center(child: Text(_controller.errorMessage!));
        }

        final total = _controller.totalProperties;

        return GridView(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1,
          ),
          children: [
            _TotalCard(total: total),
            for (final item in _controller.systemCounts)
              _SystemPercentCard(
                name: item.name,
                count: item.count,
                total: total,
              ),
          ],
        );
      },
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.total});
  final int total;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$total',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Propriedades',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemPercentCard extends StatelessWidget {
  const _SystemPercentCard({
    required this.name,
    required this.count,
    required this.total,
  });

  final String name;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    // total == 0 (banco vazio) -> evita divisão por zero, mostra 0%
    final percent = total == 0 ? 0 : ((count / total) * 100).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$percent%',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '$count propriedade${count == 1 ? '' : 's'}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}