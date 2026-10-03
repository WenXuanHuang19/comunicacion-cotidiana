import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'app/app.dart';
import 'app/config.dart';
import 'data/local_store.dart';
import 'data/local_preview.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LocalStore? store;
  String? issue;
  if (!AppConfig.configured) {
    issue =
        'Falta configurar el servicio de inicio de sesión. Consulta las instrucciones de instalación del proyecto.';
  } else {
    try {
      await Firebase.initializeApp(options: AppConfig.firebaseOptions);
      store = await LocalStore.open();
    } catch (_) {
      issue =
          'No se pudo iniciar la aplicación. Revisa la configuración y el almacenamiento del dispositivo.';
    }
  }
  runApp(
    CommunicationApp(
      store: store,
      startupIssue: issue,
      openPreviewStore: kDebugMode ? LocalPreview.open : null,
    ),
  );
}
