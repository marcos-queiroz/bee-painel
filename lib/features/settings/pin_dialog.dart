import 'package:flutter/material.dart';

import '../../core/pin_utils.dart';

/// Diálogo de verificação de PIN para sair do kiosque.
/// Retorna `true` se o PIN conferir (ou não houver PIN).
class PinDialog extends StatefulWidget {
  const PinDialog({super.key, required this.expectedHash});

  final String? expectedHash;

  static Future<bool> show(BuildContext context, String? expectedHash) async {
    if (expectedHash == null || expectedHash.isEmpty) return true;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => PinDialog(expectedHash: expectedHash),
    );
    return ok ?? false;
  }

  @override
  State<PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<PinDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (PinUtils.verify(_controller.text, widget.expectedHash)) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = 'PIN incorreto');
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('PIN para sair'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(hintText: 'Digite o PIN', errorText: _error),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Confirmar')),
      ],
    );
  }
}
