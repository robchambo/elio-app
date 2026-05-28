// lib/screens/account/password_prompt.dart
//
// Sprint 17 — modal password prompt extracted from AccountScreen for the
// Email/password Delete Account reauth flow. Pure UI helper so it can be
// widget-tested without the rest of AccountScreen's Firebase initState
// chain.
//
// Behaviour contract:
//
//   - Shows a non-dismissible AlertDialog with an obscured TextField
//     pre-focused.
//   - Returns the entered password string if the user taps Confirm or
//     submits via the keyboard.
//   - Returns `null` if the user taps Cancel.
//   - Caller is responsible for credentialising + retrying on wrong-
//     password (FirebaseAuthException surfaces upstream in
//     AccountService.deleteAccount).

import 'package:flutter/material.dart';

import '../../theme/elio_spacing.dart';

/// Show a modal password-confirmation dialog for the given [email].
///
/// Returns the entered password (may be empty if the user submits with
/// an empty field — caller should treat empty as "cancel" too), or
/// `null` if the dialog was dismissed via Cancel.
Future<String?> promptForPassword(
  BuildContext context, {
  required String email,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PasswordPromptDialog(email: email),
  );
}

/// Internal stateful widget so the TextEditingController's lifecycle is
/// owned by the dialog's State and gets disposed when the dialog is
/// removed from the tree — not earlier (which would crash a still-
/// rendering TextField).
class _PasswordPromptDialog extends StatefulWidget {
  final String email;
  const _PasswordPromptDialog({required this.email});

  @override
  State<_PasswordPromptDialog> createState() => _PasswordPromptDialogState();
}

class _PasswordPromptDialogState extends State<_PasswordPromptDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() => Navigator.of(context).pop(_controller.text);
  void _cancel() => Navigator.of(context).pop(null);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Confirm your password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'To delete your account, please confirm your password for ${widget.email}.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: ElioSpacing.md),
          TextField(
            controller: _controller,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _confirm(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: _cancel, child: const Text('Cancel')),
        FilledButton(onPressed: _confirm, child: const Text('Confirm')),
      ],
    );
  }
}
