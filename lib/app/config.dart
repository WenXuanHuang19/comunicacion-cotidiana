import 'package:firebase_core/firebase_core.dart';

class AppConfig {
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const senderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
  static const webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const suggestionUrl = String.fromEnvironment('SUGGESTION_ENDPOINT');
  static bool get configured =>
      [apiKey, appId, projectId, senderId].every((s) => s.isNotEmpty);
  static FirebaseOptions get firebaseOptions => const FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: senderId,
    projectId: projectId,
    iosBundleId: 'mx.edu.comunicacion.comunicacionCotidiana',
  );
}
