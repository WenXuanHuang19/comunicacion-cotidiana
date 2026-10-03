import 'dart:io';
import 'package:flutter/material.dart';
import '../app/account_dependencies.dart';
import '../application/board_view_model.dart';
import '../application/management_gate.dart';
import '../data/pin_vault.dart';
import '../domain/ports.dart';
import '../domain/models.dart';
import 'management_view.dart';
import 'pin_dialog.dart';

class BoardView extends StatefulWidget {
  const BoardView({
    super.key,
    required this.dependencies,
    required this.signOut,
    this.isPreview = false,
  });
  final AccountDependencies dependencies;
  final Future<void> Function() signOut;
  final bool isPreview;
  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> with WidgetsBindingObserver {
  final input = TextEditingController();
  ManagementGate get gate => widget.dependencies.gate;
  CommunicationRepository get repository => widget.dependencies.repository;
  PinVault get vault => widget.dependencies.vault;
  BoardViewModel get vm => widget.dependencies.board;
  String? loadError;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    vm.addListener(changed);
    reload();
  }

  Future<void> reload() async {
    try {
      await vm.load();
      if (mounted) setState(() => loadError = null);
    } catch (_) {
      if (mounted) {
        setState(
          () => loadError = 'No se pudieron abrir los perfiles locales.',
        );
      }
    }
  }

  void changed() {
    if (!mounted) return;
    if (input.text != vm.originalInput) {
      input.value = TextEditingValue(
        text: vm.originalInput,
        selection: TextSelection.collapsed(offset: vm.originalInput.length),
      );
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      gate.lock();
      vm.suspend();
    }
  }

  Future<void> manage() async {
    await vm.suspend();
    if (!mounted ||
        !await requestManagementAccess(context, vault) ||
        !mounted) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ManagementView(
          repository: repository,
          addCard: widget.dependencies.addCard,
          vault: vault,
          profiles: vm.profiles,
          current: vm.profile,
          signOut: () async {
            gate.lock();
            await widget.signOut();
          },
        ),
      ),
    );
    gate.lock();
    if (mounted) {
      await reload();
      await vm.refreshCards();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    gate.lock();
    vm.removeListener(changed);

    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Comunicación cotidiana'),
      bottom: widget.isPreview
          ? const PreferredSize(
              preferredSize: Size.fromHeight(28),
              child: Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Vista previa · datos locales'),
              ),
            )
          : null,
      actions: [
        if (widget.isPreview)
          IconButton(
            onPressed: widget.signOut,
            tooltip: 'Salir de la vista previa',
            icon: const Icon(Icons.logout),
          ),
        IconButton(
          onPressed: manage,
          tooltip: 'Administración',
          icon: const Icon(Icons.lock_outline),
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (loadError != null) ...[
                Text(loadError!),
                TextButton(
                  onPressed: reload,
                  child: const Text('Volver a intentar'),
                ),
              ],
              if (vm.profiles.isEmpty) ...[
                const SizedBox(height: 36),
                const Text(
                  'Agrega el primer perfil para empezar.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: manage,
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Crear perfil'),
                ),
              ] else ...[
                DropdownButtonFormField<String>(
                  initialValue: vm.profile?.id,
                  decoration: const InputDecoration(labelText: 'Perfil'),
                  items: vm.profiles
                      .map(
                        (p) =>
                            DropdownMenuItem(value: p.id, child: Text(p.name)),
                      )
                      .toList(),
                  onChanged: (id) async {
                    if (id != null) {
                      gate.lock();
                      await vm.selectProfile(
                        vm.profiles.firstWhere((p) => p.id == id),
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: BoardTheme.values
                      .map(
                        (t) => ChoiceChip(
                          label: Text(t.label),
                          selected: vm.theme == t,
                          onSelected: (_) => vm.changeTheme(t),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: input,
                  maxLines: null,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Tu mensaje',
                    hintText: 'Toca tarjetas o escribe aquí',
                  ),
                  onChanged: vm.editInput,
                ),
                if (vm.selectedSuggestion != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Sugerencia elegida'),
                          const SizedBox(height: 8),
                          Text(
                            vm.output,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          TextButton(
                            onPressed: vm.useOriginal,
                            child: const Text('Usar mi mensaje original'),
                          ),
                        ],
                      ),
                    ),
                  ),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: vm.speaking || vm.output.trim().isEmpty
                          ? null
                          : vm.play,
                      icon: const Icon(Icons.volume_up),
                      label: Text(
                        vm.speaking ? 'Reproduciendo…' : 'Reproducir mensaje',
                      ),
                    ),
                    OutlinedButton(
                      onPressed: vm.clear,
                      child: const Text('Borrar mensaje'),
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          widget.isPreview ||
                              vm.loadingSuggestions ||
                              vm.originalInput.trim().isEmpty
                          ? null
                          : vm.requestSuggestions,
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: const Text('Pedir sugerencias en línea'),
                    ),
                  ],
                ),
                if (widget.isPreview)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'La vista previa permite usar tarjetas y texto. Las sugerencias de IA requieren una cuenta y el servicio en línea.',
                    ),
                  ),
                if (vm.loadingSuggestions)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(),
                  ),
                if (vm.notice != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Semantics(liveRegion: true, child: Text(vm.notice!)),
                  ),
                if (vm.suggestions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Elige una sugerencia y después toca Reproducir mensaje.',
                  ),
                  ...vm.suggestions.map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton(
                        onPressed: () => vm.chooseSuggestion(s),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(s),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  vm.theme.label,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cada tarjeta se lee al tocarla y se agrega al mensaje.',
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: vm.cards.map((c) {
                      final columns = constraints.maxWidth >= 700 ? 4 : 2;
                      return SizedBox(
                        width:
                            (constraints.maxWidth - (columns - 1) * 12) /
                            columns,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                            minimumSize: const Size(0, 150),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: vm.speaking ? null : () => vm.tapCard(c),
                          child: Column(
                            children: [
                              if (c.photoPath != null)
                                Image.file(
                                  File(c.photoPath!),
                                  height: 68,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.image_not_supported_outlined,
                                    size: 48,
                                  ),
                                )
                              else
                                Text(
                                  c.symbol,
                                  style: const TextStyle(fontSize: 38),
                                ),
                              const SizedBox(height: 12),
                              Text(
                                c.label,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
