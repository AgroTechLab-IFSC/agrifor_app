import 'package:flutter/material.dart';

class TelaNoticias extends StatelessWidget {
  const TelaNoticias({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notícias'),
      ),
      body: const Center(
        child: Text('Aqui serão exibidas as notícias relacionadas ao projeto Agrifor.',
        style: TextStyle(fontSize: 24)),
      ),
    );
  }
}