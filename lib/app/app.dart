import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../data/auth_repository.dart';
import '../data/local_preview.dart';
import '../data/local_store.dart';
import '../ui/auth_view.dart';
import '../ui/board_view.dart';
import 'account_dependencies.dart';

class CommunicationApp extends StatefulWidget {
  const CommunicationApp({
    super.key,
    this.store,
    this.startupIssue,
    this.openPreviewStore,
  });
  final LocalStore? store;
  final String? startupIssue;
  final Future<LocalStore> Function()? openPreviewStore;
  @override
  State<CommunicationApp> createState() => _CommunicationAppState();
}

class _CommunicationAppState extends State<CommunicationApp> {
  late final AuthRepository? auth = widget.store == null
      ? null
      : AuthRepository();
  LocalStore? _previewStore;
  bool _openingPreview = false;
  bool _previewActive = false;
  String? _previewError;
  bool get _canPreview => kDebugMode && widget.openPreviewStore != null;

  Future<void> _enterPreview() async {
    if (!_canPreview || _openingPreview) return;
    setState(() {
      _openingPreview = true;
      _previewError = null;
    });
    try {
      final store = _previewStore ?? await widget.openPreviewStore!();
      if (!mounted) {
        await store.database.close();
        return;
      }
      setState(() {
        _previewStore = store;
        _previewActive = true;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _previewError =
              'No se pudo abrir la vista previa local. Vuelve a intentarlo.',
        );
      }
    } finally {
      if (mounted) setState(() => _openingPreview = false);
    }
  }

  Future<void> _leavePreview() async {
    setState(() => _previewActive = false);
  }

  @override
  void dispose() {
    _previewStore?.database.close();
    super.dispose();
  }

  Widget _home() {
    if (_openingPreview) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_previewActive) {
      return _AccountHost(
        key: const ValueKey('local-preview'),
        store: _previewStore!,
        ownerId: LocalPreview.ownerId,
        idToken: () async => null,
        signOut: _leavePreview,
        isPreview: true,
      );
    }
    if (widget.store == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Comunicación cotidiana')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_canPreview) ...[
                    const Icon(
                      Icons.forum_outlined,
                      size: 52,
                      color: Color(0xff126b67),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Prueba el tablero con un perfil local, sin crear una cuenta.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _enterPreview,
                      icon: const Icon(Icons.preview_outlined),
                      label: const Text('Probar sin iniciar sesión'),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Los datos de prueba se guardan en este dispositivo. Las sugerencias de IA no están disponibles en la vista previa.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                  ],
                  Text(
                    widget.startupIssue ?? 'No se pudo iniciar.',
                    textAlign: TextAlign.center,
                  ),
                  if (_previewError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(_previewError!),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return StreamBuilder<User?>(
      stream: auth!.changes,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        return user == null
            ? Column(
                children: [
                  if (_previewError != null)
                    SafeArea(
                      bottom: false,
                      child: Material(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(_previewError!),
                        ),
                      ),
                    ),
                  Expanded(
                    child: AuthView(
                      auth: auth!,
                      onPreview: _canPreview ? _enterPreview : null,
                    ),
                  ),
                ],
              )
            : _AccountHost(
                key: ValueKey(user.uid),
                store: widget.store!,
                ownerId: user.uid,
                idToken: () => user.getIdToken(),
                signOut: auth!.signOut,
              );
      },
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Comunicación cotidiana',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff126b67)),
      scaffoldBackgroundColor: const Color(0xfff7faf9),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 52)),
      ),
    ),
    home: _home(),
  );
}

class _AccountHost extends StatefulWidget {
  const _AccountHost({
    super.key,
    required this.store,
    required this.ownerId,
    required this.idToken,
    required this.signOut,
    this.isPreview = false,
  });
  final LocalStore store;
  final String ownerId;
  final Future<String?> Function() idToken;
  final Future<void> Function() signOut;
  final bool isPreview;
  @override
  State<_AccountHost> createState() => _AccountHostState();
}

class _AccountHostState extends State<_AccountHost> {
  late final dependencies = AccountDependencies(
    ownerId: widget.ownerId,
    store: widget.store,
    idToken: widget.idToken,
    allowOnlineSuggestions: !widget.isPreview,
  );
  @override
  Widget build(BuildContext context) => BoardView(
    dependencies: dependencies,
    signOut: widget.signOut,
    isPreview: widget.isPreview,
  );
  @override
  void dispose() {
    dependencies.dispose();
    super.dispose();
  }
}
