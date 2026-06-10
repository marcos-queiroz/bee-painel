import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

class _PinDialogState extends State<PinDialog> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _fieldFocus = FocusNode();
  final _confirmFocus = FocusNode();
  String? _error;
  double _lastBottomInset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Na Android TV o campo de texto "prende" o D-pad (as setas movem o cursor
    // do texto e nunca saem do campo). As setas cima/baixo movem o FOCO para
    // fora do campo, destravando a navegacao apos abrir/fechar o teclado.
    _fieldFocus.onKeyEvent = (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        node.focusInDirection(TraversalDirection.down);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        node.focusInDirection(TraversalDirection.up);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _fieldFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  // Ao fechar o teclado virtual na Android TV, o foco do D-pad costuma ficar
  // "perdido". Detectamos o fechamento do IME e devolvemos o foco para um alvo
  // navegavel (botao Confirmar).
  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bottom = MediaQuery.of(context).viewInsets.bottom;
      final keyboardClosed = _lastBottomInset > 0 && bottom == 0;
      _lastBottomInset = bottom;
      if (keyboardClosed) {
        _fieldFocus.unfocus();
        _confirmFocus.requestFocus();
      }
    });
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
        focusNode: _fieldFocus,
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
        FilledButton(
          focusNode: _confirmFocus,
          onPressed: _submit,
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
