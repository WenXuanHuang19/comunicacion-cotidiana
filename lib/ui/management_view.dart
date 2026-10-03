import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../application/add_card.dart';
import '../domain/ports.dart';
import '../data/pin_vault.dart';
import '../domain/models.dart';
import 'pin_dialog.dart';

class ManagementView extends StatefulWidget {
  const ManagementView({
    super.key,
    required this.repository,
    required this.addCard,
    required this.vault,
    required this.profiles,
    required this.current,
    required this.signOut,
  });
  final CommunicationRepository repository;
  final AddCard addCard;
  final PinVault vault;
  final List<UserProfile> profiles;
  final UserProfile? current;
  final Future<void> Function() signOut;
  @override
  State<ManagementView> createState() => _ManagementViewState();
}

class _ManagementViewState extends State<ManagementView>
    with WidgetsBindingObserver {
  late List<UserProfile> profiles = List.of(widget.profiles);
  late UserProfile? selected = widget.current;
  List<InteractionRecord> records = [];
  bool busy = false;
  String? message;
  int _historyGeneration = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadHistory();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _historyGeneration++;
      widget.vault.gate.lock();
      if (mounted) setState(() => records = []);
    }
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  Future<bool> access() async =>
      await requestManagementAccess(context, widget.vault);
  Future<void> perform(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(
          () => message = e is AppFailure
              ? e.message
              : 'No se pudo guardar el cambio.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> loadHistory() async {
    if (selected == null) return;
    final profileId = selected!.id;
    final generation = ++_historyGeneration;
    try {
      final loaded = await widget.repository.history(profileId);
      if (mounted &&
          generation == _historyGeneration &&
          selected?.id == profileId) {
        setState(() => records = loaded);
      }
    } catch (e) {
      if (mounted && generation == _historyGeneration) {
        setState(
          () => message = e is AppFailure
              ? e.message
              : 'No se pudo abrir el historial.',
        );
      }
    }
  }

  Future<void> addProfile() async {
    if (!await access() || !mounted) return;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NameDialog(),
    );
    if (name == null || !mounted) return;
    await perform(() async {
      if (!await access()) return;
      await widget.repository.addProfile(name);
      profiles = await widget.repository.profiles();
      selected ??= profiles.first;
      await loadHistory();
    });
  }

  Future<void> addCard() async {
    if (selected == null || !await access() || !mounted) return;
    final profileId = selected!.id;
    final draft = await showDialog<_CardDraft>(
      context: context,
      builder: (_) => const _CardDialog(),
    );
    if (draft == null || !mounted) return;
    await perform(() async {
      if (!await access()) return;
      await widget.addCard(
        profileId: profileId,
        theme: draft.theme,
        label: draft.label,
        spoken: draft.spoken,
        photoSource: draft.photo,
      );
      message = 'Tarjeta guardada en este dispositivo.';
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Administración')),
    body: !widget.vault.gate.isUnlocked
        ? Center(
            child: FilledButton(
              onPressed: () async {
                if (await access()) {
                  await loadHistory();
                  if (mounted) setState(() {});
                }
              },
              child: const Text('Ingresar PIN'),
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Los cambios se guardan en este dispositivo. No hay sincronización ni recuperación de estos datos.',
              ),
              const SizedBox(height: 20),
              if (profiles.isNotEmpty)
                DropdownButtonFormField<String>(
                  key: ValueKey(selected?.id),
                  initialValue: selected?.id,
                  decoration: const InputDecoration(
                    labelText: 'Perfil que vas a administrar',
                  ),
                  items: profiles
                      .map(
                        (p) =>
                            DropdownMenuItem(value: p.id, child: Text(p.name)),
                      )
                      .toList(),
                  onChanged: busy
                      ? null
                      : (id) async {
                          setState(() {
                            selected = profiles.firstWhere((p) => p.id == id);
                            records = [];
                          });
                          await loadHistory();
                        },
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: busy ? null : addProfile,
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Agregar perfil'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy || selected == null ? null : addCard,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Agregar tarjeta'),
                  ),
                ],
              ),
              if (message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(message!),
                ),
              const SizedBox(height: 24),
              Text(
                'Historial local',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text(
                'Se muestran las últimas 100 reproducciones guardadas. La ayuda de otra persona se anota manualmente.',
              ),
              if (records.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Este perfil todavía no tiene registros visibles.',
                  ),
                ),
              ...records.map(
                (r) => Card(
                  child: ExpansionTile(
                    title: Text(r.finalText),
                    subtitle: Text(
                      '${r.theme.label} · ${r.createdAt.toLocal().toString().substring(0, 16)}',
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Entrada original: ${r.originalInput}'),
                            Text(
                              'Tipo: ${r.kind == 'card' ? 'Tarjeta' : 'Mensaje'}',
                            ),
                            Text(
                              'Sugerencias: ${r.suggestions.isEmpty ? 'No se usaron' : r.suggestions.join(' / ')}',
                            ),
                            Text(
                              'Elección de IA: ${r.usedSuggestion ? 'Sí' : 'No'}',
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<Assistance>(
                              initialValue: r.assistance,
                              decoration: const InputDecoration(
                                labelText: 'Ayuda de otra persona',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: Assistance.unrecorded,
                                  child: Text('Sin registrar'),
                                ),
                                DropdownMenuItem(
                                  value: Assistance.independent,
                                  child: Text('Sin ayuda observada'),
                                ),
                                DropdownMenuItem(
                                  value: Assistance.supported,
                                  child: Text('Con ayuda observada'),
                                ),
                              ],
                              onChanged: busy
                                  ? null
                                  : (value) => perform(() async {
                                      if (value != null && await access()) {
                                        await widget.repository.annotate(
                                          r.profileId,
                                          r.id,
                                          value,
                                        );
                                        await loadHistory();
                                      }
                                    }),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => perform(() async {
                        if (!await access() || !context.mounted) return;
                        Navigator.pop(context);
                        await widget.signOut();
                      }),
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog();
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final text = TextEditingController();
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Agregar perfil'),
    content: TextField(
      controller: text,
      maxLength: 60,
      decoration: const InputDecoration(labelText: 'Nombre o apodo'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, text.text),
        child: const Text('Guardar'),
      ),
    ],
  );
}

class _CardDraft {
  const _CardDraft(this.label, this.spoken, this.theme, this.photo);
  final String label;
  final String spoken;
  final BoardTheme theme;
  final String? photo;
}

class _CardDialog extends StatefulWidget {
  const _CardDialog();
  @override
  State<_CardDialog> createState() => _CardDialogState();
}

class _CardDialogState extends State<_CardDialog> {
  final label = TextEditingController();
  final spoken = TextEditingController();
  BoardTheme theme = BoardTheme.home;
  String? photo;
  String? error;
  @override
  void dispose() {
    label.dispose();
    spoken.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Agregar tarjeta'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: label,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Palabra o frase'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: spoken,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Texto que se leerá',
              hintText: 'Vacío: se leerá la palabra o frase',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<BoardTheme>(
            initialValue: theme,
            decoration: const InputDecoration(labelText: 'Tablero'),
            items: BoardTheme.values
                .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                .toList(),
            onChanged: (t) {
              if (t != null) setState(() => theme = t);
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                final image = await ImagePicker().pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 1200,
                  maxHeight: 1200,
                  imageQuality: 85,
                );
                if (mounted) setState(() => photo = image?.path ?? photo);
              } catch (_) {
                if (mounted) {
                  setState(() => error = 'No se pudo abrir la galería.');
                }
              }
            },
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(photo == null ? 'Elegir foto' : 'Cambiar foto'),
          ),
          if (error != null) Text(error!),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (label.text.trim().isEmpty) {
            setState(() => error = 'Escribe una palabra o frase.');
            return;
          }
          Navigator.pop(
            context,
            _CardDraft(
              label.text.trim(),
              spoken.text.trim().isEmpty
                  ? label.text.trim()
                  : spoken.text.trim(),
              theme,
              photo,
            ),
          );
        },
        child: const Text('Guardar'),
      ),
    ],
  );
}
