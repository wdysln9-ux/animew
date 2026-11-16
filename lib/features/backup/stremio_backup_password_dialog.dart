import 'package:flutter/material.dart';

import '../../core/app_mode.dart';
import '../../core/di/injector.dart';
import '../../core/tv/tv_text_field.dart';
import '../../core/ui/app_dialog.dart';
import '../../l10n/l10n.dart';

class StremioBackupPasswordDialog extends StatefulWidget {
  const StremioBackupPasswordDialog({super.key, required this.confirm});
  final bool confirm;
  @override
  State<StremioBackupPasswordDialog> createState() =>
      _StremioBackupPasswordDialogState();
}

class _StremioBackupPasswordDialogState
    extends State<StremioBackupPasswordDialog> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  String? _error;

  void _submit() {
    final password = _password.text;
    final error = password.length < 8 || password.length > 1024
        ? 'Password minimal 8 karakter.'
        : widget.confirm && password != _confirmation.text
        ? 'Password tidak cocok.'
        : null;
    if (error != null) {
      setState(() => _error = error);
    } else {
      Navigator.of(context).pop(password);
    }
  }

  Widget _field(TextEditingController controller, String label) {
    final decoration = InputDecoration(
      labelText: label,
      errorText: controller == _password ? _error : null,
    );
    if (sl.isRegistered<AppMode>() && sl<AppMode>().isTv) {
      return TvTextField(
        controller: controller,
        decoration: decoration,
        obscureText: true,
        autocorrect: false,
        enableSuggestions: false,
        onSubmitted: (_) => _submit(),
      );
    }
    return TextField(
      controller: controller,
      decoration: decoration,
      obscureText: true,
      autocorrect: false,
      enableSuggestions: false,
      onSubmitted: (_) => _submit(),
    );
  }

  @override
  Widget build(BuildContext context) => TvAlertDialog(
    title: widget.confirm ? 'Lindungi backup add-on' : 'Buka backup add-on',
    body: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.confirm
              ? 'URL add-on bisa berisi token akun pribadi. Simpan password ini untuk memulihkannya di perangkat lain.'
              : 'Masukkan password yang digunakan saat backup ini dibuat.',
        ),
        const SizedBox(height: 12),
        _field(_password, context.l10n.password),
        if (widget.confirm) ...[
          const SizedBox(height: 12),
          _field(_confirmation, 'Konfirmasi password'),
        ],
      ],
    ),
    actions: [
      TvAlertAction(
        label: context.l10n.cancel,
        onTap: () => Navigator.of(context).pop(),
      ),
      TvAlertAction(
        label: 'Lanjutkan',
        primary: true,
        autofocus: true,
        onTap: _submit,
      ),
    ],
  );

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }
}
