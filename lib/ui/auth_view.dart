import 'package:flutter/material.dart';
import '../data/auth_repository.dart';

class AuthView extends StatefulWidget {
  const AuthView({super.key, required this.auth, this.onPreview});
  final AuthRepository auth;
  final VoidCallback? onPreview;
  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? message;
  Future<void> run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => message = AuthRepository.message(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.forum_outlined,
                  size: 52,
                  color: Color(0xff126b67),
                ),
                const SizedBox(height: 20),
                Text(
                  'Comunicación cotidiana',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Acceso para madres, padres y personas cuidadoras.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => run(
                          () => widget.auth.email(email.text, password.text),
                        ),
                  child: const Text('Iniciar sesión'),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => run(
                          () => widget.auth.email(
                            email.text,
                            password.text,
                            register: true,
                          ),
                        ),
                  child: const Text('Crear cuenta con este correo'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => run(widget.auth.google),
                  icon: const Icon(Icons.account_circle_outlined),
                  label: const Text('Continuar con Google'),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => run(() async {
                          await widget.auth.resetPassword(email.text);
                          if (mounted) {
                            setState(
                              () => message =
                                  'Revisa tu correo para cambiar la contraseña.',
                            );
                          }
                        }),
                  child: const Text('Olvidé mi contraseña'),
                ),
                if (busy) const LinearProgressIndicator(),
                if (message != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(message!, semanticsLabel: message),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Cada dispositivo conserva sus propios perfiles, tarjetas y registros. Iniciar sesión en otro equipo no los recupera.',
                  textAlign: TextAlign.center,
                ),
                if (widget.onPreview != null) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: busy ? null : widget.onPreview,
                    icon: const Icon(Icons.preview_outlined),
                    label: const Text('Probar sin iniciar sesión'),
                  ),
                  const Text(
                    'Vista previa con un perfil local de prueba.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
