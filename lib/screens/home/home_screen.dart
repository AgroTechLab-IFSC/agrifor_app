// lib/screens/home/home_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../map/property_map_view.dart';
import '../../models/property_model.dart';
import '../../repositories/property_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final PropertyRepository _repository =
      PropertyRepository(FirebaseFirestore.instance);
  late final Stream<List<PropertyModel>> _propertiesStream =
      _repository.watchAll();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PropertyModel>>(
      stream: _propertiesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Não foi possível carregar as propriedades.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return PropertyMapView(properties: snapshot.data!);
      },
    );
  }
}