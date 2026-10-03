import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/pin_vault.dart';
import '../domain/models.dart';

Future<bool> requestManagementAccess(
  BuildContext context,
  PinVault vault,
) async {
  if (vault.gate.isUnlocked) return true;
  final exists = await vault.exists();
  if (!context.mounted) return false;
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _PinDialog(vault: vault, creating: !exists),
      ) ??
      false;
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.vault, required this.creating});
  final PinVault vault;
  final bool creating;
  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final pin = TextEditingController();
  final repeat = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    pin.dispose();
    repeat.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (widget.creating) {
        if (pin.text != repeat.text) {
          throw const AppFailure('Los dos PIN deben coincidir.');
        }
        await widget.vault.create(pin.text);
      } else {
        await widget.vault.unlock(pin.text);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is AppFailure
              ? e.message
              : 'No se pudo abrir la administración.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(TextEditingController controller, String label) => TextField(
    controller: controller,
    obscureText: true,
    keyboardType: TextInputType.number,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(6),
    ],
    decoration: InputDecoration(labelText: label),
  );
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.creating ? 'Crear PIN de administración' : 'Abrir administración',
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Ingresa seis números.'),
          const SizedBox(height: 16),
          field(pin, 'PIN'),
          if (widget.creating) ...[
            const SizedBox(height: 12),
            field(repeat, 'Repetir PIN'),
          ],
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(error!),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context, false),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: busy ? null : submit,
        child: Text(busy ? 'Espera…' : 'Continuar'),
      ),
    ],
  );
}
