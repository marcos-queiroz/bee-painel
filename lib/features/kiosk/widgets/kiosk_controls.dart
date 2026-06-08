import 'package:flutter/material.dart';

/// Controle discreto e sempre visível no canto inferior esquerdo do kiosque,
/// com as ações de sair/voltar (cada uma passa pela verificação de PIN no chamador).
class KioskControls extends StatefulWidget {
  const KioskControls({
    super.key,
    required this.onSettings,
    required this.onHome,
    required this.onQuit,
    this.onTogglePin,
    this.isPinned = false,
  });

  final VoidCallback onSettings;
  final VoidCallback onHome;
  final VoidCallback onQuit;

  /// Fixa/desafixa a URL atual. Se `null`, o botão não é exibido (ex.: demo).
  final VoidCallback? onTogglePin;

  /// Indica se a URL atual está fixada (controla o ícone exibido).
  final bool isPinned;

  @override
  State<KioskControls> createState() => _KioskControlsState();
}

class _KioskControlsState extends State<KioskControls> {
  bool _expanded = false;
  bool _focused = false;

  void _onFocusChange(bool focused) {
    setState(() {
      _focused = focused;
      // No Android TV (D-pad) ao focar o controle ele se expande
      // automaticamente, dispensando o toque.
      if (focused) _expanded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 12,
      left: 12,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: (_expanded || _focused) ? 1.0 : 0.35,
        child: Material(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ControlButton(
                  icon: _expanded ? Icons.chevron_left : Icons.menu_rounded,
                  tooltip: _expanded ? 'Recolher' : 'Opções',
                  autofocus: false,
                  onFocusChange: _onFocusChange,
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
                if (_expanded) ...[
                  if (widget.onTogglePin != null)
                    _ControlButton(
                      icon: widget.isPinned
                          ? Icons.push_pin
                          : Icons.push_pin_outlined,
                      tooltip: widget.isPinned
                          ? 'Desafixar URL'
                          : 'Fixar esta URL',
                      onPressed: widget.onTogglePin!,
                    ),
                  _ControlButton(
                    icon: Icons.settings,
                    tooltip: 'Configurações',
                    onPressed: widget.onSettings,
                  ),
                  _ControlButton(
                    icon: Icons.home_rounded,
                    tooltip: 'Tela inicial',
                    onPressed: widget.onHome,
                  ),
                  _ControlButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Fechar BeePainel',
                    onPressed: widget.onQuit,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatefulWidget {
  const _ControlButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.autofocus = false,
    this.onFocusChange,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool autofocus;
  final ValueChanged<bool>? onFocusChange;

  @override
  State<_ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<_ControlButton> {
  late final FocusNode _node = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocus);
  }

  void _onFocus() {
    if (_focused == _node.hasFocus) return;
    setState(() => _focused = _node.hasFocus);
    widget.onFocusChange?.call(_node.hasFocus);
  }

  @override
  void dispose() {
    _node.removeListener(_onFocus);
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: widget.tooltip,
      focusNode: _node,
      autofocus: widget.autofocus,
      style: _focused
          ? IconButton.styleFrom(backgroundColor: Colors.white24)
          : null,
      icon: Icon(widget.icon, color: Colors.white),
      onPressed: widget.onPressed,
    );
  }
}
