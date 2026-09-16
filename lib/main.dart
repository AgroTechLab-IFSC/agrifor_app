import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'map/map_region_setup.dart';
import 'map/property_map_view.dart' show kLagesTileStore;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await initTileCache(); // rápido, só abre/cria o store local

  _downloadMapInBackground(); // sem await, roda por trás

  runApp(const App());
}

void _downloadMapInBackground() async {
  try {
    final store = FMTCStore(kLagesTileStore);
    final stats = await store.stats.all; // confirmar nome do método na sua versão do FMTC
    if (stats.length > 0) return; // já tem cache, não baixa de novo

    // ALTERADO: downloadLagesRegion() -> downloadPropertiesRegion().
    // Agora é async porque busca as propriedades no Firestore antes
    // de calcular a área e começar o download.
    final download = await downloadPropertiesRegion();
    download.downloadProgress.listen(
      (progress) {
        debugPrint('Baixando mapa offline: ${progress.percentageProgress.toStringAsFixed(0)}%');
      },
      onDone: () {
        debugPrint('Mapa offline baixado com sucesso.');
      },
      onError: (e) {
        debugPrint('Falha ao baixar mapa offline: $e');
      },
    );
  } catch (e) {
    debugPrint('Erro ao iniciar download do mapa offline: $e');
  }
}