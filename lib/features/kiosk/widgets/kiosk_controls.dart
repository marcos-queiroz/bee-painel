import 'package:flutter/material.dart';

/// Controle discreto e sempre visível no canto inferior esquerdo do kiosque,
/// com as ações de sair/voltar (cada uma passa pela verificação de PIN no chamador).
class KioskControls extends StatefulWidget {
  const KioskControls({
    super.key,
    required this.onSettings,
    required this.onHome,
    required this.onQuit,
  });

  final VoidCallback onSettings;
  final VoidCallback onHome;
  final VoidCallback onQuit;

  @override
  State<KioskControls> createState() => _KioskControlsState();
}

class _KioskControlsState extends State<KioskControls> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 12,
      left: 12,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: _expanded ? 1.0 : 0.35,
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
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
                if (_expanded) ...[
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

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, color: Colors.white),
      onPressed: onPressed,
    );
  }
}
